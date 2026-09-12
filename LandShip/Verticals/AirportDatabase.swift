//
//  AirportDatabase.swift
//
//  Read-only access to the bundled airport reference database built by
//  tools/build-airports.py from the OurAirports open dataset (public domain).
//
//  Add airports.sqlite to the app target's Copy Bundle Resources phase. The file
//  is never written to, so it does not belong in SwiftData — this is static
//  reference data that ships with the build and is replaced by shipping a new
//  build. Anything the user *creates* about an airport (a fuel stop, a note, a
//  home base) should be a SwiftData model that stores the `icao` string as a
//  foreign key into this table.
//

import Foundation
import SQLite3

// sqlite3_bind_text needs to copy the string; SQLITE_TRANSIENT is a macro that
// does not survive into Swift, so redeclare it.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Model

public enum AirportType: String, Codable, CaseIterable, Sendable {
    case large = "large_airport"
    case medium = "medium_airport"
    case small = "small_airport"
    case heliport
    case seaplaneBase = "seaplane_base"
    case balloonport

    public var displayName: String {
        switch self {
        case .large:        return "Large airport"
        case .medium:       return "Medium airport"
        case .small:        return "Small airport"
        case .heliport:     return "Heliport"
        case .seaplaneBase: return "Seaplane base"
        case .balloonport:  return "Balloonport"
        }
    }

    /// Fixed-wing landing sites, for filtering a picker by aircraft category.
    public var acceptsFixedWing: Bool {
        switch self {
        case .large, .medium, .small, .seaplaneBase: return true
        case .heliport, .balloonport:                return false
        }
    }
}

public struct Airport: Identifiable, Hashable, Sendable {
    /// ICAO where one exists, otherwise the OurAirports identifier. Stable — use
    /// this as the foreign key from your own records.
    public let id: String
    public let icao: String?
    public let iata: String?
    /// FAA / national local code, e.g. "TUS", "1G4".
    public let localCode: String?
    public let name: String
    public let type: AirportType
    public let latitude: Double?
    public let longitude: Double?
    public let elevationFeet: Int?
    public let municipality: String?
    public let countryCode: String
    public let countryName: String?
    public let regionCode: String?
    public let regionName: String?
    public let hasScheduledService: Bool
    /// IANA identifier, e.g. "America/Phoenix". Nil if the build ran without
    /// the timezone pass, or the lookup failed.
    public let timeZoneIdentifier: String?

    public var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    /// "KTUS · TUS" — what to show in a list row.
    public var codeLabel: String {
        [icao, iata].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Tucson, Arizona, United States"
    public var locationLabel: String {
        [municipality, regionName, countryName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Errors

public enum AirportDatabaseError: Error, LocalizedError {
    case resourceMissing(String)
    case openFailed(String)
    case queryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "\(name) is missing from the app bundle."
        case .openFailed(let message):
            return "Could not open the airport database: \(message)"
        case .queryFailed(let message):
            return "Airport query failed: \(message)"
        }
    }
}

// MARK: - Database

public actor AirportDatabase {

    // `OpaquePointer` isn't Sendable, so actor isolation would otherwise block
    // touching it from the nonisolated `deinit` that closes the connection. The
    // pointer is set once in `init` and never mutated, so trusting it here is safe.
    private nonisolated(unsafe) let handle: OpaquePointer

    /// Opens the bundled database read-only.
    public init(resource: String = "airports", extension ext: String = "sqlite",
                bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw AirportDatabaseError.resourceMissing("\(resource).\(ext)")
        }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw AirportDatabaseError.openFailed(message)
        }
        self.handle = db
    }

    deinit { sqlite3_close(handle) }

    // MARK: Lookups

    public func airport(icao: String) throws -> Airport? {
        try query("SELECT \(Self.columns) FROM airports WHERE icao = ? LIMIT 1",
                  [icao.uppercased()]).first
    }

    public func airport(iata: String) throws -> Airport? {
        try query("SELECT \(Self.columns) FROM airports WHERE iata = ? LIMIT 1",
                  [iata.uppercased()]).first
    }

    public func airport(id: String) throws -> Airport? {
        try query("SELECT \(Self.columns) FROM airports WHERE ident = ? LIMIT 1",
                  [id.uppercased()]).first
    }

    /// Resolves whatever the user typed — ICAO, IATA or local code.
    public func airport(anyCode code: String) throws -> Airport? {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !c.isEmpty else { return nil }
        return try query("""
            SELECT \(Self.columns) FROM airports
            WHERE icao = ?1 OR iata = ?1 OR local_code = ?1 OR ident = ?1
            ORDER BY CASE WHEN icao = ?1 THEN 0 WHEN iata = ?1 THEN 1 ELSE 2 END
            LIMIT 1
            """, [c]).first
    }

    // MARK: Search

    /// Search-as-you-type. Codes match by prefix and rank first; names and
    /// cities go through the full-text index.
    public func search(_ text: String, limit: Int = 25) throws -> [Airport] {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 2 else { return [] }

        // GLOB rather than LIKE: LIKE is case-insensitive by default, so SQLite
        // cannot use the BINARY-collated code indexes for it and the query
        // degrades to a full table scan. GLOB is case-sensitive and index-friendly.
        // Codes are stored uppercase, so uppercase and strip anything GLOB would
        // read as a wildcard.
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !code.isEmpty else { return [] }

        // Bind the complete pattern. Writing `icao GLOB ?1 || '*'` builds the
        // pattern inside SQL, and SQLite will not apply its prefix optimisation
        // to a concatenated expression — measured on 30k rows that is a full scan
        // at ~4.2 ms per keystroke. Binding "KJ*" whole gives a MULTI-INDEX OR
        // across the three code indexes at ~0.13 ms. Do not inline the '*'.
        let pattern = code + "*"

        // Codes: index-backed prefix match.
        var results = try query("""
            SELECT \(Self.columns) FROM airports
            WHERE icao GLOB ?2 OR iata GLOB ?2 OR local_code GLOB ?2
            ORDER BY
              CASE WHEN icao = ?1 OR iata = ?1 THEN 0 ELSE 1 END,
              CASE type WHEN 'large_airport' THEN 0 WHEN 'medium_airport' THEN 1
                        WHEN 'small_airport' THEN 2 ELSE 3 END,
              ident
            LIMIT ?3
            """, [code, pattern, limit])

        guard results.count < limit else { return results }

        // Names and cities: FTS5 prefix query. Escape quotes, then quote each
        // token so punctuation cannot be read as FTS syntax.
        let tokens = raw
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return results }
        let match = tokens
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " ")

        let seen = Set(results.map(\.id))
        let byName = try query("""
            SELECT \(Self.columns.replacingOccurrences(of: "airports.", with: "a."))
            FROM airports_fts f
            JOIN airports a ON a.rowid = f.rowid
            WHERE airports_fts MATCH ?1
            ORDER BY
              CASE a.type WHEN 'large_airport' THEN 0 WHEN 'medium_airport' THEN 1
                          WHEN 'small_airport' THEN 2 ELSE 3 END,
              a.scheduled_service DESC,
              a.name
            LIMIT ?2
            """, [match, limit - results.count])

        results.append(contentsOf: byName.filter { !seen.contains($0.id) })
        return Array(results.prefix(limit))
    }

    // MARK: Nearest

    /// Airports near a point, closest first. Prefilters with a bounding box so
    /// the coordinate index does the work, then sorts by great-circle distance.
    public func nearest(latitude: Double, longitude: Double,
                        withinNauticalMiles radius: Double = 100,
                        limit: Int = 10,
                        types: Set<AirportType>? = nil) throws -> [(airport: Airport, distanceNM: Double)] {
        let degLat = radius / 60.0
        let cosLat = max(cos(latitude * .pi / 180), 0.01)
        let degLon = degLat / cosLat

        let candidates = try query("""
            SELECT \(Self.columns) FROM airports
            WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?
            """, [latitude - degLat, latitude + degLat,
                  longitude - degLon, longitude + degLon])

        return candidates
            .filter { types == nil || types!.contains($0.type) }
            .compactMap { airport -> (Airport, Double)? in
                guard let lat = airport.latitude, let lon = airport.longitude else { return nil }
                let d = Self.greatCircleNM(latitude, longitude, lat, lon)
                return d <= radius ? (airport, d) : nil
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { (airport: $0.0, distanceNM: $0.1) }
    }

    /// Great-circle distance in nautical miles.
    public nonisolated static func greatCircleNM(_ lat1: Double, _ lon1: Double,
                                                 _ lat2: Double, _ lon2: Double) -> Double {
        let r = 3440.065  // mean Earth radius in NM
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180
        let dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    // MARK: Counts

    public func count() throws -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM airports", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else {
            throw AirportDatabaseError.queryFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: Plumbing

    private static let columns = """
        airports.ident, airports.icao, airports.iata, airports.local_code, airports.name, \
        airports.type, airports.latitude, airports.longitude, airports.elevation_ft, \
        airports.municipality, airports.iso_country, airports.country_name, \
        airports.iso_region, airports.region_name, airports.scheduled_service, airports.tz
        """

    private func query(_ sql: String, _ bindings: [Any]) throws -> [Airport] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw AirportDatabaseError.queryFailed(String(cString: sqlite3_errmsg(handle)))
        }
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let s as String: sqlite3_bind_text(stmt, index, s, -1, SQLITE_TRANSIENT)
            case let i as Int:    sqlite3_bind_int64(stmt, index, Int64(i))
            case let d as Double: sqlite3_bind_double(stmt, index, d)
            default:              sqlite3_bind_null(stmt, index)
            }
        }

        var rows: [Airport] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(Self.decode(stmt))
        }
        return rows
    }

    private static func decode(_ stmt: OpaquePointer?) -> Airport {
        func text(_ i: Int32) -> String? {
            guard let c = sqlite3_column_text(stmt, i) else { return nil }
            let s = String(cString: c)
            return s.isEmpty ? nil : s
        }
        func double(_ i: Int32) -> Double? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, i)
        }
        func int(_ i: Int32) -> Int? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, i))
        }

        return Airport(
            id: text(0) ?? "",
            icao: text(1),
            iata: text(2),
            localCode: text(3),
            name: text(4) ?? "",
            type: AirportType(rawValue: text(5) ?? "") ?? .small,
            latitude: double(6),
            longitude: double(7),
            elevationFeet: int(8),
            municipality: text(9),
            countryCode: text(10) ?? "",
            countryName: text(11),
            regionCode: text(12),
            regionName: text(13),
            hasScheduledService: (int(14) ?? 0) == 1,
            timeZoneIdentifier: text(15)
        )
    }
}

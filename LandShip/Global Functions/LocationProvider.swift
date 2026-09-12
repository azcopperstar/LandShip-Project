import Foundation
import CoreLocation
import MapKit
import SwiftUI

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isFetching: Bool = false
    @Published private(set) var lastError: Error?
    /// The most recent fix from refreshLocationContext — set as a side effect inside
    /// requestOneLocation() so callers don't need to thread it through separately. Purely
    /// for display (e.g. a lat/lon caption under a location field); not used for geocoding
    /// decisions.
    @Published private(set) var lastLocation: CLLocation?
    /// The closest airports to `lastLocation`, nearest first — populated by
    /// refreshLocationContext(includeNearbyAirports:) for AeroTrax's location fields. Never
    /// auto-fills anything; the view offers each as a manual choice (see LabelLocationTextview).
    @Published private(set) var nearbyAirports: [NearbyAirport] = []
    /// The closest marinas (NauticalTrax) or ordinary businesses (VehicleTrax) to
    /// `lastLocation`, nearest first — populated by refreshLocationContext(nearbyPlaceQuery:).
    /// Backed by a live MapKit POI search rather than a bundled database (there's no marina/
    /// business equivalent of OurAirports, but MapKit's place *names* are reliable — unlike
    /// its total lack of ICAO/IATA *codes* for airports). Never auto-fills; the view offers
    /// each as a manual choice (see LabelLocationTextview).
    @Published private(set) var nearbyPlaces: [NearbyPlace] = []
    /// Fallback for VehicleTrax when a `.businesses` query finds no nearby POIs at all (e.g.
    /// a rural road) — the street name from a reverse geocode, shown as context with no
    /// fillable value (see LabelLocationTextview). `nil` whenever `nearbyPlaces` is non-empty.
    @Published private(set) var nearestRoadName: String?

    private let locationManager: CLLocationManager
    private let geocoder: CLGeocoder

    override init() {
        locationManager = CLLocationManager()
        geocoder = CLGeocoder()
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    /// What kind of nearby-place list to populate in `refreshLocationContext` — mutually
    /// exclusive per vertical (NauticalTrax's marinas vs. VehicleTrax's ordinary businesses).
    enum NearbyPlaceQuery {
        case none
        case marinas
        case businesses
    }

    /// Fetches the current location once and populates `lastLocation` (for the lat/lon
    /// caption) and, when requested, `nearbyAirports` (AeroTrax) or `nearbyPlaces`
    /// (NauticalTrax marinas / VehicleTrax businesses). Never writes to a text field itself;
    /// the view offers each result as a manual choice. Errors are silently ignored — this is
    /// a best-effort background refresh.
    func refreshLocationContext(includeNearbyAirports: Bool = false, nearbyPlaceQuery: NearbyPlaceQuery = .none) async {
        lastError = nil

        let status = await requestAuthorizationIfNeeded()
        switch status {
        case .denied, .restricted:
            return
        default:
            break
        }

        do {
            let location = try await requestOneLocation()   // also sets lastLocation

            if includeNearbyAirports, let db = Self.airportDatabase {
                let results = try await db.nearest(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    withinNauticalMiles: 150,
                    limit: 2,
                    types: [.large, .medium, .small, .seaplaneBase]
                )
                nearbyAirports = results.map { result in
                    let code = result.airport.icao ?? result.airport.iata ?? result.airport.localCode ?? result.airport.id
                    return NearbyAirport(
                        code: code, name: result.airport.name, distanceMeters: result.distanceNM * 1852.0,
                        latitude: result.airport.latitude ?? location.coordinate.latitude,
                        longitude: result.airport.longitude ?? location.coordinate.longitude
                    )
                }
            }

            switch nearbyPlaceQuery {
            case .none:
                break
            case .marinas:
                let results = try await nearbyPointsOfInterest(
                    around: location, categories: [.marina], radiusMeters: 80_000, limit: 2
                )
                nearbyPlaces = results.map { NearbyPlace(name: $0.name, distanceMeters: $0.distance, latitude: $0.latitude, longitude: $0.longitude) }
            case .businesses:
                // `CLPlacemark.areasOfInterest` (the reverse-address-geocoder path this used
                // to try first) is a landmark afterthought — empty for the overwhelming
                // majority of ordinary businesses. MapKit's POI search is built for exactly
                // this (a name for a place), the same way it's built for airport *names* —
                // just not for airport *codes*, which is the one thing it can't do (see
                // AirportDatabase.swift for why that's a bundled database instead).
                let results = try await nearbyPointsOfInterest(
                    around: location, categories: nil, radiusMeters: 2_000, limit: 2
                )
                if results.isEmpty {
                    nearbyPlaces = []
                    nearestRoadName = try? await reverseGeocodeRoadName(location: location)
                } else {
                    nearbyPlaces = results.map { NearbyPlace(name: $0.name, distanceMeters: $0.distance, latitude: $0.latitude, longitude: $0.longitude) }
                    nearestRoadName = nil
                }
            }
        } catch {
            self.lastError = error
        }
    }

    /// Opened once and reused — a fresh read-only SQLite connection per lookup would be
    /// wasteful, and the bundled file never changes at runtime. `nil` (rather than
    /// crashing) if the resource is somehow missing from the bundle.
    private static let airportDatabase: AirportDatabase? = try? AirportDatabase()

    /// Resolves an ICAO/IATA/local airport code typed directly into a location field
    /// (as opposed to a nearby-airport "Use" tap) to that airport's own coordinate and
    /// display code/name, so the coordinate caption stays accurate even when the code
    /// wasn't in the nearby list — e.g. the departure airport once already underway, or
    /// any distant stop — and the field itself can be normalized to "KTUS- Tucson
    /// International Airport" the same way a nearby-airport "Use" tap would show it.
    /// `code` prefers ICAO, matching the nearby-airport list's own preference order.
    /// `nil` on no match; never throws, since a location field is free text and most
    /// keystrokes along the way won't resolve to anything.
    func airportMatch(forCode code: String) async -> (code: String, name: String, latitude: Double, longitude: Double)? {
        guard let db = Self.airportDatabase else { return nil }
        guard let airport = try? await db.airport(anyCode: code),
              let lat = airport.latitude, let lon = airport.longitude else { return nil }
        let resolvedCode = airport.icao ?? airport.iata ?? airport.localCode ?? airport.id
        return (resolvedCode, airport.name, lat, lon)
    }

    /// Geocodes a typed place name (a city, not an airport code — see `airportMatch`
    /// above for that case) to a coordinate, then returns the 2 closest airports to it.
    /// For a location field that holds a city name rather than a code, so the user can
    /// still pick a specific airport via a "Use" button instead of typing the code
    /// themselves. `nil` when the name doesn't geocode to anything; empty when it does
    /// but no airport is nearby.
    func nearbyAirports(forPlaceName placeName: String) async -> [NearbyAirport]? {
        guard let db = Self.airportDatabase else { return nil }
        guard let placemarks = try? await geocodeAddressString(placeName),
              let location = placemarks.first?.location else { return nil }
        guard let results = try? await db.nearest(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            withinNauticalMiles: 150, limit: 2, types: [.large, .medium, .small, .seaplaneBase]
        ) else { return [] }
        return results.map { result in
            let code = result.airport.icao ?? result.airport.iata ?? result.airport.localCode ?? result.airport.id
            return NearbyAirport(
                code: code, name: result.airport.name, distanceMeters: result.distanceNM * 1852.0,
                latitude: result.airport.latitude ?? location.coordinate.latitude,
                longitude: result.airport.longitude ?? location.coordinate.longitude
            )
        }
    }

    private func geocodeAddressString(_ address: String) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CLPlacemark], Error>) in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    /// Nearby points of interest, closest first. Backs both VehicleTrax's nearest-
    /// businesses list (`categories: nil`) and NauticalTrax's nearest-marinas list
    /// (`categories: [.marina]`). MapKit is well-suited to *names* here — unlike the
    /// aviation case, where the same API couldn't supply an ICAO code because `MKMapItem`
    /// has no such property at all (see AirportDatabase.swift for why that feature is
    /// backed by a bundled database instead).
    private func nearbyPointsOfInterest(
        around location: CLLocation, categories: [MKPointOfInterestCategory]?,
        radiusMeters: CLLocationDistance, limit: Int
    ) async throws -> [(name: String, distance: CLLocationDistance, latitude: Double, longitude: Double)] {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radiusMeters)
        if let categories {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems
            .compactMap { item -> (name: String, distance: CLLocationDistance, latitude: Double, longitude: Double)? in
                guard let name = item.name, !name.isEmpty, let itemLocation = item.placemark.location else { return nil }
                return (name, location.distance(from: itemLocation), itemLocation.coordinate.latitude, itemLocation.coordinate.longitude)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    private func requestAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                let delegate = AuthorizationDelegate {
                    continuation.resume(returning: self.locationManager.authorizationStatus)
                }
                locationManager.delegate = delegate
                locationManager.requestWhenInUseAuthorization()
                // The AuthorizationDelegate instance needs to be kept alive until callback
                self.authorizationDelegateHolder = delegate
            }
        } else {
            return status
        }
    }

    private func requestOneLocation() async throws -> CLLocation {
        let location = try await withCheckedThrowingContinuation { continuation in
            let delegate = LocationRequestDelegate { result in
                continuation.resume(with: result)
            }
            locationManager.delegate = delegate
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.requestLocation()
            // Keep delegate alive until callback
            self.locationRequestDelegateHolder = delegate
        }
        lastLocation = location
        return location
    }

    /// Street name only (e.g. "Old Mill Rd") — the fallback for VehicleTrax when no business
    /// POIs are found nearby. Never returns a full street address; the caller treats this as
    /// context, not a fillable value.
    private func reverseGeocodeRoadName(location: CLLocation) async throws -> String? {
        let placemarks = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CLPlacemark], Error>) in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
        return placemarks.first?.thoroughfare
    }

    // Hold delegates so they don't get deallocated immediately
    private var authorizationDelegateHolder: AuthorizationDelegate?
    private var locationRequestDelegateHolder: LocationRequestDelegate?
}

/// One row of LocationProvider.nearbyAirports — the code is what gets written into a
/// location field if the user taps "Use"; `name` is shown alongside it for context.
struct NearbyAirport: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let distanceMeters: CLLocationDistance
    let latitude: Double
    let longitude: Double
}

/// One row of LocationProvider.nearbyPlaces (NauticalTrax marinas or VehicleTrax
/// businesses). Neither has an equivalent of an ICAO code, so unlike NearbyAirport, the
/// name itself is what gets written into the field.
struct NearbyPlace: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let distanceMeters: CLLocationDistance
    let latitude: Double
    let longitude: Double
}

// MARK: - CLLocationManagerDelegate helpers

private final class AuthorizationDelegate: NSObject, @MainActor CLLocationManagerDelegate {
    private let continuation: () -> Void

    init(continuation: @escaping () -> Void) {
        self.continuation = continuation
        super.init()
    }

    @MainActor
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuation()
    }
}

private final class LocationRequestDelegate: NSObject, @MainActor CLLocationManagerDelegate {
    private let callback: (Result<CLLocation, Error>) -> Void

    init(callback: @escaping (Result<CLLocation, Error>) -> Void) {
        self.callback = callback
        super.init()
    }

    @MainActor
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            callback(.success(location))
        } else {
            callback(.failure(LocationError.noLocations))
        }
        // Remove delegate to break retain cycle
        cleanupDelegate(from: manager)
    }

    @MainActor
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        callback(.failure(error))
        cleanupDelegate(from: manager)
    }

    @MainActor
    private func cleanupDelegate(from manager: CLLocationManager) {
        manager.delegate = nil
    }

    enum LocationError: Error {
        case noLocations
    }
}

extension LocationProvider: @MainActor CLLocationManagerDelegate {
    @MainActor
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
}

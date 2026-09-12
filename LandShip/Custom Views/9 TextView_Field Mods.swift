//
//  Custom Views.swift
//  LandShip
//
//  Created by JP on 9/4/25.
//

import Foundation
import SwiftUI
import SwiftData
import CoreLocation
import Combine
import CoreLocation

//import SwiftData


// MARK: textfield used for notes on forms
struct TextFieldNote_FullWidth_3lines: View {
	let sectionText: String
	let prompt: String
	@Binding var data: String
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: sectionText)
			TextField(prompt, text: $data, axis: .vertical)
				.textFieldStyle(.roundedBorder)
				.lineLimit(3...)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

// MARK: title of page + app name
struct PageTitle_Col2_NoPhoto: View {
	/// this is used in column 2 of the app to list the name of the database being presented along with the app name and version.  It is displayed in the app .safeAreaInset()
	/// Inputs:
	///	label: database name (ie VEHICLE DATABASE)
	///	i.e.
	///	.safeAreaInset(edge: .top) { PageTitle_Col2_NoPhoto(label: "VEHICLE DATABASE") }

	let label: String
	var body: some View {
		Text(label)
			.safeArea_TitleNoGraphic_Modifier()
	}
}
// MARK: photo + title of page + app name
struct PageTitle_Col3_Photo: View {
	/// this is used in column 3 of the app to list the a photo, name of the record being presented along with the app name and version.  It is displayed in the app .safeAreaInset()
	/// Inputs:
	///	label: database name (ie VEHICLE DATABASE)
	///	photo: optional photo
	///	i.e.
	///	.safeAreaInset(edge: .top) { PageTitle_Col2_NoPhoto(label: "VEHICLE DATABASE") }
	
	let label: String
	let action: String /// edit or display
	let dbRecord: String	/// record being displayed (may be a vehicleId UUID that needs lookup)
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		/// Look up display name if dbRecord is a vehicle UUID
		let displayText = Functions().getVehicleDisplayName(vehicleId: dbRecord, context: modelContext)

		Group {
			if action == "edit" {
				Text("EDIT \(displayText)".uppercased())
			} else {
				Text("\(displayText) DETAILS".uppercased())
			}
		}
		.safeArea_TitleNoGraphic_Modifier()
	}
}


// MARK: label + textfield string
// CHANGELOG: [Added] [iOS] LabelLocationTextview: added location service to location textfield
@MainActor
struct LabelLocationTextview: View {
    let label: String
    @Binding var data: String
    /// Coordinate captured alongside `data` — never typed, only ever set by tapping a
    /// "Use" choice below (or filled from Home). When both bindings are supplied, a
    /// non-editable "<coordinateLabel>: 39.8600°N, 75.2010°W" caption is shown above the
    /// text field so the coordinate a "Use" tap actually stored stays visible.
    var latitude: Binding<Double?>? = nil
    var longitude: Binding<Double?>? = nil
    var coordinateLabel: String = "Coordinates"

    @StateObject private var locationProvider = LocationProvider()
    @Query(filter: #Predicate<Settings1> { $0.userName == "primary1" })
    private var settingsFetch: [Settings1]
    /// Gates the ICAO/IATA/local code lookup to focus loss rather than every keystroke —
    /// see the `onChange(of:)` below — so a code isn't rewritten out from under the user
    /// while they're still typing it.
    @FocusState private var isLocationFieldFocused: Bool
    /// The 2 closest airports to a typed city name, populated on focus loss when `data`
    /// doesn't resolve as an airport code itself — offered as manual "Use" choices the
    /// same way the GPS-based nearby list is, never auto-filled.
    @State private var cityAirportChoices: [NearbyAirport] = []

    private var coordinateCaption: String {
        guard let lat = latitude?.wrappedValue, let lon = longitude?.wrappedValue else {
            return "-------N --------W"
        }
        return Self.coordinateString(for: CLLocation(latitude: lat, longitude: lon))
    }

    /// True once a real coordinate is showing — from a "Use" tap (present position via a
    /// nearby choice or Home) or a typed ICAO/IATA/local code — as opposed to the dashed
    /// placeholder. Drives the caption's accent-color highlight.
    private var hasCoordinateValue: Bool {
        latitude?.wrappedValue != nil && longitude?.wrappedValue != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
        if latitude != nil, longitude != nil {
            Text("\(coordinateLabel): \(coordinateCaption)")
                .font(.caption2)
                .foregroundStyle(hasCoordinateValue ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .textLabelModified()
            TextField("", text: $data, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
                .textViewModified()
                .focused($isLocationFieldFocused)
#if os(iOS)
                .selectAllTextOnBeginEditing()
#endif
        }
        if let location = locationProvider.lastLocation {
            ViewThatFits(in: .horizontal) {
                Text("Current Location: \(Self.coordinateString(for: location))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Location: \(Self.coordinateString(for: location))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        // Up to 2 manual "Use" choices — nearest airports (AeroTrax), marinas
        // (NauticalTrax), or businesses (VehicleTrax), with "Home" substituted in as the
        // top choice when it's closer than the nearest live result. Never auto-fills; see
        // locationChoices below and LocationProvider.refreshLocationContext(...).
        ForEach(locationChoices) { choice in
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(choice.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Use") {
                    data = choice.value
                    if let choiceLat = choice.latitude, let choiceLon = choice.longitude {
                        latitude?.wrappedValue = choiceLat
                        longitude?.wrappedValue = choiceLon
                    }
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(!choice.isEnabled)
            }
        }
        // Closest airports to a typed city name (not a code) — see cityAirportChoices
        // and resolveAirportCodeIfPossible() above. Same "Use" row shape as the GPS-based
        // list, just keyed off what the user typed instead of the device's location.
        ForEach(cityAirportChoices) { airport in
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("\(airport.code) — \(airport.name) (\(Self.distanceString(meters: airport.distanceMeters, nautical: true)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("Use") {
                    data = "\(airport.code)- \(airport.name)"
                    latitude?.wrappedValue = airport.latitude
                    longitude?.wrappedValue = airport.longitude
                    cityAirportChoices = []
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        }
        .task {
            // Populate the lat/lon caption and the nearby-airports/nearby-places list
            // above. Display-only until the user taps "Use" — this never writes to `data`
            // itself, on any vertical.
            await locationProvider.refreshLocationContext(
                includeNearbyAirports: Vertical.current.id == .aviation,
                nearbyPlaceQuery: Vertical.current.id == .marine ? .marinas
                    : Vertical.current.id == .land ? .businesses : .none
            )
        }
        .onChange(of: isLocationFieldFocused) { wasFocused, isFocused in
            // Only resolve the exact-code rewrite once the user is done typing (focus
            // lost), not per keystroke — rewriting the field mid-type would fight the
            // cursor/selection. City search (below) doesn't touch the field, so it isn't
            // gated the same way.
            guard wasFocused, !isFocused else { return }
            Task { await resolveAirportCodeIfPossible() }
        }
        .task(id: data) {
            // Live city-name search, as opposed to the focus-gated exact-code rewrite
            // above — safe to run on every keystroke since it only ever populates
            // cityAirportChoices for manual "Use" selection, never writes to `data`
            // itself. SwiftUI cancels the in-flight geocode when `data` changes again,
            // giving debounce-like behavior for free (same pattern as the appear-time
            // .task{} above).
            await searchCityAirportsLive()
        }
        .accessibilityHint("Shows nearby locations for manual selection")
    }

    /// Resolves the current `data` text as an ICAO/IATA/local airport code once the user
    /// is done editing (see the focus `onChange` above). On a match, normalizes the field
    /// to "KTUS- Tucson International Airport" and fills the coordinate caption, same as
    /// tapping a nearby-airport "Use" row.
    private func resolveAirportCodeIfPossible() async {
        guard Vertical.current.id == .aviation, latitude != nil, longitude != nil else { return }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }
        if let match = await locationProvider.airportMatch(forCode: trimmed) {
            latitude?.wrappedValue = match.latitude
            longitude?.wrappedValue = match.longitude
            let formatted = "\(match.code)- \(match.name)"
            if data != formatted {
                data = formatted
            }
        }
    }

    /// Tries the current `data` text as a city name as the user types and, if it
    /// geocodes, populates `cityAirportChoices` with the 2 closest airports — offered via
    /// "Use" only, since a city name is ambiguous about which airport is meant. Runs live
    /// (not focus-gated) because, unlike `resolveAirportCodeIfPossible`, it never writes
    /// to `data` or the coordinate itself. Skips the geocode entirely when the text is
    /// already an exact airport code — that case is handled by the focus-gated rewrite,
    /// and city results for it would be redundant.
    private func searchCityAirportsLive() async {
        guard Vertical.current.id == .aviation, latitude != nil, longitude != nil else { return }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            cityAirportChoices = []
            return
        }
        if await locationProvider.airportMatch(forCode: trimmed) != nil {
            cityAirportChoices = []
            return
        }
        cityAirportChoices = await locationProvider.nearbyAirports(forPlaceName: trimmed) ?? []
    }

    /// The Home coordinate saved in Settings, if the user has set one. Read here rather than
    /// in LocationProvider because it needs `Settings1`, a SwiftData model — LocationProvider
    /// itself has no ModelContext and is plain location/MapKit plumbing only.
    private var homeLocation: CLLocation? {
        guard let settings = settingsFetch.first,
              let lat = settings.homeLatitude, let lon = settings.homeLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private var homeDistanceMeters: CLLocationDistance? {
        guard let home = homeLocation, let current = locationProvider.lastLocation else { return nil }
        return current.distance(from: home)
    }

    /// One row of the manual "Use" list — a uniform shape covering airports, marinas,
    /// businesses, Home, and the disabled road-name fallback, so the view only needs one
    /// `ForEach` instead of a near-duplicate block per vertical.
    private struct LocationChoice: Identifiable {
        let id: String
        let title: String
        let value: String
        var latitude: Double? = nil
        var longitude: Double? = nil
        var isEnabled: Bool = true
    }

    /// Builds the 0-2 rows shown below the lat/lon caption. Aviation/marine use nautical
    /// miles for distance (the universal convention for both); land uses locale-natural
    /// units. When land's business search finds nothing nearby, falls back to a disabled,
    /// blank-value row showing just the road name — informational only, since there's
    /// nothing meaningful to fill into the field.
    private var locationChoices: [LocationChoice] {
        let nautical = Vertical.current.id != .land
        let base: [(choice: LocationChoice, distanceMeters: CLLocationDistance)]
        switch Vertical.current.id {
        case .aviation:
            base = locationProvider.nearbyAirports.map { airport in
                (LocationChoice(
                    id: airport.code,
                    title: "\(airport.code) — \(airport.name) (\(Self.distanceString(meters: airport.distanceMeters, nautical: true)))",
                    value: airport.code,
                    latitude: airport.latitude,
                    longitude: airport.longitude
                ), airport.distanceMeters)
            }
        case .marine:
            base = locationProvider.nearbyPlaces.map { place in
                (LocationChoice(
                    id: place.name,
                    title: "\(place.name) (\(Self.distanceString(meters: place.distanceMeters, nautical: true)))",
                    value: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude
                ), place.distanceMeters)
            }
        case .land:
            if locationProvider.nearbyPlaces.isEmpty {
                guard let road = locationProvider.nearestRoadName else { return [] }
                return [LocationChoice(id: "road", title: road, value: "", isEnabled: false)]
            }
            base = locationProvider.nearbyPlaces.map { place in
                (LocationChoice(
                    id: place.name,
                    title: "\(place.name) (\(Self.distanceString(meters: place.distanceMeters, nautical: false)))",
                    value: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude
                ), place.distanceMeters)
            }
        }

        guard let homeDistanceMeters, homeDistanceMeters < (base.first?.distanceMeters ?? .infinity) else {
            return base.map(\.choice)
        }
        let homeChoice = LocationChoice(
            id: "home",
            title: "Home (\(Self.distanceString(meters: homeDistanceMeters, nautical: nautical)))",
            value: "Home",
            latitude: homeLocation?.coordinate.latitude,
            longitude: homeLocation?.coordinate.longitude
        )
        return ([homeChoice] + base.map(\.choice)).prefix(2).map { $0 }
    }

    /// Signed decimal degrees with N/S, E/W suffixes, e.g. "39.8600°N, 75.2010°W".
    private static func coordinateString(for location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let latDirection = lat >= 0 ? "N" : "S"
        let lonDirection = lon >= 0 ? "E" : "W"
        return String(format: "%.4f°%@, %.4f°%@", abs(lat), latDirection, abs(lon), lonDirection)
    }

    /// Distance to a nearby-list entry. Aviation and marine use nautical miles (the
    /// universal convention for both); land uses `MeasurementFormatter`'s natural-scale
    /// output, which picks feet/miles or meters/km to match the device's locale.
    private static func distanceString(meters: CLLocationDistance, nautical: Bool) -> String {
        if nautical {
            return String(format: "%.1f nm", meters / 1852.0)
        }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}


// MARK: label + textfield string
struct LabelDataTextview: View {
	let label: String
	@Binding var data: String
	/// Overrides the placeholder text shown when `data` is empty. Defaults to `label` when nil.
	var prompt: String? = nil
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", text: $data, prompt: Text(prompt ?? label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if os(iOS)
			.selectAllTextOnBeginEditing()
#endif

	}
}

/// A multi-line variant of `LabelDataTextview`, for a free-form field that lives as one more
/// row inside an existing card section rather than in its own `TextFieldNote_FullWidth_3lines`
/// card with its own header.
struct LabelDataTextview_MultiLine: View {
	let label: String
	@Binding var data: String
	var prompt: String? = nil
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.textLabelModified()
			TextField(prompt ?? label, text: $data, axis: .vertical)
				.textFieldStyle(.roundedBorder)
				.lineLimit(3...)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

// MARK: label + textfield INT
struct LabelDataTextview_Numberpad_Int: View {
	let label: String
	@Binding var data: Int
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, formatter: functions.IntFormatter, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if os(iOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.numberPad)
#endif
	}
}

// MARK: label + textfield Double
struct LabelDataTextview_Numberpad_Float: View {
	let label: String
	@Binding var data: Float
	/// When true, uses the fixed Medium-width box (matching Qty/Price/Oil/tank-added/etc.
	/// in LabelDataTextview_Numberpad_Fuel) instead of the default full-width field — for
	/// fields that sit alongside other fixed-width fields in the same row/section, so all
	/// boxes read as the same size. Defaults to the original full-width behavior so every
	/// other call site of this shared struct is unaffected.
	var fixedWidth: Bool = false
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		if fixedWidth {
			TextField("", value: $data, formatter: functions.DoubleFormatter, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
				.textViewModified_Medium()
#if !os(macOS)
				.selectAllTextOnBeginEditing()
				.keyboardType(.decimalPad)
#endif
		} else {
			TextField("", value: $data, formatter: functions.DoubleFormatter, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
				.textViewModified()
#if !os(macOS)
				.selectAllTextOnBeginEditing()
				.keyboardType(.decimalPad)
#endif
		}
	}
}

/// An existing fuel log offered when linking an enroute stop to a record that already exists.
struct FuelLogChoice: Identifiable, Hashable {
	/// The `FuelLog1.logId` of the record.
	let id: String
	/// Row text shown in the picker (date, quantity and location).
	let label: String
}

// MARK: label + textfield for fuel added
struct LabelDataTextview_Numberpad_Fuel: View {
	let label: String
	@Binding var dataQuantity: Float
	@Binding var dataFuelLog: Bool
	var fuelEntryValue: Float
	@Binding var dataPrice: Float
	@Binding var fuelOdometer: Float
	@Binding var fuelEngHours: Float
	@Binding var fuelLocation: String
	/// Coordinate captured alongside `fuelLocation` when a "Use" choice is tapped. See
	/// LabelLocationTextview.latitude/longitude — same never-typed, "Use"-only contract.
	var fuelLocationLat: Binding<Double?>? = nil
	var fuelLocationLon: Binding<Double?>? = nil
	@Binding var fuelNotes: String
	@Binding var oilAdded: Float
	let labelOil: String
	@Binding var defAdded: Float
	let labelDEF: String
	@Binding var oilChecked: Bool
	@Binding var engineCoolantChecked: Bool
	@Binding var secondaryCoolantChecked: Bool
	@Binding var powerSteeringChecked: Bool
	@Binding var brakeFluidChecked: Bool
	@Binding var transmissionFluidChecked: Bool
	@Binding var rearAxleChecked: Bool
	@Binding var frontAxleChecked: Bool
	@Binding var fuelWaterSeparatorChecked: Bool
	@Binding var airSystemWaterBleedChecked: Bool
	/// Aviation/marine fluid checks for this stop — see FluidCheckList in 11 Enums.swift.
	/// When supplied, the fixed bindings above are ignored inside the Fluid Checks sheet.
	var checkedFluidItems: Binding<Set<String>>? = nil
	@Binding var fuelDateTime: Date
	@Binding var fuelImage1: Data?
	@Binding var fuelImage2: Data?
	@Binding var fuelImage3: Data?
	var fuelExitTime: Binding<Date>? = nil
	var stopReason: Binding<String>? = nil
	var stopComment: Binding<String>? = nil
	/// Fuel-log attributes for this stop. Supplied only when the stop should write a
	/// linked FuelLog1 record, so they are shown alongside the other fuel log fields.
	var fuelLevelStart: Binding<Float>? = nil
	var fuelLevelEnd: Binding<Float>? = nil
	var defLevel: Binding<Float>? = nil
	var fuelType: Binding<String>? = nil
	/// Actual quantities behind each level. Supply these to make the figures editable,
	/// for a digital readout where an exact amount beats an eighths estimate.
	var fuelQuantityStart: Binding<Float>? = nil
	var fuelQuantityEnd: Binding<Float>? = nil
	var defQuantity: Binding<Float>? = nil
	/// DEF level before adding any. The `defLevel`/`defQuantity` pair above is the level
	/// after adding, shown as "DEF Level End".
	var defLevelStart: Binding<Float>? = nil
	var defQuantityStart: Binding<Float>? = nil
	/// Price per unit of DEF added at this stop.
	var defPrice: Binding<Float>? = nil
	/// Multi-tank aircraft only (AeroTrax) — per-tank Added amount for this stop, persisted
	/// onto the linked FuelLog1's own fuelTankNAdded fields (see add_editFuelRecord). A
	/// fixed 6-element array (unused slots ignored) rather than 6 discrete bindings, to
	/// avoid a 36-property explosion across the six enroute-stop editors that embed this view.
	var tankAdded: Binding<[Float]>? = nil
	var tankCount: Int = 1
	var tankName: (Int) -> String = { "Tank \($0)" }
	var tankCapacityFor: (Int) -> Float = { _ in 0 }
	/// Multi-tank aircraft only (AeroTrax) — per-engine oil added for this stop, replacing
	/// the single `oilAdded` field the same way it already replaced it on the standalone
	/// Fuel Log (see FuelLog1's "FLUIDS ADDED" fields). A fixed 6-element array for the
	/// same reason as `tankAdded` above.
	var engineOilAdded: Binding<[Float]>? = nil
	var engineCount: Int = 1
	var engineNameFor: (Int) -> String = { "Engine \($0)" }
	/// Per-engine tach time reading at this stop — mirrors `engineOilAdded` above, using
	/// the same fixed 6-element array and `engineCount`/`engineNameFor`. Persisted onto the
	/// linked FuelLog1's own `engineTach` field (see add_editFuelRecord).
	var engineTach: Binding<[Float]>? = nil
	/// Aviation-only fluids, alongside engine oil — mirrors FuelLog1's deiceFluidAdded/
	/// hydraulicFluidAdded/brakeFluidAdded, persisted the same way.
	var deiceFluidAdded: Binding<Float>? = nil
	var hydraulicFluidAdded: Binding<Float>? = nil
	var brakeFluidAdded: Binding<Float>? = nil
	/// Tank capacities used by the level pickers to show the resulting quantity.
	var fuelCapacity: Float = 0
	var defCapacity: Float = 0
	/// `logId` of the fuel log this stop writes to. Empty means a new log is created on save.
	var linkedLogId: Binding<String>? = nil
	/// Existing fuel logs the stop may be linked to instead of creating a new one.
	var fuelLogChoices: [FuelLogChoice] = []
	/// Called with the newly chosen `logId` so the owner can load that record's values.
	var onLinkFuelLog: ((String) -> Void)? = nil
	let functions: Functions = Functions()
	
	/// Optional callback invoked when any of the fuel fields (notably notes) change or commit
	var onUpdate: (() -> Void)? = nil
	@State private var showFluidChecks: Bool = false
	@State private var showFluidsAdded: Bool = false

	private var isLocationValid: Bool { !fuelLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !dataFuelLog }
	private var isQuantityValid: Bool { dataQuantity >= 0 }
	private var isPriceValid: Bool { !dataFuelLog || dataPrice >= 0 }
	private var isOdometerValid: Bool { !dataFuelLog || fuelOdometer >= 0 }
	private var isEngHoursValid: Bool { !dataFuelLog || fuelEngHours >= 0 }
	private var isOilValid: Bool { !dataFuelLog || oilAdded >= 0 }
	private var isDEFValid: Bool { !dataFuelLog || defAdded >= 0 }
	/// Stop details stay hidden until a stop reason is chosen, so a freshly-added stop doesn't show a wall of empty fields.
	private var fieldsVisible: Bool { stopReason.map { !$0.wrappedValue.isEmpty } ?? true }
	/// DEF only applies to a diesel vehicle, so its fields stay hidden for anything else.
	private var isDieselStop: Bool { fuelType.map { isDieselFamilyFuelType($0.wrappedValue) } ?? false }
	/// Quantity only applies to fuel stops; other stop reasons (rest, food, etc.) don't add fuel.
	private var isFuelStop: Bool { stopReason.map { $0.wrappedValue == "Fuel" } ?? true }

	/// Drops a trailing " (manufacturer)" from an engine name — `engineNameFor` includes it
	/// (useful for the Oil Added rows, which can span several engines), but the Tach row
	/// only needs "Engine 1 Tach", not "Engine 1 (Lycoming O-360) Tach".
	private func withoutManufacturer(_ name: String) -> String {
		guard let idx = name.firstIndex(of: "(") else { return name }
		return String(name[..<idx]).trimmingCharacters(in: .whitespaces)
	}

	/// "Fluid Checks" with a running count, so the button says how many were done
	/// without having to open the sheet.
	private var fluidChecksTitle: String {
		let done: Int
		if let items = checkedFluidItems {
			done = items.wrappedValue.count
		} else {
			done = [oilChecked, engineCoolantChecked, secondaryCoolantChecked, powerSteeringChecked,
				 brakeFluidChecked, transmissionFluidChecked, rearAxleChecked, frontAxleChecked,
				 fuelWaterSeparatorChecked, airSystemWaterBleedChecked].filter { $0 }.count
		}
		return "Fluid Checks (\(done) completed)"
	}

	/// Fills the end-of-stop fuel quantity in from the level before fuelling plus the amount
	/// added, so a stop only needs those two figures entered.
	///
	/// Only the quantity is set, not the eighths dropdown: writing the fraction here would
	/// trip its own `onChange` and overwrite the computed amount with the nearest eighth.
	/// The dropdown is reconciled from the quantity when the trip is saved.
	private func recalcEndLevelFromQuantity() {
		guard fuelCapacity > 0, let fuelQuantityEnd else { return }
		let startQuantity: Float
		if let stored = fuelQuantityStart?.wrappedValue {
			startQuantity = stored
		} else if let fraction = fuelLevelStart?.wrappedValue {
			startQuantity = fuelCapacity * fraction
		} else {
			return
		}
		// A tank can't hold more than its capacity, however much was keyed in.
		fuelQuantityEnd.wrappedValue = min(fuelCapacity, max(0, startQuantity + dataQuantity))
	}

	/// Binding into one slot of a `tankAdded`/`engineOilAdded` fixed 6-element array —
	/// see those properties above for why an array instead of 6 discrete bindings.
	private func tankAddedBinding(_ array: Binding<[Float]>, _ number: Int) -> Binding<Float> {
		Binding(
			get: { number - 1 < array.wrappedValue.count ? array.wrappedValue[number - 1] : 0 },
			set: { newValue in
				var values = array.wrappedValue
				while values.count < number { values.append(0) }
				values[number - 1] = newValue
				array.wrappedValue = values
			}
		)
	}
	
	/// Fills the end DEF quantity in from the level before adding plus the amount added,
	/// mirroring how the end fuel level is derived.
	///
	/// Sets only the quantity, not the eighths dropdown — writing the fraction would trip its
	/// own `onChange` and overwrite the computed amount with the nearest eighth.
	private func recalcEndDefLevelFromAdded() {
		guard defCapacity > 0, let defQuantity else { return }
		let startQuantity: Float
		if let stored = defQuantityStart?.wrappedValue {
			startQuantity = stored
		} else if let fraction = defLevelStart?.wrappedValue {
			startQuantity = defCapacity * fraction
		} else {
			return
		}
		defQuantity.wrappedValue = min(defCapacity, max(0, startQuantity + defAdded))
	}
	
	/// Menu entry (and closed-state label) for "no linked log — create one on save".
	private var newFuelLogLabel: String { "— New Log —" }

	/// Closed-state label for the linked fuel log menu.
	/// - Parameter id: The `logId` currently linked, or an empty string for a new log.
	private func linkedFuelLogLabel(_ id: String) -> String {
		guard !id.isEmpty else { return newFuelLogLabel }
		return fuelLogChoices.first(where: { $0.id == id })?.label ?? newFuelLogLabel
	}

	/// Links this stop to `id` and lets the owner load that record's values.
	private func selectFuelLog(_ id: String, _ linkedLogId: Binding<String>) {
		linkedLogId.wrappedValue = id
		onLinkFuelLog?(id)
	}

	@ViewBuilder private func validatedField<Content: View>(_ valid: Bool, @ViewBuilder content: () -> Content) -> some View {
		content()
			.overlay(
				RoundedRectangle(cornerRadius: 7)
					.stroke(valid ? Color.clear : Color.red.opacity(0.6), lineWidth: valid ? 0 : 1)
			)
	}
	
	var body: some View {
		VStack {
				if let stopReason {
					let predefined: [String] = ["", "Fuel", "Rest", "Food", "Sightseeing", "Lodging", "Maintenance", "Weather"]
					let pickerSel = predefined.contains(stopReason.wrappedValue) ? stopReason.wrappedValue : "Other"
					HStack {
						Text("Stop Reason")
							.textLabelModified()
						Picker("", selection: Binding(
							get: { pickerSel },
							set: { val in
								if val == "Other" { stopReason.wrappedValue = "Other" }
								else { stopReason.wrappedValue = val }
								// The toggle is only shown for a fuel stop, so keep the flag in step with the
								// reason — otherwise a stop switched away from Fuel would keep its fuel log
								// fields on screen with no control left to turn them off.
								dataFuelLog = (val == "Fuel")
							}
						)) {
							Text("Not Set").tag("")
							Text("Fuel").tag("Fuel")
							Text("Rest").tag("Rest")
							Text("Food").tag("Food")
							Text("Sightseeing").tag("Sightseeing")
							Text("Lodging").tag("Lodging")
							Text("Maintenance").tag("Maintenance")
							Text("Weather").tag("Weather")
							Text("Other").tag("Other")
						}
						.pickerStyle(.menu)
						.pickerModifier_Medium()
					}
					if pickerSel == "Other" {
						HStack {
							Text("  Specify")
								.bold()
							TextField("Describe stop", text: Binding(
								get: { stopReason.wrappedValue == "Other" ? "" : stopReason.wrappedValue },
								set: { stopReason.wrappedValue = $0.isEmpty ? "Other" : $0 }
							))
							.textFieldStyle(.roundedBorder)
						}
					}
				}
				if fieldsVisible {
				if let stopComment {
					HStack {
						Text("Comments")
							.bold()
						TextField("Stop notes", text: stopComment)
							.textFieldStyle(.roundedBorder)
					}
				}
				if fuelEntryValue == 0, isFuelStop {
				// only display fuel log option if new entry, and only for a fuel stop —
				// an edited entry would be > 0 so its log already exists
				Toggle(isOn: $dataFuelLog){
					Text("Create Fuel Log")
						.textLabelModified()
				}
				.accessibilityLabel("Create Fuel Log")
				.accessibilityHint("Enable to store this fuel stop as a separate log with price, odometer, and fluids")
				.onChange(of: dataFuelLog) { _, newValue in
					if newValue { stopReason?.wrappedValue = "Fuel" }
				}
			}
				// Link this stop to a fuel log that already exists rather than making a new one.
				if dataFuelLog, let linkedLogId, !fuelLogChoices.isEmpty {
					HStack {
						Text("Linked Fuel Log")
							.textLabelModified()
						// A Menu rather than a Picker: a fuel log's label is long, and a menu Picker
						// wraps its closed-state label over several lines, spilling into the row below.
						Menu {
							Button(newFuelLogLabel) { selectFuelLog("", linkedLogId) }
							ForEach(fuelLogChoices) { choice in
								Button(choice.label) { selectFuelLog(choice.id, linkedLogId) }
							}
						} label: {
							Text(linkedFuelLogLabel(linkedLogId.wrappedValue))
								.lineLimit(1)
								.truncationMode(.tail)
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						.accessibilityLabel("Linked Fuel Log")
						.accessibilityHint("Choose an existing fuel log to attach to this stop, or create a new one")
					}
				}
				LabelDataPicker_DateTime(label: Vertical.current.id == .aviation ? "Arrive                       " : "Start Stop                   ", data: $fuelDateTime)
				if let fuelExitTime {
					LabelDataPicker_DateTime(label: Vertical.current.id == .aviation ? "Depart                       " : "End Stop                     ", data: fuelExitTime, notEarlierThan: fuelDateTime)
				}
				LabelLocationTextview(label: "Location", data: $fuelLocation, latitude: fuelLocationLat, longitude: fuelLocationLon, coordinateLabel: "Enroute Stop Coordinates")
				// Odometer, hours and fuel type describe the stop itself, so they come before the
				// tank readings and the amount put in.
				if dataFuelLog {
					HStack {
						if Vertical.current.visibleFieldGroups.contains(.odometer) {
						Text("Odometer")
							.textLabelModified()
						validatedField(isOdometerValid) {
							TextField("", value: $fuelOdometer, formatter: functions.FloatFormatter)
								.textViewModified_Medium()
#if !os(macOS)
								.selectAllTextOnBeginEditing()
								.keyboardType(.numberPad)
#endif
								.accessibilityLabel("Fuel Odometer")
						}
						if !isOdometerValid {
							Text("Odometer cannot be negative")
								.font(.caption2)
								.foregroundStyle(.red)
						}
						}
						Text(Vertical.current.hoursMeterLabel)
							.textLabelModified()
						validatedField(isEngHoursValid) {
							TextField("", value: $fuelEngHours, formatter: functions.FloatFormatter)
								.textViewModified_Medium()
#if !os(macOS)
								.selectAllTextOnBeginEditing()
								.keyboardType(.numberPad)
#endif
								.accessibilityLabel(Vertical.current.hoursMeterLabel)
						}
						if !isEngHoursValid {
							Text("Engine hours cannot be negative")
								.font(.caption2)
								.foregroundStyle(.red)
						}
					}
				}
				if let engineTach, Vertical.current.id == .aviation {
				ForEach(1...engineCount, id: \.self) { engineNumber in
					HStack {
						Text("\(withoutManufacturer(engineNameFor(engineNumber))) Tach")
							.textLabelModified()
						TextField("", value: tankAddedBinding(engineTach, engineNumber), formatter: functions.FloatFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("\(engineNameFor(engineNumber)) Tach Time")
					}
				}
			}
			if dataFuelLog, let fuelType {
					HStack {
						Spacer()
						Text("Fuel Type")
							.textLabelModified()
						Picker("", selection: fuelType) {
							FuelTypePickerOptions(currentValue: fuelType.wrappedValue)
						}
						.pickerStyle(.automatic)
					}
				}
				if dataFuelLog { FuelTypePickerNote() }
					// Level before fuelling comes before the amount put in, so the stop reads in the
				// order it happens: how full it was, then how much went in, then how full it ended.
				if dataFuelLog, let fuelLevelStart {
					HStack {
						Spacer()
						// Choosing an eighth fills the quantity in; a typed quantity is left alone and
						// reconciled back to the nearest eighth when the trip is saved.
						Picker_FuelLevel1(label: "Fuel Level Start", data: fuelLevelStart, data1: fuelCapacity, quantity: fuelQuantityStart)
							.onChange(of: fuelLevelStart.wrappedValue) { _, newFraction in
								fuelQuantityStart?.wrappedValue = fuelCapacity * newFraction
								recalcEndLevelFromQuantity()
							}
					}
				}
			if isFuelStop, let tankAdded, tankCount > 1 {
				ForEach(1...tankCount, id: \.self) { tankNumber in
					HStack {
						Text("\(tankName(tankNumber)) Qty\(label)")
							.textLabelModified()
						TextField("", value: tankAddedBinding(tankAdded, tankNumber), formatter: functions.DoubleFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("\(tankName(tankNumber)) Fuel Quantity \(label)")
							.onChange(of: tankAdded.wrappedValue) { _, _ in
								dataQuantity = tankAdded.wrappedValue.prefix(tankCount).reduce(0, +)
								recalcEndLevelFromQuantity()
							}
					}
				}
			}
			HStack {
				if isFuelStop, tankAdded == nil || tankCount <= 1 {
					Text("Qty\(label)")
						.textLabelModified()
					validatedField(isQuantityValid) {
						TextField("", value: $dataQuantity, formatter: functions.DoubleFormatter)
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("Fuel Quantity \(label)")
							.onChange(of: dataQuantity) { _, _ in
								recalcEndLevelFromQuantity()
							}
					}
					if !isQuantityValid {
						Text("Quantity cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
				}
				if dataFuelLog {
					Text("Price/\(label)")
						.textLabelModified()
					validatedField(isPriceValid) {
						TextField("", value: $dataPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
							.textViewModified_Medium()
#if !os(macOS)
							.selectAllTextOnBeginEditing()
							.keyboardType(.decimalPad)
#endif
							.accessibilityLabel("Fuel Price per \(label)")
					}
					if !isPriceValid {
						Text("Price cannot be negative")
							.font(.caption2)
							.foregroundStyle(.red)
					}
				}
			}
			if dataFuelLog, let fuelLevelEnd {
				HStack {
					Spacer()
					Picker_FuelLevel1(label: "Fuel Level End", data: fuelLevelEnd, data1: fuelCapacity, quantity: fuelQuantityEnd)
						.onChange(of: fuelLevelEnd.wrappedValue) { _, newFraction in
							fuelQuantityEnd?.wrappedValue = fuelCapacity * newFraction
						}
				}
			}
			if dataFuelLog {
				VStack {
					// Aviation moves Oil/Deice/Hydraulic/Brake into the "Fluids Added" popup
					// below instead — land/marine keep the simple inline Oil field, unchanged.
					if Vertical.current.id != .aviation {
					HStack(alignment: .center) {
						Text("--------- Fluids Added ---------")
					}
					// Oil stands on its own row; DEF gets its own amount and price so a stop records DEF
					// cost the same way the fuel log does.
					HStack {
						Text("Oil \(labelOil)")
							.textLabelModified()
						validatedField(isOilValid) {
							TextField("", value: $oilAdded, formatter: functions.FloatFormatter)
								.textViewModified_Medium()
#if !os(macOS)
								.selectAllTextOnBeginEditing()
								.keyboardType(.decimalPad)
#endif
								.accessibilityLabel("Oil Added \(labelOil)")
						}
						if !isOilValid {
							Text("Oil cannot be negative")
								.font(.caption2)
								.foregroundStyle(.red)
						}
					}
					}
					if isDieselStop, let defLevelStart {
						HStack {
							Picker_FuelLevel1(label: "DEF Level Start", data: defLevelStart, data1: defCapacity, quantity: defQuantityStart)
								.onChange(of: defLevelStart.wrappedValue) { _, newFraction in
									defQuantityStart?.wrappedValue = defCapacity * newFraction
									recalcEndDefLevelFromAdded()
								}
						}
					}
					// DEF amount and price sit side by side and use the same labels as the fuel row above.
					if isDieselStop {
						HStack {
								Text("Qty\(labelDEF)")
								.textLabelModified()
							validatedField(isDEFValid) {
								TextField("", value: $defAdded, formatter: functions.FloatFormatter)
									.textViewModified_Medium()
#if !os(macOS)
									.selectAllTextOnBeginEditing()
									.keyboardType(.decimalPad)
#endif
									.accessibilityLabel("DEF Added \(labelDEF)")
									.onChange(of: defAdded) { _, _ in
										recalcEndDefLevelFromAdded()
									}
							}
							if !isDEFValid {
								Text("DEF cannot be negative")
									.font(.caption2)
									.foregroundStyle(.red)
							}
							if let defPrice {
								Text("Price/\(labelDEF)")
									.textLabelModified()
								validatedField(defPrice.wrappedValue >= 0) {
									TextField("", value: defPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
										.textViewModified_Medium()
#if !os(macOS)
										.selectAllTextOnBeginEditing()
										.keyboardType(.decimalPad)
#endif
										.accessibilityLabel("DEF Price per \(labelDEF)")
								}
							}
						}
					}
					if isDieselStop, let defLevel {
						HStack {
							Picker_FuelLevel1(label: "DEF Level End", data: defLevel, data1: defCapacity, quantity: defQuantity)
								.onChange(of: defLevel.wrappedValue) { _, newFraction in
									defQuantity?.wrappedValue = defCapacity * newFraction
								}
						}
					}
					HStack {
						Spacer()
						if Vertical.current.id == .aviation {
							Button {
								showFluidsAdded = true
							} label: {
								Label("Fluids Added", systemImage: "drop.triangle")
							}
							.buttonStyle(.bordered)
						}
						Button {
							showFluidChecks = true
						} label: {
							Label(fluidChecksTitle, systemImage: "drop.circle")
						}
						.buttonStyle(.bordered)
					}
					.sheet(isPresented: $showFluidChecks) {
						if let items = checkedFluidItems {
							FluidCheckSheet(checkedItems: items)
						} else {
							FluidCheckSheet(
							oilChecked: $oilChecked,
							engineCoolantChecked: $engineCoolantChecked,
							secondaryCoolantChecked: $secondaryCoolantChecked,
							powerSteeringChecked: $powerSteeringChecked,
							brakeFluidChecked: $brakeFluidChecked,
							transmissionFluidChecked: $transmissionFluidChecked,
							rearAxleChecked: $rearAxleChecked,
							frontAxleChecked: $frontAxleChecked,
							fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked,
							airSystemWaterBleedChecked: $airSystemWaterBleedChecked,
						)
						}
					}
					.sheet(isPresented: $showFluidsAdded) {
						FluidsAddedSheet(
							engineOilAdded: engineOilAdded,
							oilAdded: $oilAdded,
							engineCount: engineCount,
							engineNameFor: engineNameFor,
							labelOil: labelOil,
							deiceFluidAdded: deiceFluidAdded,
							hydraulicFluidAdded: hydraulicFluidAdded,
							brakeFluidAdded: brakeFluidAdded
						)
					}
				}
				HStack {
					
					CardView {
						TextFieldNote_FullWidth_3lines(sectionText: "FUEL LOG NOTES", prompt: "Enter notes...", data: $fuelNotes)
					}
					.onChange(of: fuelNotes) { _, _ in
						onUpdate?()
					}
					.onSubmit {
						onUpdate?()
					}
					.onDisappear {
						onUpdate?()
					}
//
//					Text("Notes")
//						.textLabelModified()
//					TextField("", text: $fuelNotes, prompt: Text("Enter fuel notes"))
//						.textViewModified()
//						.accessibilityLabel("Fuel Notes")
//						.accessibilityHint("Optional notes about this fuel stop")
//						.onChange(of: fuelNotes) { _, _ in
//							onUpdate?()
//						}
//						.onSubmit {
//							onUpdate?()
//						}
//						.onDisappear {
//							onUpdate?()
//						}
				}
				HStack(spacing: 8) {
					FuelStop_ImagePicker(imageData: $fuelImage1)
					FuelStop_ImagePicker(imageData: $fuelImage2)
					FuelStop_ImagePicker(imageData: $fuelImage3)
				}
			}
			}
		}
	}
}
	


// MARK: label + textfield currency
struct LabelDataTextview_Currency_Float: View {
	let label: String
	@Binding var data: Float
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, format: .currency(code: Locale.current.currency?.identifier ?? "USD"), prompt: Text(label.replacingOccurrences(of: ":", with: "")))
			.textViewModified()
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.decimalPad)
#endif
	}
}

// MARK: label + textfield currency
//struct LabelDataTextview_Currency_Float_Multiply: View {
//	let label: String
//	@Binding var data1: Float
//	@Binding var data2: Float
//	let functions: Functions = Functions()
//	var body: some View {
//		let data:Float = data1 * data2
//		Text(label)
//			.textLabelModified()
//		TextField("", value: data, formatter: functions.DoubleFormatter)
//			.textViewModified()
//#if !os(macOS)
//			.keyboardType(.decimalPad)
//#endif
//	}
//}

// MARK: label + textfield Double
struct LabelDataTextview_Numberpad_Currency: View {
	let label: String
	@Binding var data: Float
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", value: $data, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
			.textViewModified()
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.decimalPad)
#endif
	}
}

// MARK: label + textfield phone
struct LabelDataTextview_Numberpad_Phone: View {
	let label: String
	@Binding var data: String
	let functions: Functions = Functions()
	var body: some View {
		Text(label)
			.textLabelModified()
		TextField("", text: $data, prompt: Text(label.replacingOccurrences(of: ":", with: "")))
#if !os(macOS)
			.selectAllTextOnBeginEditing()
			.keyboardType(.phonePad)
#endif
	}
}

// MARK: modifier for all textfields >>>>>
struct TextFieldModifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
			.cornerRadius(corner)
			.frame(maxWidth: .infinity, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
					.stroke(.secondary.opacity(0.5), lineWidth: 1))
		//			.background(Color.blue)
	}
}

// MARK: modifier for textfields with short input field >>>>>
struct TextFieldModifier_Short: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
			.cornerRadius(corner)
			.frame(width: 50, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
				.stroke(.secondary.opacity(0.5), lineWidth: 1))
	}
}

struct TextFieldModifier_Medium: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding(EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
			.cornerRadius(corner)
			.frame(width: 80, alignment: .trailing)
			.multilineTextAlignment(.trailing)
			.overlay(RoundedRectangle(cornerRadius: 7)
				.stroke(.secondary.opacity(0.5), lineWidth: 1))
	}
}

struct SafeArea_Title_Modifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.font(.title2.bold())
			.foregroundStyle(.secondary)
			.shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
			.padding(.vertical, 2)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
}
struct SafeArea_TitleNoGraphic_Modifier: ViewModifier {
	let corner: CGFloat
	func body(content: Content) -> some View {
		content
			.font(.title2.bold())
			.foregroundStyle(.primary)
			.padding(.vertical, 2)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial)
			.overlay(alignment: .bottom) {
				Rectangle()
					.fill(Color.accentColor)
					.frame(height: 2)
			}
	}
}

// MARK: convenience extension for all modifiers
extension View {
	func textViewModified(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier(corner: radius))}
	func textViewModified_Short(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier_Short(corner: radius))}
	func textViewModified_Medium(with radius: CGFloat = 5) -> some View {
		self.modifier(TextFieldModifier_Medium(corner: radius))}
	func safeArea_Title_Modifier(with radius: CGFloat = 5) -> some View {
		self.modifier(SafeArea_Title_Modifier(corner: radius))}
	func safeArea_TitleNoGraphic_Modifier(with radius: CGFloat = 5) -> some View {
		self.modifier(SafeArea_TitleNoGraphic_Modifier(corner: radius))}
}

// used to select all text when textview field is entered (import Combine)
public struct SelectAllTextOnBeginEditingModifier: ViewModifier {
	public func body(content: Content) -> some View {
#if os(iOS)
		content
			.onReceive(NotificationCenter.default.publisher(
				for: UITextField.textDidBeginEditingNotification)) { _ in
					DispatchQueue.main.async {
						UIApplication.shared.sendAction(
							#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
						)
					}
				}
#endif
	}

}
extension View {
#if os(iOS)
	public func selectAllTextOnBeginEditing() -> some View {
		modifier(SelectAllTextOnBeginEditingModifier())
	}
#endif
}

// MARK: - Fluids Added Sheet
/// Aviation-only popup for a stop's Oil (per-engine when the aircraft has more than one)
/// plus Deice/Hydraulic/Brake fluid — pulled out of the enroute-stop form inline, mirroring
/// how "Fluid Checks" is its own popup rather than ten inline toggles.
struct FluidsAddedSheet: View {
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()

	var engineOilAdded: Binding<[Float]>? = nil
	@Binding var oilAdded: Float
	var engineCount: Int
	var engineNameFor: (Int) -> String
	var labelOil: String
	var deiceFluidAdded: Binding<Float>? = nil
	var hydraulicFluidAdded: Binding<Float>? = nil
	var brakeFluidAdded: Binding<Float>? = nil

	private func slotBinding(_ array: Binding<[Float]>, _ number: Int) -> Binding<Float> {
		Binding(
			get: { number - 1 < array.wrappedValue.count ? array.wrappedValue[number - 1] : 0 },
			set: { newValue in
				var values = array.wrappedValue
				while values.count < number { values.append(0) }
				values[number - 1] = newValue
				array.wrappedValue = values
			}
		)
	}

	/// Drops a trailing " (manufacturer)" from an engine name — mirrors the identical helper
	/// in `LabelDataTextview_Numberpad_Fuel`, kept local since this is a separate struct.
	private func withoutManufacturer(_ name: String) -> String {
		guard let idx = name.firstIndex(of: "(") else { return name }
		return String(name[..<idx]).trimmingCharacters(in: .whitespaces)
	}

	@ViewBuilder private func row(_ label: String, _ value: Binding<Float>, accessibilityLabel: String) -> some View {
		HStack {
			Text(label)
			Spacer()
			TextField("", value: value, formatter: functions.FloatFormatter)
				.multilineTextAlignment(.trailing)
#if !os(macOS)
				.selectAllTextOnBeginEditing()
				.keyboardType(.decimalPad)
#endif
				.accessibilityLabel(accessibilityLabel)
		}
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					if let engineOilAdded, engineCount > 1 {
						ForEach(1...engineCount, id: \.self) { engineNumber in
							row("\(withoutManufacturer(engineNameFor(engineNumber))) Oil \(labelOil)", slotBinding(engineOilAdded, engineNumber), accessibilityLabel: "\(withoutManufacturer(engineNameFor(engineNumber))) Oil Added \(labelOil)")
						}
					} else {
						row("Oil \(labelOil)", $oilAdded, accessibilityLabel: "Oil Added \(labelOil)")
					}
					if let deiceFluidAdded {
						row("Deice Fluid \(labelOil)", deiceFluidAdded, accessibilityLabel: "Deice Fluid Added \(labelOil)")
					}
					if let hydraulicFluidAdded {
						row("Hydraulic Fluid \(labelOil)", hydraulicFluidAdded, accessibilityLabel: "Hydraulic Fluid Added \(labelOil)")
					}
					if let brakeFluidAdded {
						row("Brake Fluid \(labelOil)", brakeFluidAdded, accessibilityLabel: "Brake Fluid Added \(labelOil)")
					}
				} header: {
					Text("Fluids added at this stop")
				}
			}
			.navigationTitle("Fluids Added")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

// MARK: - Fluid Check Sheet
struct FluidCheckSheet: View {
	@Environment(\.dismiss) private var dismiss

	@Query(filter: #Predicate<Settings1> { $0.userName == "primary1" })
	private var settingsQuery: [Settings1]
	private var s: Settings1? { settingsQuery.first }

	var oilChecked: Binding<Bool>? = nil
	var engineCoolantChecked: Binding<Bool>? = nil
	var secondaryCoolantChecked: Binding<Bool>? = nil
	var powerSteeringChecked: Binding<Bool>? = nil
	var brakeFluidChecked: Binding<Bool>? = nil
	var transmissionFluidChecked: Binding<Bool>? = nil
	var rearAxleChecked: Binding<Bool>? = nil
	var frontAxleChecked: Binding<Bool>? = nil
	var fuelWaterSeparatorChecked: Binding<Bool>? = nil
	var airSystemWaterBleedChecked: Binding<Bool>? = nil

	/// Aviation/marine — a vertical-specific item list (FluidCheckList.currentLabels)
	/// backed by one Set<String>, instead of the ten fixed Bool bindings above. When this
	/// is supplied, the fixed bindings are ignored entirely.
	var checkedItems: Binding<Set<String>>? = nil

	/// The vertical's full item list, filtered by whichever items the user has enabled in
	/// Settings — same "hide the ones I don't need" idea as the land fluidChk_* Bools just
	/// below, but backed by a single enabled-set per vertical instead of ten fixed fields.
	private var enabledLabels: [String] {
		switch Vertical.current.id {
			case .land: return []
			case .aviation: return (s?.enabledAviationFluidCheckItems ?? AviationFluidCheckItem.allCases).map(\.rawValue)
			case .marine: return (s?.enabledMarineFluidCheckItems ?? MarineFluidCheckItem.allCases).map(\.rawValue)
		}
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					if let items = checkedItems {
						ForEach(enabledLabels, id: \.self) { label in
							Toggle(label, isOn: Binding(
								get: { items.wrappedValue.contains(label) },
								set: { isOn in
									if isOn { items.wrappedValue.insert(label) }
									else { items.wrappedValue.remove(label) }
								}
							))
						}
					} else {
						if let b = oilChecked, s?.fluidChk_engineOil ?? true { Toggle("Engine Oil", isOn: b) }
						if let b = engineCoolantChecked, s?.fluidChk_engineCoolant ?? true { Toggle("Engine Coolant", isOn: b) }
						if let b = secondaryCoolantChecked, s?.fluidChk_secondaryCoolant ?? true { Toggle("Secondary Coolant", isOn: b) }
						if let b = powerSteeringChecked, s?.fluidChk_powerSteering ?? true { Toggle("Power Steering", isOn: b) }
						if let b = brakeFluidChecked, s?.fluidChk_brake ?? true { Toggle("Brake", isOn: b) }
						if let b = transmissionFluidChecked, s?.fluidChk_transmission ?? true { Toggle("Transmission", isOn: b) }
						if let b = rearAxleChecked, s?.fluidChk_rearAxle ?? true { Toggle("Rear Axle", isOn: b) }
						if let b = frontAxleChecked, s?.fluidChk_frontAxle ?? true { Toggle("Front Axle", isOn: b) }
						if let b = fuelWaterSeparatorChecked, s?.fluidChk_fuelWaterSep ?? true { Toggle("Fuel/Water Separator", isOn: b) }
						if let b = airSystemWaterBleedChecked, s?.fluidChk_airWaterBleed ?? true { Toggle("Air System Water Bleed", isOn: b) }
					}
				} header: {
					Text("Mark fluids checked at this stop")
				}
			}
			.navigationTitle("Fluid Checks")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

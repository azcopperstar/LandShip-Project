//
//  Vertical.swift
//  LandShip
//

import Foundation

/// Internal identifier for a product vertical. Stays a domain word — `.land` /
/// `.aviation` / `.marine` — even where the marine product is branded "NauticalTrax";
/// brand names live only in Vertical.storeProductID / build-setting display names,
/// never in identifiers.
enum VerticalID: String {
	case land
	case aviation
	case marine
}

/// Field groups on Vehicle8 that are meaningful for some verticals and not others.
/// Land shows all of them (unchanged behavior); aviation/marine hide the ones that
/// don't apply rather than removing the underlying stored data.
enum AssetFieldGroup: Hashable {
	case weightRatings   // gvwr, gcwr, gawrFront/Rear
	case axleWeights     // scaleWeightFrontAxle...TrailerAxle
	case tires           // tireSize, tirePressure*, wheelStudSize, wheelNutTorque
	case wheelFasteners
	case rvTanks         // waterCapacity, grayCapacity, blackCapacity, defCapacity
	case towing          // vehicleTowed, towingCapcity
}

/// Feature areas gated per vertical — used for sidebar rows, dashboard cards, and
/// model registration for vertical-specific @Model types added in later phases
/// (e.g. AirworthinessDirective, InspectionCycle for aviation).
enum VerticalFeature: Hashable {
	case airworthinessDirectives
	case inspectionCycles
	case componentTimes
	case haulOutRecords
	case surveyRecords
}

/// Optional grandfathering policy for users who owned the app before it converted
/// to free-with-IAP. `nil` means the vertical has no such history — a fresh product
/// launch must never grandfather anyone in. See TrialPolicy.isOriginalPurchaser.
struct GrandfatheringPolicy: Sendable {
	let originalAppVersionThresholdIOS: String
	let originalAppVersionThresholdMacOS: String
	let firstFreeBuildNumber: Int
}

/// Per-vertical terminology, icons, capability, and commerce configuration. One
/// profile per VerticalID; selection happens once via Vertical.active/.current.
/// The `.land` profile must reproduce today's VehicleTrax strings byte-for-byte —
/// Phase 1 of the multi-vertical rollout is a no-op for existing users.
struct Vertical: Sendable {
	let id: VerticalID

	// Terminology
	let assetSingular: String
	let assetPlural: String
	let garageSectionTitle: String
	let primaryMeterLabel: String
	let secondaryMeterLabel: String
	let registrationLabel: String
	let plateLabel: String
	let travelLogLabel: String

	// Icons
	let assetIcon: String
	let assetGroupIcon: String

	// Capability
	let visibleFieldGroups: Set<AssetFieldGroup>
	let enabledFeatures: Set<VerticalFeature>

	// Commerce
	let storeProductID: String
	let grandfathering: GrandfatheringPolicy?
}

extension Vertical {
	static let land = Vertical(
		id: .land,
		assetSingular: "Vehicle",
		assetPlural: "Vehicles",
		garageSectionTitle: "Garage",
		primaryMeterLabel: "Odometer",
		secondaryMeterLabel: "Engine Hours",
		registrationLabel: "VIN",
		plateLabel: "License Plate",
		travelLogLabel: "Travel Log",
		assetIcon: "car.fill",
		assetGroupIcon: "car.2.fill",
		visibleFieldGroups: [.weightRatings, .axleWeights, .tires, .wheelFasteners, .rvTanks, .towing],
		enabledFeatures: [],
		storeProductID: "com.aeronauticaltrax.LandShip.fullversion",
		grandfathering: GrandfatheringPolicy(
			originalAppVersionThresholdIOS: "92",
			originalAppVersionThresholdMacOS: "2026.09.02",
			firstFreeBuildNumber: 92
		)
	)

	static let aviation = Vertical(
		id: .aviation,
		assetSingular: "Aircraft",
		assetPlural: "Aircraft",
		garageSectionTitle: "Hangar",
		primaryMeterLabel: "Hobbs Time",
		secondaryMeterLabel: "Tach Time",
		registrationLabel: "Tail Number",
		plateLabel: "Registration",
		travelLogLabel: "Flight Log",
		assetIcon: "airplane",
		assetGroupIcon: "airplane",
		visibleFieldGroups: [],
		enabledFeatures: [.airworthinessDirectives, .inspectionCycles, .componentTimes],
		storeProductID: "com.aeronauticaltrax.aerotraxapp.fullversion",
		grandfathering: nil
	)

	static let marine = Vertical(
		id: .marine,
		assetSingular: "Vessel",
		assetPlural: "Vessels",
		garageSectionTitle: "Marina",
		primaryMeterLabel: "Engine Hours",
		secondaryMeterLabel: "",
		registrationLabel: "HIN",
		plateLabel: "Registration",
		travelLogLabel: "Voyage Log",
		assetIcon: "sailboat.fill",
		assetGroupIcon: "sailboat.fill",
		visibleFieldGroups: [.rvTanks],
		enabledFeatures: [.haulOutRecords, .surveyRecords],
		storeProductID: "com.aeronauticaltrax.nauticaltrax.fullversion",
		grandfathering: nil
	)

	/// Resolved once at launch from the active compilation condition. Exactly one
	/// #if in the whole codebase should ever test VERTICAL_AVIATION/VERTICAL_MARINE —
	/// this is it.
	static let active: Vertical = {
#if VERTICAL_AVIATION
		.aviation
#elseif VERTICAL_MARINE
		.marine
#else
		.land
#endif
	}()

#if DEBUG
	/// Debug-only override so a single build can preview all three verticals
	/// (relaunch required to pick up a change). Never consulted in Release.
	private static let debugOverrideKey = "debugVerticalOverride"

	static var current: Vertical {
		if let raw = UserDefaults.standard.string(forKey: debugOverrideKey),
		   let id = VerticalID(rawValue: raw) {
			switch id {
				case .land: return .land
				case .aviation: return .aviation
				case .marine: return .marine
			}
		}
		return active
	}
#else
	static var current: Vertical { active }
#endif
}

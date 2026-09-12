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
	case odometer        // the Int distance meter (mileage/odometerStart/odometerEnd/Miles)
	                     // in log editors — no aircraft logs an odometer reading
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
	case pilotLogbook
	case marinerSeaService
	case partCompliance     // identity/approval-basis/life/installation cards on MxParts1
	case fuelOperations     // cost stack/contract fuel/quality/performance cards on FuelLog1
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
	// The Float hours meter (Vehicle8.engHours) — what every log editor's "Engine Hours"
	// field actually feeds, and what derived part-life math reads. Distinct from
	// `primaryMeterLabel`, which historically got attached to the wrong (Int/odometer)
	// field in aviation's log editors — see multi-vertical-expansion memory, Phase 0.
	let hoursMeterLabel: String
	// The Int distance meter (mileage/odometerStart/odometerEnd/Miles). Only rendered
	// when `visibleFieldGroups.contains(.odometer)`.
	let distanceMeterLabel: String
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

	// Compliance
	/// Shown wherever regulatory-adjacent records are entered (AD/inspection/component
	/// records, haul-out/survey records) and during onboarding. `nil` for land, which has
	/// no equivalent regulatory framework this app could be mistaken for satisfying.
	let regulatoryDisclaimer: String?
}

extension Vertical {
	static let land = Vertical(
		id: .land,
		assetSingular: "Vehicle",
		assetPlural: "Vehicles",
		garageSectionTitle: "Garage",
		primaryMeterLabel: "Odometer",
		secondaryMeterLabel: "Engine Hours",
		hoursMeterLabel: "Engine Hours",
		distanceMeterLabel: "Odometer",
		registrationLabel: "VIN",
		plateLabel: "License Plate",
		travelLogLabel: "Travel Log",
		assetIcon: "car.fill",
		assetGroupIcon: "car.2.fill",
		visibleFieldGroups: [.weightRatings, .axleWeights, .tires, .wheelFasteners, .rvTanks, .towing, .odometer],
		enabledFeatures: [],
		storeProductID: "com.aeronauticaltrax.LandShip.fullversion",
		grandfathering: GrandfatheringPolicy(
			originalAppVersionThresholdIOS: "112",
			originalAppVersionThresholdMacOS: "2026.09.12",
			firstFreeBuildNumber: 112
		),
		regulatoryDisclaimer: nil
	)

	static let aviation = Vertical(
		id: .aviation,
		assetSingular: "Aircraft",
		assetPlural: "Aircraft",
		garageSectionTitle: "Hangar",
		primaryMeterLabel: "Hobbs Time",
		secondaryMeterLabel: "Tach Time",
		hoursMeterLabel: "Hobbs Time",
		distanceMeterLabel: "Distance Flown",
		registrationLabel: "Tail Number",
		plateLabel: "Serial Number",
		travelLogLabel: "Flight Log",
		assetIcon: "airplane",
		assetGroupIcon: "airplane",
		visibleFieldGroups: [],
		enabledFeatures: [.airworthinessDirectives, .inspectionCycles, .componentTimes, .pilotLogbook, .partCompliance, .fuelOperations],
		storeProductID: "com.aeronauticaltrax.aerotraxapp.fullversion",
		grandfathering: nil,
		regulatoryDisclaimer: "AeroTrax is a personal recordkeeping tool. It does not replace your official aircraft maintenance logbook, an A&P/IA's signoff, or your own research into applicable Airworthiness Directives. Always verify compliance through official FAA sources before flight."
	)

	static let marine = Vertical(
		id: .marine,
		assetSingular: "Vessel",
		assetPlural: "Vessels",
		garageSectionTitle: "Marina",
		primaryMeterLabel: "Engine Hours",
		secondaryMeterLabel: "",
		hoursMeterLabel: "Engine Hours",
		distanceMeterLabel: "Distance",
		registrationLabel: "HIN",
		plateLabel: "Registration",
		travelLogLabel: "Voyage Log",
		assetIcon: "sailboat.fill",
		assetGroupIcon: "sailboat.fill",
		visibleFieldGroups: [.rvTanks, .odometer],
		enabledFeatures: [.haulOutRecords, .surveyRecords, .marinerSeaService],
		storeProductID: "com.aeronauticaltrax.nauticaltrax.fullversion",
		grandfathering: nil,
		regulatoryDisclaimer: "NauticalTrax is a personal recordkeeping tool. It does not replace a licensed marine surveyor's report or your vessel's official maintenance and safety records. Always consult a qualified surveyor for insurance, safety, or pre-purchase decisions."
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

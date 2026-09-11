//
//  Enums.swift
//  LandShip
//
//  Created by JP on 10/5/25.
//

import Foundation

// Sidebar item identifiers for selection
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
	case dashboard
	case vehicles
	case parts
	case fuelLog
	case tripLog
	case pilotLogbook
	case seaService
	case records
	case items
	case systems
	case vendors
	case settings
	case backup
	case restore
	case additions
	case subscriptions
	case projectList
	case punchList
	case livePunchList
	case displayChecklist
	// Non-link resources/help is not part of selection (sheet/button)
	var id: String { rawValue }
}

// Fields that can be mirrored from a master Vehicle8 record onto a linked
// "aspect" record (e.g. Chassis, Engine, Body/House). The user chooses which
// of these to sync per linked record via a checkable picker in EditVehicle.
enum LinkableVehicleField: String, CaseIterable, Identifiable, Hashable {
	case odometer
	case engineHours
	case location
	case owner
	case insurance
	case vin
	case licensePlate
	case titleNumber

	var id: String { rawValue }

	var displayName: String {
		switch self {
			case .odometer: return "Odometer"
			case .engineHours: return "Engine Hours"
			case .location: return "Location"
			case .owner: return "Owner"
			case .insurance: return "Insurance Information"
			case .vin: return "VIN"
			case .licensePlate: return "License Plate"
			case .titleNumber: return "Title Number"
		}
	}

	var summary: String {
		switch self {
			case .odometer: return "Mirrors odometer and virtual odometer readings."
			case .engineHours: return "Mirrors current engine hours."
			case .location: return "Mirrors the \(Vertical.current.assetSingular.lowercased())'s location."
			case .owner: return "Mirrors the \(Vertical.current.assetSingular.lowercased())'s owner."
			case .insurance: return "Mirrors insurance provider, policy #, holder, and expiration."
			case .vin: return "Mirrors the VIN."
			case .licensePlate: return "Mirrors the license plate number."
			case .titleNumber: return "Mirrors the title number."
		}
	}
}

// Cards available on the Dashboard. The user chooses which are shown, in what
// order, via DashboardConfigView; the scheme is persisted on Settings1.
// rawValue is persisted — never rename or reorder cases without a migration.
enum DashboardCard: String, CaseIterable, Identifiable, Hashable {
	case maintenanceStatus
	case nextServiceDue
	case tripGroups
	case fleetSnapshot
	case insurance
	case warranty
	case quickActions
	case recentService
	case usageSinceLast
	case systemHotlist
	case costSnapshot
	case additionsCost
	case inventoryStatus

	var id: String { rawValue }

	/// "Fleet" reads naturally for land vehicles even with one owner; other verticals
	/// read better with their own asset word ("Aircraft Snapshot", not "Fleet Snapshot").
	private static var fleetWord: String {
		Vertical.current.id == .land ? "Fleet" : Vertical.current.assetPlural
	}

	var displayName: String {
		switch self {
			case .maintenanceStatus: return "\(Self.fleetWord) Maintenance Status"
			case .nextServiceDue: return "Next Service Due"
			case .tripGroups: return "Trip Groups"
			case .fleetSnapshot: return "\(Self.fleetWord) Snapshot"
			case .insurance: return "Insurance & Recurring Costs"
			case .warranty: return "Warranties"
			case .quickActions: return "Quick Actions"
			case .recentService: return "Recently Completed Service"
			case .usageSinceLast: return "Usage Since Last Service"
			case .systemHotlist: return "System Hotlist"
			case .costSnapshot: return "Maintenance Cost Snapshot"
			case .additionsCost: return "Additions Cost by Category"
			case .inventoryStatus: return "Inventory Status"
		}
	}

	var summary: String {
		switch self {
			case .maintenanceStatus: return "Overdue/due-soon status per \(Vertical.current.assetSingular.lowercased())."
			case .nextServiceDue: return "Most urgent upcoming service items."
			case .tripGroups: return "Trips grouped by trip name/tag."
			case .fleetSnapshot: return Vertical.current.id == .land
				? "Fleet counts, mileage, and maintenance cost totals."
				: "\(Self.fleetWord) counts, \(Vertical.current.primaryMeterLabel.lowercased()), and maintenance cost totals."
			case .insurance: return "Recurring subscription costs and insurance expirations."
			case .warranty: return Vertical.current.id == .land
				? "Warranty expiration and mileage-limit status."
				: "Warranty expiration and usage-limit status."
			case .quickActions: return "Shortcuts to add records."
			case .recentService: return "Most recently completed service records."
			case .usageSinceLast: return "Miles/hours accumulated since each \(Vertical.current.assetSingular.lowercased())'s last service."
			case .systemHotlist: return "\(Vertical.current.assetSingular) systems with the most overdue/due-soon items."
			case .costSnapshot: return "Month-to-date, 90-day, and year-to-date maintenance costs."
			case .additionsCost: return "Improvement/addition spending by category."
			case .inventoryStatus: return "Inventory-tracked parts that are low or out of stock."
		}
	}

	var icon: String {
		switch self {
			case .maintenanceStatus: return "wrench.and.screwdriver.fill"
			case .nextServiceDue: return "wrench.and.screwdriver.fill"
			case .tripGroups: return "map.fill"
			case .fleetSnapshot: return Vertical.current.assetGroupIcon
			case .insurance: return "shield.lefthalf.filled"
			case .warranty: return "checkmark.seal.fill"
			case .quickActions: return "plus.circle.fill"
			case .recentService: return "clock.arrow.circlepath"
			case .usageSinceLast: return "speedometer"
			case .systemHotlist: return "flame.fill"
			case .costSnapshot: return "dollarsign.circle.fill"
			case .additionsCost: return "plus.square.on.square"
			case .inventoryStatus: return "shippingbox.fill"
		}
	}

	/// Cards shown before the user configures anything — matches the dashboard's original hardcoded order.
	static let defaultOrder: [DashboardCard] = [
		.maintenanceStatus, .nextServiceDue, .tripGroups,
		.fleetSnapshot, .insurance, .warranty, .quickActions
	]
}

// Aviation fuel types offered by the Fuel Type picker (Edit Vehicle / Edit Fuel Log)
// when Vertical.current.id == .aviation. rawValue is both the persisted Vehicle8/FuelLog1
// fuelType string and the value stored in Settings1.enabledFuelTypesRaw — never rename
// or remove a case without a migration for both.
enum AviationFuelType: String, CaseIterable, Identifiable, Hashable {
	case avgas100LL = "100LL"
	case ul94 = "UL94"
	case ul9196 = "91/96 UL"
	case ul91 = "UL91"
	case mogas = "Mogas"

	case g100UL = "G100UL"
	case swift100R = "100R"
	case ul100E = "UL100E"

	case jetA = "Jet A"
	case jetA1 = "Jet A-1"
	case jetB = "Jet B"
	case ts1 = "TS-1"
	case no3JetFuel = "No. 3 Jet Fuel"

	case jp4 = "JP-4"
	case jp5 = "JP-5"
	case jp8 = "JP-8"
	case f24 = "F-24"
	case f35 = "F-35"
	case jp7 = "JP-7"
	case jpts = "JPTS"
	case jp10 = "JP-10"

	case saf = "SAF"
	case hydrogen = "Hydrogen"
	case lngMethane = "LNG/Methane"
	case batteryElectric = "Battery-Electric"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case pistonCurrent = "In Current Use"
		case pistonTransition = "Unleaded 100-Octane Transition"
		case turbineCivil = "Turbine — Civil"
		case turbineMilitary = "Turbine — Military"
		case sustainable = "Sustainable / Alternative"
	}

	var category: Category {
		switch self {
			case .avgas100LL, .ul94, .ul9196, .ul91, .mogas: return .pistonCurrent
			case .g100UL, .swift100R, .ul100E: return .pistonTransition
			case .jetA, .jetA1, .jetB, .ts1, .no3JetFuel: return .turbineCivil
			case .jp4, .jp5, .jp8, .f24, .f35, .jp7, .jpts, .jp10: return .turbineMilitary
			case .saf, .hydrogen, .lngMethane, .batteryElectric: return .sustainable
		}
	}

	var summary: String {
		switch self {
			case .avgas100LL: return "Low-lead, dyed blue — the global default for spark-ignition GA."
			case .ul94: return "Swift Fuels unleaded 94 octane, ASTM D7547."
			case .ul9196: return "Unleaded, ASTM D7547 — mostly Europe."
			case .ul91: return "Hjelmco/TotalEnergies unleaded — Scandinavia/Europe."
			case .mogas: return "Ethanol-free automotive gasoline burned under EAA/Petersen STCs."
			case .g100UL: return "GAMI unleaded 100-octane replacement, STC'd for essentially all spark-ignition piston aircraft."
			case .swift100R: return "Swift Fuels unleaded 100-octane replacement; ASTM production spec Sept 2025."
			case .ul100E: return "LyondellBasell/VP Racing unleaded 100-octane replacement; in PAFI testing."
			case .jetA: return "US domestic turbine standard, freeze point −40°C."
			case .jetA1: return "International turbine standard, freeze point −47°C."
			case .jetB: return "Wide-cut naphtha/kerosene blend for extreme cold (Canada, Alaska)."
			case .ts1: return "Russia/CIS primary jet fuel."
			case .no3JetFuel: return "China, GB 6537 — roughly equivalent to Jet A-1."
			case .jp4: return "NATO F-40 — wide-cut, largely retired."
			case .jp5: return "NATO F-44 — high flash point, carrier/naval use."
			case .jp8: return "NATO F-34 — land-based standard."
			case .f24: return "Jet A with military additive package (US domestic)."
			case .f35: return "Jet A-1 without static dissipator."
			case .jp7: return "SR-71 — high thermal stability."
			case .jpts: return "U-2 / high-altitude — very low freeze point."
			case .jp10: return "Synthetic single-component fuel for missiles and ramjets."
			case .saf: return "Sustainable Aviation Fuel — ASTM D7566 blending components, re-certified as D1655 once blended."
			case .hydrogen: return "Liquid (LH2) or gaseous — experimental/demonstrator aircraft only."
			case .lngMethane: return "Experimental."
			case .batteryElectric: return "Not a fuel, but shown in the same field on most logging systems."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings — the handful
	/// of fuels that cover the vast majority of GA piston and turbine aircraft.
	static let defaultEnabled: [AviationFuelType] = [.avgas100LL, .mogas, .jetA, .jetA1]
}

// Centralize storage keys to avoid typos across the app
enum StorageKey {
	static let trackVehicleSelected = "trackVehicleSelected"
	static let splitColumnVisibility = "splitColumnVisibility"
	static let hasCompletedOnboarding = "hasCompletedOnboarding"
	static let sidebarColumnWidth = "sidebarColumnWidth"
	static let contentColumnWidth = "contentColumnWidth"
	static let detailColumnWidth = "detailColumnWidth"
	static let launchScreen = "launchScreen"
	static let lastSidebarSection = "lastSidebarSection"
	static let lastBackupDate = "lastBackupDate"
	static let lastManualBackupBookmark = "lastManualBackupBookmark"
	static let lastAutoBackupDate = "lastAutoBackupDate"
	static let autoBackupInterval = "autoBackupInterval"
	static let autoBackupRetentionCount = "autoBackupRetentionCount"

	// Trial / full-version entitlement. Persisted so a cold launch while offline
	// keeps the user unlocked (fail open) — see EntitlementStore. Exactly one
	// code path may ever write fullVersionUnlocked = false: a successful,
	// verified currentEntitlements read that also fails the grandfathering checks.
	static let fullVersionUnlocked = "fullVersionUnlocked"
	static let fullVersionSource = "fullVersionSource"
	static let entitlementCheckedAt = "entitlementCheckedAt"
	static let originalAppVersionCached = "originalAppVersionCached"
	static let appStoreEnvironment = "appStoreEnvironment"
	static let firstFreeLaunchDate = "firstFreeLaunchDate"
	static let priorInstallDetected = "priorInstallDetected"
#if DEBUG
	static let debugForcedEntitlement = "debugForcedEntitlement"
#endif
}

// How often automatic backups should be created. rawValue is persisted via
// AppStorage — never rename or reorder cases without a migration.
enum AutoBackupInterval: String, CaseIterable, Identifiable, Hashable {
	case off
	case daily
	case weekly
	case monthly

	var id: String { rawValue }

	var label: String {
		switch self {
			case .off: return "Off"
			case .daily: return "Daily"
			case .weekly: return "Weekly"
			case .monthly: return "Monthly"
		}
	}

	/// Minimum elapsed time since the last backup (of any kind) before an
	/// automatic backup is due again. `nil` for `.off`.
	var minimumElapsed: TimeInterval? {
		switch self {
			case .off: return nil
			case .daily: return 60 * 60 * 24
			case .weekly: return 60 * 60 * 24 * 7
			case .monthly: return 60 * 60 * 24 * 30
		}
	}
}

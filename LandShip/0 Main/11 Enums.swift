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
			case .location: return "Mirrors the vehicle's location."
			case .owner: return "Mirrors the vehicle's owner."
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

	var id: String { rawValue }

	var displayName: String {
		switch self {
			case .maintenanceStatus: return "Fleet Maintenance Status"
			case .nextServiceDue: return "Next Service Due"
			case .tripGroups: return "Trip Groups"
			case .fleetSnapshot: return "Fleet Snapshot"
			case .insurance: return "Insurance & Recurring Costs"
			case .warranty: return "Warranties"
			case .quickActions: return "Quick Actions"
			case .recentService: return "Recently Completed Service"
			case .usageSinceLast: return "Usage Since Last Service"
			case .systemHotlist: return "System Hotlist"
			case .costSnapshot: return "Maintenance Cost Snapshot"
			case .additionsCost: return "Additions Cost by Category"
		}
	}

	var summary: String {
		switch self {
			case .maintenanceStatus: return "Overdue/due-soon status per vehicle."
			case .nextServiceDue: return "Most urgent upcoming service items."
			case .tripGroups: return "Trips grouped by trip name/tag."
			case .fleetSnapshot: return "Fleet counts, mileage, and maintenance cost totals."
			case .insurance: return "Recurring subscription costs and insurance expirations."
			case .warranty: return "Warranty expiration and mileage-limit status."
			case .quickActions: return "Shortcuts to add records."
			case .recentService: return "Most recently completed service records."
			case .usageSinceLast: return "Miles/hours accumulated since each vehicle's last service."
			case .systemHotlist: return "Vehicle systems with the most overdue/due-soon items."
			case .costSnapshot: return "Month-to-date, 90-day, and year-to-date maintenance costs."
			case .additionsCost: return "Improvement/addition spending by category."
		}
	}

	var icon: String {
		switch self {
			case .maintenanceStatus: return "wrench.and.screwdriver.fill"
			case .nextServiceDue: return "wrench.and.screwdriver.fill"
			case .tripGroups: return "map.fill"
			case .fleetSnapshot: return "car.2.fill"
			case .insurance: return "shield.lefthalf.filled"
			case .warranty: return "checkmark.seal.fill"
			case .quickActions: return "plus.circle.fill"
			case .recentService: return "clock.arrow.circlepath"
			case .usageSinceLast: return "speedometer"
			case .systemHotlist: return "flame.fill"
			case .costSnapshot: return "dollarsign.circle.fill"
			case .additionsCost: return "plus.square.on.square"
		}
	}

	/// Cards shown before the user configures anything — matches the dashboard's original hardcoded order.
	static let defaultOrder: [DashboardCard] = [
		.maintenanceStatus, .nextServiceDue, .tripGroups,
		.fleetSnapshot, .insurance, .warranty, .quickActions
	]
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
}

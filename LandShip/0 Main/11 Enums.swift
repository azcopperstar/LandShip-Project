//
//  Enums.swift
//  LandShip
//
//  Created by JP on 10/5/25.
//

import Foundation

// Sidebar item identifiers for selection
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
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
	// Non-link resources/help is not part of selection (sheet/button)
	var id: String { rawValue }
}

// Centralize storage keys to avoid typos across the app
enum StorageKey {
	static let trackVehicleSelected = "trackVehicleSelected"
	static let splitColumnVisibility = "splitColumnVisibility"
	static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

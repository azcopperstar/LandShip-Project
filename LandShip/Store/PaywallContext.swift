//
//  PaywallContext.swift
//  LandShip
//

import Foundation

/// What triggered the paywall, so the sheet can show a specific reason
/// instead of a generic pitch. Also doubles as the `.sheet(item:)` payload.
enum PaywallContext: Identifiable, Equatable {
	case capReached(feature: String, used: Int, limit: Int, requested: Int)
	case pdfExport
	case pdfPrint
	case autoBackup
	case manualBackup
	case restore
	case menu
	case sidebar

	var id: String {
		switch self {
			case .capReached(let feature, _, _, _): return "capReached-\(feature)"
			case .pdfExport: return "pdfExport"
			case .pdfPrint: return "pdfPrint"
			case .autoBackup: return "autoBackup"
			case .manualBackup: return "manualBackup"
			case .restore: return "restore"
			case .menu: return "menu"
			case .sidebar: return "sidebar"
		}
	}
}

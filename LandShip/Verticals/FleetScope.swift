//
//  FleetScope.swift
//  LandShip
//

import Foundation

/// The "All Vehicles" scope sentinel used by `trackVehicleSelected` and every report's
/// `scope` state. The persisted/compared string is fixed forever, regardless of
/// vertical — only its on-screen label changes. Comparisons against the raw literal
/// "All Vehicles" elsewhere in the codebase remain correct because this constant's
/// value never changes; `isAll` exists for new call sites and for readability.
enum FleetScope {
	static let allSentinel = "All Vehicles"
	static var allDisplayLabel: String { "All \(Vertical.current.assetPlural)" }
	static func isAll(_ value: String) -> Bool { value == allSentinel || value.isEmpty }
}

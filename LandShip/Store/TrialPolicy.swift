//
//  TrialPolicy.swift
//  LandShip
//

import Foundation

/// The version at which the app converted from paid-upfront to free-with-IAP.
/// Pure constants — no StoreKit/SwiftUI imports, so this is unit-testable standalone.
/// Sourced from Vertical.current.grandfathering — `nil` for verticals with no such
/// history (AeroTrax, NauticalTrax launch free-with-IAP from day one, so nobody may
/// ever be grandfathered in on those products).
enum FirstFreeRelease {
	static var policy: GrandfatheringPolicy? { Vertical.current.grandfathering }

#if os(macOS)
	/// AppTransaction.originalAppVersion is CFBundleShortVersionString on macOS.
	static var originalAppVersionThreshold: String? { policy?.originalAppVersionThresholdMacOS }
#else
	/// On iOS/iPadOS (and every other non-macOS platform) it is CFBundleVersion — the build number.
	static var originalAppVersionThreshold: String? { policy?.originalAppVersionThresholdIOS }
#endif
	/// The CFBundleVersion of the first free build, used by the local prior-install marker.
	static var firstFreeBuildNumber: Int? { policy?.firstFreeBuildNumber }
}

enum TrialPolicy {
	/// True when the receipt says this install originally purchased the app
	/// before it converted to free. `.numeric` is required: plain string
	/// comparison gets "9" vs "91" wrong, and "2026.9.1" vs "2026.10.1" only
	/// compares correctly numerically. Always false when the active vertical has
	/// no grandfathering policy (see FirstFreeRelease) — a vertical with no paid-
	/// upfront history must never grant a free unlock this way.
	static func isOriginalPurchaser(originalAppVersion: String) -> Bool {
		guard let threshold = FirstFreeRelease.originalAppVersionThreshold else { return false }
		return originalAppVersion.compare(
			threshold,
			options: .numeric
		) == .orderedAscending
	}

	/// True when this copy of the app was installed via TestFlight. Deliberately
	/// distinct from AppTransaction.environment == .sandbox, which is ALSO true
	/// during App Review — gating on that would unlock the full version for
	/// Apple's reviewer too, defeating the point of letting them see the trial.
	/// This receipt-filename check is the long-standing, TestFlight-specific
	/// heuristic (not guaranteed by Apple, but the conventional approach).
	///
	/// `appStoreReceiptURL` is deprecated in favor of AppTransaction/Transaction.all —
	/// intentionally not adopted here, since that replacement can't distinguish
	/// TestFlight from App Review (both report .sandbox). The deprecation warning
	/// on the line below is expected; do not "fix" it without re-solving that problem.
	static var isRunningViaTestFlight: Bool {
		Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
	}
}

//
//  TrialPolicy.swift
//  LandShip
//

import Foundation

/// The version at which the app converted from paid-upfront to free-with-IAP.
/// Pure constants — no StoreKit/SwiftUI imports, so this is unit-testable standalone.
enum FirstFreeRelease {
#if os(macOS)
	/// AppTransaction.originalAppVersion is CFBundleShortVersionString on macOS.
	static let originalAppVersionThreshold = "2026.10.01"
#else
	/// On iOS/iPadOS (and every other non-macOS platform) it is CFBundleVersion — the build number.
	static let originalAppVersionThreshold = "91"
#endif
	/// The CFBundleVersion of the first free build, used by the local prior-install marker.
	static let firstFreeBuildNumber = 91
}

enum TrialPolicy {
	/// True when the receipt says this install originally purchased the app
	/// before it converted to free. `.numeric` is required: plain string
	/// comparison gets "9" vs "91" wrong, and "2026.9.1" vs "2026.10.1" only
	/// compares correctly numerically.
	static func isOriginalPurchaser(originalAppVersion: String) -> Bool {
		originalAppVersion.compare(
			FirstFreeRelease.originalAppVersionThreshold,
			options: .numeric
		) == .orderedAscending
	}
}

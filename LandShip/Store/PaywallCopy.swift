//
//  PaywallCopy.swift
//  LandShip
//

import Foundation

enum PaywallCopy {
	static var title: String { "Unlock Full Version" }
	static let systemImage = "lock.open"

	static var whatsIncludedTitle: String { "What's included" }
	static var whatsIncludedMessage: String {
		"A single, one-time purchase — no subscription. Unlimited \(Vertical.current.assetPlural.lowercased()) and records in every table, PDF export and printing for every report, and automatic scheduled backups."
	}

	static func headline(for context: PaywallContext) -> String {
		switch context {
			case .capReached(let feature, let used, let limit, _):
				return "You've used all \(limit) of your free \(feature.lowercased()) (\(used) of \(limit))."
			case .pdfExport:
				return "Exporting reports is part of the full version."
			case .pdfPrint:
				return "Printing reports is part of the full version."
			case .autoBackup:
				return "Automatic scheduled backups are part of the full version."
			case .manualBackup:
				return "Backing up your data is part of the full version."
			case .restore:
				return "Restoring from backup is part of the full version."
			case .menu, .sidebar:
				return "Try \(AppInfo.displayName) free, then unlock everything with a single purchase."
		}
	}

	enum Sidebar {
		static var sectionTitle: String { "Full Version" }
		static var rowTitle: String { "Unlock Full Version" }
		static var trialCaption: String { "Free trial — 2 \(Vertical.current.assetPlural.lowercased()), 10 records each" }
	}

	enum Settings {
		static var sectionTitle: String { "Full Version" }
		static var unlockedCaption: String { "Full version — unlocked" }
		static var trialCaption: String { "Free trial" }
		static var unlockButtonLabel: String { "Unlock Full Version…" }
		static var restoreButtonLabel: String { "Restore Purchases" }
	}

	enum Restore {
		static var restoredTitle: String { "Purchases Restored" }
		static var restoredMessage: String { "The full version is now unlocked." }
		static var nothingTitle: String { "No Purchases Found" }
		static var nothingMessage: String { "We couldn't find a previous purchase to restore for this Apple ID." }
		static var failedTitle: String { "Restore Failed" }
	}

	static var storeUnavailableMessage: String { "The App Store is unavailable right now. Please try again." }
	static var retryButtonLabel: String { "Retry" }
	static var purchaseInProgressLabel: String { "Purchasing…" }
}

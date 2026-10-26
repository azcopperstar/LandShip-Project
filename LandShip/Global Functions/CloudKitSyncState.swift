//
//  CloudKitSyncState.swift
//  LandShip
//
//  Observable snapshot of CloudKit mirroring health, fed by CloudKitSyncMonitor from
//  NSPersistentCloudKitContainer events. Answers "is sync stuck, throttled, or just slow?"
//  without needing Console.app, and lets app-initiated writes back off while CloudKit
//  is rate limiting this container.
//

import CloudKit
import CoreData
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class CloudKitSyncState {
	static let shared = CloudKitSyncState()

	enum Operation: String {
		case setup = "Setup"
		case export = "Upload"
		case `import` = "Download"

		init?(_ type: NSPersistentCloudKitContainer.EventType) {
			switch type {
				case .setup: self = .setup
				case .export: self = .export
				case .import: self = .import
				@unknown default: return nil
			}
		}
	}

	private enum Key {
		static let lastExport = "cloudKitLastExportSuccess"
		static let lastImport = "cloudKitLastImportSuccess"
		static let throttledUntil = "cloudKitThrottledUntil"
	}

	private(set) var lastExportSuccess: Date? = UserDefaults.standard.object(forKey: Key.lastExport) as? Date
	private(set) var lastImportSuccess: Date? = UserDefaults.standard.object(forKey: Key.lastImport) as? Date
	private(set) var inFlight: Set<Operation> = []
	/// Set while CloudKit has told us to slow down; nil once the wait has elapsed.
	/// Persisted so the window survives a relaunch (launch-time writes check it).
	private(set) var throttledUntil: Date? = UserDefaults.standard.object(forKey: Key.throttledUntil) as? Date
	private(set) var lastErrorSummary: String?

	/// True while a CloudKit rate-limit window is still open.
	var isThrottled: Bool {
		guard let throttledUntil else { return false }
		return throttledUntil > Date()
	}

	/// Plain-language state for the UI.
	var headline: String {
		if isThrottled { return "Paused by iCloud (rate limited)" }
		if lastErrorSummary != nil && inFlight.isEmpty { return "Last attempt failed" }
		if inFlight.contains(.export) { return "Uploading changes…" }
		if inFlight.contains(.import) { return "Downloading changes…" }
		if inFlight.contains(.setup) { return "Setting up…" }
		return "Idle"
	}

	func begin(_ operation: Operation) {
		inFlight.insert(operation)
	}

	func succeeded(_ operation: Operation, at date: Date) {
		inFlight.remove(operation)
		lastErrorSummary = nil
		switch operation {
			case .export:
				lastExportSuccess = date
				UserDefaults.standard.set(date, forKey: Key.lastExport)
			case .import:
				lastImportSuccess = date
				UserDefaults.standard.set(date, forKey: Key.lastImport)
			case .setup:
				break
		}
	}

	/// Records a failure. A rate-limit error opens a back-off window honoring CloudKit's
	/// own `retryAfterSeconds`; anything else just updates the summary.
	func failed(_ operation: Operation, error: Error) {
		inFlight.remove(operation)
		lastErrorSummary = (error as NSError).localizedDescription
		if let wait = Self.retryAfter(for: error) {
			let until = Date().addingTimeInterval(wait)
			throttledUntil = until
			UserDefaults.standard.set(until, forKey: Key.throttledUntil)
		}
	}

	/// Seconds CloudKit asked us to wait, if this error (or any per-item error inside a
	/// partial failure) is a rate-limit / busy-zone response. Falls back to 60s when
	/// CloudKit throttles without saying for how long.
	nonisolated static func retryAfter(for error: Error) -> TimeInterval? {
		guard let ckError = error as? CKError else { return nil }

		switch ckError.code {
			case .requestRateLimited, .zoneBusy, .serviceUnavailable:
				return ckError.retryAfterSeconds ?? 60
			case .partialFailure:
				let waits = (ckError.partialErrorsByItemID ?? [:]).values.compactMap { retryAfter(for: $0) }
				return waits.max()
			default:
				return nil
		}
	}
}

// MARK: - Debug Tools section

/// Compact sync-health readout for the Debug Tools sheet.
struct CloudKitSyncStatusSection: View {
	private var state: CloudKitSyncState { .shared }

	var body: some View {
		Section("iCloud Sync Status") {
			LabeledContent("State", value: state.headline)
			LabeledContent("Last upload") { timestamp(state.lastExportSuccess) }
			LabeledContent("Last download") { timestamp(state.lastImportSuccess) }
			if state.isThrottled, let until = state.throttledUntil {
				LabeledContent("Resumes") {
					Text(until, style: .relative)
				}
			}
			if let summary = state.lastErrorSummary {
				Text(summary)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
	}

	@ViewBuilder
	private func timestamp(_ date: Date?) -> some View {
		if let date {
			Text(date, format: .dateTime.month().day().hour().minute())
		} else {
			Text("Never").foregroundStyle(.secondary)
		}
	}
}

// MARK: - Sidebar status bar

/// One-line sync readout, sized to sit under the sidebar's logo and copyright line. Tapping it opens the
/// sync activity popup.
struct CloudKitSyncStatusBar: View {
	@State private var showingActivity = false

	private var state: CloudKitSyncState { .shared }

	private var lastSync: Date? {
		[state.lastExportSuccess, state.lastImportSuccess].compactMap { $0 }.max()
	}

	private var symbol: String {
		if state.isThrottled { return "icloud.slash" }
		if state.lastErrorSummary != nil && state.inFlight.isEmpty { return "exclamationmark.icloud" }
		if !state.inFlight.isEmpty { return "arrow.triangle.2.circlepath.icloud" }
		return "checkmark.icloud"
	}

	private var tint: Color {
		if state.isThrottled || (state.lastErrorSummary != nil && state.inFlight.isEmpty) { return .orange }
		if !state.inFlight.isEmpty { return .accentColor }
		return .secondary
	}

	var body: some View {
		Button { showingActivity = true } label: {
			HStack(spacing: 6) {
				Image(systemName: symbol)
					.foregroundStyle(tint)
				Text(state.headline)
					.lineLimit(1)
				Spacer(minLength: 4)
				if let lastSync {
					Text(lastSync, format: .dateTime.hour().minute())
						.monospacedDigit()
				}
			}
			.font(.caption2)
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .center)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.sheet(isPresented: $showingActivity) { SyncActivitySheet() }
		.accessibilityLabel("iCloud sync: \(state.headline)")
		.accessibilityHint("Opens sync activity")
	}
}

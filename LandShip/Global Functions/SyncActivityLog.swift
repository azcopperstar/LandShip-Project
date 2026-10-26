//
//  SyncActivityLog.swift
//  LandShip
//
//  Persistent, user-visible record of CloudKit sync activity (uploads, downloads,
//  throttling, failures). Unlike InAppLogger it survives relaunches, so a flaky sync
//  can be reviewed after the fact. Shown in the Settings form; fed by CloudKitSyncMonitor.
//

import Foundation
import Observation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SyncActivityEntry: Codable, Identifiable, Equatable {
	enum Kind: String, Codable {
		case success, failure, throttled, deferred
	}

	var id = UUID()
	var date: Date
	var kind: Kind
	/// "Upload", "Download" or "Setup".
	var operation: String
	var message: String
}

@MainActor
@Observable
final class SyncActivityLog {
	static let shared = SyncActivityLog()

	/// Newest first.
	private(set) var entries: [SyncActivityEntry] = []

	/// Enough history to cover several sessions without letting the file grow unbounded.
	private static let maxEntries = 200

	private static var fileURL: URL? {
		try? FileManager.default.url(
			for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
		).appendingPathComponent("cloudkit-activity-log.json")
	}

	private init() {
		if let url = Self.fileURL,
		   let data = try? Data(contentsOf: url),
		   let saved = try? JSONDecoder().decode([SyncActivityEntry].self, from: data) {
			entries = saved
		}
	}

	func record(_ kind: SyncActivityEntry.Kind, operation: String, message: String, at date: Date = Date()) {
		entries.insert(SyncActivityEntry(date: date, kind: kind, operation: operation, message: message), at: 0)
		if entries.count > Self.maxEntries {
			entries.removeLast(entries.count - Self.maxEntries)
		}
		persist()
	}

	func clear() {
		entries.removeAll()
		persist()
	}

	/// Plain text, oldest first, for pasting into an email or bug report.
	var exportText: String {
		entries.reversed().map { entry in
			"\(entry.date.formatted(date: .abbreviated, time: .standard)) [\(entry.operation)] \(entry.kind.rawValue): \(entry.message)"
		}.joined(separator: "\n")
	}

	private func persist() {
		guard let url = Self.fileURL, let data = try? JSONEncoder().encode(entries) else { return }
		try? data.write(to: url, options: .atomic)
	}
}

// MARK: - Activity popup

/// Sheet opened from the sidebar status line: current sync state plus a scrollable
/// history of recent uploads, downloads and problems.
struct SyncActivitySheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@State private var showingClearConfirmation = false

	private var log: SyncActivityLog { .shared }
	private var state: CloudKitSyncState { .shared }

	var body: some View {
		NavigationStack {
			List {
				Section("Status") {
					LabeledContent("State", value: state.headline)
					if state.isThrottled, let until = state.throttledUntil {
						LabeledContent("Resumes") { Text(until, style: .relative) }
					}
					if let summary = state.lastErrorSummary {
						Text(summary)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}

				Section("Local Time") {
					TimelineView(.periodic(from: .now, by: 1)) { context in
						Text(context.date, format: .dateTime.hour().minute().second())
							.font(.title3.monospacedDigit())
					}
				}

				Section {
					if log.entries.isEmpty {
						Text("No sync activity recorded yet.")
							.foregroundStyle(.secondary)
					} else {
						ForEach(log.entries) { entry in
							row(entry)
						}
					}
				} header: {
					Text("Recent Activity")
				} footer: {
					Text("Newest first. Paused or deferred syncs retry automatically.")
				}
			}
			.navigationTitle("iCloud Sync")
			#if os(macOS)
			.frame(width: 520, height: 560)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") { dismiss() }
				}
#if !os(macOS)
				ToolbarItemGroup(placement: .primaryAction) {
					actionButtons
				}
#endif
			}
#if os(macOS)
			// Sheet toolbars on macOS drop trailing items, so the actions live in a
			// visible bar along the bottom of the popup instead.
			.safeAreaInset(edge: .bottom, spacing: 0) {
				VStack(spacing: 0) {
					Divider()
					HStack(spacing: 16) {
						actionButtons
						Spacer()
					}
					.labelStyle(.titleAndIcon)
					.padding(.horizontal)
					.padding(.vertical, 8)
				}
				.background(.bar)
			}
#endif
			.confirmationDialog("Clear sync log?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
				Button("Clear Log", role: .destructive) { log.clear() }
				Button("Cancel", role: .cancel) {}
			}
		}
		#if !os(macOS)
		.presentationDetents([.medium, .large])
		#endif
	}

	private func row(_ entry: SyncActivityEntry) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 8) {
			Image(systemName: symbol(for: entry.kind))
				.foregroundStyle(tint(for: entry.kind))
				.frame(width: 18)
			VStack(alignment: .leading, spacing: 2) {
				Text("\(entry.operation) — \(entry.message)")
					.font(.callout)
				HStack(spacing: 6) {
					Text(entry.date, format: .dateTime.month().day().hour().minute().second())
					Text("·")
					// Ticks each second so the age stays current while the popup is open.
					TimelineView(.periodic(from: .now, by: 1)) { context in
						Text(Self.ageText(since: entry.date, now: context.date))
							.monospacedDigit()
					}
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			}
		}
	}

	/// Copy / Email / Clear — in the toolbar on iOS, in a bottom bar on macOS.
	@ViewBuilder
	private var actionButtons: some View {
		Button {
			copyToPasteboard(log.exportText)
		} label: {
			Label("Copy Log", systemImage: "doc.on.doc")
		}
		.disabled(log.entries.isEmpty)
		Button {
			emailLog()
		} label: {
			Label("Email Developer", systemImage: "envelope")
		}
		Button(role: .destructive) {
			showingClearConfirmation = true
		} label: {
			Label("Clear Log", systemImage: "trash")
		}
		.disabled(log.entries.isEmpty)
	}

	/// "12s ago", "4m 05s ago", "2h 14m ago", "3d 4h ago".
	private static func ageText(since date: Date, now: Date) -> String {
		let seconds = max(0, Int(now.timeIntervalSince(date)))
		switch seconds {
			case ..<60: return "\(seconds)s ago"
			case ..<3600: return "\(seconds / 60)m \(String(format: "%02d", seconds % 60))s ago"
			case ..<86400: return "\(seconds / 3600)h \((seconds % 3600) / 60)m ago"
			default: return "\(seconds / 86400)d \((seconds % 86400) / 3600)h ago"
		}
	}

	private func symbol(for kind: SyncActivityEntry.Kind) -> String {
		switch kind {
			case .success: return "checkmark.circle.fill"
			case .failure: return "xmark.octagon.fill"
			case .throttled: return "hourglass"
			case .deferred: return "wifi.slash"
		}
	}

	private func tint(for kind: SyncActivityEntry.Kind) -> Color {
		switch kind {
			case .success: return .green
			case .failure: return .red
			case .throttled, .deferred: return .orange
		}
	}

	/// Same flow as Debug Tools: the full log goes on the clipboard (too long for a mailto
	/// URL) and the most recent entries are included inline for context.
	private func emailLog() {
		copyToPasteboard(log.exportText)
		let recent = log.exportText
			.split(separator: "\n", omittingEmptySubsequences: true)
			.suffix(8)
			.map { String($0.prefix(160)) }
			.joined(separator: "\n")
		let body = """
		The full iCloud sync log has been copied to the clipboard - please paste it below.


		--
		Version: \(AppInfo.version)
		Bundle ID: \(Bundle.main.bundleIdentifier ?? "(unknown)")
		Sync state: \(state.headline)
		Last error: \(state.lastErrorSummary ?? "none")

		Most recent entries:
		\(recent)
		"""
		var allowed = CharacterSet.alphanumerics
		allowed.insert(charactersIn: "-._~")
		let subject = "iCloud sync log - \(AppInfo.displayName) \(AppInfo.version)"
		guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
			  let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed),
			  let url = URL(string: "mailto:\(FeedbackView.supportAddress)?subject=\(encodedSubject)&body=\(encodedBody)") else { return }
		openURL(url)
	}

	private func copyToPasteboard(_ text: String) {
		#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
		#else
		UIPasteboard.general.string = text
		#endif
	}
}

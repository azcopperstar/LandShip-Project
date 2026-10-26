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

// MARK: - Settings section

/// Scrollable list of recent sync activity for the Settings form.
struct SyncActivityLogSection: View {
	private var log: SyncActivityLog { .shared }

	var body: some View {
		Section {
			if log.entries.isEmpty {
				Text("No sync activity recorded yet.")
					.font(.callout)
					.foregroundStyle(.secondary)
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 6) {
						ForEach(log.entries) { entry in
							row(entry)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.frame(height: 220)

				HStack {
					Button {
						copyToPasteboard(log.exportText)
					} label: {
						Label("Copy", systemImage: "doc.on.doc")
					}
					Spacer()
					Button(role: .destructive) {
						log.clear()
					} label: {
						Label("Clear", systemImage: "trash")
					}
				}
				.buttonStyle(.borderless)
			}
		} header: {
			Text("iCloud Sync Activity")
		} footer: {
			Text("The most recent \(200) uploads, downloads and problems, newest first. Retries after a pause happen automatically.")
		}
	}

	private func row(_ entry: SyncActivityEntry) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Image(systemName: symbol(for: entry.kind))
				.foregroundStyle(tint(for: entry.kind))
				.frame(width: 16)
			VStack(alignment: .leading, spacing: 1) {
				Text("\(entry.operation) — \(entry.message)")
					.font(.caption)
					.fixedSize(horizontal: false, vertical: true)
				Text(entry.date, format: .dateTime.month().day().hour().minute().second())
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
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

	private func copyToPasteboard(_ text: String) {
		#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
		#else
		UIPasteboard.general.string = text
		#endif
	}
}

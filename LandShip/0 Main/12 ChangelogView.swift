//
//  ChangelogView.swift
//  LandShip
//
//  Shared parser and renderer for the bundled changelog.md file. Used by both
//  the startup "What's New" sheet (LandShipApp.swift) and the in-app Help
//  document, so there is a single source of truth for how the changelog is
//  read and displayed.
//

import SwiftUI

/// A single parsed version entry from the bundled changelog.md file.
struct ChangelogVersionBlock: Identifiable {
	let id = UUID()
	let label: String
	let date: String
	let added: [String]
	let fixed: [String]
	let changed: [String]
	let notes: [String]
}

/// Parses the bundled `changelog.md` file into structured version blocks.
enum ChangelogParser {
	static func parseBundledChangelog() -> [ChangelogVersionBlock] {
		guard let url = Bundle.main.url(forResource: "changelog", withExtension: "md"),
			  let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }

		let normalized = raw
			.replacingOccurrences(of: "\r\n", with: "\n")
			.replacingOccurrences(of: "\r", with: "\n")

		var result: [ChangelogVersionBlock] = []
		var label = "", date = ""
		var added: [String] = [], fixed: [String] = [], changed: [String] = [], notes: [String] = []
		var currentSection = ""

		func flush() {
			guard !label.isEmpty else { return }
			result.append(ChangelogVersionBlock(label: label, date: date,
											   added: added, fixed: fixed,
											   changed: changed, notes: notes))
			label = ""; date = ""; added = []; fixed = []; changed = []; notes = []; currentSection = ""
		}

		for rawLine in normalized.components(separatedBy: "\n") {
			let line = rawLine.trimmingCharacters(in: .whitespaces)
			if line.hasPrefix("---") { flush(); continue }
			if line.hasPrefix("Version:") {
				flush()
				let rest = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
				let parts = rest.components(separatedBy: " - ")
				label = (parts.first ?? rest).trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
				date  = parts.count > 1 ? parts[1] : ""
				continue
			}
			switch line {
			case "ADDED":   currentSection = "added";   continue
			case "FIXED":   currentSection = "fixed";   continue
			case "CHANGED": currentSection = "changed"; continue
			case "NOTES":   currentSection = "notes";   continue
			default: break
			}
			guard line.hasPrefix("- ") else { continue }
			let item = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
			guard !item.isEmpty && item != "-" else { continue }
			switch currentSection {
			case "added":   added.append(item)
			case "fixed":   fixed.append(item)
			case "changed": changed.append(item)
			case "notes":   notes.append(item)
			default: break
			}
		}
		flush()
		return result
	}
}

/// Reusable, live-updating view of the app's changelog. Re-parses `changelog.md`
/// from the bundle each time it appears, so any edit to that file is reflected
/// here automatically — no other code needs to change to keep this current.
struct ChangelogList: View {
	/// Limits how many of the most recent version blocks are shown. `nil` shows the full history.
	var maxVersions: Int? = nil

	@State private var sections: [ChangelogVersionBlock] = []

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			if sections.isEmpty {
				Text("No release notes available.")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				ForEach(displayedSections) { section in
					versionCard(section)
				}
			}
		}
		.onAppear(perform: refresh)
	}

	private var displayedSections: [ChangelogVersionBlock] {
		guard let maxVersions else { return sections }
		return Array(sections.prefix(maxVersions))
	}

	private func refresh() {
		sections = ChangelogParser.parseBundledChangelog()
	}

	@ViewBuilder private func versionCard(_ v: ChangelogVersionBlock) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .firstTextBaseline) {
				Text("Version \(v.label)")
					.font(.subheadline.bold())
				Spacer()
				if !v.date.isEmpty {
					Text(v.date)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}
			}
			if !v.added.isEmpty   { itemGroup("Added",   items: v.added,   color: .green)  }
			if !v.fixed.isEmpty   { itemGroup("Fixed",   items: v.fixed,   color: .orange) }
			if !v.changed.isEmpty { itemGroup("Changed", items: v.changed, color: .blue)   }
			if !v.notes.isEmpty   { itemGroup("Notes",   items: v.notes,   color: .secondary) }
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
	}

	@ViewBuilder private func itemGroup(_ label: String, items: [String], color: Color) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Divider()
			Text(label.uppercased())
				.font(.caption2.bold())
				.foregroundStyle(color)
			ForEach(items, id: \.self) { item in
				HStack(alignment: .top, spacing: 6) {
					Circle()
						.fill(color.opacity(0.5))
						.frame(width: 5, height: 5)
						.padding(.top, 5)
					Group {
						if let attr = try? AttributedString(markdown: item,
							options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
							Text(attr)
						} else {
							Text(item)
						}
					}
					.font(.caption)
					.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}
}

/// Full-screen "What's New" presentation of the changelog, used both for the
/// automatic once-per-version sheet at launch and for the on-demand
/// "What's New" item in the sidebar's Resources section.
struct ChangelogSheet: View {
	var onDismiss: () -> Void

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					headerCard
					ChangelogList()
				}
				.padding()
			}
			.navigationTitle("What's New")
			.toolbar {
#if os(macOS)
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { onDismiss() }
						.keyboardShortcut("w", modifiers: .command)
						.keyboardShortcut(.cancelAction)
				}
#else
				ToolbarItem(placement: .primaryAction) {
					Button("Done") { onDismiss() }
				}
#endif
			}
		}
	}

	private var headerCard: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("VehicleTrax Release Notes")
				.font(.headline)
			HStack(spacing: 4) {
				Text("Suggestions & feedback:")
					.font(.caption)
					.foregroundStyle(.secondary)
				Link("info@aeronauticaltrax.com",
					 destination: URL(string: "mailto:info@aeronauticaltrax.com")!)
					.font(.caption)
			}
		}
		.padding()
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
	}
}

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

/// A run of bullets sharing one "## Section" heading inside an ADDED/FIXED/CHANGED/NOTES
/// block. `title` is empty for bullets written without a heading above them.
struct ChangelogItemGroup: Identifiable {
	let id = UUID()
	let title: String
	let items: [String]
}

/// A single parsed version entry from the bundled changelog.md file.
struct ChangelogVersionBlock: Identifiable {
	let id = UUID()
	let label: String
	let date: String
	let added: [ChangelogItemGroup]
	let fixed: [ChangelogItemGroup]
	let changed: [ChangelogItemGroup]
	let notes: [ChangelogItemGroup]
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
		var added: [ChangelogItemGroup] = [], fixed: [ChangelogItemGroup] = [],
			changed: [ChangelogItemGroup] = [], notes: [ChangelogItemGroup] = []
		var currentSection = ""
		var groupTitle = ""
		var groupItems: [String] = []

		/// Files the bullets gathered since the last "## Section" heading into the
		/// block being read. Must run before `currentSection` changes.
		func flushGroup() {
			defer { groupTitle = ""; groupItems = [] }
			guard !groupItems.isEmpty else { return }
			let group = ChangelogItemGroup(title: groupTitle, items: groupItems)
			switch currentSection {
			case "added":   added.append(group)
			case "fixed":   fixed.append(group)
			case "changed": changed.append(group)
			case "notes":   notes.append(group)
			default: break
			}
		}

		func flush() {
			flushGroup()
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
			case "ADDED":   flushGroup(); currentSection = "added";   continue
			case "FIXED":   flushGroup(); currentSection = "fixed";   continue
			case "CHANGED": flushGroup(); currentSection = "changed"; continue
			case "NOTES":   flushGroup(); currentSection = "notes";   continue
			default: break
			}
			if line.hasPrefix("## ") {
				flushGroup()
				groupTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
				continue
			}
			guard line.hasPrefix("- ") else { continue }
			let item = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
			guard !item.isEmpty && item != "-" else { continue }
			groupItems.append(item)
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
			if !v.added.isEmpty   { itemGroup("Added",   groups: v.added,   color: .green)  }
			if !v.fixed.isEmpty   { itemGroup("Fixed",   groups: v.fixed,   color: .orange) }
			if !v.changed.isEmpty { itemGroup("Changed", groups: v.changed, color: .blue)   }
			if !v.notes.isEmpty   { itemGroup("Notes",   groups: v.notes,   color: .secondary) }
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
	}

	@ViewBuilder private func itemGroup(_ label: String, groups: [ChangelogItemGroup], color: Color) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Divider()
			Text(label.uppercased())
				.font(.caption2.bold())
				.foregroundStyle(color)
			ForEach(groups) { group in
				if !group.title.isEmpty {
					// Faint bar tinted to the block's own colour, so the affected area
					// stands out from the bullets without competing with the ADDED/FIXED heading.
					Text(group.title)
						.font(.caption.bold())
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.vertical, 3)
						.padding(.horizontal, 6)
						.background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
						.padding(.top, 5)
						.accessibilityAddTraits(.isHeader)
				}
				ForEach(group.items, id: \.self) { item in
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

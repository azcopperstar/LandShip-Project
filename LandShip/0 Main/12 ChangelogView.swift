//
//  ChangelogView.swift
//  LandShip
//
//  Shared parser and renderer for the bundled per-vertical changelog file
//  (changelog.md / changelog-aero.md / changelog-marine.md — see
//  ChangelogParser.bundledResourceName). Used by both the startup "What's New"
//  sheet (LandShipApp.swift) and the in-app Help document, so there is a single
//  source of truth for how the changelog is read and displayed.
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

/// Parses the bundled changelog file into structured version blocks. Each vertical
/// ships its own history — VehicleTrax kept its original "changelog" filename, and
/// AeroTrax/NauticalTrax get their own files — so a shared codebase change doesn't
/// show up as release notes in a product that never shipped it.
enum ChangelogParser {
	private static var bundledResourceName: String {
		switch Vertical.current.id {
			case .land: return "changelog"
			case .aviation: return "changelog-aero"
			case .marine: return "changelog-marine"
		}
	}

	static func parseBundledChangelog() -> [ChangelogVersionBlock] {
		guard let url = Bundle.main.url(forResource: bundledResourceName, withExtension: "md"),
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
					VersionCardView(version: section)
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

}

/// One version's card: header, notes callout, change-count chips, a quick "at a
/// glance" list of the areas touched, and the full Added/Fixed/Changed text tucked
/// behind a disclosure — so scanning the whole history stays short, and the detail
/// is one tap away instead of always taking up space.
private struct VersionCardView: View {
	let version: ChangelogVersionBlock

	@State private var isExpanded = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .firstTextBaseline) {
				Text("Version \(version.label)")
					.font(.subheadline.bold())
				Spacer()
				if !version.date.isEmpty {
					Text(version.date)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}
			}
			if !version.notes.isEmpty { notesCallout }
			changeTally
			if !touchedAreas.isEmpty { areasQuickList }
			if hasDetails {
				DisclosureGroup(isExpanded: $isExpanded) {
					VStack(alignment: .leading, spacing: 4) {
						if !version.added.isEmpty   { itemGroup("Added",   groups: version.added,   color: .green)  }
						if !version.fixed.isEmpty   { itemGroup("Fixed",   groups: version.fixed,   color: .orange) }
						if !version.changed.isEmpty { itemGroup("Changed", groups: version.changed, color: .blue)   }
					}
					.padding(.top, 4)
				} label: {
					Text(isExpanded ? "Hide full details" : "Show full details")
						.font(.caption.bold())
				}
			}
		}
		.padding()
		.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
	}

	private var hasDetails: Bool {
		!version.added.isEmpty || !version.fixed.isEmpty || !version.changed.isEmpty
	}

	/// Distinct "## Area" headings touched by this version, in first-seen order,
	/// across Added/Fixed/Changed alike — these are already short and curated,
	/// so they double as the release's quick-glance summary without any new
	/// authoring format in changelog.md.
	private var touchedAreas: [String] {
		var seen = Set<String>()
		var result: [String] = []
		for group in version.added + version.fixed + version.changed {
			guard !group.title.isEmpty, !seen.contains(group.title) else { continue }
			seen.insert(group.title)
			result.append(group.title)
		}
		return result
	}

	/// Small capsule chips tallying the version's entries ("Added: 10 · Fixed: 5 …"),
	/// shown below the notes so the size of a release can be taken in at a glance.
	/// Each chip wears its section's color. Versions with no entries show nothing.
	@ViewBuilder private var changeTally: some View {
		let counts: [(label: String, count: Int, color: Color)] = [
			("Added",   version.added.reduce(0)   { $0 + $1.items.count }, .green),
			("Fixed",   version.fixed.reduce(0)   { $0 + $1.items.count }, .orange),
			("Changed", version.changed.reduce(0) { $0 + $1.items.count }, .blue)
		].filter { $0.1 > 0 }
		if !counts.isEmpty {
			HStack(spacing: 6) {
				ForEach(counts, id: \.label) { entry in
					HStack(spacing: 3) {
						Text(entry.label)
							.font(.caption2)
						Text("\(entry.count)")
							.font(.caption2.bold())
							.monospacedDigit()
					}
					.padding(.vertical, 3)
					.padding(.horizontal, 8)
					.foregroundStyle(entry.color)
					.background(entry.color.opacity(0.15), in: Capsule())
				}
			}
			.accessibilityElement(children: .combine)
		}
	}

	/// Notes lead the version card inside a tinted callout so release-critical
	/// information is read before the Added/Fixed/Changed lists.
	@ViewBuilder private var notesCallout: some View {
		VStack(alignment: .leading, spacing: 4) {
			Label("NOTES", systemImage: "exclamationmark.circle.fill")
				.font(.caption2.bold())
				.foregroundStyle(.yellow)
			ForEach(version.notes) { group in
				if !group.title.isEmpty {
					Text(group.title)
						.font(.caption.bold())
						.accessibilityAddTraits(.isHeader)
				}
				ForEach(group.items, id: \.self) { item in
					HStack(alignment: .top, spacing: 6) {
						Circle()
							.fill(.yellow.opacity(0.7))
							.frame(width: 5, height: 5)
							.padding(.top, 5)
						markdownText(item)
							.font(.caption.weight(.medium))
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
		.padding(8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
		.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.yellow.opacity(0.35)))
	}

	/// Quick-glance box listing just the areas this version touched (e.g. "Dashboard",
	/// "Fuel Log"), with a 5-word-max summary of each change indented underneath —
	/// so the gist of a release reads in seconds; the full bullet text lives behind
	/// "Show full details" below.
	private var areasQuickList: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 4) {
				Label("AT A GLANCE", systemImage: "list.bullet.rectangle.portrait.fill")
					.font(.caption2.bold())
					.foregroundStyle(.indigo)
				Text("— tap Show full details below for more")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			ForEach(touchedAreas, id: \.self) { area in
				VStack(alignment: .leading, spacing: 2) {
					HStack(alignment: .top, spacing: 6) {
						Circle()
							.fill(.indigo.opacity(0.5))
							.frame(width: 5, height: 5)
							.padding(.top, 5)
						Text(area)
							.font(.caption.weight(.medium))
					}
					ForEach(Array(shortSummaries(for: area).enumerated()), id: \.offset) { _, summary in
						Text("– \(summary)")
							.font(.caption2)
							.foregroundStyle(.secondary)
							.padding(.leading, 16)
					}
				}
			}
		}
		.padding(8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
		.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.indigo.opacity(0.25)))
	}

	/// Every item filed under the given "## Area" heading (across Added/Fixed/Changed,
	/// in that order), each reduced to its quick-glance summary.
	private func shortSummaries(for area: String) -> [String] {
		(version.added + version.fixed + version.changed)
			.filter { $0.title == area }
			.flatMap { $0.items }
			.map { quickSummary($0) }
	}

	/// The quick-glance form of one bullet. The changelog authoring convention (from
	/// build 92 onward) is to write bullets as "Lead-in phrase: rest of the detail" —
	/// everything before the first ":" is the intended summary, so that's used as-is
	/// when present. Older bullets written without a colon fall back to the previous
	/// auto-truncation heuristic.
	private func quickSummary(_ text: String) -> String {
		let cleaned = text.replacingOccurrences(of: "**", with: "")
		if let colonIndex = cleaned.firstIndex(of: ":") {
			let head = String(cleaned[cleaned.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
			let tail = cleaned[cleaned.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
			return tail.isEmpty || head.isEmpty ? (head.isEmpty ? tail : head) : head + "…"
		}
		return shortSummary(cleaned, maxWords: 5)
	}

	/// Trims a bullet down to a short, clean phrase: drops any parenthetical aside,
	/// caps the result at `maxWords`, and then trims trailing connector words ("in",
	/// "the", "to"…) a hard word-count cut can land on — so "New customization sheet
	/// (slider icon in the toolbar) lets…" reads as "New customization sheet…"
	/// instead of "New customization sheet (slider icon…". Used only as a fallback
	/// for bullets with no ":" lead-in (see `quickSummary`).
	private func shortSummary(_ text: String, maxWords: Int) -> String {
		var cleaned = text.replacingOccurrences(of: "**", with: "")
		var wasTruncated = false

		if let parenIndex = cleaned.firstIndex(of: "(") {
			cleaned = String(cleaned[cleaned.startIndex..<parenIndex])
			wasTruncated = true
		}

		var words = cleaned.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
		if words.count > maxWords {
			words = Array(words.prefix(maxWords))
			wasTruncated = true
		}

		let stopWords: Set<String> = ["the", "a", "an", "in", "of", "to", "for", "on",
									   "and", "with", "at", "by", "from", "is", "are"]
		while words.count > 1, stopWords.contains(words.last!.lowercased()) {
			words.removeLast()
			wasTruncated = true
		}

		let summary = words.joined(separator: " ")
		guard wasTruncated, !summary.isEmpty else { return summary }
		return summary + "…"
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
						markdownText(item)
							.font(.caption)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
	}

	private func markdownText(_ item: String) -> Text {
		if let attr = try? AttributedString(markdown: item,
			options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
			return Text(attr)
		}
		return Text(item)
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

	/// Hero banner atop the What's New sheet — a gradient card with a glowing
	/// sparkles badge, gradient-filled title, version capsule and feedback link,
	/// so the sheet opens with a sense of occasion instead of a plain grey box.
	private var headerCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 12) {
				Image(systemName: "sparkles")
					.font(.title.bold())
					.foregroundStyle(.yellow)
					.shadow(color: .yellow.opacity(0.6), radius: 6)
				VStack(alignment: .leading, spacing: 2) {
					Text("What's New")
						.font(.title2.bold())
						.foregroundStyle(
							LinearGradient(colors: [.white, .yellow.opacity(0.85)],
										   startPoint: .leading, endPoint: .trailing)
						)
					Text("\(AppInfo.displayName) Release Notes")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.white.opacity(0.9))
				}
				Spacer()
				Text("v\(AppInfo.version)")
					.font(.caption2.bold())
					.monospacedDigit()
					.padding(.vertical, 4)
					.padding(.horizontal, 8)
					.background(.white.opacity(0.2), in: Capsule())
					.foregroundStyle(.white)
			}
			HStack(spacing: 8) {
				Text("Suggestions & feedback:")
					.font(.caption)
					.foregroundStyle(.white.opacity(0.85))
				// A Link styled as a solid white pill — Link's default tint is
				// invisible against the gradient, so the label is fully custom.
				Link(destination: URL(string: "mailto:info@aeronauticaltrax.com")!) {
					Label("info@aeronauticaltrax.com", systemImage: "envelope.fill")
						.font(.caption.bold())
						.foregroundStyle(.indigo)
						.padding(.vertical, 5)
						.padding(.horizontal, 10)
						.background(.white, in: Capsule())
				}
				.buttonStyle(.plain)
			}
		}
		.padding()
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			LinearGradient(colors: [.blue, .indigo],
						   startPoint: .topLeading, endPoint: .bottomTrailing),
			in: RoundedRectangle(cornerRadius: 12)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.strokeBorder(.white.opacity(0.2))
		)
		.shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
	}
}

#Preview("What's New") {
	ChangelogSheet(onDismiss: {})
}

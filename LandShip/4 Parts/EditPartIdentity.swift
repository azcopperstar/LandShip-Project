//
//  EditPartIdentity.swift
//  LandShip
//
//  Sheet editor for MxParts1's identity fields — part number is already on the main
//  EditParts screen; this covers serial/lot (the P/N + S/N pair that's the real unique
//  identity for a serialized rotable), nomenclature, ATA chapter, alternate/interchangeable
//  P/Ns, and supersession. Takes the part non-optional — the row always exists, so unlike
//  EditAirworthinessDirective's template there's no create fork. AeroTrax only.
//

import SwiftUI
import SwiftData

struct EditPartIdentity: View {
	let part: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var serialNumber: String
	@State private var lotNumber: String
	@State private var nomenclature: String
	@State private var ataChapter: String
	@State private var alternatePartNumbers: String
	@State private var supersededByPartNumber: String
	@State private var partClass: String

	@State private var isPresentingATAPicker = false
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(part: MxParts1) {
		self.part = part
		self._serialNumber = State(initialValue: part.serialNumber)
		self._lotNumber = State(initialValue: part.lotNumber)
		self._nomenclature = State(initialValue: part.nomenclature)
		self._ataChapter = State(initialValue: part.ataChapter)
		self._alternatePartNumbers = State(initialValue: part.alternatePartNumbers)
		self._supersededByPartNumber = State(initialValue: part.supersededByPartNumber)
		self._partClass = State(initialValue: part.partClass)
	}

	private var ataChapterDisplay: String {
		ATAChapter.all.first(where: { $0.code == ataChapter })?.displayName ?? (ataChapter.isEmpty ? "—" : ataChapter)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "IDENTITY")
						HStack{LabelDataTextview(label: "Serial Number", data: $serialNumber)}
						HStack{LabelDataTextview(label: "Lot/Batch Number", data: $lotNumber)}
						HStack{LabelDataTextview(label: "Nomenclature", data: $nomenclature)}
						HStack {
							Text("Part Class").textLabelModified()
							Picker("", selection: $partClass) {
								Text("—").tag("")
								ForEach(PartClass.allCases) { Text($0.rawValue).tag($0.rawValue) }
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "SHOP REFERENCE")
						HStack {
							Text("ATA Chapter").textLabelModified()
							Button(ataChapterDisplay) { isPresentingATAPicker = true }
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Alternate Part Numbers", data: $alternatePartNumbers)}
						Text("Comma-separated — interchangeable P/Ns and NSN for ex-military stock.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .trailing)
						HStack{LabelDataTextview(label: "Superseded By", data: $supersededByPartNumber)}
					}
				}
			}
			.navigationTitle("Part Identity")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
			}
			.sheet(isPresented: $isPresentingATAPicker) {
				ATAChapterPicker(selection: $ataChapter)
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func save() {
		part.serialNumber = serialNumber
		part.lotNumber = lotNumber
		part.nomenclature = nomenclature
		part.ataChapter = ataChapter
		part.alternatePartNumbers = alternatePartNumbers
		part.supersededByPartNumber = supersededByPartNumber
		part.partClass = partClass
		part.updatedAt = Date()
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

/// Searchable picker for ATA 100 / iSpec 2200 chapters (Verticals/ATAChapters.swift) —
/// an inline Picker with ~80 items is unusable on iPhone.
private struct ATAChapterPicker: View {
	@Binding var selection: String
	@Environment(\.dismiss) private var dismiss
	@State private var query = ""

	private var filtered: [ATAChapter] {
		query.isEmpty ? ATAChapter.all : ATAChapter.all.filter {
			$0.title.localizedCaseInsensitiveContains(query) || $0.code.localizedCaseInsensitiveContains(query)
		}
	}

	var body: some View {
		NavigationStack {
			List {
				Button("— None —") { selection = ""; dismiss() }
				ForEach(ATAChapter.Group.allCases, id: \.self) { group in
					let chapters = filtered.filter { $0.group == group }
					if !chapters.isEmpty {
						Section(group.rawValue) {
							ForEach(chapters) { chapter in
								Button {
									selection = chapter.code
									dismiss()
								} label: {
									HStack {
										Text(chapter.displayName)
										if chapter.code == selection {
											Spacer()
											Image(systemName: "checkmark")
										}
									}
								}
							}
						}
					}
				}
			}
			.searchable(text: $query)
			.navigationTitle("ATA Chapter")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
			}
		}
	}
}

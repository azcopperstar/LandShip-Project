//
//  EditPartLife.swift
//  LandShip
//
//  Sheet editor for MxParts1's declared limit and carry-in time, plus condition/status.
//  Carry-in TSN/CSN/TSO/CSO/TSR are used only until a PartInstallation segment exists for
//  this part (see PartTimeMath.swift) — once one does, the Installation card on EditParts
//  takes over and these become historical starting points, not live numbers. AeroTrax only.
//

import SwiftUI
import SwiftData

struct EditPartLife: View {
	let part: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var limitType: String
	@State private var limitHours: Float
	@State private var limitCycles: Int
	@State private var limitCalendarMonths: Int
	@State private var limitTimeBase: String
	@State private var maintenanceProgram: String
	@State private var carryInTSN: Float
	@State private var carryInCSN: Int
	@State private var carryInTSO: Float
	@State private var carryInCSO: Int
	@State private var carryInTSR: Float
	@State private var conditionCode: String
	@State private var hasShelfLife: Bool
	@State private var shelfLifeExpiry: Date
	@State private var hasCureDate: Bool
	@State private var cureDate: Date
	@State private var quarantineNotes: String
	@State private var storageRequirements: String
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(part: MxParts1) {
		self.part = part
		self._limitType = State(initialValue: part.limitType)
		self._limitHours = State(initialValue: part.limitHours)
		self._limitCycles = State(initialValue: part.limitCycles)
		self._limitCalendarMonths = State(initialValue: part.limitCalendarMonths)
		self._limitTimeBase = State(initialValue: part.limitTimeBase)
		self._maintenanceProgram = State(initialValue: part.maintenanceProgram)
		self._carryInTSN = State(initialValue: part.carryInTSN)
		self._carryInCSN = State(initialValue: part.carryInCSN)
		self._carryInTSO = State(initialValue: part.carryInTSO)
		self._carryInCSO = State(initialValue: part.carryInCSO)
		self._carryInTSR = State(initialValue: part.carryInTSR)
		self._conditionCode = State(initialValue: part.conditionCode)
		self._hasShelfLife = State(initialValue: part.shelfLifeExpiry != nil)
		self._shelfLifeExpiry = State(initialValue: part.shelfLifeExpiry ?? Date())
		self._hasCureDate = State(initialValue: part.cureDate != nil)
		self._cureDate = State(initialValue: part.cureDate ?? Date())
		self._quarantineNotes = State(initialValue: part.quarantineNotes)
		self._storageRequirements = State(initialValue: part.storageRequirements)
	}

	private var selectedLimitType: PartLimitType? { PartLimitType(rawValue: limitType) }

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "TIME & LIFE LIMIT")
						HStack {
							Text("Limit Type").textLabelModified()
							Picker("", selection: $limitType) {
								Text("—").tag("")
								ForEach(PartLimitType.allCases) { type in
									Text(type.rawValue).tag(type.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if let type = selectedLimitType, type != .none {
							Text(type.isRegulatoryLimit
								? "A hard discard point — the part comes off and is destroyed, no extension."
								: "A manufacturer recommendation — mandatory under Part 135/121, advisory under Part 91.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
							HStack{LabelDataTextview_Numberpad_Float(label: "Limit (Hours)", data: $limitHours)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Limit (Cycles)", data: $limitCycles)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Limit (Calendar Months)", data: $limitCalendarMonths)}
							HStack {
								Text("Limit Time Base").textLabelModified()
								Picker("", selection: $limitTimeBase) {
									Text("—").tag("")
									ForEach(PartTimeBase.allCases) { base in
										Text(base.rawValue).tag(base.rawValue)
									}
								}
								.pickerStyle(.automatic)
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
						}
						HStack {
							Text("Maintenance Program").textLabelModified()
							Picker("", selection: $maintenanceProgram) {
								Text("—").tag("")
								Text("Hard Time").tag("Hard Time")
								Text("On-Condition").tag("On-Condition")
								Text("Condition Monitoring").tag("Condition Monitoring")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "CARRY-IN TIME")
						Text("Used only until an Installation record exists for this part — see the Installation card on the main Part screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack{LabelDataTextview_Numberpad_Float(label: "TSN (Time Since New)", data: $carryInTSN)}
						HStack{LabelDataTextview_Numberpad_Int(label: "CSN (Cycles Since New)", data: $carryInCSN)}
						HStack{LabelDataTextview_Numberpad_Float(label: "TSO (Time Since Overhaul)", data: $carryInTSO)}
						HStack{LabelDataTextview_Numberpad_Int(label: "CSO (Cycles Since Overhaul)", data: $carryInCSO)}
						HStack{LabelDataTextview_Numberpad_Float(label: "TSR (Time Since Repair)", data: $carryInTSR)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "CONDITION & STATUS")
						HStack {
							Text("Condition").textLabelModified()
							Picker("", selection: $conditionCode) {
								Text("—").tag("")
								ForEach(PartConditionCode.allCases) { code in
									Text(code.rawValue).tag(code.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataToggle(label: "Has Shelf Life", data: $hasShelfLife)}
						if hasShelfLife {
							HStack{LabelDataPicker_Date(label: "Shelf Life Expiry", data: $shelfLifeExpiry)}
						}
						HStack{LabelDataToggle(label: "Has Cure Date", data: $hasCureDate)}
						if hasCureDate {
							HStack{LabelDataPicker_Date(label: "Cure Date", data: $cureDate)}
						}
						HStack{LabelDataTextview(label: "Storage Requirements", data: $storageRequirements)}
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "QUARANTINE / HOLD NOTES", prompt: "Enter notes...", data: $quarantineNotes)
				}
			}
			.navigationTitle("Life & Condition")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func save() {
		part.limitType = limitType
		part.limitHours = limitHours
		part.limitCycles = limitCycles
		part.limitCalendarMonths = limitCalendarMonths
		part.limitTimeBase = limitTimeBase
		part.maintenanceProgram = maintenanceProgram
		part.carryInTSN = carryInTSN
		part.carryInCSN = carryInCSN
		part.carryInTSO = carryInTSO
		part.carryInCSO = carryInCSO
		part.carryInTSR = carryInTSR
		part.conditionCode = conditionCode
		part.shelfLifeExpiry = hasShelfLife ? shelfLifeExpiry : nil
		part.cureDate = hasCureDate ? cureDate : nil
		part.quarantineNotes = quarantineNotes
		part.storageRequirements = storageRequirements
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

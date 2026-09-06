//
//  EditHaulOutRecord.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single HaulOutRecord.
//  Presented from EditVehicle whenever the user taps a haul-out row or the Add button.
//  NauticalTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditHaulOutRecord: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let record: HaulOutRecord?

	@State private var haulOutDate: Date = Date()
	@State private var yardName: String = ""
	@State private var bottomPaintType: String = ""
	@State private var bottomPaintApplied: Bool = false
	@State private var zincsReplaced: Bool = false
	@State private var runningGearServiced: Bool = false
	@State private var cost: Float = 0
	@State private var nextDueDate: Date = Date()
	@State private var notes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, record: HaulOutRecord? = nil) {
		self.vehicleId = vehicleId
		self.record = record
		self._haulOutDate = State(initialValue: record?.haulOutDate ?? Date())
		self._yardName = State(initialValue: record?.yardName ?? "")
		self._bottomPaintType = State(initialValue: record?.bottomPaintType ?? "")
		self._bottomPaintApplied = State(initialValue: record?.bottomPaintApplied ?? false)
		self._zincsReplaced = State(initialValue: record?.zincsReplaced ?? false)
		self._runningGearServiced = State(initialValue: record?.runningGearServiced ?? false)
		self._cost = State(initialValue: record?.cost ?? 0)
		self._nextDueDate = State(initialValue: record?.nextDueDate ?? Date())
		self._notes = State(initialValue: record?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "HAUL-OUT DETAILS")
						HStack { LabelDataPicker_Date(label: "Haul-Out Date", data: $haulOutDate) }
						HStack { LabelDataTextview(label: "Yard", data: $yardName) }
					}
				}

				CardView {
					VStack {
						SectionText(label: "BOTTOM & RUNNING GEAR")
						HStack { LabelDataTextview(label: "Bottom Paint Type", data: $bottomPaintType) }
						HStack { LabelDataToggle(label: "Bottom Paint Applied", data: $bottomPaintApplied) }
						HStack { LabelDataToggle(label: "Zincs Replaced", data: $zincsReplaced) }
						HStack { LabelDataToggle(label: "Running Gear Serviced", data: $runningGearServiced) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Cost", data: $cost) }
						HStack { LabelDataPicker_Date(label: "Next Due Date", data: $nextDueDate) }
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if record != nil {
					CardView {
						VStack {
							Button("Delete Haul-Out Record", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this haul-out record?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let r = record {
										modelContext.delete(r)
										do {
											try modelContext.save()
											dismiss()
										} catch {
											saveErrorMessage = error.localizedDescription
											showSaveError = true
										}
									} else {
										dismiss()
									}
								}
							} message: {
								Text("This action cannot be undone.")
							}
						}
					}
				}
			}
			.navigationTitle(record == nil ? "Add Haul-Out Record" : "Edit Haul-Out Record")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveRecord()
					}
					.disabled(yardName.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveRecord() {
		if let existing = record {
			existing.haulOutDate = haulOutDate
			existing.yardName = yardName
			existing.bottomPaintType = bottomPaintType
			existing.bottomPaintApplied = bottomPaintApplied
			existing.zincsReplaced = zincsReplaced
			existing.runningGearServiced = runningGearServiced
			existing.cost = cost
			existing.nextDueDate = nextDueDate
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let newRecord = HaulOutRecord(
				vehicleId: vehicleId,
				haulOutDate: haulOutDate,
				yardName: yardName,
				bottomPaintType: bottomPaintType,
				bottomPaintApplied: bottomPaintApplied,
				zincsReplaced: zincsReplaced,
				runningGearServiced: runningGearServiced,
				cost: cost,
				nextDueDate: nextDueDate,
				notes: notes
			)
			modelContext.insert(newRecord)
		}
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

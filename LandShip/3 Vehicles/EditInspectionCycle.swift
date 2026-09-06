//
//  EditInspectionCycle.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single InspectionCycle.
//  Presented from EditVehicle whenever the user taps an inspection row or the Add button.
//  AeroTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditInspectionCycle: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let inspection: InspectionCycle?

	@State private var inspectionType: String = "Annual"
	@State private var lastCompliedDate: Date = Date()
	@State private var lastCompliedHours: Float = 0
	@State private var intervalMonths: Int = 0
	@State private var intervalHours: Float = 0
	@State private var nextDueDate: Date = Date()
	@State private var nextDueHours: Float = 0
	@State private var performingShop: String = ""
	@State private var notes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, inspection: InspectionCycle? = nil) {
		self.vehicleId = vehicleId
		self.inspection = inspection
		self._inspectionType = State(initialValue: inspection?.inspectionType.isEmpty == false ? inspection!.inspectionType : "Annual")
		self._lastCompliedDate = State(initialValue: inspection?.lastCompliedDate ?? Date())
		self._lastCompliedHours = State(initialValue: inspection?.lastCompliedHours ?? 0)
		self._intervalMonths = State(initialValue: inspection?.intervalMonths ?? 0)
		self._intervalHours = State(initialValue: inspection?.intervalHours ?? 0)
		self._nextDueDate = State(initialValue: inspection?.nextDueDate ?? Date())
		self._nextDueHours = State(initialValue: inspection?.nextDueHours ?? 0)
		self._performingShop = State(initialValue: inspection?.performingShop ?? "")
		self._notes = State(initialValue: inspection?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "INSPECTION DETAILS")
						HStack {
							Text("Type")
								.textLabelModified()
							Picker("", selection: $inspectionType) {
								Text("Annual").tag("Annual")
								Text("100-Hour").tag("100-Hour")
								Text("Pitot-Static").tag("Pitot-Static")
								Text("Transponder").tag("Transponder")
								Text("ELT").tag("ELT")
								Text("Altimeter").tag("Altimeter")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack { LabelDataTextview(label: "Performing Shop", data: $performingShop) }
					}
				}

				CardView {
					VStack {
						SectionText(label: "SCHEDULE")
						HStack { LabelDataPicker_Date(label: "Last Complied Date", data: $lastCompliedDate) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Last Complied Hours", data: $lastCompliedHours) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Interval (months)", data: $intervalMonths) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Interval (hours)", data: $intervalHours) }
						HStack { LabelDataPicker_Date(label: "Next Due Date", data: $nextDueDate) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Next Due Hours", data: $nextDueHours) }
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if inspection != nil {
					CardView {
						VStack {
							Button("Delete Inspection", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this inspection?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let i = inspection {
										modelContext.delete(i)
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
			.navigationTitle(inspection == nil ? "Add Inspection" : "Edit Inspection")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveInspection()
					}
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveInspection() {
		if let existing = inspection {
			existing.inspectionType = inspectionType
			existing.lastCompliedDate = lastCompliedDate
			existing.lastCompliedHours = lastCompliedHours
			existing.intervalMonths = intervalMonths
			existing.intervalHours = intervalHours
			existing.nextDueDate = nextDueDate
			existing.nextDueHours = nextDueHours
			existing.performingShop = performingShop
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let newInspection = InspectionCycle(
				vehicleId: vehicleId,
				inspectionType: inspectionType,
				lastCompliedDate: lastCompliedDate,
				lastCompliedHours: lastCompliedHours,
				intervalMonths: intervalMonths,
				intervalHours: intervalHours,
				nextDueDate: nextDueDate,
				nextDueHours: nextDueHours,
				performingShop: performingShop,
				notes: notes
			)
			modelContext.insert(newInspection)
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

//
//  EditComponentTimes.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single ComponentTimes record (one row
//  per airframe/engine/propeller so twins are represented as separate records).
//  Presented from EditVehicle whenever the user taps a component row or the Add button.
//  AeroTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditComponentTimes: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let component: ComponentTimes?

	@State private var componentName: String = ""
	@State private var componentType: String = "Airframe"
	@State private var totalTime: Float = 0
	@State private var timeSinceOverhaul: Float = 0
	@State private var lastOverhaulDate: Date = Date()
	@State private var notes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, component: ComponentTimes? = nil) {
		self.vehicleId = vehicleId
		self.component = component
		self._componentName = State(initialValue: component?.componentName ?? "")
		self._componentType = State(initialValue: component?.componentType.isEmpty == false ? component!.componentType : "Airframe")
		self._totalTime = State(initialValue: component?.totalTime ?? 0)
		self._timeSinceOverhaul = State(initialValue: component?.timeSinceOverhaul ?? 0)
		self._lastOverhaulDate = State(initialValue: component?.lastOverhaulDate ?? Date())
		self._notes = State(initialValue: component?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "COMPONENT")
						HStack { LabelDataTextview(label: "Name", data: $componentName) }
						HStack {
							Text("Type")
								.textLabelModified()
							Picker("", selection: $componentType) {
								Text("Airframe").tag("Airframe")
								Text("Engine").tag("Engine")
								Text("Propeller").tag("Propeller")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TIMES")
						HStack { LabelDataTextview_Numberpad_Float(label: "Total Time", data: $totalTime) }
						if componentType != "Airframe" {
							HStack { LabelDataTextview_Numberpad_Float(label: "Time Since Overhaul", data: $timeSinceOverhaul) }
							HStack { LabelDataPicker_Date(label: "Last Overhaul Date", data: $lastOverhaulDate) }
						}
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if component != nil {
					CardView {
						VStack {
							Button("Delete Component", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this component record?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let c = component {
										modelContext.delete(c)
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
			.navigationTitle(component == nil ? "Add Component" : "Edit Component")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveComponent()
					}
					.disabled(componentName.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveComponent() {
		if let existing = component {
			existing.componentName = componentName
			existing.componentType = componentType
			existing.totalTime = totalTime
			existing.timeSinceOverhaul = timeSinceOverhaul
			existing.lastOverhaulDate = lastOverhaulDate
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let newComponent = ComponentTimes(
				vehicleId: vehicleId,
				componentName: componentName,
				componentType: componentType,
				totalTime: totalTime,
				timeSinceOverhaul: timeSinceOverhaul,
				lastOverhaulDate: lastOverhaulDate,
				notes: notes
			)
			modelContext.insert(newComponent)
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

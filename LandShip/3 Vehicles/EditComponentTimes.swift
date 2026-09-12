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
	@State private var typeSelection: String = "Airframe"
	@State private var customTypeText: String = ""
	@State private var allComponentTypes: [String] = ["Airframe", "Engine", "Propeller"]
	private let addNewTypeOption = "Add New Type..."
	private var componentType: String {
		typeSelection == addNewTypeOption ? customTypeText.trimmingCharacters(in: .whitespaces) : typeSelection
	}
	@State private var totalTime: Float = 0
	@State private var currentTachTime: Float = 0
	@State private var timeSinceOverhaul: Float = 0
	@State private var lastOverhaulDate: Date = Date()
	@State private var make: String = ""
	@State private var horsepower: Float = 0
	@State private var serialNumber: String = ""
	@State private var notes: String = ""

	// Opt-in derivation (see ComponentTimes model header + PartTimeMath.swift). Every
	// existing row for every existing user has derivesFromMeter == false, so this is
	// additive-in-effect, not just additive-in-schema.
	@State private var derivesFromMeter: Bool
	@State private var totalTimeAtSnapshot: Float
	@State private var snapshotMeterHours: Float
	@State private var snapshotDate: Date
	@State private var isPresentingDerivePromotion = false

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, component: ComponentTimes? = nil) {
		self.vehicleId = vehicleId
		self.component = component
		self._componentName = State(initialValue: component?.componentName ?? "")
		self._typeSelection = State(initialValue: component?.componentType.isEmpty == false ? component!.componentType : "Airframe")
		self._totalTime = State(initialValue: component?.totalTime ?? 0)
		self._currentTachTime = State(initialValue: component?.currentTachTime ?? 0)
		self._timeSinceOverhaul = State(initialValue: component?.timeSinceOverhaul ?? 0)
		self._lastOverhaulDate = State(initialValue: component?.lastOverhaulDate ?? Date())
		self._make = State(initialValue: component?.make ?? "")
		self._horsepower = State(initialValue: component?.horsepower ?? 0)
		self._serialNumber = State(initialValue: component?.serialNumber ?? "")
		self._notes = State(initialValue: component?.notes ?? "")
		self._derivesFromMeter = State(initialValue: component?.derivesFromMeter ?? false)
		self._totalTimeAtSnapshot = State(initialValue: component?.totalTimeAtSnapshot ?? 0)
		self._snapshotMeterHours = State(initialValue: component?.snapshotMeterHours ?? 0)
		self._snapshotDate = State(initialValue: component?.snapshotDate ?? Date())
	}

	private var derivedTotalTime: Float {
		let meter = Functions().loadVehicleMeter(context: modelContext, vehicleId: vehicleId)
		let (accrued, _) = PartTimeMath.accruedHours(installMeter: snapshotMeterHours, installMeterKnown: true, currentMeter: meter)
		return totalTimeAtSnapshot + accrued
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
							Picker("", selection: $typeSelection) {
								ForEach(allComponentTypes, id: \.self) { type in
									Text(type).tag(type)
								}
								Text("Add New Type...").tag(addNewTypeOption)
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if typeSelection == addNewTypeOption {
							HStack { LabelDataTextview(label: "New Type Name", data: $customTypeText) }
						}
					}
				}

				if componentType == "Engine" {
				CardView {
					VStack {
						SectionText(label: "ENGINE DETAILS")
						HStack { LabelDataTextview(label: "Make", data: $make) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Horsepower", data: $horsepower) }
						HStack { LabelDataTextview(label: "Serial Number", data: $serialNumber) }
					}
				}
				}

				CardView {
					VStack {
						SectionText(label: "TIMES")
						HStack { LabelDataToggle(label: "Track from Aircraft \(Vertical.current.hoursMeterLabel)", data: $derivesFromMeter) }
							.onChange(of: derivesFromMeter) { old, new in
								if new && !old { isPresentingDerivePromotion = true }
							}
						if derivesFromMeter {
							HStack { LabelDataText(label: componentType == "Engine" ? "Engine Hours" : "Total Time", data: "\(derivedTotalTime.formatted(.number.precision(.fractionLength(1)))) hrs") }
							Text("Last hand-entered total: \(totalTimeAtSnapshot.formatted(.number.precision(.fractionLength(1)))) h (\(Functions().formatDate_DDMMMyy(date: snapshotDate))).")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						} else {
							HStack { LabelDataTextview_Numberpad_Float(label: componentType == "Engine" ? "Engine Hours" : "Total Time", data: $totalTime) }
							Text("Total Time will follow this aircraft's \(Vertical.current.hoursMeterLabel) reading instead of being typed in, once you switch this on. Your current entered value is kept as the starting point.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
							if componentType == "Engine" {
								HStack { LabelDataTextview_Numberpad_Float(label: "Tach Time", data: $currentTachTime) }
								Text("The engine's current tach-gauge reading. Flight log saves add each flight's tach increase onto Engine Hours, so if the tach is replaced, just correct this field to the new gauge's reading — Engine Hours won't jump.")
									.font(.caption)
									.foregroundStyle(.secondary)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
						if componentType != "Airframe" {
							HStack { LabelDataTextview_Numberpad_Float(label: "Time Since Overhaul", data: $timeSinceOverhaul) }
							HStack { LabelDataPicker_Date(label: "Last Overhaul Date", data: $lastOverhaulDate) }
						}
					}
				}
				.confirmationDialog("Track from Aircraft \(Vertical.current.hoursMeterLabel)?", isPresented: $isPresentingDerivePromotion) {
					Button("Track From Meter") { promoteToMeterDerived() }
					Button("Cancel", role: .cancel) { derivesFromMeter = false }
				} message: {
					Text("Total Time will follow the aircraft's \(Vertical.current.hoursMeterLabel) reading instead of being typed in. Your current entered value (\(totalTime.formatted(.number.precision(.fractionLength(1)))) h) is kept as the starting point — nothing is lost, and this can be turned off again.")
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
					.disabled(componentName.trimmingCharacters(in: .whitespaces).isEmpty || componentType.isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
		.task {
			loadComponentTypes()
		}
	}

	private func loadComponentTypes() {
		let defaults = ["Airframe", "Engine", "Propeller"]
		let all = (try? modelContext.fetch(FetchDescriptor<ComponentTimes>())) ?? []
		let customs = Set(all.map(\.componentType)).subtracting(defaults).subtracting([""])
		allComponentTypes = defaults + customs.sorted()
		if !allComponentTypes.contains(typeSelection) {
			customTypeText = typeSelection
			typeSelection = addNewTypeOption
		}
	}

	/// One-time, non-destructive promotion: `totalTime` is copied into the snapshot, not
	/// overwritten. Reversible — turning the toggle back off just re-reveals the
	/// hand-entered field, still holding its last value.
	private func promoteToMeterDerived() {
		totalTimeAtSnapshot = totalTime
		snapshotMeterHours = Functions().loadVehicleMeter(context: modelContext, vehicleId: vehicleId).hours
		snapshotDate = Date()
	}

	private func saveComponent() {
		if let existing = component {
			existing.componentName = componentName
			existing.componentType = componentType
			existing.totalTime = totalTime
			existing.currentTachTime = currentTachTime
			existing.timeSinceOverhaul = timeSinceOverhaul
			existing.lastOverhaulDate = lastOverhaulDate
			existing.make = make
			existing.horsepower = horsepower
			existing.serialNumber = serialNumber
			existing.notes = notes
			existing.derivesFromMeter = derivesFromMeter
			existing.totalTimeAtSnapshot = totalTimeAtSnapshot
			existing.snapshotMeterHours = snapshotMeterHours
			existing.snapshotDate = snapshotDate
			existing.updatedAt = Date()
		} else {
			let newComponent = ComponentTimes(
				vehicleId: vehicleId,
				componentName: componentName,
				componentType: componentType,
				totalTime: totalTime,
				currentTachTime: currentTachTime,
				timeSinceOverhaul: timeSinceOverhaul,
				lastOverhaulDate: lastOverhaulDate,
				make: make,
				horsepower: horsepower,
				serialNumber: serialNumber,
				notes: notes,
				derivesFromMeter: derivesFromMeter,
				totalTimeAtSnapshot: totalTimeAtSnapshot,
				snapshotMeterHours: snapshotMeterHours,
				snapshotDate: snapshotDate
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

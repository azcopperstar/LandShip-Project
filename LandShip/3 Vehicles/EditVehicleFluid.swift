//
//  EditVehicleFluid.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single VehicleFluid record (one
//  row per lubricated/fluid-filled component). Presented from EditVehicle
//  whenever the user taps a fluid row or the Add button. Component name and
//  fluid type are user-definable — a Picker offers defaults plus every
//  distinct value entered across all vehicles, with an "Add New..." option
//  that reveals a free-text field.
//

import SwiftUI
import SwiftData

struct EditVehicleFluid: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let fluid: VehicleFluid?

	@State private var componentSelection: String = "Engine"
	@State private var customComponentText: String = ""
	@State private var allComponentNames: [String] = ["Engine", "Transmission", "Transfer Case", "Front Differential", "Rear Differential", "Power Steering", "Coolant System", "Brake System"]
	private let addNewComponentOption = "Add New Component..."
	private var componentName: String {
		componentSelection == addNewComponentOption ? customComponentText.trimmingCharacters(in: .whitespaces) : componentSelection
	}

	@State private var fluidTypeSelection: String = "Engine Oil"
	@State private var customFluidTypeText: String = ""
	@State private var allFluidTypes: [String] = ["Engine Oil", "Automatic Transmission Fluid (ATF)", "Manual Transmission Fluid", "Gear Oil", "Coolant / Antifreeze", "Power Steering Fluid", "Brake Fluid"]
	private let addNewFluidTypeOption = "Add New Fluid Type..."
	private var fluidType: String {
		fluidTypeSelection == addNewFluidTypeOption ? customFluidTypeText.trimmingCharacters(in: .whitespaces) : fluidTypeSelection
	}

	@State private var quantityRequired: Float = 0
	private let unitOptions = ["qt", "L", "gal", "oz", "mL"]
	@State private var quantityUnit: String = "qt"

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, fluid: VehicleFluid? = nil) {
		self.vehicleId = vehicleId
		self.fluid = fluid
		self._componentSelection = State(initialValue: fluid?.componentName.isEmpty == false ? fluid!.componentName : "Engine")
		self._fluidTypeSelection = State(initialValue: fluid?.fluidType.isEmpty == false ? fluid!.fluidType : "Engine Oil")
		self._quantityRequired = State(initialValue: fluid?.quantityRequired ?? 0)
		self._quantityUnit = State(initialValue: fluid?.quantityUnit.isEmpty == false ? fluid!.quantityUnit : "qt")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "FLUID")
						HStack {
							Text("Component")
								.textLabelModified()
							Picker("", selection: $componentSelection) {
								ForEach(allComponentNames, id: \.self) { name in
									Text(name).tag(name)
								}
								Text(addNewComponentOption).tag(addNewComponentOption)
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if componentSelection == addNewComponentOption {
							HStack { LabelDataTextview(label: "New Component Name", data: $customComponentText) }
						}
						HStack {
							Text("Fluid Type")
								.textLabelModified()
							Picker("", selection: $fluidTypeSelection) {
								ForEach(allFluidTypes, id: \.self) { type in
									Text(type).tag(type)
								}
								Text(addNewFluidTypeOption).tag(addNewFluidTypeOption)
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if fluidTypeSelection == addNewFluidTypeOption {
							HStack { LabelDataTextview(label: "New Fluid Type", data: $customFluidTypeText) }
						}
						HStack { LabelDataTextview_Numberpad_Float(label: "Quantity Required", data: $quantityRequired) }
						HStack {
							Text("Unit")
								.textLabelModified()
							Picker("", selection: $quantityUnit) {
								ForEach(unitOptions, id: \.self) { u in
									Text(u).tag(u)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				if fluid != nil {
					CardView {
						VStack {
							Button("Delete Fluid Entry", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this fluid entry?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let f = fluid {
										modelContext.delete(f)
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
			.navigationTitle(fluid == nil ? "Add Fluid" : "Edit Fluid")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveFluid()
					}
					.disabled(componentName.isEmpty || fluidType.isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
		.task {
			loadComponentNames()
			loadFluidTypes()
		}
	}

	private func loadComponentNames() {
		let defaults = ["Engine", "Transmission", "Transfer Case", "Front Differential", "Rear Differential", "Power Steering", "Coolant System", "Brake System"]
		let all = (try? modelContext.fetch(FetchDescriptor<VehicleFluid>())) ?? []
		let customs = Set(all.map(\.componentName)).subtracting(defaults).subtracting([""])
		allComponentNames = defaults + customs.sorted()
		if !allComponentNames.contains(componentSelection) {
			customComponentText = componentSelection
			componentSelection = addNewComponentOption
		}
	}

	private func loadFluidTypes() {
		let defaults = ["Engine Oil", "Automatic Transmission Fluid (ATF)", "Manual Transmission Fluid", "Gear Oil", "Coolant / Antifreeze", "Power Steering Fluid", "Brake Fluid"]
		let all = (try? modelContext.fetch(FetchDescriptor<VehicleFluid>())) ?? []
		let customs = Set(all.map(\.fluidType)).subtracting(defaults).subtracting([""])
		allFluidTypes = defaults + customs.sorted()
		if !allFluidTypes.contains(fluidTypeSelection) {
			customFluidTypeText = fluidTypeSelection
			fluidTypeSelection = addNewFluidTypeOption
		}
	}

	private func saveFluid() {
		if let existing = fluid {
			existing.componentName = componentName
			existing.fluidType = fluidType
			existing.quantityRequired = quantityRequired
			existing.quantityUnit = quantityUnit
			existing.updatedAt = Date()
		} else {
			let newFluid = VehicleFluid(
				vehicleId: vehicleId,
				componentName: componentName,
				fluidType: fluidType,
				quantityRequired: quantityRequired,
				quantityUnit: quantityUnit
			)
			modelContext.insert(newFluid)
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

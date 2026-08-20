/**
 EditParts.swift
 LandShip
 
 A SwiftUI view for viewing and editing a single `MxParts1` record (a stored part in inventory).
 
 Overview
 --------
 `EditParts` presents two primary modes:
 - Details mode (read-only): Displays the current values from the bound `MxParts1` model.
 - Edit mode: Allows the user to modify fields, select related models (vehicle, system, vendor), and attach images.
 
 Persistence
 -----------
 This view uses SwiftData via `@Environment(\.modelContext)` to persist changes. The `updateItem()` function writes the in-memory state back to `dataSet` and saves the context. Destructive actions are supported via:
 - `DeleteRecord()` which removes the model object and saves the context.
 - `makeInactive()` which flags the record as inactive and persists that change.
 
 Related Models
 --------------
 - `Vehicle8`: Used to scope parts to a particular vehicle.
 - `VehicleSystems1`: Used to scope parts to a particular system for a selected vehicle.
 - `Vendors1`: Used to represent the supplier/source of a part.
 
 UI Notes
 --------
 - Sectioned cards group related fields (General, Part Details, Part Costs, Part Source, and Graphics).
 - Model pickers are used to select related objects from the data store with optional filtering and sorting.
 - The toolbar provides Edit/Cancel/Save controls in edit mode and a Delete/Make Inactive confirmation in details mode.
 
 Previews
 --------
 The preview builds an in-memory `ModelContainer`, seeds related models (vehicle, system, vendor), and inserts a sample `MxParts1` record so both modes are representative.
 
 Maintenance
 -----------
 - Keep `updateItem()` synchronized with new properties added to `MxParts1`.
 - Consider surfacing save errors to the user with alerts where appropriate.
 - The view dismisses after destructive actions; adjust if the flow should differ.
 */

import SwiftUI
import SwiftData

/// A detail-and-edit view for a single `MxParts1` part record.
///
/// Displays a read-only summary by default and toggles into edit mode when requested.
/// Edits are staged in local `@State` and committed to the model via `updateItem()`.
///
/// - Parameters:
///   - mxParts: The `MxParts1` instance to view and edit.
///   - startEditing: If `true`, the view starts in edit mode.
struct EditParts: View {
	@State private var dataSet: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	// Access settings (units) without storing them in @State
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false
	
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vehicleId = ""
	@State private var vehicleSystem = ""
	@State private var partName = ""
	@State private var partNumber = ""
	@State private var partManufacture = ""
	@State private var partDescription = ""
	@State private var Notes = ""
	@State private var costPerUnit: Float = 0.0
	@State private var partUnit = ""
	@State private var partSource = ""
	@State private var partQuantity = 0
	@State private var partLocation = ""
	@State private var partStatus = ""
	@State private var inactive: Bool = false
//	@State private var partImage = ""
	@State private var partSupplier = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	@State private var selectedVehicle: Vehicle8?
	@State private var selectedVendor: Vendors1?

	@Query private var vehicles: [Vehicle8]
	@Query private var vendors: [Vendors1]

	/// Creates a new `EditParts` view.
	///
	/// Copies values from the provided `mxParts` into local `@State` so edits can be staged
	/// without immediately mutating the persisted model. Optionally starts in edit mode.
	///
	/// - Parameters:
	///   - mxParts: The source model to display and edit.
	///   - startEditing: If `true`, the view begins in edit mode.
	init(mxParts: MxParts1, startEditing: Bool = false) {
		self.dataSet = mxParts

		self._createdAt = State(initialValue: mxParts.createdAt)
		self._updatedAt = State(initialValue: mxParts.updatedAt)
		self._vehicleId = State(initialValue: mxParts.vehicleId)
		self._vehicleSystem = State(initialValue: mxParts.vehicleSystem)
		self._partName = State(initialValue: mxParts.partName)
		self._partNumber = State(initialValue: mxParts.partNumber)
		self._partManufacture = State(initialValue: mxParts.partManufacture)
		self._partDescription = State(initialValue: mxParts.partDescription)
		self._Notes = State(initialValue: mxParts.Notes)
		self._costPerUnit = State(initialValue: mxParts.costPerUnit)
		self._partUnit = State(initialValue: mxParts.partUnit)
		self._partSource = State(initialValue: mxParts.partSource)
		self._partQuantity = State(initialValue: mxParts.partQuantity)
		self._partLocation = State(initialValue: mxParts.partLocation)
		self._partStatus = State(initialValue: mxParts.partStatus)
		self._inactive = State(initialValue: mxParts.inactive)
		self._partSupplier = State(initialValue: mxParts.partSupplier)
		self._image1 = State(initialValue: mxParts.image1)
		self._image2 = State(initialValue: mxParts.image2)
		self._image3 = State(initialValue: mxParts.image3)
		self._image1Description = State(initialValue: mxParts.image1Description)
		self._image2Description = State(initialValue: mxParts.image2Description)
		self._image3Description = State(initialValue: mxParts.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL")

						LabeledContent {
							ModelPicker<Vehicle8>(
								selection: $selectedVehicle,
								title: "Vehicle",
								includeEmptyChoice: true,
								emptyChoiceLabel: "All Vehicles",
								autoSelectFirst: false,
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { v in "\(v.year) \(v.displayName)"},
								onSelectionChanged: { sel in
									vehicleId = sel?.name ?? "All Vehicles"
								}
							)
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Vehicle")
								.textLabelModified()
						}

						Picker_VehicleSystem(label: "Vehicle System", data: $vehicleSystem)
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART DETAILS")
						
						HStack{LabelDataTextview(label: "Part Name", data: $partName)}
						HStack{LabelDataTextview(label: "Part #", data: $partNumber)}
						HStack{LabelDataTextview(label: "Manufacturer", data: $partManufacture)}
						HStack{LabelDataTextview(label: "Description", data: $partDescription)}
					}
				}
				
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "PART NOTES", prompt: "Enter notes...", data: $Notes)
				}

				CardView {
					VStack {
						SectionText(label: "PART COSTS")
						
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost/Unit", data: $costPerUnit)}
						Picker_PartsUnit(label: "Unit", data: $partUnit)
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(partUnit))", data: $partQuantity)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART SOURCE")
						LabeledContent {
							ModelPicker<Vendors1>(
								selection: $selectedVendor,
								title: "Supplier",
								includeEmptyChoice: true,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								sort: [SortDescriptor(\.vendorName, order: .forward)],
								labelProvider: { v in v.vendorName },
								onSelectionChanged: { sel in
									partSupplier = sel?.vendorName ?? ""
								}
							)
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Supplier")
								.textLabelModified()
						}

						HStack{LabelDataTextview(label: "Source", data: $partSource)}
						HStack{LabelDataTextview(label: "Location", data: $partLocation)}
						HStack{LabelDataTextview(label: "Status", data: $partStatus)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "PARTS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  PARTS GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Parts Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

			}// end of scroll

			.onAppear {
				// Preselect the Vehicle picker from the current vehicleId when possible.
				if vehicleId.isEmpty || vehicleId == "All Vehicles" {
					selectedVehicle = nil
				} else {
					selectedVehicle = vehicles.first(where: { $0.name == vehicleId })
				}

				// Preselect the Vendor picker from the current partSupplier when possible.
				if partSupplier.isEmpty {
					selectedVendor = nil
				} else {
					selectedVendor = vendors.first(where: { $0.vendorName == partSupplier })
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "part")
			}

			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						isEditing.toggle()
						updateItem()}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}
			
		} else {
			
			// display data
			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle", data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						HStack{LabelDataText(label: "Vehicle System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
						HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active")}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART DETAILS")
						HStack{LabelDataText(label: "Name", data: functions.cleanOptional(inputString: dataSet.partName))}
						if dataSet.partDescription != "" {
							HStack{LabelDataText(label: "Description", data: functions.cleanOptional(inputString: dataSet.partDescription))}
						}
						if dataSet.vehicleSystem != "" {
							HStack{LabelDataText(label: "System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
						}
						if dataSet.partNumber != "" {
							HStack{LabelDataText(label: "Part #", data: functions.cleanOptional(inputString: dataSet.partNumber))}
						}
						if dataSet.partManufacture != "" {
							HStack{LabelDataText(label: "Manufacturer", data: functions.cleanOptional(inputString: dataSet.partManufacture))}
						}
					}
				}
				
				if dataSet.Notes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "PART NOTES", data: dataSet.Notes)}
				}

				CardView {
					VStack{
						SectionText(label: "PART COSTS")
						if dataSet.costPerUnit != 0 {
							HStack{LabelDataText(label: "Cost/Unit", data: "\(functions.formatCurrency(dollars: dataSet.costPerUnit)) / \(dataSet.partUnit)")}
						}
						if dataSet.partUnit != "" {
							HStack{LabelDataText(label: "Unit Type", data: functions.cleanOptional(inputString: dataSet.partUnit))}
						}
						if dataSet.partQuantity != 0 {
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.partQuantity) \(dataSet.partUnit)")}
						}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART SOURCE")
						if dataSet.partSource != "" {
							HStack{LabelDataText(label: "Source", data: functions.cleanOptional(inputString: dataSet.partSource))}
						}
						if dataSet.partLocation != "" {
							HStack{LabelDataText(label: "Location", data: functions.cleanOptional(inputString: dataSet.partLocation))}
						}
						if dataSet.partStatus != "" {
							HStack{LabelDataText(label: "Status", data: functions.cleanOptional(inputString: dataSet.partStatus))}
						}
						if dataSet.partSupplier != "" {
							HStack{LabelDataText(label: "Supplier", data: functions.cleanOptional(inputString: dataSet.partSupplier))}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PARTS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}
			}
			.listStyle(.automatic)
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "part")
			}

			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Delete", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
						Button("Make Inactive") {
							makeInactive()
						}
					} message: {
						Text("Confirm either deletion or deactivation of this service record.  Deactivated records will still be available for reference, but will not be included in any reports or calculations.")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}
	/// Commits staged edits from local `@State` back to `dataSet` and saves the context.
	///
	/// This method mirrors all editable properties from the view's state to the
	/// underlying `MxParts1` instance, updates the `updatedAt` timestamp, and attempts
	/// to persist the changes using the SwiftData `modelContext`.
	///
	/// - Note: Consider surfacing save failures to the user with an alert.
	private func updateItem() {
		// Synchronize all fields from view state back into the persisted model.
		dataSet.inactive = inactive
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.vehicleSystem = vehicleSystem
		dataSet.partName = partName
		dataSet.partNumber = partNumber
		dataSet.partManufacture = partManufacture
		dataSet.partDescription = partDescription
		dataSet.Notes = Notes
		dataSet.costPerUnit = costPerUnit
		dataSet.partUnit = partUnit
		dataSet.partSource = partSource
		dataSet.partQuantity = partQuantity
		dataSet.partLocation = partLocation
		dataSet.partStatus = partStatus
		dataSet.inactive = inactive
		dataSet.partSupplier = partSupplier
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		createSystemIfNeeded()

		// Attempt to persist all changes to the model context.
		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
	}

	/// If the user typed a vehicle system name that doesn't already exist for this
	/// vehicle, create a new `VehicleSystems1` record so it's available for future selection.
	private func createSystemIfNeeded() {
		let name = vehicleSystem.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return }
		let vId = vehicleId
		let fetch = FetchDescriptor<VehicleSystems1>(predicate: #Predicate<VehicleSystems1> {
			$0.systemName == name && $0.vehicleId == vId
		})
		let exists = (try? modelContext.fetch(fetch))?.isEmpty == false
		guard !exists else { return }
		let newSystem = VehicleSystems1(
			vehicleId: vId,
			systemName: name,
			systemDescription: "",
			systemType: "",
			systemManufacturer: "",
			systemModel: "",
			systemSerialNumber: "",
			systemPartNumber: "",
			systemLocation: "",
			systemStatus: "",
			systemNotes: "",
			systemImage: nil
		)
		modelContext.insert(newSystem)
	}
	/// Permanently deletes the current `MxParts1` record and dismisses the view.
	///
	/// Removes `dataSet` from the `modelContext` and saves. If saving fails, the error
	/// is printed to the console. The view is dismissed after the operation.
	private func DeleteRecord(){
		// Remove the object from the context and persist the deletion.
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		// Close the view after deletion to return to the previous screen.
		dismiss()
	}
	/// Marks the current `MxParts1` record as inactive and persists the change.
	///
	/// This helper sets both the underlying model (`dataSet`) and the view's local
	/// state (`inactive`) to `true`, updates the `updatedAt` timestamp, and then
	/// attempts to save the change to the SwiftData `modelContext`. If saving
	/// succeeds, the view is dismissed. If saving fails, an error is printed to the
	/// console and the view is still dismissed to keep the flow consistent with the
	/// destructive action.
	///
	/// Behavior details:
	/// - Sets `dataSet.inactive` to `true` so the persisted record is marked inactive.
	/// - Mirrors that value to the view state `inactive` so the UI reflects the change immediately.
	/// - Updates `dataSet.updatedAt` to the current time to reflect the modification.
	/// - Saves the context to persist the change.
	/// - Dismisses the sheet/view regardless of save outcome (you can adjust this
	///   if you prefer to keep the view open on failure).
	///
	/// Side effects:
	/// - Persists changes to the model context.
	/// - Dismisses the current view using `@Environment(\.dismiss)`.
	///
	/// - Note: Consider surfacing save failures to the user with an alert if needed.
	private func makeInactive() {
		// Mark the underlying model as inactive so the persisted record reflects the change.
		dataSet.inactive = true

		// Keep the view's local state in sync so any UI bound to `inactive` updates immediately.
		inactive = true

		// Record the modification time for auditing/sorting purposes.
		dataSet.updatedAt = Date()

		// Attempt to persist the change to the SwiftData model context.
		do {
			try modelContext.save()
		} catch {
			// In production, consider presenting a user-facing alert instead of just printing.
			print("Failed to mark inactive: \(error.localizedDescription)")
		}

		// Close the current view regardless of save success to maintain a consistent flow
		// after a destructive or terminal action. Adjust if you prefer to remain on screen
		// when persistence fails.
		dismiss()
	}
}

/// Provides a safe subscript returning `nil` for out-of-bounds indices.
///
/// Useful for optional access when the count of an array may be unknown or dynamic.
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

// Provide a local shim for Functions.cleanOptional so this view compiles even if
// the global Functions type doesn't define it. Returns a trimmed string or "—"
// when the input is nil or empty.
private extension Functions {
    func cleanOptional(inputString: String?) -> String {
        let trimmed = (inputString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    func cleanOptional(inputString: String) -> String {
        let trimmed = inputString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}

#Preview("EditParts Preview with sample MxParts1") {
	makeEditPartsPreview()
}

/// Builds an in-memory model container and seeds related data for previews.
///
/// Inserts a vehicle, system, vendor, and a sample `MxParts1` record so both the
/// read-only and edit experiences can be exercised in Xcode previews.
@MainActor private func makeEditPartsPreview() -> some View {
	// In-memory container with related models available for pickers if you toggle Edit.
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				VehicleSystems1.self,
				Vendors1.self,
				MxParts1.self,
				configurations: configuration
	)

	// Seed some related data so pickers have items
	let vehicle = Vehicle8(
		name: "Truck 1500",
		year: 2020,
		mileage: 42000,
		mileageVirtual: 0,
		engHours: 1234.5,
		fuelType: "Gasoline",
		fuelCapacity: 26,
		notes: "",
		vin: "",
		licensePlate: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let system = VehicleSystems1(
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		systemName: "Engine",
		systemDescription: "",
		systemType: "",
		systemManufacturer: "",
		systemModel: "",
		systemSerialNumber: "",
		systemPartNumber: "",
		systemLocation: "",
		systemStatus: "",
		systemNotes: "",
		systemImage: nil,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let vendor = Vendors1(
		createdAt: Date(),
		updatedAt: Date(),
		vendorName: "Main Warehouse",
		vendorType: "",
		vendorContact1: "",
		vendorContact2: "",
		vendorContact3: "",
		vendorAddress: "",
		vendorCity: "",
		vendorState: "",
		vendorZip: "",
		vendorPhone: "",
		vendorEmail: "",
		vendorWebsite: "",
		vendorNotes: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	container.mainContext.insert(vehicle)
	container.mainContext.insert(system)
	container.mainContext.insert(vendor)

	// Seed a sample part
	let sample = MxParts1(
		createdAt: Date().addingTimeInterval(-86400),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		vehicleSystem: system.systemName,
		partName: "Oil Filter",
		partNumber: "OF-9876",
		partManufacture: "FilterCo",
		partDescription: "High performance oil filter compatible with V8 engines.",
		Notes: "Replace every 5,000 miles.",
		costPerUnit: 12.99,
		partUnit: "each",
		partSource: "Aisle 3",
		partQuantity: 4,
		partLocation: "Bin B",
		partStatus: "In Stock",
		partImage: nil,
		partSupplier: vendor.vendorName,
		image1: nil,
		image1Description: "Box front",
		image2: nil,
		image2Description: "Filter element",
		image3: nil,
		image3Description: "Installed view"
	)
	container.mainContext.insert(sample)

	return EditParts(mxParts: sample)
		.modelContainer(container)
}


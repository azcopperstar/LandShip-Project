/*
 EditSystems.swift
 LandShip

 Created by JP on 8/12/25

 Overview
 --------
 EditSystems is a SwiftUI view responsible for displaying and editing a single VehicleSystems1 record. The view supports three primary modes:
 - Read mode: Shows a read-only detail view of the system.
 - Edit mode: Presents editable controls for all fields, including a ModelPicker to select the associated Vehicle8 by name.
 - Filtered notice: If the system is inactive and the global setting `showInactiveVehicles` is false, a filtered message is shown instead of details.

 Key Responsibilities
 --------------------
 - Provide a clear editing experience with cancel support using a local snapshot (SystemSnapshot).
 - Persist changes to SwiftData via the Environment modelContext.
 - Allow destructive actions (delete) and non-destructive status changes (make inactive) from the toolbar.
 - Keep local UI state in sync with the underlying data model, only committing on save (except explicit destructive/terminal actions).

 Data Flow & State
 -----------------
 - `dataSet`: The bound VehicleSystems1 model being read/edited.
 - Local @State mirrors each model property for form editing; this avoids uncommitted mutations until Save.
 - `snapshot`: Captures the local state when entering edit mode; used to restore values on Cancel.
 - `selectedVehicle`: The currently selected Vehicle8 in the ModelPicker. The vehicle reference is stored as `vehicleId` using the vehicle's `name`.
 - `@AppStorage("showInactiveVehicles")`: Toggles whether inactive systems are visible when not editing.

 Persistence & Actions
 ---------------------
 - updateItem(): Copies local state back to the model and saves via SwiftData.
 - DeleteRecord(): Deletes the model from the context and dismisses the view.
 - makeInactive(): Immediately marks the model inactive, saves, and dismisses.

 UI Structure
 ------------
 - Toolbar: Contextual actions switch between Edit/Save/Cancel/Delete depending on mode.
 - Page title: Uses PageTitle_Col3_Photo for a consistent top inset across modes.
 - Content: CardView sections group General, Details, Notes, Images, and Status.

 Dependencies & Assumptions
 --------------------------
 - Relies on custom views/types (e.g., CardView, SectionText, LabelDataTextview, Image_Edit, ModelPicker, Vehicle8, VehicleSystems1) existing elsewhere in the project.
 - Vehicle association uses a string vehicleId equal to Vehicle8.name.
 - The code assumes modelContext is available in the environment.

 Previews
 --------
 - Provide both a populated and an empty/new example using an in-memory SwiftData container, seeding Vehicle8 and VehicleSystems1 as needed.
*/

import SwiftUI
import SwiftData

/// A detail/edit view for a VehicleSystems1 record.
///
/// - Shows read-only details by default, unless `startEditing` is true.
/// - Provides a full editing form with cancel/restore support.
/// - Enforces minimal validation (non-empty name) before allowing Save.
struct EditSystems: View {
	// MARK: - Model & user preferences
	@State private var dataSet: VehicleSystems1
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = true

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()

	// MARK: - View mode & flow control
	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false
	
	// MARK: - Local editable copies of model fields (not persisted until Save)
	@State fileprivate var inactive: Bool = false
	@State fileprivate var createdAt = Date()
	@State fileprivate var updatedAt = Date()
	@State fileprivate var vehicleId = ""
	@State fileprivate var systemName = "System title..."
	@State fileprivate var systemDescription = ""
	@State fileprivate var systemType = ""
	@State fileprivate var systemManufacturer = ""
	@State fileprivate var systemModel = ""
	@State fileprivate var systemSerialNumber = ""
	@State fileprivate var systemPartNumber = ""
	@State fileprivate var systemLocation = ""
	@State fileprivate var systemStatus = ""
	@State fileprivate var systemNotes = ""
	@State fileprivate var image1: Data?
	@State fileprivate var image2: Data?
	@State fileprivate var image3: Data?
	@State fileprivate var image1Description: String = ""
	@State fileprivate var image2Description: String = ""
	@State fileprivate var image3Description: String = ""

	// MARK: - Snapshot used to support Cancel while editing
	@State private var snapshot: SystemSnapshot?

	// MARK: - ModelPicker selection
	/// Holds the selected Vehicle8 for the vehicle association; persisted via `vehicleId` (vehicle name).
	@State private var selectedVehicle: Vehicle8? = nil

	/// Initializes the view with a specific system record.
	/// - Parameters:
	///   - vehicleSystem: The VehicleSystems1 model to display/edit.
	///   - startEditing: When true, the view opens directly in edit mode.
	init(vehicleSystem: VehicleSystems1, startEditing: Bool = false) {
		self.dataSet = vehicleSystem

		self._inactive = State(initialValue: vehicleSystem.inactive)
		self._createdAt = State(initialValue: vehicleSystem.createdAt)
		self._updatedAt = State(initialValue: vehicleSystem.updatedAt)
		self._vehicleId = State(initialValue: vehicleSystem.vehicleId)
		self._systemName = State(initialValue: vehicleSystem.systemName)
		self._systemDescription = State(initialValue: vehicleSystem.systemDescription)
		self._systemType = State(initialValue: vehicleSystem.systemType)
		self._systemManufacturer = State(initialValue: vehicleSystem.systemManufacturer)
		self._systemModel = State(initialValue: vehicleSystem.systemModel)
		self._systemSerialNumber = State(initialValue: vehicleSystem.systemSerialNumber)
		self._systemPartNumber = State(initialValue: vehicleSystem.systemPartNumber)
		self._systemLocation = State(initialValue: vehicleSystem.systemLocation)
		self._systemStatus = State(initialValue: vehicleSystem.systemStatus)
		self._systemNotes = State(initialValue: vehicleSystem.systemNotes)
		self._image1 = State(initialValue: vehicleSystem.image1)
		self._image2 = State(initialValue: vehicleSystem.image2)
		self._image3 = State(initialValue: vehicleSystem.image3)
		self._image1Description = State(initialValue: vehicleSystem.image1Description)
		self._image2Description = State(initialValue: vehicleSystem.image2Description)
		self._image3Description = State(initialValue: vehicleSystem.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}

	/// Main view entry point; switches between edit, filtered, and read content based on state.
	var body: some View {
		Group {
			if isEditing {
				editContent
			} else if !showInactiveVehicles && dataSet.inactive {
				filteredContent
			} else {
				readContent
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.toolbar { toolbarContent }
	}

	/// Edit-mode content with form controls bound to local @State mirrors.
	/// Changes are not persisted until `Save`.
	private var editContent: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "GENERAL")
					
					LabeledContent {
						// Associate this system to a Vehicle8 by selecting its name; stored in `vehicleId`.
						ModelPicker(
							selection: $selectedVehicle,
							title: "Vehicle",
							includeEmptyChoice: false,
							emptyChoiceLabel: "—",
							autoSelectFirst: false,
							filter: nil,
							sort: [SortDescriptor(\.name, order: .forward)],
							labelProvider: { $0.name }
						)
						.onChange(of: selectedVehicle) { _, newVehicle in
							let name = newVehicle?.name ?? ""
							vehicleId = name
							dataSet.vehicleId = name
						}
					} label: {
						Text("Vehicle")
							.textLabelModified()
					}

					
//					HStack{
//						Text("Vehicle")
//							.textLabelModified()
//						// Replaced VehiclePickerSystems with ModelPicker<Vehicle8>
//						ModelPicker(
//							selection: $selectedVehicle,
//							title: "Vehicle",
//							includeEmptyChoice: false,
//							emptyChoiceLabel: "—",
//							autoSelectFirst: false,
//							filter: nil,
//							sort: [SortDescriptor(\.name, order: .forward)],
//							labelProvider: { $0.name }
//						)
//						.onChange(of: selectedVehicle) { _, newVehicle in
//							let name = newVehicle?.name ?? ""
//							vehicleId = name
//							dataSet.vehicleId = name
//						}
//						.frame(maxWidth: .infinity, alignment: .trailing)
//					}
	
					HStack{LabelDataTextview(label: "System Name", data: $systemName)}
					HStack{LabelDataTextview(label: "Description", data: $systemDescription)}
					HStack{LabelDataText(label: "Status", data: inactive ? "Inactive" : "Active")}
				}
			}
			
			CardView {
				VStack {
					SectionText(label: "DETAILS")
					HStack{LabelDataTextview(label: "System Type", data: $systemType)}
					HStack{LabelDataTextview(label: "Manufacture", data: $systemManufacturer)}
					HStack{LabelDataTextview(label: "Model", data: $systemModel)}
					HStack{LabelDataTextview(label: "Serial Number", data: $systemSerialNumber)}
					HStack{LabelDataTextview(label: "Part Number", data: $systemPartNumber)}
					HStack{LabelDataTextview(label: "Location", data: $systemLocation)}
					HStack{LabelDataTextview(label: "Status", data: $systemStatus)}
				}
			}
			
			CardView {
				TextFieldNote_FullWidth_3lines(sectionText: "SYSTEM NOTES", prompt: "Enter notes...", data: $systemNotes)
			}
			
			CardView {
				VStack {
#if os(macOS)
					SectionText(label: "VEHICLE SYSTEMS GRAPHICS")
#elseif os(iOS)
					SectionText(label: "  VEHICLE SYSTEMS GRAPHICS\n(Click Image to Change)")
#endif
					HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
					HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
					HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
				}
			}
			
			CardView {
				VStack {
					SectionText(label: "STATUS")
					HStack{LabelDataToggle(label: "Deactivate System Record", data: $inactive)}
					Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
						.font(.caption)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
		}

		.safeAreaInset(edge: .top) {
			PageTitle_Col3_Photo(
				label: "",
				action: "edit",
				dbRecord: "system")
		}

		.onAppear {
			// When we enter edit mode, ensure local state matches the latest model and capture a snapshot
			loadFromModel()
			snapshot = SystemSnapshot(from: self)

			// Seed vehicle picker from existing vehicleId if present
			if selectedVehicle == nil, !vehicleId.isEmpty {
				let name = vehicleId
				var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
				fd.fetchLimit = 1
				if let v = try? modelContext.fetch(fd).first {
					selectedVehicle = v
				}
			}
		}
	}

	/// Read-only detail content for the system.
	private var readContent: some View {
		ScrollView {
			VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
			
			CardView {
				VStack{
					SectionText(label: "GENERAL")
					HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
					HStack{LabelDataText(label: "System Name", data: "\(dataSet.systemName)")}
					HStack{LabelDataText(label: "Status", data: inactive ? "Inactive" : "Active")}
					if dataSet.systemDescription != "" {
						HStack{LabelDataText(label: "Description", data: "\(dataSet.systemDescription)")}
					}
				}
			}
			
			CardView {
				VStack{
					SectionText(label: "DETAILS")
					if dataSet.systemType != "" {
						HStack{LabelDataText(label: "System Type", data: "\(dataSet.systemType)")}
					}
					if dataSet.systemManufacturer != "" {
						HStack{LabelDataText(label: "Manufacturer", data: "\(dataSet.systemManufacturer)")}
					}
					if dataSet.systemModel != "" {
						HStack{LabelDataText(label: "Model #", data: "\(dataSet.systemModel)")}
					}
					if dataSet.systemSerialNumber != "" {
						HStack{LabelDataText(label: "Serial #", data: "\(dataSet.systemSerialNumber)")}
					}
					if dataSet.systemPartNumber != "" {
						HStack{LabelDataText(label: "Part #", data: "\(dataSet.systemPartNumber)")}
					}
					if dataSet.systemLocation != "" {
						HStack{LabelDataText(label: "Location", data: "\(dataSet.systemLocation)")}
					}
					if dataSet.systemStatus != "" {
						HStack{LabelDataText(label: "Status", data: "\(dataSet.systemStatus)")}
					}
				}
			}
			
			if dataSet.systemNotes != "" {CardView {
				TextNoteDisplay_FullWidth(sectionText: "SYSTEM NOTES", data: dataSet.systemNotes)}
			}
			
			CardView {
				VStack {
					SectionText(label: "VEHICLE SYSTEMS GRAPHICS")
					Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
					Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
					Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
				}
			}
		}
		.listStyle(.automatic)

		.safeAreaInset(edge: .top) {
			PageTitle_Col3_Photo(
				label: "",
				action: "details",
				dbRecord: "system")
		}
	}

	/// Alternate content shown when the system is inactive and the global filter hides inactive items.
	private var filteredContent: some View {
		ScrollView {
			VStack(spacing: 16) {
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						SectionText(label: "HIDDEN BY FILTER")
						Text("This system is marked inactive and is hidden because 'Show Inactive Vehicles' is turned off.")
							.foregroundStyle(.secondary)
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataText(label: "Status", data: inactive ? "Inactive" : "Active")}
					}
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.safeAreaInset(edge: .top) {
			PageTitle_Col3_Photo(
				label: "",
				action: "details",
				dbRecord: "system")
		}
	}

	// MARK: - Toolbar actions and mode switching
	/// Toolbar content switches between Edit/Cancel/Save/Delete depending on `isEditing`.
	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		if isEditing {
			ToolbarItem(placement: .automatic) {
				Button("Cancel") {
					cancelEditing()
				}
				.buttonStyle(GrowingButton(buttonColor: Color.green))
			}
			ToolbarItem(placement: .automatic) {
				Button("Save") {
					isEditing = false
					updateItem()
				}
				.buttonStyle(GrowingButton(buttonColor: Color.red))
				.disabled(isSaveDisabled)
			}
		} else {
			ToolbarItem(placement: .automatic) {
				Button("Edit") {
					isEditing = true
					// load current model values into editing state and capture snapshot
					loadFromModel()
					snapshot = SystemSnapshot(from: self)
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

	/// Minimal validation: disable Save when the system name is empty or whitespace.
	private var isSaveDisabled: Bool {
		systemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// Load current model values into local @State for editing.
	private func loadFromModel() {
		inactive = dataSet.inactive
		createdAt = dataSet.createdAt
		updatedAt = dataSet.updatedAt
		vehicleId = dataSet.vehicleId
		systemName = dataSet.systemName
		systemDescription = dataSet.systemDescription
		systemType = dataSet.systemType
		systemManufacturer = dataSet.systemManufacturer
		systemModel = dataSet.systemModel
		systemSerialNumber = dataSet.systemSerialNumber
		systemPartNumber = dataSet.systemPartNumber
		systemLocation = dataSet.systemLocation
		systemStatus = dataSet.systemStatus
		systemNotes = dataSet.systemNotes
		image1 = dataSet.image1
		image2 = dataSet.image2
		image3 = dataSet.image3
		image1Description = dataSet.image1Description
		image2Description = dataSet.image2Description
		image3Description = dataSet.image3Description
	}

	/// Restore local @State from the snapshot captured upon entering edit mode.
	private func restoreFromSnapshot() {
		guard let snap = snapshot else { return }
		inactive = snap.inactive
		createdAt = snap.createdAt
		updatedAt = snap.updatedAt
		vehicleId = snap.vehicleId
		systemName = snap.systemName
		systemDescription = snap.systemDescription
		systemType = snap.systemType
		systemManufacturer = snap.systemManufacturer
		systemModel = snap.systemModel
		systemSerialNumber = snap.systemSerialNumber
		systemPartNumber = snap.systemPartNumber
		systemLocation = snap.systemLocation
		systemStatus = snap.systemStatus
		systemNotes = snap.systemNotes
		image1 = snap.image1
		image2 = snap.image2
		image3 = snap.image3
		image1Description = snap.image1Description
		image2Description = snap.image2Description
		image3Description = snap.image3Description
	}

	/// Cancel edit mode, restoring values from snapshot and leaving the model untouched.
	private func cancelEditing() {
		restoreFromSnapshot()
		isEditing = false
	}

	/// Persist local edits back to the model and save via SwiftData.
	/// Updates `updatedAt` to the current time.
	@MainActor
	private func updateItem() {
		dataSet.inactive = inactive
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.systemName = systemName
		dataSet.systemDescription = systemDescription
		dataSet.systemType = systemType
		dataSet.systemManufacturer = systemManufacturer
		dataSet.systemModel = systemModel
		dataSet.systemSerialNumber = systemSerialNumber
		dataSet.systemPartNumber = systemPartNumber
		dataSet.systemLocation = systemLocation
		dataSet.systemStatus = systemStatus
		dataSet.systemNotes = systemNotes
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
	}

	/// Delete the current record from SwiftData and dismiss the view.
	@MainActor
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}

	/// Mark the record as inactive immediately, save, and dismiss.
	/// This acts as a non-destructive alternative to deletion.
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

// MARK: - Snapshot for cancel support
/// A plain struct capturing the view's local state when entering edit mode.
/// This enables full restoration on Cancel without mutating the persisted model.
private struct SystemSnapshot {
	let inactive: Bool
	let createdAt: Date
	let updatedAt: Date
	let vehicleId: String
	let systemName: String
	let systemDescription: String
	let systemType: String
	let systemManufacturer: String
	let systemModel: String
	let systemSerialNumber: String
	let systemPartNumber: String
	let systemLocation: String
	let systemStatus: String
	let systemNotes: String
	let image1: Data?
	let image2: Data?
	let image3: Data?
	let image1Description: String
	let image2Description: String
	let image3Description: String

	/// Capture all relevant local state values from the view for later restoration.
	@MainActor
	init(from view: EditSystems) {
		self.inactive = view.inactive
		self.createdAt = view.createdAt
		self.updatedAt = view.updatedAt
		self.vehicleId = view.vehicleId
		self.systemName = view.systemName
		self.systemDescription = view.systemDescription
		self.systemType = view.systemType
		self.systemManufacturer = view.systemManufacturer
		self.systemModel = view.systemModel
		self.systemSerialNumber = view.systemSerialNumber
		self.systemPartNumber = view.systemPartNumber
		self.systemLocation = view.systemLocation
		self.systemStatus = view.systemStatus
		self.systemNotes = view.systemNotes
		self.image1 = view.image1
		self.image2 = view.image2
		self.image3 = view.image3
		self.image1Description = view.image1Description
		self.image2Description = view.image2Description
		self.image3Description = view.image3Description
	}
}

// MARK: - Previews

#Preview("EditSystems - Populated Sample") {
	// Configure an in-memory model container and seed sample data for demonstration.
	// In-memory SwiftData container
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self, VehicleSystems1.self,
		configurations: config
	)
	let context = container.mainContext

	// Seed a vehicle for the picker and to reference by name
	let vehicle = Vehicle8(
		name: "Demo Rig",
		year: 2020,
		mileage: 42000,
		engHours: 850.5,
		fuelType: "Diesel",
		fuelCapacity: 120
	)
	context.insert(vehicle)

	// Seed a populated system record
	let system = VehicleSystems1(
		vehicleId: vehicle.name,
		systemName: "Cooling System",
		systemDescription: "Radiator, hoses, thermostat",
		systemType: "Engine",
		systemManufacturer: "ACME Cooling",
		systemModel: "CX-200",
		systemSerialNumber: "SN123456",
		systemPartNumber: "PN-COOL-200",
		systemLocation: "Front compartment",
		systemStatus: "Operational",
		systemNotes: "Inspect annually",
		systemImage: nil,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	context.insert(system)
	try? context.save()

	return NavigationStack {
		EditSystems(vehicleSystem: system, startEditing: false)
	}
	.modelContainer(container)
}

#Preview("EditSystems - Empty/New Sample") {
	// Configure an in-memory model container and seed sample data for demonstration.
	// In-memory SwiftData container
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self, VehicleSystems1.self,
		configurations: config
	)
	let context = container.mainContext

	// Seed at least one vehicle so the picker has choices
	let vehicle = Vehicle8(
		name: "Blank Vehicle",
		year: 2024,
		mileage: 0,
		engHours: 0.0,
		fuelType: "Gasoline",
		fuelCapacity: 0
	)
	context.insert(vehicle)

	// Create a mostly empty/new system record (referencing the vehicle by name)
	let system = VehicleSystems1(
		vehicleId: vehicle.name,
		systemName: "",
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
	context.insert(system)
	try? context.save()

	return NavigationStack {
		// Start in edit mode to demonstrate the ModelPicker and fields
		EditSystems(vehicleSystem: system, startEditing: true)
	}
	.modelContainer(container)
}

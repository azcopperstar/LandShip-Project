//
//  DisplaySystems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//
//  Overview
//  --------
//  DisplaySystems is a SwiftUI view that lists vehicle systems (VehicleSystems1) and
//  provides sorting, filtering, and navigation to create and edit records. It integrates
//  with SwiftData for persistence, supports programmatic navigation after record creation,
//  and remembers the user's selected vehicle via an external binding (trackVehicleSelected).
//
//  Responsibilities
//  - Present a vehicle picker to scope the systems list to a specific vehicle or all vehicles.
//  - Display a list of VehicleSystems1 records with multiple sort options.
//  - Provide an empty state with a call to action when no records exist.
//  - Allow adding a new system and navigate directly to its edit screen.
//  - Respect an app setting to include/exclude inactive vehicles.
//
//  Key Concepts
//  - Sorting: Users can choose among several sort orders (by vehicle, by name, by recency).
//  - Filtering: Records are filtered by selected vehicle and the inactive flag.
//  - Navigation: Uses NavigationLink for selection and navigationDestination for programmatic push
//    after creating a new record.
//  - State Sharing: The selected vehicle name is shared across views using the binding
//    `trackVehicleSelected` to keep the user's context consistent.
//
//  Dependencies
//  - SwiftUI for UI composition.
//  - SwiftData for data querying, insertion, and persistence.
//  - Custom views/types expected in the project: ModelPicker, QueryView, PageTitle_Col2_NoPhoto,
//    EditSystems, EmptyStateSection, GrowingButton, plus styling modifiers like textLabelModified(),
//    textModifier_ListTitle(), etc.
//
//  Notes
//  - This view avoids altering the underlying data model beyond creating a new record on demand.
//  - The filter predicate is written to clearly separate the inactive and vehicle scoping logic.
//  - The `.id(record.id)` on EditSystems works around split view detail updates when selection changes.
//

/// A SwiftUI list view for browsing and managing `VehicleSystems1` records.
///
/// Features:
/// - Vehicle scoping via a model picker (or "All Vehicles").
/// - Multiple sort orders exposed via a toolbar menu.
/// - Empty state with a guided action to create the first record.
/// - Programmatic navigation to the edit screen after creating a new record.
/// - Optional inclusion of inactive vehicles via `@AppStorage`.


import SwiftUI
import SwiftData

struct DisplaySystems: View {
	// MARK: - Dependencies & Environment
	
	/// Available vehicles fetched from the persistent store.
	/// Used to populate and resolve selections in the vehicle picker.
	@Query var vehicles: [Vehicle8]
	
	/// SwiftData model context used for fetching, inserting, and saving records.
	@Environment(\.modelContext) var modelContext
	
	/// User preference that controls whether inactive vehicles are included in the list.
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	/// The record currently selected in the list (used for list selection state).
	@State private var selectedRecord: VehicleSystems1?
	
	/// The currently selected vehicle from the picker. `nil` means "All Vehicles".
	@State private var selectedVehicle: Vehicle8? = nil
	
	/// Utility helper (project-specific). Not used directly in this file but kept for parity with other views.
	let functions: Functions = Functions()
	
	// MARK: - Cross-View State
	
	/// Tracks the vehicle selection across views by name. "All Vehicles" indicates no scoping.
	@Binding var trackVehicleSelected: String
	
	// MARK: - Legacy/Ad-hoc Sorting
	
	/// Legacy/ad-hoc sort descriptor by vehicle ID; kept for quick experiments.
	@State private var sortVehicle: SortDescriptor<VehicleSystems1> = .init(\.vehicleId, order: .forward)
	
	/// Legacy/ad-hoc sort descriptor by system name; kept for quick experiments.
	@State private var sortSysName: SortDescriptor<VehicleSystems1> = .init(\.systemName, order: .forward)
	
	// MARK: - Navigation
	
	/// When set, triggers a navigation to the edit screen for the newly created record.
	@State private var newRecordToEdit: VehicleSystems1?
	
	// MARK: - Sorting
	
	/// User-facing sort modes for the systems list, with associated sort descriptors.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc_nameAsc = "Vehicle A–Z, System A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, System Z–A"
		case nameAsc = "System A–Z"
		case nameDesc = "System Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		/// The concrete SwiftData sort descriptors used by `QueryView` for this sort mode.
		var descriptors: [SortDescriptor<VehicleSystems1>] {
			switch self {
				case .vehicleAsc_nameAsc:
					return [
						.init(\.vehicleId, order: .forward),
						.init(\.systemName, order: .forward)
					]
				case .vehicleAsc_nameDesc:
					return [
						.init(\.vehicleId, order: .forward),
						.init(\.systemName, order: .reverse)
					]
				case .nameAsc:
					return [ .init(\.systemName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.systemName, order: .reverse) ]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	
	/// The currently selected sort mode; reflected in the toolbar and header.
	@State private var selectedSort: PartsSort = .vehicleAsc_nameAsc
	
	// MARK: - Body
	var body: some View {
		
		// Vehicle scope picker — choose a specific vehicle or show all systems.
		LabeledContent {
			ModelPicker(
				selection: $selectedVehicle,
				title: "Vehicle",
				includeEmptyChoice: true,
				emptyChoiceLabel: "All Vehicles",
				autoSelectFirst: false,
				filter: nil,
				sort: [SortDescriptor(\.name, order: .forward)],
				labelProvider: { v in "\(v.year) \(v.name)" }
			)
			.onChange(of: selectedVehicle) { _, newVehicle in
				// Keep the cross-view binding in sync with the local selection.
				trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
			}
			.onAppear {
				// Resolve initial selection from the shared binding, defaulting to "All Vehicles".
				if trackVehicleSelected.isEmpty { trackVehicleSelected = "All Vehicles" }
				if trackVehicleSelected != "All Vehicles" {
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == trackVehicleSelected })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					} else {
						selectedVehicle = nil
						trackVehicleSelected = "All Vehicles"
					}
				} else {
					selectedVehicle = nil
				}
			}
			.fixedSize(horizontal: true, vertical: true)
		} label: {
			Text("Vehicle:")
				.textLabelModified()
		}
		
		// Page title banner for this screen.
		.safeAreaInset(edge: .top) {
			PageTitle_Col2_NoPhoto(label: "SYSTEMS")
		}
		
		// Data-driven list of systems. The sort reflects the user's current selection.
		QueryView(for: VehicleSystems1.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
				// Empty state with guidance and a CTA to create the first system.
				List {
					EmptyStateSection(
						title: "Add your first System",
						systemImage: "glowplug",
						description: "Create a System to be used when creating service items and service records.\n\nTo add additional systems after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First System",
						action: { addNewRecord() }
					)
				}
			} else {
				// Populated list of systems with navigation to edit each record.
				Section {
					List(selection: $selectedRecord){
						ForEach(records) { record in
							// Navigate to edit view; `.id(record.id)` ensures split view updates on selection changes.
							NavigationLink {
								EditSystems(vehicleSystem: record)
									.id(record.id) // <<< work-around to get splitview to change details when selected
							} label: {
								HStack{
									let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
									Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
									VStack{
										Text("\(record.systemName)")
											.textModifier_ListTitle()
										Text("\(record.vehicleId)")
											.textModifier_ListSubTitle_R()
										Text("\(record.systemDescription)")
											.textModifier_ListSubTitle_L()
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
								}
							}
						}
					}
					.toolbar {
						// Sorting menu — exposes the enum-backed sort modes to the user.
						ToolbarItem(placement: .automatic) {
							Menu {
								Picker("Sort by", selection: $selectedSort) {
									ForEach(PartsSort.allCases) { sortCase in
										Text(sortCase.rawValue).tag(sortCase)
									}
								}
							} label: {
								Label("Sort", systemImage: "arrow.up.arrow.down")
							}
							.buttonStyle(GrowingButton(buttonColor: Color.gray))
							.accessibilityLabel("Sort parts")
						}
						// Add button — creates a new record and navigates to its edit form.
						ToolbarItem(placement: .automatic) {
							Button {
								addNewRecord()
							} label: {
								Label("Add", systemImage: "plus.capsule")
							}
							.disabled(false)
						}
					}
				} header: {
					// Lightweight header summarizing the current sort selection.
					HStack(spacing: 6) {
						Image(systemName: "arrow.up.arrow.down")
						Text("Sort: \(selectedSort.rawValue)")
					}
					.font(.caption)
					.foregroundStyle(.secondary)
					.padding(.top, 4)
				}
			}
		} filter: {
			// Filter predicate combining vehicle scoping and inactive visibility.
			#Predicate { item in
				// Inactive ON: include inactive items.
				if showInactiveVehicles {
					// No vehicle scoping — show all.
					if trackVehicleSelected == "All Vehicles" {
						true
					} else {
						// Scoped to the selected vehicle by name match.
						item.vehicleId.contains(trackVehicleSelected)
					}
				} else {
					// No vehicle scoping — show all.
					if trackVehicleSelected == "All Vehicles" {
						// Exclude inactive items when preference is OFF.
						item.inactive == false
					} else {
						// Scoped to the selected vehicle by name match.
						// Exclude inactive items when preference is OFF.
						item.vehicleId.contains(trackVehicleSelected) && item.inactive == false
					}
				}
			}
		}
		// Programmatic navigation after creating a new record.
		.navigationDestination(item: $newRecordToEdit) { record in
			EditSystems(vehicleSystem: record, startEditing: true)
				.id(record.id)
		}
	}
	
	// MARK: - Actions
	
	/// Creates and inserts a new `VehicleSystems1` record, then navigates to its edit screen.
	///
	/// Behavior:
	/// - Assigns the selected vehicle (if any) by name to `vehicleId`.
	/// - Sets timestamps for creation and last update.
	/// - Persists the record and updates local selection/navigation state.
	@MainActor
	private func addNewRecord() {
		// Prepare timestamps and determine vehicle scoping for the new record.
		let now = Date()
		let assignedVehicleId = (trackVehicleSelected == "All Vehicles") ? "" : trackVehicleSelected
		
		// Construct the new model instance with sensible defaults.
		let newRecord = VehicleSystems1(
			inactive: false,
			createdAt: now,
			updatedAt: now,
			vehicleId: assignedVehicleId,
			systemName: "New vehicle system...",
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
		
		// Stage the new record in the context and attempt to persist it.
		modelContext.insert(newRecord)
		
		do {
			// Save to persistent store.
			try modelContext.save()
			
			// Reflect selection in the list to highlight the new item.
			selectedRecord = newRecord
			
			// Trigger programmatic navigation to the edit screen.
			newRecordToEdit = newRecord
		} catch {
			// In a production app, consider surfacing a user-visible error instead of just logging.
			print("Failed to save VehicleSystems1: \(error.localizedDescription)")
		}
	}
}

#Preview {
	//    DisplayItems()
}

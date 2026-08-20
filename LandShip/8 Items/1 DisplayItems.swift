/**
 DisplayItems.swift
 LandShip
 
 Created by JP on 8/12/25
 
 Overview
 --------
 DisplayItems presents a browsable, sortable list of service item templates (`MxItems3`) filtered by a selected vehicle. It supports creating a new item for the currently selected vehicle and navigating into `EditItems` for viewing/editing details.
 
 Key Responsibilities
 --------------------
 - Provide a vehicle picker to scope the item list (or show all vehicles).
 - Query and display `MxItems3` records with multiple sort modes.
 - Navigate to `EditItems` for the selected record.
 - Create a new service item for the selected vehicle and immediately navigate to edit it.
 
 Data Flow
 ---------
 - Uses SwiftData's `@Query` to bring in vehicles and `QueryView` to fetch `MxItems3` with sort/filter.
 - Persists new records via `modelContext.insert` and `modelContext.save`.
 - Tracks cross-view vehicle selection via a `@Binding` (`trackVehicleSelected`).
 
 UX Notes
 --------
 - When no items exist, an empty state invites the user to add the first service item.
 - The toolbar provides sorting and an add button when items are present.
 - The filter respects `@AppStorage("showInactiveVehicles")` to optionally include inactive items.
 */

import SwiftUI
import SwiftData

/// A list and management view for `MxItems3` (service item templates).
/// - Filters by selected vehicle (or shows all).
/// - Supports multiple sort modes and navigation to edit.
/// - Creates a new item for the current vehicle and opens it in edit mode.
struct DisplayItems: View {
	// MARK: - Data sources & environment
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	
	// MARK: - Selection & preferences
	@State private var selectedRecord: MxItems3?
    @State private var selectedVehicle: Vehicle8?
    @AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	let functions: Functions = Functions()
	
	// Tracks the currently selected vehicle across views ("All Vehicles" means no filter).
	@Binding var trackVehicleSelected: String

	// MARK: - Legacy sort descriptors (kept for reference)
	// These are not directly used; the enum below defines active sort behavior.
	@State private var sortVehicle: SortDescriptor<MxItems3> = .init(\.vehicleId, order: .forward)
	@State private var sortItem: SortDescriptor<MxItems3> = .init(\.mxName, order: .forward)

	// MARK: - Navigation state
	// Programmatic navigation to EditItems after adding a new record.
	@State private var newRecordToEdit: MxItems3?
	
	/// Sort options for listing service items.
	/// Provides a set of `SortDescriptor` arrays used by `QueryView`.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Items A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Items Z–A"
		case nameAsc = "Items A–Z"
		case nameDesc = "Items Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<MxItems3>] {
			switch self {
				case .dateDesc:
					return [ .init(\.createdAt, order: .reverse) ]
				case .dateAsc:
					return [ .init(\.createdAt, order: .forward) ]
				case .vehicleAsc_nameAsc:
					return [
						.init(\.vehicleId, order: .forward),
						.init(\.mxName, order: .forward)
					]
				case .vehicleAsc_nameDesc:
					return [
						.init(\.vehicleId, order: .forward),
						.init(\.mxName, order: .reverse)
					]
				case .nameAsc:
					return [ .init(\.mxName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.mxName, order: .reverse) ]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	
	// MARK: - Active sort selection
	@AppStorage("sort_items") private var selectedSort: PartsSort = .dateDesc

	var body: some View {

		// Vehicle scope picker. Selecting a vehicle scopes the items list; "All Vehicles" shows all.
        ModelPicker<Vehicle8>(
            selection: $selectedVehicle,
            title: "",
            includeEmptyChoice: true,
            emptyChoiceLabel: "All Vehicles",
            autoSelectFirst: false,
            sort: [SortDescriptor(\.displayName, order: .forward)],
            labelProvider: { v in "\(v.year) \(v.displayName)"},
            onSelectionChanged: { sel in
                trackVehicleSelected = sel?.name ?? "All Vehicles"
            }
        )
        .frame(maxWidth: .infinity)
		// Keep `selectedVehicle` in sync with the cross-view binding on appear.
        .onAppear {
            if trackVehicleSelected.isEmpty || trackVehicleSelected == "All Vehicles" {
                selectedVehicle = nil
            } else {
                selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
            }
        }
		// React to external changes to the tracked vehicle selection.
        .onChange(of: trackVehicleSelected) { _, newValue in
            if newValue.isEmpty || newValue == "All Vehicles" {
                selectedVehicle = nil
            } else if selectedVehicle?.name != newValue {
                selectedVehicle = vehicles.first(where: { $0.name == newValue })
            }
        }
				.safeAreaInset(edge: .top) {
					PageTitle_Col2_NoPhoto(label: "ITEMS")
				}


		// Main list of items, driven by QueryView with the selected sort order.
		QueryView(for: MxItems3.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
				// Empty state encouraging the user to create their first service item.
				List {
					EmptyStateSection(
						title: "Add your first Service Item",
						systemImage: "folder.badge.gearshape",
						description: "Create a Service Item to be used as service templates when creating service records.\n\nTo add additional items after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Fuel Log",
						action: { addNewRecord() }
					)
				}
			} else {
				// Populated list of items with selection and navigation to EditItems.
				Section {
					List(selection: $selectedRecord){
						ForEach(records) { record in
							NavigationLink {
								EditItems(mxItems: record)
									.id(record.id) // <<< work-around to get splitview to change details when selected
							} label: {
								HStack{
//									let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
//									Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
									VStack(alignment: .leading, spacing: 1) {
										Text("\(record.mxName)")
											.font(.headline)
										if !record.mxDescription.isEmpty {
											Text("\(record.mxDescription)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if !intervalDescription(for: record).isEmpty {
											Text("Interval: \(intervalDescription(for: record))")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if !record.vendor.isEmpty {
											Text("\(record.vendor)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if trackVehicleSelected == "All Vehicles" {
											Text("\(Functions().getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext))")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
								}
							}
						}
//						.textModifier_ListDivider()
					}
					// List-level toolbar: sort menu and add button.
					.toolbar {
						ToolbarItem(placement: .automatic) {
							Menu {
								Picker("Sort by", selection: $selectedSort) {
									ForEach(PartsSort.allCases) { sortCase in
										Text(sortCase.rawValue).tag(sortCase)
									}
								}
							} label: {
#if os(macOS)
								Image(systemName: "arrow.up.arrow.down")
#else
								VStack(spacing: 2) {
								Image(systemName: "arrow.up.arrow.down")
								Text("Sort")
									.font(.caption2)
							}
#endif
							}
							.buttonStyle(GrowingButton(buttonColor: Color.gray))
							.help("Sort")
							.accessibilityLabel("Sort parts")
						}
						ToolbarItem(placement: .automatic) {
							Button {
								addNewRecord()
							} label: {
#if os(macOS)
								Image(systemName: "plus.capsule")
#else
								VStack(spacing: 2) {
								Image(systemName: "plus.capsule")
								Text("Add")
									.font(.caption2)
							}
#endif
							}
							.disabled(false)
							.help("Add")
							.accessibilityLabel("Add")
						}
					}
				}
				// Section header reflects the current sort mode.
				header: {
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
			// Filter by vehicle (or all) and optionally include inactive items based on settings.
			#Predicate { item in
				((trackVehicleSelected == "All Vehicles") || (item.vehicleId == trackVehicleSelected)) && (showInactiveVehicles || (item.inactive == false))
			}
		}
		// Navigate to the newly-created item in edit mode as soon as it is saved.
		.navigationDestination(item: $newRecordToEdit) { record in
			EditItems(mxItems: record, startEditing: true)
				.id(record.id)
		}
	}

	/// Builds a compact "6 mo / 5,000 mi / 200 hrs" style summary of the item's service interval,
	/// omitting any component that is zero.
	private func intervalDescription(for record: MxItems3) -> String {
		var parts: [String] = []
		if record.intervalMonths != 0 { parts.append("\(record.intervalMonths) mo") }
		if record.intervalMiles != 0 { parts.append("\(record.intervalMiles) mi") }
		if record.intervalHours != 0 { parts.append("\(record.intervalHours.formatted(.number.precision(.fractionLength(0)))) hrs") }
		return parts.joined(separator: " / ")
	}

	/// Creates a new `MxItems3` for the currently selected vehicle and saves it.
	/// On success, selects it in the list and navigates to `EditItems` in edit mode.
	private func addNewRecord() {
		// Only allow when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }
		
		let newRecord = MxItems3(
			inactive: false,
			createdAt: Date(),
			updatedAt: Date(),
			vehicleId: trackVehicleSelected,
			vehicleSystem: "",
			mxName: "(New service item)",
			mxDescription: "",
			Notes: "",
			vendor: "",
			laborCost: 0,
			intervalMonths: 0,
			intervalMiles: 0,
			intervalHours: 0,
			part1: "",
			part1Id: "",
			part1Qty: 0,
			part1cost: 0,
			part1Unit: "Each",
			part2: "",
			part2Id: "",
			part2Qty: 0,
			part2cost: 0,
			part2Unit: "Each",
			part3: "",
			part3Id: "",
			part3Qty: 0,
			part3cost: 0,
			part3Unit: "Each",
			part4: "",
			part4Id: "",
			part4Qty: 0,
			part4cost: 0,
			part4Unit: "Each",
			part5: "",
			part5Id: "",
			part5Qty: 0,
			part5cost: 0,
			part5Unit: "Each",
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)

		modelContext.insert(newRecord)
		do {
			try modelContext.save()
			// reflect selection in the list (optional)
			selectedRecord = newRecord
			// trigger navigation to edit this new record
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save service item: \(error.localizedDescription)")
		}
	}
}

// Preview with seeded vehicles and items to exercise sorting and navigation.
#Preview("DisplayItems – Seeded Data") {
    @MainActor
    func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Vehicle8.self,
                 MxItems3.self,
                 Settings1.self,
                 configurations: config
        )
    }

    let container = makeContainer()
    let context = container.mainContext

    // Seed vehicles
    let vehicleA = Vehicle8(name: "Vehicle A", year: 2021, mileage: 12050, engHours: 12.5, fuelType: "Gasoline", fuelCapacity: 26)
    let vehicleB = Vehicle8(name: "Vehicle B", year: 2019, mileage: 5400, engHours: 4.0, fuelType: "Diesel", fuelCapacity: 32)
    context.insert(vehicleA)
    context.insert(vehicleB)

    // Seed a few service items for both vehicles
    let item1 = MxItems3(
        createdAt: Date(), updatedAt: Date(),
        vehicleId: vehicleA.name, vehicleSystem: "Engine",
        mxName: "Oil Change",
        mxDescription: "Change engine oil and filter",
        Notes: "",
        vendor: "Local Auto Shop",
        laborCost: 80.0,
        intervalMonths: 6, intervalMiles: 5000, intervalHours: 200.0,
        part1: "5W-30", part1Id: "", part1Qty: 5, part1cost: 7.5, part1Unit: "qt",
        part2: "Oil Filter", part2Id: "", part2Qty: 1, part2cost: 12.0, part2Unit: "Each",
        part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "",
        part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "",
        part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: "",
        image1: nil, image1Description: "",
        image2: nil, image2Description: "",
        image3: nil, image3Description: ""
    )
    let item2 = MxItems3(
        createdAt: Date(), updatedAt: Date(),
        vehicleId: vehicleA.name, vehicleSystem: "Brakes",
        mxName: "Brake Inspection",
        mxDescription: "Inspect pads and rotors",
        Notes: "",
        vendor: "BrakeCo",
        laborCost: 60.0,
        intervalMonths: 12, intervalMiles: 10000, intervalHours: 0.0,
        part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "",
        part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "",
        part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "",
        part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "",
        part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: "",
        image1: nil, image1Description: "",
        image2: nil, image2Description: "",
        image3: nil, image3Description: ""
    )
    let item3 = MxItems3(
        createdAt: Date(), updatedAt: Date(),
        vehicleId: vehicleB.name, vehicleSystem: "Tires",
        mxName: "Rotate Tires",
        mxDescription: "Front to rear rotation",
        Notes: "",
        vendor: "Tire Shop",
        laborCost: 40.0,
        intervalMonths: 6, intervalMiles: 6000, intervalHours: 0.0,
        part1: "", part1Id: "", part1Qty: 0, part1cost: 0, part1Unit: "",
        part2: "", part2Id: "", part2Qty: 0, part2cost: 0, part2Unit: "",
        part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "",
        part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "",
        part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: "",
        image1: nil, image1Description: "",
        image2: nil, image2Description: "",
        image3: nil, image3Description: ""
    )
    context.insert(item1)
    context.insert(item2)
    context.insert(item3)

    // Seed settings (optional; not strictly required here)
    let settings = Settings1()
    settings.userName = "primary1"
    context.insert(settings)

    try? context.save()

    let selection = State(initialValue: "All Vehicles")

    return NavigationStack {
        DisplayItems(trackVehicleSelected: selection.projectedValue)
            .modelContainer(container)
            .navigationTitle("Items")
    }
}

// Preview with a single vehicle but no items to exercise empty state.
#Preview("DisplayItems – Empty") {
    @MainActor
    func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Vehicle8.self,
                 MxItems3.self,
                 configurations: config
        )
    }

    let container = makeContainer()
    let context = container.mainContext

    // Provide a single vehicle so the picker has a choice, but no items
    let vehicle = Vehicle8(name: "Preview Vehicle", year: 2024)
    context.insert(vehicle)
    try? context.save()

    let selection = State(initialValue: "All Vehicles")

    return NavigationStack {
        DisplayItems(trackVehicleSelected: selection.projectedValue)
            .modelContainer(container)
            .navigationTitle("Items")
    }
}


//
//  DisplayParts.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//
//  Overview
//  --------
//  DisplayParts is a SwiftUI view that lists persisted `MxParts1` records and
//  provides sorting, filtering, and navigation to an edit form and a PDF report.
//
//  Key responsibilities:
//  - Filter parts by the currently selected vehicle, honoring the global
//    `showInactiveVehicles` setting (via @AppStorage) used elsewhere in the app.
//  - Allow users to sort parts by multiple criteria (vehicle, name, updated date).
//  - Navigate to:
//      • EditParts: to view/edit an existing part or immediately edit a newly
//        created part.
//      • pdfReportParts: to generate a PDF report for the current vehicle filter.
//  - Provide a friendly empty state with an action to create the first part.
//
//  Architecture & Navigation:
//  - Uses SwiftData `@Query` for vehicles and a custom `QueryView(for:sort:filter:)`
//    for parts. The filter is expressed as a type-safe SwiftData predicate.
//  - Uses modern `navigationDestination` routing on iOS 17+/macOS 14+, with a
//    compatibility fallback using a hidden `NavigationLink` for earlier OSes.
//
//  State Synchronization:
//  - `trackVehicleSelected` is a string binding shared across views to keep the
//    selected vehicle consistent. This view keeps the local `selectedVehicle`
//    (a `Vehicle8?`) in sync with that string binding.
//
//  Accessibility & UX:
//  - List rows expose combined labels for VoiceOver.
//  - Toolbar provides quick access to Sort, Add, and Report actions.
//
//  Previews:
//  - A dedicated preview creates an in-memory SwiftData container, seeds a few
//    vehicles, and demonstrates the empty-state UI when there are no parts.
//

import SwiftUI
import SwiftData

/// A view that displays and manages a list of parts with filtering, sorting,
/// and navigation to editing and reporting interfaces.
struct DisplayParts: View {
    // MARK: - Data & Environment

    /// All vehicles available in the data store. Used to populate the vehicle picker
    /// and to synchronize with the cross-view vehicle selection string.
    @Query var vehicles: [Vehicle8]

    /// SwiftData model context used for inserting and saving new records.
    @Environment(\.modelContext) var modelContext
    @Environment(\.entitlements) private var entitlements

    // MARK: - Selection & Navigation State

    /// The currently selected part record in the list (for multi-selection-capable lists).
    @State private var selectedRecord: MxParts1?

    /// Utility container for app-wide helper methods (if any). Not used directly here
    /// but kept for parity with other views in the app.
    let functions: Functions = Functions()

    /// Global setting used by multiple views to toggle visibility of inactive vehicles.
    /// When false, inactive items are filtered out of the query.
    @AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

    /// A cross-view string binding indicating which vehicle is currently selected.
    /// The special value "All Vehicles" means no vehicle-specific filtering.
    @Binding var trackVehicleSelected: String

    /// Local object reference that mirrors `trackVehicleSelected` as a `Vehicle8?`.
    /// This keeps the picker and the shared binding in sync.
    @State private var selectedVehicle: Vehicle8?

    /// Navigation to PDF report with a frozen scope to avoid feedback loops
    private struct ReportDestination: Hashable { let scope: String }
    @State private var reportDestination: ReportDestination?
    @State private var complianceReportDestination: ReportDestination?

    /// Holds a newly-created record to trigger programmatic navigation into editing.
    @State private var newRecordToEdit: MxParts1?

    /// Fallback boolean trigger used for iOS 16/macOS 13 to push `EditParts` via a hidden link.
    @State private var isPushingNewRecord: Bool = false

    // MARK: - Sorting

    /// Supported sort options for parts. Each case maps to concrete SortDescriptors
    /// used by the parts query.
    private enum PartsSort: String, CaseIterable, Identifiable {
        case dateDesc = "Date ↓"
        case dateAsc = "Date ↑"
        case vehicleAsc_nameAsc = "Vehicle A–Z, Part A–Z"
        case vehicleAsc_nameDesc = "Vehicle A–Z, Part Z–A"
        case nameAsc = "Part A–Z"
        case nameDesc = "Part Z–A"
        case updatedDesc = "Recently Updated"
        var id: String { rawValue }

        /// Vertical-aware display text — the persisted rawValue stays "Vehicle ..." so
        /// existing AppStorage selections keep decoding correctly.
        var displayName: String { rawValue.replacingOccurrences(of: "Vehicle", with: Vertical.current.assetSingular) }

        /// Concrete sort descriptors used by the SwiftData query for `MxParts1`.
        var descriptors: [SortDescriptor<MxParts1>] {
            switch self {
            case .dateDesc:
                return [ .init(\.createdAt, order: .reverse) ]
            case .dateAsc:
                return [ .init(\.createdAt, order: .forward) ]
            case .vehicleAsc_nameAsc:
                return [
                    .init(\.vehicleId, order: .forward),
                    .init(\.partName, order: .forward)
                ]
            case .vehicleAsc_nameDesc:
                return [
                    .init(\.vehicleId, order: .forward),
                    .init(\.partName, order: .reverse)
                ]
            case .nameAsc:
                return [ .init(\.partName, order: .forward) ]
            case .nameDesc:
                return [ .init(\.partName, order: .reverse) ]
            case .updatedDesc:
                return [ .init(\.updatedAt, order: .reverse) ]
            }
        }
    }

    /// Currently selected sort option.
    @AppStorage("sort_parts") private var selectedSort: PartsSort = .dateDesc

    // MARK: - Body

    var body: some View {
        // Build the shared content for both modern and legacy navigation flows.
        let sharedContent = Group {
            // MARK: Vehicle Filter Row
            ModelPicker(
                selection: $selectedVehicle,
                title: "",
                includeEmptyChoice: true,
                emptyChoiceLabel: FleetScope.allDisplayLabel,
                autoSelectFirst: false,
                filter: nil,
                sort: [SortDescriptor(\.displayName, order: .forward)],
									labelProvider: { v in "\(v.year) \(v.displayName)"},
                thumbnailData: { $0.image1 }
            )
            .frame(maxWidth: .infinity)
            // Keep the shared string binding and local object selection synchronized.
            .onChange(of: selectedVehicle) { _, newVehicle in
                // When the user picks a vehicle object, reflect it into the shared string.
                trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
            }
            .onChange(of: trackVehicleSelected) { _, newValue in
                // When the shared string changes externally, update our local object.
                if newValue == "All Vehicles" {
                    selectedVehicle = nil
                } else {
                    if let match = vehicles.first(where: { $0.name == newValue }) {
                        if selectedVehicle?.persistentModelID != match.persistentModelID {
                            selectedVehicle = match
                        }
                    } else {
                        selectedVehicle = nil
                    }
                }
            }
            .onAppear {
                // Seed initial state from the incoming binding.
                if trackVehicleSelected != "All Vehicles" {
                    selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
                } else {
                    selectedVehicle = nil
                }
            }
						.safeAreaInset(edge: .top) {
							PageTitle_Col2_NoPhoto(label: "PARTS")
						}

            // MARK: Parts Query & List
            // QueryView drives a SwiftData fetch for `MxParts1` using the selected
            // sort descriptors and a type-safe filter predicate below.
            QueryView(for: MxParts1.self, sort: selectedSort.descriptors) { records in
                Group {
                    if records.isEmpty {
                        // Empty-state presentation with guidance and a primary CTA to add a part.
                        List {
                            EmptyStateSection(
                                title: "Add your first Part",
                                systemImage: "gearshape.2.fill",
                                description: "Create a part to track inventory, sourcing, and usage in service items and records.\n\nTo add additional parts after this first one, select the '+' button at the top of the form.",
                                actionTitle: "Add First Part",
                                action: { addNewRecord() }
                            )
                        }
                    } else {
                        // Main list of parts with navigation to edit each record.
                        Section {
                            List(selection: $selectedRecord) {
                                ForEach(records) { record in
                                    NavigationLink {
                                        // The `.id(record.id)` workaround ensures that SplitView updates
                                        // its detail when a new record is selected.
                                        EditParts(mxParts: record)
                                            .id(record.id)
                                    } label: {
                                        HStack {
                                            // Thumbnail and primary fields for the part.
//                                            Image_View_Thumbnail(imageData: record.image1)
//																					let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
//																					Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
                                            VStack(alignment: .leading, spacing: 1) {
																							Text("\(record.partName)")
																								.font(.headline)
                                                if !record.partManufacture.isEmpty || !record.partNumber.isEmpty {
                                                    Text("\([record.partManufacture, record.partNumber].filter { !$0.isEmpty }.joined(separator: " · "))")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if !record.partDescription.isEmpty {
                                                    Text("\(record.partDescription)")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if !record.vehicleSystem.isEmpty {
                                                    Text("\(record.vehicleSystem)")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if record.partQuantity != 0 || record.costPerUnit != 0 {
                                                    Text("\(record.partQuantity) \(record.partUnit) · \(record.costPerUnit.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if !record.partStatus.isEmpty {
                                                    Text("\(record.partStatus)")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if record.inventoryTracked {
                                                    let isLowStock = record.inventoryQuantityOnHand <= record.inventoryReorderPoint
                                                    Text("In Stock: \(record.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(record.partUnit)\(isLowStock ? " · LOW STOCK" : "")")
                                                        .font(.subheadline)
                                                        .foregroundStyle(isLowStock ? .red : .secondary)
                                                }
                                                if !record.partSupplier.isEmpty {
                                                    Text("Supplier: \(record.partSupplier)")
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
                                        // Improve VoiceOver by combining child elements into a single label.
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("\(record.partName), \(Vertical.current.assetSingular.lowercased()) \(record.vehicleId)")
                                    }
                                }
//                                .textModifier_ListDivider()
                            }
                            // Toolbar actions specific to the list view: Report, Sort, Add.
                            .toolbar {
                                ToolbarItem(placement: .automatic) {
                                    Button {
                                        let frozen = trackVehicleSelected
                                        reportDestination = ReportDestination(scope: frozen)
                                    } label: {
#if os(macOS)
                                        Image(systemName: "doc.text")
#else
                                        VStack(spacing: 2) {
                                            Image(systemName: "doc.text")
                                            Text("Report")
                                                .font(.caption2)
                                        }
#endif
                                    }
                                    .help("Report")
                                    .accessibilityLabel("Report")
                                }
                                if Vertical.current.enabledFeatures.contains(.partCompliance) {
                                ToolbarItem(placement: .automatic) {
                                    Button {
                                        let frozen = trackVehicleSelected
                                        complianceReportDestination = ReportDestination(scope: frozen)
                                    } label: {
#if os(macOS)
                                        Image(systemName: "checkmark.shield")
#else
                                        VStack(spacing: 2) {
                                            Image(systemName: "checkmark.shield")
                                            Text("Compliance")
                                                .font(.caption2)
                                        }
#endif
                                    }
                                    .help("Parts Compliance Report")
                                    .accessibilityLabel("Parts Compliance Report")
                                }
                                }
                                ToolbarItem(placement: .automatic) {
                                    Menu {
                                        Picker("Sort by", selection: $selectedSort) {
                                            ForEach(PartsSort.allCases) { sortCase in
                                                Text(sortCase.displayName).tag(sortCase)
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
                                    .help("Add")
                                    .accessibilityLabel("Add")
                                }
                            }
                        } header: {
                            // Shows the active sort option above the list.
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text("Sort: \(selectedSort.displayName)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    }
                }
            } filter: {
                // MARK: Parts Filter Predicate
                // If "All Vehicles" is selected, include all parts; otherwise, include
                // only parts whose `vehicleId` contains the selected vehicle name.
                // Respect the global `showInactiveVehicles` toggle.
                #Predicate { item in
                        ((trackVehicleSelected == "All Vehicles") || item.vehicleId.contains(trackVehicleSelected))
                        && (showInactiveVehicles || (item.inactive == false))
                }
            }
        }

        // MARK: Navigation Destinations
        // Conditionally wrap the shared content in the appropriate navigation API
        // for the current platform version.
        if #available(iOS 17.0, macOS 14.0, *) {
            sharedContent
                // Route to the PDF report when requested via toolbar.
                // The report owns and re-fetches its own scope via an in-report vehicle picker,
                // so no .id() here — that would reset the user's picker selection on navigation.
                .navigationDestination(item: $reportDestination) { dest in
                    pdfReportParts(trackVehicleSelected: dest.scope)
                        .ignoresSafeArea()
                }
                .navigationDestination(item: $complianceReportDestination) { dest in
                    pdfReportPartsCompliance(trackVehicleSelected: dest.scope)
                        .ignoresSafeArea()
                }
                // Programmatic navigation when a new record is created and assigned.
                .navigationDestination(item: $newRecordToEdit) { item in
                    EditParts(mxParts: item, startEditing: true)
                }
        } else {
            sharedContent
                // Legacy route to the PDF report for iOS 16/macOS 13.
                // The report owns and re-fetches its own scope via an in-report vehicle picker,
                // so no .id() here — that would reset the user's picker selection on navigation.
                .navigationDestination(item: $reportDestination) { dest in
                    pdfReportParts(trackVehicleSelected: dest.scope)
                        .ignoresSafeArea()
                }
                .navigationDestination(item: $complianceReportDestination) { dest in
                    pdfReportPartsCompliance(trackVehicleSelected: dest.scope)
                        .ignoresSafeArea()
                }
                // Fallback hidden NavigationLink to push EditParts when creating a new record.
                .background(
                    NavigationLink(isActive: $isPushingNewRecord) {
                        Group {
                            if let item = newRecordToEdit {
                                EditParts(mxParts: item, startEditing: true)
                            } else {
                                EmptyView()
                            }
                        }
                    } label: {
                        EmptyView()
                    }
                    .hidden()
                )
        }
			
    }

    // MARK: - Actions

    /// Creates and inserts a new `MxParts1` record, saves it, and triggers
    /// programmatic navigation into `EditParts` in editing mode.
    private func addNewRecord() {
        guard entitlements.requestCreate(MxParts1.self, in: modelContext) else { return }
        let newRecord = MxParts1(
            inactive: false,
            createdAt: Date(),
            updatedAt: Date(),
            vehicleId: trackVehicleSelected == "All Vehicles" ? "" : trackVehicleSelected,
            vehicleSystem: "",
            partName: "(New Part)",
            partNumber: "",
            partManufacture: "",
            partDescription: "",
            Notes: "",
            costPerUnit: 0,
            partUnit: "",
            partSource: "",
            partQuantity: 0,
            partLocation: "",
            partStatus: "",
            partSupplier: "",
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
            // Trigger navigation to EditParts in editing mode.
            if #available(iOS 17.0, macOS 14.0, *) {
                newRecordToEdit = newRecord
            } else {
                newRecordToEdit = newRecord
                isPushingNewRecord = true
            }
        } catch {
            // Keep this print to aid development diagnostics without surfacing to users.
            print("Failed to save book: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previews

#Preview("DisplayParts - Seeded") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle8.self, MxParts1.self, configurations: config)
    let ctx = container.mainContext

    // Seed vehicles
    let truck = Vehicle8()
    truck.name = "Big Red"
    truck.displayName = "Big Red"
    truck.year = 2021
    truck.manufacturer = "Ford"
    truck.model = "F-250"
    truck.fuelType = "Diesel"
    truck.fuelCapacity = 48
    truck.mileage = 42500
    ctx.insert(truck)

    let van = Vehicle8()
    van.name = "White Van"
    van.displayName = "White Van"
    van.year = 2019
    van.manufacturer = "Ford"
    van.model = "Transit"
    van.fuelType = "Gasoline"
    van.fuelCapacity = 25
    van.mileage = 88000
    ctx.insert(van)

    // Seed parts
    let partsData: [(vehicle: String, system: String, name: String, number: String, make: String, qty: Int, cost: Float, status: String, supplier: String)] = [
        ("Big Red",  "Engine",       "Oil Filter",          "PH3593A",  "Fram",       2,  12.99, "In Stock",  "AutoZone"),
        ("Big Red",  "Engine",       "Air Filter",          "CA10755",  "Fram",       1,   9.49, "In Stock",  "AutoZone"),
        ("Big Red",  "Transmission", "Transmission Filter", "TF271",    "WIX",        1,  22.00, "Ordered",   "Rock Auto"),
        ("Big Red",  "Brakes",       "Front Brake Pads",    "D1453",    "Wagner",     1,  48.50, "In Stock",  "O'Reilly"),
        ("Big Red",  "Belts/Hoses",  "Serpentine Belt",     "K060882",  "Gates",      1,  31.75, "Low Stock", "NAPA"),
        ("White Van","Engine",       "Spark Plug Set",      "5224",     "NGK",        8,   3.99, "In Stock",  "AutoZone"),
        ("White Van","Brakes",       "Rear Brake Rotors",   "BR900835", "Raybestos",  2,  54.00, "In Stock",  "Rock Auto"),
    ]

    for p in partsData {
        let part = MxParts1(
            vehicleId: p.vehicle,
            vehicleSystem: p.system,
            partName: p.name,
            partNumber: p.number,
            partManufacture: p.make,
            partDescription: "",
            Notes: "",
            costPerUnit: p.cost,
            partUnit: "each",
            partSource: "",
            partQuantity: p.qty,
            partLocation: "Shop Shelf",
            partStatus: p.status,
            partSupplier: p.supplier
        )
        ctx.insert(part)
    }

    return NavigationStack {
        DisplayParts(trackVehicleSelected: .constant("Big Red"))
    }
    .modelContainer(container)
}

#Preview("DisplayParts - Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle8.self, MxParts1.self, configurations: config)
    let ctx = container.mainContext

    let truck = Vehicle8()
    truck.name = "Big Red"
    truck.displayName = "Big Red"
    truck.year = 2021
    ctx.insert(truck)

    return NavigationStack {
        DisplayParts(trackVehicleSelected: .constant("All Vehicles"))
    }
    .modelContainer(container)
}


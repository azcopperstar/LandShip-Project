//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//
//  Overview
//  --------
//  DisplayRecords is the primary list view for ServiceRecords1. It shows all service
//  records for the currently selected vehicle (or all vehicles) and lets the user:
//  - Change the vehicle scope via a shared PickerVehicle control.
//  - Sort the records using several sort orders.
//  - Create a new service record that is prefilled with the selected vehicle’s current
//    odometer (mileage) and engine hours.
//  - Navigate to an EditRecord view to view or edit an existing record.
//  - Open a PDF report in the detail column (when used inside a NavigationSplitView).
//
//  Key Concepts
//  ------------
//  - trackVehicleSelected (Binding): The selected vehicle’s name shared across views.
//    When "All Vehicles" is selected, the list shows records for all vehicles. Otherwise,
//    it filters to the matching Vehicle8.name.
//  - SwiftData: Uses @Query for Vehicle8 and a QueryView wrapper for fetching and
//    sorting ServiceRecords1. modelContext is used to insert and save new records.
//  - Sorting: The PartsSort enum provides multiple SortDescriptor configurations to
//    present records differently (by date, by name, recently updated, etc.).
//  - Programmatic Navigation: A NavigationLink with isActive drives showing the PDF
//    report in the detail column. A navigationDestination drives opening EditRecord
//    immediately after adding a new record.
//  - Settings/Units: PrefsFunctions is used to load unit strings (e.g., mi, km) for
//    display without persisting them in @State here.
//
//  File Layout
//  -----------
//  - Imports
//  - View: DisplayRecords
//    - Dependencies and shared helpers
//    - State (selection, navigation, sorting)
//    - Body: header toolbar, PDF link, QueryView list, sort menu, add button
//    - Filtering predicate for records
//    - Navigation to edit newly created record
//    - addNewRecord(): creates a new record prefilled from the selected vehicle
//  - Array safe subscript helper
//  - Previews with in-memory ModelContainer and seeded data
//

import SwiftUI
import SwiftData

struct DisplayRecords: View {
	// MARK: - Data sources and environment
	
	// Live list of vehicles for the vehicle scope picker and general lookups
	@Query var vehicles: [Vehicle8]
	
	// SwiftData context used to insert, save, and fetch data
	@Environment(\.modelContext) var modelContext
	
	// For optional list selection (not strictly required for navigation, but useful on macOS)
	@State private var selectedRecord: ServiceRecords1?
	
	// Shared utility helpers
	let functions: Functions = Functions()
	
	// Access settings (units)
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// Cached settings array (units), fetched once on appear rather than per-row.
	@State private var cachedSettingsArray: [String] = Array(repeating: "", count: 13)

	// Helper to read unit strings from the cached settings array.
	private func unit(_ index: Int) -> String {
		cachedSettingsArray[safe: index] ?? ""
	}

	// Loads (or refreshes) the cached settings array once.
	private func loadCachedSettings() {
		cachedSettingsArray = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)
	}
	
	// Tracks whether "All Vehicles" is selected; used to disable or alter certain UI affordances
	@State private var allVehiclesSelected: Bool = true
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// MARK: - Vehicle selection shared across views
	
	// The selected vehicle scope. When "All Vehicles", the list shows all records.
	// Otherwise, it filters to records where ServiceRecords1.vehicleId == this value.
	@Binding var trackVehicleSelected: String

	// Local binding for ModelPicker<Vehicle8>, kept in sync with trackVehicleSelected.
	@State private var selectedVehicle: Vehicle8?

	// MARK: - Navigation state
	
	// Used to navigate programmatically to EditRecord immediately after creating a new record
	@State private var newRecordToEdit: ServiceRecords1?
	
	// Navigation to PDF report with a frozen scope to avoid feedback loops
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?

	// MARK: - Save error feedback
	@State private var showRecordSaveError = false
	@State private var recordSaveErrorMessage: String?

	// MARK: - Sorting
	
	// Sort options for the records list. Each case defines a set of SortDescriptors.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Records A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Records Z–A"
		case nameAsc = "Records A–Z"
		case nameDesc = "Records Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		// Translate each sort mode into SwiftData SortDescriptors on ServiceRecords1
		var descriptors: [SortDescriptor<ServiceRecords1>] {
			switch self {
				case .dateDesc:
					return [ .init(\.mxDate, order: .reverse) ]
				case .dateAsc:
					return [ .init(\.mxDate, order: .forward) ]
				case .datedDesc_vehicleAsc:
					return [.init(\.vehicleId, order: .forward), .init(\.mxDate, order: .reverse)]
				case .vehicleAsc_nameAsc:
					return [.init(\.vehicleId, order: .forward), .init(\.mxName, order: .forward)]
				case .vehicleAsc_nameDesc:
					return [.init(\.vehicleId, order: .forward), .init(\.mxName, order: .reverse)]
				case .nameAsc:
					return [ .init(\.mxName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.mxName, order: .reverse) ]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	
	// Current sort selection; defaults to vehicle A–Z and date descending
	@AppStorage("sort_records") private var selectedSort: PartsSort = .dateDesc
	
	// MARK: - Body
	
	var body: some View {
		
		// Vehicle scope picker using the same ModelPicker pattern as in EditRecord.
		ModelPicker(
			selection: $selectedVehicle,
			title: "",
			includeEmptyChoice: true,
			emptyChoiceLabel: "All Vehicles",
			autoSelectFirst: false,
			filter: nil,
			sort: [SortDescriptor(\.displayName, order: .forward)],
			labelProvider: { v in "\(v.year) \(v.displayName)"},
			thumbnailData: { $0.image1 }
		)
		.frame(maxWidth: .infinity)
		.onChange(of: selectedVehicle) { _, newVehicle in
			// Sync shared string binding from object selection
			trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
			allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
		}
		.onChange(of: trackVehicleSelected) { _, newValue in
			// Keep local object selection in sync if some other view changes the binding
			allVehiclesSelected = (newValue == "All Vehicles")
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
			// Seed initial states
			allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
			if trackVehicleSelected != "All Vehicles" {
				selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
			} else {
				selectedVehicle = nil
			}
			// Fetch unit settings once rather than per-row in `unit(_:)`
			loadCachedSettings()
		}
		.safeAreaInset(edge: .top) {
			PageTitle_Col2_NoPhoto(label: "SERVICE")
		}


		// Main records list. QueryView fetches ServiceRecords1 with the selected sort order.
		QueryView(for: ServiceRecords1.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
				// Empty state with a helpful CTA to add the first record
				List {
					EmptyStateSection(
						title: "Add your first Service Record",
						systemImage: "wrench.and.screwdriver.fill",
						description: "Create a Service Record to track service, maintenance, and repairs.\n\nTo add additional records after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Service Record",
						action: { addNewRecord() }
					)
				}
			} else {
				// Populated state: list of service records
				Section {
					List(selection: $selectedRecord) {
						ForEach(records) { record in
							// Row -> EditRecord detail navigation
							NavigationLink {
								EditRecord(serviceRecords1: record)
									.id(record.id) // Ensures split view updates details when a new row is selected
							} label: {
								// Row presentation: date, odometer + units, vehicle name, and record name (no photo)
								let mxDate = functions.formatDate_DDMMMyy(date: record.mxDate)
								HStack {
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
										Text("\(mxDate)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
										if record.Miles != 0 {
											Text("\(record.Miles) \(unit(UnitIndex.distance))")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if record.engHours != 0 {
											Text("\(record.engHours.formatted(.number.precision(.fractionLength(1)))) hrs")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if !record.customMeasureLabel.isEmpty {
											Text("\(record.customMeasureLabel): \(record.customMeasureValue.formatted(.number.precision(.fractionLength(1)))) \(record.customMeasureUnit)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if trackVehicleSelected == "All Vehicles" {
											Text("\(Functions().getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext))")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if !record.vendor.isEmpty {
											Text("\(record.vendor)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
								}
							}
						}
					}
					.toolbar {
						// Open PDF report for the current scope (detail column)
						ToolbarItem(placement: .automatic) {
							Button {
								// Freeze the current scope and navigate
								let frozen = trackVehicleSelected
								print("reportVehicleScope (frozen): \(frozen)")
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
						// Sort menu: presents all sort cases via a Picker
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
							.accessibilityLabel("Sort records")
						}
						if !allVehiclesSelected {
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

				} header: {
					// Compact descriptor of the active sort order
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
			// SwiftData predicate applied by QueryView:
			// - If showInactiveVehicles is true, include inactive and active records.
			// - Otherwise, exclude inactive records.
			// - Vehicle scope: If "All Vehicles", show all matching records; otherwise, only for the selected vehicle.
			#Predicate { item in
				(showInactiveVehicles || !item.inactive) && (
					trackVehicleSelected == "All Vehicles"
					|| item.vehicleId == trackVehicleSelected
				)
			}
		}
		// Destination used for programmatic navigation after adding a record
		.navigationDestination(item: $newRecordToEdit) { record in
			EditRecord(serviceRecords1: record, startEditing: true)
		}
		// Destination used to show the PDF report programmatically with a frozen scope
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportService(trackVehicleSelected: dest.scope)
				.ignoresSafeArea()
		}
		.alert("Couldn't Save", isPresented: $showRecordSaveError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(recordSaveErrorMessage ?? "")
		}
	}
	
	// MARK: - Record creation
	
	/// Creates a new ServiceRecords1 for the selected vehicle and navigates to edit it.
	/// Behavior:
	/// - Requires a specific vehicle selection (not "All Vehicles").
	/// - Prefills Miles and engHours from the selected Vehicle8 (by name).
	/// - Inserts and saves the record in the SwiftData modelContext.
	/// - Triggers programmatic navigation to EditRecord in editing mode.
	private func addNewRecord() {
		// Only allow when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }
		
		// Prefill current odometer and engine hours from the selected vehicle
		// loadVehicleDetails looks up a Vehicle8 by name (vehicleId) and returns a lightweight struct.
		let details = functions.loadVehicleDetails(context: modelContext, vehicleId: trackVehicleSelected)
		let currentMiles = details?.mileage ?? 0
		let currentHours = details?.engHours ?? 0
		
		let newRecord = ServiceRecords1(
			inactive: false,
			createdAt: Date(),
			updatedAt: Date(),
			mxDate: Date(),
			vehicleId: trackVehicleSelected,
			Miles: currentMiles,
			engHours: currentHours,
			mxName: "(New Service Record)",
			mxItemId: "",
			mxDescription: "",
			Notes: "",
			vendor: "",
			laborCost: 0,
			part1: "",
			part1cost: 0,
			part1Unit: "",
			part1Quantity: 0,
			part2: "",
			part2cost: 0,
			part2Unit: "",
			part2Quantity: 0,
			part3: "",
			part3cost: 0,
			part3Unit: "",
			part3Quantity: 0,
			part4: "",
			part4cost: 0,
			part4Unit: "",
			part4Quantity: 0,
			part5: "",
			part5cost: 0,
			part5Unit: "",
			part5Quantity: 0,
			image: nil,
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
			// Navigate to EditRecord in edit mode
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save service record: \(error.localizedDescription)")
			recordSaveErrorMessage = error.localizedDescription
			showRecordSaveError = true
		}
	}
}


// MARK: - Previews
// Previews build an in-memory model container, seed sample data, and demonstrate the list
// both for "All Vehicles" and for a single vehicle selection.

#Preview("DisplayRecords – Seeded Data") {
	@MainActor
	func makeContainer() -> ModelContainer {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		return try! ModelContainer(for: Vehicle8.self, ServiceRecords1.self, Settings1.self, configurations: config)
	}
	
	let container = makeContainer()
	let context = container.mainContext

	// Seed vehicles
	let vehicleA = Vehicle8(name: "Vehicle A", year: 2021, mileage: 12050, engHours: 12.5, fuelType: "Gasoline", fuelCapacity: 26)
	let vehicleB = Vehicle8(name: "Vehicle B", year: 2019, mileage: 5400, engHours: 4.0, fuelType: "Diesel", fuelCapacity: 32)
	context.insert(vehicleA)
	context.insert(vehicleB)

	// Helper to build sample service records
	func makeService(vehicleId: String, daysAgo: Int, miles: Int, hours: Float, item: String, desc: String, vendor: String, labor: Float, parts: [(String, Float, String, Int)], notes: String) -> ServiceRecords1 {
		let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
		let p1 = parts.indices.contains(0) ? parts[0] : ("", 0, "", 0)
		let p2 = parts.indices.contains(1) ? parts[1] : ("", 0, "", 0)
		let p3 = parts.indices.contains(2) ? parts[2] : ("", 0, "", 0)
		let p4 = parts.indices.contains(3) ? parts[3] : ("", 0, "", 0)
		let p5 = parts.indices.contains(4) ? parts[4] : ("", 0, "", 0)
		return ServiceRecords1(
			createdAt: date,
			updatedAt: date,
			mxDate: date,
			vehicleId: vehicleId,
			Miles: miles,
			engHours: hours,
			mxName: item,
			mxItemId: "",
			mxDescription: desc,
			Notes: notes,
			vendor: vendor,
			laborCost: labor,
			part1: p1.0, part1cost: Float(p1.1), part1Unit: p1.2, part1Quantity: p1.3,
			part2: p2.0, part2cost: Float(p2.1), part2Unit: p2.2, part2Quantity: p2.3,
			part3: p3.0, part3cost: Float(p3.1), part3Unit: p3.2, part3Quantity: p3.3,
			part4: p4.0, part4cost: Float(p4.1), part4Unit: p4.2, part4Quantity: p4.3,
			part5: p5.0, part5cost: Float(p5.1), part5Unit: p5.2, part5Quantity: p5.3,
			image: nil,
			image1: nil, image1Description: "",
			image2: nil, image2Description: "",
			image3: nil, image3Description: ""
		)
	}

	// Seed service records
	let samples: [ServiceRecords1] = [
		makeService(vehicleId: "Vehicle A", daysAgo: 0, miles: 12050, hours: 12.5, item: "Oil Change", desc: "Changed engine oil and filter. Checked belts and hoses.", vendor: "Joe's Garage", labor: 120, parts: [("Oil Filter", 8.5, "ea", 1), ("5W-30", 7.0, "qt", 5)], notes: "Next change in 3 months."),
		makeService(vehicleId: "Vehicle A", daysAgo: 15, miles: 11820, hours: 10.0, item: "Brake Service", desc: "Replaced front pads, resurfaced rotors.", vendor: "BrakeCo", labor: 200, parts: [("Front Pads", 45.0, "set", 1), ("Brake Cleaner", 4.5, "can", 1)], notes: "Slight squeal at low speed observed."),
		makeService(vehicleId: "Vehicle B", daysAgo: 5, miles: 5400, hours: 4.0, item: "Battery", desc: "Replaced battery and cleaned terminals.", vendor: "AutoParts", labor: 60, parts: [("Battery Group 24", 110.0, "ea", 1)], notes: "Starts faster.")
	]
	samples.forEach { context.insert($0) }

	// Seed settings so unit(UnitIndex.distance) resolves
	let settings = Settings1()
	settings.userName = "primary1"
	settings.unitVolumeFuel = "gal"
	settings.unitVolumeOil = "qt"
	settings.unitVolumeDEF = "gal"
	settings.unitTemp = "°F"
	settings.unitSpeed = "mph"
	settings.unitPressure = "PSI"
	settings.unitMass = "lb"
	settings.unitDistance = "mi"
	settings.unitArea = "ft²"
	settings.unitLength = "ft"
	settings.unitWidth = "ft"
	settings.unitHeight = "ft"
	settings.unitWheelBase = "in"
	context.insert(settings)

	try? context.save()

	// Binding for the selected vehicle in the preview
	let selection = State(initialValue: "All Vehicles")

	return NavigationStack {
		DisplayRecords(trackVehicleSelected: selection.projectedValue)
			.modelContainer(container)
			.navigationTitle("Service Records")
	}
}

#Preview("DisplayRecords – Vehicle A Only") {
	@MainActor
	func makeContainer() -> ModelContainer {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		return try! ModelContainer(for: Vehicle8.self, ServiceRecords1.self, Settings1.self, configurations: config)
	}
	
	let container = makeContainer()
	let context = container.mainContext

	// Vehicles
	let vehicleA = Vehicle8(name: "Vehicle A", year: 2021, mileage: 12050, engHours: 12.5, fuelType: "Gasoline", fuelCapacity: 26)
	let vehicleB = Vehicle8(name: "Vehicle B", year: 2019, mileage: 5400, engHours: 4.0, fuelType: "Diesel", fuelCapacity: 32)
	context.insert(vehicleA)
	context.insert(vehicleB)

	// Records (only A)
	let now = Date()
	let rec1 = ServiceRecords1(createdAt: now, updatedAt: now, mxDate: now, vehicleId: "Vehicle A", Miles: 12050, engHours: 12.5, mxName: "Alignment", mxItemId: "", mxDescription: "4-wheel alignment", Notes: "Tracks straight", vendor: "Tires Plus", laborCost: 89.0, part1: "", part1cost: 0, part1Unit: "", part1Quantity: 0, image: nil)
	let rec2 = ServiceRecords1(createdAt: now.addingTimeInterval(-7*86400), updatedAt: now.addingTimeInterval(-7*86400), mxDate: now.addingTimeInterval(-7*86400), vehicleId: "Vehicle A", Miles: 11900, engHours: 11.9, mxName: "Cabin Filter", mxItemId: "", mxDescription: "Replaced cabin air filter", Notes: "", vendor: "DIY", laborCost: 0, part1: "Cabin Filter", part1cost: 15.0, part1Unit: "ea", part1Quantity: 1, image: nil)
	context.insert(rec1)
	context.insert(rec2)

	// Settings
	let settings = Settings1(userName: "primary1", unitVolumeFuel: "gal", unitVolumeOil: "qt", unitVolumeDEF: "gal", unitTemp: "°F", unitSpeed: "mph", unitPressure: "PSI", unitMass: "lb", unitLength: "ft", unitWidth: "ft", unitHeight: "ft", unitWheelBase: "in")
	settings.unitDistance = "mi"
	context.insert(settings)

	try? context.save()

	let selection = State(initialValue: "Vehicle A")

	return NavigationStack {
		DisplayRecords(trackVehicleSelected: selection.projectedValue)
			.modelContainer(container)
			.navigationTitle("Service Records")
	}
}


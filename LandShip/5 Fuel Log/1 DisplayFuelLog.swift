//
//  DisplayFuelLog.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//
//  Overview:
//  DisplayFuelLog is a SwiftUI view that lists FuelLog1 records and allows users to:
//  - Filter by a specific vehicle (or show all vehicles)
//  - Sort fuel logs by multiple criteria (date, vehicle, name, updated time)
//  - Create a new fuel log for the currently selected vehicle
//  - Navigate to edit an existing fuel log
//  - Generate and view a PDF report for the current selection
//
//  Key Concepts:
//  - Uses SwiftData (ModelContext, @Query) to fetch and manage persistent data.
//  - Uses a custom ModelPicker to select a vehicle and to optionally include inactive vehicles.
//  - Supports programmatic navigation to a newly created record for immediate editing.
//  - Applies additional in-memory filtering to hide logs associated with inactive vehicles (when configured).
//  - Employs a query-level predicate to constrain results by selected vehicle, improving performance.
//
//  Notes:
//  - The view relies on a binding (trackVehicleSelected) to synchronize the selected vehicle across views.
//  - The Add button is disabled unless a single, specific vehicle is selected (not "All Vehicles").
//  - The PDF report is presented using navigationDestination with a boolean state flag.
//

import SwiftUI
import SwiftData

/// A view that displays and manages fuel logs.
///
/// Responsibilities:
/// - Presents a list of `FuelLog1` items with optional sorting and filtering.
/// - Synchronizes selected vehicle across the app via `trackVehicleSelected`.
/// - Creates new logs seeded with sensible defaults from the selected vehicle and last fuel log.
/// - Provides navigation to edit an existing or newly added record.
/// - Presents a PDF report for the current vehicle selection.
///
/// Dependencies:
/// - SwiftData model types: `Vehicle8` and `FuelLog1`.
/// - Utility helpers: `Functions`, `PrefsFunctions` and custom views (e.g., `ModelPicker`, `QueryView`).
struct DisplayFuelLog: View {
	/// All vehicles loaded from the store. Used for filtering logic and to derive inactive vehicle names.
	@Query var vehicles: [Vehicle8]
	/// SwiftData context used for fetching, inserting, and saving records.
	@Environment(\.modelContext) var modelContext
	/// Tracks the selection in the list for highlighting and navigation purposes.
	@State private var selectedRecord: FuelLog1?
	/// User preference persisted in App Storage to include or exclude inactive vehicles from pickers and lists.
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	/// Utility functions for date formatting and other helpers.
	let functions: Functions = Functions()
	/// Preferences helper used to load settings (mirrors usage in pdfReportService).
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	/// Helper to read unit strings without @State; protects against missing settings
	private func unit(_ index: Int) -> String {
		let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)
		return arr[safe: index] ?? ""
	}

	/// True when "All Vehicles" is selected; used to disable actions that require a specific vehicle (e.g., Add).
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button

	/// A shared selection string for the currently chosen vehicle name (or "All Vehicles"), synchronized with other views.
	@Binding var trackVehicleSelected: String

	/// Legacy/auxiliary sort descriptor for vehicle ID; retained for compatibility with QueryView usage.
	@State private var sortVehicle: SortDescriptor<FuelLog1> = .init(\.vehicleId, order: .forward) /// for QueryView
	/// Sort descriptor for date-based ordering (newest first) when needed by QueryView.
	@State private var sortDate: SortDescriptor<FuelLog1> = .init(\.fuelDateTime, order: .reverse) /// for QueryView

	/// Controls presentation of the PDF report destination.
	@State private var isShowingPDFReport: Bool = false
	
	/// When a new record is created, setting this triggers navigation to its edit screen.
	@State private var newRecordToEdit: FuelLog1?
	/// Backing model for the vehicle picker; kept in sync with `trackVehicleSelected`.
	@State private var selectedVehicle: Vehicle8? = nil
	
	/// Navigation to PDF report with a frozen scope to avoid feedback loops
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?

	/// Sorting options for the list of fuel logs. Each case maps to one or more `SortDescriptor` values.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Fuel Log A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Fuel Log Z–A"
		case nameAsc = "Fuel Log A–Z"
		case nameDesc = "Fuel Log Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<FuelLog1>] {
			switch self {
				case .dateDesc:
					return [ .init(\.fuelDateTime, order: .reverse) ]
				case .dateAsc:
					return [ .init(\.fuelDateTime, order: .forward) ]
				case .datedDesc_vehicleAsc:
					return [.init(\.vehicleId, order: .forward),.init(\.fuelDateTime, order: .reverse)]
				case .vehicleAsc_nameAsc:
					return [.init(\.vehicleId, order: .forward),.init(\.logName, order: .forward)]
				case .vehicleAsc_nameDesc:
					return [.init(\.vehicleId, order: .forward),.init(\.logName, order: .reverse)]
				case .nameAsc:
					return [ .init(\.logName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.logName, order: .reverse) ]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	
	@AppStorage("sort_fuellog") private var selectedSort: PartsSort = .dateDesc
	
	/// Main view hierarchy: vehicle picker, sorted/filterable list, toolbars, and navigation destinations.
	var body: some View {
		// Root container to keep layout simple and to scope toolbar/navigation modifiers.
		Group {
			// Custom model picker to choose a specific vehicle or "All Vehicles" (empty choice).
			// The `filter` respects `showInactiveVehicles` to optionally hide inactive items.
			ModelPicker(
				selection: $selectedVehicle,
				title: "",
				includeEmptyChoice: true,
				emptyChoiceLabel: "All Vehicles",
				autoSelectFirst: false,
				filter: showInactiveVehicles ? nil : #Predicate { !$0.inactive },
				sort: [SortDescriptor(\.displayName, order: .forward)],
				labelProvider: { v in "\(v.year) \(v.displayName)"},
			)
			.frame(maxWidth: .infinity)
			// Keep the external binding (`trackVehicleSelected`) and the Add button state aligned with the picker selection.
			.onChange(of: selectedVehicle) { _, newVehicle in
				if let v = newVehicle {
					trackVehicleSelected = v.name
					allVehiclesSelected = false
				} else {
					trackVehicleSelected = "All Vehicles"
					allVehiclesSelected = true
				}
			}
			// Reflect external changes (from other views) back into this view's `selectedVehicle` and control state.
			.onChange(of: trackVehicleSelected) { _, newValue in
				if newValue == "All Vehicles" || newValue.isEmpty {
					allVehiclesSelected = true
					selectedVehicle = nil
				} else {
					allVehiclesSelected = false
					// Keep selectedVehicle synced when the binding changes externally
					do {
						var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == newValue })
						fd.fetchLimit = 1
						if let v = try modelContext.fetch(fd).first {
							selectedVehicle = v
						} else {
							selectedVehicle = nil
						}
					} catch {
						selectedVehicle = nil
					}
				}
			}
			// Seed initial selection from the inbound binding and load persisted settings.
			.onAppear {
				// Sync allVehiclesSelected and seed ModelPicker selection from the incoming binding
				if trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty {
					allVehiclesSelected = true
					selectedVehicle = nil
				} else {
					allVehiclesSelected = false
					// Seed selectedVehicle from the current trackVehicleSelected string
					do {
						var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == trackVehicleSelected })
						fd.fetchLimit = 1
						if let v = try modelContext.fetch(fd).first {
							selectedVehicle = v
						} else {
							selectedVehicle = nil
						}
					} catch {
						selectedVehicle = nil
					}
				}
				// Load settings as an array (same approach as pdfReportService)
				let _ = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
					?? Array(repeating: "", count: 13)
			}
			.safeAreaInset(edge: .top) {
				PageTitle_Col2_NoPhoto(label: "FUEL LOGS")
			}

			// Fetch and display FuelLog1 records, applying sort descriptors from the user's selection.
			QueryView(for: FuelLog1.self, sort: selectedSort.descriptors) {records in
				// Additional in-memory filtering: optionally exclude logs tied to inactive vehicles and any log flagged inactive.
				let filteredRecords: [FuelLog1] = {
						if !showInactiveVehicles {
								let inactiveVehicleNames: Set<String> = Set(vehicles.filter { $0.inactive }.map { $0.name })
								return records.filter { record in
										!record.inactive && !inactiveVehicleNames.contains(record.vehicleId)
								}
						} else {
								return records
						}
				}()
				// Empty state encourages the user to create their first fuel log with helpful instructions.
				if filteredRecords.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first Fuel Log",
							systemImage: "fuelpump.arrowtriangle.left",
							description: "Create a Fuel Log to track fuel, oil and DEF records.\n\nTo add additional logs after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Fuel Log",
							action: { addNewRecord() }
						)
					}
				} else {
					// Main list of fuel logs with navigation to edit screens and controls in the toolbar.
					Section {
						List(selection: $selectedRecord) {
							ForEach(filteredRecords) { record in
								// Navigate to edit the tapped record. `.id(record.id)` ensures split view updates when selection changes.
								NavigationLink {
									EditFuelLog(dataSet: record)
										.id(record.id) // <<< work-around to get splitview to change details when selected
								} label: {
									let mxDate = functions.formatDate_DDMMMyy(date:record.fuelDateTime)
									HStack{
//										let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
//										Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
										VStack(alignment: .leading, spacing: 1) {
											Text("\(record.logName)")
												.font(.headline)
											Text("Date: \(mxDate)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
											Text("Odometer: \(record.odometer)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
											if record.fuelAdded != 0 {
												Text("Fuel: \(record.fuelAdded.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) · \(record.fuelCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) · \(record.fuelPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))/\(unit(UnitIndex.fuel))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if record.defAdded != 0 {
												Text("DEF: \(record.defAdded.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.def)) · \(record.defPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))/\(unit(UnitIndex.def))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if trackVehicleSelected == "All Vehicles" {
												Text("\(Functions().getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if !record.location.isEmpty {
												Text("\(record.location)")
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
							// Open the PDF report for the current vehicle selection.
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
							// Sorting menu to choose among predefined sort orders.
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
							// Create a new fuel log for the currently selected vehicle. Disabled when "All Vehicles" is selected.
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
									.disabled(allVehiclesSelected)
									.help("Add")
									.accessibilityLabel("Add")
								}
							}
						}
					} header: {
						// Header reflects the active sort selection plus totals for the currently listed records.
						let totalFuel = filteredRecords.reduce(Float(0)) { $0 + $1.fuelAdded }
						let totalCost = filteredRecords.reduce(Float(0)) { $0 + $1.fuelCost }
						let avgPrice: Float = totalFuel > 0 ? totalCost / totalFuel : 0
						// Distance/economy only make sense for a single vehicle's odometer trail.
						let sortedByDate = filteredRecords.sorted { $0.fuelDateTime < $1.fuelDateTime }
						let totalDistance = (trackVehicleSelected != "All Vehicles" && sortedByDate.count > 1)
							? max(0, (sortedByDate.last?.odometer ?? 0) - (sortedByDate.first?.odometer ?? 0))
							: 0
						let avgEconomy: Float = totalFuel > 0 ? Float(totalDistance) / totalFuel : 0
						VStack(alignment: .leading, spacing: 2) {
							HStack(spacing: 6) {
								Image(systemName: "arrow.up.arrow.down")
								Text("Sort: \(selectedSort.rawValue)")
							}
							if totalFuel > 0 {
								Text("Total Fuel: \(totalFuel.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.fuel)) · Total Cost: \(totalCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) · Avg: \(avgPrice.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))/\(unit(UnitIndex.fuel))")
							}
							if totalDistance > 0 {
								Text("Distance: \(totalDistance) \(unit(UnitIndex.distance)) · Avg Economy: \(avgEconomy.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))")
							}
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 4)
					}
				}
			} filter: {
				// Query-level filter: if a specific vehicle is selected, constrain results by vehicleId; otherwise return all.
				#Predicate { item in
					if trackVehicleSelected == "All Vehicles" {
						true
					} else {
						item.vehicleId.contains(trackVehicleSelected)
					}
				}
			}
		}
		// Presents the PDF report in the detail column when requested.
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportFuel(trackVehicleSelected: .constant(dest.scope))
				.id("FuelReport-\(dest.scope)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		}
		// After creating a new record, navigate directly to its edit screen in editing mode.
		.navigationDestination(item: $newRecordToEdit) { record in
			EditFuelLog(dataSet: record, startEditing: true)
				.id(record.id)
		}
	}
	
	/// Creates a new `FuelLog1` for the currently selected vehicle.
	///
	/// The function:
	/// - Requires a specific vehicle selection (not "All Vehicles").
	/// - Seeds odometer, engine hours, fuel capacity/type from the selected vehicle.
	/// - Carries forward the last known fuel price for convenience.
	/// - Inserts and saves the new record, then navigates to its edit screen.
	private func addNewRecord() {
		// Ensure a specific vehicle is selected before allowing creation.
		guard !trackVehicleSelected.isEmpty, !allVehiclesSelected else { return }

		// Fetch the selected vehicle's properties to prefill the new log with sensible defaults.
		var odometerVehicle: Int = 0
		var engHoursVehicle: Float = 0.0
		var fuelCapacityVehicle: Int = 0
		var fuelTypeVehicle: String = ""

		do {
			var vehicleFetch = FetchDescriptor<Vehicle8>(
				predicate: #Predicate { fetchModel in fetchModel.name == trackVehicleSelected }
			)
			vehicleFetch.fetchLimit = 1

			if let vehicle = try modelContext.fetch(vehicleFetch).first {
				odometerVehicle = vehicle.mileage
				engHoursVehicle = vehicle.engHours
				fuelCapacityVehicle = vehicle.fuelCapacity
				fuelTypeVehicle = vehicle.fuelType
			}
		} catch {
			// If vehicle fetch fails, we still proceed with sensible defaults
			print("Failed to fetch vehicle '\(trackVehicleSelected)': \(error.localizedDescription)")
		}
		
		// Look up the most recent fuel log for this vehicle to carry forward its fuel price.
		var fuelPrice: Float = 0.0
		var defPrice: Float = 0.0
		do {
			var lastFuelFetch = FetchDescriptor<FuelLog1>(
				predicate: #Predicate { fetchModel in fetchModel.vehicleId == trackVehicleSelected },
				sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)]
			)
			lastFuelFetch.fetchLimit = 1
			if let lastLog = try modelContext.fetch(lastFuelFetch).first {
				fuelPrice = lastLog.fuelPrice
				defPrice = lastLog.defPrice
			}
		} catch {
			print("Failed to fetch last fuel log for '\(trackVehicleSelected)': \(error.localizedDescription)")
		}

		// Compose a default name and instantiate the new `FuelLog1` with prefilled values.
		let logName = "Fuel Log: " + functions.formatDate_DDMMMyy_HHmm(date: Date())
		let newRecord = FuelLog1(
			vehicleId: trackVehicleSelected,
			logName: logName,
			fuelNotes: "",
			createdAt: Date(),
			updatedAt: Date(),
			fuelDateTime: Date(),
			odometer: odometerVehicle,
			location: "",
			engHours: engHoursVehicle,
			fuelQuantityStart: Float(fuelCapacityVehicle) * 0.25,
			fuelQuantityEnd: Float(fuelCapacityVehicle),
			fuelAdded: 0.0,
			defAdded: 0.0,
			defPrice: defPrice,
			oilAdded: 0.0,
			fuelLevelStart1: 0.25,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/4",
			fuelLevelEnd: "Full",
			fuelPrice: fuelPrice,
			fuelCost: 0.0,
			fuelType: fuelTypeVehicle,
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)

		// Persist the new record and prepare navigation to its edit screen.
		modelContext.insert(newRecord)
		do {
			try modelContext.save()
			// reflect selection in the list (optional)
			selectedRecord = newRecord
			// trigger navigation to edit this new record
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save new fuel log: \(error.localizedDescription)")
		}
	}
}

/// Safe index helper for arrays to avoid out-of-bounds crashes when settings are missing.
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, FuelLog1.self, configurations: config)
	let ctx = container.mainContext

	// Seed a vehicle
	let truck = Vehicle8()
	truck.name = "Big Red"
	truck.displayName = "Big Red"
	truck.year = 2021
	truck.manufacturer = "Ford"
	truck.model = "F-250"
	truck.fuelType = "Diesel"
	truck.fuelCapacity = 48
	truck.mileage = 42500
	truck.engHours = 312.5
	ctx.insert(truck)

	// Seed fuel logs
	let calendar = Calendar.current
	let seededLogs: [(name: String, daysAgo: Int, odometer: Int, added: Float, price: Float, cost: Float)] = [
		("Fuel Log: 01 Apr 2026", 11, 42500, 32.4, 3.89, 126.04),
		("Fuel Log: 15 Mar 2026", 28, 41980, 28.1, 3.75, 105.38),
		("Fuel Log: 01 Mar 2026", 42, 41520, 35.0, 3.69, 129.15),
		("Fuel Log: 10 Feb 2026", 61, 40900, 29.6, 3.55, 105.08),
	]

	for entry in seededLogs {
		let log = FuelLog1(
			vehicleId: "Big Red",
			logName: entry.name,
			fuelDateTime: calendar.date(byAdding: .day, value: -entry.daysAgo, to: Date()) ?? Date(),
			odometer: entry.odometer,
			fuelQuantityStart: 12.0,
			fuelQuantityEnd: Float(48),
			fuelAdded: entry.added,
			fuelLevelStart1: 0.25,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/4",
			fuelLevelEnd: "Full",
			fuelPrice: entry.price,
			fuelCost: entry.cost,
			fuelType: "Diesel"
		)
		ctx.insert(log)
	}

	return NavigationStack {
		DisplayFuelLog(trackVehicleSelected: .constant("Big Red"))
	}
	.modelContainer(container)
}


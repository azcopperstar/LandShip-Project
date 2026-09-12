/*
 DisplayTripLog.swift
 LandShip
 
 Created by JP on 8/12/25
 
 PURPOSE
 -------
 DisplayTripLog presents a browsable, filterable list of TripLog2 records and provides
 entry points for creating, sorting, and editing trip logs. It supports programmatic
 navigation to a new record in edit mode and a PDF report for the selected vehicle(s).
 
 RESPONSIBILITIES
 ----------------
 - Display a list of TripLog2 entries using QueryView with configurable sorting.
 - Filter by vehicle selection (via ModelPicker) and by active/inactive status.
 - Create new TripLog2 entries seeded from the most recent trip for the vehicle.
 - Navigate to EditTripLog for editing or to a PDF report view.
 
 DATA FLOW & STATE
 ------------------
 - trackVehicleSelected (Binding): The currently selected vehicle name shared with parent
   views. When set to "All Vehicles", the list shows trips for every vehicle.
 - selectedVehicle: The ModelPicker selection that mirrors trackVehicleSelected.
 - selectedSort: A user-selected sort mode that maps to an array of SortDescriptor values.
 - selectedRecord/newRecordToEdit: Control navigation to an EditTripLog instance.
 - isShowingPDFReport: Controls navigation to the PDF report destination.
 
 PERSISTENCE NOTES
 ------------------
 - SwiftData (ModelContext) is used to query and insert TripLog2 records.
 - The list is populated by QueryView with a predicate that respects the vehicle selection
   and the showInactiveVehicles app setting.
 
 UI ASSUMPTIONS
 --------------
 - Custom subviews such as ModelPicker, QueryView, LabelDataText_Toolbar, and Image_View_Thumbnail
   are available elsewhere in the project to provide consistent styling and behavior.
 */

import SwiftUI
import SwiftData

/// A SwiftUI view for listing and managing `TripLog2` records.
///
/// Features include vehicle filtering, multiple sort modes, adding a new trip (seeded
/// from the most recent record), and navigation to editing and reporting destinations.
///
/// Dependencies:
/// - `SwiftData` for persistence via `@Environment(\.modelContext)` and `@Query`
/// - `ModelPicker` for vehicle selection and synchronization with `trackVehicleSelected`
/// - Custom UI components for toolbar and list rows (thumbnails, labels)
struct DisplayTripLog: View {
    @AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@Environment(\.entitlements) private var entitlements
	@State private var selectedRecord: TripLog2?
	let functions: Functions = Functions()
	// Access settings (units) - loaded once and cached (see `loadUnits()`) instead of
	// re-querying SwiftData every time `unit(_:)` is called, which happens per visible row.
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	@State private var unitStrings: [String] = Array(repeating: "", count: 13)
	private func loadUnits() {
		unitStrings = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)
	}
	// Helper to read unit strings from the cached array
	private func unit(_ index: Int) -> String {
		unitStrings[safe: index] ?? ""
	}
	
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button

	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	@State private var sortVehicle: SortDescriptor<TripLog2> = .init(\.vehicleId, order: .forward) /// for QueryView
	@State private var sortDate: SortDescriptor<TripLog2> = .init(\.tripDateTimeStart, order: .reverse) /// for QueryView

	// Navigation to PDF report with a frozen scope to avoid feedback loops
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?

	// Programmatic navigation to EditRecord after adding
	@State private var newRecordToEdit: TripLog2?
    @State private var selectedVehicle: Vehicle8? = nil
	
	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Travel Log A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Travel Log Z–A"
		case nameAsc = "Travel Log A–Z"
		case nameDesc = "Travel Log Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }

		/// Vertical-aware display text — the persisted rawValue stays "Vehicle ..." so
		/// existing AppStorage selections keep decoding correctly.
		var displayName: String { rawValue.replacingOccurrences(of: "Vehicle", with: Vertical.current.assetSingular) }

		var descriptors: [SortDescriptor<TripLog2>] {
			switch self {
				case .dateDesc:
					return [ .init(\.tripDateTimeStart, order: .reverse) ]
				case .dateAsc:
					return [ .init(\.tripDateTimeStart, order: .forward) ]
				case .datedDesc_vehicleAsc:
					return [.init(\.vehicleId, order: .forward),.init(\.tripDateTimeStart, order: .reverse)]
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
	@AppStorage("sort_triplog") private var selectedSort: PartsSort = .dateDesc

	/// Main content that composes the vehicle filter, the trip list (via `QueryView`),
	/// and toolbar actions for sorting, reporting, and adding new records.
	var body: some View {
		Group {
			// MARK: - Vehicle Filter & Toolbar
			// Custom model picker to choose a specific vehicle or "All Vehicles" (empty choice).
			// The `filter` respects `showInactiveVehicles` to optionally hide inactive items.
			ModelPicker(
				selection: $selectedVehicle,
				title: "",
				includeEmptyChoice: true,
				emptyChoiceLabel: FleetScope.allDisplayLabel,
				autoSelectFirst: false,
				filter: showInactiveVehicles ? nil : #Predicate { !$0.inactive },
				sort: [SortDescriptor(\.displayName, order: .forward)],
				labelProvider: { v in "\(v.year) \(v.displayName)"},
				thumbnailData: { $0.image1 }
			)
			.frame(maxWidth: .infinity)
            .onChange(of: selectedVehicle) { _, newVehicle in
                let name = newVehicle?.name ?? "All Vehicles"
                trackVehicleSelected = name
                allVehiclesSelected = (name == "All Vehicles")
            }
            .onChange(of: trackVehicleSelected) {
                allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
                // Keep ModelPicker selection in sync if trackVehicleSelected changes externally
                if trackVehicleSelected == "All Vehicles" {
                    if selectedVehicle != nil { selectedVehicle = nil }
                } else {
                    // If names don't match, try to seed from the current vehicle name
                    if selectedVehicle?.name != trackVehicleSelected {
                        do {
                            var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == trackVehicleSelected })
                            fd.fetchLimit = 1
                            if let v = try modelContext.fetch(fd).first {
                                selectedVehicle = v
                            }
                        } catch {
                            // Ignore failures; leave selection as-is
                        }
                    }
                }
            }
            .onAppear {
                // Initialize both the flag and the picker selection from the incoming binding.
                allVehiclesSelected = (trackVehicleSelected == "All Vehicles")

                if trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty {
                    // No specific vehicle selected: show all vehicles and clear the picker.
                    selectedVehicle = nil
                } else if selectedVehicle == nil {
                    // Seed the picker selection from the incoming vehicle name if possible.
                    do {
                        var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == trackVehicleSelected })
                        fd.fetchLimit = 1
                        if let v = try modelContext.fetch(fd).first {
                            selectedVehicle = v
                        }
                    } catch {
                        // Non-fatal: if lookup fails, keep the picker nil and proceed.
                    }
                }
                // Load settings once and cache them for `unit(_:)` lookups in row rendering.
                loadUnits()
            }
						.safeAreaInset(edge: .top) {
							PageTitle_Col2_NoPhoto(label: "TRAVEL LOGS")
						}


			// MARK: - Trip Logs List
			QueryView(for: TripLog2.self, sort: selectedSort.descriptors) { records in
				// Precompute group totals once for this render instead of running a fresh
				// FetchDescriptor per row (see `groupTotals(for:)` below, which now just
				// looks this dictionary up by group name).
				let groupTotalsByName = groupTotalsByGroupName()
				if records.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first Travel Log",
							systemImage: "map",
							description: "Create a Travel Log to track trips taken, fuel consumed and \(Vertical.current.assetSingular.lowercased()) \(Vertical.current.primaryMeterLabel.lowercased()).\n\nTo add additional logs after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Travel Log",
							action: { addNewRecord() }
						)
					}
				} else {
					Section {
						List(selection: $selectedRecord) {
							ForEach(records) { record in
								NavigationLink {
									EditTripLog(dataSet: record)
										.id(record.id) // work-around to get splitview to change details when selected
								} label: {
									let mxDateStart = functions.formatDate_DDMMMyy_HHmm(date: record.tripDateTimeStart)
									let mxDateEnd = functions.formatDate_DDMMMyy_HHmm(date: record.tripDateTimeEnd)
									HStack {
//										let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
//										Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
										VStack(alignment: .leading, spacing: 1) {
											Text("\(record.logName)")
												.font(.headline)
											let groupTotals = record.tripGroup.isEmpty ? nil : groupTotalsByName[record.tripGroup]
											let rowDistance = groupTotals?.distance ?? (record.odometerEnd > record.odometerStart ? record.odometerEnd - record.odometerStart : 0)
											let rowFuel = groupTotals?.fuel ?? totalFuelUsed(for: record)
											if !record.tripGroup.isEmpty || rowDistance > 0 || rowFuel > 0 {
												HStack(spacing: 8) {
													if !record.tripGroup.isEmpty {
														Text("Group: \(record.tripGroup)")
													}
													if rowDistance > 0 {
														Text("\(rowDistance)\(unit(UnitIndex.distance))")
													}
													if rowFuel > 0 {
														Text("\(fuelQuantityFormatted(rowFuel))\(unit(UnitIndex.fuel))")
													}
												}
												.font(.subheadline)
												.foregroundStyle(.secondary)
											}
											Text("Start: \(mxDateStart)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
											Text("Stop: \(mxDateEnd)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
											if !movingTimeDescription(for: record).isEmpty {
												Text("\(Vertical.current.id == .aviation ? "Flight Time" : "Time Underway"): \(movingTimeDescription(for: record))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if totalFuelUsed(for: record) > 0 {
												Text("Fuel Burn: \(fuelQuantityFormatted(totalFuelUsed(for: record))) \(unit(UnitIndex.fuel))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if trackVehicleSelected == "All Vehicles" {
												Text("\(Functions().getVehicleDisplayName(vehicleId: record.vehicleId, context: modelContext))")
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
											if !routeDescription(for: record).isEmpty {
												Text(routeDescription(for: record))
													.font(.subheadline)
													.foregroundStyle(.secondary)
											}
										}
										.cardStyle(backgroundColor: .blue.opacity(0.6))
									}
								}
							}
//							.textModifier_ListDivider()
						}
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
									.help("Add")
									.accessibilityLabel("Add")
								}
							}
						}
					} header: {
						// Header reflects the active sort selection plus totals for the currently listed trips.
						let totalMiles = records.reduce(0) { $0 + max(0, $1.odometerEnd - $1.odometerStart) }
						let totalFuel = records.reduce(Float(0)) { $0 + totalFuelUsed(for: $1) }
						let avgEconomy: Double = totalFuel > 0 ? Double(totalMiles) / Double(totalFuel) : 0
						let totalUnderwaySeconds = records.reduce(0.0) { $0 + movingTimeInterval(for: $1) }
						let avgSpeed: Double = totalUnderwaySeconds > 0 ? Double(totalMiles) / (totalUnderwaySeconds / 3600.0) : 0
						VStack(alignment: .leading, spacing: 2) {
							HStack(spacing: 6) {
								Image(systemName: "arrow.up.arrow.down")
								Text("Sort: \(selectedSort.displayName)")
							}
							if totalMiles > 0 || totalFuel > 0 {
								Text("Total Miles: \(totalMiles)\(unit(UnitIndex.distance)) · Total Fuel: \(fuelQuantityFormatted(totalFuel))\(unit(UnitIndex.fuel)) · Avg Economy: \(avgEconomy.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))")
							}
							if totalUnderwaySeconds > 0 {
								Text("Time Underway: \(formattedDuration(totalUnderwaySeconds)) · Avg Speed: \(avgSpeed.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.distance))/hr")
							}
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 4)
					}
				}
			} filter: {
				#Predicate { item in
					if showInactiveVehicles {
						// Mode: Show all logs (active and inactive).
						// If no specific vehicle is selected, return all; otherwise match by vehicle name.
						if trackVehicleSelected == "All Vehicles" {
							true
						} else {
							item.vehicleId.contains(trackVehicleSelected)
						}
					} else {
						// Mode: Hide inactive logs.
						// Return all active logs or only those for the selected vehicle that are active.
						if trackVehicleSelected == "All Vehicles" {
							item.inactive == false
						} else {
							item.vehicleId.contains(trackVehicleSelected) && item.inactive == false
						}
					}
				}
			}
		}
		// MARK: - Navigation Destinations
		// Present the newly-created record in edit mode (like DisplayFuelLog)
		.navigationDestination(item: $newRecordToEdit) { record in
			EditTripLog(dataSet: record, startEditing: true)
				.id(record.id)
		}
		// The report owns and re-fetches its own scope via an in-report vehicle picker,
		// so no .id() here — that would reset the user's picker selection on navigation.
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportTrip(trackVehicleSelected: dest.scope)
				.ignoresSafeArea()
		}
	}

	/// Builds a "Start → Stop → Stop → End" string from the trip's start/end locations
	/// plus any populated enroute fuel stop locations, in stop order.
	private func routeDescription(for record: TripLog2) -> String {
		let stops = [
			record.fuelLocation1, record.fuelLocation2, record.fuelLocation3,
			record.fuelLocation4, record.fuelLocation5, record.fuelLocation6
		].filter { !$0.isEmpty }

		let legs = [record.locationStart] + stops + [record.locationEnd]
		let nonEmptyLegs = legs.filter { !$0.isEmpty }
		guard nonEmptyLegs.count > 1 else { return "" }
		return nonEmptyLegs.map(icaoOnly).joined(separator: " → ")
	}

	/// A resolved airport location is stored as "CODE- Full Airport Name" (see
	/// `LabelLocationTextview`'s auto-format in `Custom Views/9 TextView_Field Mods.swift`).
	/// This row only has room for the route at a glance, so it shows just the code — a plain
	/// typed location with no "- " in it (a city name, a non-aviation address) is left as-is.
	private func icaoOnly(_ location: String) -> String {
		guard let dashRange = location.range(of: "- ") else { return location }
		return String(location[..<dashRange.lowerBound])
	}


	/// Time actually underway: total elapsed time minus time spent at any enroute stops
	/// (based on each stop's entry/exit time).
	private func movingTimeInterval(for record: TripLog2) -> TimeInterval {
		let totalInterval = record.tripDateTimeEnd.timeIntervalSince(record.tripDateTimeStart)
		guard totalInterval > 0 else { return 0 }
		let stops: [(active: Bool, enter: Date?, exit: Date?)] = [
			(record.fuelAdded1 > 0 || !record.stopReason1.isEmpty, record.fuelDateTime1, record.fuelExitTime1),
			(record.fuelAdded2 > 0 || !record.stopReason2.isEmpty, record.fuelDateTime2, record.fuelExitTime2),
			(record.fuelAdded3 > 0 || !record.stopReason3.isEmpty, record.fuelDateTime3, record.fuelExitTime3),
			(record.fuelAdded4 > 0 || !record.stopReason4.isEmpty, record.fuelDateTime4, record.fuelExitTime4),
			(record.fuelAdded5 > 0 || !record.stopReason5.isEmpty, record.fuelDateTime5, record.fuelExitTime5),
			(record.fuelAdded6 > 0 || !record.stopReason6.isEmpty, record.fuelDateTime6, record.fuelExitTime6),
		]
		let stopInterval = stops.reduce(0.0) { total, stop in
			guard stop.active, let enter = stop.enter, let exit = stop.exit, exit > enter else { return total }
			return total + exit.timeIntervalSince(enter)
		}
		return max(0, totalInterval - stopInterval)
	}

	/// Builds a compact "1h 45m" style summary of a time interval. Returns an empty string for a non-positive interval.
	private func formattedDuration(_ interval: TimeInterval) -> String {
		guard interval > 0 else { return "" }
		let formatter = DateComponentsFormatter()
		formatter.allowedUnits = [.hour, .minute]
		formatter.unitsStyle = .abbreviated
		return formatter.string(from: interval) ?? ""
	}

	/// Builds a compact "1h 45m" style summary of time actually underway for a single trip.
	private func movingTimeDescription(for record: TripLog2) -> String {
		formattedDuration(movingTimeInterval(for: record))
	}

	/// Total fuel used on the trip: prefers the stored `fuelConsumed` field if set, otherwise
	/// computes it from starting/ending fuel quantity plus fuel added at enroute stops.
	private func totalFuelUsed(for record: TripLog2) -> Float {
		if record.fuelConsumed > 0 { return record.fuelConsumed }
		let enrouteAdds = record.fuelAdded1 + record.fuelAdded2 + record.fuelAdded3 + record.fuelAdded4 + record.fuelAdded5 + record.fuelAdded6
		return max(0, (record.fuelQuantityStart - record.fuelQuantityEnd) + enrouteAdds)
	}

	/// Formats a fuel quantity to one decimal place.
	private func fuelQuantityFormatted(_ value: Float) -> String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 1
		return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
	}

	/// Builds a dictionary of trip-group name to summed distance/fuel across every leg sharing
	/// that group, computed once per list render via a single fetch rather than running a
	/// separate `FetchDescriptor` for every row belonging to a group.
	private func groupTotalsByGroupName() -> [String: (distance: Int, fuel: Float)] {
		let fd = FetchDescriptor<TripLog2>()
		guard let allTrips = try? modelContext.fetch(fd) else { return [:] }
		let grouped = Dictionary(grouping: allTrips.filter { !$0.tripGroup.isEmpty }, by: { $0.tripGroup })
		return grouped.mapValues { trips in
			let distance = trips.reduce(0) { $0 + max(0, $1.odometerEnd - $1.odometerStart) }
			let fuel = trips.reduce(Float(0)) { $0 + totalFuelUsed(for: $1) }
			return (distance, fuel)
		}
	}

	/// Creates a new `TripLog2` seeded from the most recent trip for the selected vehicle.
	///
	/// - Behavior: If seeding succeeds, odometer, engine hours, fuel level/quantity, location,
	///   and towed vehicle status are carried forward. The new record is saved, selected, and
	///   the view navigates to `EditTripLog` in editing mode.
	private func addNewRecord() {
		// Only allow creating a record when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }
		guard entitlements.requestCreate(TripLog2.self, in: modelContext) else { return }

		let logName = functions.formatDate_DDMMMyy_HHmm(date: Date())
		var odometerStart: Int = 0
		var engHoursStart: Float = 0.0
		var fuelStart: Float = 0.0
		var fuelLevelStart: Float = 0.0
		var locationStart: String = ""
		var vehicleTowed: Bool = false
		var defLevelStart: Float = 0.0
		var defLevelStartFraction: String = ""

		// Fetch the last trip record for this vehicle to seed starting values
		do {
			var fetchDescriptor = FetchDescriptor<TripLog2>(
				predicate: #Predicate { fetchModel in fetchModel.vehicleId == trackVehicleSelected },
				sortBy: [SortDescriptor(\.tripDateTimeEnd, order: .reverse)]
			)
			fetchDescriptor.fetchLimit = 1
			if let last = try modelContext.fetch(fetchDescriptor).first {
				odometerStart = last.odometerEnd
				engHoursStart = last.engHoursEnd
				fuelStart = last.fuelQuantityEnd
				fuelLevelStart = last.fuelLevelEnd1
				locationStart = last.locationEnd
				vehicleTowed = last.vehicleTowed
				defLevelStart = last.defLevelEnd1
				defLevelStartFraction = last.defLevelEndFraction
			}
		} catch {
			// If fetching last trip fails, just start with sensible defaults
			print("Failed to fetch last trip log for '\(trackVehicleSelected)': \(error.localizedDescription)")
		}

		let newRecord = TripLog2(
			inactive: false,
			vehicleId: trackVehicleSelected,
			logName: logName,
			tripNotes: "",
			createdAt: Date(),
			updatedAt: Date(),
			tripDateTimeStart: Date(),
			tripDateTimeEnd: Date(),
			odometerStart: odometerStart,
			odometerEnd: 0,
			engHoursStart: engHoursStart,
			engHoursEnd: 0.0,
			fuelQuantityStart: fuelStart,
			fuelQuantityEnd: 0.0,
			fuelConsumed: 0.0,
			fuelLevelStart1: fuelLevelStart,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "Full",
			fuelLevelEnd: "Full",
			defLevel1: defLevelStart,
			defLevelFraction: defLevelStartFraction,
			fuelAdded1: 0.0,
			fuelAdded2: 0.0,
			fuelAdded3: 0.0,
			fuelAdded4: 0.0,
			fuelAdded5: 0.0,
			fuelAdded6: 0.0,
			locationStart: locationStart,
			locationEnd: "",
			vehicleTowed: vehicleTowed,
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
			print("Failed to save new trip log: \(error.localizedDescription)")
		}
	}
}

#Preview("Empty State") {
    // In-memory SwiftData container with required models for this view
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Vehicle8.self, TripLog2.self, FuelLog1.self, Settings1.self,
        configurations: config
    )

    return NavigationStack {
        DisplayTripLog(trackVehicleSelected: .constant("All Vehicles"))
    }
    .modelContainer(container)
}

#Preview("With Data") {
    // In-memory SwiftData container and seeded demo data
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Vehicle8.self, TripLog2.self, FuelLog1.self, Settings1.self,
        configurations: config
    )
    let context = container.mainContext

    // Seed settings for units so UI labels render nicely
    let settings = Settings1()
    settings.userName = "primary1"
    settings.unitVolumeFuel = "gal"
    settings.unitVolumeOil = "qt"
    settings.unitVolumeDEF = "gal"
    settings.unitTemp = "F"
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

    // Seed a couple of vehicles
    let truck = Vehicle8(name: "Demo Truck", year: 2021, mileage: 15000, engHours: 320.5, fuelType: "Diesel", fuelCapacity: 100)
    let van = Vehicle8(name: "Support Van", year: 2019, mileage: 82000, engHours: 0, fuelType: "Gasoline", fuelCapacity: 24)
    context.insert(truck)
    context.insert(van)

    // Seed a few trip logs for Demo Truck
    let start1 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let end1 = Calendar.current.date(byAdding: .hour, value: 5, to: start1)!
    let trip1 = TripLog2(
        inactive: false,
        vehicleId: truck.name,
        logName: "Morning Delivery Run",
        tripNotes: "Light traffic.",
        createdAt: start1,
        updatedAt: end1,
        tripDateTimeStart: start1,
        tripDateTimeEnd: end1,
        odometerStart: truck.mileage,
        odometerEnd: truck.mileage + 180,
        engHoursStart: truck.engHours,
        engHoursEnd: truck.engHours + 5.0,
        fuelQuantityStart: 60,
        fuelQuantityEnd: 40,
        fuelConsumed: 0,
        fuelLevelStart1: 0.6,
        fuelLevelEnd1: 0.4,
        fuelLevelStart: "3/5",
        fuelLevelEnd: "2/5",
        fuelAdded1Log: "",
        fuelAdded1: 8,
        fuelAdded2Log: "",
        fuelAdded2: 0,
        fuelAdded3Log: "",
        fuelAdded3: 0,
        fuelAdded4Log: "",
        fuelAdded4: 0,
        fuelAdded5Log: "",
        fuelAdded5: 0,
        fuelAdded6Log: "",
        fuelAdded6: 0,
        locationStart: "Depot",
        locationEnd: "Warehouse",
        vehicleTowed: false,
        vehicleIdTowed: "",
        image1: nil,
        image1Description: "",
        image2: nil,
        image2Description: "",
        image3: nil,
        image3Description: ""
    )

    let start2 = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let end2 = Calendar.current.date(byAdding: .hour, value: 7, to: start2)!
    let trip2 = TripLog2(
        inactive: false,
        vehicleId: truck.name,
        logName: "Regional Haul",
        tripNotes: "One fuel stop enroute.",
        createdAt: start2,
        updatedAt: end2,
        tripDateTimeStart: start2,
        tripDateTimeEnd: end2,
        odometerStart: truck.mileage + 200,
        odometerEnd: truck.mileage + 480,
        engHoursStart: truck.engHours + 6.0,
        engHoursEnd: truck.engHours + 13.0,
        fuelQuantityStart: 70,
        fuelQuantityEnd: 30,
        fuelConsumed: 0,
        fuelLevelStart1: 0.7,
        fuelLevelEnd1: 0.3,
        fuelLevelStart: "7/10",
        fuelLevelEnd: "3/10",
        fuelAdded1Log: "",
        fuelAdded1: 12,
        fuelAdded2Log: "",
        fuelAdded2: 0,
        fuelAdded3Log: "",
        fuelAdded3: 0,
        fuelAdded4Log: "",
        fuelAdded4: 0,
        fuelAdded5Log: "",
        fuelAdded5: 0,
        fuelAdded6Log: "",
        fuelAdded6: 0,
        locationStart: "Warehouse",
        locationEnd: "Harbor",
        vehicleTowed: true,
        vehicleIdTowed: "Trailer A",
        image1: nil,
        image1Description: "",
        image2: nil,
        image2Description: "",
        image3: nil,
        image3Description: ""
    )

    context.insert(trip1)
    context.insert(trip2)
    try? context.save()

    return NavigationStack {
        DisplayTripLog(trackVehicleSelected: .constant("Demo Truck"))
    }
    .modelContainer(container)
}


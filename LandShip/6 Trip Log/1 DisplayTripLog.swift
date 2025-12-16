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
	@State private var selectedRecord: TripLog2?
	let functions: Functions = Functions()
	// Access settings (units) without storing them in @State
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	// Helper to read unit strings without @State
	private func unit(_ index: Int) -> String {
		let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)
		return arr[safe: index] ?? ""
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
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Travel Log A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Travel Log Z–A"
		case nameAsc = "Travel Log A–Z"
		case nameDesc = "Travel Log Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<TripLog2>] {
			switch self {
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
	@State private var selectedSort: PartsSort = .datedDesc_vehicleAsc

	/// Main content that composes the vehicle filter, the trip list (via `QueryView`),
	/// and toolbar actions for sorting, reporting, and adding new records.
	var body: some View {
		Group {
			// MARK: - Vehicle Filter & Toolbar
			HStack(spacing: 3) {
				
				LabeledContent {
					// Custom model picker to choose a specific vehicle or "All Vehicles" (empty choice).
					// The `filter` respects `showInactiveVehicles` to optionally hide inactive items.
					ModelPicker(
						selection: $selectedVehicle,
						title: "Vehicle",
						includeEmptyChoice: true,
						emptyChoiceLabel: "All Vehicles",
						autoSelectFirst: false,
						filter: showInactiveVehicles ? nil : #Predicate { !$0.inactive },
						sort: [SortDescriptor(\.name, order: .forward)],
						labelProvider: { $0.name }
					)
					.fixedSize(horizontal: true, vertical: true)
				} label: {
					Text("Vehicle")
						.textLabelModified()
				}

//                ModelPicker(
//                    selection: $selectedVehicle,
//                    title: "Vehicle",
//                    includeEmptyChoice: true,
//                    emptyChoiceLabel: "All Vehicles",
//                    autoSelectFirst: false,
//                    filter: nil,
//                    sort: [SortDescriptor(\.name, order: .forward)],
//                    labelProvider: { $0.name }
//                )
//                .frame(maxWidth: .infinity, alignment: .trailing)
            }
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
            }
						.safeAreaInset(edge: .top) {
							PageTitle_Col2_NoPhoto(label: "TRAVEL LOGS")
						}


			// MARK: - Trip Logs List
			QueryView(for: TripLog2.self, sort: selectedSort.descriptors) { records in
				if records.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first Travel Log",
							systemImage: "map",
							description: "Create a Travel Log to track trips taken, fuel consumed and vehicle mileage.\n\nTo add additional logs after this first one, select the '+' button at the top of the form.",
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
									let mxDate = functions.formatDate_DDMMMyy(date: record.tripDateTimeStart)
									HStack {
										let vehicleForImage = vehicles.first { $0.name == record.vehicleId }
										Image_View_Thumbnail(imageData: vehicleForImage?.image1 ?? record.image1)
										VStack {
											Text("\(record.logName)")
												.textModifier_ListTitle()
											Text("\(mxDate)")
												.textModifier_ListSubTitle_R()
											Text("\(record.vehicleId)")
												.textModifier_ListSubTitle_R()
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
									Label("Report", systemImage: "list.clipboard")
								}
							}
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
							if !allVehiclesSelected {
								ToolbarItem(placement: .automatic) {
									Button {
										addNewRecord()
									} label: {
										Label("Add", systemImage: "plus.capsule")
									}
									.disabled(false)
								}
							}
						}
					} header: {
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
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportTrip(trackVehicleSelected: .constant(dest.scope))
				.id("TripReport-\(dest.scope)")
				.ignoresSafeArea()
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

		let logName = "Travel Log: " + functions.formatDate_DDMMMyy_HHmm(date: Date())
		var odometerStart: Int = 0
		var engHoursStart: Float = 0.0
		var fuelStart: Float = 0.0
		var fuelLevelStart: Float = 0.0
		var locationStart: String = ""
		var vehicleTowed: Bool = false

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

/// Safe index helper for arrays to avoid out-of-bounds crashes when settings are missing.
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
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


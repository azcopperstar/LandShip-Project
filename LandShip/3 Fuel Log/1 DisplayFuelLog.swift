//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayFuelLog: View {
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@State private var selectedRecord: FuelLog1?
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	
	@State private var allVehiclesSelected: Bool = true /// if all vehicles, disable save update button

	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	@State private var sortVehicle: SortDescriptor<FuelLog1> = .init(\.vehicleId, order: .forward) /// for QueryView
	@State private var sortDate: SortDescriptor<FuelLog1> = .init(\.fuelDateTime, order: .reverse) /// for QueryView

	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false
	
	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Fuel Log A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Fuel Log Z–A"
		case nameAsc = "Fuel Log A–Z"
		case nameDesc = "Fuel Log Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<FuelLog1>] {
			switch self {
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
	@State private var selectedSort: PartsSort = .datedDesc_vehicleAsc

	var body: some View {
		Group {
			PickerVehicle(trackVehicleSelected: $trackVehicleSelected, _vehicles: _vehicles)
				.onChange(of: trackVehicleSelected) {
					if trackVehicleSelected == "All Vehicles" {
						allVehiclesSelected = true
					} else {
						allVehiclesSelected = false
					}
				}
				.onAppear {
					if trackVehicleSelected == "All Vehicles" {
						allVehiclesSelected = true
					} else {
						allVehiclesSelected = false
					}
					// Load settings as an array (same approach as pdfReportService)
					let prefsUnits = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
						?? Array(repeating: "", count: 13)
				}
				.toolbar {
					ToolbarItem(placement: .automatic) {
						LabelDataText_Toolbar(label: "LOGS")
					}
				}
			
			QueryView(for: FuelLog1.self, sort: selectedSort.descriptors) {records in
				if records.isEmpty {
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

					Section {
						List(selection: $selectedRecord) {
							ForEach(records) { record in
								NavigationLink {
									EditFuelLog(dataSet: record)
										.id(record.id) // <<< work-around to get splitview to change details when selected
								} label: {
									let mxDate = functions.formatDate_DDMMMyy(date:record.fuelDateTime)
									HStack{
										Image_View_Thumbnail(imageData: record.image1)
										VStack{
											Text("Date: \(mxDate)")
												.textModifier_ListSubTitle_R()
											Text("\(record.logName)")
												.textModifier_ListTitle()
											Text("Odometer: \(record.odometer)")
												.textModifier_ListSubTitle_R()
											Text("\(record.vehicleId)")
												.textModifier_ListSubTitle_R()
										}
									}
								}
							}
							.textModifier_ListDivider()
						}
						.toolbar {
							ToolbarItem(placement: .automatic) {
								Button {
									isShowingPDFReport = true
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
					if trackVehicleSelected == "All Vehicles" {
						true
					} else {
						item.vehicleId.contains(trackVehicleSelected)
					}
				}
			}
		}
		// Present the PDF report using modern navigation APIs
		.navigationDestination(isPresented: $isShowingPDFReport) {
			pdfReportFuel(trackVehicleSelected: $trackVehicleSelected)
				.id("FuelReport-\(trackVehicleSelected)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		}
	}
	
	// Function to add a new fuel log
	private func addNewRecord() {
		// Only allow creating a record when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, !allVehiclesSelected else { return }

		// Fetch selected vehicle (limit to 1)
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
		
		// Find last fuel record for price (limit to 1)
		var fuelPrice: Float = 0.0
		do {
			var lastFuelFetch = FetchDescriptor<FuelLog1>(
				predicate: #Predicate { fetchModel in fetchModel.vehicleId == trackVehicleSelected },
				sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)]
			)
			lastFuelFetch.fetchLimit = 1
			if let lastLog = try modelContext.fetch(lastFuelFetch).first {
				fuelPrice = lastLog.fuelPrice
			}
		} catch {
			print("Failed to fetch last fuel log for '\(trackVehicleSelected)': \(error.localizedDescription)")
		}

		let logName = "Fueled: " + functions.formatDate_DDMMMyy_HHmm(date: Date())
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

		modelContext.insert(newRecord)
		do {
			try modelContext.save()
		} catch {
			print("Failed to save new fuel log: \(error.localizedDescription)")
		}
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, ServiceRecords1.self, MxItems3.self, MxParts1.self, Vendors1.self, configurations: config)
	return ContentView()
		.modelContainer(container)
}

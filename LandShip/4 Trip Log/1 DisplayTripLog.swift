//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayTripLog: View {
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

	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false

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

	var body: some View {
		
		PickerVehicle(trackVehicleSelected: $trackVehicleSelected, _vehicles: _vehicles)
			.onChange(of: trackVehicleSelected) {
				allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
			}
			.onAppear {
				allVehiclesSelected = (trackVehicleSelected == "All Vehicles")
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "TRAVEL")
				}
//				ToolbarItem(placement: .automatic) {
//					Button {
//						isShowingPDFReport = true
//					} label: {
//						Label("Report", systemImage: "list.clipboard")
//					}
//				}
//				ToolbarItem(placement: .automatic) {
//					Menu {
//						Picker("Sort by", selection: $selectedSort) {
//							ForEach(PartsSort.allCases) { sortCase in
//								Text(sortCase.rawValue).tag(sortCase)
//							}
//						}
//					} label: {
//						Label("Sort", systemImage: "arrow.up.arrow.down")
//					}
//					.buttonStyle(GrowingButton(buttonColor: Color.gray))
//					.accessibilityLabel("Sort parts")
//				}
//				ToolbarItem(placement: .automatic) {
//					Button {
//						addNewRecord()
//					} label: {
//						Label("Add", systemImage: "plus.capsule")
//					}
//					.disabled(false)
//				}
			}
		// Hidden NavigationLink that targets the detail column in a NavigationSplitView
		NavigationLink(isActive: $isShowingPDFReport) {
			pdfReportTrip(trackVehicleSelected: $trackVehicleSelected)
				.id("TripReport-\(trackVehicleSelected)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		} label: {
			EmptyView()
		}
		.hidden()

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
								Image_View_Thumbnail(imageData: record.image1)
								
								let mxDate = functions.formatDate_DDMMMyy(date: record.tripDateTimeStart)
								HStack {
									VStack {
										Text("Date: \(mxDate)")
											.textModifier_ListSubTitle_R()
										Text("\(record.vehicleId)")
											.textModifier_ListSubTitle_R()
										Text("\(record.logName)")
											.textModifier_ListTitle()
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
	
	// Function to add a new trip log
	private func addNewRecord() {
		// Only allow creating a record when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }

		let logName = "Travel " + functions.formatDate_DDMMMyy_HHmm(date: Date())
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
		} catch {
			print("Failed to save new trip log: \(error.localizedDescription)")
		}
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, ServiceRecords1.self, MxItems3.self, MxParts1.self, Vendors1.self, configurations: config)
	return ContentView()
		.modelContainer(container)
}

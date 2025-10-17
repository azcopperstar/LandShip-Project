//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayRecords: View {
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@State private var selectedRecord: ServiceRecords1?
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

	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false

	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Records A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Records Z–A"
		case nameAsc = "Records A–Z"
		case nameDesc = "Records Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<ServiceRecords1>] {
			switch self {
				case .datedDesc_vehicleAsc:
					return [.init(\.vehicleId, order: .forward),.init(\.mxDate, order: .reverse)]
				case .vehicleAsc_nameAsc:
					return [.init(\.vehicleId, order: .forward),.init(\.mxName, order: .forward)]
				case .vehicleAsc_nameDesc:
					return [.init(\.vehicleId, order: .forward),.init(\.mxName, order: .reverse)]
				case .nameAsc:
					return [ .init(\.mxName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.mxName, order: .reverse) ]
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
					LabelDataText_Toolbar(label: "SERVICE")
				}
			}
		// Hidden NavigationLink that targets the detail column in a NavigationSplitView
		NavigationLink(isActive: $isShowingPDFReport) {
			pdfReportService(trackVehicleSelected: $trackVehicleSelected)
				.id("ServiceReport-\(trackVehicleSelected)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		} label: {
			EmptyView()
		}
		.hidden()
		
		QueryView(for: ServiceRecords1.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
				List {
					EmptyStateSection(
						title: "Add your first Service Record",
						systemImage: "square.grid.3x1.folder.badge.plus",
						description: "Create a Service Record to track service, maintence, and repairs.\n\nTo add additional records after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Fuel Log",
						action: { addNewRecord() }
					)
				}
			} else {
				Section {
					List(selection: $selectedRecord) {
						ForEach(records) { record in
							NavigationLink {
								EditRecord(serviceRecords1: record)
									.id(record.id) // work-around to get splitview to change details when selected
							} label: {
								let mxDate = functions.formatDate_DDMMMyy(date: record.mxDate)
								HStack {
									VStack {
										Text("Date: \(mxDate)")
											.textModifier_ListSubTitle_L()
										Text("Odometer: \(record.Miles) \(unit(UnitIndex.distance))")
											.textModifier_ListSubTitle_L()
									}
									VStack {
										Text("\(record.vehicleId)")
											.textModifier_ListSubTitle_R()
										Text("\(record.mxName)")
											.textModifier_ListTitle()
									}
								}
							}
						}
						.textModifier_ListDivider()
					}
					.toolbar {
//						ToolbarItem(placement: .automatic) {
//							LabelDataText_Toolbar(label: "SERVICE")
//						}
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
							.accessibilityLabel("Sort records")
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
	
	// Function to add a new service record
	private func addNewRecord() {
		// Only allow when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }
		
		let newRecord = ServiceRecords1(
			createdAt: Date(),
			updatedAt: Date(),
			mxDate: Date(),
			vehicleId: trackVehicleSelected,
			Miles: 0,
			engHours: 0,
			mxName: "New service record...",
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
		} catch {
			print("Failed to save service record: \(error.localizedDescription)")
		}
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

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

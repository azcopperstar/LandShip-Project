//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplaySystems: View {
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@State private var selectedRecord: VehicleSystems1?
	let functions: Functions = Functions()
	
	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	// for QueryView (kept in case you still want quick ad‑hoc sorts elsewhere)
	@State private var sortVehicle: SortDescriptor<VehicleSystems1> = .init(\.vehicleId, order: .forward)
	@State private var sortSysName: SortDescriptor<VehicleSystems1> = .init(\.systemName, order: .forward)

	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc_nameAsc = "Vehicle A–Z, System A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, System Z–A"
		case nameAsc = "System A–Z"
		case nameDesc = "System Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
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
	@State private var selectedSort: PartsSort = .vehicleAsc_nameAsc

    var body: some View {
			
			PickerVehicle(trackVehicleSelected: $trackVehicleSelected, _vehicles: _vehicles)
				.toolbar {
					ToolbarItem(placement: .automatic) {
						LabelDataText_Toolbar(label: "SYSTEMS")
					}
				}

			// Use the selected sort descriptors so the header reflects actual sorting
			QueryView(for: VehicleSystems1.self, sort: selectedSort.descriptors) { records in
				if records.isEmpty {
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
					Section {
						List(selection: $selectedRecord){
							ForEach(records) { record in
								NavigationLink {
									EditSystems(vehicleSystem: record)
										.id(record.id) // <<< work-around to get splitview to change details when selected
								} label: {
									HStack{
										VStack{
											Text("\(record.systemDescription)")
												.textModifier_ListSubTitle_L()
										}
										VStack{
											Text("\(record.vehicleId)")
												.textModifier_ListSubTitle_R()
											Text("\(record.systemName)")
												.textModifier_ListTitle()
										}
									}
								}
							}
							.textModifier_ListDivider()
						}
						.toolbar {
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

	// Function to add a new service item
	@MainActor
	private func addNewRecord() {
		let now = Date()
		let assignedVehicleId = (trackVehicleSelected == "All Vehicles") ? "" : trackVehicleSelected

		let newRecord = VehicleSystems1(
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
		modelContext.insert(newRecord)
		
		do {
			try modelContext.save()
		} catch {
			print("Failed to save VehicleSystems1: \(error.localizedDescription)")
		}
	}
}

#Preview {
//    DisplayItems()
}

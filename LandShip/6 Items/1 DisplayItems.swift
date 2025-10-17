//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayItems: View {
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@State private var selectedRecord: MxItems3?
	let functions: Functions = Functions()
	
	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	// for QueryView
	@State private var sortVehicle: SortDescriptor<MxItems3> = .init(\.vehicleId, order: .forward)
	@State private var sortItem: SortDescriptor<MxItems3> = .init(\.mxName, order: .forward)

	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc_nameAsc = "Vehicle A–Z, Items A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Items Z–A"
		case nameAsc = "Items A–Z"
		case nameDesc = "Items Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<MxItems3>] {
			switch self {
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
	@State private var selectedSort: PartsSort = .vehicleAsc_nameAsc

	var body: some View {

		PickerVehicle(trackVehicleSelected: $trackVehicleSelected, _vehicles: _vehicles)
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "ITEMS")
				}
			}

		QueryView(for: MxItems3.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
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
				Section {
					List(selection: $selectedRecord){
						ForEach(records) { record in
							NavigationLink {
								EditItems(mxItems: record)
									.id(record.id) // <<< work-around to get splitview to change details when selected
							} label: {
								HStack{
									VStack{
										Text("\(record.mxDescription)")
											.textModifier_ListSubTitle_L()
										
									}
									VStack{
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
		private func addNewRecord() {
		// Only allow when a specific vehicle is selected
		guard !trackVehicleSelected.isEmpty, trackVehicleSelected != "All Vehicles" else { return }
		
		let newRecord = MxItems3(
			createdAt: Date(),
			updatedAt: Date(),
			vehicleId: trackVehicleSelected,
			vehicleSystem: "",
			mxName: "New service item...",
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
		} catch {
			print("Failed to save service item: \(error.localizedDescription)")
		}
	}
	}

#Preview {
//    DisplayItems()
}

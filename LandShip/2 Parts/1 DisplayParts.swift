//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayParts: View {
	@Query var vehicles: [Vehicle8]
	@Environment(\.modelContext) var modelContext
	@State private var selectedRecord: MxParts1?
	let functions: Functions = Functions()

	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false

	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc_nameAsc = "Vehicle A–Z, Part A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Part Z–A"
		case nameAsc = "Part A–Z"
		case nameDesc = "Part Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }

		var descriptors: [SortDescriptor<MxParts1>] {
			switch self {
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
	@State private var selectedSort: PartsSort = .vehicleAsc_nameAsc

	var body: some View {
		
		PickerVehicle(trackVehicleSelected: $trackVehicleSelected, _vehicles: _vehicles)
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "PARTS")
				}
			}
		// Hidden NavigationLink that targets the detail column in a NavigationSplitView
		NavigationLink(isActive: $isShowingPDFReport) {
			pdfReportParts(trackVehicleSelected: $trackVehicleSelected)
				.id("PartsReport-\(trackVehicleSelected)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		} label: {
			EmptyView()
		}
		.hidden()

		QueryView(for: MxParts1.self, sort: selectedSort.descriptors) { records in
			Group {
				if records.isEmpty {
					List {
						EmptyStateSection(
							title: "Add your first Part",
							systemImage: "engine.combustion.badge.exclamationmark",
							description: "Create a part to track inventory, sourcing, and usage in service items and records.\n\nTo add additional parts after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Part",
							action: { addNewRecord() }
						)
					}
				} else {
					Section {
						List(selection: $selectedRecord) {
							ForEach(records) { record in
								NavigationLink {
									EditParts(mxParts: record)
										.id(record.id) // <<< work-around to get splitview to change details when selected
								} label: {
									HStack {
										Image_View_Thumbnail(imageData: record.image1)
										VStack {
											Text("\(record.vehicleId)")
												.textModifier_ListSubTitle_R()
											Text("\(record.partName)")
												.textModifier_ListTitle()
										}
									}
									.accessibilityElement(children: .combine)
									.accessibilityLabel("\(record.partName), vehicle \(record.vehicleId)")
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
		let newRecord = MxParts1(
			createdAt: Date(),
			updatedAt: Date(),
			vehicleId: trackVehicleSelected == "All Vehicles" ? "" : trackVehicleSelected,
			vehicleSystem: "",
			partName: "New part name...",
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
		} catch {
			print("Failed to save book: \(error.localizedDescription)")
		}
	}
}

#Preview("DisplayParts - Empty State") {
	makeDisplayPartsEmptyPreview(initialVehicle: "All Vehicles")
}

@MainActor
private func makeDisplayPartsEmptyPreview(initialVehicle: String) -> some View {
	// In-memory SwiftData container (include both models so queries work)
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				MxParts1.self,
				configurations: configuration
	)

	let context = container.mainContext

	// Seed vehicles only (no parts), so the table is empty
	let vehicleA = Vehicle8(
		name: "Truck 1500",
		year: 2020,
		mileage: 42000,
		mileageVirtual: 0,
		engHours: 1234.5,
		fuelType: "Gasoline",
		fuelCapacity: 26
	)
	let vehicleB = Vehicle8(
		name: "Van 2500",
		year: 2018,
		mileage: 88000,
		mileageVirtual: 0,
		engHours: 2345.6,
		fuelType: "Diesel",
		fuelCapacity: 32
	)
	context.insert(vehicleA)
	context.insert(vehicleB)
	try? context.save()

	// Binding for the selected vehicle in the preview
	let selection = State(initialValue: initialVehicle)

	// Wrap in a NavigationStack so the hidden NavigationLink can navigate
	return NavigationStack {
		DisplayParts(trackVehicleSelected: selection.projectedValue)
			.modelContainer(container)
			.navigationTitle("Parts")
	}
}

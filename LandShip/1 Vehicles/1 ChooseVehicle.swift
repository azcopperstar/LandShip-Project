//
//  VehicleListingView.swift
//  LandShip
//
//  Created by JP on 7/19/25.
//

import SwiftData
import SwiftUI

struct ChooseVehicle: View {
	@Environment(\.modelContext) var modelContext

	// Toggle to include inactive vehicles in the list (moved to Settings; read via AppStorage)
	@AppStorage("showInactiveVehicles") private var includeInactive: Bool = false

	// Two queries: one for active-only, one for all. We choose at runtime via computed property.
	@Query(
		filter: #Predicate<Vehicle8> { $0.inactive == false },
		sort: \Vehicle8.name,
		order: .forward
	)
	private var activeVehicles: [Vehicle8]

	@Query(
		sort: \Vehicle8.name,
		order: .forward
	)
	private var allVehicles: [Vehicle8]

	// Runtime-selected source based on the toggle
	private var vehicles: [Vehicle8] {
		includeInactive ? allVehicles : activeVehicles
	}

	// tracks vehicle selected between views
	@Binding var trackVehicleSelected: String

	// navigation state for the PDF report (detail column)
	@State private var isShowingPDFReport: Bool = false

	// search support
	@State private var searchText: String = ""

	// Derived filtered list (simple in-memory filtering for UX)
	private var filteredVehicles: [Vehicle8] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return vehicles }
		return vehicles.filter { v in
			let haystack = [
				v.name,
				v.manufacturer,
				v.model,
				v.trim,
				v.vin,
				v.licensePlate
			]
			.joined(separator: " ")
			.lowercased()
			return haystack.contains(query.lowercased())
		}
	}

	// Sort handling
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc = "Vehicle A–Z"
		case vehicleDesc = "Vehicle Z-A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		var descriptors: [SortDescriptor<Vehicle8>] {
			switch self {
				case .vehicleAsc:
					return [.init(\.name, order: .forward)]
				case .vehicleDesc:
					return [.init(\.name, order: .reverse)]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	@State private var selectedSort: PartsSort = .vehicleAsc
	
	var body: some View {
		List {
			if vehicles.isEmpty {
					EmptyStateSection(
						title: "Add your first vehicle",
						systemImage: "truck.pickup.side.front.open",
						description: "Create a new vehicle to begin tracking, parts, fuel logs, travel logs, service items, service records.\n\nThe vehicles entered here will be available in all the other tables.\n\nTo add additional vehicles, after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Vehicle",
						action: { addNewRecord() }
					)
			} else {
				Section {
					ForEach(filteredVehicles) { vehicle in
						NavigationLink {
							EditVehicle(dataSet: vehicle, trackVehicleSelected: $trackVehicleSelected)
								.id(vehicle.id) // ensure split view updates details when selected
						} label: {
							VStack(alignment: .leading) {
								HStack {
									Image_View_Thumbnail(imageData: vehicle.image1)
									VStack(alignment: .leading, spacing: 2) {
										Text(vehicle.name)
											.font(.headline)
										let year = vehicle.year
										let manufacturer = vehicle.manufacturer
										let trim = vehicle.trim
										Text("\(year) \(manufacturer) \(trim)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
										Text("Odometer: \(vehicle.mileage)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
									}
									.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
							.accessibilityElement(children: .combine)
							.accessibilityLabel("\(vehicle.name), \(yearDescription(vehicle))")
							.accessibilityHint("Opens vehicle details")
						}
					}
					.onDelete(perform: deleteFilteredVehicles)
				} header: {
					// Static header because the @Query is always name ascending
					HStack(spacing: 6) {
						Image(systemName: "arrow.up.arrow.down")
						Text("Sort: Name A–Z")
					}
					.font(.caption)
					.foregroundStyle(.secondary)
					.padding(.top, 4)
				}
			}
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				LabelDataText_Toolbar(label: "VEHICLES")
			}
			if !vehicles.isEmpty {
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
					.accessibilityLabel("Sort vehicles")
				}
			}
			// Moved the "Show Inactive" toggle to SettingsEditorView; no toggle here anymore.
			ToolbarItem(placement: .automatic) {
				Button {
					addNewRecord()
				} label: {
					Label("Add", systemImage: "plus.capsule")
				}
			}
		}

		// .searchable(text: $searchText, placement: .automatic, prompt: Text("Search vehicles"))

		// iOS 16+: Use navigationDestination(isPresented:) instead of deprecated NavigationLink(isActive:)
		.navigationDestination(isPresented: $isShowingPDFReport) {
			pdfReportVehicles(trackVehicleSelected: $trackVehicleSelected)
				.id("VehiclesReport-\(trackVehicleSelected)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		}
	}

	// MARK: - Helpers

	private func yearDescription(_ v: Vehicle8) -> String {
		let parts = [String(v.year), v.manufacturer, v.model, v.trim]
			.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
		return parts.joined(separator: " ")
	}

	private func addNewRecord() {
		let newRecord = Vehicle8(
			inactive: false,
			name: "New vehicle",
			manufacturer: "",
			model: "",
			year: Calendar.current.component(.year, from: Date()),
			trim: "",
			mileage: 0,
			transmission: "",
			engine: "",
			fuelType: "",
			doors: 0,
			seats: 0,
			cargoSpace: 0,
			length: 0,
			width: 0,
			height: 0,
			weight: 0,
			imageUrl: "",
			price: 0,
			notes: "",
			createdAt: Date(),
			updatedAt: Date(),
			ownerId: "",
			locationId: "",
			vin: "",
			licensePlate: "",
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
			print("Failed to save vehicle: \(error.localizedDescription)")
		}
	}

	// Delete handler that maps IndexSet from the filtered list back to real objects
	private func deleteFilteredVehicles(at offsets: IndexSet) {
		let toDelete: [Vehicle8] = offsets.compactMap { idx in
			guard filteredVehicles.indices.contains(idx) else { return nil }
			return filteredVehicles[idx]
		}
		for vehicle in toDelete {
			modelContext.delete(vehicle)
		}
		do {
			try modelContext.save()
		} catch {
			print("Failed to delete vehicle(s): \(error.localizedDescription)")
		}
	}

	// Legacy direct deletion by indices on unfiltered array (kept if needed elsewhere)
	func deleteVehicle(_ indexSet: IndexSet) {
		for index in indexSet {
			let vehicle = vehicles[index]
			modelContext.delete(vehicle)
		}
	}
}

// MARK: - Preview Hosts

private struct ChooseVehicleEmptyPreviewHost: View {
	let container: ModelContainer
	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		self.container = try! ModelContainer(for: Vehicle8.self, configurations: config)
	}
	var body: some View {
		NavigationStack {
			ChooseVehicle(trackVehicleSelected: .constant(""))
		}
		.modelContainer(container)
	}
}

private struct ChooseVehicleSamplesPreviewHost: View {
	let container: ModelContainer
	init() {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		let container = try! ModelContainer(for: Vehicle8.self, configurations: config)

		// Seed a few sample vehicles
		let ctx = container.mainContext
		let now = Date()
		let currentYear = Calendar.current.component(.year, from: now)

		let samples: [Vehicle8] = [
			Vehicle8(
				inactive: false,
				name: "Family SUV",
				manufacturer: "Subaru",
				model: "Outback",
				year: currentYear - 2,
				trim: "Premium",
				mileage: 24500,
				transmission: "CVT",
				engine: "2.5L",
				fuelType: "Gasoline",
				doors: 4,
				seats: 5,
				cargoSpace: 32,
				length: 0,
				width: 0,
				height: 0,
				weight: 0,
				imageUrl: "",
				price: 0,
				notes: "Primary family car",
				createdAt: now,
				updatedAt: now,
				ownerId: "",
				locationId: "",
				vin: "VIN1234567890",
				licensePlate: "ABC-123",
				image1: nil,
				image1Description: "",
				image2: nil,
				image2Description: "",
				image3: nil,
				image3Description: ""
			),
			Vehicle8(
				inactive: false,
				name: "Work Truck",
				manufacturer: "Ford",
				model: "F-150",
				year: currentYear - 5,
				trim: "XLT",
				mileage: 78500,
				transmission: "Automatic",
				engine: "3.5L",
				fuelType: "Gasoline",
				doors: 4,
				seats: 5,
				cargoSpace: 0,
				length: 0,
				width: 0,
				height: 0,
				weight: 0,
				imageUrl: "",
				price: 0,
				notes: "Used for hauling",
				createdAt: now,
				updatedAt: now,
				ownerId: "",
				locationId: "",
				vin: "VIN0987654321",
				licensePlate: "TRK-456",
				image1: nil,
				image1Description: "",
				image2: nil,
				image2Description: "",
				image3: nil,
				image3Description: ""
			),
			Vehicle8(
				inactive: false,
				name: "Commuter",
				manufacturer: "Toyota",
				model: "Prius",
				year: currentYear - 1,
				trim: "LE",
				mileage: 12000,
				transmission: "Automatic",
				engine: "1.8L Hybrid",
				fuelType: "Hybrid",
				doors: 4,
				seats: 5,
				cargoSpace: 27,
				length: 0,
				width: 0,
				height: 0,
				weight: 0,
				imageUrl: "",
				price: 0,
				notes: "Daily driver",
				createdAt: now,
				updatedAt: now,
				ownerId: "",
				locationId: "",
				vin: "VIN2468013579",
				licensePlate: "ECO-789",
				image1: nil,
				image1Description: "",
				image2: nil,
				image2Description: "",
				image3: nil,
				image3Description: ""
			)
		]

		for v in samples { ctx.insert(v) }
		try? ctx.save()

		self.container = container
	}
	var body: some View {
		NavigationStack {
			ChooseVehicle(trackVehicleSelected: .constant(""))
		}
		.modelContainer(container)
	}
}

#Preview("Empty State") {
	ChooseVehicleEmptyPreviewHost()
}

#Preview("With Sample Vehicles") {
	ChooseVehicleSamplesPreviewHost()
}

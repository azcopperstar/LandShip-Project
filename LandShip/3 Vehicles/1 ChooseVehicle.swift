/**
 ChooseVehicle.swift
 LandShip
 
 A SwiftUI view that lists vehicles stored with SwiftData and provides navigation to edit
 or report screens. This view supports:
 
 - Filtering active vs. inactive vehicles (via AppStorage-driven setting)
 - Client-side text search across common vehicle fields
 - Sort selection (UI picker) with multiple sort descriptors
 - Programmatic navigation to a newly created vehicle's edit screen
 - Deletion of vehicles from filtered results while mapping back to the underlying model
 - Accessibility annotations for VoiceOver
 - Preview hosts for empty and sample data scenarios
 
 Data flow & responsibilities:
 - Fetches `Vehicle8` objects using two `@Query` properties: one for active vehicles and one for all vehicles.
 - Uses a computed `vehicles` list to choose which query to present based on the `includeInactive` AppStorage flag.
 - Applies an in-memory search to the chosen list to produce `filteredVehicles` for display.
 - Handles creation and deletion using the injected `modelContext`.
 - Navigates to `EditVehicle` when a row is tapped or immediately after creating a new record.
 - Presents a PDF report view using a boolean navigation state.
 
 Performance considerations:
 - Search is performed in-memory for responsiveness and simplicity. For very large datasets,
   consider moving search predicates into SwiftData queries or adding indexes to relevant fields.
 - Sorting in the UI is currently reflected by the picker state but the base query remains
   name-ascending; consider wiring `selectedSort` into the query if server-/store-side sort is needed.
 
 Accessibility:
 - Rows are combined into a single accessibility element with a concise label and hint.
 - Toolbar items include accessibility labels.
 
 Testing & previews:
 - Two preview hosts are provided: one with an empty in-memory store and one seeded with sample data.
 - Use these to validate empty states, list rendering, and navigation behavior.
 
 Change log:
 - 2025-10-19: Added comprehensive documentation header and inline comments for clarity.
 */

import SwiftData
import SwiftUI

/// Displays a searchable, (optionally) inactive-inclusive list of vehicles and navigates
/// to edit and report views. Uses SwiftData for persistence and NavigationStack destinations
/// for programmatic navigation.
struct ChooseVehicle: View {
	/// The SwiftData model context used for creating, saving, and deleting `Vehicle8` records.
	@Environment(\.modelContext) var modelContext

	/// User preference (persisted via AppStorage) that determines whether inactive vehicles
	/// should be included in the list. The toggle is surfaced in Settings; this view only reads it.
	@AppStorage("showInactiveVehicles") private var includeInactive: Bool = false

	/// Two SwiftData queries:
	/// - `activeVehicles`: Filters to vehicles where `inactive == false`.
	/// - `allVehicles`: Unfiltered, all records.
	/// The view chooses which to render at runtime via the `vehicles` computed property.
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

	/// The currently selected source of truth for the list, based on `includeInactive`.
	private var vehicles: [Vehicle8] {
		includeInactive ? allVehicles : activeVehicles
	}

	/// Binding used to share the currently selected vehicle identifier across views (e.g., reports).
	@Binding var trackVehicleSelected: String

	/// Navigation to PDF report with a frozen scope to avoid feedback loops
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?

	/// Controls navigation to the PDF report destination.
	@State private var isShowingPDFReport: Bool = false

	/// Local search text for simple in-memory filtering of the displayed vehicles.
	@State private var searchText: String = ""

	/// When set during creation, triggers navigation to the editor for the new vehicle.
	@State private var newRecordToEdit: Vehicle8?
	
	/// Derived list used to back the `ForEach` in the UI. This performs a simple in-memory search across
	/// commonly queried fields (name, manufacturer, model, trim, VIN, license plate). This is sufficient
	/// for moderate datasets and provides instant feedback while typing. If your dataset grows large,
	/// consider moving this logic into a SwiftData predicate to leverage store-side filtering.
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

	/// User-facing sort options for the vehicles list. The selected case exposes one or more
	/// `SortDescriptor` values that can be applied to a query when integrating store-side sorting.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case vehicleAsc = "Vehicle A–Z"
		case vehicleDesc = "Vehicle Z-A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		/// Sort descriptors associated with each user-facing option.
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
		// Layout: List with empty state fallback, row navigation to editor, and toolbar with report, sort, and add actions.
		List {
			// Empty-state guidance when there are no vehicles to show.
			if vehicles.isEmpty {
					EmptyStateSection(
						title: "Add your first vehicle",
						systemImage: "truck.pickup.side.front.open",
						description: "Create a new vehicle to begin tracking, parts, fuel logs, travel logs, service items, service records.\n\nThe vehicles entered here will be available in all the other tables.\n\nTo add additional vehicles, after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Vehicle",
						action: { addNewRecord() }
					)
			} else {
				// Main section rendering the filtered vehicles and enabling swipe-to-delete.
				Section {
					ForEach(filteredVehicles) { vehicle in
						NavigationLink {
							EditVehicle(dataSet: vehicle, trackVehicleSelected: $trackVehicleSelected)
								.id(vehicle.id) // ensure split view updates details when selected
						} label: {
							// Row layout: thumbnail + key vehicle details with accessible labels.
							VStack(alignment: .leading) {
								HStack {
									Image_View_Thumbnail(imageData: vehicle.image1)
									VStack(alignment: .leading, spacing: 1) {
										let year = String(vehicle.year)
										let manufacturer = vehicle.manufacturer
										let trim = vehicle.trim
										Text(vehicle.name)
											.font(.headline)
										Text("\(year) \(manufacturer) \(trim)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
										Text("Odometer: \(vehicle.mileage)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
									.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
							.accessibilityElement(children: .combine)
							.accessibilityLabel("\(vehicle.name), \(yearDescription(vehicle))")
							.accessibilityHint("Opens vehicle details")
						}
					}
					// Map deletions from the filtered view back to the underlying model objects.
					.onDelete(perform: deleteFilteredVehicles)
				} header: {
					// Static header currently reflects name-ascending order. If you wire `selectedSort`
					// into a query, consider reflecting the active sort choice here dynamically.
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

		.safeAreaInset(edge: .top) {
			PageTitle_Col2_NoPhoto(label: "VEHICLES")
		}

		// Toolbar: title label, report button, sort menu, and add button.
		.toolbar {
			if !vehicles.isEmpty {
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
						// Sort selection. Currently updates UI state; wire into queries to change store-side order.
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

		// Optional: Enable system search UI to pair with in-memory filtering.
		// .searchable(text: $searchText, placement: .automatic, prompt: Text("Search vehicles"))

		// Navigation destination for the PDF report (boolean-driven).
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportVehicles(trackVehicleSelected: .constant(dest.scope))
				.id("VehicleReport-\(dest.scope)") // ensure refresh if vehicle changes
				.ignoresSafeArea()
		}
		// Navigation destination for editing a newly created record (item-driven).
		.navigationDestination(item: $newRecordToEdit) { vehicle in
			EditVehicle(dataSet: vehicle, trackVehicleSelected: $trackVehicleSelected, startEditing: true)
				.id(vehicle.id)
		}
	}

	/// Builds a concise, human-readable vehicle description for accessibility and row subtitles.
	private func yearDescription(_ v: Vehicle8) -> String {
		let parts = [String(v.year), v.manufacturer, v.model, v.trim]
			.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
		return parts.joined(separator: " ")
	}

	/// Creates a new `Vehicle8` with minimal defaults, saves it, and navigates directly to its
	/// editor so the user can immediately provide details.
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
			// Trigger programmatic navigation to the editor for the newly created record.
			newRecordToEdit = newRecord
		} catch {
			print("Failed to save vehicle: \(error.localizedDescription)")
		}
	}

	/// Handles deletions from the filtered list by resolving each visible index back to the
	/// corresponding model object, deleting it from the context, and saving changes.
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

	/// Legacy deletion helper that assumes indices are from the unfiltered `vehicles` array.
	/// Kept for compatibility in case other views call it directly.
	func deleteVehicle(_ indexSet: IndexSet) {
		for index in indexSet {
			let vehicle = vehicles[index]
			modelContext.delete(vehicle)
		}
	}
}

/// Preview host that renders the view with an empty in-memory store to validate empty-state UI.
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

/// Preview host that seeds a few example vehicles into an in-memory store for visual validation
/// of list rendering, navigation, and accessibility labeling.
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


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
	@Environment(\.entitlements) private var entitlements

	/// User preference (persisted via AppStorage) that determines whether inactive vehicles
	/// should be included in the list. The toggle is surfaced in Settings; this view only reads it.
	@AppStorage("showInactiveVehicles") private var includeInactive: Bool = false

	/// Two SwiftData queries:
	/// - `activeVehicles`: Filters to vehicles where `inactive == false`.
	/// - `allVehicles`: Unfiltered, all records.
	/// The view chooses which to render at runtime via the `vehicles` computed property.
	@Query(
		filter: #Predicate<Vehicle8> { $0.inactive == false },
		sort: \Vehicle8.sortOrder,
		order: .forward
	)
	private var activeVehicles: [Vehicle8]

	@Query(
		sort: \Vehicle8.sortOrder,
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
	
	/// Edit mode for manual reordering
	@State private var isEditMode: Bool = false
	
	/// Derived list used to back the `ForEach` in the UI. This performs a simple in-memory search across
	/// commonly queried fields (name, manufacturer, model, trim, VIN, license plate). This is sufficient
	/// for moderate datasets and provides instant feedback while typing. If your dataset grows large,
	/// consider moving this logic into a SwiftData predicate to leverage store-side filtering.
	private var filteredVehicles: [Vehicle8] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return vehicles }
		return vehicles.filter { v in
			let haystack = [
				v.displayName,
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
	
#if os(iOS)
	/// Custom inline search field used in place of `.searchable` on iOS — see the
	/// `.safeAreaInset` usage below for why.
	private var searchField: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
			TextField("Search \(Vertical.current.assetPlural.lowercased())", text: $searchText)
				.textFieldStyle(.plain)
			if !searchText.isEmpty {
				Button {
					searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Clear search")
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
		.padding(.horizontal, 12)
		.padding(.top, 6)
		.padding(.bottom, 4)
	}
#endif

	var body: some View {
		// Layout: List with empty state fallback, row navigation to editor, and toolbar with report, sort, and add actions.
		List {
			// Empty-state guidance when there are no vehicles to show.
			if vehicles.isEmpty {
					EmptyStateSection(
						title: "Add your first \(Vertical.current.assetSingular.lowercased())",
						systemImage: Vertical.current.assetGroupIcon,
						description: "Create a new \(Vertical.current.assetSingular.lowercased()) to begin tracking, parts, fuel logs, travel logs, service items, service records.\n\nThe \(Vertical.current.assetPlural.lowercased()) entered here will be available in all the other tables.\n\nTo add additional \(Vertical.current.assetPlural.lowercased()), after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First \(Vertical.current.assetSingular)",
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
									if !isEditMode {
						Image_View_Thumbnail(imageData: vehicle.image1)
					}
									VStack(alignment: .leading, spacing: 1) {
										let year = String(vehicle.year)
										let manufacturer = vehicle.manufacturer
										let trim = vehicle.trim
										Text(vehicle.displayName)
											.font(.headline)
										Text("\(year) \(manufacturer) \(trim)")
											.font(.subheadline)
											.foregroundStyle(.secondary)
										if vehicle.mileage > 0, Vertical.current.id == .land {
											Text("Odometer: \(vehicle.mileage)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if vehicle.engHours > 0 {
											Text("\(Vertical.current.id == .land ? "Engine Hours" : Vertical.current.primaryMeterLabel): \(vehicle.engHours, specifier: "%.1f")")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										if let masterName = masterDisplayName(for: vehicle) {
											Text("Linked to: \(masterName)")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
										let linkedChildren = linkedChildrenNames(for: vehicle)
										if !linkedChildren.isEmpty {
											Text("Linked \(Vertical.current.assetPlural.lowercased()): \(linkedChildren.joined(separator: ", "))")
												.font(.subheadline)
												.foregroundStyle(.secondary)
										}
									}
									.cardStyle(backgroundColor: .blue.opacity(0.6))
									.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
							.accessibilityElement(children: .combine)
							.accessibilityLabel("\(vehicle.displayName), \(yearDescription(vehicle))")
							.accessibilityHint("Opens \(Vertical.current.assetSingular.lowercased()) details")
						}
					}
					// Map deletions from the filtered view back to the underlying model objects.
					.onDelete(perform: deleteFilteredVehicles)
					.conditionalModifier(isEditMode) { view in
						view.onMove(perform: performMove)
					}
				}
			}
		}
		
#if os(iOS)
		// .insetGrouped (the default here) wraps each Section in a floating card with its
		// own top/bottom margins — that's what was still leaving dead space around the
		// sort-order hint even after it stopped being a `header:`. .plain removes that
		// outer card margin; the custom cardStyle() on each row already provides the
		// visual grouping, so nothing is lost.
		.listStyle(.plain)
#endif
		.safeAreaInset(edge: .top) {
			VStack(spacing: 8) {
				PageTitle_Col2_NoPhoto(label: Vertical.current.assetPlural.uppercased())
#if os(iOS)
				// Inline rather than via .searchable: a system search bar renders in the
				// navigation bar drawer above this title, pushing this column's blue title
				// underline lower than the other columns'. Placing it here instead, in the
				// space above the sort-order hint, keeps that underline flush with the top.
				searchField
#endif
			}
		}

		// Toolbar: title label, report button, edit button, and add button.
		.toolbar {
			if !vehicles.isEmpty {
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
					Button {
						withAnimation {
							isEditMode.toggle()
						}
					} label: {
#if os(macOS)
						Image(systemName: isEditMode ? "checkmark" : "pencil")
#else
						VStack(spacing: 2) {
						Image(systemName: isEditMode ? "checkmark" : "pencil")
						Text(isEditMode ? "Done" : "Edit")
							.font(.caption2)
					}
#endif
					}
					.help(isEditMode ? "Done" : "Edit")
					.accessibilityLabel(isEditMode ? "Done editing" : "Edit order")
				}
			}
			// Moved the "Show Inactive" toggle to SettingsEditorView; no toggle here anymore.
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

#if os(macOS)
		// Enable system search UI to pair with in-memory filtering.
		.searchable(text: $searchText, placement: .automatic, prompt: Text("Search \(Vertical.current.assetPlural.lowercased())"))
#endif

		// Navigation destination for the PDF report (boolean-driven).
		.navigationDestination(item: $reportDestination) { dest in
			// The report owns and re-fetches its own scope via an in-report vehicle picker,
			// so no .id() here — that would reset the user's picker selection on navigation.
			pdfReportVehicles(trackVehicleSelected: dest.scope)
				.ignoresSafeArea()
		}
		// Navigation destination for editing a newly created record (item-driven).
		.navigationDestination(item: $newRecordToEdit) { vehicle in
			EditVehicle(dataSet: vehicle, trackVehicleSelected: $trackVehicleSelected, startEditing: true, isNewRecord: true)
				.id(vehicle.id)
		}
	}

	/// Builds a concise, human-readable vehicle description for accessibility and row subtitles.
	private func yearDescription(_ v: Vehicle8) -> String {
		let parts = [String(v.year), v.manufacturer, v.model, v.trim]
			.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
		return parts.joined(separator: " ")
	}

	/// Resolves the display name of the master vehicle this record links to, if any.
	/// Looks across `allVehicles` (not just the currently filtered/visible list) so the
	/// master's name still resolves even if it's inactive and hidden from view.
	private func masterDisplayName(for vehicle: Vehicle8) -> String? {
		guard !vehicle.linkedMasterVehicleId.isEmpty else { return nil }
		guard let master = allVehicles.first(where: { $0.name == vehicle.linkedMasterVehicleId }) else { return nil }
		return master.displayName.isEmpty ? master.name : master.displayName
	}

	/// Display names of any vehicles linked to this one as their master.
	private func linkedChildrenNames(for vehicle: Vehicle8) -> [String] {
		allVehicles
			.filter { $0.linkedMasterVehicleId == vehicle.name }
			.map { $0.displayName.isEmpty ? $0.name : $0.displayName }
	}

	/// Creates a new `Vehicle8` with minimal defaults, saves it, and navigates directly to its
	/// editor so the user can immediately provide details.
	private func addNewRecord() {
		guard entitlements.requestCreate(Vehicle8.self, in: modelContext) else { return }
		let maxSortOrder = vehicles.map { $0.sortOrder }.max() ?? -1
		let newRecord = Vehicle8(
			inactive: false,
			name: UUID().uuidString,
			displayName: "New \(Vertical.current.assetSingular.lowercased())",
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
			sortOrder: maxSortOrder + 1,
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

	/// Handles reordering of vehicles in the list by updating their sortOrder values.
	private func performMove(from source: IndexSet, to destination: Int) {
		var reorderedVehicles = filteredVehicles
		reorderedVehicles.move(fromOffsets: source, toOffset: destination)
		
		// Update sortOrder for all vehicles based on their new positions
		for (index, vehicle) in reorderedVehicles.enumerated() {
			vehicle.sortOrder = index
			vehicle.updatedAt = Date()
		}
		
		do {
			try modelContext.save()
		} catch {
			print("Failed to save reordered vehicles: \(error.localizedDescription)")
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


//
//  DisplayVendors.swift
//  LandShip
//
//  Purpose:
//  A SwiftUI list-based browser for the Vendors/Shops model (Vendors1). Provides
//  search, sorting, inline deletion, and programmatic navigation into an edit view.
//
//  Responsibilities:
//  - Query and display Vendors1 records using SwiftData
//  - Provide a flexible filter combining text search with an "include inactive" toggle
//  - Offer multiple sort options (name A–Z/Z–A, recently updated)
//  - Handle creation of a new vendor and navigate directly to its edit screen
//  - Support deletion with animated UI updates
//  - Present a friendly empty state when no vendors exist
//
//  Key Types & Dependencies:
//  - Vendors1: SwiftData model representing a vendor/shop
//  - EditIVendors: detail editor for a single vendor
//  - QueryView: helper that executes a SwiftData query and supplies results
//  - SwiftData: persistence and querying
//  - SwiftUI: presentation and navigation
//
//  Accessibility:
//  - Combines vendor fields into an accessibility label for each row
//  - Keeps list content concise and readable with clear hierarchy
//
//  Notes:
//  - The filter closure is built dynamically to avoid unnecessary predicates when not searching
//  - Programmatic navigation uses a temporary @State item to push the edit screen after creation
//
//  Created by JP on 8/12/25
//

import SwiftUI
import SwiftData

/// A list-based browser for vendor/shop records.
///
/// Features:
/// - Text search across common vendor fields
/// - Optional inclusion of inactive vendors (via AppStorage flag)
/// - Sort by name (ascending/descending) or most recently updated
/// - Add, delete, and navigate to edit a selected vendor
/// - Empty state with onboarding-style action
struct DisplayVendors: View {
	/// SwiftData model context for fetching, inserting, and deleting Vendors1 records.
	@Environment(\.modelContext) private var modelContext

	/// Selection binding for list rows (used to reflect the currently focused vendor).
	@State private var selectedRecord: Vendors1?
	/// User-entered search text. When non-empty, a predicate is applied across several fields.
	@State private var searchText: String = ""
	/// Persists the user's preference for including inactive vendors in results.
	/// Note: The key name is shared with other areas of the app.
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

	/// Holds a newly-created vendor to trigger programmatic navigation to its edit screen.
	@State private var newRecordToEdit: Vendors1?
	
	/// Sort options for the vendors list. Backed by a SwiftData SortDescriptor.
	private enum VendorSort: String, CaseIterable, Identifiable {
		// Name ascending (A–Z)
		case nameAsc = "Name A–Z"
		// Name descending (Z–A)
		case nameDesc = "Name Z–A"
		// Most recently updated first
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }

		/// Maps the UI selection to a concrete SwiftData SortDescriptor.
		var sortDescriptor: SortDescriptor<Vendors1> {
			switch self {
			case .nameAsc:
				return .init(\.vendorName, order: .forward)
			case .nameDesc:
				return .init(\.vendorName, order: .reverse)
			case .updatedDesc:
				return .init(\.updatedAt, order: .reverse)
			}
		}
	}
	/// The currently selected sort option (defaults to name ascending).
	@State private var selectedSort: VendorSort = .nameAsc

	var body: some View {
		// Normalize the search term once to keep predicates simple and stable.
		let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

		// Snapshot the toggle to avoid capturing a mutable state inside the predicate.
		let includeInactive = showInactiveVehicles

		// Build a dynamic filter that:
		// - Avoids a predicate when not searching and including inactive

		/*
		 Dynamically constructs a predicate only when needed.
		 Behavior:
		 - No search text:
		   - If including inactive: return nil to avoid filtering (fast path)
		   - Else: filter to active vendors only
		 - With search text:
		   - Combine the inactive condition with a multi-field contains() search
		 Returning `nil` allows QueryView to skip attaching a predicate.
		*/
		let filterClosure: (() -> Predicate<Vendors1>)? = {
			if trimmed.isEmpty {
				// No search: only filter out inactive when not showing inactive
				if includeInactive {
					return nil
				} else {
					return { #Predicate<Vendors1> { v in v.inactive == false } }
				}
			} else {
				// Search + optional inactive filter
				return { #Predicate<Vendors1> { v in
					(includeInactive || v.inactive == false) &&
					(
						v.vendorName.localizedStandardContains(trimmed) ||
						v.vendorType.localizedStandardContains(trimmed) ||
						v.vendorContact1.localizedStandardContains(trimmed) ||
						v.vendorContact2.localizedStandardContains(trimmed) ||
						v.vendorContact3.localizedStandardContains(trimmed) ||
						v.vendorCity.localizedStandardContains(trimmed) ||
						v.vendorState.localizedStandardContains(trimmed)
					)
				} }
			}
		}()

		// QueryView executes the SwiftData fetch and supplies results to the content closure.
		QueryView(for: Vendors1.self,
							sort: [selectedSort.sortDescriptor],
							content: { records in
			Group {
				if records.isEmpty {
					// Empty state shown when there are no vendors to display.
					List {
						EmptyStateSection(
							title: "Add your first Vendor / Shop",
							systemImage: "person.2.badge.gearshape",
							description: "Create a vendor or repair shop to streamline entry in service items and service records.\n\nTo add additional vendors, after this first one, select the '+' button at the top of the form.",
							actionTitle: "Add First Vendor",
							action: { addNewRecord() }
						)
					}
				} else {
					// Main list of vendors with navigation to the edit screen.
					Section {
						List(selection: $selectedRecord) {
							ForEach(records) { record in
								// Detail navigation: open the editor for the tapped vendor.
								NavigationLink {
									EditIVendors(vendors: record)
										.id(record.persistentModelID) // Keeps your split view detail refresh workaround
								} label: {
									VStack(alignment: .leading, spacing: 6) {
										Text(record.vendorName)
											.textModifier_ListTitle()
										HStack {
											Text(record.vendorContact1)
												.textModifier_ListSubTitle_L()
											Spacer()
											Text(record.vendorType)
												.textModifier_ListSubTitle_R()
										}
									}
									.accessibilityElement(children: .combine)
									.accessibilityLabel("\(record.vendorName), \(record.vendorType), contact \(record.vendorContact1)")
								}
							}
							// Enable swipe-to-delete on rows.
							.onDelete(perform: delete)
						}
						.textModifier_ListDivider()
						// Toolbar actions for sorting and adding vendors.
						.toolbar {
							ToolbarItem(placement: .automatic) {
								Menu {
									Picker("Sort by", selection: $selectedSort) {
										ForEach(VendorSort.allCases) { sortCase in
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
						// Compact, always-visible summary of the active sort.
						HStack(spacing: 6) {
							Image(systemName: "arrow.up.arrow.down")
							Text("Sort: \(selectedSort.rawValue)")
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 4)

						// Column title pinned to the safe area (large header style).
						.safeAreaInset(edge: .top) {
							PageTitle_Col2_NoPhoto(label: "VENDORS/SHOPS")
						}
					}
					
				}
			}
		}, filter: filterClosure)
		// System search field binds to `searchText` and updates the predicate.
		.searchable(text: $searchText, placement: .automatic, prompt: "Search vendors")
		// Pull to refresh is a no-op here; yielding allows UI to complete the gesture.
		.refreshable {
			await Task.yield()
		}
		// When a new vendor is created, push directly to its edit view.
		.navigationDestination(item: $newRecordToEdit) { record in
			EditIVendors(vendors: record, startEditing: true)
				.id(record.persistentModelID)
		}
	}

	/// Creates, inserts, saves, and navigates to a new vendor record.
	/// Selection is updated to reflect the inserted item.
	@MainActor
	private func addNewRecord() {
		let newRecord = makeNewVendor()
		withAnimation {
			// Persist the new record and trigger navigation on success.
			modelContext.insert(newRecord)
			do {
				try modelContext.save()
				// reflect selection in the list (optional)
				selectedRecord = newRecord
				// trigger navigation to edit this new record
				newRecordToEdit = newRecord
			} catch {
				print("Failed to save new vendor: \(error.localizedDescription)")
			}
		}
	}

	/// Deletes vendors at the given list offsets.
	/// Uses a fresh fetch in the current sort order to map offsets to models.
	@MainActor
	private func delete(at offsets: IndexSet) {
		// Map list offsets to models by fetching the current ordered set.
		do {
			let fetch = FetchDescriptor<Vendors1>(sortBy: [SortDescriptor(\.vendorName, order: .forward)])
			let current = try modelContext.fetch(fetch)
			let toDelete = offsets.compactMap { idx in current.indices.contains(idx) ? current[idx] : nil }
			withAnimation {
				for item in toDelete {
					modelContext.delete(item)
				}
			}
			try modelContext.save()
		} catch {
			print("Failed to delete vendor(s): \(error.localizedDescription)")
		}
	}

	/// Factory for a new Vendors1 with sensible defaults for immediate editing.
	private func makeNewVendor() -> Vendors1 {
		Vendors1(
			inactive: false, createdAt: Date(),
			updatedAt: Date(),
			vendorName: "New vendor name...",
			vendorType: "",
			vendorContact1: "",
			vendorContact2: "",
			vendorContact3: "",
			vendorAddress: "",
			vendorCity: "",
			vendorState: "",
			vendorZip: "",
			vendorPhone: "",
			vendorEmail: "",
			vendorWebsite: "",
			vendorNotes: "",
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: ""
		)
	}
}

/// Interactive preview with an in-memory model container and seeded vendors.
#Preview("Vendors – Sample Data") {
	makeVendorsPreview()
}

/// Builds a preview environment with sample data.
///
/// - Creates an in-memory SwiftData container
/// - Seeds a few representative vendors (active and inactive)
/// - Wraps the list in a NavigationStack so links function in previews
@MainActor
private func makeVendorsPreview() -> some View {
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vendors1.self, configurations: configuration)

	// Seed a few vendors
	let samples: [Vendors1] = [
		Vendors1(
			inactive: false, createdAt: Date().addingTimeInterval(-86400 * 10),
			updatedAt: Date().addingTimeInterval(-86400 * 2),
			vendorName: "Joe's Garage",
			vendorType: "Service & Repair",
			vendorContact1: "Joe Smith",
			vendorContact2: "Service Desk",
			vendorContact3: "",
			vendorAddress: "123 Main St",
			vendorCity: "Springfield",
			vendorState: "IL",
			vendorZip: "62704",
			vendorPhone: "555-123-4567",
			vendorEmail: "contact@joesgarage.example",
			vendorWebsite: "https://joesgarage.example",
			vendorNotes: "Open Mon–Sat. ASE certified.",
			image1: nil, image1Description: "",
			image2: nil, image2Description: "",
			image3: nil, image3Description: ""
		),
		Vendors1(
			inactive: false, createdAt: Date().addingTimeInterval(-86400 * 20),
			updatedAt: Date().addingTimeInterval(-86400 * 1),
			vendorName: "AutoParts Plus",
			vendorType: "Parts Vendor",
			vendorContact1: "Sally Jones",
			vendorContact2: "",
			vendorContact3: "",
			vendorAddress: "456 Commerce Blvd",
			vendorCity: "Madison",
			vendorState: "WI",
			vendorZip: "53703",
			vendorPhone: "555-987-6543",
			vendorEmail: "sales@autopartsplus.example",
			vendorWebsite: "https://autopartsplus.example",
			vendorNotes: "Fleet discounts available.",
			image1: nil, image1Description: "",
			image2: nil, image2Description: "",
			image3: nil, image3Description: ""
		),
		Vendors1(
			inactive: true, createdAt: Date().addingTimeInterval(-86400 * 30),
			updatedAt: Date(),
			vendorName: "City Motors",
			vendorType: "Auto Dealership",
			vendorContact1: "Reception",
			vendorContact2: "Service Dept",
			vendorContact3: "",
			vendorAddress: "789 Dealer Way",
			vendorCity: "Portland",
			vendorState: "OR",
			vendorZip: "97201",
			vendorPhone: "555-222-3344",
			vendorEmail: "info@citymotors.example",
			vendorWebsite: "https://citymotors.example",
			vendorNotes: "Loaner cars on request.",
			image1: nil, image1Description: "",
			image2: nil, image2Description: "",
			image3: nil, image3Description: ""
		)
	]
	let context = container.mainContext
	samples.forEach { context.insert($0) }
	try? context.save()

	// Wrap in NavigationStack so NavigationLink works in preview
	return NavigationStack {
		DisplayVendors()
	}
	.modelContainer(container)
}

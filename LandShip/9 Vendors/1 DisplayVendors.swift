//
//  DisplayItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct DisplayVendors: View {
	@Environment(\.modelContext) private var modelContext

	@State private var selectedRecord: Vendors1?
	@State private var searchText: String = ""

	// Sort handling
	private enum VendorSort: String, CaseIterable, Identifiable {
		case nameAsc = "Name A–Z"
		case nameDesc = "Name Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }

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
	@State private var selectedSort: VendorSort = .nameAsc

	var body: some View {
		// Precompute a trimmed term once to keep expressions simple
		let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

		// Build an optional filter closure for QueryView only when searching
		let filterClosure: (() -> Predicate<Vendors1>)? = trimmed.isEmpty
		? nil
		: { vendorFilterPredicate(term: trimmed) }

		QueryView(for: Vendors1.self,
							sort: [selectedSort.sortDescriptor],
							content: { records in
			Group {
				if records.isEmpty {
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
					Section {
						List(selection: $selectedRecord) {
							ForEach(records) { record in
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
							.onDelete(perform: delete)
						}
						.textModifier_ListDivider()
						.toolbar {
							// Title for this column
							ToolbarItem(placement: .principal) {
								LabelDataText_Toolbar(label: "VENDORS")
							}
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
//			.toolbar {
//				// Title for this column
//				ToolbarItem(placement: .principal) {
//					LabelDataText_Toolbar(label: "VENDORS")
//				}
//				ToolbarItem(placement: .automatic) {
//					Menu {
//						Picker("Sort by", selection: $selectedSort) {
//							ForEach(VendorSort.allCases) { sortCase in
//								Text(sortCase.rawValue).tag(sortCase)
//							}
//						}
//					} label: {
//						Label("Sort", systemImage: "arrow.up.arrow.down")
//					}
//					.buttonStyle(GrowingButton(buttonColor: Color.gray))
//					.accessibilityLabel("Sort parts")
//				}
//			}
	
			// Trailing actions for this column
//				ToolbarItemGroup(placement: .automatic) {
//					Menu {
//						Picker("Sort by", selection: $selectedSort) {
//							ForEach(VendorSort.allCases) { sortCase in
//								Text(sortCase.rawValue).tag(sortCase)
//							}
//						}
//					} label: {
//						Label("Sort", systemImage: "arrow.up.arrow.down")
//					}
//					.buttonStyle(GrowingButton(buttonColor: Color.gray))
//					.accessibilityLabel("Sort vendors")
//
//					Button {
//						addNewRecord()
//					} label: {
//						Label("Add", systemImage: "plus.capsule")
//					}
//				}
				
//			}
		}, filter: filterClosure)
		.searchable(text: $searchText, placement: .automatic, prompt: "Search vendors")
		.refreshable {
			await Task.yield()
		}
	}

	// MARK: - Predicate builder (kept small to help the type-checker)
	private func vendorFilterPredicate(term: String) -> Predicate<Vendors1> {
		#Predicate<Vendors1> { v in
			v.vendorName.localizedStandardContains(term) ||
			v.vendorType.localizedStandardContains(term) ||
			v.vendorContact1.localizedStandardContains(term) ||
			v.vendorContact2.localizedStandardContains(term) ||
			v.vendorContact3.localizedStandardContains(term) ||
			v.vendorCity.localizedStandardContains(term) ||
			v.vendorState.localizedStandardContains(term)
		}
	}

	// MARK: - Actions
	@MainActor
	private func addNewRecord() {
		let newRecord = makeNewVendor()
		withAnimation {
			modelContext.insert(newRecord)
			do {
				try modelContext.save()
			} catch {
				print("Failed to save new vendor: \(error.localizedDescription)")
			}
		}
	}

	@MainActor
	private func delete(at offsets: IndexSet) {
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

	// MARK: - Factory
	private func makeNewVendor() -> Vendors1 {
		Vendors1(
			createdAt: Date(),
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

#Preview("Vendors – Sample Data") {
	makeVendorsPreview()
}

@MainActor
private func makeVendorsPreview() -> some View {
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vendors1.self, configurations: configuration)

	// Seed a few vendors
	let samples: [Vendors1] = [
		Vendors1(
			createdAt: Date().addingTimeInterval(-86400 * 10),
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
			createdAt: Date().addingTimeInterval(-86400 * 20),
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
			createdAt: Date().addingTimeInterval(-86400 * 30),
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

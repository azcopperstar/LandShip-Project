//
//  DisplaySubscriptions.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData
import TipKit

struct DisplaySubscriptions: View {
	// MARK: - Data sources and environment
	
	// SwiftData context used to insert, save, and fetch data
	@Environment(\.modelContext) var modelContext
	
	@Query var vehicles: [Vehicle8]
	
	// For optional list selection (not strictly required for navigation, but useful on macOS)
	@State private var selectedRecord: Subscriptions?
	
	// Shared utility helpers
	let functions: Functions = Functions()
	
	// Access settings (units) without storing them in @State
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	
	// Helper to read unit strings without @State; protects against missing settings
	private func unit(_ index: Int) -> String {
		let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
			?? Array(repeating: "", count: 13)
		return arr[safe: index] ?? ""
	}
	
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	
	// Cross-view vehicle selection ("All Vehicles" means no filter)
	@State private var trackVehicleSelected: String = "All Vehicles"
	// Local selected vehicle object for ModelPicker
	@State private var selectedVehicle: Vehicle8?

	// MARK: - Navigation state
	
	// Used to navigate programmatically to EditSubscriptions immediately after creating a new record
	@State private var newRecordToEdit: Subscriptions?
	
	// Navigation to PDF report
	private struct ReportDestination: Hashable { let scope: String }
	@State private var reportDestination: ReportDestination?

	// MARK: - Sorting
	
	// Sort options for the records list. Each case defines a set of SortDescriptors.
	private enum PartsSort: String, CaseIterable, Identifiable {
		case dateDesc = "Date ↓"
		case dateAsc = "Date ↑"
		case datedDesc_vehicleAsc = "Vehicle A–Z, Date Desc"
		case vehicleAsc_nameAsc = "Vehicle A–Z, Expenses A–Z"
		case vehicleAsc_nameDesc = "Vehicle A–Z, Expenses Z–A"
		case nameAsc = "Expenses A–Z"
		case nameDesc = "Expenses Z–A"
		case updatedDesc = "Recently Updated"
		var id: String { rawValue }
		
		// Translate each sort mode into SwiftData SortDescriptors on Subscriptions
		var descriptors: [SortDescriptor<Subscriptions>] {
			switch self {
				case .dateDesc:
					return [ .init(\.createdAt, order: .reverse) ]
				case .dateAsc:
					return [ .init(\.createdAt, order: .forward) ]
				case .datedDesc_vehicleAsc:
					return [.init(\.vehicleId, order: .forward), .init(\.updatedAt, order: .reverse)]
				case .vehicleAsc_nameAsc:
					return [.init(\.vehicleId, order: .forward), .init(\.updatedAt, order: .forward)]
				case .vehicleAsc_nameDesc:
					return [.init(\.vehicleId, order: .forward), .init(\.updatedAt, order: .reverse)]
				case .nameAsc:
					return [ .init(\.itemName, order: .forward) ]
				case .nameDesc:
					return [ .init(\.itemName, order: .reverse) ]
				case .updatedDesc:
					return [ .init(\.updatedAt, order: .reverse) ]
			}
		}
	}
	
	// Current sort selection; defaults to vehicle A–Z and date descending
	@AppStorage("sort_subscriptions") private var selectedSort: PartsSort = .dateDesc
	
	// MARK: - Body
	
	var body: some View {
		// Vehicle filter row
		ModelPicker(
			selection: $selectedVehicle,
			title: "",
			includeEmptyChoice: true,
			emptyChoiceLabel: "All Vehicles",
			autoSelectFirst: false,
			filter: nil,
			sort: [SortDescriptor(\.displayName, order: .forward)],
			labelProvider: { v in "\(v.year) \(v.displayName)" },
			thumbnailData: { $0.image1 }
		)
		.frame(maxWidth: .infinity)
		.onChange(of: selectedVehicle) { _, newVehicle in
			trackVehicleSelected = newVehicle?.name ?? "All Vehicles"
		}
		.onChange(of: trackVehicleSelected) { _, newValue in
			if newValue == "All Vehicles" {
				selectedVehicle = nil
			} else {
				if let match = vehicles.first(where: { $0.name == newValue }) {
					if selectedVehicle?.persistentModelID != match.persistentModelID {
						selectedVehicle = match
					}
				} else {
					selectedVehicle = nil
				}
			}
		}
		.onAppear {
			if trackVehicleSelected != "All Vehicles" {
				selectedVehicle = vehicles.first(where: { $0.name == trackVehicleSelected })
			} else {
				selectedVehicle = nil
			}
		}
		#if os(iOS) || os(macOS)
		.safeAreaInset(edge: .top) {
			PageTitle_Col2_NoPhoto(label: "EXPENSES")
		}
		#endif
		.toolbar {
			// Open PDF report
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
			// Sort menu: presents all sort cases via a Picker
			ToolbarItem(placement: .automatic) {
				Menu {
					Picker("Sort by", selection: $selectedSort) {
						ForEach(PartsSort.allCases) { sortCase in
							Text(sortCase.rawValue).tag(sortCase)
						}
					}
				} label: {
#if os(macOS)
					Image(systemName: "arrow.up.arrow.down")
#else
					VStack(spacing: 2) {
						Image(systemName: "arrow.up.arrow.down")
						Text("Sort")
							.font(.caption2)
					}
#endif
				}
				.buttonStyle(GrowingButton(buttonColor: Color.gray))
				.help("Sort")
				.accessibilityLabel("Sort records")
			}
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
		// Destination used for programmatic navigation after adding a record
		.navigationDestination(item: $newRecordToEdit) { record in
			EditSubscriptions(Records: record, startEditing: true)
		}
		// Destination used to show the PDF report programmatically
		.navigationDestination(item: $reportDestination) { dest in
			pdfReportSubscriptions(trackVehicleSelected: dest.scope)
				.ignoresSafeArea()
		}

		// Main records list. QueryView fetches Subscriptions with the selected sort order.
		QueryView(for: Subscriptions.self, sort: selectedSort.descriptors) { records in
			if records.isEmpty {
				// Empty state with a helpful CTA to add the first record
				List {
					EmptyStateSection(
						title: "Add your first Expense, Subscription or Recurring Charge",
						systemImage: "square.grid.3x1.folder.badge.plus",
						description: "Create an expense, subscription or recurring charge to track items.\n\nTo add additional records after this first one, select the '+' button at the top of the form.",
						actionTitle: "Add First Expenditure",
						action: { addNewRecord() }
					)
				}
			} else {
				if trackVehicleSelected == "All Vehicles" {
					// All Vehicles: group by vehicle, then category/subcategory within each vehicle
					let byVehicle = Dictionary(grouping: records) { (rec: Subscriptions) in
						rec.vehicleId.isEmpty ? "No Vehicle Assigned" : rec.vehicleId
					}
					Section {
						List(selection: $selectedRecord) {
							ForEach(byVehicle.keys.sorted(), id: \.self) { vehicleKey in
								Section(header:
									HStack {
										Text(vehicleKey)
											.font(.headline)
											.fontWeight(.heavy)
											.textCase(nil)
											.foregroundStyle(.primary)
										Spacer(minLength: 0)
									}
									.padding(.vertical, 6)
									.padding(.horizontal, 10)
								) {
									let vehicleRecords = byVehicle[vehicleKey] ?? []
									let grouped = Dictionary(grouping: vehicleRecords) { (rec: Subscriptions) in
										rec.category.isEmpty ? "Uncategorized" : rec.category
									}
									ForEach(grouped.keys.sorted(), id: \.self) { catKey in
										Text(catKey)
											.font(.footnote)
											.fontWeight(.semibold)
											.foregroundStyle(.secondary)
											.textCase(nil)
											.listRowBackground(Color.secondary.opacity(0.12))
										let subGrouped = Dictionary(grouping: grouped[catKey] ?? []) { (rec: Subscriptions) in
											rec.subCategory.isEmpty ? "—" : rec.subCategory
										}
										let subKeys = subGrouped.keys.sorted()
										ForEach(subKeys, id: \.self) { subKey in
											if subKey != "—" {
												Text(subKey)
													.font(.footnote)
													.foregroundStyle(.secondary)
													.textCase(nil)
													.listRowBackground(Color.secondary.opacity(0.08))
											}
											ForEach(subGrouped[subKey] ?? []) { record in
												NavigationLink {
													EditSubscriptions(Records: record)
														.id(record.id)
												} label: {
													HStack(spacing: 6) {
														VStack(alignment: .leading, spacing: 2) {
															Text(record.itemName)
																.font(.footnote)
																.fontWeight(.medium)
																.lineLimit(1)
															if record.itemRecurring {
																Text("(Recurring Charge)")
																	.font(.caption2)
																	.foregroundStyle(.secondary)
															}
														}
														Spacer()
														VStack(alignment: .trailing, spacing: 1) {
															Text(record.itemCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
																.font(.footnote)
																.foregroundStyle(.secondary)
																.monospacedDigit()
															if record.itemRecurring {
																let n = record.itemRecurringDays
																let abbr = n == 1
																	? (record.itemRecurringInterval == "Day" ? "/day"
																	   : record.itemRecurringInterval == "Month" ? "/mo"
																	   : record.itemRecurringInterval == "Year" ? "/yr" : "")
																	: (record.itemRecurringInterval == "Day" ? "/\(n) days"
																	   : record.itemRecurringInterval == "Month" ? "/\(n) mos"
																	   : record.itemRecurringInterval == "Year" ? "/\(n) yrs" : "")
																if !abbr.isEmpty {
																	Text(abbr)
																		.font(.caption2)
																		.foregroundStyle(.tertiary)
																}
															}
														}
													}
													.padding(.vertical, 1)
												}
											}
										}
									}
								}
							}
							// Vehicle totals
							Section(header: Text("Vehicle Totals").font(.caption).foregroundStyle(.secondary)) {
								ForEach(byVehicle.keys.sorted(), id: \.self) { vehicleKey in
									let subtotal = (byVehicle[vehicleKey] ?? []).reduce(0 as Float) { $0 + $1.itemCost }
									HStack {
										Text(vehicleKey)
										Spacer()
										Text(subtotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
											.monospacedDigit()
											.foregroundStyle(.tertiary)
									}
									.font(.caption2)
								}
								let grandTotal = records.reduce(0 as Float) { $0 + $1.itemCost }
								HStack {
									Text("Total")
										.font(.caption)
										.fontWeight(.semibold)
									Spacer()
									Text(grandTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
										.font(.caption)
										.monospacedDigit()
										.fontWeight(.semibold)
								}
							}
						}
						.listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
						#if os(iOS) || os(watchOS) || os(tvOS)
						.listRowSpacing(2)
						#endif
						.listSectionSeparator(.visible)
						#if os(iOS) || os(watchOS) || os(tvOS)
						.listStyle(.insetGrouped)
						#else
						.listStyle(.inset)
						#endif
					} header: {
						HStack(spacing: 6) {
							Image(systemName: "arrow.up.arrow.down")
							Text("Sort: \(selectedSort.rawValue)")
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.padding(.top, 4)
					}
				} else {
					// Single vehicle: group by category then subcategory
					let grouped = Dictionary(grouping: records) { (rec: Subscriptions) in
						rec.category.isEmpty ? "Uncategorized" : rec.category
					}
					Section {
						List(selection: $selectedRecord) {
							ForEach(grouped.keys.sorted(), id: \.self) { key in
								Section(header:
									HStack {
										Text(key)
											.font(.headline)
											.fontWeight(.heavy)
											.textCase(nil)
											.foregroundStyle(.primary)
										Spacer(minLength: 0)
									}
									.padding(.vertical, 6)
									.padding(.horizontal, 10)
								) {
									let subGrouped = Dictionary(grouping: grouped[key] ?? []) { (rec: Subscriptions) in
										rec.subCategory.isEmpty ? "—" : rec.subCategory
									}
									let subKeys = subGrouped.keys.sorted()
									ForEach(subKeys, id: \.self) { subKey in
										if subKey != "—" {
											Text(subKey)
												.font(.footnote)
												.foregroundStyle(.secondary)
												.textCase(nil)
												.listRowBackground(Color.secondary.opacity(0.08))
										}
										ForEach(subGrouped[subKey] ?? []) { record in
											NavigationLink {
												EditSubscriptions(Records: record)
													.id(record.id)
											} label: {
												HStack(spacing: 6) {
													VStack(alignment: .leading, spacing: 2) {
														Text(record.itemName)
															.font(.footnote)
															.fontWeight(.medium)
															.lineLimit(1)
														if record.itemRecurring {
															Text("(Recurring Charge)")
																.font(.caption2)
																.foregroundStyle(.secondary)
														}
													}
													Spacer()
													VStack(alignment: .trailing, spacing: 1) {
														Text(record.itemCost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
															.font(.footnote)
															.foregroundStyle(.secondary)
															.monospacedDigit()
														if record.itemRecurring {
															let n = record.itemRecurringDays
															let abbr = n == 1
																? (record.itemRecurringInterval == "Day" ? "/day"
																   : record.itemRecurringInterval == "Month" ? "/mo"
																   : record.itemRecurringInterval == "Year" ? "/yr" : "")
																: (record.itemRecurringInterval == "Day" ? "/\(n) days"
																   : record.itemRecurringInterval == "Month" ? "/\(n) mos"
																   : record.itemRecurringInterval == "Year" ? "/\(n) yrs" : "")
															if !abbr.isEmpty {
																Text(abbr)
																	.font(.caption2)
																	.foregroundStyle(.tertiary)
															}
														}
													}
												}
												.padding(.vertical, 1)
											}
										}
									}
								}
							}
							// Category totals
							Section(header: Text("Category Totals").font(.caption).foregroundStyle(.secondary)) {
								ForEach(grouped.keys.sorted(), id: \.self) { key in
									let subtotal = (grouped[key] ?? []).reduce(0 as Float) { partial, rec in
										partial + (rec.itemCost)
									}
									VStack(alignment: .leading, spacing: 4) {
										HStack {
											Text(key)
											Spacer()
											Text(subtotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
												.monospacedDigit()
												.foregroundStyle(.tertiary)
										}
										.font(.caption2)
										let subTotals = Dictionary(grouping: grouped[key] ?? []) { $0.subCategory.isEmpty ? "—" : $0.subCategory }
										ForEach(subTotals.keys.sorted(), id: \.self) { subKey in
											let sub = (subTotals[subKey] ?? []).reduce(0 as Float) { $0 + $1.itemCost }
											HStack {
												Text("  • \(subKey)")
												Spacer()
												Text(sub.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
													.monospacedDigit()
													.foregroundStyle(.tertiary)
											}
											.font(.caption2)
										}
									}
								}
								let grandTotal = grouped.values.flatMap { $0 }.reduce(0 as Float) { partial, rec in
									partial + (rec.itemCost)
								}
								HStack {
									Text("Total")
										.font(.caption)
										.fontWeight(.semibold)
									Spacer()
									Text(grandTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
										.font(.caption)
										.monospacedDigit()
										.fontWeight(.semibold)
								}
							}
						}
						.listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
						#if os(iOS) || os(watchOS) || os(tvOS)
						.listRowSpacing(2)
						#endif
						.listSectionSeparator(.visible)
						#if os(iOS) || os(watchOS) || os(tvOS)
						.listStyle(.insetGrouped)
						#else
						.listStyle(.inset)
						#endif
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
			// SwiftData predicate applied by QueryView:
			// - If showInactiveVehicles is true, include inactive and active records.
			// - Otherwise, exclude inactive records.
			#Predicate { item in
				((trackVehicleSelected == "All Vehicles") || item.vehicleId.contains(trackVehicleSelected))
				&& (showInactiveVehicles || (item.inactive == false))
			}
		}
	}
	
	// MARK: - Record creation
	
	/// Creates a new Subscriptions and navigates to edit it.
	/// Behavior:
	/// - Inserts and saves the record in the SwiftData modelContext.
	/// - Triggers programmatic navigation to EditSubscriptions in editing mode.
	private func addNewRecord() {
		let newRecord = Subscriptions(
			inactive: false,
			createdAt: Date(),
			updatedAt: Date(),
			vehicleId: trackVehicleSelected == "All Vehicles" ? "" : trackVehicleSelected,
			miles: 0,
			engHours: 0,
			itemName: "(New Subscriptions or Recurring Charge)",
			itemDescription: "",
			itemNotes: "",
			itemVendor: "",
			category: "",
			subCategory: "",
			itemCost: 0,
			image1: nil,
			image1Description: "",
			image2: nil,
			image2Description: "",
			image3: nil,
			image3Description: "",
			image4: nil,
			image4Description: "",
			image5: nil,
			image5Description: ""
		)
		
		modelContext.insert(newRecord)
		do {
			try modelContext.save()
			// Defer navigation so SwiftData's re-fetch settles before triggering the destination
			DispatchQueue.main.async {
				newRecordToEdit = nil
				DispatchQueue.main.async {
					newRecordToEdit = newRecord
				}
			}
		} catch {
			print("Failed to save subscription record: \(error.localizedDescription)")
		}
	}
}

// MARK: - Tips
struct SubscriptionsTips: Tip {
	var title: Text { Text("Subscriptions & Expenses") }
	var message: Text? {
		Text("Track recurring charges, subscriptions, and one-time expenses for your vehicles to monitor ongoing costs.")
	}
	var image: Image? { Image(systemName: "square.grid.3x1.folder.badge.plus") }
}

// MARK: - Previews
// Previews build an in-memory model container, seed sample data, and demonstrate the list

#Preview("DisplaySubscriptions – Seeded Data") {
	@MainActor
	func makeContainer() -> ModelContainer {
		let config = ModelConfiguration(isStoredInMemoryOnly: true)
		return try! ModelContainer(for: Vehicle8.self, Subscriptions.self, Settings1.self, configurations: config)
	}
	
	let container = makeContainer()
	let context = container.mainContext

	// Seed vehicles
	let vehicleA = Vehicle8(name: "Vehicle A", year: 2021, mileage: 12050, engHours: 12.5, fuelType: "Gasoline", fuelCapacity: 26)
	let vehicleB = Vehicle8(name: "Vehicle B", year: 2019, mileage: 5400, engHours: 4.0, fuelType: "Diesel", fuelCapacity: 32)
	context.insert(vehicleA)
	context.insert(vehicleB)

	// Seed subscriptions
	let sub1 = Subscriptions(
		inactive: false,
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: "Vehicle A",
		miles: 12050,
		engHours: 12.5,
		itemName: "Insurance",
		itemDescription: "Monthly auto insurance",
		itemNotes: "",
		itemVendor: "State Farm",
		category: "Insurance",
		subCategory: "Auto",
		itemCost: 150,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: "",
		image4: nil,
		image4Description: "",
		image5: nil,
		image5Description: ""
	)
	let sub2 = Subscriptions(
		inactive: false,
		createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
		updatedAt: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
		vehicleId: "Vehicle A",
		miles: 11820,
		engHours: 11.9,
		itemName: "Roadside Assistance",
		itemDescription: "AAA membership",
		itemNotes: "",
		itemVendor: "AAA",
		category: "Services",
		subCategory: "Emergency",
		itemCost: 75,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: "",
		image4: nil,
		image4Description: "",
		image5: nil,
		image5Description: ""
	)
	context.insert(sub1)
	context.insert(sub2)

	// Seed settings
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

	return NavigationStack {
		DisplaySubscriptions()
			.modelContainer(container)
			.navigationTitle("Subscriptions")
	}
}


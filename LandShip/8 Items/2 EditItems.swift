/**
 EditItems.swift
 LandShip
 
 Created by JP on 8/12/25
 
 Overview
 --------
 EditItems is a SwiftUI view responsible for viewing and editing a single service item template (`MxItems3`). A service item template describes a maintenance task (e.g., "Oil and Filter Change") that can be applied to a specific vehicle and system, with optional vendor information, cost breakdowns (labor and up to five parts), service intervals (months/miles/hours), and illustrative images.
 
 Key Responsibilities
 --------------------
 - Display all persisted fields of an `MxItems3` record in a readable layout when not editing.
 - Provide an edit experience with inline controls (text inputs, number pads, model pickers) to modify the underlying record.
 - Compute derived statistics such as per-part totals, overall parts total, grand total, and simple usage stats (line count, quantity sums, averages).
 - Show vehicle context (current miles/hours) and last service details for the selected item to estimate next-due mileage/hours/date based on configured intervals.
 - Persist changes via SwiftData (`modelContext.save()`), and support record deletion or deactivation.
 
 Data Flow & Persistence
 -----------------------
 - The view holds a local mutable copy of an `MxItems3` instance in `@State` (`dataSet`). Most UI fields mirror this state and push changes back into `dataSet` on save.
 - SwiftData is accessed via `@Environment(\.modelContext)` for reads (fetch descriptors) and writes (save, delete).
 - Pickers (Vehicle, System, Vendor, and Parts) are backed by SwiftData models (`Vehicle8`, `VehicleSystems1`, `Vendors1`, `MxParts1`) and synchronize selected values to the item fields.
 
 Editing vs. Viewing
 -------------------
 - The view toggles between two modes using `isEditing`.
   - View Mode: read-only presentation of the `MxItems3` data and computed totals/stats.
   - Edit Mode: interactive controls for modifying fields. The toolbar exposes Cancel and Save actions.
 
 Vehicle & Service Stats
 -----------------------
 - On appear and when relevant fields change (vehicle, item name, intervals), the view recomputes:
   - Last service record for this vehicle + item (date, miles, engine hours).
   - Miles/hours since service and remaining to due.
   - Estimated next due date based on interval months.
 
 Notes for Maintainers
 ---------------------
 - This view intentionally avoids business-logic side effects beyond saving the edited item. More advanced scheduling, notifications, or cross-record updates should live in dedicated services.
 - When adding new fields to `MxItems3`, remember to:
   1. Mirror them in local `@State` (for edit mode),
   2. Bind them in the form controls,
   3. Assign them back in `updateItem()` before saving,
   4. Display them in view mode if appropriate.
 */

import SwiftUI
import SwiftData

/// A detail/edit view for a single `MxItems3` (service item template).
/// - Presents a read-only summary and an editable form for all fields.
/// - Integrates with SwiftData for fetching related models and saving updates.
/// - Computes service statistics (last service, next due) based on vehicle data and intervals.
struct EditItems: View {
	
	// MARK: - User preferences
	// Controls whether inactive vehicles should appear in pickers and lists.
	@AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false

	// MARK: - Backing model state
	// Local, editable copy of the incoming `MxItems3` record used to drive the UI.
	@State private var dataSet: MxItems3
	
	// MARK: - Environment
	// SwiftData context for fetching/saving and a dismiss action for navigation.
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	
	let functions: Functions = Functions()
	
	// MARK: - UI State
	// Transient state for dialogs and mode toggling.
	@State private var isPresentingConfirm: Bool = false

	@State private var isEditing: Bool = false
	
	// MARK: - Editable fields mirroring `MxItems3`
	// These track user edits while in edit mode. On save, they are copied back to `dataSet`.
	@State private var inactive: Bool = false
	
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vehicleId = ""
	@State private var vehicleSystem: String = ""
	@State private var mxName: String = ""
	@State private var mxDescription: String = ""
	@State private var Notes: String = ""
	@State private var vendor: String = ""
	@State private var laborCost: Float = 0
	@State private var intervalMonths: Int = 0
	@State private var intervalMiles: Int = 0
	@State private var intervalHours: Float = 0
	@State private var part1: String = ""
	@State private var part1Id: String = ""
	@State private var part1Qty: Float = 0
	@State private var part1cost: Float = 0
	@State private var part1Unit: String = "Each"
	@State private var part2: String = ""
	@State private var part2Id: String = ""
	@State private var part2Qty: Float = 0
	@State private var part2cost: Float = 0
	@State private var part2Unit: String = "Each"
	@State private var part3: String = ""
	@State private var part3Id: String = ""
	@State private var part3Qty: Float = 0
	@State private var part3cost: Float = 0
	@State private var part3Unit: String = "Each"
	@State private var part4: String = ""
	@State private var part4Id: String = ""
	@State private var part4Qty: Float = 0
	@State private var part4cost: Float = 0
	@State private var part4Unit: String = "Each"
	@State private var part5: String = ""
	@State private var part5Id: String = ""
	@State private var part5Qty: Float = 0
	@State private var part5cost: Float = 0
	@State private var part5Unit: String = "Each"
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// MARK: - Units & vehicle context
	// Units are loaded from user settings to render labels. Vehicle readings are pulled to
	// compute since-service and remaining-to-due metrics.
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		units.indices.contains(index) ? units[index] : ""
	}
	@State private var vehicleCurrentMiles: Int = 0
	@State private var vehicleCurrentEngHours: Float = 0.0

	// Last service and next due stats for this item+vehicle
	@State private var lastServiceDate: Date? = nil
	@State private var lastServiceMiles: Int = 0
	@State private var lastServiceEngHours: Float = 0.0
	@State private var milesSinceService: Int = 0
	@State private var hoursSinceService: Float = 0.0
	@State private var milesRemainingToDue: Int = 0
	@State private var hoursRemainingToDue: Float = 0.0
	@State private var daysRemainingToDue: Int = 0
	@State private var nextDueDate: Date? = nil

	// MARK: - Computed totals & aggregates
	// These values are derived live from the editable fields to keep the UI reactive.
	// - partsLinesCount: counts non-empty part lines with positive quantity
	// - totalPartsQuantity: sum of all part quantities (ignoring negatives)
	// - avgCostPerPartUnit: parts total divided by total quantity
	// - partXTotal: quantity * unit cost for each line
	// - partsTotal: sum of all part line totals
	// - grandTotal: partsTotal + labor cost
	private var partsLinesCount: Int {
		let lines: [(String, Float)] = [
			(part1, part1Qty),
			(part2, part2Qty),
			(part3, part3Qty),
			(part4, part4Qty),
			(part5, part5Qty)
		]
		return lines.filter { !$0.0.isEmpty && $0.1 > 0 }.count
	}
	private var totalPartsQuantity: Double {
		max(0, Double(part1Qty)) +
		max(0, Double(part2Qty)) +
		max(0, Double(part3Qty)) +
		max(0, Double(part4Qty)) +
		max(0, Double(part5Qty))
	}
	private var avgCostPerPartUnit: Double {
		let qty = totalPartsQuantity
		return qty > 0 ? partsTotal / qty : 0.0
	}

	// Reactive totals (computed)
	private var part1Total: Double { Double(part1Qty) * Double(part1cost) }
	private var part2Total: Double { Double(part2Qty) * Double(part2cost) }
	private var part3Total: Double { Double(part3Qty) * Double(part3cost) }
	private var part4Total: Double { Double(part4Qty) * Double(part4cost) }
	private var part5Total: Double { Double(part5Qty) * Double(part5cost) }
	private var partsTotal: Double { part1Total + part2Total + part3Total + part4Total + part5Total }
	private var grandTotal: Double { partsTotal + Double(laborCost) }
	
	// MARK: - Picker selections
	// Bindings for ModelPicker/PartPickerRow components. These sync to the mirrored fields.
	@State private var selectedVehicle: Vehicle8? = nil
    @State private var selectedSystem: VehicleSystems1? = nil
    @State private var selectedVendor: Vendors1? = nil
    @State private var selectedPart1: MxParts1? = nil
    @State private var selectedPart2: MxParts1? = nil
    @State private var selectedPart3: MxParts1? = nil
    @State private var selectedPart4: MxParts1? = nil
    @State private var selectedPart5: MxParts1? = nil
	
	/// Initializes the view with an existing `MxItems3` record.
	/// - Parameters:
	///   - mxItems: The item to display/edit.
	///   - startEditing: When true, the view opens directly in edit mode.
	init(mxItems: MxItems3, startEditing: Bool = false) {
		self.dataSet = mxItems
		self._inactive = State(initialValue: dataSet.inactive)
		
		self._createdAt = State(initialValue: dataSet.createdAt)
		self._updatedAt = State(initialValue: dataSet.updatedAt)
		self._vehicleId = State(initialValue: dataSet.vehicleId)
		self._vehicleSystem = State(initialValue: dataSet.vehicleSystem)
		self._mxName = State(initialValue: dataSet.mxName)
		self._mxDescription = State(initialValue: dataSet.mxDescription)
		self._Notes = State(initialValue: dataSet.Notes)
		self._vendor = State(initialValue: dataSet.vendor)
		self._laborCost = State(initialValue: dataSet.laborCost)
		self._intervalMonths = State(initialValue: dataSet.intervalMonths)
		self._intervalMiles = State(initialValue: dataSet.intervalMiles)
		self._intervalHours = State(initialValue: dataSet.intervalHours)
		
		self._part1 = State(initialValue: dataSet.part1)
		self._part1Id = State(initialValue: dataSet.part1Id)
		self._part1Qty = State(initialValue: dataSet.part1Qty)
		self._part1cost = State(initialValue: dataSet.part1cost)
		self._part1Unit = State(initialValue: dataSet.part1Unit)

		self._part2 = State(initialValue: dataSet.part2)
		self._part2Id = State(initialValue: dataSet.part2Id)
		self._part2Qty = State(initialValue: dataSet.part2Qty)
		self._part2cost = State(initialValue: dataSet.part2cost)
		self._part2Unit = State(initialValue: dataSet.part2Unit)

		self._part3 = State(initialValue: dataSet.part3)
		self._part3Id = State(initialValue: dataSet.part3Id)
		self._part3Qty = State(initialValue: dataSet.part3Qty)
		self._part3cost = State(initialValue: dataSet.part3cost)
		self._part3Unit = State(initialValue: dataSet.part3Unit)

		self._part4 = State(initialValue: dataSet.part4)
		self._part4Id = State(initialValue: dataSet.part4Id)
		self._part4Qty = State(initialValue: dataSet.part4Qty)
		self._part4cost = State(initialValue: dataSet.part4cost)
		self._part4Unit = State(initialValue: dataSet.part4Unit)

		self._part5 = State(initialValue: dataSet.part5)
		self._part5Id = State(initialValue: dataSet.part5Id)
		self._part5Qty = State(initialValue: dataSet.part5Qty)
		self._part5cost = State(initialValue: dataSet.part5cost)
		self._part5Unit = State(initialValue: dataSet.part5Unit)
		
		self._image1 = State(initialValue: dataSet.image1)
		self._image2 = State(initialValue: dataSet.image2)
		self._image3 = State(initialValue: dataSet.image3)
		self._image1Description = State(initialValue: dataSet.image1Description)
		self._image2Description = State(initialValue: dataSet.image2Description)
		self._image3Description = State(initialValue: dataSet.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	var body: some View {
		// The UI toggles between Edit Mode and View Mode based on `isEditing`.
		if isEditing {
			
			// EDIT MODE: Interactive controls and pickers for all editable fields.
			ScrollView {
				// General vehicle/system selection and status.
				CardView {
					VStack {
						SectionText(label: "GENERAL")
//						HStack{
							
							LabeledContent {
								ModelPicker(
									selection: $selectedVehicle,
									title: "Vehicle",
									includeEmptyChoice: false,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: nil,
									sort: [SortDescriptor(\.name, order: .forward)],
									labelProvider: { $0.name }
								)
								.onChange(of: selectedVehicle) { _, newVehicle in
									let name = newVehicle?.name ?? ""
									vehicleId = name
									dataSet.vehicleId = name
									refreshVehicleDetails()
									loadLastServiceForItem()
								}
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Vehicle")
									.textLabelModified()
							}

							
							LabeledContent {
//								let currentVehicle = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
//								let systemsFilter: Predicate<VehicleSystems1>? = currentVehicle.isEmpty ? nil : #Predicate<VehicleSystems1> { $0.vehicleId == currentVehicle }
								ModelPicker<VehicleSystems1>(
									selection: $selectedSystem,
									title: "Vehicle System",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: {
										if vehicleId.isEmpty || vehicleId == "All Vehicles" {
											return nil
										}
										return #Predicate<VehicleSystems1> { sys in
											sys.vehicleId == vehicleId
										}
									}(),
									sort: [SortDescriptor(\.systemName, order: .forward)],
									labelProvider: { s in s.systemName },
									onSelectionChanged: { sel in
										vehicleSystem = sel?.systemName ?? ""
									}
								)
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Vehicle System")
									.textLabelModified()
							}

							
//						HStack{
//							Text("Vehicle System")
//								.textLabelModified()
//							let currentVehicle = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
//							let systemsFilter: Predicate<VehicleSystems1>? = currentVehicle.isEmpty ? nil : #Predicate<VehicleSystems1> { $0.vehicleId == currentVehicle }
//							ModelPicker(
//								selection: $selectedSystem,
//								title: "Vehicle System",
//								includeEmptyChoice: true,
//								emptyChoiceLabel: "—",
//								autoSelectFirst: false,
//								filter: systemsFilter,
//								sort: [SortDescriptor(\.systemName, order: .forward)],
//								labelProvider: { $0.systemName }
//							)
//							.onChange(of: selectedSystem) { _, newSystem in
//								let name = newSystem?.systemName ?? ""
//								vehicleSystem = name
//								dataSet.vehicleSystem = name
//							}
//							.frame(maxWidth: .infinity, alignment: .trailing)
//						}
						HStack{ LabelDataText(label: "Status", data: inactive ? "Inactive" : "Active") }
					}
				}
				
				// Core item metadata: name, description, notes, vendor.
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataTextview(label: "Item Name", data: $mxName)}
							.onChange(of: mxName) { _, _ in
								loadLastServiceForItem()
							}
						HStack{LabelDataTextview(label: "Item Description", data: $mxDescription)}

						LabeledContent {
							ModelPicker(
								selection: $selectedVendor,
								title: "Vendor",
								includeEmptyChoice: true,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.vendorName, order: .forward)],
								labelProvider: { $0.vendorName },
								onSelectionChanged: { sel in
									vendor = sel?.vendorName ?? ""
								}
							)
//							.onChange(of: selectedVendor) { _, newVendor in
//								let name = newVendor?.vendorName ?? ""
//								vendor = name
//								dataSet.vendor = name
//							}
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Supplier")
								.textLabelModified()
						}

//						HStack{
//							Text("Shop")
//								.textLabelModified()
//							ModelPicker(
//								selection: $selectedVendor,
//								title: "Vendor",
//								includeEmptyChoice: true,
//								emptyChoiceLabel: "—",
//								autoSelectFirst: false,
//								filter: nil,
//								sort: [SortDescriptor(\.vendorName, order: .forward)],
//								labelProvider: { $0.vendorName }
//							)
//							.onChange(of: selectedVendor) { _, newVendor in
//								let name = newVendor?.vendorName ?? ""
//								vendor = name
//								dataSet.vendor = name
//							}
//							.frame(maxWidth: .infinity, alignment: .trailing)
//						}
					}
				}
				
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "ITEM NOTES", prompt: "Enter notes...", data: $Notes)
				}

				// Service intervals controlling due calculations (months/miles/hours).
				CardView {
					VStack {
						SectionText(label: "SERVICE COMPLETED AT")
						HStack{LabelDataTextview_Numberpad_Int(label: "Interval Months", data: $intervalMonths)}
							.onChange(of: intervalMonths) { _, _ in recomputeServiceStats() }
						HStack{LabelDataTextview_Numberpad_Int(label: "Interval Miles", data: $intervalMiles)}
							.onChange(of: intervalMiles) { _, _ in recomputeServiceStats() }
						HStack{LabelDataTextview_Numberpad_Float(label: "Interval Hours", data: $intervalHours)}
							.onChange(of: intervalHours) { _, _ in recomputeServiceStats() }
					}
				}

				// Part 1: Either select from database or enter manually, with quantity/cost/unit.
				CardView {
					VStack {
						SectionText(label: "PART 1")
						HStack{
							Text("Database Entry")
								.textLabelModified()
							PartPickerRow(
									title: "Part 1",
									vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId,
									selection: $selectedPart1,
									seedPartName: getPartNameFromDataSet(index: 1)
							) { newPart in
									setPart(index: 1, from: newPart)
							}
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Manual Entry", data: $part1)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part1Unit))", data: $part1Qty)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part1cost)}
						Picker_PartsUnit(label: "Unit", data: $part1Unit)
						HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part1Total), unit: "")}
					}
				}
				
				// Part 2: Either select from database or enter manually, with quantity/cost/unit.
				if part2 != "" || part1 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 2")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
										title: "Part 2",
										vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId,
										selection: $selectedPart2,
										seedPartName: getPartNameFromDataSet(index: 2)
								) { newPart in
										setPart(index: 2, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part2)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part2Unit))", data: $part2Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part2cost)}
							Picker_PartsUnit(label: "Unit", data: $part2Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part2Total), unit: "")}
						}
					}
				}
				
				// Part 3: Either select from database or enter manually, with quantity/cost/unit.
				if part3 != "" || part2 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 3")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
										title: "Part 3",
										vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId,
										selection: $selectedPart3,
										seedPartName: getPartNameFromDataSet(index: 3)
								) { newPart in
										setPart(index: 3, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part3)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part3Unit))", data: $part3Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part3cost)}
							Picker_PartsUnit(label: "Unit", data: $part3Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part3Total), unit: "")}
						}
					}
				}
				
				// Part 4: Either select from database or enter manually, with quantity/cost/unit.
				if part4 != "" || part3 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 4")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
										title: "Part 4",
										vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId,
										selection: $selectedPart4,
										seedPartName: getPartNameFromDataSet(index: 4)
								) { newPart in
										setPart(index: 4, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part4)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part4Unit))", data: $part4Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part4cost)}
							Picker_PartsUnit(label: "Unit", data: $part4Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part4Total), unit: "")}
						}
					}
				}
				
				// Part 5: Either select from database or enter manually, with quantity/cost/unit.
				if part5 != "" || part4 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 5")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
										title: "Part 5",
										vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId,
										selection: $selectedPart5,
										seedPartName: getPartNameFromDataSet(index: 5)
								) { newPart in
										setPart(index: 5, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part5)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part5Unit))", data: $part5Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part5cost)}
							Picker_PartsUnit(label: "Unit", data: $part5Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part5Total), unit: "")}
						}
					}
				}
				
				// Labor cost and derived totals.
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $laborCost)}
					}
				}

				// Simple usage stats derived from part lines (lines, quantities, averages).
				CardView {
					VStack {
						SectionText(label: "STATISTICS")
						HStack{LabelDataNumber(label: "Parts Lines Used", data: Float(partsLinesCount), fractionalLength: 0)}
						HStack{LabelDataNumber(label: "Total Parts Quantity", data: Float(totalPartsQuantity), fractionalLength: 0)}
						HStack{LabelDataCurrency(label: "Avg Cost/Part Unit", data: Float(avgCostPerPartUnit), unit: "")}
					}
				}

				// Vehicle context, last service lookup, and next-due estimates.
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM & VEHICLE STATS")
						HStack{LabelDataText(label: "Vehicle", data: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId)}
						if vehicleCurrentMiles > 0 {
							HStack{LabelDataText(label: "Current Odometer", data: "\(vehicleCurrentMiles) \(unit(UnitIndex.distance))")}
						}
						if vehicleCurrentEngHours > 0 {
							HStack{LabelDataNumber(label: "Current Engine Hours", data: vehicleCurrentEngHours, fractionalLength: 1)}
						}
						Divider()
						// Last service
						if let lastDate = lastServiceDate {
							HStack{LabelDataText(label: "Last Service", data: functions.formatDate_DDMMMyy(date: lastDate))}
						} else {
							HStack{LabelDataText(label: "Last Service", data: "No record found")}
						}
						if lastServiceMiles > 0 {
							HStack{LabelDataText(label: "Miles at Last Service", data: "\(lastServiceMiles) \(unit(UnitIndex.distance))")}
						}
						if lastServiceEngHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours at Last", data: lastServiceEngHours, fractionalLength: 1)}
						}
						if lastServiceMiles > 0 && vehicleCurrentMiles >= lastServiceMiles {
							HStack{LabelDataText(label: "Miles Since Service", data: "\(milesSinceService) \(unit(UnitIndex.distance))")}
						}
						if lastServiceEngHours > 0 && vehicleCurrentEngHours >= lastServiceEngHours {
							HStack{LabelDataNumber(label: "Hours Since Service", data: hoursSinceService, fractionalLength: 1)}
						}
						
						Divider()
						
						// Intervals and next due
						if intervalMiles > 0 || intervalMonths > 0 || intervalHours > 0 {
							HStack{LabelDataText(label: "Service Item", data: mxName.isEmpty ? dataSet.mxName : mxName)}
							if intervalMiles > 0 {
								HStack{LabelDataText(label: "Interval (Miles)", data: "\(intervalMiles) \(unit(UnitIndex.distance))")}
								HStack{LabelDataText(label: "Remaining Miles", data: "\(max(0, milesRemainingToDue)) \(unit(UnitIndex.distance))")}
							}
							if intervalHours > 0 {
								HStack{LabelDataNumber(label: "Interval (Hours)", data: intervalHours, fractionalLength: 1)}
								HStack{LabelDataNumber(label: "Remaining Hours", data: max(0, hoursRemainingToDue), fractionalLength: 1)}
							}
							if intervalMonths > 0 {
								HStack{LabelDataText(label: "Interval (Months)", data: "\(intervalMonths)")}
								HStack{LabelDataText(label: "Remaining (Days)", data: "\(max(0, daysRemainingToDue))")}
								if let due = nextDueDate {
									HStack{LabelDataText(label: "Est. Next Due", data: functions.formatDate_DDMMMyy(date: due))}
								}
							}
						} else {
							HStack{LabelDataText(label: "Service Item", data: mxName.isEmpty ? dataSet.mxName : mxName)}
							HStack{LabelDataText(label: "Intervals", data: "None specified")}
						}
					}
				}
				
				// Optional reference images for the service item.
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "SERVICE ITEM GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  SERVICE ITEM GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
				
				// Record activation state (inactive records are hidden in most lists).
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Items Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

			}//end of list
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "service item")
			}

			.onAppear {
				loadUnits()
				
				// Seed vehicle picker from existing vehicleId
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}
				
				// Seed system picker from existing vehicleSystem
				if selectedSystem == nil, !vehicleSystem.isEmpty {
						let sysName = vehicleSystem
						let vName = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
						var fd = FetchDescriptor<VehicleSystems1>(predicate: #Predicate { $0.systemName == sysName && $0.vehicleId == vName })
						fd.fetchLimit = 1
						if let s = try? modelContext.fetch(fd).first { selectedSystem = s }
				}
				
				// Seed vendor picker
				if selectedVendor == nil, !vendor.isEmpty {
						let name = vendor
						var fd = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
						fd.fetchLimit = 1
						if let v = try? modelContext.fetch(fd).first { selectedVendor = v }
				}
				
				// Seed parts pickers
				if selectedPart1 == nil, !part1.isEmpty {
						var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part1 })
						fd.fetchLimit = 1
						if let p = try? modelContext.fetch(fd).first { selectedPart1 = p }
				}
				if selectedPart2 == nil, !part2.isEmpty {
						var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part2 })
						fd.fetchLimit = 1
						if let p = try? modelContext.fetch(fd).first { selectedPart2 = p }
				}
				if selectedPart3 == nil, !part3.isEmpty {
						var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part3 })
						fd.fetchLimit = 1
						if let p = try? modelContext.fetch(fd).first { selectedPart3 = p }
				}
				if selectedPart4 == nil, !part4.isEmpty {
						var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part4 })
						fd.fetchLimit = 1
						if let p = try? modelContext.fetch(fd).first { selectedPart4 = p }
				}
				if selectedPart5 == nil, !part5.isEmpty {
						var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part5 })
						fd.fetchLimit = 1
						if let p = try? modelContext.fetch(fd).first { selectedPart5 = p }
				}
				
				refreshVehicleDetails()
				loadLastServiceForItem()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						isEditing.toggle()
						updateItem()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}
			
		} else {
			
			// VIEW MODE: Read-only presentation of the current `dataSet` values and computed stats.
			ScrollView {
				VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
				
				// General vehicle/system selection and status.
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle:", data: dataSet.vehicleId)}
						HStack{LabelDataText(label: "Systems:", data: "\(dataSet.vehicleSystem)")}
						HStack{LabelDataText(label: "Status:", data: dataSet.inactive ? "Inactive" : "Active")}
					}
				}
				
				// Core item metadata: name, description, notes, vendor.
				CardView {
					VStack{
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataText(label: "Service Item:", data: "\(dataSet.mxName)")}
						if dataSet.mxDescription != "" {
							HStack{LabelDataText(label: "Description:", data: "\(dataSet.mxDescription)")}
						}
						if dataSet.vendor != "" {
							HStack{LabelDataText(label: "Shop:", data: "\(dataSet.vendor)")}
						}
					}
				}
			
				if dataSet.Notes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "ITEM NOTES", data: dataSet.Notes)}
				}

				// Service intervals controlling due calculations (months/miles/hours).
				CardView {
					VStack{
						SectionText(label: "SERVICE INTERVALS")
						if dataSet.intervalMiles > 0 {
							HStack{LabelDataMeasurement(label: "Miles:", unit: .miles, data: Double(dataSet.intervalMiles))}
						}
						if dataSet.intervalHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: Float(dataSet.intervalHours), fractionalLength: 1)}
						}
						if dataSet.intervalMonths > 0 {
							HStack{LabelDataText(label: "Months:", data: "\(dataSet.intervalMonths)")}
						}
					}
				}
				
				// Part 1..5 parts used details
				CardView {
					VStack{
						SectionText(label: "PARTS USED")
						if dataSet.part1 != "" {
							HStack{LabelDataText(label: "", data: "")}
							HStack{LabelDataText(label: "Part:", data: "\(dataSet.part1)")}
							HStack{LabelDataText(label: "Quantity:", data: "\(dataSet.part1Qty) \(dataSet.part1Unit)")}
							HStack{LabelDataText(label: "Cost/Unit:", data: "\(functions.formatCurrency(dollars: dataSet.part1cost)) / \(dataSet.part1Unit)")}
							HStack{LabelDataText(label: "Part Total:", data: "\(functions.formatCurrency(dollars: Float(part1Total)))")}
						}
						if dataSet.part2 != "" {
							HStack{LabelDataText(label: "", data: "")}
							HStack{LabelDataText(label: "Part:", data: "\(dataSet.part2)")}
							HStack{LabelDataText(label: "Quantity:", data: "\(dataSet.part2Qty) \(dataSet.part2Unit)")}
							HStack{LabelDataText(label: "Cost/Unit:", data: "\(functions.formatCurrency(dollars: dataSet.part2cost)) / \(dataSet.part2Unit)")}
							HStack{LabelDataText(label: "Part Total:", data: "\(functions.formatCurrency(dollars: Float(part2Total)))")}
						}
						if dataSet.part3 != "" {
							HStack{LabelDataText(label: "", data: "")}
							HStack{LabelDataText(label: "Part:", data: "\(dataSet.part3)")}
							HStack{LabelDataText(label: "Quantity:", data: "\(dataSet.part3Qty) \(dataSet.part3Unit)")}
							HStack{LabelDataText(label: "Cost/Unit:", data: "\(functions.formatCurrency(dollars: dataSet.part3cost)) / \(dataSet.part3Unit)")}
							HStack{LabelDataText(label: "Part Total:", data: "\(functions.formatCurrency(dollars: Float(part3Total)))")}
						}
						if dataSet.part4 != "" {
							HStack{LabelDataText(label: "", data: "")}
							HStack{LabelDataText(label: "Part:", data: "\(dataSet.part4)")}
							HStack{LabelDataText(label: "Quantity:", data: "\(dataSet.part4Qty) \(dataSet.part4Unit)")}
							HStack{LabelDataText(label: "Cost/Unit:", data: "\(functions.formatCurrency(dollars: dataSet.part4cost)) / \(dataSet.part4Unit)")}
							HStack{LabelDataText(label: "Part Total:", data: "\(functions.formatCurrency(dollars: Float(part4Total)))")}
						}
						if dataSet.part5 != "" {
							HStack{LabelDataText(label: "", data: "")}
							HStack{LabelDataText(label: "Part:", data: "\(dataSet.part5)")}
							HStack{LabelDataText(label: "Quantity:", data: "\(dataSet.part5Qty) \(dataSet.part5Unit)")}
							HStack{LabelDataText(label: "Cost/Unit:", data: "\(functions.formatCurrency(dollars: dataSet.part5cost)) / \(dataSet.part5Unit)")}
							HStack{LabelDataText(label: "Part Total:", data: "\(functions.formatCurrency(dollars: Float(part5Total)))")}
						}
					}
				}
				
				// Labor cost and derived totals.
				CardView {
					VStack{
						SectionText(label: "COSTS")
						HStack{
							HStack{LabelDataText(label: "Labor Cost:", data: "\(functions.formatCurrency(dollars: laborCost))")}
						}
						HStack{LabelDataText(label: "Parts Cost:", data: "\(functions.formatCurrency(dollars: Float(partsTotal)))")}
						Divider()
						HStack{LabelDataText(label: "Total Cost:", data: "\(functions.formatCurrency(dollars: Float(grandTotal)))")}
							.foregroundColor(.red)
					}
				}

				// Simple usage stats derived from part lines (lines, quantities, averages).
				CardView {
					VStack {
						SectionText(label: "STATISTICS")
						HStack{LabelDataNumber(label: "Parts Lines Used", data: Float(partsLinesCount), fractionalLength: 0)}
						HStack{LabelDataNumber(label: "Total Parts Quantity", data: Float(totalPartsQuantity), fractionalLength: 0)}
						HStack{LabelDataCurrency(label: "Avg Cost/Part Unit", data: Float(avgCostPerPartUnit), unit: "")}
					}
				}

				// Vehicle context, last service lookup, and next-due estimates.
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM & VEHICLE STATS")
						HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
						if vehicleCurrentMiles > 0 {
							HStack{LabelDataText(label: "Current Odometer", data: "\(vehicleCurrentMiles) \(unit(UnitIndex.distance))")}
						}
						if vehicleCurrentEngHours > 0 {
							HStack{LabelDataNumber(label: "Current Engine Hours", data: vehicleCurrentEngHours, fractionalLength: 1)}
						}
						Divider()
						// Last service
						if let lastDate = lastServiceDate {
							HStack{LabelDataText(label: "Last Service", data: functions.formatDate_DDMMMyy(date: lastDate))}
						} else {
							HStack{LabelDataText(label: "Last Service", data: "No record found")}
						}
						if lastServiceMiles > 0 {
							HStack{LabelDataText(label: "Miles at Last Service", data: "\(lastServiceMiles) \(unit(UnitIndex.distance))")}
						}
						if lastServiceEngHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours at Last", data: lastServiceEngHours, fractionalLength: 1)}
						}
						if lastServiceMiles > 0 && vehicleCurrentMiles >= lastServiceMiles {
							HStack{LabelDataText(label: "Miles Since Service", data: "\(milesSinceService) \(unit(UnitIndex.distance))")}
						}
						if lastServiceEngHours > 0 && vehicleCurrentEngHours >= lastServiceEngHours {
							HStack{LabelDataNumber(label: "Hours Since Service", data: hoursSinceService, fractionalLength: 1)}
						}
						Divider()
						if dataSet.intervalMiles > 0 || dataSet.intervalMonths > 0 || dataSet.intervalHours > 0 {
							HStack{LabelDataText(label: "Service Item", data: dataSet.mxName)}
							if dataSet.intervalMiles > 0 {
								HStack{LabelDataText(label: "Interval (Miles)", data: "\(dataSet.intervalMiles) \(unit(UnitIndex.distance))")}
								HStack{LabelDataText(label: "Remaining Miles", data: "\(max(0, milesRemainingToDue)) \(unit(UnitIndex.distance))")}
							}
							if dataSet.intervalHours > 0 {
								HStack{LabelDataNumber(label: "Interval (Hours)", data: dataSet.intervalHours, fractionalLength: 1)}
								HStack{LabelDataNumber(label: "Remaining Hours", data: max(0, hoursRemainingToDue), fractionalLength: 1)}
							}
							if dataSet.intervalMonths > 0 {
								HStack{LabelDataText(label: "Interval (Months)", data: "\(dataSet.intervalMonths)")}
								HStack{LabelDataText(label: "Remaining (Days)", data: "\(max(0, daysRemainingToDue))")}
								if let due = nextDueDate {
									HStack{LabelDataText(label: "Est. Next Due", data: functions.formatDate_DDMMMyy(date: due))}
								}
							}
						} else {
							HStack{LabelDataText(label: "Service Item", data: dataSet.mxName)}
							HStack{LabelDataText(label: "Intervals", data: "None specified")}
						}
					}
				}
				
				// Reference images displayed in read-only mode.
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}

			}
			.listStyle(.automatic)
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "service item")
			}

			.onAppear {
				loadUnits()
				// Seed vehicle picker from existing vehicleId
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}
                // Seed system picker from existing vehicleSystem
                if selectedSystem == nil, !vehicleSystem.isEmpty {
                    let sysName = vehicleSystem
                    let vName = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
                    var fd = FetchDescriptor<VehicleSystems1>(predicate: #Predicate { $0.systemName == sysName && $0.vehicleId == vName })
                    fd.fetchLimit = 1
                    if let s = try? modelContext.fetch(fd).first { selectedSystem = s }
                }
                // Seed vendor picker
                if selectedVendor == nil, !vendor.isEmpty {
                    let name = vendor
                    var fd = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
                    fd.fetchLimit = 1
                    if let v = try? modelContext.fetch(fd).first { selectedVendor = v }
                }
                // Seed parts pickers
                if selectedPart1 == nil, !part1.isEmpty {
                    var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part1 })
                    fd.fetchLimit = 1
                    if let p = try? modelContext.fetch(fd).first { selectedPart1 = p }
                }
                if selectedPart2 == nil, !part2.isEmpty {
                    var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part2 })
                    fd.fetchLimit = 1
                    if let p = try? modelContext.fetch(fd).first { selectedPart2 = p }
                }
                if selectedPart3 == nil, !part3.isEmpty {
                    var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part3 })
                    fd.fetchLimit = 1
                    if let p = try? modelContext.fetch(fd).first { selectedPart3 = p }
                }
                if selectedPart4 == nil, !part4.isEmpty {
                    var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part4 })
                    fd.fetchLimit = 1
                    if let p = try? modelContext.fetch(fd).first { selectedPart4 = p }
                }
                if selectedPart5 == nil, !part5.isEmpty {
                    var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part5 })
                    fd.fetchLimit = 1
                    if let p = try? modelContext.fetch(fd).first { selectedPart5 = p }
                }
				refreshVehicleDetails()
				loadLastServiceForItem()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Delete", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
						Button("Make Inactive") {
							makeInactive()
						}
					} message: {
						Text("Confirm either deletion or deactivation of this service record.  Deactivated records will still be available for reference, but will not be included in any reports or calculations.")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}
	
	/// Copies edited fields back into `dataSet` and persists changes with SwiftData.
	/// Updates `updatedAt` timestamp and leaves `createdAt` unchanged.
	@MainActor
	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.vehicleSystem = vehicleSystem
		dataSet.inactive = inactive
		dataSet.mxName = mxName
		dataSet.mxDescription = mxDescription
		dataSet.Notes = Notes
		dataSet.vendor = vendor
		dataSet.laborCost = laborCost
		dataSet.intervalMonths = intervalMonths
		dataSet.intervalMiles = intervalMiles
		dataSet.intervalHours = intervalHours
		dataSet.part1 = part1
		dataSet.part1Id = part1Id
		dataSet.part1Qty = part1Qty
		dataSet.part1cost = part1cost
		dataSet.part1Unit = part1Unit
		dataSet.part2 = part2
		dataSet.part2Id = part2Id
		dataSet.part2Qty = part2Qty
		dataSet.part2cost = part2cost
		dataSet.part2Unit = part2Unit
		dataSet.part3 = part3
		dataSet.part3Id = part3Id
		dataSet.part3Qty = part3Qty
		dataSet.part3cost = part3cost
		dataSet.part3Unit = part3Unit
		dataSet.part4 = part4
		dataSet.part4Id = part4Id
		dataSet.part4Qty = part4Qty
		dataSet.part4cost = part4cost
		dataSet.part4Unit = part4Unit
		dataSet.part5 = part5
		dataSet.part5Id = part5Id
		dataSet.part5Qty = part5Qty
		dataSet.part5cost = part5cost
		dataSet.part5Unit = part5Unit
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// Permanently deletes this item from the model context and dismisses the view.
	@MainActor
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
	
	/// Marks the record as inactive (soft delete) and saves it, then dismisses.
	private func makeInactive() {
		dataSet.inactive = true
		inactive = true
		dataSet.updatedAt = Date()
		do {
			try modelContext.save()
		} catch {
			print("Failed to mark inactive: \(error.localizedDescription)")
		}
		dismiss()
	}

	/// Looks up a part by name and returns its unit, unit cost, and default quantity.
	/// - Note: Returns zero/empty values when the part is not found.
	func getPartsDetails(partName: String) -> (partUnit: String, partCost: Double, partQty: Double) {
		var partUnit: String = ""
		var partCost: Double = 0
		var partQty: Double = 0
		print("partName: \(partName)")

		let fetchDescriptor = FetchDescriptor<MxParts1>(predicate: #Predicate { fetchModel in
			fetchModel.partName == partName
		})
		do {
			let FetchModels = try modelContext.fetch(fetchDescriptor)
			if FetchModels.isEmpty{
				partCost = 0
				partUnit = ""
				partQty = 0
			} else {
				for fetchModel in FetchModels {
					partUnit = fetchModel.partUnit
					partCost = Double(fetchModel.costPerUnit)
					partQty = Double(fetchModel.partQuantity)
				}
			}
			print("partUnit: \(partUnit)")
		} catch {
			print("Failed to load parts.")
		}
		return (partUnit, partCost, partQty)
	}

    /// Synchronizes the selected `MxParts1` into the corresponding part line fields.
    /// - Parameter index: Line number (1...5) indicating which part slot to update.
    private func setPart(index: Int, from part: MxParts1?) {
        let name = part?.partName ?? ""
        let cost = part?.costPerUnit ?? 0
        let unit = part?.partUnit ?? ""
        let qtyI = part?.partQuantity ?? 0
        let qtyF = Float(qtyI)
        switch index {
        case 1:
            part1 = name; part1Id = name; part1Unit = unit; part1cost = cost; part1Qty = qtyF
            dataSet.part1 = part1; dataSet.part1Id = part1Id; dataSet.part1Unit = part1Unit; dataSet.part1cost = part1cost; dataSet.part1Qty = part1Qty
        case 2:
            part2 = name; part2Id = name; part2Unit = unit; part2cost = cost; part2Qty = qtyF
            dataSet.part2 = part2; dataSet.part2Id = part2Id; dataSet.part2Unit = part2Unit; dataSet.part2cost = part2cost; dataSet.part2Qty = part2Qty
        case 3:
            part3 = name; part3Id = name; part3Unit = unit; part3cost = cost; part3Qty = qtyF
            dataSet.part3 = part3; dataSet.part3Id = part3Id; dataSet.part3Unit = part3Unit; dataSet.part3cost = part3cost; dataSet.part3Qty = part3Qty
        case 4:
            part4 = name; part4Id = name; part4Unit = unit; part4cost = cost; part4Qty = qtyF
            dataSet.part4 = part4; dataSet.part4Id = part4Id; dataSet.part4Unit = part4Unit; dataSet.part4cost = part4cost; dataSet.part4Qty = part4Qty
        case 5:
            part5 = name; part5Id = name; part5Unit = unit; part5cost = cost; part5Qty = qtyF
            dataSet.part5 = part5; dataSet.part5Id = part5Id; dataSet.part5Unit = part5Unit; dataSet.part5cost = part5cost; dataSet.part5Qty = part5Qty
        default:
            break
        }
    }

    /// Helper to read the current part name from `dataSet` for a given line (1...5).
    private func getPartNameFromDataSet(index: Int) -> String {
        switch index {
        case 1: return dataSet.part1
        case 2: return dataSet.part2
        case 3: return dataSet.part3
        case 4: return dataSet.part4
        case 5: return dataSet.part5
        default: return ""
        }
    }

	/// Loads unit preferences from settings to format labels and measurements.
	private func loadUnits() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}
	
	/// Fetches current vehicle readings (miles/hours) and triggers a stats recompute.
	private func refreshVehicleDetails() {
		let id = (vehicleId.isEmpty ? dataSet.vehicleId : vehicleId)
		if let details = functions.loadVehicleDetails(context: modelContext, vehicleId: id) {
			vehicleCurrentMiles = details.mileage
			vehicleCurrentEngHours = details.engHours
		} else {
			vehicleCurrentMiles = 0
			vehicleCurrentEngHours = 0
		}
		recomputeServiceStats()
	}
	
	/// Retrieves the most recent service record for the selected vehicle + item name.
	/// Updates last-service metrics and recomputes remaining-to-due values.
	private func loadLastServiceForItem() {
		let vId = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
		let itemName = mxName.isEmpty ? dataSet.mxName : mxName
		guard !vId.isEmpty, !itemName.isEmpty else {
			lastServiceDate = nil
			lastServiceMiles = 0
			lastServiceEngHours = 0
			recomputeServiceStats()
			return
		}
		do {
			var fd = FetchDescriptor<ServiceRecords1>(
				predicate: #Predicate { $0.vehicleId == vId && $0.mxName == itemName },
				sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
			)
			fd.fetchLimit = 1
			if let rec = try modelContext.fetch(fd).first {
				lastServiceDate = rec.mxDate
				lastServiceMiles = rec.Miles
				lastServiceEngHours = rec.engHours
			} else {
				lastServiceDate = nil
				lastServiceMiles = 0
				lastServiceEngHours = 0
			}
		} catch {
			lastServiceDate = nil
			lastServiceMiles = 0
			lastServiceEngHours = 0
		}
		recomputeServiceStats()
	}
	
	/// Recalculates since-service, remaining-to-due (miles/hours), and next due date.
	/// Uses current vehicle readings, last-service values, and configured intervals.
	private func recomputeServiceStats() {
		// Since-service
		if lastServiceMiles > 0 && vehicleCurrentMiles >= lastServiceMiles {
			milesSinceService = max(0, vehicleCurrentMiles - lastServiceMiles)
		} else {
			milesSinceService = 0
		}
		if lastServiceEngHours > 0 && vehicleCurrentEngHours >= lastServiceEngHours {
			hoursSinceService = max(0, vehicleCurrentEngHours - lastServiceEngHours)
		} else {
			hoursSinceService = 0
		}
		// Remaining to due
		if intervalMiles > 0 {
			milesRemainingToDue = max(0, intervalMiles - milesSinceService)
		} else {
			milesRemainingToDue = 0
		}
		if intervalHours > 0 {
			hoursRemainingToDue = max(0, intervalHours - hoursSinceService)
		} else {
			hoursRemainingToDue = 0
		}
		// Next due date from last service date + months
		if intervalMonths > 0, let last = lastServiceDate {
			if let due = Calendar(identifier: .gregorian).date(byAdding: .month, value: intervalMonths, to: last) {
				nextDueDate = due
				let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: due).day ?? 0
				daysRemainingToDue = days
			} else {
				nextDueDate = nil
				daysRemainingToDue = 0
			}
		} else {
			nextDueDate = nil
			daysRemainingToDue = 0
		}
	}
}

// Preview with a fully populated item and seeded related models for realism.
#Preview("EditItems – Populated Sample") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
			 MxItems3.self,
			 MxParts1.self,
			 Vendors1.self,
			 Settings1.self,
			 configurations: config
	)

	// Seed a vehicle
	let vehicle = Vehicle8(name: "Preview Vehicle", year: 2022, mileage: 42000, engHours: 123.4, fuelType: "Gasoline", fuelCapacity: 26)
	container.mainContext.insert(vehicle)

	// Seed settings for units
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
	container.mainContext.insert(settings)

	// Seed a populated service item template
	let item = MxItems3(
		createdAt: Date().addingTimeInterval(-86400 * 10),
		updatedAt: Date().addingTimeInterval(-86400 * 1),
		vehicleId: vehicle.name,
		vehicleSystem: "Engine",
		mxName: "Oil and Filter Change",
		mxDescription: "Change oil and filter",
		Notes: "Use full synthetic",
		vendor: "Local Auto Shop",
		laborCost: 95.0,
		intervalMonths: 6,
		intervalMiles: 5000,
		intervalHours: 200.0,
		part1: "Engine Oil",
		part1Id: "",
		part1Qty: 6,
		part1cost: 8.99,
		part1Unit: "qt",
		part2: "Oil Filter",
		part2Id: "",
		part2Qty: 1,
		part2cost: 12.49,
		part2Unit: "Each",
		part3: "",
		part3Id: "",
		part3Qty: 0,
		part3cost: 0,
		part3Unit: "",
		part4: "",
		part4Id: "",
		part4Qty: 0,
		part4cost: 0,
		part4Unit: "",
		part5: "",
		part5Id: "",
		part5Qty: 0,
		part5cost: 0,
		part5Unit: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	container.mainContext.insert(item)

	return NavigationStack {
		EditItems(mxItems: item)
	}
	.modelContainer(container)
}

// Preview with a minimal/blank item to validate empty-state UI.
#Preview("EditItems – Empty Sample") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
			 MxItems3.self,
			 MxParts1.self,
			 Vendors1.self,
			 Settings1.self,
			 configurations: config
	)

	// Minimal vehicle
	let vehicle = Vehicle8(name: "Blank Vehicle", year: 2024)
	container.mainContext.insert(vehicle)

	// Seed settings so units resolve
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
	container.mainContext.insert(settings)

	// Blank item
	let item = MxItems3(
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		vehicleSystem: "",
		mxName: "New Service Item…",
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
		part1Unit: "",
		part2: "",
		part2Id: "",
		part2Qty: 0,
		part2cost: 0,
		part2Unit: "",
		part3: "",
		part3Id: "",
		part3Qty: 0,
		part3cost: 0,
		part3Unit: "",
		part4: "",
		part4Id: "",
		part4Qty: 0,
		part4cost: 0,
		part4Unit: "",
		part5: "",
		part5Id: "",
		part5Qty: 0,
		part5cost: 0,
		part5Unit: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	container.mainContext.insert(item)

	return NavigationStack {
		EditItems(mxItems: item)
	}
	.modelContainer(container)
}


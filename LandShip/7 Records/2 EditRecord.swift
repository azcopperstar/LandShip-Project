//
//  EditMxRecord.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//
//  Overview
//  --------
//  EditRecord is a SwiftUI view that shows and edits a single ServiceRecords1 model using SwiftData.
//  The view has two primary modes:
//    - Details mode (read-only, nicely formatted)
//    - Edit mode (interactive controls with pickers and text fields)
//  A toolbar toggle switches between the modes, and a Save action persists changes back to SwiftData.
//
//  Highlights
//  ----------
//  - Uses SwiftData (ModelContext) for loading, updating, and deleting ServiceRecords1 as well as related models:
//      Vehicle8, MxItems3 (service templates), MxParts1 (parts), Vendors1, Settings1.
//  - Uses a generic ModelPicker<T> (custom view elsewhere in the project) to select service items, vendors, and parts.
//  - Carefully avoids capturing model instances directly inside #Predicate closures by copying the needed values first.
//  - Computes a variety of costs and statistics in recomputeTotals(), including totals, averages, and due intervals.
//  - Keeps several "derived selections" in sync: when a service item template is chosen, fields and pickers update accordingly.
//  - Updates a vehicle's odometer/engine hours if the service record's values exceed current values.
//
//  Structure
//  ---------
//  1) State and Environment
//  2) Initializer: seeds @State from the incoming ServiceRecords1 instance
//  3) Body: two modes (Edit vs Details) laid out in CardView sections
//  4) Actions: delete, update/save
//  5) Helpers: loading units, vehicle details, intervals, syncing selections, recomputeTotals
//  6) Previews: in-memory containers to demo both a populated and an empty record
//

import SwiftUI
import SwiftData

struct EditRecord: View {
	// The record being edited or displayed.
	// Kept in @State to drive the UI; changes are written back on Save.
	@State private var dataSet: ServiceRecords1

	// SwiftData environment context for fetching/saving/deleting.
	@Environment(\.modelContext) var modelContext
	@Environment(\.entitlements) private var entitlements

	// Dismiss handler for closing the view (e.g., after delete).
	@Environment(\.dismiss) private var dismiss

	// App-wide helper functions (formatting, fetch helpers, etc.).
	let functions: Functions = Functions()

	// Preferences accessor for units; loaded once on appear.
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		// Safe unit accessor
		units.indices.contains(index) ? units[index] : ""
	}

	// UI state flags
	@State private var isPresentingConfirm: Bool = false  // Controls delete confirmation dialog
	@State private var isEditing: Bool = false            // Toggles between Edit and Details modes

	// Controls presentation of the "save as service item" prompt, shown when saving a record
	// whose service item was typed manually rather than picked from the Database Item list.
	@State private var showingSaveAsItemPrompt: Bool = false
	
	// Core fields mirrored from ServiceRecords1.
	// These are edited in Edit mode and written back to dataSet on Save.
	@State private var inactive: Bool = false
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var mxDate: Date = Date()
	@State private var vehicleId = ""
	@State private var Miles: Int = 0
	@State private var engHours: Float = 0
	@State private var mxName: String = ""
	@State private var mxItemId: String = ""
	@State private var mxDescription: String = ""
	@State private var Notes: String = ""
	@State private var vendor: String = ""
	@State private var laborCost: Float = 0
	@State private var part1: String = ""
	@State private var part1cost: Float = 0
	@State private var part1Unit: String = "Each"
	@State private var part1Quantity: Int = 0
	@State private var part2: String = ""
	@State private var part2cost: Float = 0
	@State private var part2Unit: String = "Each"
	@State private var part2Quantity: Int = 0
	@State private var part3: String = ""
	@State private var part3cost: Float = 0
	@State private var part3Unit: String = "Each"
	@State private var part3Quantity: Int = 0
	@State private var part4: String = ""
	@State private var part4cost: Float = 0
	@State private var part4Unit: String = "Each"
	@State private var part4Quantity: Int = 0
	@State private var part5: String = ""
	@State private var part5cost: Float = 0
	@State private var part5Unit: String = "Each"
	@State private var part5Quantity: Int = 0

	// User-defined numeric field to complement Miles/engHours (e.g. "Water Gallons" in "gal")
	@State private var customMeasureLabel: String = ""
	@State private var customMeasureUnit: String = ""
	@State private var customMeasureValue: Float = 0
	@State private var availableCustomMeasureLabels: [String] = []
	@State private var customMeasureLabelSelection: String = "__none__"

	// Optional images and captions for the record
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// Running costs (computed)
	@State private var trackPartsCost1: Double = 0.0
	@State private var trackPartsCost2: Double = 0.0
	@State private var trackPartsCost3: Double = 0.0
	@State private var trackPartsCost4: Double = 0.0
	@State private var trackPartsCost5: Double = 0.0
	@State private var trackPartsCostTotal: Double = 0.0
	@State private var trackAllCostTotal: Double = 0.0

	// Statistics derived from parts and totals
	@State private var partsLinesCount: Int = 0
	@State private var totalPartsQuantity: Int = 0
	@State private var avgCostPerPartUnit: Double = 0.0
	@State private var costPerMile: Double = 0.0
	@State private var costPerEngineHour: Double = 0.0

	// Vehicle current stats and deltas since the service
	@State private var vehicleCurrentMiles: Int = 0
	@State private var vehicleCurrentEngHours: Float = 0.0
	@State private var milesSinceService: Int = 0
	@State private var hoursSinceService: Float = 0.0
	
	// Service item intervals (from MxItems3 template) and remaining values
	@State private var itemIntervalMiles: Int = 0
	@State private var itemIntervalMonths: Int = 0
	@State private var itemIntervalHours: Float = 0.0
	@State private var milesRemainingToDue: Int = 0
	@State private var hoursRemainingToDue: Float = 0.0
	@State private var daysRemainingToDue: Int = 0
	@State private var nextDueDate: Date? = nil

	// Selections for generic pickers (ModelPicker<T>)
	@State private var selectedServiceItem: MxItems3? = nil
	@State private var selectedVendor: Vendors1? = nil
	@State private var selectedPart1: MxParts1? = nil
	@State private var selectedPart2: MxParts1? = nil
	@State private var selectedPart3: MxParts1? = nil
	@State private var selectedPart4: MxParts1? = nil
	@State private var selectedPart5: MxParts1? = nil
	@State private var selectedVehicle: Vehicle8? = nil

	// Embedded sub service items (up to 5), each optionally picked from MxItems3.
	// Description/labor cost are one-time snapshots taken when picked; editing the source
	// item later does not reach back into this record.
	@State private var subItem1: String = ""
	@State private var subItem1Id: String = ""
	@State private var subItem1Description: String = ""
	@State private var subItem1LaborCost: Float = 0
	@State private var subItem1Comments: String = ""
	@State private var subItem2: String = ""
	@State private var subItem2Id: String = ""
	@State private var subItem2Description: String = ""
	@State private var subItem2LaborCost: Float = 0
	@State private var subItem2Comments: String = ""
	@State private var subItem3: String = ""
	@State private var subItem3Id: String = ""
	@State private var subItem3Description: String = ""
	@State private var subItem3LaborCost: Float = 0
	@State private var subItem3Comments: String = ""
	@State private var subItem4: String = ""
	@State private var subItem4Id: String = ""
	@State private var subItem4Description: String = ""
	@State private var subItem4LaborCost: Float = 0
	@State private var subItem4Comments: String = ""
	@State private var subItem5: String = ""
	@State private var subItem5Id: String = ""
	@State private var subItem5Description: String = ""
	@State private var subItem5LaborCost: Float = 0
	@State private var subItem5Comments: String = ""
	@State private var trackSubItemsLaborTotal: Double = 0.0
	@State private var selectedSubItem1: MxItems3? = nil
	@State private var selectedSubItem2: MxItems3? = nil
	@State private var selectedSubItem3: MxItems3? = nil
	@State private var selectedSubItem4: MxItems3? = nil
	@State private var selectedSubItem5: MxItems3? = nil

	// Additions transfer link
	@State private var additionsLinkId: String = ""
	@State private var showAdditionsTransferSheet: Bool = false
	@State private var transferCategory: String = ""
	@State private var transferSubCategory: String = ""
	@State private var allAdditionsCategories: [String] = []
	@State private var allAdditionsSubCategories: [String] = []
	@State private var linkedAdditionsCount: Int = 0

	// Initializer
	// Seeds all local @State fields from the incoming ServiceRecords1 record so the edit UI
	// can be fully controlled by local state. The Save action writes these back to dataSet.
	init(serviceRecords1: ServiceRecords1, startEditing: Bool = false) {
		self.dataSet = serviceRecords1
		vehicleId = dataSet.vehicleId

		self._inactive = State.init(initialValue: dataSet.inactive)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._mxDate = State.init(initialValue: dataSet.mxDate)
		self._vehicleId = State.init(initialValue: dataSet.vehicleId)
		self._Miles = State.init(initialValue: dataSet.Miles)
		self._engHours = State.init(initialValue: dataSet.engHours)
		self._mxName = State.init(initialValue: dataSet.mxName)
		self._mxItemId = State.init(initialValue: dataSet.mxItemId)
		self._mxDescription = State .init(initialValue: dataSet.mxDescription)
		self._Notes = State.init(initialValue: dataSet.Notes)
		self._vendor = State.init(initialValue: dataSet.vendor)
		self._laborCost = State.init(initialValue: dataSet.laborCost)
		self._part1 = State.init(initialValue: dataSet.part1)
		self._part1cost = State.init(initialValue: dataSet.part1cost)
		self._part1Unit = State.init(initialValue: dataSet.part1Unit)
		self._part1Quantity = State.init(initialValue: dataSet.part1Quantity)
		self._part2 = State.init(initialValue: dataSet.part2)
		self._part2cost = State.init(initialValue: dataSet.part2cost)
		self._part2Unit = State.init(initialValue: dataSet.part2Unit)
		self._part2Quantity = State.init(initialValue: dataSet.part2Quantity)
		self._part3 = State.init(initialValue: dataSet.part3)
		self._part3cost = State.init(initialValue: dataSet.part3cost)
		self._part3Unit = State.init(initialValue: dataSet.part3Unit)
		self._part3Quantity = State.init(initialValue: dataSet.part3Quantity)
		self._part4 = State.init(initialValue: dataSet.part4)
		self._part4cost = State.init(initialValue: dataSet.part4cost)
		self._part4Unit = State.init(initialValue: dataSet.part4Unit)
		self._part4Quantity = State.init(initialValue: dataSet.part4Quantity)
		self._part5 = State.init(initialValue: dataSet.part5)
		self._part5cost = State.init(initialValue: dataSet.part5cost)
		self._part5Unit = State.init(initialValue: dataSet.part5Unit)
		self._part5Quantity = State.init(initialValue: dataSet.part5Quantity)
		self._customMeasureLabel = State.init(initialValue: dataSet.customMeasureLabel)
		self._customMeasureUnit = State.init(initialValue: dataSet.customMeasureUnit)
		self._customMeasureValue = State.init(initialValue: dataSet.customMeasureValue)
		self._customMeasureLabelSelection = State(initialValue: dataSet.customMeasureLabel.isEmpty ? "__none__" : dataSet.customMeasureLabel)
		self._image1 = State.init(initialValue: dataSet.image1)
		self._image2 = State.init(initialValue: dataSet.image2)
		self._image3 = State.init(initialValue: dataSet.image3)
		self._image1Description = State.init(initialValue: dataSet.image1Description)
		self._image2Description = State.init(initialValue: dataSet.image2Description)
		self._image3Description = State.init(initialValue: dataSet.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
		self._additionsLinkId = State.init(initialValue: serviceRecords1.additionsLinkId)

		self._subItem1 = State.init(initialValue: dataSet.subItem1)
		self._subItem1Id = State.init(initialValue: dataSet.subItem1Id)
		self._subItem1Description = State.init(initialValue: dataSet.subItem1Description)
		self._subItem1LaborCost = State.init(initialValue: dataSet.subItem1LaborCost)
		self._subItem1Comments = State.init(initialValue: dataSet.subItem1Comments)
		self._subItem2 = State.init(initialValue: dataSet.subItem2)
		self._subItem2Id = State.init(initialValue: dataSet.subItem2Id)
		self._subItem2Description = State.init(initialValue: dataSet.subItem2Description)
		self._subItem2LaborCost = State.init(initialValue: dataSet.subItem2LaborCost)
		self._subItem2Comments = State.init(initialValue: dataSet.subItem2Comments)
		self._subItem3 = State.init(initialValue: dataSet.subItem3)
		self._subItem3Id = State.init(initialValue: dataSet.subItem3Id)
		self._subItem3Description = State.init(initialValue: dataSet.subItem3Description)
		self._subItem3LaborCost = State.init(initialValue: dataSet.subItem3LaborCost)
		self._subItem3Comments = State.init(initialValue: dataSet.subItem3Comments)
		self._subItem4 = State.init(initialValue: dataSet.subItem4)
		self._subItem4Id = State.init(initialValue: dataSet.subItem4Id)
		self._subItem4Description = State.init(initialValue: dataSet.subItem4Description)
		self._subItem4LaborCost = State.init(initialValue: dataSet.subItem4LaborCost)
		self._subItem4Comments = State.init(initialValue: dataSet.subItem4Comments)
		self._subItem5 = State.init(initialValue: dataSet.subItem5)
		self._subItem5Id = State.init(initialValue: dataSet.subItem5Id)
		self._subItem5Description = State.init(initialValue: dataSet.subItem5Description)
		self._subItem5Comments = State.init(initialValue: dataSet.subItem5Comments)
		self._subItem5LaborCost = State.init(initialValue: dataSet.subItem5LaborCost)
	}
	
	var body: some View {
		// The UI is split into Edit (interactive) and Details (read-only) modes.
		if isEditing {
			// EDIT MODE
			ScrollView {
				// GENERAL
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{
							Text(Vertical.current.assetSingular)
								.textLabelModified()

							ModelPicker(
								selection: $selectedVehicle,
								title: Vertical.current.assetSingular,
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil,
								sort: [SortDescriptor(\.displayName, order: .forward)],
								labelProvider: { v in "\(v.year) \(v.displayName)"},
								thumbnailData: { $0.image1 }
							)
							.fixedSize(horizontal: true, vertical: true)
							.frame(maxWidth: .infinity, alignment: .trailing)
							.onChange(of: selectedVehicle) { _, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								dataSet.vehicleId = name
								refreshVehicleDetails()
								recomputeTotals()
							}
						}
						// Service date
						HStack{LabelDataPicker_Date(label: "Service Date", data: $mxDate)}
						// Inactive toggle
					}
				}
				
				// SERVICE ITEM DETAILS
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
//						HStack{
//							Text("Database Item")
//								.textLabelModified()
//						}
							
						// Generic ModelPicker for MxItems3 filtered by the chosen vehicle, plus any
							// generic "All Vehicles" items. IMPORTANT: Avoid capturing dataSet directly
							// inside #Predicate.
							let currentVehicle = vehicleId
							let itemsFilter: Predicate<MxItems3>? = currentVehicle.isEmpty
							? nil
							: #Predicate<MxItems3> { $0.vehicleId == currentVehicle || $0.vehicleId == "All Vehicles" }
							LabeledContent {
								ModelPicker(
									selection: $selectedServiceItem,
									title: "Database Item",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: itemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.pickerLabel }
								)
								.onChange(of: selectedServiceItem) { _, newItem in
									guard let item = newItem else {
										dataSet.mxItemId = ""
										return
									}
									mxItemId = item.mxName
									dataSet.mxItemId = item.mxName
									mxName = item.mxName
									mxDescription = item.mxDescription
									Notes = item.Notes
									vendor = item.vendor
									dataSet.vendor = item.vendor
									// Sync Vendor picker selection to the item's vendor if resolvable
									if item.vendor.isEmpty {
										selectedVendor = nil
									} else {
										let vendorName = item.vendor
										var fdV = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == vendorName })
										fdV.fetchLimit = 1
										if let v = try? modelContext.fetch(fdV).first {
											selectedVendor = v
										} else {
											selectedVendor = nil
										}
									}
									laborCost = item.laborCost
									// Intervals
									itemIntervalMiles = item.intervalMiles
									itemIntervalMonths = item.intervalMonths
									itemIntervalHours = item.intervalHours
									// Parts
									part1 = item.part1
									part1cost = item.part1cost
									part1Unit = item.part1Unit
									part1Quantity = Int(item.part1Qty)
									part2 = item.part2
									part2cost = item.part2cost
									part2Unit = item.part2Unit
									part2Quantity = Int(item.part2Qty)
									part3 = item.part3
									part3cost = item.part3cost
									part3Unit = item.part3Unit
									part3Quantity = Int(item.part3Qty)
									part4 = item.part4
									part4cost = item.part4cost
									part4Unit = item.part4Unit
									part4Quantity = Int(item.part4Qty)
									part5 = item.part5
									part5cost = item.part5cost
									part5Unit = item.part5Unit
									part5Quantity = Int(item.part5Qty)
									// Custom tracking field, if the selected item template defines one
									if !item.customMeasureLabel.isEmpty {
										customMeasureLabel = item.customMeasureLabel
										customMeasureUnit = item.customMeasureUnit
										customMeasureValue = item.customMeasureValue
										customMeasureLabelSelection = item.customMeasureLabel
									}
									// Also sync the five parts ModelPicker selections to match the new item
									syncPartSelectionsFromNames(
										p1: part1, p2: part2, p3: part3, p4: part4, p5: part5
									)
									// Import the master item's own embedded sub service items, so this
									// record's SUB SERVICE ITEMS slots pick up the whole bundle. Overwrites
									// whatever sub-items were previously on this record, exactly like the
									// description/vendor/parts copy above.
									importSubItemsFromTemplate(item)
									recomputeTotals()
								}
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Database Item")
									.textLabelModified()
							}
							.frame(maxWidth: .infinity, alignment: .trailing)
						
						
						// Manual overrides for the service item and descriptions
						HStack{LabelDataTextview(label: "Manual Item", data: $mxName)}
						Text("Not in Database Item above? Type a name here — saving offers to add it as a new Service Item for reuse.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .trailing)
						HStack{LabelDataTextview(label: "Description", data: $mxDescription)}
//						HStack{LabelDataTextview(label: "Notes", data: $Notes)}

						// Vendor selection (ModelPicker<Vendors1>)
						HStack{
							Text("Vendor")
								.textLabelModified()

							ModelPicker(
								selection: $selectedVendor,
								title: "Vendor",
								includeEmptyChoice: true,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: nil, // Show all vendors
								sort: [SortDescriptor(\.vendorName, order: .forward)],
								labelProvider: { $0.vendorName }
							)
							.frame(maxWidth: .infinity, alignment: .trailing)
							.onChange(of: selectedVendor) { _, newVendor in
								// Keep local and model vendor strings in sync
								let name = newVendor?.vendorName ?? ""
								vendor = name
								dataSet.vendor = name
							}
							.onAppear {
								// Seed local state and picker selection from the model
								vendor = dataSet.vendor
								if selectedVendor == nil, !dataSet.vendor.isEmpty {
                                    let name = dataSet.vendor
									var fd = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
									fd.fetchLimit = 1
									if let found = try? modelContext.fetch(fd).first {
										selectedVendor = found
									}
								}
							}
						}
					}
				}
				
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "SERVICE RECORD NOTES", prompt: "Enter notes...", data: $Notes)
				}
				
				// SERVICE COMPLETED AT
				CardView {
					VStack {
						SectionText(label: "SERVICE COMPLETED AT")
						// Mileage and engine hours at the time of service
						if Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataTextview_Numberpad_Int(label: "\(Vertical.current.distanceMeterLabel) (\(unit(UnitIndex.distance)))", data: $Miles)}
								.onChange(of: Miles) { _, _ in recomputeTotals() }
						}
						HStack{LabelDataTextview_Numberpad_Float(label: Vertical.current.hoursMeterLabel, data: $engHours)}
							.onChange(of: engHours) { _, _ in recomputeTotals() }
						// User-defined numeric tracking field (e.g. Water Gallons). Selecting a
						// previously used field name auto-fills the unit last used with it.
						LabeledContent {
							Picker("", selection: $customMeasureLabelSelection) {
								Text("— None —").tag("__none__")
								ForEach(availableCustomMeasureLabels, id: \.self) { name in
									Text(name).tag(name)
								}
								Text("New Field...").tag("__new__")
							}
							.pickerStyle(.menu)
							.fixedSize()
							.onChange(of: customMeasureLabelSelection) { _, newVal in
								if newVal == "__none__" {
									customMeasureLabel = ""
									customMeasureUnit = ""
								} else if newVal != "__new__" {
									customMeasureLabel = newVal
									customMeasureUnit = unitForCustomMeasureLabel(newVal)
								}
							}
						} label: {
							Text("Custom Field Name")
								.textLabelModified()
						}
						if customMeasureLabelSelection == "__new__" {
							HStack{LabelDataTextview(label: "Field Name", data: $customMeasureLabel)}
						}
						if customMeasureLabelSelection != "__none__" {
							HStack{LabelDataTextview(label: "Custom Field Unit", data: $customMeasureUnit)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Custom Field Value\(customMeasureUnit.isEmpty ? "" : " (\(customMeasureUnit))")", data: $customMeasureValue)}
						}
					}
				}

				// PART 1
				CardView {
					VStack {
						SectionText(label: "PART 1")
						// Link to MxParts1 database entry
						HStack{
							Text("Database Entry")
								.textLabelModified()
							PartPickerRow(
								title: "Part 1",
								vehicleId: vehicleId,
								selection: $selectedPart1,
								seedPartName: getPartNameFromDataSet(index: 1)
							) { newPart in
								setPart(index: 1, from: newPart)
							}
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						// Manual overrides
						HStack{LabelDataTextview(label: "Manual Entry", data: $part1)}
						if let p = selectedPart1, p.inventoryTracked {
							HStack{LabelDataText(label: "Current Inventory", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
						}
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity Used/Repair", data: $part1Quantity)}
							.onChange(of: part1Quantity) { _, _ in recomputeTotals() }
						if let p = selectedPart1, p.inventoryTracked {
							let projectedRemaining = p.inventoryQuantityOnHand - Float(part1Quantity)
							let reorderNeeded = projectedRemaining <= p.inventoryReorderPoint
							HStack{LabelDataText(label: "Inventory After", data: "\(projectedRemaining.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
								.foregroundColor(reorderNeeded ? .red : .primary)
							if reorderNeeded {
								Text("Reorder needed — remaining inventory will be at or below the reorder point.")
									.font(.caption)
									.foregroundStyle(.red)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part1cost)}
							.onChange(of: part1cost) { _, _ in recomputeTotals() }
						Picker_PartsUnit(label: "Unit", data: $part1Unit)
						HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part1Quantity) * Double(part1cost)), unit: "")}
					}
				}

				// PART 2 (conditionally shown if at least part1 or part2 is non-empty)
				if part2 != "" || part1 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 2")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
									title: "Part 2",
									vehicleId: vehicleId,
									selection: $selectedPart2,
									seedPartName: getPartNameFromDataSet(index: 2)
								) { newPart in
									setPart(index: 2, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part2)}
							if let p = selectedPart2, p.inventoryTracked {
								HStack{LabelDataText(label: "Current Inventory", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity Used/Repair", data: $part2Quantity)}
								.onChange(of: part2Quantity) { _, _ in recomputeTotals() }
							if let p = selectedPart2, p.inventoryTracked {
								let projectedRemaining = p.inventoryQuantityOnHand - Float(part2Quantity)
								let reorderNeeded = projectedRemaining <= p.inventoryReorderPoint
								HStack{LabelDataText(label: "Inventory After", data: "\(projectedRemaining.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
									.foregroundColor(reorderNeeded ? .red : .primary)
								if reorderNeeded {
									Text("Reorder needed — remaining inventory will be at or below the reorder point.")
										.font(.caption)
										.foregroundStyle(.red)
										.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part2cost)}
								.onChange(of: part2cost) { _, _ in recomputeTotals() }
							Picker_PartsUnit(label: "Unit", data: $part2Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part2Quantity) * Double(part2cost)), unit: "")}
						}
					}
				}

				// PART 3
				if part3 != "" || part2 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 3")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
									title: "Part 3",
									vehicleId: vehicleId,
									selection: $selectedPart3,
									seedPartName: getPartNameFromDataSet(index: 3)
								) { newPart in
									setPart(index: 3, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part3)}
							if let p = selectedPart3, p.inventoryTracked {
								HStack{LabelDataText(label: "Current Inventory", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity Used/Repair", data: $part3Quantity)}
								.onChange(of: part3Quantity) { _, _ in recomputeTotals() }
							if let p = selectedPart3, p.inventoryTracked {
								let projectedRemaining = p.inventoryQuantityOnHand - Float(part3Quantity)
								let reorderNeeded = projectedRemaining <= p.inventoryReorderPoint
								HStack{LabelDataText(label: "Inventory After", data: "\(projectedRemaining.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
									.foregroundColor(reorderNeeded ? .red : .primary)
								if reorderNeeded {
									Text("Reorder needed — remaining inventory will be at or below the reorder point.")
										.font(.caption)
										.foregroundStyle(.red)
										.frame(maxWidth: .infinity, alignment: .leading)
								}
							}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part3cost)}
								.onChange(of: part3cost) { _, _ in recomputeTotals() }
							Picker_PartsUnit(label: "Unit", data: $part3Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part3Quantity) * Double(part3cost)), unit: "")}
						}
					}
				}
				
				// PART 4
				if part4 != "" || part3 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 4")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
									title: "Part 4",
									vehicleId: vehicleId,
									selection: $selectedPart4,
									seedPartName: getPartNameFromDataSet(index: 4)
								) { newPart in
									setPart(index: 4, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part4)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part4Unit))", data: $part4Quantity)}
								.onChange(of: part4Quantity) { _, _ in recomputeTotals() }
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part4cost)}
								.onChange(of: part4cost) { _, _ in recomputeTotals() }
							Picker_PartsUnit(label: "Unit", data: $part4Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part4Quantity) * Double(part4cost)), unit: "")}
							if let p = selectedPart4, p.inventoryTracked {
								HStack{LabelDataText(label: "In Stock", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
									.foregroundColor(p.inventoryQuantityOnHand <= p.inventoryReorderPoint ? .red : .primary)
							}
						}
					}
				}
				
				// PART 5
				if part5 != "" || part4 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 5")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								PartPickerRow(
									title: "Part 5",
									vehicleId: vehicleId,
									selection: $selectedPart5,
									seedPartName: getPartNameFromDataSet(index: 5)
								) { newPart in
									setPart(index: 5, from: newPart)
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part5)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part5Unit))", data: $part5Quantity)}
								.onChange(of: part5Quantity) { _, _ in recomputeTotals() }
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part5cost)}
								.onChange(of: part5cost) { _, _ in recomputeTotals() }
							Picker_PartsUnit(label: "Unit", data: $part5Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part5Quantity) * Double(part5cost)), unit: "")}
							if let p = selectedPart5, p.inventoryTracked {
								HStack{LabelDataText(label: "In Stock", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
									.foregroundColor(p.inventoryQuantityOnHand <= p.inventoryReorderPoint ? .red : .primary)
							}
						}
					}
				}

				// SUB SERVICE ITEMS
				// Additional MxItems3 templates covering other work done during the same visit.
				// Each slot is its own card and reveals the next once it has a name, mirroring
				// the PART 1...PART 5 cards above. Picking a Database Item copies its
				// description/labor cost in as a one-time snapshot — later edits to that
				// template do not reach back here.
				let currentSubItemVehicle = vehicleId
				let subItemsFilter: Predicate<MxItems3>? = currentSubItemVehicle.isEmpty
				? nil
				: #Predicate<MxItems3> { $0.vehicleId == currentSubItemVehicle || $0.vehicleId == "All Vehicles" }

				CardView {
					VStack {
						SectionBanner(label: "ITEM 1")
						LabeledContent {
							ModelPicker(
								selection: $selectedSubItem1,
								title: "Sub Item 1",
								includeEmptyChoice: true,
								emptyChoiceLabel: "—",
								autoSelectFirst: false,
								filter: subItemsFilter,
								sort: [SortDescriptor(\.mxName, order: .forward)],
								labelProvider: { $0.pickerLabel },
								onSelectionChanged: { newItem in setSubItem(index: 1, from: newItem) }
							)
							.fixedSize(horizontal: true, vertical: true)
							.frame(maxWidth: .infinity, alignment: .trailing)
						} label: {
							Text("Database Item")
								.textLabelModified()
						}
						HStack{LabelDataTextview(label: "Manual Item", data: $subItem1)}
						HStack{LabelDataTextview(label: "Description", data: $subItem1Description)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $subItem1LaborCost)}
							.onChange(of: subItem1LaborCost) { _, _ in recomputeTotals() }
						LabelDataTextview_MultiLine(label: "Comments", data: $subItem1Comments)
					}
				}

				if !subItem1.isEmpty {
					CardView {
						VStack {
							SectionBanner(label: "ITEM 2")
							LabeledContent {
								ModelPicker(
									selection: $selectedSubItem2,
									title: "Sub Item 2",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: subItemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.pickerLabel },
									onSelectionChanged: { newItem in setSubItem(index: 2, from: newItem) }
								)
								.fixedSize(horizontal: true, vertical: true)
								.frame(maxWidth: .infinity, alignment: .trailing)
							} label: {
								Text("Database Item")
									.textLabelModified()
							}
							HStack{LabelDataTextview(label: "Manual Item", data: $subItem2)}
							HStack{LabelDataTextview(label: "Description", data: $subItem2Description)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $subItem2LaborCost)}
								.onChange(of: subItem2LaborCost) { _, _ in recomputeTotals() }
							LabelDataTextview_MultiLine(label: "Comments", data: $subItem2Comments)
						}
					}
				}

				if !subItem2.isEmpty {
					CardView {
						VStack {
							SectionBanner(label: "ITEM 3")
							LabeledContent {
								ModelPicker(
									selection: $selectedSubItem3,
									title: "Sub Item 3",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: subItemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.pickerLabel },
									onSelectionChanged: { newItem in setSubItem(index: 3, from: newItem) }
								)
								.fixedSize(horizontal: true, vertical: true)
								.frame(maxWidth: .infinity, alignment: .trailing)
							} label: {
								Text("Database Item")
									.textLabelModified()
							}
							HStack{LabelDataTextview(label: "Manual Item", data: $subItem3)}
							HStack{LabelDataTextview(label: "Description", data: $subItem3Description)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $subItem3LaborCost)}
								.onChange(of: subItem3LaborCost) { _, _ in recomputeTotals() }
							LabelDataTextview_MultiLine(label: "Comments", data: $subItem3Comments)
						}
					}
				}

				if !subItem3.isEmpty {
					CardView {
						VStack {
							SectionBanner(label: "ITEM 4")
							LabeledContent {
								ModelPicker(
									selection: $selectedSubItem4,
									title: "Sub Item 4",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: subItemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.pickerLabel },
									onSelectionChanged: { newItem in setSubItem(index: 4, from: newItem) }
								)
								.fixedSize(horizontal: true, vertical: true)
								.frame(maxWidth: .infinity, alignment: .trailing)
							} label: {
								Text("Database Item")
									.textLabelModified()
							}
							HStack{LabelDataTextview(label: "Manual Item", data: $subItem4)}
							HStack{LabelDataTextview(label: "Description", data: $subItem4Description)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $subItem4LaborCost)}
								.onChange(of: subItem4LaborCost) { _, _ in recomputeTotals() }
							LabelDataTextview_MultiLine(label: "Comments", data: $subItem4Comments)
						}
					}
				}

				if !subItem4.isEmpty {
					CardView {
						VStack {
							SectionBanner(label: "ITEM 5")
							LabeledContent {
								ModelPicker(
									selection: $selectedSubItem5,
									title: "Sub Item 5",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: subItemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.pickerLabel },
									onSelectionChanged: { newItem in setSubItem(index: 5, from: newItem) }
								)
								.fixedSize(horizontal: true, vertical: true)
								.frame(maxWidth: .infinity, alignment: .trailing)
							} label: {
								Text("Database Item")
									.textLabelModified()
							}
							HStack{LabelDataTextview(label: "Manual Item", data: $subItem5)}
							HStack{LabelDataTextview(label: "Description", data: $subItem5Description)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $subItem5LaborCost)}
								.onChange(of: subItem5LaborCost) { _, _ in recomputeTotals() }
							LabelDataTextview_MultiLine(label: "Comments", data: $subItem5Comments)
						}
					}
				}

				// COSTS (labor only here; parts totals are computed)
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $laborCost)}
							.onChange(of: laborCost) { _, _ in recomputeTotals() }
					}
				}

				// LINK TO ADDITIONS
				CardView {
					VStack(spacing: 8) {
						SectionText(label: "LINK TO ADDITIONS")
						if additionsLinkId.isEmpty {
							Text("Transfer parts and labor costs to the Additions module by linking this service record to an Additions entry.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
							Button("Transfer to Additions") {
								loadAdditionsCategories()
								showAdditionsTransferSheet = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.blue))
						} else {
							HStack { LabelDataText(label: "Category", data: transferCategory) }
							if !transferSubCategory.isEmpty {
								HStack { LabelDataText(label: "Sub-Category", data: transferSubCategory) }
							}
							HStack { LabelDataNumber(label: "Linked Items", data: Float(linkedAdditionsCount), fractionalLength: 0) }
							HStack { LabelDataCurrency(label: "Total Synced Cost", data: Float(trackAllCostTotal), unit: "") }
							Button("Unlink All from Additions") { unlinkFromAdditions() }
								.buttonStyle(GrowingButton(buttonColor: Color.gray))
						}
					}
				}

				// STATISTICS (computed values and aggregates)
				CardView {
					VStack {
						SectionText(label: "STATISTICS")
						HStack{LabelDataCurrency(label: "Parts Subtotal", data: Float(trackPartsCostTotal), unit: "")}
						HStack{LabelDataCurrency(label: "Labor", data: laborCost, unit: "")}
						if trackSubItemsLaborTotal != 0 {
							HStack{LabelDataCurrency(label: "Sub-Items Labor", data: Float(trackSubItemsLaborTotal), unit: "")}
						}
						Divider()
						HStack{LabelDataCurrency(label: "Grand Total", data: Float(trackAllCostTotal), unit: "")}
							.foregroundColor(.red)
						Divider()
						HStack{LabelDataNumber(label: "Parts Lines Used", data: Float(partsLinesCount), fractionalLength: 0)}
						HStack{LabelDataNumber(label: "Total Parts Quantity", data: Float(totalPartsQuantity), fractionalLength: 0)}
						HStack{LabelDataCurrency(label: "Avg Cost/Part Unit", data: Float(avgCostPerPartUnit), unit: "")}
						if Miles > 0 {
							HStack{LabelDataCurrency(label: "Cost per \(unit(UnitIndex.distance))", data: Float(costPerMile), unit: "/ \(unit(UnitIndex.distance))")}
						}
						if engHours > 0 {
							HStack{LabelDataCurrency(label: "Cost per Engine Hour", data: Float(costPerEngineHour), unit: "/ hr")}
						}
					}
				}

				// SERVICE ITEM & VEHICLE STATS (intervals and due estimates)
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM & \(Vertical.current.assetSingular.uppercased()) STATS")
						// Vehicle
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: vehicleId, context: modelContext))}
						if vehicleCurrentMiles > 0 && Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataText(label: "Current \(Vertical.current.distanceMeterLabel)", data: "\(vehicleCurrentMiles) \(unit(UnitIndex.distance))")}
						}
						if vehicleCurrentEngHours > 0 {
							HStack{LabelDataNumber(label: "Current \(Vertical.current.hoursMeterLabel)", data: vehicleCurrentEngHours, fractionalLength: 1)}
						}
						if Miles > 0 && vehicleCurrentMiles >= Miles && Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataText(label: "\(Vertical.current.distanceMeterLabel) Since Service", data: "\(milesSinceService) \(unit(UnitIndex.distance))")}
						}
						if engHours > 0 && vehicleCurrentEngHours >= engHours {
							HStack{LabelDataNumber(label: "Hours Since Service", data: hoursSinceService, fractionalLength: 1)}
						}
						Divider()
						// Service Item intervals
						if itemIntervalMiles > 0 || itemIntervalMonths > 0 || itemIntervalHours > 0 {
							HStack{LabelDataText(label: "Service Item", data: mxName.isEmpty ? dataSet.mxName : mxName)}
							if itemIntervalMiles > 0 {
								HStack{LabelDataText(label: "Interval (Miles)", data: "\(itemIntervalMiles) \(unit(UnitIndex.distance))")}
								HStack{LabelDataText(label: "Remaining Miles", data: "\(max(0, milesRemainingToDue)) \(unit(UnitIndex.distance))")}
							}
							if itemIntervalHours > 0 {
								HStack{LabelDataNumber(label: "Interval (Hours)", data: itemIntervalHours, fractionalLength: 1)}
								HStack{LabelDataNumber(label: "Remaining Hours", data: max(0, hoursRemainingToDue), fractionalLength: 1)}
							}
							if itemIntervalMonths > 0 {
								HStack{LabelDataText(label: "Interval (Months)", data: "\(itemIntervalMonths)")}
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
				
				// RECORDS GRAPHICS (edit)
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "RECORDS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  RECORDS GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Service Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

				
			}// end of edit scroll view

			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "service")
			}

			.onAppear {
				// Load display units (e.g., miles vs km), vehicle stats, and intervals.
				// Seed pickers from existing model values.
				loadUnits()
				refreshVehicleDetails()
				loadItemIntervalsIfNeeded()
				loadAvailableCustomMeasureLabels()
				recomputeTotals()

				// Seed the vehicle picker from existing vehicleId if present
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}

				// Seed the generic service item picker from existing mxItemId, if present
				if selectedServiceItem == nil, !dataSet.mxItemId.isEmpty {
					let mxId = dataSet.mxItemId
					var fd = FetchDescriptor<MxItems3>(predicate: #Predicate { $0.mxName == mxId })
					fd.fetchLimit = 1
					if let item = try? modelContext.fetch(fd).first {
						selectedServiceItem = item
					}
				}

				// Seed the sub-item pickers from existing subItemNId, if present. Assign the
				// selection only — do NOT call setSubItem here, which would re-copy the source
				// MxItems3's current description/labor cost over this record's saved snapshot.
				if selectedSubItem1 == nil, !dataSet.subItem1Id.isEmpty {
					selectedSubItem1 = resolveMxItem(named: dataSet.subItem1Id)
				}
				if selectedSubItem2 == nil, !dataSet.subItem2Id.isEmpty {
					selectedSubItem2 = resolveMxItem(named: dataSet.subItem2Id)
				}
				if selectedSubItem3 == nil, !dataSet.subItem3Id.isEmpty {
					selectedSubItem3 = resolveMxItem(named: dataSet.subItem3Id)
				}
				if selectedSubItem4 == nil, !dataSet.subItem4Id.isEmpty {
					selectedSubItem4 = resolveMxItem(named: dataSet.subItem4Id)
				}
				if selectedSubItem5 == nil, !dataSet.subItem5Id.isEmpty {
					selectedSubItem5 = resolveMxItem(named: dataSet.subItem5Id)
				}

				// Seed vendor selection if needed
				if selectedVendor == nil, !dataSet.vendor.isEmpty {
					let name = dataSet.vendor
					var fdV = FetchDescriptor<Vendors1>(predicate: #Predicate { $0.vendorName == name })
					fdV.fetchLimit = 1
					if let v = try? modelContext.fetch(fdV).first {
						selectedVendor = v
					}
				}

				// Seed part pickers from existing record values
				if selectedPart1 == nil, !dataSet.part1.isEmpty {
					let name = dataSet.part1
					var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
					fd.fetchLimit = 1
					if let p = try? modelContext.fetch(fd).first { selectedPart1 = p }
				}
				if selectedPart2 == nil, !dataSet.part2.isEmpty {
					let name = dataSet.part2
					var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
					fd.fetchLimit = 1
					if let p = try? modelContext.fetch(fd).first { selectedPart2 = p }
				}
				if selectedPart3 == nil, !dataSet.part3.isEmpty {
					let name = dataSet.part3
					var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
					fd.fetchLimit = 1
					if let p = try? modelContext.fetch(fd).first { selectedPart3 = p }
				}
				if selectedPart4 == nil, !dataSet.part4.isEmpty {
					let name = dataSet.part4
					var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
					fd.fetchLimit = 1
					if let p = try? modelContext.fetch(fd).first { selectedPart4 = p }
				}
				if selectedPart5 == nil, !dataSet.part5.isEmpty {
					let name = dataSet.part5
					var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
					fd.fetchLimit = 1
					if let p = try? modelContext.fetch(fd).first { selectedPart5 = p }
				}
				// Load additions link state
				additionsLinkId = dataSet.additionsLinkId
				loadAdditionsCategories()
				if !additionsLinkId.isEmpty { loadAdditionsLinkState() }
			}
			.sheet(isPresented: $showAdditionsTransferSheet) {
				AdditionsTransferSheet(
					existingCategories: allAdditionsCategories,
					existingSubCategories: allAdditionsSubCategories,
					lineItems: buildTransferLineItems(),
					onTransfer: { cat, subcat in
						transferToAdditions(category: cat, subCategory: subcat)
					}
				)
			}
			.toolbar {
				// Edit mode toolbar: label, Cancel toggle, Save
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						// Tapping Save writes all local state back into dataSet and persists it —
						// unless the current item name isn't in the Service Items table yet
						// (whether it was typed manually or edited after picking a database item),
						// in which case we offer to save it there first.
						let trimmedName = trimmed(mxName)
						if !trimmedName.isEmpty && !serviceItemExists(trimmedName) {
							showingSaveAsItemPrompt = true
						} else {
							isEditing.toggle()
							updateItem()
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.confirmationDialog(
						"Save as Service Item?",
						isPresented: $showingSaveAsItemPrompt,
						titleVisibility: .visible
					) {
						Button("Save as New Service Item") {
							saveManualItemAsServiceItem()
							isEditing.toggle()
							updateItem()
						}
						Button("Just Save This Record") {
							isEditing.toggle()
							updateItem()
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						Text("\"\(trimmed(mxName))\" isn't in your Service Items list yet. Save it there so it can be reused for future service records on this \(Vertical.current.assetSingular.lowercased())?")
					}
				}
			}

		} else {

			// DETAILS MODE (read-only, formatted)
			ScrollView {
				// Created/Updated timestamps
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}

				// GENERAL
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						HStack{LabelDataText(label: "Service Date", data: "\(functions.formatDate_DDMMMyy(date:dataSet.mxDate))")}
						HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "INACTIVE" : "ACTIVE")}
					}
				}
				
				// SERVICE ITEM DETAILS
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataText(label: "Service Item", data: "\(dataSet.mxName)")}
						if dataSet.mxDescription != "" {
							HStack{LabelDataText(label: "Description", data: "\(dataSet.mxDescription)")}
						}
						if dataSet.vendor != "" {
							HStack{LabelDataText(label: "Shop", data: "\(dataSet.vendor)")}
						}
					}
				}
				
				if dataSet.Notes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "SERVICE RECORD NOTES", data: dataSet.Notes)}
				}
				
				// SERVICE COMPLETED AT — hidden when no usage values were recorded
				if hasServiceCompletedAt {
					CardView {
					VStack {
						SectionText(label: "SERVICE COMPLETED AT")
						if dataSet.Miles > 0 && Vertical.current.visibleFieldGroups.contains(.odometer) {
							HStack{LabelDataText(label: Vertical.current.distanceMeterLabel, data: "\(dataSet.Miles) \(unit(UnitIndex.distance))")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: Vertical.current.hoursMeterLabel, data: Float(dataSet.engHours), fractionalLength: 1)}
						}
						if !dataSet.customMeasureLabel.isEmpty {
							HStack{LabelDataText(label: dataSet.customMeasureLabel, data: "\(dataSet.customMeasureValue.formatted(.number.precision(.fractionLength(1)))) \(dataSet.customMeasureUnit)")}
						}
					}
					}
				}

				// PARTS USED (read-only summary) — hidden when no parts were entered
				if hasPartsUsed {
					CardView {
					VStack {
						SectionText(label: "PARTS USED")
						if dataSet.part1 != "" {
							HStack{LabelDataText(label: "Part Name", data: "\(part1)")}
							HStack{LabelDataText(label: "Quantity", data: "\(part1Quantity) \(part1Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part1cost), unit: "/ \(part1Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part1Quantity) * Double(part1cost)), unit: "")}
							if let p = fetchPart(named: dataSet.part1), p.inventoryTracked {
								HStack{LabelDataText(label: "Inventory Remaining", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
						}
						if dataSet.part2 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part2)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part2Quantity) \(dataSet.part2Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part2cost), unit: "/ \(part2Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part2Quantity) * Double(part2cost)), unit: "")}
							if let p = fetchPart(named: dataSet.part2), p.inventoryTracked {
								HStack{LabelDataText(label: "Inventory Remaining", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
						}
						if dataSet.part3 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part3)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part3Quantity) \(dataSet.part3Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part3cost), unit: "/ \(part3Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part3Quantity) * Double(part3cost)), unit: "")}
							if let p = fetchPart(named: dataSet.part3), p.inventoryTracked {
								HStack{LabelDataText(label: "Inventory Remaining", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
						}
						if dataSet.part4 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part4)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part4Quantity) \(dataSet.part4Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part4cost), unit: "/ \(part4Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part4Quantity) * Double(part4cost)), unit: "")}
							if let p = fetchPart(named: dataSet.part4), p.inventoryTracked {
								HStack{LabelDataText(label: "Inventory Remaining", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
						}
						if dataSet.part5 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part5)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part5Quantity) \(dataSet.part5Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part5cost), unit: "/ \(part5Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part5Quantity) * Double(part5cost)), unit: "")}
							if let p = fetchPart(named: dataSet.part5), p.inventoryTracked {
								HStack{LabelDataText(label: "Inventory Remaining", data: "\(p.inventoryQuantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(p.partUnit)")}
							}
						}
					}
					}
				}

				// SUB SERVICE ITEMS (read-only summary) — each sub-item is its own card, for
				// clear visual separation, mirroring the PART 1...PART 5 cards above.
				if dataSet.subItem1 != "" {
					CardView {
						VStack {
							SectionText(label: "SUB SERVICE ITEM 1")
							HStack{LabelDataText(label: "Item Name", data: dataSet.subItem1)}
							if dataSet.subItem1Description != "" { HStack{LabelDataText(label: "Description", data: dataSet.subItem1Description)} }
							HStack{LabelDataCurrency(label: "Labor Cost", data: Float(dataSet.subItem1LaborCost), unit: "")}
							if dataSet.subItem1Comments != "" { TextNoteDisplay_Inline(label: "Comments", data: dataSet.subItem1Comments) }
						}
					}
				}
				if dataSet.subItem2 != "" {
					CardView {
						VStack {
							SectionText(label: "SUB SERVICE ITEM 2")
							HStack{LabelDataText(label: "Item Name", data: dataSet.subItem2)}
							if dataSet.subItem2Description != "" { HStack{LabelDataText(label: "Description", data: dataSet.subItem2Description)} }
							HStack{LabelDataCurrency(label: "Labor Cost", data: Float(dataSet.subItem2LaborCost), unit: "")}
							if dataSet.subItem2Comments != "" { TextNoteDisplay_Inline(label: "Comments", data: dataSet.subItem2Comments) }
						}
					}
				}
				if dataSet.subItem3 != "" {
					CardView {
						VStack {
							SectionText(label: "SUB SERVICE ITEM 3")
							HStack{LabelDataText(label: "Item Name", data: dataSet.subItem3)}
							if dataSet.subItem3Description != "" { HStack{LabelDataText(label: "Description", data: dataSet.subItem3Description)} }
							HStack{LabelDataCurrency(label: "Labor Cost", data: Float(dataSet.subItem3LaborCost), unit: "")}
							if dataSet.subItem3Comments != "" { TextNoteDisplay_Inline(label: "Comments", data: dataSet.subItem3Comments) }
						}
					}
				}
				if dataSet.subItem4 != "" {
					CardView {
						VStack {
							SectionText(label: "SUB SERVICE ITEM 4")
							HStack{LabelDataText(label: "Item Name", data: dataSet.subItem4)}
							if dataSet.subItem4Description != "" { HStack{LabelDataText(label: "Description", data: dataSet.subItem4Description)} }
							HStack{LabelDataCurrency(label: "Labor Cost", data: Float(dataSet.subItem4LaborCost), unit: "")}
							if dataSet.subItem4Comments != "" { TextNoteDisplay_Inline(label: "Comments", data: dataSet.subItem4Comments) }
						}
					}
				}
				if dataSet.subItem5 != "" {
					CardView {
						VStack {
							SectionText(label: "SUB SERVICE ITEM 5")
							HStack{LabelDataText(label: "Item Name", data: dataSet.subItem5)}
							if dataSet.subItem5Description != "" { HStack{LabelDataText(label: "Description", data: dataSet.subItem5Description)} }
							HStack{LabelDataCurrency(label: "Labor Cost", data: Float(dataSet.subItem5LaborCost), unit: "")}
							if dataSet.subItem5Comments != "" { TextNoteDisplay_Inline(label: "Comments", data: dataSet.subItem5Comments) }
						}
					}
				}

				// COSTS (read-only)
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataCurrency(label: "Labor", data: Float(laborCost), unit: "")}
						HStack{LabelDataCurrency(label: "Parts", data: Float(trackPartsCostTotal), unit: "")}
						if trackSubItemsLaborTotal != 0 {
							HStack{LabelDataCurrency(label: "Sub-Items Labor", data: Float(trackSubItemsLaborTotal), unit: "")}
						}
						Divider()
						HStack{LabelDataCurrency(label: "Total Costs", data: Float(trackAllCostTotal), unit: "")}
							.foregroundColor(.red)
					}
				}

				// LINKED ADDITION (read-only)
				if !additionsLinkId.isEmpty {
					CardView {
						VStack {
							SectionText(label: "LINKED TO ADDITIONS")
							HStack { LabelDataText(label: "Category", data: transferCategory) }
							if !transferSubCategory.isEmpty {
								HStack { LabelDataText(label: "Sub-Category", data: transferSubCategory) }
							}
							HStack { LabelDataNumber(label: "Linked Items", data: Float(linkedAdditionsCount), fractionalLength: 0) }
							HStack { LabelDataCurrency(label: "Total Synced Cost", data: Float(trackAllCostTotal), unit: "") }
						}
					}
				}

				// STATISTICS (read-only)
				CardView {
					VStack {
						SectionText(label: "STATISTICS")
						HStack{LabelDataNumber(label: "Parts Used", data: Float(totalPartsQuantity), fractionalLength: 0)}
						HStack{LabelDataCurrency(label: "Avg Cost/Part Unit", data: Float(avgCostPerPartUnit), unit: "")}
						if dataSet.Miles > 0 {
							HStack{LabelDataCurrency(label: "Cost / \(unit(UnitIndex.distance))", data: Float(costPerMile), unit: "")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataCurrency(label: "Cost / Engine Hour", data: Float(costPerEngineHour), unit: "")}
						}
					}
				}

				// VEHICLE STATS and SERVICE ITEM intervals (read-only)
				CardView {
					VStack {
						SectionText(label: "\(Vertical.current.assetSingular.uppercased()) STATS")
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						if vehicleCurrentMiles > 0 {
							HStack{LabelDataText(label: "Current Odometer", data: "\(vehicleCurrentMiles) \(unit(UnitIndex.distance))")}
						}
						if vehicleCurrentEngHours > 0 {
							HStack{LabelDataNumber(label: "Current Engine Hours", data: vehicleCurrentEngHours, fractionalLength: 1)}
						}

						SectionText(label: "SERVICE ITEM")
						if itemIntervalMiles > 0 || itemIntervalMonths > 0 || itemIntervalHours > 0 {
							HStack{LabelDataText(label: "Item Name", data: dataSet.mxName)}
							if itemIntervalMiles > 0 {
								HStack{LabelDataText(label: "Interval (\(unit(UnitIndex.distance)))", data: "\(itemIntervalMiles)")}
								HStack{LabelDataText(label: "Due (\(unit(UnitIndex.distance)))", data: "\(max(0, milesRemainingToDue))")}
							}
							if itemIntervalHours > 0 {
								HStack{LabelDataNumber(label: "Interval (Hours)", data: itemIntervalHours, fractionalLength: 1)}
								HStack{LabelDataNumber(label: "Due (Hours)", data: max(0, hoursRemainingToDue), fractionalLength: 1)}
							}
							if itemIntervalMonths > 0 {
								HStack{LabelDataText(label: "Interval (Months)", data: "\(itemIntervalMonths)")}
								HStack{LabelDataText(label: "Due (Days)", data: "\(max(0, daysRemainingToDue))")}
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
				
				// SERVICE RECORDS GRAPHICS (read-only images) — hidden when none attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "SERVICE RECORDS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
					}
				}

			}//end of details scroll view
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "service")
			}

			.onAppear {
				// Keep derived values up-to-date when entering details mode
				loadUnits()
				refreshVehicleDetails()
				loadItemIntervalsIfNeeded()
				recomputeTotals()
				// Load additions link state
				additionsLinkId = dataSet.additionsLinkId
				if !additionsLinkId.isEmpty { loadAdditionsLinkState() }
			}

			.toolbar {
				// Details toolbar: label, Edit toggle, Delete
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

	// Deletes the current record from SwiftData and dismisses the view.
	private func DeleteRecord(){
		// Return any inventory this record consumed before it disappears, so deleting
		// a service record doesn't permanently understate stock on hand.
		releaseAllPartsInventory()
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}

	// Marks the record inactive and saves it.
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

	// Persists changes from local @State back to the SwiftData model, then
	// updates related Vehicle8 odometer/hours if needed, and refreshes derived values.
	private func updateItem() {
		// Snapshot each part slot's previously-saved name/quantity before overwriting dataSet,
		// so inventory can be reconciled against what was actually consumed last time.
		let oldParts: [(name: String, qty: Int)] = [
			(dataSet.part1, dataSet.part1Quantity),
			(dataSet.part2, dataSet.part2Quantity),
			(dataSet.part3, dataSet.part3Quantity),
			(dataSet.part4, dataSet.part4Quantity),
			(dataSet.part5, dataSet.part5Quantity),
		]

		// Copy all edited values back into the model
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.inactive = inactive
		dataSet.mxDate = mxDate
		dataSet.vehicleId = vehicleId
		dataSet.Miles = Miles
		dataSet.engHours = engHours
		dataSet.mxName = mxName
		dataSet.mxItemId = mxItemId
		dataSet.mxDescription = mxDescription
		dataSet.Notes = Notes
		dataSet.vendor = vendor
		dataSet.laborCost = laborCost
		dataSet.part1 = part1
		dataSet.part1cost = part1cost
		dataSet.part1Unit = part1Unit
		dataSet.part1Quantity = part1Quantity
		dataSet.part2 = part2
		dataSet.part2cost = part2cost
		dataSet.part2Unit = part2Unit
		dataSet.part2Quantity = part2Quantity
		dataSet.part3 = part3
		dataSet.part3cost = part3cost
		dataSet.part3Unit = part3Unit
		dataSet.part3Quantity = part3Quantity
		dataSet.part4 = part4
		dataSet.part4cost = part4cost
		dataSet.part4Unit = part4Unit
		dataSet.part4Quantity = part4Quantity
		dataSet.part5 = part5
		dataSet.part5cost = part5cost
		dataSet.part5Unit = part5Unit
		dataSet.part5Quantity = part5Quantity
		dataSet.customMeasureLabel = customMeasureLabel
		dataSet.customMeasureUnit = customMeasureUnit
		dataSet.customMeasureValue = customMeasureValue
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description
		dataSet.subItem1 = subItem1
		dataSet.subItem1Id = subItem1Id
		dataSet.subItem1Description = subItem1Description
		dataSet.subItem1LaborCost = subItem1LaborCost
		dataSet.subItem1Comments = subItem1Comments
		dataSet.subItem2 = subItem2
		dataSet.subItem2Id = subItem2Id
		dataSet.subItem2Description = subItem2Description
		dataSet.subItem2LaborCost = subItem2LaborCost
		dataSet.subItem2Comments = subItem2Comments
		dataSet.subItem3 = subItem3
		dataSet.subItem3Id = subItem3Id
		dataSet.subItem3Description = subItem3Description
		dataSet.subItem3LaborCost = subItem3LaborCost
		dataSet.subItem3Comments = subItem3Comments
		dataSet.subItem4 = subItem4
		dataSet.subItem4Id = subItem4Id
		dataSet.subItem4Description = subItem4Description
		dataSet.subItem4LaborCost = subItem4LaborCost
		dataSet.subItem4Comments = subItem4Comments
		dataSet.subItem5 = subItem5
		dataSet.subItem5Id = subItem5Id
		dataSet.subItem5Description = subItem5Description
		dataSet.subItem5LaborCost = subItem5LaborCost
		dataSet.subItem5Comments = subItem5Comments

		// Reconcile inventory-tracked parts against what this record previously consumed,
		// so quantity changes, part swaps, and this save all net out to the correct on-hand total.
		let newParts: [(name: String, qty: Int)] = [
			(part1, part1Quantity), (part2, part2Quantity), (part3, part3Quantity),
			(part4, part4Quantity), (part5, part5Quantity),
		]
		reconcilePartsInventory(old: oldParts, new: newParts)

		// Save the record
		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}

		// Update the related vehicle's odometer and engine hours if the service record exceeds current values
		var fetchDescriptor = FetchDescriptor<Vehicle8>(
			predicate: #Predicate { $0.name == vehicleId }
		)
		fetchDescriptor.fetchLimit = 1
		do {
			if let vehicleRecord = try modelContext.fetch(fetchDescriptor).first {
				if Miles > vehicleRecord.mileage {
					vehicleRecord.mileage = Miles
					vehicleRecord.updatedAt = Date()
				}
				if engHours > vehicleRecord.engHours {
					vehicleRecord.engHours = engHours
				}
				try? modelContext.save()
			}
		} catch {
			print("Failed to update vehicle: \(error.localizedDescription)")
		}
		// Refresh derived info after save
		refreshVehicleDetails()
		recomputeTotals()
		// Sync linked Additions record if one exists
		if !additionsLinkId.isEmpty { syncLinkedAddition() }
		dataSet.additionsLinkId = additionsLinkId
	}

	// MARK: - Details section visibility
	// Card sections in Details mode are only rendered when at least one of their
	// fields holds data, so a section title never appears above an empty card.

	/// True when a usage reading was recorded for the service.
	private var hasServiceCompletedAt: Bool {
		dataSet.Miles > 0 || dataSet.engHours > 0 || !dataSet.customMeasureLabel.isEmpty
	}

	/// True when at least one part was entered.
	private var hasPartsUsed: Bool {
		!(dataSet.part1.isEmpty
		  && dataSet.part2.isEmpty
		  && dataSet.part3.isEmpty
		  && dataSet.part4.isEmpty
		  && dataSet.part5.isEmpty)
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
	}

	// MARK: - Helpers

	// Loads user-preference units from Settings1 via PrefsFunctions.
	private func loadUnits() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}

	// Looks up the current vehicle's odometer and engine hours for display and deltas.
	private func refreshVehicleDetails() {
		if let details = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId.isEmpty ? dataSet.vehicleId : vehicleId) {
			vehicleCurrentMiles = details.mileage
			vehicleCurrentEngHours = details.engHours
		} else {
			vehicleCurrentMiles = 0
			vehicleCurrentEngHours = 0
		}
	}

	// Loads interval values (miles, months, hours) from an MxItems3 template matching mxName.
	// Avoids capturing dataSet in #Predicate closure.
	private func loadItemIntervalsIfNeeded() {
		let name = mxName
		guard !name.isEmpty else { return }
		var fd = FetchDescriptor<MxItems3>(predicate: #Predicate { $0.mxName == name })
		fd.fetchLimit = 1
		do {
			if let item = try modelContext.fetch(fd).first {
				itemIntervalMiles = item.intervalMiles
				itemIntervalMonths = item.intervalMonths
				itemIntervalHours = item.intervalHours
			}
		} catch {}
	}

	// Loads the distinct custom tracking field names previously used, cross-referencing both
	// ServiceRecords1 (service records) and MxItems3 (service item templates), so the
	// "Custom Field Name" picker offers names entered in either place for reuse.
	private func loadAvailableCustomMeasureLabels() {
		var labels = Set<String>()
		if let records = try? modelContext.fetch(FetchDescriptor<ServiceRecords1>()) {
			labels.formUnion(records.compactMap { $0.customMeasureLabel.isEmpty ? nil : $0.customMeasureLabel })
		}
		if let items = try? modelContext.fetch(FetchDescriptor<MxItems3>()) {
			labels.formUnion(items.compactMap { $0.customMeasureLabel.isEmpty ? nil : $0.customMeasureLabel })
		}
		var sortedLabels = labels.sorted()
		if !customMeasureLabel.isEmpty && !sortedLabels.contains(customMeasureLabel) {
			sortedLabels.insert(customMeasureLabel, at: 0)
		}
		availableCustomMeasureLabels = sortedLabels
		if !customMeasureLabel.isEmpty && sortedLabels.contains(customMeasureLabel) && customMeasureLabelSelection == "__none__" {
			customMeasureLabelSelection = customMeasureLabel
		}
	}

	// Looks up the unit of measure most recently used with a given custom field name,
	// checking both ServiceRecords1 and MxItems3, so choosing that name auto-completes its unit.
	private func unitForCustomMeasureLabel(_ label: String) -> String {
		var recordFd = FetchDescriptor<ServiceRecords1>(predicate: #Predicate<ServiceRecords1> { $0.customMeasureLabel == label })
		recordFd.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
		recordFd.fetchLimit = 1
		var itemFd = FetchDescriptor<MxItems3>(predicate: #Predicate<MxItems3> { $0.customMeasureLabel == label })
		itemFd.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
		itemFd.fetchLimit = 1
		let recordMatch = try? modelContext.fetch(recordFd).first
		let itemMatch = try? modelContext.fetch(itemFd).first
		switch (recordMatch, itemMatch) {
		case (.some(let record), .some(let item)):
			return record.updatedAt >= item.updatedAt ? record.customMeasureUnit : item.customMeasureUnit
		case (.some(let record), nil):
			return record.customMeasureUnit
		case (nil, .some(let item)):
			return item.customMeasureUnit
		default:
			return ""
		}
	}

	// Sync selectedPart1...5 from the current part name strings.
	// Useful when a template is chosen or when seeding from an existing record.
	private func syncPartSelectionsFromNames(p1: String, p2: String, p3: String, p4: String, p5: String) {
		func fetchPart(named name: String) -> MxParts1? {
			guard !name.isEmpty else { return nil }
			var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == name })
			fd.fetchLimit = 1
			return try? modelContext.fetch(fd).first
		}
		selectedPart1 = fetchPart(named: p1)
		selectedPart2 = fetchPart(named: p2)
		selectedPart3 = fetchPart(named: p3)
		selectedPart4 = fetchPart(named: p4)
		selectedPart5 = fetchPart(named: p5)
	}

	// Centralized updater for part fields (both local state and dataSet) by index.
	// Called when a ModelPicker<MxParts1> selection changes.
	private func setPart(index: Int, from part: MxParts1?) {
		let name = part?.partName ?? ""
		let cost = part?.costPerUnit ?? 0
		let unit = part?.partUnit ?? ""
		let qty  = part?.partQuantity ?? 0

		switch index {
		case 1:
			part1 = name; part1cost = cost; part1Unit = unit; part1Quantity = qty
			dataSet.part1 = name; dataSet.part1cost = cost; dataSet.part1Unit = unit; dataSet.part1Quantity = qty
		case 2:
			part2 = name; part2cost = cost; part2Unit = unit; part2Quantity = qty
			dataSet.part2 = name; dataSet.part2cost = cost; dataSet.part2Unit = unit; dataSet.part2Quantity = qty
		case 3:
			part3 = name; part3cost = cost; part3Unit = unit; part3Quantity = qty
			dataSet.part3 = name; dataSet.part3cost = cost; dataSet.part3Unit = unit; dataSet.part3Quantity = qty
		case 4:
			part4 = name; part4cost = cost; part4Unit = unit; part4Quantity = qty
			dataSet.part4 = name; dataSet.part4cost = cost; dataSet.part4Unit = unit; dataSet.part4Quantity = qty
		case 5:
			part5 = name; part5cost = cost; part5Unit = unit; part5Quantity = qty
			dataSet.part5 = name; dataSet.part5cost = cost; dataSet.part5Unit = unit; dataSet.part5Quantity = qty
		default:
			break
		}
		recomputeTotals()
	}

	// Centralized updater for embedded sub-item fields (both local state and dataSet) by index.
	// Called when a ModelPicker<MxItems3> selection changes. Description/labor cost/comments
	// are copied as a one-time snapshot — later edits to the source MxItems3 template never
	// reach back into this record. Comments is seeded from the picked item's own Item Notes,
	// same as every other copied field, so re-picking replaces it too.
	private func setSubItem(index: Int, from item: MxItems3?) {
		let name = item?.mxName ?? ""
		let description = item?.mxDescription ?? ""
		let cost = item?.laborCost ?? 0
		let comments = item?.Notes ?? ""

		switch index {
		case 1:
			subItem1 = name; subItem1Id = name; subItem1Description = description; subItem1LaborCost = cost; subItem1Comments = comments
			dataSet.subItem1 = name; dataSet.subItem1Id = name; dataSet.subItem1Description = description; dataSet.subItem1LaborCost = cost; dataSet.subItem1Comments = comments
		case 2:
			subItem2 = name; subItem2Id = name; subItem2Description = description; subItem2LaborCost = cost; subItem2Comments = comments
			dataSet.subItem2 = name; dataSet.subItem2Id = name; dataSet.subItem2Description = description; dataSet.subItem2LaborCost = cost; dataSet.subItem2Comments = comments
		case 3:
			subItem3 = name; subItem3Id = name; subItem3Description = description; subItem3LaborCost = cost; subItem3Comments = comments
			dataSet.subItem3 = name; dataSet.subItem3Id = name; dataSet.subItem3Description = description; dataSet.subItem3LaborCost = cost; dataSet.subItem3Comments = comments
		case 4:
			subItem4 = name; subItem4Id = name; subItem4Description = description; subItem4LaborCost = cost; subItem4Comments = comments
			dataSet.subItem4 = name; dataSet.subItem4Id = name; dataSet.subItem4Description = description; dataSet.subItem4LaborCost = cost; dataSet.subItem4Comments = comments
		case 5:
			subItem5 = name; subItem5Id = name; subItem5Description = description; subItem5LaborCost = cost; subItem5Comments = comments
			dataSet.subItem5 = name; dataSet.subItem5Id = name; dataSet.subItem5Description = description; dataSet.subItem5LaborCost = cost; dataSet.subItem5Comments = comments
		default:
			break
		}
		recomputeTotals()
	}

	/// Resolves a sub-item's stored template-name reference to a live `MxItems3`, if it
	/// still exists. Used both to seed picker selections and to resolve a master item's
	/// bundled sub-items when importing them below.
	private func resolveMxItem(named name: String) -> MxItems3? {
		guard !name.isEmpty else { return nil }
		var fd = FetchDescriptor<MxItems3>(predicate: #Predicate<MxItems3> { $0.mxName == name })
		fd.fetchLimit = 1
		return try? modelContext.fetch(fd).first
	}

	// Writes a raw sub-item snapshot (as already stored on a master MxItems3, not re-derived
	// from a live object) into both local state and dataSet, then resolves the picker
	// selection for interactivity. Used by importSubItemsFromTemplate below; kept distinct
	// from setSubItem(index:from:), which derives its snapshot from a live MxItems3 instead.
	private func setSubItemSnapshot(index: Int, name: String, id: String, description: String, laborCost: Float, comments: String) {
		let resolved = resolveMxItem(named: id)
		switch index {
		case 1:
			subItem1 = name; subItem1Id = id; subItem1Description = description; subItem1LaborCost = laborCost; subItem1Comments = comments
			dataSet.subItem1 = name; dataSet.subItem1Id = id; dataSet.subItem1Description = description; dataSet.subItem1LaborCost = laborCost; dataSet.subItem1Comments = comments
			selectedSubItem1 = resolved
		case 2:
			subItem2 = name; subItem2Id = id; subItem2Description = description; subItem2LaborCost = laborCost; subItem2Comments = comments
			dataSet.subItem2 = name; dataSet.subItem2Id = id; dataSet.subItem2Description = description; dataSet.subItem2LaborCost = laborCost; dataSet.subItem2Comments = comments
			selectedSubItem2 = resolved
		case 3:
			subItem3 = name; subItem3Id = id; subItem3Description = description; subItem3LaborCost = laborCost; subItem3Comments = comments
			dataSet.subItem3 = name; dataSet.subItem3Id = id; dataSet.subItem3Description = description; dataSet.subItem3LaborCost = laborCost; dataSet.subItem3Comments = comments
			selectedSubItem3 = resolved
		case 4:
			subItem4 = name; subItem4Id = id; subItem4Description = description; subItem4LaborCost = laborCost; subItem4Comments = comments
			dataSet.subItem4 = name; dataSet.subItem4Id = id; dataSet.subItem4Description = description; dataSet.subItem4LaborCost = laborCost; dataSet.subItem4Comments = comments
			selectedSubItem4 = resolved
		case 5:
			subItem5 = name; subItem5Id = id; subItem5Description = description; subItem5LaborCost = laborCost; subItem5Comments = comments
			dataSet.subItem5 = name; dataSet.subItem5Id = id; dataSet.subItem5Description = description; dataSet.subItem5LaborCost = laborCost; dataSet.subItem5Comments = comments
			selectedSubItem5 = resolved
		default:
			break
		}
	}

	/// Imports a master `MxItems3`'s own bundled sub-items into this record as a one-time
	/// snapshot (the master's already-snapshotted values, not re-derived from whatever those
	/// sub-items currently look like). Only one level deep — a sub-item's own sub-items, if
	/// any, are not expanded further.
	private func importSubItemsFromTemplate(_ item: MxItems3) {
		setSubItemSnapshot(index: 1, name: item.subItem1, id: item.subItem1Id, description: item.subItem1Description, laborCost: item.subItem1LaborCost, comments: item.subItem1Comments)
		setSubItemSnapshot(index: 2, name: item.subItem2, id: item.subItem2Id, description: item.subItem2Description, laborCost: item.subItem2LaborCost, comments: item.subItem2Comments)
		setSubItemSnapshot(index: 3, name: item.subItem3, id: item.subItem3Id, description: item.subItem3Description, laborCost: item.subItem3LaborCost, comments: item.subItem3Comments)
		setSubItemSnapshot(index: 4, name: item.subItem4, id: item.subItem4Id, description: item.subItem4Description, laborCost: item.subItem4LaborCost, comments: item.subItem4Comments)
		setSubItemSnapshot(index: 5, name: item.subItem5, id: item.subItem5Id, description: item.subItem5Description, laborCost: item.subItem5LaborCost, comments: item.subItem5Comments)
	}

	/// True if an `MxItems3` service item template already exists with this name.
	private func serviceItemExists(_ name: String) -> Bool {
		guard !name.isEmpty else { return false }
		var fd = FetchDescriptor<MxItems3>(predicate: #Predicate<MxItems3> { $0.mxName == name })
		fd.fetchLimit = 1
		return ((try? modelContext.fetch(fd)) ?? []).isEmpty == false
	}

	/// Creates a new `MxItems3` service item template from the manually-entered fields on this
	/// service record (name, description, notes, vendor, labor, parts, custom field), so the
	/// item becomes available for future records via the "Database Item" picker.
	private func saveManualItemAsServiceItem() {
		let name = trimmed(mxName)
		guard !name.isEmpty, !serviceItemExists(name) else { return }
		let vId = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId

		let newItem = MxItems3(
			createdAt: Date(),
			updatedAt: Date(),
			vehicleId: vId,
			vehicleSystem: "",
			mxName: name,
			mxDescription: mxDescription,
			Notes: Notes,
			vendor: vendor,
			laborCost: laborCost,
			intervalMonths: 0,
			intervalMiles: 0,
			intervalHours: 0,
			part1: part1, part1Id: part1, part1Qty: Float(part1Quantity), part1cost: part1cost, part1Unit: part1Unit,
			part2: part2, part2Id: part2, part2Qty: Float(part2Quantity), part2cost: part2cost, part2Unit: part2Unit,
			part3: part3, part3Id: part3, part3Qty: Float(part3Quantity), part3cost: part3cost, part3Unit: part3Unit,
			part4: part4, part4Id: part4, part4Qty: Float(part4Quantity), part4cost: part4cost, part4Unit: part4Unit,
			part5: part5, part5Id: part5, part5Qty: Float(part5Quantity), part5cost: part5cost, part5Unit: part5Unit,
			customMeasureLabel: customMeasureLabel,
			customMeasureUnit: customMeasureUnit,
			customMeasureValue: customMeasureValue,
			image1: image1, image1Description: image1Description,
			image2: image2, image2Description: image2Description,
			image3: image3, image3Description: image3Description
		)
		modelContext.insert(newItem)

		// Link this record to the newly created template, same as picking it from Database Item.
		mxName = name
		mxItemId = name
		dataSet.mxItemId = name

		do {
			try modelContext.save()
		} catch {
			print("Failed to save new service item: \(error.localizedDescription)")
		}
	}

	// Helper to read the current part name from the record for seeding ModelPicker.
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

	// Recomputes all totals, statistics, deltas, and due intervals.
	// This is called whenever relevant inputs change (miles, hours, labor, parts, selections).
	private func recomputeTotals() {
		// Costs per part line and subtotals
		trackPartsCost1 = Double(part1Quantity) * Double(part1cost)
		trackPartsCost2 = Double(part2Quantity) * Double(part2cost)
		trackPartsCost3 = Double(part3Quantity) * Double(part3cost)
		trackPartsCost4 = Double(part4Quantity) * Double(part4cost)
		trackPartsCost5 = Double(part5Quantity) * Double(part5cost)
		trackPartsCostTotal = trackPartsCost1 + trackPartsCost2 + trackPartsCost3 + trackPartsCost4 + trackPartsCost5
		trackSubItemsLaborTotal = Double(subItem1LaborCost) + Double(subItem2LaborCost) + Double(subItem3LaborCost) + Double(subItem4LaborCost) + Double(subItem5LaborCost)
		trackAllCostTotal = trackPartsCostTotal + Double(laborCost) + trackSubItemsLaborTotal

		// Lines and quantities
		let line1 = (!part1.isEmpty && part1Quantity > 0) ? 1 : 0
		let line2 = (!part2.isEmpty && part2Quantity > 0) ? 1 : 0
		let line3 = (!part3.isEmpty && part3Quantity > 0) ? 1 : 0
		let line4 = (!part4.isEmpty && part4Quantity > 0) ? 1 : 0
		let line5 = (!part5.isEmpty && part5Quantity > 0) ? 1 : 0
		partsLinesCount = line1 + line2 + line3 + line4 + line5

		totalPartsQuantity = max(0, part1Quantity) + max(0, part2Quantity) + max(0, part3Quantity) + max(0, part4Quantity) + max(0, part5Quantity)

		if totalPartsQuantity > 0 {
			avgCostPerPartUnit = trackPartsCostTotal / Double(totalPartsQuantity)
		} else {
			avgCostPerPartUnit = 0.0
		}

		// Choose bases: prefer local edits if present; otherwise fall back to model values
		let milesBase = Miles > 0 ? Miles : dataSet.Miles
		let hoursBase = engHours > 0 ? engHours : dataSet.engHours

		// Cost per mile and per engine hour
		if milesBase > 0 {
			costPerMile = trackAllCostTotal / Double(milesBase)
		} else {
			costPerMile = 0.0
		}

		if hoursBase > 0 {
			costPerEngineHour = trackAllCostTotal / Double(hoursBase)
		} else {
			costPerEngineHour = 0.0
		}

		// Vehicle deltas (since the service)
		let currentMiles = vehicleCurrentMiles
		let currentHours = vehicleCurrentEngHours
		milesSinceService = max(0, currentMiles - milesBase)
		hoursSinceService = max(0, currentHours - hoursBase)

		// Remaining to due (based on intervals)
		if itemIntervalMiles > 0 {
			milesRemainingToDue = max(0, itemIntervalMiles - milesSinceService)
		} else {
			milesRemainingToDue = 0
		}
		if itemIntervalHours > 0 {
			hoursRemainingToDue = max(0, itemIntervalHours - hoursSinceService)
		} else {
			hoursRemainingToDue = 0
		}
		// Time interval: compute next due date by adding months to mxDate, and days remaining from now.
		if itemIntervalMonths > 0 {
			if let due = Calendar(identifier: .gregorian).date(byAdding: .month, value: itemIntervalMonths, to: mxDate) {
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

	// Loads distinct category/subcategory values from all Additions records.
	private func loadAdditionsCategories() {
		if let results = try? modelContext.fetch(FetchDescriptor<Additions>()) {
			let cats = results.filter { !$0.category.isEmpty }.map { $0.category }
			allAdditionsCategories = Array(Set(cats)).sorted()
			let subs = results.filter { !$0.subCategory.isEmpty }.map { $0.subCategory }
			allAdditionsSubCategories = Array(Set(subs)).sorted()
		}
	}

	// Reads category/subcategory from the linked Additions record into local state.
	private func loadAdditionsLinkState() {
		let lid = additionsLinkId
		guard !lid.isEmpty else { return }
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		if let additions = try? modelContext.fetch(fd), !additions.isEmpty {
			transferCategory = additions[0].category
			transferSubCategory = additions[0].subCategory
			linkedAdditionsCount = additions.count
		}
	}

	// Builds the list of line items (label + cost) that will be transferred to Additions.
	private func buildTransferLineItems() -> [(name: String, cost: Float)] {
		var items: [(name: String, cost: Float)] = []
		if laborCost > 0 {
			items.append((name: "Labor", cost: laborCost))
		}
		let parts: [(String, Float, Int)] = [
			(part1, part1cost, part1Quantity),
			(part2, part2cost, part2Quantity),
			(part3, part3cost, part3Quantity),
			(part4, part4cost, part4Quantity),
			(part5, part5cost, part5Quantity),
		]
		for (name, cost, qty) in parts where !name.isEmpty {
			items.append((name: name, cost: Float(Double(qty) * Double(cost))))
		}
		let subItems: [(String, Float)] = [
			(subItem1, subItem1LaborCost), (subItem2, subItem2LaborCost), (subItem3, subItem3LaborCost),
			(subItem4, subItem4LaborCost), (subItem5, subItem5LaborCost),
		]
		for (name, cost) in subItems where !name.isEmpty && cost > 0 {
			items.append((name: name, cost: cost))
		}
		return items
	}

	// Creates individual Additions records (one per part + one for labor) linked to this service record.
	private func transferToAdditions(category: String, subCategory: String) {
		let parts: [(String, Float, Int)] = [
			(part1, part1cost, part1Quantity),
			(part2, part2cost, part2Quantity),
			(part3, part3cost, part3Quantity),
			(part4, part4cost, part4Quantity),
			(part5, part5cost, part5Quantity),
		]
		let subItems: [(String, Float)] = [
			(subItem1, subItem1LaborCost), (subItem2, subItem2LaborCost), (subItem3, subItem3LaborCost),
			(subItem4, subItem4LaborCost), (subItem5, subItem5LaborCost),
		]
		let willCreate = (laborCost > 0 ? 1 : 0) + parts.filter { !$0.0.isEmpty }.count
			+ subItems.filter { !$0.0.isEmpty && $0.1 > 0 }.count
		guard willCreate > 0 else { return }
		guard entitlements.requestCreate(Additions.self, count: willCreate, in: modelContext) else { return }

		let linkId = UUID().uuidString
		let vId = vehicleId.isEmpty ? dataSet.vehicleId : vehicleId
		let serviceName = mxName.isEmpty ? dataSet.mxName : mxName
		let vend = vendor.isEmpty ? dataSet.vendor : vendor
		var count = 0
		// Labor entry
		if laborCost > 0 {
			let entry = Additions(
				vehicleId: vId, miles: Miles, engHours: engHours,
				itemName: "Labor", itemDescription: serviceName,
				itemVendor: vend, category: category,
				subCategory: subCategory, itemCost: laborCost
			)
			entry.serviceRecordLinkId = linkId
			modelContext.insert(entry)
			count += 1
		}
		// Part entries
		for (pName, pCost, pQty) in parts where !pName.isEmpty {
			let entry = Additions(
				vehicleId: vId, miles: Miles, engHours: engHours,
				itemName: pName, itemDescription: serviceName,
				itemVendor: vend, category: category,
				subCategory: subCategory,
				itemCost: Float(Double(pQty) * Double(pCost))
			)
			entry.serviceRecordLinkId = linkId
			modelContext.insert(entry)
			count += 1
		}
		// Sub-item labor entries
		for (siName, siCost) in subItems where !siName.isEmpty && siCost > 0 {
			let entry = Additions(
				vehicleId: vId, miles: Miles, engHours: engHours,
				itemName: siName, itemDescription: serviceName,
				itemVendor: vend, category: category,
				subCategory: subCategory, itemCost: siCost
			)
			entry.serviceRecordLinkId = linkId
			modelContext.insert(entry)
			count += 1
		}
		dataSet.additionsLinkId = linkId
		additionsLinkId = linkId
		transferCategory = category
		transferSubCategory = subCategory
		linkedAdditionsCount = count
		try? modelContext.save()
	}

	// Removes the link between this service record and ALL its linked Additions entries.
	private func unlinkFromAdditions() {
		let lid = additionsLinkId
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		if let additions = try? modelContext.fetch(fd) {
			for addition in additions { addition.serviceRecordLinkId = "" }
		}
		dataSet.additionsLinkId = ""
		additionsLinkId = ""
		transferCategory = ""
		transferSubCategory = ""
		linkedAdditionsCount = 0
		try? modelContext.save()
	}

	// Syncs costs on all linked Additions records by matching their itemName to current parts/labor.
	private func syncLinkedAddition() {
		let lid = additionsLinkId
		guard !lid.isEmpty else { return }
		let fd = FetchDescriptor<Additions>(predicate: #Predicate { $0.serviceRecordLinkId == lid })
		guard let additions = try? modelContext.fetch(fd), !additions.isEmpty else { return }
		let serviceName = mxName.isEmpty ? dataSet.mxName : mxName
		let vend = vendor.isEmpty ? dataSet.vendor : vendor
		for addition in additions {
			addition.itemDescription = serviceName
			addition.itemVendor = vend
			addition.updatedAt = Date()
			if addition.itemName == "Labor" {
				addition.itemCost = laborCost
			} else if addition.itemName == part1 {
				addition.itemCost = Float(Double(part1Quantity) * Double(part1cost))
			} else if addition.itemName == part2 {
				addition.itemCost = Float(Double(part2Quantity) * Double(part2cost))
			} else if addition.itemName == part3 {
				addition.itemCost = Float(Double(part3Quantity) * Double(part3cost))
			} else if addition.itemName == part4 {
				addition.itemCost = Float(Double(part4Quantity) * Double(part4cost))
			} else if addition.itemName == part5 {
				addition.itemCost = Float(Double(part5Quantity) * Double(part5cost))
			} else if addition.itemName == subItem1 {
				addition.itemCost = subItem1LaborCost
			} else if addition.itemName == subItem2 {
				addition.itemCost = subItem2LaborCost
			} else if addition.itemName == subItem3 {
				addition.itemCost = subItem3LaborCost
			} else if addition.itemName == subItem4 {
				addition.itemCost = subItem4LaborCost
			} else if addition.itemName == subItem5 {
				addition.itemCost = subItem5LaborCost
			}
		}
		try? modelContext.save()
		transferCategory = additions[0].category
		transferSubCategory = additions[0].subCategory
		linkedAdditionsCount = additions.count
	}

	// MARK: - Inventory tracking

	/// Fetches the `MxParts1` record matching `name`, if any.
	private func fetchPart(named name: String) -> MxParts1? {
		guard !name.isEmpty else { return nil }
		var fd = FetchDescriptor<MxParts1>(predicate: #Predicate<MxParts1> { $0.partName == name })
		fd.fetchLimit = 1
		return try? modelContext.fetch(fd).first
	}

	/// Adjusts the named part's on-hand inventory by `-delta` (a positive delta consumes more
	/// stock, a negative delta returns stock). No-ops for parts that aren't inventory-tracked
	/// or can't be matched by name.
	private func adjustInventory(partNamed name: String, byDelta delta: Int) {
		guard delta != 0, let part = fetchPart(named: name), part.inventoryTracked else { return }
		part.inventoryQuantityOnHand -= Float(delta)
		part.updatedAt = Date()
	}

	/// Reconciles inventory for all five part slots between what this record previously consumed
	/// and what's about to be saved. A slot whose part name changed returns the old part's stock
	/// in full and consumes the new part's stock in full, rather than diffing across two parts.
	private func reconcilePartsInventory(
		old: [(name: String, qty: Int)],
		new: [(name: String, qty: Int)]
	) {
		for i in 0..<old.count {
			let oldName = old[i].name, oldQty = old[i].qty
			let newName = new[i].name, newQty = new[i].qty
			if oldName == newName {
				adjustInventory(partNamed: oldName, byDelta: newQty - oldQty)
			} else {
				adjustInventory(partNamed: oldName, byDelta: -oldQty)
				adjustInventory(partNamed: newName, byDelta: newQty)
			}
		}
	}

	/// Returns all inventory this record currently has consumed. Called before deleting the
	/// record so removing it doesn't permanently understate stock on hand.
	private func releaseAllPartsInventory() {
		let parts: [(name: String, qty: Int)] = [
			(dataSet.part1, dataSet.part1Quantity),
			(dataSet.part2, dataSet.part2Quantity),
			(dataSet.part3, dataSet.part3Quantity),
			(dataSet.part4, dataSet.part4Quantity),
			(dataSet.part5, dataSet.part5Quantity),
		]
		for p in parts { adjustInventory(partNamed: p.name, byDelta: -p.qty) }
	}
}

// MARK: - Normalization helpers
private extension EditRecord {
	/// Trims leading and trailing whitespace/newlines from the provided string.
	func trimmed(_ s: String) -> String {
		s.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

// Sheet presented when transferring a service record's costs to the Additions module.
private struct AdditionsTransferSheet: View {
	let existingCategories: [String]
	let existingSubCategories: [String]
	let lineItems: [(name: String, cost: Float)]
	let onTransfer: (String, String) -> Void

	@Environment(\.dismiss) private var dismiss
	@State private var selectedCategory: String = ""
	@State private var newCategoryName: String = ""
	@State private var useNewCategory: Bool = false
	@State private var selectedSubCategory: String = ""
	@State private var newSubCategoryName: String = ""
	@State private var useNewSubCategory: Bool = false

	var chosenCategory: String { useNewCategory ? newCategoryName : selectedCategory }
	var chosenSubCategory: String { (useNewSubCategory || existingSubCategories.isEmpty) ? newSubCategoryName : selectedSubCategory }
	var canTransfer: Bool { !chosenCategory.trimmingCharacters(in: .whitespaces).isEmpty }
	var totalCost: Float { lineItems.reduce(0) { $0 + $1.cost } }

	var body: some View {
		NavigationStack {
			Form {
				Section("Items to Transfer") {
					ForEach(lineItems, id: \.name) { item in
						LabeledContent(item.name) {
							Text(item.cost, format: .currency(code: "USD"))
						}
					}
					LabeledContent("Total") {
						Text(totalCost, format: .currency(code: "USD"))
							.bold()
					}
				}
				Section("Category") {
					if !existingCategories.isEmpty {
						Toggle("Use Existing Category", isOn: Binding(
							get: { !useNewCategory },
							set: { useNewCategory = !$0 }
						))
					}
					if !useNewCategory && !existingCategories.isEmpty {
						Picker("Category", selection: $selectedCategory) {
							Text("— Select —").tag("")
							ForEach(existingCategories, id: \.self) { cat in
								Text(cat).tag(cat)
							}
						}
					} else {
						TextField("New Category Name", text: $newCategoryName)
					}
				}
				Section("Sub-Category (optional)") {
					if !existingSubCategories.isEmpty {
						Toggle("Use Existing Sub-Category", isOn: Binding(
							get: { !useNewSubCategory },
							set: { useNewSubCategory = !$0 }
						))
					}
					if !useNewSubCategory && !existingSubCategories.isEmpty {
						Picker("Sub-Category", selection: $selectedSubCategory) {
							Text("— None —").tag("")
							ForEach(existingSubCategories, id: \.self) { sub in
								Text(sub).tag(sub)
							}
						}
					} else {
						TextField("New Sub-Category Name", text: $newSubCategoryName)
					}
				}
			}
			.navigationTitle("Transfer to Additions")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Transfer") {
						onTransfer(chosenCategory.trimmingCharacters(in: .whitespaces), chosenSubCategory)
						dismiss()
					}
					.disabled(!canTransfer)
				}
			}
			.onAppear {
				// Default to new category if no existing ones
				if existingCategories.isEmpty { useNewCategory = true }
			}
		}
	}
}

#Preview("EditRecord - Populated Sample") {
	// In-memory container to preview a fully populated record
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				 ServiceRecords1.self,
				 MxItems3.self,
				 MxParts1.self,
				 Vendors1.self,
				 Settings1.self,
				 Additions.self,
				 configurations: config
	)

	// Seed a vehicle (useful if you toggle into Edit mode and use pickers)
	let vehicle = Vehicle8(name: "Preview Vehicle", year: 2022, mileage: 42000, engHours: 123.4, fuelType: "Gasoline")
	container.mainContext.insert(vehicle)

	// Seed a service item template to provide intervals
	let item = MxItems3(
		createdAt: Date(), updatedAt: Date(),
		vehicleId: vehicle.name, vehicleSystem: "Engine",
		mxName: "Oil and Filter Change",
		mxDescription: "Change oil and filter",
		Notes: "", vendor: "Local Auto Shop",
		laborCost: 95.0,
		intervalMonths: 6, intervalMiles: 5000, intervalHours: 200.0,
		part1: "Engine Oil", part1Id: "", part1Qty: 6, part1cost: 8.99, part1Unit: "qt",
		part2: "Oil Filter", part2Id: "", part2Qty: 1, part2cost: 12.49, part2Unit: "Each",
		part3: "", part3Id: "", part3Qty: 0, part3cost: 0, part3Unit: "",
		part4: "", part4Id: "", part4Qty: 0, part4cost: 0, part4Unit: "",
		part5: "", part5Id: "", part5Qty: 0, part5cost: 0, part5Unit: ""
	)
	container.mainContext.insert(item)

	// Seed a populated service record
	let record = ServiceRecords1(
		createdAt: Date().addingTimeInterval(-86400 * 10),
		updatedAt: Date().addingTimeInterval(-86400 * 1),
		mxDate: Date().addingTimeInterval(-86400 * 60),
		vehicleId: vehicle.name,
		Miles: 38000,
		engHours: 100.0,
		mxName: "Oil and Filter Change",
		mxItemId: "Oil and Filter Change",
		mxDescription: "Changed engine oil and filter",
		Notes: "Used full synthetic",
		vendor: "Local Auto Shop",
		laborCost: 95.0,
		part1: "Engine Oil",
		part1cost: 8.99,
		part1Unit: "qt",
		part1Quantity: 6,
		part2: "Oil Filter",
		part2cost: 12.49,
		part2Unit: "Each",
		part2Quantity: 1,
		part3: "",
		part3cost: 0,
		part3Unit: "",
		part3Quantity: 0,
		part4: "",
		part4cost: 0,
		part4Unit: "",
		part4Quantity: 0,
		part5: "",
		part5cost: 0,
		part5Unit: "",
		part5Quantity: 0
	)
	container.mainContext.insert(record)

	return NavigationStack {
		EditRecord(serviceRecords1: record)
	}
	.modelContainer(container)
}

#Preview("EditRecord - Empty Sample") {
	// In-memory container to preview a mostly empty/new record
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				 ServiceRecords1.self,
				 MxItems3.self,
				 MxParts1.self,
				 Vendors1.self,
				 Settings1.self,
				 Additions.self,
				 configurations: config
	)

	// Minimal vehicle (optional, helps if you toggle to Edit)
	let vehicle = Vehicle8(name: "Blank Vehicle", year: 2024)
	container.mainContext.insert(vehicle)

	// Blank/new service record (uses defaults)
	let record = ServiceRecords1(
		mxDate: Date(),
		vehicleId: vehicle.name
	)
	container.mainContext.insert(record)

	return NavigationStack {
		EditRecord(serviceRecords1: record)
	}
	.modelContainer(container)
}

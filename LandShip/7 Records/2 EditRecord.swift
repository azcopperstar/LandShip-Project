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

	// Up to 5 parts per record, each with name, cost, unit, quantity.
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
		self._image1 = State.init(initialValue: dataSet.image1)
		self._image2 = State.init(initialValue: dataSet.image2)
		self._image3 = State.init(initialValue: dataSet.image3)
		self._image1Description = State.init(initialValue: dataSet.image1Description)
		self._image2Description = State.init(initialValue: dataSet.image2Description)
		self._image3Description = State.init(initialValue: dataSet.image3Description)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
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
							Text("Vehicle")
								.textLabelModified()

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
							
						// Generic ModelPicker for MxItems3 filtered by the chosen vehicle.
							// IMPORTANT: Avoid capturing dataSet directly inside #Predicate.
							let currentVehicle = vehicleId
							let itemsFilter: Predicate<MxItems3>? = currentVehicle.isEmpty
							? nil
							: #Predicate<MxItems3> { $0.vehicleId == currentVehicle }
							LabeledContent {
								ModelPicker(
									selection: $selectedServiceItem,
									title: "Database Item",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: itemsFilter,
									sort: [SortDescriptor(\.mxName, order: .forward)],
									labelProvider: { $0.mxName }
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
									// Also sync the five parts ModelPicker selections to match the new item
									syncPartSelectionsFromNames(
										p1: part1, p2: part2, p3: part3, p4: part4, p5: part5
									)
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
						HStack{LabelDataTextview(label: "Description", data: $mxDescription)}
						HStack{LabelDataTextview(label: "Notes", data: $Notes)}

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
						HStack{LabelDataTextview_Numberpad_Int(label: "Miles (\(unit(UnitIndex.distance)))", data: $Miles)}
							.onChange(of: Miles) { _, _ in recomputeTotals() }
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
							.onChange(of: engHours) { _, _ in recomputeTotals() }
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
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part1Unit))", data: $part1Quantity)}
							.onChange(of: part1Quantity) { _, _ in recomputeTotals() }
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
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part2Unit))", data: $part2Quantity)}
								.onChange(of: part2Quantity) { _, _ in recomputeTotals() }
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
							HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part3Unit))", data: $part3Quantity)}
								.onChange(of: part3Quantity) { _, _ in recomputeTotals() }
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

				// STATISTICS (computed values and aggregates)
				CardView {
					VStack {
						SectionText(label: "STATISTICS")
						HStack{LabelDataCurrency(label: "Parts Subtotal", data: Float(trackPartsCostTotal), unit: "")}
						HStack{LabelDataCurrency(label: "Labor", data: laborCost, unit: "")}
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
						SectionText(label: "SERVICE ITEM & VEHICLE STATS")
						// Vehicle
						HStack{LabelDataText(label: "Vehicle", data: vehicleId)}
						if vehicleCurrentMiles > 0 {
							HStack{LabelDataText(label: "Current Odometer", data: "\(vehicleCurrentMiles) \(unit(UnitIndex.distance))")}
						}
						if vehicleCurrentEngHours > 0 {
							HStack{LabelDataNumber(label: "Current Engine Hours", data: vehicleCurrentEngHours, fractionalLength: 1)}
						}
						if Miles > 0 && vehicleCurrentMiles >= Miles {
							HStack{LabelDataText(label: "Miles Since Service", data: "\(milesSinceService) \(unit(UnitIndex.distance))")}
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
					dbRecord: "service record")
			}

			.onAppear {
				// Load display units (e.g., miles vs km), vehicle stats, and intervals.
				// Seed pickers from existing model values.
				loadUnits()
				refreshVehicleDetails()
				loadItemIntervalsIfNeeded()
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
			}
			.toolbar {
				// Edit mode toolbar: label, Cancel toggle, Save
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						// Tapping Save writes all local state back into dataSet and persists it.
						isEditing.toggle()
						updateItem()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
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
						HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
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
				
				// SERVICE COMPLETED AT
				CardView {
					VStack {
						SectionText(label: "SERVICE COMPLETED AT")
						if dataSet.Miles > 0 {
							HStack{LabelDataText(label: "Miles", data: "\(dataSet.Miles) \(unit(UnitIndex.distance))")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours", data: Float(dataSet.engHours), fractionalLength: 1)}
						}
					}
				}
				
				// PARTS USED (read-only summary)
				CardView {
					VStack {
						SectionText(label: "PARTS USED")
						if dataSet.part1 != "" {
							HStack{LabelDataText(label: "Part Name", data: "\(part1)")}
							HStack{LabelDataText(label: "Quantity", data: "\(part1Quantity) \(part1Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part1cost), unit: "/ \(part1Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part1Quantity) * Double(part1cost)), unit: "")}
						}
						if dataSet.part2 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part2)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part2Quantity) \(dataSet.part2Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part2cost), unit: "/ \(part2Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part2Quantity) * Double(part2cost)), unit: "")}
						}
						if dataSet.part3 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part3)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part3Quantity) \(dataSet.part3Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part3cost), unit: "/ \(part3Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part3Quantity) * Double(part3cost)), unit: "")}
						}
						if dataSet.part4 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part4)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part4Quantity) \(dataSet.part4Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part4cost), unit: "/ \(part4Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part4Quantity) * Double(part4cost)), unit: "")}
						}
						if dataSet.part5 != "" {
							Divider()
							HStack{LabelDataText(label: "Part Name", data: "\(dataSet.part5)")}
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.part5Quantity) \(dataSet.part5Unit)")}
							HStack{LabelDataCurrency(label: "Cost/Unit", data: Float(part5cost), unit: "/ \(part5Unit)")}
							HStack{LabelDataCurrency(label: "Part Total", data: Float(Double(part5Quantity) * Double(part5cost)), unit: "")}
						}
					}
				}
				
				// COSTS (read-only)
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataCurrency(label: "Labor", data: Float(laborCost), unit: "")}
						HStack{LabelDataCurrency(label: "Parts", data: Float(trackPartsCostTotal), unit: "")}
						Divider()
						HStack{LabelDataCurrency(label: "Total Costs", data: Float(trackAllCostTotal), unit: "")}
							.foregroundColor(.red)
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
						SectionText(label: "VEHICLE STATS")
						HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
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
				
				// SERVICE RECORDS GRAPHICS (read-only images)
				CardView {
					VStack {
						SectionText(label: "SERVICE RECORDS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}

			}//end of details scroll view
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "service record")
			}

			.onAppear {
				// Keep derived values up-to-date when entering details mode
				loadUnits()
				refreshVehicleDetails()
				loadItemIntervalsIfNeeded()
				recomputeTotals()
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
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

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
		trackAllCostTotal = trackPartsCostTotal + Double(laborCost)

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
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
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

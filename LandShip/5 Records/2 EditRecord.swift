//
//  EditMxRecord.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import SwiftUI
import SwiftData

struct EditRecord: View {
	@State private var dataSet: ServiceRecords1
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	// Access settings (units) once
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		units.indices.contains(index) ? units[index] : ""
	}

	@State private var isPresentingConfirm: Bool = false /// for confirmation dialog
	@State private var isEditing: Bool = false
	
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
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	@State private var trackPartsCost1: Double = 0.0
	@State private var trackPartsCost2: Double = 0.0
	@State private var trackPartsCost3: Double = 0.0
	@State private var trackPartsCost4: Double = 0.0
	@State private var trackPartsCost5: Double = 0.0
	@State private var trackPartsCostTotal: Double = 0.0
	@State private var trackAllCostTotal: Double = 0.0

	init(serviceRecords1: ServiceRecords1) {
		self.dataSet = serviceRecords1
		vehicleId = dataSet.vehicleId

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
	}
	
	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{
							Text("Vehicle")
								.textLabelModified()
							VehiclePickerRecords(RequestingData:$dataSet)
								.onChange(of: dataSet.vehicleId) { _, _ in
									vehicleId = dataSet.vehicleId
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataPicker_Date(label: "Service Date", data: $mxDate)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{
							Text("Database Item")
								.textLabelModified()
							ItemsPickerRecords(RequestingData:$dataSet)
								.onChange(of: dataSet.mxItemId) { _, _ in
									mxItemId = dataSet.mxItemId
									mxName = dataSet.mxItemId
									// fetch selected mxItems and transfer applicable fields to serviceRecords
									var fetchDescriptor = FetchDescriptor<MxItems3>(
										predicate: #Predicate { $0.mxName == mxName }
									)
									fetchDescriptor.fetchLimit = 1
									do {
										if let mxItems = try modelContext.fetch(fetchDescriptor).first {
											mxName = mxItems.mxName
											mxDescription = mxItems.mxDescription
											Notes = mxItems.Notes
											vendor = mxItems.vendor
											laborCost = mxItems.laborCost
											part1 = mxItems.part1
											part1cost = mxItems.part1cost
											part1Quantity = Int(mxItems.part1Qty)
											part2 = mxItems.part2
											part2cost = mxItems.part2cost
											part2Quantity = Int(mxItems.part2Qty)
											part3 = mxItems.part3
											part3cost = mxItems.part3cost
											part3Quantity = Int(mxItems.part3Qty)
											part4 = mxItems.part4
											part4cost = mxItems.part4cost
											part4Quantity = Int(mxItems.part4Qty)
											part5 = mxItems.part5
											part5cost = mxItems.part5cost
											part5Quantity = Int(mxItems.part5Qty)
											recomputeTotals()
										}
									} catch {
										print("Failed to load items: \(error.localizedDescription)")
									}
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Manual Item", data: $mxName)}
						HStack{LabelDataTextview(label: "Description", data: $mxDescription)}
						HStack{LabelDataTextview(label: "Notes", data: $Notes)}
						HStack{
							Text("Vendor")
								.textLabelModified()
							VendorPickerRecords(RequestingData:$dataSet)
								.onChange(of: dataSet.vendor) { _, _ in
									vendor = dataSet.vendor
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "SERVICE COMPLETED AT")
						HStack{LabelDataTextview_Numberpad_Int(label: "Miles (\(unit(UnitIndex.distance)))", data: $Miles)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART 1")
						HStack{
							Text("Database Entry")
								.textLabelModified()
							Part1PickerRecords(RequestingData:$dataSet)
								.onAppear { part1 = dataSet.part1 }
								.frame(maxWidth: .infinity, alignment: .trailing)
								.onChange(of: dataSet.part1) { _, _ in
									part1 = dataSet.part1
									var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part1 })
									fd.fetchLimit = 1
									do {
										if let fetchModel = try modelContext.fetch(fd).first {
											part1cost = Float(fetchModel.costPerUnit)
											part1Unit = fetchModel.partUnit
											part1Quantity = fetchModel.partQuantity
										} else {
											part1cost = 0
											part1Unit = ""
											part1Quantity = 0
										}
										recomputeTotals()
									} catch {}
								}
						}
						HStack{LabelDataTextview(label: "Manual Entry", data: $part1)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(part1Unit))", data: $part1Quantity)}
							.onChange(of: part1Quantity) { _, _ in recomputeTotals() }
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part1cost)}
							.onChange(of: part1cost) { _, _ in recomputeTotals() }
						Picker_PartsUnit(label: "Unit", data: $part1Unit)
						HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(Double(part1Quantity) * Double(part1cost)), unit: "")}
					}
				}
				
				if part2 != "" || part1 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 2")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								Part2PickerRecords(RequestingData:$dataSet)
									.onAppear { part2 = dataSet.part2 }
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part2) { _, _ in
										part2 = dataSet.part2
										var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part2 })
										fd.fetchLimit = 1
										do {
											if let fetchModel = try modelContext.fetch(fd).first {
												part2cost = Float(fetchModel.costPerUnit)
												part2Unit = fetchModel.partUnit
												part2Quantity = fetchModel.partQuantity
											} else {
												part2cost = 0
												part2Unit = ""
												part2Quantity = 0
											}
											recomputeTotals()
										} catch {}
									}
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

				if part3 != "" || part2 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 3")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								Part3PickerRecords(RequestingData:$dataSet)
									.onAppear { part3 = dataSet.part3 }
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part3) { _, _ in
										part3 = dataSet.part3
										var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part3 })
										fd.fetchLimit = 1
										do {
											if let fetchModel = try modelContext.fetch(fd).first {
												part3cost = Float(fetchModel.costPerUnit)
												part3Unit = fetchModel.partUnit
												part3Quantity = fetchModel.partQuantity
											} else {
												part3cost = 0
												part3Unit = ""
												part3Quantity = 0
											}
											recomputeTotals()
										} catch {}
									}
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
				
				if part4 != "" || part3 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 4")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								Part4PickerRecords(RequestingData:$dataSet)
									.onAppear { part4 = dataSet.part4 }
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part4) { _, _ in
										part4 = dataSet.part4
										var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part4 })
										fd.fetchLimit = 1
										do {
											if let fetchModel = try modelContext.fetch(fd).first {
												part4cost = Float(fetchModel.costPerUnit)
												part4Unit = fetchModel.partUnit
												part4Quantity = fetchModel.partQuantity
											} else {
												part4cost = 0
												part4Unit = ""
												part4Quantity = 0
											}
											recomputeTotals()
										} catch {}
									}
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
				
				if part5 != "" || part4 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 5")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								Part5PickerRecords(RequestingData:$dataSet)
									.onAppear { part5 = dataSet.part5 }
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part5) { _, _ in
										part5 = dataSet.part5
										var fd = FetchDescriptor<MxParts1>(predicate: #Predicate { $0.partName == part5 })
										fd.fetchLimit = 1
										do {
											if let fetchModel = try modelContext.fetch(fd).first {
												part5cost = Float(fetchModel.costPerUnit)
												part5Unit = fetchModel.partUnit
												part5Quantity = fetchModel.partQuantity
											} else {
												part5cost = 0
												part5Unit = ""
												part5Quantity = 0
											}
											recomputeTotals()
										} catch {}
									}
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
				
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $laborCost)}
							.onChange(of: laborCost) { _, _ in recomputeTotals() }
					}
				}
				
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

			}// end of form

			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.onAppear {
				loadUnits()
				recomputeTotals()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "EDIT")
				}
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "  Cancel  " : "  Edit  ") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("  Save  ") {
						isEditing.toggle()
						updateItem()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}

		} else {

			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle", data: functions.cleanOptional(inputString: dataSet.vehicleId))}
						HStack{LabelDataText(label: "Service Date", data: "\(functions.formatDate_DDMMMyy(date:dataSet.mxDate))")}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataText(label: "Service Item", data: "\(dataSet.mxName)")}
						if dataSet.mxDescription != "" {
							HStack{LabelDataText(label: "Description", data: "\(dataSet.mxDescription)")}
						}
						if dataSet.Notes != "" {
							HStack{LabelDataText(label: "Notes", data: "\(dataSet.Notes)")}
						}
						if dataSet.vendor != "" {
							HStack{LabelDataText(label: "Shop", data: "\(dataSet.vendor)")}
						}
					}
				}
				
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
				
				CardView {
					VStack {
						SectionText(label: "SERVICE RECORDS GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}

			}//end of list
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.onAppear {
				loadUnits()
				recomputeTotals()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "DETAILS")
				}
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "  Cancel  " : "  Edit  ") {
						isEditing.toggle()
					}
					.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("  Delete  ", role: .destructive) {
						isPresentingConfirm = true
					}
					.confirmationDialog("Confirm action", isPresented: $isPresentingConfirm) {
						Button("Delete record?", role: .destructive) {
							DeleteRecord()
						}
					} message: {
						Text("Confirm deletion of this service record...")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}

	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}

	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
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

		// update the record
		do {
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}

		// update the vehicle odometer record with the service record odometer if greater
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
	}

	// MARK: - Helpers
	private func loadUnits() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}
	private func recomputeTotals() {
		trackPartsCost1 = Double(part1Quantity) * Double(part1cost)
		trackPartsCost2 = Double(part2Quantity) * Double(part2cost)
		trackPartsCost3 = Double(part3Quantity) * Double(part3cost)
		trackPartsCost4 = Double(part4Quantity) * Double(part4cost)
		trackPartsCost5 = Double(part5Quantity) * Double(part5cost)
		trackPartsCostTotal = trackPartsCost1 + trackPartsCost2 + trackPartsCost3 + trackPartsCost4 + trackPartsCost5
		trackAllCostTotal = trackPartsCostTotal + Double(laborCost)
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, ServiceRecords1.self, MxItems3.self, MxParts1.self, Vendors1.self, configurations: config)
	return ContentView()
	.modelContainer(container)
}

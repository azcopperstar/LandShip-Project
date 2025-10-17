//
//  EditItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct EditItems: View {
	@State private var dataSet: MxItems3
	
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	@State private var isPresentingConfirm: Bool = false

	@State private var isEditing: Bool = false
	
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

	// Reactive totals (computed)
	private var part1Total: Double { Double(part1Qty) * Double(part1cost) }
	private var part2Total: Double { Double(part2Qty) * Double(part2cost) }
	private var part3Total: Double { Double(part3Qty) * Double(part3cost) }
	private var part4Total: Double { Double(part4Qty) * Double(part4cost) }
	private var part5Total: Double { Double(part5Qty) * Double(part5cost) }
	private var partsTotal: Double { part1Total + part2Total + part3Total + part4Total + part5Total }
	private var grandTotal: Double { partsTotal + Double(laborCost) }
	
	init(mxItems: MxItems3) {
		self.dataSet = mxItems
		
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
							VehiclePickerItems(RequestingData:$dataSet)
								.onChange(of: dataSet.vehicleId) { _, _ in
									vehicleId = dataSet.vehicleId
								}
						}
						.frame(maxWidth: .infinity, alignment: .trailing)
						
						HStack{
							Text("Vehicle System")
								.textLabelModified()
							SystemsPickerItems(mxItems:$dataSet)
								.onChange(of: dataSet.vehicleSystem) { _, _ in
									vehicleSystem = dataSet.vehicleSystem
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataTextview(label: "Item Name", data: $mxName)}
						HStack{LabelDataTextview(label: "Item Description", data: $mxDescription)}
						HStack{LabelDataTextview(label: "Item Notes", data: $Notes)}
						HStack{
							Text("Shop")
								.textLabelModified()
							VendorPickerItems(RequestingData:$dataSet)
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
						HStack{LabelDataTextview_Numberpad_Int(label: "Interval Months", data: $intervalMonths)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Interval Miles", data: $intervalMiles)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Interval Hours", data: $intervalHours)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "PART 1")
						HStack{
							Text("Database Entry")
								.textLabelModified()
							Part1PickerItems(RequestingData:$dataSet)
								.onAppear {
									part1 = dataSet.part1
									part1Id = dataSet.part1Id
									part1Qty = dataSet.part1Qty
									part1cost = Float(dataSet.part1cost)
									part1Unit = dataSet.part1Unit
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
								.onChange(of: dataSet.part1) { _, _ in
									part1 = dataSet.part1
									part1Id = dataSet.part1
									let partDetails = getPartsDetails(partName: part1)
									part1Unit = partDetails.partUnit
									part1cost = Float(partDetails.partCost)
									part1Qty = Float(partDetails.partQty)
								}
						}
						HStack{LabelDataTextview(label: "Manual Entry", data: $part1)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part1Unit))", data: $part1Qty)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part1cost)}
						Picker_PartsUnit(label: "Unit", data: $part1Unit)
						HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part1Total), unit: "")}
					}
				}
				
				if part2 != "" || part1 != "" {
					CardView {
						VStack {
							SectionText(label: "PART 2")
							HStack{
								Text("Database Entry")
									.textLabelModified()
								Part2PickerItems(RequestingData:$dataSet)
									.onAppear {
										part2 = dataSet.part2
										part2Id = dataSet.part2Id
										part2Qty = dataSet.part2Qty
										part2cost = Float(dataSet.part2cost)
										part2Unit = dataSet.part2Unit
									}
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part2) { _, _ in
										part2 = dataSet.part2
										part2Id = dataSet.part2
										let partDetails = getPartsDetails(partName: part2)
										part2Unit = partDetails.partUnit
										part2cost = Float(partDetails.partCost)
										part2Qty = Float(partDetails.partQty)
									}
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part2)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part2Unit))", data: $part2Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part2cost)}
							Picker_PartsUnit(label: "Unit", data: $part2Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part2Total), unit: "")}
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
								Part3PickerItems(RequestingData:$dataSet)
									.onAppear {
										part3 = dataSet.part3
										part3Id = dataSet.part3Id
										part3Qty = dataSet.part3Qty
										part3cost = Float(dataSet.part3cost)
										part3Unit = dataSet.part3Unit
									}
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part3) { _, _ in
										part3 = dataSet.part3
										part3Id = dataSet.part3
										let partDetails = getPartsDetails(partName: part3)
										part3Unit = partDetails.partUnit
										part3cost = Float(partDetails.partCost)
										part3Qty = Float(partDetails.partQty)
									}
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part3)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part3Unit))", data: $part3Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part3cost)}
							Picker_PartsUnit(label: "Unit", data: $part3Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part3Total), unit: "")}
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
								Part4PickerItems(RequestingData:$dataSet)
									.onAppear {
										part4 = dataSet.part4
										part4Id = dataSet.part4Id
										part4Qty = dataSet.part4Qty
										part4cost = Float(dataSet.part4cost)
										part4Unit = dataSet.part4Unit
									}
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part4) { _, _ in
										part4 = dataSet.part4
										part4Id = dataSet.part4
										let partDetails = getPartsDetails(partName: part4)
										part4Unit = partDetails.partUnit
										part4cost = Float(partDetails.partCost)
										part4Qty = Float(partDetails.partQty)
									}
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part4)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part4Unit))", data: $part4Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part4cost)}
							Picker_PartsUnit(label: "Unit", data: $part4Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part4Total), unit: "")}
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
								Part5PickerItems(RequestingData:$dataSet)
									.onAppear {
										part5 = dataSet.part5
										part5Id = dataSet.part5Id
										part5Qty = dataSet.part5Qty
										part5cost = Float(dataSet.part5cost)
										part5Unit = dataSet.part5Unit
									}
									.frame(maxWidth: .infinity, alignment: .trailing)
									.onChange(of: dataSet.part5) { _, _ in
										part5 = dataSet.part5
										part5Id = dataSet.part5
										let partDetails = getPartsDetails(partName: part5)
										part5Unit = partDetails.partUnit
										part5cost = Float(partDetails.partCost)
										part5Qty = Float(partDetails.partQty)
									}
							}
							HStack{LabelDataTextview(label: "Manual Entry", data: $part5)}
							HStack{LabelDataTextview_Numberpad_Float(label: "Quantity (\(part5Unit))", data: $part5Qty)}
							HStack{LabelDataTextview_Numberpad_Currency(label: "Cost", data: $part5cost)}
							Picker_PartsUnit(label: "Unit", data: $part5Unit)
							HStack{LabelDataCurrency(label: "Total Part Cost", data: Float(part5Total), unit: "")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "COSTS")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Labor Cost", data: $laborCost)}
					}
				}
				
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

			}//end of list
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.toolbar {
				ToolbarItem(placement: .automatic) {
					LabelDataText_Toolbar(label: "EDIT")
				}
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "  Cancel  " : "  Edit  ") {
						isEditing.toggle()
					}
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
			
			// display data
			ScrollView {
				VStack{CreatedUpdatedText(created: dataSet.createdAt, updated: dataSet.updatedAt)}
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle:", data: functions.cleanOptional(inputString: dataSet.vehicleId))}
						HStack{LabelDataText(label: "Systems:", data: "\(dataSet.vehicleSystem)")}
					}
				}
				CardView {
					VStack{
						SectionText(label: "SERVICE ITEM DETAILS")
						HStack{LabelDataText(label: "Service Item:", data: "\(dataSet.mxName)")}
						if dataSet.mxDescription != "" {
							HStack{LabelDataText(label: "Description:", data: "\(dataSet.mxDescription)")}
						}
						if dataSet.Notes != "" {
							HStack{LabelDataText(label: "Notes:", data: "\(dataSet.Notes)")}
						}
						if dataSet.vendor != "" {
							HStack{LabelDataText(label: "Shop:", data: "\(dataSet.vendor)")}
						}
					}
				}
			
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
						Text("Confirm deletion of this item record...")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}
	
	@MainActor
	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.vehicleSystem = vehicleSystem
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
	
}
#Preview {
//	EditItems_test(mxItems: , vehicleId: "test")
//		.modelContainer(for:[MxItems.self])
}

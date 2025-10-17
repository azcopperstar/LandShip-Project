//
//  EditItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import SwiftUI
import SwiftData

struct EditParts: View {
	@State private var dataSet: MxParts1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	// Access settings (units) without storing them in @State
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	@State private var isPresentingConfirm: Bool = false
	@State private var isEditing: Bool = false
	
	@State private var createdAt = Date()
	@State private var updatedAt = Date()
	@State private var vehicleId = ""
	@State private var vehicleSystem = ""
	@State private var partName = ""
	@State private var partNumber = ""
	@State private var partManufacture = ""
	@State private var partDescription = ""
	@State private var Notes = ""
	@State private var costPerUnit: Float = 0.0
	@State private var partUnit = ""
	@State private var partSource = ""
	@State private var partQuantity = 0
	@State private var partLocation = ""
	@State private var partStatus = ""
//	@State private var partImage = ""
	@State private var partSupplier = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	init(mxParts: MxParts1) {
		self.dataSet = mxParts

		self._createdAt = State(initialValue: mxParts.createdAt)
		self._updatedAt = State(initialValue: mxParts.updatedAt)
		self._vehicleId = State(initialValue: mxParts.vehicleId)
		self._vehicleSystem = State(initialValue: mxParts.vehicleSystem)
		self._partName = State(initialValue: mxParts.partName)
		self._partNumber = State(initialValue: mxParts.partNumber)
		self._partManufacture = State(initialValue: mxParts.partManufacture)
		self._partDescription = State(initialValue: mxParts.partDescription)
		self._Notes = State(initialValue: mxParts.Notes)
		self._costPerUnit = State(initialValue: mxParts.costPerUnit)
		self._partUnit = State(initialValue: mxParts.partUnit)
		self._partSource = State(initialValue: mxParts.partSource)
		self._partQuantity = State(initialValue: mxParts.partQuantity)
		self._partLocation = State(initialValue: mxParts.partLocation)
		self._partStatus = State(initialValue: mxParts.partStatus)
		self._partSupplier = State(initialValue: mxParts.partSupplier)
		self._image1 = State(initialValue: mxParts.image1)
		self._image2 = State(initialValue: mxParts.image2)
		self._image3 = State(initialValue: mxParts.image3)
		self._image1Description = State(initialValue: mxParts.image1Description)
		self._image2Description = State(initialValue: mxParts.image2Description)
		self._image3Description = State(initialValue: mxParts.image3Description)
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
							VehiclePickerParts(RequestingData: $dataSet)
								.onChange(of: dataSet.vehicleId) { _, _ in
									vehicleId = dataSet.vehicleId
								}
						}
						HStack{
							Text("Vehicle System")
								.textLabelModified()
							SystemsPickerParts(mxParts:$dataSet)
								.onChange(of: dataSet.vehicleSystem) { _, _ in
									vehicleSystem = dataSet.vehicleSystem
								}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART DETAILS")
						
						HStack{LabelDataTextview(label: "Part Name", data: $partName)}
						HStack{LabelDataTextview(label: "Part #", data: $partNumber)}
						HStack{LabelDataTextview(label: "Manufacturer", data: $partManufacture)}
						HStack{LabelDataTextview(label: "Description", data: $partDescription)}
						HStack{LabelDataTextview(label: "Notes", data: $Notes)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART COSTS")
						
						HStack{LabelDataTextview_Numberpad_Currency(label: "Cost/Unit", data: $costPerUnit)}
						Picker_PartsUnit(label: "Unit", data: $partUnit)
						HStack{LabelDataTextview_Numberpad_Int(label: "Quantity (\(partUnit))", data: $partQuantity)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PART SOURCE")

						HStack{
							Text("Supplier:")
								.textLabelModified()
							VendorPickerParts(RequestingData:$dataSet)
								.onChange(of: dataSet.partSupplier) { _, _ in
									partSupplier = dataSet.partSupplier
								}
						}
						HStack{LabelDataTextview(label: "Source", data: $partSource)}
						HStack{LabelDataTextview(label: "Location", data: $partLocation)}
						HStack{LabelDataTextview(label: "Status", data: $partStatus)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "PARTS GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  PARTS GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
			}// end of scroll
			
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
						updateItem()}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}
			
		} else {
			// display data
			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				
				CardView {
					VStack{
						SectionText(label: "GENERAL")
						HStack{LabelDataText(label: "Vehicle", data: functions.cleanOptional(inputString: dataSet.vehicleId))}
						HStack{LabelDataText(label: "Vehicle System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART DETAILS")
						HStack{LabelDataText(label: "Name", data: functions.cleanOptional(inputString: dataSet.partName))}
						if dataSet.partDescription != "" {
							HStack{LabelDataText(label: "Description", data: functions.cleanOptional(inputString: dataSet.partDescription))}
						}
						if dataSet.vehicleSystem != "" {
							HStack{LabelDataText(label: "System", data: functions.cleanOptional(inputString: dataSet.vehicleSystem))}
						}
						if dataSet.partNumber != "" {
							HStack{LabelDataText(label: "Part #", data: functions.cleanOptional(inputString: dataSet.partNumber))}
						}
						if dataSet.partManufacture != "" {
							HStack{LabelDataText(label: "Manufacturer", data: functions.cleanOptional(inputString: dataSet.partManufacture))}
						}
						if dataSet.Notes != "" {
							HStack{LabelDataText(label: "Notes", data: functions.cleanOptional(inputString: dataSet.Notes))}
						}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART COSTS")
						if dataSet.costPerUnit != 0 {
							HStack{LabelDataText(label: "Cost/Unit", data: "\(functions.formatCurrency(dollars: dataSet.costPerUnit)) / \(dataSet.partUnit)")}
						}
						if dataSet.partUnit != "" {
							HStack{LabelDataText(label: "Unit Type", data: functions.cleanOptional(inputString: dataSet.partUnit))}
						}
						if dataSet.partQuantity != 0 {
							HStack{LabelDataText(label: "Quantity", data: "\(dataSet.partQuantity) \(dataSet.partUnit)")}
						}
					}
				}
				
				CardView {
					VStack{
						SectionText(label: "PART SOURCE")
						if dataSet.partSource != "" {
							HStack{LabelDataText(label: "Source", data: functions.cleanOptional(inputString: dataSet.partSource))}
						}
						if dataSet.partLocation != "" {
							HStack{LabelDataText(label: "Location", data: functions.cleanOptional(inputString: dataSet.partLocation))}
						}
						if dataSet.partStatus != "" {
							HStack{LabelDataText(label: "Status", data: functions.cleanOptional(inputString: dataSet.partStatus))}
						}
						if dataSet.partSupplier != "" {
							HStack{LabelDataText(label: "Supplier", data: functions.cleanOptional(inputString: dataSet.partSupplier))}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "PARTS GRAPHICS")
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
						Text("Confirm deletion of this part record...")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}
	private func updateItem() {
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.vehicleId = vehicleId
		dataSet.vehicleSystem = vehicleSystem
		dataSet.partName = partName
		dataSet.partNumber = partNumber
		dataSet.partManufacture = partManufacture
		dataSet.partDescription = partDescription
		dataSet.Notes = Notes
		dataSet.costPerUnit = costPerUnit
		dataSet.partUnit = partUnit
		dataSet.partSource = partSource
		dataSet.partQuantity = partQuantity
		dataSet.partLocation = partLocation
		dataSet.partStatus = partStatus
		dataSet.partSupplier = partSupplier
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
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview("EditParts Preview with sample MxParts1") {
	makeEditPartsPreview()
}

// Move all setup/seeding out of the ViewBuilder to avoid '()' as a child View.
@MainActor private func makeEditPartsPreview() -> some View {
	// In-memory container with related models available for pickers if you toggle Edit.
	let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(
		for: Vehicle8.self,
				VehicleSystems1.self,
				Vendors1.self,
				MxParts1.self,
				configurations: configuration
	)

	// Seed some related data so pickers have items
	let vehicle = Vehicle8(
		name: "Truck 1500",
		year: 2020,
		mileage: 42000,
		mileageVirtual: 0,
		engHours: 1234.5,
		fuelType: "Gasoline",
		fuelCapacity: 26,
		notes: "",
		vin: "",
		licensePlate: "",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let system = VehicleSystems1(
		createdAt: Date(),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		systemName: "Engine",
		systemDescription: "",
		systemType: "",
		systemManufacturer: "",
		systemModel: "",
		systemSerialNumber: "",
		systemPartNumber: "",
		systemLocation: "",
		systemStatus: "",
		systemNotes: "",
		systemImage: nil,
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	let vendor = Vendors1(
		createdAt: Date(),
		updatedAt: Date(),
		vendorName: "Main Warehouse",
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
	container.mainContext.insert(vehicle)
	container.mainContext.insert(system)
	container.mainContext.insert(vendor)

	// Seed a sample part
	let sample = MxParts1(
		createdAt: Date().addingTimeInterval(-86400),
		updatedAt: Date(),
		vehicleId: vehicle.name,
		vehicleSystem: system.systemName,
		partName: "Oil Filter",
		partNumber: "OF-9876",
		partManufacture: "FilterCo",
		partDescription: "High performance oil filter compatible with V8 engines.",
		Notes: "Replace every 5,000 miles.",
		costPerUnit: 12.99,
		partUnit: "each",
		partSource: "Aisle 3",
		partQuantity: 4,
		partLocation: "Bin B",
		partStatus: "In Stock",
		partImage: nil,
		partSupplier: vendor.vendorName,
		image1: nil,
		image1Description: "Box front",
		image2: nil,
		image2Description: "Filter element",
		image3: nil,
		image3Description: "Installed view"
	)
	container.mainContext.insert(sample)

	return EditParts(mxParts: sample)
		.modelContainer(container)
}

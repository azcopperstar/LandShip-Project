//
//  EditMxRecord.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import SwiftUI
import SwiftData

struct EditFuelLog: View {
	@State private var dataSet: FuelLog1
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// Cache settings (units) once; keep access helper simple and safe.
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		units.indices.contains(index) ? units[index] : ""
	}

	@State private var isPresentingConfirm: Bool = false /// for confirmation dialog
	@State private var isEditing: Bool = false

	@State private var vehicleId: String = ""
	@State private var logName: String = ""
	@State private var fuelNotes: String = ""
	@State private var createdAt: Date = Date()
	@State private var updatedAt: Date = Date()
	@State private var fuelDateTime: Date = Date()
	@State private var odometer: Int = 0
	@State private var location: String = ""
	@State private var engHours: Float = 0.0
	@State private var fuelQuantityStart: Float = 0.0
	@State private var fuelQuantityEnd: Float = 0.0
	@State private var fuelAdded: Float = 0.0
	@State private var defAdded: Float = 0.0
	@State private var oilAdded: Float = 0.0
	@State private var fuelLevelStart1: Float = 0.0
	@State private var fuelLevelEnd1: Float = 0.0
	@State private var fuelLevelStartFraction: String = ""
	@State private var fuelLevelEndFraction: String = ""
	@State private var fuelPrice: Float = 0.0
	@State private var fuelCost: Float = 0.0
	@State private var fuelType: String = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// shared vehicle details accessible anywhere in this file
	@State private var vehicleDetails: VehicleDetails? = nil
	
	init(dataSet: FuelLog1) {
		// Properly initialize the @State wrapper for dataSet
		self._dataSet = State(initialValue: dataSet)
		
		self._vehicleId = State.init(initialValue: dataSet.vehicleId)
		self._logName = State.init(initialValue: dataSet.logName)
		self._fuelNotes = State.init(initialValue: dataSet.fuelNotes)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._fuelDateTime = State.init(initialValue: dataSet.fuelDateTime)
		self._odometer = State.init(initialValue: dataSet.odometer)
		self._location = State.init(initialValue: dataSet.location)
		self._engHours = State.init(initialValue: dataSet.engHours)
		self._fuelQuantityStart = State.init(initialValue: dataSet.fuelQuantityStart)
		self._fuelQuantityEnd = State.init(initialValue: dataSet.fuelQuantityEnd)
		self._fuelAdded = State.init(initialValue: dataSet.fuelAdded)
		self._defAdded = State.init(initialValue: dataSet.defAdded)
		self._oilAdded = State.init(initialValue: dataSet.oilAdded)
		self._fuelLevelStart1 = State.init(initialValue: dataSet.fuelLevelStart1)
		self._fuelLevelEnd1 = State.init(initialValue: dataSet.fuelLevelEnd1)
		self._fuelLevelStartFraction = State.init(initialValue: dataSet.fuelLevelStartFraction)
		self._fuelLevelEndFraction = State.init(initialValue: dataSet.fuelLevelEndFraction)
		self._fuelPrice = State.init(initialValue: dataSet.fuelPrice)
		self._fuelCost = State.init(initialValue: dataSet.fuelCost)
		self._fuelType = State.init(initialValue: dataSet.fuelType)
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
						HStack{
							Text("Vehicle")
								.textLabelModified()
							VehiclePickerFuelLog(RequestingData:$dataSet)
								.onChange(of: dataSet.vehicleId) {_, _ in
									vehicleId = dataSet.vehicleId
									refreshVehicleDetails()
									recomputeFuelQuantities()
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{
							LabelDataPicker_DateTime(label: "Date/Time           ", data: $fuelDateTime)
								.onAppear {
									loadUnitsIfNeeded()
									refreshVehicleDetails()
									recomputeFuelQuantities()
									fuelLevelStartFraction = functions.getFuelLevel(unit: fuelLevelStart1)
								}
						}
								
						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						HStack{LabelDataTextview(label: "Location", data: $location)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometer)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
						HStack{
							Text("Fuel Type")
								.textLabelModified()
							Picker("", selection: $fuelType) {
								Text("Gasoline").tag("Gasoline")
								Text("Diesel").tag("Diesel")
								Text("EV").tag("EV")
								Text("Hybrid").tag("Hybrid")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					
						HStack{
							Picker_FuelLevel1(label: "Fuel Level Start", data: $fuelLevelStart1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
						}
						.onChange(of: fuelLevelStart1) {_, _ in
							fuelLevelStartFraction = functions.getFuelLevel(unit: fuelLevelStart1)
							recomputeFuelQuantities()
						}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level End", data: $fuelLevelEnd1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
						}
						.onChange(of: fuelLevelEnd1) {_, _ in
							fuelLevelEndFraction = functions.getFuelLevel(unit: fuelLevelEnd1)
							recomputeFuelQuantities()
						}

						HStack{
							LabelDataTextview_Numberpad_Currency(label: "Price/\(unit(UnitIndex.fuel))", data: $fuelPrice)
								.onChange(of: fuelPrice) {_, _ in
									fuelCost = fuelPrice * fuelAdded
								}
						}
						HStack{
							LabelDataTextview_Numberpad_Float(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: $fuelAdded)
								.onChange(of: fuelAdded) {_, _ in
									fuelCost = fuelPrice * fuelAdded
								}
						}
						HStack{
							LabelDataTextview_Numberpad_Currency(label: "Cost", data: $fuelCost)
						}
						HStack{LabelDataTextview_Numberpad_Float(label: "Oil Added (\(unit(UnitIndex.oil)))", data: $oilAdded)}
						if fuelType == "Diesel" {
							HStack{LabelDataTextview_Numberpad_Float(label: "DEF Added (\(unit(UnitIndex.def)))", data: $defAdded)}
						}
						HStack{LabelDataTextview(label: "NOTES", data: $fuelNotes)}
						
						CardView {
							VStack {
#if os(macOS)
								SectionText(label: "FUEL GRAPHICS")
#elseif os(iOS)
								SectionText(label: "  FUEL GRAPHICS\n(Click Image to Change)")
#endif
								HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
								HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
								HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
							}
						}
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.onAppear {
				loadUnitsIfNeeded()
				refreshVehicleDetails()
				recomputeFuelQuantities()
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
						SectionText(label: "VEHICLE / LOCATION DETAILS")
							.onAppear {
								loadUnitsIfNeeded()
								refreshVehicleDetails()
							}
						HStack{LabelDataText(label: "Vehicle", data: functions.cleanOptional(inputString: dataSet.vehicleId))}
						HStack{LabelDataText(label: "Date/Time", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.fuelDateTime))")}
						HStack{LabelDataText(label: "Log Name", data: "\(dataSet.logName)")}
						if dataSet.location != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.location)")}
						}
						HStack{LabelDataText(label: "Odometer", data: "\(dataSet.odometer) \(unit(UnitIndex.distance))")}
						if dataSet.engHours > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHours, fractionalLength: 1)}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "FUELING DETAILS")
						HStack{LabelDataText(label: "Fuel Type", data: "\(dataSet.fuelType)")}
						if dataSet.fuelLevelStartFraction != "" {
							HStack{LabelDataText(label: "Fuel Level Start", data: "~\((Float(vehicleDetails?.fuelCapacity ?? 0) * dataSet.fuelLevelStart1)) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelStartFraction)")}
						}
						if dataSet.fuelLevelEndFraction != "" {
							HStack{LabelDataText(label: "Fuel Level End", data: "~\(Float(vehicleDetails?.fuelCapacity ?? 0) * dataSet.fuelLevelEnd1) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelEndFraction)")}
						}
						HStack{LabelDataCurrency(label: "Price/\(unit(UnitIndex.fuel))", data: dataSet.fuelPrice, unit: "/ \(unit(UnitIndex.fuel))")}
						HStack{LabelDataNumber(label: "Fuel Added (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded, fractionalLength: 1)}
						HStack{LabelDataCurrency(label: "Cost", data: dataSet.fuelCost, unit: "")}
						if dataSet.oilAdded > 0.0 {
							HStack{LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: dataSet.oilAdded, fractionalLength: 1)}
						}
						if dataSet.defAdded > 0.0 {
							HStack{LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: dataSet.defAdded, fractionalLength: 1)}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "NOTES")
						if dataSet.fuelNotes != "" {
							HStack{LabelDataText(label: "", data: "\(dataSet.fuelNotes)")}
						}
					}
				}
				
				CardView {
					VStack {
						var lastPrice:Float = 0.0
						var lastOdometer:Int = 0
						SectionText(label: "FUEL STATISTICS")
							.onAppear() {
								// find last fuel record
								var fetchDescriptor1 = FetchDescriptor<FuelLog1>(
									predicate: #Predicate { fetchModel in fetchModel.vehicleId == vehicleId },
									sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)])
								fetchDescriptor1.fetchLimit = 1 // to get only last record
								do {
									let FetchModels = try modelContext.fetch(fetchDescriptor1)
									if !FetchModels.isEmpty{ // not 1st time
										for fetchModel in FetchModels {
											lastPrice = fetchModel.fuelPrice
											lastOdometer = fetchModel.odometer
										}
									}
								} catch {}
							}

						// distance
						HStack{LabelDataText(label: "Distance Since Last Fueling",data: "\(max(0, dataSet.odometer - lastOdometer)) \(unit(UnitIndex.distance))")}
						HStack{LabelDataText(label: "Fuel Burned",data: "\(dataSet.fuelAdded) \(unit(UnitIndex.fuel))")}
						let fuelEconomy: Float = dataSet.fuelAdded > 0 ? Float(max(0, dataSet.odometer - lastOdometer)) / dataSet.fuelAdded : 0
						HStack{LabelDataText(label: "Fuel Economy",data: "\(fuelEconomy.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))")}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FUEL GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}

			}//end of list
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.toolbar {
				ToolbarItem(placement: ToolbarItemPlacement.automatic) {
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
						Text("Confirm deletion of this fuel record...")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
			.onAppear {
				loadUnitsIfNeeded()
				refreshVehicleDetails()
			}
		}
	}

	// Centralized loader so vehicleDetails is available app-wide in this view file
	private func refreshVehicleDetails() {
		self.vehicleDetails = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId)
	}

	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
	}

	private func loadUnitsIfNeeded() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
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
		dataSet.vehicleId = vehicleId
		dataSet.logName = logName
		dataSet.fuelNotes = fuelNotes
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.fuelDateTime = fuelDateTime
		dataSet.odometer = odometer
		dataSet.location = location
		dataSet.engHours = engHours
		dataSet.fuelQuantityStart = fuelQuantityStart
		dataSet.fuelQuantityEnd = fuelQuantityEnd
		dataSet.fuelAdded = fuelAdded
		dataSet.defAdded = defAdded
		dataSet.oilAdded = oilAdded
		dataSet.fuelLevelStart1 = fuelLevelStart1
		dataSet.fuelLevelEnd1 = fuelLevelEnd1
		dataSet.fuelLevelStartFraction = fuelLevelStartFraction
		dataSet.fuelLevelEndFraction = fuelLevelEndFraction
		dataSet.fuelPrice = fuelPrice
		dataSet.fuelCost = fuelCost
		dataSet.fuelType = fuelType
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

		// Update the primary vehicle with newer odometer/engHours if greater
		var fetchDescriptor = FetchDescriptor<Vehicle8>(
			predicate: #Predicate { fetchModel in fetchModel.name == vehicleId })
		do {
			let vehicleDataSet: [Vehicle8] = try modelContext.fetch(fetchDescriptor)
			if !vehicleDataSet.isEmpty {
				for vehicleRecord in vehicleDataSet {
					if odometer > vehicleRecord.mileage {
						vehicleRecord.updatedAt = Date()
						vehicleRecord.mileage = odometer
					}
					if engHours > vehicleRecord.engHours {
						vehicleRecord.engHours = engHours
					}
					do {
						try modelContext.save()
					} catch {}
					break
				}
			}
		} catch {}
	}
}

// Safe index helper for arrays to avoid out-of-bounds if settings are missing
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

#Preview {
}

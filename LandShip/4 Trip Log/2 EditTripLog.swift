//
//  EditMxRecord.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import SwiftUI
import SwiftData

struct EditTripLog: View {
	@State private var dataSet: TripLog2
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
	@State private var tripNotes: String = ""
	@State private var createdAt: Date = Date()
	@State private var updatedAt: Date = Date()
	@State private var tripDateTimeStart: Date = Date()
	@State private var tripDateTimeEnd: Date = Date()
	@State private var odometerStart: Int = 0
	@State private var odometerEnd: Int = 0
	@State private var engHoursStart: Float = 0.0
	@State private var engHoursEnd: Float = 0.0
	@State private var fuelQuantityStart: Float = 0.0
	@State private var fuelQuantityEnd: Float = 0.0
	@State private var fuelConsumed: Float = 0.0
	@State private var fuelLevelStart1: Float = 1.0
	@State private var fuelLevelEnd1: Float = 1.0
	@State private var fuelLevelStart: String = "Full"
	@State private var fuelLevelEnd: String = "Full"
	@State private var fuelAdded1Log: String = ""
	@State private var fuelAdded1: Float = 0.0
	@State private var fuelAdded2Log: String = ""
	@State private var fuelAdded2: Float = 0.0
	@State private var fuelAdded3Log: String = ""
	@State private var fuelAdded3: Float = 0.0
	@State private var fuelAdded4Log: String = ""
	@State private var fuelAdded4: Float = 0.0
	@State private var fuelAdded5Log: String = ""
	@State private var fuelAdded5: Float = 0.0
	@State private var fuelAdded6Log: String = ""
	@State private var fuelAdded6: Float = 0.0
	@State private var locationStart: String = ""
	@State private var locationEnd: String = ""
	@State private var vehicleTowed: Bool = false
	@State private var vehicleIdTowed: String = ""
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// vehicle stats (centralized via VehicleDetails)
	@State private var vehicleDetails: VehicleDetails? = nil
	
	// create fuel log controls for up to 6 stops
	@State private var createFuelLog1: Bool = false
	@State private var fuelPrice1: Float = 0.0
	@State private var fuelOdometer1: Float = 0.0
	@State private var fuelEngHours1: Float = 0.0
	@State private var fuelLocation1: String = ""
	@State private var oilAdded1: Float = 0.0
	@State private var defAdded1: Float = 0.0
	@State private var createFuelLog2: Bool = false
	@State private var fuelPrice2: Float = 0.0
	@State private var fuelOdometer2: Float = 0.0
	@State private var fuelEngHours2: Float = 0.0
	@State private var fuelLocation2: String = ""
	@State private var oilAdded2: Float = 0.0
	@State private var defAdded2: Float = 0.0
	@State private var createFuelLog3: Bool = false
	@State private var fuelPrice3: Float = 0.0
	@State private var fuelOdometer3: Float = 0.0
	@State private var fuelEngHours3: Float = 0.0
	@State private var fuelLocation3: String = ""
	@State private var oilAdded3: Float = 0.0
	@State private var defAdded3: Float = 0.0
	@State private var createFuelLog4: Bool = false
	@State private var fuelPrice4: Float = 0.0
	@State private var fuelOdometer4: Float = 0.0
	@State private var fuelEngHours4: Float = 0.0
	@State private var fuelLocation4: String = ""
	@State private var oilAdded4: Float = 0.0
	@State private var defAdded4: Float = 0.0
	@State private var createFuelLog5: Bool = false
	@State private var fuelPrice5: Float = 0.0
	@State private var fuelOdometer5: Float = 0.0
	@State private var fuelEngHours5: Float = 0.0
	@State private var fuelLocation5: String = ""
	@State private var oilAdded5: Float = 0.0
	@State private var defAdded5: Float = 0.0
	@State private var createFuelLog6: Bool = false
	@State private var fuelPrice6: Float = 0.0
	@State private var fuelOdometer6: Float = 0.0
	@State private var fuelEngHours6: Float = 0.0
	@State private var fuelLocation6: String = ""
	@State private var oilAdded6: Float = 0.0
	@State private var defAdded6: Float = 0.0

	init(dataSet: TripLog2) {
		self.dataSet = dataSet
		vehicleId = dataSet.vehicleId
		
		self._vehicleId = State.init(initialValue: dataSet.vehicleId)
		self._logName = State.init(initialValue: dataSet.logName)
		self._tripNotes = State.init(initialValue: dataSet.tripNotes)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._tripDateTimeStart = State.init(initialValue: dataSet.tripDateTimeStart)
		self._tripDateTimeEnd = State.init(initialValue: dataSet.tripDateTimeEnd)
		self._odometerStart = State.init(initialValue: dataSet.odometerStart)
		self._odometerEnd = State.init(initialValue: dataSet.odometerEnd)
		self._engHoursStart = State.init(initialValue: dataSet.engHoursStart)
		self._engHoursEnd = State.init(initialValue: dataSet.engHoursEnd)
		self._fuelQuantityStart = State.init(initialValue: dataSet.fuelQuantityStart)
		self._fuelQuantityEnd = State.init(initialValue: dataSet.fuelQuantityEnd)
		self._fuelConsumed = State.init(initialValue: dataSet.fuelConsumed)
		self._fuelLevelStart1 = State.init(initialValue: dataSet.fuelLevelStart1)
		self._fuelLevelEnd1 = State.init(initialValue: dataSet.fuelLevelEnd1)
		self._fuelLevelStart = State.init(initialValue: dataSet.fuelLevelStart)
		self._fuelLevelEnd = State.init(initialValue: dataSet.fuelLevelEnd)
		self._fuelAdded1Log = State.init(initialValue: dataSet.fuelAdded1Log)
		self._fuelAdded1 = State.init(initialValue: dataSet.fuelAdded1)
		self._fuelAdded2Log = State.init(initialValue: dataSet.fuelAdded2Log)
		self._fuelAdded2 = State.init(initialValue: dataSet.fuelAdded2)
		self._fuelAdded3Log = State.init(initialValue: dataSet.fuelAdded3Log)
		self._fuelAdded3 = State.init(initialValue: dataSet.fuelAdded3)
		self._fuelAdded4Log = State.init(initialValue: dataSet.fuelAdded4Log)
		self._fuelAdded4 = State.init(initialValue: dataSet.fuelAdded4)
		self._fuelAdded5Log = State.init(initialValue: dataSet.fuelAdded5Log)
		self._fuelAdded5 = State.init(initialValue: dataSet.fuelAdded5)
		self._fuelAdded6Log = State.init(initialValue: dataSet.fuelAdded6Log)
		self._fuelAdded6 = State.init(initialValue: dataSet.fuelAdded6)
		self._locationStart = State.init(initialValue: dataSet.locationStart)
		self._locationEnd = State.init(initialValue: dataSet.locationEnd)
		self._vehicleTowed = State.init(initialValue: dataSet.vehicleTowed)
		self._vehicleIdTowed = State.init(initialValue: dataSet.vehicleIdTowed)
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
							VehiclePickerTripLog(RequestingData:$dataSet)
								.onChange(of: dataSet.vehicleId) { _, _ in
									vehicleId = dataSet.vehicleId
									refreshVehicleDetails()
									recomputeFuelQuantities()
								}
								.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						HStack{LabelDataToggle(label: "Vehicle Towed", data: $vehicleTowed)}
						if vehicleTowed {
							HStack{
								Text("Towed Vehicle")
									.textLabelModified()
								VehiclePickerTripLog_Towed(RequestingData:$dataSet)
									.onChange(of: dataSet.vehicleIdTowed) { _, _ in
										vehicleIdTowed = dataSet.vehicleIdTowed
									}
									.frame(maxWidth: .infinity, alignment: .trailing)
							}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL START")
						HStack{LabelDataPicker_DateTime(label: "Date/Time           ", data: $tripDateTimeStart)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometerStart)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursStart)}
						HStack{LabelDataTextview(label: "Location", data: $locationStart)}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level", data: $fuelLevelStart1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
								.onChange(of: fuelLevelStart1) { _, _ in
									recomputeFuelQuantities()
									fuelLevelStart = functions.getFuelLevel(unit: fuelLevelStart1)
								}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "ENROUTE FUEL ADDED")
						SectionText(label: "FUEL STOP 1")
						HStack{
							LabelDataTextview_Numberpad_Fuel(
								label: "(\(unit(UnitIndex.fuel)))",
								dataQuantity: $fuelAdded1,
								dataFuelLog: $createFuelLog1,
								fuelEntryValue: fuelAdded1,
								dataPrice: $fuelPrice1,
								fuelOdometer: $fuelOdometer1,
								fuelEngHours: $fuelEngHours1,
								fuelLocation: $fuelLocation1,
								oilAdded: $oilAdded1,
								labelOil: "(\(unit(UnitIndex.oil)))",
								defAdded: $defAdded1,
								labelDEF: "(\(unit(UnitIndex.def)))"
							)
						}
						if fuelAdded1 > 0 {
							SectionText(label: "FUEL STOP 2")
							HStack{
								LabelDataTextview_Numberpad_Fuel(
									label: "(\(unit(UnitIndex.fuel)))",
									dataQuantity: $fuelAdded2,
									dataFuelLog: $createFuelLog2,
									fuelEntryValue: fuelAdded2,
									dataPrice: $fuelPrice2,
									fuelOdometer: $fuelOdometer2,
									fuelEngHours: $fuelEngHours2,
									fuelLocation: $fuelLocation2,
									oilAdded: $oilAdded2,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded2,
									labelDEF: "(\(unit(UnitIndex.def)))"
								)
							}
						}
						if fuelAdded2 > 0 {
							SectionText(label: "FUEL STOP 3")
							HStack{
								LabelDataTextview_Numberpad_Fuel(
									label: "(\(unit(UnitIndex.fuel)))",
									dataQuantity: $fuelAdded3,
									dataFuelLog: $createFuelLog3,
									fuelEntryValue: fuelAdded3,
									dataPrice: $fuelPrice3,
									fuelOdometer: $fuelOdometer3,
									fuelEngHours: $fuelEngHours3,
									fuelLocation: $fuelLocation3,
									oilAdded: $oilAdded3,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded3,
									labelDEF: "(\(unit(UnitIndex.def)))"
								)
							}
						}
						if fuelAdded3 > 0 {
							SectionText(label: "FUEL STOP 4")
							HStack{
								LabelDataTextview_Numberpad_Fuel(
									label: "(\(unit(UnitIndex.fuel)))",
									dataQuantity: $fuelAdded4,
									dataFuelLog: $createFuelLog4,
									fuelEntryValue: fuelAdded4,
									dataPrice: $fuelPrice4,
									fuelOdometer: $fuelOdometer4,
									fuelEngHours: $fuelEngHours4,
									fuelLocation: $fuelLocation4,
									oilAdded: $oilAdded4,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded4,
									labelDEF: "(\(unit(UnitIndex.def)))"
								)
							}
						}
						if fuelAdded4 > 0 {
							SectionText(label: "FUEL STOP 5")
							HStack{
								LabelDataTextview_Numberpad_Fuel(
									label: "(\(unit(UnitIndex.fuel)))",
									dataQuantity: $fuelAdded5,
									dataFuelLog: $createFuelLog5,
									fuelEntryValue: fuelAdded5,
									dataPrice: $fuelPrice5,
									fuelOdometer: $fuelOdometer5,
									fuelEngHours: $fuelEngHours5,
									fuelLocation: $fuelLocation5,
									oilAdded: $oilAdded5,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded5,
									labelDEF: "(\(unit(UnitIndex.def)))"
								)
							}
						}
						if fuelAdded5 > 0 {
							SectionText(label: "FUEL STOP 6")
							HStack{
								LabelDataTextview_Numberpad_Fuel(
									label: "(\(unit(UnitIndex.fuel)))",
									dataQuantity: $fuelAdded6,
									dataFuelLog: $createFuelLog6,
									fuelEntryValue: fuelAdded6,
									dataPrice: $fuelPrice6,
									fuelOdometer: $fuelOdometer6,
									fuelEngHours: $fuelEngHours6,
									fuelLocation: $fuelLocation6,
									oilAdded: $oilAdded6,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded6,
									labelDEF: "(\(unit(UnitIndex.def)))"
								)
							}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL END")
						HStack{LabelDataPicker_DateTime(label: "Date/Time           ", data: $tripDateTimeEnd)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometerEnd)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursEnd)}
						HStack{LabelDataTextview(label: "Location", data: $locationEnd)}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level", data: $fuelLevelEnd1, data1: Float(vehicleDetails?.fuelCapacity ?? 0))
								.onChange(of: fuelLevelEnd1) { _, _ in
									recomputeFuelQuantities()
									fuelLevelEnd = functions.getFuelLevel(unit: fuelLevelEnd1)
								}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "NOTES")
						HStack{LabelDataTextview(label: "", data: $tripNotes)}
					}
				}
				
				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "TRAVEL GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  TRAVEL GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}

			}// end of form
			
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
						SectionText(label: "GENERAL")
							.onAppear {
								loadUnitsIfNeeded()
								refreshVehicleDetails()
								// get fuel log data if available
								if fuelAdded1Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded1Log)
									fuelPrice1 = fuelLogData.fuelPrice
									fuelOdometer1 = fuelLogData.fuelOdometer
									fuelEngHours1 = fuelLogData.fuelEngHours
									fuelLocation1 = fuelLogData.fuelLocation
									oilAdded1 = fuelLogData.oilAdded
									defAdded1 = fuelLogData.defAdded
									createFuelLog1 = true
								}
								if fuelAdded2Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded2Log)
									fuelPrice2 = fuelLogData.fuelPrice
									fuelOdometer2 = fuelLogData.fuelOdometer
									fuelEngHours2 = fuelLogData.fuelEngHours
									fuelLocation2 = fuelLogData.fuelLocation
									oilAdded2 = fuelLogData.oilAdded
									defAdded2 = fuelLogData.defAdded
									createFuelLog2 = true
								}
								if fuelAdded3Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded3Log)
									fuelPrice3 = fuelLogData.fuelPrice
									fuelOdometer3 = fuelLogData.fuelOdometer
									fuelEngHours3 = fuelLogData.fuelEngHours
									fuelLocation3 = fuelLogData.fuelLocation
									oilAdded3 = fuelLogData.oilAdded
									defAdded3 = fuelLogData.defAdded
									createFuelLog3 = true
								}
								if fuelAdded4Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded4Log)
									fuelPrice4 = fuelLogData.fuelPrice
									fuelOdometer4 = fuelLogData.fuelOdometer
									fuelEngHours4 = fuelLogData.fuelEngHours
									fuelLocation4 = fuelLogData.fuelLocation
									oilAdded4 = fuelLogData.oilAdded
									defAdded4 = fuelLogData.defAdded
									createFuelLog4 = true
								}
								if fuelAdded5Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded5Log)
									fuelPrice5 = fuelLogData.fuelPrice
									fuelOdometer5 = fuelLogData.fuelOdometer
									fuelEngHours5 = fuelLogData.fuelEngHours
									fuelLocation5 = fuelLogData.fuelLocation
									oilAdded5 = fuelLogData.oilAdded
									defAdded5 = fuelLogData.defAdded
									createFuelLog5 = true
								}
								if fuelAdded6Log != "" {
									let fuelLogData = getFuelLogData(saveLogId: fuelAdded6Log)
									fuelPrice6 = fuelLogData.fuelPrice
									fuelOdometer6 = fuelLogData.fuelOdometer
									fuelEngHours6 = fuelLogData.fuelEngHours
									fuelLocation6 = fuelLogData.fuelLocation
									oilAdded6 = fuelLogData.oilAdded
									defAdded6 = fuelLogData.defAdded
									createFuelLog6 = true
								}
							}
						HStack{LabelDataText(label: "Vehicle", data: functions.cleanOptional(inputString: dataSet.vehicleId))}
						if dataSet.vehicleTowed {
							HStack{LabelDataText(label: "Towed Vehicle", data: "\(dataSet.vehicleIdTowed)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL START")
						HStack{LabelDataText(label: "Departure", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.tripDateTimeStart))")}
						HStack{LabelDataText(label: "Odometer", data: "\(dataSet.odometerStart) \(unit(UnitIndex.distance))")}
						if dataSet.engHoursStart > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHoursStart, fractionalLength: 1)}
						}
						if dataSet.fuelLevelStart != "" {
							HStack{LabelDataText(label: "Fuel Level", data: "~\(dataSet.fuelQuantityStart) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelStart)")}
						}
						if dataSet.locationStart != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationStart)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL ENROUTE")
						if dataSet.fuelAdded1 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation1)", data: dataSet.fuelAdded1, fractionalLength: 1)}
						}
						if dataSet.fuelAdded2 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation2)", data: dataSet.fuelAdded2, fractionalLength: 1)}
						}
						if dataSet.fuelAdded3 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation3)", data: dataSet.fuelAdded3, fractionalLength: 1)}
						}
						if dataSet.fuelAdded4 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation4)", data: dataSet.fuelAdded4, fractionalLength: 1)}
						}
						if dataSet.fuelAdded5 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation5)", data: dataSet.fuelAdded5, fractionalLength: 1)}
						}
						if dataSet.fuelAdded6 > 0 {
							HStack{LabelDataNumber(label: "Fuel Added \(fuelLocation6)", data: dataSet.fuelAdded6, fractionalLength: 1)}
						}
						
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL END")
						HStack{LabelDataText(label: "Arrival", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.tripDateTimeEnd))")}
						HStack{LabelDataText(label: "Odometer", data: "\(dataSet.odometerEnd) \(unit(UnitIndex.distance))")}
						if dataSet.engHoursEnd > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHoursEnd, fractionalLength: 1)}
						}
						if dataSet.fuelLevelEnd != "" {
							HStack{LabelDataText(label: "Fuel Level", data: "~\(dataSet.fuelQuantityEnd) \(unit(UnitIndex.fuel)) \(dataSet.fuelLevelEnd)")}
						}
						if dataSet.locationEnd != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationEnd)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL STATISTICS")
						// time
						let ymdhmBetweenAnnouncements = Calendar(identifier: .gregorian).dateComponents(
							[.year, .month, .day, .hour, .minute],
							from: dataSet.tripDateTimeStart,
							to: dataSet.tripDateTimeEnd
						)
						if (ymdhmBetweenAnnouncements.day ?? 0) != 0 {
							HStack{LabelDataText(label: "Underway",data: "\(ymdhmBetweenAnnouncements.day!) days, \(ymdhmBetweenAnnouncements.hour ?? 0) hours, \(ymdhmBetweenAnnouncements.minute ?? 0) minutes")}
						} else if (ymdhmBetweenAnnouncements.hour ?? 0) != 0 {
							HStack{LabelDataText(label: "Underway", data: "\(ymdhmBetweenAnnouncements.hour!) hours, \(ymdhmBetweenAnnouncements.minute ?? 0) minutes")}
						} else {
							HStack{LabelDataText(label: "Underway",data: "\(ymdhmBetweenAnnouncements.minute ?? 0) minutes")}
						}
						// distance (non-negative)
						let distance = max(0, dataSet.odometerEnd - dataSet.odometerStart)
						HStack{LabelDataText(label: "Distance",data: "\(distance) \(unit(UnitIndex.distance))")}
						
						let fuelBurned: Float = max(0, (dataSet.fuelQuantityStart - dataSet.fuelQuantityEnd) + dataSet.fuelAdded1 + dataSet.fuelAdded2 + dataSet.fuelAdded3 + dataSet.fuelAdded4 + dataSet.fuelAdded5 + dataSet.fuelAdded6)
						HStack{LabelDataText(label: "Fuel Burned",data: "\(fuelBurned) \(unit(UnitIndex.fuel))")}
						
						let fuelEconomy: Float = fuelBurned > 0 ? Float(distance) / fuelBurned : 0
						HStack{LabelDataText(label: "Fuel Economy",data: "\(fuelEconomy.formatted(.number.precision(.fractionLength(1)))) \(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel))")}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL GRAPHICS")
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
						Text("Confirm deletion of this service record...")
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
	
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {print(error.localizedDescription)}
		dismiss()
	}
	
	private func updateItem() {
		// save fuel log(s) first to return the fuel log id(s) for saving
		if createFuelLog1 {
			fuelAdded1Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer1), saveEngineHours: fuelEngHours1, saveQuantity: Int(fuelAdded1), savePrice: fuelPrice1, saveLocation: fuelLocation1, saveLogId: fuelAdded1Log, saveOil: oilAdded1, saveDEF: defAdded1)
		}
		if createFuelLog2 {
			fuelAdded2Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer2), saveEngineHours: fuelEngHours2, saveQuantity: Int(fuelAdded2), savePrice: fuelPrice2, saveLocation: fuelLocation2, saveLogId: fuelAdded2Log, saveOil: oilAdded2, saveDEF: defAdded2)
		}
		if createFuelLog3 {
			fuelAdded3Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer3), saveEngineHours: fuelEngHours3, saveQuantity: Int(fuelAdded3), savePrice: fuelPrice3, saveLocation: fuelLocation3, saveLogId: fuelAdded3Log, saveOil: oilAdded3, saveDEF: defAdded3)
		}
		if createFuelLog4 {
			fuelAdded4Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer4), saveEngineHours: fuelEngHours4, saveQuantity: Int(fuelAdded4), savePrice: fuelPrice4, saveLocation: fuelLocation4, saveLogId: fuelAdded4Log, saveOil: oilAdded4, saveDEF: defAdded4)
		}
		if createFuelLog5 {
			fuelAdded5Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer5), saveEngineHours: fuelEngHours5, saveQuantity: Int(fuelAdded5), savePrice: fuelPrice5, saveLocation: fuelLocation5, saveLogId: fuelAdded5Log, saveOil: oilAdded5, saveDEF: defAdded5)
		}
		if createFuelLog6 {
			fuelAdded6Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer6), saveEngineHours: fuelEngHours6, saveQuantity: Int(fuelAdded6), savePrice: fuelPrice6, saveLocation: fuelLocation6, saveLogId: fuelAdded6Log, saveOil: oilAdded6, saveDEF: defAdded6)
		}

		dataSet.vehicleId = vehicleId
		dataSet.logName = logName
		dataSet.tripNotes = tripNotes
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.tripDateTimeStart = tripDateTimeStart
		dataSet.tripDateTimeEnd = tripDateTimeEnd
		dataSet.odometerStart = odometerStart
		dataSet.odometerEnd = odometerEnd
		dataSet.engHoursStart = engHoursStart
		dataSet.engHoursEnd = engHoursEnd
		dataSet.fuelQuantityStart = fuelQuantityStart
		dataSet.fuelQuantityEnd = fuelQuantityEnd
		dataSet.fuelConsumed = fuelConsumed
		dataSet.fuelLevelStart1 = fuelLevelStart1
		dataSet.fuelLevelEnd1 = fuelLevelEnd1
		dataSet.fuelLevelStart = fuelLevelStart
		dataSet.fuelLevelEnd = fuelLevelEnd
		dataSet.fuelAdded1Log = fuelAdded1Log
		dataSet.fuelAdded1 = fuelAdded1
		dataSet.fuelAdded2Log = fuelAdded2Log
		dataSet.fuelAdded2 = fuelAdded2
		dataSet.fuelAdded3Log = fuelAdded3Log
		dataSet.fuelAdded3 = fuelAdded3
		dataSet.fuelAdded4Log = fuelAdded4Log
		dataSet.fuelAdded4 = fuelAdded4
		dataSet.fuelAdded5Log = fuelAdded5Log
		dataSet.fuelAdded5 = fuelAdded5
		dataSet.fuelAdded6Log = fuelAdded6Log
		dataSet.fuelAdded6 = fuelAdded6
		dataSet.locationStart = locationStart
		dataSet.locationEnd = locationEnd
		dataSet.vehicleTowed = vehicleTowed
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		if vehicleTowed {
			dataSet.vehicleIdTowed = vehicleIdTowed
		} else {
			dataSet.vehicleIdTowed = ""
		}
		
		// update the record
		do {
			try modelContext.save()
		} catch {print(error.localizedDescription)}
		
		// Update the primary vehicle data with the travelLog data if greater
		do {
			var fetchDescriptor = FetchDescriptor<Vehicle8>(
				predicate: #Predicate { fetchModel in fetchModel.name == vehicleId }
			)
			fetchDescriptor.fetchLimit = 1
			if let vehicleRecord = try modelContext.fetch(fetchDescriptor).first {
				if odometerEnd > vehicleRecord.mileage {
					vehicleRecord.updatedAt = Date()
					vehicleRecord.mileage = odometerEnd
				}
				if engHoursEnd > vehicleRecord.engHours {
					vehicleRecord.engHours = engHoursEnd
				}
				try? modelContext.save()
			}
		} catch {}
		
		// Update the towed vehicle virtual odometer if applicable
		if vehicleTowed {
			do {
				var fetchDescriptor = FetchDescriptor<Vehicle8>(
					predicate: #Predicate { fetchModel in fetchModel.name == vehicleIdTowed }
				)
				fetchDescriptor.fetchLimit = 1
				if let towedVehicle = try modelContext.fetch(fetchDescriptor).first {
					let distanceTraveled = max(0, odometerEnd - odometerStart)
					if towedVehicle.mileageVirtual > 0 && distanceTraveled > 0 {
						towedVehicle.mileageVirtual += distanceTraveled
					} else {
						towedVehicle.mileageVirtual = towedVehicle.mileage + distanceTraveled
					}
					towedVehicle.updatedAt = Date()
					try? modelContext.save()
				}
			} catch {}
		}
	}
	
	// search to see if a fuel log exists for this travel log
	private func searchFuelRecord(saveOdometer: Int, saveLogId: String) -> String {
		// Prefer explicit logId if provided
		if !saveLogId.isEmpty {
			do {
				var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.logId == saveLogId })
				fd.fetchLimit = 1
				if let found = try modelContext.fetch(fd).first {
					return found.logId
				}
			} catch {}
		}
		// Try by odometer + vehicle
		do {
			var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.odometer == saveOdometer && $0.vehicleId == vehicleId })
			fd.fetchLimit = 1
			if let found = try modelContext.fetch(fd).first {
				// create a new logId from timestamp and assign
				let newId = functions.formatDate_DDMMMyy_HHmmss(date: Date())
				found.logId = newId
				try? modelContext.save()
				return newId
			}
		} catch {}
		// not found
		return ""
	}
	
	// Function to add or edit a fuel record
	private func add_editFuelRecord(saveOdometer: Int, saveEngineHours: Float, saveQuantity: Int, savePrice: Float, saveLocation: String, saveLogId: String, saveOil: Float, saveDEF: Float) -> String {
		var logId: String = ""
		
		// get vehicle details (via Vehicle8)
		var odometerVehicle: Int = 0
		var engHoursVehicle: Float = 0.0
		var fuelCapacityVehicle: Int = 0
		var fuelTypeVehicle: String = ""
		do {
			var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == vehicleId })
			fd.fetchLimit = 1
			if let v = try modelContext.fetch(fd).first {
				odometerVehicle = v.mileage
				engHoursVehicle = v.engHours
				fuelCapacityVehicle = v.fuelCapacity
				fuelTypeVehicle = v.fuelType
			}
		} catch {}
		
		// see if there is already a fuel log for this travel log
		logId = searchFuelRecord(saveOdometer: saveOdometer, saveLogId: saveLogId)
		if !logId.isEmpty {
			// update existing record (by logId if possible, else fallback to odometer+vehicle)
			do {
				var fdById = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.logId == logId })
				fdById.fetchLimit = 1
				if let existing = try modelContext.fetch(fdById).first {
					existing.logId = logId
					existing.fuelAdded = Float(saveQuantity)
					existing.fuelPrice = savePrice
					existing.fuelCost = savePrice * Float(saveQuantity)
					existing.location = saveLocation
					existing.odometer = saveOdometer
					existing.engHours = saveEngineHours
					existing.oilAdded = saveOil
					existing.defAdded = saveDEF
					existing.fuelNotes = existing.fuelNotes + "\nEdited: \(functions.formatDate_DDMMMyy_HHmm(date: Date()))"
					existing.updatedAt = Date()
					try? modelContext.save()
					return logId
				}
				// fallback fetch
				var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.odometer == saveOdometer && $0.vehicleId == vehicleId })
				fd.fetchLimit = 1
				if let existing = try modelContext.fetch(fd).first {
					existing.logId = logId
					existing.fuelAdded = Float(saveQuantity)
					existing.fuelPrice = savePrice
					existing.fuelCost = savePrice * Float(saveQuantity)
					existing.location = saveLocation
					existing.odometer = saveOdometer
					existing.engHours = saveEngineHours
					existing.oilAdded = saveOil
					existing.defAdded = saveDEF
					existing.fuelNotes = existing.fuelNotes + "\nEdited: \(functions.formatDate_DDMMMyy_HHmm(date: Date()))"
					existing.updatedAt = Date()
					try? modelContext.save()
					return logId
				}
			} catch {}
		}
		
		// not found, create new fuel record
		logId = functions.formatDate_DDMMMyy_HHmmss(date: Date())
		let newRecord = FuelLog1(
			logId: logId,
			vehicleId: vehicleId,
			logName: logName,
			fuelNotes: "Auto-added from travel log: \(logName)",
			createdAt: Date(),
			updatedAt: Date(),
			fuelDateTime: Date(),
			odometer: saveOdometer,
			location: saveLocation,
			engHours: saveEngineHours,
			fuelQuantityStart: max(0, Float(fuelCapacityVehicle) - Float(saveQuantity)),
			fuelQuantityEnd: Float(fuelCapacityVehicle),
			fuelAdded: Float(saveQuantity),
			defAdded: saveDEF,
			oilAdded: saveOil,
			fuelLevelStart1: 0.25,
			fuelLevelEnd1: 1.0,
			fuelLevelStart: "1/4",
			fuelLevelEnd: "Full",
			fuelPrice: savePrice,
			fuelCost: savePrice * Float(saveQuantity),
			fuelType: fuelTypeVehicle
		)
		modelContext.insert(newRecord)
		do { try modelContext.save() } catch {}
		return logId
	}
	
	// get fuel log data by logId
	func getFuelLogData(saveLogId: String) -> (fuelAdded: Float, fuelPrice: Float, fuelCost: Float, fuelOdometer: Float, fuelEngHours: Float, fuelLocation: String, oilAdded: Float, defAdded: Float) {
		var fuelAdded: Float = 0
		var fuelPrice: Float = 0
		var fuelCost: Float = 0
		var fuelOdometer: Float = 0
		var fuelEngHours: Float = 0
		var fuelLocation: String = ""
		var oilAdded: Float = 0
		var defAdded: Float = 0
		do {
			var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.logId == saveLogId })
			fd.fetchLimit = 1
			if let fetchModel = try modelContext.fetch(fd).first {
				fuelAdded = fetchModel.fuelAdded
				fuelPrice = fetchModel.fuelPrice
				fuelCost = fetchModel.fuelCost
				fuelOdometer = Float(fetchModel.odometer)
				fuelEngHours = fetchModel.engHours
				fuelLocation = fetchModel.location
				oilAdded = fetchModel.oilAdded
				defAdded = fetchModel.defAdded
			}
		} catch {}
		return (fuelAdded, fuelPrice, fuelCost, fuelOdometer, fuelEngHours, fuelLocation, oilAdded, defAdded)
	}
	
	// MARK: - Helpers
	private func loadUnitsIfNeeded() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}
	private func refreshVehicleDetails() {
		self.vehicleDetails = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId)
	}
	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
		// keep a running consumed value if helpful in edit state
		fuelConsumed = max(0, (fuelQuantityStart - fuelQuantityEnd) + fuelAdded1 + fuelAdded2 + fuelAdded3 + fuelAdded4 + fuelAdded5 + fuelAdded6)
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

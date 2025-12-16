/*
 File: EditVehicle.swift
 Module: LandShip
 
 Summary
 -------
 A SwiftUI view that displays and edits a single Vehicle8 record. The view supports a dual-mode UI
 (Details vs. Edit), persists changes back to SwiftData, and computes per-vehicle "Next Service Due"
 information by inspecting maintenance items (MxItems3) and the most recent service records
 (ServiceRecords1). Images can be attached to the vehicle and edited inline on iOS.
 
 Key Features
 ------------
 - Dual-mode UI with toolbar actions (Edit/Cancel/Save and Delete/Deactivate)
 - Soft delete via an `inactive` flag, with optional hard delete
 - Unit string caching via PrefsFunctions to minimize repeated settings fetches
 - Per-vehicle maintenance forecasting using SwiftData fetches and simple ranking
 - Rich details layout grouped into logical cards (General, Mechanical, Dimensions, Weights, etc.)
 - Platform-conditional UI for image editing (iOS vs. macOS)
 
 Data Flow
 ---------
 - The view is initialized with a Vehicle8 model instance (dataSet) and a binding `trackVehicleSelected`.
 - `@State` mirrors the model fields for form editing; `updateItem()` writes them back to the model
   and calls `modelContext.save()`.
 - `recomputeNextDue()` fetches MxItems3 scoped to this vehicle and the latest ServiceRecords1 per item,
   then computes remaining miles/hours/days and ranks urgency to surface the next two items.
 - Unit strings are loaded once on appear and then read via the `unit(_:)` helper for display labels.
 
 Dependencies
 ------------
 - Frameworks: SwiftUI, SwiftData, PhotosUI
 - Models: Vehicle8, MxItems3, ServiceRecords1
 - Utilities: Functions, PrefsFunctions, plus shared UI components (CardView, SectionText, etc.)
 
 Concurrency & Persistence
 -------------------------
 - Operates on SwiftUI's main thread; SwiftData fetches run against the injected main `modelContext`.
 - All persistence changes are explicit via `modelContext.save()` with simple error logging.
 
 Notes
 -----
 - This file adds only UI and helper logic; business rules for maintenance items live in the data models.
 - The header intentionally documents data flow and dependencies to aid future maintenance and testing.
 */

/// A view for displaying and editing a single Vehicle8 record.
/// - Parameters:
///   - dataSet: The Vehicle8 instance to present and edit.
///   - trackVehicleSelected: A binding used by parent views to reflect the currently visible vehicle.
///   - startEditing: Optional flag to start in edit mode (defaults to false).

import SwiftUI
import SwiftData

struct EditVehicle: View {
	// MARK: State & Environment
	// The following state mirrors the fields of Vehicle8 for editing. Changes are committed
	// back to the model in `updateItem()` and persisted via SwiftData.
	@State private var dataSet: Vehicle8
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
	@Binding var trackVehicleSelected: String
	
	// for confirmation dialog
	@State private var isPresentingConfirm: Bool = false
	
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()
	
	@State private var isEditing: Bool = false
	
	// Cache unit strings once per appearance to avoid repeated fetches
	@State private var unitStrings: [String] = Array(repeating: "", count: 13)
	private func loadUnits() {
		unitStrings = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1")
		?? Array(repeating: "", count: 13)
	}
	// Helper to read unit strings from cached array
	private func unit(_ index: Int) -> String {
		unitStrings[safe: index] ?? ""
	}
	@State private var inactive: Bool = false
	@State private var name: String = ""
	@State private var manufacturer: String = ""
	@State private var model: String = ""
	@State private var year: Int = 0
	@State private var trim: String = ""
	@State private var mileage: Int = 0
	@State private var mileageVirtual: Int = 0
	@State private var engHours: Float = 0.0
	@State private var transmission: String = ""
	@State private var engine: String = ""
	@State private var fuelType: String = ""
	@State private var doors: Int = 0
	@State private var seats: Int = 0
	@State private var cargoSpace: Int = 0
	@State private var length: Int = 0
	@State private var width: Int = 0
	@State private var height: Int = 0
	@State private var weight: Int = 0
	@State private var dateWeighed: Date = Date()
	@State private var wheelbase: Int = 0
	@State private var gvwr: Int = 0
	@State private var gcwr: Int = 0
	@State private var gawrRear: Int = 0
	@State private var gawrFront: Int = 0
	@State private var towingCapcity: Int = 0
	@State private var uvw: Int = 0
	@State private var ccc: Int = 0
	
	@State private var fuelCapacity: Int = 0
	@State private var defCapacity: Int = 0
	@State private var waterCapacity: Int = 0
	@State private var grayCapacity: Int = 0
	@State private var blackCapacity: Int = 0
	
	@State private var imageUrl: String = ""
	@State private var price: Int = 0
	@State private var notes: String = ""
	@State private var createdAt: Date = Date()
	@State private var updatedAt: Date = Date()
	@State private var ownerId: String = ""
	@State private var locationId: String = ""
	@State private var vin: String = ""
	@State private var licensePlate: String = ""
	
	@State private var datePurchased: Date = Date()
	@State private var placePurchased: String = ""
	@State private var tireSize: String = ""
	@State private var titleNumber: String = ""
	
	@State private var onlineServiceProvider: String = ""
	@State private var onlineServiceNumber: String = ""
	@State private var onlineServiceLogin: String = ""
	@State private var onlineServiceURL: String = ""
	@State private var onlineServiceBillingAccount: String = ""
	@State private var vehicleMobileNumber: String = ""
	
	@State private var insuranceCompany: String = ""
	@State private var insurancePolicyNumber: String = ""
	@State private var insurancePolicyHolder: String = ""
	@State private var insuranceExpiration: Date = Date()
	
	@State private var tirePressureFront: Int = 0
	@State private var tirePressureRear: Int = 0
	@State private var tirePressureTag: Int = 0
	@State private var tirePressurePusher: Int = 0
	@State private var availablePayload: Int = 0
	
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// MARK: - Next Service Due (per this vehicle)
	struct UpcomingDue: Identifiable {
		let id = UUID()
		let itemName: String
		let itemDescription: String
		let intervalMiles: Int
		let intervalHours: Float
		let intervalMonths: Int
		let remainingMiles: Int?
		let remainingHours: Float?
		let remainingDays: Int?
		let dueDate: Date?
		let score: Double // lower is more urgent
	}
	@State private var nextTwoDue: [UpcomingDue] = []
	
	init(dataSet: Vehicle8, trackVehicleSelected: Binding<String>, startEditing: Bool = false) {
		// Properly initialize @State
		self._dataSet = State(initialValue: dataSet)
		self._trackVehicleSelected = trackVehicleSelected
		
		self._inactive = State.init(initialValue: dataSet.inactive)
		self._name = State.init(initialValue: dataSet.name)
		self._manufacturer = State.init(initialValue: dataSet.manufacturer)
		self._model = State.init(initialValue: dataSet.model)
		self._year = State.init(initialValue: dataSet.year)
		self._trim = State.init(initialValue: dataSet.trim)
		self._mileage = State.init(initialValue: dataSet.mileage)
		self._mileageVirtual = State.init(initialValue: dataSet.mileageVirtual)
		self._engHours = State.init(initialValue: Float(dataSet.engHours))
		self._transmission = State.init(initialValue: dataSet.transmission)
		self._engine = State.init(initialValue: dataSet.engine)
		self._fuelType = State.init(initialValue: dataSet.fuelType)
		self._doors = State.init(initialValue: dataSet.doors)
		self._seats = State.init(initialValue: dataSet.seats)
		self._cargoSpace = State.init(initialValue: dataSet.cargoSpace)
		self._length = State.init(initialValue: dataSet.length)
		self._width = State.init(initialValue: dataSet.width)
		self._height = State.init(initialValue: dataSet.height)
		self._weight = State.init(initialValue: dataSet.weight)
		self._dateWeighed = State.init(initialValue: dataSet.dateWeighed)
		self._wheelbase = State.init(initialValue: dataSet.wheelbase)
		self._gvwr = State.init(initialValue: dataSet.gvwr)
		self._gcwr = State.init(initialValue: dataSet.gcwr)
		self._gawrFront = State.init(initialValue: dataSet.gawrFront)
		self._gawrRear = State.init(initialValue: dataSet.gawrRear)
		self._towingCapcity = State.init(initialValue: dataSet.towingCapcity)
		self._uvw = State.init(initialValue: dataSet.uvw)
		self._ccc = State.init(initialValue: dataSet.ccc)
		self._fuelCapacity = State.init(initialValue: dataSet.fuelCapacity)
		self._defCapacity = State.init(initialValue: dataSet.defCapacity)
		self._waterCapacity = State.init(initialValue: dataSet.waterCapacity)
		self._grayCapacity = State.init(initialValue: dataSet.grayCapacity)
		self._blackCapacity = State.init(initialValue: dataSet.blackCapacity)
		self._imageUrl = State.init(initialValue: dataSet.imageUrl)
		self._price = State.init(initialValue: dataSet.price)
		self._notes = State.init(initialValue: dataSet.notes)
		self._createdAt = State.init(initialValue: dataSet.createdAt)
		self._updatedAt = State.init(initialValue: dataSet.updatedAt)
		self._ownerId = State.init(initialValue: dataSet.ownerId)
		self._locationId = State.init(initialValue: dataSet.locationId)
		self._vin = State.init(initialValue: dataSet.vin)
		self._licensePlate = State.init(initialValue: dataSet.licensePlate)
		
		self._datePurchased = State.init(initialValue: dataSet.datePurchased)
		self._placePurchased = State.init(initialValue: dataSet.placePurchased)
		self._tireSize = State.init(initialValue: dataSet.tireSize)
		self._titleNumber = State.init(initialValue: dataSet.titleNumber)
		self._onlineServiceProvider = State.init(initialValue: dataSet.onlineServiceProvider)
		self._onlineServiceNumber = State.init(initialValue: dataSet.onlineServiceNumber)
		self._onlineServiceLogin = State.init(initialValue: dataSet.onlineServiceLogin)
		self._onlineServiceURL = State.init(initialValue: dataSet.onlineServiceURL)
		self._onlineServiceBillingAccount = State.init(initialValue: dataSet.onlineServiceBillingAccount)
		self._vehicleMobileNumber = State.init(initialValue: dataSet.vehicleMobileNumber)
		self._insuranceCompany = State.init(initialValue: dataSet.insuranceCompany)
		self._insurancePolicyNumber = State.init(initialValue: dataSet.insurancePolicyNumber)
		self._insurancePolicyHolder = State.init(initialValue: dataSet.insurancePolicyHolder)
		self._insuranceExpiration = State.init(initialValue: dataSet.insuranceExpiration)
		self._tirePressureFront = State.init(initialValue: dataSet.tirePressureFront)
		self._tirePressureRear = State.init(initialValue: dataSet.tirePressureRear)
		self._tirePressureTag = State.init(initialValue: dataSet.tirePressureTag)
		self._tirePressurePusher = State.init(initialValue: dataSet.tirePressurePusher)
		self._availablePayload = State.init(initialValue: dataSet.availablePayload)
		
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
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL INFORMATION")
						HStack{LabelDataTextview(label: "Name", data: $name)}
						HStack{
							Text("Model Year:")
								.textLabelModified()
							Picker("", selection: $year) {
								let year:Int = Calendar.current.component(.year, from: Date()) + 1
								ForEach((1980...year).reversed(), id: \.self) {
									Text(verbatim: "\($0)").tag($0)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview(label: "Manufacturer", data: $manufacturer)}
						HStack{LabelDataTextview(label: "Model", data: $model)}
						HStack{LabelDataTextview(label: "Trim Level", data: $trim)}
						HStack{LabelDataTextview(label: "VIN", data: $vin)}
						HStack{LabelDataTextview(label: "Title Number", data: $titleNumber)}
						HStack{LabelDataTextview(label: "Plate Number", data: $licensePlate)}
					}
				}
			
				
				
				CardView {
					VStack {
						SectionText(label: "MECHANICAL DETAILS")
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
						HStack{LabelDataTextview(label: "Engine", data: $engine)}
						HStack{LabelDataTextview(label: "Transmission", data: $transmission)}
					}
				}
		
				CardView {
					VStack {
						SectionText(label: "VEHICLE DETAILS")
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $mileage)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer (Virtual)", data: $mileageVirtual)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Doors", data: $doors)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Seats", data: $seats)}
					}
				}

				// NEW: Next Service Due (Edit mode)
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						SectionText(label: "NEXT SERVICE DUE")
						if nextTwoDue.isEmpty {
							Text("No upcoming service items found.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(nextTwoDue) { due in
								VStack(alignment: .leading, spacing: 4) {
									Text(due.itemName).font(.subheadline).bold()
									if !due.itemDescription.isEmpty {
										Text(due.itemDescription).font(.caption).foregroundStyle(.secondary)
									}
									HStack(spacing: 12) {
										if due.intervalMiles > 0, let rm = due.remainingMiles {
											Text("Miles: \(max(0, rm)) \(unit(UnitIndex.distance))").font(.caption)
										}
										if due.intervalHours > 0, let rh = due.remainingHours {
											Text(String(format: "Hours: %.1f", max(0, rh))).font(.caption)
										}
										if due.intervalMonths > 0, let rd = due.remainingDays {
											Text("Days: \(max(0, rd))").font(.caption)
										}
									}
									if let d = due.dueDate {
										Text("Est. next due: \(functions.formatDate_DDMMMyy(date: d))")
											.font(.caption2)
											.foregroundStyle(.secondary)
									}
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
					}
				}
			
				CardView {
					VStack {
						SectionText(label: "TIRE SPECIFICATIONS")
						HStack{LabelDataTextview(label: "Make/Model/Size", data: $tireSize)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Pressure Front (\(unit(UnitIndex.pressure)))", data: $tirePressureFront)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Pressure Rear (\(unit(UnitIndex.pressure)))", data: $tirePressureRear)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Pressure Tag Axle (\(unit(UnitIndex.pressure)))", data: $tirePressureTag)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Pressure Pusher Axle (\(unit(UnitIndex.pressure)))", data: $tirePressurePusher)}
					}
					VStack {
						SectionText(label: "DIMENSIONS")
						HStack{LabelDataTextview_Numberpad_Int(label: "Wheelbase (\(unit(UnitIndex.wheelBase)))", data: $wheelbase)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Length (\(unit(UnitIndex.length)))", data: $length)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Width (\(unit(UnitIndex.width)))", data: $width)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Height (\(unit(UnitIndex.height)))", data: $height)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Cargo Space (\(unit(UnitIndex.area)))", data: $cargoSpace)}
					}
					VStack {
						SectionText(label: "WEIGHT DATA")
						HStack{LabelDataTextview_Numberpad_Int(label: "Vehicle Weight (\(unit(UnitIndex.mass)))", data: $weight)}
						HStack{LabelDataPicker_Date(label: "Date Weighed", data: $dateWeighed)}
						HStack{LabelDataTextview_Numberpad_Int(label: "GVWR (\(unit(UnitIndex.mass)))", data: $gvwr)}
						HStack{LabelDataTextview_Numberpad_Int(label: "GCWR (\(unit(UnitIndex.mass)))", data: $gcwr)}
						HStack{LabelDataTextview_Numberpad_Int(label: "GAWR Front (\(unit(UnitIndex.mass)))", data: $gawrFront)}
						HStack{LabelDataTextview_Numberpad_Int(label: "GAWR Rear (\(unit(UnitIndex.mass)))", data: $gawrRear)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Towing Capacity (\(unit(UnitIndex.mass)))", data: $towingCapcity)}
						HStack{LabelDataTextview_Numberpad_Int(label: "UVW (\(unit(UnitIndex.mass)))", data: $uvw)}
						HStack{LabelDataTextview_Numberpad_Int(label: "CCC (\(unit(UnitIndex.mass)))", data: $ccc)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Payload (\(unit(UnitIndex.mass)))", data: $availablePayload)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "CAPACITIES")
						HStack{LabelDataTextview_Numberpad_Int(label: "Fuel (\(unit(UnitIndex.fuel)))", data: $fuelCapacity)}
						HStack{LabelDataTextview_Numberpad_Int(label: "DEF (\(unit(UnitIndex.def)))", data: $defCapacity)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Fresh Water (\(unit(UnitIndex.fuel)))", data: $waterCapacity)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Gray Water (\(unit(UnitIndex.fuel)))", data: $grayCapacity)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Black Water (\(unit(UnitIndex.fuel)))", data: $blackCapacity)}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "MISCELLANEOUS")
						HStack{LabelDataTextview_Numberpad_Int(label: "Purchase Price", data: $price)}
						HStack{LabelDataTextview(label: "Place Purchased", data: $placePurchased)}
						HStack{LabelDataPicker_Date(label: "Date Purchased", data: $datePurchased)}
						HStack{LabelDataTextview(label: "Owner", data: $ownerId)}
						HStack{LabelDataTextview(label: "Location", data: $locationId)}
					}
				}
						
				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "VEHICLE NOTES", prompt: "Enter notes...", data: $notes)
				}
				
				CardView {
					VStack {
						SectionText(label: "INSURANCE INFORMATION")
						HStack{LabelDataTextview(label: "Provider", data: $insuranceCompany)}
						HStack{LabelDataTextview(label: "Policy #", data: $insurancePolicyNumber)}
						HStack{LabelDataTextview(label: "Policy Holder", data: $insurancePolicyHolder)}
						HStack{LabelDataPicker_Date(label: "Expiration", data: $insuranceExpiration)}
					}
				}
						
				CardView {
					VStack {
						SectionText(label: "ONLINE SERVICE (OnStar...)")
						HStack{LabelDataTextview(label: "Provider", data: $onlineServiceProvider)}
						HStack{LabelDataTextview(label: "Number", data: $onlineServiceNumber)}
						HStack{LabelDataTextview(label: "URL", data: $onlineServiceURL)}
						HStack{LabelDataTextview(label: "Login/Password", data: $onlineServiceLogin)}
						HStack{LabelDataTextview(label: "Billing Account", data: $onlineServiceBillingAccount)}
						HStack{LabelDataTextview(label: "Vehicle Mobile #", data: $vehicleMobileNumber)}
					}
				}

				CardView {
					VStack {
#if os(macOS)
						SectionText(label: "VEHICLE GRAPHICS")
#elseif os(iOS)
						SectionText(label: "  VEHICLE GRAPHICS\n(Click Image to Change)")
#endif
						HStack {Image_Edit(label: "1", imageData: $image1, imageDescription: $image1Description)}
						HStack {Image_Edit(label: "2", imageData: $image2, imageDescription: $image2Description)}
						HStack {Image_Edit(label: "3", imageData: $image3, imageDescription: $image3Description)}
					}
				}
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Vehicle Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

			}
			.onAppear {
				loadUnits()
				recomputeNextDue()
			}
			.onChange(of: mileage) { _, _ in recomputeNextDue() }
			.onChange(of: engHours) { _, _ in recomputeNextDue() }
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			// title area
			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: trackVehicleSelected)
			}

			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						isEditing.toggle()
						updateItem()}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
				}
			}//end of form/list
			
			
		} else {
			
			// display data
			ScrollView {
				VStack{CreatedUpdatedText(created: createdAt, updated: updatedAt)}
				CardView {
					VStack {
						SectionText(label: "GENERAL INFORMATION")
							.onAppear {
								// set selection for parent views that track it
								trackVehicleSelected = dataSet.name
							}
						
						HStack{LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active")}
						HStack{LabelDataText(label: "Vehicle Name", data: "\(dataSet.name)")}
						HStack{LabelDataText(label: "Model Year", data: "\(functions.formatYear(year: dataSet.year))")}
						HStack{LabelDataText(label: "Manufacturer", data: "\(dataSet.manufacturer)")}
						HStack{LabelDataText(label: "Model", data: "\(dataSet.model)")}
						HStack{LabelDataText(label: "Trim Level", data: "\(dataSet.trim)")}
						if dataSet.vin != "" {
							HStack{LabelDataText(label: "VIN", data: "\(dataSet.vin)")}
						}
						if dataSet.titleNumber != "" {
							HStack{LabelDataText(label: "Title Number", data: "\(dataSet.titleNumber)")}
						}
						if dataSet.licensePlate != "" {
							HStack{LabelDataText(label: "Plate Number", data: "\(dataSet.licensePlate)")}
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "MECHANICAL DETAILS")
						if dataSet.fuelType != "" {
							HStack{LabelDataText(label: "Fuel Type", data: "\(dataSet.fuelType)")}
						}
						if dataSet.engine != "" {
							HStack{LabelDataText(label: "Engine", data: "\(dataSet.engine)")}
						}
						if dataSet.transmission != "" {
							HStack{LabelDataText(label: "Transmission", data: "\(dataSet.transmission)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "VEHICLE DETAILS")
						if dataSet.mileage > 0 {
							HStack{LabelDataText(label: "Odometer", data: "\(dataSet.mileage) \(unit(UnitIndex.distance))")}
						}
						if dataSet.mileageVirtual > 0 {
							HStack{LabelDataText(label: "Odometer (Virtual)", data: "\(dataSet.mileageVirtual) \(unit(UnitIndex.distance))")}
						}
						if dataSet.engHours > 0 {
							HStack{LabelDataText(label: "Current Engine Hours", data: "\(dataSet.engHours) hrs")}
						}
						if dataSet.doors > 0 {
							HStack{LabelDataText(label: "Doors", data: "\(dataSet.doors)")}
						}
						if dataSet.seats > 0 {
							HStack{LabelDataText(label: "Seats", data: "\(dataSet.seats)")}
						}
					}
				}

				// NEW: Next Service Due (Details mode)
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						SectionText(label: "NEXT SERVICE DUE")
						if nextTwoDue.isEmpty {
							Text("No upcoming service items found.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(nextTwoDue) { due in
								VStack(alignment: .leading, spacing: 4) {
									Text(due.itemName).font(.subheadline).bold()
									if !due.itemDescription.isEmpty {
										Text(due.itemDescription).font(.caption).foregroundStyle(.secondary)
									}
									HStack(spacing: 12) {
										if due.intervalMiles > 0, let rm = due.remainingMiles {
											Text("Miles: \(max(0, rm)) \(unit(UnitIndex.distance))").font(.caption)
										}
										if due.intervalHours > 0, let rh = due.remainingHours {
											Text(String(format: "Hours: %.1f", max(0, rh))).font(.caption)
										}
										if due.intervalMonths > 0, let rd = due.remainingDays {
											Text("Days: \(max(0, rd))").font(.caption)
										}
									}
									if let d = due.dueDate {
										Text("Est. next due: \(functions.formatDate_DDMMMyy(date: d))")
											.font(.caption2)
											.foregroundStyle(.secondary)
									}
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TIRE INFORMATION")
						if dataSet.tireSize != "" {
							HStack{LabelDataText(label: "Make/Model/Size", data: "\(dataSet.tireSize)")}
						}
						if dataSet.tirePressureFront > 0 {
							HStack{LabelDataText(label: "Pressure Front", data: "\(dataSet.tirePressureFront) \(unit(UnitIndex.pressure))")}
						}
						if dataSet.tirePressureRear > 0 {
							HStack{LabelDataText(label: "Pressure Rear", data: "\(dataSet.tirePressureRear) \(unit(UnitIndex.pressure))")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "DIMENSIONS")
						if dataSet.wheelbase > 0 {
							HStack{LabelDataText(label: "Wheelbase", data: "\(dataSet.wheelbase) \(unit(UnitIndex.wheelBase))")}
						}
						if dataSet.length > 0 {
							HStack{LabelDataText(label: "Length", data: "\(dataSet.length) \(unit(UnitIndex.length))")}
						}
						if dataSet.width > 0 {
							HStack{LabelDataText(label: "Width", data: "\(dataSet.width) \(unit(UnitIndex.width))")}
						}
						if dataSet.height > 0 {
							HStack{LabelDataText(label: "Height", data: "\(dataSet.height) \(unit(UnitIndex.height))")}
						}
						if dataSet.cargoSpace > 0 {
							HStack{LabelDataText(label: "Cargo Space", data: "\(dataSet.cargoSpace) \(unit(UnitIndex.area))")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "WEIGHT DATA")
						if dataSet.weight > 0 {
							HStack{LabelDataText(label: "Vehicle Weight", data: "\(dataSet.weight) \(unit(UnitIndex.mass))")}
							HStack{LabelDataText(label: "Date Weighed", data: "\(functions.formatDate_DDMMMyy(date:dataSet.dateWeighed))")}
						}
						if dataSet.gvwr > 0 {
							HStack{LabelDataText(label: "GVWR", data: "\(dataSet.gvwr) \(unit(UnitIndex.mass))")}
						}
						if dataSet.gcwr > 0 {
							HStack{LabelDataText(label: "GCWR", data: "\(dataSet.gcwr) \(unit(UnitIndex.mass))")}
						}
						if dataSet.gawrFront > 0 {
							HStack{LabelDataText(label: "GAWR Front", data: "\(dataSet.gawrFront) \(unit(UnitIndex.mass))")}
						}
						if dataSet.gawrRear > 0 {
							HStack{LabelDataText(label: "GAWR Rear", data: "\(dataSet.gawrRear) \(unit(UnitIndex.mass))")}
						}
						if dataSet.towingCapcity > 0 {
							HStack{LabelDataText(label: "Towing Capacity", data: "\(dataSet.towingCapcity) \(unit(UnitIndex.mass))")}
						}
						if dataSet.uvw > 0 {
							HStack{LabelDataText(label: "UVW", data: "\(dataSet.uvw) \(unit(UnitIndex.mass))")}
						}
						if dataSet.ccc > 0 {
							HStack{LabelDataText(label: "CCC", data: "\(dataSet.ccc) \(unit(UnitIndex.mass))")}
						}
						if dataSet.availablePayload > 0 {
							HStack{LabelDataText(label: "Payload", data: "\(dataSet.availablePayload) \(unit(UnitIndex.mass))")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "CAPACITIES")
						if dataSet.fuelCapacity > 0 {
							HStack{LabelDataText(label: "Fuel", data: "\(dataSet.fuelCapacity) \(unit(UnitIndex.fuel))")}
						}
						if dataSet.defCapacity > 0 {
							HStack{LabelDataText(label: "DEF", data: "\(dataSet.defCapacity) \(unit(UnitIndex.def))")}
						}
						if dataSet.waterCapacity > 0 {
							HStack{LabelDataText(label: "Fresh Water", data: "\(dataSet.waterCapacity) \(unit(UnitIndex.fuel))")}
						}
						if dataSet.grayCapacity > 0 {
							HStack{LabelDataText(label: "Gray Water", data: "\(dataSet.grayCapacity) \(unit(UnitIndex.fuel))")}
						}
						if dataSet.blackCapacity > 0 {
							HStack{LabelDataText(label: "Black Water", data: "\(dataSet.blackCapacity) \(unit(UnitIndex.fuel))")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "MISCELLANEOUS")
						if dataSet.price > 0 {
							HStack{LabelDataCurrency(label: "Purchase price", data: Float(dataSet.price), unit: "")}
						}
						if dataSet.placePurchased != "" {
							HStack{LabelDataText(label: "Place Purchased", data: "\(dataSet.placePurchased)")}
						}
						// Show date purchased if set (not just based on placePurchased)
						HStack{LabelDataText(label: "Date Purchased", data: "\(functions.formatDate_DDMMMyy(date:dataSet.datePurchased))")}
						if dataSet.ownerId != "" {
							HStack{LabelDataText(label: "Owner", data: "\(dataSet.ownerId)")}
						}
						if dataSet.locationId != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationId)")}
						}
					}
				}
				
				if dataSet.notes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "VEHICLE NOTES", data: dataSet.notes)}
				}

				CardView {
					VStack {
						SectionText(label: "INSURANCE INFORMATION")
						if dataSet.insuranceCompany != "" {
							HStack{LabelDataText(label: "Provider", data: "\(dataSet.insuranceCompany)")}
						}
						if dataSet.insurancePolicyNumber != "" {
							HStack{LabelDataText(label: "Policy #", data: "\(dataSet.insurancePolicyNumber)")}
						}
						if dataSet.insurancePolicyHolder != "" {
							HStack{LabelDataText(label: "Place Holder", data: "\(dataSet.insurancePolicyHolder)")}
						}
						if dataSet.insuranceCompany != "" {
							HStack{LabelDataText(label: "Expiration", data: "\(functions.formatDate_DDMMMyy(date:dataSet.insuranceExpiration))")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "ONLINE SERVICE (OnStar...)")
						if dataSet.onlineServiceProvider != "" {
							HStack{LabelDataText(label: "Provider", data: "\(dataSet.onlineServiceProvider)")}
						}
						if dataSet.onlineServiceNumber != "" {
							HStack{LabelDataText(label: "Number", data: "\(dataSet.onlineServiceNumber)")}
						}
						if dataSet.onlineServiceURL != "" {
							HStack{LabelDataText(label: "URL", data: "\(dataSet.onlineServiceURL)")}
						}
						if dataSet.onlineServiceLogin != "" {
							HStack{LabelDataText(label: "Login/Password", data: "\(dataSet.onlineServiceLogin)")}
						}
						if dataSet.onlineServiceBillingAccount != "" {
							HStack{LabelDataText(label: "Billing Account", data: "\(dataSet.onlineServiceBillingAccount)")}
						}
						if dataSet.vehicleMobileNumber != "" {
							HStack{LabelDataText(label: "Vehicle Mobile #", data: "\(dataSet.vehicleMobileNumber)")}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "VEHICLE GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
				}
				
			}//end of list
			.onAppear {
				loadUnits()
				recomputeNextDue()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			// implementation of persistant titles at top of page
				.safeAreaInset(edge: .top) {
					PageTitle_Col3_Photo(
						label: "",
						action: "details",
						dbRecord: trackVehicleSelected)
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
						Button("Delete?", role: .destructive) {
							DeleteRecord()
						}
						Button("Deactivate?") {
							makeInactive()
						}
					} message: {
						Text("Confirm either deletion or deactivation of this record.  Deactivated records will still be available for reference, but will not be included in any reports or calculations.")
					}
					.buttonStyle(GrowingButton(buttonColor: Color.gray))
				}
			}
		}
	}

	/// Permanently deletes the current Vehicle8 record from the model context.
	/// Uses a destructive operation and dismisses the view on success.
	/// Errors are printed to the console for diagnostics.
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {
			print(error.localizedDescription)
		}
		dismiss()
	}
	/// Soft-deletes the record by marking it inactive and updating `updatedAt`.
	/// Saves the change and then dismisses the view.
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

	/// Writes all editable @State fields back into the bound Vehicle8 model and saves.
	/// Also updates `updatedAt` to the current time.
	///
	/// This method intentionally performs a field-by-field assignment so that the UI state
	/// is the single source of truth during editing. On successful save, the Details view
	/// reflects the new values.
	private func updateItem() {
		dataSet.inactive = inactive
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.name = name
		dataSet.manufacturer = manufacturer
		dataSet.model = model
		dataSet.trim = trim
		dataSet.year = year
		dataSet.mileage = mileage
		dataSet.mileageVirtual = mileageVirtual
		dataSet.engHours = engHours
		dataSet.transmission = transmission
		dataSet.engine = engine
		dataSet.fuelType = fuelType
		dataSet.doors = doors
		dataSet.seats = seats
		dataSet.cargoSpace = cargoSpace
		dataSet.length = length
		dataSet.width = width
		dataSet.height = height
		dataSet.weight = weight
		dataSet.dateWeighed = dateWeighed
		dataSet.wheelbase = wheelbase
		dataSet.gvwr = gvwr
		dataSet.gcwr = gcwr
		dataSet.gawrFront = gawrFront
		dataSet.gawrRear = gawrRear
		dataSet.towingCapcity = towingCapcity
		dataSet.uvw = uvw
		dataSet.ccc = ccc
		dataSet.fuelCapacity = fuelCapacity
		dataSet.defCapacity = defCapacity
		dataSet.waterCapacity = waterCapacity
		dataSet.grayCapacity = grayCapacity
		dataSet.blackCapacity = blackCapacity
		dataSet.imageUrl = imageUrl
		dataSet.price = price
		dataSet.notes = notes
		dataSet.ownerId = ownerId
		dataSet.locationId = locationId
		dataSet.vin = vin
		dataSet.licensePlate = licensePlate
		dataSet.datePurchased = datePurchased
		dataSet.placePurchased = placePurchased
		dataSet.tireSize = tireSize
		dataSet.titleNumber = titleNumber
		dataSet.onlineServiceProvider = onlineServiceProvider
		dataSet.onlineServiceNumber = onlineServiceNumber
		dataSet.onlineServiceLogin = onlineServiceLogin
		dataSet.onlineServiceURL = onlineServiceURL
		dataSet.onlineServiceBillingAccount = onlineServiceBillingAccount
		dataSet.vehicleMobileNumber = vehicleMobileNumber
		dataSet.insuranceCompany = insuranceCompany
		dataSet.insurancePolicyNumber = insurancePolicyNumber
		dataSet.insurancePolicyHolder = insurancePolicyHolder
		dataSet.insuranceExpiration = insuranceExpiration
		dataSet.tirePressureFront = tirePressureFront
		dataSet.tirePressureRear = tirePressureRear
		dataSet.tirePressureTag = tirePressureTag
		dataSet.tirePressurePusher = tirePressurePusher
		dataSet.availablePayload = availablePayload
		
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

	// MARK: - Next Service Due (per-vehicle computation)
	/// Recomputes the next two maintenance items due for this vehicle.
	///
	/// Algorithm overview:
	/// 1. Fetch all MxItems3 scoped to this vehicle (`vehicleId == dataSet.name`).
	/// 2. For each item, fetch the most recent ServiceRecords1 for this vehicle+item.
	/// 3. Compute miles/hours since last service and time-based due date if intervalMonths > 0.
	/// 4. Calculate remaining miles/hours/days and derive a ranking score (lower is more urgent).
	/// 5. Sort by score, then by nearest due date, then by remaining miles/hours as tiebreakers.
	/// 6. Keep only the top two and publish to `nextTwoDue` for display in both modes.
	///
	/// Side effects: Updates the `nextTwoDue` state array, which is rendered in UI cards.
	private func recomputeNextDue() {
		// Capture plain values for use inside #Predicate
		let vehicleId = dataSet.name

		// Fetch service items scoped to this vehicle
		let fd = FetchDescriptor<MxItems3>(predicate: #Predicate { $0.vehicleId == vehicleId })
		do {
			let items = try modelContext.fetch(fd)
			var computed: [UpcomingDue] = []
			for item in items {
				guard item.intervalMiles > 0 || item.intervalHours > 0 || item.intervalMonths > 0 else { continue }

				let currentMiles = mileage
				let currentHours = engHours

				// Last service record for this vehicle+item
				var lastDate: Date? = nil
				var lastMiles: Int = 0
				var lastHours: Float = 0.0
				do {
					// Capture values needed inside the predicate
					let mxName = item.mxName
					let vId = vehicleId
					var fdRec = FetchDescriptor<ServiceRecords1>(
						predicate: #Predicate { $0.vehicleId == vId && $0.mxName == mxName },
						sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
					)
					fdRec.fetchLimit = 1
					if let rec = try modelContext.fetch(fdRec).first {
						lastDate = rec.mxDate
						lastMiles = rec.Miles
						lastHours = rec.engHours
					}
				} catch {
					// ignore
				}

				// Since-service
				let milesSince = (lastMiles > 0 && currentMiles >= lastMiles) ? (currentMiles - lastMiles) : 0
				let hoursSince = (lastHours > 0 && currentHours >= lastHours) ? (currentHours - lastHours) : 0

				// Remaining
				let remainingMiles: Int? = item.intervalMiles > 0 ? max(0, item.intervalMiles - milesSince) : nil
				let remainingHours: Float? = item.intervalHours > 0 ? max(0, item.intervalHours - hoursSince) : nil

				// Time-based due
				var dueDate: Date? = nil
				var remainingDays: Int? = nil
				if item.intervalMonths > 0 {
					let anchor = lastDate ?? item.createdAt
					if let d = Calendar(identifier: .gregorian).date(byAdding: .month, value: item.intervalMonths, to: anchor) {
						dueDate = d
						let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: d).day ?? 0
						remainingDays = max(0, days)
					}
				}

				// Ranking score
				var factors: [Double] = []
				if let rm = remainingMiles, item.intervalMiles > 0 {
					factors.append(Double(rm) / Double(item.intervalMiles))
				}
				if let rh = remainingHours, item.intervalHours > 0 {
					factors.append(Double(rh) / Double(item.intervalHours))
				}
				if let rd = remainingDays, item.intervalMonths > 0 {
					let totalDays = max(1, item.intervalMonths * 30)
					factors.append(Double(rd) / Double(totalDays))
				}
				guard !factors.isEmpty else { continue }
				let score = factors.min() ?? 1.0

				let due = UpcomingDue(
					itemName: item.mxName,
					itemDescription: item.mxDescription,
					intervalMiles: item.intervalMiles,
					intervalHours: item.intervalHours,
					intervalMonths: item.intervalMonths,
					remainingMiles: remainingMiles,
					remainingHours: remainingHours,
					remainingDays: remainingDays,
					dueDate: dueDate,
					score: score
				)
				computed.append(due)
			}
			computed.sort {
				if $0.score != $1.score { return $0.score < $1.score }
				if let d0 = $0.dueDate, let d1 = $1.dueDate, d0 != d1 { return d0 < d1 }
				let m0 = $0.remainingMiles ?? Int.max
				let m1 = $1.remainingMiles ?? Int.max
				if m0 != m1 { return m0 < m1 }
				let h0 = $0.remainingHours ?? Float.greatestFiniteMagnitude
				let h1 = $1.remainingHours ?? Float.greatestFiniteMagnitude
				return h0 < h1
			}
			self.nextTwoDue = Array(computed.prefix(2))
		} catch {
			self.nextTwoDue = []
		}
	}
}

/// Safe indexing helper to avoid out-of-bounds access when reading unit strings or other arrays.
/// Returns `nil` for invalid indices instead of trapping.
private extension Array {
	subscript(safe index: Int) -> Element? {
		if indices.contains(index) {
			return self[index]
		} else {
			return nil
		}
	}
}

// MARK: - Previews
// The previews construct in-memory ModelContainers to showcase both populated and empty samples.
#Preview("EditVehicle - Populated Sample") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, configurations: config)

	let now = Date()
	let sample: Vehicle8 = Vehicle8(
		name: "Family SUV",
		manufacturer: "Subaru",
		model: "Outback",
		year: Calendar.current.component(.year, from: now) - 2,
		trim: "Premium",
		mileage: 24500,
		transmission: "CVT",
		engine: "2.5L",
		fuelType: "Gasoline",
		doors: 4,
		seats: 5,
		cargoSpace: 32,
		length: 190,
		width: 73,
		height: 66,
		weight: 3600,
		imageUrl: "",
		price: 32000,
		notes: "Primary family car",
		createdAt: now,
		updatedAt: now,
		ownerId: "Me",
		locationId: "Home",
		vin: "VIN1234567890",
		licensePlate: "ABC-123",
		image1: (nil as Data?),
		image1Description: "",
		image2: (nil as Data?),
		image2Description: "",
		image3: (nil as Data?),
		image3Description: ""
	)
	container.mainContext.insert(sample)

	return NavigationStack {
		EditVehicle(dataSet: sample, trackVehicleSelected: .constant(sample.name))
	}
	.modelContainer(container)
}

#Preview("EditVehicle - Empty Sample") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, configurations: config)

	// Create a minimal sample vehicle (defaults fill the rest)
	let sample: Vehicle8 = Vehicle8(
		name: "Preview Vehicle",
		manufacturer: "Make",
		model: "Model",
		year: Calendar.current.component(.year, from: Date()),
		trim: "Trim",
		mileage: 12345,
		transmission: "Automatic",
		engine: "2.0L",
		fuelType: "Gasoline",
		doors: 4,
		seats: 5,
		cargoSpace: 20,
		length: 0,
		width: 0,
		height: 0,
		weight: 0,
		imageUrl: "",
		price: 0,
		notes: "",
		createdAt: Date(),
		updatedAt: Date(),
		ownerId: "",
		locationId: "",
		vin: "VINPREVIEW123",
		licensePlate: "PVW-001",
		image1: (nil as Data?),
		image1Description: "",
		image2: (nil as Data?),
		image2Description: "",
		image3: (nil as Data?),
		image3Description: ""
	)
	container.mainContext.insert(sample)

	return NavigationStack {
		EditVehicle(dataSet: sample, trackVehicleSelected: .constant(sample.name))
	}
	.modelContainer(container)
}


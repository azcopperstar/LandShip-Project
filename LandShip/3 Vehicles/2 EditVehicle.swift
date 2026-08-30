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
	/// The vehicle's name as of the last save, used to detect renames and to know which
	/// old value to search for when updating other records that reference this vehicle by name.
	@State private var originalName: String = ""
	@State private var showingRenameChoice: Bool = false
	/// True until this vehicle's first successful save. Suppresses the rename-warning dialog
	/// on a brand-new record's initial save, since nothing can yet reference its placeholder name.
	@State private var isNewUnsavedRecord: Bool = false
	@State private var nameValidationError: String? = nil
	@State private var manufacturer: String = ""
	@State private var model: String = ""
	@State private var year: Int = 0
	@State private var trim: String = ""
	@State private var mileage: Int = 0
	@State private var mileageVirtual: Int = 0
	@State private var engHours: Float = 0.0
	@State private var transmission: String = ""
	@State private var engine: String = ""
	@State private var engineSerialNumber: String = ""
	@State private var transmissionSerialNumber: String = ""
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
	
	@State private var warranties: [VehicleWarranty] = []
	@State private var warrantyToEdit: VehicleWarranty? = nil
	@State private var showingAddWarranty: Bool = false
	@State private var scaleTickets: [VehicleScaleTicket] = []
	@State private var showingAddScaleTicket: Bool = false
	@State private var scaleTicketToEdit: VehicleScaleTicket? = nil

	@State private var serialItems: [VehicleSerialItem] = []
	@State private var showingAddSerialItem: Bool = false
	@State private var newSerialItemName: String = ""
	@State private var newSerialItemSerial: String = ""
	@State private var editingSerialItem: VehicleSerialItem? = nil
	@State private var editSerialItemName: String = ""
	@State private var editSerialItemSerial: String = ""
	
	@State private var tirePressureFront: Int = 0
	@State private var tirePressureRear: Int = 0
	@State private var tirePressureTag: Int = 0
	@State private var tirePressurePusher: Int = 0
	@State private var wheelStudSize: String = ""
	@State private var wheelNutSocket: String = ""
	@State private var wheelNutTorque: String = ""
	@State private var availablePayload: Int = 0
	@State private var scaleWeightFrontAxle: Int = 0
	@State private var scaleWeightRearAxle: Int = 0
	@State private var scaleWeightPusherAxle: Int = 0
	@State private var scaleWeightTagAxle: Int = 0
	@State private var scaleWeightTrailerAxle: Int = 0
	
	@State private var image1: Data?
	@State private var image2: Data?
	@State private var image3: Data?
	@State private var image1Description: String = ""
	@State private var image2Description: String = ""
	@State private var image3Description: String = ""

	// MARK: - Linked Vehicle Records
	@State private var linkedMasterVehicleId: String = ""
	@State private var vehicleAspect: String = ""
	@State private var linkedSyncFields: Set<LinkableVehicleField> = []
	@State private var showingLinkedFieldsPicker: Bool = false
	@State private var allVehiclesForLinking: [Vehicle8] = []
	@State private var linkedAspectVehicles: [Vehicle8] = []
	@State private var masterVehicle: Vehicle8? = nil

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
	
	init(dataSet: Vehicle8, trackVehicleSelected: Binding<String>, startEditing: Bool = false, isNewRecord: Bool = false) {
		// Properly initialize @State
		self._dataSet = State(initialValue: dataSet)
		self._trackVehicleSelected = trackVehicleSelected

		self._inactive = State.init(initialValue: dataSet.inactive)
		// A brand-new record's `name` is a throwaway UUID (used only as a unique placeholder
		// key) - show a blank field with a "(New Vehicle)" prompt instead of that UUID.
		self._name = State.init(initialValue: isNewRecord ? "" : dataSet.name)
		self._originalName = State.init(initialValue: dataSet.name)
		self._isNewUnsavedRecord = State.init(initialValue: isNewRecord)
		self._manufacturer = State.init(initialValue: dataSet.manufacturer)
		self._model = State.init(initialValue: dataSet.model)
		self._year = State.init(initialValue: dataSet.year)
		self._trim = State.init(initialValue: dataSet.trim)
		self._mileage = State.init(initialValue: dataSet.mileage)
		self._mileageVirtual = State.init(initialValue: dataSet.mileageVirtual)
		self._engHours = State.init(initialValue: Float(dataSet.engHours))
		self._transmission = State.init(initialValue: dataSet.transmission)
		self._engine = State.init(initialValue: dataSet.engine)
		self._engineSerialNumber = State.init(initialValue: dataSet.engineSerialNumber)
		self._transmissionSerialNumber = State.init(initialValue: dataSet.transmissionSerialNumber)
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
		self._wheelStudSize = State.init(initialValue: dataSet.wheelStudSize)
		self._wheelNutSocket = State.init(initialValue: dataSet.wheelNutSocket)
		self._wheelNutTorque = State.init(initialValue: dataSet.wheelNutTorque)
		self._availablePayload = State.init(initialValue: dataSet.availablePayload)
		self._scaleWeightFrontAxle = State.init(initialValue: dataSet.scaleWeightFrontAxle)
		self._scaleWeightRearAxle = State.init(initialValue: dataSet.scaleWeightRearAxle)
		self._scaleWeightPusherAxle = State.init(initialValue: dataSet.scaleWeightPusherAxle)
		self._scaleWeightTagAxle = State.init(initialValue: dataSet.scaleWeightTagAxle)
		self._scaleWeightTrailerAxle = State.init(initialValue: dataSet.scaleWeightTrailerAxle)
		
		self._image1 = State.init(initialValue: dataSet.image1)
		self._image2 = State.init(initialValue: dataSet.image2)
		self._image3 = State.init(initialValue: dataSet.image3)
		self._image1Description = State.init(initialValue: dataSet.image1Description)
		self._image2Description = State.init(initialValue: dataSet.image2Description)
		self._image3Description = State.init(initialValue: dataSet.image3Description)

		self._linkedMasterVehicleId = State.init(initialValue: dataSet.linkedMasterVehicleId)
		self._vehicleAspect = State.init(initialValue: dataSet.vehicleAspect)
		self._linkedSyncFields = State.init(initialValue: dataSet.linkedSyncFields)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}

	// MARK: - Details section visibility
	// Card sections in Details mode are only rendered when at least one of their
	// fields holds data, so a section title never appears above an empty card.
	// Sections that show an explicit "none recorded" message (Next Service Due,
	// Warranties, Scale Tickets) always remain visible.

	/// True when any mechanical field has data.
	private var hasMechanicalDetails: Bool {
		!(dataSet.fuelType.isEmpty
		  && dataSet.engine.isEmpty
		  && dataSet.transmission.isEmpty
		  && dataSet.engineSerialNumber.isEmpty
		  && dataSet.transmissionSerialNumber.isEmpty)
	}

	/// True when any usage/occupancy figure was entered.
	private var hasVehicleDetails: Bool {
		dataSet.mileage > 0
			|| dataSet.mileageVirtual > 0
			|| dataSet.engHours > 0
			|| dataSet.doors > 0
			|| dataSet.seats > 0
	}

	/// True when any tire or wheel field has data.
	private var hasTireInformation: Bool {
		!dataSet.tireSize.isEmpty
			|| dataSet.tirePressureFront > 0
			|| dataSet.tirePressureRear > 0
			|| !dataSet.wheelStudSize.isEmpty
			|| !dataSet.wheelNutSocket.isEmpty
			|| !dataSet.wheelNutTorque.isEmpty
	}

	/// True when any dimension was entered.
	private var hasDimensions: Bool {
		dataSet.wheelbase > 0
			|| dataSet.length > 0
			|| dataSet.width > 0
			|| dataSet.height > 0
			|| dataSet.cargoSpace > 0
	}

	/// True when any weight rating or scale reading was entered.
	private var hasWeightData: Bool {
		dataSet.weight > 0
			|| dataSet.gvwr > 0
			|| dataSet.gcwr > 0
			|| dataSet.gawrFront > 0
			|| dataSet.gawrRear > 0
			|| dataSet.towingCapcity > 0
			|| dataSet.uvw > 0
			|| dataSet.ccc > 0
			|| dataSet.availablePayload > 0
			|| dataSet.scaleWeightFrontAxle > 0
			|| dataSet.scaleWeightRearAxle > 0
			|| dataSet.scaleWeightPusherAxle > 0
			|| dataSet.scaleWeightTagAxle > 0
			|| dataSet.scaleWeightTrailerAxle > 0
	}

	/// True when any tank capacity was entered.
	private var hasCapacities: Bool {
		dataSet.fuelCapacity > 0
			|| dataSet.defCapacity > 0
			|| dataSet.waterCapacity > 0
			|| dataSet.grayCapacity > 0
			|| dataSet.blackCapacity > 0
	}

	/// True when any insurance field has data.
	private var hasInsuranceInformation: Bool {
		!(dataSet.insuranceCompany.isEmpty
		  && dataSet.insurancePolicyNumber.isEmpty
		  && dataSet.insurancePolicyHolder.isEmpty)
	}

	/// True when any online service field has data.
	private var hasOnlineService: Bool {
		!(dataSet.onlineServiceProvider.isEmpty
		  && dataSet.onlineServiceNumber.isEmpty
		  && dataSet.onlineServiceURL.isEmpty
		  && dataSet.onlineServiceLogin.isEmpty
		  && dataSet.onlineServiceBillingAccount.isEmpty
		  && dataSet.vehicleMobileNumber.isEmpty)
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
	}

	var body: some View {
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL INFORMATION")
						HStack{LabelDataTextview(label: "Name", data: $name, prompt: "(New Vehicle)")}
							.onChange(of: name) { _, _ in nameValidationError = nil }
						if let nameValidationError {
							HStack(alignment: .top, spacing: 6) {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundStyle(.red)
								Text(nameValidationError)
									.font(.caption)
									.foregroundStyle(.red)
							}
						} else if !isNewUnsavedRecord, name != originalName, !originalName.isEmpty {
							HStack(alignment: .top, spacing: 6) {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundStyle(.orange)
								Text("Changing this name will break links to this vehicle's Fuel Log, Trip Log, Service Records, Parts, Maintenance Items, Systems, Additions, Subscriptions, Projects, CheckLists, Warranties, Serial Items, Scale Tickets, and any linked vehicle records — unless you choose to update them when you save.")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
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
						SectionText(label: "COMPONENT SERIAL NUMBERS")
						HStack {
							Text("Add Component")
								.textLabelModified()
							Spacer()
							Button { showingAddSerialItem.toggle() } label: {
								Image(systemName: "plus.capsule")
							}
						}
						if showingAddSerialItem {
							HStack{LabelDataTextview(label: "Component Name", data: $newSerialItemName)}
							HStack{LabelDataTextview(label: "Serial Number", data: $newSerialItemSerial)}
							HStack {
								Spacer()
								Button("Add Item") {
									let item = VehicleSerialItem(
										vehicleId: dataSet.name,
										itemName: newSerialItemName,
										serialNumber: newSerialItemSerial
									)
									modelContext.insert(item)
									try? modelContext.save()
									newSerialItemName = ""
									newSerialItemSerial = ""
									showingAddSerialItem = false
									loadSerialItems()
								}
								.buttonStyle(.bordered)
								.disabled(newSerialItemName.isEmpty)
							}
						}
						ForEach(serialItems) { item in
							if editingSerialItem === item {
								HStack{LabelDataTextview(label: "Component Name", data: $editSerialItemName)}
								HStack{LabelDataTextview(label: "Serial Number", data: $editSerialItemSerial)}
								HStack {
									Spacer()
									Button("Save") {
										item.itemName = editSerialItemName
										item.serialNumber = editSerialItemSerial
										try? modelContext.save()
										editingSerialItem = nil
										loadSerialItems()
									}
									.buttonStyle(.bordered)
									.disabled(editSerialItemName.isEmpty)
									Button("Cancel") { editingSerialItem = nil }
										.buttonStyle(.bordered)
								}
								Divider()
							} else {
								HStack {
									VStack(alignment: .leading, spacing: 2) {
										Text(item.itemName).font(.subheadline)
										Text(item.serialNumber).font(.caption).foregroundStyle(.secondary)
									}
									Spacer()
									Button {
										editSerialItemName = item.itemName
										editSerialItemSerial = item.serialNumber
										editingSerialItem = item
										showingAddSerialItem = false
									} label: {
										Image(systemName: "pencil.circle").imageScale(.large)
									}
									.buttonStyle(.plain)
									Button {
										modelContext.delete(item)
										try? modelContext.save()
										loadSerialItems()
									} label: {
										Image(systemName: "trash").foregroundStyle(.red)
									}
									.buttonStyle(.plain)
								}
								.padding(.vertical, 2)
								Divider()
							}
						}
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
						HStack{LabelDataTextview(label: "Engine Serial #", data: $engineSerialNumber)}
						HStack{LabelDataTextview(label: "Transmission", data: $transmission)}
						HStack{LabelDataTextview(label: "Trans. Serial #", data: $transmissionSerialNumber)}
					}
				}
		
				CardView {
					VStack {
						SectionText(label: "VEHICLE DETAILS")
						if linkedSyncFields.contains(.odometer), let master = masterVehicle {
							HStack{LabelDataText(label: "Odometer (synced w/ master)", data: "\(master.mileage) \(unit(UnitIndex.distance))")}
						} else {
							HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $mileage)}
							HStack{LabelDataTextview_Numberpad_Int(label: "Odometer (Virtual)", data: $mileageVirtual)}
						}
						if linkedSyncFields.contains(.engineHours), let master = masterVehicle {
							HStack{LabelDataText(label: "Engine Hours (synced w/ master)", data: "\(master.engHours) hrs")}
						} else {
							HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours", data: $engHours)}
						}
						HStack{LabelDataTextview_Numberpad_Int(label: "Doors", data: $doors)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Seats", data: $seats)}
					}
				}

				// NEW: Linked Vehicle Records (Edit mode)
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						SectionText(label: "LINKED VEHICLE RECORDS")
						Text("Link separate vehicle records that represent different aspects of the same physical vehicle (e.g. Chassis, Engine, Body/House). One record is the master; linked records can mirror its odometer and engine hours.")
							.font(.caption)
							.foregroundStyle(.secondary)

						if !linkedAspectVehicles.isEmpty {
							Text("This is the master record for:")
								.font(.subheadline).bold()
							ForEach(linkedAspectVehicles) { child in
								HStack {
									VStack(alignment: .leading, spacing: 2) {
										Text(child.vehicleAspect.isEmpty ? child.name : child.vehicleAspect)
											.font(.subheadline)
										Text(child.name).font(.caption).foregroundStyle(.secondary)
									}
									Spacer()
								}
								.padding(.vertical, 2)
								Divider()
							}
							Text("A master record cannot also link to another vehicle's master.")
								.font(.caption)
								.foregroundStyle(.secondary)
						} else {
							HStack{LabelDataTextview(label: "Vehicle Aspect", data: $vehicleAspect)}
							HStack {
								Text("Master Vehicle")
									.textLabelModified()
								Picker("", selection: $linkedMasterVehicleId) {
									Text("None (Standalone)").tag("")
									ForEach(availableMasterCandidates) { v in
										Text(v.displayName.isEmpty ? v.name : v.displayName).tag(v.name)
									}
								}
								.pickerStyle(.automatic)
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
							if !linkedMasterVehicleId.isEmpty {
								Button {
									showingLinkedFieldsPicker = true
								} label: {
									HStack {
										Text("Synced Fields")
											.textLabelModified()
										Spacer()
										Text(linkedSyncFields.isEmpty ? "None Selected" : "\(linkedSyncFields.count) Selected")
											.foregroundStyle(.secondary)
										Image(systemName: "chevron.right")
											.font(.caption)
											.foregroundStyle(.secondary)
									}
								}
								.buttonStyle(.plain)
							}
						}
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
						HStack{LabelDataTextview(label: "Wheel Stud Size", data: $wheelStudSize)}
						HStack{LabelDataTextview(label: "Wheel Nut Socket", data: $wheelNutSocket)}
						HStack{LabelDataTextview(label: "Wheel Nut Torque", data: $wheelNutTorque)}
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
						SectionText(label: "SCALE WEIGHT READINGS")
						HStack{LabelDataTextview_Numberpad_Int(label: "Steer Axle (\(unit(UnitIndex.mass)))", data: $scaleWeightFrontAxle)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Drive Axle(s) (\(unit(UnitIndex.mass)))", data: $scaleWeightRearAxle)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Pusher Axle (\(unit(UnitIndex.mass)))", data: $scaleWeightPusherAxle)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Tag Axle (\(unit(UnitIndex.mass)))", data: $scaleWeightTagAxle)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Trailer Axle(s) (\(unit(UnitIndex.mass)))", data: $scaleWeightTrailerAxle)}
						let totalVehicleWt = scaleWeightFrontAxle + scaleWeightRearAxle + scaleWeightPusherAxle + scaleWeightTagAxle
						let totalRollingWt = totalVehicleWt + scaleWeightTrailerAxle
						if totalVehicleWt > 0 {
							HStack{LabelDataText(label: "Total Vehicle Weight", data: "\(totalVehicleWt) \(unit(UnitIndex.mass))")}
						}
						if totalRollingWt > 0 {
							HStack{LabelDataText(label: "Total Rolling Weight", data: "\(totalRollingWt) \(unit(UnitIndex.mass))")}
						}
						HStack {
							SectionText(label: "WEIGHT SCALE TICKETS")
							Spacer()
							Button {
								showingAddScaleTicket = true
							} label: {
								Image(systemName: "plus.capsule")
							}
						}
						if scaleTickets.isEmpty {
							Text("No scale tickets recorded.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(scaleTickets) { ticket in
								HStack(alignment: .top) {
									VStack(alignment: .leading, spacing: 2) {
										Text(functions.formatDate_DDMMMyy(date: ticket.date)).font(.subheadline).bold()
										if !ticket.location.isEmpty {
											Text(ticket.location).font(.caption).foregroundStyle(.secondary)
										}
										if ticket.grossWeight > 0 {
											Text("Gross: \(ticket.grossWeight) lbs").font(.caption)
										}
									}
									Spacer()
									Button {
										scaleTicketToEdit = ticket
									} label: {
										Image(systemName: "pencil.circle").imageScale(.large)
									}
									.buttonStyle(.plain)
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
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
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							SectionText(label: "WARRANTIES")
							Spacer()
							Button {
								showingAddWarranty = true
							} label: {
								Image(systemName: "plus.capsule")
							}
						}
						if warranties.isEmpty {
							Text("No warranties recorded.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(warranties) { w in
								HStack(alignment: .top) {
									VStack(alignment: .leading, spacing: 2) {
										Text(w.warrantyName).font(.subheadline).bold()
										if !w.warrantyType.isEmpty {
											Text(w.warrantyType).font(.caption).foregroundStyle(.blue)
										}
										if !w.warrantyProvider.isEmpty {
											Text(w.warrantyProvider).font(.caption).foregroundStyle(.secondary)
										}
										if w.warrantyLengthMonths > 0 {
											Text("\(w.warrantyLengthMonths) months").font(.caption).foregroundStyle(.secondary)
										}
										if w.warrantyMileageLimit > 0 {
											let miRemaining = w.warrantyMileageLimit - mileage
											Text(miRemaining > 0 ? "\(miRemaining) mi remaining" : "Mileage exceeded")
												.font(.caption)
												.foregroundStyle(warrantyMileageColor(remaining: miRemaining))
										}
										Text("Exp: \(functions.formatDate_DDMMMyy(date: w.warrantyExpirationDate))")
											.font(.caption).foregroundStyle(warrantyExpirationColor(date: w.warrantyExpirationDate))
									}
									Spacer()
									Button {
										warrantyToEdit = w
									} label: {
										Image(systemName: "pencil.circle").imageScale(.large)
									}
									.buttonStyle(.plain)
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
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
				// Keep the shared "currently viewed vehicle" binding in sync so the title bar
				// (PageTitle_Col3_Photo) reflects this record instead of whichever vehicle was
				// selected before - otherwise a newly created vehicle's edit screen would show
				// the previously selected vehicle's name in the title.
				trackVehicleSelected = dataSet.name
				loadUnits()
				recomputeNextDue()
				loadWarranties()
				loadSerialItems()
				loadScaleTickets()
				loadLinkedVehicles()
			}
			.onChange(of: mileage) { _, _ in recomputeNextDue() }
			.onChange(of: engHours) { _, _ in recomputeNextDue() }
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.sheet(isPresented: $showingAddWarranty, onDismiss: loadWarranties) {
				EditWarranty(vehicleId: dataSet.name)
			}
			.sheet(item: $warrantyToEdit, onDismiss: loadWarranties) { w in
				EditWarranty(vehicleId: dataSet.name, warranty: w)
			}
			.sheet(isPresented: $showingAddScaleTicket, onDismiss: { loadScaleTickets(); syncWeightsFromModel() }) {
				EditScaleTicket(vehicleId: dataSet.name)
			}
			.sheet(item: $scaleTicketToEdit, onDismiss: { loadScaleTickets(); syncWeightsFromModel() }) { ticket in
				EditScaleTicket(vehicleId: dataSet.name, ticket: ticket)
			}
			.sheet(isPresented: $showingLinkedFieldsPicker) {
				LinkedFieldsPickerSheet(selection: $linkedSyncFields)
			}

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
						let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
						guard !trimmedName.isEmpty else {
							nameValidationError = "Vehicle name cannot be blank."
							return
						}
						guard !isNameTaken(trimmedName) else {
							nameValidationError = "That name is already used by another vehicle."
							return
						}
						nameValidationError = nil
						name = trimmedName
						if !isNewUnsavedRecord, name != originalName {
							showingRenameChoice = true
						} else {
							isEditing.toggle()
							updateItem()
							isNewUnsavedRecord = false
						}
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.confirmationDialog(
						"Vehicle Name Changed",
						isPresented: $showingRenameChoice,
						titleVisibility: .visible
					) {
						Button("Update Linked Records") {
							renameLinkedRecords(from: originalName, to: name)
							isEditing.toggle()
							updateItem()
						}
						Button("Save Without Updating Links", role: .destructive) {
							isEditing.toggle()
							updateItem()
						}
						Button("Cancel", role: .cancel) { }
					} message: {
						Text("Renaming \"\(originalName)\" to \"\(name)\" will break its links to other records unless they're updated to the new name. Update them now?")
					}
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

				// Hidden when no component serial numbers were recorded
				if !serialItems.isEmpty {
					CardView {
					VStack {
						SectionText(label: "COMPONENT SERIAL NUMBERS")
						ForEach(serialItems) { item in
							HStack{LabelDataText(label: item.itemName, data: item.serialNumber)}
						}
					}
					}
				}

				// Hidden when no mechanical fields have data
				if hasMechanicalDetails {
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
						if dataSet.engineSerialNumber != "" {
							HStack{LabelDataText(label: "Engine Serial #", data: dataSet.engineSerialNumber)}
						}
						if dataSet.transmissionSerialNumber != "" {
							HStack{LabelDataText(label: "Trans. Serial #", data: dataSet.transmissionSerialNumber)}
						}
					}
					}
				}
				
				// Hidden when no vehicle detail fields have data
				if hasVehicleDetails {
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
				}

				// NEW: Linked Vehicle Records (Details mode)
				if !linkedAspectVehicles.isEmpty || !dataSet.linkedMasterVehicleId.isEmpty {
					CardView {
						VStack(alignment: .leading, spacing: 8) {
							SectionText(label: "LINKED VEHICLE RECORDS")
							if !linkedAspectVehicles.isEmpty {
								HStack{LabelDataText(label: "Role", data: "Master Record")}
								ForEach(linkedAspectVehicles) { child in
									HStack{LabelDataText(
										label: child.vehicleAspect.isEmpty ? "Linked Record" : child.vehicleAspect,
										data: child.name)}
								}
							} else if let master = masterVehicle {
								HStack{LabelDataText(label: "Aspect", data: dataSet.vehicleAspect.isEmpty ? "Linked Record" : dataSet.vehicleAspect)}
								HStack{LabelDataText(label: "Master Vehicle", data: master.displayName.isEmpty ? master.name : master.displayName)}
								if dataSet.linkedSyncFields.isEmpty {
									HStack{LabelDataText(label: "Synced Fields", data: "None")}
								} else {
									ForEach(LinkableVehicleField.allCases.filter { dataSet.linkedSyncFields.contains($0) }) { field in
										HStack{LabelDataText(label: field.displayName, data: "Synced with master")}
									}
								}
							}
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
				
				// Hidden when no tire fields have data
				if hasTireInformation {
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
						if dataSet.wheelStudSize != "" {
							HStack{LabelDataText(label: "Wheel Stud Size", data: dataSet.wheelStudSize)}
						}
						if dataSet.wheelNutSocket != "" {
							HStack{LabelDataText(label: "Wheel Nut Socket", data: dataSet.wheelNutSocket)}
						}
						if dataSet.wheelNutTorque != "" {
							HStack{LabelDataText(label: "Wheel Nut Torque", data: dataSet.wheelNutTorque)}
						}
					}
					}
				}
				
				// Hidden when no dimension fields have data
				if hasDimensions {
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
				}
				
				CardView {
					VStack {
						// Title only appears when weight figures were entered
						if hasWeightData {
							SectionText(label: "WEIGHT DATA")
						}
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
						let totalVehicleWt = dataSet.scaleWeightFrontAxle + dataSet.scaleWeightRearAxle + dataSet.scaleWeightPusherAxle + dataSet.scaleWeightTagAxle
						let totalRollingWt = totalVehicleWt + dataSet.scaleWeightTrailerAxle
						if dataSet.scaleWeightFrontAxle > 0 || dataSet.scaleWeightRearAxle > 0 || dataSet.scaleWeightPusherAxle > 0 || dataSet.scaleWeightTagAxle > 0 || dataSet.scaleWeightTrailerAxle > 0 {
							SectionText(label: "SCALE WEIGHT READINGS")
							if dataSet.scaleWeightFrontAxle > 0 {
								HStack{LabelDataText(label: "Steer Axle", data: "\(dataSet.scaleWeightFrontAxle) \(unit(UnitIndex.mass))")}
							}
							if dataSet.scaleWeightRearAxle > 0 {
								HStack{LabelDataText(label: "Drive Axle(s)", data: "\(dataSet.scaleWeightRearAxle) \(unit(UnitIndex.mass))")}
							}
							if dataSet.scaleWeightPusherAxle > 0 {
								HStack{LabelDataText(label: "Pusher Axle", data: "\(dataSet.scaleWeightPusherAxle) \(unit(UnitIndex.mass))")}
							}
							if dataSet.scaleWeightTagAxle > 0 {
								HStack{LabelDataText(label: "Tag Axle", data: "\(dataSet.scaleWeightTagAxle) \(unit(UnitIndex.mass))")}
							}
							if dataSet.scaleWeightTrailerAxle > 0 {
								HStack{LabelDataText(label: "Trailer Axle(s)", data: "\(dataSet.scaleWeightTrailerAxle) \(unit(UnitIndex.mass))")}
							}
							if totalVehicleWt > 0 {
								HStack{LabelDataText(label: "Total Vehicle Weight", data: "\(totalVehicleWt) \(unit(UnitIndex.mass))")}
							}
							if totalRollingWt > 0 {
								HStack{LabelDataText(label: "Total Rolling Weight", data: "\(totalRollingWt) \(unit(UnitIndex.mass))")}
							}
						}
						SectionText(label: "WEIGHT SCALE TICKETS")
						if scaleTickets.isEmpty {
							Text("No scale tickets recorded.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(scaleTickets) { ticket in
								ScaleTicketRow(ticket: ticket) { t in
									scaleTicketToEdit = t
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
					}
				}
				
				// Hidden when no capacities were entered
				if hasCapacities {
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

				// Hidden when no insurance fields have data
				if hasInsuranceInformation {
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
				}
				
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						SectionText(label: "VEHICLE WARRANTIES")
						if warranties.isEmpty {
							Text("No warranties recorded.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							ForEach(warranties) { w in
								VStack(alignment: .leading, spacing: 4) {
//									Text(w.warrantyName).font(.subheadline).bold()
									if !w.warrantyName.isEmpty {
										HStack{LabelDataText(label: "Warrenty Name", data: w.warrantyName)}
									}
									if !w.warrantyType.isEmpty {
										HStack{LabelDataText(label: "Type", data: w.warrantyType)}
									}
									if !w.warrantyProvider.isEmpty {
										HStack{LabelDataText(label: "Warrenter", data: w.warrantyProvider)}
									}
									if !w.warrantyDescription.isEmpty {
										HStack{LabelDataText(label: "Description", data: w.warrantyDescription)}
									}
									if !w.warrantyNotes.isEmpty {
										HStack{LabelDataText(label: "Notes", data: w.warrantyNotes)}
									}
									if w.warrantyLengthMonths > 0 {
										HStack{LabelDataText(label: "Warrenty Length", data: "\(w.warrantyLengthMonths) months")}
									}
									if w.warrantyMileageLimit > 0 {
										let miRemaining = w.warrantyMileageLimit - dataSet.mileage
										HStack{LabelDataText(label: "Mileage Limit", data: "\(w.warrantyMileageLimit)")}
										HStack {
											Text("Mileage Remaining").textLabelModified()
											Text(miRemaining > 0 ? "\(miRemaining) mi" : "Exceeded")
												.frame(maxWidth: .infinity, alignment: .trailing)
												.foregroundStyle(warrantyMileageColor(remaining: miRemaining))
										}
									}
									HStack {
										Text("Expiration").textLabelModified()
										Text("\(functions.formatDate_DDMMMyy(date: w.warrantyExpirationDate))")
											.frame(maxWidth: .infinity, alignment: .trailing)
											.foregroundStyle(warrantyExpirationColor(date: w.warrantyExpirationDate))
									}
								}
								.padding(.vertical, 4)
								Divider()
							}
						}
					}
				}


				// Hidden when no online service fields have data
				if hasOnlineService {
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
				}

				// Hidden when no images are attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "VEHICLE GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
					}
				}

			}
			.onAppear {
				loadUnits()
				recomputeNextDue()
				loadWarranties()
				loadSerialItems()
				loadScaleTickets()
				loadLinkedVehicles()
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

	private func warrantyMileageColor(remaining: Int) -> Color {
		if remaining <= 0 { return .red }
		if remaining <= 10000 { return .yellow }
		return .green
	}

	private func warrantyExpirationColor(date: Date) -> Color {
		let now = Date()
		if date < now { return .red }
		let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: now) ?? now
		if date <= sixMonths { return .yellow }
		return .green
	}

	private func loadWarranties() {
		let vehicleId = dataSet.name
		let fd = FetchDescriptor<VehicleWarranty>(
			predicate: #Predicate { $0.vehicleId == vehicleId },
			sortBy: [SortDescriptor(\VehicleWarranty.warrantyName)]
		)
		warranties = (try? modelContext.fetch(fd)) ?? []
	}

	private func loadSerialItems() {
		let vehicleId = dataSet.name
		let fd = FetchDescriptor<VehicleSerialItem>(
			predicate: #Predicate { $0.vehicleId == vehicleId },
			sortBy: [SortDescriptor(\VehicleSerialItem.itemName)]
		)
		serialItems = (try? modelContext.fetch(fd)) ?? []
	}

	private func loadScaleTickets() {
		let vehicleId = dataSet.name
		let fd = FetchDescriptor<VehicleScaleTicket>(
			predicate: #Predicate { $0.vehicleId == vehicleId },
			sortBy: [SortDescriptor(\VehicleScaleTicket.date, order: .reverse)]
		)
		scaleTickets = (try? modelContext.fetch(fd)) ?? []
	}

	// MARK: - Linked Vehicle Records

	/// Vehicles eligible to be selected as this vehicle's master.
	/// Excludes self and any vehicle that is itself already linked to a master (no chains).
	private var availableMasterCandidates: [Vehicle8] {
		allVehiclesForLinking.filter { $0.name != dataSet.name && $0.linkedMasterVehicleId.isEmpty }
	}

	private func loadLinkedVehicles() {
		let selfName = dataSet.name
		let fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { !$0.inactive })
		allVehiclesForLinking = (try? modelContext.fetch(fd)) ?? []
		linkedAspectVehicles = allVehiclesForLinking
			.filter { $0.linkedMasterVehicleId == selfName }
			.sorted { $0.vehicleAspect < $1.vehicleAspect }
		masterVehicle = linkedMasterVehicleId.isEmpty
			? nil
			: allVehiclesForLinking.first(where: { $0.name == linkedMasterVehicleId })
	}

	/// Pulls the values for whichever fields this record has opted to sync (`linkedSyncFields`)
	/// from its master vehicle into the local @State mirrors, so `updateItem()`'s normal
	/// field write-back persists the master's authoritative values instead of stale local edits.
	private func pullLinkedFieldsFromMaster() {
		guard !linkedMasterVehicleId.isEmpty, !linkedSyncFields.isEmpty else { return }
		let masterName = linkedMasterVehicleId
		let fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == masterName })
		guard let master = try? modelContext.fetch(fd).first else { return }
		for field in linkedSyncFields {
			switch field {
				case .odometer:
					mileage = master.mileage
					mileageVirtual = master.mileageVirtual
				case .engineHours:
					engHours = master.engHours
				case .location:
					locationId = master.locationId
				case .owner:
					ownerId = master.ownerId
				case .insurance:
					insuranceCompany = master.insuranceCompany
					insurancePolicyNumber = master.insurancePolicyNumber
					insurancePolicyHolder = master.insurancePolicyHolder
					insuranceExpiration = master.insuranceExpiration
				case .vin:
					vin = master.vin
				case .licensePlate:
					licensePlate = master.licensePlate
				case .titleNumber:
					titleNumber = master.titleNumber
			}
		}
	}

	/// Pushes this vehicle's current field values to any linked aspect vehicles that have
	/// opted in (via their own `linkedSyncFields` selection) to syncing, so the master's
	/// readings stay authoritative.
	private func propagateToLinkedAspects() {
		guard !linkedAspectVehicles.isEmpty else { return }
		var didChange = false
		for child in linkedAspectVehicles where !child.linkedSyncFields.isEmpty {
			child.applyLinkedFields(from: dataSet)
			child.updatedAt = Date()
			didChange = true
		}
		if didChange {
			try? modelContext.save()
		}
	}

	private func syncWeightsFromModel() {
		scaleWeightFrontAxle = dataSet.scaleWeightFrontAxle
		scaleWeightRearAxle = dataSet.scaleWeightRearAxle
		scaleWeightPusherAxle = dataSet.scaleWeightPusherAxle
		scaleWeightTagAxle = dataSet.scaleWeightTagAxle
		scaleWeightTrailerAxle = dataSet.scaleWeightTrailerAxle
		weight = dataSet.weight
		dateWeighed = dataSet.dateWeighed
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
		// If linked to a master vehicle, pull the current values for whichever fields this
		// record has opted to sync, so it can't be saved out of step with the master.
		pullLinkedFieldsFromMaster()

		dataSet.inactive = inactive
		dataSet.createdAt = createdAt
		dataSet.updatedAt = Date()
		dataSet.name = name
		dataSet.displayName = name
		dataSet.manufacturer = manufacturer
		dataSet.model = model
		dataSet.trim = trim
		dataSet.year = year
		dataSet.mileage = mileage
		dataSet.mileageVirtual = mileageVirtual
		dataSet.engHours = engHours
		dataSet.transmission = transmission
		dataSet.engine = engine
		dataSet.engineSerialNumber = engineSerialNumber
		dataSet.transmissionSerialNumber = transmissionSerialNumber
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
		dataSet.wheelStudSize = wheelStudSize
		dataSet.wheelNutSocket = wheelNutSocket
		dataSet.wheelNutTorque = wheelNutTorque
		dataSet.availablePayload = availablePayload
		dataSet.scaleWeightFrontAxle = scaleWeightFrontAxle
		dataSet.scaleWeightRearAxle = scaleWeightRearAxle
		dataSet.scaleWeightPusherAxle = scaleWeightPusherAxle
		dataSet.scaleWeightTagAxle = scaleWeightTagAxle
		dataSet.scaleWeightTrailerAxle = scaleWeightTrailerAxle
		
		dataSet.image1 = image1
		dataSet.image2 = image2
		dataSet.image3 = image3
		dataSet.image1Description = image1Description
		dataSet.image2Description = image2Description
		dataSet.image3Description = image3Description

		dataSet.linkedMasterVehicleId = linkedMasterVehicleId
		dataSet.vehicleAspect = vehicleAspect
		dataSet.linkedSyncFields = linkedSyncFields

		do {
			try modelContext.save()
			originalName = name
		} catch {
			print(error.localizedDescription)
		}

		// Push this vehicle's readings out to any linked aspect vehicles that sync to it.
		propagateToLinkedAspects()
	}

	/// Returns true if another Vehicle8 record (not this one) already uses `candidate` as its
	/// name. Since `name` is the unique key every other model references a vehicle by, two
	/// vehicles sharing a name would make links ambiguous.
	private func isNameTaken(_ candidate: String) -> Bool {
		// Compared case-insensitively so "Truck" and "truck" are treated as the same name -
		// #Predicate can't express that, so this fetches all vehicles and compares in-memory.
		let fd = FetchDescriptor<Vehicle8>()
		guard let all = try? modelContext.fetch(fd) else { return false }
		return all.contains {
			$0.name != originalName && $0.name.caseInsensitiveCompare(candidate) == .orderedSame
		}
	}

	/// Updates the `vehicleId` field on every other record type that references this vehicle by
	/// name, plus any Vehicle8 records linked to this one as their master, so existing links
	/// survive a vehicle rename. Vehicle names are the only identifier most other models use to
	/// associate their records with a specific vehicle (LandShip's string-based linking
	/// convention — see VehicleWarranty, VehicleScaleTicket, etc.), so a rename without this
	/// cascade would silently orphan all related data.
	private func renameLinkedRecords(from oldName: String, to newName: String) {
		guard !oldName.isEmpty, oldName != newName else { return }

		func rename<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, _ apply: (T) -> Void) {
			guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else { return }
			records.forEach(apply)
		}

		rename(FetchDescriptor<VehicleWarranty>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<VehicleSerialItem>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<VehicleScaleTicket>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<VehicleSystems1>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<MxParts1>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<MxItems3>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<ServiceRecords1>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<TripLog2>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<Additions>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<Subscriptions>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<ProjectList>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<CheckList>(predicate: #Predicate { $0.vehicleId == oldName })) { $0.vehicleId = newName }
		rename(FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.linkedMasterVehicleId == oldName })) { $0.linkedMasterVehicleId = newName }

		do {
			try modelContext.save()
		} catch {
			print("Failed to update linked records after vehicle rename: \(error.localizedDescription)")
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

// MARK: - Linked Fields Picker Sheet

/// A checkable popup form letting the user choose which fields a linked vehicle "aspect"
/// record (e.g. Chassis, Engine, Body/House) should mirror from its master vehicle.
private struct LinkedFieldsPickerSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Binding var selection: Set<LinkableVehicleField>

	var body: some View {
		NavigationStack {
			Form {
				Section {
					ForEach(LinkableVehicleField.allCases) { field in
						Button {
							if selection.contains(field) {
								selection.remove(field)
							} else {
								selection.insert(field)
							}
						} label: {
							HStack {
								VStack(alignment: .leading, spacing: 2) {
									Text(field.displayName)
										.foregroundStyle(.primary)
									Text(field.summary)
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								Spacer()
								if selection.contains(field) {
									Image(systemName: "checkmark")
										.foregroundStyle(.blue)
										.imageScale(.large)
								}
							}
							.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
					}
				} header: {
					Text("Select which fields this record should mirror from its master vehicle. Selected fields become read-only here and update automatically whenever the master is saved.")
				}
			}
			.navigationTitle("Synced Fields")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
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


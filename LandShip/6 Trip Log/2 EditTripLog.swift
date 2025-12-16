/*
 EditTripLog.swift
 LandShip
 
 Created by JP on 7/20/25
 
 PURPOSE
 -------
 EditTripLog is a SwiftUI view responsible for displaying and editing a single TripLog2 record.
 It provides two primary modes: an editing form (isEditing == true) and a read-only details
 view (isEditing == false). The editing form supports vehicle and towed-vehicle selection via
 ModelPicker, start/end trip attributes, up to six enroute fuel stops (optionally linked to
 FuelLog1 records), image attachments, and a soft-delete (inactive) control.
 
 RESPONSIBILITIES
 ----------------
 - Present and edit TripLog2 fields in a structured, card-based layout.
 - Compute derived trip statistics (duration, distance, fuel, cost, economy) for display.
 - Persist changes to SwiftData (ModelContext) including related FuelLog1 updates/creation.
 - Optionally update Vehicle8 mileage/engine hours, and credit towed vehicle virtual mileage.
 - Respect user unit preferences (distance, fuel, oil, DEF) loaded from Settings1.
 
 DATA FLOW & STATE
 ------------------
 - dataSet: The TripLog2 model being edited/viewed. Many @State properties mirror dataSet to
   drive the editing UI. On save, the mirrored values are written back to dataSet and persisted.
 - selectedVehicle / selectedTowedVehicle: ModelPicker selections that map to vehicleId and
   vehicleIdTowed on the TripLog2 model.
 - createFuelLog[1...6] and associated fields allow inline creation or update of FuelLog1 entries
   which can be linked to the trip via fuelAdded#Log IDs.
 - vehicleDetails caches vehicle stats (fuel capacity, etc.) to compute fuel quantities.
 
 EDITING VS. DETAILS
 --------------------
 - Editing Mode: Form-based input with pickers, text fields, toggles, and image editors.
 - Details Mode: Read-only presentation of the trip with computed statistics and totals.
 
 PERSISTENCE NOTES
 ------------------
 - SwiftData (ModelContext) is used for TripLog2, FuelLog1, Vehicle8, and Settings1.
 - updateItem() handles saving TripLog2, creating/updating FuelLog1, and updating Vehicle8.
 - makeInactive() performs a soft delete by toggling the inactive flag and saving.
 - DeleteRecord() permanently removes the TripLog2 from the store.
 
 PERFORMANCE & SAFETY
 ---------------------
 - Unit strings are cached in an array to avoid repeated preference lookups.
 - Helper functions guard against negative distances and fuel calculations.
 - Array index access uses a safe helper to prevent out-of-bounds errors.
 
 UI ASSUMPTIONS
 --------------
 - Custom subviews like CardView, SectionText, and LabelData* are assumed to be present in the
   project and are used for consistent styling and layout.
 */

import SwiftUI
import SwiftData

/// A SwiftUI view for viewing and editing a single `TripLog2` record.
///
/// This view maintains an internal editing state that toggles between a read-only
/// details presentation and a comprehensive editing form. It also coordinates related
/// `FuelLog1` records and updates `Vehicle8` mileage/hours as needed.
///
/// Dependencies:
/// - `SwiftData` for persistence via `@Environment(\.modelContext)`
/// - `Functions` and `PrefsFunctions` for formatting, unit handling, and lookups
/// - Custom UI components (e.g., `CardView`, `SectionText`, `LabelData*`)
///
/// Behavior highlights:
/// - Supports up to six enroute fuel stops with optional linked `FuelLog1` entries.
/// - Computes trip statistics and vehicle totals for the details view.
/// - Provides soft-delete (inactive) and hard-delete (permanent) actions.
struct EditTripLog: View {
	@State private var dataSet: TripLog2
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) private var dismiss
    @AppStorage("showInactiveVehicles") private var showInactiveVehicles: Bool = false
	let functions: Functions = Functions()
	let prefsFunc: PrefsFunctions = PrefsFunctions()

	// Cache settings (units) once; keep access helper simple and safe.
	@State private var units: [String] = Array(repeating: "", count: 13)
	private func unit(_ index: Int) -> String {
		units.indices.contains(index) ? units[index] : ""
	}
	
	@State private var isPresentingConfirm: Bool = false /// for confirmation dialog
	@State private var isEditing: Bool = false
	
	@State private var inactive: Bool = false
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
	@State private var oilChecked1: Bool = false
	@State private var createFuelLog2: Bool = false
	@State private var fuelNotes1: String = ""
	@State private var fuelPrice2: Float = 0.0
	@State private var fuelOdometer2: Float = 0.0
	@State private var fuelEngHours2: Float = 0.0
	@State private var fuelLocation2: String = ""
	@State private var oilAdded2: Float = 0.0
	@State private var defAdded2: Float = 0.0
	@State private var oilChecked2: Bool = false
	@State private var fuelNotes2: String = ""
	@State private var createFuelLog3: Bool = false
	@State private var fuelPrice3: Float = 0.0
	@State private var fuelOdometer3: Float = 0.0
	@State private var fuelEngHours3: Float = 0.0
	@State private var fuelLocation3: String = ""
	@State private var oilAdded3: Float = 0.0
	@State private var defAdded3: Float = 0.0
	@State private var oilChecked3: Bool = false
	@State private var fuelNotes3: String = ""
	@State private var createFuelLog4: Bool = false
	@State private var fuelPrice4: Float = 0.0
	@State private var fuelOdometer4: Float = 0.0
	@State private var fuelEngHours4: Float = 0.0
	@State private var fuelLocation4: String = ""
	@State private var oilAdded4: Float = 0.0
	@State private var defAdded4: Float = 0.0
	@State private var oilChecked4: Bool = false
	@State private var fuelNotes4: String = ""
	@State private var createFuelLog5: Bool = false
	@State private var fuelPrice5: Float = 0.0
	@State private var fuelOdometer5: Float = 0.0
	@State private var fuelEngHours5: Float = 0.0
	@State private var fuelLocation5: String = ""
	@State private var oilAdded5: Float = 0.0
	@State private var defAdded5: Float = 0.0
	@State private var oilChecked5: Bool = false
	@State private var fuelNotes5: String = ""
	@State private var createFuelLog6: Bool = false
	@State private var fuelPrice6: Float = 0.0
	@State private var fuelOdometer6: Float = 0.0
	@State private var fuelEngHours6: Float = 0.0
	@State private var fuelLocation6: String = ""
	@State private var oilAdded6: Float = 0.0
	@State private var defAdded6: Float = 0.0
	@State private var oilChecked6: Bool = false
	@State private var fuelNotes6: String = ""

	// New: ModelPicker selections
	@State private var selectedVehicle: Vehicle8? = nil
	@State private var selectedTowedVehicle: Vehicle8? = nil
    @State private var tripInactive: Bool = false

	/// Initializes the editor with an existing `TripLog2` record.
	/// - Parameters:
	///   - dataSet: The `TripLog2` model to present.
	///   - startEditing: If `true`, the view opens directly in editing mode.
	///
	/// The initializer seeds local `@State` mirrors from the provided model and optionally
	/// starts the view in edit mode to streamline inline editing workflows.
	init(dataSet: TripLog2, startEditing: Bool = false) {
		self.dataSet = dataSet
		vehicleId = dataSet.vehicleId
		
		self._inactive = State.init(initialValue: dataSet.inactive)
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
        self._tripInactive = State.init(initialValue: dataSet.inactive)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	/// The main view body that switches between editing and details modes.
	///
	/// - Editing Mode: Presents interactive controls for all major trip fields, vehicle
	///   selection, enroute fuel entries, and image attachments.
	/// - Details Mode: Shows a read-only summary of the trip including computed statistics,
	///   totals, and any linked fuel and image information.
	var body: some View {
		// MARK: - Editing Mode UI
		if isEditing {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "GENERAL")
						
						LabeledContent {
							ModelPicker(
								selection: $selectedVehicle,
								title: "Vehicle",
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								filter: showInactiveVehicles ? nil : #Predicate<Vehicle8> { $0.inactive == false },
								sort: [SortDescriptor(\.name, order: .forward)],
								labelProvider: { $0.name }
							)
							.onChange(of: selectedVehicle) { _, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								dataSet.vehicleId = name
								refreshVehicleDetails()
								recomputeFuelQuantities()
							}
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text("Vehicle")
								.textLabelModified()
						}

						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						HStack{LabelDataToggle(label: "Towed Vehicle", data: $vehicleTowed)}

						if vehicleTowed {
							// Replaced VehiclePickerTripLog_Towed with ModelPicker<Vehicle8>
							let current = vehicleId
							let towedFilter: Predicate<Vehicle8>? = {
									if current.isEmpty {
											return showInactiveVehicles ? nil : #Predicate<Vehicle8> { $0.inactive == false }
									} else {
											return showInactiveVehicles
											? #Predicate<Vehicle8> { $0.name != current }
											: #Predicate<Vehicle8> { $0.name != current && $0.inactive == false }
									}
							}()
							LabeledContent {
								ModelPicker(
									selection: $selectedTowedVehicle,
									title: "",
									includeEmptyChoice: true,
									emptyChoiceLabel: "—",
									autoSelectFirst: false,
									filter: towedFilter,
									sort: [SortDescriptor(\.name, order: .forward)],
									labelProvider: { $0.name }
								)
								.onChange(of: selectedTowedVehicle) { _, newVehicle in
									let name = newVehicle?.name ?? ""
									vehicleIdTowed = name
									dataSet.vehicleIdTowed = name
								}
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Towed Vehicle")
									.textLabelModified()
							}
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL START")
						HStack{LabelDataPicker_DateTime(label: "Date/Time                    ", data: $tripDateTimeStart)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometerStart)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursStart)}
						HStack{LabelLocationTextview(label: "Location", data: $locationStart)}
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
								fuelNotes: $fuelNotes1,
								oilAdded: $oilAdded1,
								labelOil: "(\(unit(UnitIndex.oil)))",
								defAdded: $defAdded1,
								labelDEF: "(\(unit(UnitIndex.def)))",
								oilChecked: $oilChecked1
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
									fuelNotes: $fuelNotes2,
									oilAdded: $oilAdded2,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded2,
									labelDEF: "(\(unit(UnitIndex.def)))",
									oilChecked: $oilChecked2
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
									fuelNotes: $fuelNotes3,
									oilAdded: $oilAdded3,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded3,
									labelDEF: "(\(unit(UnitIndex.def)))",
									oilChecked: $oilChecked3
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
									fuelNotes: $fuelNotes4,
									oilAdded: $oilAdded4,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded4,
									labelDEF: "(\(unit(UnitIndex.def)))",
									oilChecked: $oilChecked4
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
									fuelNotes: $fuelNotes5,
									oilAdded: $oilAdded5,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded5,
									labelDEF: "(\(unit(UnitIndex.def)))",
									oilChecked: $oilChecked5
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
									fuelNotes: $fuelNotes6,
									oilAdded: $oilAdded6,
									labelOil: "(\(unit(UnitIndex.oil)))",
									defAdded: $defAdded6,
									labelDEF: "(\(unit(UnitIndex.def)))",
									oilChecked: $oilChecked6
								)
							}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL END")
						HStack{LabelDataPicker_DateTime(label: "Date/Time                    ", data: $tripDateTimeEnd)}
						HStack{LabelDataTextview_Numberpad_Int(label: "Odometer", data: $odometerEnd)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursEnd)}
						HStack{LabelLocationTextview(label: "Location", data: $locationEnd)}
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
					TextFieldNote_FullWidth_3lines(sectionText: "TRAVEL LOG NOTES", prompt: "Enter notes...", data: $tripNotes)
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
				CardView {
					VStack {
						SectionText(label: "STATUS")
						HStack{LabelDataToggle(label: "Deactivate Travel Log Record", data: $inactive)}
						Text("When selected, this record is marked as inactive. It will be hidden in lists and pickers, but its data remains available for viewing and editing, and can be un-hidden by selecting 'View Inactive' on the 'Settings' screen.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}

			}// end of form
			
			.frame(maxWidth: .infinity, maxHeight: .infinity)

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "edit",
					dbRecord: "travel log")
			}

			.onAppear {
				loadUnitsIfNeeded()
				// Seed vehicle picker from existing vehicleId
				if selectedVehicle == nil, !vehicleId.isEmpty {
					let name = vehicleId
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedVehicle = v
					}
				}
				// Seed towed vehicle picker if needed
				if selectedTowedVehicle == nil, !vehicleIdTowed.isEmpty {
					let name = vehicleIdTowed
					var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == name })
					fd.fetchLimit = 1
					if let v = try? modelContext.fetch(fd).first {
						selectedTowedVehicle = v
					}
				}
				refreshVehicleDetails()
				recomputeFuelQuantities()
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
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
			
			// MARK: - Details Mode UI
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
									fuelNotes1 = fuelLogData.fuelNotes
									oilChecked1 = fuelLogData.oilChecked
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
									fuelNotes2 = fuelLogData.fuelNotes
									oilChecked2 = fuelLogData.oilChecked
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
									fuelNotes3 = fuelLogData.fuelNotes
									oilChecked3 = fuelLogData.oilChecked
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
									fuelNotes4 = fuelLogData.fuelNotes
									oilChecked4 = fuelLogData.oilChecked
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
									fuelNotes5 = fuelLogData.fuelNotes
									oilChecked5 = fuelLogData.oilChecked
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
									fuelNotes6 = fuelLogData.fuelNotes
									oilChecked6 = fuelLogData.oilChecked
									createFuelLog6 = true
								}
							}
						HStack{LabelDataText(label: "Name", data: dataSet.logName)}
						HStack{LabelDataText(label: "Vehicle", data: dataSet.vehicleId)}
						if dataSet.vehicleTowed {
							HStack{LabelDataText(label: "Towed Vehicle", data: "\(dataSet.vehicleIdTowed)")}
						}
							HStack{ LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active") }
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
							HStack{LabelDataText(label: "Fuel Level", data: "\(dataSet.fuelLevelStart) \(dataSet.fuelQuantityStart)\(unit(UnitIndex.fuel))")}
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
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation1)", data: dataSet.fuelAdded1, fractionalLength: 1)}
						}
						if dataSet.fuelAdded2 > 0 {
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation2)", data: dataSet.fuelAdded2, fractionalLength: 1)}
						}
						if dataSet.fuelAdded3 > 0 {
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation3)", data: dataSet.fuelAdded3, fractionalLength: 1)}
						}
						if dataSet.fuelAdded4 > 0 {
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation4)", data: dataSet.fuelAdded4, fractionalLength: 1)}
						}
						if dataSet.fuelAdded5 > 0 {
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation5)", data: dataSet.fuelAdded5, fractionalLength: 1)}
						}
						if dataSet.fuelAdded6 > 0 {
							HStack{LabelDataNumber(label: "Fuel- \(fuelLocation6)", data: dataSet.fuelAdded6, fractionalLength: 1)}
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
							HStack{LabelDataText(label: "Fuel Level", data: "\(dataSet.fuelLevelEnd) \(dataSet.fuelQuantityEnd)\(unit(UnitIndex.fuel))")}
						}
						if dataSet.locationEnd != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationEnd)")}
						}
					}
				}

				if dataSet.tripNotes != "" {CardView {
					TextNoteDisplay_FullWidth(sectionText: "TRAVEL LOG NOTES", data: dataSet.tripNotes)}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL STATISTICS")
						let stats = computeTripStats()
						// Duration
						HStack{ LabelDataText(label: "Time Underway", data: stats.durationString) }
						HStack{ LabelDataNumber(label: "Underway (hrs)", data: Float(stats.durationHours), fractionalLength: 2) }
						// Distance
						HStack{ LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(stats.distance)") }
						// Average speed
						if stats.avgSpeed > 0 {
							HStack{ LabelDataNumber(label: "Average Speed (\(unit(UnitIndex.distance))/Hr)", data: Float(stats.avgSpeed), fractionalLength: 1) }
						}
						
						// Fuel added (new)
						if stats.totalFuelAdded > 0 {
							HStack{ LabelDataNumber(label: "Added Enroute (\(unit(UnitIndex.fuel)))", data: stats.totalFuelAdded, fractionalLength: 1) }
						}
						// Fuel burned and economy
						HStack{ LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: stats.fuelBurned, fractionalLength: 1) }
						if stats.fuelEconomy > 0 {
							HStack{
								LabelDataText(label: "Fuel Economy (\(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel)))", data: "\(stats.fuelEconomy.formatted(.number.precision(.fractionLength(1))))")
							}
						}
						// Fuel cost and price
						if stats.totalFuelCost > 0 {
							HStack{ LabelDataCurrency(label: "Fuel Cost", data: stats.totalFuelCost, unit: "") }
						}
						if stats.weightedAvgFuelPrice > 0 {
							HStack{ LabelDataCurrency(label: "Avg Fuel Price/\(unit(UnitIndex.fuel))", data: stats.weightedAvgFuelPrice, unit: "") }
						}
						// Fluids
						if stats.oilAdded > 0 {
							HStack{ LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: stats.oilAdded, fractionalLength: 1) }
						}
						if stats.defAdded > 0 {
							HStack{ LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: stats.defAdded, fractionalLength: 1) }
						}
						// Images
						if stats.imagesCount > 0 {
							HStack{ LabelDataText(label: "Images Attached", data: "\(stats.imagesCount)") }
						}
						// Towed distance
						if dataSet.vehicleTowed, stats.distance > 0 {
							HStack{ LabelDataText(label: "Towed Distance Credited (\(unit(UnitIndex.distance)))", data: "\(stats.distance)") }
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "VEHICLE TOTALS")
						Text("Totals are calculated from all travel logs that have been created for this vehicle up to and including the current travel log.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .center)
						let totals = computeVehicleTotals()
						HStack{ LabelDataText(label: "Trips Counted", data: "\(totals.tripCount)") }
						HStack{ LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(totals.totalDistance)") }
						HStack{ LabelDataNumber(label: "Underway (hours)", data: Float(totals.totalHours), fractionalLength: 1) }
						HStack{ LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: totals.totalFuelBurned, fractionalLength: 1) }
						if totals.avgEconomy > 0 {
							HStack{ LabelDataText(label: "Average (\(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel)))", data: "\(totals.avgEconomy.formatted(.number.precision(.fractionLength(1))))") }
						}
						if totals.totalFuelCost > 0 {
							HStack{ LabelDataCurrency(label: "Fuel Cost", data: totals.totalFuelCost, unit: "") }
						}
						if totals.totalOilAdded > 0 {
							HStack{ LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: totals.totalOilAdded, fractionalLength: 1) }
						}
						if totals.totalDEFAdded > 0 {
							HStack{ LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: totals.totalDEFAdded, fractionalLength: 1) }
						}
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

			.safeAreaInset(edge: .top) {
				PageTitle_Col3_Photo(
					label: "",
					action: "details",
					dbRecord: "travel log")
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
			.onAppear {
				loadUnitsIfNeeded()
				refreshVehicleDetails()
			}
		}
	}
	
	/// Permanently deletes the current `TripLog2` and dismisses the view.
	///
	/// - Warning: This action cannot be undone. Use `makeInactive()` for a reversible,
	///   non-destructive alternative.
	private func DeleteRecord(){
		do {
			modelContext.delete(dataSet)
			try modelContext.save()
		} catch {print(error.localizedDescription)}
		dismiss()
	}
	
	/// Marks the current trip log as inactive (soft delete) and persists the change.
	///
	/// - Note: Inactive records remain available for historical reference but are excluded
	///   from reports and calculations.
	/// - Side Effects: Updates `updatedAt`, saves the model context, and dismisses the view.
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

	/// Writes the editing state back to `dataSet` and persists changes.
	///
	/// This method also:
	/// - Creates or updates up to six related `FuelLog1` entries.
	/// - Updates `Vehicle8` mileage/engine hours if the trip extends them.
	/// - Credits towed vehicle virtual mileage when applicable.
	private func updateItem() {
		// save fuel log(s) first to return the fuel log id(s) for saving
		if createFuelLog1 {
			fuelAdded1Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer1), saveEngineHours: fuelEngHours1, saveQuantity: Int(fuelAdded1), savePrice: fuelPrice1, saveLocation: fuelLocation1, saveLogId: fuelAdded1Log, saveOil: oilAdded1, saveDEF: defAdded1, saveNotes: fuelNotes1, saveOilChecked: oilChecked1)
		}
		if createFuelLog2 {
			fuelAdded2Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer2), saveEngineHours: fuelEngHours2, saveQuantity: Int(fuelAdded2), savePrice: fuelPrice2, saveLocation: fuelLocation2, saveLogId: fuelAdded2Log, saveOil: oilAdded2, saveDEF: defAdded2, saveNotes: fuelNotes2, saveOilChecked: oilChecked2)
		}
		if createFuelLog3 {
			fuelAdded3Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer3), saveEngineHours: fuelEngHours3, saveQuantity: Int(fuelAdded3), savePrice: fuelPrice3, saveLocation: fuelLocation3, saveLogId: fuelAdded3Log, saveOil: oilAdded3, saveDEF: defAdded3, saveNotes: fuelNotes3, saveOilChecked: oilChecked3)
		}
		if createFuelLog4 {
			fuelAdded4Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer4), saveEngineHours: fuelEngHours4, saveQuantity: Int(fuelAdded4), savePrice: fuelPrice4, saveLocation: fuelLocation4, saveLogId: fuelAdded4Log, saveOil: oilAdded4, saveDEF: defAdded4, saveNotes: fuelNotes4, saveOilChecked: oilChecked4)
		}
		if createFuelLog5 {
			fuelAdded5Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer5), saveEngineHours: fuelEngHours5, saveQuantity: Int(fuelAdded5), savePrice: fuelPrice5, saveLocation: fuelLocation5, saveLogId: fuelAdded5Log, saveOil: oilAdded5, saveDEF: defAdded5, saveNotes: fuelNotes5, saveOilChecked: oilChecked5)
		}
		if createFuelLog6 {
			fuelAdded6Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer6), saveEngineHours: fuelEngHours6, saveQuantity: Int(fuelAdded6), savePrice: fuelPrice6, saveLocation: fuelLocation6, saveLogId: fuelAdded6Log, saveOil: oilAdded6, saveDEF: defAdded6, saveNotes: fuelNotes6, saveOilChecked: oilChecked6)
		}

		dataSet.inactive = inactive
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
        dataSet.inactive = tripInactive

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
	
	/// Attempts to locate an existing `FuelLog1` for this trip.
	///
	/// Search order:
	/// 1. By explicit `logId` if provided.
	/// 2. By `(odometer, vehicleId)` pair, assigning a new `logId` if found.
	///
	/// - Returns: The resolved `logId` if a record is found, or an empty string if not.
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
	
	/// Creates or updates a `FuelLog1` record for an enroute fuel stop.
	///
	/// - Parameters mirror the data captured inline on the editing form.
	/// - If an existing record is found (via `searchFuelRecord`), it is updated; otherwise,
	///   a new record is created and inserted.
	/// - Returns: The `logId` of the created/updated record.
	private func add_editFuelRecord(saveOdometer: Int, saveEngineHours: Float, saveQuantity: Int, savePrice: Float, saveLocation: String, saveLogId: String, saveOil: Float, saveDEF: Float, saveNotes: String, saveOilChecked: Bool) -> String {
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
					existing.fuelNotes = saveNotes
					existing.oilChecked = saveOilChecked
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
					existing.fuelNotes = saveNotes
					existing.oilChecked = saveOilChecked
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
			fuelNotes: "Travel log: \(logName)",
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
			oilChecked: saveOilChecked,
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
	
	/// Loads persisted fuel stop attributes for a linked `FuelLog1`.
	/// - Parameter saveLogId: The `logId` of the `FuelLog1` to fetch.
	/// - Returns: Tuple containing quantity, price, cost, odometer, engine hours, location,
	///   oil added, DEF added, and oil checked status. Missing logs return zeros/empty strings/false.
	func getFuelLogData(saveLogId: String) -> (fuelAdded: Float, fuelPrice: Float, fuelCost: Float, fuelOdometer: Float, fuelEngHours: Float, fuelLocation: String, oilAdded: Float, defAdded: Float, fuelNotes: String, oilChecked: Bool) {
		var fuelAdded: Float = 0
		var fuelPrice: Float = 0
		var fuelCost: Float = 0
		var fuelOdometer: Float = 0
		var fuelEngHours: Float = 0
		var fuelLocation: String = ""
		var oilAdded: Float = 0
		var defAdded: Float = 0
		var fuelNotes: String = ""
		var oilChecked: Bool = false
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
				fuelNotes = fetchModel.fuelNotes
				oilChecked = fetchModel.oilChecked
			}
		} catch {}
		return (fuelAdded, fuelPrice, fuelCost, fuelOdometer, fuelEngHours, fuelLocation, oilAdded, defAdded, fuelNotes, oilChecked)
	}
	
	/// Loads and caches user unit preferences if not already loaded.
	///
	/// Preferences are fetched via `PrefsFunctions` and cached locally for fast, safe access.
	private func loadUnitsIfNeeded() {
		if let arr = prefsFunc.loadSettingsArray(context: modelContext, userName: "primary1") {
			self.units = arr
		}
	}
	/// Refreshes cached `vehicleDetails` from the current `vehicleId`.
	///
	/// Used to derive fuel quantities and other vehicle-specific computations.
	private func refreshVehicleDetails() {
		self.vehicleDetails = functions.loadVehicleDetails(context: modelContext, vehicleId: vehicleId)
	}
	/// Recomputes start/end fuel quantities and a running consumed estimate.
	///
	/// The calculation uses the selected vehicle's fuel capacity and the fractional
	/// fuel levels chosen in the editing UI.
	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
		// keep a running consumed value if helpful in edit state
		fuelConsumed = max(0, (fuelQuantityStart - fuelQuantityEnd) + fuelAdded1 + fuelAdded2 + fuelAdded3 + fuelAdded4 + fuelAdded5 + fuelAdded6)
	}
}

/// Safe index helper for arrays to avoid out-of-bounds crashes when settings are missing.
private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

// MARK: - Statistics helpers
private extension EditTripLog {
	/// Aggregated statistics for a single trip, derived from `TripLog2` and linked fuel logs.
	struct TripStats {
		let durationString: String
		let durationHours: Double
		let distance: Int
		let avgSpeed: Double
		let fuelBurned: Float
		let fuelEconomy: Double
		let totalFuelCost: Float
		let weightedAvgFuelPrice: Float
		let oilAdded: Float
		let defAdded: Float
		let imagesCount: Int
		let totalFuelAdded: Float
	}
	
	/// Computes trip duration, distance, fuel usage, economy, costs, and attachments count.
	///
	/// - Returns: A `TripStats` value summarizing core metrics for the current `dataSet`.
	func computeTripStats() -> TripStats {
		// Duration
		let comps = Calendar(identifier: .gregorian).dateComponents([.day, .hour, .minute], from: dataSet.tripDateTimeStart, to: dataSet.tripDateTimeEnd)
		let days = comps.day ?? 0
		let hours = comps.hour ?? 0
		let mins = comps.minute ?? 0
		let durationString: String = {
			if days != 0 {
				return "\(days) days, \(hours) hours, \(mins) minutes"
			} else if hours != 0 {
			 return "\(hours) hours, \(mins) minutes"
			} else {
				return "\(mins) minutes"
			}
		}()
		let durationHours = max(0.0, (Double(days) * 24.0) + Double(hours) + Double(mins)/60.0)
		
		// Distance
		let distance = max(0, dataSet.odometerEnd - dataSet.odometerStart)
		
		// Total fuel added across all stops
		let totalAdded = dataSet.fuelAdded1 + dataSet.fuelAdded2 + dataSet.fuelAdded3 + dataSet.fuelAdded4 + dataSet.fuelAdded5 + dataSet.fuelAdded6
		
		// fuelBurned = (Starting fuel + Fuel added) - Ending fuel
		let fuelBurned = (dataSet.fuelQuantityStart + dataSet.fuelAdded1 + dataSet.fuelAdded2 + dataSet.fuelAdded3 + dataSet.fuelAdded4 + dataSet.fuelAdded5 + dataSet.fuelAdded6) - dataSet.fuelQuantityEnd
		
		// Economy and avg speed
		let fuelEconomy: Double = fuelBurned > 0 ? Double(distance) / Double(fuelBurned) : 0
		let avgSpeed: Double = durationHours > 0 ? Double(distance) / durationHours : 0
		
		// Linked fuel logs (cost, price, oil, DEF) - weighted price by quantity
		var totalCost: Float = 0
		var totalQty: Float = 0
		var priceQtyProduct: Float = 0
		var oilTotal: Float = 0
		var defTotal: Float = 0
		let logIds = [fuelAdded1Log, fuelAdded2Log, fuelAdded3Log, fuelAdded4Log, fuelAdded5Log, fuelAdded6Log].filter { !$0.isEmpty }
		if !logIds.isEmpty {
			do {
				let fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { logIds.contains($0.logId) })
				let logs = try modelContext.fetch(fd)
				for l in logs {
					totalCost += l.fuelCost
					priceQtyProduct += (l.fuelPrice * l.fuelAdded)
					totalQty += l.fuelAdded
					oilTotal += l.oilAdded
					defTotal += l.defAdded
				}
			} catch {}
		}
		let weightedAvgPrice: Float = totalQty > 0 ? priceQtyProduct / totalQty : 0
		
		// Images count
		let imagesCount = [dataSet.image1, dataSet.image2, dataSet.image3].compactMap { $0 }.count
		
		return TripStats(
			durationString: durationString,
			durationHours: durationHours,
			distance: distance,
			avgSpeed: avgSpeed,
			fuelBurned: fuelBurned,
			fuelEconomy: fuelEconomy,
			totalFuelCost: totalCost,
			weightedAvgFuelPrice: weightedAvgPrice,
			oilAdded: oilTotal,
			defAdded: defTotal,
			imagesCount: imagesCount,
			totalFuelAdded: totalAdded
		)
	}
	
	/// Aggregated totals across trips for the current vehicle up to this record's end date.
	struct VehicleTotals {
		let tripCount: Int
		let totalDistance: Int
		let totalHours: Double
		let totalFuelBurned: Float
		let avgEconomy: Double
		let totalFuelCost: Float
		let totalOilAdded: Float
		let totalDEFAdded: Float
	}
	/// Computes cumulative distance, duration, fuel consumption, economy, and fluid totals.
	///
	/// The query includes all `TripLog2` entries for the same vehicle with an end date
	/// less than or equal to the current trip's end date.
	func computeVehicleTotals() -> VehicleTotals {
		var trips: [TripLog2] = []
		do {
			// Use captured constants to satisfy #Predicate
			let currentVehicleId = vehicleId
			let cutoff = dataSet.tripDateTimeEnd
			let fd = FetchDescriptor<TripLog2>(predicate: #Predicate { $0.vehicleId == currentVehicleId && $0.tripDateTimeEnd <= cutoff })
			trips = try modelContext.fetch(fd)
		} catch {}
		
		let tripCount = trips.count
		var totalDistance = 0
		var totalHours: Double = 0
		var totalFuelBurned: Float = 0
		
		for t in trips {
			let distance = max(0, t.odometerEnd - t.odometerStart)
			totalDistance += distance
			let comps = Calendar(identifier: .gregorian).dateComponents([.day, .hour, .minute], from: t.tripDateTimeStart, to: t.tripDateTimeEnd)
			let d = comps.day ?? 0
			let h = comps.hour ?? 0
			let m = comps.minute ?? 0
			totalHours += (Double(d) * 24.0) + Double(h) + Double(m)/60.0
			let burned = (t.fuelQuantityStart + t.fuelAdded1 + t.fuelAdded2 + t.fuelAdded3 + t.fuelAdded4 + t.fuelAdded5 + t.fuelAdded6) - t.fuelQuantityEnd
			totalFuelBurned += burned
		}
		let avgEconomy: Double = (totalFuelBurned > 0) ? Double(totalDistance) / Double(totalFuelBurned) : 0
		
		// Aggregate all fuel logs for this vehicle up to this record's end date for total cost and fluids
		var totalFuelCost: Float = 0
		var totalOilAdded: Float = 0
		var totalDEFAdded: Float = 0
		do {
			let currentVehicleId = dataSet.vehicleId
			let cutoff = dataSet.tripDateTimeEnd
			let fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.vehicleId == currentVehicleId && $0.fuelDateTime <= cutoff })
			let logs = try modelContext.fetch(fd)
			for l in logs {
				totalFuelCost += l.fuelCost
				totalOilAdded += l.oilAdded
				totalDEFAdded += l.defAdded
			}
		} catch {}
		
		return VehicleTotals(
			tripCount: tripCount,
			totalDistance: totalDistance,
			totalHours: totalHours,
			totalFuelBurned: totalFuelBurned,
			avgEconomy: avgEconomy,
			totalFuelCost: totalFuelCost,
			totalOilAdded: totalOilAdded,
			totalDEFAdded: totalDEFAdded
		)
	}
}

#Preview {
	// In-memory SwiftData container for this preview
	let config = ModelConfiguration(isStoredInMemoryOnly: true)
	let container = try! ModelContainer(for: Vehicle8.self, TripLog2.self, FuelLog1.self, Settings1.self, configurations: config)

	let context = container.mainContext

	// Seed a vehicle
	let vehicle = Vehicle8(
		name: "Demo Truck",
		year: 2021,
		mileage: 15000,
		engHours: 320.5,
		fuelType: "Diesel",
		fuelCapacity: 100
	)
	context.insert(vehicle)

	// Seed settings so units load nicely
	let settings = Settings1()
	settings.userName = "primary1"
	settings.unitVolumeFuel = "gal"
	settings.unitVolumeOil = "qt"
	settings.unitVolumeDEF = "gal"
	settings.unitTemp = "F"
	settings.unitSpeed = "mph"
	settings.unitPressure = "PSI"
	settings.unitMass = "lb"
	settings.unitDistance = "mi"
	settings.unitArea = "ft²"
	settings.unitLength = "ft"
	settings.unitWidth = "ft"
	settings.unitHeight = "ft"
	settings.unitWheelBase = "in"
	context.insert(settings)

	// Seed a sample trip log that references the vehicle
	let start = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
	let end = Calendar.current.date(byAdding: .hour, value: 6, to: start) ?? start
	let trip = TripLog2(
		vehicleId: vehicle.name,
		logName: "Weekend Run",
		tripNotes: "Light traffic, one refuel enroute.",
		createdAt: start,
		updatedAt: end,
		tripDateTimeStart: start,
		tripDateTimeEnd: end,
		odometerStart: vehicle.mileage,
		odometerEnd: vehicle.mileage + 235,
		engHoursStart: vehicle.engHours,
		engHoursEnd: vehicle.engHours + 6.0,
		fuelQuantityStart: 60,
		fuelQuantityEnd: 35,
		fuelConsumed: 0, // let UI compute from quantities + adds
		fuelLevelStart1: 0.6,
		fuelLevelEnd1: 0.35,
		fuelLevelStart: "3/5",
		fuelLevelEnd: "1/3",
		fuelAdded1Log: "",
		fuelAdded1: 10.0,
		fuelAdded2Log: "",
		fuelAdded2: 0.0,
		fuelAdded3Log: "",
		fuelAdded3: 0.0,
		fuelAdded4Log: "",
		fuelAdded4: 0.0,
		fuelAdded5Log: "",
		fuelAdded5: 0.0,
		fuelAdded6Log: "",
		fuelAdded6: 0.0,
		locationStart: "Depot",
		locationEnd: "Harbor",
		vehicleTowed: true,
		vehicleIdTowed: "Trailer 1",
		image1: nil,
		image1Description: "",
		image2: nil,
		image2Description: "",
		image3: nil,
		image3Description: ""
	)
	context.insert(trip)

	try? context.save()

	return EditTripLog(dataSet: trip)
		.modelContainer(container)
}


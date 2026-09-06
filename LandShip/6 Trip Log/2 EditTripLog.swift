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
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
	@Environment(\.colorScheme) private var colorScheme
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
	@State private var defLevel1: Float = 0.0
	@State private var defLevelFraction: String = ""
	@State private var defLevelEnd1: Float = 0.0
	@State private var defLevelEndFraction: String = ""
	@State private var defQuantityStart: Float = 0.0
	@State private var defQuantityEnd: Float = 0.0
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
	@State private var engineCoolantChecked1: Bool = false
	@State private var secondaryCoolantChecked1: Bool = false
	@State private var powerSteeringChecked1: Bool = false
	@State private var brakeFluidChecked1: Bool = false
	@State private var transmissionFluidChecked1: Bool = false
	@State private var rearAxleChecked1: Bool = false
	@State private var frontAxleChecked1: Bool = false
	@State private var fuelWaterSeparatorChecked1: Bool = false
	@State private var airSystemWaterBleedChecked1: Bool = false
	@State private var createFuelLog2: Bool = false
	@State private var fuelNotes1: String = ""
	@State private var fuelPrice2: Float = 0.0
	@State private var fuelOdometer2: Float = 0.0
	@State private var fuelEngHours2: Float = 0.0
	@State private var fuelLocation2: String = ""
	@State private var oilAdded2: Float = 0.0
	@State private var defAdded2: Float = 0.0
	@State private var oilChecked2: Bool = false
	@State private var engineCoolantChecked2: Bool = false
	@State private var secondaryCoolantChecked2: Bool = false
	@State private var powerSteeringChecked2: Bool = false
	@State private var brakeFluidChecked2: Bool = false
	@State private var transmissionFluidChecked2: Bool = false
	@State private var rearAxleChecked2: Bool = false
	@State private var frontAxleChecked2: Bool = false
	@State private var fuelWaterSeparatorChecked2: Bool = false
	@State private var airSystemWaterBleedChecked2: Bool = false
	@State private var fuelNotes2: String = ""
	@State private var createFuelLog3: Bool = false
	@State private var fuelPrice3: Float = 0.0
	@State private var fuelOdometer3: Float = 0.0
	@State private var fuelEngHours3: Float = 0.0
	@State private var fuelLocation3: String = ""
	@State private var oilAdded3: Float = 0.0
	@State private var defAdded3: Float = 0.0
	@State private var oilChecked3: Bool = false
	@State private var engineCoolantChecked3: Bool = false
	@State private var secondaryCoolantChecked3: Bool = false
	@State private var powerSteeringChecked3: Bool = false
	@State private var brakeFluidChecked3: Bool = false
	@State private var transmissionFluidChecked3: Bool = false
	@State private var rearAxleChecked3: Bool = false
	@State private var frontAxleChecked3: Bool = false
	@State private var fuelWaterSeparatorChecked3: Bool = false
	@State private var airSystemWaterBleedChecked3: Bool = false
	@State private var fuelNotes3: String = ""
	@State private var createFuelLog4: Bool = false
	@State private var fuelPrice4: Float = 0.0
	@State private var fuelOdometer4: Float = 0.0
	@State private var fuelEngHours4: Float = 0.0
	@State private var fuelLocation4: String = ""
	@State private var oilAdded4: Float = 0.0
	@State private var defAdded4: Float = 0.0
	@State private var oilChecked4: Bool = false
	@State private var engineCoolantChecked4: Bool = false
	@State private var secondaryCoolantChecked4: Bool = false
	@State private var powerSteeringChecked4: Bool = false
	@State private var brakeFluidChecked4: Bool = false
	@State private var transmissionFluidChecked4: Bool = false
	@State private var rearAxleChecked4: Bool = false
	@State private var frontAxleChecked4: Bool = false
	@State private var fuelWaterSeparatorChecked4: Bool = false
	@State private var airSystemWaterBleedChecked4: Bool = false
	@State private var fuelNotes4: String = ""
	@State private var createFuelLog5: Bool = false
	@State private var fuelPrice5: Float = 0.0
	@State private var fuelOdometer5: Float = 0.0
	@State private var fuelEngHours5: Float = 0.0
	@State private var fuelLocation5: String = ""
	@State private var oilAdded5: Float = 0.0
	@State private var defAdded5: Float = 0.0
	@State private var oilChecked5: Bool = false
	@State private var engineCoolantChecked5: Bool = false
	@State private var secondaryCoolantChecked5: Bool = false
	@State private var powerSteeringChecked5: Bool = false
	@State private var brakeFluidChecked5: Bool = false
	@State private var transmissionFluidChecked5: Bool = false
	@State private var rearAxleChecked5: Bool = false
	@State private var frontAxleChecked5: Bool = false
	@State private var fuelWaterSeparatorChecked5: Bool = false
	@State private var airSystemWaterBleedChecked5: Bool = false
	@State private var fuelNotes5: String = ""
	@State private var createFuelLog6: Bool = false
	@State private var fuelPrice6: Float = 0.0
	@State private var fuelOdometer6: Float = 0.0
	@State private var fuelEngHours6: Float = 0.0
	@State private var fuelLocation6: String = ""
	@State private var oilAdded6: Float = 0.0
	@State private var defAdded6: Float = 0.0
	@State private var oilChecked6: Bool = false
	@State private var engineCoolantChecked6: Bool = false
	@State private var secondaryCoolantChecked6: Bool = false
	@State private var powerSteeringChecked6: Bool = false
	@State private var brakeFluidChecked6: Bool = false
	@State private var transmissionFluidChecked6: Bool = false
	@State private var rearAxleChecked6: Bool = false
	@State private var frontAxleChecked6: Bool = false
	@State private var fuelWaterSeparatorChecked6: Bool = false
	@State private var airSystemWaterBleedChecked6: Bool = false
	@State private var fuelNotes6: String = ""
	@State private var fuelDateTime1: Date = Date()
	@State private var fuelDateTime2: Date = Date()
	@State private var fuelDateTime3: Date = Date()
	@State private var fuelDateTime4: Date = Date()
	@State private var fuelDateTime5: Date = Date()
	@State private var fuelDateTime6: Date = Date()
	@State private var fuelExitTime1: Date = Date()
	@State private var fuelExitTime2: Date = Date()
	@State private var fuelExitTime3: Date = Date()
	@State private var fuelExitTime4: Date = Date()
	@State private var fuelExitTime5: Date = Date()
	@State private var fuelExitTime6: Date = Date()
	@State private var stopReason1: String = ""
	@State private var stopReason2: String = ""
	@State private var stopReason3: String = ""
	@State private var stopReason4: String = ""
	@State private var stopReason5: String = ""
	@State private var stopReason6: String = ""
	@State private var stopComment1: String = ""
	@State private var stopComment2: String = ""
	@State private var stopComment3: String = ""
	@State private var stopComment4: String = ""
	@State private var stopComment5: String = ""
	@State private var stopComment6: String = ""
	@State private var fuelStop1Image1: Data?
	@State private var fuelStop1Image2: Data?
	@State private var fuelStop1Image3: Data?
	@State private var fuelStop2Image1: Data?
	@State private var fuelStop2Image2: Data?
	@State private var fuelStop2Image3: Data?
	@State private var fuelStop3Image1: Data?
	@State private var fuelStop3Image2: Data?
	@State private var fuelStop3Image3: Data?
	@State private var fuelStop4Image1: Data?
	@State private var fuelStop4Image2: Data?
	@State private var fuelStop4Image3: Data?
	@State private var fuelStop5Image1: Data?
	@State private var fuelStop5Image2: Data?
	@State private var fuelStop5Image3: Data?
	@State private var fuelStop6Image1: Data?
	@State private var fuelStop6Image2: Data?
	@State private var fuelStop6Image3: Data?

	// Fuel-log levels and fuel type captured per enroute stop. These are stored on the
	// linked FuelLog1 record rather than on TripLog2.
	@State private var stopFuelLevelStart1: Float = 0.25
	@State private var stopFuelLevelEnd1: Float = 1.0
	@State private var stopDefLevel1: Float = 0.0
	@State private var stopFuelType1: String = ""
	@State private var stopFuelLevelStart2: Float = 0.25
	@State private var stopFuelLevelEnd2: Float = 1.0
	@State private var stopDefLevel2: Float = 0.0
	@State private var stopFuelType2: String = ""
	@State private var stopFuelLevelStart3: Float = 0.25
	@State private var stopFuelLevelEnd3: Float = 1.0
	@State private var stopDefLevel3: Float = 0.0
	@State private var stopFuelType3: String = ""
	@State private var stopFuelLevelStart4: Float = 0.25
	@State private var stopFuelLevelEnd4: Float = 1.0
	@State private var stopDefLevel4: Float = 0.0
	@State private var stopFuelType4: String = ""
	@State private var stopFuelLevelStart5: Float = 0.25
	@State private var stopFuelLevelEnd5: Float = 1.0
	@State private var stopDefLevel5: Float = 0.0
	@State private var stopFuelType5: String = ""
	@State private var stopFuelLevelStart6: Float = 0.25
	@State private var stopFuelLevelEnd6: Float = 1.0
	@State private var stopDefLevel6: Float = 0.0
	@State private var stopFuelType6: String = ""
	// Actual fuel/DEF quantities per stop, stored on the linked FuelLog1 alongside the fractions.
	@State private var stopFuelQtyStart1: Float = 0.0
	@State private var stopFuelQtyEnd1: Float = 0.0
	@State private var stopDefQty1: Float = 0.0
	@State private var stopFuelQtyStart2: Float = 0.0
	@State private var stopFuelQtyEnd2: Float = 0.0
	@State private var stopDefQty2: Float = 0.0
	@State private var stopFuelQtyStart3: Float = 0.0
	@State private var stopFuelQtyEnd3: Float = 0.0
	@State private var stopDefQty3: Float = 0.0
	@State private var stopFuelQtyStart4: Float = 0.0
	@State private var stopFuelQtyEnd4: Float = 0.0
	@State private var stopDefQty4: Float = 0.0
	@State private var stopFuelQtyStart5: Float = 0.0
	@State private var stopFuelQtyEnd5: Float = 0.0
	@State private var stopDefQty5: Float = 0.0
	@State private var stopFuelQtyStart6: Float = 0.0
	@State private var stopFuelQtyEnd6: Float = 0.0
	@State private var stopDefQty6: Float = 0.0
	// DEF level before adding any, per stop. stopDefLevel/stopDefQty above are after adding.
	@State private var stopDefLevelStart1: Float = 0.0
	@State private var stopDefQtyStart1: Float = 0.0
	@State private var stopDefLevelStart2: Float = 0.0
	@State private var stopDefQtyStart2: Float = 0.0
	@State private var stopDefLevelStart3: Float = 0.0
	@State private var stopDefQtyStart3: Float = 0.0
	@State private var stopDefLevelStart4: Float = 0.0
	@State private var stopDefQtyStart4: Float = 0.0
	@State private var stopDefLevelStart5: Float = 0.0
	@State private var stopDefQtyStart5: Float = 0.0
	@State private var stopDefLevelStart6: Float = 0.0
	@State private var stopDefQtyStart6: Float = 0.0
	// Price per unit of DEF added at each stop, stored on the linked FuelLog1.
	@State private var stopDefPrice1: Float = 0.0
	@State private var stopDefPrice2: Float = 0.0
	@State private var stopDefPrice3: Float = 0.0
	@State private var stopDefPrice4: Float = 0.0
	@State private var stopDefPrice5: Float = 0.0
	@State private var stopDefPrice6: Float = 0.0

	// Fluid checks recorded at travel start and travel end
	@State private var startOilChecked: Bool = false
	@State private var startEngineCoolantChecked: Bool = false
	@State private var startSecondaryCoolantChecked: Bool = false
	@State private var startPowerSteeringChecked: Bool = false
	@State private var startBrakeFluidChecked: Bool = false
	@State private var startTransmissionFluidChecked: Bool = false
	@State private var startRearAxleChecked: Bool = false
	@State private var startFrontAxleChecked: Bool = false
	@State private var startFuelWaterSeparatorChecked: Bool = false
	@State private var startAirSystemWaterBleedChecked: Bool = false
	@State private var endOilChecked: Bool = false
	@State private var endEngineCoolantChecked: Bool = false
	@State private var endSecondaryCoolantChecked: Bool = false
	@State private var endPowerSteeringChecked: Bool = false
	@State private var endBrakeFluidChecked: Bool = false
	@State private var endTransmissionFluidChecked: Bool = false
	@State private var endRearAxleChecked: Bool = false
	@State private var endFrontAxleChecked: Bool = false
	@State private var endFuelWaterSeparatorChecked: Bool = false
	@State private var endAirSystemWaterBleedChecked: Bool = false
	@State private var showStartFluidChecks: Bool = false
	@State private var showEndFluidChecks: Bool = false

	// New: ModelPicker selections
	@State private var selectedVehicle: Vehicle8? = nil
	@State private var selectedTowedVehicle: Vehicle8? = nil
	@State private var tripGroup: String = ""
	@State private var availableGroups: [String] = []
	@State private var availableFuelLogs: [FuelLogChoice] = []
	/// Stops the user explicitly set back to "New Log", so saving must not re-attach the
	/// record they just unlinked by matching on odometer.
	@State private var stopsForcedNew: Set<Int> = []
	@State private var tripGroupSelection: String = "__none__"

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
		self._defLevel1 = State.init(initialValue: dataSet.defLevel1)
		self._defLevelFraction = State.init(initialValue: dataSet.defLevelFraction)
		self._defLevelEnd1 = State.init(initialValue: dataSet.defLevelEnd1)
		self._defLevelEndFraction = State.init(initialValue: dataSet.defLevelEndFraction)
		self._defQuantityStart = State.init(initialValue: dataSet.defQuantityStart)
		self._defQuantityEnd = State.init(initialValue: dataSet.defQuantityEnd)
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
		// A stop with no recorded entry time is treated as starting now. An entry time with
		// no exit time means no departure was logged, so exit starts out matching entry —
		// for a new stop that makes both "now", and it never reads as a bogus stop duration.
		let stopStart1 = dataSet.fuelDateTime1 ?? Date()
		let stopStart2 = dataSet.fuelDateTime2 ?? Date()
		let stopStart3 = dataSet.fuelDateTime3 ?? Date()
		let stopStart4 = dataSet.fuelDateTime4 ?? Date()
		let stopStart5 = dataSet.fuelDateTime5 ?? Date()
		let stopStart6 = dataSet.fuelDateTime6 ?? Date()
		self._fuelDateTime1 = State.init(initialValue: stopStart1)
		self._fuelDateTime2 = State.init(initialValue: stopStart2)
		self._fuelDateTime3 = State.init(initialValue: stopStart3)
		self._fuelDateTime4 = State.init(initialValue: stopStart4)
		self._fuelDateTime5 = State.init(initialValue: stopStart5)
		self._fuelDateTime6 = State.init(initialValue: stopStart6)
		self._fuelExitTime1 = State.init(initialValue: dataSet.fuelExitTime1 ?? stopStart1)
		self._fuelExitTime2 = State.init(initialValue: dataSet.fuelExitTime2 ?? stopStart2)
		self._fuelExitTime3 = State.init(initialValue: dataSet.fuelExitTime3 ?? stopStart3)
		self._fuelExitTime4 = State.init(initialValue: dataSet.fuelExitTime4 ?? stopStart4)
		self._fuelExitTime5 = State.init(initialValue: dataSet.fuelExitTime5 ?? stopStart5)
		self._fuelExitTime6 = State.init(initialValue: dataSet.fuelExitTime6 ?? stopStart6)
		self._stopReason1 = State.init(initialValue: dataSet.stopReason1)
		self._stopReason2 = State.init(initialValue: dataSet.stopReason2)
		self._stopReason3 = State.init(initialValue: dataSet.stopReason3)
		self._stopReason4 = State.init(initialValue: dataSet.stopReason4)
		self._stopReason5 = State.init(initialValue: dataSet.stopReason5)
		self._stopReason6 = State.init(initialValue: dataSet.stopReason6)
		self._stopComment1 = State.init(initialValue: dataSet.stopComment1)
		self._stopComment2 = State.init(initialValue: dataSet.stopComment2)
		self._stopComment3 = State.init(initialValue: dataSet.stopComment3)
		self._stopComment4 = State.init(initialValue: dataSet.stopComment4)
		self._stopComment5 = State.init(initialValue: dataSet.stopComment5)
		self._stopComment6 = State.init(initialValue: dataSet.stopComment6)
		self._fuelLocation1 = State.init(initialValue: dataSet.fuelLocation1)
		self._fuelLocation2 = State.init(initialValue: dataSet.fuelLocation2)
		self._fuelLocation3 = State.init(initialValue: dataSet.fuelLocation3)
		self._fuelLocation4 = State.init(initialValue: dataSet.fuelLocation4)
		self._fuelLocation5 = State.init(initialValue: dataSet.fuelLocation5)
		self._fuelLocation6 = State.init(initialValue: dataSet.fuelLocation6)
		self._fuelStop1Image1 = State.init(initialValue: dataSet.fuelStop1Image1)
		self._fuelStop1Image2 = State.init(initialValue: dataSet.fuelStop1Image2)
		self._fuelStop1Image3 = State.init(initialValue: dataSet.fuelStop1Image3)
		self._fuelStop2Image1 = State.init(initialValue: dataSet.fuelStop2Image1)
		self._fuelStop2Image2 = State.init(initialValue: dataSet.fuelStop2Image2)
		self._fuelStop2Image3 = State.init(initialValue: dataSet.fuelStop2Image3)
		self._fuelStop3Image1 = State.init(initialValue: dataSet.fuelStop3Image1)
		self._fuelStop3Image2 = State.init(initialValue: dataSet.fuelStop3Image2)
		self._fuelStop3Image3 = State.init(initialValue: dataSet.fuelStop3Image3)
		self._fuelStop4Image1 = State.init(initialValue: dataSet.fuelStop4Image1)
		self._fuelStop4Image2 = State.init(initialValue: dataSet.fuelStop4Image2)
		self._fuelStop4Image3 = State.init(initialValue: dataSet.fuelStop4Image3)
		self._fuelStop5Image1 = State.init(initialValue: dataSet.fuelStop5Image1)
		self._fuelStop5Image2 = State.init(initialValue: dataSet.fuelStop5Image2)
		self._fuelStop5Image3 = State.init(initialValue: dataSet.fuelStop5Image3)
		self._fuelStop6Image1 = State.init(initialValue: dataSet.fuelStop6Image1)
		self._fuelStop6Image2 = State.init(initialValue: dataSet.fuelStop6Image2)
		self._fuelStop6Image3 = State.init(initialValue: dataSet.fuelStop6Image3)
		self._startOilChecked = State.init(initialValue: dataSet.startOilChecked)
		self._startEngineCoolantChecked = State.init(initialValue: dataSet.startEngineCoolantChecked)
		self._startSecondaryCoolantChecked = State.init(initialValue: dataSet.startSecondaryCoolantChecked)
		self._startPowerSteeringChecked = State.init(initialValue: dataSet.startPowerSteeringChecked)
		self._startBrakeFluidChecked = State.init(initialValue: dataSet.startBrakeFluidChecked)
		self._startTransmissionFluidChecked = State.init(initialValue: dataSet.startTransmissionFluidChecked)
		self._startRearAxleChecked = State.init(initialValue: dataSet.startRearAxleChecked)
		self._startFrontAxleChecked = State.init(initialValue: dataSet.startFrontAxleChecked)
		self._startFuelWaterSeparatorChecked = State.init(initialValue: dataSet.startFuelWaterSeparatorChecked)
		self._startAirSystemWaterBleedChecked = State.init(initialValue: dataSet.startAirSystemWaterBleedChecked)
		self._endOilChecked = State.init(initialValue: dataSet.endOilChecked)
		self._endEngineCoolantChecked = State.init(initialValue: dataSet.endEngineCoolantChecked)
		self._endSecondaryCoolantChecked = State.init(initialValue: dataSet.endSecondaryCoolantChecked)
		self._endPowerSteeringChecked = State.init(initialValue: dataSet.endPowerSteeringChecked)
		self._endBrakeFluidChecked = State.init(initialValue: dataSet.endBrakeFluidChecked)
		self._endTransmissionFluidChecked = State.init(initialValue: dataSet.endTransmissionFluidChecked)
		self._endRearAxleChecked = State.init(initialValue: dataSet.endRearAxleChecked)
		self._endFrontAxleChecked = State.init(initialValue: dataSet.endFrontAxleChecked)
		self._endFuelWaterSeparatorChecked = State.init(initialValue: dataSet.endFuelWaterSeparatorChecked)
		self._endAirSystemWaterBleedChecked = State.init(initialValue: dataSet.endAirSystemWaterBleedChecked)
		let group = dataSet.tripGroup
		self._tripGroup = State(initialValue: group)
		self._tripGroupSelection = State(initialValue: group.isEmpty ? "__none__" : group)

		// Start in edit mode if requested
		self._isEditing = State(initialValue: startEditing)
	}
	
	// MARK: - Details section visibility
	// Card sections in Details mode are only rendered when at least one of their
	// fields holds data, so a section title never appears above an empty card.

	/// True when at least one enroute stop was recorded (fuel added or a stop reason).
	private var hasStopsEnroute: Bool {
		dataSet.fuelAdded1 > 0 || !stopReason1.isEmpty
			|| dataSet.fuelAdded2 > 0 || !stopReason2.isEmpty
			|| dataSet.fuelAdded3 > 0 || !stopReason3.isEmpty
			|| dataSet.fuelAdded4 > 0 || !stopReason4.isEmpty
			|| dataSet.fuelAdded5 > 0 || !stopReason5.isEmpty
			|| dataSet.fuelAdded6 > 0 || !stopReason6.isEmpty
	}

	/// True when at least one image is attached.
	private var hasGraphics: Bool {
		dataSet.image1 != nil || dataSet.image2 != nil || dataSet.image3 != nil
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
								title: Vertical.current.assetSingular,
								includeEmptyChoice: false,
								emptyChoiceLabel: "—",
								filter: showInactiveVehicles ? nil : #Predicate<Vehicle8> { $0.inactive == false },
								sort: [SortDescriptor(\.displayName, order: .forward)],
								labelProvider: { v in "\(v.year) \(v.displayName)"},
								thumbnailData: { $0.image1 }
							)
							.onChange(of: selectedVehicle) { oldVehicle, newVehicle in
								let name = newVehicle?.name ?? ""
								vehicleId = name
								dataSet.vehicleId = name
								refreshVehicleDetails()
								// Rescale the tanks only when the vehicle genuinely changed. Seeding this picker on
								// appear also fires this handler, and rescaling then would replace exact typed
								// quantities with their eighths equivalents.
								if let previous = oldVehicle, previous.name != name {
									recomputeFuelQuantities()
								}
								loadAvailableFuelLogs()
							}
							.fixedSize(horizontal: true, vertical: true)
						} label: {
							Text(Vertical.current.assetSingular)
								.textLabelModified()
						}

						HStack{LabelDataTextview(label: "Log Name", data: $logName)}
						LabeledContent {
							Picker("", selection: $tripGroupSelection) {
								Text("— No Group —").tag("__none__")
								ForEach(availableGroups, id: \.self) { grp in
									Text(grp).tag(grp)
								}
								Text("New Group...").tag("__new__")
							}
							.pickerStyle(.menu)
							.fixedSize()
							.onChange(of: tripGroupSelection) { _, newVal in
								if newVal == "__none__" {
									tripGroup = ""
								} else if newVal != "__new__" {
									tripGroup = newVal
								}
							}
						} label: {
							Text("Trip Group")
								.textLabelModified()
						}
						if tripGroupSelection == "__new__" {
							HStack{LabelDataTextview(label: "Group Name", data: $tripGroup)}
						}
						HStack{LabelDataToggle(label: "Towed \(Vertical.current.assetSingular)", data: $vehicleTowed)}

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
									labelProvider: { $0.displayName },
									thumbnailData: { $0.image1 }
								)
								.onChange(of: selectedTowedVehicle) { _, newVehicle in
									let name = newVehicle?.name ?? ""
									vehicleIdTowed = name
									dataSet.vehicleIdTowed = name
								}
								.fixedSize(horizontal: true, vertical: true)
							} label: {
								Text("Towed \(Vertical.current.assetSingular)")
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
						HStack{LabelDataTextview_Numberpad_Int(label: Vertical.current.primaryMeterLabel, data: $odometerStart)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursStart)}
						HStack{LabelLocationTextview(label: "Location", data: $locationStart)}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level", data: $fuelLevelStart1, data1: Float(vehicleDetails?.fuelCapacity ?? 0), quantity: $fuelQuantityStart)
								// Choosing an eighth fills in the quantity. Typing a quantity is left alone — it is
								// reconciled back to the nearest eighth on save, so the two can't fight each other.
								.onChange(of: fuelLevelStart1) { _, newFraction in
									fuelQuantityStart = Float(vehicleDetails?.fuelCapacity ?? 0) * newFraction
									fuelLevelStart = functions.getFuelLevel(unit: newFraction)
									recomputeFuelConsumed()
								}
								.onChange(of: fuelQuantityStart) { _, _ in
									recomputeFuelConsumed()
								}
						}
						HStack{
							Picker_FuelLevel1(label: "DEF Level", data: $defLevel1, data1: Float(vehicleDetails?.defCapacity ?? 0), quantity: $defQuantityStart)
								.onChange(of: defLevel1) { _, newFraction in
									defQuantityStart = Float(vehicleDetails?.defCapacity ?? 0) * newFraction
									defLevelFraction = functions.getFuelLevel(unit: newFraction)
								}
						}
						HStack {
							Spacer()
							Button {
								showStartFluidChecks = true
							} label: {
								Label(fluidChecksTitle(startFluidChecks), systemImage: "drop.circle")
							}
							.buttonStyle(.bordered)
							Spacer()
						}
						.sheet(isPresented: $showStartFluidChecks) {
							FluidCheckSheet(
								oilChecked: $startOilChecked,
								engineCoolantChecked: $startEngineCoolantChecked,
								secondaryCoolantChecked: $startSecondaryCoolantChecked,
								powerSteeringChecked: $startPowerSteeringChecked,
								brakeFluidChecked: $startBrakeFluidChecked,
								transmissionFluidChecked: $startTransmissionFluidChecked,
								rearAxleChecked: $startRearAxleChecked,
								frontAxleChecked: $startFrontAxleChecked,
								fuelWaterSeparatorChecked: $startFuelWaterSeparatorChecked,
								airSystemWaterBleedChecked: $startAirSystemWaterBleedChecked
							)
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "ENROUTE STOPS")
						SectionBanner(label: "STOP 1")
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
								oilChecked: $oilChecked1,
								engineCoolantChecked: $engineCoolantChecked1,
								secondaryCoolantChecked: $secondaryCoolantChecked1,
								powerSteeringChecked: $powerSteeringChecked1,
								brakeFluidChecked: $brakeFluidChecked1,
								transmissionFluidChecked: $transmissionFluidChecked1,
								rearAxleChecked: $rearAxleChecked1,
								frontAxleChecked: $frontAxleChecked1,
								fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked1,
								airSystemWaterBleedChecked: $airSystemWaterBleedChecked1,
							fuelDateTime: $fuelDateTime1,
							fuelImage1: $fuelStop1Image1,
							fuelImage2: $fuelStop1Image2,
							fuelImage3: $fuelStop1Image3,
							fuelExitTime: $fuelExitTime1,
							stopReason: $stopReason1,
							stopComment: $stopComment1,
							fuelLevelStart: $stopFuelLevelStart1,
							fuelLevelEnd: $stopFuelLevelEnd1,
							defLevel: $stopDefLevel1,
							fuelType: $stopFuelType1,
							fuelQuantityStart: $stopFuelQtyStart1,
							fuelQuantityEnd: $stopFuelQtyEnd1,
							defQuantity: $stopDefQty1,
							defLevelStart: $stopDefLevelStart1,
							defQuantityStart: $stopDefQtyStart1,
							defPrice: $stopDefPrice1,
							fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
							defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
							linkedLogId: $fuelAdded1Log,
							fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded1Log),
							onLinkFuelLog: { newId in linkStop(1, to: newId) }
							)
						}
						if fuelAdded1 > 0 || !stopReason1.isEmpty {
							Divider()
						SectionBanner(label: "STOP 2")
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
									oilChecked: $oilChecked2,
									engineCoolantChecked: $engineCoolantChecked2,
									secondaryCoolantChecked: $secondaryCoolantChecked2,
									powerSteeringChecked: $powerSteeringChecked2,
									brakeFluidChecked: $brakeFluidChecked2,
									transmissionFluidChecked: $transmissionFluidChecked2,
									rearAxleChecked: $rearAxleChecked2,
									frontAxleChecked: $frontAxleChecked2,
									fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked2,
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked2,
								fuelDateTime: $fuelDateTime2,
								fuelImage1: $fuelStop2Image1,
								fuelImage2: $fuelStop2Image2,
								fuelImage3: $fuelStop2Image3,
								fuelExitTime: $fuelExitTime2,
								stopReason: $stopReason2,
								stopComment: $stopComment2,
								fuelLevelStart: $stopFuelLevelStart2,
								fuelLevelEnd: $stopFuelLevelEnd2,
								defLevel: $stopDefLevel2,
								fuelType: $stopFuelType2,
								fuelQuantityStart: $stopFuelQtyStart2,
								fuelQuantityEnd: $stopFuelQtyEnd2,
								defQuantity: $stopDefQty2,
								defLevelStart: $stopDefLevelStart2,
								defQuantityStart: $stopDefQtyStart2,
								defPrice: $stopDefPrice2,
								fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
								defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
								linkedLogId: $fuelAdded2Log,
								fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded2Log),
								onLinkFuelLog: { newId in linkStop(2, to: newId) }
								)
							}
						}
						if fuelAdded2 > 0 || !stopReason2.isEmpty {
							Divider()
						SectionBanner(label: "STOP 3")
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
									oilChecked: $oilChecked3,
									engineCoolantChecked: $engineCoolantChecked3,
									secondaryCoolantChecked: $secondaryCoolantChecked3,
									powerSteeringChecked: $powerSteeringChecked3,
									brakeFluidChecked: $brakeFluidChecked3,
									transmissionFluidChecked: $transmissionFluidChecked3,
									rearAxleChecked: $rearAxleChecked3,
									frontAxleChecked: $frontAxleChecked3,
									fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked3,
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked3,
								fuelDateTime: $fuelDateTime3,
								fuelImage1: $fuelStop3Image1,
								fuelImage2: $fuelStop3Image2,
								fuelImage3: $fuelStop3Image3,
								fuelExitTime: $fuelExitTime3,
								stopReason: $stopReason3,
								stopComment: $stopComment3,
								fuelLevelStart: $stopFuelLevelStart3,
								fuelLevelEnd: $stopFuelLevelEnd3,
								defLevel: $stopDefLevel3,
								fuelType: $stopFuelType3,
								fuelQuantityStart: $stopFuelQtyStart3,
								fuelQuantityEnd: $stopFuelQtyEnd3,
								defQuantity: $stopDefQty3,
								defLevelStart: $stopDefLevelStart3,
								defQuantityStart: $stopDefQtyStart3,
								defPrice: $stopDefPrice3,
								fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
								defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
								linkedLogId: $fuelAdded3Log,
								fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded3Log),
								onLinkFuelLog: { newId in linkStop(3, to: newId) }
								)
							}
						}
						if fuelAdded3 > 0 || !stopReason3.isEmpty {
							Divider()
						SectionBanner(label: "STOP 4")
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
									oilChecked: $oilChecked4,
									engineCoolantChecked: $engineCoolantChecked4,
									secondaryCoolantChecked: $secondaryCoolantChecked4,
									powerSteeringChecked: $powerSteeringChecked4,
									brakeFluidChecked: $brakeFluidChecked4,
									transmissionFluidChecked: $transmissionFluidChecked4,
									rearAxleChecked: $rearAxleChecked4,
									frontAxleChecked: $frontAxleChecked4,
									fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked4,
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked4,
								fuelDateTime: $fuelDateTime4,
								fuelImage1: $fuelStop4Image1,
								fuelImage2: $fuelStop4Image2,
								fuelImage3: $fuelStop4Image3,
								fuelExitTime: $fuelExitTime4,
								stopReason: $stopReason4,
								stopComment: $stopComment4,
								fuelLevelStart: $stopFuelLevelStart4,
								fuelLevelEnd: $stopFuelLevelEnd4,
								defLevel: $stopDefLevel4,
								fuelType: $stopFuelType4,
								fuelQuantityStart: $stopFuelQtyStart4,
								fuelQuantityEnd: $stopFuelQtyEnd4,
								defQuantity: $stopDefQty4,
								defLevelStart: $stopDefLevelStart4,
								defQuantityStart: $stopDefQtyStart4,
								defPrice: $stopDefPrice4,
								fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
								defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
								linkedLogId: $fuelAdded4Log,
								fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded4Log),
								onLinkFuelLog: { newId in linkStop(4, to: newId) }
								)
							}
						}
						if fuelAdded4 > 0 || !stopReason4.isEmpty {
							Divider()
						SectionBanner(label: "STOP 5")
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
									oilChecked: $oilChecked5,
									engineCoolantChecked: $engineCoolantChecked5,
									secondaryCoolantChecked: $secondaryCoolantChecked5,
									powerSteeringChecked: $powerSteeringChecked5,
									brakeFluidChecked: $brakeFluidChecked5,
									transmissionFluidChecked: $transmissionFluidChecked5,
									rearAxleChecked: $rearAxleChecked5,
									frontAxleChecked: $frontAxleChecked5,
									fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked5,
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked5,
								fuelDateTime: $fuelDateTime5,
								fuelImage1: $fuelStop5Image1,
								fuelImage2: $fuelStop5Image2,
								fuelImage3: $fuelStop5Image3,
								fuelExitTime: $fuelExitTime5,
								stopReason: $stopReason5,
								stopComment: $stopComment5,
								fuelLevelStart: $stopFuelLevelStart5,
								fuelLevelEnd: $stopFuelLevelEnd5,
								defLevel: $stopDefLevel5,
								fuelType: $stopFuelType5,
								fuelQuantityStart: $stopFuelQtyStart5,
								fuelQuantityEnd: $stopFuelQtyEnd5,
								defQuantity: $stopDefQty5,
								defLevelStart: $stopDefLevelStart5,
								defQuantityStart: $stopDefQtyStart5,
								defPrice: $stopDefPrice5,
								fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
								defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
								linkedLogId: $fuelAdded5Log,
								fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded5Log),
								onLinkFuelLog: { newId in linkStop(5, to: newId) }
								)
							}
						}
						if fuelAdded5 > 0 || !stopReason5.isEmpty {
							Divider()
						SectionBanner(label: "STOP 6")
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
									oilChecked: $oilChecked6,
									engineCoolantChecked: $engineCoolantChecked6,
									secondaryCoolantChecked: $secondaryCoolantChecked6,
									powerSteeringChecked: $powerSteeringChecked6,
									brakeFluidChecked: $brakeFluidChecked6,
									transmissionFluidChecked: $transmissionFluidChecked6,
									rearAxleChecked: $rearAxleChecked6,
									frontAxleChecked: $frontAxleChecked6,
									fuelWaterSeparatorChecked: $fuelWaterSeparatorChecked6,
									airSystemWaterBleedChecked: $airSystemWaterBleedChecked6,
								fuelDateTime: $fuelDateTime6,
								fuelImage1: $fuelStop6Image1,
								fuelImage2: $fuelStop6Image2,
								fuelImage3: $fuelStop6Image3,
								fuelExitTime: $fuelExitTime6,
								stopReason: $stopReason6,
								stopComment: $stopComment6,
								fuelLevelStart: $stopFuelLevelStart6,
								fuelLevelEnd: $stopFuelLevelEnd6,
								defLevel: $stopDefLevel6,
								fuelType: $stopFuelType6,
								fuelQuantityStart: $stopFuelQtyStart6,
								fuelQuantityEnd: $stopFuelQtyEnd6,
								defQuantity: $stopDefQty6,
								defLevelStart: $stopDefLevelStart6,
								defQuantityStart: $stopDefQtyStart6,
								defPrice: $stopDefPrice6,
								fuelCapacity: Float(vehicleDetails?.fuelCapacity ?? 0),
								defCapacity: Float(vehicleDetails?.defCapacity ?? 0),
								linkedLogId: $fuelAdded6Log,
								fuelLogChoices: fuelLogChoices(currentlyLinked: fuelAdded6Log),
								onLinkFuelLog: { newId in linkStop(6, to: newId) }
								)
							}
						}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL END")
						HStack{LabelDataPicker_DateTime(label: "Date/Time                    ", data: $tripDateTimeEnd)}
						HStack{LabelDataTextview_Numberpad_Int(label: Vertical.current.primaryMeterLabel, data: $odometerEnd)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Engine Hours:", data: $engHoursEnd)}
						HStack{LabelLocationTextview(label: "Location", data: $locationEnd)}
						HStack{
							Picker_FuelLevel1(label: "Fuel Level", data: $fuelLevelEnd1, data1: Float(vehicleDetails?.fuelCapacity ?? 0), quantity: $fuelQuantityEnd)
								.onChange(of: fuelLevelEnd1) { _, newFraction in
									fuelQuantityEnd = Float(vehicleDetails?.fuelCapacity ?? 0) * newFraction
									fuelLevelEnd = functions.getFuelLevel(unit: newFraction)
									recomputeFuelConsumed()
								}
								.onChange(of: fuelQuantityEnd) { _, _ in
									recomputeFuelConsumed()
								}
						}
						HStack{
							Picker_FuelLevel1(label: "DEF Level", data: $defLevelEnd1, data1: Float(vehicleDetails?.defCapacity ?? 0), quantity: $defQuantityEnd)
								.onChange(of: defLevelEnd1) { _, newFraction in
									defQuantityEnd = Float(vehicleDetails?.defCapacity ?? 0) * newFraction
									defLevelEndFraction = functions.getFuelLevel(unit: newFraction)
								}
						}
						HStack {
							Spacer()
							Button {
								showEndFluidChecks = true
							} label: {
								Label(fluidChecksTitle(endFluidChecks), systemImage: "drop.circle")
							}
							.buttonStyle(.bordered)
							Spacer()
						}
						.sheet(isPresented: $showEndFluidChecks) {
							FluidCheckSheet(
								oilChecked: $endOilChecked,
								engineCoolantChecked: $endEngineCoolantChecked,
								secondaryCoolantChecked: $endSecondaryCoolantChecked,
								powerSteeringChecked: $endPowerSteeringChecked,
								brakeFluidChecked: $endBrakeFluidChecked,
								transmissionFluidChecked: $endTransmissionFluidChecked,
								rearAxleChecked: $endRearAxleChecked,
								frontAxleChecked: $endFrontAxleChecked,
								fuelWaterSeparatorChecked: $endFuelWaterSeparatorChecked,
								airSystemWaterBleedChecked: $endAirSystemWaterBleedChecked
							)
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
						HStack{LabelDataToggle(label: "Deactivate \(Vertical.current.travelLogLabel) Record", data: $inactive)}
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
				loadAvailableGroups()
				loadAvailableFuelLogs()
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
				backfillDefQuantities()
				seedStopQuantities()
				// Only the consumed estimate: the stored quantities may be typed exact figures.
				recomputeFuelConsumed()
				// Load fuel log data for enroute stops so fields are pre-populated in edit mode
				if fuelAdded1Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded1Log)
					fuelPrice1 = d.fuelPrice; fuelOdometer1 = d.fuelOdometer; fuelEngHours1 = d.fuelEngHours
					fuelLocation1 = d.fuelLocation; oilAdded1 = d.oilAdded; defAdded1 = d.defAdded
					fuelNotes1 = d.fuelNotes; oilChecked1 = d.oilChecked; engineCoolantChecked1 = d.engineCoolantChecked; secondaryCoolantChecked1 = d.secondaryCoolantChecked; powerSteeringChecked1 = d.powerSteeringChecked; brakeFluidChecked1 = d.brakeFluidChecked; transmissionFluidChecked1 = d.transmissionFluidChecked; rearAxleChecked1 = d.rearAxleChecked; frontAxleChecked1 = d.frontAxleChecked; fuelWaterSeparatorChecked1 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked1 = d.airSystemWaterBleedChecked; fuelDateTime1 = d.fuelDateTime
					fuelStop1Image1 = d.image1; fuelStop1Image2 = d.image2; fuelStop1Image3 = d.image3
					stopFuelLevelStart1 = d.fuelLevelStart; stopFuelLevelEnd1 = d.fuelLevelEnd; stopDefLevel1 = d.defLevel; stopFuelType1 = d.fuelType
					stopFuelQtyStart1 = d.fuelQuantityStart; stopFuelQtyEnd1 = d.fuelQuantityEnd; stopDefQty1 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart1 = d.defLevelStart; stopDefQtyStart1 = d.defQuantityStart
					stopDefPrice1 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime1 = max(exit, fuelDateTime1) }
					createFuelLog1 = true
				}
				if fuelAdded2Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded2Log)
					fuelPrice2 = d.fuelPrice; fuelOdometer2 = d.fuelOdometer; fuelEngHours2 = d.fuelEngHours
					fuelLocation2 = d.fuelLocation; oilAdded2 = d.oilAdded; defAdded2 = d.defAdded
					fuelNotes2 = d.fuelNotes; oilChecked2 = d.oilChecked; engineCoolantChecked2 = d.engineCoolantChecked; secondaryCoolantChecked2 = d.secondaryCoolantChecked; powerSteeringChecked2 = d.powerSteeringChecked; brakeFluidChecked2 = d.brakeFluidChecked; transmissionFluidChecked2 = d.transmissionFluidChecked; rearAxleChecked2 = d.rearAxleChecked; frontAxleChecked2 = d.frontAxleChecked; fuelWaterSeparatorChecked2 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked2 = d.airSystemWaterBleedChecked; fuelDateTime2 = d.fuelDateTime
					fuelStop2Image1 = d.image1; fuelStop2Image2 = d.image2; fuelStop2Image3 = d.image3
					stopFuelLevelStart2 = d.fuelLevelStart; stopFuelLevelEnd2 = d.fuelLevelEnd; stopDefLevel2 = d.defLevel; stopFuelType2 = d.fuelType
					stopFuelQtyStart2 = d.fuelQuantityStart; stopFuelQtyEnd2 = d.fuelQuantityEnd; stopDefQty2 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart2 = d.defLevelStart; stopDefQtyStart2 = d.defQuantityStart
					stopDefPrice2 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime2 = max(exit, fuelDateTime2) }
					createFuelLog2 = true
				}
				if fuelAdded3Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded3Log)
					fuelPrice3 = d.fuelPrice; fuelOdometer3 = d.fuelOdometer; fuelEngHours3 = d.fuelEngHours
					fuelLocation3 = d.fuelLocation; oilAdded3 = d.oilAdded; defAdded3 = d.defAdded
					fuelNotes3 = d.fuelNotes; oilChecked3 = d.oilChecked; engineCoolantChecked3 = d.engineCoolantChecked; secondaryCoolantChecked3 = d.secondaryCoolantChecked; powerSteeringChecked3 = d.powerSteeringChecked; brakeFluidChecked3 = d.brakeFluidChecked; transmissionFluidChecked3 = d.transmissionFluidChecked; rearAxleChecked3 = d.rearAxleChecked; frontAxleChecked3 = d.frontAxleChecked; fuelWaterSeparatorChecked3 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked3 = d.airSystemWaterBleedChecked; fuelDateTime3 = d.fuelDateTime
					fuelStop3Image1 = d.image1; fuelStop3Image2 = d.image2; fuelStop3Image3 = d.image3
					stopFuelLevelStart3 = d.fuelLevelStart; stopFuelLevelEnd3 = d.fuelLevelEnd; stopDefLevel3 = d.defLevel; stopFuelType3 = d.fuelType
					stopFuelQtyStart3 = d.fuelQuantityStart; stopFuelQtyEnd3 = d.fuelQuantityEnd; stopDefQty3 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart3 = d.defLevelStart; stopDefQtyStart3 = d.defQuantityStart
					stopDefPrice3 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime3 = max(exit, fuelDateTime3) }
					createFuelLog3 = true
				}
				if fuelAdded4Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded4Log)
					fuelPrice4 = d.fuelPrice; fuelOdometer4 = d.fuelOdometer; fuelEngHours4 = d.fuelEngHours
					fuelLocation4 = d.fuelLocation; oilAdded4 = d.oilAdded; defAdded4 = d.defAdded
					fuelNotes4 = d.fuelNotes; oilChecked4 = d.oilChecked; engineCoolantChecked4 = d.engineCoolantChecked; secondaryCoolantChecked4 = d.secondaryCoolantChecked; powerSteeringChecked4 = d.powerSteeringChecked; brakeFluidChecked4 = d.brakeFluidChecked; transmissionFluidChecked4 = d.transmissionFluidChecked; rearAxleChecked4 = d.rearAxleChecked; frontAxleChecked4 = d.frontAxleChecked; fuelWaterSeparatorChecked4 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked4 = d.airSystemWaterBleedChecked; fuelDateTime4 = d.fuelDateTime
					fuelStop4Image1 = d.image1; fuelStop4Image2 = d.image2; fuelStop4Image3 = d.image3
					stopFuelLevelStart4 = d.fuelLevelStart; stopFuelLevelEnd4 = d.fuelLevelEnd; stopDefLevel4 = d.defLevel; stopFuelType4 = d.fuelType
					stopFuelQtyStart4 = d.fuelQuantityStart; stopFuelQtyEnd4 = d.fuelQuantityEnd; stopDefQty4 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart4 = d.defLevelStart; stopDefQtyStart4 = d.defQuantityStart
					stopDefPrice4 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime4 = max(exit, fuelDateTime4) }
					createFuelLog4 = true
				}
				if fuelAdded5Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded5Log)
					fuelPrice5 = d.fuelPrice; fuelOdometer5 = d.fuelOdometer; fuelEngHours5 = d.fuelEngHours
					fuelLocation5 = d.fuelLocation; oilAdded5 = d.oilAdded; defAdded5 = d.defAdded
					fuelNotes5 = d.fuelNotes; oilChecked5 = d.oilChecked; engineCoolantChecked5 = d.engineCoolantChecked; secondaryCoolantChecked5 = d.secondaryCoolantChecked; powerSteeringChecked5 = d.powerSteeringChecked; brakeFluidChecked5 = d.brakeFluidChecked; transmissionFluidChecked5 = d.transmissionFluidChecked; rearAxleChecked5 = d.rearAxleChecked; frontAxleChecked5 = d.frontAxleChecked; fuelWaterSeparatorChecked5 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked5 = d.airSystemWaterBleedChecked; fuelDateTime5 = d.fuelDateTime
					fuelStop5Image1 = d.image1; fuelStop5Image2 = d.image2; fuelStop5Image3 = d.image3
					stopFuelLevelStart5 = d.fuelLevelStart; stopFuelLevelEnd5 = d.fuelLevelEnd; stopDefLevel5 = d.defLevel; stopFuelType5 = d.fuelType
					stopFuelQtyStart5 = d.fuelQuantityStart; stopFuelQtyEnd5 = d.fuelQuantityEnd; stopDefQty5 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart5 = d.defLevelStart; stopDefQtyStart5 = d.defQuantityStart
					stopDefPrice5 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime5 = max(exit, fuelDateTime5) }
					createFuelLog5 = true
				}
				if fuelAdded6Log != "" {
					let d = getFuelLogData(saveLogId: fuelAdded6Log)
					fuelPrice6 = d.fuelPrice; fuelOdometer6 = d.fuelOdometer; fuelEngHours6 = d.fuelEngHours
					fuelLocation6 = d.fuelLocation; oilAdded6 = d.oilAdded; defAdded6 = d.defAdded
					fuelNotes6 = d.fuelNotes; oilChecked6 = d.oilChecked; engineCoolantChecked6 = d.engineCoolantChecked; secondaryCoolantChecked6 = d.secondaryCoolantChecked; powerSteeringChecked6 = d.powerSteeringChecked; brakeFluidChecked6 = d.brakeFluidChecked; transmissionFluidChecked6 = d.transmissionFluidChecked; rearAxleChecked6 = d.rearAxleChecked; frontAxleChecked6 = d.frontAxleChecked; fuelWaterSeparatorChecked6 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked6 = d.airSystemWaterBleedChecked; fuelDateTime6 = d.fuelDateTime
					fuelStop6Image1 = d.image1; fuelStop6Image2 = d.image2; fuelStop6Image3 = d.image3
					stopFuelLevelStart6 = d.fuelLevelStart; stopFuelLevelEnd6 = d.fuelLevelEnd; stopDefLevel6 = d.defLevel; stopFuelType6 = d.fuelType
					stopFuelQtyStart6 = d.fuelQuantityStart; stopFuelQtyEnd6 = d.fuelQuantityEnd; stopDefQty6 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
					stopDefLevelStart6 = d.defLevelStart; stopDefQtyStart6 = d.defQuantityStart
					stopDefPrice6 = d.defPrice
					if let exit = d.fuelExitTime { fuelExitTime6 = max(exit, fuelDateTime6) }
					createFuelLog6 = true
				}
			}
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button(isEditing ? "Cancel" : "Edit") {isEditing.toggle()}
						.buttonStyle(GrowingButton(buttonColor: Color.green))
				}
				ToolbarItem(placement: .automatic) {
					Button("Save") {
						// End editing so any field the user was still typing in writes
						// its value to the binding before it is read below.
						commitPendingTextEdits()
						// Give the field one run-loop turn to publish its committed
						// value into @State, then persist and leave edit mode.
						DispatchQueue.main.async {
							updateItem()
							isEditing = false
						}
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
									fuelDateTime1 = fuelLogData.fuelDateTime
									fuelStop1Image1 = fuelLogData.image1
									fuelStop1Image2 = fuelLogData.image2
									fuelStop1Image3 = fuelLogData.image3
									stopFuelLevelStart1 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd1 = fuelLogData.fuelLevelEnd
									stopDefLevel1 = fuelLogData.defLevel
									stopFuelType1 = fuelLogData.fuelType
									stopFuelQtyStart1 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd1 = fuelLogData.fuelQuantityEnd
									stopDefQty1 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart1 = fuelLogData.defLevelStart
									stopDefQtyStart1 = fuelLogData.defQuantityStart
									stopDefPrice1 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime1 = max(exit, fuelDateTime1) }
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
									fuelDateTime2 = fuelLogData.fuelDateTime
									fuelStop2Image1 = fuelLogData.image1
									fuelStop2Image2 = fuelLogData.image2
									fuelStop2Image3 = fuelLogData.image3
									stopFuelLevelStart2 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd2 = fuelLogData.fuelLevelEnd
									stopDefLevel2 = fuelLogData.defLevel
									stopFuelType2 = fuelLogData.fuelType
									stopFuelQtyStart2 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd2 = fuelLogData.fuelQuantityEnd
									stopDefQty2 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart2 = fuelLogData.defLevelStart
									stopDefQtyStart2 = fuelLogData.defQuantityStart
									stopDefPrice2 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime2 = max(exit, fuelDateTime2) }
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
									fuelDateTime3 = fuelLogData.fuelDateTime
									fuelStop3Image1 = fuelLogData.image1
									fuelStop3Image2 = fuelLogData.image2
									fuelStop3Image3 = fuelLogData.image3
									stopFuelLevelStart3 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd3 = fuelLogData.fuelLevelEnd
									stopDefLevel3 = fuelLogData.defLevel
									stopFuelType3 = fuelLogData.fuelType
									stopFuelQtyStart3 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd3 = fuelLogData.fuelQuantityEnd
									stopDefQty3 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart3 = fuelLogData.defLevelStart
									stopDefQtyStart3 = fuelLogData.defQuantityStart
									stopDefPrice3 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime3 = max(exit, fuelDateTime3) }
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
									fuelDateTime4 = fuelLogData.fuelDateTime
									fuelStop4Image1 = fuelLogData.image1
									fuelStop4Image2 = fuelLogData.image2
									fuelStop4Image3 = fuelLogData.image3
									stopFuelLevelStart4 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd4 = fuelLogData.fuelLevelEnd
									stopDefLevel4 = fuelLogData.defLevel
									stopFuelType4 = fuelLogData.fuelType
									stopFuelQtyStart4 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd4 = fuelLogData.fuelQuantityEnd
									stopDefQty4 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart4 = fuelLogData.defLevelStart
									stopDefQtyStart4 = fuelLogData.defQuantityStart
									stopDefPrice4 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime4 = max(exit, fuelDateTime4) }
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
									fuelDateTime5 = fuelLogData.fuelDateTime
									fuelStop5Image1 = fuelLogData.image1
									fuelStop5Image2 = fuelLogData.image2
									fuelStop5Image3 = fuelLogData.image3
									stopFuelLevelStart5 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd5 = fuelLogData.fuelLevelEnd
									stopDefLevel5 = fuelLogData.defLevel
									stopFuelType5 = fuelLogData.fuelType
									stopFuelQtyStart5 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd5 = fuelLogData.fuelQuantityEnd
									stopDefQty5 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart5 = fuelLogData.defLevelStart
									stopDefQtyStart5 = fuelLogData.defQuantityStart
									stopDefPrice5 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime5 = max(exit, fuelDateTime5) }
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
									fuelDateTime6 = fuelLogData.fuelDateTime
									fuelStop6Image1 = fuelLogData.image1
									fuelStop6Image2 = fuelLogData.image2
									fuelStop6Image3 = fuelLogData.image3
									stopFuelLevelStart6 = fuelLogData.fuelLevelStart
									stopFuelLevelEnd6 = fuelLogData.fuelLevelEnd
									stopDefLevel6 = fuelLogData.defLevel
									stopFuelType6 = fuelLogData.fuelType
									stopFuelQtyStart6 = fuelLogData.fuelQuantityStart
									stopFuelQtyEnd6 = fuelLogData.fuelQuantityEnd
									stopDefQty6 = defQuantityOrDerived(fuelLogData, capacity: Float(vehicleDetails?.defCapacity ?? 0))
									stopDefLevelStart6 = fuelLogData.defLevelStart
									stopDefQtyStart6 = fuelLogData.defQuantityStart
									stopDefPrice6 = fuelLogData.defPrice
									if let exit = fuelLogData.fuelExitTime { fuelExitTime6 = max(exit, fuelDateTime6) }
									createFuelLog6 = true
								}
							}
						HStack{LabelDataText(label: "Name", data: dataSet.logName)}
						if !tripGroup.isEmpty {
							HStack{LabelDataText(label: "Trip Group", data: tripGroup)}
						}
						HStack{LabelDataText(label: Vertical.current.assetSingular, data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleId, context: modelContext))}
						if dataSet.vehicleTowed {
							HStack{LabelDataText(label: "Towed \(Vertical.current.assetSingular)", data: Functions().getVehicleDisplayName(vehicleId: dataSet.vehicleIdTowed, context: modelContext))}
						}
							HStack{ LabelDataText(label: "Status", data: dataSet.inactive ? "Inactive" : "Active") }
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL START")
						HStack{LabelDataText(label: "Departure", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.tripDateTimeStart))")}
						HStack{LabelDataText(label: Vertical.current.primaryMeterLabel, data: "\(dataSet.odometerStart) \(unit(UnitIndex.distance))")}
						if dataSet.engHoursStart > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHoursStart, fractionalLength: 1)}
						}
						if dataSet.fuelLevelStart != "" {
							HStack{LabelDataText(label: "Fuel Level", data: "\(dataSet.fuelLevelStart) \(dataSet.fuelQuantityStart)\(unit(UnitIndex.fuel))")}
						}
						if dataSet.defLevelFraction != "" {
							let defQtyStart = dataSet.defQuantityStart > 0
							? dataSet.defQuantityStart
							: dataSet.defLevel1 * Float(vehicleDetails?.defCapacity ?? 0)
							let defQtyStartText = defQtyStart > 0 ? " \(defQtyStart.formatted(.number.precision(.fractionLength(1))))\(unit(UnitIndex.def))" : ""
							HStack{LabelDataText(label: "DEF Level", data: "\(dataSet.defLevelFraction)\(defQtyStartText)")}
						}
						if dataSet.locationStart != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationStart)")}
						}
						let startChecks = checkedFluidList([
							("Engine Oil", dataSet.startOilChecked),
							("Engine Coolant", dataSet.startEngineCoolantChecked),
							("Secondary Coolant", dataSet.startSecondaryCoolantChecked),
							("Power Steering", dataSet.startPowerSteeringChecked),
							("Brake", dataSet.startBrakeFluidChecked),
							("Transmission", dataSet.startTransmissionFluidChecked),
							("Rear Axle", dataSet.startRearAxleChecked),
							("Front Axle", dataSet.startFrontAxleChecked),
							("Fuel/Water Separator", dataSet.startFuelWaterSeparatorChecked),
							("Air System Water Bleed", dataSet.startAirSystemWaterBleedChecked)
						])
						if !startChecks.isEmpty {
							HStack{LabelDataText(label: "Fluids Checked", data: startChecks)}
						}
					}
				}
				
				// Hidden when no enroute stops were recorded
				if hasStopsEnroute {
					CardView {
					VStack {
						SectionText(label: "ENROUTE STOPS")
						if dataSet.fuelAdded1 > 0 || !stopReason1.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation1)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime1))")}
							if !stopReason1.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason1)} }
							if !stopComment1.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment1)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded1, fractionalLength: 1)}
							if !fuelAdded1Log.isEmpty {
								if !stopFuelType1.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType1)} }
								let fuelStartText1 = tankReading(fraction: stopFuelLevelStart1, quantity: stopFuelQtyStart1, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText1 = tankReading(fraction: stopFuelLevelEnd1, quantity: stopFuelQtyEnd1, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText1) to \(fuelEndText1)")}
								if stopDefLevelStart1 > 0 || stopDefQtyStart1 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart1, quantity: stopDefQtyStart1, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice1 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice1, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded1 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice1 * defAdded1, unit: "")}
									}
								}
								if stopDefLevel1 > 0 || stopDefQty1 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel1, quantity: stopDefQty1, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop1Image1 != nil || fuelStop1Image2 != nil || fuelStop1Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop1Image1)
									FuelStop_ImageThumb(imageData: fuelStop1Image2)
									FuelStop_ImageThumb(imageData: fuelStop1Image3)
								}
							}
							if fuelExitTime1 > fuelDateTime1 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime1))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(1) }
						}
						if dataSet.fuelAdded2 > 0 || !stopReason2.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation2)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime2))")}
							if !stopReason2.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason2)} }
							if !stopComment2.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment2)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded2, fractionalLength: 1)}
							if !fuelAdded2Log.isEmpty {
								if !stopFuelType2.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType2)} }
								let fuelStartText2 = tankReading(fraction: stopFuelLevelStart2, quantity: stopFuelQtyStart2, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText2 = tankReading(fraction: stopFuelLevelEnd2, quantity: stopFuelQtyEnd2, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText2) to \(fuelEndText2)")}
								if stopDefLevelStart2 > 0 || stopDefQtyStart2 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart2, quantity: stopDefQtyStart2, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice2 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice2, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded2 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice2 * defAdded2, unit: "")}
									}
								}
								if stopDefLevel2 > 0 || stopDefQty2 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel2, quantity: stopDefQty2, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop2Image1 != nil || fuelStop2Image2 != nil || fuelStop2Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop2Image1)
									FuelStop_ImageThumb(imageData: fuelStop2Image2)
									FuelStop_ImageThumb(imageData: fuelStop2Image3)
								}
							}
							if fuelExitTime2 > fuelDateTime2 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime2))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(2) }
						}
						if dataSet.fuelAdded3 > 0 || !stopReason3.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation3)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime3))")}
							if !stopReason3.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason3)} }
							if !stopComment3.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment3)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded3, fractionalLength: 1)}
							if !fuelAdded3Log.isEmpty {
								if !stopFuelType3.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType3)} }
								let fuelStartText3 = tankReading(fraction: stopFuelLevelStart3, quantity: stopFuelQtyStart3, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText3 = tankReading(fraction: stopFuelLevelEnd3, quantity: stopFuelQtyEnd3, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText3) to \(fuelEndText3)")}
								if stopDefLevelStart3 > 0 || stopDefQtyStart3 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart3, quantity: stopDefQtyStart3, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice3 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice3, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded3 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice3 * defAdded3, unit: "")}
									}
								}
								if stopDefLevel3 > 0 || stopDefQty3 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel3, quantity: stopDefQty3, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop3Image1 != nil || fuelStop3Image2 != nil || fuelStop3Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop3Image1)
									FuelStop_ImageThumb(imageData: fuelStop3Image2)
									FuelStop_ImageThumb(imageData: fuelStop3Image3)
								}
							}
							if fuelExitTime3 > fuelDateTime3 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime3))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(3) }
						}
						if dataSet.fuelAdded4 > 0 || !stopReason4.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation4)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime4))")}
							if !stopReason4.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason4)} }
							if !stopComment4.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment4)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded4, fractionalLength: 1)}
							if !fuelAdded4Log.isEmpty {
								if !stopFuelType4.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType4)} }
								let fuelStartText4 = tankReading(fraction: stopFuelLevelStart4, quantity: stopFuelQtyStart4, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText4 = tankReading(fraction: stopFuelLevelEnd4, quantity: stopFuelQtyEnd4, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText4) to \(fuelEndText4)")}
								if stopDefLevelStart4 > 0 || stopDefQtyStart4 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart4, quantity: stopDefQtyStart4, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice4 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice4, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded4 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice4 * defAdded4, unit: "")}
									}
								}
								if stopDefLevel4 > 0 || stopDefQty4 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel4, quantity: stopDefQty4, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop4Image1 != nil || fuelStop4Image2 != nil || fuelStop4Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop4Image1)
									FuelStop_ImageThumb(imageData: fuelStop4Image2)
									FuelStop_ImageThumb(imageData: fuelStop4Image3)
								}
							}
							if fuelExitTime4 > fuelDateTime4 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime4))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(4) }
						}
						if dataSet.fuelAdded5 > 0 || !stopReason5.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation5)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime5))")}
							if !stopReason5.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason5)} }
							if !stopComment5.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment5)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded5, fractionalLength: 1)}
							if !fuelAdded5Log.isEmpty {
								if !stopFuelType5.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType5)} }
								let fuelStartText5 = tankReading(fraction: stopFuelLevelStart5, quantity: stopFuelQtyStart5, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText5 = tankReading(fraction: stopFuelLevelEnd5, quantity: stopFuelQtyEnd5, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText5) to \(fuelEndText5)")}
								if stopDefLevelStart5 > 0 || stopDefQtyStart5 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart5, quantity: stopDefQtyStart5, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice5 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice5, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded5 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice5 * defAdded5, unit: "")}
									}
								}
								if stopDefLevel5 > 0 || stopDefQty5 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel5, quantity: stopDefQty5, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop5Image1 != nil || fuelStop5Image2 != nil || fuelStop5Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop5Image1)
									FuelStop_ImageThumb(imageData: fuelStop5Image2)
									FuelStop_ImageThumb(imageData: fuelStop5Image3)
								}
							}
							if fuelExitTime5 > fuelDateTime5 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime5))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(5) }
						}
						if dataSet.fuelAdded6 > 0 || !stopReason6.isEmpty {
						VStack(alignment: .leading, spacing: 4) {
							HStack{LabelDataText(label: "\(fuelLocation6)", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelDateTime6))")}
							if !stopReason6.isEmpty { HStack{LabelDataText(label: "  Reason", data: stopReason6)} }
							if !stopComment6.isEmpty { HStack{LabelDataText(label: "  Notes", data: stopComment6)} }
							HStack{LabelDataNumber(label: "Fuel (\(unit(UnitIndex.fuel)))", data: dataSet.fuelAdded6, fractionalLength: 1)}
							if !fuelAdded6Log.isEmpty {
								if !stopFuelType6.isEmpty { HStack{LabelDataText(label: "  Fuel Type", data: stopFuelType6)} }
								let fuelStartText6 = tankReading(fraction: stopFuelLevelStart6, quantity: stopFuelQtyStart6, unitLabel: unit(UnitIndex.fuel))
								let fuelEndText6 = tankReading(fraction: stopFuelLevelEnd6, quantity: stopFuelQtyEnd6, unitLabel: unit(UnitIndex.fuel))
								HStack{LabelDataText(label: "  Fuel Level", data: "\(fuelStartText6) to \(fuelEndText6)")}
								if stopDefLevelStart6 > 0 || stopDefQtyStart6 > 0 {
									HStack{LabelDataText(label: "  DEF Level Start", data: tankReading(fraction: stopDefLevelStart6, quantity: stopDefQtyStart6, unitLabel: unit(UnitIndex.def)))}
								}
								if stopDefPrice6 > 0 {
									HStack{LabelDataCurrency(label: "  DEF Price", data: stopDefPrice6, unit: "/ \(unit(UnitIndex.def))")}
									if defAdded6 > 0 {
										HStack{LabelDataCurrency(label: "  DEF Cost", data: stopDefPrice6 * defAdded6, unit: "")}
									}
								}
								if stopDefLevel6 > 0 || stopDefQty6 > 0 {
									HStack{LabelDataText(label: "  DEF Level End", data: tankReading(fraction: stopDefLevel6, quantity: stopDefQty6, unitLabel: unit(UnitIndex.def)))}
								}
							}
							if fuelStop6Image1 != nil || fuelStop6Image2 != nil || fuelStop6Image3 != nil {
								HStack(spacing: 8) {
									FuelStop_ImageThumb(imageData: fuelStop6Image1)
									FuelStop_ImageThumb(imageData: fuelStop6Image2)
									FuelStop_ImageThumb(imageData: fuelStop6Image3)
								}
							}
							if fuelExitTime6 > fuelDateTime6 {
								HStack{LabelDataText(label: "  Departed", data: "\(functions.formatDate_DDMMMyy_HHmm(date: fuelExitTime6))")}
							}
						}
						.cardStyle(backgroundColor: .blue.opacity(0.5))
						// .ultraThinMaterial reads as barely-there against a dark background —
						// add a visible tinted border in dark mode only so the card still reads
						// as its own surface; light mode already has enough contrast.
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(colorScheme == .dark ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 1.5)
						)
						.overlay(alignment: .topLeading) { stopNumberBadge(6) }
						}
						let tripTotalSecs = dataSet.tripDateTimeEnd.timeIntervalSince(dataSet.tripDateTimeStart)
						let stopTotalSecs: TimeInterval = {
							var t: TimeInterval = 0
							if (dataSet.fuelAdded1 > 0 || !dataSet.stopReason1.isEmpty) && fuelExitTime1 > fuelDateTime1 { t += fuelExitTime1.timeIntervalSince(fuelDateTime1) }
							if (dataSet.fuelAdded2 > 0 || !dataSet.stopReason2.isEmpty) && fuelExitTime2 > fuelDateTime2 { t += fuelExitTime2.timeIntervalSince(fuelDateTime2) }
							if (dataSet.fuelAdded3 > 0 || !dataSet.stopReason3.isEmpty) && fuelExitTime3 > fuelDateTime3 { t += fuelExitTime3.timeIntervalSince(fuelDateTime3) }
							if (dataSet.fuelAdded4 > 0 || !dataSet.stopReason4.isEmpty) && fuelExitTime4 > fuelDateTime4 { t += fuelExitTime4.timeIntervalSince(fuelDateTime4) }
							if (dataSet.fuelAdded5 > 0 || !dataSet.stopReason5.isEmpty) && fuelExitTime5 > fuelDateTime5 { t += fuelExitTime5.timeIntervalSince(fuelDateTime5) }
							if (dataSet.fuelAdded6 > 0 || !dataSet.stopReason6.isEmpty) && fuelExitTime6 > fuelDateTime6 { t += fuelExitTime6.timeIntervalSince(fuelDateTime6) }
							return t
						}()
						if stopTotalSecs > 0 {
							let movingSecs = max(0, tripTotalSecs - stopTotalSecs)
							let sH = Int(stopTotalSecs) / 3600; let sM = (Int(stopTotalSecs) % 3600) / 60
							let mH = Int(movingSecs) / 3600; let mM = (Int(movingSecs) % 3600) / 60
							Divider()
							HStack{LabelDataText(label: "Stop Time", data: "\(sH)h \(String(format: "%02d", sM))m")}
							HStack{LabelDataText(label: "Time Moving", data: "\(mH)h \(String(format: "%02d", mM))m")}
						}
					}
					}
				}
				
				CardView {
					VStack {
						SectionText(label: "TRAVEL END")
						HStack{LabelDataText(label: "Arrival", data: "\(functions.formatDate_DDMMMyy_HHmm(date:dataSet.tripDateTimeEnd))")}
						HStack{LabelDataText(label: Vertical.current.primaryMeterLabel, data: "\(dataSet.odometerEnd) \(unit(UnitIndex.distance))")}
						if dataSet.engHoursEnd > 0 {
							HStack{LabelDataNumber(label: "Engine Hours:", data: dataSet.engHoursEnd, fractionalLength: 1)}
						}
						if dataSet.fuelLevelEnd != "" {
							HStack{LabelDataText(label: "Fuel Level", data: "\(dataSet.fuelLevelEnd) \(dataSet.fuelQuantityEnd)\(unit(UnitIndex.fuel))")}
						}
						if dataSet.defLevelEndFraction != "" {
							let defQtyEnd = dataSet.defQuantityEnd > 0
							? dataSet.defQuantityEnd
							: dataSet.defLevelEnd1 * Float(vehicleDetails?.defCapacity ?? 0)
							let defQtyEndText = defQtyEnd > 0 ? " \(defQtyEnd.formatted(.number.precision(.fractionLength(1))))\(unit(UnitIndex.def))" : ""
							HStack{LabelDataText(label: "DEF Level", data: "\(dataSet.defLevelEndFraction)\(defQtyEndText)")}
						}
						if dataSet.locationEnd != "" {
							HStack{LabelDataText(label: "Location", data: "\(dataSet.locationEnd)")}
						}
						let endChecks = checkedFluidList([
							("Engine Oil", dataSet.endOilChecked),
							("Engine Coolant", dataSet.endEngineCoolantChecked),
							("Secondary Coolant", dataSet.endSecondaryCoolantChecked),
							("Power Steering", dataSet.endPowerSteeringChecked),
							("Brake", dataSet.endBrakeFluidChecked),
							("Transmission", dataSet.endTransmissionFluidChecked),
							("Rear Axle", dataSet.endRearAxleChecked),
							("Front Axle", dataSet.endFrontAxleChecked),
							("Fuel/Water Separator", dataSet.endFuelWaterSeparatorChecked),
							("Air System Water Bleed", dataSet.endAirSystemWaterBleedChecked)
						])
						if !endChecks.isEmpty {
							HStack{LabelDataText(label: "Fluids Checked", data: endChecks)}
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
						HStack{ LabelDataText(label: "Total Elapsed", data: stats.totalElapsedString) }
						HStack{ LabelDataText(label: "Time Underway", data: stats.durationString) }
						HStack{ LabelDataNumber(label: "Underway (hrs)", data: Float(stats.durationHours), fractionalLength: 2) }
						if stats.engineTime > 0 {
							HStack{ LabelDataNumber(label: "Engine Time (hrs)", data: stats.engineTime, fractionalLength: 2) }
						}
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
						SectionText(label: "\(Vertical.current.assetSingular.uppercased()) TOTALS")
						Text("Totals are calculated from all travel logs that have been created for this \(Vertical.current.assetSingular.lowercased()) up to and including the current travel log.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .center)
						let totals = computeVehicleTotals()
						HStack{ LabelDataText(label: "Trips Counted", data: "\(totals.tripCount)") }
						HStack{ LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(totals.totalDistance)") }
						HStack{ LabelDataNumber(label: "Total Elapsed (hrs)", data: Float(totals.totalElapsedHours), fractionalLength: 1) }
						HStack{ LabelDataNumber(label: "Underway (hours)", data: Float(totals.totalHours), fractionalLength: 1) }
						if totals.totalEngineTime > 0 {
							HStack{ LabelDataNumber(label: "Engine Time (hrs)", data: totals.totalEngineTime, fractionalLength: 1) }
						}
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
				
				if !tripGroup.isEmpty {
					CardView {
						VStack {
							SectionText(label: "GROUP TOTALS")
							Text("Totals for all travel logs in the \"\(tripGroup)\" group.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .center)
							if let groupTotals = computeGroupTotals() {
								HStack{ LabelDataText(label: "Trips in Group", data: "\(groupTotals.tripCount)") }
								HStack{ LabelDataText(label: "Distance (\(unit(UnitIndex.distance)))", data: "\(groupTotals.totalDistance)") }
								HStack{ LabelDataNumber(label: "Total Elapsed (hrs)", data: Float(groupTotals.totalElapsedHours), fractionalLength: 1) }
								HStack{ LabelDataNumber(label: "Fuel Used (\(unit(UnitIndex.fuel)))", data: groupTotals.totalFuelBurned, fractionalLength: 1) }
								if groupTotals.avgEconomy > 0 {
									HStack{ LabelDataText(label: "Average (\(unit(UnitIndex.distance))/\(unit(UnitIndex.fuel)))", data: "\(groupTotals.avgEconomy.formatted(.number.precision(.fractionLength(1))))") }
								}
								if groupTotals.totalFuelCost > 0 {
									HStack{ LabelDataCurrency(label: "Fuel Cost", data: groupTotals.totalFuelCost, unit: "") }
								}
								if groupTotals.totalOilAdded > 0 {
									HStack{ LabelDataNumber(label: "Oil Added (\(unit(UnitIndex.oil)))", data: groupTotals.totalOilAdded, fractionalLength: 1) }
								}
								if groupTotals.totalDEFAdded > 0 {
									HStack{ LabelDataNumber(label: "DEF Added (\(unit(UnitIndex.def)))", data: groupTotals.totalDEFAdded, fractionalLength: 1) }
								}
							}
						}
					}
				}
				// Hidden when no images are attached
				if hasGraphics {
					CardView {
					VStack {
						SectionText(label: "TRAVEL GRAPHICS")
						Image_View_Details(label:"1", imageData: dataSet.image1, imageDescription: dataSet.image1Description)
						Image_View_Details(label:"2", imageData: dataSet.image2, imageDescription: dataSet.image2Description)
						Image_View_Details(label:"3", imageData: dataSet.image3, imageDescription: dataSet.image3Description)
					}
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
		// The quantity fields are authoritative — a digital readout can be typed straight in.
		// Bring the eighths dropdown and its fraction label back into line with whatever the
		// quantities ended up as, so the record reopens self-consistent.
		var levelStartFraction = fuelLevelStart1
		var levelEndFraction = fuelLevelEnd1
		var levelStartText = fuelLevelStart
		var levelEndText = fuelLevelEnd
		let tankCapacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		if tankCapacity > 0 {
			levelStartFraction = nearestFuelEighth(fuelQuantityStart / tankCapacity)
			levelEndFraction = nearestFuelEighth(fuelQuantityEnd / tankCapacity)
			levelStartText = functions.getFuelLevel(unit: levelStartFraction)
			levelEndText = functions.getFuelLevel(unit: levelEndFraction)
		}
		var defStartFraction = defLevel1
		var defEndFraction = defLevelEnd1
		var defStartText = defLevelFraction
		var defEndText = defLevelEndFraction
		let defTankCapacity = Float(vehicleDetails?.defCapacity ?? 0)
		if defTankCapacity > 0 {
			defStartFraction = nearestFuelEighth(defQuantityStart / defTankCapacity)
			defEndFraction = nearestFuelEighth(defQuantityEnd / defTankCapacity)
			defStartText = functions.getFuelLevel(unit: defStartFraction)
			defEndText = functions.getFuelLevel(unit: defEndFraction)
		}
		// Each stop's quantities are authoritative too. Snap its dropdowns to match, and hand
		// both the quantity and the reconciled fraction down to the linked fuel log.
		let stopFuelCapacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		let stopDefCapacity = Float(vehicleDetails?.defCapacity ?? 0)
		let stopLevelStart1 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart1 / stopFuelCapacity) : stopFuelLevelStart1
		let stopLevelEnd1 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd1 / stopFuelCapacity) : stopFuelLevelEnd1
		let stopDefLevelFinal1 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty1 / stopDefCapacity) : stopDefLevel1
		let stopDefLevelStartFinal1 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart1 / stopDefCapacity) : stopDefLevelStart1
		let stopLevelStart2 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart2 / stopFuelCapacity) : stopFuelLevelStart2
		let stopLevelEnd2 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd2 / stopFuelCapacity) : stopFuelLevelEnd2
		let stopDefLevelFinal2 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty2 / stopDefCapacity) : stopDefLevel2
		let stopDefLevelStartFinal2 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart2 / stopDefCapacity) : stopDefLevelStart2
		let stopLevelStart3 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart3 / stopFuelCapacity) : stopFuelLevelStart3
		let stopLevelEnd3 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd3 / stopFuelCapacity) : stopFuelLevelEnd3
		let stopDefLevelFinal3 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty3 / stopDefCapacity) : stopDefLevel3
		let stopDefLevelStartFinal3 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart3 / stopDefCapacity) : stopDefLevelStart3
		let stopLevelStart4 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart4 / stopFuelCapacity) : stopFuelLevelStart4
		let stopLevelEnd4 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd4 / stopFuelCapacity) : stopFuelLevelEnd4
		let stopDefLevelFinal4 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty4 / stopDefCapacity) : stopDefLevel4
		let stopDefLevelStartFinal4 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart4 / stopDefCapacity) : stopDefLevelStart4
		let stopLevelStart5 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart5 / stopFuelCapacity) : stopFuelLevelStart5
		let stopLevelEnd5 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd5 / stopFuelCapacity) : stopFuelLevelEnd5
		let stopDefLevelFinal5 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty5 / stopDefCapacity) : stopDefLevel5
		let stopDefLevelStartFinal5 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart5 / stopDefCapacity) : stopDefLevelStart5
		let stopLevelStart6 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyStart6 / stopFuelCapacity) : stopFuelLevelStart6
		let stopLevelEnd6 = stopFuelCapacity > 0 ? nearestFuelEighth(stopFuelQtyEnd6 / stopFuelCapacity) : stopFuelLevelEnd6
		let stopDefLevelFinal6 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQty6 / stopDefCapacity) : stopDefLevel6
		let stopDefLevelStartFinal6 = stopDefCapacity > 0 ? nearestFuelEighth(stopDefQtyStart6 / stopDefCapacity) : stopDefLevelStart6
		// A stop's exit time can never precede its entry time.
		let stopExit1 = max(fuelExitTime1, fuelDateTime1)
		let stopExit2 = max(fuelExitTime2, fuelDateTime2)
		let stopExit3 = max(fuelExitTime3, fuelDateTime3)
		let stopExit4 = max(fuelExitTime4, fuelDateTime4)
		let stopExit5 = max(fuelExitTime5, fuelDateTime5)
		let stopExit6 = max(fuelExitTime6, fuelDateTime6)
		// save fuel log(s) first to return the fuel log id(s) for saving
		if createFuelLog1 {
			fuelAdded1Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer1), saveEngineHours: fuelEngHours1, saveQuantity: fuelAdded1, savePrice: fuelPrice1, saveLocation: fuelLocation1, saveLogId: fuelAdded1Log, saveOil: oilAdded1, saveDEF: defAdded1, saveNotes: fuelNotes1, saveOilChecked: oilChecked1, saveEngineCoolantChecked: engineCoolantChecked1, saveSecondaryCoolantChecked: secondaryCoolantChecked1, savePowerSteeringChecked: powerSteeringChecked1, saveBrakeFluidChecked: brakeFluidChecked1, saveTransmissionFluidChecked: transmissionFluidChecked1, saveRearAxleChecked: rearAxleChecked1, saveFrontAxleChecked: frontAxleChecked1, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked1, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked1, saveDateTime: fuelDateTime1, saveImage1: fuelStop1Image1, saveImage2: fuelStop1Image2, saveImage3: fuelStop1Image3, saveFuelLevelStart: stopLevelStart1, saveFuelLevelEnd: stopLevelEnd1, saveDefLevel: stopDefLevelFinal1, saveFuelType: stopFuelType1, saveMatchByOdometer: !stopsForcedNew.contains(1), saveExitTime: stopExit1, saveFuelQuantityStart: stopFuelQtyStart1, saveFuelQuantityEnd: stopFuelQtyEnd1, saveDefQuantity: stopDefQty1, saveDefLevelStart: stopDefLevelStartFinal1, saveDefQuantityStart: stopDefQtyStart1, saveDefPrice: stopDefPrice1)
		}
		if createFuelLog2 {
			fuelAdded2Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer2), saveEngineHours: fuelEngHours2, saveQuantity: fuelAdded2, savePrice: fuelPrice2, saveLocation: fuelLocation2, saveLogId: fuelAdded2Log, saveOil: oilAdded2, saveDEF: defAdded2, saveNotes: fuelNotes2, saveOilChecked: oilChecked2, saveEngineCoolantChecked: engineCoolantChecked2, saveSecondaryCoolantChecked: secondaryCoolantChecked2, savePowerSteeringChecked: powerSteeringChecked2, saveBrakeFluidChecked: brakeFluidChecked2, saveTransmissionFluidChecked: transmissionFluidChecked2, saveRearAxleChecked: rearAxleChecked2, saveFrontAxleChecked: frontAxleChecked2, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked2, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked2, saveDateTime: fuelDateTime2, saveImage1: fuelStop2Image1, saveImage2: fuelStop2Image2, saveImage3: fuelStop2Image3, saveFuelLevelStart: stopLevelStart2, saveFuelLevelEnd: stopLevelEnd2, saveDefLevel: stopDefLevelFinal2, saveFuelType: stopFuelType2, saveMatchByOdometer: !stopsForcedNew.contains(2), saveExitTime: stopExit2, saveFuelQuantityStart: stopFuelQtyStart2, saveFuelQuantityEnd: stopFuelQtyEnd2, saveDefQuantity: stopDefQty2, saveDefLevelStart: stopDefLevelStartFinal2, saveDefQuantityStart: stopDefQtyStart2, saveDefPrice: stopDefPrice2)
		}
		if createFuelLog3 {
			fuelAdded3Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer3), saveEngineHours: fuelEngHours3, saveQuantity: fuelAdded3, savePrice: fuelPrice3, saveLocation: fuelLocation3, saveLogId: fuelAdded3Log, saveOil: oilAdded3, saveDEF: defAdded3, saveNotes: fuelNotes3, saveOilChecked: oilChecked3, saveEngineCoolantChecked: engineCoolantChecked3, saveSecondaryCoolantChecked: secondaryCoolantChecked3, savePowerSteeringChecked: powerSteeringChecked3, saveBrakeFluidChecked: brakeFluidChecked3, saveTransmissionFluidChecked: transmissionFluidChecked3, saveRearAxleChecked: rearAxleChecked3, saveFrontAxleChecked: frontAxleChecked3, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked3, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked3, saveDateTime: fuelDateTime3, saveImage1: fuelStop3Image1, saveImage2: fuelStop3Image2, saveImage3: fuelStop3Image3, saveFuelLevelStart: stopLevelStart3, saveFuelLevelEnd: stopLevelEnd3, saveDefLevel: stopDefLevelFinal3, saveFuelType: stopFuelType3, saveMatchByOdometer: !stopsForcedNew.contains(3), saveExitTime: stopExit3, saveFuelQuantityStart: stopFuelQtyStart3, saveFuelQuantityEnd: stopFuelQtyEnd3, saveDefQuantity: stopDefQty3, saveDefLevelStart: stopDefLevelStartFinal3, saveDefQuantityStart: stopDefQtyStart3, saveDefPrice: stopDefPrice3)
		}
		if createFuelLog4 {
			fuelAdded4Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer4), saveEngineHours: fuelEngHours4, saveQuantity: fuelAdded4, savePrice: fuelPrice4, saveLocation: fuelLocation4, saveLogId: fuelAdded4Log, saveOil: oilAdded4, saveDEF: defAdded4, saveNotes: fuelNotes4, saveOilChecked: oilChecked4, saveEngineCoolantChecked: engineCoolantChecked4, saveSecondaryCoolantChecked: secondaryCoolantChecked4, savePowerSteeringChecked: powerSteeringChecked4, saveBrakeFluidChecked: brakeFluidChecked4, saveTransmissionFluidChecked: transmissionFluidChecked4, saveRearAxleChecked: rearAxleChecked4, saveFrontAxleChecked: frontAxleChecked4, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked4, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked4, saveDateTime: fuelDateTime4, saveImage1: fuelStop4Image1, saveImage2: fuelStop4Image2, saveImage3: fuelStop4Image3, saveFuelLevelStart: stopLevelStart4, saveFuelLevelEnd: stopLevelEnd4, saveDefLevel: stopDefLevelFinal4, saveFuelType: stopFuelType4, saveMatchByOdometer: !stopsForcedNew.contains(4), saveExitTime: stopExit4, saveFuelQuantityStart: stopFuelQtyStart4, saveFuelQuantityEnd: stopFuelQtyEnd4, saveDefQuantity: stopDefQty4, saveDefLevelStart: stopDefLevelStartFinal4, saveDefQuantityStart: stopDefQtyStart4, saveDefPrice: stopDefPrice4)
		}
		if createFuelLog5 {
			fuelAdded5Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer5), saveEngineHours: fuelEngHours5, saveQuantity: fuelAdded5, savePrice: fuelPrice5, saveLocation: fuelLocation5, saveLogId: fuelAdded5Log, saveOil: oilAdded5, saveDEF: defAdded5, saveNotes: fuelNotes5, saveOilChecked: oilChecked5, saveEngineCoolantChecked: engineCoolantChecked5, saveSecondaryCoolantChecked: secondaryCoolantChecked5, savePowerSteeringChecked: powerSteeringChecked5, saveBrakeFluidChecked: brakeFluidChecked5, saveTransmissionFluidChecked: transmissionFluidChecked5, saveRearAxleChecked: rearAxleChecked5, saveFrontAxleChecked: frontAxleChecked5, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked5, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked5, saveDateTime: fuelDateTime5, saveImage1: fuelStop5Image1, saveImage2: fuelStop5Image2, saveImage3: fuelStop5Image3, saveFuelLevelStart: stopLevelStart5, saveFuelLevelEnd: stopLevelEnd5, saveDefLevel: stopDefLevelFinal5, saveFuelType: stopFuelType5, saveMatchByOdometer: !stopsForcedNew.contains(5), saveExitTime: stopExit5, saveFuelQuantityStart: stopFuelQtyStart5, saveFuelQuantityEnd: stopFuelQtyEnd5, saveDefQuantity: stopDefQty5, saveDefLevelStart: stopDefLevelStartFinal5, saveDefQuantityStart: stopDefQtyStart5, saveDefPrice: stopDefPrice5)
		}
		if createFuelLog6 {
			fuelAdded6Log = add_editFuelRecord(saveOdometer: Int(fuelOdometer6), saveEngineHours: fuelEngHours6, saveQuantity: fuelAdded6, savePrice: fuelPrice6, saveLocation: fuelLocation6, saveLogId: fuelAdded6Log, saveOil: oilAdded6, saveDEF: defAdded6, saveNotes: fuelNotes6, saveOilChecked: oilChecked6, saveEngineCoolantChecked: engineCoolantChecked6, saveSecondaryCoolantChecked: secondaryCoolantChecked6, savePowerSteeringChecked: powerSteeringChecked6, saveBrakeFluidChecked: brakeFluidChecked6, saveTransmissionFluidChecked: transmissionFluidChecked6, saveRearAxleChecked: rearAxleChecked6, saveFrontAxleChecked: frontAxleChecked6, saveFuelWaterSeparatorChecked: fuelWaterSeparatorChecked6, saveAirSystemWaterBleedChecked: airSystemWaterBleedChecked6, saveDateTime: fuelDateTime6, saveImage1: fuelStop6Image1, saveImage2: fuelStop6Image2, saveImage3: fuelStop6Image3, saveFuelLevelStart: stopLevelStart6, saveFuelLevelEnd: stopLevelEnd6, saveDefLevel: stopDefLevelFinal6, saveFuelType: stopFuelType6, saveMatchByOdometer: !stopsForcedNew.contains(6), saveExitTime: stopExit6, saveFuelQuantityStart: stopFuelQtyStart6, saveFuelQuantityEnd: stopFuelQtyEnd6, saveDefQuantity: stopDefQty6, saveDefLevelStart: stopDefLevelStartFinal6, saveDefQuantityStart: stopDefQtyStart6, saveDefPrice: stopDefPrice6)
		}

		dataSet.inactive = inactive
		dataSet.vehicleId = vehicleId
		dataSet.logName = logName
		dataSet.tripGroup = tripGroup
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
		dataSet.fuelLevelStart1 = levelStartFraction
		dataSet.fuelLevelEnd1 = levelEndFraction
		dataSet.fuelLevelStart = levelStartText
		dataSet.fuelLevelEnd = levelEndText
		dataSet.defLevel1 = defStartFraction
		dataSet.defLevelFraction = defStartText
		dataSet.defLevelEnd1 = defEndFraction
		dataSet.defLevelEndFraction = defEndText
		dataSet.defQuantityStart = defQuantityStart
		dataSet.defQuantityEnd = defQuantityEnd
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
		dataSet.fuelDateTime1 = fuelDateTime1
		dataSet.fuelDateTime2 = fuelDateTime2
		dataSet.fuelDateTime3 = fuelDateTime3
		dataSet.fuelDateTime4 = fuelDateTime4
		dataSet.fuelDateTime5 = fuelDateTime5
		dataSet.fuelDateTime6 = fuelDateTime6
		dataSet.fuelExitTime1 = stopExit1
		dataSet.fuelExitTime2 = stopExit2
		dataSet.fuelExitTime3 = stopExit3
		dataSet.fuelExitTime4 = stopExit4
		dataSet.fuelExitTime5 = stopExit5
		dataSet.fuelExitTime6 = stopExit6
		dataSet.stopReason1 = stopReason1
		dataSet.stopReason2 = stopReason2
		dataSet.stopReason3 = stopReason3
		dataSet.stopReason4 = stopReason4
		dataSet.stopReason5 = stopReason5
		dataSet.stopReason6 = stopReason6
		dataSet.stopComment1 = stopComment1
		dataSet.stopComment2 = stopComment2
		dataSet.stopComment3 = stopComment3
		dataSet.stopComment4 = stopComment4
		dataSet.stopComment5 = stopComment5
		dataSet.stopComment6 = stopComment6
		dataSet.fuelLocation1 = fuelLocation1
		dataSet.fuelLocation2 = fuelLocation2
		dataSet.fuelLocation3 = fuelLocation3
		dataSet.fuelLocation4 = fuelLocation4
		dataSet.fuelLocation5 = fuelLocation5
		dataSet.fuelLocation6 = fuelLocation6
		dataSet.fuelStop1Image1 = fuelStop1Image1
		dataSet.fuelStop1Image2 = fuelStop1Image2
		dataSet.fuelStop1Image3 = fuelStop1Image3
		dataSet.fuelStop2Image1 = fuelStop2Image1
		dataSet.fuelStop2Image2 = fuelStop2Image2
		dataSet.fuelStop2Image3 = fuelStop2Image3
		dataSet.fuelStop3Image1 = fuelStop3Image1
		dataSet.fuelStop3Image2 = fuelStop3Image2
		dataSet.fuelStop3Image3 = fuelStop3Image3
		dataSet.fuelStop4Image1 = fuelStop4Image1
		dataSet.fuelStop4Image2 = fuelStop4Image2
		dataSet.fuelStop4Image3 = fuelStop4Image3
		dataSet.fuelStop5Image1 = fuelStop5Image1
		dataSet.fuelStop5Image2 = fuelStop5Image2
		dataSet.fuelStop5Image3 = fuelStop5Image3
		dataSet.fuelStop6Image1 = fuelStop6Image1
		dataSet.fuelStop6Image2 = fuelStop6Image2
		dataSet.fuelStop6Image3 = fuelStop6Image3
		dataSet.locationStart = locationStart
		dataSet.locationEnd = locationEnd
		dataSet.startOilChecked = startOilChecked
		dataSet.startEngineCoolantChecked = startEngineCoolantChecked
		dataSet.startSecondaryCoolantChecked = startSecondaryCoolantChecked
		dataSet.startPowerSteeringChecked = startPowerSteeringChecked
		dataSet.startBrakeFluidChecked = startBrakeFluidChecked
		dataSet.startTransmissionFluidChecked = startTransmissionFluidChecked
		dataSet.startRearAxleChecked = startRearAxleChecked
		dataSet.startFrontAxleChecked = startFrontAxleChecked
		dataSet.startFuelWaterSeparatorChecked = startFuelWaterSeparatorChecked
		dataSet.startAirSystemWaterBleedChecked = startAirSystemWaterBleedChecked
		dataSet.endOilChecked = endOilChecked
		dataSet.endEngineCoolantChecked = endEngineCoolantChecked
		dataSet.endSecondaryCoolantChecked = endSecondaryCoolantChecked
		dataSet.endPowerSteeringChecked = endPowerSteeringChecked
		dataSet.endBrakeFluidChecked = endBrakeFluidChecked
		dataSet.endTransmissionFluidChecked = endTransmissionFluidChecked
		dataSet.endRearAxleChecked = endRearAxleChecked
		dataSet.endFrontAxleChecked = endFrontAxleChecked
		dataSet.endFuelWaterSeparatorChecked = endFuelWaterSeparatorChecked
		dataSet.endAirSystemWaterBleedChecked = endAirSystemWaterBleedChecked
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
		
		fuelLevelStart1 = levelStartFraction
		fuelLevelEnd1 = levelEndFraction
		fuelLevelStart = levelStartText
		fuelLevelEnd = levelEndText
		defLevel1 = defStartFraction
		defLevelEnd1 = defEndFraction
		defLevelFraction = defStartText
		defLevelEndFraction = defEndText
		stopFuelLevelStart1 = stopLevelStart1
		stopFuelLevelStart2 = stopLevelStart2
		stopFuelLevelStart3 = stopLevelStart3
		stopFuelLevelStart4 = stopLevelStart4
		stopFuelLevelStart5 = stopLevelStart5
		stopFuelLevelStart6 = stopLevelStart6
		stopFuelLevelEnd1 = stopLevelEnd1
		stopFuelLevelEnd2 = stopLevelEnd2
		stopFuelLevelEnd3 = stopLevelEnd3
		stopFuelLevelEnd4 = stopLevelEnd4
		stopFuelLevelEnd5 = stopLevelEnd5
		stopFuelLevelEnd6 = stopLevelEnd6
		stopDefLevel1 = stopDefLevelFinal1
		stopDefLevel2 = stopDefLevelFinal2
		stopDefLevel3 = stopDefLevelFinal3
		stopDefLevel4 = stopDefLevelFinal4
		stopDefLevel5 = stopDefLevelFinal5
		stopDefLevel6 = stopDefLevelFinal6
		stopDefLevelStart1 = stopDefLevelStartFinal1
		stopDefLevelStart2 = stopDefLevelStartFinal2
		stopDefLevelStart3 = stopDefLevelStartFinal3
		stopDefLevelStart4 = stopDefLevelStartFinal4
		stopDefLevelStart5 = stopDefLevelStartFinal5
		stopDefLevelStart6 = stopDefLevelStartFinal6

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
	/// 2. By `(odometer, vehicleId)` pair, assigning a new `logId` if found. Skipped when
	///    `matchByOdometer` is `false`, which the caller uses to force a brand new record.
	///
	/// - Returns: The resolved `logId` if a record is found, or an empty string if not.
	private func searchFuelRecord(saveOdometer: Int, saveLogId: String, matchByOdometer: Bool = true) -> String {
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
		// Try by odometer + vehicle, unless the caller unlinked this stop on purpose
		guard matchByOdometer else { return "" }
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
	private func add_editFuelRecord(saveOdometer: Int, saveEngineHours: Float, saveQuantity: Float, savePrice: Float, saveLocation: String, saveLogId: String, saveOil: Float, saveDEF: Float, saveNotes: String, saveOilChecked: Bool, saveEngineCoolantChecked: Bool = false, saveSecondaryCoolantChecked: Bool = false, savePowerSteeringChecked: Bool = false, saveBrakeFluidChecked: Bool = false, saveTransmissionFluidChecked: Bool = false, saveRearAxleChecked: Bool = false, saveFrontAxleChecked: Bool = false, saveFuelWaterSeparatorChecked: Bool = false, saveAirSystemWaterBleedChecked: Bool = false, saveDateTime: Date = Date(), saveImage1: Data? = nil, saveImage2: Data? = nil, saveImage3: Data? = nil, saveFuelLevelStart: Float = 0.25, saveFuelLevelEnd: Float = 1.0, saveDefLevel: Float = 0.0, saveFuelType: String = "", saveMatchByOdometer: Bool = true, saveExitTime: Date? = nil, saveFuelQuantityStart: Float = 0, saveFuelQuantityEnd: Float = 0, saveDefQuantity: Float = 0, saveDefLevelStart: Float = 0, saveDefQuantityStart: Float = 0, saveDefPrice: Float = 0) -> String {
		var logId: String = ""
		
		// get vehicle details (via Vehicle8)
		var fuelTypeVehicle: String = ""
		do {
			var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == vehicleId })
			fd.fetchLimit = 1
			if let v = try modelContext.fetch(fd).first {
				fuelTypeVehicle = v.fuelType
			}
		} catch {}
		
		// see if there is already a fuel log for this travel log
		logId = searchFuelRecord(saveOdometer: saveOdometer, saveLogId: saveLogId, matchByOdometer: saveMatchByOdometer)
		if !logId.isEmpty {
			// update existing record (by logId if possible, else fallback to odometer+vehicle)
			do {
				var fdById = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.logId == logId })
				fdById.fetchLimit = 1
				if let existing = try modelContext.fetch(fdById).first {
					existing.logId = logId
					existing.fuelAdded = saveQuantity
					existing.fuelPrice = savePrice
					existing.fuelCost = savePrice * saveQuantity
					existing.location = saveLocation
					existing.odometer = saveOdometer
					existing.engHours = saveEngineHours
					existing.oilAdded = saveOil
					existing.defAdded = saveDEF
					existing.fuelNotes = saveNotes
					existing.oilChecked = saveOilChecked
					existing.engineCoolantChecked = saveEngineCoolantChecked
					existing.secondaryCoolantChecked = saveSecondaryCoolantChecked
					existing.powerSteeringChecked = savePowerSteeringChecked
					existing.brakeFluidChecked = saveBrakeFluidChecked
					existing.transmissionFluidChecked = saveTransmissionFluidChecked
					existing.rearAxleChecked = saveRearAxleChecked
					existing.frontAxleChecked = saveFrontAxleChecked
					existing.fuelWaterSeparatorChecked = saveFuelWaterSeparatorChecked
					existing.airSystemWaterBleedChecked = saveAirSystemWaterBleedChecked
					existing.fuelLevelStart1 = saveFuelLevelStart
					existing.fuelLevelEnd1 = saveFuelLevelEnd
					existing.fuelLevelStartFraction = functions.getFuelLevel(unit: saveFuelLevelStart)
					existing.fuelLevelEndFraction = functions.getFuelLevel(unit: saveFuelLevelEnd)
					existing.fuelQuantityStart = saveFuelQuantityStart
					existing.fuelQuantityEnd = saveFuelQuantityEnd
					existing.defLevel1 = saveDefLevel
					existing.defQuantity = saveDefQuantity
					existing.defLevelStart1 = saveDefLevelStart
					existing.defLevelStartFraction = functions.getFuelLevel(unit: saveDefLevelStart)
					existing.defQuantityStart = saveDefQuantityStart
					existing.defPrice = saveDefPrice
					existing.defLevelFraction = functions.getFuelLevel(unit: saveDefLevel)
					existing.fuelType = saveFuelType.isEmpty ? fuelTypeVehicle : saveFuelType
					existing.fuelDateTime = saveDateTime
					existing.fuelExitTime = saveExitTime
					existing.image1 = saveImage1
					existing.image2 = saveImage2
					existing.image3 = saveImage3
					existing.updatedAt = Date()
					try? modelContext.save()
					return logId
				}
				// fallback fetch
				var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.odometer == saveOdometer && $0.vehicleId == vehicleId })
				fd.fetchLimit = 1
				if let existing = try modelContext.fetch(fd).first {
					existing.logId = logId
					existing.fuelAdded = saveQuantity
					existing.fuelPrice = savePrice
					existing.fuelCost = savePrice * saveQuantity
					existing.location = saveLocation
					existing.odometer = saveOdometer
					existing.engHours = saveEngineHours
					existing.oilAdded = saveOil
					existing.defAdded = saveDEF
					existing.fuelNotes = saveNotes
					existing.oilChecked = saveOilChecked
					existing.engineCoolantChecked = saveEngineCoolantChecked
					existing.secondaryCoolantChecked = saveSecondaryCoolantChecked
					existing.powerSteeringChecked = savePowerSteeringChecked
					existing.brakeFluidChecked = saveBrakeFluidChecked
					existing.transmissionFluidChecked = saveTransmissionFluidChecked
					existing.rearAxleChecked = saveRearAxleChecked
					existing.frontAxleChecked = saveFrontAxleChecked
					existing.fuelWaterSeparatorChecked = saveFuelWaterSeparatorChecked
					existing.airSystemWaterBleedChecked = saveAirSystemWaterBleedChecked
					existing.fuelLevelStart1 = saveFuelLevelStart
					existing.fuelLevelEnd1 = saveFuelLevelEnd
					existing.fuelLevelStartFraction = functions.getFuelLevel(unit: saveFuelLevelStart)
					existing.fuelLevelEndFraction = functions.getFuelLevel(unit: saveFuelLevelEnd)
					existing.fuelQuantityStart = saveFuelQuantityStart
					existing.fuelQuantityEnd = saveFuelQuantityEnd
					existing.defLevel1 = saveDefLevel
					existing.defQuantity = saveDefQuantity
					existing.defLevelStart1 = saveDefLevelStart
					existing.defLevelStartFraction = functions.getFuelLevel(unit: saveDefLevelStart)
					existing.defQuantityStart = saveDefQuantityStart
					existing.defPrice = saveDefPrice
					existing.defLevelFraction = functions.getFuelLevel(unit: saveDefLevel)
					existing.fuelType = saveFuelType.isEmpty ? fuelTypeVehicle : saveFuelType
					existing.fuelDateTime = saveDateTime
					existing.fuelExitTime = saveExitTime
					existing.image1 = saveImage1
					existing.image2 = saveImage2
					existing.image3 = saveImage3
					existing.updatedAt = Date()
					try? modelContext.save()
					return logId
				}
			} catch {}
		}
		
		// not found, create new fuel record
		logId = functions.formatDate_DDMMMyy_HHmmss(date: Date())
		let newFuelQuantityStart: Float = saveFuelQuantityStart
		let newFuelQuantityEnd: Float = saveFuelQuantityEnd
		let newDefQuantity: Float = saveDefQuantity
		let newDefStartText: String = functions.getFuelLevel(unit: saveDefLevelStart)
		let newDefFractionText: String = functions.getFuelLevel(unit: saveDefLevel)
		let newFuelStartText: String = functions.getFuelLevel(unit: saveFuelLevelStart)
		let newFuelEndText: String = functions.getFuelLevel(unit: saveFuelLevelEnd)
		let newFuelCost: Float = savePrice * saveQuantity
		let newFuelType: String = saveFuelType.isEmpty ? fuelTypeVehicle : saveFuelType
		let newFuelNotes: String = "Travel log: \(logName)"
		let newRecord = FuelLog1(
			logId: logId,
			vehicleId: vehicleId,
			logName: logName,
			fuelNotes: newFuelNotes,
			createdAt: Date(),
			updatedAt: Date(),
			fuelDateTime: saveDateTime,
			fuelExitTime: saveExitTime,
			odometer: saveOdometer,
			location: saveLocation,
			engHours: saveEngineHours,
			fuelQuantityStart: newFuelQuantityStart,
			fuelQuantityEnd: newFuelQuantityEnd,
			fuelAdded: saveQuantity,
			defAdded: saveDEF,
			defPrice: saveDefPrice,
			defLevelStart1: saveDefLevelStart,
			defLevelStartFraction: newDefStartText,
			defQuantityStart: saveDefQuantityStart,
			defLevel1: saveDefLevel,
			defLevelFraction: newDefFractionText,
			defQuantity: newDefQuantity,
			oilAdded: saveOil,
			oilChecked: saveOilChecked,
			engineCoolantChecked: saveEngineCoolantChecked,
			secondaryCoolantChecked: saveSecondaryCoolantChecked,
			powerSteeringChecked: savePowerSteeringChecked,
			brakeFluidChecked: saveBrakeFluidChecked,
			transmissionFluidChecked: saveTransmissionFluidChecked,
			rearAxleChecked: saveRearAxleChecked,
			frontAxleChecked: saveFrontAxleChecked,
			fuelWaterSeparatorChecked: saveFuelWaterSeparatorChecked,
			airSystemWaterBleedChecked: saveAirSystemWaterBleedChecked,
			fuelLevelStart1: saveFuelLevelStart,
			fuelLevelEnd1: saveFuelLevelEnd,
			fuelLevelStart: newFuelStartText,
			fuelLevelEnd: newFuelEndText,
			fuelPrice: savePrice,
			fuelCost: newFuelCost,
			fuelType: newFuelType,
			image1: saveImage1,
			image2: saveImage2,
			image3: saveImage3
		)
		modelContext.insert(newRecord)
		do { try modelContext.save() } catch {}
		return logId
	}
	
	/// Values loaded from a linked `FuelLog1` when populating an enroute stop.
	///
	/// Fuel levels, DEF level and fuel type live on the fuel log rather than on
	/// `TripLog2`, so they are read back through here whenever a stop is displayed.
	struct FuelStopData {
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
		var engineCoolantChecked: Bool = false
		var secondaryCoolantChecked: Bool = false
		var powerSteeringChecked: Bool = false
		var brakeFluidChecked: Bool = false
		var transmissionFluidChecked: Bool = false
		var rearAxleChecked: Bool = false
		var frontAxleChecked: Bool = false
		var fuelWaterSeparatorChecked: Bool = false
		var airSystemWaterBleedChecked: Bool = false
		var fuelDateTime: Date = Date()
		var fuelExitTime: Date? = nil
		var image1: Data? = nil
		var image2: Data? = nil
		var image3: Data? = nil
		var fuelLevelStart: Float = 0.25
		var fuelLevelEnd: Float = 1.0
		var defLevel: Float = 0
		var fuelQuantityStart: Float = 0
		var fuelQuantityEnd: Float = 0
		var defQuantity: Float = 0
		var defLevelStart: Float = 0
		var defQuantityStart: Float = 0
		var defPrice: Float = 0
		var fuelType: String = ""
	}
	
	/// Loads persisted fuel stop attributes for a linked `FuelLog1`.
	/// - Parameter saveLogId: The `logId` of the `FuelLog1` to fetch.
	/// - Returns: The stop's stored values, or defaults when no matching log exists.
	func getFuelLogData(saveLogId: String) -> FuelStopData {
		var data = FuelStopData()
		do {
			var fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { $0.logId == saveLogId })
			fd.fetchLimit = 1
			if let fetchModel = try modelContext.fetch(fd).first {
				data.fuelAdded = fetchModel.fuelAdded
				data.fuelPrice = fetchModel.fuelPrice
				data.fuelCost = fetchModel.fuelCost
				data.fuelOdometer = Float(fetchModel.odometer)
				data.fuelEngHours = fetchModel.engHours
				data.fuelLocation = fetchModel.location
				data.oilAdded = fetchModel.oilAdded
				data.defAdded = fetchModel.defAdded
				data.fuelNotes = fetchModel.fuelNotes
				data.oilChecked = fetchModel.oilChecked
				data.engineCoolantChecked = fetchModel.engineCoolantChecked
				data.secondaryCoolantChecked = fetchModel.secondaryCoolantChecked
				data.powerSteeringChecked = fetchModel.powerSteeringChecked
				data.brakeFluidChecked = fetchModel.brakeFluidChecked
				data.transmissionFluidChecked = fetchModel.transmissionFluidChecked
				data.rearAxleChecked = fetchModel.rearAxleChecked
				data.frontAxleChecked = fetchModel.frontAxleChecked
				data.fuelWaterSeparatorChecked = fetchModel.fuelWaterSeparatorChecked
				data.airSystemWaterBleedChecked = fetchModel.airSystemWaterBleedChecked
				data.fuelDateTime = fetchModel.fuelDateTime
				data.fuelExitTime = fetchModel.fuelExitTime
				data.image1 = fetchModel.image1
				data.image2 = fetchModel.image2
				data.image3 = fetchModel.image3
				data.fuelLevelStart = fetchModel.fuelLevelStart1
				data.fuelLevelEnd = fetchModel.fuelLevelEnd1
				data.defLevel = fetchModel.defLevel1
				data.fuelQuantityStart = fetchModel.fuelQuantityStart
				data.fuelQuantityEnd = fetchModel.fuelQuantityEnd
				data.defQuantity = fetchModel.defQuantity
				data.defLevelStart = fetchModel.defLevelStart1
				data.defQuantityStart = fetchModel.defQuantityStart
				data.defPrice = fetchModel.defPrice
				data.fuelType = fetchModel.fuelType
			}
		} catch {}
		return data
	}
	
	/// Fluid check flags recorded at travel start, in the sheet's display order.
	private var startFluidChecks: [Bool] {
		[startOilChecked, startEngineCoolantChecked, startSecondaryCoolantChecked,
		 startPowerSteeringChecked, startBrakeFluidChecked, startTransmissionFluidChecked,
		 startRearAxleChecked, startFrontAxleChecked,
		 startFuelWaterSeparatorChecked, startAirSystemWaterBleedChecked]
	}
	
	/// Fluid check flags recorded at travel end, in the sheet's display order.
	private var endFluidChecks: [Bool] {
		[endOilChecked, endEngineCoolantChecked, endSecondaryCoolantChecked,
		 endPowerSteeringChecked, endBrakeFluidChecked, endTransmissionFluidChecked,
		 endRearAxleChecked, endFrontAxleChecked,
		 endFuelWaterSeparatorChecked, endAirSystemWaterBleedChecked]
	}
	
	/// "Fluid Checks" with a running count, so the button says how many were done
	/// without having to open the sheet.
	private func fluidChecksTitle(_ flags: [Bool]) -> String {
		"Fluid Checks (\(flags.filter { $0 }.count) completed)"
	}
	
	/// Seconds spent at an enroute stop.
	/// - Returns: 0 when the stop is unused, or when either time was never recorded.
	private func stopDuration(active: Bool, enter: Date?, exit: Date?) -> TimeInterval {
		guard active, let enter, let exit, exit > enter else { return 0 }
		return exit.timeIntervalSince(enter)
	}
	
	/// Comma-separated list of the fluids marked checked, for the details view.
	/// - Parameter flags: Fluid name / checked pairs, in display order.
	/// - Returns: The checked names joined with commas, or an empty string when none were checked.
	private func checkedFluidList(_ flags: [(String, Bool)]) -> String {
		flags.filter { $0.1 }.map { $0.0 }.joined(separator: ", ")
	}
	
	/// Loads the vehicle's fuel logs so an enroute stop can be linked to a record that
	/// already exists instead of always creating a new one.
	private func loadAvailableFuelLogs() {
		let vid = vehicleId
		guard !vid.isEmpty else {
			availableFuelLogs = []
			return
		}
		do {
			var fd = FetchDescriptor<FuelLog1>(
				predicate: #Predicate { $0.vehicleId == vid && $0.inactive == false },
				sortBy: [SortDescriptor(\.fuelDateTime, order: .reverse)]
			)
			fd.fetchLimit = 200
			availableFuelLogs = try modelContext.fetch(fd)
				.filter { !$0.logId.isEmpty }
				.map { log in
					let qty = log.fuelAdded.formatted(.number.precision(.fractionLength(1)))
					// Day and month only, no year or time — the fetch above already orders by the
					// full timestamp. The station name goes ahead of the quantity: the menu label
					// truncates at the tail, and the station identifies a log better than the volume.
					let parts = [
						functions.formatDate_DDMMM(date: log.fuelDateTime),
						log.location.trimmingCharacters(in: .whitespacesAndNewlines),
						"\(qty)\(unit(UnitIndex.fuel))"
					]
					return FuelLogChoice(
						id: log.logId,
						label: parts.filter { !$0.isEmpty }.joined(separator: " • ")
					)
				}
		} catch {
			availableFuelLogs = []
		}
	}
	
	/// Fuel logs a stop may pick from: the vehicle's logs, less any already linked to another
	/// stop on this trip, plus this stop's own link so the picker always has a valid selection.
	/// - Parameter currentlyLinked: The `logId` this stop is linked to, or an empty string.
	private func fuelLogChoices(currentlyLinked: String) -> [FuelLogChoice] {
		let taken = Set([fuelAdded1Log, fuelAdded2Log, fuelAdded3Log, fuelAdded4Log, fuelAdded5Log, fuelAdded6Log]
			.filter { !$0.isEmpty && $0 != currentlyLinked })
		var choices = availableFuelLogs.filter { !taken.contains($0.id) }
		if !currentlyLinked.isEmpty, !choices.contains(where: { $0.id == currentlyLinked }) {
			choices.insert(FuelLogChoice(id: currentlyLinked, label: "Linked log \(currentlyLinked)"), at: 0)
		}
		return choices
	}
	
	/// Populates an enroute stop from the fuel log the user picked for it.
	///
	/// Choosing "New Log" clears the link and leaves the typed values alone, so a fresh
	/// record is created on save. Choosing an existing log overwrites the stop's fields with
	/// that record's values; saving afterwards writes any further edits back to it.
	/// - Parameters:
	///   - index: Stop number, 1 through 6.
	///   - logId: The chosen `FuelLog1.logId`, or an empty string for a new log.
	private func linkStop(_ index: Int, to logId: String) {
		guard !logId.isEmpty else {
			stopsForcedNew.insert(index)
			return
		}
		stopsForcedNew.remove(index)
		let d = getFuelLogData(saveLogId: logId)
		switch index {
		case 1:
			fuelAdded1 = d.fuelAdded; fuelPrice1 = d.fuelPrice; fuelOdometer1 = d.fuelOdometer; fuelEngHours1 = d.fuelEngHours
			fuelLocation1 = d.fuelLocation; oilAdded1 = d.oilAdded; defAdded1 = d.defAdded; fuelNotes1 = d.fuelNotes
			oilChecked1 = d.oilChecked; engineCoolantChecked1 = d.engineCoolantChecked; secondaryCoolantChecked1 = d.secondaryCoolantChecked; powerSteeringChecked1 = d.powerSteeringChecked; brakeFluidChecked1 = d.brakeFluidChecked; transmissionFluidChecked1 = d.transmissionFluidChecked; rearAxleChecked1 = d.rearAxleChecked; frontAxleChecked1 = d.frontAxleChecked; fuelWaterSeparatorChecked1 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked1 = d.airSystemWaterBleedChecked
			fuelDateTime1 = d.fuelDateTime
			fuelStop1Image1 = d.image1; fuelStop1Image2 = d.image2; fuelStop1Image3 = d.image3
			stopFuelLevelStart1 = d.fuelLevelStart; stopFuelLevelEnd1 = d.fuelLevelEnd; stopDefLevel1 = d.defLevel; stopFuelType1 = d.fuelType
			stopFuelQtyStart1 = d.fuelQuantityStart; stopFuelQtyEnd1 = d.fuelQuantityEnd; stopDefQty1 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart1 = d.defLevelStart; stopDefQtyStart1 = d.defQuantityStart
			stopDefPrice1 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime1 = max(exit, fuelDateTime1) }
			createFuelLog1 = true
			if stopReason1.isEmpty { stopReason1 = "Fuel" }
		case 2:
			fuelAdded2 = d.fuelAdded; fuelPrice2 = d.fuelPrice; fuelOdometer2 = d.fuelOdometer; fuelEngHours2 = d.fuelEngHours
			fuelLocation2 = d.fuelLocation; oilAdded2 = d.oilAdded; defAdded2 = d.defAdded; fuelNotes2 = d.fuelNotes
			oilChecked2 = d.oilChecked; engineCoolantChecked2 = d.engineCoolantChecked; secondaryCoolantChecked2 = d.secondaryCoolantChecked; powerSteeringChecked2 = d.powerSteeringChecked; brakeFluidChecked2 = d.brakeFluidChecked; transmissionFluidChecked2 = d.transmissionFluidChecked; rearAxleChecked2 = d.rearAxleChecked; frontAxleChecked2 = d.frontAxleChecked; fuelWaterSeparatorChecked2 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked2 = d.airSystemWaterBleedChecked
			fuelDateTime2 = d.fuelDateTime
			fuelStop2Image1 = d.image1; fuelStop2Image2 = d.image2; fuelStop2Image3 = d.image3
			stopFuelLevelStart2 = d.fuelLevelStart; stopFuelLevelEnd2 = d.fuelLevelEnd; stopDefLevel2 = d.defLevel; stopFuelType2 = d.fuelType
			stopFuelQtyStart2 = d.fuelQuantityStart; stopFuelQtyEnd2 = d.fuelQuantityEnd; stopDefQty2 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart2 = d.defLevelStart; stopDefQtyStart2 = d.defQuantityStart
			stopDefPrice2 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime2 = max(exit, fuelDateTime2) }
			createFuelLog2 = true
			if stopReason2.isEmpty { stopReason2 = "Fuel" }
		case 3:
			fuelAdded3 = d.fuelAdded; fuelPrice3 = d.fuelPrice; fuelOdometer3 = d.fuelOdometer; fuelEngHours3 = d.fuelEngHours
			fuelLocation3 = d.fuelLocation; oilAdded3 = d.oilAdded; defAdded3 = d.defAdded; fuelNotes3 = d.fuelNotes
			oilChecked3 = d.oilChecked; engineCoolantChecked3 = d.engineCoolantChecked; secondaryCoolantChecked3 = d.secondaryCoolantChecked; powerSteeringChecked3 = d.powerSteeringChecked; brakeFluidChecked3 = d.brakeFluidChecked; transmissionFluidChecked3 = d.transmissionFluidChecked; rearAxleChecked3 = d.rearAxleChecked; frontAxleChecked3 = d.frontAxleChecked; fuelWaterSeparatorChecked3 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked3 = d.airSystemWaterBleedChecked
			fuelDateTime3 = d.fuelDateTime
			fuelStop3Image1 = d.image1; fuelStop3Image2 = d.image2; fuelStop3Image3 = d.image3
			stopFuelLevelStart3 = d.fuelLevelStart; stopFuelLevelEnd3 = d.fuelLevelEnd; stopDefLevel3 = d.defLevel; stopFuelType3 = d.fuelType
			stopFuelQtyStart3 = d.fuelQuantityStart; stopFuelQtyEnd3 = d.fuelQuantityEnd; stopDefQty3 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart3 = d.defLevelStart; stopDefQtyStart3 = d.defQuantityStart
			stopDefPrice3 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime3 = max(exit, fuelDateTime3) }
			createFuelLog3 = true
			if stopReason3.isEmpty { stopReason3 = "Fuel" }
		case 4:
			fuelAdded4 = d.fuelAdded; fuelPrice4 = d.fuelPrice; fuelOdometer4 = d.fuelOdometer; fuelEngHours4 = d.fuelEngHours
			fuelLocation4 = d.fuelLocation; oilAdded4 = d.oilAdded; defAdded4 = d.defAdded; fuelNotes4 = d.fuelNotes
			oilChecked4 = d.oilChecked; engineCoolantChecked4 = d.engineCoolantChecked; secondaryCoolantChecked4 = d.secondaryCoolantChecked; powerSteeringChecked4 = d.powerSteeringChecked; brakeFluidChecked4 = d.brakeFluidChecked; transmissionFluidChecked4 = d.transmissionFluidChecked; rearAxleChecked4 = d.rearAxleChecked; frontAxleChecked4 = d.frontAxleChecked; fuelWaterSeparatorChecked4 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked4 = d.airSystemWaterBleedChecked
			fuelDateTime4 = d.fuelDateTime
			fuelStop4Image1 = d.image1; fuelStop4Image2 = d.image2; fuelStop4Image3 = d.image3
			stopFuelLevelStart4 = d.fuelLevelStart; stopFuelLevelEnd4 = d.fuelLevelEnd; stopDefLevel4 = d.defLevel; stopFuelType4 = d.fuelType
			stopFuelQtyStart4 = d.fuelQuantityStart; stopFuelQtyEnd4 = d.fuelQuantityEnd; stopDefQty4 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart4 = d.defLevelStart; stopDefQtyStart4 = d.defQuantityStart
			stopDefPrice4 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime4 = max(exit, fuelDateTime4) }
			createFuelLog4 = true
			if stopReason4.isEmpty { stopReason4 = "Fuel" }
		case 5:
			fuelAdded5 = d.fuelAdded; fuelPrice5 = d.fuelPrice; fuelOdometer5 = d.fuelOdometer; fuelEngHours5 = d.fuelEngHours
			fuelLocation5 = d.fuelLocation; oilAdded5 = d.oilAdded; defAdded5 = d.defAdded; fuelNotes5 = d.fuelNotes
			oilChecked5 = d.oilChecked; engineCoolantChecked5 = d.engineCoolantChecked; secondaryCoolantChecked5 = d.secondaryCoolantChecked; powerSteeringChecked5 = d.powerSteeringChecked; brakeFluidChecked5 = d.brakeFluidChecked; transmissionFluidChecked5 = d.transmissionFluidChecked; rearAxleChecked5 = d.rearAxleChecked; frontAxleChecked5 = d.frontAxleChecked; fuelWaterSeparatorChecked5 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked5 = d.airSystemWaterBleedChecked
			fuelDateTime5 = d.fuelDateTime
			fuelStop5Image1 = d.image1; fuelStop5Image2 = d.image2; fuelStop5Image3 = d.image3
			stopFuelLevelStart5 = d.fuelLevelStart; stopFuelLevelEnd5 = d.fuelLevelEnd; stopDefLevel5 = d.defLevel; stopFuelType5 = d.fuelType
			stopFuelQtyStart5 = d.fuelQuantityStart; stopFuelQtyEnd5 = d.fuelQuantityEnd; stopDefQty5 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart5 = d.defLevelStart; stopDefQtyStart5 = d.defQuantityStart
			stopDefPrice5 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime5 = max(exit, fuelDateTime5) }
			createFuelLog5 = true
			if stopReason5.isEmpty { stopReason5 = "Fuel" }
		case 6:
			fuelAdded6 = d.fuelAdded; fuelPrice6 = d.fuelPrice; fuelOdometer6 = d.fuelOdometer; fuelEngHours6 = d.fuelEngHours
			fuelLocation6 = d.fuelLocation; oilAdded6 = d.oilAdded; defAdded6 = d.defAdded; fuelNotes6 = d.fuelNotes
			oilChecked6 = d.oilChecked; engineCoolantChecked6 = d.engineCoolantChecked; secondaryCoolantChecked6 = d.secondaryCoolantChecked; powerSteeringChecked6 = d.powerSteeringChecked; brakeFluidChecked6 = d.brakeFluidChecked; transmissionFluidChecked6 = d.transmissionFluidChecked; rearAxleChecked6 = d.rearAxleChecked; frontAxleChecked6 = d.frontAxleChecked; fuelWaterSeparatorChecked6 = d.fuelWaterSeparatorChecked; airSystemWaterBleedChecked6 = d.airSystemWaterBleedChecked
			fuelDateTime6 = d.fuelDateTime
			fuelStop6Image1 = d.image1; fuelStop6Image2 = d.image2; fuelStop6Image3 = d.image3
			stopFuelLevelStart6 = d.fuelLevelStart; stopFuelLevelEnd6 = d.fuelLevelEnd; stopDefLevel6 = d.defLevel; stopFuelType6 = d.fuelType
			stopFuelQtyStart6 = d.fuelQuantityStart; stopFuelQtyEnd6 = d.fuelQuantityEnd; stopDefQty6 = defQuantityOrDerived(d, capacity: Float(vehicleDetails?.defCapacity ?? 0))
			stopDefLevelStart6 = d.defLevelStart; stopDefQtyStart6 = d.defQuantityStart
			stopDefPrice6 = d.defPrice
			if let exit = d.fuelExitTime { fuelExitTime6 = max(exit, fuelDateTime6) }
			createFuelLog6 = true
			if stopReason6.isEmpty { stopReason6 = "Fuel" }
		default:
			break
		}
		// Linking changes the fuel added at the stop, not what's in the tank at either end.
		recomputeFuelConsumed()
	}
	
	/// Ends text editing so an in-flight field commits its value to its binding.
	///
	/// `TextField(value:formatter:)` — used by the fuel-stop quantity, price, odometer,
	/// engine-hours, oil and DEF fields — only writes to its binding when it loses focus.
	/// Tapping Save while such a field is still focused would otherwise read the previous
	/// value and appear to discard the edit.
	private func commitPendingTextEdits() {
#if os(iOS)
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#elseif os(macOS)
		NSApp.keyWindow?.makeFirstResponder(nil)
#endif
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
		// Start each stop's fuel type off at the vehicle's own fuel type. A stop that already
		// carries a value (typed here or read back from its fuel log) is left alone.
		let type = vehicleDetails?.fuelType ?? ""
		guard !type.isEmpty else { return }
		if stopFuelType1.isEmpty { stopFuelType1 = type }
		if stopFuelType2.isEmpty { stopFuelType2 = type }
		if stopFuelType3.isEmpty { stopFuelType3 = type }
		if stopFuelType4.isEmpty { stopFuelType4 = type }
		if stopFuelType5.isEmpty { stopFuelType5 = type }
		if stopFuelType6.isEmpty { stopFuelType6 = type }
	}
	
	/// Seeds a stop's fuel/DEF quantities from its eighths dropdown when it hasn't got one
	/// yet — a brand new stop, or a linked log saved before the quantity fields existed —
	/// so the figure and the dropdown never disagree on screen.
	private func seedStopQuantities() {
		let fuelCap = Float(vehicleDetails?.fuelCapacity ?? 0)
		let defCap = Float(vehicleDetails?.defCapacity ?? 0)
		if fuelCap > 0, stopFuelQtyStart1 == 0 { stopFuelQtyStart1 = fuelCap * stopFuelLevelStart1 }
		if fuelCap > 0, stopFuelQtyEnd1 == 0 { stopFuelQtyEnd1 = fuelCap * stopFuelLevelEnd1 }
		if defCap > 0, stopDefQty1 == 0 { stopDefQty1 = defCap * stopDefLevel1 }
		if defCap > 0, stopDefQtyStart1 == 0 { stopDefQtyStart1 = defCap * stopDefLevelStart1 }
		if fuelCap > 0, stopFuelQtyStart2 == 0 { stopFuelQtyStart2 = fuelCap * stopFuelLevelStart2 }
		if fuelCap > 0, stopFuelQtyEnd2 == 0 { stopFuelQtyEnd2 = fuelCap * stopFuelLevelEnd2 }
		if defCap > 0, stopDefQty2 == 0 { stopDefQty2 = defCap * stopDefLevel2 }
		if defCap > 0, stopDefQtyStart2 == 0 { stopDefQtyStart2 = defCap * stopDefLevelStart2 }
		if fuelCap > 0, stopFuelQtyStart3 == 0 { stopFuelQtyStart3 = fuelCap * stopFuelLevelStart3 }
		if fuelCap > 0, stopFuelQtyEnd3 == 0 { stopFuelQtyEnd3 = fuelCap * stopFuelLevelEnd3 }
		if defCap > 0, stopDefQty3 == 0 { stopDefQty3 = defCap * stopDefLevel3 }
		if defCap > 0, stopDefQtyStart3 == 0 { stopDefQtyStart3 = defCap * stopDefLevelStart3 }
		if fuelCap > 0, stopFuelQtyStart4 == 0 { stopFuelQtyStart4 = fuelCap * stopFuelLevelStart4 }
		if fuelCap > 0, stopFuelQtyEnd4 == 0 { stopFuelQtyEnd4 = fuelCap * stopFuelLevelEnd4 }
		if defCap > 0, stopDefQty4 == 0 { stopDefQty4 = defCap * stopDefLevel4 }
		if defCap > 0, stopDefQtyStart4 == 0 { stopDefQtyStart4 = defCap * stopDefLevelStart4 }
		if fuelCap > 0, stopFuelQtyStart5 == 0 { stopFuelQtyStart5 = fuelCap * stopFuelLevelStart5 }
		if fuelCap > 0, stopFuelQtyEnd5 == 0 { stopFuelQtyEnd5 = fuelCap * stopFuelLevelEnd5 }
		if defCap > 0, stopDefQty5 == 0 { stopDefQty5 = defCap * stopDefLevel5 }
		if defCap > 0, stopDefQtyStart5 == 0 { stopDefQtyStart5 = defCap * stopDefLevelStart5 }
		if fuelCap > 0, stopFuelQtyStart6 == 0 { stopFuelQtyStart6 = fuelCap * stopFuelLevelStart6 }
		if fuelCap > 0, stopFuelQtyEnd6 == 0 { stopFuelQtyEnd6 = fuelCap * stopFuelLevelEnd6 }
		if defCap > 0, stopDefQty6 == 0 { stopDefQty6 = defCap * stopDefLevel6 }
		if defCap > 0, stopDefQtyStart6 == 0 { stopDefQtyStart6 = defCap * stopDefLevelStart6 }
	}
	/// Recomputes the running consumed estimate from the current start/end quantities.
	///
	/// Kept separate from `recomputeFuelQuantities()` so a quantity the user typed by hand
	/// is never overwritten just because the estimate needed refreshing.
	private func recomputeFuelConsumed() {
		fuelConsumed = max(0, (fuelQuantityStart - fuelQuantityEnd) + fuelAdded1 + fuelAdded2 + fuelAdded3 + fuelAdded4 + fuelAdded5 + fuelAdded6)
	}
	
	/// Recomputes start/end fuel quantities from the eighths pickers, then the consumed estimate.
	///
	/// Used when the vehicle changes, since the tank capacity the quantities derive from
	/// changes with it. Not called on appear, where a typed exact quantity must survive.
	private func recomputeFuelQuantities() {
		let capacity = Float(vehicleDetails?.fuelCapacity ?? 0)
		fuelQuantityStart = capacity * fuelLevelStart1
		fuelQuantityEnd = capacity * fuelLevelEnd1
		let defCapacity = Float(vehicleDetails?.defCapacity ?? 0)
		defQuantityStart = defCapacity * defLevel1
		defQuantityEnd = defCapacity * defLevelEnd1
		recomputeFuelConsumed()
	}
	
	/// Derives a DEF quantity for a record saved before the field existed, so the editable
	/// field doesn't read zero next to a dropdown saying "1/2 Tank".
	private func backfillDefQuantities() {
		let capacity = Float(vehicleDetails?.defCapacity ?? 0)
		guard capacity > 0 else { return }
		if defQuantityStart == 0, defLevel1 > 0 { defQuantityStart = capacity * defLevel1 }
		if defQuantityEnd == 0, defLevelEnd1 > 0 { defQuantityEnd = capacity * defLevelEnd1 }
	}
	
	/// A tank reading as "1/4 Tank (25.0gal)", pairing the eighths label with the exact
	/// quantity so a typed figure shows rather than just the eighth it snapped to.
	/// - Returns: The quantity alone when the fraction has no label (a non-eighth value).
	private func tankReading(fraction: Float, quantity: Float, unitLabel: String) -> String {
		let label = functions.getFuelLevel(unit: fraction)
		let amount = quantity.formatted(.number.precision(.fractionLength(1)))
		return label.isEmpty ? "\(amount)\(unitLabel)" : "\(label) (\(amount)\(unitLabel))"
	}

	/// Small numbered badge overlaid on a stop card's top-left corner, replacing the
	/// "(N)" that used to be inline in the stop's title text.
	private func stopNumberBadge(_ number: Int) -> some View {
		Text("\(number)")
			.font(.caption2.bold())
			.foregroundStyle(.white)
			.frame(width: 20, height: 20)
			.background(Circle().fill(Color.blue))
			.offset(x: -8, y: -8)
	}

	/// A stop's DEF quantity, derived from its fraction when the linked log predates the
	/// quantity field, so a stop never opens showing zero next to "1/2 Tank".
	private func defQuantityOrDerived(_ data: FuelStopData, capacity: Float) -> Float {
		data.defQuantity > 0 ? data.defQuantity : capacity * data.defLevel
	}
	
	/// Snaps a 0...1 tank ratio to the nearest eighth, matching the dropdown's choices.
	/// - Note: `Functions.getFuelLevel(unit:)` only labels exact eighths, so a raw ratio
	///   has to be snapped before it can be turned into a fraction label.
	private func nearestFuelEighth(_ ratio: Float) -> Float {
		let clamped = min(1, max(0, ratio))
		return (clamped * 8).rounded() / 8
	}
}

// MARK: - Statistics helpers
private extension EditTripLog {
	/// Aggregated statistics for a single trip, derived from `TripLog2` and linked fuel logs.
	struct TripStats {
		let totalElapsedString: String
		let totalElapsedHours: Double
		let durationString: String
		let durationHours: Double
		let engineTime: Float
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
		// Total elapsed (raw start to end)
		let tripTotalInterval = dataSet.tripDateTimeEnd.timeIntervalSince(dataSet.tripDateTimeStart)
		let elapsedSecs = Int(max(0, tripTotalInterval))
		let daysE = elapsedSecs / 86400
		let hoursE = (elapsedSecs % 86400) / 3600
		let minsE = (elapsedSecs % 3600) / 60
		let totalElapsedString: String = {
			if daysE != 0 {
				return "\(daysE) days, \(hoursE) hours, \(minsE) minutes"
			} else if hoursE != 0 {
				return "\(hoursE) hours, \(minsE) minutes"
			} else {
				return "\(minsE) minutes"
			}
		}()
		let totalElapsedHours = max(0.0, (Double(daysE) * 24.0) + Double(hoursE) + Double(minsE)/60.0)
		// Time underway = total elapsed - time at fuel stops
		var stopTotalInterval: TimeInterval = 0
		if (dataSet.fuelAdded1 > 0 || !dataSet.stopReason1.isEmpty) && fuelExitTime1 > fuelDateTime1 { stopTotalInterval += fuelExitTime1.timeIntervalSince(fuelDateTime1) }
		if (dataSet.fuelAdded2 > 0 || !dataSet.stopReason2.isEmpty) && fuelExitTime2 > fuelDateTime2 { stopTotalInterval += fuelExitTime2.timeIntervalSince(fuelDateTime2) }
		if (dataSet.fuelAdded3 > 0 || !dataSet.stopReason3.isEmpty) && fuelExitTime3 > fuelDateTime3 { stopTotalInterval += fuelExitTime3.timeIntervalSince(fuelDateTime3) }
		if (dataSet.fuelAdded4 > 0 || !dataSet.stopReason4.isEmpty) && fuelExitTime4 > fuelDateTime4 { stopTotalInterval += fuelExitTime4.timeIntervalSince(fuelDateTime4) }
		if (dataSet.fuelAdded5 > 0 || !dataSet.stopReason5.isEmpty) && fuelExitTime5 > fuelDateTime5 { stopTotalInterval += fuelExitTime5.timeIntervalSince(fuelDateTime5) }
		if (dataSet.fuelAdded6 > 0 || !dataSet.stopReason6.isEmpty) && fuelExitTime6 > fuelDateTime6 { stopTotalInterval += fuelExitTime6.timeIntervalSince(fuelDateTime6) }
		let movingInterval = max(0, tripTotalInterval - stopTotalInterval)
		let movingSecs = Int(movingInterval)
		let days = movingSecs / 86400
		let hours = (movingSecs % 86400) / 3600
		let mins = (movingSecs % 3600) / 60
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
		// Engine time
		let engineTime = max(0, engHoursEnd - engHoursStart)
		
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
			totalElapsedString: totalElapsedString,
			totalElapsedHours: totalElapsedHours,
			durationString: durationString,
			durationHours: durationHours,
			engineTime: engineTime,
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
		let totalElapsedHours: Double
		let totalHours: Double
		let totalEngineTime: Float
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
		var totalElapsedHours: Double = 0
		var totalHours: Double = 0
		var totalEngineTime: Float = 0
		var totalFuelBurned: Float = 0
		
		for t in trips {
			let distance = max(0, t.odometerEnd - t.odometerStart)
			totalDistance += distance
			let rawInterval = t.tripDateTimeEnd.timeIntervalSince(t.tripDateTimeStart)
			totalElapsedHours += max(0, rawInterval) / 3600.0
			var stopSecs: TimeInterval = 0
			stopSecs += stopDuration(active: t.fuelAdded1 > 0 || !t.stopReason1.isEmpty, enter: t.fuelDateTime1, exit: t.fuelExitTime1)
			stopSecs += stopDuration(active: t.fuelAdded2 > 0 || !t.stopReason2.isEmpty, enter: t.fuelDateTime2, exit: t.fuelExitTime2)
			stopSecs += stopDuration(active: t.fuelAdded3 > 0 || !t.stopReason3.isEmpty, enter: t.fuelDateTime3, exit: t.fuelExitTime3)
			stopSecs += stopDuration(active: t.fuelAdded4 > 0 || !t.stopReason4.isEmpty, enter: t.fuelDateTime4, exit: t.fuelExitTime4)
			stopSecs += stopDuration(active: t.fuelAdded5 > 0 || !t.stopReason5.isEmpty, enter: t.fuelDateTime5, exit: t.fuelExitTime5)
			stopSecs += stopDuration(active: t.fuelAdded6 > 0 || !t.stopReason6.isEmpty, enter: t.fuelDateTime6, exit: t.fuelExitTime6)
			totalHours += max(0, rawInterval - stopSecs) / 3600.0
			totalEngineTime += max(0, t.engHoursEnd - t.engHoursStart)
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
			totalElapsedHours: totalElapsedHours,
			totalHours: totalHours,
			totalEngineTime: totalEngineTime,
			totalFuelBurned: totalFuelBurned,
			avgEconomy: avgEconomy,
			totalFuelCost: totalFuelCost,
			totalOilAdded: totalOilAdded,
			totalDEFAdded: totalDEFAdded
		)
	}

	struct GroupTotals {
		let tripCount: Int
		let totalDistance: Int
		let totalElapsedHours: Double
		let totalFuelBurned: Float
		let avgEconomy: Double
		let totalFuelCost: Float
		let totalOilAdded: Float
		let totalDEFAdded: Float
	}

	func computeGroupTotals() -> GroupTotals? {
		guard !tripGroup.isEmpty else { return nil }
		var trips: [TripLog2] = []
		do {
			let groupName = tripGroup
			let fd = FetchDescriptor<TripLog2>(predicate: #Predicate { $0.tripGroup == groupName })
			trips = try modelContext.fetch(fd)
		} catch {}

		var totalDistance = 0
		var totalElapsedHours: Double = 0
		var totalFuelBurned: Float = 0
		for t in trips {
			totalDistance += max(0, t.odometerEnd - t.odometerStart)
			let rawInterval = t.tripDateTimeEnd.timeIntervalSince(t.tripDateTimeStart)
			totalElapsedHours += max(0, rawInterval) / 3600.0
			let burned = (t.fuelQuantityStart + t.fuelAdded1 + t.fuelAdded2 + t.fuelAdded3 + t.fuelAdded4 + t.fuelAdded5 + t.fuelAdded6) - t.fuelQuantityEnd
			totalFuelBurned += burned
		}
		let avgEconomy: Double = totalFuelBurned > 0 ? Double(totalDistance) / Double(totalFuelBurned) : 0

		var totalFuelCost: Float = 0
		var totalOilAdded: Float = 0
		var totalDEFAdded: Float = 0
		do {
			var logIds: [String] = []
			for t in trips {
				for id in [t.fuelAdded1Log, t.fuelAdded2Log, t.fuelAdded3Log, t.fuelAdded4Log, t.fuelAdded5Log, t.fuelAdded6Log] {
					if !id.isEmpty { logIds.append(id) }
				}
			}
			if !logIds.isEmpty {
				let fd = FetchDescriptor<FuelLog1>(predicate: #Predicate { logIds.contains($0.logId) })
				let logs = try modelContext.fetch(fd)
				for l in logs {
					totalFuelCost += l.fuelCost
					totalOilAdded += l.oilAdded
					totalDEFAdded += l.defAdded
				}
			}
		} catch {}

		return GroupTotals(
			tripCount: trips.count,
			totalDistance: totalDistance,
			totalElapsedHours: totalElapsedHours,
			totalFuelBurned: totalFuelBurned,
			avgEconomy: avgEconomy,
			totalFuelCost: totalFuelCost,
			totalOilAdded: totalOilAdded,
			totalDEFAdded: totalDEFAdded
		)
	}

	private func loadAvailableGroups() {
		do {
			let fd = FetchDescriptor<TripLog2>()
			let all = try modelContext.fetch(fd)
			var groups = Array(Set(all.compactMap { t in
				t.tripGroup.isEmpty ? nil : t.tripGroup
			})).sorted()
			if !tripGroup.isEmpty && !groups.contains(tripGroup) {
				groups.insert(tripGroup, at: 0)
			}
			availableGroups = groups
			if !tripGroup.isEmpty && groups.contains(tripGroup) && tripGroupSelection == "__none__" {
				tripGroupSelection = tripGroup
			}
		} catch {}
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


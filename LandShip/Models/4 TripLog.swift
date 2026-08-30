//
//  FuelLog.swift
//  LandShip
//
//  Created by JP on 9/11/25.
//

import Foundation
import SwiftData

@Model
class TripLog2	{
	
	var inactive: Bool = false
	var vehicleId: String = ""
	var logName: String = ""
	var tripNotes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var tripDateTimeStart: Date = Date()
	var tripDateTimeEnd: Date = Date()
	var odometerStart: Int = 0
	var odometerEnd: Int = 0
	var engHoursStart: Float = 0.0
	var engHoursEnd: Float = 0.0
	var fuelQuantityStart: Float = 0.0
	var fuelQuantityEnd: Float = 0.0
	var fuelConsumed: Float = 0.0
	var fuelLevelStart1: Float = 1.0
	var fuelLevelEnd1: Float = 1.0
	var fuelLevelStart: String = "Full"
	var fuelLevelEnd: String = "Full"
	var defLevel1: Float = 0.0
	var defLevelFraction: String = ""
	var defLevelEnd1: Float = 0.0
	var defLevelEndFraction: String = ""
	// Actual DEF in the tank at each end of the trip. The fraction fields above are the
	// eighths estimate; these hold what was really there, typed or derived.
	var defQuantityStart: Float = 0.0
	var defQuantityEnd: Float = 0.0
	var fuelAdded1Log: String = ""
	var fuelAdded1: Float = 0.0
	var fuelAdded2Log: String = ""
	var fuelAdded2: Float = 0.0
	var fuelAdded3Log: String = ""
	var fuelAdded3: Float = 0.0
	var fuelAdded4Log: String = ""
	var fuelAdded4: Float = 0.0
	var fuelAdded5Log: String = ""
	var fuelAdded5: Float = 0.0
	var fuelAdded6Log: String = ""
	var fuelAdded6: Float = 0.0
	// Entry and exit time for each enroute stop. `nil` means the time was never
	// recorded, which the editors distinguish from a real value.
	var fuelDateTime1: Date?
	var fuelDateTime2: Date?
	var fuelDateTime3: Date?
	var fuelDateTime4: Date?
	var fuelDateTime5: Date?
	var fuelDateTime6: Date?
	var fuelExitTime1: Date?
	var fuelExitTime2: Date?
	var fuelExitTime3: Date?
	var fuelExitTime4: Date?
	var fuelExitTime5: Date?
	var fuelExitTime6: Date?
	var stopReason1: String = ""
	var stopReason2: String = ""
	var stopReason3: String = ""
	var stopReason4: String = ""
	var stopReason5: String = ""
	var stopReason6: String = ""
	var stopComment1: String = ""
	var stopComment2: String = ""
	var stopComment3: String = ""
	var stopComment4: String = ""
	var stopComment5: String = ""
	var stopComment6: String = ""
	var fuelLocation1: String = ""
	var fuelLocation2: String = ""
	var fuelLocation3: String = ""
	var fuelLocation4: String = ""
	var fuelLocation5: String = ""
	var fuelLocation6: String = ""
	var locationStart: String = ""
	var locationEnd: String = ""
	// Fluid checks performed at travel start
	var startOilChecked: Bool = false
	var startEngineCoolantChecked: Bool = false
	var startSecondaryCoolantChecked: Bool = false
	var startPowerSteeringChecked: Bool = false
	var startBrakeFluidChecked: Bool = false
	var startTransmissionFluidChecked: Bool = false
	var startRearAxleChecked: Bool = false
	var startFrontAxleChecked: Bool = false
	var startFuelWaterSeparatorChecked: Bool = false
	var startAirSystemWaterBleedChecked: Bool = false
	// Fluid checks performed at travel end
	var endOilChecked: Bool = false
	var endEngineCoolantChecked: Bool = false
	var endSecondaryCoolantChecked: Bool = false
	var endPowerSteeringChecked: Bool = false
	var endBrakeFluidChecked: Bool = false
	var endTransmissionFluidChecked: Bool = false
	var endRearAxleChecked: Bool = false
	var endFrontAxleChecked: Bool = false
	var endFuelWaterSeparatorChecked: Bool = false
	var endAirSystemWaterBleedChecked: Bool = false
	var vehicleTowed: Bool = false
	var vehicleIdTowed: String = ""
	var tripGroup: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""
	@Attribute(.externalStorage)
	var fuelStop1Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop1Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop1Image3: Data?
	@Attribute(.externalStorage)
	var fuelStop2Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop2Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop2Image3: Data?
	@Attribute(.externalStorage)
	var fuelStop3Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop3Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop3Image3: Data?
	@Attribute(.externalStorage)
	var fuelStop4Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop4Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop4Image3: Data?
	@Attribute(.externalStorage)
	var fuelStop5Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop5Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop5Image3: Data?
	@Attribute(.externalStorage)
	var fuelStop6Image1: Data?
	@Attribute(.externalStorage)
	var fuelStop6Image2: Data?
	@Attribute(.externalStorage)
	var fuelStop6Image3: Data?

	init(
		inactive: Bool = false,
		vehicleId: String = "",
		logName: String = "",
		tripNotes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		tripDateTimeStart: Date = Date(),
		tripDateTimeEnd: Date = Date(),
		odometerStart: Int = 0,
		odometerEnd: Int = 0,
		engHoursStart: Float = 0.0,
		engHoursEnd: Float = 0.0,
		fuelQuantityStart: Float = 0.0,
		fuelQuantityEnd: Float = 0.0,
		fuelConsumed: Float = 0.0,
		fuelLevelStart1: Float = 1.0,
		fuelLevelEnd1: Float = 1.0,
		fuelLevelStart: String = "Full",
		fuelLevelEnd: String = "Full",
		defLevel1: Float = 0.0,
		defLevelFraction: String = "",
		defLevelEnd1: Float = 0.0,
		defLevelEndFraction: String = "",
		fuelAdded1Log: String = "",
		fuelAdded1: Float = 0.0,
		fuelAdded2Log: String = "",
		fuelAdded2: Float = 0.0,
		fuelAdded3Log: String = "",
		fuelAdded3: Float = 0.0,
		fuelAdded4Log: String = "",
		fuelAdded4: Float = 0.0,
		fuelAdded5Log: String = "",
		fuelAdded5: Float = 0.0,
		fuelAdded6Log: String = "",
		fuelAdded6: Float = 0.0,
		fuelDateTime1: Date? = nil,
		fuelDateTime2: Date? = nil,
		fuelDateTime3: Date? = nil,
		fuelDateTime4: Date? = nil,
		fuelDateTime5: Date? = nil,
		fuelDateTime6: Date? = nil,
		locationStart: String = "",
		locationEnd: String = "",
		vehicleTowed: Bool = false,
		vehicleIdTowed: String = "",
		tripGroup: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""

	){
		self.inactive = inactive
		self.vehicleId = vehicleId
		self.logName = logName
		self.tripNotes = tripNotes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.tripDateTimeStart = tripDateTimeStart
		self.tripDateTimeEnd = tripDateTimeEnd
		self.odometerStart = odometerStart
		self.odometerEnd = odometerEnd
		self.engHoursStart = engHoursStart
		self.engHoursEnd = engHoursEnd
		self.fuelQuantityStart = fuelQuantityStart
		self.fuelQuantityEnd = fuelQuantityEnd
		self.fuelConsumed = fuelConsumed
		self.fuelLevelStart1 = fuelLevelStart1
		self.fuelLevelEnd1 = fuelLevelEnd1
		self.fuelLevelStart = fuelLevelStart
		self.fuelLevelEnd = fuelLevelEnd
		self.defLevel1 = defLevel1
		self.defLevelFraction = defLevelFraction
		self.defLevelEnd1 = defLevelEnd1
		self.defLevelEndFraction = defLevelEndFraction
		self.fuelAdded1Log = fuelAdded1Log
		self.fuelAdded1 = fuelAdded1
		self.fuelAdded2Log = fuelAdded2Log
		self.fuelAdded2 = fuelAdded2
		self.fuelAdded3Log = fuelAdded3Log
		self.fuelAdded3 = fuelAdded3
		self.fuelAdded4Log = fuelAdded4Log
		self.fuelAdded4 = fuelAdded4
		self.fuelAdded5Log = fuelAdded5Log
		self.fuelAdded5 = fuelAdded5
		self.fuelAdded6Log = fuelAdded6Log
		self.fuelAdded6 = fuelAdded6
		self.fuelDateTime1 = fuelDateTime1
		self.fuelDateTime2 = fuelDateTime2
		self.fuelDateTime3 = fuelDateTime3
		self.fuelDateTime4 = fuelDateTime4
		self.fuelDateTime5 = fuelDateTime5
		self.fuelDateTime6 = fuelDateTime6
		self.locationStart = locationStart
		self.locationEnd = locationEnd
		self.vehicleTowed = vehicleTowed
		self.vehicleIdTowed = vehicleIdTowed
		self.tripGroup = tripGroup
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
	
}

//
//  FuelLog.swift
//  LandShip
//
//  Created by JP on 9/11/25.
//

import Foundation
import SwiftData

@Model
class FuelLog1 {
	var inactive: Bool = false
	var logId: String = ""
	var vehicleId: String = ""
	var logName: String = ""
	var fuelNotes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var fuelDateTime: Date = Date()
	/// When the vehicle left this stop. `nil` on records made before exit time was tracked.
	var fuelExitTime: Date?
	var odometer: Int = 0
	var location: String = ""
	var engHours: Float = 0.0
	var fuelQuantityStart: Float = 0.0
	var fuelQuantityEnd: Float = 0.0
	var fuelAdded: Float = 0.0
	var defAdded: Float = 0.0
	var defPrice: Float = 0.0
	// DEF in the tank before adding any. `defLevel1`/`defLevelFraction`/`defQuantity` below
	// are the level *after* adding — kept under their original names to avoid a rename
	// migration, but labelled "DEF Level End" in the UI.
	var defLevelStart1: Float = 0.0
	var defLevelStartFraction: String = ""
	var defQuantityStart: Float = 0.0
	var defLevel1: Float = 0.0
	var defLevelFraction: String = ""
	/// Actual DEF in the tank after adding, alongside the eighths estimate in `defLevel1`.
	var defQuantity: Float = 0.0
	var oilAdded: Float = 0.0
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
	var fuelLevelStart1: Float = 1.0
	var fuelLevelEnd1: Float = 1.0
	var fuelLevelStartFraction: String = ""
	var fuelLevelEndFraction: String = ""
	var fuelPrice: Float = 0.0
	var fuelCost: Float = 0.0
	var fuelType: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""

	init(
		inactive: Bool = false,
		logId: String = "",
		vehicleId: String = "",
		logName: String = "",
		fuelNotes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		fuelDateTime: Date = Date(),
		fuelExitTime: Date? = nil,
		odometer: Int = 0,
		location: String = "",
		engHours: Float = 0.0,
		fuelQuantityStart: Float = 0.0,
		fuelQuantityEnd: Float = 0.0,
		fuelAdded: Float = 0.0,
		defAdded: Float = 0.0,
		defPrice: Float = 0.0,
		defLevelStart1: Float = 0.0,
		defLevelStartFraction: String = "",
		defQuantityStart: Float = 0.0,
		defLevel1: Float = 0.0,
		defLevelFraction: String = "",
		defQuantity: Float = 0.0,
		oilAdded: Float = 0.0,
		oilChecked: Bool = false,
		engineCoolantChecked: Bool = false,
		secondaryCoolantChecked: Bool = false,
		powerSteeringChecked: Bool = false,
		brakeFluidChecked: Bool = false,
		transmissionFluidChecked: Bool = false,
		rearAxleChecked: Bool = false,
		frontAxleChecked: Bool = false,
		fuelWaterSeparatorChecked: Bool = false,
		airSystemWaterBleedChecked: Bool = false,
		fuelLevelStart1: Float = 1.0,
		fuelLevelEnd1: Float = 1.0,
		fuelLevelStart: String = "",
		fuelLevelEnd: String = "",
		fuelPrice: Float = 0.0,
		fuelCost: Float = 0.0,
		fuelType: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""
	) {
		self.inactive = inactive
		self.logId = logId
		self.vehicleId = vehicleId
		self.logName = logName
		self.fuelNotes = fuelNotes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.fuelDateTime = fuelDateTime
		self.fuelExitTime = fuelExitTime
		self.odometer = odometer
		self.location = location
		self.engHours = engHours
		self.fuelQuantityStart = fuelQuantityStart
		self.fuelQuantityEnd = fuelQuantityEnd
		self.fuelAdded = fuelAdded
		self.defAdded = defAdded
		self.defPrice = defPrice
		self.defLevelStart1 = defLevelStart1
		self.defLevelStartFraction = defLevelStartFraction
		self.defQuantityStart = defQuantityStart
		self.defLevel1 = defLevel1
		self.defLevelFraction = defLevelFraction
		self.defQuantity = defQuantity
		self.oilAdded = oilAdded
		self.oilChecked = oilChecked
		self.engineCoolantChecked = engineCoolantChecked
		self.secondaryCoolantChecked = secondaryCoolantChecked
		self.powerSteeringChecked = powerSteeringChecked
		self.brakeFluidChecked = brakeFluidChecked
		self.transmissionFluidChecked = transmissionFluidChecked
		self.rearAxleChecked = rearAxleChecked
		self.frontAxleChecked = frontAxleChecked
		self.fuelWaterSeparatorChecked = fuelWaterSeparatorChecked
		self.airSystemWaterBleedChecked = airSystemWaterBleedChecked
		self.fuelLevelStart1 = fuelLevelStart1
		self.fuelLevelEnd1 = fuelLevelEnd1
		self.fuelLevelStartFraction = fuelLevelStart
		self.fuelLevelEndFraction = fuelLevelEnd
		self.fuelPrice = fuelPrice
		self.fuelCost = fuelCost
		self.fuelType = fuelType
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
	}
	
}

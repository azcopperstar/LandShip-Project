//
//  FuelLog.swift
//  LandShip
//
//  Created by JP on 9/11/25.
//

import Foundation
import SwiftData

@Model
class FuelLog1	{
	var logId: String = ""
	var vehicleId: String = ""
	var logName: String = ""
	var fuelNotes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var fuelDateTime: Date = Date()
	var odometer: Int = 0
	var location: String = ""
	var engHours: Float = 0.0
	var fuelQuantityStart: Float = 0.0
	var fuelQuantityEnd: Float = 0.0
	var fuelAdded: Float = 0.0
	var defAdded: Float = 0.0
	var oilAdded: Float = 0.0
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
		logId: String = "",
		vehicleId: String = "",
		logName: String = "",
		fuelNotes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		fuelDateTime: Date = Date(),
		odometer: Int = 0,
		location: String = "",
		engHours: Float = 0.0,
		fuelQuantityStart: Float = 0.0,
		fuelQuantityEnd: Float = 0.0,
		fuelAdded: Float = 0.0,
		defAdded: Float = 0.0,
		oilAdded: Float = 0.0,
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

	){
		self.logId = logId
		self.vehicleId = vehicleId
		self.logName = logName
		self.fuelNotes = fuelNotes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.fuelDateTime = fuelDateTime
		self.odometer = odometer
		self.location = location
		self.engHours = engHours
		self.fuelQuantityStart = fuelQuantityStart
		self.fuelQuantityEnd = fuelQuantityEnd
		self.fuelAdded = fuelAdded
		self.defAdded = defAdded
		self.oilAdded = oilAdded
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

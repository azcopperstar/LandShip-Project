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
	var locationStart: String = ""
	var locationEnd: String = ""
	var vehicleTowed: Bool = false
	var vehicleIdTowed: String = ""
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
		locationStart: String = "",
		locationEnd: String = "",
		vehicleTowed: Bool = false,
		vehicleIdTowed: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""

	){
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
		self.locationStart = locationStart
		self.locationEnd = locationEnd
		self.vehicleTowed = vehicleTowed
		self.vehicleIdTowed = vehicleIdTowed
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
	
}

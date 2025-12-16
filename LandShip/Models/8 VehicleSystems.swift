//
//  VehicleSystems1.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import Foundation
import SwiftData

@Model
class VehicleSystems1 {
	
		var inactive: Bool = false
		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var vehicleId: String = ""
		var systemName: String = ""
		var systemDescription: String = ""
		var systemType: String = ""
		var systemManufacturer: String = ""
		var systemModel: String = ""
		var systemSerialNumber: String = ""
		var systemPartNumber: String = ""
		var systemLocation: String = ""
		var systemStatus: String = ""
		var systemNotes: String = ""
		var systemImage: Data? = nil
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""


	init (
		inactive: Bool = false,
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		vehicleId: String,
		systemName: String,
		systemDescription: String,
		systemType: String,
		systemManufacturer: String,
		systemModel: String,
		systemSerialNumber: String,
		systemPartNumber: String,
		systemLocation: String,
		systemStatus: String,
		systemNotes: String,
		systemImage: Data?,
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""

	)
	{
		self.inactive = inactive
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.vehicleId = vehicleId
		self.systemName = systemName
		self.systemDescription = systemDescription
		self.systemType = systemType
		self.systemManufacturer = systemManufacturer
		self.systemModel = systemModel
		self.systemSerialNumber = systemSerialNumber
		self.systemPartNumber = systemPartNumber
		self.systemLocation = systemLocation
		self.systemStatus = systemStatus
		self.systemNotes = systemNotes
		self.systemImage = systemImage
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
}

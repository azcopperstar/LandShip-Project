//
//  MxParts1.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import Foundation
import SwiftData

@Model
class MxParts1 {
	
		var inactive: Bool = false
		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var vehicleId: String = ""
		var vehicleSystem: String = ""
		var partName: String = ""
		var partNumber: String = ""
		var partManufacture: String = ""
		var partDescription: String = ""
		var Notes: String = ""
		var costPerUnit: Float = 0
		var partUnit: String = ""
		var partSource: String = ""
		var partQuantity: Int = 0
		var partLocation: String = ""
		var partStatus: String = ""
		var partImage: Data? = nil
		var partSupplier: String = ""

		// Inventory tracking. When `inventoryTracked` is false, the remaining fields are
		// ignored everywhere else in the app (EditRecord consumption, DisplayParts, dashboard).
		var inventoryTracked: Bool = false
		var inventoryQuantityOnHand: Float = 0
		var inventoryReorderPoint: Float = 0
		var inventoryReorderQuantity: Float = 0

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
		vehicleSystem: String,
		partName: String,
		partNumber: String,
		partManufacture: String,
		partDescription: String,
		Notes: String,
		costPerUnit: Float,
		partUnit: String,
		partSource: String,
		partQuantity: Int,
		partLocation: String,
		partStatus: String,
		partImage: Data? = nil,
		partSupplier: String,
		inventoryTracked: Bool = false,
		inventoryQuantityOnHand: Float = 0,
		inventoryReorderPoint: Float = 0,
		inventoryReorderQuantity: Float = 0,
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
		self.vehicleSystem = vehicleSystem
		self.partName = partName
		self.partNumber = partNumber
		self.partManufacture = partManufacture
		self.partDescription = partDescription
		self.Notes = Notes
		self.costPerUnit = costPerUnit
		self.partUnit = partUnit
		self.partSource = partSource
		self.partQuantity = partQuantity
		self.partLocation = partLocation
		self.partStatus = partStatus
		self.partImage = partImage
		self.partSupplier = partSupplier
		self.inventoryTracked = inventoryTracked
		self.inventoryQuantityOnHand = inventoryQuantityOnHand
		self.inventoryReorderPoint = inventoryReorderPoint
		self.inventoryReorderQuantity = inventoryReorderQuantity
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
	}
}

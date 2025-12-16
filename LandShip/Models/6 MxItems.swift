//
//  MxItems.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import Foundation
import SwiftData

@Model
class MxItems3 {
		var inactive: Bool = false
		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var vehicleId: String = ""
		var vehicleSystem: String = ""
		var mxName: String = ""
		var mxDescription: String = ""
		var Notes: String = ""
		var vendor: String = ""
		var laborCost: Float = 0
		var intervalMonths: Int = 0
		var intervalMiles: Int = 0
		var intervalHours: Float = 0
		var part1: String = ""
		var part1Id: String = ""
		var part1Qty: Float = 0
		var part1cost: Float = 0
		var part1Unit: String = ""
		var part2: String = ""
		var part2Id: String = ""
		var part2Qty: Float = 0
		var part2cost: Float = 0
		var part2Unit: String = ""
		var part3: String = ""
		var part3Id: String = ""
		var part3Qty: Float = 0
		var part3cost: Float = 0
		var part3Unit: String = ""
		var part4: String = ""
		var part4Id: String = ""
		var part4Qty: Float = 0
		var part4cost: Float = 0
		var part4Unit: String = ""
		var part5: String = ""
		var part5Id: String = ""
		var part5Qty: Float = 0
		var part5cost: Float = 0
		var part5Unit: String = ""
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
		createdAt: Date,
		updatedAt: Date,
		vehicleId: String,
		vehicleSystem: String,
		mxName: String,
		mxDescription: String,
		Notes: String,
		vendor: String,
		laborCost: Float,
		intervalMonths: Int,
		intervalMiles: Int,
		intervalHours: Float,
		part1: String,
		part1Id: String,
		part1Qty: Float,
		part1cost: Float,
		part1Unit: String,
		part2: String,
		part2Id: String,
		part2Qty: Float,
		part2cost: Float,
		part2Unit: String,
		part3: String,
		part3Id: String,
		part3Qty: Float,
		part3cost: Float,
		part3Unit: String,
		part4: String,
		part4Id: String,
		part4Qty: Float,
		part4cost: Float,
		part4Unit: String,
		part5: String,
		part5Id: String,
		part5Qty: Float,
		part5cost: Float,
		part5Unit: String,
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
		self.mxName = mxName
		self.mxDescription = mxDescription
		self.Notes = Notes
		self.vendor = vendor
		self.laborCost = laborCost
		self.intervalMonths = intervalMonths
		self.intervalMiles = intervalMiles
		self.intervalHours = intervalHours
		self.part1 = part1
		self.part1Id = part1Id
		self.part1Qty = part1Qty
		self.part1cost = part1cost
		self.part1Unit = part1Unit
		self.part2 = part2
		self.part2Id = part2Id
		self.part2Qty = part2Qty
		self.part2cost = part2cost
		self.part2Unit = part1Unit
		self.part3 = part3
		self.part3Id = part3Id
		self.part3Qty = part3Qty
		self.part3cost = part3cost
		self.part3Unit = part1Unit
		self.part4 = part4
		self.part4Id = part4Id
		self.part4Qty = part4Qty
		self.part4cost = part4cost
		self.part4Unit = part1Unit
		self.part5 = part5
		self.part5Id = part5Id
		self.part5Qty = part5Qty
		self.part5cost = part5cost
		self.part5Unit = part1Unit
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
}

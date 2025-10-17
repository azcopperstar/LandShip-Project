//
//  MX.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import Foundation
import SwiftData

extension ServiceRecords1: Identifiable {}

@Model
class ServiceRecords1 {

		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var mxDate: Date = Date()
		var vehicleId: String = ""
		var Miles: Int = 0
		var engHours: Float = 0
		var mxName: String = ""
		var mxItemId: String = ""
		var mxDescription: String = ""
		var Notes: String = ""
		var vendor: String = ""
		var laborCost: Float = 0
		var part1: String = ""
		var part1cost: Float = 0
		var part1Unit: String = ""
		var part1Quantity: Int = 0
		var part2: String = ""
		var part2cost: Float = 0
		var part2Unit: String = ""
		var part2Quantity: Int = 0
		var part3: String = ""
		var part3cost: Float = 0
		var part3Unit: String = ""
		var part3Quantity: Int = 0
		var part4: String = ""
		var part4cost: Float = 0
		var part4Unit: String = ""
		var part4Quantity: Int = 0
		var part5: String = ""
		var part5cost: Float = 0
		var part5Unit: String = ""
		var part5Quantity: Int = 0
		var image: Data? = nil
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
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		mxDate: Date = Date(),
		vehicleId: String = "",
		Miles: Int = 0,
		engHours: Float = 0,
		mxName: String = "",
		mxItemId: String = "",
		mxDescription: String = "",
		Notes: String = "",
		vendor: String = "",
		laborCost: Float = 0,
		part1: String = "",
		part1cost: Float = 0,
		part1Unit: String = "",
		part1Quantity: Int = 0,
		part2: String = "",
		part2cost: Float = 0,
		part2Unit: String = "",
		part2Quantity: Int = 0,
		part3: String = "",
		part3cost: Float = 0,
		part3Unit: String = "",
		part3Quantity: Int = 0,
		part4: String = "",
		part4cost: Float = 0,
		part4Unit: String = "",
		part4Quantity: Int = 0,
		part5: String = "",
		part5cost: Float = 0,
		part5Unit: String = "",
		part5Quantity: Int = 0,
		image: Data? = nil,
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""

	)
	{
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.mxDate = mxDate
		self.vehicleId = vehicleId
		self.Miles = Miles
		self.engHours = engHours
		self.mxName = mxName
		self.mxItemId = mxItemId
		self.mxDescription = mxDescription
		self.Notes = Notes
		self.vendor = vendor
		self.laborCost = laborCost
		self.part1 = part1
		self.part1cost = part1cost
		self.part1Unit = part1Unit
		self.part1Quantity = part1Quantity
		self.part2 = part2
		self.part2cost = part2cost
		self.part2Unit = part1Unit
		self.part2Quantity = part1Quantity
		self.part3 = part3
		self.part3cost = part3cost
		self.part3Unit = part1Unit
		self.part3Quantity = part1Quantity
		self.part4 = part4
		self.part4cost = part4cost
		self.part4Unit = part1Unit
		self.part4Quantity = part1Quantity
		self.part5 = part5
		self.part5cost = part5cost
		self.part5Unit = part1Unit
		self.part5Quantity = part1Quantity
		self.image = image
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
}

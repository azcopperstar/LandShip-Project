//
//  Additions.swift
//  VehicleTrax
//
//  Created by JP on 2/14/26.
//

import Foundation
import SwiftData

@Model
class ProjectList {
	var inactive: Bool = false
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var vehicleId: String = ""
	var miles: Int = 0
	var engHours: Float = 0
	var itemName: String = ""
	var itemDescription: String = ""
	var itemNotes: String = ""
	var itemVendor: String = ""
	var category: String = ""
	var categoryOrder: Int = 0
	var subCategory: String = ""
	var subcategoryOrder: Int = 0
	var projectOrder: Int = 0
	var priority: Int = 0
	var itemCompleted: Bool = false //
	var completedAt: Date = Date()
	var saveInLogbook: Bool = false //
	var savedToLogbook: Bool = false //
	var additionsLinkId: String = ""
	var itemCost: Float = 0
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
	var image4: Data?
	var image4Description: String = ""
	@Attribute(.externalStorage)
	var image5: Data?
	var image5Description: String = ""

    init(
        inactive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        vehicleId: String = "",
        miles: Int = 0,
        engHours: Float = 0,
        itemName: String = "",
        itemDescription: String = "",
        itemNotes: String = "",
        itemVendor: String = "",
        category: String = "",
        categoryOrder: Int = 0,
        subCategory: String = "",
        subcategoryOrder: Int = 0,
        projectOrder: Int = 0,
				priority: Int = 0,
        itemCompleted: Bool = false,
				completedAt: Date,
				saveInLogbook: Bool = false,
				savedToLogbook: Bool = false,
        itemCost: Float = 0,
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
        image1: Data? = nil,
        image1Description: String = "",
        image2: Data? = nil,
        image2Description: String = "",
        image3: Data? = nil,
        image3Description: String = "",
        image4: Data? = nil,
        image4Description: String = "",
        image5: Data? = nil,
        image5Description: String = ""
    ) {
        self.inactive = inactive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.vehicleId = vehicleId
        self.miles = miles
        self.engHours = engHours
        self.itemName = itemName
        self.itemDescription = itemDescription
        self.itemNotes = itemNotes
        self.itemVendor = itemVendor
        self.category = category
        self.categoryOrder = categoryOrder
        self.subCategory = subCategory
        self.subcategoryOrder = subcategoryOrder
        self.projectOrder = projectOrder
			self.priority = priority
        self.itemCompleted = itemCompleted
			self.completedAt = completedAt
			self.saveInLogbook = saveInLogbook
			self.savedToLogbook = savedToLogbook
        self.itemCost = itemCost
			self.laborCost = laborCost
			self.part1 = part1
			self.part1cost = part1cost
			self.part1Unit = part1Unit
			self.part1Quantity = part1Quantity
			self.part2 = part2
			self.part2cost = part2cost
			self.part2Unit = part2Unit
			self.part2Quantity = part2Quantity
			self.part3 = part3
			self.part3cost = part3cost
			self.part3Unit = part3Unit
			self.part3Quantity = part3Quantity
			self.part4 = part4
			self.part4cost = part4cost
			self.part4Unit = part4Unit
			self.part4Quantity = part4Quantity
			self.part5 = part5
			self.part5cost = part5cost
			self.part5Unit = part5Unit
			self.part5Quantity = part5Quantity
        self.image1 = image1
        self.image1Description = image1Description
        self.image2 = image2
        self.image2Description = image2Description
        self.image3 = image3
        self.image3Description = image3Description
        self.image4 = image4
        self.image4Description = image4Description
        self.image5 = image5
        self.image5Description = image5Description
    }
}

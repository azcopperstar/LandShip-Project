//
//  Additions.swift
//  VehicleTrax
//
//  Created by JP on 2/14/26.
//

import Foundation
import SwiftData

@Model
class Subscriptions {
	var inactive: Bool = false
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var lastPayment: Date = Date() //
	var vehicleId: String = ""
	var miles: Int = 0
	var engHours: Float = 0
	var itemName: String = ""
	var itemDescription: String = ""
	var itemNotes: String = ""
	var itemVendor: String = ""
	var accountNumber: String = "" //
	var category: String = ""
	var subCategory: String = ""
	var itemRecurring: Bool = false //
	var itemRecurringInterval: String = "Month" //
	var itemRecurringDays: Int = 0 //
	var itemCost: Float = 0

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
        lastPayment: Date = Date(),
        vehicleId: String = "",
        miles: Int = 0,
        engHours: Float = 0,
        itemName: String = "",
        itemDescription: String = "",
        itemNotes: String = "",
        itemVendor: String = "",
        category: String = "",
        subCategory: String = "",
        itemRecurring: Bool = false,
				itemRecurringInterval: String = "Month",
        itemRecurringDays: Int = 0,
        itemCost: Float = 0,
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
        self.lastPayment = lastPayment
        self.vehicleId = vehicleId
        self.miles = miles
        self.engHours = engHours
        self.itemName = itemName
        self.itemDescription = itemDescription
        self.itemNotes = itemNotes
        self.itemVendor = itemVendor
        self.category = category
        self.subCategory = subCategory
        self.itemRecurring = itemRecurring
			self.itemRecurringInterval = itemRecurringInterval
        self.itemRecurringDays = itemRecurringDays
        self.itemCost = itemCost
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

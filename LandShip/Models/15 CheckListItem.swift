//
//  Additions.swift
//  VehicleTrax
//
//  Created by JP on 2/14/26.
//

import Foundation
import SwiftData

@Model
class CheckListItem {
	var inactive: Bool = false
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var checklistName: String = ""
	var itemName: String = ""
	var itemDescription: String = ""
	var itemNotes: String = ""
	var itemCompleted: Bool = false //
	var completedAt: Date = Date()
	var orderIndex: Int = 0
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	
	// Parent-child relationship for sub-items using UUID strings
	var itemID: String = ""
	var parentItemUUID: String? = nil
	var hasSubItems: Bool = false
	var subItemsSectionName: String = "Sub-Items"

    init(
        inactive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
				checklistName: String = "",
				itemName: String = "",
				itemDescription: String = "",
				itemNotes: String = "",
				itemCompleted: Bool = false,
				completedAt: Date,
				orderIndex: Int = 0,
				image1: Data? = nil,
				image1Description: String = "",
				itemID: String = UUID().uuidString,
				parentItemUUID: String? = nil,
				hasSubItems: Bool = false,
				subItemsSectionName: String = "Sub-Items"

    ) {
        self.inactive = inactive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.checklistName = checklistName
			self.itemName = itemName
        self.itemDescription = itemDescription
        self.itemNotes = itemNotes
        self.itemCompleted = itemCompleted
			self.completedAt = completedAt
			self.orderIndex = orderIndex
			self.image1 = image1
			self.image1Description = image1Description
			self.itemID = itemID
			self.parentItemUUID = parentItemUUID
			self.hasSubItems = hasSubItems
			self.subItemsSectionName = subItemsSectionName
    }
}

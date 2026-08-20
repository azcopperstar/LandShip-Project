//
//  Additions.swift
//  VehicleTrax
//
//  Created by JP on 2/14/26.
//

import Foundation
import SwiftData

@Model
class CheckList {
	var inactive: Bool = false
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var vehicleId: String = ""
	var category: String = ""
	var categoryOrder: Int = 0
	var checklistName: String = ""
	var checklistDescription: String = ""
	var checklistNotes: String = ""
	var checklistCompleted: Bool = false //
	var completedAt: Date = Date()
	var checklistOrder: Int = 0
	var completionLog: [Date] = []
	var headerBgColorHex: String = ""
	var headerFgColorHex: String = ""

	init(
			inactive: Bool = false,
			createdAt: Date = Date(),
			updatedAt: Date = Date(),
			vehicleId: String = "",
			category: String = "",
			categoryOrder: Int = 0,
			checklistName: String = "",
			checklistDescription: String = "",
			checklistNotes: String = "",
			checklistCompleted: Bool = false,
			completedAt: Date,
			checklistOrder: Int = 0,
			completionLog: [Date] = [],
			headerBgColorHex: String = "",
			headerFgColorHex: String = ""
	) {
			self.inactive = inactive
			self.createdAt = createdAt
			self.updatedAt = updatedAt
			self.vehicleId = vehicleId
			self.category = category
			self.categoryOrder = categoryOrder
			self.checklistName = checklistName
			self.checklistDescription = checklistDescription
			self.checklistNotes = checklistNotes
			self.checklistCompleted = checklistCompleted
		self.completedAt = completedAt
		self.checklistOrder = checklistOrder
		self.completionLog = completionLog
		self.headerBgColorHex = headerBgColorHex
		self.headerFgColorHex = headerFgColorHex
	}
}

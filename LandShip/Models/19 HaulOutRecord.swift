//
//  19 HaulOutRecord.swift
//  LandShip
//
//  A haul-out/yard record linked to a vessel by vehicleId — bottom paint, zincs,
//  running gear service, and cost. NauticalTrax only (see Vertical.enabledFeatures)
//  — additive model, not used by land or aviation.
//

import Foundation
import SwiftData

@Model
class HaulOutRecord {
	var inactive: Bool = false
	var vehicleId: String = ""
	var haulOutDate: Date = Date()
	var yardName: String = ""
	var bottomPaintType: String = ""
	var bottomPaintApplied: Bool = false
	var zincsReplaced: Bool = false
	var runningGearServiced: Bool = false
	var cost: Float = 0
	var nextDueDate: Date = Date()
	var notes: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		haulOutDate: Date = Date(),
		yardName: String = "",
		bottomPaintType: String = "",
		bottomPaintApplied: Bool = false,
		zincsReplaced: Bool = false,
		runningGearServiced: Bool = false,
		cost: Float = 0,
		nextDueDate: Date = Date(),
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.haulOutDate = haulOutDate
		self.yardName = yardName
		self.bottomPaintType = bottomPaintType
		self.bottomPaintApplied = bottomPaintApplied
		self.zincsReplaced = zincsReplaced
		self.runningGearServiced = runningGearServiced
		self.cost = cost
		self.nextDueDate = nextDueDate
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

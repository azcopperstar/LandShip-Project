//
//  17 InspectionCycle.swift
//  LandShip
//
//  A recurring inspection record (annual, 100-hour, pitot-static, transponder, ELT,
//  altimeter) linked to a vehicle by vehicleId. AeroTrax only (see
//  Vertical.enabledFeatures) — additive model, not used by land or marine.
//

import Foundation
import SwiftData

@Model
class InspectionCycle {
	var inactive: Bool = false
	var vehicleId: String = ""
	var inspectionType: String = ""
	var lastCompliedDate: Date = Date()
	var lastCompliedHours: Float = 0
	var intervalMonths: Int = 0
	var intervalHours: Float = 0
	var nextDueDate: Date = Date()
	var nextDueHours: Float = 0
	var performingShop: String = ""
	var notes: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		inspectionType: String = "",
		lastCompliedDate: Date = Date(),
		lastCompliedHours: Float = 0,
		intervalMonths: Int = 0,
		intervalHours: Float = 0,
		nextDueDate: Date = Date(),
		nextDueHours: Float = 0,
		performingShop: String = "",
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.inspectionType = inspectionType
		self.lastCompliedDate = lastCompliedDate
		self.lastCompliedHours = lastCompliedHours
		self.intervalMonths = intervalMonths
		self.intervalHours = intervalHours
		self.nextDueDate = nextDueDate
		self.nextDueHours = nextDueHours
		self.performingShop = performingShop
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

//
//  18 ComponentTimes.swift
//  LandShip
//
//  Tracks total time and time-since-overhaul for a single airframe/engine/propeller,
//  linked to a vehicle by vehicleId. One row per component so twins (two engines,
//  two props) are represented as separate records rather than flattened fields.
//  AeroTrax only (see Vertical.enabledFeatures) — additive model, not used by land
//  or marine.
//

import Foundation
import SwiftData

@Model
class ComponentTimes {
	var inactive: Bool = false
	var vehicleId: String = ""
	var componentName: String = ""
	var componentType: String = ""
	var totalTime: Float = 0
	var timeSinceOverhaul: Float = 0
	var lastOverhaulDate: Date = Date()
	var notes: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		componentName: String = "",
		componentType: String = "",
		totalTime: Float = 0,
		timeSinceOverhaul: Float = 0,
		lastOverhaulDate: Date = Date(),
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.componentName = componentName
		self.componentType = componentType
		self.totalTime = totalTime
		self.timeSinceOverhaul = timeSinceOverhaul
		self.lastOverhaulDate = lastOverhaulDate
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

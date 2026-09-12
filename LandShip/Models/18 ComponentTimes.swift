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
	// The engine's own current tach-gauge reading, tracked separately from `totalTime`
	// because replacing the tach gives it a new, unrelated reading. Flight-log saves accrue
	// into `totalTime` by the *change* in this value (tachEnd - currentTachTime), then advance
	// it to tachEnd — so a tach swap only needs this field corrected once (EditComponentTimes.swift)
	// and doesn't corrupt the accumulated totalTime. Zero means "never tach-tracked yet";
	// callers fall back to `totalTime` as the baseline until this gets its first real value.
	var currentTachTime: Float = 0
	var timeSinceOverhaul: Float = 0
	var lastOverhaulDate: Date = Date()
	var make: String = ""
	var horsepower: Float = 0
	var serialNumber: String = ""
	var notes: String = ""

	// Opt-in derivation, added without touching existing hand-entered data (both apps are
	// live in TestFlight, no SchemaMigrationPlan exists). `derivesFromMeter == false` —
	// every existing row for every existing user — keeps `totalTime` behaving exactly as
	// it does today. Flipping the toggle performs a one-time, confirmed, non-destructive
	// promotion (EditComponentTimes.swift): totalTime is copied into totalTimeAtSnapshot
	// and left untouched, never overwritten. See PartTimeMath.swift for the accrual math
	// this reuses.
	var derivesFromMeter: Bool = false
	var totalTimeAtSnapshot: Float = 0
	var snapshotMeterHours: Float = 0
	var snapshotDate: Date = Date()

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
		currentTachTime: Float = 0,
		timeSinceOverhaul: Float = 0,
		lastOverhaulDate: Date = Date(),
		make: String = "",
		horsepower: Float = 0,
		serialNumber: String = "",
		notes: String = "",
		derivesFromMeter: Bool = false,
		totalTimeAtSnapshot: Float = 0,
		snapshotMeterHours: Float = 0,
		snapshotDate: Date = Date(),
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.componentName = componentName
		self.componentType = componentType
		self.totalTime = totalTime
		self.currentTachTime = currentTachTime
		self.timeSinceOverhaul = timeSinceOverhaul
		self.lastOverhaulDate = lastOverhaulDate
		self.make = make
		self.horsepower = horsepower
		self.serialNumber = serialNumber
		self.notes = notes
		self.derivesFromMeter = derivesFromMeter
		self.totalTimeAtSnapshot = totalTimeAtSnapshot
		self.snapshotMeterHours = snapshotMeterHours
		self.snapshotDate = snapshotDate
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

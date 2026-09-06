//
//  21 PilotLogbookEntry.swift
//  LandShip
//
//  A per-flight pilot logbook entry — distinct from TripLog2 (which tracks the aircraft's
//  usage/fuel/route) because a logbook entry is about the PILOT's currency and totals, not
//  the aircraft. vehicleId links to a Vehicle8 in the fleet when the flight was in a tracked
//  aircraft; aircraftIdentifier is a free-text fallback for aircraft outside the fleet (e.g. a
//  rental or club aircraft). AeroTrax only (see Vertical.enabledFeatures) — additive model, not
//  used by land or marine. Single-pilot app: no pilot-name field, matching the rest of the app's
//  one-owner-per-install assumption.
//

import Foundation
import SwiftData

@Model
class PilotLogbookEntry {
	var inactive: Bool = false
	var date: Date = Date()
	var vehicleId: String = ""
	var aircraftIdentifier: String = ""
	var departureLocation: String = ""
	var arrivalLocation: String = ""
	var totalTime: Float = 0
	var picTime: Float = 0
	var sicTime: Float = 0
	var dualReceived: Float = 0
	var soloTime: Float = 0
	var nightTime: Float = 0
	var actualInstrumentTime: Float = 0
	var simulatedInstrumentTime: Float = 0
	var crossCountryTime: Float = 0
	var dayLandings: Int = 0
	var nightLandings: Int = 0
	var remarks: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		date: Date = Date(),
		vehicleId: String = "",
		aircraftIdentifier: String = "",
		departureLocation: String = "",
		arrivalLocation: String = "",
		totalTime: Float = 0,
		picTime: Float = 0,
		sicTime: Float = 0,
		dualReceived: Float = 0,
		soloTime: Float = 0,
		nightTime: Float = 0,
		actualInstrumentTime: Float = 0,
		simulatedInstrumentTime: Float = 0,
		crossCountryTime: Float = 0,
		dayLandings: Int = 0,
		nightLandings: Int = 0,
		remarks: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.date = date
		self.vehicleId = vehicleId
		self.aircraftIdentifier = aircraftIdentifier
		self.departureLocation = departureLocation
		self.arrivalLocation = arrivalLocation
		self.totalTime = totalTime
		self.picTime = picTime
		self.sicTime = sicTime
		self.dualReceived = dualReceived
		self.soloTime = soloTime
		self.nightTime = nightTime
		self.actualInstrumentTime = actualInstrumentTime
		self.simulatedInstrumentTime = simulatedInstrumentTime
		self.crossCountryTime = crossCountryTime
		self.dayLandings = dayLandings
		self.nightLandings = nightLandings
		self.remarks = remarks
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

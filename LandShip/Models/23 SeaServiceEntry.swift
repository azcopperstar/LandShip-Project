//
//  23 SeaServiceEntry.swift
//  LandShip
//
//  A per-voyage sea service entry toward Merchant Mariner Credential (MMC) sea-time
//  requirements — distinct from TripLog2 (which tracks the vessel's usage/fuel/route) because
//  a sea service entry is about the MARINER's qualifying service, not the vessel. vehicleId
//  links to a Vehicle8 in the fleet when the voyage was on a tracked vessel; vesselIdentifier
//  is a free-text fallback for vessels outside the fleet. NauticalTrax only (see
//  Vertical.enabledFeatures) — additive model, not used by land or aviation. Single-mariner
//  app: no mariner-name field, matching the rest of the app's one-owner-per-install assumption.
//
//  USCG sea service is counted in days, not raw hours, and the exact day-counting rules
//  (e.g. the 8-hour/watch rule for near-coastal service) are nuanced enough that this leaves
//  daysOfService as a user-entered judgment call rather than trying to derive it from hours.
//

import Foundation
import SwiftData

@Model
class SeaServiceEntry {
	var inactive: Bool = false
	var date: Date = Date()
	var vehicleId: String = ""
	var vesselIdentifier: String = ""
	var watersType: String = ""
	var tonnage: Float = 0
	var capacityServed: String = ""
	var daysOfService: Float = 0
	var hoursUnderway: Float = 0
	var routeDescription: String = ""
	var remarks: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		date: Date = Date(),
		vehicleId: String = "",
		vesselIdentifier: String = "",
		watersType: String = "",
		tonnage: Float = 0,
		capacityServed: String = "",
		daysOfService: Float = 0,
		hoursUnderway: Float = 0,
		routeDescription: String = "",
		remarks: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.date = date
		self.vehicleId = vehicleId
		self.vesselIdentifier = vesselIdentifier
		self.watersType = watersType
		self.tonnage = tonnage
		self.capacityServed = capacityServed
		self.daysOfService = daysOfService
		self.hoursUnderway = hoursUnderway
		self.routeDescription = routeDescription
		self.remarks = remarks
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

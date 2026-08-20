//
//  9 Warranty.swift
//  LandShip
//
//  A warranty record linked to a vehicle by vehicleId.
//  Each vehicle may have multiple warranties (engine, powertrain, chassis, etc.)
//

import Foundation
import SwiftData

@Model
class VehicleWarranty {
	var vehicleId: String = ""
	var warrantyName: String = ""
	var warrantyProvider: String = ""
	var warrantyType: String = ""
	var warrantyStartDate: Date = Date()
	var warrantyLengthMonths: Int = 0
	var warrantyExpirationDate: Date = Date()
	var warrantyMileageLimit: Int = 0
	var warrantyDescription: String = ""
	var warrantyNotes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		warrantyName: String = "",
		warrantyProvider: String = "",
		warrantyType: String = "General",
		warrantyStartDate: Date = Date(),
		warrantyLengthMonths: Int = 0,
		warrantyExpirationDate: Date = Date(),
		warrantyMileageLimit: Int = 0,
		warrantyDescription: String = "",
		warrantyNotes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.warrantyName = warrantyName
		self.warrantyProvider = warrantyProvider
		self.warrantyType = warrantyType
		self.warrantyStartDate = warrantyStartDate
		self.warrantyLengthMonths = warrantyLengthMonths
		self.warrantyExpirationDate = warrantyExpirationDate
		self.warrantyMileageLimit = warrantyMileageLimit
		self.warrantyDescription = warrantyDescription
		self.warrantyNotes = warrantyNotes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

//
//  10 ScaleTicket.swift
//  LandShip
//
//  A CAT (commercial weigh station) scale ticket record linked to a vehicle by vehicleId.
//  Each vehicle may have multiple scale ticket records.
//

import Foundation
import SwiftData

@Model
class VehicleScaleTicket {
	var vehicleId: String = ""
	var date: Date = Date()
	var ticketNumber: String = ""
	var weighNumber: String = ""
	var location: String = ""
	var tractorLicensePlate: String = ""
	var trailerLicensePlate: String = ""
	var companyName: String = ""
	var tractorNumber: String = ""
	var trailerNumber: String = ""
	var cost: Int = 0
	var costDecimal: Double = 0.0
	var steerAxleWeight: Int = 0
	var driveAxleWeight: Int = 0
	var trailerAxleWeight: Int = 0
	@Attribute(.externalStorage)
	var ticketImage: Data?
	var ticketImageDescription: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	var grossWeight: Int { steerAxleWeight + driveAxleWeight + trailerAxleWeight }

	init(
		vehicleId: String = "",
		date: Date = Date(),
		ticketNumber: String = "",
		weighNumber: String = "",
		location: String = "",
		tractorLicensePlate: String = "",
		trailerLicensePlate: String = "",
		companyName: String = "",
		tractorNumber: String = "",
		trailerNumber: String = "",
		cost: Int = 0,
		costDecimal: Double = 0.0,
		steerAxleWeight: Int = 0,
		driveAxleWeight: Int = 0,
		trailerAxleWeight: Int = 0,
		ticketImage: Data? = nil,
		ticketImageDescription: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.date = date
		self.ticketNumber = ticketNumber
		self.weighNumber = weighNumber
		self.location = location
		self.tractorLicensePlate = tractorLicensePlate
		self.trailerLicensePlate = trailerLicensePlate
		self.companyName = companyName
		self.tractorNumber = tractorNumber
		self.trailerNumber = trailerNumber
		self.cost = cost
		self.costDecimal = costDecimal
		self.steerAxleWeight = steerAxleWeight
		self.driveAxleWeight = driveAxleWeight
		self.trailerAxleWeight = trailerAxleWeight
		self.ticketImage = ticketImage
		self.ticketImageDescription = ticketImageDescription
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

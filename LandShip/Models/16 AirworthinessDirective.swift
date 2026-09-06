//
//  16 AirworthinessDirective.swift
//  LandShip
//
//  An FAA (or equivalent) Airworthiness Directive record linked to a vehicle by
//  vehicleId. Each aircraft may have many ADs, one-time or recurring. AeroTrax only
//  (see Vertical.enabledFeatures) — additive model, not used by land or marine.
//

import Foundation
import SwiftData

@Model
class AirworthinessDirective {
	var inactive: Bool = false
	var vehicleId: String = ""
	var adNumber: String = ""
	var title: String = ""
	var applicability: String = ""
	var isRecurring: Bool = false
	var intervalType: String = ""
	var intervalValue: Float = 0
	var complianceDate: Date = Date()
	var complianceHours: Float = 0
	var methodOfCompliance: String = ""
	var signedOffBy: String = ""
	var nextDueDate: Date = Date()
	var nextDueHours: Float = 0
	var notes: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		adNumber: String = "",
		title: String = "",
		applicability: String = "",
		isRecurring: Bool = false,
		intervalType: String = "",
		intervalValue: Float = 0,
		complianceDate: Date = Date(),
		complianceHours: Float = 0,
		methodOfCompliance: String = "",
		signedOffBy: String = "",
		nextDueDate: Date = Date(),
		nextDueHours: Float = 0,
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.adNumber = adNumber
		self.title = title
		self.applicability = applicability
		self.isRecurring = isRecurring
		self.intervalType = intervalType
		self.intervalValue = intervalValue
		self.complianceDate = complianceDate
		self.complianceHours = complianceHours
		self.methodOfCompliance = methodOfCompliance
		self.signedOffBy = signedOffBy
		self.nextDueDate = nextDueDate
		self.nextDueHours = nextDueHours
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

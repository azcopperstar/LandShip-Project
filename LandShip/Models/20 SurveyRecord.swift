//
//  20 SurveyRecord.swift
//  LandShip
//
//  A marine survey record linked to a vessel by vehicleId — surveyor, survey type
//  (insurance, pre-purchase, damage, condition & value), findings, and next due.
//  NauticalTrax only (see Vertical.enabledFeatures) — additive model, not used by
//  land or aviation.
//

import Foundation
import SwiftData

@Model
class SurveyRecord {
	var inactive: Bool = false
	var vehicleId: String = ""
	var surveyDate: Date = Date()
	var surveyorName: String = ""
	var surveyType: String = ""
	var findings: String = ""
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
		surveyDate: Date = Date(),
		surveyorName: String = "",
		surveyType: String = "",
		findings: String = "",
		cost: Float = 0,
		nextDueDate: Date = Date(),
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.surveyDate = surveyDate
		self.surveyorName = surveyorName
		self.surveyType = surveyType
		self.findings = findings
		self.cost = cost
		self.nextDueDate = nextDueDate
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

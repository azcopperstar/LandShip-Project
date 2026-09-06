//
//  22 PilotCertification.swift
//  LandShip
//
//  Singleton profile of the pilot's certificate, ratings, and currency dates — not vehicleId
//  scoped, since a certificate belongs to the pilot, not any one aircraft. Mirrors Settings1's
//  fetch-or-create-one pattern (see SettingsEditorView.ensureSettings()). AeroTrax only (see
//  Vertical.enabledFeatures) — additive model, not used by land or marine. Deliberately not
//  TrialCapped, matching Settings1 — a singleton record has nothing meaningful to cap.
//

import Foundation
import SwiftData

@Model
class PilotCertification {
	var certificateType: String = ""
	var certificateNumber: String = ""
	var ratings: String = ""
	var medicalClass: String = ""
	var medicalExpirationDate: Date = Date()
	var lastFlightReviewDate: Date = Date()
	var lastInstrumentProficiencyCheckDate: Date = Date()
	var notes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		certificateType: String = "",
		certificateNumber: String = "",
		ratings: String = "",
		medicalClass: String = "",
		medicalExpirationDate: Date = Date(),
		lastFlightReviewDate: Date = Date(),
		lastInstrumentProficiencyCheckDate: Date = Date(),
		notes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.certificateType = certificateType
		self.certificateNumber = certificateNumber
		self.ratings = ratings
		self.medicalClass = medicalClass
		self.medicalExpirationDate = medicalExpirationDate
		self.lastFlightReviewDate = lastFlightReviewDate
		self.lastInstrumentProficiencyCheckDate = lastInstrumentProficiencyCheckDate
		self.notes = notes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}

	/// FAA flight review is due 24 calendar months after the month it was completed.
	var flightReviewDueDate: Date {
		Calendar.current.date(byAdding: .month, value: 24, to: lastFlightReviewDate) ?? lastFlightReviewDate
	}
}

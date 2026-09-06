//
//  24 MarinerCredential.swift
//  LandShip
//
//  Singleton profile of the mariner's credential, endorsements, and currency dates — not
//  vehicleId scoped, since a credential belongs to the mariner, not any one vessel. Mirrors
//  Settings1's fetch-or-create-one pattern (see SettingsEditorView.ensureSettings()).
//  NauticalTrax only (see Vertical.enabledFeatures) — additive model, not used by land or
//  aviation. Deliberately not TrialCapped, matching Settings1 — a singleton record has
//  nothing meaningful to cap.
//

import Foundation
import SwiftData

@Model
class MarinerCredential {
	var credentialType: String = ""
	var credentialNumber: String = ""
	var endorsements: String = ""
	var issueDate: Date = Date()
	var expirationDate: Date = Date()
	var medicalCertExpirationDate: Date = Date()
	var notes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		credentialType: String = "",
		credentialNumber: String = "",
		endorsements: String = "",
		issueDate: Date = Date(),
		expirationDate: Date = Date(),
		medicalCertExpirationDate: Date = Date(),
		notes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.credentialType = credentialType
		self.credentialNumber = credentialNumber
		self.endorsements = endorsements
		self.issueDate = issueDate
		self.expirationDate = expirationDate
		self.medicalCertExpirationDate = medicalCertExpirationDate
		self.notes = notes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

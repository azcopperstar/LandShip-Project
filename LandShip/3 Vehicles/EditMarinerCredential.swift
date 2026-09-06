//
//  EditMarinerCredential.swift
//  LandShip
//
//  Singleton form for the mariner's credential, endorsements, and currency dates.
//  Fetch-or-create pattern mirrors SettingsEditorView.ensureSettings() — there is always
//  exactly one MarinerCredential record. NauticalTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditMarinerCredential: View {
	@Environment(\.modelContext) private var modelContext

	@Query private var fetched: [MarinerCredential]
	@State private var record: MarinerCredential?

	@State private var credentialType: String = ""
	@State private var credentialNumber: String = ""
	@State private var endorsements: String = ""
	@State private var issueDate: Date = Date()
	@State private var expirationDate: Date = Date()
	@State private var medicalCertExpirationDate: Date = Date()
	@State private var notes: String = ""

	var body: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "CREDENTIAL")
					HStack { LabelDataTextview(label: "Credential Type", data: $credentialType) }
					HStack { LabelDataTextview(label: "Credential Number", data: $credentialNumber) }
					HStack { LabelDataTextview(label: "Endorsements", data: $endorsements) }
					HStack { LabelDataPicker_Date(label: "Issue Date", data: $issueDate) }
					HStack { LabelDataPicker_Date(label: "Expiration Date", data: $expirationDate) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "MEDICAL")
					HStack { LabelDataPicker_Date(label: "Medical Certificate Expiration", data: $medicalCertExpirationDate) }
				}
			}

			CardView {
				TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
			}
		}
		.navigationTitle("Credential & Currency")
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Save") { save() }
			}
		}
		.onAppear { ensureRecord() }
	}

	private func ensureRecord() {
		if let existing = fetched.first {
			record = existing
			credentialType = existing.credentialType
			credentialNumber = existing.credentialNumber
			endorsements = existing.endorsements
			issueDate = existing.issueDate
			expirationDate = existing.expirationDate
			medicalCertExpirationDate = existing.medicalCertExpirationDate
			notes = existing.notes
			return
		}
		let newRecord = MarinerCredential()
		modelContext.insert(newRecord)
		do { try modelContext.save() } catch { print("Failed to seed MarinerCredential: \(error)") }
		record = newRecord
	}

	private func save() {
		guard let record else { return }
		record.credentialType = credentialType
		record.credentialNumber = credentialNumber
		record.endorsements = endorsements
		record.issueDate = issueDate
		record.expirationDate = expirationDate
		record.medicalCertExpirationDate = medicalCertExpirationDate
		record.notes = notes
		record.updatedAt = Date()
		do {
			try modelContext.save()
		} catch {
			print("Failed to save MarinerCredential: \(error.localizedDescription)")
		}
	}
}

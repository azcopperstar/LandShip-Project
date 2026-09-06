//
//  EditPilotCertification.swift
//  LandShip
//
//  Singleton form for the pilot's certificate, ratings, and currency dates. Fetch-or-create
//  pattern mirrors SettingsEditorView.ensureSettings() — there is always exactly one
//  PilotCertification record. AeroTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditPilotCertification: View {
	@Environment(\.modelContext) private var modelContext

	@Query private var fetched: [PilotCertification]
	@State private var record: PilotCertification?

	@State private var certificateType: String = ""
	@State private var certificateNumber: String = ""
	@State private var ratings: String = ""
	@State private var medicalClass: String = ""
	@State private var medicalExpirationDate: Date = Date()
	@State private var lastFlightReviewDate: Date = Date()
	@State private var lastInstrumentProficiencyCheckDate: Date = Date()
	@State private var notes: String = ""

	let functions = Functions()

	var body: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "CERTIFICATE")
					HStack { LabelDataTextview(label: "Certificate Type", data: $certificateType) }
					HStack { LabelDataTextview(label: "Certificate Number", data: $certificateNumber) }
					HStack { LabelDataTextview(label: "Ratings", data: $ratings) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "MEDICAL")
					HStack { LabelDataTextview(label: "Medical Class", data: $medicalClass) }
					HStack { LabelDataPicker_Date(label: "Medical Expiration", data: $medicalExpirationDate) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "CURRENCY")
					HStack { LabelDataPicker_Date(label: "Last Flight Review", data: $lastFlightReviewDate) }
					HStack {
						LabelDataText(label: "Flight Review Due", data: functions.formatDate_DDMMMyy(date: flightReviewDueDate))
					}
					HStack { LabelDataPicker_Date(label: "Last Instrument Proficiency Check", data: $lastInstrumentProficiencyCheckDate) }
				}
			}

			CardView {
				TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
			}
		}
		.navigationTitle("Certificate & Currency")
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Save") { save() }
			}
		}
		.onAppear { ensureRecord() }
	}

	private var flightReviewDueDate: Date {
		Calendar.current.date(byAdding: .month, value: 24, to: lastFlightReviewDate) ?? lastFlightReviewDate
	}

	private func ensureRecord() {
		if let existing = fetched.first {
			record = existing
			certificateType = existing.certificateType
			certificateNumber = existing.certificateNumber
			ratings = existing.ratings
			medicalClass = existing.medicalClass
			medicalExpirationDate = existing.medicalExpirationDate
			lastFlightReviewDate = existing.lastFlightReviewDate
			lastInstrumentProficiencyCheckDate = existing.lastInstrumentProficiencyCheckDate
			notes = existing.notes
			return
		}
		let newRecord = PilotCertification()
		modelContext.insert(newRecord)
		do { try modelContext.save() } catch { print("Failed to seed PilotCertification: \(error)") }
		record = newRecord
	}

	private func save() {
		guard let record else { return }
		record.certificateType = certificateType
		record.certificateNumber = certificateNumber
		record.ratings = ratings
		record.medicalClass = medicalClass
		record.medicalExpirationDate = medicalExpirationDate
		record.lastFlightReviewDate = lastFlightReviewDate
		record.lastInstrumentProficiencyCheckDate = lastInstrumentProficiencyCheckDate
		record.notes = notes
		record.updatedAt = Date()
		do {
			try modelContext.save()
		} catch {
			print("Failed to save PilotCertification: \(error.localizedDescription)")
		}
	}
}

//
//  EditSurveyRecord.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single SurveyRecord.
//  Presented from EditVehicle whenever the user taps a survey row or the Add button.
//  NauticalTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditSurveyRecord: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let record: SurveyRecord?

	@State private var surveyDate: Date = Date()
	@State private var surveyorName: String = ""
	@State private var surveyType: String = "Insurance"
	@State private var findings: String = ""
	@State private var cost: Float = 0
	@State private var nextDueDate: Date = Date()
	@State private var notes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, record: SurveyRecord? = nil) {
		self.vehicleId = vehicleId
		self.record = record
		self._surveyDate = State(initialValue: record?.surveyDate ?? Date())
		self._surveyorName = State(initialValue: record?.surveyorName ?? "")
		self._surveyType = State(initialValue: record?.surveyType.isEmpty == false ? record!.surveyType : "Insurance")
		self._findings = State(initialValue: record?.findings ?? "")
		self._cost = State(initialValue: record?.cost ?? 0)
		self._nextDueDate = State(initialValue: record?.nextDueDate ?? Date())
		self._notes = State(initialValue: record?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "SURVEY DETAILS")
						HStack { LabelDataPicker_Date(label: "Survey Date", data: $surveyDate) }
						HStack { LabelDataTextview(label: "Surveyor", data: $surveyorName) }
						HStack {
							Text("Survey Type")
								.textLabelModified()
							Picker("", selection: $surveyType) {
								Text("Insurance").tag("Insurance")
								Text("Pre-Purchase").tag("Pre-Purchase")
								Text("Damage").tag("Damage")
								Text("Condition & Value").tag("Condition & Value")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FINDINGS & FOLLOW-UP")
						HStack { LabelDataTextview_Numberpad_Float(label: "Cost", data: $cost) }
						HStack { LabelDataPicker_Date(label: "Next Due Date", data: $nextDueDate) }
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "FINDINGS", prompt: "Enter findings...", data: $findings)
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if record != nil {
					CardView {
						VStack {
							Button("Delete Survey Record", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this survey record?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let r = record {
										modelContext.delete(r)
										do {
											try modelContext.save()
											dismiss()
										} catch {
											saveErrorMessage = error.localizedDescription
											showSaveError = true
										}
									} else {
										dismiss()
									}
								}
							} message: {
								Text("This action cannot be undone.")
							}
						}
					}
				}
			}
			.navigationTitle(record == nil ? "Add Survey Record" : "Edit Survey Record")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveRecord()
					}
					.disabled(surveyorName.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveRecord() {
		if let existing = record {
			existing.surveyDate = surveyDate
			existing.surveyorName = surveyorName
			existing.surveyType = surveyType
			existing.findings = findings
			existing.cost = cost
			existing.nextDueDate = nextDueDate
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let newRecord = SurveyRecord(
				vehicleId: vehicleId,
				surveyDate: surveyDate,
				surveyorName: surveyorName,
				surveyType: surveyType,
				findings: findings,
				cost: cost,
				nextDueDate: nextDueDate,
				notes: notes
			)
			modelContext.insert(newRecord)
		}
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

//
//  EditAirworthinessDirective.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single AirworthinessDirective.
//  Presented from EditVehicle whenever the user taps an AD row or the Add button.
//  AeroTrax only — see Vertical.enabledFeatures.
//

import SwiftUI
import SwiftData

struct EditAirworthinessDirective: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let directive: AirworthinessDirective?

	@State private var adNumber: String = ""
	@State private var title: String = ""
	@State private var applicability: String = ""
	@State private var isRecurring: Bool = false
	@State private var intervalType: String = "One-Time"
	@State private var intervalValue: Float = 0
	@State private var complianceDate: Date = Date()
	@State private var complianceHours: Float = 0
	@State private var methodOfCompliance: String = ""
	@State private var signedOffBy: String = ""
	@State private var nextDueDate: Date = Date()
	@State private var nextDueHours: Float = 0
	@State private var notes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(vehicleId: String, directive: AirworthinessDirective? = nil) {
		self.vehicleId = vehicleId
		self.directive = directive
		self._adNumber = State(initialValue: directive?.adNumber ?? "")
		self._title = State(initialValue: directive?.title ?? "")
		self._applicability = State(initialValue: directive?.applicability ?? "")
		self._isRecurring = State(initialValue: directive?.isRecurring ?? false)
		self._intervalType = State(initialValue: directive?.intervalType.isEmpty == false ? directive!.intervalType : "One-Time")
		self._intervalValue = State(initialValue: directive?.intervalValue ?? 0)
		self._complianceDate = State(initialValue: directive?.complianceDate ?? Date())
		self._complianceHours = State(initialValue: directive?.complianceHours ?? 0)
		self._methodOfCompliance = State(initialValue: directive?.methodOfCompliance ?? "")
		self._signedOffBy = State(initialValue: directive?.signedOffBy ?? "")
		self._nextDueDate = State(initialValue: directive?.nextDueDate ?? Date())
		self._nextDueHours = State(initialValue: directive?.nextDueHours ?? 0)
		self._notes = State(initialValue: directive?.notes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "AD DETAILS")
						HStack { LabelDataTextview(label: "AD Number", data: $adNumber) }
						HStack { LabelDataTextview(label: "Title", data: $title) }
						HStack { LabelDataTextview(label: "Applicability", data: $applicability) }
					}
				}

				CardView {
					VStack {
						SectionText(label: "COMPLIANCE SCHEDULE")
						HStack { LabelDataToggle(label: "Recurring", data: $isRecurring) }
						HStack {
							Text("Interval Type")
								.textLabelModified()
							Picker("", selection: $intervalType) {
								Text("One-Time").tag("One-Time")
								Text("Calendar Months").tag("Calendar Months")
								Text("Hours").tag("Hours")
								Text("Cycles").tag("Cycles")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if isRecurring {
							HStack { LabelDataTextview_Numberpad_Float(label: "Interval Value", data: $intervalValue) }
						}
						HStack { LabelDataPicker_Date(label: "Compliance Date", data: $complianceDate) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Compliance Hours", data: $complianceHours) }
						HStack { LabelDataTextview(label: "Method of Compliance", data: $methodOfCompliance) }
						HStack { LabelDataTextview(label: "Signed Off By", data: $signedOffBy) }
						HStack { LabelDataPicker_Date(label: "Next Due Date", data: $nextDueDate) }
						HStack { LabelDataTextview_Numberpad_Float(label: "Next Due Hours", data: $nextDueHours) }
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $notes)
				}

				if directive != nil {
					CardView {
						VStack {
							Button("Delete AD", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this AD?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let d = directive {
										modelContext.delete(d)
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
			.navigationTitle(directive == nil ? "Add Airworthiness Directive" : "Edit Airworthiness Directive")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveDirective()
					}
					.disabled(adNumber.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveDirective() {
		if let existing = directive {
			existing.adNumber = adNumber
			existing.title = title
			existing.applicability = applicability
			existing.isRecurring = isRecurring
			existing.intervalType = intervalType
			existing.intervalValue = intervalValue
			existing.complianceDate = complianceDate
			existing.complianceHours = complianceHours
			existing.methodOfCompliance = methodOfCompliance
			existing.signedOffBy = signedOffBy
			existing.nextDueDate = nextDueDate
			existing.nextDueHours = nextDueHours
			existing.notes = notes
			existing.updatedAt = Date()
		} else {
			let newDirective = AirworthinessDirective(
				vehicleId: vehicleId,
				adNumber: adNumber,
				title: title,
				applicability: applicability,
				isRecurring: isRecurring,
				intervalType: intervalType,
				intervalValue: intervalValue,
				complianceDate: complianceDate,
				complianceHours: complianceHours,
				methodOfCompliance: methodOfCompliance,
				signedOffBy: signedOffBy,
				nextDueDate: nextDueDate,
				nextDueHours: nextDueHours,
				notes: notes
			)
			modelContext.insert(newDirective)
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

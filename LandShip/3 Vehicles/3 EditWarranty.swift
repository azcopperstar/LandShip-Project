//
//  3 EditWarranty.swift
//  LandShip
//
//  Sheet-based form for adding or editing a single VehicleWarranty.
//  Presented from EditVehicle whenever the user taps a warranty row or the Add button.
//

import SwiftUI
import SwiftData

struct EditWarranty: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let vehicleId: String
	let warranty: VehicleWarranty?

	@State private var warrantyName: String = ""
	@State private var warrantyProvider: String = ""
	@State private var warrantyType: String = "General"
	@State private var warrantyStartDate: Date = Date()
	@State private var warrantyLengthMonths: Int = 0
	@State private var warrantyExpirationDate: Date = Date()
	@State private var warrantyMileageLimit: Int = 0
	@State private var warrantyDescription: String = ""
	@State private var warrantyNotes: String = ""

	@State private var isPresentingDeleteConfirm: Bool = false

	init(vehicleId: String, warranty: VehicleWarranty? = nil) {
		self.vehicleId = vehicleId
		self.warranty = warranty
		self._warrantyName = State(initialValue: warranty?.warrantyName ?? "")
		self._warrantyProvider = State(initialValue: warranty?.warrantyProvider ?? "")
		self._warrantyType = State(initialValue: warranty?.warrantyType ?? "General")
		self._warrantyStartDate = State(initialValue: warranty?.warrantyStartDate ?? Date())
		self._warrantyLengthMonths = State(initialValue: warranty?.warrantyLengthMonths ?? 0)
		self._warrantyExpirationDate = State(initialValue: warranty?.warrantyExpirationDate ?? Date())
		self._warrantyMileageLimit = State(initialValue: warranty?.warrantyMileageLimit ?? 0)
		self._warrantyDescription = State(initialValue: warranty?.warrantyDescription ?? "")
		self._warrantyNotes = State(initialValue: warranty?.warrantyNotes ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "WARRANTY DETAILS")
						HStack { LabelDataTextview(label: "Warranty Name", data: $warrantyName) }
						HStack { LabelDataTextview(label: "Provider", data: $warrantyProvider) }
						HStack {
							Text("Component Type")
								.textLabelModified()
							Picker("", selection: $warrantyType) {
								Text("General").tag("General")
								Text("Engine").tag("Engine")
								Text("Transmission").tag("Transmission")
								Text("Powertrain").tag("Powertrain")
								Text("Chassis").tag("Chassis")
								Text("Electrical").tag("Electrical")
								Text("Body/Paint").tag("Body/Paint")
								Text("Interior").tag("Interior")
								Text("Tires").tag("Tires")
								Text("Battery").tag("Battery")
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "COVERAGE")
						HStack { LabelDataPicker_Date(label: "Start Date", data: $warrantyStartDate) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Length (months)", data: $warrantyLengthMonths) }
						HStack { LabelDataPicker_Date(label: "Expiration Date", data: $warrantyExpirationDate) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Mileage Limit", data: $warrantyMileageLimit) }
					}
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "DESCRIPTION", prompt: "Enter description...", data: $warrantyDescription)
				}

				CardView {
					TextFieldNote_FullWidth_3lines(sectionText: "NOTES", prompt: "Enter notes...", data: $warrantyNotes)
				}

				if warranty != nil {
					CardView {
						VStack {
							Button("Delete Warranty", role: .destructive) {
								isPresentingDeleteConfirm = true
							}
							.buttonStyle(GrowingButton(buttonColor: Color.red))
							.confirmationDialog("Delete this warranty?", isPresented: $isPresentingDeleteConfirm) {
								Button("Delete", role: .destructive) {
									if let w = warranty {
										modelContext.delete(w)
										try? modelContext.save()
									}
									dismiss()
								}
							} message: {
								Text("This action cannot be undone.")
							}
						}
					}
				}
			}
			.navigationTitle(warranty == nil ? "Add Warranty" : "Edit Warranty")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveWarranty()
						dismiss()
					}
					.disabled(warrantyName.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.onChange(of: warrantyStartDate) { _, _ in recalculateExpiration() }
			.onChange(of: warrantyLengthMonths) { _, _ in recalculateExpiration() }
		}
	}

	private func recalculateExpiration() {
		guard warrantyLengthMonths > 0 else { return }
		if let date = Calendar.current.date(byAdding: .month, value: warrantyLengthMonths, to: warrantyStartDate) {
			warrantyExpirationDate = date
		}
	}

	private func saveWarranty() {
		if let existing = warranty {
			existing.warrantyName = warrantyName
			existing.warrantyProvider = warrantyProvider
			existing.warrantyType = warrantyType
			existing.warrantyStartDate = warrantyStartDate
			existing.warrantyLengthMonths = warrantyLengthMonths
			existing.warrantyExpirationDate = warrantyExpirationDate
			existing.warrantyMileageLimit = warrantyMileageLimit
			existing.warrantyDescription = warrantyDescription
			existing.warrantyNotes = warrantyNotes
			existing.updatedAt = Date()
		} else {
			let newWarranty = VehicleWarranty(
				vehicleId: vehicleId,
				warrantyName: warrantyName,
				warrantyProvider: warrantyProvider,
				warrantyType: warrantyType,
				warrantyStartDate: warrantyStartDate,
				warrantyLengthMonths: warrantyLengthMonths,
				warrantyExpirationDate: warrantyExpirationDate,
				warrantyMileageLimit: warrantyMileageLimit,
				warrantyDescription: warrantyDescription,
				warrantyNotes: warrantyNotes
			)
			modelContext.insert(newWarranty)
		}
		try? modelContext.save()
	}
}

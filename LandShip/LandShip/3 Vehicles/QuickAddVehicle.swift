//
//  QuickAddVehicle.swift
//  LandShip
//
//  Minimal sheet for creating a new Vehicle8 with just its identifying fields, from
//  contexts (like the Flight Log's aircraft picker) that need to add a vehicle without
//  leaving the current form. Full editing still happens in EditVehicle afterward.
//

import SwiftUI
import SwiftData

struct QuickAddVehicle: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss
	@Environment(\.entitlements) private var entitlements

	/// Called with the newly created, already-saved record so the caller can select it.
	let onCreate: (Vehicle8) -> Void

	@State private var name: String = ""
	@State private var year: Int = Calendar.current.component(.year, from: Date())
	@State private var manufacturer: String = ""
	@State private var model: String = ""
	@State private var registration: String = ""

	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "\(Vertical.current.assetSingular.uppercased()) DETAILS")
						HStack { LabelDataTextview(label: "Name", data: $name) }
						HStack { LabelDataTextview_Numberpad_Int(label: "Year", data: $year) }
						HStack { LabelDataTextview(label: "Manufacturer", data: $manufacturer) }
						HStack { LabelDataTextview(label: "Model", data: $model) }
						HStack { LabelDataTextview(label: Vertical.current.registrationLabel, data: $registration) }
					}
				}
			}
			.navigationTitle("Add \(Vertical.current.assetSingular)")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						saveNewVehicle()
					}
					.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
				}
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func saveNewVehicle() {
		guard entitlements.requestCreate(Vehicle8.self, in: modelContext) else { return }
		let newVehicle = Vehicle8(
			name: UUID().uuidString,
			displayName: name,
			manufacturer: manufacturer,
			model: model,
			year: year,
			vin: registration
		)
		modelContext.insert(newVehicle)
		do {
			try modelContext.save()
			onCreate(newVehicle)
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

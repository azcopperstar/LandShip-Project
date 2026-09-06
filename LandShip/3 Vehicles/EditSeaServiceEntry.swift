//
//  EditSeaServiceEntry.swift
//  LandShip
//
//  Form for adding or editing a single SeaServiceEntry. NauticalTrax only — see
//  Vertical.enabledFeatures. Vessel selection is optional and falls back to a free-text
//  identifier, since mariners commonly log service on vessels outside the tracked fleet.
//

import SwiftUI
import SwiftData

struct EditSeaServiceEntry: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let entry: SeaServiceEntry

	@State private var selectedVehicle: Vehicle8?
	@State private var date: Date
	@State private var vesselIdentifier: String
	@State private var watersType: String
	@State private var tonnage: Float
	@State private var capacityServed: String
	@State private var daysOfService: Float
	@State private var hoursUnderway: Float
	@State private var routeDescription: String
	@State private var remarks: String

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(entry: SeaServiceEntry) {
		self.entry = entry
		self._date = State(initialValue: entry.date)
		self._vesselIdentifier = State(initialValue: entry.vesselIdentifier)
		self._watersType = State(initialValue: entry.watersType)
		self._tonnage = State(initialValue: entry.tonnage)
		self._capacityServed = State(initialValue: entry.capacityServed)
		self._daysOfService = State(initialValue: entry.daysOfService)
		self._hoursUnderway = State(initialValue: entry.hoursUnderway)
		self._routeDescription = State(initialValue: entry.routeDescription)
		self._remarks = State(initialValue: entry.remarks)
	}

	var body: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "VOYAGE DETAILS")
					HStack { LabelDataPicker_Date(label: "Date", data: $date) }
					LabeledContent {
						ModelPicker(
							selection: $selectedVehicle,
							title: "",
							includeEmptyChoice: true,
							emptyChoiceLabel: "Not in fleet",
							autoSelectFirst: false,
							sort: [SortDescriptor(\Vehicle8.displayName, order: .forward)],
							labelProvider: { $0.displayName },
							thumbnailData: { $0.image1 }
						)
						.onChange(of: selectedVehicle) { _, newVehicle in
							if let newVehicle {
								vesselIdentifier = newVehicle.displayName.isEmpty ? newVehicle.name : newVehicle.displayName
							}
						}
						.fixedSize(horizontal: true, vertical: true)
					} label: {
						Text("Vessel")
							.textLabelModified()
					}
					if selectedVehicle == nil {
						HStack { LabelDataTextview(label: "Vessel (not in fleet)", data: $vesselIdentifier) }
					}
					HStack { LabelDataTextview(label: "Route", data: $routeDescription) }
					HStack { LabelDataTextview(label: "Waters (Ocean/Near Coastal/Inland/Great Lakes)", data: $watersType) }
					HStack { LabelDataTextview(label: "Capacity Served (Master/Mate/OICNW/etc.)", data: $capacityServed) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "SERVICE")
					HStack { LabelDataTextview_Numberpad_Float(label: "Tonnage (Gross Tons)", data: $tonnage) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Days of Service", data: $daysOfService) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Hours Underway", data: $hoursUnderway) }
				}
			}

			CardView {
				TextFieldNote_FullWidth_3lines(sectionText: "REMARKS", prompt: "Enter remarks...", data: $remarks)
			}

			CardView {
				VStack {
					Button("Delete Entry", role: .destructive) {
						isPresentingDeleteConfirm = true
					}
					.buttonStyle(GrowingButton(buttonColor: Color.red))
					.confirmationDialog("Delete this sea service entry?", isPresented: $isPresentingDeleteConfirm) {
						Button("Delete", role: .destructive) {
							modelContext.delete(entry)
							do {
								try modelContext.save()
								dismiss()
							} catch {
								saveErrorMessage = error.localizedDescription
								showSaveError = true
							}
						}
					} message: {
						Text("This action cannot be undone.")
					}
				}
			}
		}
		.navigationTitle("Sea Service Entry")
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Save") {
					saveEntry()
				}
			}
		}
		.onAppear {
			if !entry.vehicleId.isEmpty {
				let vehicleId = entry.vehicleId
				let fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == vehicleId })
				selectedVehicle = try? modelContext.fetch(fd).first
			}
		}
		.alert("Couldn't Save", isPresented: $showSaveError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(saveErrorMessage ?? "")
		}
	}

	private func saveEntry() {
		entry.date = date
		entry.vehicleId = selectedVehicle?.name ?? ""
		entry.vesselIdentifier = vesselIdentifier
		entry.watersType = watersType
		entry.tonnage = tonnage
		entry.capacityServed = capacityServed
		entry.daysOfService = daysOfService
		entry.hoursUnderway = hoursUnderway
		entry.routeDescription = routeDescription
		entry.remarks = remarks
		entry.updatedAt = Date()
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

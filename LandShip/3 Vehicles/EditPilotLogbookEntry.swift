//
//  EditPilotLogbookEntry.swift
//  LandShip
//
//  Form for adding or editing a single PilotLogbookEntry. AeroTrax only — see
//  Vertical.enabledFeatures. Aircraft selection is optional and falls back to a free-text
//  identifier, since pilots commonly log flights in aircraft outside the tracked fleet
//  (rentals, club aircraft).
//

import SwiftUI
import SwiftData

struct EditPilotLogbookEntry: View {
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	let entry: PilotLogbookEntry

	@State private var selectedVehicle: Vehicle8?
	@State private var date: Date
	@State private var aircraftIdentifier: String
	@State private var departureLocation: String
	@State private var arrivalLocation: String
	@State private var totalTime: Float
	@State private var picTime: Float
	@State private var sicTime: Float
	@State private var dualReceived: Float
	@State private var soloTime: Float
	@State private var nightTime: Float
	@State private var actualInstrumentTime: Float
	@State private var simulatedInstrumentTime: Float
	@State private var crossCountryTime: Float
	@State private var dayLandings: Int
	@State private var nightLandings: Int
	@State private var remarks: String

	@State private var isPresentingDeleteConfirm: Bool = false
	@State private var showSaveError: Bool = false
	@State private var saveErrorMessage: String?

	init(entry: PilotLogbookEntry) {
		self.entry = entry
		self._date = State(initialValue: entry.date)
		self._aircraftIdentifier = State(initialValue: entry.aircraftIdentifier)
		self._departureLocation = State(initialValue: entry.departureLocation)
		self._arrivalLocation = State(initialValue: entry.arrivalLocation)
		self._totalTime = State(initialValue: entry.totalTime)
		self._picTime = State(initialValue: entry.picTime)
		self._sicTime = State(initialValue: entry.sicTime)
		self._dualReceived = State(initialValue: entry.dualReceived)
		self._soloTime = State(initialValue: entry.soloTime)
		self._nightTime = State(initialValue: entry.nightTime)
		self._actualInstrumentTime = State(initialValue: entry.actualInstrumentTime)
		self._simulatedInstrumentTime = State(initialValue: entry.simulatedInstrumentTime)
		self._crossCountryTime = State(initialValue: entry.crossCountryTime)
		self._dayLandings = State(initialValue: entry.dayLandings)
		self._nightLandings = State(initialValue: entry.nightLandings)
		self._remarks = State(initialValue: entry.remarks)
	}

	var body: some View {
		ScrollView {
			CardView {
				VStack {
					SectionText(label: "FLIGHT DETAILS")
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
								aircraftIdentifier = newVehicle.displayName.isEmpty ? newVehicle.name : newVehicle.displayName
							}
						}
						.fixedSize(horizontal: true, vertical: true)
					} label: {
						Text("Aircraft")
							.textLabelModified()
					}
					if selectedVehicle == nil {
						HStack { LabelDataTextview(label: "Aircraft (not in fleet)", data: $aircraftIdentifier) }
					}
					HStack { LabelDataTextview(label: "Departure", data: $departureLocation) }
					HStack { LabelDataTextview(label: "Arrival", data: $arrivalLocation) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "TIME")
					HStack { LabelDataTextview_Numberpad_Float(label: "Total Time", data: $totalTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "PIC", data: $picTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "SIC", data: $sicTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Dual Received", data: $dualReceived) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Solo", data: $soloTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Night", data: $nightTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Actual Instrument", data: $actualInstrumentTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Simulated Instrument", data: $simulatedInstrumentTime) }
					HStack { LabelDataTextview_Numberpad_Float(label: "Cross-Country", data: $crossCountryTime) }
				}
			}

			CardView {
				VStack {
					SectionText(label: "LANDINGS")
					HStack { LabelDataTextview_Numberpad_Int(label: "Day Landings", data: $dayLandings) }
					HStack { LabelDataTextview_Numberpad_Int(label: "Night Landings", data: $nightLandings) }
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
					.confirmationDialog("Delete this logbook entry?", isPresented: $isPresentingDeleteConfirm) {
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
		.navigationTitle("Logbook Entry")
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
		entry.aircraftIdentifier = aircraftIdentifier
		entry.departureLocation = departureLocation
		entry.arrivalLocation = arrivalLocation
		entry.totalTime = totalTime
		entry.picTime = picTime
		entry.sicTime = sicTime
		entry.dualReceived = dualReceived
		entry.soloTime = soloTime
		entry.nightTime = nightTime
		entry.actualInstrumentTime = actualInstrumentTime
		entry.simulatedInstrumentTime = simulatedInstrumentTime
		entry.crossCountryTime = crossCountryTime
		entry.dayLandings = dayLandings
		entry.nightLandings = nightLandings
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

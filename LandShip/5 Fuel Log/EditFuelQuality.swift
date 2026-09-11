//
//  EditFuelQuality.swift
//  LandShip
//
//  Sheet editor for FuelLog1's fuel-quality data: sump/water check, additives (FSII,
//  biocide, static dissipator), and SAF blend/certificate tracking for emissions
//  reporting. AeroTrax only (Vertical.enabledFeatures.fuelOperations).
//

import SwiftUI
import SwiftData

struct EditFuelQuality: View {
	let log: FuelLog1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var sumpCheckPerformed: Bool
	@State private var sumpCheckResultRaw: String
	@State private var fuelSampleRetained: Bool
	@State private var qualityDocumentReference: String

	@State private var additiveFSII: Bool
	@State private var additiveFSIIConcentration: Float
	@State private var additiveBiocide: Bool
	@State private var additiveStaticDissipator: Bool
	@State private var additiveNotes: String

	@State private var safBlendPercent: Float
	@State private var safCertificateReference: String

	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(log: FuelLog1) {
		self.log = log
		self._sumpCheckPerformed = State(initialValue: log.sumpCheckPerformed)
		self._sumpCheckResultRaw = State(initialValue: log.sumpCheckResultRaw)
		self._fuelSampleRetained = State(initialValue: log.fuelSampleRetained)
		self._qualityDocumentReference = State(initialValue: log.qualityDocumentReference)
		self._additiveFSII = State(initialValue: log.additiveFSII)
		self._additiveFSIIConcentration = State(initialValue: log.additiveFSIIConcentration)
		self._additiveBiocide = State(initialValue: log.additiveBiocide)
		self._additiveStaticDissipator = State(initialValue: log.additiveStaticDissipator)
		self._additiveNotes = State(initialValue: log.additiveNotes)
		self._safBlendPercent = State(initialValue: log.safBlendPercent)
		self._safCertificateReference = State(initialValue: log.safCertificateReference)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "SUMP & WATER CHECK")
						HStack{LabelDataToggle(label: "Sump Check Performed", data: $sumpCheckPerformed)}
						if sumpCheckPerformed {
							HStack {
								Text("Result").textLabelModified()
								Picker("", selection: $sumpCheckResultRaw) {
									Text("—").tag("")
									ForEach(FuelSumpResult.allCases) { result in
										Text(result.rawValue).tag(result.rawValue)
									}
								}
								.pickerStyle(.automatic)
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
						}
						HStack{LabelDataToggle(label: "Fuel Sample Retained", data: $fuelSampleRetained)}
						HStack{LabelDataTextview(label: "Quality Document Reference", data: $qualityDocumentReference)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "ADDITIVES")
						Text("Some airframes require FSII and some prohibit it — record whether it was added, not just that it's normally used.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack{LabelDataToggle(label: "FSII / Prist Added", data: $additiveFSII)}
						if additiveFSII {
							HStack{LabelDataTextview_Numberpad_Float(label: "FSII Concentration (%)", data: $additiveFSIIConcentration)}
						}
						HStack{LabelDataToggle(label: "Biocide Added", data: $additiveBiocide)}
						HStack{LabelDataToggle(label: "Static Dissipator Added", data: $additiveStaticDissipator)}
						HStack{LabelDataTextview(label: "Additive Notes", data: $additiveNotes)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "SAF (SUSTAINABLE AVIATION FUEL)")
						HStack{LabelDataTextview_Numberpad_Float(label: "SAF Blend (%)", data: $safBlendPercent)}
						if safBlendPercent > 0 {
							HStack{LabelDataTextview(label: "Certificate / Batch Reference", data: $safCertificateReference)}
							Text("A book-and-claim certificate needs a paper trail for emissions reporting — attach the document in Attachments on the main Fuel Log screen.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}
			}
			.navigationTitle("Fuel Quality")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
			}
			.alert("Couldn't Save", isPresented: $showSaveError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(saveErrorMessage ?? "")
			}
		}
	}

	private func save() {
		log.sumpCheckPerformed = sumpCheckPerformed
		log.sumpCheckResultRaw = sumpCheckResultRaw
		log.fuelSampleRetained = fuelSampleRetained
		log.qualityDocumentReference = qualityDocumentReference
		log.additiveFSII = additiveFSII
		log.additiveFSIIConcentration = additiveFSIIConcentration
		log.additiveBiocide = additiveBiocide
		log.additiveStaticDissipator = additiveStaticDissipator
		log.additiveNotes = additiveNotes
		log.safBlendPercent = safBlendPercent
		log.safCertificateReference = safCertificateReference
		log.updatedAt = Date()
		do {
			try modelContext.save()
			dismiss()
		} catch {
			saveErrorMessage = error.localizedDescription
			showSaveError = true
		}
	}
}

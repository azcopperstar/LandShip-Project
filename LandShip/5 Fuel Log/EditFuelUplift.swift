//
//  EditFuelUplift.swift
//  LandShip
//
//  Sheet editor for FuelLog1's canonical uplift quantity/density, fill type, fuel-on-board,
//  and capture-time UTC offset. Unconditional across all verticals — see FuelMath.swift for
//  the "never assume 6.7" density fallback and the full-to-full economy gate this feeds.
//

import SwiftUI
import SwiftData

struct EditFuelUplift: View {
	let log: FuelLog1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var upliftQuantity: Float
	@State private var upliftUnitRaw: String
	@State private var density: Float
	@State private var densityUnitRaw: String
	@State private var densitySourceRaw: String
	@State private var fillTypeRaw: String
	@State private var fobBeforeKnown: Bool
	@State private var fobBefore: Float
	@State private var fobAfterKnown: Bool
	@State private var fobAfter: Float
	@State private var fobUnitRaw: String
	@State private var utcOffsetKnown: Bool
	@State private var utcOffsetHours: Float
	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(log: FuelLog1) {
		self.log = log
		self._upliftQuantity = State(initialValue: log.upliftQuantity)
		self._upliftUnitRaw = State(initialValue: log.upliftUnitRaw)
		self._density = State(initialValue: log.density)
		self._densityUnitRaw = State(initialValue: log.densityUnitRaw)
		self._densitySourceRaw = State(initialValue: log.densitySourceRaw)
		self._fillTypeRaw = State(initialValue: log.fillTypeRaw)
		self._fobBeforeKnown = State(initialValue: log.fobBeforeKnown)
		self._fobBefore = State(initialValue: log.fobBefore)
		self._fobAfterKnown = State(initialValue: log.fobAfterKnown)
		self._fobAfter = State(initialValue: log.fobAfter)
		self._fobUnitRaw = State(initialValue: log.fobUnitRaw)
		self._utcOffsetKnown = State(initialValue: log.utcOffsetKnown)
		self._utcOffsetHours = State(initialValue: Float(log.utcOffsetSeconds) / 3600)
	}

	private var selectedFillType: FuelFillType? { FuelFillType(rawValue: fillTypeRaw) }

	/// Live preview of the canonical conversion as the operator types — the same call
	/// EditFuelLog's derived-data refresh makes after save, shown here before commit so
	/// a cleared/mistyped density is visible immediately rather than after dismissing.
	private var canonicalPreview: FuelCanonicalQuantity {
		FuelMath.canonical(FuelUplift(
			quantity: upliftQuantity,
			unit: FuelQuantityUnit(rawValue: upliftUnitRaw),
			density: density,
			densityUnit: FuelDensityUnit(rawValue: densityUnitRaw),
			fuelType: log.fuelType
		))
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "UPLIFT QUANTITY")
						HStack {
							Text("Unit").textLabelModified()
							Picker("", selection: $upliftUnitRaw) {
								Text("—").tag("")
								ForEach(FuelQuantityUnit.allCases) { unit in
									Text(unit.rawValue).tag(unit.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview_Numberpad_Float(label: "Quantity", data: $upliftQuantity)}
						HStack {
							Text("Fill Type").textLabelModified()
							Picker("", selection: $fillTypeRaw) {
								Text("—").tag("")
								ForEach(FuelFillType.allCases) { type in
									Text(type.rawValue).tag(type.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if let fill = selectedFillType {
							Text(fill.establishesKnownFullPoint
								? "Anchors the next economy calculation — later fills measure burn back to this one."
								: "Doesn't reach a known-full point — fuel used here rolls forward into the next full-to-full interval.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "DENSITY")
						Text("Jet A is nominally 6.7 lb/gal, but it varies with temperature — enter the density the ticket was actually billed at rather than trusting the standard figure.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack {
							Text("Density Unit").textLabelModified()
							Picker("", selection: $densityUnitRaw) {
								Text("—").tag("")
								ForEach(FuelDensityUnit.allCases) { unit in
									Text(unit.rawValue).tag(unit.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview_Numberpad_Float(label: "Density", data: $density)}
						HStack {
							Text("Source").textLabelModified()
							Picker("", selection: $densitySourceRaw) {
								Text("—").tag("")
								ForEach(FuelDensitySource.allCases) { source in
									Text(source.rawValue).tag(source.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if upliftQuantity != 0 {
							let preview = canonicalPreview
							Text("≈ \(preview.gallons.formatted(.number.precision(.fractionLength(1)))) gal · \(preview.pounds.formatted(.number.precision(.fractionLength(0)))) lb")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
							if preview.flags.contains(.densityAssumed) {
								Text("No density entered — using a standard assumption for this fuel type. Enter the ticket's actual density for an exact figure.")
									.font(.caption)
									.foregroundStyle(.orange)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
							if preview.flags.contains(.unitMismatch) {
								Text("No density available for this fuel type — weight can't be derived.")
									.font(.caption)
									.foregroundStyle(.orange)
									.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FUEL ON BOARD")
						HStack{LabelDataToggle(label: "FOB Before Known", data: $fobBeforeKnown)}
						if fobBeforeKnown {
							HStack{LabelDataTextview_Numberpad_Float(label: "FOB Before", data: $fobBefore)}
						}
						HStack{LabelDataToggle(label: "FOB After Known", data: $fobAfterKnown)}
						if fobAfterKnown {
							HStack{LabelDataTextview_Numberpad_Float(label: "FOB After", data: $fobAfter)}
						}
						if fobBeforeKnown || fobAfterKnown {
							HStack {
								Text("FOB Unit").textLabelModified()
								Picker("", selection: $fobUnitRaw) {
									Text("—").tag("")
									ForEach(FuelQuantityUnit.allCases) { unit in
										Text(unit.rawValue).tag(unit.rawValue)
									}
								}
								.pickerStyle(.automatic)
								.frame(maxWidth: .infinity, alignment: .trailing)
							}
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TIME")
						HStack{LabelDataToggle(label: "UTC Offset Known", data: $utcOffsetKnown)}
						if utcOffsetKnown {
							HStack{LabelDataTextview_Numberpad_Float(label: "UTC Offset (hours)", data: $utcOffsetHours)}
							Text("Local minus Zulu — e.g. −5 for US Eastern Standard Time. Used to reconcile this record against trip sheets kept in Zulu.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}
			}
			.navigationTitle("Uplift & Units")
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
		log.upliftQuantity = upliftQuantity
		log.upliftUnitRaw = upliftUnitRaw
		log.density = density
		log.densityUnitRaw = densityUnitRaw
		log.densitySourceRaw = densitySourceRaw
		log.fillTypeRaw = fillTypeRaw
		log.fobBeforeKnown = fobBeforeKnown
		log.fobBefore = fobBeforeKnown ? fobBefore : 0
		log.fobAfterKnown = fobAfterKnown
		log.fobAfter = fobAfterKnown ? fobAfter : 0
		log.fobUnitRaw = fobUnitRaw
		log.utcOffsetKnown = utcOffsetKnown
		log.utcOffsetSeconds = utcOffsetKnown ? Int(utcOffsetHours * 3600) : 0
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

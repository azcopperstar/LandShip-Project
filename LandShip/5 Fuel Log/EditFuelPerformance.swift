//
//  EditFuelPerformance.swift
//  LandShip
//
//  Sheet editor for FuelLog1's performance inputs — planned burn, taxi fuel, landing
//  reserve, and burn by phase. These are the inputs FuelMath can't derive on its own;
//  the planned-vs-actual variance itself is computed and shown on the main Fuel Log
//  detail screen, where the engine-hours delta since the previous fill is available.
//  AeroTrax only (Vertical.enabledFeatures.fuelOperations).
//

import SwiftUI
import SwiftData

struct EditFuelPerformance: View {
	let log: FuelLog1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var plannedBurnKnown: Bool
	@State private var plannedBurn: Float
	@State private var taxiFuel: Float
	@State private var reserveAtLanding: Float
	@State private var burnClimb: Float
	@State private var burnCruise: Float
	@State private var burnDescent: Float

	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(log: FuelLog1) {
		self.log = log
		self._plannedBurnKnown = State(initialValue: log.plannedBurnKnown)
		self._plannedBurn = State(initialValue: log.plannedBurn)
		self._taxiFuel = State(initialValue: log.taxiFuel)
		self._reserveAtLanding = State(initialValue: log.reserveAtLanding)
		self._burnClimb = State(initialValue: log.burnClimb)
		self._burnCruise = State(initialValue: log.burnCruise)
		self._burnDescent = State(initialValue: log.burnDescent)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "PLANNED BURN")
						HStack{LabelDataToggle(label: "Planned Burn Known", data: $plannedBurnKnown)}
						if plannedBurnKnown {
							HStack{LabelDataTextview_Numberpad_Float(label: "Planned Burn", data: $plannedBurn)}
							Text("The variance against actual burn is the number that tells you something — the absolute figure alone just says the airplane is normal.")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TAXI & RESERVE")
						HStack{LabelDataTextview_Numberpad_Float(label: "Taxi Fuel", data: $taxiFuel)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Reserve at Landing", data: $reserveAtLanding)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "BURN BY PHASE")
						Text("Climb, cruise, and descent burn wildly differently — a single average hides everything for a turbine.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack{LabelDataTextview_Numberpad_Float(label: "Climb", data: $burnClimb)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Cruise", data: $burnCruise)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Descent", data: $burnDescent)}
					}
				}
			}
			.navigationTitle("Performance")
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
		log.plannedBurnKnown = plannedBurnKnown
		log.plannedBurn = plannedBurnKnown ? plannedBurn : 0
		log.taxiFuel = taxiFuel
		log.reserveAtLanding = reserveAtLanding
		log.burnClimb = burnClimb
		log.burnCruise = burnCruise
		log.burnDescent = burnDescent
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

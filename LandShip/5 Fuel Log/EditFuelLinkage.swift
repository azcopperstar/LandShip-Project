//
//  EditFuelLinkage.swift
//  LandShip
//
//  Sheet editor for FuelLog1's cost-center/billing linkage — trip number, cost center,
//  client, operating rule, and billable flag, for charter passthrough or fractional/
//  co-ownership billing. No reverse trip link: TripLog2 already points at fuel logs (see
//  linkedTravelLogSummary() in EditFuelLog.swift), so a second link here would create a
//  second source of truth. AeroTrax only (Vertical.enabledFeatures.fuelOperations).
//

import SwiftUI
import SwiftData

struct EditFuelLinkage: View {
	let log: FuelLog1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var tripNumber: String
	@State private var costCenter: String
	@State private var clientName: String
	@State private var operatingRuleRaw: String
	@State private var billableToCustomer: Bool

	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(log: FuelLog1) {
		self.log = log
		self._tripNumber = State(initialValue: log.tripNumber)
		self._costCenter = State(initialValue: log.costCenter)
		self._clientName = State(initialValue: log.clientName)
		self._operatingRuleRaw = State(initialValue: log.operatingRuleRaw)
		self._billableToCustomer = State(initialValue: log.billableToCustomer)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "MISSION & BILLING")
						HStack{LabelDataTextview(label: "Trip / Mission Number", data: $tripNumber)}
						HStack{LabelDataTextview(label: "Cost Center", data: $costCenter)}
						HStack{LabelDataTextview(label: "Client", data: $clientName)}
						HStack {
							Text("Operating Rule").textLabelModified()
							Picker("", selection: $operatingRuleRaw) {
								Text("—").tag("")
								ForEach(FuelOperatingRule.allCases) { rule in
									Text(rule.rawValue).tag(rule.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						Text("Determines tax treatment and whether fuel is billable to a customer.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						HStack{LabelDataToggle(label: "Billable to Customer", data: $billableToCustomer)}
					}
				}
			}
			.navigationTitle("Linkage")
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
		log.tripNumber = tripNumber
		log.costCenter = costCenter
		log.clientName = clientName
		log.operatingRuleRaw = operatingRuleRaw
		log.billableToCustomer = billableToCustomer
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

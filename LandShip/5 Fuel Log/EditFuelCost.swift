//
//  EditFuelCost.swift
//  LandShip
//
//  Sheet editor for FuelLog1's transaction identity, tank distribution, and the full
//  corporate cost stack — contract fuel, taxes, fees, fee waivers, and international/
//  payment details. AeroTrax only (Vertical.enabledFeatures.fuelOperations).
//
//  `fuelCost` on the main record stays the fuel line ONLY (fuelPrice × fuelAdded) — every
//  field on this sheet is additive on top of it. See FuelMath.costBreakdown for the
//  all-in total; this sheet never writes to fuelCost.
//

import SwiftUI
import SwiftData

struct EditFuelCost: View {
	let log: FuelLog1

	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss

	@State private var ticketNumber: String
	@State private var truckNumber: String
	@State private var supplierBrand: String
	@State private var airportIdentifier: String
	@State private var fboName: String
	@State private var intoPlaneAgent: String
	@State private var serviceTypeRaw: String

	@State private var tankLeftMain: Float
	@State private var tankRightMain: Float
	@State private var tankCenter: Float
	@State private var tankAux: Float
	@State private var tankTips: Float
	@State private var tankUnitRaw: String

	@State private var postedPricePerUnit: Float
	@State private var contractReleaseNumber: String
	@State private var contractPricePerUnit: Float
	@State private var loyaltyProgram: String
	@State private var loyaltyDiscountAmount: Float

	@State private var taxFederalExcise: Float
	@State private var taxState: Float
	@State private var taxLocal: Float
	@State private var taxSales: Float
	@State private var taxRefundable: Bool

	@State private var feeFlowage: Float
	@State private var feeIntoPlane: Float
	@State private var feeRamp: Float
	@State private var feeHandling: Float
	@State private var feeOvernight: Float
	@State private var feeFacility: Float
	@State private var feeAfterHours: Float
	@State private var feeGPU: Float
	@State private var feeLavService: Float

	@State private var feeWaiverThresholdQuantity: Float
	@State private var feeWaiverAchieved: Bool
	@State private var feeWaiverNotes: String

	@State private var currencyCode: String
	@State private var exchangeRateToBase: Float
	@State private var vatAmount: Float
	@State private var vatReclaimable: Bool
	@State private var paymentMethodRaw: String
	@State private var fuelCardNetwork: String

	@State private var showSaveError = false
	@State private var saveErrorMessage: String?

	init(log: FuelLog1) {
		self.log = log
		self._ticketNumber = State(initialValue: log.ticketNumber)
		self._truckNumber = State(initialValue: log.truckNumber)
		self._supplierBrand = State(initialValue: log.supplierBrand)
		self._airportIdentifier = State(initialValue: log.airportIdentifier)
		self._fboName = State(initialValue: log.fboName)
		self._intoPlaneAgent = State(initialValue: log.intoPlaneAgent)
		self._serviceTypeRaw = State(initialValue: log.serviceTypeRaw)
		self._tankLeftMain = State(initialValue: log.tankLeftMain)
		self._tankRightMain = State(initialValue: log.tankRightMain)
		self._tankCenter = State(initialValue: log.tankCenter)
		self._tankAux = State(initialValue: log.tankAux)
		self._tankTips = State(initialValue: log.tankTips)
		self._tankUnitRaw = State(initialValue: log.tankUnitRaw)
		self._postedPricePerUnit = State(initialValue: log.postedPricePerUnit)
		self._contractReleaseNumber = State(initialValue: log.contractReleaseNumber)
		self._contractPricePerUnit = State(initialValue: log.contractPricePerUnit)
		self._loyaltyProgram = State(initialValue: log.loyaltyProgram)
		self._loyaltyDiscountAmount = State(initialValue: log.loyaltyDiscountAmount)
		self._taxFederalExcise = State(initialValue: log.taxFederalExcise)
		self._taxState = State(initialValue: log.taxState)
		self._taxLocal = State(initialValue: log.taxLocal)
		self._taxSales = State(initialValue: log.taxSales)
		self._taxRefundable = State(initialValue: log.taxRefundable)
		self._feeFlowage = State(initialValue: log.feeFlowage)
		self._feeIntoPlane = State(initialValue: log.feeIntoPlane)
		self._feeRamp = State(initialValue: log.feeRamp)
		self._feeHandling = State(initialValue: log.feeHandling)
		self._feeOvernight = State(initialValue: log.feeOvernight)
		self._feeFacility = State(initialValue: log.feeFacility)
		self._feeAfterHours = State(initialValue: log.feeAfterHours)
		self._feeGPU = State(initialValue: log.feeGPU)
		self._feeLavService = State(initialValue: log.feeLavService)
		self._feeWaiverThresholdQuantity = State(initialValue: log.feeWaiverThresholdQuantity)
		self._feeWaiverAchieved = State(initialValue: log.feeWaiverAchieved)
		self._feeWaiverNotes = State(initialValue: log.feeWaiverNotes)
		self._currencyCode = State(initialValue: log.currencyCode)
		self._exchangeRateToBase = State(initialValue: log.exchangeRateToBase)
		self._vatAmount = State(initialValue: log.vatAmount)
		self._vatReclaimable = State(initialValue: log.vatReclaimable)
		self._paymentMethodRaw = State(initialValue: log.paymentMethodRaw)
		self._fuelCardNetwork = State(initialValue: log.fuelCardNetwork)
	}

	private var totalFees: Float {
		feeFlowage + feeIntoPlane + feeRamp + feeHandling + feeOvernight + feeFacility + feeAfterHours + feeGPU + feeLavService
	}

	private var totalTaxes: Float {
		taxFederalExcise + taxState + taxLocal + taxSales
	}

	private var contractSavings: Float {
		guard postedPricePerUnit > 0, contractPricePerUnit > 0 else { return 0 }
		return max(0, postedPricePerUnit - contractPricePerUnit) * log.upliftQuantity
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				CardView {
					VStack {
						SectionText(label: "TRANSACTION")
						HStack{LabelDataTextview(label: "Ticket / Invoice Number", data: $ticketNumber)}
						HStack{LabelDataTextview(label: "Truck Number", data: $truckNumber)}
						HStack{LabelDataTextview(label: "Supplier / Brand", data: $supplierBrand)}
						HStack{LabelDataTextview(label: "Airport (ICAO/IATA)", data: $airportIdentifier)}
						HStack{LabelDataTextview(label: "FBO", data: $fboName)}
						HStack{LabelDataTextview(label: "Into-Plane Agent", data: $intoPlaneAgent)}
						HStack {
							Text("Service Type").textLabelModified()
							Picker("", selection: $serviceTypeRaw) {
								Text("—").tag("")
								ForEach(FuelServiceType.allCases) { type in
									Text(type.rawValue).tag(type.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TANK DISTRIBUTION")
						HStack {
							Text("Unit").textLabelModified()
							Picker("", selection: $tankUnitRaw) {
								Text("—").tag("")
								ForEach(FuelQuantityUnit.allCases) { unit in
									Text(unit.rawValue).tag(unit.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						HStack{LabelDataTextview_Numberpad_Float(label: "Left Main", data: $tankLeftMain)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Right Main", data: $tankRightMain)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Center", data: $tankCenter)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Aux", data: $tankAux)}
						HStack{LabelDataTextview_Numberpad_Float(label: "Tips", data: $tankTips)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "PRICING & CONTRACT FUEL")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Posted Price", data: $postedPricePerUnit)}
						HStack{LabelDataTextview(label: "Contract Release Number", data: $contractReleaseNumber)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Contract Price", data: $contractPricePerUnit)}
						HStack{LabelDataTextview(label: "Loyalty Program", data: $loyaltyProgram)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Loyalty Discount", data: $loyaltyDiscountAmount)}
						if contractSavings > 0 {
							Text("Contract savings on this uplift: \(contractSavings.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "TAXES")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Federal Excise", data: $taxFederalExcise)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "State", data: $taxState)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Local", data: $taxLocal)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Sales", data: $taxSales)}
						HStack{LabelDataToggle(label: "Refundable", data: $taxRefundable)}
						if totalTaxes > 0 {
							Text("Total taxes: \(totalTaxes.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FEES")
						HStack{LabelDataTextview_Numberpad_Currency(label: "Flowage", data: $feeFlowage)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Into-Plane", data: $feeIntoPlane)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Ramp", data: $feeRamp)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Handling", data: $feeHandling)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Overnight", data: $feeOvernight)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Facility", data: $feeFacility)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "After-Hours Callout", data: $feeAfterHours)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "GPU", data: $feeGPU)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "Lav Service", data: $feeLavService)}
						if totalFees > 0 {
							Text("Total fees: \(totalFees.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
								.font(.caption)
								.foregroundStyle(.secondary)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
					}
				}

				CardView {
					VStack {
						SectionText(label: "FEE WAIVER")
						HStack{LabelDataTextview_Numberpad_Float(label: "Waiver Threshold Quantity", data: $feeWaiverThresholdQuantity)}
						HStack{LabelDataToggle(label: "Waiver Achieved", data: $feeWaiverAchieved)}
						if feeWaiverThresholdQuantity > 0, !feeWaiverAchieved, log.upliftQuantity > 0 {
							Text("Uplifted \(log.upliftQuantity.formatted(.number.precision(.fractionLength(0)))) against a \(feeWaiverThresholdQuantity.formatted(.number.precision(.fractionLength(0)))) threshold — a fee waiver was missed on this fill.")
								.font(.caption)
								.foregroundStyle(.orange)
								.frame(maxWidth: .infinity, alignment: .leading)
						}
						HStack{LabelDataTextview(label: "Notes", data: $feeWaiverNotes)}
					}
				}

				CardView {
					VStack {
						SectionText(label: "INTERNATIONAL & PAYMENT")
						HStack{LabelDataTextview(label: "Currency Code", data: $currencyCode, prompt: "Device default")}
						HStack{LabelDataTextview_Numberpad_Float(label: "Exchange Rate to Base", data: $exchangeRateToBase)}
						HStack{LabelDataTextview_Numberpad_Currency(label: "VAT Amount", data: $vatAmount)}
						HStack{LabelDataToggle(label: "VAT Reclaimable", data: $vatReclaimable)}
						HStack {
							Text("Payment Method").textLabelModified()
							Picker("", selection: $paymentMethodRaw) {
								Text("—").tag("")
								ForEach(FuelPaymentMethod.allCases) { method in
									Text(method.rawValue).tag(method.rawValue)
								}
							}
							.pickerStyle(.automatic)
							.frame(maxWidth: .infinity, alignment: .trailing)
						}
						if paymentMethodRaw == FuelPaymentMethod.fuelCard.rawValue {
							HStack{LabelDataTextview(label: "Fuel Card Network", data: $fuelCardNetwork, prompt: "AVCARD, UVair, WFS, Multi Service…")}
						}
					}
				}
			}
			.navigationTitle("Cost & Contract Fuel")
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
		log.ticketNumber = ticketNumber
		log.truckNumber = truckNumber
		log.supplierBrand = supplierBrand
		log.airportIdentifier = airportIdentifier
		log.fboName = fboName
		log.intoPlaneAgent = intoPlaneAgent
		log.serviceTypeRaw = serviceTypeRaw
		log.tankLeftMain = tankLeftMain
		log.tankRightMain = tankRightMain
		log.tankCenter = tankCenter
		log.tankAux = tankAux
		log.tankTips = tankTips
		log.tankUnitRaw = tankUnitRaw
		log.postedPricePerUnit = postedPricePerUnit
		log.contractReleaseNumber = contractReleaseNumber
		log.contractPricePerUnit = contractPricePerUnit
		log.loyaltyProgram = loyaltyProgram
		log.loyaltyDiscountAmount = loyaltyDiscountAmount
		log.taxFederalExcise = taxFederalExcise
		log.taxState = taxState
		log.taxLocal = taxLocal
		log.taxSales = taxSales
		log.taxRefundable = taxRefundable
		log.feeFlowage = feeFlowage
		log.feeIntoPlane = feeIntoPlane
		log.feeRamp = feeRamp
		log.feeHandling = feeHandling
		log.feeOvernight = feeOvernight
		log.feeFacility = feeFacility
		log.feeAfterHours = feeAfterHours
		log.feeGPU = feeGPU
		log.feeLavService = feeLavService
		log.feeWaiverThresholdQuantity = feeWaiverThresholdQuantity
		log.feeWaiverAchieved = feeWaiverAchieved
		log.feeWaiverNotes = feeWaiverNotes
		log.currencyCode = currencyCode
		log.exchangeRateToBase = exchangeRateToBase
		log.vatAmount = vatAmount
		log.vatReclaimable = vatReclaimable
		log.paymentMethodRaw = paymentMethodRaw
		log.fuelCardNetwork = fuelCardNetwork
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

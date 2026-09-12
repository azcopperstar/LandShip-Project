//
//  FuelLog.swift
//  LandShip
//
//  Created by JP on 9/11/25.
//

import Foundation
import SwiftData

@Model
class FuelLog1 {
	var inactive: Bool = false
	var logId: String = ""
	var vehicleId: String = ""
	var logName: String = ""
	var fuelNotes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var fuelDateTime: Date = Date()
	/// When the vehicle left this stop. `nil` on records made before exit time was tracked.
	var fuelExitTime: Date?
	var odometer: Int = 0
	var location: String = ""
	var engHours: Float = 0.0
	var fuelQuantityStart: Float = 0.0
	var fuelQuantityEnd: Float = 0.0
	var fuelAdded: Float = 0.0
	var defAdded: Float = 0.0
	var defPrice: Float = 0.0
	// DEF in the tank before adding any. `defLevel1`/`defLevelFraction`/`defQuantity` below
	// are the level *after* adding — kept under their original names to avoid a rename
	// migration, but labelled "DEF Level End" in the UI.
	var defLevelStart1: Float = 0.0
	var defLevelStartFraction: String = ""
	var defQuantityStart: Float = 0.0
	var defLevel1: Float = 0.0
	var defLevelFraction: String = ""
	/// Actual DEF in the tank after adding, alongside the eighths estimate in `defLevel1`.
	var defQuantity: Float = 0.0
	var oilAdded: Float = 0.0
	var oilChecked: Bool = false
	var engineCoolantChecked: Bool = false
	var secondaryCoolantChecked: Bool = false
	var powerSteeringChecked: Bool = false
	var brakeFluidChecked: Bool = false
	var transmissionFluidChecked: Bool = false
	var rearAxleChecked: Bool = false
	var frontAxleChecked: Bool = false
	var fuelWaterSeparatorChecked: Bool = false
	var airSystemWaterBleedChecked: Bool = false
	// Aviation/marine fluid checks — see FluidCheckList/AviationFluidCheckItem/
	// MarineFluidCheckItem in 11 Enums.swift. Land keeps using the 10 Bool fields above
	// directly and never populates this array.
	// Orphaned: a `[String]` attribute crashes on decode if CloudKit ever delivers it with
	// empty/corrupt bytes (confirmed in the field, 2026-09-08) — no longer read or written
	// anywhere; kept declared only so existing stored data isn't dropped by a lightweight
	// migration. `checkedFluidItemsPacked` below is the live replacement.
	var checkedFluidItemsRaw: [String] = []
	var checkedFluidItemsPacked: String = ""
	var fuelLevelStart1: Float = 1.0
	var fuelLevelEnd1: Float = 1.0
	var fuelLevelStartFraction: String = ""
	var fuelLevelEndFraction: String = ""
	var fuelPrice: Float = 0.0
	var fuelCost: Float = 0.0
	var fuelType: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""

	// MARK: - Fuel operations (additive — see Vertical.enabledFeatures.fuelOperations).
	// Unconditional block (uplift/units/density/fill-type/FOB/Zulu time/sump check) shows
	// for every vertical; everything below the second MARK surfaces only behind the gate.
	// All defaulted so existing rows and land/marine are unaffected. `fuelAdded` above
	// stays the display-unit authoritative figure for every existing report/dashboard/
	// economy calc — these fields are additive canonical data, not a replacement. See
	// Global Functions/FuelMath.swift for derivation.

	// Uplift & units
	var upliftQuantity: Float = 0
	var upliftUnitRaw: String = ""          // FuelQuantityUnit rawValue
	var density: Float = 0
	var densityUnitRaw: String = ""         // FuelDensityUnit rawValue
	var densitySourceRaw: String = ""       // FuelDensitySource rawValue
	var fillTypeRaw: String = ""            // FuelFillType rawValue — drives FuelMath.interval
	var fobBefore: Float = 0
	var fobBeforeKnown: Bool = false
	var fobAfter: Float = 0
	var fobAfterKnown: Bool = false
	var fobUnitRaw: String = ""             // FuelQuantityUnit rawValue

	// Zulu time. `fuelDateTime` above is an absolute Date; this is the UTC offset in
	// effect at capture, letting the record render both original local wall-clock and
	// Zulu. No timezone handling exists elsewhere in the app — this is new ground.
	var utcOffsetSeconds: Int = 0
	var utcOffsetKnown: Bool = false

	// Quality — sump check only; additives/SAF are gated below.
	var sumpCheckPerformed: Bool = false
	var sumpCheckResultRaw: String = ""     // FuelSumpResult rawValue
	var fuelSampleRetained: Bool = false

	// MARK: - Fuel operations, gated (Vertical.enabledFeatures.fuelOperations only)

	// Transaction identity
	var ticketNumber: String = ""
	var truckNumber: String = ""
	var supplierBrand: String = ""
	var airportIdentifier: String = ""
	var fboName: String = ""
	var intoPlaneAgent: String = ""
	var serviceTypeRaw: String = ""         // FuelServiceType rawValue

	// Tank distribution — fixed arity rather than a child entity: FuelLog1.logId is
	// unpopulated in practice and logName is user-editable, so a child model would need
	// a new linking idiom in an otherwise uniformly name-linked codebase. Five covers
	// every airframe this product targets; a child entity remains addable later.
	var tankLeftMain: Float = 0
	var tankRightMain: Float = 0
	var tankCenter: Float = 0
	var tankAux: Float = 0
	var tankTips: Float = 0
	var tankUnitRaw: String = ""            // FuelQuantityUnit rawValue

	// Cost stack. `fuelCost` above is the fuel line ONLY (fuelPrice × fuelAdded, as
	// EditFuelLog already maintains it) — never fold taxes/fees into it. FuelMath
	// .costBreakdown derives allInCost from these plus fuelCost. Getting this wrong
	// double-counts every corporate record.
	var postedPricePerUnit: Float = 0
	var contractReleaseNumber: String = ""
	var contractPricePerUnit: Float = 0
	var loyaltyProgram: String = ""
	var loyaltyDiscountAmount: Float = 0
	var taxFederalExcise: Float = 0
	var taxState: Float = 0
	var taxLocal: Float = 0
	var taxSales: Float = 0
	var taxRefundable: Bool = false
	var feeFlowage: Float = 0
	var feeIntoPlane: Float = 0
	var feeRamp: Float = 0
	var feeHandling: Float = 0
	var feeOvernight: Float = 0
	var feeFacility: Float = 0
	var feeAfterHours: Float = 0
	var feeGPU: Float = 0
	var feeLavService: Float = 0
	var feeWaiverThresholdQuantity: Float = 0
	var feeWaiverAchieved: Bool = false
	var feeWaiverNotes: String = ""
	var currencyCode: String = ""           // "" == device locale, matching today's behavior
	var exchangeRateToBase: Float = 0
	var vatAmount: Float = 0
	var vatReclaimable: Bool = false
	var paymentMethodRaw: String = ""       // FuelPaymentMethod rawValue
	var fuelCardNetwork: String = ""        // e.g. "AVCARD", "UVair", "WFS", "Multi Service"

	// Quality — additives & SAF
	var additiveFSII: Bool = false
	var additiveFSIIConcentration: Float = 0
	var additiveBiocide: Bool = false
	var additiveStaticDissipator: Bool = false
	var additiveNotes: String = ""
	var qualityDocumentReference: String = ""
	var safBlendPercent: Float = 0
	var safCertificateReference: String = ""

	// Performance inputs — burn/reserve are computed in FuelMath; these are the inputs
	// that computation can't derive on its own.
	var plannedBurn: Float = 0
	var plannedBurnKnown: Bool = false
	var taxiFuel: Float = 0
	var reserveAtLanding: Float = 0
	var burnClimb: Float = 0
	var burnCruise: Float = 0
	var burnDescent: Float = 0

	// Linkage — no reverse trip link; TripLog2 already points here (see
	// linkedTravelLogSummary() in EditFuelLog.swift), so a second link would create a
	// second source of truth.
	var tripNumber: String = ""
	var costCenter: String = ""
	var clientName: String = ""
	var operatingRuleRaw: String = ""       // FuelOperatingRule rawValue
	var billableToCustomer: Bool = false

	// Fluids added, aviation — oil is tracked per engine rather than as one generic
	// figure, since a twin/multi-engine aircraft's engines are serviced independently.
	// Six fixed slots to match the "Number of Engines" 1-6 range on Vehicle8/
	// ComponentTimes (see syncEngineSlots in EditVehicle.swift) — same fixed-arity-over-
	// child-entity reasoning as the tank distribution fields above. `oilAdded` above
	// stays the field land/marine use unchanged. Not threaded through init, matching the
	// TripLog2 fluid-check-fields precedent — always default-constructed then set via the
	// edit form's @State.
	var oilAddedEngine1: Float = 0
	var oilAddedEngine2: Float = 0
	var oilAddedEngine3: Float = 0
	var oilAddedEngine4: Float = 0
	var oilAddedEngine5: Float = 0
	var oilAddedEngine6: Float = 0
	var deiceFluidAdded: Float = 0
	var hydraulicFluidAdded: Float = 0
	var brakeFluidAdded: Float = 0
	// Per-engine tach time reading at this stop (AeroTrax), one entry per engine listed in
	// the aircraft's ComponentTimes rows — see TripLog2.engineTachStart/End for the
	// departure/arrival equivalent. Index 0 = engine slot 1.
	var engineTach: [Float] = []

	// Per-tank fuel start/stop level, quantity, and added, aviation — mirrors the same
	// fixed-arity idiom as the per-engine oil fields above, keyed to Vehicle8's
	// numberOfFuelTanks/fuelTankNName/fuelTankNCapacity (1-6). `fuelLevelStart1`/
	// `fuelQuantityStart`/`fuelLevelEnd1`/`fuelQuantityEnd`/`fuelAdded` above stay the
	// whole-aircraft totals — for a multi-tank aircraft they're kept as the sum across
	// configured tanks (see EditFuelLog's recomputeAggregateFuelFromTanks) rather than
	// typed directly, so FuelMath/dashboard/reports keep reading one authoritative figure.
	// Price/cost stay singular per the request — only quantity is broken out per tank.
	var fuelTank1LevelStart1: Float = 0
	var fuelTank2LevelStart1: Float = 0
	var fuelTank3LevelStart1: Float = 0
	var fuelTank4LevelStart1: Float = 0
	var fuelTank5LevelStart1: Float = 0
	var fuelTank6LevelStart1: Float = 0
	var fuelTank1QuantityStart: Float = 0
	var fuelTank2QuantityStart: Float = 0
	var fuelTank3QuantityStart: Float = 0
	var fuelTank4QuantityStart: Float = 0
	var fuelTank5QuantityStart: Float = 0
	var fuelTank6QuantityStart: Float = 0
	var fuelTank1LevelEnd1: Float = 0
	var fuelTank2LevelEnd1: Float = 0
	var fuelTank3LevelEnd1: Float = 0
	var fuelTank4LevelEnd1: Float = 0
	var fuelTank5LevelEnd1: Float = 0
	var fuelTank6LevelEnd1: Float = 0
	var fuelTank1QuantityEnd: Float = 0
	var fuelTank2QuantityEnd: Float = 0
	var fuelTank3QuantityEnd: Float = 0
	var fuelTank4QuantityEnd: Float = 0
	var fuelTank5QuantityEnd: Float = 0
	var fuelTank6QuantityEnd: Float = 0
	var fuelTank1Added: Float = 0
	var fuelTank2Added: Float = 0
	var fuelTank3Added: Float = 0
	var fuelTank4Added: Float = 0
	var fuelTank5Added: Float = 0
	var fuelTank6Added: Float = 0

	init(
		inactive: Bool = false,
		logId: String = "",
		vehicleId: String = "",
		logName: String = "",
		fuelNotes: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		fuelDateTime: Date = Date(),
		fuelExitTime: Date? = nil,
		odometer: Int = 0,
		location: String = "",
		engHours: Float = 0.0,
		fuelQuantityStart: Float = 0.0,
		fuelQuantityEnd: Float = 0.0,
		fuelAdded: Float = 0.0,
		defAdded: Float = 0.0,
		defPrice: Float = 0.0,
		defLevelStart1: Float = 0.0,
		defLevelStartFraction: String = "",
		defQuantityStart: Float = 0.0,
		defLevel1: Float = 0.0,
		defLevelFraction: String = "",
		defQuantity: Float = 0.0,
		oilAdded: Float = 0.0,
		oilChecked: Bool = false,
		engineCoolantChecked: Bool = false,
		secondaryCoolantChecked: Bool = false,
		powerSteeringChecked: Bool = false,
		brakeFluidChecked: Bool = false,
		transmissionFluidChecked: Bool = false,
		rearAxleChecked: Bool = false,
		frontAxleChecked: Bool = false,
		fuelWaterSeparatorChecked: Bool = false,
		airSystemWaterBleedChecked: Bool = false,
		checkedFluidItemsRaw: [String] = [],
		fuelLevelStart1: Float = 1.0,
		fuelLevelEnd1: Float = 1.0,
		fuelLevelStart: String = "",
		fuelLevelEnd: String = "",
		fuelPrice: Float = 0.0,
		fuelCost: Float = 0.0,
		fuelType: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = "",
		upliftQuantity: Float = 0,
		upliftUnitRaw: String = "",
		density: Float = 0,
		densityUnitRaw: String = "",
		densitySourceRaw: String = "",
		fillTypeRaw: String = "",
		fobBefore: Float = 0,
		fobBeforeKnown: Bool = false,
		fobAfter: Float = 0,
		fobAfterKnown: Bool = false,
		fobUnitRaw: String = "",
		utcOffsetSeconds: Int = 0,
		utcOffsetKnown: Bool = false,
		sumpCheckPerformed: Bool = false,
		sumpCheckResultRaw: String = "",
		fuelSampleRetained: Bool = false,
		ticketNumber: String = "",
		truckNumber: String = "",
		supplierBrand: String = "",
		airportIdentifier: String = "",
		fboName: String = "",
		intoPlaneAgent: String = "",
		serviceTypeRaw: String = "",
		tankLeftMain: Float = 0,
		tankRightMain: Float = 0,
		tankCenter: Float = 0,
		tankAux: Float = 0,
		tankTips: Float = 0,
		tankUnitRaw: String = "",
		postedPricePerUnit: Float = 0,
		contractReleaseNumber: String = "",
		contractPricePerUnit: Float = 0,
		loyaltyProgram: String = "",
		loyaltyDiscountAmount: Float = 0,
		taxFederalExcise: Float = 0,
		taxState: Float = 0,
		taxLocal: Float = 0,
		taxSales: Float = 0,
		taxRefundable: Bool = false,
		feeFlowage: Float = 0,
		feeIntoPlane: Float = 0,
		feeRamp: Float = 0,
		feeHandling: Float = 0,
		feeOvernight: Float = 0,
		feeFacility: Float = 0,
		feeAfterHours: Float = 0,
		feeGPU: Float = 0,
		feeLavService: Float = 0,
		feeWaiverThresholdQuantity: Float = 0,
		feeWaiverAchieved: Bool = false,
		feeWaiverNotes: String = "",
		currencyCode: String = "",
		exchangeRateToBase: Float = 0,
		vatAmount: Float = 0,
		vatReclaimable: Bool = false,
		paymentMethodRaw: String = "",
		fuelCardNetwork: String = "",
		additiveFSII: Bool = false,
		additiveFSIIConcentration: Float = 0,
		additiveBiocide: Bool = false,
		additiveStaticDissipator: Bool = false,
		additiveNotes: String = "",
		qualityDocumentReference: String = "",
		safBlendPercent: Float = 0,
		safCertificateReference: String = "",
		plannedBurn: Float = 0,
		plannedBurnKnown: Bool = false,
		taxiFuel: Float = 0,
		reserveAtLanding: Float = 0,
		burnClimb: Float = 0,
		burnCruise: Float = 0,
		burnDescent: Float = 0,
		tripNumber: String = "",
		costCenter: String = "",
		clientName: String = "",
		operatingRuleRaw: String = "",
		billableToCustomer: Bool = false
	) {
		self.inactive = inactive
		self.logId = logId
		self.vehicleId = vehicleId
		self.logName = logName
		self.fuelNotes = fuelNotes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.fuelDateTime = fuelDateTime
		self.fuelExitTime = fuelExitTime
		self.odometer = odometer
		self.location = location
		self.engHours = engHours
		self.fuelQuantityStart = fuelQuantityStart
		self.fuelQuantityEnd = fuelQuantityEnd
		self.fuelAdded = fuelAdded
		self.defAdded = defAdded
		self.defPrice = defPrice
		self.defLevelStart1 = defLevelStart1
		self.defLevelStartFraction = defLevelStartFraction
		self.defQuantityStart = defQuantityStart
		self.defLevel1 = defLevel1
		self.defLevelFraction = defLevelFraction
		self.defQuantity = defQuantity
		self.oilAdded = oilAdded
		self.oilChecked = oilChecked
		self.engineCoolantChecked = engineCoolantChecked
		self.secondaryCoolantChecked = secondaryCoolantChecked
		self.powerSteeringChecked = powerSteeringChecked
		self.brakeFluidChecked = brakeFluidChecked
		self.transmissionFluidChecked = transmissionFluidChecked
		self.rearAxleChecked = rearAxleChecked
		self.frontAxleChecked = frontAxleChecked
		self.fuelWaterSeparatorChecked = fuelWaterSeparatorChecked
		self.airSystemWaterBleedChecked = airSystemWaterBleedChecked
		self.checkedFluidItemsRaw = checkedFluidItemsRaw
		self.fuelLevelStart1 = fuelLevelStart1
		self.fuelLevelEnd1 = fuelLevelEnd1
		self.fuelLevelStartFraction = fuelLevelStart
		self.fuelLevelEndFraction = fuelLevelEnd
		self.fuelPrice = fuelPrice
		self.fuelCost = fuelCost
		self.fuelType = fuelType
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
		self.upliftQuantity = upliftQuantity
		self.upliftUnitRaw = upliftUnitRaw
		self.density = density
		self.densityUnitRaw = densityUnitRaw
		self.densitySourceRaw = densitySourceRaw
		self.fillTypeRaw = fillTypeRaw
		self.fobBefore = fobBefore
		self.fobBeforeKnown = fobBeforeKnown
		self.fobAfter = fobAfter
		self.fobAfterKnown = fobAfterKnown
		self.fobUnitRaw = fobUnitRaw
		self.utcOffsetSeconds = utcOffsetSeconds
		self.utcOffsetKnown = utcOffsetKnown
		self.sumpCheckPerformed = sumpCheckPerformed
		self.sumpCheckResultRaw = sumpCheckResultRaw
		self.fuelSampleRetained = fuelSampleRetained
		self.ticketNumber = ticketNumber
		self.truckNumber = truckNumber
		self.supplierBrand = supplierBrand
		self.airportIdentifier = airportIdentifier
		self.fboName = fboName
		self.intoPlaneAgent = intoPlaneAgent
		self.serviceTypeRaw = serviceTypeRaw
		self.tankLeftMain = tankLeftMain
		self.tankRightMain = tankRightMain
		self.tankCenter = tankCenter
		self.tankAux = tankAux
		self.tankTips = tankTips
		self.tankUnitRaw = tankUnitRaw
		self.postedPricePerUnit = postedPricePerUnit
		self.contractReleaseNumber = contractReleaseNumber
		self.contractPricePerUnit = contractPricePerUnit
		self.loyaltyProgram = loyaltyProgram
		self.loyaltyDiscountAmount = loyaltyDiscountAmount
		self.taxFederalExcise = taxFederalExcise
		self.taxState = taxState
		self.taxLocal = taxLocal
		self.taxSales = taxSales
		self.taxRefundable = taxRefundable
		self.feeFlowage = feeFlowage
		self.feeIntoPlane = feeIntoPlane
		self.feeRamp = feeRamp
		self.feeHandling = feeHandling
		self.feeOvernight = feeOvernight
		self.feeFacility = feeFacility
		self.feeAfterHours = feeAfterHours
		self.feeGPU = feeGPU
		self.feeLavService = feeLavService
		self.feeWaiverThresholdQuantity = feeWaiverThresholdQuantity
		self.feeWaiverAchieved = feeWaiverAchieved
		self.feeWaiverNotes = feeWaiverNotes
		self.currencyCode = currencyCode
		self.exchangeRateToBase = exchangeRateToBase
		self.vatAmount = vatAmount
		self.vatReclaimable = vatReclaimable
		self.paymentMethodRaw = paymentMethodRaw
		self.fuelCardNetwork = fuelCardNetwork
		self.additiveFSII = additiveFSII
		self.additiveFSIIConcentration = additiveFSIIConcentration
		self.additiveBiocide = additiveBiocide
		self.additiveStaticDissipator = additiveStaticDissipator
		self.additiveNotes = additiveNotes
		self.qualityDocumentReference = qualityDocumentReference
		self.safBlendPercent = safBlendPercent
		self.safCertificateReference = safCertificateReference
		self.plannedBurn = plannedBurn
		self.plannedBurnKnown = plannedBurnKnown
		self.taxiFuel = taxiFuel
		self.reserveAtLanding = reserveAtLanding
		self.burnClimb = burnClimb
		self.burnCruise = burnCruise
		self.burnDescent = burnDescent
		self.tripNumber = tripNumber
		self.costCenter = costCenter
		self.clientName = clientName
		self.operatingRuleRaw = operatingRuleRaw
		self.billableToCustomer = billableToCustomer
	}
	
}

//
//  FuelMath.swift
//  LandShip
//
//  Derives canonical uplift quantity, full-to-full interval economy, cost breakdown, and
//  tankering breakeven for FuelLog1 — mirrors PartTimeMath.swift's two-layer shape: pure
//  value-type math up front (testable without a ModelContext, which matters here since
//  RenderPreview/RunCodeSnippet are both broken in this dev environment), with a thin
//  SwiftData fetch layer at the bottom mirroring Functions.loadVehicleDetails's shape.
//
//  The one invariant every caller must respect: FuelLog1.fuelCost is the fuel line ONLY
//  (fuelPrice × fuelAdded) — taxes and fees are additive on top of it via
//  FuelCostBreakdown.allInCost, never folded back into fuelCost itself. Folding them in
//  would double-count every corporate record.
//

import Foundation
import SwiftData

// MARK: - Value inputs (no ModelContext — unit-testable in isolation)

/// A flat mirror of the uplift-relevant subset of FuelLog1, so `canonical(_:)` never
/// touches a live @Model. Two inits mirror PartTimeMath.InstallSegment: `init(model:)`
/// for real use, plus a trailing memberwise init for tests.
struct FuelUplift: Equatable {
	let quantity: Float
	let unit: FuelQuantityUnit?
	let density: Float
	let densityUnit: FuelDensityUnit?
	let fuelType: String

	init(model: FuelLog1) {
		quantity = model.upliftQuantity
		unit = FuelQuantityUnit(rawValue: model.upliftUnitRaw)
		density = model.density
		densityUnit = FuelDensityUnit(rawValue: model.densityUnitRaw)
		fuelType = model.fuelType
	}

	init(quantity: Float, unit: FuelQuantityUnit?, density: Float, densityUnit: FuelDensityUnit?, fuelType: String) {
		self.quantity = quantity
		self.unit = unit
		self.density = density
		self.densityUnit = densityUnit
		self.fuelType = fuelType
	}
}

/// A flat mirror of the interval-relevant subset of FuelLog1 — what `interval(_:)` walks
/// backward through. Kept separate from `FuelUplift` since the two are used independently.
struct FuelLogPoint: Equatable {
	let date: Date
	let odometer: Int
	let fuelAdded: Float
	let fuelCost: Float
	let fuelPrice: Float
	let fillType: FuelFillType?

	init(model: FuelLog1) {
		date = model.fuelDateTime
		odometer = model.odometer
		fuelAdded = model.fuelAdded
		fuelCost = model.fuelCost
		fuelPrice = model.fuelPrice
		fillType = FuelFillType(rawValue: model.fillTypeRaw)
	}

	init(date: Date, odometer: Int, fuelAdded: Float, fuelCost: Float, fuelPrice: Float, fillType: FuelFillType?) {
		self.date = date
		self.odometer = odometer
		self.fuelAdded = fuelAdded
		self.fuelCost = fuelCost
		self.fuelPrice = fuelPrice
		self.fillType = fillType
	}
}

struct FuelCanonicalQuantity: Equatable {
	let gallons: Float
	let pounds: Float
	let poundsPerGallonUsed: Float
	let flags: Set<FuelDataFlag>
}

struct FuelIntervalStats: Equatable {
	let distance: Int
	let fuelUsed: Float          // display-unit, summed across every fill since the anchor
	let economy: Float           // distance per fuelUsed unit; 0 when not computable
	let costPerDistance: Float
	let daysSinceLast: Int
	let previousOdometer: Int
	let previousDate: Date?
	/// The immediately-prior fill's price, regardless of the full-point anchor used for
	/// distance/economy — price change is a per-transaction metric, not an interval one.
	let previousFuelPrice: Float
	let hasPreviousFill: Bool
	let flags: Set<FuelDataFlag>
}

struct FuelCostBreakdown: Equatable {
	let fuelCost: Float          // == FuelLog1.fuelCost, fuel line only — see file header
	let totalTaxes: Float
	let totalFees: Float
	let vatAmount: Float
	let allInCost: Float
	let contractSavings: Float   // 0 unless both postedPricePerUnit and contractPricePerUnit are set
}

struct FuelTankeringResult: Equatable {
	let extraQuantity: Float
	let costSavedAtOrigin: Float
	let burnPenalty: Float
	let netSavings: Float
	let worthIt: Bool
}

/// Data-quality flags — never errors. A number is always returned; the flag says how
/// much to trust it, matching PartTimeMath.PartTimeFlag's "(value, flags)" idiom.
enum FuelDataFlag: String, Hashable, CaseIterable {
	case noPriorFullFill
	case partialFillInInterval
	case fobNotRecorded
	case densityAssumed
	case unitMismatch
	case implausibleBurn
	case meterNotAdvanced
}

// MARK: - Pure statics

enum FuelMath {

	/// Above this, a burn-per-hour figure is reported with `.implausibleBurn` rather than
	/// silently trusted — sized well above the thirstiest turbine this product targets, so
	/// a legitimate high-burn leg never trips it. Guards the same meter-typo hazard
	/// PartTimeMath.implausibleAccrualHours guards against for part life.
	static let implausibleBurnPerHour: Float = 2000

	/// Standard density in lb/US gallon, for the "never assume 6.7" fallback only — see
	/// `canonical(_:)`. `nil` for fuels where density is meaningless (electric, gaseous,
	/// nuclear); callers must not substitute a number for those.
	static func standardDensity(forFuelType fuelType: String) -> Float? {
		if let aviation = AviationFuelType(rawValue: fuelType) {
			switch aviation {
				case .jetA, .jetA1, .jetB, .ts1, .no3JetFuel, .jp4, .jp5, .jp8, .f24, .f35, .jp7, .jpts, .jp10, .saf:
					return 6.71
				case .avgas100LL, .ul94, .ul9196, .ul91, .mogas, .g100UL, .swift100R, .ul100E:
					return 6.0
				case .hydrogen, .lngMethane, .batteryElectric:
					return nil
			}
		}
		if let marine = MarineFuelType(rawValue: fuelType) {
			switch marine {
				case .lng, .bioLNG, .lpg, .cng, .hydrogen, .batteryElectric, .nuclear, .ammonia, .eFuels, .hybridDieselElectric, .coal, .wood:
					return nil
				default:
					return 7.05   // ISO 8217 distillate/residual — close enough for a flagged assumption
			}
		}
		if let land = LandFuelType(rawValue: fuelType) {
			switch land {
				case .acLevel1, .acLevel2, .dcFastCharge, .batterySwap, .phev, .hydrogen, .compressedAir, .woodGas, .steamCoal:
					return nil
				case .dieselULSD, .dieselLowHighSulfur, .no1D, .no2D, .no4D, .winterArcticDiesel, .dyedDiesel,
					 .biodieselBlend, .b100, .hvo100, .xtl:
					return 7.1
				default:
					return 6.1    // gasoline / ethanol-blend family
			}
		}
		return nil
	}

	/// Converts an uplift to canonical gallons and pounds. Never assumes 6.7 — density
	/// comes from the ticket/measured value when present, and only falls back to
	/// `standardDensity` (flagged `.densityAssumed`) when it isn't. `.unitMismatch` marks
	/// the rarer case where no density is available at all and the conversion can't be done.
	static func canonical(_ uplift: FuelUplift) -> FuelCanonicalQuantity {
		guard let unit = uplift.unit, uplift.quantity != 0 else {
			return FuelCanonicalQuantity(gallons: 0, pounds: 0, poundsPerGallonUsed: 0, flags: [])
		}

		var flags: Set<FuelDataFlag> = []
		var poundsPerGallon = uplift.densityUnit.map { $0.poundsPerUSGallon(uplift.density) } ?? 0
		if poundsPerGallon <= 0 {
			if let standard = standardDensity(forFuelType: uplift.fuelType) {
				poundsPerGallon = standard
				flags.insert(.densityAssumed)
			} else {
				flags.insert(.unitMismatch)
			}
		}

		if unit.isMass {
			let pounds = uplift.quantity * (unit.poundsPerUnit ?? 0)
			let gallons = poundsPerGallon > 0 ? pounds / poundsPerGallon : 0
			return FuelCanonicalQuantity(gallons: gallons, pounds: pounds, poundsPerGallonUsed: poundsPerGallon, flags: flags)
		} else {
			let gallons = uplift.quantity * (unit.usGallonsPerUnit ?? 0)
			let pounds = poundsPerGallon > 0 ? gallons * poundsPerGallon : 0
			return FuelCanonicalQuantity(gallons: gallons, pounds: pounds, poundsPerGallonUsed: poundsPerGallon, flags: flags)
		}
	}

	/// The fill-flag gate: economy is only meaningful between two known-full points.
	/// Walks backward from `current` through `priorAscending` (same vehicle, ascending by
	/// date, not including `current`) to the nearest point that `establishesKnownFullPoint`
	/// — that point becomes the anchor for distance/date, and every fill strictly between
	/// the anchor and `current` (exclusive of the anchor's own fuelAdded, inclusive of
	/// `current`'s) is summed into `fuelUsed`. When no such anchor exists, falls back to
	/// the nearest prior fill and flags `.noPriorFullFill` rather than returning nothing.
	static func interval(current: FuelLogPoint, priorAscending: [FuelLogPoint]) -> FuelIntervalStats {
		guard let nearest = priorAscending.last else {
			return FuelIntervalStats(distance: 0, fuelUsed: 0, economy: 0, costPerDistance: 0,
				daysSinceLast: 0, previousOdometer: 0, previousDate: nil, previousFuelPrice: 0,
				hasPreviousFill: false, flags: [])
		}

		var flags: Set<FuelDataFlag> = []
		var fuelUsed = current.fuelAdded
		var anchor = nearest
		var foundFullPoint = false

		for point in priorAscending.reversed() {
			// Unset fillType (every record predating this feature, and any record the
			// operator hasn't touched) defaults to treating the fill as full — this is
			// exactly today's existing behavior (anchor on the immediately-prior fill,
			// no accumulation, no flags) and must not change for historical data. The
			// gating only engages once a fill is explicitly marked `.partial`/`.defuel`.
			if point.fillType?.establishesKnownFullPoint ?? true {
				anchor = point
				foundFullPoint = true
				break
			}
			fuelUsed += point.fuelAdded
			flags.insert(.partialFillInInterval)
		}
		if !foundFullPoint {
			flags.insert(.noPriorFullFill)
		}

		let distance = max(0, current.odometer - anchor.odometer)
		let days = Calendar.current.dateComponents([.day], from: anchor.date, to: current.date).day ?? 0
		let economy = fuelUsed > 0 ? Float(distance) / fuelUsed : 0
		let costPerDistance = distance > 0 ? current.fuelCost / Float(distance) : 0

		return FuelIntervalStats(
			distance: distance, fuelUsed: fuelUsed, economy: economy, costPerDistance: costPerDistance,
			daysSinceLast: days, previousOdometer: anchor.odometer, previousDate: anchor.date,
			previousFuelPrice: nearest.fuelPrice, hasPreviousFill: true, flags: flags
		)
	}

	/// Burn per hour over a leg. `hoursFlown <= 0` returns 0 flagged `.meterNotAdvanced`
	/// rather than dividing by zero; results above `implausibleBurnPerHour` are flagged
	/// rather than trusted outright.
	static func burnPerHour(fuelUsed: Float, hoursFlown: Float) -> (value: Float, flags: Set<FuelDataFlag>) {
		guard hoursFlown > 0 else { return (0, [.meterNotAdvanced]) }
		let burn = fuelUsed / hoursFlown
		if burn > implausibleBurnPerHour { return (burn, [.implausibleBurn]) }
		return (burn, [])
	}

	static func specificRange(distance: Int, fuelUsed: Float) -> Float {
		guard fuelUsed > 0 else { return 0 }
		return Float(distance) / fuelUsed
	}

	/// The variance between planned and actual burn — the number that tells you
	/// something; the absolute burn on its own just says the airplane is normal.
	static func plannedVsActual(planned: Float, actual: Float) -> Float {
		planned - actual
	}

	/// `fuelCost` stays the fuel line only (see file header); this derives the all-in
	/// total on top of it. Never write this back into `fuelCost` itself.
	static func costBreakdown(_ log: FuelLog1) -> FuelCostBreakdown {
		let totalTaxes = log.taxFederalExcise + log.taxState + log.taxLocal + log.taxSales
		let totalFees = log.feeFlowage + log.feeIntoPlane + log.feeRamp + log.feeHandling +
			log.feeOvernight + log.feeFacility + log.feeAfterHours + log.feeGPU + log.feeLavService
		let allIn = log.fuelCost + totalTaxes + totalFees + log.vatAmount - log.loyaltyDiscountAmount
		let savings = (log.postedPricePerUnit > 0 && log.contractPricePerUnit > 0)
			? max(0, log.postedPricePerUnit - log.contractPricePerUnit) * log.upliftQuantity
			: 0
		return FuelCostBreakdown(
			fuelCost: log.fuelCost, totalTaxes: totalTaxes, totalFees: totalFees,
			vatAmount: log.vatAmount, allInCost: allIn, contractSavings: savings
		)
	}

	/// Did carrying cheap fuel from the departure field pay after the burn penalty of
	/// carrying the weight? `burnPenaltyFactor` is the extra fuel burned per unit of extra
	/// fuel carried over the leg (a fraction, e.g. 0.02 for 2%) — supplied by the caller,
	/// since it depends on aircraft and leg length rather than anything derivable here.
	static func tankeringBreakeven(
		extraQuantity: Float, originPricePerUnit: Float, destinationPricePerUnit: Float, burnPenaltyFactor: Float
	) -> FuelTankeringResult {
		let costSaved = max(0, destinationPricePerUnit - originPricePerUnit) * extraQuantity
		let burnPenalty = extraQuantity * burnPenaltyFactor * originPricePerUnit
		let net = costSaved - burnPenalty
		return FuelTankeringResult(
			extraQuantity: extraQuantity, costSavedAtOrigin: costSaved,
			burnPenalty: burnPenalty, netSavings: net, worthIt: net > 0
		)
	}
}

// MARK: - SwiftData fetch layer (mirrors Functions.loadVehicleDetails's shape)

extension Functions {
	/// Every fuel log for a vehicle strictly before `date`, ascending — the window
	/// `FuelMath.interval` walks backward through.
	func loadPriorFuelLogs(context: ModelContext, vehicleId: String, before date: Date) -> [FuelLog1] {
		guard !vehicleId.isEmpty else { return [] }
		let fd = FetchDescriptor<FuelLog1>(
			predicate: #Predicate { $0.vehicleId == vehicleId && $0.fuelDateTime < date },
			sortBy: [SortDescriptor(\FuelLog1.fuelDateTime, order: .forward)]
		)
		return (try? context.fetch(fd)) ?? []
	}

	/// Single-record convenience — the interval stats for one log against its vehicle's
	/// prior history.
	func loadFuelIntervalStats(context: ModelContext, log: FuelLog1) -> FuelIntervalStats {
		let priors = loadPriorFuelLogs(context: context, vehicleId: log.vehicleId, before: log.fuelDateTime)
			.map(FuelLogPoint.init(model:))
		return FuelMath.interval(current: FuelLogPoint(model: log), priorAscending: priors)
	}

	/// Batch form for lists/dashboard/reports — one fetch per distinct vehicle rather than
	/// one per log, so a large fuel history stays cheap.
	func loadFuelIntervalStatsBatch(context: ModelContext, logs: [FuelLog1]) -> [PersistentIdentifier: FuelIntervalStats] {
		let byVehicle = Dictionary(grouping: logs, by: { $0.vehicleId })
		var result: [PersistentIdentifier: FuelIntervalStats] = [:]
		for (vehicleId, vehicleLogs) in byVehicle {
			guard !vehicleId.isEmpty else { continue }
			let fd = FetchDescriptor<FuelLog1>(
				predicate: #Predicate { $0.vehicleId == vehicleId },
				sortBy: [SortDescriptor(\FuelLog1.fuelDateTime, order: .forward)]
			)
			let allForVehicle = ((try? context.fetch(fd)) ?? []).map(FuelLogPoint.init(model:))
			for log in vehicleLogs {
				let point = FuelLogPoint(model: log)
				let priors = allForVehicle.filter { $0.date < point.date }
				result[log.persistentModelID] = FuelMath.interval(current: point, priorAscending: priors)
			}
		}
		return result
	}
}

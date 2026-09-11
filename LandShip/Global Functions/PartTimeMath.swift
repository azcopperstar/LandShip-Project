//
//  PartTimeMath.swift
//  LandShip
//
//  Derives a part's TSN/TSO/TSR/cycle counters from PartInstallation segments instead of
//  hand-maintained fields — "derive, don't store." Pure value-type math up front (testable
//  without a ModelContext, which matters here since RenderPreview/RunCodeSnippet are both
//  broken in this dev environment), with a thin SwiftData fetch layer at the bottom mirroring
//  Functions.loadVehicleDetails's shape.
//
//  Derivation is exactly ONE segment deep: a snapshot is either the open segment's opening
//  balance plus accrual since installMeterHours, or (no open segment) the latest closed
//  segment's frozen closing balance, or (never installed via the app) MxParts1's carry-in
//  fields. This is why cross-aircraft moves, shelf-then-reinstall, and overhaul zeroing all
//  fall out for free instead of needing special-case code — see multi-vertical-expansion
//  memory for the full design rationale.
//

import Foundation
import SwiftData

// MARK: - Value inputs (no ModelContext — unit-testable in isolation)

struct PartCarryIn: Equatable {
	var tsn: Float = 0
	var csn: Int = 0
	var tso: Float = 0
	var cso: Int = 0
	var tsr: Float = 0
	var limitTimeBase: String = ""
}

struct InstallSegment: Equatable {
	var installDate: Date
	var installMeterHours: Float
	var installMeterKnown: Bool
	var installMeterCycles: Int
	var openingTSN: Float
	var openingCSN: Int
	var openingTSO: Float
	var openingCSO: Int
	var openingTSR: Float
	var removalDate: Date?
	var removalMeterHours: Float
	var removalMeterKnown: Bool
	var removalMeterCycles: Int
	var closingTSN: Float
	var closingCSN: Int
	var closingTSO: Float
	var closingCSO: Int
	var closingTSR: Float
	var vehicleId: String
	var position: String
	var meterTimeBase: String

	init(model: PartInstallation) {
		installDate = model.installDate
		installMeterHours = model.installMeterHours
		installMeterKnown = model.installMeterKnown
		installMeterCycles = model.installMeterCycles
		openingTSN = model.openingTSN
		openingCSN = model.openingCSN
		openingTSO = model.openingTSO
		openingCSO = model.openingCSO
		openingTSR = model.openingTSR
		removalDate = model.removalDate
		removalMeterHours = model.removalMeterHours
		removalMeterKnown = model.removalMeterKnown
		removalMeterCycles = model.removalMeterCycles
		closingTSN = model.closingTSN
		closingCSN = model.closingCSN
		closingTSO = model.closingTSO
		closingCSO = model.closingCSO
		closingTSR = model.closingTSR
		vehicleId = model.vehicleId
		position = model.position
		meterTimeBase = model.meterTimeBase
	}

	// Synthesized memberwise init is still available for tests since every property above
	// has an explicit type; Swift only suppresses it when you write your OWN init, so tests
	// construct segments via this trailing convenience initializer instead.
	init(
		installDate: Date, installMeterHours: Float, installMeterKnown: Bool, installMeterCycles: Int = 0,
		openingTSN: Float = 0, openingCSN: Int = 0, openingTSO: Float = 0, openingCSO: Int = 0, openingTSR: Float = 0,
		removalDate: Date? = nil, removalMeterHours: Float = 0, removalMeterKnown: Bool = false, removalMeterCycles: Int = 0,
		closingTSN: Float = 0, closingCSN: Int = 0, closingTSO: Float = 0, closingCSO: Int = 0, closingTSR: Float = 0,
		vehicleId: String = "", position: String = "", meterTimeBase: String = ""
	) {
		self.installDate = installDate
		self.installMeterHours = installMeterHours
		self.installMeterKnown = installMeterKnown
		self.installMeterCycles = installMeterCycles
		self.openingTSN = openingTSN
		self.openingCSN = openingCSN
		self.openingTSO = openingTSO
		self.openingCSO = openingCSO
		self.openingTSR = openingTSR
		self.removalDate = removalDate
		self.removalMeterHours = removalMeterHours
		self.removalMeterKnown = removalMeterKnown
		self.removalMeterCycles = removalMeterCycles
		self.closingTSN = closingTSN
		self.closingCSN = closingCSN
		self.closingTSO = closingTSO
		self.closingCSO = closingCSO
		self.closingTSR = closingTSR
		self.vehicleId = vehicleId
		self.position = position
		self.meterTimeBase = meterTimeBase
	}
}

struct MeterReading: Equatable {
	var hours: Float = 0
	var known: Bool = false
	var cycles: Int = 0
	var timeBase: String = ""
}

enum PartTimeFlag: String, Hashable, CaseIterable {
	case noCurrentMeterReading
	case noInstallSnapshot
	case installSnapshotAheadOfMeter
	case implausibleAccrual
	case timeBaseMismatch
}

struct PartTimeSnapshot: Equatable {
	enum Provenance: String {
		case openInstallation, closedInstallation, manualCarryIn
	}

	let tsn: Float
	let csn: Int
	let tso: Float
	let cso: Int
	let tsr: Float
	let accruedThisInstall: Float
	let accruedCyclesThisInstall: Int
	let isInstalled: Bool
	let vehicleId: String
	let position: String
	let installDate: Date?
	let effectiveTimeBase: String
	let provenance: Provenance
	let flags: Set<PartTimeFlag>
}

struct PartLifeRemaining: Equatable {
	let limitType: String
	let isRegulatoryLimit: Bool
	let remainingHours: Float?
	let remainingCycles: Int?
	let remainingCalendarDays: Int?
	let isOverdue: Bool
}

enum PartTimeMath {

	/// Any accrual larger than this on a single install segment is reported with
	/// `.implausibleAccrual` rather than silently trusted — sized just above a typical
	/// piston TBO run so a legitimate long install never trips it. This is the guardrail
	/// against the Vehicle8.engHours meter-typo hazard: a corrected log entry can't lower
	/// the high-water mark, so a fat-fingered reading otherwise inflates every installed
	/// part's derived life silently.
	static let implausibleAccrualHours: Float = 3000

	static func accruedHours(
		installMeter: Float,
		installMeterKnown: Bool,
		currentMeter: MeterReading
	) -> (hours: Float, flags: Set<PartTimeFlag>) {
		guard currentMeter.known, currentMeter.hours > 0 else { return (0, [.noCurrentMeterReading]) }
		guard installMeterKnown else { return (0, [.noInstallSnapshot]) }
		let delta = currentMeter.hours - installMeter
		if delta < 0 { return (0, [.installSnapshotAheadOfMeter]) }
		if delta > implausibleAccrualHours { return (delta, [.implausibleAccrual]) }
		return (delta, [])
	}

	static func accruedCycles(installCycles: Int, currentCycles: Int) -> Int {
		max(0, currentCycles - installCycles)
	}

	/// The part's full time position. An open segment wins; then the frozen closing
	/// balances of the latest closed segment; then MxParts1's manual carry-in.
	static func snapshot(
		carryIn: PartCarryIn,
		openSegment: InstallSegment?,
		latestClosedSegment: InstallSegment?,
		currentMeter: MeterReading
	) -> PartTimeSnapshot {
		if let open = openSegment {
			let (accrued, hourFlags) = accruedHours(
				installMeter: open.installMeterHours,
				installMeterKnown: open.installMeterKnown,
				currentMeter: currentMeter
			)
			let accruedCyc = accruedCycles(installCycles: open.installMeterCycles, currentCycles: currentMeter.cycles)
			var flags = hourFlags
			if !open.meterTimeBase.isEmpty, !carryIn.limitTimeBase.isEmpty, open.meterTimeBase != carryIn.limitTimeBase {
				flags.insert(.timeBaseMismatch)
			}
			// TSN/TSO/TSR accrue at the same rate within one segment — they only diverge via
			// their opening balances (set at the install/overhaul boundary), never mid-segment.
			return PartTimeSnapshot(
				tsn: open.openingTSN + accrued,
				csn: open.openingCSN + accruedCyc,
				tso: open.openingTSO + accrued,
				cso: open.openingCSO + accruedCyc,
				tsr: open.openingTSR + accrued,
				accruedThisInstall: accrued,
				accruedCyclesThisInstall: accruedCyc,
				isInstalled: true,
				vehicleId: open.vehicleId,
				position: open.position,
				installDate: open.installDate,
				effectiveTimeBase: open.meterTimeBase.isEmpty ? currentMeter.timeBase : open.meterTimeBase,
				provenance: .openInstallation,
				flags: flags
			)
		} else if let closed = latestClosedSegment {
			return PartTimeSnapshot(
				tsn: closed.closingTSN,
				csn: closed.closingCSN,
				tso: closed.closingTSO,
				cso: closed.closingCSO,
				tsr: closed.closingTSR,
				accruedThisInstall: 0,
				accruedCyclesThisInstall: 0,
				isInstalled: false,
				vehicleId: closed.vehicleId,
				position: closed.position,
				installDate: closed.installDate,
				effectiveTimeBase: closed.meterTimeBase,
				provenance: .closedInstallation,
				flags: []
			)
		} else {
			return PartTimeSnapshot(
				tsn: carryIn.tsn,
				csn: carryIn.csn,
				tso: carryIn.tso,
				cso: carryIn.cso,
				tsr: carryIn.tsr,
				accruedThisInstall: 0,
				accruedCyclesThisInstall: 0,
				isInstalled: false,
				vehicleId: "",
				position: "",
				installDate: nil,
				effectiveTimeBase: carryIn.limitTimeBase,
				provenance: .manualCarryIn,
				flags: []
			)
		}
	}

	/// Remaining life against a declared limit. `nil` when no limit is set, or for
	/// `.inspectionInterval` — part-level inspection intervals are expressed as an
	/// MxItems3 service item linked to the part instead, reusing recomputeNextDue rather
	/// than duplicating that machinery here.
	static func remaining(
		snapshot: PartTimeSnapshot,
		limitType: String,
		limitHours: Float,
		limitCycles: Int,
		limitCalendarMonths: Int,
		installDate: Date?,
		asOf: Date = Date()
	) -> PartLifeRemaining? {
		guard let type = PartLimitType(rawValue: limitType),
			  type != .none, type != .inspectionInterval else { return nil }

		// A hard life limit and on-condition both track total life (TSN); a TBO tracks
		// time since the last overhaul (TSO) — the whole reason PartInstallation carries
		// both counters separately rather than one "time" field.
		let basisHours = (type == .overhaulTBO) ? snapshot.tso : snapshot.tsn
		let basisCycles = (type == .overhaulTBO) ? snapshot.cso : snapshot.csn

		let remainingHours: Float? = limitHours > 0 ? (limitHours - basisHours) : nil
		let remainingCycles: Int? = limitCycles > 0 ? (limitCycles - basisCycles) : nil

		var remainingCalendarDays: Int? = nil
		if limitCalendarMonths > 0, let start = installDate {
			let dueDate = Calendar.current.date(byAdding: .month, value: limitCalendarMonths, to: start) ?? start
			remainingCalendarDays = Calendar.current.dateComponents([.day], from: asOf, to: dueDate).day
		}

		let isOverdue = (remainingHours ?? .greatestFiniteMagnitude) <= 0
			|| (remainingCycles ?? Int.max) <= 0
			|| (remainingCalendarDays ?? Int.max) <= 0

		return PartLifeRemaining(
			limitType: limitType,
			isRegulatoryLimit: type.isRegulatoryLimit,
			remainingHours: remainingHours,
			remainingCycles: remainingCycles,
			remainingCalendarDays: remainingCalendarDays,
			isOverdue: isOverdue
		)
	}

	/// Balances to freeze when a removal is recorded. Called exactly once, from
	/// EditPartInstallation's save path — never from a read path, since this is history,
	/// not a cache.
	static func closingBalances(
		for segment: InstallSegment,
		removalMeterHours: Float,
		removalMeterCycles: Int
	) -> (tsn: Float, csn: Int, tso: Float, cso: Int, tsr: Float) {
		let (accrued, _) = accruedHours(
			installMeter: segment.installMeterHours,
			installMeterKnown: segment.installMeterKnown,
			currentMeter: MeterReading(hours: removalMeterHours, known: true, cycles: removalMeterCycles, timeBase: segment.meterTimeBase)
		)
		let accruedCyc = accruedCycles(installCycles: segment.installMeterCycles, currentCycles: removalMeterCycles)
		return (
			segment.openingTSN + accrued,
			segment.openingCSN + accruedCyc,
			segment.openingTSO + accrued,
			segment.openingCSO + accruedCyc,
			segment.openingTSR + accrued
		)
	}

	/// Opening balances for a new installation. `zeroTSN`/`zeroTSO`/`zeroTSR` are the
	/// user's explicit declarations in the install sheet (rebuilt to zero time per 14 CFR
	/// 43.2(b), or installed after an overhaul/repair) — never inferred.
	static func openingBalances(
		carryIn: PartCarryIn,
		previousSegment: InstallSegment?,
		zeroTSN: Bool,
		zeroTSO: Bool,
		zeroTSR: Bool
	) -> (tsn: Float, csn: Int, tso: Float, cso: Int, tsr: Float) {
		let baseTSN = previousSegment?.closingTSN ?? carryIn.tsn
		let baseCSN = previousSegment?.closingCSN ?? carryIn.csn
		let baseTSO = previousSegment?.closingTSO ?? carryIn.tso
		let baseCSO = previousSegment?.closingCSO ?? carryIn.cso
		let baseTSR = previousSegment?.closingTSR ?? carryIn.tsr
		return (
			zeroTSN ? 0 : baseTSN,
			zeroTSN ? 0 : baseCSN,
			zeroTSO ? 0 : baseTSO,
			zeroTSO ? 0 : baseCSO,
			zeroTSR ? 0 : baseTSR
		)
	}
}

// MARK: - SwiftData fetch layer (mirrors Functions.loadVehicleDetails's shape)

extension Functions {
	/// The single declared meter for an aircraft, plus cycles derived by summing
	/// TripLog2.landings rather than a high-water mark (a landing count is an increment,
	/// not a meter reading — see Vehicle8.cyclesAtEntry).
	func loadVehicleMeter(context: ModelContext, vehicleId: String) -> MeterReading {
		guard !vehicleId.isEmpty else { return MeterReading() }
		var fd = FetchDescriptor<Vehicle8>(predicate: #Predicate { $0.name == vehicleId })
		fd.fetchLimit = 1
		guard let vehicle = (try? context.fetch(fd))?.first else { return MeterReading() }

		let tripsFD = FetchDescriptor<TripLog2>(predicate: #Predicate { $0.vehicleId == vehicleId })
		let landings = ((try? context.fetch(tripsFD)) ?? []).reduce(0) { $0 + $1.landings }

		return MeterReading(
			hours: vehicle.engHours,
			known: vehicle.engHours > 0,
			cycles: vehicle.cyclesAtEntry + landings,
			timeBase: vehicle.hoursMeterType
		)
	}

	/// Every part currently installed on a vehicle (open PartInstallation segments).
	func loadInstalledParts(context: ModelContext, vehicleId: String) -> [PartInstallation] {
		let fd = FetchDescriptor<PartInstallation>(
			predicate: #Predicate { $0.vehicleId == vehicleId && $0.removalDate == nil },
			sortBy: [SortDescriptor(\PartInstallation.position)]
		)
		return (try? context.fetch(fd)) ?? []
	}

	/// Every install/removal segment for a part, newest first.
	func loadInstallationHistory(context: ModelContext, partName: String) -> [PartInstallation] {
		let fd = FetchDescriptor<PartInstallation>(
			predicate: #Predicate { $0.partName == partName },
			sortBy: [SortDescriptor(\PartInstallation.installDate, order: .reverse)]
		)
		return (try? context.fetch(fd)) ?? []
	}

	func loadPartTimeSnapshot(context: ModelContext, part: MxParts1) -> PartTimeSnapshot {
		let history = loadInstallationHistory(context: context, partName: part.partName)
		let open = history.first(where: { $0.removalDate == nil })
		let latestClosed = history.first(where: { $0.removalDate != nil })
		let meter = open.map { loadVehicleMeter(context: context, vehicleId: $0.vehicleId) } ?? MeterReading()
		let carryIn = PartCarryIn(
			tsn: part.carryInTSN, csn: part.carryInCSN, tso: part.carryInTSO, cso: part.carryInCSO,
			tsr: part.carryInTSR, limitTimeBase: part.limitTimeBase
		)
		return PartTimeMath.snapshot(
			carryIn: carryIn,
			openSegment: open.map(InstallSegment.init(model:)),
			latestClosedSegment: latestClosed.map(InstallSegment.init(model:)),
			currentMeter: meter
		)
	}

	/// Batch form for lists/dashboard/reports — fetch cost scales with distinct vehicles
	/// and installation rows, never with part count, so a large parts catalog stays cheap.
	func loadPartTimeSnapshots(context: ModelContext, parts: [MxParts1]) -> [String: PartTimeSnapshot] {
		let installFD = FetchDescriptor<PartInstallation>(sortBy: [SortDescriptor(\PartInstallation.installDate, order: .reverse)])
		let installations = (try? context.fetch(installFD)) ?? []
		let byPart = Dictionary(grouping: installations, by: { $0.partName })

		var meters: [String: MeterReading] = [:]
		for vehicleId in Set(installations.map { $0.vehicleId }) where !vehicleId.isEmpty {
			meters[vehicleId] = loadVehicleMeter(context: context, vehicleId: vehicleId)
		}

		var result: [String: PartTimeSnapshot] = [:]
		for part in parts {
			let history = byPart[part.partName] ?? []
			let open = history.first(where: { $0.removalDate == nil })
			let latestClosed = history.first(where: { $0.removalDate != nil })
			let meter = open.flatMap { meters[$0.vehicleId] } ?? MeterReading()
			let carryIn = PartCarryIn(
				tsn: part.carryInTSN, csn: part.carryInCSN, tso: part.carryInTSO, cso: part.carryInCSO,
				tsr: part.carryInTSR, limitTimeBase: part.limitTimeBase
			)
			result[part.partName] = PartTimeMath.snapshot(
				carryIn: carryIn,
				openSegment: open.map(InstallSegment.init(model:)),
				latestClosedSegment: latestClosed.map(InstallSegment.init(model:)),
				currentMeter: meter
			)
		}
		return result
	}
}

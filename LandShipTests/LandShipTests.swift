//
//  LandShipTests.swift
//  LandShipTests
//
//  Scenario tests for PartTimeMath — pure value-type math with no ModelContext, so it's
//  testable in isolation. This matters specifically because RenderPreview and
//  RunCodeSnippet are both broken in this dev environment (sandboxed JIT permission
//  error), making a real test target the only working way to execute Swift here.
//

import Testing
@testable import LandShip

struct PartTimeMathTests {

	// Position change on the same aircraft: close at current meter, open a new segment
	// at the same meter. Accrual should be continuous with zero gap.
	@Test func sameAircraftPositionChange() async throws {
		let currentMeter = MeterReading(hours: 1500, known: true, cycles: 0, timeBase: "Hobbs Time")
		let closedSegment = InstallSegment(
			installDate: Date(timeIntervalSinceNow: -1000), installMeterHours: 1000, installMeterKnown: true,
			openingTSN: 500,
			removalDate: Date(timeIntervalSinceNow: -100), removalMeterHours: 1400, removalMeterKnown: true,
			closingTSN: 900, closingTSO: 900,
			vehicleId: "N12345", position: "LH Mag", meterTimeBase: "Hobbs Time"
		)
		let openSegment = InstallSegment(
			installDate: Date(timeIntervalSinceNow: -100), installMeterHours: 1400, installMeterKnown: true,
			openingTSN: 900, openingTSO: 900,
			vehicleId: "N12345", position: "RH Mag", meterTimeBase: "Hobbs Time"
		)

		let snapshot = PartTimeMath.snapshot(carryIn: PartCarryIn(), openSegment: openSegment, latestClosedSegment: closedSegment, currentMeter: currentMeter)
		#expect(snapshot.tsn == 1000) // 900 opening + (1500 - 1400) accrued
		#expect(snapshot.isInstalled)
		#expect(snapshot.provenance == .openInstallation)
	}

	// Moved to another aircraft: opening balances carry from the prior segment's closing
	// balances, and the new segment reads THAT aircraft's meter — no special case needed.
	@Test func crossAircraftMove() async throws {
		let closedOnOldAircraft = InstallSegment(
			installDate: Date(timeIntervalSinceNow: -5000), installMeterHours: 1000, installMeterKnown: true,
			openingTSN: 0,
			removalDate: Date(timeIntervalSinceNow: -1000), removalMeterHours: 1800, removalMeterKnown: true,
			closingTSN: 800,
			vehicleId: "N11111", position: "Alternator", meterTimeBase: "Hobbs Time"
		)
		let openOnNewAircraft = InstallSegment(
			installDate: Date(timeIntervalSinceNow: -1000), installMeterHours: 500, installMeterKnown: true,
			openingTSN: 800,
			vehicleId: "N22222", position: "Alternator", meterTimeBase: "Hobbs Time"
		)
		let newAircraftMeter = MeterReading(hours: 550, known: true, cycles: 0, timeBase: "Hobbs Time")

		let snapshot = PartTimeMath.snapshot(carryIn: PartCarryIn(), openSegment: openOnNewAircraft, latestClosedSegment: closedOnOldAircraft, currentMeter: newAircraftMeter)
		#expect(snapshot.tsn == 850) // 800 + (550 - 500)
		#expect(snapshot.vehicleId == "N22222")
	}

	// Removed and shelved, not yet reinstalled: no open segment, so the part's time is
	// exactly the frozen closing balance — a pure historical assertion, not a live read.
	@Test func shelvedAfterRemoval() async throws {
		let closed = InstallSegment(
			installDate: Date(timeIntervalSinceNow: -5000), installMeterHours: 1000, installMeterKnown: true,
			openingTSN: 0,
			removalDate: Date(timeIntervalSinceNow: -1000), removalMeterHours: 1300, removalMeterKnown: true,
			closingTSN: 300,
			vehicleId: "N33333", position: "Vacuum Pump", meterTimeBase: "Hobbs Time"
		)
		let snapshot = PartTimeMath.snapshot(carryIn: PartCarryIn(tsn: 999), openSegment: nil, latestClosedSegment: closed, currentMeter: MeterReading())
		#expect(snapshot.tsn == 300)
		#expect(!snapshot.isInstalled)
		#expect(snapshot.provenance == .closedInstallation)
	}

	// Overhaul zeroing TSO but not TSN: openingTSO resets to 0, openingTSN carries forward.
	@Test func overhaulZeroesTSOOnly() async throws {
		let opening = PartTimeMath.openingBalances(
			carryIn: PartCarryIn(),
			previousSegment: InstallSegment(installDate: Date(), installMeterHours: 0, installMeterKnown: false, closingTSN: 1200, closingTSO: 1200),
			zeroTSN: false, zeroTSO: true, zeroTSR: false
		)
		#expect(opening.tsn == 1200)
		#expect(opening.tso == 0)
	}

	// Rebuilt to zero time (14 CFR 43.2(b)): both TSN and TSO reset.
	@Test func rebuiltToZeroTime() async throws {
		let opening = PartTimeMath.openingBalances(
			carryIn: PartCarryIn(),
			previousSegment: InstallSegment(installDate: Date(), installMeterHours: 0, installMeterKnown: false, closingTSN: 1200, closingTSO: 1200),
			zeroTSN: true, zeroTSO: true, zeroTSR: false
		)
		#expect(opening.tsn == 0)
		#expect(opening.tso == 0)
	}

	// Never installed via the app: falls back to MxParts1's carry-in fields.
	@Test func noSegmentsFallsBackToCarryIn() async throws {
		let carryIn = PartCarryIn(tsn: 1200, csn: 400, tso: 0, cso: 0, tsr: 0, limitTimeBase: "Hobbs Time")
		let snapshot = PartTimeMath.snapshot(carryIn: carryIn, openSegment: nil, latestClosedSegment: nil, currentMeter: MeterReading())
		#expect(snapshot.tsn == 1200)
		#expect(snapshot.csn == 400)
		#expect(snapshot.provenance == .manualCarryIn)
	}

	// Install meter reading ahead of the current aircraft meter (data-entry error): accrual
	// clamps to 0 and the flag is set — never a negative TSN.
	@Test func installSnapshotAheadOfMeterIsFlagged() async throws {
		let (hours, flags) = PartTimeMath.accruedHours(installMeter: 2000, installMeterKnown: true, currentMeter: MeterReading(hours: 1500, known: true))
		#expect(hours == 0)
		#expect(flags.contains(.installSnapshotAheadOfMeter))
	}

	// No current meter reading at all: flagged, not silently zero.
	@Test func unknownCurrentMeterIsFlagged() async throws {
		let (hours, flags) = PartTimeMath.accruedHours(installMeter: 1000, installMeterKnown: true, currentMeter: MeterReading(hours: 0, known: false))
		#expect(hours == 0)
		#expect(flags.contains(.noCurrentMeterReading))
	}

	// Time-base mismatch between the aircraft's declared meter and the part's limit basis
	// is surfaced as a flag rather than a silently-wrong remaining-life number.
	@Test func timeBaseMismatchIsFlagged() async throws {
		let currentMeter = MeterReading(hours: 1100, known: true, timeBase: "Hobbs Time")
		let openSegment = InstallSegment(installDate: Date(), installMeterHours: 1000, installMeterKnown: true, meterTimeBase: "Hobbs Time")
		let snapshot = PartTimeMath.snapshot(carryIn: PartCarryIn(limitTimeBase: "Tach Time"), openSegment: openSegment, latestClosedSegment: nil, currentMeter: currentMeter)
		#expect(snapshot.flags.contains(.timeBaseMismatch))
	}

	// Accrual well beyond a typical piston TBO run on a single install segment is flagged
	// as implausible rather than trusted outright — the guardrail against the
	// Vehicle8.engHours meter-typo hazard (a corrected log can't lower the high-water mark).
	@Test func implausibleAccrualIsFlagged() async throws {
		let (hours, flags) = PartTimeMath.accruedHours(installMeter: 100, installMeterKnown: true, currentMeter: MeterReading(hours: 100 + PartTimeMath.implausibleAccrualHours + 1, known: true))
		#expect(hours > PartTimeMath.implausibleAccrualHours)
		#expect(flags.contains(.implausibleAccrual))
	}
}

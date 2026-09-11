//
//  25 PartInstallation.swift
//  LandShip
//
//  One row per install→removal segment for a part (MxParts1.partName), linked to the
//  vehicle it's installed on by vehicleId. removalDate == nil marks the open (current)
//  segment. Each segment stores the part's TSN/TSO/TSR/cycle counters as of the START
//  of the segment (opening*) and freezes them again when the segment closes (closing*) —
//  derivation is one segment deep, never a fold over history. See PartTimeMath.swift for
//  the math and multi-vertical-expansion memory for the design rationale (cross-aircraft
//  moves, overhaul zeroing, shelf-then-reinstall all fall out of this shape for free).
//  AeroTrax only (see Vertical.enabledFeatures) — additive model, not used by land or marine.
//

import Foundation
import SwiftData

@Model
class PartInstallation {
	var inactive: Bool = false

	// Name links (LandShip convention — see name-based-linking-decision memory). Both
	// need rename-cascade legs in EditParts.swift / EditVehicle.swift.
	var partName: String = ""              // MxParts1.partName
	var vehicleId: String = ""             // Vehicle8.name
	var position: String = ""              // "Left Magneto", "Nose Gear" — free text
	var nextHigherAssembly: String = ""    // free text, deliberately not a link — see
	                                        // ComponentTimes, which has no rename cascade

	// Segment open
	var installDate: Date = Date()
	var installMeterHours: Float = 0
	var installMeterKnown: Bool = false    // distinguishes "0.0 hours" from "not recorded"
	var installMeterCycles: Int = 0
	var installedBy: String = ""
	var meterTimeBase: String = ""         // Vehicle8.hoursMeterType captured at install

	// Opening balances — the part's counters as of installDate
	var openingTSN: Float = 0
	var openingCSN: Int = 0
	var openingTSO: Float = 0
	var openingCSO: Int = 0
	var openingTSR: Float = 0
	var zeroedTSOAtInstall: Bool = false   // provenance: installed after overhaul
	var zeroedTSNAtInstall: Bool = false   // provenance: rebuilt to zero time, 14 CFR 43.2(b)
	var zeroedTSRAtInstall: Bool = false   // provenance: installed after repair

	// Segment close. nil == currently installed.
	var removalDate: Date?
	var removalMeterHours: Float = 0
	var removalMeterKnown: Bool = false
	var removalMeterCycles: Int = 0
	var removalReason: String = ""
	var removedBy: String = ""

	// Frozen closing balances — written exactly once, by the removal save path. This is
	// a historical assertion ("this magneto had 2,143.6 TSN when it came off"), which is
	// what 14 CFR 91.417(a)(2)(i) wants retained — not a cache of a live computation.
	var closingTSN: Float = 0
	var closingCSN: Int = 0
	var closingTSO: Float = 0
	var closingCSO: Int = 0
	var closingTSR: Float = 0

	var notes: String = ""
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	/// Non-persisted. `#Predicate` fetches must compare `removalDate == nil` directly
	/// rather than calling this computed property.
	var isInstalled: Bool { removalDate == nil }

	init(
		vehicleId: String = "",
		partName: String = "",
		position: String = "",
		nextHigherAssembly: String = "",
		installDate: Date = Date(),
		installMeterHours: Float = 0,
		installMeterKnown: Bool = false,
		installMeterCycles: Int = 0,
		installedBy: String = "",
		meterTimeBase: String = "",
		openingTSN: Float = 0,
		openingCSN: Int = 0,
		openingTSO: Float = 0,
		openingCSO: Int = 0,
		openingTSR: Float = 0,
		zeroedTSOAtInstall: Bool = false,
		zeroedTSNAtInstall: Bool = false,
		zeroedTSRAtInstall: Bool = false,
		removalDate: Date? = nil,
		removalMeterHours: Float = 0,
		removalMeterKnown: Bool = false,
		removalMeterCycles: Int = 0,
		removalReason: String = "",
		removedBy: String = "",
		closingTSN: Float = 0,
		closingCSN: Int = 0,
		closingTSO: Float = 0,
		closingCSO: Int = 0,
		closingTSR: Float = 0,
		notes: String = "",
		image1: Data? = nil,
		image1Description: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.partName = partName
		self.position = position
		self.nextHigherAssembly = nextHigherAssembly
		self.installDate = installDate
		self.installMeterHours = installMeterHours
		self.installMeterKnown = installMeterKnown
		self.installMeterCycles = installMeterCycles
		self.installedBy = installedBy
		self.meterTimeBase = meterTimeBase
		self.openingTSN = openingTSN
		self.openingCSN = openingCSN
		self.openingTSO = openingTSO
		self.openingCSO = openingCSO
		self.openingTSR = openingTSR
		self.zeroedTSOAtInstall = zeroedTSOAtInstall
		self.zeroedTSNAtInstall = zeroedTSNAtInstall
		self.zeroedTSRAtInstall = zeroedTSRAtInstall
		self.removalDate = removalDate
		self.removalMeterHours = removalMeterHours
		self.removalMeterKnown = removalMeterKnown
		self.removalMeterCycles = removalMeterCycles
		self.removalReason = removalReason
		self.removedBy = removedBy
		self.closingTSN = closingTSN
		self.closingCSN = closingCSN
		self.closingTSO = closingTSO
		self.closingCSO = closingCSO
		self.closingTSR = closingTSR
		self.notes = notes
		self.image1 = image1
		self.image1Description = image1Description
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

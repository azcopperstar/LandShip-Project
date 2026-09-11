//
//  ATAChapters.swift
//  LandShip
//
//  Static reference table for ATA 100 / iSpec 2200 chapter numbers, used to classify
//  parts (MxParts1.ataChapter) so parts, ADs, manual references and maintenance entries
//  sort together. Deliberately data, not an enum: nothing branches on the chapter, an
//  80-item inline Picker is unusable on iPhone, and owners legitimately need sub-chapters
//  ("74-10 Ignition Harness") that a fixed CaseIterable can't express without ballooning.
//  AeroTrax only. Optional and de-emphasized in the UI — most GA owners won't use it.
//

import Foundation

struct ATAChapter: Identifiable, Hashable {
	let code: String       // "74" or "74-10"
	let title: String      // "Ignition" or "Ignition Harness"
	let group: Group

	var id: String { code }
	var displayName: String { "\(code) — \(title)" }

	enum Group: String, CaseIterable, Hashable {
		case general = "General"
		case airframeSystems = "Airframe Systems"
		case structures = "Structures"
		case propulsion = "Propulsion"
	}

	static let all: [ATAChapter] = [
		// General
		ATAChapter(code: "00", title: "General", group: .general),
		ATAChapter(code: "04", title: "Airworthiness Limitations", group: .general),
		ATAChapter(code: "05", title: "Time Limits / Maintenance Checks", group: .general),
		ATAChapter(code: "06", title: "Dimensions and Areas", group: .general),
		ATAChapter(code: "07", title: "Lifting and Shoring", group: .general),
		ATAChapter(code: "08", title: "Leveling and Weighing", group: .general),
		ATAChapter(code: "09", title: "Towing and Taxiing", group: .general),
		ATAChapter(code: "10", title: "Parking, Mooring, Storage", group: .general),
		ATAChapter(code: "11", title: "Placards and Markings", group: .general),
		ATAChapter(code: "12", title: "Servicing", group: .general),

		// Airframe systems
		ATAChapter(code: "20", title: "Standard Practices — Airframe", group: .airframeSystems),
		ATAChapter(code: "21", title: "Air Conditioning", group: .airframeSystems),
		ATAChapter(code: "22", title: "Auto Flight", group: .airframeSystems),
		ATAChapter(code: "23", title: "Communications", group: .airframeSystems),
		ATAChapter(code: "24", title: "Electrical Power", group: .airframeSystems),
		ATAChapter(code: "25", title: "Equipment / Furnishings", group: .airframeSystems),
		ATAChapter(code: "26", title: "Fire Protection", group: .airframeSystems),
		ATAChapter(code: "27", title: "Flight Controls", group: .airframeSystems),
		ATAChapter(code: "28", title: "Fuel", group: .airframeSystems),
		ATAChapter(code: "29", title: "Hydraulic Power", group: .airframeSystems),
		ATAChapter(code: "30", title: "Ice and Rain Protection", group: .airframeSystems),
		ATAChapter(code: "31", title: "Indicating / Recording Systems", group: .airframeSystems),
		ATAChapter(code: "32", title: "Landing Gear", group: .airframeSystems),
		ATAChapter(code: "32-10", title: "Main Gear and Doors", group: .airframeSystems),
		ATAChapter(code: "32-20", title: "Nose Gear and Doors", group: .airframeSystems),
		ATAChapter(code: "32-40", title: "Wheels and Brakes", group: .airframeSystems),
		ATAChapter(code: "32-45", title: "Tires and Tubes", group: .airframeSystems),
		ATAChapter(code: "33", title: "Lights", group: .airframeSystems),
		ATAChapter(code: "34", title: "Navigation", group: .airframeSystems),
		ATAChapter(code: "35", title: "Oxygen", group: .airframeSystems),
		ATAChapter(code: "36", title: "Pneumatic", group: .airframeSystems),
		ATAChapter(code: "38", title: "Water / Waste", group: .airframeSystems),
		ATAChapter(code: "39", title: "Electrical / Electronic Panels", group: .airframeSystems),

		// Structures
		ATAChapter(code: "51", title: "Standard Practices / Structures", group: .structures),
		ATAChapter(code: "52", title: "Doors", group: .structures),
		ATAChapter(code: "53", title: "Fuselage", group: .structures),
		ATAChapter(code: "54", title: "Nacelles / Pylons", group: .structures),
		ATAChapter(code: "55", title: "Stabilizers", group: .structures),
		ATAChapter(code: "56", title: "Windows", group: .structures),
		ATAChapter(code: "57", title: "Wings", group: .structures),

		// Propulsion
		ATAChapter(code: "60", title: "Standard Practices — Engine", group: .propulsion),
		ATAChapter(code: "61", title: "Propellers/Propulsors", group: .propulsion),
		ATAChapter(code: "61-10", title: "Propeller Assembly", group: .propulsion),
		ATAChapter(code: "61-20", title: "Controlling", group: .propulsion),
		ATAChapter(code: "62", title: "Main Rotor(s)", group: .propulsion),
		ATAChapter(code: "63", title: "Main Rotor Drive", group: .propulsion),
		ATAChapter(code: "64", title: "Tail Rotor", group: .propulsion),
		ATAChapter(code: "65", title: "Tail Rotor Drive", group: .propulsion),
		ATAChapter(code: "66", title: "Folding Blades / Pylon", group: .propulsion),
		ATAChapter(code: "67", title: "Rotors Flight Control", group: .propulsion),
		ATAChapter(code: "71", title: "Power Plant", group: .propulsion),
		ATAChapter(code: "72", title: "Engine (Turbine/Turboprop)", group: .propulsion),
		ATAChapter(code: "72-10", title: "Reciprocating Engine", group: .propulsion),
		ATAChapter(code: "73", title: "Engine Fuel and Control", group: .propulsion),
		ATAChapter(code: "74", title: "Ignition", group: .propulsion),
		ATAChapter(code: "74-10", title: "Magnetos", group: .propulsion),
		ATAChapter(code: "74-20", title: "Spark Plugs and Harness", group: .propulsion),
		ATAChapter(code: "75", title: "Bleed Air", group: .propulsion),
		ATAChapter(code: "76", title: "Engine Controls", group: .propulsion),
		ATAChapter(code: "77", title: "Engine Indicating", group: .propulsion),
		ATAChapter(code: "78", title: "Exhaust", group: .propulsion),
		ATAChapter(code: "79", title: "Oil", group: .propulsion),
		ATAChapter(code: "80", title: "Starting", group: .propulsion),
		ATAChapter(code: "81", title: "Turbines (Reciprocating Engine)", group: .propulsion),
		ATAChapter(code: "82", title: "Water Injection", group: .propulsion),
		ATAChapter(code: "83", title: "Accessory Gear Boxes", group: .propulsion),
		ATAChapter(code: "84", title: "Propulsion Augmentation", group: .propulsion),
		ATAChapter(code: "85", title: "Fuel Cell Systems", group: .propulsion),
	]
}

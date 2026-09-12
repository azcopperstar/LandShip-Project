//
//  Enums.swift
//  LandShip
//
//  Created by JP on 10/5/25.
//

import Foundation
import SwiftUI

// Sidebar item identifiers for selection
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
	case dashboard
	case vehicles
	case parts
	case fuelLog
	case tripLog
	case pilotLogbook
	case seaService
	case records
	case items
	case systems
	case vendors
	case settings
	case backup
	case restore
	case additions
	case subscriptions
	case projectList
	case punchList
	case livePunchList
	case displayChecklist
	// Non-link resources/help is not part of selection (sheet/button)
	var id: String { rawValue }
}

// Fields that can be mirrored from a master Vehicle8 record onto a linked
// "aspect" record (e.g. Chassis, Engine, Body/House). The user chooses which
// of these to sync per linked record via a checkable picker in EditVehicle.
enum LinkableVehicleField: String, CaseIterable, Identifiable, Hashable {
	case odometer
	case engineHours
	case location
	case owner
	case insurance
	case vin
	case licensePlate
	case titleNumber

	var id: String { rawValue }

	var displayName: String {
		switch self {
			case .odometer: return "Odometer"
			case .engineHours: return "Engine Hours"
			case .location: return "Location"
			case .owner: return "Owner"
			case .insurance: return "Insurance Information"
			case .vin: return "VIN"
			case .licensePlate: return "License Plate"
			case .titleNumber: return "Title Number"
		}
	}

	var summary: String {
		switch self {
			case .odometer: return "Mirrors odometer and virtual odometer readings."
			case .engineHours: return "Mirrors current engine hours."
			case .location: return "Mirrors the \(Vertical.current.assetSingular.lowercased())'s location."
			case .owner: return "Mirrors the \(Vertical.current.assetSingular.lowercased())'s owner."
			case .insurance: return "Mirrors insurance provider, policy #, holder, and expiration."
			case .vin: return "Mirrors the VIN."
			case .licensePlate: return "Mirrors the license plate number."
			case .titleNumber: return "Mirrors the title number."
		}
	}
}

// Cards available on the Dashboard. The user chooses which are shown, in what
// order, via DashboardConfigView; the scheme is persisted on Settings1.
// rawValue is persisted — never rename or reorder cases without a migration.
enum DashboardCard: String, CaseIterable, Identifiable, Hashable {
	case maintenanceStatus
	case nextServiceDue
	case tripGroups
	case fleetSnapshot
	case insurance
	case warranty
	case quickActions
	case recentService
	case usageSinceLast
	case systemHotlist
	case costSnapshot
	case additionsCost
	case inventoryStatus

	var id: String { rawValue }

	/// "Fleet" reads naturally for land vehicles even with one owner; other verticals
	/// read better with their own asset word ("Aircraft Snapshot", not "Fleet Snapshot").
	private static var fleetWord: String {
		Vertical.current.id == .land ? "Fleet" : Vertical.current.assetPlural
	}

	var displayName: String {
		switch self {
			case .maintenanceStatus: return "\(Self.fleetWord) Maintenance Status"
			case .nextServiceDue: return "Next Service Due"
			case .tripGroups: return "Trip Groups"
			case .fleetSnapshot: return "\(Self.fleetWord) Snapshot"
			case .insurance: return "Insurance & Recurring Costs"
			case .warranty: return "Warranties"
			case .quickActions: return "Quick Actions"
			case .recentService: return "Recently Completed Service"
			case .usageSinceLast: return "Usage Since Last Service"
			case .systemHotlist: return "System Hotlist"
			case .costSnapshot: return "Maintenance Cost Snapshot"
			case .additionsCost: return "Additions Cost by Category"
			case .inventoryStatus: return "Inventory Status"
		}
	}

	var summary: String {
		switch self {
			case .maintenanceStatus: return "Overdue/due-soon status per \(Vertical.current.assetSingular.lowercased())."
			case .nextServiceDue: return "Most urgent upcoming service items."
			case .tripGroups: return "Trips grouped by trip name/tag."
			case .fleetSnapshot: return Vertical.current.id == .land
				? "Fleet counts, mileage, and maintenance cost totals."
				: "\(Self.fleetWord) counts, \(Vertical.current.primaryMeterLabel.lowercased()), and maintenance cost totals."
			case .insurance: return "Recurring subscription costs and insurance expirations."
			case .warranty: return Vertical.current.id == .land
				? "Warranty expiration and mileage-limit status."
				: "Warranty expiration and usage-limit status."
			case .quickActions: return "Shortcuts to add records."
			case .recentService: return "Most recently completed service records."
			case .usageSinceLast: return "Miles/hours accumulated since each \(Vertical.current.assetSingular.lowercased())'s last service."
			case .systemHotlist: return "\(Vertical.current.assetSingular) systems with the most overdue/due-soon items."
			case .costSnapshot: return "Month-to-date, 90-day, and year-to-date maintenance costs."
			case .additionsCost: return "Improvement/addition spending by category."
			case .inventoryStatus: return "Inventory-tracked parts that are low or out of stock."
		}
	}

	var icon: String {
		switch self {
			case .maintenanceStatus: return "wrench.and.screwdriver.fill"
			case .nextServiceDue: return "wrench.and.screwdriver.fill"
			case .tripGroups: return "map.fill"
			case .fleetSnapshot: return Vertical.current.assetGroupIcon
			case .insurance: return "shield.lefthalf.filled"
			case .warranty: return "checkmark.seal.fill"
			case .quickActions: return "plus.circle.fill"
			case .recentService: return "clock.arrow.circlepath"
			case .usageSinceLast: return "speedometer"
			case .systemHotlist: return "flame.fill"
			case .costSnapshot: return "dollarsign.circle.fill"
			case .additionsCost: return "plus.square.on.square"
			case .inventoryStatus: return "shippingbox.fill"
		}
	}

	/// Cards shown before the user configures anything — matches the dashboard's original hardcoded order.
	static let defaultOrder: [DashboardCard] = [
		.maintenanceStatus, .nextServiceDue, .tripGroups,
		.fleetSnapshot, .insurance, .warranty, .quickActions
	]
}

// Aviation fuel types offered by the Fuel Type picker (Edit Vehicle / Edit Fuel Log)
// when Vertical.current.id == .aviation. rawValue is both the persisted Vehicle8/FuelLog1
// fuelType string and the value stored in Settings1.enabledFuelTypesRaw — never rename
// or remove a case without a migration for both.
enum AviationFuelType: String, CaseIterable, Identifiable, Hashable {
	case avgas100LL = "100LL"
	case ul94 = "UL94"
	case ul9196 = "91/96 UL"
	case ul91 = "UL91"
	case mogas = "Mogas"

	case g100UL = "G100UL"
	case swift100R = "100R"
	case ul100E = "UL100E"

	case jetA = "Jet A"
	case jetA1 = "Jet A-1"
	case jetB = "Jet B"
	case ts1 = "TS-1"
	case no3JetFuel = "No. 3 Jet Fuel"

	case jp4 = "JP-4"
	case jp5 = "JP-5"
	case jp8 = "JP-8"
	case f24 = "F-24"
	case f35 = "F-35"
	case jp7 = "JP-7"
	case jpts = "JPTS"
	case jp10 = "JP-10"

	case saf = "SAF"
	case hydrogen = "Hydrogen"
	case lngMethane = "LNG/Methane"
	case batteryElectric = "Battery-Electric"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case pistonCurrent = "In Current Use"
		case pistonTransition = "Unleaded 100-Octane Transition"
		case turbineCivil = "Turbine — Civil"
		case turbineMilitary = "Turbine — Military"
		case sustainable = "Sustainable / Alternative"
	}

	var category: Category {
		switch self {
			case .avgas100LL, .ul94, .ul9196, .ul91, .mogas: return .pistonCurrent
			case .g100UL, .swift100R, .ul100E: return .pistonTransition
			case .jetA, .jetA1, .jetB, .ts1, .no3JetFuel: return .turbineCivil
			case .jp4, .jp5, .jp8, .f24, .f35, .jp7, .jpts, .jp10: return .turbineMilitary
			case .saf, .hydrogen, .lngMethane, .batteryElectric: return .sustainable
		}
	}

	var summary: String {
		switch self {
			case .avgas100LL: return "Low-lead, dyed blue — the global default for spark-ignition GA."
			case .ul94: return "Swift Fuels unleaded 94 octane, ASTM D7547."
			case .ul9196: return "Unleaded, ASTM D7547 — mostly Europe."
			case .ul91: return "Hjelmco/TotalEnergies unleaded — Scandinavia/Europe."
			case .mogas: return "Ethanol-free automotive gasoline burned under EAA/Petersen STCs."
			case .g100UL: return "GAMI unleaded 100-octane replacement, STC'd for essentially all spark-ignition piston aircraft."
			case .swift100R: return "Swift Fuels unleaded 100-octane replacement; ASTM production spec Sept 2025."
			case .ul100E: return "LyondellBasell/VP Racing unleaded 100-octane replacement; in PAFI testing."
			case .jetA: return "US domestic turbine standard, freeze point −40°C."
			case .jetA1: return "International turbine standard, freeze point −47°C."
			case .jetB: return "Wide-cut naphtha/kerosene blend for extreme cold (Canada, Alaska)."
			case .ts1: return "Russia/CIS primary jet fuel."
			case .no3JetFuel: return "China, GB 6537 — roughly equivalent to Jet A-1."
			case .jp4: return "NATO F-40 — wide-cut, largely retired."
			case .jp5: return "NATO F-44 — high flash point, carrier/naval use."
			case .jp8: return "NATO F-34 — land-based standard."
			case .f24: return "Jet A with military additive package (US domestic)."
			case .f35: return "Jet A-1 without static dissipator."
			case .jp7: return "SR-71 — high thermal stability."
			case .jpts: return "U-2 / high-altitude — very low freeze point."
			case .jp10: return "Synthetic single-component fuel for missiles and ramjets."
			case .saf: return "Sustainable Aviation Fuel — ASTM D7566 blending components, re-certified as D1655 once blended."
			case .hydrogen: return "Liquid (LH2) or gaseous — experimental/demonstrator aircraft only."
			case .lngMethane: return "Experimental."
			case .batteryElectric: return "Not a fuel, but shown in the same field on most logging systems."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings — the handful
	/// of fuels that cover the vast majority of GA piston and turbine aircraft.
	static let defaultEnabled: [AviationFuelType] = [.avgas100LL, .mogas, .jetA, .jetA1]
}

// Marine fuel types offered by the Fuel Type picker (Edit Vehicle / Edit Fuel Log)
// when Vertical.current.id == .marine. rawValue is both the persisted Vehicle8/FuelLog1
// fuelType string and the value stored in Settings1.enabledMarineFuelTypesRaw — never
// rename or remove a case without a migration for both.
enum MarineFuelType: String, CaseIterable, Identifiable, Hashable {
	// Recreational / small craft
	case marineGasE0 = "Marine Gasoline (E0)"
	case marineGasE10 = "Marine Gasoline (E10)"
	case twoStrokePremix = "Two-Stroke Premix"
	case dieselULSD = "Diesel (EN 590 / ULSD)"
	case dyedDiesel = "Dyed/Red Diesel"
	case biodieselBlend = "Biodiesel Blend (B5–B20)"
	case hvo100 = "HVO100"

	// Distillate marine fuels (ISO 8217)
	case dmx = "DMX"
	case lsmgo = "DMA/LSMGO (Marine Gas Oil)"
	case dmz = "DMZ"
	case mdo = "DMB/MDO (Marine Diesel Oil)"
	case bioDistillate = "DFA/DFZ/DFB (Bio-Distillate)"

	// Residual fuel oils
	case hsfo = "HSFO"
	case vlsfo = "VLSFO"
	case ulsfo = "ULSFO"
	case ifo = "IFO 180/380"

	// Gaseous
	case lng = "LNG"
	case bioLNG = "Bio-LNG"
	case lpg = "LPG"
	case cng = "CNG"
	case hydrogen = "Hydrogen"

	// Alternative and emerging
	case methanol = "Methanol"
	case ammonia = "Ammonia"
	case eFuels = "e-Fuels (e-Methanol/e-Ammonia/e-Diesel)"
	case batteryElectric = "Battery-Electric"
	case hybridDieselElectric = "Hybrid Diesel-Electric"

	// Naval and military
	case f76 = "F-76"
	case f75 = "F-75"
	case jp5 = "JP-5/F-44"
	case nuclear = "Nuclear"

	// Historic
	case coal = "Coal"
	case wood = "Wood"
	case bunkerC = "Bunker C"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case recreational = "Recreational / Small Craft"
		case distillate = "Distillate (ISO 8217)"
		case residual = "Residual Fuel Oil"
		case gaseous = "Gaseous"
		case alternative = "Alternative / Emerging"
		case naval = "Naval / Military"
		case historic = "Historic"
	}

	var category: Category {
		switch self {
			case .marineGasE0, .marineGasE10, .twoStrokePremix, .dieselULSD, .dyedDiesel, .biodieselBlend, .hvo100: return .recreational
			case .dmx, .lsmgo, .dmz, .mdo, .bioDistillate: return .distillate
			case .hsfo, .vlsfo, .ulsfo, .ifo: return .residual
			case .lng, .bioLNG, .lpg, .cng, .hydrogen: return .gaseous
			case .methanol, .ammonia, .eFuels, .batteryElectric, .hybridDieselElectric: return .alternative
			case .f76, .f75, .jp5, .nuclear: return .naval
			case .coal, .wood, .bunkerC: return .historic
		}
	}

	var summary: String {
		switch self {
			case .marineGasE0: return "Ethanol-free pump gasoline, sold as REC-90 in the US — preferred for vented marine tanks."
			case .marineGasE10: return "Standard ethanol-blended pump gasoline; can cause phase separation in vented marine tanks."
			case .twoStrokePremix: return "Legacy outboards; TC-W3 rated oil, ratio (50:1, 100:1) belongs in its own field."
			case .dieselULSD: return "Automotive-grade diesel (EN 590/ULSD) — what most diesel pleasure craft take at a fuel dock."
			case .dyedDiesel: return "Tax-marked; availability to private pleasure craft is jurisdiction-specific and tightening."
			case .biodieselBlend: return "FAME biodiesel — hygroscopic, encourages microbial growth in tanks that sit."
			case .hvo100: return "Renewable diesel, drop-in and stores better than FAME; appearing at Northern European marinas."
			case .dmx: return "Light distillate — emergency generators and lifeboats."
			case .lsmgo: return "Marine Gas Oil — the standard ECA-compliant distillate."
			case .dmz: return "Like DMA/LSMGO with a higher viscosity minimum."
			case .mdo: return "Marine Diesel Oil — a distillate that may carry trace residual content."
			case .bioDistillate: return "ISO 8217:2024 distillate grades permitting up to 7% FAME."
			case .hsfo: return "High Sulfur Fuel Oil, >0.50% sulfur — legal only with a scrubber fitted."
			case .vlsfo: return "Very Low Sulfur Fuel Oil, ≤0.50% — the global default since IMO 2020."
			case .ulsfo: return "Ultra Low Sulfur Fuel Oil, ≤0.10% — for emission control areas."
			case .ifo: return "Legacy Intermediate Fuel Oil naming, still in common speech."
			case .lng: return "The most established alternative marine fuel — cruise ships, container ships, ferries."
			case .bioLNG: return "Liquefied biomethane, drop-in for LNG vessels."
			case .lpg: return "VLGCs burning their own cargo, plus some smaller vessels."
			case .cng: return "Rare, short-range vessels only."
			case .hydrogen: return "Compressed or liquid, small ferries and demonstrators, usually fuel cells."
			case .methanol: return "The most commercially real alternative right now — dual-fuel container ships in service."
			case .ammonia: return "Carbon-free at the stack but toxic, with NOx and N₂O issues; first vessels entering service."
			case .eFuels: return "e-LNG, e-methanol, e-ammonia, e-diesel from renewable hydrogen."
			case .batteryElectric: return "Norwegian ferries, harbor craft, and increasingly small pleasure craft."
			case .hybridDieselElectric: return "Logs both fuel and charge."
			case .f76: return "NATO naval distillate — the standard for surface warships."
			case .f75: return "An older naval distillate grade."
			case .jp5: return "Carried aboard carriers and amphibs for aircraft; usable in some ship systems."
			case .nuclear: return "Submarines and carriers."
			case .coal: return "Steamships, and still burned on preserved vessels."
			case .wood: return "Early steam."
			case .bunkerC: return "Old term for the heaviest residual grade."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings — the handful
	/// of fuels that cover the vast majority of recreational and small commercial craft.
	static let defaultEnabled: [MarineFuelType] = [.marineGasE0, .dieselULSD, .twoStrokePremix, .lsmgo]
}

// Land vehicle fuel types offered by the Fuel Type picker (Edit Vehicle / Edit Fuel Log)
// when Vertical.current.id == .land. rawValue is both the persisted Vehicle8/FuelLog1
// fuelType string and the value stored in Settings1.enabledLandFuelTypesRaw — never
// rename or remove a case without a migration for both. DEF/AdBlue and two-stroke oil
// are tracked as their own fields elsewhere and are deliberately not fuel types here.
enum LandFuelType: String, CaseIterable, Identifiable, Hashable {
	// Gasoline / petrol
	case regularGasoline = "Gasoline"
	case midGrade = "Mid-Grade (89 AKI / 93 RON)"
	case premium = "Premium (91–93 AKI / 95 RON)"
	case superPlus = "Super Plus (98–100 RON)"
	case leadedHistoric = "Leaded Petrol (Historic)"

	// Ethanol blends
	case e5 = "E5"
	case e10 = "E10"
	case e15 = "E15 (Unleaded 88)"
	case e20 = "E20"
	case e25e30 = "E25/E27/E30"
	case e85 = "E85 (Flex-Fuel)"
	case e100 = "E100 (Hydrous Ethanol)"

	// Diesel
	case dieselULSD = "Diesel"
	case dieselLowHighSulfur = "Low/High-Sulfur Diesel"
	case no1D = "No. 1-D (Winter)"
	case no2D = "No. 2-D (Standard)"
	case no4D = "No. 4-D (Slow-Speed)"
	case winterArcticDiesel = "Winterized/Arctic Diesel"
	case dyedDiesel = "Dyed/Red Diesel"

	// Biodiesel and renewable diesel
	case biodieselBlend = "Biodiesel Blend (B5–B30)"
	case b100 = "B100"
	case hvo100 = "HVO100 (Renewable Diesel)"
	case xtl = "XTL (GTL/BTL/CTL)"
	case svoWvo = "SVO/WVO (Straight/Waste Veg Oil)"

	// Gaseous fuels
	case lpgAutogas = "LPG/Autogas"
	case cng = "CNG"
	case lng = "LNG"
	case biomethane = "Biomethane/RNG/CBG"
	case hydrogen = "Hydrogen"

	// Electric
	case acLevel1 = "AC Level 1 (120V)"
	case acLevel2 = "AC Level 2 (240V)"
	case dcFastCharge = "DC Fast Charge"
	case batterySwap = "Battery Swap"
	case phev = "PHEV (Plug-In Hybrid)"

	// Alcohols and other liquids
	case methanol = "Methanol (M15/M85/M100)"
	case keroseneParaffin = "Kerosene/Paraffin"
	case dme = "DME (Dimethyl Ether)"
	case ammonia = "Ammonia"

	// Specialty and historic
	case twoStrokePremix = "Two-Stroke Premix"
	case racingFuel = "Racing Fuel"
	case woodGas = "Wood Gas/Producer Gas"
	case steamCoal = "Steam/Coal"
	case compressedAir = "Compressed Air"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case gasoline = "Gasoline / Petrol"
		case ethanolBlends = "Ethanol Blends"
		case diesel = "Diesel"
		case biodieselRenewable = "Biodiesel & Renewable Diesel"
		case gaseous = "Gaseous"
		case electric = "Electric"
		case alcohols = "Alcohols & Other Liquids"
		case specialtyHistoric = "Specialty & Historic"
	}

	var category: Category {
		switch self {
			case .regularGasoline, .midGrade, .premium, .superPlus, .leadedHistoric: return .gasoline
			case .e5, .e10, .e15, .e20, .e25e30, .e85, .e100: return .ethanolBlends
			case .dieselULSD, .dieselLowHighSulfur, .no1D, .no2D, .no4D, .winterArcticDiesel, .dyedDiesel: return .diesel
			case .biodieselBlend, .b100, .hvo100, .xtl, .svoWvo: return .biodieselRenewable
			case .lpgAutogas, .cng, .lng, .biomethane, .hydrogen: return .gaseous
			case .acLevel1, .acLevel2, .dcFastCharge, .batterySwap, .phev: return .electric
			case .methanol, .keroseneParaffin, .dme, .ammonia: return .alcohols
			case .twoStrokePremix, .racingFuel, .woodGas, .steamCoal, .compressedAir: return .specialtyHistoric
		}
	}

	var summary: String {
		switch self {
			case .regularGasoline: return "The (R+M)/2 AKI average in the US/Canada; roughly RON − 4–5 elsewhere."
			case .midGrade: return "Regional names: Mid-Grade, Plus, or 93/95 RON."
			case .premium: return "Regional names: Premium, Super, or 95 RON."
			case .superPlus: return "Regional names: Super Plus, or China's 98#."
			case .leadedHistoric: return "Globally eliminated for road use (Algeria was last, 2021) — historic vehicle records only."
			case .e5: return "European baseline ethanol blend."
			case .e10: return "Standard in the UK, much of the EU, Australia, and the US."
			case .e15: return "Sold in the US as \"Unleaded 88.\""
			case .e20: return "India's nationwide standard as of 2025."
			case .e25e30: return "Brazil's mandatory gasoline blend, raised to E30 in August 2025."
			case .e85: return "Flex-fuel — US, Sweden, France (Superéthanol-E85); seasonally drops to ~E51–E70 in winter."
			case .e100: return "Hydrous ethanol sold standalone at Brazilian pumps alongside E30 gasoline."
			case .dieselULSD: return "Ultra-low sulfur diesel, ≤10–15 ppm — the standard in North America, EU, and most regulated markets."
			case .dieselLowHighSulfur: return "Still sold in parts of Africa, Central Asia, and Latin America."
			case .no1D: return "Kerosene-based winter diesel (ASTM D975)."
			case .no2D: return "The normal diesel grade (ASTM D975)."
			case .no4D: return "For large slow-speed engines (ASTM D975)."
			case .winterArcticDiesel: return "CFPP-graded blends, sold seasonally."
			case .dyedDiesel: return "Chemically identical to regular diesel, tax-marked for off-road, agricultural, and construction use."
			case .biodieselBlend: return "FAME biodiesel — B5 through B30; mandated levels climbing fast (Indonesia B40, Brazil B15)."
			case .b100: return "Pure FAME biodiesel."
			case .hvo100: return "Hydrotreated vegetable oil, a drop-in paraffinic fuel to EN 15940 — chemically unlike FAME."
			case .xtl: return "EN 16942 umbrella label for synthetic paraffinic diesel: GTL, BTL, CTL."
			case .svoWvo: return "Straight/waste vegetable oil — conversion vehicles only."
			case .lpgAutogas: return "Propane-butane — huge fleets in Turkey, Poland, South Korea, Italy, Australia."
			case .cng: return "Compressed natural gas — dominant in India, Pakistan, Iran, Argentina, Italy."
			case .lng: return "Liquefied natural gas — mostly heavy trucking."
			case .biomethane: return "Renewable natural gas, dispensed as CNG or LNG; India has a dedicated CBG mandate."
			case .hydrogen: return "Compressed (350/700 bar) or liquid — powers fuel cells (FCEV) or, rarely, H2-ICE combustion."
			case .acLevel1: return "120V AC — the slowest home charging option."
			case .acLevel2: return "240V AC, 7–22 kW — the common home/public Level 2 rate."
			case .dcFastCharge: return "CCS1, CCS2, NACS/J3400, CHAdeMO, or GB/T."
			case .batterySwap: return "Metered per swap — notably NIO in China."
			case .phev: return "Genuinely dual-fuel; the record needs both a liquid fill and a charge."
			case .methanol: return "M15/M85/M100 — China runs methanol trucks and taxis at scale; also Israel and Denmark."
			case .keroseneParaffin: return "Still used in some older vehicles in developing markets."
			case .dme: return "Dimethyl ether — compression-ignition alternative, limited fleet trials."
			case .ammonia: return "Experimental — mostly marine, but some heavy-vehicle research."
			case .twoStrokePremix: return "Motorcycles, scooters, small engines. Ratio (32:1, 50:1) belongs in its own field."
			case .racingFuel: return "Leaded race gas (VP C12, Sunoco), methanol, nitromethane, toluene blends, E85 race."
			case .woodGas: return "Wartime and off-grid gasifier conversions."
			case .steamCoal: return "Traction engines and preserved vehicles."
			case .compressedAir: return "Experimental only."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings — mirrors the
	/// four options (Gasoline/Diesel/EV/Hybrid) shown before this catalog existed.
	static let defaultEnabled: [LandFuelType] = [.regularGasoline, .dieselULSD, .dcFastCharge, .phev]

	/// Diesel-family fuels — the ones an SCR-equipped engine would need DEF/AdBlue for.
	var isDieselFamily: Bool {
		switch self {
			case .dieselULSD, .dieselLowHighSulfur, .no1D, .no2D, .no4D, .winterArcticDiesel, .dyedDiesel,
				 .biodieselBlend, .b100, .hvo100, .xtl:
				return true
			default:
				return false
		}
	}
}

extension MarineFuelType {
	/// Diesel-family fuels — the ones an SCR-equipped engine would need DEF/urea for.
	var isDieselFamily: Bool {
		switch self {
			case .dieselULSD, .dyedDiesel, .biodieselBlend, .hvo100,
				 .dmx, .lsmgo, .dmz, .mdo, .bioDistillate:
				return true
			default:
				return false
		}
	}
}

/// True when `fuelType` (the raw string stored on Vehicle8/FuelLog1) represents a
/// diesel-family fuel that takes DEF/AdBlue in an SCR-equipped engine. Checks the
/// legacy "Diesel" value plus the diesel-family cases in LandFuelType/MarineFuelType,
/// so DEF fields keep showing after the Fuel Type picker expanded past one "Diesel" tag.
func isDieselFamilyFuelType(_ fuelType: String) -> Bool {
	if fuelType.caseInsensitiveCompare("Diesel") == .orderedSame { return true }
	if let land = LandFuelType(rawValue: fuelType) { return land.isDieselFamily }
	if let marine = MarineFuelType(rawValue: fuelType) { return marine.isDieselFamily }
	return false
}

// Land vehicle hydraulic fluid types offered by the Hydraulic Fluid Type picker on Edit
// Vehicle when Vertical.current.id == .land. rawValue is both the persisted Vehicle8
// hydraulicFluidType string and the value stored in Settings1.enabledLandHydraulicFluidTypesRaw
// — never rename or remove a case without a migration. Includes automatic transmission
// fluid (ATF) types and tractor/ag-equipment brand-name fluids, since most off-road and
// farm equipment specs an ATF or combined hydraulic/transmission fluid rather than a
// dedicated hydraulic oil.
enum LandHydraulicFluidType: String, CaseIterable, Identifiable, Hashable {
	// Standard hydraulic oil
	case awISO32 = "AW Hydraulic Oil (ISO 32)"
	case awISO46 = "AW Hydraulic Oil (ISO 46)"
	case awISO68 = "AW Hydraulic Oil (ISO 68)"
	case universalTractorFluid = "Universal Tractor Hydraulic Fluid (UTHF/UTF)"
	case biodegradableHydraulic = "Biodegradable Hydraulic Fluid (HEES)"
	case syntheticHydraulic = "Synthetic Hydraulic Fluid"

	// Automatic transmission fluid — generic
	case dexronIII = "Dexron III (ATF)"
	case dexronVI = "Dexron VI (ATF)"
	case merconV = "Mercon V (ATF)"
	case merconLV = "Mercon LV (ATF)"
	case atfPlus4 = "ATF+4 (Chrysler/Mopar)"
	case typeF = "Type F (ATF)"
	case cvtFluid = "CVT Fluid"

	// Tractor / ag-equipment hydraulic-transmission fluid brands
	case johnDeereHyGard = "John Deere Hy-Gard"
	case caseIHHyTran = "Case IH Hy-Tran Ultraction"
	case kubotaSuperUDT = "Kubota Super UDT2"
	case masseyFergusonPermaTrans = "Massey Ferguson Perma-Trans/Multipower"
	case newHollandSuperFRM = "New Holland Super FRM"
	case agcoPowerFluid = "AGCO Power Fluid 821 XL"
	case fendtHydraulicFluid = "Fendt Hydraulic Fluid"

	// Other
	case powerSteeringFluid = "Power Steering Fluid"
	case brakeFluidDOT3 = "Brake Fluid (DOT 3/4 — shared reservoir systems)"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case standardHydraulic = "Standard Hydraulic Oil"
		case atf = "Automatic Transmission Fluid (ATF)"
		case tractorBrands = "Tractor / Ag Equipment Brands"
		case other = "Other"
	}

	var category: Category {
		switch self {
			case .awISO32, .awISO46, .awISO68, .universalTractorFluid, .biodegradableHydraulic, .syntheticHydraulic: return .standardHydraulic
			case .dexronIII, .dexronVI, .merconV, .merconLV, .atfPlus4, .typeF, .cvtFluid: return .atf
			case .johnDeereHyGard, .caseIHHyTran, .kubotaSuperUDT, .masseyFergusonPermaTrans, .newHollandSuperFRM, .agcoPowerFluid, .fendtHydraulicFluid: return .tractorBrands
			case .powerSteeringFluid, .brakeFluidDOT3: return .other
		}
	}

	var summary: String {
		switch self {
			case .awISO32: return "Light viscosity anti-wear hydraulic oil — cold climates, high-speed pumps."
			case .awISO46: return "The most common general-purpose hydraulic oil viscosity grade."
			case .awISO68: return "Heavier viscosity — hot climates, older/higher-clearance pumps."
			case .universalTractorFluid: return "Single fluid for hydraulics, wet brakes, and transmission in most modern tractors."
			case .biodegradableHydraulic: return "Vegetable/synthetic ester base — environmentally sensitive sites (forestry, marine-adjacent equipment)."
			case .syntheticHydraulic: return "Full-synthetic base stock — wider temperature range, longer service life."
			case .dexronIII: return "GM automatic transmission fluid, also common in older loader/backhoe hydraulic systems."
			case .dexronVI: return "Current GM ATF spec — backward-compatible with Dexron III applications."
			case .merconV: return "Ford automatic transmission fluid."
			case .merconLV: return "Ford low-viscosity ATF — modern 6-speed and later automatics."
			case .atfPlus4: return "Chrysler/Mopar ATF, HFM-specific — do not substitute Dexron/Mercon."
			case .typeF: return "Older Ford ATF — friction characteristics differ from Dexron/Mercon."
			case .cvtFluid: return "Continuously variable transmission fluid — not interchangeable with standard ATF."
			case .johnDeereHyGard: return "John Deere's own hydraulic/transmission/wet-brake fluid, specified across most Deere equipment."
			case .caseIHHyTran: return "Case IH/New Holland CNH hydraulic-transmission fluid family."
			case .kubotaSuperUDT: return "Kubota Universal Dynamic Trans-Hydraulic fluid, specified for most Kubota tractors."
			case .masseyFergusonPermaTrans: return "AGCO/Massey Ferguson branded hydraulic-transmission fluid."
			case .newHollandSuperFRM: return "New Holland's Fluid for Rear-axle and Manual transmission/hydraulic systems."
			case .agcoPowerFluid: return "AGCO's own multi-purpose tractor hydraulic-transmission fluid."
			case .fendtHydraulicFluid: return "Fendt-branded hydraulic fluid for AGCO's Fendt line."
			case .powerSteeringFluid: return "Dedicated power steering fluid on vehicles without a shared hydraulic reservoir."
			case .brakeFluidDOT3: return "Only relevant where the brake and hydraulic systems share a reservoir/fluid spec."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings — the handful
	/// of fluids that cover most passenger vehicles and common ag/off-road equipment.
	static let defaultEnabled: [LandHydraulicFluidType] = [.awISO46, .universalTractorFluid, .dexronVI, .powerSteeringFluid]
}

// Marine hydraulic fluid types offered by the Hydraulic Fluid Type picker on Edit
// Vehicle when Vertical.current.id == .marine. rawValue is both the persisted Vehicle8
// hydraulicFluidType string and the value stored in Settings1.enabledMarineHydraulicFluidTypesRaw
// — never rename or remove a case without a migration.
enum MarineHydraulicFluidType: String, CaseIterable, Identifiable, Hashable {
	case awISO32 = "AW Hydraulic Oil (ISO 32)"
	case awISO46 = "AW Hydraulic Oil (ISO 46)"
	case sternDriveHydraulic = "Stern Drive/Outboard Power Steering Fluid"
	case tiltTrimFluid = "Power Tilt/Trim Fluid"
	case biodegradableHydraulic = "Biodegradable Hydraulic Fluid (HEES)"
	case dexronIII = "Dexron III (ATF — common trim/tilt substitute)"
	case syntheticHydraulic = "Synthetic Hydraulic Fluid"
	case navalHydraulic = "Naval/Military Hydraulic Fluid (MIL-PRF-17672)"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case standardHydraulic = "Standard Hydraulic Oil"
		case steeringTrim = "Steering / Tilt / Trim"
		case navalMilitary = "Naval / Military"
	}

	var category: Category {
		switch self {
			case .awISO32, .awISO46, .biodegradableHydraulic, .syntheticHydraulic: return .standardHydraulic
			case .sternDriveHydraulic, .tiltTrimFluid, .dexronIII: return .steeringTrim
			case .navalHydraulic: return .navalMilitary
		}
	}

	var summary: String {
		switch self {
			case .awISO32: return "Light viscosity anti-wear hydraulic oil — steering rams, small hydraulic systems."
			case .awISO46: return "General-purpose hydraulic oil for larger vessel steering/stabilizer systems."
			case .sternDriveHydraulic: return "OEM fluid for hydraulic steering rams on stern drives and outboards."
			case .tiltTrimFluid: return "Dedicated power tilt/trim reservoir fluid — outboards and stern drives."
			case .biodegradableHydraulic: return "Vegetable/synthetic ester base — required in some environmentally sensitive waterways."
			case .dexronIII: return "Widely accepted substitute for OEM tilt/trim fluid on many outboards."
			case .syntheticHydraulic: return "Full-synthetic base stock — wider temperature range, longer service life."
			case .navalHydraulic: return "MIL-PRF-17672 — shipboard hydraulic/lube oil standard, naval and some commercial vessels."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings.
	static let defaultEnabled: [MarineHydraulicFluidType] = [.awISO46, .tiltTrimFluid, .dexronIII]
}

// Aviation hydraulic fluid types offered by the Hydraulic Fluid Type picker on Edit
// Vehicle when Vertical.current.id == .aviation. rawValue is both the persisted Vehicle8
// hydraulicFluidType string and the value stored in Settings1.enabledHydraulicFluidTypesRaw
// — never rename or remove a case without a migration.
enum AviationHydraulicFluidType: String, CaseIterable, Identifiable, Hashable {
	case milPRF5606 = "MIL-PRF-5606 (Red Mineral-Based)"
	case milPRF83282 = "MIL-PRF-83282 (Fire-Resistant Synthetic)"
	case milPRF87257 = "MIL-PRF-87257 (Low-Temp Fire-Resistant Synthetic)"
	case skydrolLD4 = "Skydrol LD-4 (Phosphate Ester)"
	case skydrol5 = "Skydrol 5 (Phosphate Ester)"
	case hyjetIV = "HyJet IV-A Plus (Phosphate Ester)"
	case milH83306 = "MIL-H-83306 (Phosphate Ester)"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case mineralBased = "Mineral-Based"
		case phosphateEster = "Fire-Resistant / Phosphate Ester"
	}

	var category: Category {
		switch self {
			case .milPRF5606: return .mineralBased
			case .milPRF83282, .milPRF87257, .skydrolLD4, .skydrol5, .hyjetIV, .milH83306: return .phosphateEster
		}
	}

	var summary: String {
		switch self {
			case .milPRF5606: return "Red mineral-based fluid — light GA aircraft, older military/civil types. Not fire-resistant."
			case .milPRF83282: return "Fire-resistant synthetic hydrocarbon — military and some transport-category aircraft."
			case .milPRF87257: return "Low-temperature version of MIL-PRF-83282."
			case .skydrolLD4: return "Eastman/Solutia phosphate ester — the common transport-category standard."
			case .skydrol5: return "Newer, more environmentally friendly Skydrol formulation."
			case .hyjetIV: return "Exxon/Mobil phosphate ester — Airbus/some Boeing types."
			case .milH83306: return "Legacy military phosphate ester spec, largely superseded."
		}
	}

	/// Enabled by default for a fresh install / not-yet-configured Settings.
	static let defaultEnabled: [AviationHydraulicFluidType] = [.milPRF5606, .skydrolLD4]
}

// MARK: - Aviation parts compliance enums (AeroTrax only — MxParts1/ServiceRecords1/PartInstallation)
// rawValues are persisted (MxParts1.approvalBasis/.conditionCode/.partClass/.limitType/
// .limitTimeBase/.releaseDocumentType, PartInstallation.removalReason,
// ServiceRecords1.certificateKind) — never rename or remove a case without a migration.

enum PartApprovalBasis: String, CaseIterable, Identifiable, Hashable {
	case tcOem = "TC/OEM Part"
	case pma = "PMA"
	case tso = "TSO Article"
	case stc = "STC-Approved Part"
	case ownerProduced = "Owner-Produced (14 CFR 21.9(a)(5))"
	case standardPart = "Standard Part (AN/MS/NAS)"
	case commercialPart = "Commercial Part"
	case unapproved = "Unapproved / Unknown"

	var id: String { rawValue }

	var summary: String {
		switch self {
			case .tcOem: return "Manufactured under the aircraft/engine/prop Type Certificate, or supplied by the OEM."
			case .pma: return "Parts Manufacturer Approval — an FAA-approved alternative to the OEM part."
			case .tso: return "Built to a Technical Standard Order — a minimum performance standard, not model-specific approval."
			case .stc: return "Approved for installation under a Supplemental Type Certificate — record the STC number."
			case .ownerProduced: return "Owner-produced under 14 CFR 21.9(a)(5) — record a justification, not a release document."
			case .standardPart: return "AN/MS/NAS hardware made to a published standard — no production approval holder to trace."
			case .commercialPart: return "A commercial part used under 14 CFR 21.9(a)(2) — not aircraft-specific approval."
			case .unapproved: return "No established approval basis — a Suspected Unapproved Part until traceability is resolved."
		}
	}

	/// Whether this basis normally comes with a release document (8130-3/Form 1/etc.)
	/// worth attaching. Owner-produced and standard parts don't get one.
	var requiresApprovalDocument: Bool {
		switch self {
			case .tcOem, .pma, .tso, .stc, .commercialPart: return true
			case .ownerProduced, .standardPart, .unapproved: return false
		}
	}
}

enum PartConditionCode: String, CaseIterable, Identifiable, Hashable {
	case new = "New"
	case newSurplus = "New Surplus"
	case overhauled = "Overhauled"
	case repaired = "Repaired"
	case serviceable = "Serviceable"
	case inspectedTested = "Inspected/Tested"
	case asRemoved = "As-Removed"
	case unserviceable = "Unserviceable"
	case scrap = "Scrap / Beyond Economic Repair"
	case unknown = "Unknown"

	var id: String { rawValue }

	enum Category: String, CaseIterable, Hashable {
		case serviceable = "Serviceable"
		case needsWork = "Needs Work"
		case notAirworthy = "Not Airworthy"
	}

	var category: Category {
		switch self {
			case .new, .newSurplus, .overhauled, .repaired, .serviceable, .inspectedTested: return .serviceable
			case .asRemoved: return .needsWork
			case .unserviceable, .scrap, .unknown: return .notAirworthy
		}
	}

	/// Whether a part in this condition may be installed as-is. `.asRemoved` is
	/// deliberately not airworthy until inspected/tested — it's an unknown, not a pass.
	var isAirworthy: Bool { category == .serviceable }
}

enum PartClass: String, CaseIterable, Identifiable, Hashable {
	case rotable = "Rotable"
	case repairable = "Repairable"
	case expendable = "Expendable"
	case consumable = "Consumable"
	case lifeLimited = "Life-Limited"

	var id: String { rawValue }

	/// Whether installation history (PartInstallation) is meaningful for this class.
	/// Consumables are used up, not installed-and-removed as a tracked article.
	var tracksInstallations: Bool {
		switch self {
			case .rotable, .repairable, .lifeLimited: return true
			case .expendable, .consumable: return false
		}
	}
}

enum PartLimitType: String, CaseIterable, Identifiable, Hashable {
	case hardLifeLimit = "Hard Life Limit"
	case overhaulTBO = "Overhaul (TBO)"
	case inspectionInterval = "Inspection Interval"
	case shelfLife = "Shelf Life"
	case onCondition = "On-Condition"
	case none = "None"

	var id: String { rawValue }

	/// A hard life limit is a regulatory discard point — no extension. A TBO is a
	/// manufacturer recommendation (mandatory under Part 135/121, advisory under Part 91).
	var isRegulatoryLimit: Bool {
		switch self {
			case .hardLifeLimit: return true
			default: return false
		}
	}
}

enum PartTimeBase: String, CaseIterable, Identifiable, Hashable {
	case hobbs = "Hobbs Time"
	case tach = "Tach Time"
	case airTime = "Airframe/Air Time"
	case flightTime = "Flight Time"
	case cycles = "Cycles"
	case calendar = "Calendar"

	var id: String { rawValue }
}

enum ReleaseDocumentType: String, CaseIterable, Identifiable, Hashable {
	case faa8130 = "FAA Form 8130-3"
	case easaForm1 = "EASA Form 1"
	case tccaFormOne = "TCCA Form One"
	case caacAAC038 = "CAAC AAC-038"
	case dualRelease = "Dual Release (8130-3/Form 1)"
	case certOfConformity = "Certificate of Conformity"
	case packingSlip = "Manufacturer Packing Slip"
	case none = "None"

	var id: String { rawValue }
}

enum RemovalReason: String, CaseIterable, Identifiable, Hashable {
	case scheduled = "Scheduled (TBO/Life Limit)"
	case inspection = "Inspection"
	case unscheduledFailure = "Unscheduled — Failure"
	case unscheduledSuspected = "Unscheduled — Suspected"
	case convenience = "Convenience"
	case saleTransfer = "Aircraft Sale/Transfer"
	case modificationSTC = "Modification/STC"
	case robbed = "Robbed for Another Aircraft"

	var id: String { rawValue }
}

enum CertificateKind: String, CaseIterable, Identifiable, Hashable {
	case ap = "A&P"
	case apIA = "A&P/IA"
	case repairman = "Repairman"
	case repairStation = "Repair Station"
	case pilotPreventive = "Pilot (Preventive Mx, Part 43 App. A(c))"
	case manufacturer = "Manufacturer"
	case ownerOperator = "Owner/Operator"
	case other = "Other"

	var id: String { rawValue }

	var summary: String {
		switch self {
			case .ap: return "Airframe & Powerplant mechanic."
			case .apIA: return "A&P with Inspection Authorization — required to sign off an annual."
			case .repairman: return "Experimental/LSA repairman certificate, aircraft-specific."
			case .repairStation: return "FAA-certificated repair station — record its certificate number."
			case .pilotPreventive: return "Owner/pilot preventive maintenance under 14 CFR 43, Appendix A(c)."
			case .manufacturer: return "Work performed by the type/parts manufacturer."
			case .ownerOperator: return "Owner-performed work outside the preventive-maintenance list — record carefully."
			case .other: return "Certificate type not covered above — describe in Notes."
		}
	}
}

// MARK: - Fuel operations enums (FuelLog1 additive fields — see Vertical.enabledFeatures
// .fuelOperations). Units/density/fill-type are unconditional across all verticals; the
// rest (service type, payment, quality, operating rule) surface only behind the gate.
// rawValues are persisted on FuelLog1 — never rename or remove a case without a migration.

enum FuelQuantityUnit: String, CaseIterable, Identifiable, Hashable {
	case usGallon = "US Gallons"
	case imperialGallon = "Imperial Gallons"
	case liter = "Liters"
	case pound = "Pounds"
	case kilogram = "Kilograms"

	var id: String { rawValue }

	var symbol: String {
		switch self {
			case .usGallon: return "gal"
			case .imperialGallon: return "Imp gal"
			case .liter: return "L"
			case .pound: return "lb"
			case .kilogram: return "kg"
		}
	}

	/// True for a mass unit — converting to/from a volume unit requires `density`,
	/// which is exactly the case this type exists to force callers to handle rather
	/// than silently treating every quantity as a volume. See FuelMath.canonical.
	var isMass: Bool {
		switch self {
			case .pound, .kilogram: return true
			case .usGallon, .imperialGallon, .liter: return false
		}
	}

	/// US gallons per one unit — volume units only; `nil` for mass units, which
	/// convert through density instead (there is no fixed gallons-per-pound).
	var usGallonsPerUnit: Float? {
		switch self {
			case .usGallon: return 1.0
			case .imperialGallon: return 1.200950
			case .liter: return 0.264172
			case .pound, .kilogram: return nil
		}
	}

	/// Pounds per one unit — mass units only; `nil` for volume units.
	var poundsPerUnit: Float? {
		switch self {
			case .pound: return 1.0
			case .kilogram: return 2.204623
			case .usGallon, .imperialGallon, .liter: return nil
		}
	}
}

enum FuelDensityUnit: String, CaseIterable, Identifiable, Hashable {
	case poundsPerUSGallon = "lb/gal"
	case kilogramsPerLiter = "kg/L"
	case specificGravity = "Specific Gravity"

	var id: String { rawValue }

	/// Converts a density value expressed in this unit to pounds per US gallon —
	/// the one common unit FuelMath does its density math in. 8.3454 lb/gal is the
	/// density of water at 60°F/15.6°C, which is what both kg/L and specific
	/// gravity are defined relative to.
	func poundsPerUSGallon(_ value: Float) -> Float {
		switch self {
			case .poundsPerUSGallon: return value
			case .kilogramsPerLiter: return value * 8.3454
			case .specificGravity: return value * 8.3454
		}
	}
}

enum FuelDensitySource: String, CaseIterable, Identifiable, Hashable {
	case ticket = "From Fueling Ticket"
	case standard = "Standard Assumption"
	case measured = "Measured"

	var id: String { rawValue }
}

enum FuelFillType: String, CaseIterable, Identifiable, Hashable {
	case full = "Full"
	case partial = "Partial"
	case toppedOff = "Topped Off"
	case tankered = "Tankered (Carrying Extra)"
	case defuel = "Defuel"

	var id: String { rawValue }

	/// Whether this uplift leaves the tank(s) at a known-full state — the only kind
	/// of point a burn/economy calculation can anchor to (see FuelMath.interval).
	/// `.toppedOff` and `.tankered` both fill to a known top reference even though
	/// neither is a bare "Full"; `.partial` and `.defuel` deliberately stop short.
	var establishesKnownFullPoint: Bool {
		switch self {
			case .full, .toppedOff, .tankered: return true
			case .partial, .defuel: return false
		}
	}
}

enum FuelServiceType: String, CaseIterable, Identifiable, Hashable {
	case selfServe = "Self-Serve"
	case fullServe = "Full-Serve"
	case truck = "Truck"
	case singlePointPressure = "Single-Point Pressure"

	var id: String { rawValue }
}

enum FuelPaymentMethod: String, CaseIterable, Identifiable, Hashable {
	case fuelCard = "Fuel Card"
	case creditCard = "Credit Card"
	case directBill = "Direct Bill"
	case cash = "Cash"
	case other = "Other"

	var id: String { rawValue }
}

enum FuelSumpResult: String, CaseIterable, Identifiable, Hashable {
	case clean = "Clean"
	case waterPresent = "Water Present"
	case contaminated = "Contaminated"

	var id: String { rawValue }
}

enum FuelOperatingRule: String, CaseIterable, Identifiable, Hashable {
	case part91 = "Part 91"
	case part135 = "Part 135"
	case part121 = "Part 121"
	case other = "Other"

	var id: String { rawValue }
}

// MARK: - Fluid check items (Fuel Log's "Fluid Checks" sheet, and the identical per-stop
// editor in Trip Log). Land keeps its original fixed FuelLog1.oilChecked/... Bool columns,
// individually hideable via Settings1.fluidChk_* — unchanged. Aviation/marine instead check
// off items from these lists, stored as rawValues in FuelLog1.checkedFluidItemsRaw — never
// rename or remove a case without a migration. Excludes a water-in-fuel sump check for
// aviation since that's already its own field (FuelLog1.sumpCheckPerformed) on the Uplift
// sub-editor — this list stays fluid-specific and doesn't duplicate it.

enum AviationFluidCheckItem: String, CaseIterable, Identifiable, Hashable {
	case engineOil = "Engine Oil"
	case hydraulicFluid = "Hydraulic Fluid"
	case brakeFluid = "Brake Fluid"
	case deiceFluid = "Deice / TKS Fluid"
	case fuelStrainerDrained = "Fuel Strainer / Gascolator Drained"

	var id: String { rawValue }
}

enum MarineFluidCheckItem: String, CaseIterable, Identifiable, Hashable {
	case engineOil = "Engine Oil"
	case coolant = "Coolant (Fresh Water / Antifreeze)"
	case transmissionOil = "Transmission / Gear Oil"
	case powerSteeringFluid = "Power Steering Fluid"
	case hydraulicSteeringFluid = "Hydraulic Steering Fluid"
	case fuelWaterSeparator = "Fuel/Water Separator"
	case bilgePump = "Bilge Pump Check"
	case shaftSeal = "Stuffing Box / Shaft Seal"

	var id: String { rawValue }
}

/// The current-vertical fluid-check item labels — `[]` for land, which uses its own fixed
/// Bool columns directly rather than this generic list. Shared by EditFuelLog, EditTripLog,
/// FluidCheckSheet, and pdfReportFuel so the item set can't drift between call sites.
enum FluidCheckList {
	static var currentLabels: [String] {
		switch Vertical.current.id {
			case .land: return []
			case .aviation: return AviationFluidCheckItem.allCases.map(\.rawValue)
			case .marine: return MarineFluidCheckItem.allCases.map(\.rawValue)
		}
	}

	/// Packs the checked-item labels into a single delimited `String` for storage —
	/// deliberately not a `[String]`, which SwiftData/CloudKit persists as an
	/// `NSSecureUnarchiveFromData`-transformed attribute. A `[String]` attribute that
	/// arrives from CloudKit with empty/corrupt bytes throws an uncaught
	/// `NSInvalidUnarchiveOperationException` the instant anything reads it — a plain
	/// `String` attribute has no unarchiving step, so it can't fail that way. None of
	/// these labels can contain "|" (they're short fixed English phrases like "Engine
	/// Oil"), so it's a safe delimiter.
	static func pack(_ items: [String]) -> String {
		items.joined(separator: "|")
	}

	static func unpack(_ packed: String) -> Set<String> {
		packed.isEmpty ? [] : Set(packed.components(separatedBy: "|"))
	}
}

// Centralize storage keys to avoid typos across the app
enum StorageKey {
	static let trackVehicleSelected = "trackVehicleSelected"
	static let splitColumnVisibility = "splitColumnVisibility"
	static let hasCompletedOnboarding = "hasCompletedOnboarding"
	static let sidebarColumnWidth = "sidebarColumnWidth"
	static let contentColumnWidth = "contentColumnWidth"
	static let detailColumnWidth = "detailColumnWidth"
	static let launchScreen = "launchScreen"
	static let lastSidebarSection = "lastSidebarSection"
	static let lastBackupDate = "lastBackupDate"
	static let lastManualBackupBookmark = "lastManualBackupBookmark"
	static let lastAutoBackupDate = "lastAutoBackupDate"
	static let autoBackupInterval = "autoBackupInterval"
	static let autoBackupRetentionCount = "autoBackupRetentionCount"
	static let appearanceMode = "appearanceMode"

	// Trial / full-version entitlement. Persisted so a cold launch while offline
	// keeps the user unlocked (fail open) — see EntitlementStore. Exactly one
	// code path may ever write fullVersionUnlocked = false: a successful,
	// verified currentEntitlements read that also fails the grandfathering checks.
	static let fullVersionUnlocked = "fullVersionUnlocked"
	static let fullVersionSource = "fullVersionSource"
	static let entitlementCheckedAt = "entitlementCheckedAt"
	static let originalAppVersionCached = "originalAppVersionCached"
	static let appStoreEnvironment = "appStoreEnvironment"
	static let firstFreeLaunchDate = "firstFreeLaunchDate"
	static let priorInstallDetected = "priorInstallDetected"

	// Set by CloudKitSyncMonitor when a real (non-PCS-noise) sync failure is logged;
	// cleared when Debug Tools is opened. Drives the badge on AppTitleView so a
	// sync problem doesn't go unnoticed until a customer reports it.
	static let hasUnreadCloudKitFailure = "hasUnreadCloudKitFailure"
#if DEBUG
	static let debugForcedEntitlement = "debugForcedEntitlement"
#endif
}

// User's preferred light/dark appearance override. rawValue is persisted via
// AppStorage — never rename or reorder cases without a migration.
enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
	case system
	case light
	case dark

	var id: String { rawValue }

	var label: String {
		switch self {
			case .system: return "System"
			case .light: return "Light"
			case .dark: return "Dark"
		}
	}

	/// `nil` tells SwiftUI to follow the system setting (via `.preferredColorScheme`).
	var colorScheme: ColorScheme? {
		switch self {
			case .system: return nil
			case .light: return .light
			case .dark: return .dark
		}
	}
}

// How often automatic backups should be created. rawValue is persisted via
// AppStorage — never rename or reorder cases without a migration.
enum AutoBackupInterval: String, CaseIterable, Identifiable, Hashable {
	case off
	case daily
	case weekly
	case monthly

	var id: String { rawValue }

	var label: String {
		switch self {
			case .off: return "Off"
			case .daily: return "Daily"
			case .weekly: return "Weekly"
			case .monthly: return "Monthly"
		}
	}

	/// Minimum elapsed time since the last backup (of any kind) before an
	/// automatic backup is due again. `nil` for `.off`.
	var minimumElapsed: TimeInterval? {
		switch self {
			case .off: return nil
			case .daily: return 60 * 60 * 24
			case .weekly: return 60 * 60 * 24 * 7
			case .monthly: return 60 * 60 * 24 * 30
		}
	}
}

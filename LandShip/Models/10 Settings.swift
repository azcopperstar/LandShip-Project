//
//  Settings.swift
//  LandShip
//
//  Created by JP on 9/9/25.
//

import Foundation
import SwiftData

@Model
class Settings1 {
	var userName: String = "primary"

	var unitVolumeFuel: String = ""
	var unitVolumeOil: String = ""
	var unitVolumeDEF: String = ""
	var unitTemp: String = ""
	var unitSpeed: String = ""
	var unitPressure: String = ""
	var unitMass: String = ""
	var unitDistance: String = ""
	var unitArea: String = ""
	var unitLength: String = ""
	var unitWidth: String = ""
	var unitHeight: String = ""
	var unitWheelBase: String = ""

	var fluidChk_engineOil: Bool = true
	var fluidChk_engineCoolant: Bool = true
	var fluidChk_secondaryCoolant: Bool = true
	var fluidChk_powerSteering: Bool = true
	var fluidChk_brake: Bool = true
	var fluidChk_transmission: Bool = true
	var fluidChk_rearAxle: Bool = true
	var fluidChk_frontAxle: Bool = true
	var fluidChk_fuelWaterSep: Bool = true
	var fluidChk_airWaterBleed: Bool = true

	// Fluid Checks sheet configuration (aviation vertical) — which AviationFluidCheckItem
	// entries appear in the Fluid Checks popup. Land uses the fluidChk_* Bools above instead.
	var enabledAviationFluidCheckItemsRaw: [String] = []
	var aviationFluidCheckItemsConfigured: Bool = false    // distinguishes "not yet set up" from "all items hidden"

	var enabledAviationFluidCheckItems: [AviationFluidCheckItem] {
		get {
			guard aviationFluidCheckItemsConfigured else { return AviationFluidCheckItem.allCases }
			return enabledAviationFluidCheckItemsRaw.compactMap(AviationFluidCheckItem.init(rawValue:))
		}
		set {
			enabledAviationFluidCheckItemsRaw = newValue.map(\.rawValue)
			aviationFluidCheckItemsConfigured = true
		}
	}

	// Fluid Checks sheet configuration (marine vertical) — which MarineFluidCheckItem
	// entries appear in the Fluid Checks popup. Land uses the fluidChk_* Bools above instead.
	var enabledMarineFluidCheckItemsRaw: [String] = []
	var marineFluidCheckItemsConfigured: Bool = false    // distinguishes "not yet set up" from "all items hidden"

	var enabledMarineFluidCheckItems: [MarineFluidCheckItem] {
		get {
			guard marineFluidCheckItemsConfigured else { return MarineFluidCheckItem.allCases }
			return enabledMarineFluidCheckItemsRaw.compactMap(MarineFluidCheckItem.init(rawValue:))
		}
		set {
			enabledMarineFluidCheckItemsRaw = newValue.map(\.rawValue)
			marineFluidCheckItemsConfigured = true
		}
	}

	// Dashboard configuration scheme
	var dashCardOrderRaw: [String] = []      // enabled DashboardCard rawValues, in display order
	var dashCardsConfigured: Bool = false    // distinguishes "not yet set up" from "all cards hidden"
	var dashVehicleScopeRaw: [String] = []   // Vehicle8.name values included in dashboard totals; empty == all vehicles

	var dashCards: [DashboardCard] {
		get {
			guard dashCardsConfigured else { return DashboardCard.defaultOrder }
			return dashCardOrderRaw.compactMap(DashboardCard.init(rawValue:))
		}
		set {
			dashCardOrderRaw = newValue.map(\.rawValue)
			dashCardsConfigured = true
		}
	}

	// Fuel Type picker configuration (aviation vertical) — which AviationFuelType
	// entries appear in the Fuel Type picker on Edit Vehicle / Edit Fuel Log.
	var enabledFuelTypesRaw: [String] = []
	var fuelTypesConfigured: Bool = false    // distinguishes "not yet set up" from "all fuels hidden"

	var enabledFuelTypes: [AviationFuelType] {
		get {
			guard fuelTypesConfigured else { return AviationFuelType.defaultEnabled }
			return enabledFuelTypesRaw.compactMap(AviationFuelType.init(rawValue:))
		}
		set {
			enabledFuelTypesRaw = newValue.map(\.rawValue)
			fuelTypesConfigured = true
		}
	}

	// Fuel Type picker configuration (marine vertical) — which MarineFuelType
	// entries appear in the Fuel Type picker on Edit Vehicle / Edit Fuel Log.
	var enabledMarineFuelTypesRaw: [String] = []
	var marineFuelTypesConfigured: Bool = false    // distinguishes "not yet set up" from "all fuels hidden"

	var enabledMarineFuelTypes: [MarineFuelType] {
		get {
			guard marineFuelTypesConfigured else { return MarineFuelType.defaultEnabled }
			return enabledMarineFuelTypesRaw.compactMap(MarineFuelType.init(rawValue:))
		}
		set {
			enabledMarineFuelTypesRaw = newValue.map(\.rawValue)
			marineFuelTypesConfigured = true
		}
	}

	// Fuel Type picker configuration (land vertical) — which LandFuelType
	// entries appear in the Fuel Type picker on Edit Vehicle / Edit Fuel Log.
	var enabledLandFuelTypesRaw: [String] = []
	var landFuelTypesConfigured: Bool = false    // distinguishes "not yet set up" from "all fuels hidden"

	var enabledLandFuelTypes: [LandFuelType] {
		get {
			guard landFuelTypesConfigured else { return LandFuelType.defaultEnabled }
			return enabledLandFuelTypesRaw.compactMap(LandFuelType.init(rawValue:))
		}
		set {
			enabledLandFuelTypesRaw = newValue.map(\.rawValue)
			landFuelTypesConfigured = true
		}
	}

	var enabledHydraulicFluidTypesRaw: [String] = []
	var hydraulicFluidTypesConfigured: Bool = false

	var enabledHydraulicFluidTypes: [AviationHydraulicFluidType] {
		get {
			guard hydraulicFluidTypesConfigured else { return AviationHydraulicFluidType.defaultEnabled }
			return enabledHydraulicFluidTypesRaw.compactMap(AviationHydraulicFluidType.init(rawValue:))
		}
		set {
			enabledHydraulicFluidTypesRaw = newValue.map(\.rawValue)
			hydraulicFluidTypesConfigured = true
		}
	}

	var enabledMarineHydraulicFluidTypesRaw: [String] = []
	var marineHydraulicFluidTypesConfigured: Bool = false

	var enabledMarineHydraulicFluidTypes: [MarineHydraulicFluidType] {
		get {
			guard marineHydraulicFluidTypesConfigured else { return MarineHydraulicFluidType.defaultEnabled }
			return enabledMarineHydraulicFluidTypesRaw.compactMap(MarineHydraulicFluidType.init(rawValue:))
		}
		set {
			enabledMarineHydraulicFluidTypesRaw = newValue.map(\.rawValue)
			marineHydraulicFluidTypesConfigured = true
		}
	}

	var enabledLandHydraulicFluidTypesRaw: [String] = []
	var landHydraulicFluidTypesConfigured: Bool = false

	var enabledLandHydraulicFluidTypes: [LandHydraulicFluidType] {
		get {
			guard landHydraulicFluidTypesConfigured else { return LandHydraulicFluidType.defaultEnabled }
			return enabledLandHydraulicFluidTypesRaw.compactMap(LandHydraulicFluidType.init(rawValue:))
		}
		set {
			enabledLandHydraulicFluidTypesRaw = newValue.map(\.rawValue)
			landHydraulicFluidTypesConfigured = true
		}
	}

	// Home location — captured via Settings' "Use Current Location" button. Optional: nil
	// until the user sets it. Consulted by LabelLocationTextview (Fuel Log/Travel Log
	// location fields) to offer "Home" as the top "Use" choice when it's closer than any
	// live-searched airport/marina/business result.
	var homeLatitude: Double?
	var homeLongitude: Double?

	var hasHomeLocation: Bool { homeLatitude != nil && homeLongitude != nil }

	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""

	init(userName: String = "",
				 unitVolumeFuel: String = "",
				 unitVolumeOil: String = "",
				 unitVolumeDEF: String = "",
				 unitTemp: String = "",
				 unitSpeed: String = "",
				 unitPressure: String = "",
				 unitMass: String = "",
				 unitLength: String = "",
				 unitWidth: String = "",
				 unitHeight: String = "",
				 unitWheelBase: String = "",
				 image1: Data? = nil,
				 image1Description: String = "",
				 image2: Data? = nil,
				 image2Description: String = "",
				 image3: Data? = nil,
				 image3Description: String = ""
				 
	) {
		self.userName = userName
		self.unitVolumeFuel = unitVolumeFuel
		self.unitVolumeOil = unitVolumeOil
		self.unitVolumeDEF = unitVolumeDEF
		self.unitTemp = unitTemp
		self.unitSpeed = unitSpeed
		self.unitPressure = unitPressure
		self.unitMass = unitMass
		self.unitLength = unitLength
		self.unitWidth = unitWidth
		self.unitHeight = unitHeight
		self.unitWheelBase = unitWheelBase
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
}

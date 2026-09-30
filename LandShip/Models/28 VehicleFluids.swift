//
//  28 VehicleFluids.swift
//  LandShip
//
//  Tracks fluids used by a vehicle (engine oil, ATF, gear oil, etc.), linked
//  to a vehicle by vehicleId. One row per lubricated/fluid-filled component
//  so a vehicle with several fluid-bearing components (engine, transmission,
//  rear axle, transfer case...) can list them all separately. Component name
//  and fluid type are user-definable free text (see EditVehicleFluid.swift).
//

import Foundation
import SwiftData

@Model
class VehicleFluid {
	var vehicleId: String = ""
	var componentName: String = ""
	var fluidType: String = ""
	var quantityRequired: Float = 0
	var quantityUnit: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		vehicleId: String = "",
		componentName: String = "",
		fluidType: String = "",
		quantityRequired: Float = 0,
		quantityUnit: String = "",
		createdAt: Date = Date(),
		updatedAt: Date = Date()
	) {
		self.vehicleId = vehicleId
		self.componentName = componentName
		self.fluidType = fluidType
		self.quantityRequired = quantityRequired
		self.quantityUnit = quantityUnit
		self.createdAt = createdAt
		self.updatedAt = updatedAt
	}
}

//
//  DataModels.swift
//  LandShip
//
//  Created by JP on 7/19/25.
//

import Foundation
import SwiftData

@Model
class Vehicle8	{
	var inactive: Bool = false
	var name: String = ""
	var displayName: String = ""
	var manufacturer: String = ""
	var model: String = ""
	var year: Int = 0
	var trim: String = ""
	var mileage: Int = 0
	var mileageVirtual: Int = 0
	var engHours: Float = 0.0
	var transmission: String = ""
	var engine: String = ""
	var engineSerialNumber: String = ""
	var transmissionSerialNumber: String = ""
	var fuelType: String = ""
	// Land-vehicle-only (Vertical.current.id == .land): the hydraulic fluid spec the
	// vehicle takes (e.g. "ISO 32", "Dexron VI") and the system's fill capacity.
	var hydraulicFluidType: String = ""
	var hydraulicFluidCapacity: Int = 0
	var doors: Int = 0
	var seats: Int = 0
	var cargoSpace: Int = 0
	var length: Int = 0
	var width: Int = 0
	var height: Int = 0
	var weight: Int = 0
	var dateWeighed: Date = Date()
	var wheelbase: Int = 0
	var gvwr: Int = 0
	var gcwr: Int = 0
	var gawrFront: Int = 0
	var gawrRear: Int = 0
	var towingCapcity: Int = 0
	var uvw: Int = 0
	var ccc: Int = 0
	var fuelCapacity: Int = 0
	// Per-tank capacities for aircraft with multiple fuel tanks (AeroTrax). `numberOfFuelTanks`
	// (1-6) controls how many of these are shown/required in the editor; `fuelCapacity` above
	// is kept in sync as the sum of tank1...tankN so existing fuel-level math elsewhere
	// (EditFuelLog, EditTripLog) keeps working unchanged for aviation vehicles.
	var numberOfFuelTanks: Int = 1
	var fuelTank1Capacity: Int = 0
	var fuelTank2Capacity: Int = 0
	var fuelTank3Capacity: Int = 0
	var fuelTank4Capacity: Int = 0
	var fuelTank5Capacity: Int = 0
	var fuelTank6Capacity: Int = 0
	var fuelTank1Name: String = ""
	var fuelTank2Name: String = ""
	var fuelTank3Name: String = ""
	var fuelTank4Name: String = ""
	var fuelTank5Name: String = ""
	var fuelTank6Name: String = ""
	var defCapacity: Int = 0
	var waterCapacity: Int = 0
	var grayCapacity: Int = 0
	var blackCapacity: Int = 0
	var imageUrl: String = ""
	var price: Int = 0
	var notes: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()
	var ownerId: String = ""
	var locationId: String = ""
	var vin: String = ""
	var licensePlate: String = ""
	
	var datePurchased: Date = Date()
	var placePurchased: String = ""
	var tireSize: String = ""
	var titleNumber: String = ""

	var onlineServiceProvider: String = ""
	var onlineServiceNumber: String = ""
	var onlineServiceLogin: String = ""
	var onlineServiceURL: String = ""
	var onlineServiceBillingAccount: String = ""
	var vehicleMobileNumber: String = ""

	var insuranceCompany: String = ""
	var insurancePolicyNumber: String = ""
	var insurancePolicyHolder: String = ""
	var insuranceExpiration: Date = Date()

	var tirePressureFront: Int = 0
	var tirePressureRear: Int = 0
	var tirePressureTag: Int = 0
	var tirePressurePusher: Int = 0
	var wheelStudSize: String = ""
	var wheelNutSocket: String = ""
	var wheelNutTorque: String = ""
	var availablePayload: Int = 0
	var scaleWeightFrontAxle: Int = 0
	var scaleWeightRearAxle: Int = 0
	var scaleWeightPusherAxle: Int = 0
	var scaleWeightTagAxle: Int = 0
	var scaleWeightTrailerAxle: Int = 0
	var sortOrder: Int = 0
	var numberOfEngines: Int = 1

	// What `engHours` means — PartTimeBase rawValue, e.g. "Hobbs Time". Declared once per
	// aircraft so derived part-life math can disclose which meter it used. Empty string
	// means undeclared (pre-existing rows, or land/marine which don't use this).
	var hoursMeterType: String = ""
	// Cycles (landings) accrued before this vehicle was entered into the app. Aircraft
	// cycles are derived by summing this plus TripLog2.landings — never a high-water mark,
	// since a landing count is an increment, not a meter reading. See PartTimeMath.swift.
	var cyclesAtEntry: Int = 0

	// MARK: - Linked Vehicle Records
	// Allows multiple Vehicle8 records to represent different aspects of the same physical
	// vehicle (e.g. chassis, body/house, engine). One record is the "master"; others link to
	// it via `linkedMasterVehicleId` (matching the master's `name`). A vehicle is considered
	// the master simply by having other vehicles link to it - no separate flag is stored.
	var linkedMasterVehicleId: String = ""
	var vehicleAspect: String = ""
	// Raw values of the user-selected LinkableVehicleField cases to mirror from the master.
	var linkedSyncFieldsRaw: [String] = []

	var linkedSyncFields: Set<LinkableVehicleField> {
		get { Set(linkedSyncFieldsRaw.compactMap(LinkableVehicleField.init(rawValue:))) }
		set { linkedSyncFieldsRaw = newValue.map(\.rawValue) }
	}

	/// Copies the values for each selected `linkedSyncFields` case from `master` onto this record.
	func applyLinkedFields(from master: Vehicle8) {
		for field in linkedSyncFields {
			switch field {
				case .odometer:
					mileage = master.mileage
					mileageVirtual = master.mileageVirtual
				case .engineHours:
					engHours = master.engHours
				case .location:
					locationId = master.locationId
				case .owner:
					ownerId = master.ownerId
				case .insurance:
					insuranceCompany = master.insuranceCompany
					insurancePolicyNumber = master.insurancePolicyNumber
					insurancePolicyHolder = master.insurancePolicyHolder
					insuranceExpiration = master.insuranceExpiration
				case .vin:
					vin = master.vin
				case .licensePlate:
					licensePlate = master.licensePlate
				case .titleNumber:
					titleNumber = master.titleNumber
			}
		}
	}

	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""

	init(inactive: Bool = false,
			 name: String = "",
			 displayName: String = "",
			 manufacturer: String = "",
			 model: String = "",
			 year: Int = 2024,
			 trim: String = "",
			 mileage: Int = 0,
			 mileageVirtual: Int = 0,
			 engHours: Float = 0.0,
			 transmission: String = "",
			 engine: String = "",
			 engineSerialNumber: String = "",
			 transmissionSerialNumber: String = "",
			 fuelType: String = "",
			 hydraulicFluidType: String = "",
			 hydraulicFluidCapacity: Int = 0,
			 doors: Int = 0,
			 seats: Int = 0,
			 cargoSpace: Int = 0,
			 length: Int = 0,
			 width: Int = 0,
			 height: Int = 0,
			 weight: Int = 0,
			 dateWeighed: Date = .now,
				wheelbase: Int = 0,
				gvwr: Int = 0,
				gcwr: Int = 0,
			 gawrFront: Int = 0,
				gawrRear: Int = 0,
				towingCapcity: Int = 0,
				uvw: Int = 0,
				ccc: Int = 0,
			 fuelCapacity: Int = 0,
			 numberOfFuelTanks: Int = 1,
			 fuelTank1Capacity: Int = 0,
			 fuelTank2Capacity: Int = 0,
			 fuelTank3Capacity: Int = 0,
			 fuelTank4Capacity: Int = 0,
			 fuelTank5Capacity: Int = 0,
			 fuelTank6Capacity: Int = 0,
			 fuelTank1Name: String = "",
			 fuelTank2Name: String = "",
			 fuelTank3Name: String = "",
			 fuelTank4Name: String = "",
			 fuelTank5Name: String = "",
			 fuelTank6Name: String = "",
			 defCapacity: Int = 0,
			waterCapacity: Int = 0,
				grayCapacity: Int = 0,
				blackCapacity: Int = 0,
			 imageUrl: String = "",
			 price: Int = 0,
			 notes: String = "",
			 createdAt: Date = .now,
			 updatedAt: Date = .now,
			 ownerId: String = "",
			 locationId: String = "",
			 vin: String = "",
			 licensePlate: String = "",
			 
			 datePurchased: Date = Date(),
			 placePurchased: String = "",
			 
			 tireSize: String = "",
			 titleNumber: String = "",
			 
			 onlineServiceProvider: String = "",
			 onlineServiceNumber: String = "",
			 onlineServiceLogin: String = "",
			 onlineServiceURL: String = "",
			 onlineServiceBillingAccount: String = "",
			 vehicleMobileNumber: String = "",
			 
			 insuranceCompany: String = "",
			 insurancePolicyNumber: String = "",
			 insurancePolicyHolder: String = "",
			 insuranceExpiration: Date = Date(),
			 
			 tirePressureFront: Int = 0,
			 tirePressureRear: Int = 0,
			 tirePressureTag: Int = 0,
			 tirePressurePusher: Int = 0,
			 wheelStudSize: String = "",
			 wheelNutSocket: String = "",
			 wheelNutTorque: String = "",
			 availablePayload: Int = 0,
			 scaleWeightFrontAxle: Int = 0,
			 scaleWeightRearAxle: Int = 0,
			 scaleWeightPusherAxle: Int = 0,
			 scaleWeightTagAxle: Int = 0,
			 scaleWeightTrailerAxle: Int = 0,
			 sortOrder: Int = 0,
			 numberOfEngines: Int = 1,
			 hoursMeterType: String = "",
			 cyclesAtEntry: Int = 0,

			 linkedMasterVehicleId: String = "",
			 vehicleAspect: String = "",
			 linkedSyncFieldsRaw: [String] = [],

			 image1: Data? = nil,
			 image1Description: String = "",
			 image2: Data? = nil,
			 image2Description: String = "",
			 image3: Data? = nil,
			 image3Description: String = ""
	) {
		self.inactive = inactive
		self.name = name
		self.displayName = displayName.isEmpty ? name : displayName
		self.manufacturer = manufacturer
		self.model = model
		self.year = year
		self.trim = trim
		self.mileage = mileage
		self.mileageVirtual = mileageVirtual
		self.engHours = engHours
		self.transmission = transmission
		self.engine = engine
		self.engineSerialNumber = engineSerialNumber
		self.transmissionSerialNumber = transmissionSerialNumber
		self.fuelType = fuelType
		self.hydraulicFluidType = hydraulicFluidType
		self.hydraulicFluidCapacity = hydraulicFluidCapacity
		self.doors = doors
		self.seats = seats
		self.cargoSpace = cargoSpace
		self.length = length
		self.width = width
		self.height = height
		self.weight = weight
		self.dateWeighed = dateWeighed
		self.wheelbase = wheelbase
		self.gvwr = gvwr
		self.gcwr = gcwr
		self.gawrFront = gawrFront
		self.gawrRear = gawrRear
		self.towingCapcity = towingCapcity
		self.uvw = uvw
		self.ccc = ccc
		self.fuelCapacity = fuelCapacity
		self.numberOfFuelTanks = numberOfFuelTanks
		self.fuelTank1Capacity = fuelTank1Capacity
		self.fuelTank2Capacity = fuelTank2Capacity
		self.fuelTank3Capacity = fuelTank3Capacity
		self.fuelTank4Capacity = fuelTank4Capacity
		self.fuelTank5Capacity = fuelTank5Capacity
		self.fuelTank6Capacity = fuelTank6Capacity
		self.fuelTank1Name = fuelTank1Name
		self.fuelTank2Name = fuelTank2Name
		self.fuelTank3Name = fuelTank3Name
		self.fuelTank4Name = fuelTank4Name
		self.fuelTank5Name = fuelTank5Name
		self.fuelTank6Name = fuelTank6Name
		self.defCapacity = defCapacity
		self.waterCapacity = waterCapacity
		self.grayCapacity = grayCapacity
		self.blackCapacity = blackCapacity
		self.imageUrl = imageUrl
		self.price = price
		self.notes = notes
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.ownerId = ownerId
		self.locationId = locationId
		self.vin = vin
		self.licensePlate = licensePlate
		
		self.datePurchased = datePurchased
		self.placePurchased = placePurchased
		
		self.tireSize = tireSize
		self.titleNumber = titleNumber
		
		self.onlineServiceProvider = onlineServiceProvider
		self.onlineServiceNumber = onlineServiceNumber
		self.onlineServiceLogin = onlineServiceLogin
		self.onlineServiceURL = onlineServiceURL
		self.onlineServiceBillingAccount = onlineServiceBillingAccount
		self.vehicleMobileNumber = vehicleMobileNumber
		
		self.insuranceCompany = insuranceCompany
		self.insurancePolicyNumber = insurancePolicyNumber
		self.insurancePolicyHolder = insurancePolicyHolder
		self.insuranceExpiration = insuranceExpiration
		
		self.tirePressureFront = tirePressureFront
		self.tirePressureRear = tirePressureRear
		self.tirePressureTag = tirePressureTag
		self.tirePressurePusher = tirePressurePusher
		self.wheelStudSize = wheelStudSize
		self.wheelNutSocket = wheelNutSocket
		self.wheelNutTorque = wheelNutTorque
		self.availablePayload = availablePayload
		self.scaleWeightFrontAxle = scaleWeightFrontAxle
		self.scaleWeightRearAxle = scaleWeightRearAxle
		self.scaleWeightPusherAxle = scaleWeightPusherAxle
		self.scaleWeightTagAxle = scaleWeightTagAxle
		self.scaleWeightTrailerAxle = scaleWeightTrailerAxle
		self.sortOrder = sortOrder
		self.numberOfEngines = numberOfEngines
		self.hoursMeterType = hoursMeterType
		self.cyclesAtEntry = cyclesAtEntry

		self.linkedMasterVehicleId = linkedMasterVehicleId
		self.vehicleAspect = vehicleAspect
		self.linkedSyncFieldsRaw = linkedSyncFieldsRaw

		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
	}
}

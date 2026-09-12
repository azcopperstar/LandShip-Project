//
//  MxParts1.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import Foundation
import SwiftData

@Model
class MxParts1 {
	
		var inactive: Bool = false
		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var vehicleId: String = ""
		var vehicleSystem: String = ""
		var partName: String = ""
		var partNumber: String = ""
		var partManufacture: String = ""
		var partDescription: String = ""
		var Notes: String = ""
		var costPerUnit: Float = 0
		var partUnit: String = ""
		var partSource: String = ""
		var partQuantity: Int = 0
		var partLocation: String = ""
		var partStatus: String = ""
		var partImage: Data? = nil
		var partSupplier: String = ""

		// Inventory tracking. When `inventoryTracked` is false, the remaining fields are
		// ignored everywhere else in the app (EditRecord consumption, DisplayParts, dashboard).
		var inventoryTracked: Bool = false
		var inventoryQuantityOnHand: Float = 0
		var inventoryReorderPoint: Float = 0
		var inventoryReorderQuantity: Float = 0

		// MARK: - Aviation compliance (AeroTrax only, see Vertical.enabledFeatures.partCompliance).
		// All additive/defaulted so land/marine and pre-existing rows are unaffected. Surfaced
		// via sub-editor sheets in EditParts.swift, not inline — see PartApprovalBasis /
		// PartConditionCode / PartClass / PartLimitType / PartTimeBase / ReleaseDocumentType
		// in 11 Enums.swift for the enums these rawValues correspond to.

		// Identity
		var serialNumber: String = ""
		var lotNumber: String = ""
		var nomenclature: String = ""
		var ataChapter: String = ""              // ATAChapter.code — see Verticals/ATAChapters.swift
		var alternatePartNumbers: String = ""    // comma-separated, deliberately not a many-to-many
		var supersededByPartNumber: String = ""
		var partClass: String = ""               // PartClass rawValue

		// Airworthiness approval basis — "is it legal to install," distinct from identity
		var approvalBasis: String = ""           // PartApprovalBasis rawValue
		var releaseDocumentType: String = ""     // ReleaseDocumentType rawValue
		var stcNumber: String = ""
		var ownerProducedJustification: String = ""   // 14 CFR 21.9(a)(5)
		var sourceTraceability: String = ""
		var icaReference: String = ""

		// Time & life — carry-in balances, used when no PartInstallation segment exists yet
		// (never-installed-via-the-app stock). See PartTimeMath.swift for the derivation
		// that layers PartInstallation segments on top of these.
		var limitType: String = ""               // PartLimitType rawValue
		var limitHours: Float = 0
		var limitCycles: Int = 0
		var limitCalendarMonths: Int = 0
		var limitTimeBase: String = ""           // PartTimeBase rawValue — what the limit is expressed in
		var maintenanceProgram: String = ""       // Hard Time / On-Condition / Condition Monitoring
		var carryInTSN: Float = 0
		var carryInCSN: Int = 0
		var carryInTSO: Float = 0
		var carryInCSO: Int = 0
		var carryInTSR: Float = 0

		// Condition & status
		var conditionCode: String = ""           // PartConditionCode rawValue
		var shelfLifeExpiry: Date?
		var cureDate: Date?
		var quarantineNotes: String = ""
		var storageRequirements: String = ""

		// Commercial / inventory
		var poNumber: String = ""
		var invoiceNumber: String = ""
		var warrantyExpiryDate: Date?
		var warrantyExpiryHours: Float = 0
		var isExchangeUnit: Bool = false
		var coreReturnDueDate: Date?
		var coreReturnedDate: Date?
		var coreDepositAmount: Float = 0

	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""


	init (
		inactive: Bool = false,
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		vehicleId: String,
		vehicleSystem: String,
		partName: String,
		partNumber: String,
		partManufacture: String,
		partDescription: String,
		Notes: String,
		costPerUnit: Float,
		partUnit: String,
		partSource: String,
		partQuantity: Int,
		partLocation: String,
		partStatus: String,
		partImage: Data? = nil,
		partSupplier: String,
		inventoryTracked: Bool = false,
		inventoryQuantityOnHand: Float = 0,
		inventoryReorderPoint: Float = 0,
		inventoryReorderQuantity: Float = 0,
		serialNumber: String = "",
		lotNumber: String = "",
		nomenclature: String = "",
		ataChapter: String = "",
		alternatePartNumbers: String = "",
		supersededByPartNumber: String = "",
		partClass: String = "",
		approvalBasis: String = "",
		releaseDocumentType: String = "",
		stcNumber: String = "",
		ownerProducedJustification: String = "",
		sourceTraceability: String = "",
		icaReference: String = "",
		limitType: String = "",
		limitHours: Float = 0,
		limitCycles: Int = 0,
		limitCalendarMonths: Int = 0,
		limitTimeBase: String = "",
		maintenanceProgram: String = "",
		carryInTSN: Float = 0,
		carryInCSN: Int = 0,
		carryInTSO: Float = 0,
		carryInCSO: Int = 0,
		carryInTSR: Float = 0,
		conditionCode: String = "",
		shelfLifeExpiry: Date? = nil,
		cureDate: Date? = nil,
		quarantineNotes: String = "",
		storageRequirements: String = "",
		poNumber: String = "",
		invoiceNumber: String = "",
		warrantyExpiryDate: Date? = nil,
		warrantyExpiryHours: Float = 0,
		isExchangeUnit: Bool = false,
		coreReturnDueDate: Date? = nil,
		coreReturnedDate: Date? = nil,
		coreDepositAmount: Float = 0,
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""
	)
	{
		self.inactive = inactive
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.vehicleId = vehicleId
		self.vehicleSystem = vehicleSystem
		self.partName = partName
		self.partNumber = partNumber
		self.partManufacture = partManufacture
		self.partDescription = partDescription
		self.Notes = Notes
		self.costPerUnit = costPerUnit
		self.partUnit = partUnit
		self.partSource = partSource
		self.partQuantity = partQuantity
		self.partLocation = partLocation
		self.partStatus = partStatus
		self.partImage = partImage
		self.partSupplier = partSupplier
		self.inventoryTracked = inventoryTracked
		self.inventoryQuantityOnHand = inventoryQuantityOnHand
		self.inventoryReorderPoint = inventoryReorderPoint
		self.inventoryReorderQuantity = inventoryReorderQuantity
		self.serialNumber = serialNumber
		self.lotNumber = lotNumber
		self.nomenclature = nomenclature
		self.ataChapter = ataChapter
		self.alternatePartNumbers = alternatePartNumbers
		self.supersededByPartNumber = supersededByPartNumber
		self.partClass = partClass
		self.approvalBasis = approvalBasis
		self.releaseDocumentType = releaseDocumentType
		self.stcNumber = stcNumber
		self.ownerProducedJustification = ownerProducedJustification
		self.sourceTraceability = sourceTraceability
		self.icaReference = icaReference
		self.limitType = limitType
		self.limitHours = limitHours
		self.limitCycles = limitCycles
		self.limitCalendarMonths = limitCalendarMonths
		self.limitTimeBase = limitTimeBase
		self.maintenanceProgram = maintenanceProgram
		self.carryInTSN = carryInTSN
		self.carryInCSN = carryInCSN
		self.carryInTSO = carryInTSO
		self.carryInCSO = carryInCSO
		self.carryInTSR = carryInTSR
		self.conditionCode = conditionCode
		self.shelfLifeExpiry = shelfLifeExpiry
		self.cureDate = cureDate
		self.quarantineNotes = quarantineNotes
		self.storageRequirements = storageRequirements
		self.poNumber = poNumber
		self.invoiceNumber = invoiceNumber
		self.warrantyExpiryDate = warrantyExpiryDate
		self.warrantyExpiryHours = warrantyExpiryHours
		self.isExchangeUnit = isExchangeUnit
		self.coreReturnDueDate = coreReturnDueDate
		self.coreReturnedDate = coreReturnedDate
		self.coreDepositAmount = coreDepositAmount
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
	}
}

//
//  MX.swift
//  LandShip
//
//  Created by JP on 7/20/25.
//

import Foundation
import SwiftData

extension ServiceRecords1: Identifiable {}

@Model
class ServiceRecords1 {

		var inactive: Bool = false
		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var mxDate: Date = Date()
		var vehicleId: String = ""
		var Miles: Int = 0
		var engHours: Float = 0
		var mxName: String = ""
		var mxItemId: String = ""
		var mxDescription: String = ""
		var Notes: String = ""
		var vendor: String = ""
		var laborCost: Float = 0
		var part1: String = ""
		var part1cost: Float = 0
		var part1Unit: String = ""
		var part1Quantity: Int = 0
		var part2: String = ""
		var part2cost: Float = 0
		var part2Unit: String = ""
		var part2Quantity: Int = 0
		var part3: String = ""
		var part3cost: Float = 0
		var part3Unit: String = ""
		var part3Quantity: Int = 0
		var part4: String = ""
		var part4cost: Float = 0
		var part4Unit: String = ""
		var part4Quantity: Int = 0
		var part5: String = ""
		var part5cost: Float = 0
		var part5Unit: String = ""
		var part5Quantity: Int = 0
		// User-defined numeric tracking field to complement Miles/engHours (e.g. "Water Gallons" in "gal")
		var customMeasureLabel: String = ""
		var customMeasureUnit: String = ""
		var customMeasureValue: Float = 0
		var image: Data? = nil
	@Attribute(.externalStorage)
	var image1: Data?
	var image1Description: String = ""
	@Attribute(.externalStorage)
	var image2: Data?
	var image2Description: String = ""
	@Attribute(.externalStorage)
	var image3: Data?
	var image3Description: String = ""
	@Attribute(.externalStorage)
	var image4: Data?
	var image4Description: String = ""
	@Attribute(.externalStorage)
	var image5: Data?
	var image5Description: String = ""
	var additionsLinkId: String = ""

	init(
		inactive: Bool = false,
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		mxDate: Date = Date(),
		vehicleId: String = "",
		Miles: Int = 0,
		engHours: Float = 0,
		mxName: String = "",
		mxItemId: String = "",
		mxDescription: String = "",
		Notes: String = "",
		vendor: String = "",
		laborCost: Float = 0,
		part1: String = "",
		part1cost: Float = 0,
		part1Unit: String = "",
		part1Quantity: Int = 0,
		part2: String = "",
		part2cost: Float = 0,
		part2Unit: String = "",
		part2Quantity: Int = 0,
		part3: String = "",
		part3cost: Float = 0,
		part3Unit: String = "",
		part3Quantity: Int = 0,
		part4: String = "",
		part4cost: Float = 0,
		part4Unit: String = "",
		part4Quantity: Int = 0,
		part5: String = "",
		part5cost: Float = 0,
		part5Unit: String = "",
		part5Quantity: Int = 0,
		customMeasureLabel: String = "",
		customMeasureUnit: String = "",
		customMeasureValue: Float = 0,
		image: Data? = nil,
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = "",
		image4: Data? = nil,
		image4Description: String = "",
		image5: Data? = nil,
		image5Description: String = ""

	)
	{
		self.inactive = inactive
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.mxDate = mxDate
		self.vehicleId = vehicleId
		self.Miles = Miles
		self.engHours = engHours
		self.mxName = mxName
		self.mxItemId = mxItemId
		self.mxDescription = mxDescription
		self.Notes = Notes
		self.vendor = vendor
		self.laborCost = laborCost
		self.part1 = part1
		self.part1cost = part1cost
		self.part1Unit = part1Unit
		self.part1Quantity = part1Quantity
		self.part2 = part2
		self.part2cost = part2cost
		self.part2Unit = part2Unit
		self.part2Quantity = part2Quantity
		self.part3 = part3
		self.part3cost = part3cost
		self.part3Unit = part3Unit
		self.part3Quantity = part3Quantity
		self.part4 = part4
		self.part4cost = part4cost
		self.part4Unit = part4Unit
		self.part4Quantity = part4Quantity
		self.part5 = part5
		self.part5cost = part5cost
		self.part5Unit = part5Unit
		self.part5Quantity = part5Quantity
		self.customMeasureLabel = customMeasureLabel
		self.customMeasureUnit = customMeasureUnit
		self.customMeasureValue = customMeasureValue
		self.image = image
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description
		self.image4 = image4
		self.image4Description = image4Description
		self.image5 = image5
		self.image5Description = image5Description

	}

	/// Create a record from a generic project item dictionary. Keys should match property names where possible.
	/// This provides a flexible way to map an existing project item into a logbook entry without importing other types here.
	convenience init(fromProjectItem item: [String: Any], vehicleId: String) {
	    self.init(
	        inactive: (item["inactive"] as? Bool) ?? false,
	        createdAt: (item["createdAt"] as? Date) ?? Date(),
	        updatedAt: Date(),
	        mxDate: (item["mxDate"] as? Date) ?? Date(),
	        vehicleId: vehicleId,
	        Miles: (item["Miles"] as? Int) ?? (item["miles"] as? Int) ?? 0,
	        engHours: (item["engHours"] as? Float) ?? 0,
	        mxName: (item["mxName"] as? String) ?? (item["name"] as? String) ?? "",
	        mxItemId: (item["mxItemId"] as? String) ?? (item["itemId"] as? String) ?? "",
	        mxDescription: (item["mxDescription"] as? String) ?? (item["description"] as? String) ?? "",
	        Notes: (item["Notes"] as? String) ?? (item["notes"] as? String) ?? "",
	        vendor: (item["vendor"] as? String) ?? "",
	        laborCost: (item["laborCost"] as? Float) ?? 0,
	        part1: (item["part1"] as? String) ?? "",
	        part1cost: (item["part1cost"] as? Float) ?? 0,
	        part1Unit: (item["part1Unit"] as? String) ?? "",
	        part1Quantity: (item["part1Quantity"] as? Int) ?? 0,
	        part2: (item["part2"] as? String) ?? "",
	        part2cost: (item["part2cost"] as? Float) ?? 0,
	        part2Unit: (item["part2Unit"] as? String) ?? "",
	        part2Quantity: (item["part2Quantity"] as? Int) ?? 0,
	        part3: (item["part3"] as? String) ?? "",
	        part3cost: (item["part3cost"] as? Float) ?? 0,
	        part3Unit: (item["part3Unit"] as? String) ?? "",
	        part3Quantity: (item["part3Quantity"] as? Int) ?? 0,
	        part4: (item["part4"] as? String) ?? "",
	        part4cost: (item["part4cost"] as? Float) ?? 0,
	        part4Unit: (item["part4Unit"] as? String) ?? "",
	        part4Quantity: (item["part4Quantity"] as? Int) ?? 0,
	        part5: (item["part5"] as? String) ?? "",
	        part5cost: (item["part5cost"] as? Float) ?? 0,
	        part5Unit: (item["part5Unit"] as? String) ?? "",
	        part5Quantity: (item["part5Quantity"] as? Int) ?? 0,
	        customMeasureLabel: (item["customMeasureLabel"] as? String) ?? "",
	        customMeasureUnit: (item["customMeasureUnit"] as? String) ?? "",
	        customMeasureValue: (item["customMeasureValue"] as? Float) ?? 0,
	        image: item["image"] as? Data,
	        image1: item["image1"] as? Data,
	        image1Description: (item["image1Description"] as? String) ?? "",
	        image2: item["image2"] as? Data,
	        image2Description: (item["image2Description"] as? String) ?? "",
	        image3: item["image3"] as? Data,
	        image3Description: (item["image3Description"] as? String) ?? "",
	        image4: item["image4"] as? Data,
	        image4Description: (item["image4Description"] as? String) ?? "",
	        image5: item["image5"] as? Data,
	        image5Description: (item["image5Description"] as? String) ?? ""
	    )
	}

	/// Save this record into the provided SwiftData context if `saveInLogbook` is true.
	/// Returns true if inserted.
	@discardableResult
	func saveIfNeeded(saveInLogbook: Bool, in context: ModelContext) -> Bool {
	    guard saveInLogbook else { return false }
	    context.insert(self)
	    return true
	}
}

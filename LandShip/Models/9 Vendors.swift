//
//  Vendors1.swift
//  LandShip
//
//  Created by JP on 8/12/25.
//

import Foundation
import SwiftData

@Model
class Vendors1 {

		var createdAt: Date = Date()
		var updatedAt: Date = Date()
		var vendorName: String = ""
		var vendorType: String = ""
		var vendorContact1: String = ""
		var vendorContact2: String = ""
		var vendorContact3: String = ""
		var vendorAddress: String = ""
		var vendorCity: String = ""
		var vendorState: String = ""
		var vendorZip: String = ""
		var vendorPhone: String = ""
		var vendorEmail: String = ""
		var vendorWebsite: String = ""
		var vendorNotes: String = ""
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
		createdAt: Date,
		updatedAt: Date,
		vendorName: String,
		vendorType: String,
		vendorContact1: String,
		vendorContact2: String,
		vendorContact3: String,
		vendorAddress: String,
		vendorCity: String,
		vendorState: String,
		vendorZip: String,
		vendorPhone: String,
		vendorEmail: String,
		vendorWebsite: String,
		vendorNotes: String,
		image1: Data? = nil,
		image1Description: String = "",
		image2: Data? = nil,
		image2Description: String = "",
		image3: Data? = nil,
		image3Description: String = ""

	)
	{
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.vendorName = vendorName
		self.vendorType = vendorType
		self.vendorContact1 = vendorContact1
		self.vendorContact2 = vendorContact2
		self.vendorContact3 = vendorContact3
		self.vendorAddress = vendorAddress
		self.vendorCity = vendorCity
		self.vendorState = vendorState
		self.vendorZip = vendorZip
		self.vendorPhone = vendorPhone
		self.vendorEmail = vendorEmail
		self.vendorWebsite = vendorWebsite
		self.vendorNotes = vendorNotes
		self.image1 = image1
		self.image1Description = image1Description
		self.image2 = image2
		self.image2Description = image2Description
		self.image3 = image3
		self.image3Description = image3Description

	}
}

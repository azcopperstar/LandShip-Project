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

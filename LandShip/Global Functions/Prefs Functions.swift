//
//  Prefs Functions.swift
//  LandShip
//
//  Created by JP on 10/1/25.
//

import Foundation
import SwiftData
import SwiftUI

class PrefsFunctions {
	// SHARED GET ALL SETTINGS FUNCTIONS
	// settings loader usable across the app
	func loadSettings(context: ModelContext, userName: String = "primary1") -> Settings1? {
		var fetchDescriptor = FetchDescriptor<Settings1>(
			predicate: #Predicate { setting in setting.userName == userName }
		)
		fetchDescriptor.fetchLimit = 1
		do {
			return try context.fetch(fetchDescriptor).first
		} catch {
			print("Failed to load settings: \(error.localizedDescription)")
			return nil
		}
	}
	// array-based loader (fixed order of 13 unit fields)
	// Index map: 0: unitVolumeFuel, 1: unitVolumeOil, 2: unitVolumeDEF, 3: unitTemp, 4: unitSpeed, 5: unitPressure, 6: unitMass, 7: unitDistance, 8: unitArea, 9: unitLength, 10: unitWidth, 11: unitHeight, 12: unitWheelBase
	func loadSettingsArray(context: ModelContext, userName: String = "primary1") -> [String]? {
		guard let s = loadSettings(context: context, userName: userName) else { return nil }
		return [
			s.unitVolumeFuel,
			s.unitVolumeOil,
			s.unitVolumeDEF,
			s.unitTemp,
			s.unitSpeed,
			s.unitPressure,
			s.unitMass,
			s.unitDistance,
			s.unitArea,
			s.unitLength,
			s.unitWidth,
			s.unitHeight,
			s.unitWheelBase
		]
	}
}
// index map for the array returned by Functions.loadSettingsArray(...)
// Index map above ^^^
// Add new indices here as you extend Settings1 and loadSettingsArray.
enum UnitIndex {
	static let fuel = 0
	static let oil = 1
	static let def = 2
	static let temp = 3
	static let speed = 4
	static let pressure = 5
	static let mass = 6
	static let distance = 7
	static let area = 8
	static let length = 9
	static let width = 10
	static let height = 11
	static let wheelBase = 12
}

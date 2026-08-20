//
//  Classes.swift
//  LandShip
//
//  Created by JP on 9/14/25.
//

import Foundation
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
import PDFKit

/// PDFView subclass that intercepts the system print: action (right-click context menu,
/// Cmd+P, or File > Print) and handles it directly via PDFDocument.printOperation.
/// Without this, those actions bubble up to NSApplication which shows
/// "this application does not support printing".
final class PrintablePDFView: PDFView {
	override func printView(_ sender: Any?) {
		guard let doc = self.document else { return }
		let printInfo = NSPrintInfo.shared
		if let op = doc.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true) {
			op.showsPrintPanel = true
			op.showsProgressPanel = true
			op.run()
		}
	}

}
#endif

//struct VehicleRef {
//	var vehicleId: String
//}
//
//struct Pref: View  {
////	@Environment(\.modelContext) var modelContext
//	@Query(filter: #Predicate<Settings1> {setting in setting.userName == "primary1"}) var settings: [Settings1]

//	init() {
//		_settings = Query(filter: #Predicate<Settings1> {setting in setting.userName == "primary1"})
//		print("settings.count: \(settings.count)")
//		print("settings.count: \(settings.count)")
//
//	}
	
//	struct Prefs {
//		var userName: String = ""
//		var unitVolumeFuel: String = ""
//		var unitTemp: String = ""
//		var unitSpeed: String = ""
//		var unitPressure: String = ""
//		var unitMass: String = ""
//		var unitDistance: String = ""
//		var unitArea: String = ""
//		var unitLength: String = ""
//		var unitWidth: String = ""
//		var unitHeight: String = ""
//		var unitWheelBase: String = ""
//		
//	}

//	var body: some View {
//		var prefs = Settings1()
//		//		let fetchDescriptor = FetchDescriptor<Settings1>(
//		//			predicate: #Predicate { setting in setting.userName == "primary1" })
//		//		do {
//		//			let settings = try modelContext.fetch(fetchDescriptor)
////		print("settings.count: \(settings.count)")
//		ForEach(settings) { setting in
//			prefs.unitVolumeFuel = setting.unitVolumeFuel
//			prefs.unitTemp = setting.unitTemp
//			prefs.unitSpeed = setting.unitSpeed
//			prefs.unitPressure = setting.unitPressure
//			prefs.unitMass = setting.unitMass
//			prefs.unitDistance = setting.unitDistance
//			prefs.unitArea = setting.unitArea
//			prefs.unitLength = setting.unitLength
//			prefs.unitWidth = setting.unitWidth
//			prefs.unitHeight = setting.unitHeight
//			prefs.unitWheelBase = setting.unitWheelBase
//			//			break
//		}
//		//		} catch {
//		//			print("Failed to load settings.")
//		//		}
//		print("prefs.unitVolumeFuel: \(prefs.unitVolumeFuel)")

//	}
	
//	func getPrefs() -> Settings1 {
//		var prefs = Settings1()
////		let fetchDescriptor = FetchDescriptor<Settings1>(
////			predicate: #Predicate { setting in setting.userName == "primary1" })
////		do {
////			let settings = try modelContext.fetch(fetchDescriptor)
//		print("settings.count: \(settings.count)")
//			for setting in settings {
//				prefs.unitVolumeFuel = setting.unitVolumeFuel
//				prefs.unitTemp = setting.unitTemp
//				prefs.unitSpeed = setting.unitSpeed
//				prefs.unitPressure = setting.unitPressure
//				prefs.unitMass = setting.unitMass
//				prefs.unitDistance = setting.unitDistance
//				prefs.unitArea = setting.unitArea
//				prefs.unitLength = setting.unitLength
//				prefs.unitWidth = setting.unitWidth
//				prefs.unitHeight = setting.unitHeight
//				prefs.unitWheelBase = setting.unitWheelBase
//				//			break
//			}
////		} catch {
////			print("Failed to load settings.")
////		}
//		print("prefs.unitVolumeFuel: \(prefs.unitVolumeFuel)")
//		return prefs
//	}
	
//}
	
	

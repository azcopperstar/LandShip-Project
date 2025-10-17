//
//  Functions.swift
//  LandShip
//
//  Created by JP on 8/15/25.
//

import Foundation
import SwiftData
import SwiftUI


struct RecordID: Codable, Hashable {
	var id = UUID()
	let recordID: String
	let vehicleId: String
}

// Lightweight container for commonly needed vehicle details
struct VehicleDetails: Codable, Hashable {
	let mileage: Int
	let engHours: Float
	let fuelCapacity: Int
	let fuelType: String
}

struct CheckboxToggleStyle: ToggleStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack {
			RoundedRectangle(cornerRadius: 5.0)
				.stroke(lineWidth: 2)
				.frame(width: 25, height: 25)
				.cornerRadius(5.0)
				.overlay {
					Image(systemName: configuration.isOn ? "checkmark" : "")
				}
				.onTapGesture {
					withAnimation(.spring()) {
						configuration.isOn.toggle()
					}
				}
			configuration.label
		}
	}
}


// for QueryView, for use, see: https://ihor.pro/implementing-a-swiftdata-query-view-as-the-most-convenient-way-to-fetch-data-in-swiftui-f69d59348783

struct QueryView<Model: PersistentModel, Content: View>: View {
	@Query private var query: [Model]
	private var content: ([Model]) -> (Content)
	init(for type: Model.Type,
			 sort: [SortDescriptor<Model>] = [],
			 @ViewBuilder content: @escaping ([Model]) -> Content,
			 filter: (() -> (Predicate<Model>))? = nil) {
		_query = Query(filter: filter?(), sort: sort)
		self.content = content
	}
	var body: some View {
		content(query)
	}
}

class Functions {
	
	func getFuelLevel(unit: Float) -> String {
		switch unit {
				// LWH
			case 1.0: return "Full Tank"
			case 0.875: return "7/8 Tank"
			case 0.75: return "3/4 Tank"
			case 0.625: return "5/8 Tank"
			case 0.5: return "1/2 Tank"
			case 0.375: return "3/8 Tank"
			case 0.25: return "1/4 Tank"
			case 0.125: return "1/8 Tank"
			case 0.0: return "Empty Tank"
				
			default: return ""
		}
	}
	
	
	func getUnits(unit: String) -> String {
		switch unit {
				// LWH
			case "ft": return "Feet"
			case "in": return "Inches"
			case "mm": return "Millimeters"
			case "cm": return "Centimeters"
				// area
			case "ft²": return "Square Feet"
			case "in²": return "Square Inches"
			case "cm²": return "Square Centimeters"
			case "m²": return "Square Meters"
				// distance
			case "mi": return "Miles"
			case "m": return "Meters"
			case "km": return "Kilometers"
				// mass
			case "lb": return "Pounds"
			case "oz": return "Onces"
			case "mg": return "Milligrams"
			case "g": return "Grams"
			case "kg": return "Kilograms"
			case "T": return "Tons"
			case "st": return "Stones"
				// pressure
			case "PSI": return "Pound Square Inch"
			case "Pa": return "Pascals"
				// speed
			case "mph": return "Miles per Hour"
			case "kph": return "Kilometers per Hour"
			case "kt": return "Knots"
				// volume
			case "gal": return "Gallons"
			case "qt": return "Quarts"
			case "pt": return "Pints"
			case "c": return "Cups"
			case "fl oz": return "Fluid Onces"
			case "ml": return "Millileters"
			case "l": return "Liters"
				
			default: return ""
		}
	}
	
	func formatYear(year: Int) -> String {
		//		let yearFormatted = year.formatted(.year.grouping(.never))
		let formatter = NumberFormatter()
		formatter.numberStyle = .none
		return formatter.string(from: NSNumber(value: year)) ?? "0000"
	}
	
	func formatCurrency(dollars: Float) -> String {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.locale = Locale(identifier: "en_US") // USD
		return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
	}
	
	func formatDate_HHmm_DDMMMyyyy(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm\nddMMMyyyy"
		return formatter.string(from: date).uppercased()
	}
	
	func formatDate_DDMMM_yyyy_HHmm(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMM\nyyyy\nHH:mm"
		return formatter.string(from: date).uppercased()
	}
	func formatDate_DDMMM_yyyy(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMM\nyyyy"
		return formatter.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMMyyyy"
		return formatter.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy_HHmm(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMMyyyy HH:mm"
		return formatter.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy_HHmmss(date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "ddMMMyyyyHHmmss"
		return formatter.string(from: date).uppercased()
	}
	
	func cleanOptional(inputString: String) -> String {
		// remove the 'Optional("xxxx")' from strings
		return inputString.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
	}
	
	//	func FormatCurrency(number: Double) -> String {
	//		return CurrencyFormatter.string(from: NSNumber(value: number)) ?? ""
	//	}
	
	
	// Formatters
	let IntFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .none
		return formatter
	}()
	let DoubleFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		return formatter
	}()
	let FloatFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		return formatter
	}()
	let CurrencyFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		return formatter
	}()
}

// MARK: - Shared data-loading helpers
extension Functions {
	// Return a single details value for a vehicle by name (vehicleId == Vehicle8.name)
	func loadVehicleDetails(context: ModelContext, vehicleId: String) -> VehicleDetails? {
		var fetchDescriptor = FetchDescriptor<Vehicle8>(
			predicate: #Predicate { v in v.name == vehicleId }
		)
		fetchDescriptor.fetchLimit = 1
		do {
			if let v = try context.fetch(fetchDescriptor).first {
				return VehicleDetails(
					mileage: v.mileage,
					engHours: v.engHours,
					fuelCapacity: v.fuelCapacity,
					fuelType: v.fuelType
				)
			}
		} catch {
			print("Failed to load vehicle details: \(error.localizedDescription)")
		}
		return nil
	}
	
	// Array-shaped helper for reuse in multiple files (often 0 or 1 element)
	func loadVehicleDetailsArray(context: ModelContext, vehicleId: String) -> [VehicleDetails] {
		if let details = loadVehicleDetails(context: context, vehicleId: vehicleId) {
			return [details]
		}
		return []
	}
}


//
//  Functions.swift
//  LandShip
//
//  Created by JP on 8/15/25.
//

import Foundation
import SwiftData
import SwiftUI


// MARK: - Unit Localization Helpers
private enum UnitMapping {
    static func unit(for abbreviation: String) -> Dimension? {
        switch abbreviation.lowercased() {
        // Length
        case "ft": return UnitLength.feet
        case "in": return UnitLength.inches
        case "mm": return UnitLength.millimeters
        case "cm": return UnitLength.centimeters
        case "m":  return UnitLength.meters
        case "km": return UnitLength.kilometers
        case "mi": return UnitLength.miles

        // Area
        case "ft²", "ft^2": return UnitArea.squareFeet
        case "in²", "in^2": return UnitArea.squareInches
        case "cm²", "cm^2": return UnitArea.squareCentimeters
        case "m²",  "m^2":  return UnitArea.squareMeters

        // Mass
        case "lb": return UnitMass.pounds
        case "oz": return UnitMass.ounces
        case "mg": return UnitMass.milligrams
        case "g":  return UnitMass.grams
        case "kg": return UnitMass.kilograms
        case "t":  return UnitMass.metricTons
        case "st": return UnitMass.stones

        // Pressure
        case "psi": return UnitPressure.poundsForcePerSquareInch
        case "pa":  return UnitPressure.newtonsPerMetersSquared

        // Speed
        case "mph": return UnitSpeed.milesPerHour
        case "kph": return UnitSpeed.kilometersPerHour
        case "kt":  return UnitSpeed.knots

        // Volume
        case "gal":   return UnitVolume.gallons
        case "qt":    return UnitVolume.quarts
        case "pt":    return UnitVolume.pints
        case "c":     return UnitVolume.cups
        case "fl oz": return UnitVolume.fluidOunces
        case "ml":    return UnitVolume.milliliters
        case "l":     return UnitVolume.liters

        default:
            return nil
        }
    }
}

// MARK: - Cached Formatters
private enum Formatters {
    // Number formatters
    static let currencyUS: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    static let plainYear: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        return f
    }()

    // Date formatters
    static let HHmm_ddMMMyyyy: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm\nddMMMyyyy"
        return f
    }()

    static let ddMMM_yyyy_HHmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMM\nyyyy\nHH:mm"
        return f
    }()

    static let ddMMM_yyyy: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMM\nyyyy"
        return f
    }()

    static let ddMMMyyyy: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMMyyyy"
        return f
    }()

    static let ddMMMyyyy_HHmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMMyyyy HH:mm"
        return f
    }()

    static let ddMMMyyyy_HHmmss: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMMyyyyHHmmss"
        return f
    }()

    static let ddMMM: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ddMMM"
        return f
    }()
}


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
	let defCapacity: Int
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

// Provide a local shim for Functions.cleanOptional so this view compiles even if
// the global Functions type doesn't define it. Returns a trimmed string or "—"
// when the input is nil or empty.
private extension Functions {
	func cleanOptional(inputString: String?) -> String {
		let trimmed = (inputString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "—" : trimmed
	}
	
	func cleanOptional(inputString: String) -> String {
		let trimmed = inputString.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "—" : trimmed
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
			case "oz": return "Ounces"
			case "mg": return "Milligrams"
			case "g": return "Grams"
			case "kg": return "Kilograms"
			case "T": return "Tons"
			case "st": return "Stones"
				// pressure
			case "PSI": return "Pounds per Square Inch"
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
			case "fl oz": return "Fluid Ounces"
			case "ml": return "Milliliters"
			case "l": return "Liters"
				
			default: return ""
		}
	}
	
	func formatYear(year: Int) -> String {
		return Formatters.plainYear.string(from: NSNumber(value: year)) ?? "0000"
	}
	
	func formatCurrency(dollars: Float) -> String {
		return Formatters.currencyUS.string(from: NSNumber(value: dollars)) ?? "$0.00"
	}
	
	func formatDate_HHmm_DDMMMyyyy(date: Date) -> String {
		return Formatters.HHmm_ddMMMyyyy.string(from: date).uppercased()
	}
	
	func formatDate_DDMMM_yyyy_HHmm(date: Date) -> String {
		return Formatters.ddMMM_yyyy_HHmm.string(from: date).uppercased()
	}
	func formatDate_DDMMM_yyyy(date: Date) -> String {
		return Formatters.ddMMM_yyyy.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy(date: Date) -> String {
		return Formatters.ddMMMyyyy.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy_HHmm(date: Date) -> String {
		return Formatters.ddMMMyyyy_HHmm.string(from: date).uppercased()
	}
	func formatDate_DDMMMyy_HHmmss(date: Date) -> String {
		return Formatters.ddMMMyyyy_HHmmss.string(from: date).uppercased()
	}
	/// Day and month only (e.g. "26AUG"), for compact pickers and menus where the surrounding
	/// list is already ordered by full date.
	func formatDate_DDMMM(date: Date) -> String {
		return Formatters.ddMMM.string(from: date).uppercased()
	}

    /// Localized date-time formatting using a template, respecting the provided locale.
    /// - Parameters:
    ///   - date: The date to format.
    ///   - locale: The desired locale. Defaults to `.current`.
    ///   - template: A Unicode date format template (e.g., "ddMMMyyyy HHmm").
    /// - Returns: A localized string derived from the template, or a reasonable fallback.
    func localizedDateTimeString(date: Date, locale: Locale = .current, template: String = "ddMMMyyyy HHmm") -> String {
        let format = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale) ?? "ddMMMyyyy HH:mm"
        let df = DateFormatter()
        df.locale = locale
        df.dateFormat = format
        return df.string(from: date)
    }
	
	/// Returns a localized display name for a unit abbreviation, if supported by Foundation units.
	/// - Parameters:
	///   - abbreviation: A unit abbreviation such as "ft", "cm", "PSI", "mph".
	///   - locale: The desired locale. Defaults to `.current`.
	/// - Returns: Localized unit display name (e.g., "Feet") or `nil` if unsupported.
	func localizedUnitName(for abbreviation: String, locale: Locale = .current) -> String? {
		guard let dim = UnitMapping.unit(for: abbreviation) else { return nil }
		let formatter = MeasurementFormatter()
		formatter.unitOptions = .providedUnit
		formatter.unitStyle = .long
		formatter.locale = locale
		return formatter.string(from: dim)
	}
	/// Returns a user-facing unit name, preferring localization and falling back to the legacy mapping.
	/// - Parameters:
	///   - unit: A unit abbreviation such as "ft", "cm", "PSI", "mph".
	///   - locale: The desired locale. Defaults to `.current`.
	/// - Returns: A localized display name if available; otherwise the legacy English mapping.
	func getUnitsDisplayName(unit: String, locale: Locale = .current) -> String {
		if let localized = localizedUnitName(for: unit, locale: locale) { return localized }
		return getUnits(unit: unit)
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
					defCapacity: v.defCapacity,
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
	
	/// Helper function to get a vehicle's display name from its internal vehicleId (name field)
	/// - Parameters:
	///   - vehicleId: The internal vehicle identifier (UUID stored in the name field)
	///   - context: The SwiftData ModelContext to query
	/// - Returns: The vehicle's displayName, or the vehicleId if vehicle not found
	func getVehicleDisplayName(vehicleId: String, context: ModelContext) -> String {
		// Handle special cases
		guard vehicleId != "All Vehicles" && !vehicleId.isEmpty else {
			return vehicleId
		}
		
		// Try to find the vehicle by its internal name (UUID)
		let descriptor = FetchDescriptor<Vehicle8>(
			predicate: #Predicate { $0.name == vehicleId }
		)
		
		guard let vehicles = try? context.fetch(descriptor),
			  let vehicle = vehicles.first else {
			return vehicleId
		}
		
		// Return displayName if not empty, otherwise fallback
		return vehicle.displayName.isEmpty ? vehicleId : vehicle.displayName
	}
}

// MARK: - App Version utilities
/// Provides app name, version, build, and a full version string that conditionally appends a "beta" suffix.
///
/// Usage:
///   let version = AppVersion.current
///   version.fullVersionString          // "v1.2.3 (45) beta"
///   version.displayStringWithAppName   // "MyApp v1.2.3 (45) beta"
struct AppVersion: Hashable {
    let appName: String
    let version: String
    let build: String
    let isBeta: Bool

    /// Returns: "v<version> (<build>)" + optional " beta"
    var fullVersionString: String {
//			"v\(version) (\(build))\(isBeta ? " beta" : "")"
			"v\(version)"
    }

    /// Returns: "<appName> v<version> (<build>)" + optional " beta"
    var displayStringWithAppName: String {
        "\(appName) \(fullVersionString)"
    }

    /// Convenience to access the current app bundle's version info.
    static var current: AppVersion { AppVersion() }

    /// Initializes from a bundle. Optionally allow forcing beta via compile-time flag.
    init(bundle: Bundle = .main) {
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
        let ver = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let bld = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""

        // TestFlight detection
        // iOS 18+: Avoid deprecated receipt URL API. Consider adopting StoreKit's AppTransaction/Transaction APIs asynchronously if needed.
        var isTestFlight: Bool
//        if #available(iOS 18.0, *) {
            // TODO: Adopt StoreKit's AppTransaction.shared / Transaction.all to detect TestFlight if needed.
//            isTestFlight = false
//        } else {
            // Pre–macOS 15: sandbox receipt indicates TestFlight install
            if #available(macOS 15.0, iOS 18.0, *) {
                isTestFlight = false // TODO: Adopt AppTransaction.shared / Transaction.all from StoreKit
            } else {
                isTestFlight = bundle.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            }
//        }

        // Allow build-time override using a custom Swift flag (e.g., -D BETA)
        #if BETA
        let forcedBeta = true
        #else
        let forcedBeta = false
        #endif

        self.appName = name
        self.version = ver
        self.build = bld
        self.isBeta = isTestFlight || forcedBeta
    }
}

/// Convenience string accessors built on top of AppVersion
struct VersionStrings {
    /// The resolved application name (Display Name -> Name -> "App")
    static var appName: String { AppVersion.current.appName }
    /// e.g., "v1.2.3 (45) beta"
    static var fullVersionString: String { AppVersion.current.fullVersionString }
    /// e.g., "MyApp v1.2.3 (45) beta"
    static var fullVersionStringWithAppName: String { AppVersion.current.displayStringWithAppName }
}

// MARK: - Color Hex Utilities

extension Color {
    /// Initialize from a hex string (6-digit RGB or 8-digit RGBA). Returns nil for invalid input.
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.hasPrefix("#") ? String(h.dropFirst()) : h
        guard h.count == 6 || h.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if h.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    /// Convert this color to an 8-digit RGBA hex string using platform-native color APIs.
    func hexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
#if os(iOS) || os(watchOS) || os(tvOS)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
#elseif os(macOS)
        (NSColor(self).usingColorSpace(.deviceRGB) ?? .black).getRed(&r, green: &g, blue: &b, alpha: &a)
#endif
        return String(format: "#%02X%02X%02X%02X",
            Int((r * 255).rounded()), Int((g * 255).rounded()),
            Int((b * 255).rounded()), Int((a * 255).rounded()))
    }
}


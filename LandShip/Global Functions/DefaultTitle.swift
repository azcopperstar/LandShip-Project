//
//  DefaultTitle.swift
//  LandShip
//
//  Builds the default title given to a record when it is created with the Add button.
//  The user's template (Settings > New Record Titles) mixes free text with tokens; when the
//  setting is off, or the template resolves to nothing, the caller's own default is used.
//

import Foundation
import SwiftData

enum DefaultTitle {
	/// Placeholders the user can insert into the template.
	enum Token: String, CaseIterable, Identifiable {
		case section = "{section}"
		case date = "{date}"
		case dateTime = "{datetime}"
		case time = "{time}"
		case vehicle = "{vehicle}"

		var id: String { rawValue }

		/// Short label for the insert buttons in Settings.
		var label: String {
			switch self {
				case .section: return "Item Name"
				case .date: return "Today's Date"
				case .dateTime: return "Date & Time"
				case .time: return "Time"
				case .vehicle: return Vertical.current.assetSingular
			}
		}
	}

	static let defaultTemplate = "{section}: {date}"

	/// Resolves the title for a new record.
	/// - Parameters:
	///   - section: Singular name of the record type, e.g. "Fuel Log" (substituted for `{section}`).
	///   - vehicleId: The record's vehicle `name` key, if it has one (substituted for `{vehicle}`).
	///   - fallback: The section's existing default, used when the setting is off.
	static func make(section: String, vehicleId: String? = nil, fallback: String, context: ModelContext, now: Date = Date()) -> String {
		guard let settings = PrefsFunctions().loadSettings(context: context), settings.defaultTitleEnabled else {
			return fallback
		}
		let resolved = resolve(template: settings.defaultTitleTemplate, section: section, vehicleId: vehicleId, context: context, now: now)
		return resolved.isEmpty ? fallback : resolved
	}

	/// Expands the tokens in `template`. Also used for the live preview in Settings.
	static func resolve(template: String, section: String, vehicleId: String? = nil, context: ModelContext, now: Date = Date()) -> String {
		let functions = Functions()
		var vehicleName = ""
		if let vehicleId, !vehicleId.isEmpty, vehicleId != "All Vehicles" {
			vehicleName = functions.getVehicleDisplayName(vehicleId: vehicleId, context: context)
		}

		var result = template
		result = result.replacingOccurrences(of: Token.section.rawValue, with: section)
		result = result.replacingOccurrences(of: Token.dateTime.rawValue, with: functions.formatDate_DDMMMyy_HHmm(date: now))
		result = result.replacingOccurrences(of: Token.date.rawValue, with: functions.formatDate_DDMMMyy(date: now))
		result = result.replacingOccurrences(of: Token.time.rawValue, with: functions.formatTime(date: now))
		result = result.replacingOccurrences(of: Token.vehicle.rawValue, with: vehicleName)

		// An empty token (e.g. no vehicle chosen) can leave doubled spaces or a dangling separator.
		while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
		let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-:·,–—|/"))
		return result.trimmingCharacters(in: trimSet)
	}
}

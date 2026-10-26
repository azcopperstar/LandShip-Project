//
//  DateDisplayPrefs.swift
//  LandShip
//
//  User-selectable date/time display format. The choice lives in Settings1 (so it syncs across
//  devices) and is mirrored into UserDefaults so Functions.formatDate_* — which has no
//  ModelContext — can read it cheaply.
//

import Foundation

enum DateDisplayStyle: String, CaseIterable, Identifiable {
	case ddMMMyyyy        // 28OCT2026 (original app style)
	case spacedMonth      // 28 Oct 2026
	case monthDayYear     // 10/28/2026
	case dayMonthYear     // 28/10/2026
	case iso              // 2026-10-28

	var id: String { rawValue }

	/// Full date pattern.
	var pattern: String {
		switch self {
			case .ddMMMyyyy: return "ddMMMyyyy"
			case .spacedMonth: return "dd MMM yyyy"
			case .monthDayYear: return "MM/dd/yyyy"
			case .dayMonthYear: return "dd/MM/yyyy"
			case .iso: return "yyyy-MM-dd"
		}
	}

	/// Day and month only, for compact pickers and menus.
	var shortPattern: String {
		switch self {
			case .ddMMMyyyy: return "ddMMM"
			case .spacedMonth: return "dd MMM"
			case .monthDayYear: return "MM/dd"
			case .dayMonthYear: return "dd/MM"
			case .iso: return "MM-dd"
		}
	}

	/// The original style is all caps; the others use normal capitalization.
	var uppercased: Bool { self == .ddMMMyyyy }

	/// Picker label, shown with a fixed sample date so every option reads the same way.
	var label: String {
		let sample = DateComponents(calendar: .current, year: 2026, month: 10, day: 28).date ?? Date()
		let f = DateFormatter()
		f.dateFormat = pattern
		let text = f.string(from: sample)
		return uppercased ? text.uppercased() : text
	}
}

enum TimeDisplayStyle: String, CaseIterable, Identifiable {
	case h24    // 14:30
	case h12    // 2:30 PM

	var id: String { rawValue }

	var pattern: String { self == .h24 ? "HH:mm" : "h:mm a" }

	var label: String { self == .h24 ? "24-hour (14:30)" : "12-hour (2:30 PM)" }
}

enum DateDisplayPrefs {
	private static let dateKey = "dateDisplayStyle"
	private static let timeKey = "timeDisplayStyle"

	static var date: DateDisplayStyle {
		DateDisplayStyle(rawValue: UserDefaults.standard.string(forKey: dateKey) ?? "") ?? .ddMMMyyyy
	}

	static var time: TimeDisplayStyle {
		TimeDisplayStyle(rawValue: UserDefaults.standard.string(forKey: timeKey) ?? "") ?? .h24
	}

	/// Copies the synced Settings values into the local mirror used by the formatters.
	static func mirror(dateRaw: String, timeRaw: String) {
		UserDefaults.standard.set(dateRaw, forKey: dateKey)
		UserDefaults.standard.set(timeRaw, forKey: timeKey)
	}
}

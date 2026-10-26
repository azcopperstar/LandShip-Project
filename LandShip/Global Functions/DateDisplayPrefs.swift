//
//  DateDisplayPrefs.swift
//  LandShip
//
//  User-selectable date/time display format. The choice lives in Settings1 (so it syncs across
//  devices) and is mirrored into UserDefaults so Functions.formatDate_* — which has no
//  ModelContext — can read it cheaply.
//

import Foundation
import SwiftUI

enum DateDisplayStyle: String, CaseIterable, Identifiable {
	case ddMMMyyyy        // 28OCT2026 (original app style)
	case spacedMonth      // 28 Oct 2026
	case monthDayYear     // 10/28/2026
	case dayMonthYear     // 28/10/2026
	case iso              // 2026-10-28
	case system           // follows the device's regional settings

	var id: String { rawValue }

	/// Full date pattern.
	var pattern: String {
		switch self {
			case .ddMMMyyyy: return "ddMMMyyyy"
			case .spacedMonth: return "dd MMM yyyy"
			case .monthDayYear: return "MM/dd/yyyy"
			case .dayMonthYear: return "dd/MM/yyyy"
			case .iso: return "yyyy-MM-dd"
			case .system: return DateFormatter.dateFormat(fromTemplate: "ddMMMyyyy", options: 0, locale: .current) ?? "dd MMM yyyy"
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
			case .system: return DateFormatter.dateFormat(fromTemplate: "ddMMM", options: 0, locale: .current) ?? "dd MMM"
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
		if self == .system { return "System (\(text))" }
		return uppercased ? text.uppercased() : text
	}
}

enum TimeDisplayStyle: String, CaseIterable, Identifiable {
	case h24    // 14:30
	case h12    // 2:30 PM
	case system // follows the device's 12/24-hour clock setting

	var id: String { rawValue }

	var pattern: String {
		switch self {
			case .h24: return "HH:mm"
			case .h12: return "h:mm a"
			// "j" resolves to the device's preferred hour cycle.
			case .system: return DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current) ?? "HH:mm"
		}
	}

	var label: String {
		switch self {
			case .h24: return "24-hour (14:30)"
			case .h12: return "12-hour (2:30 PM)"
			case .system: return "System setting"
		}
	}
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

extension View {
	/// Makes date/time pickers and system date text follow the 12/24-hour choice in Settings,
	/// keeping the user's regional date order. (The system pickers otherwise use the device's
	/// own clock setting.)
	@ViewBuilder
	func timeDisplayLocale() -> some View {
		if DateDisplayPrefs.time == .system {
			self
		} else {
			timeDisplayLocaleOverride()
		}
	}

	private func timeDisplayLocaleOverride() -> some View {
		var components = Locale.Components(locale: .current)
		components.hourCycle = DateDisplayPrefs.time == .h24 ? .zeroToTwentyThree : .oneToTwelve
		return self.environment(\.locale, Locale(components: components))
	}
}

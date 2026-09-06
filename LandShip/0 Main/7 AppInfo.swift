//
//  AppInfo.swift
//  LandShip
//
//  Created by JP on 7/19/25.
//

import Foundation
import SwiftUI

// Global app information accessors
enum AppInfo {
	static var displayName: String {
		// Prefer CFBundleDisplayName, fall back to CFBundleName
		if let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !display.isEmpty {
			return display
		}
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
	}
	
	static var version: String {
		// e.g., "1.2.3 (45)"
		let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
		return "\(short) (\(build))"
	}
}

// Custom title view that shows app name and version (version in smaller font)
struct AppTitleView: View {
	var body: some View {
#if os(macOS)
		// The Liquid Glass toolbar pill only has room for a single line, so name and
		// version sit side by side here rather than stacked like on iOS.
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Text(AppInfo.displayName)
				.font(.headline.bold())
				.foregroundStyle(Color.accentColor)
			Text(VersionStrings.fullVersionString)
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 4)
#else
		VStack(spacing: 0) {
			Text(" \(AppInfo.displayName)")
				.font(.headline.bold())
				.foregroundStyle(Color.accentColor)
			Text(VersionStrings.fullVersionString)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.baselineOffset(6)
		}
#endif
	}
}



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
	// Set by CloudKitSyncMonitor when a real sync failure is logged; cleared when
	// Debug Tools is opened. See StorageKey.hasUnreadCloudKitFailure.
	@AppStorage(StorageKey.hasUnreadCloudKitFailure) private var hasUnreadCloudKitFailure = false

	var body: some View {
#if os(macOS)
		VStack(spacing: 0) {
			Text(AppInfo.displayName)
				.font(.subheadline.bold())
				.foregroundStyle(Color.accentColor)
			Text(VersionStrings.fullVersionString)
				.font(.caption2)
				.fontWeight(.medium)
				.foregroundStyle(.secondary)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 4)
		.background(
			Capsule(style: .continuous)
				.fill(Color.accentColor.opacity(0.14))
				.overlay(
					Capsule(style: .continuous)
						.strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
				)
		)
		.shadow(color: .black.opacity(0.15), radius: 2, y: 1)
		.overlay(alignment: .topTrailing) { syncFailureBadge }
#else
		VStack(spacing: 0) {
			Text(AppInfo.displayName)
				.font(.subheadline.bold())
				.foregroundStyle(Color.accentColor)
			Text(VersionStrings.fullVersionString)
				.font(.caption2)
				.fontWeight(.medium)
				.foregroundStyle(.secondary)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 4)
		.background(
			Capsule(style: .continuous)
				.fill(Color.accentColor.opacity(0.14))
				.overlay(
					Capsule(style: .continuous)
						.strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
				)
		)
		.shadow(color: .black.opacity(0.15), radius: 2, y: 1)
		.overlay(alignment: .topTrailing) { syncFailureBadge }
#endif
	}

	@ViewBuilder
	private var syncFailureBadge: some View {
		if hasUnreadCloudKitFailure {
			Circle()
				.fill(.red)
				.frame(width: 9, height: 9)
				.overlay(Circle().strokeBorder(.white, lineWidth: 1))
				.offset(x: 4, y: -4)
				.accessibilityLabel("Unread CloudKit sync failure logged")
		}
	}
}



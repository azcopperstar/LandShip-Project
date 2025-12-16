//
//  LandShipApp.swift
//  LandShip
//
//  App entry point. Creates a single SwiftData ModelContainer using a custom
//  Schema and prefers CloudKit sync with a local-only fallback. If both fail,
//  a fatal startup view is shown. On macOS, provides a Help window and command.
//  Settings are presented as a sheet from the main UI instead of a separate scene.
//
//  Created by JP on 7/19/25.
//

import SwiftUI
import SwiftData
import CloudKit

#if os(macOS)
import AppKit
#endif

@main
struct LandShipApp: App {
	
	// MARK: - Startup Result
	
	private let modelContainer: ModelContainer?
	private let startupError: Error?
	private let isLocalOnly: Bool
	
	// Diagnostics
	private static let cloudKitContainerID = "iCloud.com.aeronauticaltrax.LandShip"
	
#if DEBUG
	private let buildConfiguration = "DEBUG"
#else
	private let buildConfiguration = "RELEASE"
#endif

	private static func isTestFlightBuild() -> Bool {
#if os(iOS)
		// Heuristic: TestFlight builds usually have a "sandboxReceipt".
		if let url = Bundle.main.appStoreReceiptURL {
			return url.lastPathComponent.lowercased() == "sandboxreceipt"
		}
#endif
		return false
	}
	
	init() {
		// Define the SwiftData schema listing all @Model types.
		let schema = Schema([
			MxItems3.self,
			MxParts1.self,
			ServiceRecords1.self,
			Vehicle8.self,
			VehicleSystems1.self,
			Vendors1.self,
			Settings1.self,
			FuelLog1.self,
			TripLog2.self
		])
		
		// Attempt CloudKit first, then local-only.
		switch Self.makeContainer(schema: schema) {
			case .cloud(let container):
				self.modelContainer = container
				self.startupError = nil
				self.isLocalOnly = false
				UserDefaults.standard.set("cloud", forKey: "StartupStoreMode")
				print("[LandShip] Store mode: CloudKit-backed")
			case .local(let container):
				self.modelContainer = container
				self.startupError = nil
				self.isLocalOnly = true
				UserDefaults.standard.set("local", forKey: "StartupStoreMode")
				print("[LandShip] Store mode: Local-only (sync unavailable)")
			case .failure(let error):
				self.modelContainer = nil
				self.startupError = error
				self.isLocalOnly = true
				UserDefaults.standard.set("failure", forKey: "StartupStoreMode")
				print("[LandShip] Store mode: FAILED to create ModelContainer: \(error)")
		}
		
		// Surface environment/build diagnostics at launch
		let bundleID = Bundle.main.bundleIdentifier ?? "(unknown)"
		let version = "\(AppInfo.version)"
		let isTF = Self.isTestFlightBuild()
		print("[LandShip] App Version: \(version)")
		print("[LandShip] Bundle ID: \(bundleID)")
		print("[LandShip] Build: \(buildConfiguration)\(isTF ? " (TestFlight/Production env)" : " (Development env if debug build)")")
		print("[LandShip] CloudKit Container: \(Self.cloudKitContainerID)")
		
		// Optional: async check iCloud account status (helpful when debugging devices)
		Task {
			let status = try? await CKContainer(identifier: Self.cloudKitContainerID).accountStatus()
			switch status {
				case .available?: print("[LandShip] iCloud account status: available")
				case .noAccount?: print("[LandShip] iCloud account status: noAccount")
				case .restricted?: print("[LandShip] iCloud account status: restricted")
				case .couldNotDetermine?: print("[LandShip] iCloud account status: couldNotDetermine")
				case .temporarilyUnavailable?: print("[LandShip] iCloud account status: temporarilyUnavailable")
				default: print("[LandShip] iCloud account status: unknown")
			}
		}
	}
	
	var body: some Scene {
		WindowGroup {
			if let container = modelContainer {
				ContentView()
					.modelContainer(container)
					.overlay(alignment: .top) {
						if isLocalOnly {
							LocalOnlyBanner()
								.transition(.move(edge: .top).combined(with: .opacity))
						}
					}
#if os(macOS)
					.windowFrameAutosave("MainWindow")
#endif
			} else {
				FatalStartupView(error: startupError)
#if os(macOS)
					.windowFrameAutosave("MainWindow")
#endif
			}
		}
#if os(macOS)
		Window("\(AppInfo.displayName) Help", id: "help") {
			HelpView()
				.frame(minWidth: 600, minHeight: 500)
				.windowFrameAutosave("HelpWindow")
		}
		.commands {
			HelpCommands()
		}
#endif
	}
}

// MARK: - macOS Help menu

#if os(macOS)
private struct HelpCommands: Commands {
	@Environment(\.openWindow) private var openWindow
	
	var body: some Commands {
		// Replace the default Help menu item so our command opens the SwiftUI Help window.
		CommandGroup(replacing: .help) {
			Button("\(AppInfo.displayName) Help") {
				openWindow(id: "help")
			}
			.keyboardShortcut("?", modifiers: [.command, .shift])
		}
	}
}
#endif

// MARK: - Container creation

private extension LandShipApp {
	enum StartupResult {
		case cloud(ModelContainer)
		case local(ModelContainer)
		case failure(Error)
	}
	
	static func makeContainer(schema: Schema) -> StartupResult {
		// Configure a CloudKit-backed store. The identifier must match your
		// CloudKit container configured in the Apple Developer portal.
		let cloudConfig = ModelConfiguration(
			schema: schema,
			cloudKitDatabase: .private(Self.cloudKitContainerID)
		)
		
		// Try creating the CloudKit container first.
		if let cloud = try? ModelContainer(for: schema, configurations: cloudConfig) {
			return .cloud(cloud)
		}
		
		// If CloudKit fails (no account, network, or configuration issues),
		// fall back to a local-only store so the app remains usable.
		let localConfig = ModelConfiguration(schema: schema)
		if let local = try? ModelContainer(for: schema, configurations: localConfig) {
			return .local(local)
		}
		
		// If both attempts failed, perform one more throwing attempt to capture
		// a concrete error for display and logging.
		do {
			_ = try ModelContainer(for: schema, configurations: localConfig)
			// Should not reach here because the try? above would have succeeded.
			return .failure(NSError(
				domain: "LandShipApp",
				code: -1,
				userInfo: [NSLocalizedDescriptionKey: "Unknown startup failure."]
			))
		} catch {
			return .failure(error)
		}
	}
}

// MARK: - Lightweight UI helpers

private struct LocalOnlyBanner: View {
	@State private var visible = true
	
	var body: some View {
		if visible {
			HStack(spacing: 8) {
				Image(systemName: "icloud.slash").imageScale(.medium)
				Text("iCloud sync is currently unavailable. Working locally.")
					.font(.callout)
					.lineLimit(2)
				Spacer()
				Button {
					withAnimation { visible = false }
				} label: {
					Image(systemName: "xmark.circle.fill")
						.imageScale(.medium)
						.symbolRenderingMode(.hierarchical)
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Dismiss")
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(.thinMaterial)
			.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
			.padding(.top, 8)
			.padding(.horizontal, 12)
			.shadow(radius: 2, y: 1)
		}
	}
}

private struct FatalStartupView: View {
	let error: Error?
	
	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 48, weight: .bold))
				.foregroundStyle(.yellow)
			Text("Unable to Start")
				.font(.title2).bold()
			Text("""
				\(AppInfo.displayName) could not initialize its data store.
				Please try relaunching the app. If the issue persists, contact support.
				""")
			.multilineTextAlignment(.center)
			.foregroundStyle(.secondary)
			if let error {
				Text(error.localizedDescription)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.padding(.top, 4)
			}
#if os(macOS)
			Button("Quit") {
				NSApp.terminate(nil)
			}
#else
			EmptyView()
#endif
		}
		.padding()
	}
}


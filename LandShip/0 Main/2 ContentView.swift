//
//  ContentView.swift
//  LandShip
//
//  Created by JP on 7/19/25.
//
//  Overview
//  --------
//  ContentView is the primary root view for the app’s UI. It presents a platform-appropriate,
//  three-column NavigationSplitView (sidebar, content, detail) on macOS and iPadOS, and a compact
//  adaptive experience on iPhone.
//
//  Major responsibilities:
//  - Presents a sidebar (menu) with top-level navigation and actions (backup, restore, settings).
//  - Drives the middle “content” column based on the current SidebarItem selection.
//  - Provides a detail placeholder in the trailing column.
//  - Persists user choices across launches:
//      * trackVehicleSelected via AppStorage (shared across scenes).
//      * split view visibility via SceneStorage (per scene/window).
//      * onboarding completion via AppStorage.
//  - Hosts sheets for Settings and (on iOS) Help.
//  - Implements Backup and Restore flows using SwiftUI’s FileDocument exporter/importer.
//  - Triggers onboarding for first-time use and prevents dismissal until completion.
//
//  Platform notes:
//  - macOS:
//      * Settings are presented in a sheet (instead of a separate Settings window) to create a
//        single consistent experience across platforms.
//      * Split view divider positions are autosaved via .splitViewAutosave.
//  - iPadOS:
//      * Shows the sidebar by default and selects “Vehicles” on first appearance.
//  - iOS (iPhone):
//      * The sidebar is hidden by default and selection is nil to reveal a content placeholder.
//
//  Backup/Restore overview:
//  - See comments further below.
//
//  Selection behavior on first appearance: see comments further below.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import CloudKit

/// The root view that hosts the three-column navigation interface, top-level sheets,
/// backup/restore flows, and first-run onboarding.
struct ContentView: View {
	// MARK: - Global presentation state
	
	// Settings and Help sheets
	@State private var showingPreferences = false // Reserved for future use if needed
	@State private var showingSettingsSheet = false
	@State private var showingHelpSheet = false
	// Removed showingUpgrades property as per instructions
	
	// Hidden Debug Tools sheet (appears on long-press of title)
	@State private var showingDebugTools = false
	
	// MARK: - Cross-view and persisted state
	
	@AppStorage(StorageKey.trackVehicleSelected) private var trackVehicleSelected: String = "All Vehicles"
	@SceneStorage(StorageKey.splitColumnVisibility) private var columnVisibilityRawValue: String = "all"
	
	@State private var splitVisibility: NavigationSplitViewVisibility = .all
	@State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
	
	@AppStorage(StorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
	@State private var showingOnboarding: Bool = false
	
	// MARK: - Sidebar selection
	
	@State private var sidebarSelection: SidebarItem? = {
#if os(iOS)
		return UIDevice.current.userInterfaceIdiom == .pad ? .vehicles : nil
#else
		return .vehicles
#endif
	}()
    @State private var detailPath = NavigationPath()
    @State private var splitResetID = UUID()
	
	// MARK: - Backup / Restore state
	
	@State private var isExportingBackup: Bool = false
	@State private var backupDocument: BackupDocument = .empty
	@State private var backupErrorMessage: String?
    @State private var backupSuccessMessage: String?
    @State private var isBackupSuccessPresented: Bool = false
	
	@State private var isImportingRestore: Bool = false
	@State private var pendingRestoreURL: URL?
	@State private var showConfirmRestore: Bool = false
	@State private var restoreErrorMessage: String?
	@State private var restoreSuccessMessage: String?
	
	@State private var isBackupErrorPresented: Bool = false
	@State private var isRestoreErrorPresented: Bool = false
	@State private var isRestoreSuccessPresented: Bool = false
	
	@Environment(\.modelContext) private var modelContext
	
#if os(iOS)
	private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#endif

	// Prevent duplicate launch logging per process
	private static var didLogLaunch = false
	
	// MARK: - Body

    // Extracted root NavigationSplitView to reduce type-checking complexity
    private var splitRoot: some View {
        NavigationSplitView(
            columnVisibility: $splitVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            SidebarView(
                sidebarSelection: $sidebarSelection,
                showingSettingsSheet: $showingSettingsSheet,
                showingHelpSheet: $showingHelpSheet,
                onBackupTapped: handleBackupTapped,
                onRestoreTapped: { isImportingRestore = true }
            )
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Hidden long-press to open Debug Tools (available in all builds)
                    AppTitleView()
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 2.0)
                                .onEnded { _ in
                                    showingDebugTools = true
                                    InAppLogger.shared.log("DebugTools opened via long-press")
                                }
                        )
                        .accessibilityHint("Long-press for debug tools")
                }
            }
#if !os(macOS)
            // Removed the toolbar block containing the Upgrades button as per instructions
#endif
        } content: {
            MiddleColumnView(
                sidebarSelection: $sidebarSelection,
                trackVehicleSelected: $trackVehicleSelected
            )
        } detail: {
            DetailColumnView(
                detailPath: $detailPath,
                selectionID: sidebarSelection
            )
        }
#if os(macOS)
        .splitViewAutosave("MainSplit")
#endif
        .id(splitResetID)
    }

	var body: some View {
        splitRoot
		.sheet(isPresented: $showingSettingsSheet) {
			SettingsEditorView()
		}
		
#if !os(macOS)
		.sheet(isPresented: $showingHelpSheet) {
			NavigationStack {
				HelpView()
					.navigationTitle("Help")
					.toolbar {
						ToolbarItem(placement: .cancellationAction) {
							Button("Close") { showingHelpSheet = false }
						}
					}
			}
		}
#endif
		
		// Removed the purchases sheet block as per instructions
		
		// Backup export
		.fileExporter(
			isPresented: $isExportingBackup,
			document: backupDocument,
			contentType: .folder,
			defaultFilename: BackupService.defaultBackupFilename()
		) { result in
            switch result {
                case .success(let url):
                    let summary = BackupService.summarizeBackupFolder(at: url)
                    backupSuccessMessage = summary
                    isBackupSuccessPresented = true
                    InAppLogger.shared.log("Backup export succeeded: \(url.lastPathComponent)")
                case .failure(let error):
                    backupErrorMessage = error.localizedDescription
                    isBackupErrorPresented = true
                    InAppLogger.shared.log("Backup export failed: \(error.localizedDescription)")
            }
        }
		
		// Restore import
		.fileImporter(
			isPresented: $isImportingRestore,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
				case .success(let urls):
					guard let url = urls.first else { return }
					pendingRestoreURL = url
					showConfirmRestore = true
					InAppLogger.shared.log("Restore selected URL: \(url.lastPathComponent)")
				case .failure(let error):
					restoreErrorMessage = error.localizedDescription
					isRestoreErrorPresented = true
					InAppLogger.shared.log("Restore import failed: \(error.localizedDescription)")
			}
		}
		
		.confirmationDialog(
			"Restore Data",
			isPresented: $showConfirmRestore,
			titleVisibility: .visible
		) {
			Button("Replace current data with selected backup", role: .destructive) {
				if let url = pendingRestoreURL {
					Task {
						do {
							let message = try await BackupService.restoreFromBackupFolder(url)
							restoreSuccessMessage = message
							isRestoreSuccessPresented = true
							InAppLogger.shared.log("Restore complete: \(message)")
						} catch {
							restoreErrorMessage = error.localizedDescription
							isRestoreErrorPresented = true
							InAppLogger.shared.log("Restore failed: \(error.localizedDescription)")
						}
					}
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This will overwrite your current data (Documents and Application Support) with the contents of the selected backup folder. It’s recommended to relaunch the app after restoring.")
		}
		
		.alert("Backup Failed", isPresented: $isBackupErrorPresented) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(backupErrorMessage ?? "")
		}
        .alert("Backup Complete", isPresented: $isBackupSuccessPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupSuccessMessage ?? "")
        }
		.alert("Restore Failed", isPresented: $isRestoreErrorPresented) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(restoreErrorMessage ?? "")
		}
		.alert("Restore Complete", isPresented: $isRestoreSuccessPresented) {
			Button("OK") { }
		} message: {
			Text(restoreSuccessMessage ?? "")
		}
		
		.tint(.blue)
		
		.onAppear {
			// Log launch once per process
			if !Self.didLogLaunch {
				Self.didLogLaunch = true
				let ts = ISO8601DateFormatter().string(from: Date())
				let bundleID = Bundle.main.bundleIdentifier ?? "(unknown)"
				let version = AppInfo.version
				let storeMode = UserDefaults.standard.string(forKey: "StartupStoreMode") ?? "(unknown)"
				InAppLogger.shared.log("Launch @ \(ts) — Bundle: \(bundleID), Version: \(version), StoreMode: \(storeMode)")
			}
			
			// Ensure the sidebar is shown on launch (iPadOS/macOS).
			if columnVisibilityRawValue != "all" {
				columnVisibilityRawValue = "all"
			}
			splitVisibility = visibility(from: columnVisibilityRawValue)
			
			if trackVehicleSelected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				trackVehicleSelected = "All Vehicles"
			}
			
			if !hasCompletedOnboarding {
				showingOnboarding = true
			}
			
#if os(iOS)
			if isPad {
				Task { @MainActor in sidebarSelection = .vehicles }
			} else {
				Task { @MainActor in sidebarSelection = nil }
			}
#else
			Task { @MainActor in sidebarSelection = .vehicles }
#endif
			
			// Log iCloud account status (also printed to console)
			Task {
				let containerID = "iCloud.com.aeronauticaltrax.LandShip"
				let status = try? await CKContainer(identifier: containerID).accountStatus()
				let msg: String
				switch status {
					case .available?: msg = "available"
					case .noAccount?: msg = "noAccount"
					case .restricted?: msg = "restricted"
					case .couldNotDetermine?: msg = "couldNotDetermine"
					case .temporarilyUnavailable?: msg = "temporarilyUnavailable"
					default: msg = "unknown"
				}
				print("[LandShip] (ContentView) iCloud account: \(msg)")
				InAppLogger.shared.log("iCloud account status: \(msg)")
			}
		}
		.onChangeCompat(of: splitVisibility) { _, newValue in
			columnVisibilityRawValue = raw(from: newValue)
		}
        .onChangeCompat(of: sidebarSelection) { _, _ in
            // Clear the detail navigation when switching sections to avoid stale detail views
            detailPath = NavigationPath()
            splitResetID = UUID()
        }
#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
		
		// Onboarding
#if os(macOS)
		.sheet(isPresented: $showingOnboarding) {
			OnboardingView(
				didFinish: {
					hasCompletedOnboarding = true
					showingOnboarding = false
					InAppLogger.shared.log("Onboarding finished")
				}
			)
			.interactiveDismissDisabled(true)
		}
#else
		.fullScreenCover(isPresented: $showingOnboarding) {
			OnboardingView(
				didFinish: {
					hasCompletedOnboarding = true
					showingOnboarding = false
					InAppLogger.shared.log("Onboarding finished")
				}
			)
			.interactiveDismissDisabled(true)
		}
#endif
		
		// Debug Tools sheet (available in all builds)
		.sheet(isPresented: $showingDebugTools) {
			DebugToolsView()
		}
	}
	
	// MARK: - Actions
	
	private func handleBackupTapped() {
		do {
			let doc = try BackupService.makeBackupDocument(context: modelContext)
			self.backupDocument = doc
			self.isExportingBackup = true
			InAppLogger.shared.log("Backup export started")
		} catch {
			self.backupErrorMessage = error.localizedDescription
			self.isBackupErrorPresented = true
			InAppLogger.shared.log("Backup export failed early: \(error.localizedDescription)")
		}
	}
}

// MARK: - Sidebar row styling

private extension View {
	func sidebarRowStyle(selected: Bool) -> some View {
		self
			.symbolRenderingMode(.hierarchical)
			.foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
			.fontWeight(selected ? .semibold : .regular)
	}
}

private extension View {
    /// Convenience to apply the recommended list row adjustments for card-styled rows.
    /// Use on the same view you call `.cardStyle(...)` within a List row.
    func cardListRowDefaults() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - Extracted subviews

private struct SidebarView: View {
	@Binding var sidebarSelection: SidebarItem?
	@Binding var showingSettingsSheet: Bool
	@Binding var showingHelpSheet: Bool
	var onBackupTapped: () -> Void
	var onRestoreTapped: () -> Void
	
	var body: some View {
		List(selection: $sidebarSelection) {
			Section(header: CenteredSectionHeader(title: "")) {
				Label("Dashboard", systemImage: "rectangle.grid.2x2")
					.sidebarRowStyle(selected: sidebarSelection == .dashboard)
					.tag(SidebarItem.dashboard)
			}

			Section(header: CenteredSectionHeader(title: "Garage")) {
				Label("Vehicles", systemImage: "truck.pickup.side.front.open")
					.sidebarRowStyle(selected: sidebarSelection == .vehicles)
					.tag(SidebarItem.vehicles)
				Label("Parts", systemImage: "engine.combustion.badge.exclamationmark")
					.sidebarRowStyle(selected: sidebarSelection == .parts)
					.tag(SidebarItem.parts)
			}

			Section(header: CenteredSectionHeader(title: "Data Tracking")) {
				Label("Fuel Log", systemImage: "fuelpump.arrowtriangle.left")
					.sidebarRowStyle(selected: sidebarSelection == .fuelLog)
					.tag(SidebarItem.fuelLog)
				Label("Travel Log", systemImage: "map")
					.sidebarRowStyle(selected: sidebarSelection == .tripLog)
					.tag(SidebarItem.tripLog)
			}
			
			Section(header: CenteredSectionHeader(title: "Vehicle Service")) {
				Label("Records", systemImage: "square.grid.3x1.folder.badge.plus")
					.sidebarRowStyle(selected: sidebarSelection == .records)
					.tag(SidebarItem.records)
				Label("Items", systemImage: "folder.badge.gearshape")
					.sidebarRowStyle(selected: sidebarSelection == .items)
					.tag(SidebarItem.items)
			}
			
			Section(header: CenteredSectionHeader(title: "Setup")) {
				Label("Systems", systemImage: "glowplug")
					.sidebarRowStyle(selected: sidebarSelection == .systems)
					.tag(SidebarItem.systems)
				Label("Vendors / Shops", systemImage:  "person.2.badge.gearshape")
					.sidebarRowStyle(selected: sidebarSelection == .vendors)
					.tag(SidebarItem.vendors)
				
				Button {
					showingSettingsSheet = true
					InAppLogger.shared.log("Opened Settings sheet")
				} label: {
					Label("Settings", systemImage: "gearshape")
						.sidebarRowStyle(selected: sidebarSelection == .settings)
				}
				.buttonStyle(.plain)
			}
			
			Section(header: CenteredSectionHeader(title: "Data Management")) {
				Button {
					onBackupTapped()
				} label: {
					Label("Backup…", systemImage: "square.and.arrow.up")
						.sidebarRowStyle(selected: sidebarSelection == .backup)
				}
				.buttonStyle(.plain)
				
				Button {
					onRestoreTapped()
				} label: {
					Label("Restore…", systemImage: "square.and.arrow.down")
						.sidebarRowStyle(selected: sidebarSelection == .restore)
				}
				.buttonStyle(.plain)
			}
			
#if !os(macOS)
			Section(header: CenteredSectionHeader(title: "Resources")) {
				Button {
					showingHelpSheet = true
					InAppLogger.shared.log("Opened Help")
				} label: {
					Label("Help", systemImage: "questionmark.circle")
						.sidebarRowStyle(selected: false)
				}
				.buttonStyle(.plain)
			}
#endif
		}
	}
}

/// Extracted middle column content to reduce type-checking complexity
private struct MiddleColumnView: View {
    @Binding var sidebarSelection: SidebarItem?
    @Binding var trackVehicleSelected: String

    var body: some View {
        Group {
            switch sidebarSelection {
                case .dashboard:
                    DashboardView()
                case .vehicles:
                    ChooseVehicle(trackVehicleSelected: $trackVehicleSelected)
                case .parts:
                    DisplayParts(trackVehicleSelected: $trackVehicleSelected)
                case .fuelLog:
                    DisplayFuelLog(trackVehicleSelected: $trackVehicleSelected)
                case .tripLog:
                    DisplayTripLog(trackVehicleSelected: $trackVehicleSelected)
                case .records:
                    DisplayRecords(trackVehicleSelected: $trackVehicleSelected)
                case .items:
                    DisplayItems(trackVehicleSelected: $trackVehicleSelected)
                case .systems:
                    DisplaySystems(trackVehicleSelected: $trackVehicleSelected)
                case .vendors:
                    DisplayVendors()
                case .settings:
                    ContentUnavailableView("Settings opens in a sheet", systemImage: "gearshape")
                case .backup:
                    ContentUnavailableView("Use Backup in Data Management", systemImage: "square.and.arrow.up")
                case .restore:
                    ContentUnavailableView("Use Restore in Data Management", systemImage: "square.and.arrow.down")
                case .none:
                    ContentPlaceholderView()
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 300)
    }
}

/// Placeholder for the middle column when no section is selected.
private struct ContentPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Select a section", systemImage: "sidebar.leading")
    }
}

/// Extracted detail column container to reduce type-checking complexity
private struct DetailColumnView: View {
    @Binding var detailPath: NavigationPath
    var selectionID: SidebarItem?

    var body: some View {
        NavigationStack(path: $detailPath) {
            DetailPlaceholderView()
        }
        .id(selectionID)
    }
}

/// Placeholder for the trailing detail column when nothing is selected.
private struct DetailPlaceholderView: View {
#if os(iOS)
	private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#endif
	
	var body: some View {
#if os(iOS)
		if isPad {
			ContentUnavailableView("Details", systemImage: "sidebar.right")
				.toolbar {
					ToolbarItem(placement: .principal) {
						AppTitleView()
					}
				}
		} else {
			ContentUnavailableView("Details", systemImage: "sidebar.right")
				.toolbar {
					ToolbarItem(placement: .principal) {
						AppTitleView()
					}
				}
		}
#else
		ContentUnavailableView("Details", systemImage: "sidebar.right")
			.toolbar {
				ToolbarItem(placement: .principal) {
					AppTitleView()
				}
			}
#endif
	}
}

#Preview {
	ContentView()
}

// MARK: - Compatibility helpers

private extension View {
	@ViewBuilder
	func onChangeCompat<Value: Equatable>(
		of value: Value,
		perform action: @escaping (_ oldValue: Value, _ newValue: Value) -> Void
	) -> some View {
		if #available(iOS 17, macOS 14, *) {
			self.onChange(of: value) { oldValue, newValue in
				action(oldValue, newValue)
			}
		} else {
			self.onChange(of: value) { newValue in
				action(value, newValue)
			}
		}
	}
}

// MARK: - Split view helpers

private extension ContentView {
	func visibility(from raw: String) -> NavigationSplitViewVisibility {
		switch raw {
			case "all": return .all
			case "doubleColumn": return .doubleColumn
			case "detailOnly": return .detailOnly
			default: return .automatic
		}
	}
	
	func raw(from visibility: NavigationSplitViewVisibility) -> String {
		switch visibility {
			case .all: return "all"
			case .doubleColumn: return "doubleColumn"
			case .detailOnly: return "detailOnly"
			default: return "automatic"
		}
	}
}

// MARK: - Debug tools (All builds)

private struct DebugToolsView: View {
	@Environment(\.dismiss) private var dismiss
	
	private var bundleID: String { Bundle.main.bundleIdentifier ?? "(unknown)" }
	private var version: String { AppInfo.version }
	private var storeMode: String { UserDefaults.standard.string(forKey: "StartupStoreMode") ?? "(unknown)" }
	private let containerID = "iCloud.com.aeronauticaltrax.LandShip"
	
#if os(iOS)
	private var platform = "iOS"
#elseif os(macOS)
	private var platform = "macOS"
#else
	private var platform = "Apple Platform"
#endif

	@State private var logsText: String = InAppLogger.shared.joined()
	@State private var isSharing: Bool = false
	@State private var shareURL: URL?

	var body: some View {
		NavigationStack {
			Form {
				Section("Environment") {
					LabeledContent("Platform", value: platform)
#if DEBUG
					LabeledContent("Build", value: "DEBUG")
#else
					LabeledContent("Build", value: "RELEASE")
#endif
					LabeledContent("Version", value: version)
					LabeledContent("Bundle ID", value: bundleID)
					LabeledContent("CloudKit Container", value: containerID)
					LabeledContent("Startup Store Mode", value: storeMode)
				}

				Section("Launch Log + Recent App Logs") {
					TextEditor(text: $logsText)
						.font(.system(.footnote, design: .monospaced))
						.frame(minHeight: 200)
						.accessibilityLabel("In-app logs")
					HStack {
						Button {
							logsText = InAppLogger.shared.joined()
						} label: { Label("Refresh", systemImage: "arrow.clockwise") }
						Spacer()
						#if os(macOS)
						Button {
							copyToPasteboard(logsText)
						} label: { Label("Copy", systemImage: "doc.on.doc") }
						#else
						Button {
							copyToPasteboard(logsText)
						} label: { Label("Copy", systemImage: "doc.on.doc") }
						Button {
							exportLogs(logsText)
						} label: { Label("Share…", systemImage: "square.and.arrow.up") }
						#endif
						Button(role: .destructive) {
							InAppLogger.shared.clear()
							logsText = ""
						} label: { Label("Clear", systemImage: "trash") }
					}
				}

				Section("Troubleshooting") {
					Button(role: .destructive) {
						resetLocalStoreAndExit()
					} label: {
						Label("Reset Local Store", systemImage: "trash")
					}
					.help("Deletes Documents and Application Support, then exits. Use to simulate a clean reinstall.")
				}
				
				Section("Notes") {
					Text("• Debug builds sync to the Development CloudKit environment.\n• TestFlight/App Store builds use Production.\n• After changing container/entitlements/bundle IDs, reinstall on devices to avoid stale metadata.")
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
			.navigationTitle("Debug Tools")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
			#if !os(macOS)
			.sheet(isPresented: $isSharing, onDismiss: {
				if let url = shareURL { try? FileManager.default.removeItem(at: url) }
				shareURL = nil
			}) {
				if let url = shareURL {
					ActivityView(activityItems: [url])
				} else {
					Text("No log to share.")
				}
			}
			#endif
		}
	}

	private func copyToPasteboard(_ text: String) {
		#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
		#else
		UIPasteboard.general.string = text
		#endif
	}

	private func exportLogs(_ text: String) {
		#if os(macOS)
		copyToPasteboard(text)
		#else
		let url = FileManager.default.temporaryDirectory.appendingPathComponent("LandShip-Logs.txt")
		do {
			try text.data(using: .utf8)?.write(to: url, options: .atomic)
			self.shareURL = url
			self.isSharing = true
		} catch {
			print("Failed to write logs: \(error)")
		}
		#endif
	}
	
	private func resetLocalStoreAndExit() {
		let fm = FileManager.default
		
		func removeIfExists(_ url: URL) {
			if fm.fileExists(atPath: url.path) {
				do {
					try fm.removeItem(at: url)
					print("[LandShip] Removed: \(url.path)")
					InAppLogger.shared.log("Removed: \(url.path)")
				} catch {
					print("[LandShip] Failed to remove \(url.path): \(error)")
					InAppLogger.shared.log("Failed to remove \(url.path): \(error.localizedDescription)")
				}
			}
		}
		
		// Remove Documents and Application Support contents
		if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
			removeIfExists(docs)
		}
		if let appSup = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			removeIfExists(appSup)
		}
		
#if os(macOS)
		NSApp.terminate(nil)
#else
		exit(0)
#endif
	}
}

// MARK: - In-app logger

@MainActor
fileprivate final class InAppLogger {
	static let shared = InAppLogger()
	private let key = "InAppLogs"
	private let maxEntries = 1000
	private let df: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return f
	}()
	private init() {}

	func log(_ message: String) {
		let ts = df.string(from: Date())
		let line = "[\(ts)] \(message)"
		var arr = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
		arr.append(line)
		if arr.count > maxEntries {
			arr.removeFirst(arr.count - maxEntries)
		}
		UserDefaults.standard.set(arr, forKey: key)
	}

	func all() -> [String] {
		(UserDefaults.standard.array(forKey: key) as? [String]) ?? []
	}

	func joined() -> String {
		all().joined(separator: "\n")
	}

	func clear() {
		UserDefaults.standard.removeObject(forKey: key)
	}
}

#if canImport(UIKit) && !os(macOS)
private struct ActivityView: UIViewControllerRepresentable {
	let activityItems: [Any]
	var applicationActivities: [UIActivity]? = nil

	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif












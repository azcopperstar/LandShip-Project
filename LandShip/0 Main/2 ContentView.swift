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

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The root view that hosts the three-column navigation interface, top-level sheets,
/// backup/restore flows, and first-run onboarding.
struct ContentView: View {
	// MARK: - Global presentation state
	
	// Settings and Help sheets
	@State private var showingPreferences = false // Reserved for future use if needed
	@State private var showingSettingsSheet = false
	@State private var showingHelpSheet = false
	@State private var showingChangelogSheet = false
	@State private var showingFeedbackSheet = false
	// Removed showingUpgrades property as per instructions
	
	// Hidden Debug Tools sheet (appears on long-press of title)
	@State private var showingDebugTools = false
	
	// MARK: - Cross-view and persisted state
	
	@AppStorage(StorageKey.trackVehicleSelected) private var trackVehicleSelected: String = "All Vehicles"
	@SceneStorage(StorageKey.splitColumnVisibility) private var columnVisibilityRawValue: String = "all"
	
	@State private var splitVisibility: NavigationSplitViewVisibility = .all
	@State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
	
	@AppStorage(StorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
	@AppStorage(StorageKey.launchScreen) private var launchScreen: String = "dashboard"
	@AppStorage(StorageKey.lastSidebarSection) private var lastSidebarSection: String = "dashboard"
	@State private var showingOnboarding: Bool = false
	
	// Column width persistence (primarily for iPad, macOS uses autosave)
	@SceneStorage(StorageKey.sidebarColumnWidth) private var sidebarWidth: Double = 240
	@SceneStorage(StorageKey.contentColumnWidth) private var contentWidth: Double = 450
	@SceneStorage(StorageKey.detailColumnWidth) private var detailWidth: Double = 400
	
	// MARK: - Sidebar selection
	
	@State private var sidebarSelection: SidebarItem? = {
#if os(iOS)
		return UIDevice.current.userInterfaceIdiom == .pad ? .dashboard : nil
#else
		return .dashboard
#endif
	}()
    @State private var detailPath = NavigationPath()
    @State private var splitResetID = UUID()
	
	// MARK: - Backup / Restore state

	// Manual backups only — automatic backups track their own timestamp
	// (StorageKey.lastAutoBackupDate) so the two are never conflated.
	@AppStorage(StorageKey.lastBackupDate) private var lastBackupDateInterval: Double = 0
	// Security-scoped bookmark to the folder the last manual backup was saved to
	// (an arbitrary, user-picked location), so it can be revealed later.
	@AppStorage(StorageKey.lastManualBackupBookmark) private var lastManualBackupBookmark: Data = Data()

	@State private var isExportingBackup: Bool = false
	@State private var isBackupInProgress: Bool = false
	@State private var backupDocument: BackupDocument = .empty
	@State private var backupErrorMessage: String?
    @State private var backupSuccessMessage: String?
    @State private var isBackupSuccessPresented: Bool = false

	@State private var showRestoreSourceChoice: Bool = false
	@State private var isImportingRestore: Bool = false
	@State private var showingManageAutoBackups: Bool = false
	@State private var pendingRestoreURL: URL?
	@State private var showConfirmRestore: Bool = false
	@State private var restoreErrorMessage: String?
	@State private var restoreSuccessMessage: String?

	@State private var isBackupErrorPresented: Bool = false
	@State private var isRestoreErrorPresented: Bool = false
	@State private var isRestoreSuccessPresented: Bool = false
	@State private var restartRequiredAfterRestore: Bool = false

	// Whether the running ModelContainer was created in CloudKit-backed mode at launch (see
	// LandShipApp). Restoring a raw local-store snapshot while CloudKit sync is active risks
	// pushing stale/deleted data back out to every synced device, so restore offers a choice
	// of mode in that case — see BackupService.restoreFromBackupFolder.
	private var isCloudKitActive: Bool {
		BackupService.isCloudKitActive()
	}

	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase

#if os(iOS)
	private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#endif

	// Prevent duplicate launch logging per process
	private static var didLogLaunch = false
	// Avoid checking for a due automatic backup more than once per launch on .onAppear;
	// .onChange(of: scenePhase) still re-checks each time the app becomes active.
	private static var didCheckAutoBackupOnLaunch = false
	
	// MARK: - Body

    // Sidebar column, shared between the 3-column layout and the iPad-Dashboard 2-column layout.
    @ViewBuilder
    private var sidebarColumn: some View {
        SidebarView(
            sidebarSelection: $sidebarSelection,
            showingSettingsSheet: $showingSettingsSheet,
            showingHelpSheet: $showingHelpSheet,
            showingChangelogSheet: $showingChangelogSheet,
            showingFeedbackSheet: $showingFeedbackSheet,
            isBackupInProgress: isBackupInProgress,
            onBackupTapped: handleBackupTapped,
            onRestoreTapped: { showRestoreSourceChoice = true },
            onShowManageAutoBackups: { showingManageAutoBackups = true }
        )
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 150, ideal: sidebarWidth, max: 300)
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
    }

    // On iPad, the Dashboard has no middle "content" column to show, so the standard 3-column
    // NavigationSplitView leaves that column visible-but-empty, wasting a wide strip of screen
    // width. Using a genuine 2-column split for this case lets the Dashboard fill that space.
#if os(iOS)
    private var dashboardIPadSplit: some View {
        NavigationSplitView(
            columnVisibility: $splitVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebarColumn
        } detail: {
            NavigationStack {
                DashboardView()
            }
        }
    }
#endif

    private var threeColumnSplit: some View {
        NavigationSplitView(
            columnVisibility: $splitVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            sidebarColumn
        } content: {
            MiddleColumnView(
                sidebarSelection: $sidebarSelection,
                trackVehicleSelected: $trackVehicleSelected
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: contentWidth, max: 500)
        } detail: {
            DetailColumnView(
                detailPath: $detailPath,
                selectionID: sidebarSelection
            )
            .navigationSplitViewColumnWidth(min: 100, ideal: detailWidth, max: 600)
        }
#if os(macOS)
        .splitViewAutosave("MainSplit")
#endif
    }

    // Extracted root NavigationSplitView to reduce type-checking complexity
    private var splitRoot: some View {
        Group {
#if os(iOS)
            if isPad && sidebarSelection == .dashboard {
                dashboardIPadSplit
            } else {
                threeColumnSplit
            }
#else
            threeColumnSplit
#endif
        }
        .id(splitResetID)
    }

	var body: some View {
        splitRoot
		.sheet(isPresented: $showingSettingsSheet) {
			SettingsEditorView(onRestoreRequested: { url in
				showingSettingsSheet = false
				requestRestore(from: url)
			})
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
		.sheet(isPresented: $showingChangelogSheet) {
			ChangelogSheet { showingChangelogSheet = false }
		}
		.sheet(isPresented: $showingFeedbackSheet) {
			FeedbackSheet { showingFeedbackSheet = false }
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
                    lastBackupDateInterval = Date().timeIntervalSince1970
                    saveLastManualBackupBookmark(for: url)
                    InAppLogger.shared.log("Backup export succeeded: \(url.lastPathComponent)")
                case .failure(let error):
                    backupErrorMessage = error.localizedDescription
                    isBackupErrorPresented = true
                    InAppLogger.shared.log("Backup export failed: \(error.localizedDescription)")
            }
        }
		
		// Restore source choice — presented before the file picker so the user can
		// restore from an automatic backup (picked from Manage Auto-Backups) instead.
		.confirmationDialog(
			"Restore Data",
			isPresented: $showRestoreSourceChoice,
			titleVisibility: .visible
		) {
			Button("From Manual Backup…") {
				isImportingRestore = true
			}
			Button("From Automatic Backup…") {
				showingManageAutoBackups = true
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Restore from a backup folder you saved yourself, or from one of the automatic backups \(AppInfo.displayName) has created for you.")
		}
		.sheet(isPresented: $showingManageAutoBackups) {
			NavigationStack {
				ManageAutoBackupsView(onRestoreRequested: { url in
					showingManageAutoBackups = false
					requestRestore(from: url)
				})
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Close") { showingManageAutoBackups = false }
					}
				}
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
			if isCloudKitActive {
				Button("Resync from iCloud (Recommended)") {
					performRestore(forceExactSnapshot: false)
				}
				Button("Restore Exact Snapshot (Advanced)", role: .destructive) {
					performRestore(forceExactSnapshot: true)
				}
			} else {
				Button("Replace current data with selected backup", role: .destructive) {
					performRestore(forceExactSnapshot: false)
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(isCloudKitActive
				? "\u{201C}Resync from iCloud\u{201D} restores your Documents (PDFs, etc.) from the backup and re-downloads your vehicle/service data fresh from iCloud — safe, but records already deleted from iCloud will stay deleted. \u{201C}Restore Exact Snapshot\u{201D} instead overwrites your local database with the backup exactly as saved; use this only if you're restoring onto a different iCloud account, or iCloud's data didn't come back correctly and you need to force the backup's data back in — it can conflict with your other devices on the same iCloud account until they resync. A restart is required after restoring either way."
				: "This will overwrite your current data (Documents and Application Support) with the contents of the selected backup folder. A restart is required after restoring.")
		}
		
		.alert("Backup Failed", isPresented: $isBackupErrorPresented) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(backupErrorMessage ?? "")
		}
        .sheet(isPresented: $isBackupSuccessPresented) {
            BackupSummarySheet(message: backupSuccessMessage ?? "") {
                isBackupSuccessPresented = false
            }
        }
		.alert("Restore Failed", isPresented: $isRestoreErrorPresented) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(restoreErrorMessage ?? "")
		}
		.alert("Restore Complete", isPresented: $isRestoreSuccessPresented) {
#if os(macOS)
			Button("Quit Now") { NSApp.terminate(nil) }
#else
			Button("OK") { restartRequiredAfterRestore = true }
#endif
		} message: {
			Text(restoreSuccessMessage ?? "")
		}
#if !os(macOS)
		.fullScreenCover(isPresented: $restartRequiredAfterRestore) {
			RestartRequiredView()
				.interactiveDismissDisabled(true)
		}
#endif

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
			
			// Migrate existing vehicles to populate displayName from name
			migrateVehicleDisplayNames()
			deduplicateSettings()
			
			// Resolve the launch screen preference
			let launchItem: SidebarItem
			if launchScreen == "lastSection" {
				launchItem = SidebarItem(rawValue: lastSidebarSection) ?? .dashboard
			} else {
				launchItem = SidebarItem(rawValue: launchScreen) ?? .dashboard
			}
#if os(iOS)
			if isPad {
				Task { @MainActor in
					sidebarSelection = launchItem
					splitVisibility = .all
				}
			} else {
				Task { @MainActor in sidebarSelection = nil }
			}
#else
			Task { @MainActor in sidebarSelection = launchItem }
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

			// Check for a due automatic backup once per launch.
			if !Self.didCheckAutoBackupOnLaunch {
				Self.didCheckAutoBackupOnLaunch = true
				checkAutoBackupIfNeeded()
			}
		}
		.onChangeCompat(of: scenePhase) { _, newPhase in
			// Re-check whenever the app comes back to the foreground, since a scheduled
			// backup could become due while the app was in the background.
			if newPhase == .active {
				checkAutoBackupIfNeeded()
			}
		}
		.onChangeCompat(of: showingSettingsSheet) { _, isShowing in
			// Re-check right after Settings closes, so turning on automatic backups
			// (with none yet on record) creates the first one immediately rather than
			// waiting for the next launch or foreground event.
			if !isShowing {
				checkAutoBackupIfNeeded()
			}
		}
		.onChangeCompat(of: splitVisibility) { _, newValue in
			columnVisibilityRawValue = raw(from: newValue)
		}
        .onChangeCompat(of: sidebarSelection) { _, newValue in
            // Clear the detail navigation when switching sections to avoid stale detail views
            detailPath = NavigationPath()
            splitResetID = UUID()
            // Persist last section for "Last Section Open" launch preference
            if let item = newValue {
                lastSidebarSection = item.rawValue
            }
#if os(iOS)
            if isPad {
                // Always keep all columns visible so the sidebar remains accessible
                splitVisibility = .all
            }
#endif
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

	/// Removes duplicate Settings1 records that can appear when multiple devices each create
	/// a record before CloudKit sync delivers the other device's copy.
	/// All devices independently converge on the same winner by sorting on persistentModelID.
	private func deduplicateSettings() {
		let descriptor = FetchDescriptor<Settings1>(
			predicate: #Predicate { $0.userName == "primary1" }
		)
		guard let all = try? modelContext.fetch(descriptor), all.count > 1 else { return }
		let enc = JSONEncoder()
		func idData2(_ m: Settings1) -> Data { (try? enc.encode(m.persistentModelID)) ?? Data() }
		let sorted = all.sorted { idData2($0).lexicographicallyPrecedes(idData2($1)) }
		for duplicate in sorted.dropFirst() {
			modelContext.delete(duplicate)
		}
		try? modelContext.save()
		print("[LandShip] Deduplicated \(all.count - 1) extra Settings1 record(s)")
	}

	private func handleBackupTapped() {
		guard !isBackupInProgress else { return }
		do {
			// Fetching model data must happen here, synchronously, on the main actor —
			// ModelContext isn't Sendable and can't be touched from a background task.
			let mediaSnapshots = try BackupService.collectMediaSnapshots(context: modelContext)
			isBackupInProgress = true
			InAppLogger.shared.log("Backup export started")
			Task {
				defer { isBackupInProgress = false }
				do {
					// The actual file-system read happens off the main thread so this
					// doesn't freeze the UI while scanning Application Support/Documents.
					let doc = try await BackupService.makeBackupDocument(mediaSnapshots: mediaSnapshots)
					self.backupDocument = doc
					self.isExportingBackup = true
				} catch {
					self.backupErrorMessage = error.localizedDescription
					self.isBackupErrorPresented = true
					InAppLogger.shared.log("Backup export failed: \(error.localizedDescription)")
				}
			}
		} catch {
			self.backupErrorMessage = error.localizedDescription
			self.isBackupErrorPresented = true
			InAppLogger.shared.log("Backup export failed early: \(error.localizedDescription)")
		}
	}

	/// Persists a security-scoped bookmark to the folder the user just picked for a manual
	/// backup, so its location can be reopened/revealed later (see SidebarView's "Last Manual
	/// Backup" link) even in a future launch of the app.
	private func saveLastManualBackupBookmark(for url: URL) {
#if os(macOS)
		let options: URL.BookmarkCreationOptions = [.withSecurityScope]
#else
		let options: URL.BookmarkCreationOptions = []
#endif
		do {
			lastManualBackupBookmark = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
		} catch {
			InAppLogger.shared.log("Failed to bookmark manual backup location: \(error.localizedDescription)")
		}
	}

	/// Presents the restore confirmation for a given backup folder URL, deferred to the next
	/// run loop so it doesn't race with another sheet/view that's still dismissing.
	private func requestRestore(from url: URL) {
		DispatchQueue.main.async {
			pendingRestoreURL = url
			showConfirmRestore = true
		}
	}

	/// Silently creates an automatic backup if one is due (see AutoBackupInterval in Settings).
	/// Safe to call opportunistically — it's a no-op unless enabled and overdue.
	private func checkAutoBackupIfNeeded() {
		guard AutoBackupService.isDue() else { return }
		do {
			// Must happen here, synchronously, on the main actor — ModelContext isn't
			// Sendable and can't be fetched from a background task.
			let mediaSnapshots = try BackupService.collectMediaSnapshots(context: modelContext)
			Task {
				await AutoBackupService.run(mediaSnapshots: mediaSnapshots)
			}
		} catch {
			InAppLogger.shared.log("Automatic backup snapshot collection failed: \(error.localizedDescription)")
		}
	}

	private func performRestore(forceExactSnapshot: Bool) {
		guard let url = pendingRestoreURL else { return }
		Task {
			do {
				let message = try await BackupService.restoreFromBackupFolder(url, forceExactSnapshot: forceExactSnapshot)
				restoreSuccessMessage = message
				isRestoreSuccessPresented = true
				InAppLogger.shared.log("Restore complete (\(forceExactSnapshot ? "exact snapshot" : "auto")): \(message)")
			} catch {
				restoreErrorMessage = error.localizedDescription
				isRestoreErrorPresented = true
				InAppLogger.shared.log("Restore failed: \(error.localizedDescription)")
			}
		}
	}
	
	/// Migrates existing Vehicle8 records to populate displayName from name if displayName is empty
	private func migrateVehicleDisplayNames() {
		let descriptor = FetchDescriptor<Vehicle8>()
		guard let vehicles = try? modelContext.fetch(descriptor) else {
			print("[Migration] Failed to fetch vehicles for displayName migration")
			return
		}
		
		var migratedCount = 0
		for vehicle in vehicles {
			if vehicle.displayName.isEmpty {
				// Check if name looks like a UUID (contains dashes and is long)
				if vehicle.name.contains("-") && vehicle.name.count > 30 {
					// It's a UUID, use a friendly default
					vehicle.displayName = "Unnamed Vehicle"
				} else {
					// It's a regular name, copy it to displayName
					vehicle.displayName = vehicle.name
				}
				migratedCount += 1
			}
		}
		
		if migratedCount > 0 {
			do {
				try modelContext.save()
				print("[Migration] Successfully migrated displayName for \(migratedCount) vehicle(s)")
			} catch {
				print("[Migration] Failed to save displayName migration: \(error.localizedDescription)")
			}
		} else {
			print("[Migration] No vehicles needed displayName migration")
		}
		
		// Also migrate vehicleId fields in all data models
		migrateVehicleIds()
	}
	
	/// Migrates vehicleId fields across all models to use vehicle names instead of UUIDs
	private func migrateVehicleIds() {
		// First, fetch all vehicles to create a UUID -> name mapping
		let vehicleDescriptor = FetchDescriptor<Vehicle8>()
		guard let vehicles = try? modelContext.fetch(vehicleDescriptor) else {
			print("[Migration] Failed to fetch vehicles for vehicleId migration")
			return
		}
		
		// Build lookup map: try matching by id string representation
		var totalMigrated = 0
		// Some migrations are commented out because their model types are unavailable in this target; re-enable when models are added.
		
		// Helper to check if a string looks like a UUID
		func looksLikeUUID(_ string: String) -> Bool {
			return string.contains("-") && string.count > 30
		}
		
		// Helper to find vehicle by matching UUID pattern in name or other fields
		func findVehicleForUUID(_ uuid: String) -> Vehicle8? {
			return vehicles.first { vehicle in
				vehicle.name == uuid || 
				vehicle.displayName == uuid ||
				String(describing: vehicle.id) == uuid
			}
		}
		
		// Migrate MxItems3
		if let items = try? modelContext.fetch(FetchDescriptor<MxItems3>()) {
			var count = 0
			for item in items where looksLikeUUID(item.vehicleId) {
				if let vehicle = findVehicleForUUID(item.vehicleId) {
					item.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) MxItems3 record(s)")
				totalMigrated += count
			}
		}
		
		// Migrate ServiceRecords3
		/*
		if let records = try? modelContext.fetch(FetchDescriptor<ServiceRecords3>()) {
			var count = 0
			for record in records where looksLikeUUID(record.vehicleId) {
				if let vehicle = findVehicleForUUID(record.vehicleId) {
					record.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) ServiceRecords3 record(s)")
				totalMigrated += count
			}
		}
		*/
		// TODO: ServiceRecords3 type not found in this target. Enable this block when the model is available.
		
		// Migrate FuelLog3
		/*
		if let logs = try? modelContext.fetch(FetchDescriptor<FuelLog3>()) {
			var count = 0
			for log in logs where looksLikeUUID(log.vehicleId) {
				if let vehicle = findVehicleForUUID(log.vehicleId) {
					log.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) FuelLog3 record(s)")
				totalMigrated += count
			}
		}
		*/
		// TODO: FuelLog3 type not found in this target. Enable this block when the model is available.
		
		// Migrate TripLog3
		/*
		if let trips = try? modelContext.fetch(FetchDescriptor<TripLog3>()) {
			var count = 0
			for trip in trips where looksLikeUUID(trip.vehicleId) {
				if let vehicle = findVehicleForUUID(trip.vehicleId) {
					trip.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) TripLog3 record(s)")
				totalMigrated += count
			}
		}
		*/
		// TODO: TripLog3 type not found in this target. Enable this block when the model is available.
		
		// Migrate MxParts3
		/*
		if let parts = try? modelContext.fetch(FetchDescriptor<MxParts3>()) {
			var count = 0
			for part in parts where looksLikeUUID(part.vehicleId) {
				if let vehicle = findVehicleForUUID(part.vehicleId) {
					part.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) MxParts3 record(s)")
				totalMigrated += count
			}
		}
		*/
		// TODO: MxParts3 type not found in this target. Enable this block when the model is available.

		// Migrate VehicleSystems2
		/*
		if let systems = try? modelContext.fetch(FetchDescriptor<VehicleSystems2>()) {
			var count = 0
			for system in systems where looksLikeUUID(system.vehicleId) {
				if let vehicle = findVehicleForUUID(system.vehicleId) {
					system.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) VehicleSystems2 record(s)")
				totalMigrated += count
			}
		}
		*/
		// TODO: VehicleSystems2 type not found in this target. Enable this block when the model is available.
		
		// Migrate ProjectList
		if let projects = try? modelContext.fetch(FetchDescriptor<ProjectList>()) {
			var count = 0
			for project in projects where looksLikeUUID(project.vehicleId) {
				if let vehicle = findVehicleForUUID(project.vehicleId) {
					project.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) ProjectList record(s)")
				totalMigrated += count
			}
		}
		
		// Migrate CheckList
		if let checklists = try? modelContext.fetch(FetchDescriptor<CheckList>()) {
			var count = 0
			for checklist in checklists where looksLikeUUID(checklist.vehicleId) {
				if let vehicle = findVehicleForUUID(checklist.vehicleId) {
					checklist.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) CheckList record(s)")
				totalMigrated += count
			}
		}
		
		// Migrate Additions
		if let additions = try? modelContext.fetch(FetchDescriptor<Additions>()) {
			var count = 0
			for addition in additions where looksLikeUUID(addition.vehicleId) {
				if let vehicle = findVehicleForUUID(addition.vehicleId) {
					addition.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) Additions record(s)")
				totalMigrated += count
			}
		}
		
		// Migrate Subscriptions
		if let subscriptions = try? modelContext.fetch(FetchDescriptor<Subscriptions>()) {
			var count = 0
			for subscription in subscriptions where looksLikeUUID(subscription.vehicleId) {
				if let vehicle = findVehicleForUUID(subscription.vehicleId) {
					subscription.vehicleId = vehicle.name
					count += 1
				}
			}
			if count > 0 {
				print("[Migration] Migrated vehicleId for \(count) Subscriptions record(s)")
				totalMigrated += count
			}
		}
		
		// Save all changes
		if totalMigrated > 0 {
			do {
				try modelContext.save()
				print("[Migration] Successfully migrated vehicleId for \(totalMigrated) total record(s)")
			} catch {
				print("[Migration] Failed to save vehicleId migration: \(error.localizedDescription)")
			}
		} else {
			print("[Migration] No records needed vehicleId migration")
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
	@Binding var showingChangelogSheet: Bool
	@Binding var showingFeedbackSheet: Bool
	var isBackupInProgress: Bool
	var onBackupTapped: () -> Void
	var onRestoreTapped: () -> Void
	// Opens ContentView's Manage Auto-Backups sheet (kept centralized there so both this
	// link and the Restore… source-choice dialog share the same presentation state).
	var onShowManageAutoBackups: () -> Void

	@AppStorage(StorageKey.lastBackupDate) private var lastBackupDateInterval: Double = 0
	@AppStorage(StorageKey.lastManualBackupBookmark) private var lastManualBackupBookmark: Data = Data()
	@AppStorage(StorageKey.lastAutoBackupDate) private var lastAutoBackupDateInterval: Double = 0

	private var lastBackupLabel: String {
		guard lastBackupDateInterval > 0 else { return "No backup on record" }
		let date = Date(timeIntervalSince1970: lastBackupDateInterval)
		let df = DateFormatter()
		df.dateStyle = .medium
		df.timeStyle = .short
		return df.string(from: date)
	}

	private var lastAutoBackupLabel: String {
		guard lastAutoBackupDateInterval > 0 else { return "None yet" }
		let date = Date(timeIntervalSince1970: lastAutoBackupDateInterval)
		let df = DateFormatter()
		df.dateStyle = .medium
		df.timeStyle = .short
		return df.string(from: date)
	}

	/// Resolves the bookmarked manual-backup location and reveals it: in Finder on macOS,
	/// or in a Files-style folder browser on iOS/iPadOS. No-op if nothing's bookmarked yet
	/// or the bookmark can no longer be resolved (e.g. the folder was moved or deleted).
	private func revealLastManualBackup() {
		guard !lastManualBackupBookmark.isEmpty else { return }
#if os(macOS)
		let resolveOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
#else
		let resolveOptions: URL.BookmarkResolutionOptions = []
#endif
		var isStale = false
		guard let url = try? URL(
			resolvingBookmarkData: lastManualBackupBookmark,
			options: resolveOptions,
			relativeTo: nil,
			bookmarkDataIsStale: &isStale
		) else { return }

#if os(macOS)
		let accessed = url.startAccessingSecurityScopedResource()
		NSWorkspace.shared.activateFileViewerSelecting([url])
		if accessed { url.stopAccessingSecurityScopedResource() }
#else
		folderBrowserURL = url
#endif
	}

#if !os(macOS)
	@State private var folderBrowserURL: URL?
#endif

	var body: some View {
		List(selection: $sidebarSelection) {
			Section(header: CenteredSectionHeader(title: "")) {
				Label("Dashboard", systemImage: "rectangle.grid.2x2")
					.sidebarRowStyle(selected: sidebarSelection == .dashboard)
					.tag(SidebarItem.dashboard)
			}

			Section(header: CenteredSectionHeader(title: "Garage")) {
				Label("Vehicles", systemImage: "car.2.fill")
					.sidebarRowStyle(selected: sidebarSelection == .vehicles)
					.tag(SidebarItem.vehicles)
				Label("Parts", systemImage: "gearshape.2.fill")
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
				Label("Records", systemImage: "wrench.and.screwdriver.fill")
					.sidebarRowStyle(selected: sidebarSelection == .records)
					.tag(SidebarItem.records)
				Label("Items", systemImage: "folder.badge.gearshape")
					.sidebarRowStyle(selected: sidebarSelection == .items)
					.tag(SidebarItem.items)
			}
			
			Section(header: CenteredSectionHeader(title: "Vehicle Financials")) {
				Label("Improvements", systemImage: "cart.badge.plus")
					.sidebarRowStyle(selected: sidebarSelection == .additions)
					.tag(SidebarItem.additions)
				Label("Expenditures", systemImage: "calendar.badge.clock")
					.sidebarRowStyle(selected: sidebarSelection == .subscriptions)
					.tag(SidebarItem.subscriptions)
			}

			Section(header: CenteredSectionHeader(title: "Projects/Checklists")) {
				Label("Projects", systemImage: "list.number.badge.ellipsis")
					.sidebarRowStyle(selected: sidebarSelection == .projectList)
					.tag(SidebarItem.projectList)
//				Label("Punch-Lists", systemImage: "iphone.badge.checkmark")
//					.sidebarRowStyle(selected: sidebarSelection == .livePunchList)
//					.tag(SidebarItem.livePunchList)

//				Divider()
//					.listRowBackground(Color.clear)
//					.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

				Label("Checklists", systemImage: "checklist")
					.sidebarRowStyle(selected: sidebarSelection == .displayChecklist)
					.tag(SidebarItem.displayChecklist)
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
					HStack {
						Label("Backup…", systemImage: "square.and.arrow.up")
							.sidebarRowStyle(selected: sidebarSelection == .backup)
						if isBackupInProgress {
							Spacer()
							ProgressView()
								.controlSize(.small)
						}
					}
				}
				.buttonStyle(.plain)
				.disabled(isBackupInProgress)

				HStack(spacing: 0) {
					Spacer().frame(width: 32)
					if lastManualBackupBookmark.isEmpty {
						Text("Last Manual Backup: " + lastBackupLabel)
							.font(.caption2)
							.foregroundStyle(.secondary)
					} else {
						Button {
							revealLastManualBackup()
						} label: {
							Text("Last Manual Backup: " + lastBackupLabel)
								.font(.caption2)
								.underline()
								.foregroundStyle(.tint)
						}
						.buttonStyle(.plain)
						.accessibilityHint("Opens the folder this backup was saved to")
					}
					Spacer()
				}
				.listRowBackground(Color.clear)

				HStack(spacing: 0) {
					Spacer().frame(width: 32)
					Button {
						onShowManageAutoBackups()
					} label: {
						Text("Last Auto Backup: " + lastAutoBackupLabel)
							.font(.caption2)
							.underline()
							.foregroundStyle(.tint)
					}
					.buttonStyle(.plain)
					.accessibilityHint("Opens the Manage Auto-Backups screen")
					Spacer()
				}
				.listRowBackground(Color.clear)

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

				Button {
					showingChangelogSheet = true
					InAppLogger.shared.log("Opened What's New")
				} label: {
					Label("What's New", systemImage: "clock.arrow.circlepath")
						.sidebarRowStyle(selected: false)
				}
				.buttonStyle(.plain)

				Button {
					showingFeedbackSheet = true
					InAppLogger.shared.log("Opened Send Feedback")
				} label: {
					Label("Send Feedback", systemImage: "paperplane")
						.sidebarRowStyle(selected: false)
				}
				.buttonStyle(.plain)
			}
#endif
		}
#if !os(macOS)
		.sheet(isPresented: Binding(
			get: { folderBrowserURL != nil },
			set: { isPresented in if !isPresented { folderBrowserURL = nil } }
		)) {
			if let url = folderBrowserURL {
				FolderBrowserView(url: url)
			}
		}
#endif
	}
}

#if !os(macOS)
/// Presents a system folder browser already navigated to a given folder's enclosing
/// directory, so the user can see/open it — used to "reveal" a manual backup's saved
/// location, which lives outside the app's own sandbox so it can't be shown any other way.
/// Browsing only: picking or cancelling both just dismiss the sheet.
private struct FolderBrowserView: UIViewControllerRepresentable {
	let url: URL

	func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
		picker.directoryURL = url.deletingLastPathComponent()
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

	func makeCoordinator() -> Coordinator { Coordinator() }

	final class Coordinator: NSObject, UIDocumentPickerDelegate {
		func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {}
		func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
	}
}
#endif

/// Extracted middle column content to reduce type-checking complexity
struct MiddleColumnView: View {
    @Binding var sidebarSelection: SidebarItem?
    @Binding var trackVehicleSelected: String

    @Query private var projectLists: [ProjectList]

    @State private var selectedProjectSubcategory: String = "Oil"

    @ViewBuilder
    var body: some View {
        let selection = sidebarSelection ?? .none

        // Derive unique, non-empty subcategory names from ProjectList.subCategory
        let subcategories: [String] = Array(
            Set(
                projectLists.compactMap { item in
                    let trimmed = item.subCategory.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
            )
        ).sorted()

        let safeSubcategories = subcategories.isEmpty ? ["General"] : subcategories

        Group {
            switch selection {
            case .dashboard:
#if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Color.clear  // Dashboard shown full-width in detail column on iPad
                } else {
                    DashboardView()
                }
#else
                DashboardView()
#endif
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
            case .additions:
                DisplayAdditions()
            case .subscriptions:
                DisplaySubscriptions()
            case .projectList:
                DisplayProjectList(trackVehicleSelected: $trackVehicleSelected)
            case .livePunchList:
                LivePunchListView()
            case .punchList:
                pdfReportPunchList(
                    trackVehicleSelected: trackVehicleSelected,
                    projectSubcategory: selectedProjectSubcategory
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
							case .displayChecklist:
								DisplayCheckList(trackVehicleSelected: $trackVehicleSelected)
							case .none:
                ContentPlaceholderView()
            }
        }
        .onAppear {
            if selectedProjectSubcategory.isEmpty, let first = safeSubcategories.first {
                selectedProjectSubcategory = first
            }
        }
        .onChange(of: subcategories) {
            if !subcategories.contains(selectedProjectSubcategory) {
                selectedProjectSubcategory = safeSubcategories.first ?? "General"
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


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
import CoreData
import OSLog
import StoreKit

#if os(macOS)
import AppKit
#endif

// Unified logging for CloudKit diagnostics
fileprivate let logger = Logger(subsystem: "com.aeronauticaltrax.LandShip", category: "CloudKitSync")

extension Notification.Name {
	/// Posted by the macOS "Debug Tools…" menu item to open ContentView's hidden
	/// debug sheet. The .principal toolbar item's long-press gesture that opens it
	/// on iOS is unreliable on macOS, where the toolbar's Liquid Glass chrome can
	/// intercept the mouse-down before SwiftUI's gesture recognizer sees it.
	static let openDebugToolsRequested = Notification.Name("openDebugToolsRequested")
}

@main
struct LandShipApp: App {
	
	// MARK: - Startup Result
	
	private let modelContainer: ModelContainer?
	private let startupError: Error?
	private let isLocalOnly: Bool

	@AppStorage(StorageKey.appearanceMode) private var appearanceModeRaw: String = AppearanceMode.system.rawValue
	private var appearanceMode: AppearanceMode { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
	
	// Sync monitoring (static to persist for app lifetime)
	private static var syncMonitor: CloudKitSyncMonitor?
	
	// Diagnostics
	// Derived (not hardcoded) so each vertical target's own bundle ID maps to its own
	// CloudKit container. For VehicleTrax, Bundle.main.bundleIdentifier is already
	// "com.aeronauticaltrax.LandShip", so this resolves to the identical value existing
	// users already sync against — this change is a no-op for VehicleTrax.
	private static var cloudKitContainerID: String {
		"iCloud." + (Bundle.main.bundleIdentifier ?? "com.aeronauticaltrax.LandShip")
	}
	
#if DEBUG
	private let buildConfiguration = "DEBUG"
#else
	private let buildConfiguration = "RELEASE"
#endif

	// Reads the App Store environment cached by EntitlementStore's AppTransaction check
	// (see StorageKey.appStoreEnvironment), which is accurate on both platforms — unlike
	// the old iOS-only receipt-filename heuristic that mislabeled macOS TestFlight builds.
	// Unset on the very first launch, before the first receipt check completes.
	private static func isTestFlightBuild() -> Bool {
		guard let raw = UserDefaults.standard.string(forKey: StorageKey.appStoreEnvironment) else {
			return false
		}
		return raw == String(describing: AppStore.Environment.sandbox)
	}
	
	init() {
		// Apply any restore staged by the Backup/Restore UI. This must happen before the
		// ModelContainer below opens the store — swapping the database files while a live
		// SQLite/CloudKit stack still has them open is what used to lose restored data
		// (SQLite deletes the -wal/-shm sidecars at the store path on clean close).
		if BackupService.applyPendingRestoreIfNeeded() {
			print("[LandShip] Pending restore applied before store initialization")
		}

		// Define the SwiftData schema from the shared model list (AppSchema is also what the
		// restore re-import walks, so the two can never drift apart).
		let schema = Schema(AppSchema.modelTypes)
		
		// Attempt CloudKit first, then local-only.
		switch Self.makeContainer(schema: schema) {
			case .cloud(let container):
				self.modelContainer = container
				self.startupError = nil
				self.isLocalOnly = false
				UserDefaults.standard.set("cloud", forKey: "StartupStoreMode")
				print("[LandShip] Store mode: CloudKit-backed")
				logger.notice("✅ Store mode: CloudKit-backed")
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
		
		// MARK: - CloudKit Monitoring Features (Commented Out - Working Now)
		// These features were used to troubleshoot and test CloudKit sync.
		// Uncomment if you need to debug sync issues in the future.
		
		// Log which CloudKit database this build is signed for, plus account status.
		Task {
			await Self.checkCloudKitStatus()
		}
		
		// Initialize sync monitor if we have a CloudKit container, so export and
		// import failures surface with their real CKError instead of failing silently.
		if !isLocalOnly, let container = modelContainer {
			Self.syncMonitor = CloudKitSyncMonitor(container: container)
		}
	}
	
	// MARK: - CloudKit Diagnostics
	
	private static func checkCloudKitStatus() async {
		let container = CKContainer(identifier: cloudKitContainerID)
		
		// Detect CloudKit environment
		let environment = detectCloudKitEnvironment()
		print("[LandShip] 🌐 CloudKit Environment: \(environment)")
		logger.notice("🌐 CloudKit Environment: \(environment, privacy: .public)")
		
		// Check account status
		do {
			let status = try await container.accountStatus()
			switch status {
				case .available:
					print("[LandShip] ✅ iCloud account status: available")
					logger.notice("✅ iCloud account status: available")
				case .noAccount:
					print("[LandShip] ❌ iCloud account status: noAccount - User needs to sign in to iCloud")
				case .restricted:
					print("[LandShip] ❌ iCloud account status: restricted - iCloud may be disabled in System Settings")
				case .couldNotDetermine:
					print("[LandShip] ⚠️ iCloud account status: couldNotDetermine")
				case .temporarilyUnavailable:
					print("[LandShip] ⚠️ iCloud account status: temporarilyUnavailable")
				@unknown default:
					print("[LandShip] ❓ iCloud account status: unknown")
			}
		} catch {
			print("[LandShip] ❌ Failed to get iCloud account status: \(error.localizedDescription)")
		}
		
		// Check if we can access the CloudKit database
		let database = container.privateCloudDatabase
		print("[LandShip] ℹ️ Private database accessible: \(database)")
		
		// Platform-specific diagnostics
		#if os(macOS)
		print("[LandShip] 🖥️ Running on macOS")
		print("[LandShip] ℹ️ Check System Settings → Apple ID → iCloud → iCloud Drive is enabled")
		#elseif os(iOS)
		print("[LandShip] 📱 Running on iOS")
		#endif
	}
	
	/// The CloudKit database this build is signed to talk to.
	///
	/// Accurate by construction: CODE_SIGN_ENTITLEMENTS resolves to
	/// LandShip-$(CONFIGURATION).entitlements, so the value of the
	/// `com.apple.developer.icloud-container-environment` entitlement and the
	/// DEBUG compilation condition both derive from the build configuration
	/// and cannot drift apart.
	///
	/// Note: `aps-environment` does NOT select the CloudKit environment -- it
	/// only controls APNs. The entitlement above is what CloudKit reads.
	private static func detectCloudKitEnvironment() -> String {
#if DEBUG
		return "DEVELOPMENT"
#else
		return "PRODUCTION"
#endif
	}
	
	var body: some Scene {
		WindowGroup {
			RootStartupView(modelContainer: modelContainer, isLocalOnly: isLocalOnly, startupError: startupError)
				.environment(\.entitlements, EntitlementStore.shared)
				.preferredColorScheme(appearanceMode.colorScheme)
		}
#if os(macOS)
		.windowToolbarStyle(.unifiedCompact(showsTitle: false))
#endif
#if os(macOS)
		Window("\(AppInfo.displayName) Help", id: "help") {
			HelpView()
				.frame(minWidth: 600, minHeight: 500)
				.windowFrameAutosave("HelpWindow")
				.environment(\.entitlements, EntitlementStore.shared)
				.preferredColorScheme(appearanceMode.colorScheme)
		}
		.commands {
			HelpCommands()
			StoreCommands()
			DebugCommands()
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

private struct StoreCommands: Commands {
	var body: some Commands {
		// Commands can't present sheets themselves — writing to the shared
		// store's paywallContext and letting ContentView's .sheet(item:) react
		// is why EntitlementStore.shared exists.
		CommandGroup(after: .appInfo) {
			Button("Unlock Full Version…") {
				EntitlementStore.shared.paywallContext = .menu
			}
			Button("Restore Purchases") {
				Task { _ = await EntitlementStore.shared.restorePurchases() }
			}
			Divider()
		}
	}
}

private struct DebugCommands: Commands {
	// Mirrors the AppTitleView badge so the menu also signals an unread
	// CloudKit failure — the sidebar title isn't always visible on macOS.
	@AppStorage(StorageKey.hasUnreadCloudKitFailure) private var hasUnreadCloudKitFailure = false

	var body: some Commands {
		// The .principal toolbar long-press that opens Debug Tools on iOS doesn't
		// reliably register on macOS, so this menu item is the macOS entry point.
		CommandGroup(after: .appInfo) {
			Button(hasUnreadCloudKitFailure ? "Debug Tools… ⚠️ Sync Failure" : "Debug Tools…") {
				NotificationCenter.default.post(name: .openDebugToolsRequested, object: nil)
			}
			.keyboardShortcut("d", modifiers: [.command, .shift, .option])
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
		
		print("[LandShip] Attempting to create CloudKit-backed ModelContainer...")
		logger.notice("Attempting to create CloudKit-backed ModelContainer...")
		
		// Try creating the CloudKit container first.
		do {
			let cloud = try ModelContainer(for: schema, configurations: cloudConfig)
			print("[LandShip] ✅ Successfully created CloudKit-backed container")
			logger.notice("✅ Successfully created CloudKit-backed container")
			print("[LandShip] 🔄 CloudKit sync monitoring will start after initialization")
			
			return .cloud(cloud)
		} catch {
			print("[LandShip] ⚠️ Failed to create CloudKit container: \(error.localizedDescription)")
			#if os(macOS)
			print("[LandShip] 💡 macOS Troubleshooting:")
			print("   1. Check System Settings → Apple ID → iCloud → iCloud Drive is ON")
			print("   2. Ensure you're signed into the same Apple ID as iOS devices")
			print("   3. Try: Quit app → Open Console.app → Filter for 'CloudKit' → Relaunch app")
			#endif
		}
		
		print("[LandShip] Falling back to local-only store...")
		
		// If CloudKit fails (no account, network, or configuration issues),
		// fall back to a local-only store so the app remains usable.
		let localConfig = ModelConfiguration(schema: schema)
		do {
			let local = try ModelContainer(for: schema, configurations: localConfig)
			print("[LandShip] ✅ Created local-only container (sync unavailable)")
			return .local(local)
		} catch {
			print("[LandShip] ❌ Failed to create local container: \(error.localizedDescription)")
		}
		
		// If both attempts failed, return the error
		return .failure(NSError(
			domain: "LandShipApp",
			code: -1,
			userInfo: [NSLocalizedDescriptionKey: "Failed to create any ModelContainer. Please check app permissions and try again."]
		))
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
#if os(iOS)
				Button {
					if let url = URL(string: UIApplication.openSettingsURLString) {
						UIApplication.shared.open(url)
					}
				} label: {
					Text("Check Settings")
						.font(.caption.weight(.semibold))
				}
				.buttonStyle(.plain)
#endif
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

/// Shown when the CloudKit-backed store thinks it's working but repeatedly fails to
/// actually export or import — the case a LocalOnlyBanner never catches, since the
/// container did initialize fine. Only appears after a few consecutive failures (see
/// RootStartupView) so a single transient network blip doesn't alarm anyone; a
/// sustained failure (like the one that prompted this) does need to reach the user,
/// since their changes may not be reaching iCloud at all.
private struct SyncFailureBanner: View {
	@AppStorage(StorageKey.cloudKitLastFailureSummary) private var lastFailureSummary: String = ""
	@State private var visible = true

	private static let supportAddress = "info@aeronauticaltrax.com"

	private var supportMailURL: URL? {
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = Self.supportAddress
		components.queryItems = [
			URLQueryItem(name: "subject", value: "\(AppInfo.displayName) — iCloud sync isn't working"),
			URLQueryItem(name: "body", value: "iCloud sync has failed repeatedly on this device.\n\nMost recent error:\n\(lastFailureSummary)")
		]
		return components.url
	}

	var body: some View {
		if visible {
			HStack(alignment: .top, spacing: 8) {
				Image(systemName: "exclamationmark.icloud").imageScale(.medium).foregroundStyle(.orange)
				VStack(alignment: .leading, spacing: 2) {
					Text("iCloud sync isn't working on this device")
						.font(.callout.weight(.semibold))
					Text("Your changes are saved here but may not be backed up to iCloud. Try quitting and reopening the app; if this continues, contact support.")
						.font(.caption)
						.foregroundStyle(.secondary)
					if let supportMailURL {
						Link("Contact Support", destination: supportMailURL)
							.font(.caption.weight(.semibold))
					}
				}
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

	private static let supportAddress = "info@aeronauticaltrax.com"

	private var supportMailURL: URL? {
		let subject = "\(AppInfo.displayName) couldn't start"
		let body = "The app failed to initialize its data store with this error:\n\n\(error?.localizedDescription ?? "(no error details)")"
		var components = URLComponents()
		components.scheme = "mailto"
		components.path = Self.supportAddress
		components.queryItems = [
			URLQueryItem(name: "subject", value: subject),
			URLQueryItem(name: "body", value: body)
		]
		return components.url
	}

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
			if let supportMailURL {
				Link("Contact Support", destination: supportMailURL)
					.padding(.top, 4)
			}
#if os(macOS)
			Button("Quit") {
				NSApp.terminate(nil)
			}
#endif
		}
		.padding()
	}
}

private struct RootStartupView: View {
	let modelContainer: ModelContainer?
	let isLocalOnly: Bool
	let startupError: Error?
	@State private var showChangelog = false
	@Environment(\.entitlements) private var entitlements
	@AppStorage(StorageKey.cloudKitConsecutiveFailures) private var consecutiveCloudKitFailures = 0

	// Consecutive real failures required before SyncFailureBanner appears — high enough
	// that one dropped network request on launch doesn't alarm anyone, low enough that
	// the sustained failure from a broken post-update sync (the case this was built for)
	// still surfaces on the very next launch or two.
	private static let syncFailureBannerThreshold = 2

	private let lastShownKey = "LastShownChangelogVersion"

	var body: some View {
		Group {
			if let container = modelContainer {
				ContentView()
					.modelContainer(container)
					.overlay(alignment: .top) {
						if isLocalOnly {
							LocalOnlyBanner()
								.transition(.move(edge: .top).combined(with: .opacity))
						} else if consecutiveCloudKitFailures >= Self.syncFailureBannerThreshold {
							SyncFailureBanner()
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
		.onAppear { evaluateChangelogPresentation() }
		.task {
			await entitlements.start()
			if let modelContainer {
				entitlements.evaluateOverCapNet(in: modelContainer.mainContext)
				// The heartbeat only exists to provoke an export; piling it onto a
				// container CloudKit is already throttling would make that worse.
				if !isLocalOnly && !CloudKitSyncState.shared.isThrottled {
					SyncHeartbeatService.ping(in: modelContainer.mainContext)
				}
			}
		}
		.sheet(isPresented: $showChangelog) {
			ChangelogSheet { markChangelogShown() }
#if os(iOS)
			.presentationDetents([.large])
#endif
		}
	}

	private func evaluateChangelogPresentation() {
		let currentVersion = String(AppInfo.version)
		let lastShown = UserDefaults.standard.string(forKey: lastShownKey)
		if lastShown != currentVersion {
			// Defer to next runloop to avoid presenting during view init
			DispatchQueue.main.async {
				showChangelog = true
			}
		}
	}

	private func markChangelogShown() {
		let currentVersion = String(AppInfo.version)
		UserDefaults.standard.set(currentVersion, forKey: lastShownKey)
		showChangelog = false
	}
}

// MARK: - Sync Heartbeat

/// Touches the hidden SyncHeartbeat singleton once per launch, purely to generate a
/// CloudKit export attempt even if the user hasn't entered any real data. Without this,
/// a broken sync pipeline on a fresh install or right after an update can sit undetected
/// until someone enters real records and only then discovers they're stranded locally.
/// The resulting export is picked up by the same CloudKitSyncMonitor as any other save.
enum SyncHeartbeatService {
	static func ping(in context: ModelContext) {
		let descriptor = FetchDescriptor<SyncHeartbeat>(predicate: #Predicate { $0.id == "primary" })
		do {
			let heartbeat = try context.fetch(descriptor).first ?? {
				let new = SyncHeartbeat()
				context.insert(new)
				return new
			}()
			heartbeat.lastPingAt = Date()
			heartbeat.pingCount += 1
			try context.save()
			logger.info("💓 Sync heartbeat saved (ping #\(heartbeat.pingCount, privacy: .public))")
		} catch {
			logger.error("💓 Sync heartbeat failed to save: \(error.localizedDescription, privacy: .public)")
		}
	}
}

// MARK: - CloudKit Sync Monitor

final class CloudKitSyncMonitor: @unchecked Sendable {
	private var observers: [NSObjectProtocol] = []
	private let container: ModelContainer
	private var lastSyncDate: Date?
	private var changeCount = 0
	private var heartbeatTimer: Timer?
	private var pollTimer: Timer?
	private let startTime = Date()
	
	init(container: ModelContainer) {
		self.container = container
		setupObservers()
		startHeartbeat()
		// startPolling() is deliberately not called: saving on a timer gets the
		// container throttled by CloudKit and amplifies whatever is already failing.
		print("[LandShip] 🔍 CloudKitSyncMonitor initialized")
		logger.notice("🔍 CloudKitSyncMonitor initialized")
	}
	
	deinit {
		heartbeatTimer?.invalidate()
		pollTimer?.invalidate()
		observers.forEach { NotificationCenter.default.removeObserver($0) }
		print("[LandShip] 🔍 CloudKitSyncMonitor deinitialized")
	}
	
	private func startHeartbeat() {
		// Log heartbeat every 2 minutes to confirm monitoring is active
		heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			let uptime = Date().timeIntervalSince(self.startTime)
			let minutes = Int(uptime / 60)
			let message = "💓 Sync monitor heartbeat - Uptime: \(minutes)m, Changes: \(self.changeCount), Last sync: \(self.lastSyncDate?.description ?? "never")"
			print("[LandShip] \(message)")
			logger.notice("\(message, privacy: .public)")
		}
	}
	
	private func startPolling() {
		// Poll for changes every 30 seconds as a fallback if push notifications fail
		// This is a workaround for APNs delivery issues on macOS
		pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			
			// Trigger a fetch by accessing the model context
			// This forces SwiftData to check CloudKit for changes
			let container = self.container
			Task { @MainActor in
				do {
					let context = container.mainContext
					// Force a save which triggers CloudKit sync check
					try context.save()
					print("[LandShip] 🔄 Polling: Forced sync check")
					logger.info("🔄 Polling: Forced sync check")
				} catch {
					print("[LandShip] ⚠️ Polling error: \(error.localizedDescription)")
				}
			}
		}
		
		print("[LandShip] 🔄 Started polling every 30 seconds (APNs fallback)")
		logger.notice("🔄 Started polling every 30 seconds as APNs fallback")
	}
	
	private func setupObservers() {
		// Monitor for remote changes from CloudKit
		let remoteChangeObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name.NSPersistentStoreRemoteChange,
			object: nil,
			queue: .main
		) { [weak self] notification in
			self?.handleRemoteChange(notification)
		}
		observers.append(remoteChangeObserver)
		
		// Monitor for local changes being saved
		let contextDidSaveObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name.NSManagedObjectContextDidSave,
			object: nil,
			queue: .main
		) { [weak self] notification in
			self?.handleContextSave(notification)
		}
		observers.append(contextDidSaveObserver)
		
		// Monitor CloudKit setup/import/export events. Use the framework's own
		// Notification.Name -- the hand-written string does not match it.
		let eventObserver = NotificationCenter.default.addObserver(
			forName: NSPersistentCloudKitContainer.eventChangedNotification,
			object: nil,
			queue: .main
		) { [weak self] notification in
			self?.handleCloudKitEvent(notification)
		}
		observers.append(eventObserver)
		
		print("[LandShip] 🔍 Registered observers for:")
		print("  - NSPersistentStoreRemoteChange (remote sync)")
		print("  - NSManagedObjectContextDidSave (local changes)")
		print("  - CloudKit container events")
		logger.notice("🔍 Registered 3 notification observers for CloudKit sync monitoring")
	}
	
	private func handleRemoteChange(_ notification: Notification) {
		changeCount += 1
		lastSyncDate = Date()
		
		let message = "🔄 REMOTE CHANGE #\(changeCount) detected at \(formatTime(lastSyncDate!))"
		print("[LandShip] \(message)")
		logger.notice("\(message, privacy: .public)")
		
		if let userInfo = notification.userInfo {
			print("[LandShip]    UserInfo keys: \(userInfo.keys.map { String(describing: $0) })")
		}
		
		// Log which store changed
		if let stores = notification.object as? NSPersistentStore {
			print("[LandShip]    Store: \(stores)")
		}
	}
	
	private func handleContextSave(_ notification: Notification) {
		// Only log if there are actual changes
		guard let userInfo = notification.userInfo else { return }
		
		let hasChanges = [
			userInfo[NSInsertedObjectsKey],
			userInfo[NSUpdatedObjectsKey],
			userInfo[NSDeletedObjectsKey]
		].contains(where: { ($0 as? Set<NSManagedObject>)?.isEmpty == false })
		
		guard hasChanges else { return }
		
		let message = "💾 LOCAL SAVE detected at \(formatTime(Date()))"
		print("[LandShip] \(message)")
		logger.notice("\(message, privacy: .public)")
		
		if let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !inserted.isEmpty {
			print("[LandShip]    Inserted: \(inserted.count) objects")
			logger.notice("   Inserted: \(inserted.count) objects")
		}
		if let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updated.isEmpty {
			print("[LandShip]    Updated: \(updated.count) objects")
			logger.notice("   Updated: \(updated.count) objects")
		}
		if let deleted = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deleted.isEmpty {
			print("[LandShip]    Deleted: \(deleted.count) objects")
			logger.notice("   Deleted: \(deleted.count) objects")
		}
	}
	
	private func handleCloudKitEvent(_ notification: Notification) {
		// The typed event is stored under the framework's own userInfo key.
		// Reading arbitrary string keys such as "type" or "error" always yields nil.
		guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
				as? NSPersistentCloudKitContainer.Event else {
			logger.error("☁️ CloudKit event posted with no decodable Event payload")
			return
		}

		let kind = Self.describe(event.type)
		let operation = CloudKitSyncState.Operation(event.type)

		// Each operation posts twice: once on start (endDate == nil), once on
		// completion. Only the completion carries succeeded/error.
		guard let endDate = event.endDate else {
			logger.info("☁️ CloudKit \(kind, privacy: .public) started")
			if let operation {
				// Safe: this handler only runs from the eventObserver closure, which
				// NotificationCenter delivers on queue: .main.
				MainActor.assumeIsolated { CloudKitSyncState.shared.begin(operation) }
			}
			return
		}

		guard let error = event.error else {
			let message = "✅ CloudKit \(kind) succeeded at \(formatTime(Date()))"
			print("[LandShip] \(message)")
			logger.notice("\(message, privacy: .public)")
			if let operation {
				MainActor.assumeIsolated {
					CloudKitSyncState.shared.succeeded(operation, at: endDate)
					SyncActivityLog.shared.record(.success, operation: operation.rawValue, message: "Completed", at: endDate)
				}
			}
			// Any real success clears the streak that drives SyncFailureBanner — the
			// banner should only reflect the *current*, sustained state of sync, not
			// a blip that has since recovered.
			UserDefaults.standard.set(0, forKey: StorageKey.cloudKitConsecutiveFailures)
			return
		}

		if let operation {
			MainActor.assumeIsolated { CloudKitSyncState.shared.failed(operation, error: error) }
		}

		// Rate limiting is CloudKit asking us to slow down, not a broken pipeline.
		// NSPersistentCloudKitContainer reschedules the work itself after the wait, so
		// it is recorded in CloudKitSyncState (which pauses our own writes) but kept out
		// of SyncFailureBanner's failure streak.
		if let wait = CloudKitSyncState.retryAfter(for: error) {
			logger.notice("⏳ CloudKit \(kind, privacy: .public) throttled — backing off \(Int(wait), privacy: .public)s")
			MainActor.assumeIsolated {
				SyncActivityLog.shared.record(.throttled, operation: operation?.rawValue ?? kind, message: "Paused by iCloud; retrying in about \(Int(wait))s", at: endDate)
			}
			return
		}

		// CloudKit's own internal Protected Cloud Storage key rotation surfaces as a
		// BAD_REQUEST on record type "_pcs_data" in the Dashboard's telemetry. It is not
		// one of our CD_* record types, NSPersistentCloudKitContainer retries it internally,
		// and Apple DTS's guidance is that it's only a concern paired with QUOTA_EXCEEDED.
		// Logging it as a failure buries real signal, so it gets a quieter log line instead.
		if Self.isBenignPCSNoise(error) {
			logger.info("ℹ️ CloudKit \(kind, privacy: .public) reported benign PCS key-rotation noise (_pcs_data BAD_REQUEST) — no action needed")
			return
		}

		// No network, no iCloud sign-in, or a momentarily unreachable account are expected
		// conditions, not evidence of a broken sync pipeline — every device that opens the
		// app in a dead zone would otherwise trip SyncFailureBanner. CloudKit already
		// retries these on its own once connectivity/account state recovers.
		if let reason = Self.benignConnectivityReason(error) {
			logger.info("ℹ️ CloudKit \(kind, privacy: .public) deferred (\(reason, privacy: .public)) — will retry automatically")
			MainActor.assumeIsolated {
				SyncActivityLog.shared.record(.deferred, operation: operation?.rawValue ?? kind, message: "Deferred: \(reason)", at: endDate)
			}
			return
		}

		let message = "❌ CloudKit \(kind) FAILED at \(formatTime(Date())): \(error.localizedDescription)"
		print("[LandShip] \(message)")
		logger.error("\(message, privacy: .public)")
		MainActor.assumeIsolated {
			SyncActivityLog.shared.record(.failure, operation: operation?.rawValue ?? kind, message: error.localizedDescription, at: endDate)
		}

		let detail = Self.detailLines(for: error)
		for line in detail {
			logger.error("\(line, privacy: .public)")
		}
		Self.persistFailure(phase: kind, error: error, detailLines: detail)
	}

	/// True only if every leaf of this error's tree is CloudKit's own internal
	/// PCS key-rotation record ("_pcs_data") failing with badRequest — never true
	/// if the tree contains any real record type, even mixed with PCS noise.
	private static func isBenignPCSNoise(_ error: Error) -> Bool {
		guard let ckError = error as? CKError,
			  ckError.code == .partialFailure,
			  let byItemID = ckError.partialErrorsByItemID,
			  !byItemID.isEmpty else { return false }

		return byItemID.allSatisfy { itemID, subError in
			(itemID as? CKRecord.ID)?.recordName.hasPrefix("_pcs_data") == true
				&& (subError as? CKError)?.code == .invalidArguments
		}
	}

	/// Non-nil (with a human-readable reason) if this error is CloudKit reporting that
	/// there's currently no way to reach the server — no network, no iCloud account
	/// signed in, or the account is momentarily unavailable — rather than the server or
	/// this app having done anything wrong.
	private static func benignConnectivityReason(_ error: Error) -> String? {
		guard let ckError = error as? CKError else { return nil }

		func reason(for code: CKError.Code) -> String? {
			switch code {
				case .networkUnavailable: return "no network connection"
				case .networkFailure: return "network request failed"
				case .notAuthenticated: return "not signed into iCloud"
				case .accountTemporarilyUnavailable: return "iCloud account temporarily unavailable"
				default: return nil
			}
		}

		if let direct = reason(for: ckError.code) { return direct }

		// A partialFailure can itself be nothing but connectivity errors per item —
		// still not worth alarming anyone about.
		if ckError.code == .partialFailure,
		   let partial = ckError.partialErrorsByItemID, !partial.isEmpty {
			let reasons = partial.values.compactMap { ($0 as? CKError).flatMap { reason(for: $0.code) } }
			if reasons.count == partial.count { return reasons.first }
		}

		return nil
	}

	/// Appends real (non-PCS-noise) sync failures — with full per-item/per-zone detail,
	/// not just the top-level localizedDescription — to a plain-text log in Application
	/// Support, so a TestFlight tester who reports "it's not syncing" can locate and
	/// share the file. Also mirrored into InAppLogger so the same detail shows up in
	/// the long-press Debug Tools sheet, without needing Console.app on their device.
	private static func persistFailure(phase: String, error: Error, detailLines: [String]) {
		let nsError = error as NSError
		let header = "\(Date()) [\(phase)] \(nsError.domain) code=\(nsError.code): \(nsError.localizedDescription)"
		let fullText = ([header] + detailLines).joined(separator: "\n   ")

		// Safe: this is only ever reached from the eventObserver closure, which
		// NotificationCenter delivers on queue: .main.
		MainActor.assumeIsolated {
			InAppLogger.shared.log("❌ CloudKit \(phase) FAILED:\n   " + detailLines.joined(separator: "\n   "))
		}
		UserDefaults.standard.set(true, forKey: StorageKey.hasUnreadCloudKitFailure)

		// Drives SyncFailureBanner: a running streak of consecutive real failures
		// (reset to 0 on any real success above) plus a short summary for its
		// "Contact Support" mail body.
		let failureCount = UserDefaults.standard.integer(forKey: StorageKey.cloudKitConsecutiveFailures) + 1
		UserDefaults.standard.set(failureCount, forKey: StorageKey.cloudKitConsecutiveFailures)
		UserDefaults.standard.set(header, forKey: StorageKey.cloudKitLastFailureSummary)

		guard let dir = try? FileManager.default.url(
			for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
		), let data = (fullText + "\n").data(using: .utf8) else { return }

		let fileURL = dir.appendingPathComponent("cloudkit-failures.log")
		if let handle = try? FileHandle(forWritingTo: fileURL) {
			handle.seekToEndOfFile()
			handle.write(data)
			try? handle.close()
		} else {
			try? data.write(to: fileURL)
		}
	}

	/// Unpacks a CloudKit error far enough to name the failing record type, which is
	/// what the CloudKit Console hides behind "BAD_REQUEST" or a bare "partialFailure".
	/// Per-item failures (the common case for record saves) are named explicitly; for
	/// anything else — zone-level partial failures, for instance, which CloudKit doesn't
	/// expose through partialErrorsByItemID — the raw userInfo is dumped instead of
	/// silently producing no detail, since guessing every possible key up front is a
	/// losing game.
	private static func detailLines(for error: Error, indent: String = "   ") -> [String] {
		var lines: [String] = []
		let nsError = error as NSError
		lines.append("\(indent)domain: \(nsError.domain) code: \(nsError.code)")

		if let ckError = error as? CKError {
			lines.append("\(indent)CKError.Code: \(String(describing: ckError.code))")

			if let retry = ckError.retryAfterSeconds {
				lines.append("\(indent)retryAfter: \(retry)s")
			}

			if let partial = ckError.partialErrorsByItemID, !partial.isEmpty {
				lines.append("\(indent)partial item failures: \(partial.count)")
				for (itemID, itemError) in partial {
					let name = (itemID as? CKRecord.ID)?.recordName ?? String(describing: itemID)
					lines.append("\(indent)- item: \(name)")
					lines.append(contentsOf: detailLines(for: itemError, indent: indent + "   "))
				}
			} else if ckError.code == .partialFailure {
				// No per-item detail — dump the raw userInfo so the next occurrence
				// doesn't produce another dead-end log line.
				lines.append("\(indent)partialFailure with no per-item detail; raw userInfo:")
				for (key, value) in nsError.userInfo {
					lines.append("\(indent)- \(key): \(value)")
				}
			}

			if let serverRecord = ckError.serverRecord {
				lines.append("\(indent)serverRecord type: \(serverRecord.recordType)")
			}
		} else {
			lines.append("\(indent)userInfo: \(nsError.userInfo)")
		}

		if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
			lines.append("\(indent)underlying:")
			lines.append(contentsOf: detailLines(for: underlying, indent: indent + "   "))
		}

		return lines
	}

	private static func describe(_ type: NSPersistentCloudKitContainer.EventType) -> String {
		switch type {
			case .setup: return "SETUP"
			case .import: return "IMPORT"
			case .export: return "EXPORT"
			@unknown default: return "UNKNOWN"
		}
	}

	
	private func formatTime(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.timeStyle = .medium
		return formatter.string(from: date)
	}
}


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

#if os(macOS)
import AppKit
#endif

// Unified logging for CloudKit diagnostics
fileprivate let logger = Logger(subsystem: "com.aeronauticaltrax.LandShip", category: "CloudKitSync")

@main
struct LandShipApp: App {
	
	// MARK: - Startup Result
	
	private let modelContainer: ModelContainer?
	private let startupError: Error?
	private let isLocalOnly: Bool
	
	// Sync monitoring (static to persist for app lifetime)
	private static var syncMonitor: CloudKitSyncMonitor?
	
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
			TripLog2.self,
			Additions.self,
			Subscriptions.self,
			ProjectList.self,
			CheckList.self,
			CheckListItem.self,
			VehicleWarranty.self,
			VehicleSerialItem.self,
			VehicleScaleTicket.self
		])
		
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

private struct RootStartupView: View {
	let modelContainer: ModelContainer?
	let isLocalOnly: Bool
	let startupError: Error?
	@State private var showChangelog = false

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

		// Each operation posts twice: once on start (endDate == nil), once on
		// completion. Only the completion carries succeeded/error.
		guard event.endDate != nil else {
			logger.info("☁️ CloudKit \(kind, privacy: .public) started")
			return
		}

		guard let error = event.error else {
			let message = "✅ CloudKit \(kind) succeeded at \(formatTime(Date()))"
			print("[LandShip] \(message)")
			logger.notice("\(message, privacy: .public)")
			return
		}

		let message = "❌ CloudKit \(kind) FAILED at \(formatTime(Date())): \(error.localizedDescription)"
		print("[LandShip] \(message)")
		logger.error("\(message, privacy: .public)")
		Self.logDetail(for: error)
	}

	/// Unpacks a CloudKit error far enough to name the failing record type and
	/// record ID, which is what the CloudKit Console hides behind "BAD_REQUEST".
	private static func logDetail(for error: Error, indent: String = "   ") {
		let nsError = error as NSError
		logger.error("\(indent, privacy: .public)domain: \(nsError.domain, privacy: .public) code: \(nsError.code, privacy: .public)")

		if let ckError = error as? CKError {
			logger.error("\(indent, privacy: .public)CKError.Code: \(String(describing: ckError.code), privacy: .public)")

			if let retry = ckError.retryAfterSeconds {
				logger.error("\(indent, privacy: .public)retryAfter: \(retry, privacy: .public)s")
			}

			// Per-item errors name the exact CKRecord.ID the server rejected.
			if let partial = ckError.partialErrorsByItemID {
				logger.error("\(indent, privacy: .public)partial failures: \(partial.count, privacy: .public)")
				for (itemID, itemError) in partial {
					logger.error("\(indent, privacy: .public)- item: \(String(describing: itemID), privacy: .public)")
					logDetail(for: itemError, indent: indent + "   ")
				}
			}

			if let serverRecord = ckError.serverRecord {
				logger.error("\(indent, privacy: .public)serverRecord type: \(serverRecord.recordType, privacy: .public)")
			}
		}

		if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
			logger.error("\(indent, privacy: .public)underlying:")
			logDetail(for: underlying, indent: indent + "   ")
		}
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


//
//  EntitlementStore.swift
//  LandShip
//

import Foundation
import StoreKit
import SwiftData
import SwiftUI

/// The single non-consumable unlock. Immutable once created in App Store
/// Connect — do not change this string after shipping, per vertical.
enum Entitlement {
	static var productID: String { Vertical.current.storeProductID }

	/// Non-isolated, allocation-free read of the last known good entitlement,
	/// for callers with no environment access (PDFReportFile, PrintablePDFView,
	/// AutoBackupService.isDue()). Returns false only when no EntitlementStore
	/// check has ever completed (the very first cold launch); once a check
	/// succeeds, this mirrors that result even fully offline afterward.
	static var cachedIsFullVersion: Bool {
		let d = UserDefaults.standard
		guard d.object(forKey: StorageKey.fullVersionUnlocked) != nil else { return false }
		return d.bool(forKey: StorageKey.fullVersionUnlocked)
	}
}

/// Why `isFullVersion` is currently true. Persisted as a string for
/// diagnostics (Debug Tools, support triage) — never used to gate logic itself.
enum EntitlementSource: String {
	case none
	case purchase
	case priorInstall
	case originalVersion
	case overCap
	case cached
	case testFlight
}

enum RestoreOutcome: Equatable {
	case restored
	case nothingToRestore
	case failed(String)
}

#if DEBUG
enum DebugEntitlementOverride: String, CaseIterable, Identifiable, Hashable {
	case auto, forceTrial, forceFull, forceGrandfathered, forceReceiptFailure
	var id: String { rawValue }
	var label: String {
		switch self {
			case .auto: return "Automatic"
			case .forceTrial: return "Force Trial"
			case .forceFull: return "Force Full Version"
			case .forceGrandfathered: return "Force Grandfathered"
			case .forceReceiptFailure: return "Force Receipt Failure"
		}
	}
}
#endif

/// Owns trial policy and the single purchase entitlement. Views reach this
/// exclusively via `\.entitlements` (see the EnvironmentKey below), never by
/// constructing their own instance — the environment default is a fully
/// unlocked store, so any view that forgets to read the real one fails OPEN
/// rather than wrongly locking someone out.
@Observable
@MainActor
final class EntitlementStore {
	// A static let of a Sendable type is nonisolated by inference even inside a
	// @MainActor class, so non-View callers (PDFReportFile, PrintablePDFView,
	// .commands) can reach `shared` without `await`. assumeIsolated below covers
	// the one-time initializer's call into the actor-isolated init.
	static let shared: EntitlementStore = MainActor.assumeIsolated { EntitlementStore() }
	static let unlockedForPreviews: EntitlementStore = MainActor.assumeIsolated { EntitlementStore(forcing: true) }

	private(set) var isFullVersion: Bool
	private(set) var source: EntitlementSource
	private(set) var purchaseInFlight = false
	private(set) var hasPurchaseEntitlement = false
	var paywallContext: PaywallContext?
	private(set) var usage: [String: Int] = [:]

	private let store: StoreKitService
	private var didStart = false

	var product: StoreKit.Product? { store.products.first }
	/// Genuinely stored (not a computed passthrough to `store.lastError`) so
	/// SwiftUI's Observation tracking actually sees it change — `store` isn't
	/// itself @Observable, so a computed indirection into it wouldn't refresh views.
	private(set) var lastError: Error?

	init() {
		store = StoreKitService(productIDs: [Entitlement.productID])
		let cachedUnlocked = Entitlement.cachedIsFullVersion
		isFullVersion = cachedUnlocked
		source = cachedUnlocked
			? (EntitlementSource(rawValue: UserDefaults.standard.string(forKey: StorageKey.fullVersionSource) ?? "") ?? .cached)
			: .none

		store.onEntitlementsChanged = { [weak self] ids in
			Task { @MainActor in self?.handleEntitlementIDs(ids) }
		}

		// Start listening for Transaction.updates as early as possible — from
		// init(), which (unlike start()) only ever runs once, at app launch,
		// well before any purchase UI can appear. Xcode's StoreKit runtime
		// checker warns if a purchase can happen before this listener is
		// demonstrably running; kicking it off here rather than from start()
		// (which only fires once RootStartupView's .task renders) closes that gap.
		Task { await store.observeTransactionUpdates() }

		// Must run here, in the singleton's init (invoked from LandShipApp.init()),
		// strictly BEFORE ContentView.onAppear sets hasCompletedOnboarding —
		// that ordering is what makes the marker a trustworthy signal.
		capturePriorInstallMarkerIfNeeded()
		if UserDefaults.standard.bool(forKey: StorageKey.priorInstallDetected) {
			grant(.priorInstall)
		}

		// TestFlight testers get the full version without a sandbox purchase.
		// Checked synchronously (receipt-filename heuristic, not AppTransaction)
		// so it's granted before the first frame, same as the prior-install marker.
		if TrialPolicy.isRunningViaTestFlight {
			grant(.testFlight)
		}
	}

	/// Preview-only convenience. Skips all UserDefaults/marker logic.
	private init(forcing full: Bool) {
		store = StoreKitService(productIDs: [])
		isFullVersion = full
		source = full ? .cached : .none
	}

	// MARK: - Lifecycle

	/// Kicks off product loading and the receipt check (the transaction
	/// observer starts earlier, from init()). Safe to call from multiple
	/// scenes (e.g. the macOS Help window) — only the first call does anything.
	func start() async {
		guard !didStart else { return }
		didStart = true

#if DEBUG
		if debugOverride != .auto {
			applyDebugOverride()
			guard debugOverride == .forceReceiptFailure else { return }
		}
#endif

		await store.refresh()
		await evaluateReceipt()
	}

	/// Cheap safety net: if a trial device already holds more records than the
	/// caps allow, treat it as full version. Only trusted on a device that
	/// already had the app before the free transition — otherwise two offline
	/// trial devices merging via CloudKit, or an imported backup, would give
	/// away the unlock for free.
	func evaluateOverCapNet(in context: ModelContext) {
		guard !isFullVersion else { return }
		guard UserDefaults.standard.bool(forKey: StorageKey.priorInstallDetected) else { return }
		for type in TrialCaps.allCapped {
			if let count = try? type.trialFetchCount(in: context), count > type.trialLimit {
				grant(.overCap)
				return
			}
		}
	}

	func refreshUsage(in context: ModelContext) {
		for type in TrialCaps.allCapped {
			usage[type.trialUsageKey] = (try? type.trialFetchCount(in: context)) ?? 0
		}
	}

	// MARK: - Purchase / Restore

	/// Re-attempts loading the product list. Unlike `start()`, this always
	/// runs — `start()`'s `didStart` guard means the paywall's "Retry" button
	/// would otherwise do nothing after the first failed attempt in a session.
	func retryLoadingProduct() async {
		await store.refresh()
		lastError = product == nil ? store.lastError : nil
	}

	func clearLastError() {
		lastError = nil
	}

	func purchase() async {
		guard let product else { return }
		purchaseInFlight = true
		defer { purchaseInFlight = false }
		let success = await store.purchase(product)
		lastError = success ? nil : store.lastError
	}

	func restorePurchases() async -> RestoreOutcome {
		do {
			try await store.restorePurchases()
			return hasPurchaseEntitlement ? .restored : .nothingToRestore
		} catch {
			return .failed(error.localizedDescription)
		}
	}

	// MARK: - Trial cap / export gates

	/// Returns true if `count` new `M` records may be created right now.
	/// On false, presents the paywall via `paywallContext`; callers just `return`.
	@discardableResult
	func requestCreate<M: TrialCapped>(_ type: M.Type, count: Int = 1, in context: ModelContext) -> Bool {
		if isFullVersion { return true }
		let used = (try? M.trialFetchCount(in: context)) ?? 0   // fail OPEN on fetch error
		usage[M.trialUsageKey] = used
		guard used + count > M.trialLimit else { return true }
		paywallContext = .capReached(feature: M.trialDisplayName, used: used, limit: M.trialLimit, requested: count)
		return false
	}

	/// Same shape as `requestCreate`, for non-record-creating gates (PDF export/
	/// print, automatic backup). `context` doubles as the paywall's reason.
	@discardableResult
	func requestExport(_ context: PaywallContext) -> Bool {
		if isFullVersion { return true }
		paywallContext = context
		return false
	}

	// MARK: - Grandfathering

	private func capturePriorInstallMarkerIfNeeded() {
		let d = UserDefaults.standard
		guard d.object(forKey: StorageKey.firstFreeLaunchDate) == nil else { return }
		d.set(Date().timeIntervalSince1970, forKey: StorageKey.firstFreeLaunchDate)

		// This device had the app set up before the free transition ⇒ paid
		// install. A genuinely new user has hasCompletedOnboarding == false and
		// no backup history at this instant.
		let hadPriorInstall = d.bool(forKey: StorageKey.hasCompletedOnboarding)
			|| d.double(forKey: StorageKey.lastBackupDate) > 0
		d.set(hadPriorInstall, forKey: StorageKey.priorInstallDetected)
	}

	private func evaluateReceipt() async {
		do {
			let result = try await AppTransaction.shared
			guard case .verified(let appTransaction) = result else {
				return // Unverified ⇒ do not downgrade. Keep the cache.
			}
			let env = appTransaction.environment
			UserDefaults.standard.set(String(describing: env), forKey: StorageKey.appStoreEnvironment)
			UserDefaults.standard.set(appTransaction.originalAppVersion, forKey: StorageKey.originalAppVersionCached)

			// originalAppVersion is always "1.0" outside production (Xcode,
			// sandbox, TestFlight, App Review) — the comparison is only
			// meaningful in production. Skipping it elsewhere is what lets
			// App Review actually see the paywall.
			guard env == .production else { return }

			if TrialPolicy.isOriginalPurchaser(originalAppVersion: appTransaction.originalAppVersion) {
				grant(.originalVersion)
			}
		} catch {
			// Offline / StoreKit failure ⇒ fail OPEN on the cache, never downgrade.
		}
	}

	private func handleEntitlementIDs(_ ids: Set<String>) {
		hasPurchaseEntitlement = ids.contains(Entitlement.productID)
		if hasPurchaseEntitlement {
			grant(.purchase)
			return
		}
		// No purchase found. Only revoke if no other grant is in force —
		// this is the ONLY branch that may ever write `false`.
		guard !UserDefaults.standard.bool(forKey: StorageKey.priorInstallDetected),
		      source != .originalVersion, source != .overCap, source != .testFlight else { return }
		revoke()
	}

	private func grant(_ newSource: EntitlementSource) {
		isFullVersion = true
		source = newSource
		let d = UserDefaults.standard
		d.set(true, forKey: StorageKey.fullVersionUnlocked)
		d.set(newSource.rawValue, forKey: StorageKey.fullVersionSource)
		d.set(Date().timeIntervalSince1970, forKey: StorageKey.entitlementCheckedAt)
	}

	private func revoke() {
		isFullVersion = false
		source = .none
		let d = UserDefaults.standard
		d.set(false, forKey: StorageKey.fullVersionUnlocked)
		d.removeObject(forKey: StorageKey.fullVersionSource)
	}

	// MARK: - Debug overrides

#if DEBUG
	var debugOverride: DebugEntitlementOverride {
		get { DebugEntitlementOverride(rawValue: UserDefaults.standard.string(forKey: StorageKey.debugForcedEntitlement) ?? "") ?? .auto }
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: StorageKey.debugForcedEntitlement)
			applyDebugOverride()
		}
	}

	/// Clears every trial/entitlement key. Sticky grants otherwise make
	/// re-testing the trial path nearly impossible.
	func resetTrialState() {
		let d = UserDefaults.standard
		for key in [
			StorageKey.fullVersionUnlocked, StorageKey.fullVersionSource, StorageKey.entitlementCheckedAt,
			StorageKey.originalAppVersionCached, StorageKey.appStoreEnvironment,
			StorageKey.firstFreeLaunchDate, StorageKey.priorInstallDetected, StorageKey.debugForcedEntitlement
		] {
			d.removeObject(forKey: key)
		}
		isFullVersion = false
		source = .none
		hasPurchaseEntitlement = false
		usage = [:]
		didStart = false
	}

	private func applyDebugOverride() {
		switch debugOverride {
			case .auto: return
			case .forceTrial: revoke()
			case .forceFull: grant(.purchase)
			case .forceGrandfathered: grant(.originalVersion)
			case .forceReceiptFailure: break // handled by evaluateReceipt's early return
		}
	}
#endif
}

// MARK: - Environment

private struct EntitlementStoreKey: EnvironmentKey {
	// Environment lookups always occur on the main actor.
	static var defaultValue: EntitlementStore { MainActor.assumeIsolated { .unlockedForPreviews } }
}

extension EnvironmentValues {
	var entitlements: EntitlementStore {
		get { self[EntitlementStoreKey.self] }
		set { self[EntitlementStoreKey.self] = newValue }
	}
}

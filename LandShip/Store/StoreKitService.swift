//
//  StoreKitService.swift
//  LandShip
//

import Foundation
import StoreKit

/// Thin StoreKit 2 wrapper: loading products, purchasing, restoring, and
/// observing entitlement changes. Holds no trial/business policy — that lives
/// in EntitlementStore, which owns one of these.
@MainActor
final class StoreKitService {
	private(set) var products: [StoreKit.Product] = []
	var lastError: Error?

	let productIDs: Set<String>

	/// Fired whenever the verified current-entitlements set changes, from a
	/// purchase, a restore, or an external Transaction.updates event.
	var onEntitlementsChanged: (Set<String>) -> Void = { _ in }

	init(productIDs: Set<String>) {
		self.productIDs = productIDs
	}

	// MARK: - Public API

	func refresh() async {
		do {
			products = try await StoreKit.Product.products(for: Array(productIDs))
			let ids = try await currentEntitlementIDs()
			onEntitlementsChanged(ids)
		} catch {
			lastError = error
		}
	}

	func purchase(_ product: StoreKit.Product) async -> Bool {
		do {
			let result = try await product.purchase()
			switch result {
			case .success(let verification):
				let transaction = try checkVerified(verification)
				let ids = try await currentEntitlementIDs()
				onEntitlementsChanged(ids)
				await transaction.finish()
				return true
			case .userCancelled:
				return false
			case .pending:
				return false
			@unknown default:
				return false
			}
		} catch {
			lastError = error
			return false
		}
	}

	func restorePurchases() async throws {
		try await AppStore.sync()
		let ids = try await currentEntitlementIDs()
		onEntitlementsChanged(ids)
	}

	func observeTransactionUpdates() async {
		for await result in StoreKit.Transaction.updates {
			do {
				let transaction = try checkVerified(result)
				let ids = try await currentEntitlementIDs()
				onEntitlementsChanged(ids)
				await transaction.finish()
			} catch {
				lastError = error
			}
		}
	}

	// MARK: - Private

	private func currentEntitlementIDs() async throws -> Set<String> {
		var ids = Set<String>()
		for await result in StoreKit.Transaction.currentEntitlements {
			if case .verified(let transaction) = result, transaction.revocationDate == nil {
				ids.insert(transaction.productID)
			}
		}
		return ids
	}

	private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
		switch result {
		case .unverified(_, let error):
			throw error
		case .verified(let safe):
			return safe
		}
	}
}

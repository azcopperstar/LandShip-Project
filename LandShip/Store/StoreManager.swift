//
//  StoreManager.swift
//  LandShip
//
//  Created by JP on 12/15/25.
//


import Foundation
import StoreKit
import SwiftUI

@MainActor
final class StoreManager: ObservableObject {
    // MARK: - Published state
    @Published private(set) var products: [StoreKit.Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var lastError: Error?

    let productIDs: Set<String>

    init(productIDs: Set<String>) {
        self.productIDs = productIDs
        Task { await refresh() }
        Task { await observeTransactionUpdates() }
    }

    // MARK: - Public API

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await StoreKit.Product.products(for: Array(productIDs))
            try await updatePurchasedEntitlements()
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
                await updatePurchasedIDs(from: transaction)
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

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            try await updatePurchasedEntitlements()
        } catch {
            lastError = error
        }
    }

    func isPurchased(_ id: String) -> Bool {
        purchasedProductIDs.contains(id)
    }

    // MARK: - Transactions

    private func observeTransactionUpdates() async {
        for await result in StoreKit.Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await updatePurchasedIDs(from: transaction)
                await transaction.finish()
            } catch {
                await MainActor.run { self.lastError = error }
            }
        }
    }

    private func updatePurchasedIDs(from transaction: StoreKit.Transaction) async {
        await MainActor.run {
            if transaction.revocationDate == nil {
                self.purchasedProductIDs.insert(transaction.productID)
            } else {
                self.purchasedProductIDs.remove(transaction.productID)
            }
        }
    }

    private func updatePurchasedEntitlements() async throws {
        var ids = Set<String>()
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        await MainActor.run { self.purchasedProductIDs = ids }
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

// MARK: - Entitlements convenience

struct Entitlements {
    // Replace with your real identifiers from App Store Connect
    static let proFeatures = "com.aeronauticaltrax.landship.pro"
    static let fuelAnalytics = "com.aeronauticaltrax.landship.fuel.analytics"
    static let tripExport = "com.aeronauticaltrax.landship.trip.export"
}

extension StoreManager {
    static var defaultProductIDs: Set<String> {
        [Entitlements.proFeatures, Entitlements.fuelAnalytics, Entitlements.tripExport]
    }
}


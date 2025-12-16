//
//  PurchasesView.swift
//  LandShip
//
//  Created by JP on 12/15/25.
//


import SwiftUI
import StoreKit

struct PurchasesView: View {
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        NavigationStack {
            List {
                Section("Upgrades") {
                    ForEach(store.products, id: \.id) { product in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.headline)
                                Text(product.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { Task { _ = await store.purchase(product) } }) {
                                Text(product.displayPrice)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if !store.purchasedProductIDs.isEmpty {
                    Section("Purchased") {
                        ForEach(Array(store.purchasedProductIDs).sorted(), id: \.self) { id in
                            Text(id)
                        }
                    }
                }
            }
            .overlay {
                if store.isLoading { ProgressView().controlSize(.large) }
            }
            .navigationTitle("Upgrades")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Restore") { Task { await store.restorePurchases() } } } }
            .task { await store.refresh() }
            .alert("Store Error", isPresented: .constant(store.lastError != nil), actions: {
                Button("OK", role: .cancel) { store.lastError = nil }
            }, message: {
                Text(store.lastError?.localizedDescription ?? "Unknown error")
            })
        }
    }
}

#Preview {
    PurchasesView()
        .environmentObject(StoreManager(productIDs: StoreManager.defaultProductIDs))
}

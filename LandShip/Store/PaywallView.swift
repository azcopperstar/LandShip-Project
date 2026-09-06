//
//  PaywallView.swift
//  LandShip
//

import SwiftUI
import StoreKit
import SwiftData

struct PaywallView: View {
	let context: PaywallContext

	@Environment(\.entitlements) private var entitlements
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@State private var restoreOutcome: RestoreOutcome?
	@State private var restoreInFlight = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					headlineCard
					includedCard
					purchaseSection
					if !entitlements.usage.isEmpty {
						usageCard
					}
				}
				.padding()
			}
			.background(Color.platformGroupedBackground)
			.navigationTitle(PaywallCopy.title)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close") { dismiss() }
				}
			}
			.task {
				entitlements.refreshUsage(in: modelContext)
			}
			.alert(restoreAlertTitle, isPresented: restoreAlertBinding) {
				Button("OK") { restoreOutcome = nil }
			} message: {
				Text(restoreAlertMessage)
			}
			.alert("Purchase Failed", isPresented: purchaseErrorBinding) {
				Button("OK") { entitlements.clearLastError() }
			} message: {
				Text(entitlements.lastError?.localizedDescription ?? "")
			}
		}
	}

	private var purchaseErrorBinding: Binding<Bool> {
		Binding(get: { entitlements.lastError != nil }, set: { if !$0 { entitlements.clearLastError() } })
	}

	private var headlineCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			Label(PaywallCopy.title, systemImage: PaywallCopy.systemImage)
				.font(.title2).bold()
			Text(PaywallCopy.headline(for: context))
				.font(.body)
				.foregroundStyle(.secondary)
		}
		.cardStyle(backgroundColor: .blue)
	}

	private var includedCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(PaywallCopy.whatsIncludedTitle)
				.font(.headline)
			Text(PaywallCopy.whatsIncludedMessage)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.cardStyle()
	}

	private var usageCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Your Free Trial Usage")
				.font(.headline)
			ForEach(Array(TrialCaps.allCapped.enumerated()), id: \.offset) { _, type in
				if let used = entitlements.usage[type.trialUsageKey], used > 0 {
					HStack {
						Text(type.trialDisplayName)
						Spacer()
						Text("\(used) of \(type.trialLimit)")
							.foregroundStyle(used >= type.trialLimit ? .red : .secondary)
					}
					.font(.subheadline)
				}
			}
		}
		.cardStyle()
	}

	private var purchaseSection: some View {
		VStack(spacing: 12) {
			if entitlements.isFullVersion {
				Label("You already have the full version.", systemImage: "checkmark.seal.fill")
					.foregroundStyle(.green)
			} else if let product = entitlements.product {
				Button {
					Task { await entitlements.purchase() }
				} label: {
					if entitlements.purchaseInFlight {
						ProgressView().frame(maxWidth: .infinity)
					} else {
						Text("Unlock for \(product.displayPrice)")
							.frame(maxWidth: .infinity)
					}
				}
				.buttonStyle(.borderedProminent)
				.disabled(entitlements.purchaseInFlight)
			} else {
				VStack(spacing: 8) {
					Text(PaywallCopy.storeUnavailableMessage)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
					Button(PaywallCopy.retryButtonLabel) {
						Task { await entitlements.retryLoadingProduct() }
					}
					.buttonStyle(.bordered)
				}
			}

			Button {
				restoreInFlight = true
				Task {
					restoreOutcome = await entitlements.restorePurchases()
					restoreInFlight = false
				}
			} label: {
				if restoreInFlight {
					ProgressView()
				} else {
					Text(PaywallCopy.Settings.restoreButtonLabel)
				}
			}
			.buttonStyle(.bordered)
			.disabled(restoreInFlight)
		}
	}

	// MARK: - Restore alert

	private var restoreAlertBinding: Binding<Bool> {
		Binding(get: { restoreOutcome != nil }, set: { if !$0 { restoreOutcome = nil } })
	}

	private var restoreAlertTitle: String {
		switch restoreOutcome {
			case .restored: return PaywallCopy.Restore.restoredTitle
			case .nothingToRestore: return PaywallCopy.Restore.nothingTitle
			case .failed: return PaywallCopy.Restore.failedTitle
			case nil: return ""
		}
	}

	private var restoreAlertMessage: String {
		switch restoreOutcome {
			case .restored: return PaywallCopy.Restore.restoredMessage
			case .nothingToRestore: return PaywallCopy.Restore.nothingMessage
			case .failed(let message): return message
			case nil: return ""
		}
	}
}

#Preview {
	PaywallView(context: .capReached(feature: "Parts", used: 10, limit: 10, requested: 1))
}

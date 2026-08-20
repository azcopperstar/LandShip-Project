// InsuranceExpirationsDetailView.swift
import SwiftUI

struct InsuranceExpirationsDetailView: View {
    let alerts: [DashboardView.InsuranceAlert]
    let recurringCosts: [DashboardView.RecurringCost]
    let formatDate: (Date) -> String
    let formatCurrency: (Double) -> String

    private var monthlyTotal: Double { recurringCosts.reduce(0) { $0 + $1.monthlyCost } }
    private var annualTotal:  Double { monthlyTotal * 12 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Recurring Costs ───────────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "repeat.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.purple)
                    Text("RECURRING COSTS")
                        .font(.headline)
                    Spacer()
                }

                if recurringCosts.isEmpty {
                    Text("No active recurring costs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(recurringCosts) { rc in
                            RecurringCostRow(rc: rc, formatDate: formatDate, formatCurrency: formatCurrency)
                                .padding(.vertical, 6)
                            if rc.id != recurringCosts.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Totals summary
                    VStack(spacing: 8) {
                        HStack {
                            Text("Monthly total")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatCurrency(monthlyTotal))
                                .font(.body.monospacedDigit())
                        }
                        Divider()
                        HStack {
                            Text("Annual total")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatCurrency(annualTotal))
                                .font(.body.monospacedDigit())
                                .bold()
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // ── Insurance Expirations ─────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.teal)
                    Text("INSURANCE EXPIRATIONS")
                        .font(.headline)
                    Spacer()
                }

                if alerts.isEmpty {
                    Text("No upcoming expirations within 90 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(alerts) { alert in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(alert.year) \(alert.vehicleName)")
                                        .font(.subheadline).bold()
                                    Text("Expires: \(formatDate(alert.expiration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    if alert.daysRemaining <= 30 {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    Text("\(alert.daysRemaining) days")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(alert.daysRemaining <= 30 ? .red : (alert.daysRemaining <= 60 ? .orange : .yellow))
                                }
                            }
                            .padding(.vertical, 8)
                            if alert.id != alerts.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("Recurring Costs & Insurance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(
            LinearGradient(colors: [
                Color.purple.opacity(0.07),
                Color.teal.opacity(0.05),
                Color.indigo.opacity(0.04)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        )
    }
}

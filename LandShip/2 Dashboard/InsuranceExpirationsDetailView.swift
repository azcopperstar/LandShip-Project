// InsuranceExpirationsDetailView.swift
import SwiftUI

struct InsuranceExpirationsDetailView: View {
    let alerts: [DashboardView.InsuranceAlert]
    let formatDate: (Date) -> String

    var body: some View {
        List {
            if alerts.isEmpty {
                Section {
                    Text("No upcoming expirations within 90 days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
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
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Insurance Expirations")
    }
}

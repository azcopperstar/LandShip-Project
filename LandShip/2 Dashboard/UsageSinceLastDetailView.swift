// UsageSinceLastDetailView.swift
import SwiftUI

struct UsageSinceLastDetailView: View {
    let rows: [DashboardView.UsageSinceLast]
    let distanceUnit: String
    let formatDate: (Date) -> String
    let onTapVehicle: (String) -> Void

    var body: some View {
        List {
            if rows.isEmpty {
                Section {
                    Text("No service history yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(rows) { row in
                    Button {
                        onTapVehicle(row.vehicleName)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.vehicleName)
                                    .font(.subheadline)
                                    .bold()
                                if let d = row.lastServiceDate {
                                    Text("Last serviced: \(formatDate(d))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No prior service record")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if row.milesSince > 0 {
                                    Text("\(row.milesSince) \(distanceUnit)")
                                        .font(.caption)
                                }
                                if row.hoursSince > 0 {
                                    Text(String(format: "%.1f h", row.hoursSince))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Usage Since Last")
    }
}

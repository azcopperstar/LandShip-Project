// Create a new file, e.g., DashboardView+NextServiceDueCard.swift

import SwiftUI

struct NextServiceDueCard: View {
    let nextTwoDue: [DashboardView.UpcomingDue]
    let distanceUnit: String
    let formatDate: (Date) -> String

    private var showsVehicleColumn: Bool {
        // Show vehicle label when multiple vehicles are represented
        Set(nextTwoDue.map { $0.vehicleId }).count > 1
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.blue)
                    Text("NEXT SERVICE DUE")
                        .font(.headline)
                }

                if nextTwoDue.isEmpty {
                    Text("No upcoming service items found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nextTwoDue) { due in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(due.itemName)
                                    .font(.subheadline)
                                    .bold()
                                if showsVehicleColumn {
                                    Spacer()
                                    Text(due.vehicleId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if !due.itemDescription.isEmpty {
                                Text(due.itemDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                if due.intervalMiles > 0, let rm = due.remainingMiles {
                                    Text("Miles: \(max(0, rm)) \(distanceUnit.isEmpty ? "mi" : distanceUnit)")
                                        .font(.caption)
                                }
                                if due.intervalHours > 0, let rh = due.remainingHours {
                                    Text(String(format: "Hours: %.1f", max(0, rh)))
                                        .font(.caption)
                                }
                                if due.intervalMonths > 0, let rd = due.remainingDays {
                                    Text("Days: \(max(0, rd))")
                                        .font(.caption)
                                }
                            }

                            if let d = due.dueDate {
                                Text("Est. next due: \(formatDate(d))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()
                    }
                }
            }
        }
    }
}

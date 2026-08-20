import SwiftUI

struct TripGroupsDetailView: View {
    let groups: [DashboardView.TripGroupSummary]
    let distanceUnit: String
    let fuelUnit: String
    let formatDate: (Date) -> String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                sectionHeader(icon: "map.fill", iconColor: .teal, title: "TRIP GROUPS")

                if groups.isEmpty {
                    Text("No trip groups have been recorded yet. Assign a group name when editing a trip log to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(groups) { group in
                        groupCard(group)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Trip Groups")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Per-group card

    @ViewBuilder private func groupCard(_ group: DashboardView.TripGroupSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.teal)
                Text(group.groupName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(group.tripCount) trip\(group.tripCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.teal)
            }

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {

                if group.totalDistance > 0 {
                    statCell(
                        icon: "road.lanes",
                        color: .blue,
                        title: "Distance",
                        value: "\(group.totalDistance.formatted(.number.grouping(.automatic))) \(distanceUnit)"
                    )
                }

                if group.totalFuelAdded > 0 {
                    statCell(
                        icon: "fuelpump.fill",
                        color: .orange,
                        title: "Fuel Added",
                        value: String(format: "%.1f \(fuelUnit)", group.totalFuelAdded)
                    )
                }

                if group.totalFuelConsumed > 0 {
                    statCell(
                        icon: "flame.fill",
                        color: .red,
                        title: "Fuel Used",
                        value: String(format: "%.1f \(fuelUnit)", group.totalFuelConsumed)
                    )
                }

                if group.vehicleCount > 1 {
                    statCell(
                        icon: "car.2.fill",
                        color: .indigo,
                        title: "Vehicles",
                        value: "\(group.vehicleCount)"
                    )
                }

                statCell(
                    icon: "calendar",
                    color: .green,
                    title: "First Trip",
                    value: formatDate(group.earliestDate)
                )

                statCell(
                    icon: "calendar.badge.checkmark",
                    color: .teal,
                    title: "Last Trip",
                    value: formatDate(group.latestDate)
                )
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    @ViewBuilder private func statCell(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder private func sectionHeader(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }
}

import SwiftUI
import SwiftData

// MARK: - TripGroupSummary model + compute

extension DashboardView {
    struct TripGroupSummary: Identifiable {
        let id = UUID()
        let groupName: String
        let tripCount: Int
        let totalDistance: Int
        let totalFuelAdded: Float
        let totalFuelConsumed: Float
        let earliestDate: Date
        let latestDate: Date
        let vehicleCount: Int
    }

    func computeTripGroups() {
        guard let trips = try? modelContext.fetch(FetchDescriptor<TripLog2>()) else {
            self.tripGroups = []
            return
        }

        let filtered = trips.filter { !$0.inactive && !$0.tripGroup.isEmpty && includesVehicle($0.vehicleId) }

        var buckets: [String: [TripLog2]] = [:]
        for trip in filtered {
            buckets[trip.tripGroup, default: []].append(trip)
        }

        let summaries: [TripGroupSummary] = buckets.map { name, groupTrips in
            let totalDistance = groupTrips.reduce(0) { $0 + max(0, $1.odometerEnd - $1.odometerStart) }
            let totalFuelAdded = groupTrips.reduce(Float(0)) {
                $0 + $1.fuelAdded1 + $1.fuelAdded2 + $1.fuelAdded3 + $1.fuelAdded4 + $1.fuelAdded5 + $1.fuelAdded6
            }
            let totalFuelConsumed = groupTrips.reduce(Float(0)) { $0 + $1.fuelConsumed }
            let earliestDate = groupTrips.map { $0.tripDateTimeStart }.min() ?? Date()
            let latestDate = groupTrips.map { $0.tripDateTimeEnd }.max() ?? Date()
            let vehicleCount = Set(groupTrips.map { $0.vehicleId }).filter { !$0.isEmpty }.count

            return TripGroupSummary(
                groupName: name,
                tripCount: groupTrips.count,
                totalDistance: totalDistance,
                totalFuelAdded: totalFuelAdded,
                totalFuelConsumed: totalFuelConsumed,
                earliestDate: earliestDate,
                latestDate: latestDate,
                vehicleCount: vehicleCount
            )
        }
        .sorted { $0.latestDate > $1.latestDate }

        self.tripGroups = summaries
    }
}

// MARK: - Trip Groups Card

struct TripGroupsCard: View {
    let groups: [DashboardView.TripGroupSummary]
    let distanceUnit: String
    let fuelUnit: String
    let formatDate: (Date) -> String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {

                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.teal)
                    Text("TRIP GROUPS")
                        .font(.headline)
                    Spacer()
                    Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if groups.isEmpty {
                    Text("No trip groups recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    Divider()
                    ForEach(Array(groups.prefix(4).enumerated()), id: \.element.id) { index, group in
                        TripGroupCardRow(group: group, distanceUnit: distanceUnit, fuelUnit: fuelUnit, formatDate: formatDate)
                        if index < min(groups.count, 4) - 1 {
                            Divider().padding(.leading, 8)
                        }
                    }
                    if groups.count > 4 {
                        Text("+ \(groups.count - 4) more…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct TripGroupCardRow: View {
    let group: DashboardView.TripGroupSummary
    let distanceUnit: String
    let fuelUnit: String
    let formatDate: (Date) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(group.groupName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text("\(group.tripCount) trip\(group.tripCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.teal)
            }
            HStack(spacing: 10) {
                if group.totalDistance > 0 {
                    Label(
                        "\(group.totalDistance.formatted(.number.grouping(.automatic))) \(distanceUnit)",
                        systemImage: "road.lanes"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if group.totalFuelAdded > 0 {
                    Label(
                        String(format: "%.1f \(fuelUnit)", group.totalFuelAdded),
                        systemImage: "fuelpump.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatDate(group.earliestDate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 1)
    }
}

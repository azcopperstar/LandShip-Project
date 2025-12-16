// FleetSnapshotDetailView.swift
import SwiftUI

struct FleetSnapshotDetailView: View {
    let fleetSnapshot: DashboardView.FleetSnapshot
    let distanceUnit: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    metricRow(title: "Total Vehicles", value: "\(fleetSnapshot.total)")
                    metricRow(title: "Active", value: "\(fleetSnapshot.active)")
                    metricRow(title: "Inactive", value: "\(fleetSnapshot.inactive)")
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    metricRow(title: "Average Mileage",
                              value: String(format: "%.0f %@", fleetSnapshot.avgMileage, distanceUnit))
                    metricRow(title: "Average Engine Hours",
                              value: String(format: "%.1f h", fleetSnapshot.avgHours))
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // New: Per-vehicle list
                if !fleetSnapshot.vehicles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vehicles")
                            .font(.headline)
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(fleetSnapshot.vehicles) { v in
                                HStack {
                                    Text(v.name)
                                        .font(.body)
                                        .foregroundStyle(v.inactive ? .secondary : .primary)
                                    Spacer()
                                    HStack(spacing: 16) {
                                        Text("\(v.odometer.formatted(.number.grouping(.automatic))) \(distanceUnit)")
                                            .font(.caption).monospacedDigit()
                                            .foregroundStyle(.secondary)
                                        Text("\(v.engHours, specifier: "%.1f") h")
                                            .font(.caption).monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Divider()
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("Fleet Snapshot")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(
            LinearGradient(colors: [
                Color.blue.opacity(0.08),
                Color.teal.opacity(0.06),
                Color.indigo.opacity(0.04)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "car.2.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)
            Text("FLEET SNAPSHOT")
                .font(.headline)
            Spacer()
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}

#Preview {
    NavigationStack {
        FleetSnapshotDetailView(
            fleetSnapshot: DashboardView.FleetSnapshot(
                total: 12,
                active: 9,
                inactive: 3,
                avgMileage: 48213,
                avgHours: 1278.4,
                vehicles: [
                    .init(name: "Truck A", odometer: 120_345, engHours: 820.5, inactive: false),
                    .init(name: "Truck B", odometer: 98_220, engHours: 640.0, inactive: true),
                    .init(name: "Van C", odometer: 45_010, engHours: 210.2, inactive: false)
                ]
            ),
            distanceUnit: "mi"
        )
    }
}

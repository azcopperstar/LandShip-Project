// FleetSnapshotDetailView.swift
import SwiftUI
import Charts

struct FleetSnapshotDetailView: View {
    let fleetSnapshot: DashboardView.FleetSnapshot
    let distanceUnit: String
    let cost: DashboardView.CostSnapshot
    let formatCurrency: (Double) -> String
    let onTapRange: (String, String) -> Void
    let onTapTopItem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Fleet Snapshot ────────────────────────────────────────
                sectionHeader(icon: "car.2.fill", iconColor: .indigo, title: "FLEET SNAPSHOT")

                // Fleet counts
                VStack(alignment: .leading, spacing: 12) {
                    metricRow(title: "Total \(Vertical.current.assetPlural)", value: "\(fleetSnapshot.total)", icon: "car.2.fill", color: .indigo)
                    metricRow(title: "Active", value: "\(fleetSnapshot.active)", icon: "checkmark.circle.fill", color: .green)
                    metricRow(title: "Inactive", value: "\(fleetSnapshot.inactive)", icon: "moon.zzz.fill", color: .gray)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Mileage & hours
                VStack(alignment: .leading, spacing: 12) {
                    metricRow(
                        title: "Total Fleet Mileage",
                        value: "\(fleetSnapshot.totalMileage.formatted(.number.grouping(.automatic))) \(distanceUnit)",
                        icon: "gauge.with.dots.needle.67percent",
                        color: .blue
                    )
                    metricRow(
                        title: "Average Mileage",
                        value: String(format: "%.0f %@", fleetSnapshot.avgMileage, distanceUnit),
                        icon: "chart.bar.fill",
                        color: .teal
                    )
                    metricRow(
                        title: "Total Engine Hours",
                        value: String(format: "%.1f h", fleetSnapshot.totalHours),
                        icon: "clock.fill",
                        color: .orange
                    )
                    metricRow(
                        title: "Average Engine Hours",
                        value: String(format: "%.1f h", fleetSnapshot.avgHours),
                        icon: "clock",
                        color: .secondary
                    )
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Per-vehicle list
                if !fleetSnapshot.vehicles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Vertical.current.assetPlural)
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(fleetSnapshot.vehicles) { v in
                                VehicleDetailRow(vehicle: v, distanceUnit: distanceUnit)
                                if v.id != fleetSnapshot.vehicles.last?.id {
                                    Divider().padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                // ── Maintenance Costs ─────────────────────────────────────
                sectionHeader(icon: "dollarsign.circle.fill", iconColor: .green, title: "MAINTENANCE COSTS")

                // Cost summary
                VStack(alignment: .leading, spacing: 12) {
                    metricRow(title: "Month to Date", value: formatCurrency(cost.monthToDate), icon: "calendar", color: .green)
                    metricRow(title: "Last 90 Days", value: formatCurrency(cost.last90Days), icon: "calendar.badge.clock", color: .teal)
                    metricRow(title: "Year to Date", value: formatCurrency(cost.yearToDate), icon: "calendar.badge.checkmark", color: .blue)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Cost bar chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Totals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Chart {
                        BarMark(x: .value("Range", "MTD"), y: .value("Total", cost.monthToDate))
                            .foregroundStyle(.green.opacity(0.9))
                            .annotation(position: .overlay) {
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { onTapRange("Costs • Month to Date", "Would navigate to costs filtered to MTD.") }
                            }
                        BarMark(x: .value("Range", "90D"), y: .value("Total", cost.last90Days))
                            .foregroundStyle(.green.opacity(0.6))
                            .annotation(position: .overlay) {
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { onTapRange("Costs • Last 90 Days", "Would navigate to costs filtered to last 90 days.") }
                            }
                        BarMark(x: .value("Range", "YTD"), y: .value("Total", cost.yearToDate))
                            .foregroundStyle(.green.opacity(0.4))
                            .annotation(position: .overlay) {
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { onTapRange("Costs • Year to Date", "Would navigate to costs filtered to YTD.") }
                            }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 160)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Top items
                if !cost.topItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Items (Last 90 Days)")
                            .font(.headline)
                        Chart(cost.topItems.prefix(10), id: \.name) { item in
                            BarMark(x: .value("Cost", item.total), y: .value("Item", item.name))
                                .foregroundStyle(.green.gradient)
                                .annotation(position: .overlay, alignment: .trailing) {
                                    Color.clear.contentShape(Rectangle())
                                        .onTapGesture { onTapTopItem(item.name) }
                                }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisGridLine(); AxisTick(); AxisValueLabel()
                            }
                        }
                        .frame(height: min(44 * CGFloat(min(10, cost.topItems.count)), 440))

                        VStack(spacing: 8) {
                            ForEach(cost.topItems.prefix(10), id: \.name) { item in
                                HStack {
                                    Text(item.name).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(formatCurrency(item.total)).font(.body.monospacedDigit())
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onTapTopItem(item.name) }
                                Divider()
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle("Fleet & Cost Snapshot")
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

    private func sectionHeader(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func metricRow(title: String, value: String, icon: String? = nil, color: Color = .secondary) -> some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
            }
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}

// MARK: - Per-vehicle row (detail view)

private struct VehicleDetailRow: View {
    let vehicle: DashboardView.FleetSnapshot.VehicleLine
    let distanceUnit: String

    private var subtitleText: String {
        var parts: [String] = []
        if vehicle.year > 0 { parts.append(String(vehicle.year)) }
        if !vehicle.manufacturer.isEmpty { parts.append(vehicle.manufacturer) }
        if !vehicle.model.isEmpty { parts.append(vehicle.model) }
        return parts.joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(vehicle.inactive ? Color.gray.opacity(0.45) : Color.green)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle.displayName)
                        .font(.body)
                        .fontWeight(vehicle.inactive ? .regular : .semibold)
                        .foregroundStyle(vehicle.inactive ? .secondary : .primary)
                    if vehicle.inactive {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8), in: Capsule())
                    }
                }
                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !vehicle.fuelType.isEmpty {
                    Text(vehicle.fuelType)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vehicle.odometer.formatted(.number.grouping(.automatic))) \(distanceUnit)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
                if vehicle.engHours > 0 {
                    Text(String(format: "%.1f h", vehicle.engHours))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FleetSnapshotDetailView(
            fleetSnapshot: DashboardView.FleetSnapshot(
                total: 3,
                active: 2,
                inactive: 1,
                totalMileage: 263_575,
                totalHours: 1670.7,
                avgMileage: 87_858,
                avgHours: 556.9,
                vehicles: [
                    .init(name: "truck-a", displayName: "Truck A", year: 2019, manufacturer: "Ford", model: "F-350", fuelType: "Diesel", odometer: 120_345, engHours: 820.5, inactive: false),
                    .init(name: "truck-b", displayName: "Truck B", year: 2021, manufacturer: "GMC", model: "Sierra", fuelType: "Gas", odometer: 98_220, engHours: 640.0, inactive: false),
                    .init(name: "van-c", displayName: "Van C", year: 2016, manufacturer: "Ford", model: "Transit", fuelType: "Gas", odometer: 45_010, engHours: 210.2, inactive: true)
                ]
            ),
            distanceUnit: "mi",
            cost: DashboardView.CostSnapshot(
                monthToDate: 245.75,
                last90Days: 1325.40,
                yearToDate: 4875.20,
                topItems: [
                    .init(name: "Oil & Filter", total: 220.0),
                    .init(name: "Front Brake Pads", total: 340.0),
                    .init(name: "Tires", total: 765.4)
                ]
            ),
            formatCurrency: { value in
                let f = NumberFormatter(); f.numberStyle = .currency; f.maximumFractionDigits = 2
                return f.string(from: NSNumber(value: value)) ?? "$0.00"
            },
            onTapRange: { _, _ in },
            onTapTopItem: { _ in }
        )
    }
}

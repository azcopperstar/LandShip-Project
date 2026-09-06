import SwiftUI
import Charts

struct MaintenanceStatusDetailView: View {
    let vehicleStatuses: [DashboardView.VehicleMaintenanceStatus]
    let nextDue: [DashboardView.UpcomingDue]
    let dueSummary: DashboardView.DueSummary
    let systemHotlist: [DashboardView.SystemHot]
    let onTapSystem: (String) -> Void

    // Most urgent UpcomingDue per vehicleId
    private var nextDueByVehicle: [String: DashboardView.UpcomingDue] {
        var result: [String: DashboardView.UpcomingDue] = [:]
        for item in nextDue {
            if result[item.vehicleId] == nil {
                result[item.vehicleId] = item
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Per-vehicle status breakdown with next-due item
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.blue)
                            Text("\(Vertical.current.assetSingular.uppercased()) STATUS")
                                .font(.headline)
                        }
                        if vehicleStatuses.isEmpty {
                            Text("No maintenance items found.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vehicleStatuses) { vs in
                                VehicleStatusDetailRow(
                                    status: vs,
                                    nextDue: nextDueByVehicle[vs.vehicleId]
                                )
                                if vs.id != vehicleStatuses.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // Aggregate summary
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("SUMMARY")
                                .font(.headline)
                        }
                        if dueSummary.totalItemsEvaluated == 0 {
                            Text("No maintenance items found.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Overdue").bold()
                                    Text("• Miles: \(dueSummary.overdueMiles)")
                                    Text("• Hours: \(dueSummary.overdueHours)")
                                    Text("• Time: \(dueSummary.overdueTime)")
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("Due soon").bold()
                                    Text("• Items: \(dueSummary.dueSoonCount)")
                                    Text("• Evaluated: \(dueSummary.totalItemsEvaluated)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.primary)
                        }
                    }
                }

                // System hotlist
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.red, .orange)
                            Text("SYSTEM HOTLIST")
                                .font(.headline)
                        }
                        if systemHotlist.isEmpty {
                            Text("No system activity to highlight.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Chart {
                                ForEach(systemHotlist) { sys in
                                    BarMark(
                                        x: .value("Overdue", sys.overdueCount),
                                        y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
                                    )
                                    .foregroundStyle(.red.gradient)
                                    .annotation(position: .overlay, alignment: .trailing) {
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onTapGesture { onTapSystem(sys.system) }
                                    }

                                    BarMark(
                                        x: .value("Soon", sys.dueSoonCount),
                                        y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
                                    )
                                    .position(by: .value("Type", "Soon"))
                                    .foregroundStyle(.orange.gradient)
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 200)

                            Divider()

                            ForEach(systemHotlist) { sys in
                                Button {
                                    onTapSystem(sys.system)
                                } label: {
                                    HStack {
                                        Text(sys.system.isEmpty ? "Unspecified" : sys.system)
                                            .bold()
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("Overdue: \(sys.overdueCount)")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                        Text("Soon: \(sys.dueSoonCount)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Maintenance Status")
    }
}

// MARK: - Per-vehicle detail row

private struct VehicleStatusDetailRow: View {
    let status: DashboardView.VehicleMaintenanceStatus
    let nextDue: DashboardView.UpcomingDue?

    var statusColor: Color {
        if status.overdueCount > 0 { return .red }
        if status.dueSoonCount > 0 { return .orange }
        if status.totalEvaluated > 0 { return .green }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Vehicle name + status badges
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                Text(status.vehicleName)
                    .font(.subheadline).bold()
                    .lineLimit(1)

                Spacer()

                if status.totalEvaluated == 0 {
                    Text("No items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        if status.overdueCount > 0 {
                            Label("\(status.overdueCount)", systemImage: "exclamationmark.circle.fill")
                                .font(.caption).bold()
                                .foregroundStyle(.red)
                        }
                        if status.dueSoonCount > 0 {
                            Label("\(status.dueSoonCount)", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if status.overdueCount == 0 && status.dueSoonCount == 0 {
                            Label("\(status.okCount) OK", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Text("\(status.totalEvaluated) items")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Next service due entry
            if let due = nextDue {
                NextDueRow(due: due)
                    .padding(.leading, 17)
            }
        }
    }
}

// MARK: - System Hotlist Detail

struct SystemHotlistDetailView: View {
    let systems: [DashboardView.SystemHot]
    let onTapSystem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.red, .orange)
                            Text("SYSTEM HOTLIST")
                                .font(.headline)
                        }
                        if systems.isEmpty {
                            Text("No system activity to highlight.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Chart {
                                ForEach(systems) { sys in
                                    BarMark(
                                        x: .value("Overdue", sys.overdueCount),
                                        y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
                                    )
                                    .foregroundStyle(.red.gradient)
                                    .annotation(position: .overlay, alignment: .trailing) {
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onTapGesture { onTapSystem(sys.system) }
                                    }
                                    BarMark(
                                        x: .value("Soon", sys.dueSoonCount),
                                        y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
                                    )
                                    .position(by: .value("Type", "Soon"))
                                    .foregroundStyle(.orange.gradient)
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 240)

                            Divider()

                            ForEach(systems) { sys in
                                Button {
                                    onTapSystem(sys.system)
                                } label: {
                                    HStack {
                                        Text(sys.system.isEmpty ? "Unspecified" : sys.system)
                                            .bold()
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("Overdue: \(sys.overdueCount)")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                        Text("Soon: \(sys.dueSoonCount)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("System Hotlist")
    }
}

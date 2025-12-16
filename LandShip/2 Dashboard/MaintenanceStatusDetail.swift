// Swift file: DashboardView+MaintenanceStatusDetail.swift
import SwiftUI
import Charts

struct MaintenanceStatusDetailView: View {
    let dueSummary: DashboardView.DueSummary
    let systemHotlist: [DashboardView.SystemHot]
    let onTapSystem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("MAINTENANCE STATUS")
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

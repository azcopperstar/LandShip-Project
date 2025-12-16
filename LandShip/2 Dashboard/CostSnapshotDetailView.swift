import SwiftUI
import Charts

struct CostSnapshotDetailView: View {
    let cost: DashboardView.CostSnapshot
    let formatCurrency: (Double) -> String
    let onTapRange: (String, String) -> Void
    let onTapTopItem: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                // Summary tiles
                VStack(alignment: .leading, spacing: 12) {
                    metricRow(title: "Month to Date", value: formatCurrency(cost.monthToDate))
                    metricRow(title: "Last 90 Days", value: formatCurrency(cost.last90Days))
                    metricRow(title: "Year to Date", value: formatCurrency(cost.yearToDate))
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Chart for MTD / 90D / YTD
                VStack(alignment: .leading, spacing: 8) {
                    Text("Totals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Chart {
                        BarMark(
                            x: .value("Range", "MTD"),
                            y: .value("Total", cost.monthToDate)
                        )
                        .foregroundStyle(.green.opacity(0.9))
                        .annotation(position: .overlay) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapRange("Costs • Month to Date", "Would navigate to costs filtered to MTD.")
                                }
                        }

                        BarMark(
                            x: .value("Range", "90D"),
                            y: .value("Total", cost.last90Days)
                        )
                        .foregroundStyle(.green.opacity(0.6))
                        .annotation(position: .overlay) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapRange("Costs • Last 90 Days", "Would navigate to costs filtered to last 90 days.")
                                }
                        }

                        BarMark(
                            x: .value("Range", "YTD"),
                            y: .value("Total", cost.yearToDate)
                        )
                        .foregroundStyle(.green.opacity(0.4))
                        .annotation(position: .overlay) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapRange("Costs • Year to Date", "Would navigate to costs filtered to YTD.")
                                }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 180)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Top items list/chart
                if !cost.topItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Items (Last 90 Days)")
                            .font(.headline)

                        Chart(cost.topItems.prefix(10), id: \.name) { item in
                            BarMark(
                                x: .value("Cost", item.total),
                                y: .value("Item", item.name)
                            )
                            .foregroundStyle(.green.gradient)
                            .annotation(position: .overlay, alignment: .trailing) {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTapTopItem(item.name) }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                        .frame(height: min(44 * CGFloat(min(10, cost.topItems.count)), 440))

                        // Also present a simple list for accessibility
                        VStack(spacing: 8) {
                            ForEach(cost.topItems.prefix(10), id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(formatCurrency(item.total))
                                        .font(.body.monospacedDigit())
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
        .navigationTitle("Maintenance Cost Snapshot")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.teal.opacity(0.06),
                    Color.indigo.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
            Text("MAINTENANCE COST SNAPSHOT")
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
        CostSnapshotDetailView(
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
                let f = NumberFormatter()
                f.numberStyle = .currency
                f.maximumFractionDigits = 2
                return f.string(from: NSNumber(value: value)) ?? "$0.00"
            },
            onTapRange: { _, _ in },
            onTapTopItem: { _ in }
        )
    }
}

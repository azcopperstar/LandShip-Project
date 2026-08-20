import SwiftUI
import Charts

struct AdditionsCostCard: View {
    let rows: [DashboardView.AdditionsCategoryCost]
    let formatCurrency: (Double) -> String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.square.on.square")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                    Text("ADDITIONS COST BY CATEGORY")
                        .font(.headline)
                }

                if rows.isEmpty {
                    Text("No costs found in the current scope.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    // Show top 5 rows for the card
                    ForEach(Array(rows.prefix(5)).indices, id: \.self) { idx in
                        let r = rows[idx]
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.category)
                                    .font(.subheadline).bold()
                                if !r.subcategory.isEmpty && r.subcategory != "—" {
                                    Text(r.subcategory)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(r.total))
                                .font(.caption.monospacedDigit())
                        }
                        if idx < min(4, rows.count - 1) { Divider() }
                    }

                    if rows.count > 5 {
                        Text("+ \(rows.count - 5) more…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct AdditionsCostDetailView: View {
    let rows: [DashboardView.AdditionsCategoryCost]
    let formatCurrency: (Double) -> String

    enum SortMode: String, CaseIterable, Identifiable { case totalDesc = "Total"; case categoryAZ = "Category"; var id: String { rawValue } }
    @State private var sortMode: SortMode = .totalDesc

    // Group rows by category for sectioned list
    private var grouped: [(category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double)] {
        let dict: [String: [DashboardView.AdditionsCategoryCost]] = Dictionary(grouping: rows, by: { (row: DashboardView.AdditionsCategoryCost) in
            row.category
        })

        var sections: [(category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double)] = dict.map { (key: String, vals: [DashboardView.AdditionsCategoryCost]) in
            let t: Double = vals.reduce(0.0, { (partial: Double, next: DashboardView.AdditionsCategoryCost) in partial + next.total })
            let sortedEntries: [DashboardView.AdditionsCategoryCost]
            switch sortMode {
            case .totalDesc:
                sortedEntries = vals.sorted(by: { (lhs: DashboardView.AdditionsCategoryCost, rhs: DashboardView.AdditionsCategoryCost) in lhs.total > rhs.total })
            case .categoryAZ:
                sortedEntries = vals.sorted(by: { (lhs: DashboardView.AdditionsCategoryCost, rhs: DashboardView.AdditionsCategoryCost) in
                    lhs.subcategory.localizedCaseInsensitiveCompare(rhs.subcategory) == .orderedAscending
                })
            }
            return (category: key, entries: sortedEntries, total: t)
        }

        switch sortMode {
        case .totalDesc:
            sections.sort(by: { (lhs: (category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double), rhs: (category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double)) in
                lhs.total > rhs.total
            })
        case .categoryAZ:
            sections.sort(by: { (lhs: (category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double), rhs: (category: String, entries: [DashboardView.AdditionsCategoryCost], total: Double)) in
                lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
            })
        }
        return sections
    }

    private var grandTotal: Double { rows.reduce(0) { $0 + $1.total } }

    var body: some View {
        List {
            Section {
                Picker("Sort", selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !rows.isEmpty {
                Section(header: Text("Summary")) {
                    Chart(grouped, id: \.category) { section in
                        BarMark(
                            x: .value("Total", section.total),
                            y: .value("Category", section.category)
                        )
                    }
                    .chartXAxisLabel("Total")
                    .frame(minHeight: 160)
                }
            }

            if rows.isEmpty {
                Section {
                    Text("No costs found in the current scope.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, section in
                    Section(header: HStack {
                        Text(section.category).font(.subheadline).bold()
                        Spacer()
                        Text(formatCurrency(section.total)).font(.caption).foregroundStyle(.secondary)
                    }) {
                        ForEach(Array(section.entries.enumerated()), id: \.offset) { _, r in
                            HStack {
                                Text(r.subcategory.isEmpty ? "—" : r.subcategory)
                                Spacer()
                                Text(formatCurrency(r.total))
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Grand Total").font(.headline)
                        Spacer()
                        Text(formatCurrency(grandTotal)).font(.headline)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Additions Cost Detail")
    }
}

//#Preview("Additions Cost Card") {
//    let sample: [DashboardView.AdditionsCategoryCost] = [
//        .init(category: "Body", subcategory: "Roof Rack", total: 420.0),
//        .init(category: "Body", subcategory: "Tow Hitch", total: 350.0),
//        .init(category: "Electrical", subcategory: "Dash Cam", total: 199.99),
//        .init(category: "Electrical", subcategory: "LED Lights", total: 89.50),
//        .init(category: "Interior", subcategory: "Floor Mats", total: 120.0),
//        .init(category: "Interior", subcategory: "Organizer", total: 60.0)
//    ]
//    AdditionsCostCard(rows: sample, formatCurrency: { dollars in
//        Functions().formatCurrency(dollars: Float(dollars))
//    })
//}
//
//#Preview("Additions Cost Detail") {
//    let sample: [DashboardView.AdditionsCategoryCost] = [
//        .init(category: "Body", subcategory: "Roof Rack", total: 420.0),
//        .init(category: "Body", subcategory: "Tow Hitch", total: 350.0),
//        .init(category: "Electrical", subcategory: "Dash Cam", total: 199.99),
//        .init(category: "Electrical", subcategory: "LED Lights", total: 89.50),
//        .init(category: "Interior", subcategory: "Floor Mats", total: 120.0),
//        .init(category: "Interior", subcategory: "Organizer", total: 60.0)
//    ]
//    NavigationStack {
//        AdditionsCostDetailView(rows: sample, formatCurrency: { dollars in
//            Functions().formatCurrency(dollars: Float(dollars))
//        })
//    }
//}


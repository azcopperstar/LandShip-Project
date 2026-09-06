// RecentServiceDetailView.swift
import SwiftUI
import SwiftData

struct RecentServiceDetailView: View {
    let vehicleScope: String
    let distanceUnit: String
    let formatDate: (Date) -> String
    let vehicleDisplayName: (String) -> String

    @Environment(\.modelContext) private var modelContext
    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let id = UUID()
        let mxDate: Date
        let vehicleId: String
        let mxName: String
        let miles: Int
        let hours: Float
    }

    var body: some View {
        List {
            if rows.isEmpty {
                Section {
                    Text("No recent service records.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(rows) { rec in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.mxName).font(.subheadline).bold()
                            Text("\(vehicleDisplayName(rec.vehicleId)) • \(formatDate(rec.mxDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if rec.miles > 0 {
                                Text("\(rec.miles) \(distanceUnit)").font(.caption)
                            }
                            if rec.hours > 0 {
                                Text(String(format: "%.1f h", rec.hours)).font(.caption)
                            }
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Recent Service")
        .onAppear { fetch() }
    }

    private func fetch(limit: Int = 50) {
        let sort = [
            SortDescriptor(\ServiceRecords1.mxDate, order: .reverse),
            SortDescriptor(\ServiceRecords1.updatedAt, order: .reverse)
        ]
        var fd = FetchDescriptor<ServiceRecords1>(sortBy: sort)
        if !vehicleScope.isEmpty && vehicleScope != "All Vehicles" {
            fd.predicate = #Predicate { $0.vehicleId == vehicleScope }
        }
        fd.fetchLimit = limit
        do {
            let recs = try modelContext.fetch(fd)
            self.rows = recs.map {
                Row(
                    mxDate: $0.mxDate,
                    vehicleId: $0.vehicleId,
                    mxName: $0.mxName,
                    miles: $0.Miles,
                    hours: $0.engHours
                )
            }
        } catch {
            self.rows = []
        }
    }
}

// NextServiceDueDetailView.swift
import SwiftUI
import SwiftData

struct NextServiceDueDetailView: View {
    let vehicleScope: String
    let distanceUnit: String
    let formatDate: (Date) -> String

    @Environment(\.modelContext) private var modelContext
    @State private var allDue: [DashboardView.UpcomingDue] = []

    private let functions = Functions()
    private var unit: String { distanceUnit.isEmpty ? "mi" : distanceUnit }
    private var showVehicleNames: Bool { vehicleScope == "All Vehicles" || vehicleScope.isEmpty }

    private var overdueCount: Int  { allDue.filter { $0.score < 0.01 }.count }
    private var dueSoonCount: Int  { allDue.filter { $0.score >= 0.01 && $0.score < 0.15 }.count }
    private var okCount: Int       { allDue.filter { $0.score >= 0.15 }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // ── Summary header ──────────────────────────────────────────
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.blue)
                            Text("SERVICE DUE SUMMARY")
                                .font(.headline)
                            Spacer()
                            Text(vehicleScope.isEmpty ? "All Vehicles" : vehicleScope)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 0) {
                            summaryTile(count: overdueCount,  label: "Overdue",  color: .red)
                            Divider().frame(height: 36)
                            summaryTile(count: dueSoonCount,  label: "Due Soon", color: .orange)
                            Divider().frame(height: 36)
                            summaryTile(count: okCount,       label: "OK",       color: .green)
                            Spacer()
                        }
                    }
                }

                // ── Item cards ──────────────────────────────────────────────
                if allDue.isEmpty {
                    CardView {
                        Text("No service items with intervals found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(allDue) { due in
                        itemCard(due)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Next Service Due")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { compute() }
    }

    // MARK: - Summary tile

    @ViewBuilder
    private func summaryTile(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Item card

    @ViewBuilder
    private func itemCard(_ due: DashboardView.UpcomingDue) -> some View {
        let (statusLabel, statusColor) = urgencyInfo(score: due.score)

        CardView {
            VStack(alignment: .leading, spacing: 10) {

                // Header: name + vehicle + badge
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(due.itemName)
                            .font(.subheadline.bold())
                        if !due.itemDescription.isEmpty {
                            Text(due.itemDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if showVehicleNames {
                            Text(functions.getVehicleDisplayName(vehicleId: due.vehicleId, context: modelContext))
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                    }

                    Spacer()

                    Text(statusLabel)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }

                Divider()

                // Progress ring + metrics
                HStack(alignment: .top, spacing: 16) {

                    ProgressRing(
                        value: due.score,
                        label: "remaining",
                        detail: "\(Int(due.score * 100))%"
                    )
                    .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 8) {

                        if due.intervalMiles > 0 {
                            metricGroup(title: "ODOMETER") {
                                metricRow("Current",   "\(due.currentMiles.formatted()) \(unit)")
                                if let dam = due.dueAtMiles {
                                    metricRow("Due At", "\(dam.formatted()) \(unit)", style: .highlighted)
                                }
                                if let rm = due.remainingMiles {
                                    metricRow("Remaining", "\(rm.formatted()) \(unit)", style: .dimmed)
                                }
                            }
                        }

                        if due.intervalHours > 0 {
                            metricGroup(title: "ENGINE HOURS") {
                                metricRow("Current",   String(format: "%.1f hrs", due.currentHours))
                                if let rh = due.remainingHours {
                                    metricRow("Remaining", String(format: "%.1f hrs", max(0, rh)), style: .highlighted)
                                }
                            }
                        }

                        if due.intervalMonths > 0 {
                            metricGroup(title: "SCHEDULE") {
                                if let rd = due.remainingDays {
                                    metricRow("Days Left", "\(max(0, rd)) days", style: .highlighted)
                                }
                                if let d = due.dueDate {
                                    metricRow("Est. Due",  formatDate(d), style: .dimmed)
                                }
                            }
                        }

                        if due.derivedIntervalMiles != nil || due.derivedIntervalHours != nil || due.derivedIntervalMonths != nil {
                            metricGroup(title: "LAST RECORDED INTERVAL") {
                                if let dm = due.derivedIntervalMiles {
                                    metricRow("Miles", "\(dm.formatted()) \(unit)", style: .dimmed)
                                }
                                if let dh = due.derivedIntervalHours {
                                    metricRow("Hours", String(format: "%.1f hrs", dh), style: .dimmed)
                                }
                                if let dmo = due.derivedIntervalMonths {
                                    metricRow("Months", "\(dmo) mo", style: .dimmed)
                                }
                            }
                        }
                    }
                }

                Divider()

                // Interval footer
                Text("Interval: \(intervalDescription(due))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Metric helpers

    private enum MetricStyle { case normal, highlighted, dimmed }

    @ViewBuilder
    private func metricGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
            content()
        }
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: String, style: MetricStyle = .normal) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
            Text(value)
                .font(.caption.monospacedDigit())
                .bold(style == .highlighted)
                .foregroundStyle(style == .dimmed ? .secondary : .primary)
        }
    }

    // MARK: - Urgency

    private func urgencyInfo(score: Double) -> (String, Color) {
        switch score {
        case ..<0.01: return ("OVERDUE",   .red)
        case ..<0.15: return ("DUE SOON",  .orange)
        case ..<0.35: return ("COMING UP", .yellow)
        default:      return ("OK",        .green)
        }
    }

    private func intervalDescription(_ due: DashboardView.UpcomingDue) -> String {
        var parts: [String] = []
        if due.intervalMiles > 0  { parts.append("every \(due.intervalMiles.formatted()) \(unit)") }
        if due.intervalHours > 0  { parts.append("every \(String(format: "%.0f", due.intervalHours)) hrs") }
        if due.intervalMonths > 0 { parts.append("every \(due.intervalMonths) month\(due.intervalMonths == 1 ? "" : "s")") }
        return parts.joined(separator: " / ")
    }

    // MARK: - Compute (mirrors recomputeNextDue, no top-N limit)

    private func compute() {
        var fd = FetchDescriptor<MxItems3>()
        if vehicleScope != "All Vehicles" && !vehicleScope.isEmpty {
            fd.predicate = #Predicate { $0.vehicleId == vehicleScope }
        }
        do {
            let items = try modelContext.fetch(fd)
            var computed: [DashboardView.UpcomingDue] = []

            for item in items {
                guard item.intervalMiles > 0 || item.intervalHours > 0 || item.intervalMonths > 0 else { continue }
                let vId = item.vehicleId
                guard let v = functions.loadVehicleDetails(context: modelContext, vehicleId: vId) else { continue }

                let currentMiles = v.mileage
                let currentHours = v.engHours

                // Fetch last 2 records — derive actual interval if history exists, else fall back to database values
                var lastDate: Date? = nil
                var lastMiles: Int = 0
                var lastHours: Float = 0.0
                var capturedDerivedMiles: Int? = nil
                var capturedDerivedHours: Float? = nil
                var capturedDerivedMonths: Int? = nil
                var effectiveIntervalMiles: Int = item.intervalMiles
                var effectiveIntervalHours: Float = item.intervalHours
                var effectiveIntervalMonths: Int = item.intervalMonths
                do {
                    let mxName = item.mxName
                    var fdRec = FetchDescriptor<ServiceRecords1>(
                        predicate: #Predicate { $0.vehicleId == vId && $0.mxName == mxName },
                        sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
                    )
                    fdRec.fetchLimit = 2
                    let recs = try modelContext.fetch(fdRec)
                    if let rec0 = recs.first {
                        lastDate  = rec0.mxDate
                        lastMiles = rec0.Miles
                        lastHours = rec0.engHours
                        if recs.count >= 2 {
                            let rec1 = recs[1]
                            let derivedMiles = rec0.Miles - rec1.Miles
                            if derivedMiles > 0 { effectiveIntervalMiles = derivedMiles }
                            let derivedHours = rec0.engHours - rec1.engHours
                            if derivedHours > 0 { effectiveIntervalHours = derivedHours }
                            let derivedMonths = Calendar(identifier: .gregorian)
                                .dateComponents([.month], from: rec1.mxDate, to: rec0.mxDate).month ?? 0
                            if derivedMonths > 0 { effectiveIntervalMonths = derivedMonths }
                            capturedDerivedMiles = derivedMiles > 0 ? derivedMiles : nil
                            capturedDerivedHours = derivedHours > 0 ? derivedHours : nil
                            capturedDerivedMonths = derivedMonths > 0 ? derivedMonths : nil
                        }
                    }
                } catch {}

                let milesSince = (lastMiles > 0 && currentMiles >= lastMiles) ? (currentMiles - lastMiles) : 0
                let hoursSince = (lastHours > 0 && currentHours >= lastHours) ? (currentHours - lastHours) : 0

                let remainingMiles: Int?   = effectiveIntervalMiles > 0 ? max(0, effectiveIntervalMiles - milesSince) : nil
                let remainingHours: Float? = effectiveIntervalHours > 0 ? max(0, effectiveIntervalHours - hoursSince) : nil
                let dueAtMiles: Int?       = effectiveIntervalMiles > 0 ? (currentMiles + (effectiveIntervalMiles - milesSince)) : nil

                var dueDate: Date? = nil
                var remainingDays: Int? = nil
                if effectiveIntervalMonths > 0 {
                    let anchor = lastDate ?? item.createdAt
                    if let d = Calendar(identifier: .gregorian).date(byAdding: .month, value: effectiveIntervalMonths, to: anchor) {
                        dueDate = d
                        let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: d).day ?? 0
                        remainingDays = max(0, days)
                    }
                }

                var factors: [Double] = []
                if let rm = remainingMiles,  effectiveIntervalMiles > 0  { factors.append(Double(rm) / Double(effectiveIntervalMiles)) }
                if let rh = remainingHours,  effectiveIntervalHours > 0  { factors.append(Double(rh) / Double(effectiveIntervalHours)) }
                if let rd = remainingDays,   effectiveIntervalMonths > 0 {
                    factors.append(Double(rd) / Double(max(1, effectiveIntervalMonths * 30)))
                }
                guard !factors.isEmpty else { continue }
                let score = factors.min() ?? 1.0

                computed.append(DashboardView.UpcomingDue(
                    vehicleId:      vId,
                    itemName:       item.mxName,
                    itemDescription: item.mxDescription,
                    intervalMiles:  effectiveIntervalMiles,
                    intervalHours:  effectiveIntervalHours,
                    intervalMonths: effectiveIntervalMonths,
                    currentMiles:   currentMiles,
                    currentHours:   currentHours,
                    lastServiceDate:  lastDate,
                    lastServiceMiles: lastMiles,
                    lastServiceHours: lastHours,
                    derivedIntervalMiles: capturedDerivedMiles,
                    derivedIntervalHours: capturedDerivedHours,
                    derivedIntervalMonths: capturedDerivedMonths,
                    remainingMiles: remainingMiles,
                    remainingHours: remainingHours,
                    remainingDays:  remainingDays,
                    dueAtMiles:     dueAtMiles,
                    dueDate:        dueDate,
                    score:          score
                ))
            }

            self.allDue = computed.sorted { $0.score < $1.score }
        } catch {
            self.allDue = []
        }
    }
}

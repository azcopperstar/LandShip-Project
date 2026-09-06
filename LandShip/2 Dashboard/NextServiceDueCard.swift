import SwiftUI
import SwiftData

struct NextServiceDueCard: View {
    let nextTwoDue: [DashboardView.UpcomingDue]
    let distanceUnit: String
    let formatDate: (Date) -> String
    let vehicleDisplayName: (String) -> String

    private struct VehicleGroup: Identifiable {
        let vehicleId: String
        var id: String { vehicleId }
        let items: [DashboardView.UpcomingDue]
    }

    private var vehicleGroups: [VehicleGroup] {
        var seen: [String] = []
        var buckets: [String: [DashboardView.UpcomingDue]] = [:]
        for due in nextTwoDue {
            if buckets[due.vehicleId] == nil { seen.append(due.vehicleId) }
            buckets[due.vehicleId, default: []].append(due)
        }
        return seen.map { VehicleGroup(vehicleId: $0, items: buckets[$0]!) }
    }

    private var unit: String { distanceUnit.isEmpty ? "mi" : distanceUnit }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {

                // ── Title ─────────────────────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.blue)
                    Text("NEXT SERVICE DUE")
                        .font(.headline)
                }

                // ── Data note ────────────────────────────────────────────
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    Text("Accuracy requires service records linked to an item from the Items table with a matching name. Intervals are derived from the two most recent records; database intervals are used as a fallback.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                // ── Detail-page link ──────────────────────────────────────
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("View full service schedule")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        Text("All items ranked by urgency with progress detail")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Divider()

                // ── Vehicle sections ──────────────────────────────────────
                if nextTwoDue.isEmpty {
                    Text("No upcoming service items found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(vehicleGroups.enumerated()), id: \.element.id) { idx, group in
                        if idx > 0 {
                            Divider().padding(.vertical, 2)
                        }
                        // Vehicle header
                        Text(vehicleDisplayName(group.vehicleId))
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .padding(.bottom, 2)

                        ForEach(group.items) { due in
                            itemRow(due)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Item row

    @ViewBuilder
    private func itemRow(_ due: DashboardView.UpcomingDue) -> some View {
        let urgColor = urgencyColor(score: due.score)

        VStack(alignment: .leading, spacing: 3) {

            // Item name + urgency badge
            HStack(spacing: 6) {
                Circle()
                    .fill(urgColor)
                    .frame(width: 7, height: 7)
                Text(due.itemName)
                    .font(.subheadline.bold())
                Spacer()
                Text(urgencyLabel(score: due.score))
                    .font(.caption2.bold())
                    .foregroundStyle(urgColor)
            }

            if !due.itemDescription.isEmpty {
                Text(due.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 13)
            }

            // ── Metrics ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {

                // Last service
                if due.lastServiceMiles > 0 || due.lastServiceDate != nil {
                    HStack(spacing: 16) {
                        if due.lastServiceMiles > 0 {
                            metricPair(label: "Last service", value: "\(due.lastServiceMiles.formatted()) \(unit)")
                        }
                        if let ld = due.lastServiceDate {
                            metricPair(label: "Last date", value: formatDate(ld))
                        }
                    }
                }

                // Miles-based
                if due.intervalMiles > 0 {
                    HStack(spacing: 16) {
                        metricPair(label: "Current", value: "\(due.currentMiles.formatted()) \(unit)")
                        if let dam = due.dueAtMiles {
                            metricPair(label: "Due at", value: "\(dam.formatted()) \(unit)",
                                       highlight: true, highlightColor: urgColor)
                        }
                        if let rm = due.remainingMiles {
                            metricPair(label: "Remaining", value: "\(rm.formatted()) \(unit)")
                        }
                    }
                }

                // Hours-based
                if due.intervalHours > 0 {
                    HStack(spacing: 16) {
                        metricPair(label: "Curr hrs", value: String(format: "%.1f", due.currentHours))
                        if let rh = due.remainingHours {
                            metricPair(label: "Hrs remaining", value: String(format: "%.1f", max(0, rh)),
                                       highlight: true, highlightColor: urgColor)
                        }
                    }
                }

                // Time-based
                if due.intervalMonths > 0 {
                    HStack(spacing: 16) {
                        if let rd = due.remainingDays {
                            metricPair(label: "Days remaining", value: "\(max(0, rd))",
                                       highlight: true, highlightColor: urgColor)
                        }
                        if let d = due.dueDate {
                            metricPair(label: "Est. due", value: formatDate(d))
                        }
                    }
                }

                // Derived interval (from last 2 records)
                if due.derivedIntervalMiles != nil || due.derivedIntervalHours != nil || due.derivedIntervalMonths != nil {
                    HStack(spacing: 16) {
                        if let dm = due.derivedIntervalMiles {
                            metricPair(label: "Last interval", value: "\(dm.formatted()) \(unit)")
                        }
                        if let dh = due.derivedIntervalHours {
                            metricPair(label: "Last hrs interval", value: String(format: "%.1f", dh))
                        }
                        if let dmo = due.derivedIntervalMonths {
                            metricPair(label: "Last mo interval", value: "\(dmo) mo")
                        }
                    }
                }
            }
            .padding(.leading, 13)
            .padding(.top, 1)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func metricPair(label: String, value: String,
                             highlight: Bool = false,
                             highlightColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospacedDigit())
                .bold(highlight)
                .foregroundStyle(highlight ? highlightColor : .secondary)
        }
    }

    private func urgencyColor(score: Double) -> Color {
        switch score {
        case ..<0.01: return .red
        case ..<0.15: return .orange
        case ..<0.35: return .yellow
        default:      return .green
        }
    }

    private func urgencyLabel(score: Double) -> String {
        switch score {
        case ..<0.01: return "OVERDUE"
        case ..<0.15: return "DUE SOON"
        case ..<0.35: return "COMING UP"
        default:      return "OK"
        }
    }
}

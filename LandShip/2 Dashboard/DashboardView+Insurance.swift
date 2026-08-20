import SwiftUI
import SwiftData

extension DashboardView {

	// MARK: - Insurance Alerts

	struct InsuranceAlert: Identifiable {
		let id = UUID()
		let vehicleName: String
		let year: Int
		let expiration: Date
		let daysRemaining: Int
	}

	func computeInsuranceAlerts() {
		let now = Date()
		guard let in90 = Calendar.current.date(byAdding: .day, value: 90, to: now) else {
			self.insuranceAlerts = []
			return
		}
		// `scopedVehicles` resolves to the DashboardView computed property, which already
		// applies both the toolbar's single-vehicle pick and the saved vehicle scheme.
		let alerts = scopedVehicles
			.map { v -> InsuranceAlert? in
				let days = Calendar.current.dateComponents([.day], from: now, to: v.insuranceExpiration).day ?? Int.max
				if v.insuranceExpiration <= in90 && days >= 0 {
					return InsuranceAlert(vehicleName: v.name, year: v.year, expiration: v.insuranceExpiration, daysRemaining: days)
				}
				return nil
			}
			.compactMap { $0 }
			.sorted { $0.daysRemaining < $1.daysRemaining }
		self.insuranceAlerts = alerts
	}

	// MARK: - Recurring Costs (from Subscriptions)

	struct RecurringCost: Identifiable {
		let id = UUID()
		let vehicleId: String
		let vehicleDisplayName: String
		let itemName: String
		let category: String
		let cost: Double
		let intervalQty: Int      // e.g. 1, 3, 6
		let intervalUnit: String  // "Day", "Month", "Year"
		let monthlyCost: Double   // normalized to per-month for totals
		let nextDue: Date?
	}

	func computeRecurringCosts() {
		guard let subs = try? modelContext.fetch(FetchDescriptor<Subscriptions>()) else {
			self.recurringCosts = []
			return
		}

		let scoped = subs.filter { includesVehicle($0.vehicleId) }

		let now = Date()
		let cal = Calendar.current

		let rows: [RecurringCost] = scoped
			.filter { $0.itemRecurring && !$0.inactive }
			.compactMap { s in
				let qty = max(1, s.itemRecurringDays)
				let cost = Double(s.itemCost)
				guard cost > 0 else { return nil }

				// Normalize to monthly equivalent
				let monthly: Double
				switch s.itemRecurringInterval {
				case "Day":  monthly = cost * (30.4375 / Double(qty))
				case "Year": monthly = cost / (Double(qty) * 12.0)
				default:     monthly = cost / Double(qty)  // "Month"
				}

				// Compute next due date
				var comps = DateComponents()
				switch s.itemRecurringInterval {
				case "Day":  comps.day   = qty
				case "Year": comps.year  = qty
				default:     comps.month = qty
				}
				var nextDue: Date? = cal.date(byAdding: comps, to: s.lastPayment)
				while let d = nextDue, d <= now {
					nextDue = cal.date(byAdding: comps, to: d)
				}

				// Vehicle display name
				let displayName = vehicles.first(where: { $0.name == s.vehicleId })?.displayName
					.nilIfEmpty ?? s.vehicleId

				return RecurringCost(
					vehicleId: s.vehicleId,
					vehicleDisplayName: displayName,
					itemName: s.itemName,
					category: s.category,
					cost: cost,
					intervalQty: qty,
					intervalUnit: s.itemRecurringInterval,
					monthlyCost: monthly,
					nextDue: nextDue
				)
			}
			.sorted { $0.monthlyCost > $1.monthlyCost }

		self.recurringCosts = rows
	}
}

private extension String {
	var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Card

struct InsuranceExpirationsCard: View {
	let alerts: [DashboardView.InsuranceAlert]
	let recurringCosts: [DashboardView.RecurringCost]
	let formatDate: (Date) -> String
	let formatCurrency: (Double) -> String

	private var monthlyTotal: Double { recurringCosts.reduce(0) { $0 + $1.monthlyCost } }
	private var annualTotal:  Double { monthlyTotal * 12 }

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 10) {

				// ── Recurring Costs ──────────────────────────────────────
				HStack(spacing: 8) {
					Image(systemName: "repeat.circle.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.purple)
					Text("RECURRING COSTS")
						.font(.headline)
					Spacer()
					if monthlyTotal > 0 {
						Text("\(formatCurrency(monthlyTotal))/mo")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}

				if recurringCosts.isEmpty {
					Text("No active recurring costs.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(recurringCosts) { rc in
						RecurringCostRow(rc: rc, formatDate: formatDate, formatCurrency: formatCurrency)
					}
					Divider()
					HStack {
						Text("Annual total")
							.font(.caption)
							.foregroundStyle(.secondary)
						Spacer()
						Text(formatCurrency(annualTotal))
							.font(.caption.monospacedDigit())
							.bold()
					}
				}

				// ── Insurance Expirations ────────────────────────────────
				Divider()
					.padding(.vertical, 2)

				HStack(spacing: 8) {
					Image(systemName: "shield.lefthalf.filled")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.teal)
					Text("INSURANCE EXPIRATIONS")
						.font(.headline)
				}

				if alerts.isEmpty {
					Text("No upcoming expirations within 90 days.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(alerts) { alert in
						HStack {
							VStack(alignment: .leading) {
								Text("\(alert.year) \(alert.vehicleName)")
									.font(.subheadline).bold()
								Text("Expires: \(formatDate(alert.expiration))")
									.font(.caption).foregroundStyle(.secondary)
							}
							Spacer()
							HStack(spacing: 6) {
								if alert.daysRemaining <= 30 {
									if #available(iOS 17, macOS 14, *) {
										Image(systemName: "exclamationmark.circle.fill")
											.foregroundStyle(.red)
											.symbolEffect(.pulse, options: .repeating)
									} else {
										Image(systemName: "exclamationmark.circle.fill")
											.foregroundStyle(.red)
									}
								}
								Text("\(alert.daysRemaining) days")
									.font(.caption.monospacedDigit())
									.foregroundStyle(alert.daysRemaining <= 30 ? .red : (alert.daysRemaining <= 60 ? .orange : .yellow))
							}
						}
						Divider()
					}
				}
			}
		}
	}
}

// MARK: - Shared recurring cost row

struct RecurringCostRow: View {
	let rc: DashboardView.RecurringCost
	let formatDate: (Date) -> String
	let formatCurrency: (Double) -> String

	private var intervalLabel: String {
		let qty = rc.intervalQty
		let unit = rc.intervalUnit.lowercased()
		return "Every \(qty) \(qty == 1 ? unit : unit + "s")"
	}

	var body: some View {
		HStack(spacing: 8) {
			VStack(alignment: .leading, spacing: 2) {
				Text(rc.itemName)
					.font(.caption)
					.fontWeight(.medium)
					.lineLimit(1)
				HStack(spacing: 4) {
					if !rc.vehicleDisplayName.isEmpty {
						Text(rc.vehicleDisplayName)
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("·")
							.font(.caption2)
							.foregroundStyle(.tertiary)
					}
					Text(intervalLabel)
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
			Spacer()
			VStack(alignment: .trailing, spacing: 2) {
				Text(formatCurrency(rc.cost))
					.font(.caption.monospacedDigit())
				if let due = rc.nextDue {
					Text("due \(formatDate(due))")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
		}
	}
}

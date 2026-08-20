import SwiftUI
import SwiftData

extension DashboardView {

	// MARK: - Warranty Data

	struct WarrantyAlert: Identifiable {
		let id = UUID()
		let vehicleDisplayName: String
		let warrantyName: String
		let warrantyType: String
		let expirationDate: Date
		let mileageLimit: Int
		let mileageRemaining: Int   // 0 when no mileage limit recorded
		let hasMileageLimit: Bool
		let status: WarrantyStatus  // worst-case across both dimensions
	}

	enum WarrantyStatus {
		case good, warning, expired
		var color: Color {
			switch self {
			case .good:    return .green
			case .warning: return .yellow
			case .expired: return .red
			}
		}
	}

	func computeWarrantyAlerts() {
		guard let warranties = try? modelContext.fetch(FetchDescriptor<VehicleWarranty>()) else {
			self.warrantyAlerts = []
			return
		}

		let scoped = warranties.filter { includesVehicle($0.vehicleId) }

		let now = Date()
		let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: now) ?? now

		let rows: [WarrantyAlert] = scoped.compactMap { w in
			let vehicle = vehicles.first(where: { $0.name == w.vehicleId })
			let dn = vehicle?.displayName ?? ""
			let displayName = dn.isEmpty ? w.vehicleId : dn

			// Expiration status
			let expStatus: WarrantyStatus
			if w.warrantyExpirationDate < now {
				expStatus = .expired
			} else if w.warrantyExpirationDate <= sixMonths {
				expStatus = .warning
			} else {
				expStatus = .good
			}

			// Mileage status
			let miRemaining: Int
			let miStatus: WarrantyStatus
			if w.warrantyMileageLimit > 0 {
				miRemaining = w.warrantyMileageLimit - (vehicle?.mileage ?? 0)
				if miRemaining <= 0 {
					miStatus = .expired
				} else if miRemaining <= 10000 {
					miStatus = .warning
				} else {
					miStatus = .good
				}
			} else {
				miRemaining = 0
				miStatus = .good
			}

			// Use the worse of the two statuses
			let worst: WarrantyStatus
			if expStatus == .expired || miStatus == .expired {
				worst = .expired
			} else if expStatus == .warning || miStatus == .warning {
				worst = .warning
			} else {
				worst = .good
			}

			return WarrantyAlert(
				vehicleDisplayName: displayName,
				warrantyName: w.warrantyName,
				warrantyType: w.warrantyType,
				expirationDate: w.warrantyExpirationDate,
				mileageLimit: w.warrantyMileageLimit,
				mileageRemaining: miRemaining,
				hasMileageLimit: w.warrantyMileageLimit > 0,
				status: worst
			)
		}
		// Sort: expired first, then warning, then good; alpha within each group
		.sorted {
			let rank: (WarrantyStatus) -> Int = { s in
				switch s { case .expired: return 0; case .warning: return 1; case .good: return 2 }
			}
			if rank($0.status) != rank($1.status) { return rank($0.status) < rank($1.status) }
			return $0.warrantyName < $1.warrantyName
		}

		self.warrantyAlerts = rows
	}
}

// MARK: - Card

struct WarrantyCard: View {
	let alerts: [DashboardView.WarrantyAlert]
	let formatDate: (Date) -> String

	private var expiredCount: Int  { alerts.filter { $0.status == .expired  }.count }
	private var warningCount: Int  { alerts.filter { $0.status == .warning  }.count }

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 8) {
					Image(systemName: "checkmark.seal.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.blue)
					Text("WARRANTIES")
						.font(.headline)
					Spacer()
					if expiredCount > 0 {
						Label("\(expiredCount) expired", systemImage: "exclamationmark.circle.fill")
							.font(.caption2)
							.foregroundStyle(.red)
					} else if warningCount > 0 {
						Label("\(warningCount) expiring", systemImage: "exclamationmark.triangle.fill")
							.font(.caption2)
							.foregroundStyle(.yellow)
					}
				}

				if alerts.isEmpty {
					Text("No warranties recorded.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(alerts) { alert in
						WarrantyRow(alert: alert, formatDate: formatDate)
						Divider()
					}
				}
			}
		}
	}
}

// MARK: - Row

private struct WarrantyRow: View {
	let alert: DashboardView.WarrantyAlert
	let formatDate: (Date) -> String

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Circle()
				.fill(alert.status.color)
				.frame(width: 8, height: 8)
				.padding(.top, 4)

			VStack(alignment: .leading, spacing: 2) {
				Text(alert.warrantyName)
					.font(.caption)
					.fontWeight(.medium)
					.lineLimit(1)
				HStack(spacing: 4) {
					Text(alert.vehicleDisplayName)
						.font(.caption2)
						.foregroundStyle(.secondary)
					if !alert.warrantyType.isEmpty {
						Text("·")
							.font(.caption2)
							.foregroundStyle(.tertiary)
						Text(alert.warrantyType)
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
			}

			Spacer()

			VStack(alignment: .trailing, spacing: 2) {
				Text("Exp: \(formatDate(alert.expirationDate))")
					.font(.caption2.monospacedDigit())
					.foregroundStyle(alert.status.color)
				if alert.hasMileageLimit {
					Text(alert.mileageRemaining > 0 ? "\(alert.mileageRemaining) mi left" : "Miles exceeded")
						.font(.caption2.monospacedDigit())
						.foregroundStyle(alert.status.color)
				}
			}
		}
	}
}

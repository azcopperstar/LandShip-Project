import SwiftUI
import SwiftData

extension DashboardView {
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
		let scopedVehicles: [Vehicle8]
		if trackVehicleSelected != "All Vehicles" && !trackVehicleSelected.isEmpty {
			scopedVehicles = vehicles.filter { $0.name == trackVehicleSelected }
		} else {
			scopedVehicles = vehicles
		}
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
}

struct InsuranceExpirationsCard: View {
	let alerts: [DashboardView.InsuranceAlert]
	let formatDate: (Date) -> String

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
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

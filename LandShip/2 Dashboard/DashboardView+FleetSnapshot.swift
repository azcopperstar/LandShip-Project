import SwiftUI
import SwiftData
import Charts

extension DashboardView {
	struct FleetSnapshot {
		struct VehicleLine: Identifiable, Equatable {
			let id = UUID()
			let name: String
			let displayName: String
			let year: Int
			let manufacturer: String
			let model: String
			let fuelType: String
			let odometer: Int
			let engHours: Float
			let inactive: Bool
		}

		var total: Int = 0
		var active: Int = 0
		var inactive: Int = 0
		var totalMileage: Int = 0
		var totalHours: Double = 0
		var avgMileage: Double = 0
		var avgHours: Double = 0
		var vehicles: [VehicleLine] = []
	}

	func computeFleetSnapshot() {
		// `scopedVehicles` resolves to the DashboardView computed property, which already
		// applies both the toolbar's single-vehicle pick and the saved vehicle scheme.
		guard !scopedVehicles.isEmpty else {
			self.fleetSnapshot = FleetSnapshot()
			return
		}

		let total = scopedVehicles.count
		let inactive = scopedVehicles.filter { $0.inactive }.count
		let active = total - inactive

		let totalMileage = scopedVehicles.reduce(0) { $0 + $1.mileage }
		let totalHours = scopedVehicles.reduce(0.0) { $0 + Double($1.engHours) }

		let avgMileage = Double(totalMileage) / Double(total)
		let avgHours = total == 0 ? 0 : totalHours / Double(total)

		// Active vehicles first, then sorted by odometer descending
		let lines: [FleetSnapshot.VehicleLine] = scopedVehicles
			.sorted { lhs, rhs in
				if lhs.inactive != rhs.inactive { return !lhs.inactive }
				return lhs.mileage > rhs.mileage
			}
			.map {
				let dName = $0.displayName.isEmpty ? $0.name : $0.displayName
				return FleetSnapshot.VehicleLine(
					name: $0.name,
					displayName: dName,
					year: $0.year,
					manufacturer: $0.manufacturer,
					model: $0.model,
					fuelType: $0.fuelType,
					odometer: $0.mileage,
					engHours: $0.engHours,
					inactive: $0.inactive
				)
			}

		self.fleetSnapshot = FleetSnapshot(
			total: total,
			active: active,
			inactive: inactive,
			totalMileage: totalMileage,
			totalHours: totalHours,
			avgMileage: avgMileage,
			avgHours: avgHours,
			vehicles: lines
		)
	}
}

// MARK: - Donut Chart

fileprivate struct DonutChart: View {
	let active: Int
	let inactive: Int

	var total: Double { Double(max(0, active + inactive)) }
	var activeFrac: Double { total == 0 ? 0 : Double(active) / total }
	var inactiveFrac: Double { 1.0 - activeFrac }

	var body: some View {
		ZStack {
			Circle()
				.trim(from: 0, to: CGFloat(inactiveFrac))
				.stroke(Color.gray.opacity(0.45), style: StrokeStyle(lineWidth: 14, lineCap: .round))
				.rotationEffect(.degrees(-90))
			Circle()
				.trim(from: CGFloat(inactiveFrac), to: 1.0)
				.stroke(Color.green, style: StrokeStyle(lineWidth: 14, lineCap: .round))
				.rotationEffect(.degrees(-90))
			Circle().fill(.background).frame(width: 56, height: 56)
			VStack(spacing: 2) {
				Text("\(active)")
					.font(.headline.monospacedDigit())
				Text("Active").font(.caption2).foregroundStyle(.secondary)
			}
		}
		.snappyAnimationIfAvailable(value: active)
		.snappyAnimationIfAvailable(value: inactive)
	}
}

// MARK: - Fleet Snapshot Card (includes Maintenance Cost Snapshot)

struct FleetSnapshotCard: View {
	let fleetSnapshot: DashboardView.FleetSnapshot
	let distanceUnit: String
	let cost: DashboardView.CostSnapshot
	let formatCurrency: (Double) -> String
	let onTapRange: (String, String) -> Void
	let onTapTopItem: (String) -> Void

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 10) {

				// ── Fleet header ─────────────────────────────────────────
				HStack(spacing: 8) {
					Image(systemName: "car.2.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.indigo)
					Text("FLEET SNAPSHOT")
						.font(.headline)
					Spacer()
					if fleetSnapshot.total > 0 {
						Text("\(fleetSnapshot.totalMileage.formatted(.number.grouping(.automatic))) \(distanceUnit) total")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}

				// Donut chart + summary counts
				HStack(alignment: .top, spacing: 16) {
					DonutChart(active: fleetSnapshot.active, inactive: fleetSnapshot.inactive)
						.frame(width: 80, height: 80)

					VStack(alignment: .leading, spacing: 4) {
						HStack(spacing: 6) {
							Circle().fill(Color.green).frame(width: 7, height: 7)
							Text("Active: \(fleetSnapshot.active)")
						}
						HStack(spacing: 6) {
							Circle().fill(Color.gray.opacity(0.5)).frame(width: 7, height: 7)
							Text("Inactive: \(fleetSnapshot.inactive)")
						}
						Text("Total: \(fleetSnapshot.total)")
							.foregroundStyle(.secondary)
						Divider().padding(.vertical, 2)
						Text(String(format: "Avg: %.0f %@ • %.1f h", fleetSnapshot.avgMileage, distanceUnit, fleetSnapshot.avgHours))
							.foregroundStyle(.secondary)
					}
					.font(.caption)
				}
				.padding(.top, 2)

				// Per-vehicle rows
				if !fleetSnapshot.vehicles.isEmpty {
					Divider()
					ForEach(fleetSnapshot.vehicles.prefix(5)) { v in
						VehicleSnapshotRow(vehicle: v, distanceUnit: distanceUnit)
					}
					if fleetSnapshot.vehicles.count > 5 {
						Text("+ \(fleetSnapshot.vehicles.count - 5) more…")
							.font(.caption2)
							.foregroundStyle(.secondary)
							.padding(.leading, 15)
					}
				}

				// ── Maintenance Cost section ──────────────────────────────
				Divider()
					.padding(.vertical, 2)

				HStack(spacing: 8) {
					Image(systemName: "dollarsign.circle.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.green)
					Text("MAINTENANCE COSTS")
						.font(.headline)
				}

				HStack {
					VStack(alignment: .leading, spacing: 3) {
						Text("Month to Date")
						Text("Last 90 Days")
						Text("Year to Date")
					}
					Spacer()
					VStack(alignment: .trailing, spacing: 3) {
						Text(formatCurrency(cost.monthToDate))
						Text(formatCurrency(cost.last90Days))
						Text(formatCurrency(cost.yearToDate))
					}
				}
				.font(.caption)

				Chart {
					BarMark(x: .value("Range", "MTD"), y: .value("Total", cost.monthToDate))
						.foregroundStyle(.green.opacity(0.9))
						.annotation(position: .overlay) {
							Color.clear.contentShape(Rectangle())
								.onTapGesture { onTapRange("Costs • Month to Date", "Would navigate to costs filtered to MTD.") }
						}
					BarMark(x: .value("Range", "90D"), y: .value("Total", cost.last90Days))
						.foregroundStyle(.green.opacity(0.6))
						.annotation(position: .overlay) {
							Color.clear.contentShape(Rectangle())
								.onTapGesture { onTapRange("Costs • Last 90 Days", "Would navigate to costs filtered to last 90 days.") }
						}
					BarMark(x: .value("Range", "YTD"), y: .value("Total", cost.yearToDate))
						.foregroundStyle(.green.opacity(0.4))
						.annotation(position: .overlay) {
							Color.clear.contentShape(Rectangle())
								.onTapGesture { onTapRange("Costs • Year to Date", "Would navigate to costs filtered to YTD.") }
						}
				}
				.chartYAxis(.hidden)
				.frame(height: 100)
				.snappyAnimationIfAvailable(value: cost)

				if !cost.topItems.isEmpty {
					Divider()
					Text("Top items (last 90 days)").font(.subheadline)
					Chart(cost.topItems.prefix(3), id: \.name) { item in
						BarMark(x: .value("Cost", item.total), y: .value("Item", item.name))
							.foregroundStyle(.green.gradient)
							.annotation(position: .overlay, alignment: .trailing) {
								Color.clear.contentShape(Rectangle())
									.onTapGesture { onTapTopItem(item.name) }
							}
					}
					.chartXAxis(.hidden)
					.frame(height: 100)
				}
			}
		}
	}
}

// MARK: - Per-vehicle row (card)

private struct VehicleSnapshotRow: View {
	let vehicle: DashboardView.FleetSnapshot.VehicleLine
	let distanceUnit: String

	private var subtitleText: String {
		var parts: [String] = []
		if vehicle.year > 0 { parts.append(String(vehicle.year)) }
		if !vehicle.manufacturer.isEmpty { parts.append(vehicle.manufacturer) }
		if !vehicle.model.isEmpty { parts.append(vehicle.model) }
		return parts.joined(separator: " ")
	}

	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(vehicle.inactive ? Color.gray.opacity(0.45) : Color.green)
				.frame(width: 7, height: 7)

			VStack(alignment: .leading, spacing: 1) {
				Text(vehicle.displayName)
					.font(.caption)
					.fontWeight(vehicle.inactive ? .regular : .medium)
					.foregroundStyle(vehicle.inactive ? .secondary : .primary)
					.lineLimit(1)
				if !subtitleText.isEmpty {
					Text(subtitleText)
						.font(.caption2)
						.foregroundStyle(.tertiary)
						.lineLimit(1)
				}
			}

			Spacer()

			VStack(alignment: .trailing, spacing: 1) {
				Text("\(vehicle.odometer.formatted(.number.grouping(.automatic))) \(distanceUnit)")
					.font(.caption2).monospacedDigit()
					.foregroundStyle(.secondary)
				if vehicle.engHours > 0 {
					Text(String(format: "%.0f h", vehicle.engHours))
						.font(.caption2).monospacedDigit()
						.foregroundStyle(.tertiary)
				}
			}
		}
	}
}

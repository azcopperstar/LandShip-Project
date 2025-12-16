import SwiftUI
import SwiftData

extension DashboardView {
	struct FleetSnapshot {
		struct VehicleLine: Identifiable, Equatable {
			let id = UUID()
			let name: String
			let odometer: Int
			let engHours: Float
			let inactive: Bool
		}

		var total: Int = 0
		var active: Int = 0
		var inactive: Int = 0
		var avgMileage: Double = 0
		var avgHours: Double = 0
		var vehicles: [VehicleLine] = []
	}

	func computeFleetSnapshot() {
		let scopedVehicles: [Vehicle8]
		if trackVehicleSelected != "All Vehicles" && !trackVehicleSelected.isEmpty {
			scopedVehicles = vehicles.filter { $0.name == trackVehicleSelected }
		} else {
			scopedVehicles = vehicles
		}
		guard !scopedVehicles.isEmpty else {
			self.fleetSnapshot = FleetSnapshot()
			return
		}
		
		let total = scopedVehicles.count
		let inactive = scopedVehicles.filter { $0.inactive }.count
		let active = total - inactive
		
		// Totals used for averages
		let totalMileage = scopedVehicles.reduce(0) { $0 + $1.mileage }
		let totalHours = scopedVehicles.reduce(0.0) { $0 + Double($1.engHours) }
		
		// Averages (safe divide)
		let avgMileage = Double(totalMileage) / Double(total)
		let avgHours = total == 0 ? 0 : totalHours / Double(total)

		// Per-vehicle lines
		let lines: [FleetSnapshot.VehicleLine] = scopedVehicles.map {
			.init(name: $0.name, odometer: $0.mileage, engHours: $0.engHours, inactive: $0.inactive)
		}
		
		self.fleetSnapshot = FleetSnapshot(
			total: total,
			active: active,
			inactive: inactive,
			avgMileage: avgMileage,
			avgHours: avgHours,
			vehicles: lines
		)
	}
}

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

struct FleetSnapshotCard: View {
	let fleetSnapshot: DashboardView.FleetSnapshot
	let distanceUnit: String

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "car.2.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.indigo)
					Text("FLEET SNAPSHOT")
						.font(.headline)
				}
				HStack {
					VStack(alignment: .leading) {
						Text("Vehicles: \(fleetSnapshot.total)")
						Text("Active: \(fleetSnapshot.active)")
						Text("Inactive: \(fleetSnapshot.inactive)")
					}
					Spacer()
					VStack(alignment: .leading, spacing: 8) {
						DonutChart(active: fleetSnapshot.active, inactive: fleetSnapshot.inactive)
							.frame(width: 96, height: 96)
						VStack(alignment: .leading, spacing: 4) {
							HStack {
								Circle().fill(Color.green).frame(width: 8, height: 8)
								Text("Active").font(.caption2)
							}
							HStack {
								Circle().fill(Color.gray).frame(width: 8, height: 8)
								Text("Inactive").font(.caption2)
							}
						}
					}
				}
				.font(.caption)
				.padding(.top, 4)

				HStack {
					Text(String(format: "Avg Mileage: %.0f %@", fleetSnapshot.avgMileage, distanceUnit))
					Text(String(format: " • Avg Hours: %.1f h", fleetSnapshot.avgHours))
				}
				.font(.caption2)
				.foregroundStyle(.secondary)
			}
		}
	}
}

import SwiftUI
import SwiftData
import Charts

extension DashboardView {
	struct UsageSinceLast: Identifiable, Equatable {
		let id = UUID()
		let vehicleName: String
		let milesSince: Int
		let hoursSince: Float
		let lastServiceDate: Date?
	}

	func computeUsageSinceLastService() {
		// `scopedVehicles` resolves to the DashboardView computed property, which already
		// applies both the toolbar's single-vehicle pick and the saved vehicle scheme.
		var rows: [UsageSinceLast] = []
		for v in scopedVehicles {
			let vid = v.name
			var fd = FetchDescriptor<ServiceRecords1>(
				predicate: #Predicate { $0.vehicleId == vid },
				sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
			)
			fd.fetchLimit = 1
			var lastDate: Date? = nil
			var lastMiles: Int = 0
			var lastHours: Float = 0
			do {
				if let rec = try modelContext.fetch(fd).first {
					lastDate = rec.mxDate
					lastMiles = rec.Miles
					lastHours = rec.engHours
				}
			} catch {}
			let milesSince = (lastMiles > 0 && v.mileage >= lastMiles) ? (v.mileage - lastMiles) : 0
			let hoursSince = (lastHours > 0 && v.engHours >= lastHours) ? (v.engHours - lastHours) : 0
			rows.append(UsageSinceLast(vehicleName: v.name, milesSince: milesSince, hoursSince: hoursSince, lastServiceDate: lastDate))
		}
		self.usageSinceLast = rows.sorted {
			if $0.milesSince != $1.milesSince { return $0.milesSince > $1.milesSince }
			return $0.hoursSince > $1.hoursSince
		}
	}
}

struct UsageSinceLastCard: View {
	let rows: [DashboardView.UsageSinceLast]
	let distanceUnit: String
	let formatDate: (Date) -> String
	let onTapVehicle: (String) -> Void

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "speedometer")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.mint)
					Text("USAGE SINCE LAST SERVICE")
						.font(.headline)
				}

				if !rows.isEmpty {
					Chart(rows.prefix(5)) { row in
						BarMark(
							x: .value("Miles", row.milesSince),
							y: .value("Vehicle", row.vehicleName)
						)
						.foregroundStyle(.mint.gradient)
						.annotation(position: .overlay, alignment: .trailing) {
							Color.clear
								.contentShape(Rectangle())
								.onTapGesture { onTapVehicle(row.vehicleName) }
						}
					}
					.chartXAxis(.hidden)
					.chartYAxis {
						AxisMarks(values: .automatic(desiredCount: 5))
					}
					.frame(height: 120)
					.snappyAnimationIfAvailable(value: rows)
					Divider()
				}

				if rows.isEmpty {
					Text("No service history yet.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(rows.prefix(5)) { row in
						HStack {
							VStack(alignment: .leading) {
								Text(row.vehicleName).font(.subheadline).bold()
								if let d = row.lastServiceDate {
									Text("Last serviced: \(formatDate(d))")
										.font(.caption).foregroundStyle(.secondary)
								} else {
									Text("No prior service record")
										.font(.caption).foregroundStyle(.secondary)
								}
							}
							Spacer()
							VStack(alignment: .trailing) {
								if row.milesSince > 0 {
									Text("\(row.milesSince) \(distanceUnit)").font(.caption)
								}
								if row.hoursSince > 0 {
									Text(String(format: "%.1f h", row.hoursSince)).font(.caption)
								}
							}
						}
						Divider()
					}
				}
			}
		}
	}
}

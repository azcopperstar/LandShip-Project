import SwiftUI
import SwiftData
import Charts

extension DashboardView {
	struct DueSummary {
		var overdueMiles: Int = 0
		var overdueHours: Int = 0
		var overdueTime: Int = 0
		var dueSoonCount: Int = 0
		var totalItemsEvaluated: Int = 0
	}

	struct SystemHot: Identifiable, Equatable {
		let id = UUID()
		let system: String
		let overdueCount: Int
		let dueSoonCount: Int
	}

	func recomputeDueSummaryAndSystemHotlist() {
		var fd = FetchDescriptor<MxItems3>()
		if trackVehicleSelected != "All Vehicles" && !trackVehicleSelected.isEmpty {
			fd.predicate = #Predicate { $0.vehicleId == trackVehicleSelected }
		}
		do {
			let items = try modelContext.fetch(fd)
			var summary = DueSummary()
			var systemBuckets: [String: (overdue: Int, soon: Int)] = [:]

			for item in items {
				guard item.intervalMiles > 0 || item.intervalHours > 0 || item.intervalMonths > 0 else { continue }
				let vId = item.vehicleId
				guard let v = functions.loadVehicleDetails(context: modelContext, vehicleId: vId) else { continue }
				let currentMiles = v.mileage
				let currentHours = v.engHours

				var lastDate: Date? = nil
				var lastMiles: Int = 0
				var lastHours: Float = 0.0
				do {
					let mxName = item.mxName
					var fdRec = FetchDescriptor<ServiceRecords1>(
						predicate: #Predicate { $0.vehicleId == vId && $0.mxName == mxName },
						sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
					)
					fdRec.fetchLimit = 1
					if let rec = try modelContext.fetch(fdRec).first {
						lastDate = rec.mxDate
						lastMiles = rec.Miles
						lastHours = rec.engHours
					}
				} catch {}

				let milesSince = (lastMiles > 0 && currentMiles >= lastMiles) ? (currentMiles - lastMiles) : 0
				let hoursSince: Float = (lastHours > 0 && currentHours >= lastHours) ? (currentHours - lastHours) : 0

				let remainingMilesRaw: Int? = (item.intervalMiles > 0) ? (item.intervalMiles - milesSince) : nil
				let remainingHoursRaw: Float? = (item.intervalHours > 0) ? (item.intervalHours - hoursSince) : nil

				var remainingDaysRaw: Int? = nil
				if item.intervalMonths > 0 {
					let anchor = lastDate ?? item.createdAt
					if let d = Calendar(identifier: .gregorian).date(byAdding: .month, value: item.intervalMonths, to: anchor) {
						let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: d).day ?? 0
						remainingDaysRaw = days
					}
				}

				var overdueMiles = false
				var overdueHours = false
				var overdueTime = false
				if let rm = remainingMilesRaw, rm < 0 { overdueMiles = true }
				if let rh = remainingHoursRaw, rh < 0.0 { overdueHours = true }
				if let rd = remainingDaysRaw, rd < 0 { overdueTime = true }

				var soon = false
				if item.intervalMiles > 0, let rm = remainingMilesRaw {
					let frac = Double(max(0, rm)) / Double(max(1, item.intervalMiles))
					if frac <= dueSoonFraction || rm <= milesWindow { soon = true }
				}
				if item.intervalHours > 0, let rh = remainingHoursRaw {
					let frac = Double(max(0.0 as Float, rh)) / Double(max(1.0 as Float, item.intervalHours))
					if frac <= dueSoonFraction || rh <= hoursWindow { soon = true }
				}
				if item.intervalMonths > 0, let rd = remainingDaysRaw {
					let totalDays = max(1, item.intervalMonths * 30)
					let frac = Double(max(0, rd)) / Double(totalDays)
					if frac <= dueSoonFraction || rd <= daysWindow { soon = true }
				}

				summary.totalItemsEvaluated += 1
				if overdueMiles { summary.overdueMiles += 1 }
				if overdueHours { summary.overdueHours += 1 }
				if overdueTime { summary.overdueTime += 1 }
				if !overdueMiles && !overdueHours && !overdueTime && soon {
					summary.dueSoonCount += 1
				}

				let key = item.vehicleSystem
				var bucket = systemBuckets[key, default: (0, 0)]
				if overdueMiles || overdueHours || overdueTime {
					bucket.overdue += 1
				} else if soon {
					bucket.soon += 1
				}
				systemBuckets[key] = bucket
			}

			self.dueSummary = summary
			let sysArray = systemBuckets.map { (k, v) in
				SystemHot(system: k, overdueCount: v.overdue, dueSoonCount: v.soon)
			}
			.sorted { lhs, rhs in
				if lhs.overdueCount != rhs.overdueCount { return lhs.overdueCount > rhs.overdueCount }
				return lhs.dueSoonCount > rhs.dueSoonCount
			}
			self.systemHotlist = sysArray
		} catch {
			self.dueSummary = DueSummary()
			self.systemHotlist = []
		}
	}
}

struct MaintenanceStatusCard: View {
	let dueSummary: DashboardView.DueSummary

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.orange)
					Text("MAINTENANCE STATUS")
						.font(.headline)
				}
				if dueSummary.totalItemsEvaluated == 0 {
					Text("No maintenance items found.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					HStack {
						VStack(alignment: .leading) {
							Text("Overdue").bold()
							Text("• Miles: \(dueSummary.overdueMiles)")
							Text("• Hours: \(dueSummary.overdueHours)")
							Text("• Time: \(dueSummary.overdueTime)")
						}
						Spacer()
						VStack(alignment: .leading) {
							Text("Due soon").bold()
							Text("• Items: \(dueSummary.dueSoonCount)")
							Text("• Evaluated: \(dueSummary.totalItemsEvaluated)")
						}
					}
					.font(.caption)
					.foregroundStyle(.primary)
				}
			}
		}
	}
}

struct SystemHotlistCard: View {
	let systems: [DashboardView.SystemHot]
	let onTapSystem: (String) -> Void

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "flame.fill")
						.symbolRenderingMode(.palette)
						.foregroundStyle(.red, .orange)
					Text("SYSTEM HOTLIST")
						.font(.headline)
				}
				if systems.isEmpty {
					Text("No system activity to highlight.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					Chart {
						ForEach(systems.prefix(5)) { sys in
							BarMark(
								x: .value("Count", sys.overdueCount),
								y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
							)
							.foregroundStyle(.red.gradient)
							.annotation(position: .overlay, alignment: .trailing) {
								Color.clear
									.contentShape(Rectangle())
									.onTapGesture { onTapSystem(sys.system) }
							}
							BarMark(
								x: .value("Count", sys.dueSoonCount),
								y: .value("System", sys.system.isEmpty ? "Unspecified" : sys.system)
							)
							.position(by: .value("Type", "Soon"))
							.foregroundStyle(.orange.gradient)
						}
					}
					.chartXAxis(.hidden)
					.frame(height: 140)
					.snappyAnimationIfAvailable(value: systems)

					Divider()
					ForEach(systems.prefix(5)) { sys in
						HStack {
							Text(sys.system.isEmpty ? "Unspecified" : sys.system).bold()
							Spacer()
							Text("Overdue: \(sys.overdueCount)").font(.caption)
							Text("Soon: \(sys.dueSoonCount)").font(.caption)
						}
						Divider()
					}
				}
			}
		}
	}
}

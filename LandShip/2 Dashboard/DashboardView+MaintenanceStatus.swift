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

	struct VehicleMaintenanceStatus: Identifiable, Equatable {
		let id = UUID()
		let vehicleId: String   // matches vehicle.name / UpcomingDue.vehicleId
		let vehicleName: String
		let overdueCount: Int
		let dueSoonCount: Int
		let okCount: Int
		let totalEvaluated: Int
	}

	func recomputeDueSummaryAndSystemHotlist() {
		var fd = FetchDescriptor<MxItems3>()
		if let ids = scopeIds {
			fd.predicate = #Predicate<MxItems3> { ids.contains($0.vehicleId) }
		}
		do {
			let items = try modelContext.fetch(fd)
			var summary = DueSummary()
			var systemBuckets: [String: (overdue: Int, soon: Int)] = [:]
			var vehicleBuckets: [String: (overdue: Int, soon: Int, ok: Int, total: Int)] = [:]

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

				let isOverdue = overdueMiles || overdueHours || overdueTime

				summary.totalItemsEvaluated += 1
				if overdueMiles { summary.overdueMiles += 1 }
				if overdueHours { summary.overdueHours += 1 }
				if overdueTime { summary.overdueTime += 1 }
				if !isOverdue && soon { summary.dueSoonCount += 1 }

				let sysKey = item.vehicleSystem
				var sysBucket = systemBuckets[sysKey, default: (0, 0)]
				if isOverdue { sysBucket.overdue += 1 } else if soon { sysBucket.soon += 1 }
				systemBuckets[sysKey] = sysBucket

				var vBucket = vehicleBuckets[vId, default: (0, 0, 0, 0)]
				vBucket.total += 1
				if isOverdue { vBucket.overdue += 1 }
				else if soon { vBucket.soon += 1 }
				else { vBucket.ok += 1 }
				vehicleBuckets[vId] = vBucket
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

			let vehicleStatuses = vehicleBuckets.map { (vId, counts) in
				let displayName: String
				if let v = vehicles.first(where: { $0.name == vId }), !v.displayName.isEmpty {
					displayName = v.displayName
				} else {
					displayName = vId
				}
				return VehicleMaintenanceStatus(
					vehicleId: vId,
					vehicleName: displayName,
					overdueCount: counts.overdue,
					dueSoonCount: counts.soon,
					okCount: counts.ok,
					totalEvaluated: counts.total
				)
			}
			.sorted { lhs, rhs in
				if lhs.overdueCount != rhs.overdueCount { return lhs.overdueCount > rhs.overdueCount }
				if lhs.dueSoonCount != rhs.dueSoonCount { return lhs.dueSoonCount > rhs.dueSoonCount }
				return lhs.vehicleName < rhs.vehicleName
			}
			self.vehicleMaintenanceStatuses = vehicleStatuses

		} catch {
			self.dueSummary = DueSummary()
			self.systemHotlist = []
			self.vehicleMaintenanceStatuses = []
		}
	}
}

// MARK: - Fleet Maintenance Status Card

struct MaintenanceStatusCard: View {
	let vehicleStatuses: [DashboardView.VehicleMaintenanceStatus]
	let nextDue: [DashboardView.UpcomingDue]
	let recentServices: [DashboardView.RecentService]
	let dueSummary: DashboardView.DueSummary
	let distanceUnit: String
	let formatDate: (Date) -> String

	private var nextDueByVehicle: [String: DashboardView.UpcomingDue] {
		var result: [String: DashboardView.UpcomingDue] = [:]
		for item in nextDue { if result[item.vehicleId] == nil { result[item.vehicleId] = item } }
		return result
	}

	private var recentByVehicle: [String: [DashboardView.RecentService]] {
		var result: [String: [DashboardView.RecentService]] = [:]
		for rec in recentServices {
			result[rec.vehicleId, default: []].append(rec)
		}
		// recentServices is already sorted newest-first; keep that order, limit to 3
		return result.mapValues { Array($0.prefix(3)) }
	}

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 10) {
				HStack(spacing: 8) {
					Image(systemName: "wrench.and.screwdriver.fill")
						.foregroundStyle(.blue)
					Text("FLEET MAINTENANCE STATUS")
						.font(.headline)
				}

				if vehicleStatuses.isEmpty {
					Text("No maintenance items found.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(vehicleStatuses) { vs in
						VehicleStatusRow(
							status: vs,
							nextDue: nextDueByVehicle[vs.vehicleId],
							recentServices: recentByVehicle[vs.vehicleId] ?? [],
							distanceUnit: distanceUnit,
							formatDate: formatDate
						)
						if vs.id != vehicleStatuses.last?.id {
							Divider()
						}
					}
				}
			}
		}
	}
}

private struct VehicleStatusRow: View {
	let status: DashboardView.VehicleMaintenanceStatus
	let nextDue: DashboardView.UpcomingDue?
	let recentServices: [DashboardView.RecentService]
	let distanceUnit: String
	let formatDate: (Date) -> String

	var statusColor: Color {
		if status.overdueCount > 0 { return .red }
		if status.dueSoonCount > 0 { return .orange }
		if status.totalEvaluated > 0 { return .green }
		return .secondary
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			// Vehicle name + status badges
			HStack(spacing: 8) {
				Circle()
					.fill(statusColor)
					.frame(width: 9, height: 9)

				Text(status.vehicleName)
					.font(.subheadline)
					.lineLimit(1)

				Spacer()

				if status.totalEvaluated == 0 {
					Text("No items")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					HStack(spacing: 10) {
						if status.overdueCount > 0 {
							Label("\(status.overdueCount)", systemImage: "exclamationmark.circle.fill")
								.font(.caption).bold()
								.foregroundStyle(.red)
						}
						if status.dueSoonCount > 0 {
							Label("\(status.dueSoonCount)", systemImage: "clock.fill")
								.font(.caption)
								.foregroundStyle(.orange)
						}
						if status.overdueCount == 0 && status.dueSoonCount == 0 {
							Label("OK", systemImage: "checkmark.circle.fill")
								.font(.caption)
								.foregroundStyle(.green)
						}
					}
				}
			}

			// Next service due
			if let due = nextDue {
				NextDueRow(due: due)
					.padding(.leading, 17)
			}

			// Last 3 service records
			if !recentServices.isEmpty {
				HStack(spacing: 4) {
					Rectangle()
						.fill(Color.secondary.opacity(0.3))
						.frame(height: 1)
					Text("Recent")
						.font(.caption2)
						.foregroundStyle(.secondary)
					Rectangle()
						.fill(Color.secondary.opacity(0.3))
						.frame(height: 1)
				}
				.padding(.leading, 17)
				.padding(.top, 2)

				ForEach(recentServices) { rec in
					HStack(spacing: 5) {
						Image(systemName: "checkmark.circle")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text(rec.mxName)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
						Spacer()
						if rec.miles > 0 {
							Text("\(rec.miles) \(distanceUnit)")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
						Text(formatDate(rec.mxDate))
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
					.padding(.leading, 17)
				}
			}
		}
	}
}


// MARK: - Shared next-due sub-row (used in card and detail view)

struct NextDueRow: View {
	let due: DashboardView.UpcomingDue

	var isOverdue: Bool { due.score < 0.001 }

	var urgencyColor: Color {
		if isOverdue { return .red }
		if due.score < 0.10 { return .orange }
		return .secondary
	}

	var remainingText: String {
		var parts: [String] = []
		if let rm = due.remainingMiles, due.intervalMiles > 0 {
			parts.append(isOverdue ? "0 mi" : "\(rm) mi")
		}
		if let rh = due.remainingHours, due.intervalHours > 0 {
			parts.append(isOverdue ? "0 hrs" : "\(Int(rh)) hrs")
		}
		if let rd = due.remainingDays, due.intervalMonths > 0 {
			parts.append(isOverdue ? "0 days" : "\(rd) days")
		}
		return parts.joined(separator: " / ")
	}

	var body: some View {
		HStack(spacing: 5) {
			Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "arrow.right.circle")
				.font(.caption2)
				.foregroundStyle(urgencyColor)
			Text(due.itemName)
				.font(.caption)
				.foregroundStyle(.primary)
				.lineLimit(1)
			Spacer()
			if isOverdue {
				Text("OVERDUE")
					.font(.caption2).bold()
					.foregroundStyle(.red)
			} else if !remainingText.isEmpty {
				Text(remainingText)
					.font(.caption2)
					.foregroundStyle(urgencyColor)
			}
		}
	}
}

// MARK: - System Hotlist Card

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

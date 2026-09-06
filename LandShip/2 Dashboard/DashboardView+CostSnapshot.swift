import SwiftUI
import SwiftData
import Charts

extension DashboardView {
	struct TopItem: Equatable {
		let name: String
		let total: Double
	}
	struct CostSnapshot: Equatable {
		var monthToDate: Double = 0
		var last90Days: Double = 0
		var yearToDate: Double = 0
		var topItems: [TopItem] = []
	}

	func computeCostSnapshot() {
		let now = Date()
		let cal = Calendar.current

		guard
			let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
			let startOfYear = cal.date(from: cal.dateComponents([.year], from: now)),
			let ninetyDaysAgo = cal.date(byAdding: .day, value: -90, to: now)
		else {
			self.costSnapshot = CostSnapshot()
			return
		}

		func partsTotal(for r: ServiceRecords1) -> Double {
			let parts: [(Double, Double)] = [
				(Double(r.part1cost), Double(r.part1Quantity)),
				(Double(r.part2cost), Double(r.part2Quantity)),
				(Double(r.part3cost), Double(r.part3Quantity)),
				(Double(r.part4cost), Double(r.part4Quantity)),
				(Double(r.part5cost), Double(r.part5Quantity))
			]
			return parts.reduce(0.0) { $0 + ($1.0 * $1.1) }
		}

		func subItemsLabor(for r: ServiceRecords1) -> Double {
			Double(r.subItem1LaborCost) + Double(r.subItem2LaborCost) + Double(r.subItem3LaborCost)
				+ Double(r.subItem4LaborCost) + Double(r.subItem5LaborCost)
		}

		func totalForRange(_ start: Date, _ end: Date, ids: [String]?) -> Double {
			var predicate: Predicate<ServiceRecords1>
			if let ids = ids {
				predicate = #Predicate { $0.mxDate >= start && $0.mxDate <= end && ids.contains($0.vehicleId) }
			} else {
				predicate = #Predicate { $0.mxDate >= start && $0.mxDate <= end }
			}
			let fd = FetchDescriptor<ServiceRecords1>(predicate: predicate)
			do {
				let recs = try modelContext.fetch(fd)
				return recs.reduce(0.0) { sum, r in
					let labor = Double(r.laborCost)
					let parts = partsTotal(for: r)
					return sum + labor + parts + subItemsLabor(for: r)
				}
			} catch {
				return 0.0
			}
		}

		let ids = scopeIds

		let mtd = totalForRange(startOfMonth, now, ids: ids)
		let last90 = totalForRange(ninetyDaysAgo, now, ids: ids)
		let ytd = totalForRange(startOfYear, now, ids: ids)

		// Top items by spend (last 90 days)
		var predTop: Predicate<ServiceRecords1>
		if let ids = ids {
			predTop = #Predicate { $0.mxDate >= ninetyDaysAgo && $0.mxDate <= now && ids.contains($0.vehicleId) }
		} else {
			predTop = #Predicate { $0.mxDate >= ninetyDaysAgo && $0.mxDate <= now }
		}
		let fdTop = FetchDescriptor<ServiceRecords1>(predicate: predTop)
		var top: [TopItem] = []
		do {
			let recs = try modelContext.fetch(fdTop)
			var buckets: [String: Double] = [:]
			for r in recs {
				let labor = Double(r.laborCost)
				let parts = partsTotal(for: r)
				let total = labor + parts + subItemsLabor(for: r)
				buckets[r.mxName, default: 0.0] += total
			}
			top = buckets
				.map { TopItem(name: $0.key, total: $0.value) }
				.sorted { $0.total > $1.total }
		} catch {
			top = []
		}

		self.costSnapshot = CostSnapshot(monthToDate: mtd, last90Days: last90, yearToDate: ytd, topItems: top)
	}
}

struct CostSnapshotCard: View {
	let cost: DashboardView.CostSnapshot
	let formatCurrency: (Double) -> String
	let onTapRange: (String, String) -> Void
	let onTapTopItem: (String) -> Void

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "dollarsign.circle.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.green)
					Text("MAINTENANCE COST SNAPSHOT")
						.font(.headline)
				}
				HStack {
					VStack(alignment: .leading) {
						Text("Month to Date")
						Text("Last 90 Days")
						Text("Year to Date")
					}
					Spacer()
					VStack(alignment: .trailing) {
						Text(formatCurrency(cost.monthToDate))
						Text(formatCurrency(cost.last90Days))
						Text(formatCurrency(cost.yearToDate))
					}
				}
				.font(.caption)

				Chart {
					BarMark(
						x: .value("Range", "MTD"),
						y: .value("Total", cost.monthToDate)
					)
					.foregroundStyle(.green.opacity(0.9))
					.annotation(position: .overlay) {
						Color.clear
							.contentShape(Rectangle())
							.onTapGesture {
								onTapRange("Costs • Month to Date", "Would navigate to costs filtered to MTD.")
							}
					}
					BarMark(
						x: .value("Range", "90D"),
						y: .value("Total", cost.last90Days)
					)
					.foregroundStyle(.green.opacity(0.6))
					.annotation(position: .overlay) {
						Color.clear
							.contentShape(Rectangle())
							.onTapGesture {
								onTapRange("Costs • Last 90 Days", "Would navigate to costs filtered to last 90 days.")
							}
					}
					BarMark(
						x: .value("Range", "YTD"),
						y: .value("Total", cost.yearToDate)
					)
					.foregroundStyle(.green.opacity(0.4))
					.annotation(position: .overlay) {
						Color.clear
							.contentShape(Rectangle())
							.onTapGesture {
								onTapRange("Costs • Year to Date", "Would navigate to costs filtered to YTD.")
							}
					}
				}
				.chartYAxis(.hidden)
				.frame(height: 120)
				.snappyAnimationIfAvailable(value: cost)

				if !cost.topItems.isEmpty {
					Divider()
					Text("Top items (last 90 days)").font(.subheadline)

					Chart(cost.topItems.prefix(3), id: \.name) { item in
						BarMark(
							x: .value("Cost", item.total),
							y: .value("Item", item.name)
						)
						.foregroundStyle(.green.gradient)
						.annotation(position: .overlay, alignment: .trailing) {
							Color.clear
								.contentShape(Rectangle())
								.onTapGesture { onTapTopItem(item.name) }
						}
					}
					.chartXAxis(.hidden)
					.frame(height: 120)
				}
			}
		}
	}
}

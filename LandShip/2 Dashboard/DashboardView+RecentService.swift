import SwiftUI
import SwiftData

extension DashboardView {
	struct RecentService: Identifiable {
		let id = UUID()
		let mxDate: Date
		let vehicleId: String
		let mxName: String
		let miles: Int
		let hours: Float
	}

	func fetchRecentServices(limit: Int = 30) {
		let sort = [SortDescriptor(\ServiceRecords1.mxDate, order: .reverse),
								SortDescriptor(\.updatedAt, order: .reverse)]
		var fd = FetchDescriptor<ServiceRecords1>(sortBy: sort)
		if let ids = scopeIds {
			fd.predicate = #Predicate<ServiceRecords1> { ids.contains($0.vehicleId) }
		}
		fd.fetchLimit = limit
		do {
			let recs = try modelContext.fetch(fd)
			self.recentServices = recs.map {
				RecentService(mxDate: $0.mxDate, vehicleId: $0.vehicleId, mxName: $0.mxName, miles: $0.Miles, hours: $0.engHours)
			}
		} catch {
			self.recentServices = []
		}
	}
}

struct RecentServiceCard: View {
	let recentServices: [DashboardView.RecentService]
	let distanceUnit: String
	let formatDate: (Date) -> String
	let vehicleDisplayName: (String) -> String

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "clock.arrow.circlepath")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.blue)
					Text("RECENTLY COMPLETED SERVICE")
						.font(.headline)
				}
				if recentServices.isEmpty {
					Text("No recent service records.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					ForEach(recentServices) { rec in
						HStack {
							VStack(alignment: .leading, spacing: 2) {
								Text(rec.mxName).font(.subheadline).bold()
								Text("\(vehicleDisplayName(rec.vehicleId)) • \(formatDate(rec.mxDate))")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							Spacer()
							VStack(alignment: .trailing, spacing: 2) {
								if rec.miles > 0 {
									Text("\(rec.miles) \(distanceUnit)").font(.caption)
								}
								if rec.hours > 0 {
									Text(String(format: "%.1f h", rec.hours)).font(.caption)
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

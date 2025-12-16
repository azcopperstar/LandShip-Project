import SwiftUI
import SwiftData

extension DashboardView {
	struct UpcomingDue: Identifiable, Equatable {
		let id = UUID()
		let vehicleId: String
		let itemName: String
		let itemDescription: String
		let intervalMiles: Int
		let intervalHours: Float
		let intervalMonths: Int
		let remainingMiles: Int?
		let remainingHours: Float?
		let remainingDays: Int?
		let dueDate: Date?
		let score: Double // lower is more urgent
	}

	// Compute the “next service due” rows for the dashboard card.
	// If All Vehicles: show the single most-urgent item per vehicle (so multiple vehicles can appear).
	// If a specific vehicle is selected: show the two most-urgent items for that vehicle.
	func recomputeNextDue() {
		var fd = FetchDescriptor<MxItems3>()
		if trackVehicleSelected != "All Vehicles" && !trackVehicleSelected.isEmpty {
			fd.predicate = #Predicate { $0.vehicleId == trackVehicleSelected }
		}

		do {
			let items = try modelContext.fetch(fd)
			var computed: [UpcomingDue] = []

			for item in items {
				guard item.intervalMiles > 0 || item.intervalHours > 0 || item.intervalMonths > 0 else { continue }
				let vId = item.vehicleId
				guard let v = functions.loadVehicleDetails(context: modelContext, vehicleId: vId) else { continue }

				let currentMiles = v.mileage
				let currentHours = v.engHours

				// Last service record for this vehicle+item
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

				// Since-service
				let milesSince = (lastMiles > 0 && currentMiles >= lastMiles) ? (currentMiles - lastMiles) : 0
				let hoursSince = (lastHours > 0 && currentHours >= lastHours) ? (currentHours - lastHours) : 0

				// Remaining to due (non-negative for dashboard display)
				let remainingMiles: Int? = item.intervalMiles > 0 ? max(0, item.intervalMiles - milesSince) : nil
				let remainingHours: Float? = item.intervalHours > 0 ? max(0, item.intervalHours - hoursSince) : nil

				// Time-based due
				var dueDate: Date? = nil
				var remainingDays: Int? = nil
				if item.intervalMonths > 0 {
					let anchor = lastDate ?? item.createdAt
					if let d = Calendar(identifier: .gregorian).date(byAdding: .month, value: item.intervalMonths, to: anchor) {
						dueDate = d
						let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: d).day ?? 0
						remainingDays = max(0, days)
					}
				}

				// Ranking score (lower is more urgent)
				var factors: [Double] = []
				if let rm = remainingMiles, item.intervalMiles > 0 { factors.append(Double(rm) / Double(item.intervalMiles)) }
				if let rh = remainingHours, item.intervalHours > 0 { factors.append(Double(rh) / Double(item.intervalHours)) }
				if let rd = remainingDays, item.intervalMonths > 0 {
					let totalDays = max(1, item.intervalMonths * 30)
					factors.append(Double(rd) / Double(totalDays))
				}
				guard !factors.isEmpty else { continue }
				let score = factors.min() ?? 1.0

				computed.append(
					UpcomingDue(
						vehicleId: vId,
						itemName: item.mxName,
						itemDescription: item.mxDescription,
						intervalMiles: item.intervalMiles,
						intervalHours: item.intervalHours,
						intervalMonths: item.intervalMonths,
						remainingMiles: remainingMiles,
						remainingHours: remainingHours,
						remainingDays: remainingDays,
						dueDate: dueDate,
						score: score
					)
				)
			}

			let compare: (UpcomingDue, UpcomingDue) -> Bool = { a, b in
				if a.score != b.score { return a.score < b.score }
				if let d0 = a.dueDate, let d1 = b.dueDate, d0 != d1 { return d0 < d1 }
				let m0 = a.remainingMiles ?? Int.max
				let m1 = b.remainingMiles ?? Int.max
				if m0 != m1 { return m0 < m1 }
				let h0 = a.remainingHours ?? Float.greatestFiniteMagnitude
				let h1 = b.remainingHours ?? Float.greatestFiniteMagnitude
				return h0 < h1
			}

			if trackVehicleSelected == "All Vehicles" || trackVehicleSelected.isEmpty {
				// Best single item per vehicle
				let grouped = Dictionary(grouping: computed, by: { $0.vehicleId })
				var results: [UpcomingDue] = []
				for arr in grouped.values {
					if let best = arr.sorted(by: compare).first {
						results.append(best)
					}
				}
				self.nextTwoDue = results.sorted(by: compare)
			} else {
				// Specific vehicle: show top two items
				self.nextTwoDue = Array(computed.sorted(by: compare).prefix(2))
			}
		} catch {
			self.nextTwoDue = []
		}
	}
}

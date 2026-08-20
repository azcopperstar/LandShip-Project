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
		let currentMiles: Int
		let currentHours: Float
		let lastServiceDate: Date?
		let lastServiceMiles: Int
		let lastServiceHours: Float
		let derivedIntervalMiles: Int?
		let derivedIntervalHours: Float?
		let derivedIntervalMonths: Int?
		let remainingMiles: Int?
		let remainingHours: Float?
		let remainingDays: Int?
		let dueAtMiles: Int?   // actual odometer reading when service is due
		let dueDate: Date?
		let score: Double // lower is more urgent
	}

	// Compute the “next service due” rows for the dashboard card.
	// If All Vehicles: show the single most-urgent item per vehicle (so multiple vehicles can appear).
	// If a specific vehicle is selected: show the two most-urgent items for that vehicle.
	func recomputeNextDue() {
		var fd = FetchDescriptor<MxItems3>()
		if let ids = scopeIds {
			fd.predicate = #Predicate<MxItems3> { ids.contains($0.vehicleId) }
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

				// Fetch last 2 records — derive actual interval if history exists, else fall back to database values
				var lastDate: Date? = nil
				var lastMiles: Int = 0
				var lastHours: Float = 0.0
				var capturedDerivedMiles: Int? = nil
				var capturedDerivedHours: Float? = nil
				var capturedDerivedMonths: Int? = nil
				var effectiveIntervalMiles: Int = item.intervalMiles
				var effectiveIntervalHours: Float = item.intervalHours
				var effectiveIntervalMonths: Int = item.intervalMonths
				do {
					let mxName = item.mxName
					var fdRec = FetchDescriptor<ServiceRecords1>(
						predicate: #Predicate { $0.vehicleId == vId && $0.mxName == mxName },
						sortBy: [SortDescriptor(\.mxDate, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
					)
					fdRec.fetchLimit = 2
					let recs = try modelContext.fetch(fdRec)
					if let rec0 = recs.first {
						lastDate  = rec0.mxDate
						lastMiles = rec0.Miles
						lastHours = rec0.engHours
						if recs.count >= 2 {
							let rec1 = recs[1]
							let derivedMiles = rec0.Miles - rec1.Miles
							if derivedMiles > 0 { effectiveIntervalMiles = derivedMiles }
							let derivedHours = rec0.engHours - rec1.engHours
							if derivedHours > 0 { effectiveIntervalHours = derivedHours }
							let derivedMonths = Calendar(identifier: .gregorian)
								.dateComponents([.month], from: rec1.mxDate, to: rec0.mxDate).month ?? 0
							if derivedMonths > 0 { effectiveIntervalMonths = derivedMonths }
							capturedDerivedMiles = derivedMiles > 0 ? derivedMiles : nil
							capturedDerivedHours = derivedHours > 0 ? derivedHours : nil
							capturedDerivedMonths = derivedMonths > 0 ? derivedMonths : nil
						}
					}
				} catch {}

				// Since last service
				let milesSince = (lastMiles > 0 && currentMiles >= lastMiles) ? (currentMiles - lastMiles) : 0
				let hoursSince = (lastHours > 0 && currentHours >= lastHours) ? (currentHours - lastHours) : 0

				// Remaining to due using effective intervals
				let remainingMiles: Int? = effectiveIntervalMiles > 0 ? max(0, effectiveIntervalMiles - milesSince) : nil
				let remainingHours: Float? = effectiveIntervalHours > 0 ? max(0, effectiveIntervalHours - hoursSince) : nil
				// Odometer reading when service is due (can be past current if overdue)
				let dueAtMiles: Int? = effectiveIntervalMiles > 0 ? (currentMiles + (effectiveIntervalMiles - milesSince)) : nil

				// Time-based due
				var dueDate: Date? = nil
				var remainingDays: Int? = nil
				if effectiveIntervalMonths > 0 {
					let anchor = lastDate ?? item.createdAt
					if let d = Calendar(identifier: .gregorian).date(byAdding: .month, value: effectiveIntervalMonths, to: anchor) {
						dueDate = d
						let days = Calendar(identifier: .gregorian).dateComponents([.day], from: Date(), to: d).day ?? 0
						remainingDays = max(0, days)
					}
				}

				// Ranking score (lower is more urgent)
				var factors: [Double] = []
				if let rm = remainingMiles, effectiveIntervalMiles > 0 { factors.append(Double(rm) / Double(effectiveIntervalMiles)) }
				if let rh = remainingHours, effectiveIntervalHours > 0 { factors.append(Double(rh) / Double(effectiveIntervalHours)) }
				if let rd = remainingDays, effectiveIntervalMonths > 0 {
					let totalDays = max(1, effectiveIntervalMonths * 30)
					factors.append(Double(rd) / Double(totalDays))
				}
				guard !factors.isEmpty else { continue }
				let score = factors.min() ?? 1.0

				computed.append(
					UpcomingDue(
						vehicleId: vId,
						itemName: item.mxName,
						itemDescription: item.mxDescription,
						intervalMiles: effectiveIntervalMiles,
						intervalHours: effectiveIntervalHours,
						intervalMonths: effectiveIntervalMonths,
						currentMiles: currentMiles,
						currentHours: currentHours,
						lastServiceDate: lastDate,
						lastServiceMiles: lastMiles,
						lastServiceHours: lastHours,
						derivedIntervalMiles: capturedDerivedMiles,
						derivedIntervalHours: capturedDerivedHours,
						derivedIntervalMonths: capturedDerivedMonths,
						remainingMiles: remainingMiles,
						remainingHours: remainingHours,
						remainingDays: remainingDays,
						dueAtMiles: dueAtMiles,
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

			// Group by vehicle, top 3 per vehicle, vehicles sorted by their most urgent item
			let grouped = Dictionary(grouping: computed, by: { $0.vehicleId })
			let vehiclesSorted = grouped.keys.sorted {
				let sA = grouped[$0]!.min(by: { compare($0, $1) })?.score ?? 1.0
				let sB = grouped[$1]!.min(by: { compare($0, $1) })?.score ?? 1.0
				return sA < sB
			}
			var results: [UpcomingDue] = []
			for vId in vehiclesSorted {
				let top3 = Array(grouped[vId]!.sorted(by: compare).prefix(3))
				results.append(contentsOf: top3)
			}
			self.nextTwoDue = results
		} catch {
			self.nextTwoDue = []
		}
	}
}

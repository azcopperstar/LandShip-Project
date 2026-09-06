import SwiftUI
import SwiftData

extension DashboardView {
	struct InventoryAlert: Identifiable, Equatable {
		let id = UUID()
		let partName: String
		let vehicleId: String
		let quantityOnHand: Float
		let reorderPoint: Float
		let reorderQuantity: Float
		let unit: String

		var isOutOfStock: Bool { quantityOnHand <= 0 }
		var isLowStock: Bool { quantityOnHand <= reorderPoint }
	}

	/// Loads every inventory-tracked part in scope and flags those at or below their reorder point.
	/// Parts with no vehicle assignment (`vehicleId.isEmpty`, i.e. shared/shop stock) are always
	/// included regardless of the vehicle scope, matching how "All Vehicles" parts behave elsewhere.
	func computeInventoryStatus() {
		let fd = FetchDescriptor<MxParts1>(predicate: #Predicate<MxParts1> { $0.inventoryTracked == true })
		do {
			let parts = try modelContext.fetch(fd)
			let scoped = parts.filter { $0.vehicleId.isEmpty || includesVehicle($0.vehicleId) }
			let alerts = scoped.map { p in
				InventoryAlert(
					partName: p.partName,
					vehicleId: p.vehicleId,
					quantityOnHand: p.inventoryQuantityOnHand,
					reorderPoint: p.inventoryReorderPoint,
					reorderQuantity: p.inventoryReorderQuantity,
					unit: p.partUnit
				)
			}
			.sorted { lhs, rhs in
				if lhs.isOutOfStock != rhs.isOutOfStock { return lhs.isOutOfStock && !rhs.isOutOfStock }
				if lhs.isLowStock != rhs.isLowStock { return lhs.isLowStock && !rhs.isLowStock }
				return lhs.partName < rhs.partName
			}
			self.inventoryAlerts = alerts
		} catch {
			self.inventoryAlerts = []
		}
	}
}

// MARK: - Inventory Status Card

struct InventoryStatusCard: View {
	let alerts: [DashboardView.InventoryAlert]
	let vehicleDisplayName: (String) -> String

	private var lowStock: [DashboardView.InventoryAlert] { alerts.filter { $0.isLowStock } }

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "shippingbox.fill")
						.foregroundStyle(.brown)
					Text("INVENTORY STATUS")
						.font(.headline)
				}
				if alerts.isEmpty {
					Text("No inventory-tracked parts yet.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else if lowStock.isEmpty {
					Label("All \(alerts.count) tracked parts are adequately stocked.", systemImage: "checkmark.circle.fill")
						.font(.subheadline)
						.foregroundStyle(.green)
				} else {
					ForEach(lowStock.prefix(5)) { alert in
						InventoryAlertRow(alert: alert, vehicleDisplayName: vehicleDisplayName)
						if alert.id != lowStock.prefix(5).last?.id {
							Divider()
						}
					}
					if lowStock.count > 5 {
						Text("+ \(lowStock.count - 5) more low-stock part(s)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
	}
}

struct InventoryAlertRow: View {
	let alert: DashboardView.InventoryAlert
	let vehicleDisplayName: (String) -> String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: alert.isOutOfStock ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
				.font(.caption)
				.foregroundStyle(alert.isOutOfStock ? .red : .orange)
			VStack(alignment: .leading, spacing: 1) {
				Text(alert.partName)
					.font(.subheadline)
					.lineLimit(1)
				if !alert.vehicleId.isEmpty {
					Text(vehicleDisplayName(alert.vehicleId))
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
			Spacer()
			Text(alert.isOutOfStock ? "OUT OF STOCK" : "\(alert.quantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(alert.unit) left")
				.font(.caption)
				.bold()
				.foregroundStyle(alert.isOutOfStock ? .red : .orange)
		}
	}
}

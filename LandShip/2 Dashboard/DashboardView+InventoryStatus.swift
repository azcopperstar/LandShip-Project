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
		let supplierName: String
		let supplierWebsite: String

		var isOutOfStock: Bool { quantityOnHand <= 0 }
		var isLowStock: Bool { quantityOnHand <= reorderPoint }

		/// The supplier's website as a `URL`, if one is set and well-formed.
		var supplierWebsiteURL: URL? {
			guard !supplierWebsite.isEmpty else { return nil }
			return URL(string: supplierWebsite)
		}
	}

	/// Loads every inventory-tracked part in scope and flags those at or below their reorder point.
	/// Parts with no vehicle assignment (`vehicleId.isEmpty`, i.e. shared/shop stock) are always
	/// included regardless of the vehicle scope, matching how "All Vehicles" parts behave elsewhere.
	func computeInventoryStatus() {
		let fd = FetchDescriptor<MxParts1>(predicate: #Predicate<MxParts1> { $0.inventoryTracked == true })
		do {
			let parts = try modelContext.fetch(fd)
			let scoped = parts.filter { $0.vehicleId.isEmpty || includesVehicle($0.vehicleId) }

			// Resolve each part's supplier (by name, the app's usual linking convention) once,
			// so a reorder alert can offer a direct link to that supplier's website.
			let vendors = (try? modelContext.fetch(FetchDescriptor<Vendors1>())) ?? []
			let vendorsByName = Dictionary(uniqueKeysWithValues: vendors.map { ($0.vendorName, $0) })

			let alerts = scoped.map { p in
				let vendor = vendorsByName[p.partSupplier]
				return InventoryAlert(
					partName: p.partName,
					vehicleId: p.vehicleId,
					quantityOnHand: p.inventoryQuantityOnHand,
					reorderPoint: p.inventoryReorderPoint,
					reorderQuantity: p.inventoryReorderQuantity,
					unit: p.partUnit,
					supplierName: vendor?.vendorName ?? p.partSupplier,
					supplierWebsite: vendor?.vendorWebsite ?? ""
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
		VStack(alignment: .leading, spacing: 3) {
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
			// Reorder guidance — how many to order, and a direct link to the supplier's
			// website when one is on file (resolved from the part's Supplier, by name).
			if alert.isLowStock && alert.reorderQuantity > 0 {
				HStack(spacing: 4) {
					Image(systemName: "cart.fill")
						.font(.caption2)
						.foregroundStyle(.secondary)
					Text("Order \(alert.reorderQuantity.formatted(.number.precision(.fractionLength(0...2)))) \(alert.unit)")
						.font(.caption2)
						.foregroundStyle(.secondary)
					if let url = alert.supplierWebsiteURL {
						Text("·")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Link("Reorder from \(alert.supplierName)", destination: url)
							.font(.caption2)
					}
				}
				.padding(.leading, 20)
			}
		}
	}
}

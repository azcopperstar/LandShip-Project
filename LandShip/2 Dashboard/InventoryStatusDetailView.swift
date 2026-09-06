import SwiftUI

struct InventoryStatusDetailView: View {
	let alerts: [DashboardView.InventoryAlert]
	let vehicleDisplayName: (String) -> String

	private var outOfStock: [DashboardView.InventoryAlert] { alerts.filter { $0.isOutOfStock } }
	private var lowStock: [DashboardView.InventoryAlert] { alerts.filter { $0.isLowStock && !$0.isOutOfStock } }
	private var wellStocked: [DashboardView.InventoryAlert] { alerts.filter { !$0.isLowStock } }

	var body: some View {
		ScrollView {
			VStack(spacing: 12) {
				CardView {
					VStack(alignment: .leading, spacing: 8) {
						HStack(spacing: 8) {
							Image(systemName: "shippingbox.fill")
								.foregroundStyle(.brown)
							Text("SUMMARY")
								.font(.headline)
						}
						HStack {
							VStack(alignment: .leading) {
								Text("Tracked Parts").bold()
								Text("\(alerts.count)")
							}
							Spacer()
							VStack(alignment: .leading) {
								Text("Low Stock").bold()
								Text("\(lowStock.count + outOfStock.count)")
									.foregroundStyle((outOfStock.isEmpty && lowStock.isEmpty) ? Color.primary : Color.orange)
							}
							Spacer()
							VStack(alignment: .leading) {
								Text("Out of Stock").bold()
								Text("\(outOfStock.count)")
									.foregroundStyle(outOfStock.isEmpty ? Color.primary : Color.red)
							}
						}
						.font(.subheadline)
					}
				}

				if !outOfStock.isEmpty {
					CardView {
						VStack(alignment: .leading, spacing: 8) {
							HStack(spacing: 8) {
								Image(systemName: "xmark.circle.fill")
									.foregroundStyle(.red)
								Text("OUT OF STOCK")
									.font(.headline)
							}
							ForEach(outOfStock) { alert in
								InventoryAlertRow(alert: alert, vehicleDisplayName: vehicleDisplayName)
								if alert.id != outOfStock.last?.id { Divider() }
							}
						}
					}
				}

				if !lowStock.isEmpty {
					CardView {
						VStack(alignment: .leading, spacing: 8) {
							HStack(spacing: 8) {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundStyle(.orange)
								Text("LOW STOCK")
									.font(.headline)
							}
							ForEach(lowStock) { alert in
								InventoryAlertRow(alert: alert, vehicleDisplayName: vehicleDisplayName)
								if alert.id != lowStock.last?.id { Divider() }
							}
						}
					}
				}

				if !wellStocked.isEmpty {
					CardView {
						VStack(alignment: .leading, spacing: 8) {
							HStack(spacing: 8) {
								Image(systemName: "checkmark.circle.fill")
									.foregroundStyle(.green)
								Text("WELL STOCKED")
									.font(.headline)
							}
							ForEach(wellStocked) { alert in
								HStack {
									Text(alert.partName)
										.font(.subheadline)
									if !alert.vehicleId.isEmpty {
										Text(vehicleDisplayName(alert.vehicleId))
											.font(.caption2)
											.foregroundStyle(.secondary)
									}
									Spacer()
									Text("\(alert.quantityOnHand.formatted(.number.precision(.fractionLength(0...2)))) \(alert.unit)")
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								if alert.id != wellStocked.last?.id { Divider() }
							}
						}
					}
				}

				if alerts.isEmpty {
					CardView {
						Text("No parts are marked as inventory-tracked yet. Enable \"Track Inventory for this Part\" on a part to see it here.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
			}
			.padding()
		}
		.navigationTitle("Inventory Status")
	}
}

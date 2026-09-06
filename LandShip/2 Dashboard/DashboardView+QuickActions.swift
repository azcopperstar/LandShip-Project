import SwiftUI

struct QuickActionsCard: View {
	var onNavigate: (SidebarItem) -> Void

	var body: some View {
		CardView {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 8) {
					Image(systemName: "plus.circle.fill")
						.symbolRenderingMode(.hierarchical)
						.foregroundStyle(.blue)
					Text("QUICK ACTIONS")
						.font(.headline)
				}
				HStack {
					Button {
						onNavigate(.records)
					} label: {
						Text("Add Service Record")
					}
					.buttonStyle(GrowingButton(buttonColor: .blue))

					Button {
						onNavigate(.items)
					} label: {
						Text("Add Service Item")
					}
					.buttonStyle(GrowingButton(buttonColor: .green))
				}
				.font(.caption)
			}
		}
	}
}

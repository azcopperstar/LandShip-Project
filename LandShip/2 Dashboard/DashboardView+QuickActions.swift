import SwiftUI

struct QuickActionsCard: View {
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
						// Hook up navigation to your Add Service Record screen
					} label: {
						Text("Add Service Record")
					}
					.buttonStyle(GrowingButton(buttonColor: .blue))

					Button {
						// Hook up navigation to your Add Service Item screen
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

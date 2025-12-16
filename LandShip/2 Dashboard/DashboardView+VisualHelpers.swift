import SwiftUI

struct ProgressRing: View {
	let value: Double // 0...1
	let label: String
	let detail: String

	private var ringColor: Color {
		switch value {
		case 0.0..<0.15: return .red
		case 0.15..<0.35: return .orange
		case 0.35..<0.65: return .yellow
		default: return .green
		}
	}

	var body: some View {
		VStack(spacing: 4) {
			ZStack {
				Circle()
					.stroke(.secondary.opacity(0.2), lineWidth: 8)
				Circle()
					.trim(from: 0, to: CGFloat(max(0, min(1, value))))
					.stroke(
						AngularGradient(gradient: Gradient(colors: [ringColor, ringColor.opacity(0.6), ringColor]),
														center: .center),
						style: StrokeStyle(lineWidth: 8, lineCap: .round)
					)
					.rotationEffect(.degrees(-90))
					.snappyAnimationIfAvailable(value: value)
				Text("\(Int(value * 100))%")
					.font(.caption2.monospacedDigit())
			}
			Text(label).font(.caption2).foregroundStyle(.secondary)
			Text(detail).font(.caption2)
		}
	}
}

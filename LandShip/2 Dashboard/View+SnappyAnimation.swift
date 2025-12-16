import SwiftUI

extension View {
	func snappyAnimationIfAvailable<Value: Equatable>(value: Value) -> some View {
		if #available(iOS 17, macOS 14, *) {
			return AnyView(self.animation(.snappy, value: value))
		} else {
			return AnyView(self.animation(.default, value: value))
		}
	}
}

import SwiftUI

@MainActor
struct ElasticButton: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @GestureState private var isPressed = false

    func makeBody(configuration: Configuration) -> some View {
        nativeButton(configuration: configuration)
            .scaleEffect(isPressed && isEnabled && !reduceMotion ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .spring(duration: isPressed ? 0.14 : 0.42, bounce: isPressed ? 0 : 0.38),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in
                        pressed = true
                    },
                isEnabled: isEnabled && !reduceMotion
            )
    }

    @ViewBuilder
    private func nativeButton(configuration: Configuration) -> some View {
        if #available(macOS 26, *), !reduceTransparency {
            Button(configuration)
                .buttonStyle(.glass)
        } else {
            Button(configuration)
                .buttonStyle(.bordered)
        }
    }
}

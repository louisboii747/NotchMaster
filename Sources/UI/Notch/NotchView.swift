import SwiftUI

@MainActor
struct NotchView: View {
    let cameraHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                .fill(.black)
                .accessibilityHidden(true)

            if size.height > cameraHeight {
                TimelineView(.everyMinute) { context in
                    NotchClockView(date: context.date)
                        .fixedSize()
                        .visualEffect { content, textGeometry in
                            content.opacity(Self.contentOpacity(
                                panelSize: size,
                                contentSize: textGeometry.size,
                                cameraHeight: cameraHeight
                            ))
                        }
                }
                .frame(width: size.width, height: size.height - cameraHeight)
                .offset(y: cameraHeight)
            }
        }
        .ignoresSafeArea()
    }

    nonisolated static func contentOpacity(
        panelSize: CGSize,
        contentSize: CGSize,
        cameraHeight: CGFloat
    ) -> Double {
        let horizontalRoom = panelSize.width - contentSize.width - 32
        let verticalRoom = panelSize.height - cameraHeight - contentSize.height - 16
        return Double(min(1, max(0, min(horizontalRoom, verticalRoom) / 8)))
    }
}

@MainActor
struct NotchClockView: View {
    let date: Date

    var body: some View {
        VStack(spacing: 4) {
            Text(date, format: .dateTime.hour().minute())
                .font(.title)
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

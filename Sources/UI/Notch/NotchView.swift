import SwiftUI

@MainActor
struct NotchView: View {
    let cameraHeight: CGFloat
    let batteryService: BatteryInformationService

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                .fill(.black)
                .accessibilityHidden(true)

            if size.height > cameraHeight {
                TimelineView(.everyMinute) { context in
                    NotchExpandedContentView(
                        date: context.date,
                        batteryInformation: batteryService.information,
                        panelSize: size,
                        cameraHeight: cameraHeight
                    )
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
struct NotchExpandedContentView: View {
    let date: Date
    let batteryInformation: BatteryInformation?
    let panelSize: CGSize
    let cameraHeight: CGFloat

    var body: some View {
        NotchClockView(date: date)
            .fixedSize()
            .visualEffect { content, textGeometry in
                content.opacity(NotchView.contentOpacity(
                    panelSize: panelSize,
                    contentSize: textGeometry.size,
                    cameraHeight: cameraHeight
                ))
            }
            .overlay {
                GeometryReader { clockGeometry in
                    let clockSize = clockGeometry.size

                    if let batteryInformation {
                        NotchBatteryView(information: batteryInformation)
                            .fixedSize()
                            .visualEffect { content, batteryGeometry in
                                content.opacity(NotchView.contentOpacity(
                                    panelSize: panelSize,
                                    contentSize: CGSize(
                                        width: clockSize.width + 2 * (batteryGeometry.size.width + 12),
                                        height: max(clockSize.height, batteryGeometry.size.height)
                                    ),
                                    cameraHeight: cameraHeight
                                ))
                            }
                            .frame(height: clockSize.height)
                            .offset(x: clockSize.width + 12)
                    }
                }
            }
    }
}

@MainActor
struct NotchBatteryView: View {
    let information: BatteryInformation

    var symbolName: String {
        if information.isCharging { return "battery.100percent.bolt" }
        let level = Int((Double(information.percentage) / 25).rounded()) * 25
        return "battery.\(level)percent"
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbolName)
                .font(.subheadline)
                .accessibilityHidden(true)
            Text(Double(information.percentage) / 100, format: .percent.precision(.fractionLength(0)))
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.65))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(information.isCharging ? Text("Battery, charging") : Text("Battery, not charging"))
        .accessibilityValue(Text(Double(information.percentage) / 100, format: .percent.precision(.fractionLength(0))))
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

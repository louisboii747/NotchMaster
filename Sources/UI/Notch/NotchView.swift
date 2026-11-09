import SwiftUI

@MainActor
struct NotchView: View {
    let cameraHeight: CGFloat
    let batteryService: BatteryInformationService
    let preferences: PreferencesStore

    var body: some View {
        let showBatteryStatus = preferences.showBatteryStatus

        GeometryReader { geometry in
            let size = geometry.size
            let contentHeight = max(0, size.height - cameraHeight)
            let cornerGrowth = min(18, contentHeight / 4)

            UnevenRoundedRectangle(
                topLeadingRadius: cornerGrowth,
                bottomLeadingRadius: 10 + cornerGrowth,
                bottomTrailingRadius: 10 + cornerGrowth,
                topTrailingRadius: cornerGrowth,
                style: .continuous
            )
            .fill(.black)
            .accessibilityHidden(true)

            if contentHeight > 0 {
                TimelineView(.everyMinute) { context in
                    NotchExpandedContentView(
                        date: context.date,
                        batteryInformation: showBatteryStatus ? batteryService.information : nil,
                        panelSize: size,
                        cameraHeight: cameraHeight
                    )
                }
                .frame(width: size.width, height: contentHeight)
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
        let horizontalRoom = panelSize.width - contentSize.width - 48
        let verticalRoom = panelSize.height - cameraHeight - contentSize.height - 28
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
        let batterySpacing: CGFloat = 28

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
                                        width: clockSize.width + 2 * (batteryGeometry.size.width + batterySpacing),
                                        height: max(clockSize.height, batteryGeometry.size.height)
                                    ),
                                    cameraHeight: cameraHeight
                                ))
                            }
                            .frame(height: clockSize.height)
                            .offset(x: clockSize.width + batterySpacing)
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
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.title3)
                .accessibilityHidden(true)
            Text(Double(information.percentage) / 100, format: .percent.precision(.fractionLength(0)))
                .font(.caption)
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

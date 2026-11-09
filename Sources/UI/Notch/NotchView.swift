import SwiftUI

@MainActor
struct NotchView: View {
    let cameraHeight: CGFloat
    let batteryService: BatteryInformationService
    let preferences: PreferencesStore
    var nowPlayingService: NowPlayingService? = nil

    var body: some View {
        let showBatteryStatus = preferences.showBatteryStatus
        let nowPlayingState = nowPlayingService?.state ?? .unavailable

        GeometryReader { geometry in
            let size = geometry.size
            let contentHeight = max(0, size.height - cameraHeight)

            NotchSurface(cameraHeight: cameraHeight)
                .fill(.black)
                .accessibilityHidden(true)

            if contentHeight > 0 {
                TimelineView(.everyMinute) { context in
                    NotchExpandedContentView(
                        date: context.date,
                        batteryInformation: showBatteryStatus ? batteryService.information : nil,
                        panelSize: size,
                        cameraHeight: cameraHeight,
                        nowPlayingState: nowPlayingState
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

struct NotchSurface: Shape {
    let cameraHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let cornerGrowth = min(18, max(0, rect.height - cameraHeight) / 4)
        let shoulder = min(14, cornerGrowth, rect.width / 4)
        let body = rect.insetBy(dx: shoulder, dy: 0)
        var path = UnevenRoundedRectangle(
            bottomLeadingRadius: 10 + cornerGrowth,
            bottomTrailingRadius: 10 + cornerGrowth,
            style: .continuous
        ).path(in: body)

        // With no expansion, retain the original compact surface exactly.
        guard shoulder > 0 else { return path }

        // The flared shoulders meet the screen edge and turn inward into the sides.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX, y: rect.minY + shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: body.minX, y: rect.minY)
        )
        path.closeSubpath()

        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: body.maxX, y: rect.minY + shoulder),
            control: CGPoint(x: body.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

@MainActor
struct NotchExpandedContentView: View {
    let date: Date
    let batteryInformation: BatteryInformation?
    let panelSize: CGSize
    let cameraHeight: CGFloat
    var nowPlayingState: NowPlayingState = .unavailable

    var body: some View {
        if nowPlayingState.track != nil {
            ViewThatFits(in: .horizontal) {
                mediaContent
                clockContent
            }
        } else {
            clockContent
        }
    }

    private var mediaContent: some View {
        HStack(spacing: 20) {
            NotchNowPlayingView(state: nowPlayingState)
                .frame(minWidth: 164, maxWidth: 220)
            NotchClockView(date: date)
                .fixedSize()
            if let batteryInformation {
                NotchBatteryView(information: batteryInformation)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 32)
        .visualEffect { content, geometry in
            content.opacity(NotchView.contentOpacity(
                panelSize: panelSize,
                contentSize: CGSize(width: geometry.size.width - 64, height: geometry.size.height),
                cameraHeight: cameraHeight
            ))
        }
    }

    private var clockContent: some View {
        let batterySpacing: CGFloat = 28

        return NotchClockView(date: date)
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

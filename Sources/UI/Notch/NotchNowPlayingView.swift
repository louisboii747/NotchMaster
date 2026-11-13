import SwiftUI

@MainActor
struct NotchNowPlayingView: View {
    static let minimumSize = CGSize(width: 480, height: 274)

    let state: NowPlayingState
    var date: Date = .now
    var batteryInformation: BatteryInformation? = nil
    var service: NowPlayingService? = nil
    var reduceMotion = false

    var body: some View {
        if let track = state.track {
            VStack(spacing: 18) {
                ZStack {
                    hero(track)
                        .id(track.identity)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .offset(y: 8).combined(with: .opacity),
                            removal: .offset(y: -8).combined(with: .opacity)
                        ))
                }
                .frame(height: 88)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: track.identity)

                if state.isPlaying, track.timing != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        NowPlayingProgressView(timing: track.timing, isPlaying: true, date: context.date)
                    }
                } else {
                    NowPlayingProgressView(timing: track.timing, isPlaying: false, date: date)
                }

                HStack(spacing: 28) {
                    transportButton(.previous, symbol: "backward.end.fill", label: "Previous track")
                    transportButton(.togglePlayback, symbol: state.isPlaying ? "pause.fill" : "play.fill", label: state.isPlaying ? "Pause" : "Play", primary: true)
                    transportButton(.next, symbol: "forward.end.fill", label: "Next track")
                }
                .frame(maxWidth: .infinity)

                footer
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func hero(_ track: NowPlayingTrack) -> some View {
        HStack(spacing: 24) {
            artwork(track.artwork)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(track.title)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
                Text(track.artist.isEmpty ? String(localized: "Unknown Artist") : track.artist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func transportButton(_ command: NowPlayingCommand, symbol: String, label: LocalizedStringKey, primary: Bool = false) -> some View {
        Button {
            service?.perform(command)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: primary ? 21 : 18, weight: .semibold))
                .frame(width: primary ? 48 : 44, height: 48)
                .background {
                    if primary {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(.white.opacity(0.12))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(primary ? 1 : 0.8))
        .disabled(service == nil || service?.isPerformingCommand == true)
        .accessibilityLabel(Text(label))
        .help(Text(label))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let error = service?.controlError {
                Text(error)
                    .foregroundStyle(.orange)
            } else {
                Text(date, format: .dateTime.hour().minute())
                    .fontWeight(.medium)
                    .monospacedDigit()
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .foregroundStyle(.white.opacity(0.42))
                Spacer(minLength: 12)
                if let batteryInformation {
                    NotchBatteryView(information: batteryInformation, isInline: true)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.65))
        .lineLimit(1)
        .frame(height: 20)
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func artwork(_ data: Data?) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }
        }
    }
}

@MainActor
struct NowPlayingProgressView: View {
    let timing: NowPlayingTiming?
    let isPlaying: Bool
    let date: Date

    var body: some View {
        let elapsed = timing?.elapsed(at: date, isPlaying: isPlaying)
        let remaining = timing.map { $0.duration - $0.elapsed(at: date, isPlaying: isPlaying) }
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(Color(red: 0.93, green: 0.35, blue: 0.21))
                    .frame(width: geometry.size.width * (timing?.fraction(at: date, isPlaying: isPlaying) ?? 0))
            }
            .frame(height: 4)
            HStack {
                Text(Self.timeLabel(elapsed))
                Spacer()
                Text(remaining.map { "−\(Self.timeLabel($0))" } ?? "–:––")
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress")
        .accessibilityValue(timing == nil ? Text("Timing unavailable") : Text("\(Self.timeLabel(elapsed)) elapsed, \(Self.timeLabel(remaining)) remaining"))
    }

    static func timeLabel(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0, seconds < 31_536_000 else { return "–:––" }
        let value = Int(seconds.rounded(.down))
        let tail = (value % 60).formatted(.number.precision(.integerLength(2)))
        let minutes = (value / 60 % 60).formatted(.number.precision(.integerLength(2)))
        if value >= 3600 { return "\(value / 3600):\(minutes):\(tail)" }
        return "\(value / 60):\(tail)"
    }
}

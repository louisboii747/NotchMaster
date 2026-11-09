import SwiftUI

@MainActor
struct NotchNowPlayingView: View {
    let state: NowPlayingState

    var body: some View {
        if let track = state.track {
            HStack(spacing: 12) {
                artwork(track.artwork)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        if case .paused = state {
                            Image(systemName: "pause.fill")
                                .font(.caption2)
                                .accessibilityLabel("Paused")
                        }
                        Text(track.artist.isEmpty ? String(localized: "Unknown Artist") : track.artist)
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.65))
                }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func artwork(_ data: Data?) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.1))
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.65))
                }
        }
    }
}

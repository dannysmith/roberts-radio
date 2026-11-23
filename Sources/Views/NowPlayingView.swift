import SwiftUI

struct NowPlayingView: View {
    let vm: RadioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vm.radioName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: vm.playStatus)
                Button {
                    Task { await vm.togglePower() }
                } label: {
                    Image(systemName: "power").font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("Standby")
            }

            TrackInfo(artworkURL: vm.artworkURL, trackName: vm.trackName, artist: vm.artist, infoText: vm.infoText)

            if vm.duration > 0 {
                PlaybackProgress(vm: vm)
            }
        }
    }
}

private struct StatusBadge: View {
    let status: PlayStatus

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private var title: String {
        switch status {
        case .playing: "Playing"
        case .paused: "Paused"
        case .buffering: "Buffering"
        case .stopped: "Stopped"
        }
    }

    private var icon: String {
        switch status {
        case .playing: "play.fill"
        case .paused: "pause.fill"
        case .buffering: "ellipsis"
        case .stopped: "stop.fill"
        }
    }
}

private struct TrackInfo: View {
    let artworkURL: URL?
    let trackName: String
    let artist: String
    let infoText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(trackName.isEmpty ? "No track info" : trackName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                if !artist.isEmpty {
                    Text(artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                if !infoText.isEmpty, infoText != trackName, infoText != artist {
                    Text(infoText).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }
}

/// Progress bar for finite-length content. Click to seek.
private struct PlaybackProgress: View {
    let vm: RadioViewModel

    var body: some View {
        HStack(spacing: 4) {
            timeLabel(vm.position)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 3)
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(vm.position) / CGFloat(max(1, vm.duration)), height: 3)
                }
                .contentShape(.rect)
                .onTapGesture { location in
                    let fraction = max(0, min(1, location.x / geo.size.width))
                    vm.seekTo(Int(fraction * Double(vm.duration)))
                }
            }
            .frame(height: 8) // slightly taller hit target than the visual 3px
            timeLabel(vm.duration)
        }
        .padding(.top, 2)
    }

    private func timeLabel(_ ms: Int) -> some View {
        Text(formatTime(ms))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private func formatTime(_ ms: Int) -> String {
        let total = ms / 1000
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

import SwiftUI

/// Toggles the radio as the Mac's Bluetooth speaker.
struct MacSpeakerButton: View {
    let speaker: MacSpeaker

    var body: some View {
        Button {
            Task { await speaker.toggle() }
        } label: {
            HStack(spacing: 4) {
                if isBusy {
                    ProgressView().controlSize(.mini)
                }
                Label("Mac Audio", systemImage: isOn ? "speaker.wave.2.fill" : "laptopcomputer")
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : .secondary)
        .controlSize(.small)
        .disabled(isBusy)
        .help(isOn ? "Stop playing this Mac's audio through the radio" : "Play this Mac's audio through the radio")
    }

    private var isOn: Bool {
        speaker.state == .connected
    }

    private var isBusy: Bool {
        speaker.state == .connecting || speaker.state == .disconnecting
    }
}

/// Explains a Mac Audio problem and offers pairing when it's needed.
struct MacSpeakerStatus: View {
    let speaker: MacSpeaker

    var body: some View {
        if let problem = speaker.problem {
            VStack(alignment: .leading, spacing: 4) {
                Text(problem)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if speaker.needsPairing {
                    Button("Set Up Pairing") {
                        Task { await speaker.beginPairing() }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.top, 4)
        }
    }
}

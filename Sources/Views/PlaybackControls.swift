import SwiftUI

struct TransportControls: View {
    let vm: RadioViewModel

    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            Button {
                Task { await vm.prev() }
            } label: {
                Image(systemName: "backward.fill").font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Previous")

            Button {
                Task { await vm.playPause() }
            } label: {
                Image(systemName: vm.playStatus == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .help(vm.playStatus == .playing ? "Pause" : "Play")

            Button {
                Task { await vm.stop() }
            } label: {
                Image(systemName: "stop.fill").font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Stop")

            Button {
                Task { await vm.next() }
            } label: {
                Image(systemName: "forward.fill").font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Next")
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct VolumeControl: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await vm.toggleMute() }
            } label: {
                Image(systemName: vm.muted ? "speaker.slash.fill" : volumeIcon)
                    .font(.system(size: 12))
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(vm.muted ? .red : .primary)
            .help(vm.muted ? "Unmute" : "Mute")

            Slider(value: $vm.volume, in: 0 ... vm.maxVolume, step: 1) {
                EmptyView()
            } onEditingChanged: { editing in
                vm.isDraggingVolume = editing
                if !editing {
                    Task { await vm.setVolume(Int(vm.volume)) }
                }
            }

            Text("\(Int(vm.volume))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
    }

    private var volumeIcon: String {
        if vm.volume == 0 {
            return "speaker.fill"
        }
        if vm.volume < vm.maxVolume * 0.33 {
            return "speaker.wave.1.fill"
        }
        if vm.volume < vm.maxVolume * 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }
}

struct ModeControls: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Mode").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $vm.selectedModeID) {
                ForEach(vm.modes) { mode in
                    Text(mode.label).tag(mode.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if !vm.eqPresets.isEmpty {
                Spacer()
                Text("EQ").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $vm.selectedEQPresetID) {
                    ForEach(vm.eqPresets) { eq in
                        Text(eq.label).tag(eq.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}

struct SpotifyInfo: View {
    let user: String
    let bitRate: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "headphones").font(.system(size: 9)).foregroundStyle(.green)
            Text(user).font(.system(size: 10)).foregroundStyle(.secondary)
            if !bitRate.isEmpty {
                Text("·").foregroundStyle(.secondary)
                Text(bitRate).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }
}

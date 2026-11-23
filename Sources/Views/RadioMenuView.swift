import SwiftUI

enum SidePanel {
    case none, presets, browse
}

/// Root of the menubar popover: the main column plus an optional side panel.
struct RadioMenuView: View {
    let vm: RadioViewModel
    @State private var showSettings = false
    @State private var showAlarms = false
    @State private var sidePanel: SidePanel = .none
    @State private var filterText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if !vm.isConnected {
                    DisconnectedView(vm: vm)
                } else if !vm.power {
                    StandbyView(vm: vm)
                    Divider().padding(.vertical, 6)
                } else {
                    PlayerSections(vm: vm, sidePanel: $sidePanel, showAlarms: $showAlarms)
                }
                Spacer(minLength: 0)
                BottomBar(vm: vm, showSettings: $showSettings)
            }
            .frame(width: 280)
            .padding(.trailing, sidePanel != .none ? 8 : 0)

            // Expands to the right of the main column
            if sidePanel != .none {
                Divider().padding(.vertical, 8)
                SidePanelView(vm: vm, panel: $sidePanel, filterText: $filterText)
                    .frame(width: 260, alignment: .top)
                    .padding(.leading, 4)
            }
        }
        .padding(14)
        .frame(minHeight: sidePanel != .none ? 420 : nil)
    }
}

private struct PlayerSections: View {
    let vm: RadioViewModel
    @Binding var sidePanel: SidePanel
    @Binding var showAlarms: Bool

    var body: some View {
        NowPlayingView(vm: vm)
        Divider().padding(.vertical, 6)
        TransportControls(vm: vm)
        Divider().padding(.vertical, 6)
        VolumeControl(vm: vm)
        if !vm.modes.isEmpty {
            Divider().padding(.vertical, 6)
            ModeControls(vm: vm)
        }
        if vm.isSpotifyMode, !vm.spotifyUser.isEmpty {
            SpotifyInfo(user: vm.spotifyUser, bitRate: vm.spotifyBitRate)
        }
        Divider().padding(.vertical, 6)
        SidePanelButtons(vm: vm, selection: $sidePanel)
        Divider().padding(.vertical, 6)
        AlarmsSection(vm: vm, isExpanded: $showAlarms)
        Divider().padding(.vertical, 6)
    }
}

private struct DisconnectedView: View {
    let vm: RadioViewModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(vm.connectionError ?? "Not connected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsFields(vm: vm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct StandbyView: View {
    let vm: RadioViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "radio").font(.system(size: 14))
                Text(vm.radioName).font(.headline)
                Spacer()
            }
            HStack {
                Text("Standby").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Power On") { Task { await vm.togglePower() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

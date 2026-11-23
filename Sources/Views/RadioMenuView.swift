import SwiftUI

// MARK: - Views

struct PresetRow: View {
    let number: Int
    let name: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 16, alignment: .trailing)
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(hovered ? Color.accentColor.opacity(0.15) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct BrowseRow: View {
    let name: String
    let isFolder: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isFolder ? "folder.fill" : "music.note")
                    .font(.system(size: 10))
                    .foregroundColor(isFolder ? Color.accentColor : .secondary)
                    .frame(width: 14)
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                if isFolder {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(hovered ? Color.accentColor.opacity(0.15) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

enum SidePanel { case none, presets, browse }

struct RadioMenuView: View {
    @Bindable var vm: RadioViewModel
    @State private var showSettings = false
    @State private var showAlarms = false
    @State private var ipField = ""
    @State private var pinField = ""
    @State private var sidePanel: SidePanel = .none
    @State private var filterText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main column
            VStack(alignment: .leading, spacing: 0) {
                if !vm.isConnected {
                    disconnectedView
                } else if !vm.power {
                    standbyView
                    Divider().padding(.vertical, 6)
                } else {
                    nowPlayingView
                    Divider().padding(.vertical, 6)
                    controlsView
                    Divider().padding(.vertical, 6)
                    volumeView
                    if !vm.modes.isEmpty {
                        Divider().padding(.vertical, 6)
                        modeView
                    }
                    if vm.isSpotifyMode, !vm.spotifyUser.isEmpty {
                        spotifyView
                    }
                    Divider().padding(.vertical, 6)
                    sidePanelButtons
                    Divider().padding(.vertical, 6)
                    alarmsView
                    Divider().padding(.vertical, 6)
                }
                Spacer(minLength: 0)
                bottomBar
            }
            .frame(width: 280)
            .padding(.trailing, sidePanel != .none ? 8 : 0)

            // Side panel (expands to the right)
            if sidePanel != .none {
                Divider().padding(.vertical, 8)
                sidePanelContent
                    .frame(width: 260, alignment: .top)
                    .padding(.leading, 4)
            }
        }
        .padding(14)
        .frame(minHeight: sidePanel != .none ? 420 : nil)
        .onAppear {
            ipField = vm.radioIP
            pinField = vm.radioPin
        }
    }

    // MARK: Disconnected

    private var disconnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(vm.connectionError ?? "Not connected")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            settingsFields
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Standby

    private var standbyView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "radio").font(.system(size: 14))
                Text(vm.radioName).font(.headline)
                Spacer()
            }
            HStack {
                Text("Standby").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Power On") { Task { await vm.togglePower() } }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
    }

    // MARK: Now Playing

    private var nowPlayingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(vm.radioName).font(.caption).foregroundColor(.secondary)
                Spacer()
                statusBadge
                Button(action: { Task { await vm.togglePower() } }) {
                    Image(systemName: "power").font(.system(size: 11))
                }
                .buttonStyle(.borderless).foregroundColor(.red).help("Standby")
            }

            // Track info
            HStack(alignment: .top, spacing: 10) {
                if let url = vm.artworkURL {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle().fill(.quaternary).overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                        }
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.trackName.isEmpty ? "No track info" : vm.trackName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    if !vm.artist.isEmpty {
                        Text(vm.artist).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    }
                    if !vm.infoText.isEmpty, vm.infoText != vm.trackName, vm.infoText != vm.artist {
                        Text(vm.infoText).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                    }
                }
            }

            // Progress bar (clickable to seek for finite-length content)
            if vm.duration > 0 {
                HStack(spacing: 4) {
                    Text(fmtTime(vm.position)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary).frame(height: 3)
                            Capsule().fill(Color.accentColor)
                                .frame(width: geo.size.width * CGFloat(vm.position) / CGFloat(max(1, vm.duration)), height: 3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let fraction = max(0, min(1, location.x / geo.size.width))
                            vm.seekTo(Int(fraction * Double(vm.duration)))
                        }
                    }.frame(height: 8) // slightly taller hit target than the visual 3px
                    Text(fmtTime(vm.duration)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch vm.playStatus {
            case .playing: Label("Playing", systemImage: "play.fill")
            case .paused: Label("Paused", systemImage: "pause.fill")
            case .buffering: Label("Buffering", systemImage: "ellipsis")
            case .stopped: Label("Stopped", systemImage: "stop.fill")
            }
        }
        .font(.system(size: 9))
        .foregroundColor(.secondary)
        .labelStyle(.titleAndIcon)
    }

    // MARK: Controls

    private var controlsView: some View {
        HStack(spacing: 20) {
            Spacer()
            Button(action: { Task { await vm.prev() } }) {
                Image(systemName: "backward.fill").font(.system(size: 14))
            }.buttonStyle(.borderless).help("Previous")

            Button(action: { Task { await vm.playPause() } }) {
                Image(systemName: vm.playStatus == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }.buttonStyle(.borderless).help(vm.playStatus == .playing ? "Pause" : "Play")

            Button(action: { Task { await vm.stop() } }) {
                Image(systemName: "stop.fill").font(.system(size: 14))
            }.buttonStyle(.borderless).help("Stop")

            Button(action: { Task { await vm.next() } }) {
                Image(systemName: "forward.fill").font(.system(size: 14))
            }.buttonStyle(.borderless).help("Next")
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: Volume

    private var volumeView: some View {
        HStack(spacing: 8) {
            Button(action: { Task { await vm.toggleMute() } }) {
                Image(systemName: vm.muted ? "speaker.slash.fill" : volumeIcon)
                    .font(.system(size: 12))
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .foregroundColor(vm.muted ? .red : .primary)
            .help(vm.muted ? "Unmute" : "Mute")

            Slider(value: $vm.volume, in: 0 ... vm.maxVolume, step: 1) { EmptyView() }
                onEditingChanged: { editing in
                    vm.isDraggingVolume = editing
                    if !editing {
                        Task { await vm.setVolume(Int(vm.volume)) }
                    }
                }

            Text("\(Int(vm.volume))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
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

    // MARK: Mode

    private var modeView: some View {
        HStack(spacing: 8) {
            Text("Mode").font(.caption).foregroundColor(.secondary)
            Picker("", selection: $vm.selectedModeID) {
                ForEach(vm.modes) { mode in
                    Text(mode.label).tag(mode.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if !vm.eqPresets.isEmpty {
                Spacer()
                Text("EQ").font(.caption).foregroundColor(.secondary)
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

    // MARK: Spotify

    private var spotifyView: some View {
        HStack(spacing: 4) {
            Image(systemName: "headphones").font(.system(size: 9)).foregroundColor(.green)
            Text(vm.spotifyUser).font(.system(size: 10)).foregroundColor(.secondary)
            if !vm.spotifyBitRate.isEmpty {
                Text("·").foregroundColor(.secondary)
                Text(vm.spotifyBitRate).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(.top, 2)
    }

    // MARK: Side Panel Buttons

    private var sidePanelButtons: some View {
        HStack(spacing: 8) {
            panelToggle("Presets", icon: "list.bullet", panel: .presets)
            panelToggle("Browse", icon: "folder", panel: .browse)
            Spacer()
        }
    }

    private func panelToggle(_ label: String, icon: String, panel: SidePanel) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                sidePanel = sidePanel == panel ? .none : panel
            }
            if sidePanel == .browse, vm.browseItems.isEmpty {
                vm.startBrowse()
            }
        }) {
            Label(label, systemImage: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .tint(sidePanel == panel ? .accentColor : .secondary)
        .controlSize(.small)
    }

    // MARK: Side Panel Content

    private var sidePanelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(sidePanel == .presets ? "Presets" : "Browse")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { sidePanel = .none }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 8)

            if sidePanel == .presets {
                presetsPanel
            } else {
                browsePanel
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var presetsPanel: some View {
        if vm.presets.isEmpty {
            Text("No presets for this mode")
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.presets) { preset in
                        PresetRow(number: preset.id + 1, name: preset.name) {
                            Task { await vm.selectPreset(preset.id) }
                        }
                    }
                }
            }
        }
    }

    private var filteredBrowseItems: [BrowseItem] {
        guard !filterText.isEmpty else { return vm.browseItems }
        return vm.browseItems.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private var browsePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Filter
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10)).foregroundColor(.secondary)
                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Navigation bar
            HStack(spacing: 4) {
                if vm.browseDepth > 0 {
                    Button(action: {
                        filterText = ""
                        vm.browseBack()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left").font(.system(size: 10))
                            Text("Back").font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.borderless)
                }
                Text(vm.browseTitle.isEmpty ? vm.modeName : vm.browseTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Items
            if vm.isBrowseLoading {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                    .padding(.vertical, 12)
            } else if vm.browseItems.isEmpty {
                Text("No items")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                let items = filteredBrowseItems
                if items.isEmpty {
                    Text("No matches")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(items) { item in
                                BrowseRow(name: item.name, isFolder: item.isFolder) {
                                    filterText = ""
                                    if item.isFolder {
                                        vm.browseInto(item.id)
                                    } else {
                                        vm.browseSelect(item.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Alarms

    private var alarmsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                showAlarms.toggle()
                if showAlarms, vm.alarms.isEmpty {
                    Task { await vm.fetchAlarms() }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "alarm").font(.system(size: 10))
                    Text("Alarms").font(.caption)
                    Spacer()
                    Image(systemName: showAlarms ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.borderless)

            if showAlarms {
                if vm.alarms.isEmpty {
                    Text("No alarms configured")
                        .font(.caption).foregroundColor(.secondary).padding(.vertical, 4)
                } else {
                    VStack(spacing: 2) {
                        ForEach(vm.alarms) { alarm in
                            alarmRow(alarm)
                        }
                    }
                }
            }
        }
    }

    private func alarmRow(_ alarm: RadioAlarm) -> some View {
        HStack(spacing: 6) {
            Circle().fill(alarm.isEnabled ? Color.green : Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            Text(alarm.time).font(.system(size: 11, weight: .medium, design: .monospaced))
            if let days = alarm.days {
                Text(days).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            if let volume = alarm.volume {
                Image(systemName: "speaker.wave.1.fill").font(.system(size: 8)).foregroundColor(.secondary)
                Text(volume).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
    }

    // MARK: Settings

    private var settingsFields: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                TextField("IP address", text: $ipField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { vm.radioIP = ipField; vm.requestPoll() }
                Button("Set") { vm.radioIP = ipField; vm.requestPoll() }
                    .controlSize(.small)
            }
            HStack(spacing: 4) {
                Text("PIN").font(.system(size: 10)).foregroundColor(.secondary)
                TextField("PIN", text: $pinField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60)
                    .onSubmit { vm.updatePin(pinField); vm.requestPoll() }
                Spacer()
                Button(action: { Task { await vm.discover() } }) {
                    HStack(spacing: 4) {
                        if vm.isDiscovering {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        }
                        Text(vm.isDiscovering ? "Searching..." : "Discover")
                    }
                }
                .controlSize(.small)
                .disabled(vm.isDiscovering)
            }
        }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack {
            if showSettings, vm.isConnected {
                VStack(alignment: .leading, spacing: 4) {
                    settingsFields
                    Button("Done") { showSettings = false }.controlSize(.small)
                }
            } else {
                Button(action: { withAnimation { showSettings.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear").font(.system(size: 11))
                        if vm.isConnected {
                            Text(vm.radioIP).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Helpers

    private func fmtTime(_ ms: Int) -> String {
        let total = ms / 1000
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

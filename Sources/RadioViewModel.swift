import Foundation
import SwiftUI

// MARK: - View Model

@MainActor
final class RadioViewModel: ObservableObject {
    /// Connection
    @Published var radioIP: String {
        didSet {
            UserDefaults.standard.set(radioIP, forKey: "radioBarIP")
            deviceInfoLoaded = false; presetsLoaded = false
            modes = []; eqPresets = []
        }
    }

    @Published var radioPin: String {
        didSet { UserDefaults.standard.set(radioPin, forKey: "radioBarPIN") }
    }

    @Published var isConnected = false
    @Published var isDiscovering = false
    @Published var connectionError: String?

    // State
    @Published var power = false
    @Published var radioName = ""
    @Published var modeName = ""
    @Published var modeId = 0
    @Published var volume: Double = 0
    @Published var maxVolume: Double = 31
    @Published var muted = false

    // Now playing
    @Published var playStatus = "stopped"
    @Published var trackName = ""
    @Published var artist = ""
    @Published var infoText = ""
    @Published var artworkURL: URL?
    @Published var position = 0
    @Published var duration = 0

    // Lists
    @Published var modes: [(id: Int, label: String)] = []
    @Published var presets: [(key: Int, name: String)] = []

    // EQ
    @Published var eqPresets: [(id: Int, label: String)] = []
    @Published var eqPresetId = 0

    /// Alarms
    @Published var alarms: [(key: Int, fields: [String: String])] = []

    // Spotify
    @Published var spotifyUser = ""
    @Published var spotifyBitRate = ""
    var isSpotifyMode: Bool {
        modeName.lowercased().contains("spotify")
    }

    // Browse
    @Published var browseItems: [(key: Int, name: String, isFolder: Bool)] = []
    @Published var browseTitle = ""
    @Published var browseDepth = 0
    @Published var isBrowseLoading = false

    // Internal
    var isDraggingVolume = false
    var popoverVisible = false {
        didSet {
            if popoverVisible != oldValue {
                restartTimer()
            }
        }
    }

    private var isPolling = false
    private var presetsLoaded = false
    private var deviceInfoLoaded = false
    private var pollTimer: Timer?
    private var client: FSAPIClient

    init() {
        let ip = UserDefaults.standard.string(forKey: "radioBarIP") ?? "192.168.1.72"
        let pin = UserDefaults.standard.string(forKey: "radioBarPIN") ?? "1234"
        radioIP = ip
        radioPin = pin
        client = FSAPIClient(pin: pin)
        Log("APP: Init (ip=\(ip))")
        restartTimer()
        Task { await poll() }
    }

    private func restartTimer() {
        pollTimer?.invalidate()
        let interval: TimeInterval = popoverVisible ? 4 : 60
        Log("VM: Poll interval -> \(Int(interval))s (popover \(popoverVisible ? "open" : "closed"))")
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.poll() }
        }
    }

    func poll() async {
        guard !isPolling, !radioIP.isEmpty else { return }
        isPolling = true
        defer { isPolling = false }

        let ip = radioIP

        // When popover is closed, only check power for the menubar icon
        if !popoverVisible {
            let r = await client.get(ip, node: "netRemote.sys.power")
            if r.status == "FS_OK" {
                let wasConnected = isConnected
                isConnected = true; connectionError = nil
                power = r.value == "1"
                if !wasConnected {
                    Log("VM: Connected to \(ip)")
                }
            } else {
                if isConnected {
                    Log("VM: Lost connection to \(ip)")
                }
                isConnected = false; connectionError = "Cannot reach radio at \(ip)"
            }
            return
        }

        // Full poll when popover is visible
        let vals = await client.getMultiple(ip, nodes: [
            "netRemote.sys.power",
            "netRemote.sys.mode",
            "netRemote.sys.audio.volume",
            "netRemote.sys.audio.mute",
            "netRemote.sys.audio.eqPreset",
            "netRemote.play.status",
            "netRemote.play.info.name",
            "netRemote.play.info.text",
            "netRemote.play.info.artist",
            "netRemote.play.info.graphicUri",
            "netRemote.play.info.duration",
            "netRemote.play.position",
            "netRemote.spotify.username",
            "netRemote.spotify.bitRate",
        ])

        guard !vals.isEmpty else {
            if isConnected {
                Log("VM: Lost connection to \(ip)")
            }
            isConnected = false
            connectionError = "Cannot reach radio at \(ip)"
            return
        }
        if !isConnected {
            Log("VM: Connected to \(ip)")
        }
        isConnected = true
        connectionError = nil

        power = vals["netRemote.sys.power"] == "1"
        if !isDraggingVolume, let s = vals["netRemote.sys.audio.volume"], let v = Double(s) {
            volume = v
        }
        muted = vals["netRemote.sys.audio.mute"] == "1"
        if let e = vals["netRemote.sys.audio.eqPreset"], let v = Int(e) {
            eqPresetId = v
        }

        let statusMap = ["1": "buffering", "2": "playing", "3": "paused"]
        playStatus = statusMap[vals["netRemote.play.status"] ?? "0"] ?? "stopped"
        let newTrack = vals["netRemote.play.info.name"] ?? ""
        if newTrack != trackName {
            Log("VM: Now playing: \(newTrack)")
        }
        trackName = newTrack
        artist = vals["netRemote.play.info.artist"] ?? ""
        infoText = vals["netRemote.play.info.text"] ?? ""
        if let u = vals["netRemote.play.info.graphicUri"], !u.isEmpty {
            artworkURL = URL(string: u)
        } else {
            artworkURL = nil
        }
        if let d = vals["netRemote.play.info.duration"], let v = Int(d) {
            duration = v
        }
        if let p = vals["netRemote.play.position"], let v = Int(p) {
            position = v
        }

        spotifyUser = vals["netRemote.spotify.username"] ?? ""
        let brMap = ["0": "Low", "1": "Normal", "2": "High", "3": "Very High"]
        spotifyBitRate = brMap[vals["netRemote.spotify.bitRate"] ?? ""] ?? ""

        let newModeId = Int(vals["netRemote.sys.mode"] ?? "0") ?? 0
        let modeChanged = newModeId != modeId
        modeId = newModeId
        if modeChanged {
            Log("VM: Mode changed to \(newModeId)")
            browseItems = []; browseDepth = 0; browseTitle = ""
            presetsLoaded = false
        }

        // Fetch device info, modes, and EQ presets once per connection
        if !deviceInfoLoaded {
            deviceInfoLoaded = true
            let info = await client.getMultiple(ip, nodes: [
                "netRemote.sys.info.friendlyName",
                "netRemote.sys.caps.volumeSteps",
            ])
            radioName = info["netRemote.sys.info.friendlyName"] ?? radioName
            if let s = info["netRemote.sys.caps.volumeSteps"], let v = Double(s) {
                maxVolume = v
            }
        }
        if modes.isEmpty {
            let r = await client.list(ip, node: "netRemote.sys.caps.validModes")
            if r.status == "FS_OK" {
                modes = r.items.map { (id: $0.key, label: $0.fields["label"] ?? "Mode \($0.key)") }
            }
        }
        if eqPresets.isEmpty {
            let r = await client.list(ip, node: "netRemote.sys.caps.eqPresets")
            if r.status == "FS_OK" {
                eqPresets = r.items.map { (id: $0.key, label: $0.fields["label"] ?? "EQ \($0.key)") }
            }
        }
        modeName = modes.first { $0.id == modeId }?.label ?? "Mode \(modeId)"

        // Fetch presets on connect and mode change (not every poll)
        if power, !presetsLoaded {
            presetsLoaded = true
            let r = await client.list(ip, node: "netRemote.nav.presets")
            presets = r.status == "FS_OK" ? r.items.map { (key: $0.key, name: $0.fields["name"] ?? "Preset \($0.key)") } : []
        }
    }

    func updatePin(_ newPin: String) {
        radioPin = newPin
        client = FSAPIClient(pin: newPin)
    }

    // MARK: Actions

    func togglePower() async {
        _ = await client.set(radioIP, node: "netRemote.sys.power", value: power ? "0" : "1")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await poll()
    }

    func setVolume(_ vol: Int) async {
        _ = await client.set(radioIP, node: "netRemote.sys.audio.volume", value: "\(max(0, min(Int(maxVolume), vol)))")
    }

    func toggleMute() async {
        _ = await client.set(radioIP, node: "netRemote.sys.audio.mute", value: muted ? "0" : "1")
        muted.toggle()
    }

    func seekTo(_ ms: Int) {
        let ip = radioIP
        let clamped = max(0, min(ms, duration))
        Task { _ = await client.set(ip, node: "netRemote.play.position", value: "\(clamped)") }
    }

    func setEqPreset(_ id: Int) async {
        _ = await client.set(radioIP, node: "netRemote.sys.audio.eqPreset", value: "\(id)")
        eqPresetId = id
    }

    func playPause() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: playStatus == "playing" ? "2" : "1")
        try? await Task.sleep(nanoseconds: 300_000_000)
        await poll()
    }

    func stop() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "0")
        try? await Task.sleep(nanoseconds: 300_000_000)
        await poll()
    }

    func next() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "3")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await poll()
    }

    func prev() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "4")
        try? await Task.sleep(nanoseconds: 500_000_000)
        await poll()
    }

    func setMode(_ id: Int) async {
        _ = await client.set(radioIP, node: "netRemote.sys.mode", value: "\(id)")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await poll()
    }

    func selectPreset(_ key: Int) async {
        _ = await client.set(radioIP, node: "netRemote.nav.action.selectPreset", value: "\(key)")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await poll()
    }

    private func fire(_ node: String, _ value: String) {
        let ip = radioIP
        Task { _ = await client.set(ip, node: node, value: value) }
    }

    // MARK: Browse — stored Task avoids SwiftUI lifecycle cancellation

    private var browseTask: Task<Void, Never>?

    func startBrowse() {
        browseTask?.cancel()
        browseTask = Task {
            _ = await client.set(radioIP, node: "netRemote.nav.state", value: "1")
            await fetchBrowseItems()
        }
    }

    func browseInto(_ key: Int) {
        browseTask?.cancel()
        browseTask = Task {
            _ = await client.set(radioIP, node: "netRemote.nav.action.navigate", value: "\(key)")
            await fetchBrowseItems()
        }
    }

    func browseBack() {
        browseTask?.cancel()
        browseTask = Task {
            _ = await client.set(radioIP, node: "netRemote.nav.action.navigate", value: "4294967295")
            await fetchBrowseItems()
        }
    }

    func browseSelect(_ key: Int) {
        if let name = browseItems.first(where: { $0.key == key })?.name {
            trackName = name; artist = ""; infoText = ""
        }
        fire("netRemote.nav.action.selectItem", "\(key)")
    }

    private func fetchBrowseItems() async {
        let ip = radioIP
        isBrowseLoading = true
        defer { isBrowseLoading = false }

        // The radio's nav layer can take a moment to populate after enable/navigate.
        // Retry a few times if numItems is 0 or the list fetch fails.
        for attempt in 0 ..< 4 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            let info = await client.getMultiple(ip, nodes: [
                "netRemote.nav.depth",
                "netRemote.nav.currentTitle",
                "netRemote.nav.numItems",
            ])
            browseDepth = Int(info["netRemote.nav.depth"] ?? "0") ?? 0
            browseTitle = info["netRemote.nav.currentTitle"] ?? modeName

            let numItems = Int(info["netRemote.nav.numItems"] ?? "0") ?? 0
            if numItems == 0, attempt < 3 {
                continue
            }
            guard numItems > 0 else { browseItems = []; return }

            let r = await client.list(ip, node: "netRemote.nav.list", maxItems: min(numItems, 200))
            if r.status == "FS_OK", !r.items.isEmpty {
                browseItems = r.items.map { item in
                    (key: item.key,
                     name: item.fields["name"] ?? "Item \(item.key)",
                     isFolder: item.fields["type"] == "0")
                }
                return
            }
        }
        browseItems = []
    }

    func fetchAlarms() async {
        let r = await client.list(radioIP, node: "netRemote.sys.alarm.config")
        if r.status == "FS_OK" {
            alarms = r.items.map { (key: $0.key, fields: $0.fields) }
        }
    }

    func discover() async {
        isDiscovering = true
        defer { isDiscovering = false }
        if let ip = await discoverRadio(timeout: 4) {
            radioIP = ip
            await poll()
        } else {
            connectionError = "No Frontier Silicon radio found on the network"
        }
    }
}

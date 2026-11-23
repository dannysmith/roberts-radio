import Foundation
import Observation

/// Owns the radio's state and sends commands to it. Lives for the lifetime of the app.
@MainActor
@Observable
final class RadioViewModel {
    /// Connection
    var radioIP: String {
        didSet {
            UserDefaults.standard.set(radioIP, forKey: "radioBarIP")
            deviceInfoLoaded = false
            presetsLoaded = false
            modes = []
            eqPresets = []
        }
    }

    var radioPin: String {
        didSet { UserDefaults.standard.set(radioPin, forKey: "radioBarPIN") }
    }

    var isConnected = false
    var isDiscovering = false
    var connectionError: String?

    // State
    var power = false
    var radioName = ""
    var modeName = ""
    var modeId = 0
    var volume: Double = 0
    var maxVolume: Double = 31
    var muted = false

    // Now playing
    var playStatus = PlayStatus.stopped
    var trackName = ""
    var artist = ""
    var infoText = ""
    var artworkURL: URL?
    var position = 0
    var duration = 0

    // Lists
    var modes: [RadioMode] = []
    var presets: [RadioPreset] = []

    // EQ
    var eqPresets: [EQPreset] = []
    var eqPresetId = 0

    /// Alarms
    var alarms: [RadioAlarm] = []

    // Spotify
    var spotifyUser = ""
    var spotifyBitRate = ""
    var isSpotifyMode: Bool {
        modeName.lowercased().contains("spotify")
    }

    // Browse
    var browseItems: [BrowseItem] = []
    var browseTitle = ""
    var browseDepth = 0
    var isBrowseLoading = false

    /// Whether the menubar popover is open. Opening or closing it refreshes state and changes the poll rate.
    var isPopoverPresented = false {
        didSet {
            guard isPopoverPresented != oldValue else { return }
            Log("VM: Poll interval -> \(pollInterval) (popover \(isPopoverPresented ? "open" : "closed"))")
            requestPoll()
        }
    }

    /// Picker selection that switches the radio's mode when set.
    var selectedModeID: Int {
        get { modeId }
        set { Task { await setMode(newValue) } }
    }

    /// Picker selection that switches the radio's EQ preset when set.
    var selectedEQPresetID: Int {
        get { eqPresetId }
        set { Task { await setEqPreset(newValue) } }
    }

    @ObservationIgnored var isDraggingVolume = false

    @ObservationIgnored private var presetsLoaded = false
    @ObservationIgnored private var deviceInfoLoaded = false
    @ObservationIgnored private var pollRequested = false
    @ObservationIgnored private var pollDelay: Task<Void, Never>?
    @ObservationIgnored private var browseTask: Task<Void, Never>?
    @ObservationIgnored private var client: FSAPIClient

    private var pollInterval: Duration {
        isPopoverPresented ? .seconds(4) : .seconds(60)
    }

    init() {
        let ip = UserDefaults.standard.string(forKey: "radioBarIP") ?? "192.168.1.72"
        let pin = UserDefaults.standard.string(forKey: "radioBarPIN") ?? "1234"
        radioIP = ip
        radioPin = pin
        client = FSAPIClient(pin: pin)
        Log("APP: Init (ip=\(ip))")
        Task { await runPollLoop() }
    }

    // MARK: Polling

    /// Runs every poll in sequence for the lifetime of the app, so polls never overlap.
    private func runPollLoop() async {
        while true {
            pollRequested = false
            await poll()
            guard !pollRequested else { continue }

            let delay = Task<Void, Never> { try? await Task.sleep(for: pollInterval) }
            pollDelay = delay
            await delay.value
            pollDelay = nil
        }
    }

    /// Refreshes state now, or immediately after any poll already in flight.
    func requestPoll() {
        pollRequested = true
        pollDelay?.cancel()
    }

    private func requestPoll(after delay: Duration) async {
        try? await Task.sleep(for: delay)
        requestPoll()
    }

    private func poll() async {
        guard !radioIP.isEmpty else { return }

        let ip = radioIP

        // When popover is closed, only check power for the menubar icon
        if !isPopoverPresented {
            let r = await client.get(ip, node: "netRemote.sys.power")
            if r.status == "FS_OK" {
                let wasConnected = isConnected
                isConnected = true
                connectionError = nil
                power = r.value == "1"
                if !wasConnected {
                    Log("VM: Connected to \(ip)")
                }
            } else {
                if isConnected {
                    Log("VM: Lost connection to \(ip)")
                }
                isConnected = false
                connectionError = "Cannot reach radio at \(ip)"
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

        playStatus = PlayStatus(fsapiValue: vals["netRemote.play.status"])
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
            browseItems = []
            browseDepth = 0
            browseTitle = ""
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
                modes = r.items.map { RadioMode(id: $0.key, label: $0.fields["label"] ?? "Mode \($0.key)") }
            }
        }
        if eqPresets.isEmpty {
            let r = await client.list(ip, node: "netRemote.sys.caps.eqPresets")
            if r.status == "FS_OK" {
                eqPresets = r.items.map { EQPreset(id: $0.key, label: $0.fields["label"] ?? "EQ \($0.key)") }
            }
        }
        modeName = modes.first { $0.id == modeId }?.label ?? "Mode \(modeId)"

        // Fetch presets on connect and mode change (not every poll)
        if power, !presetsLoaded {
            presetsLoaded = true
            let r = await client.list(ip, node: "netRemote.nav.presets")
            presets = r.status == "FS_OK"
                ? r.items.map { RadioPreset(id: $0.key, name: $0.fields["name"] ?? "Preset \($0.key)") }
                : []
        }
    }

    func updatePin(_ newPin: String) {
        radioPin = newPin
        client = FSAPIClient(pin: newPin)
    }

    // MARK: Actions

    func togglePower() async {
        _ = await client.set(radioIP, node: "netRemote.sys.power", value: power ? "0" : "1")
        await requestPoll(after: .milliseconds(500))
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
        _ = await client.set(radioIP, node: "netRemote.play.control", value: playStatus == .playing ? "2" : "1")
        await requestPoll(after: .milliseconds(300))
    }

    func stop() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "0")
        await requestPoll(after: .milliseconds(300))
    }

    func next() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "3")
        await requestPoll(after: .milliseconds(500))
    }

    func prev() async {
        _ = await client.set(radioIP, node: "netRemote.play.control", value: "4")
        await requestPoll(after: .milliseconds(500))
    }

    func setMode(_ id: Int) async {
        _ = await client.set(radioIP, node: "netRemote.sys.mode", value: "\(id)")
        await requestPoll(after: .seconds(1))
    }

    func selectPreset(_ key: Int) async {
        _ = await client.set(radioIP, node: "netRemote.nav.action.selectPreset", value: "\(key)")
        await requestPoll(after: .seconds(1))
    }

    private func fire(_ node: String, _ value: String) {
        let ip = radioIP
        Task { _ = await client.set(ip, node: node, value: value) }
    }

    // MARK: Browse — stored Task avoids SwiftUI lifecycle cancellation

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
        if let name = browseItems.first(where: { $0.id == key })?.name {
            trackName = name
            artist = ""
            infoText = ""
        }
        fire("netRemote.nav.action.selectItem", "\(key)")
    }

    private func fetchBrowseItems() async {
        guard !Task.isCancelled else { return }
        let ip = radioIP
        isBrowseLoading = true
        // A cancelled fetch has been replaced by a newer one, which owns the loading state
        defer {
            if !Task.isCancelled {
                isBrowseLoading = false
            }
        }

        // The radio's nav layer can take a moment to populate after enable/navigate.
        // Retry a few times if numItems is 0 or the list fetch fails.
        for attempt in 0 ..< 4 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled else { return }

            let info = await client.getMultiple(ip, nodes: [
                "netRemote.nav.depth",
                "netRemote.nav.currentTitle",
                "netRemote.nav.numItems",
            ])
            guard !Task.isCancelled else { return }
            browseDepth = Int(info["netRemote.nav.depth"] ?? "0") ?? 0
            browseTitle = info["netRemote.nav.currentTitle"] ?? modeName

            let numItems = Int(info["netRemote.nav.numItems"] ?? "0") ?? 0
            if numItems == 0, attempt < 3 {
                continue
            }
            guard numItems > 0 else {
                browseItems = []
                return
            }

            let r = await client.list(ip, node: "netRemote.nav.list", maxItems: min(numItems, 200))
            guard !Task.isCancelled else { return }
            if r.status == "FS_OK", !r.items.isEmpty {
                browseItems = r.items.map { item in
                    BrowseItem(
                        id: item.key,
                        name: item.fields["name"] ?? "Item \(item.key)",
                        isFolder: item.fields["type"] == "0",
                    )
                }
                return
            }
        }
        browseItems = []
    }

    func fetchAlarms() async {
        let r = await client.list(radioIP, node: "netRemote.sys.alarm.config")
        if r.status == "FS_OK" {
            alarms = r.items.map(RadioAlarm.init(item:))
        }
    }

    func discover() async {
        isDiscovering = true
        defer { isDiscovering = false }
        if let ip = await discoverRadio(timeout: 4) {
            radioIP = ip
            requestPoll()
        } else {
            connectionError = "No Frontier Silicon radio found on the network"
        }
    }
}

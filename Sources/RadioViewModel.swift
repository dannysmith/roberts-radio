import Foundation
import Network
import Observation

/// Owns the radio's state and sends commands to it. Lives for the lifetime of the app.
@MainActor
@Observable
final class RadioViewModel {
    /// Connection
    var radioIP: String {
        didSet {
            UserDefaults.standard.set(radioIP, forKey: "radioBarIP")
            resetDeviceState()
        }
    }

    var radioPin: String {
        didSet { UserDefaults.standard.set(radioPin, forKey: "radioBarPIN") }
    }

    var isConnected = false
    var isDiscovering = false
    var connectionProblem: ConnectionProblem?

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
    var playCaps = PlayCaps.all
    var trackName = ""
    var artist = ""
    var infoText = ""
    var artworkURL: URL?
    var position = 0
    var duration = 0

    // Lists
    var modes: [RadioMode] = []
    var presets: [RadioPreset] = []
    /// How many preset slots the current mode has, including empty ones.
    var presetSlotCount = 0

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

    var bluetoothModeID: Int? {
        modes.first { $0.label.localizedCaseInsensitiveContains("bluetooth") }?.id
    }

    var primaryAction: PrimaryPlaybackAction? {
        PrimaryPlaybackAction(status: playStatus, caps: playCaps)
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

    /// The saved radio's stable ID. Automatic reconnection only accepts this radio.
    @ObservationIgnored private var radioID: String? {
        didSet { UserDefaults.standard.set(radioID, forKey: "radioBarID") }
    }

    /// Whether the host at `radioIP` has proven it's the right radio. No PIN is sent to it until it has.
    @ObservationIgnored private var isRadioVerified = false
    /// Whether a failed verification may search the network, limiting searches to one per lost connection.
    @ObservationIgnored private var needsNetworkSearch = true

    private static let maxBrowseAttempts = 15

    private var pollInterval: Duration {
        isPopoverPresented ? .seconds(4) : .seconds(60)
    }

    init() {
        let ip = UserDefaults.standard.string(forKey: "radioBarIP") ?? "192.168.1.72"
        let pin = UserDefaults.standard.string(forKey: "radioBarPIN") ?? "1234"
        radioIP = ip
        radioPin = pin
        client = FSAPIClient(pin: pin)
        radioID = UserDefaults.standard.string(forKey: "radioBarID")
        Log("APP: Init (ip=\(ip))")
        Task { await runPollLoop() }
        Task { await watchNetworkChanges() }
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
        if !isRadioVerified {
            guard await verifyConnection() else { return }
        }

        let ip = radioIP

        // When popover is closed, only check power for the menubar icon
        if !isPopoverPresented {
            let r = await client.get(ip, node: "netRemote.sys.power")
            guard ip == radioIP else { return }
            guard r.status == "FS_OK" else {
                await handleFailedPoll()
                return
            }
            markConnected()
            power = r.value == "1"
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
            "netRemote.play.caps",
            "netRemote.play.info.name",
            "netRemote.play.info.text",
            "netRemote.play.info.artist",
            "netRemote.play.info.graphicUri",
            "netRemote.play.info.duration",
            "netRemote.play.position",
            "netRemote.spotify.username",
            "netRemote.spotify.bitRate",
        ])

        guard ip == radioIP else { return }
        guard !vals.isEmpty else {
            await handleFailedPoll()
            return
        }
        markConnected()

        power = vals["netRemote.sys.power"] == "1"
        if !isDraggingVolume, let s = vals["netRemote.sys.audio.volume"], let v = Double(s) {
            volume = v
        }
        muted = vals["netRemote.sys.audio.mute"] == "1"
        if let e = vals["netRemote.sys.audio.eqPreset"], let v = Int(e) {
            eqPresetId = v
        }

        playStatus = PlayStatus(fsapiValue: vals["netRemote.play.status"])
        // The radio briefly drops capabilities while buffering, so keep the last stable set
        if playStatus != .buffering {
            playCaps = vals["netRemote.play.caps"].flatMap(Int.init).map(PlayCaps.init(rawValue:)) ?? .all
        }
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
            guard ip == radioIP else { return }
            radioName = info["netRemote.sys.info.friendlyName"] ?? radioName
            if let s = info["netRemote.sys.caps.volumeSteps"], let v = Double(s) {
                maxVolume = v
            }
        }
        if modes.isEmpty {
            let r = await client.list(ip, node: "netRemote.sys.caps.validModes")
            guard ip == radioIP else { return }
            if r.status == "FS_OK" {
                modes = r.items.map { RadioMode(id: $0.key, label: $0.fields["label"] ?? "Mode \($0.key)") }
            }
        }
        if eqPresets.isEmpty {
            let r = await client.list(ip, node: "netRemote.sys.caps.eqPresets")
            guard ip == radioIP else { return }
            if r.status == "FS_OK" {
                eqPresets = r.items.map { EQPreset(id: $0.key, label: $0.fields["label"] ?? "EQ \($0.key)") }
            }
        }
        modeName = modes.first { $0.id == modeId }?.label ?? "Mode \(modeId)"

        // Fetch presets on connect and mode change (not every poll)
        if power, !presetsLoaded {
            presetsLoaded = true
            await loadPresets(from: ip)
        }
    }

    /// Loads the current mode's presets. The radio turns navigation off on every mode change
    /// and blocks the preset list until it's back on.
    private func loadPresets(from ip: String) async {
        var result = await client.list(ip, node: "netRemote.nav.presets")
        if result.status == "FS_NODE_BLOCKED" {
            await send("netRemote.nav.state", "1")
            for _ in 0 ..< 4 where result.status == "FS_NODE_BLOCKED" {
                try? await Task.sleep(for: .milliseconds(500))
                result = await client.list(ip, node: "netRemote.nav.presets")
            }
        }
        guard ip == radioIP else { return }

        let slots = result.status == "FS_OK" ? result.items : []
        presetSlotCount = slots.count
        presets = RadioPreset.saved(in: slots)
    }

    // MARK: Connection

    /// Connects to a host the user chose, replacing the saved radio.
    func connect(to host: String) {
        radioID = nil
        radioIP = host
        isRadioVerified = false
        needsNetworkSearch = false
        requestPoll()
    }

    func updatePin(_ newPin: String) {
        radioPin = newPin
        client = FSAPIClient(pin: newPin)
        isRadioVerified = false
        needsNetworkSearch = false
        requestPoll()
    }

    /// Searches the network for any radio, and can replace the saved radio.
    func discover() async {
        isDiscovering = true
        defer { isDiscovering = false }

        switch await RadioDiscovery(pin: radioPin, radioID: nil).findRadio(preferring: radioIP) {
        case let .found(identity):
            adopt(identity)
            requestPoll()
        case let .wrongPIN(host):
            if host != radioIP {
                radioID = nil
                radioIP = host
            }
            isRadioVerified = false
            needsNetworkSearch = false
            setDisconnected(.wrongPIN)
        case .notFound:
            isRadioVerified = false
            needsNetworkSearch = false
            setDisconnected(.noRadioFound)
        }
    }

    /// Confirms `radioIP` is the right radio, searching the network once per lost connection if it isn't.
    private func verifyConnection() async -> Bool {
        let ip = radioIP
        let verification = await RadioVerifier(pin: radioPin).verify(host: ip)
        guard ip == radioIP else { return false }

        switch verification {
        case let .verified(identity) where radioID == nil || identity.radioID == radioID:
            adopt(identity)
            return true
        case .wrongPIN:
            setDisconnected(.wrongPIN)
        default:
            // Keep the result of a manual search rather than replacing it on the next poll
            setDisconnected(connectionProblem == .noRadioFound ? .noRadioFound : .radioNotResponding(host: ip))
        }

        guard needsNetworkSearch, let radioID else { return false }
        needsNetworkSearch = false
        Log("VM: Searching the network for the saved radio")
        guard case let .found(identity) = await RadioDiscovery(pin: radioPin, radioID: radioID).findRadio(),
              ip == radioIP
        else { return false }
        adopt(identity)
        return true
    }

    /// A failed poll may be a blip, so check the radio before reporting the connection as lost.
    private func handleFailedPoll() async {
        Log("VM: Poll failed for \(radioIP)")
        isRadioVerified = false
        needsNetworkSearch = true
        _ = await verifyConnection()
    }

    private func adopt(_ identity: RadioIdentity) {
        if identity.radioID != radioID {
            radioID = identity.radioID
            resetDeviceState()
        }
        if identity.host != radioIP {
            radioIP = identity.host
        }
        if !identity.name.isEmpty {
            radioName = identity.name
        }
        isRadioVerified = true
        needsNetworkSearch = false
        connectionProblem = nil
    }

    private func markConnected() {
        if !isConnected {
            Log("VM: Connected to \(radioIP)")
        }
        isConnected = true
        connectionProblem = nil
    }

    private func setDisconnected(_ problem: ConnectionProblem) {
        if isConnected {
            Log("VM: Lost connection to \(radioIP)")
        }
        isConnected = false
        connectionProblem = problem
    }

    private func resetDeviceState() {
        deviceInfoLoaded = false
        presetsLoaded = false
        modes = []
        eqPresets = []
    }

    /// Re-verifies the radio whenever the Mac moves to a different network.
    private func watchNetworkChanges() async {
        var currentNetwork: String?
        for await path in NWPathMonitor() {
            let network = "\(path.status) \(path.availableInterfaces.map(\.name)) \(path.gateways)"
            let previousNetwork = currentNetwork
            currentNetwork = network
            guard let previousNetwork, previousNetwork != network else { continue }

            Log("VM: Network changed")
            isRadioVerified = false
            needsNetworkSearch = true
            requestPoll()
        }
    }

    // MARK: Actions

    /// Sends a command to the verified radio.
    private func send(_ node: String, _ value: String) async {
        guard isRadioVerified else { return }
        _ = await client.set(radioIP, node: node, value: value)
    }

    func togglePower() async {
        await send("netRemote.sys.power", power ? "0" : "1")
        await requestPoll(after: .milliseconds(500))
    }

    func setVolume(_ vol: Int) async {
        await send("netRemote.sys.audio.volume", "\(max(0, min(Int(maxVolume), vol)))")
    }

    func toggleMute() async {
        await send("netRemote.sys.audio.mute", muted ? "0" : "1")
        muted.toggle()
    }

    func seekTo(_ ms: Int) {
        guard playCaps.contains(.seek) else { return }
        let clamped = max(0, min(ms, duration))
        Task { await send("netRemote.play.position", "\(clamped)") }
    }

    func setEqPreset(_ id: Int) async {
        await send("netRemote.sys.audio.eqPreset", "\(id)")
        eqPresetId = id
    }

    func performPrimaryAction() async {
        switch primaryAction {
        case .play: await send("netRemote.play.control", "1")
        case .pause: await send("netRemote.play.control", "2")
        case .stop: await send("netRemote.play.control", "0")
        case nil: return
        }
        await requestPoll(after: .milliseconds(300))
    }

    func stop() async {
        await send("netRemote.play.control", "0")
        await requestPoll(after: .milliseconds(300))
    }

    func next() async {
        await send("netRemote.play.control", "3")
        await requestPoll(after: .milliseconds(500))
    }

    func prev() async {
        await send("netRemote.play.control", "4")
        await requestPoll(after: .milliseconds(500))
    }

    func setMode(_ id: Int) async {
        await send("netRemote.sys.mode", "\(id)")
        await requestPoll(after: .seconds(1))
    }

    func selectPreset(_ key: Int) async {
        await send("netRemote.nav.action.selectPreset", "\(key)")
        await requestPoll(after: .seconds(1))
    }

    /// Reads the radio's mode directly, since `modeId` only updates while the popover is open.
    func fetchCurrentModeID() async -> Int? {
        guard isRadioVerified else { return nil }
        let result = await client.get(radioIP, node: "netRemote.sys.mode")
        return result.status == "FS_OK" ? result.value.flatMap(Int.init) : nil
    }

    /// Lets a new device pair with the radio. This can disconnect the device currently using it.
    func makeBluetoothDiscoverable() async {
        await send("netRemote.bluetooth.discoverableState", "1")
    }

    // MARK: Browse — stored Task avoids SwiftUI lifecycle cancellation

    func startBrowse() {
        browseTask?.cancel()
        browseTask = Task {
            await send("netRemote.nav.state", "1")
            await fetchBrowseItems()
        }
    }

    func browseInto(_ key: Int) {
        browseTask?.cancel()
        browseTask = Task {
            await send("netRemote.nav.action.navigate", "\(key)")
            await fetchBrowseItems()
        }
    }

    func browseBack() {
        browseTask?.cancel()
        browseTask = Task {
            await send("netRemote.nav.action.navigate", "4294967295")
            await fetchBrowseItems()
        }
    }

    func browseSelect(_ key: Int) {
        if let name = browseItems.first(where: { $0.id == key })?.name {
            trackName = name
            artist = ""
            infoText = ""
        }
        Task { await send("netRemote.nav.action.selectItem", "\(key)") }
    }

    private func fetchBrowseItems() async {
        guard !Task.isCancelled, isRadioVerified else { return }
        let ip = radioIP
        isBrowseLoading = true
        // A cancelled fetch has been replaced by a newer one, which owns the loading state
        defer {
            if !Task.isCancelled {
                isBrowseLoading = false
            }
        }

        // The radio's nav layer can take a moment to populate after enable/navigate.
        // Retry if numItems is 0, or while the list is blocked or still contains loading rows.
        for attempt in 0 ..< Self.maxBrowseAttempts {
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

            let r = await client.list(ip, node: "netRemote.nav.list")
            guard !Task.isCancelled else { return }
            if r.status == "FS_OK", !r.items.isEmpty, !r.items.contains(where: \.isLoadingPlaceholder) {
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
        guard isRadioVerified else { return }
        let r = await client.list(radioIP, node: "netRemote.sys.alarm.config")
        if r.status == "FS_OK" {
            alarms = r.items.map(RadioAlarm.init(item:))
        }
    }
}

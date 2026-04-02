// RadioBar.swift — Menubar app for controlling a Roberts Revival iStream 3L via FSAPI
// Build & run: ./bin/radiobar-gui
// Or manually: swiftc -parse-as-library RadioBar.swift -o RadioBar && ./RadioBar

import Foundation
import MenuBarExtraAccess
import SwiftUI

// MARK: - Debug Logging

let debugMode = CommandLine.arguments.contains("--debug")

func Log(_ msg: String) {
    guard debugMode else { return }
    let c = Calendar.current, d = Date()
    let ts = String(format: "%02d:%02d:%02d", c.component(.hour, from: d), c.component(.minute, from: d), c.component(.second, from: d))
    fputs("[\(ts)] \(msg)\n", stderr)
}

// MARK: - XML Parsing

/// Parses a GET response: <fsapiResponse><status>X</status><value><TYPE>V</TYPE></value></fsapiResponse>
final class FSAPIGetParser: NSObject, XMLParserDelegate {
    private(set) var status = ""
    private(set) var value: String?
    private var path: [String] = []
    private var text = ""

    static func parse(_ data: Data) -> (status: String, value: String?) {
        let handler = FSAPIGetParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.status, handler.value)
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        path.append(name)
        text = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "status", parent == "fsapiResponse" { status = t }
        else if parent == "value" { value = t }
    }
}

/// Parses LIST_GET_NEXT: items with key attribute and named fields
final class FSAPIListParser: NSObject, XMLParserDelegate {
    struct Item { let key: Int; var fields: [String: String] }

    private(set) var status = ""
    private(set) var items: [Item] = []
    private var path: [String] = []
    private var text = ""
    private var itemKey: Int?
    private var itemFields: [String: String] = [:]
    private var fieldName: String?

    static func parse(_ data: Data) -> (status: String, items: [Item]) {
        let handler = FSAPIListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.status, handler.items)
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes: [String: String] = [:]) {
        path.append(name)
        text = ""
        if name == "item" {
            itemKey = Int(attributes["key"] ?? "")
            itemFields = [:]
        } else if name == "field" {
            fieldName = attributes["name"]
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "status", parent == "fsapiResponse" { status = t }
        else if parent == "field", let fn = fieldName { itemFields[fn] = t }
        else if name == "item", let k = itemKey { items.append(Item(key: k, fields: itemFields)) }
    }
}

/// Parses GET_MULTIPLE: multiple <fsapiResponse> blocks inside <fsapiGetMultipleResponse>
final class FSAPIMultiParser: NSObject, XMLParserDelegate {
    private(set) var values: [String: String] = [:]
    private var path: [String] = []
    private var text = ""
    private var curNode = ""
    private var curStatus = ""
    private var curValue = ""

    static func parse(_ data: Data) -> [String: String] {
        let handler = FSAPIMultiParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.values
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        path.append(name)
        text = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (name, parent) {
        case ("status", "fsapiResponse"): curStatus = t
        case ("node", "fsapiResponse"): curNode = t
        case (_, "value"): curValue = t
        case ("fsapiResponse", _):
            if curStatus == "FS_OK", !curNode.isEmpty { values[curNode] = curValue }
            curNode = ""; curStatus = ""; curValue = ""
        default: break
        }
    }
}

// MARK: - FSAPI Client

actor FSAPIClient {
    private let pin: String
    private let session: URLSession

    init(pin: String = "1234") {
        self.pin = pin
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 5
        cfg.timeoutIntervalForResource = 8
        session = URLSession(configuration: cfg)
    }

    private func fetch(_ url: URL) async -> Data? {
        let start = Date()
        let label = url.path + "?" + (url.query ?? "")
        do {
            let (data, _) = try await session.data(from: url)
            Log("FSAPI: \(label) -> \(data.count)B (\(Int(Date().timeIntervalSince(start) * 1000))ms)")
            return data.isEmpty ? nil : data
        } catch {
            Log("FSAPI: \(label) -> error: \(error.localizedDescription)")
            return nil
        }
    }

    func get(_ ip: String, node: String) async -> (status: String, value: String?) {
        guard let url = URL(string: "http://\(ip)/fsapi/GET/\(node)?pin=\(pin)"),
              let data = await fetch(url) else { return ("FS_REQUEST_FAILED", nil) }
        return FSAPIGetParser.parse(data)
    }

    func set(_ ip: String, node: String, value: String) async -> String {
        let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        guard let url = URL(string: "http://\(ip)/fsapi/SET/\(node)?pin=\(pin)&value=\(v)"),
              let data = await fetch(url) else { return "FS_REQUEST_FAILED" }
        return FSAPIGetParser.parse(data).status
    }

    func list(_ ip: String, node: String, maxItems: Int = 100) async -> (status: String, items: [FSAPIListParser.Item]) {
        guard let url = URL(string: "http://\(ip)/fsapi/LIST_GET_NEXT/\(node)/-1?pin=\(pin)&maxItems=\(maxItems)"),
              let data = await fetch(url) else { return ("FS_REQUEST_FAILED", []) }
        return FSAPIListParser.parse(data)
    }

    /// GET_MULTIPLE, chunked to 5 nodes per request (radio rejects long URLs)
    func getMultiple(_ ip: String, nodes: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        for i in stride(from: 0, to: nodes.count, by: 5) {
            let chunk = Array(nodes[i ..< min(i + 5, nodes.count)])
            let q = chunk.map { "node=\($0)" }.joined(separator: "&")
            guard let url = URL(string: "http://\(ip)/fsapi/GET_MULTIPLE?pin=\(pin)&\(q)"),
                  let data = await fetch(url)
            else {
                if result.isEmpty { return [:] }
                break
            }
            result.merge(FSAPIMultiParser.parse(data)) { _, new in new }
        }
        return result
    }
}

// MARK: - SSDP Discovery

/// Discovers a Frontier Silicon radio on the local network via SSDP multicast.
func discoverRadio(timeout: TimeInterval = 3) async -> String? {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard sock >= 0 else { continuation.resume(returning: nil); return }
            defer { close(sock) }

            var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

            var dest = sockaddr_in()
            dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            dest.sin_family = sa_family_t(AF_INET)
            dest.sin_port = UInt16(1900).bigEndian
            inet_pton(AF_INET, "239.255.255.250", &dest.sin_addr)

            let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: urn:schemas-frontier-silicon-com:fs_reference:fsapi:1\r\n\r\n"
            let msgBytes = Array(msg.utf8)

            let sent = msgBytes.withUnsafeBufferPointer { buf in
                withUnsafePointer(to: &dest) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                        sendto(sock, buf.baseAddress, buf.count, 0, addr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            guard sent > 0 else { continuation.resume(returning: nil); return }

            var buffer = [UInt8](repeating: 0, count: 4096)
            var sender = sockaddr_in()
            var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let n = withUnsafeMutablePointer(to: &sender) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                    recvfrom(sock, &buffer, buffer.count, 0, addr, &senderLen)
                }
            }

            guard n > 0, let response = String(bytes: buffer[0 ..< n], encoding: .utf8) else {
                continuation.resume(returning: nil); return
            }

            // Extract IP from LOCATION header
            for line in response.components(separatedBy: "\r\n") {
                if line.uppercased().hasPrefix("LOCATION:") {
                    let urlStr = String(line.dropFirst("LOCATION:".count)).trimmingCharacters(in: .whitespaces)
                    if let url = URL(string: urlStr), let host = url.host {
                        continuation.resume(returning: host); return
                    }
                }
            }

            // Fallback: sender IP
            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &sender.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
            continuation.resume(returning: String(cString: ipBuf))
        }
    }
}

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
        didSet { if popoverVisible != oldValue { restartTimer() } }
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
                if !wasConnected { Log("VM: Connected to \(ip)") }
            } else {
                if isConnected { Log("VM: Lost connection to \(ip)") }
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
            if isConnected { Log("VM: Lost connection to \(ip)") }
            isConnected = false
            connectionError = "Cannot reach radio at \(ip)"
            return
        }
        if !isConnected { Log("VM: Connected to \(ip)") }
        isConnected = true
        connectionError = nil

        power = vals["netRemote.sys.power"] == "1"
        if !isDraggingVolume, let s = vals["netRemote.sys.audio.volume"], let v = Double(s) { volume = v }
        muted = vals["netRemote.sys.audio.mute"] == "1"
        if let e = vals["netRemote.sys.audio.eqPreset"], let v = Int(e) { eqPresetId = v }

        let statusMap = ["1": "buffering", "2": "playing", "3": "paused"]
        playStatus = statusMap[vals["netRemote.play.status"] ?? "0"] ?? "stopped"
        let newTrack = vals["netRemote.play.info.name"] ?? ""
        if newTrack != trackName { Log("VM: Now playing: \(newTrack)") }
        trackName = newTrack
        artist = vals["netRemote.play.info.artist"] ?? ""
        infoText = vals["netRemote.play.info.text"] ?? ""
        if let u = vals["netRemote.play.info.graphicUri"], !u.isEmpty { artworkURL = URL(string: u) }
        else { artworkURL = nil }
        if let d = vals["netRemote.play.info.duration"], let v = Int(d) { duration = v }
        if let p = vals["netRemote.play.position"], let v = Int(p) { position = v }

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
            if let s = info["netRemote.sys.caps.volumeSteps"], let v = Double(s) { maxVolume = v }
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
            if attempt > 0 { try? await Task.sleep(nanoseconds: 500_000_000) }

            let info = await client.getMultiple(ip, nodes: [
                "netRemote.nav.depth",
                "netRemote.nav.currentTitle",
                "netRemote.nav.numItems",
            ])
            browseDepth = Int(info["netRemote.nav.depth"] ?? "0") ?? 0
            browseTitle = info["netRemote.nav.currentTitle"] ?? modeName

            let numItems = Int(info["netRemote.nav.numItems"] ?? "0") ?? 0
            if numItems == 0, attempt < 3 { continue }
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
        if r.status == "FS_OK" { alarms = r.items.map { (key: $0.key, fields: $0.fields) } }
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
    @ObservedObject var vm: RadioViewModel
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
            vm.popoverVisible = true
            Task { await vm.poll() }
        }
        .onDisappear {
            vm.popoverVisible = false
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
                        if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                        else { Rectangle().fill(.quaternary).overlay(Image(systemName: "music.note").foregroundColor(.secondary)) }
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
            case "playing": Label("Playing", systemImage: "play.fill")
            case "paused": Label("Paused", systemImage: "pause.fill")
            case "buffering": Label("Buffering", systemImage: "ellipsis")
            default: Label("Stopped", systemImage: "stop.fill")
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
                Image(systemName: vm.playStatus == "playing" ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
            }.buttonStyle(.borderless).help(vm.playStatus == "playing" ? "Pause" : "Play")

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
                    if !editing { Task { await vm.setVolume(Int(vm.volume)) } }
                }

            Text("\(Int(vm.volume))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
    }

    private var volumeIcon: String {
        if vm.volume == 0 { return "speaker.fill" }
        if vm.volume < vm.maxVolume * 0.33 { return "speaker.wave.1.fill" }
        if vm.volume < vm.maxVolume * 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    // MARK: Mode

    private var modeView: some View {
        HStack(spacing: 8) {
            Text("Mode").font(.caption).foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: { vm.modeId },
                set: { id in Task { await vm.setMode(id) } }
            )) {
                ForEach(vm.modes, id: \.id) { mode in
                    Text(mode.label).tag(mode.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if !vm.eqPresets.isEmpty {
                Spacer()
                Text("EQ").font(.caption).foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { vm.eqPresetId },
                    set: { id in Task { await vm.setEqPreset(id) } }
                )) {
                    ForEach(vm.eqPresets, id: \.id) { eq in
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

    private var presetsPanel: some View {
        Group {
            if vm.presets.isEmpty {
                Text("No presets for this mode")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.presets, id: \.key) { preset in
                            PresetRow(number: preset.key + 1, name: preset.name) {
                                Task { await vm.selectPreset(preset.key) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredBrowseItems: [(key: Int, name: String, isFolder: Bool)] {
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
                            ForEach(items, id: \.key) { item in
                                BrowseRow(name: item.name, isFolder: item.isFolder) {
                                    filterText = ""
                                    if item.isFolder { vm.browseInto(item.key) }
                                    else { vm.browseSelect(item.key) }
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
                if showAlarms, vm.alarms.isEmpty { Task { await vm.fetchAlarms() } }
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
                        ForEach(vm.alarms, id: \.key) { alarm in
                            alarmRow(alarm)
                        }
                    }
                }
            }
        }
    }

    private func alarmRow(_ alarm: (key: Int, fields: [String: String])) -> some View {
        let f = alarm.fields
        let enabled = f["enable"] == "1"
        let time = formatAlarmTime(f["time"] ?? "")
        let days = formatWeekdays(f["weekdays"])
        let vol = f["volume"]
        return HStack(spacing: 6) {
            Circle().fill(enabled ? Color.green : Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            Text(time).font(.system(size: 11, weight: .medium, design: .monospaced))
            if let days { Text(days).font(.system(size: 10)).foregroundColor(.secondary) }
            Spacer()
            if let vol {
                Image(systemName: "speaker.wave.1.fill").font(.system(size: 8)).foregroundColor(.secondary)
                Text(vol).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .opacity(enabled ? 1.0 : 0.5)
    }

    private func formatAlarmTime(_ raw: String) -> String {
        if let secs = Int(raw) { return String(format: "%02d:%02d", secs / 3600, (secs % 3600) / 60) }
        return raw.isEmpty ? "--:--" : raw
    }

    private func formatWeekdays(_ raw: String?) -> String? {
        guard let raw, let mask = Int(raw), mask > 0 else { return nil }
        if mask == 127 { return "Every day" }
        if mask == 31 { return "Weekdays" }
        if mask == 96 { return "Weekends" }
        let days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        return (0 ..< 7).filter { mask & (1 << $0) != 0 }.map { days[$0] }.joined(separator: " ")
    }

    // MARK: Settings

    private var settingsFields: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                TextField("IP address", text: $ipField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { vm.radioIP = ipField; Task { await vm.poll() } }
                Button("Set") { vm.radioIP = ipField; Task { await vm.poll() } }
                    .controlSize(.small)
            }
            HStack(spacing: 4) {
                Text("PIN").font(.system(size: 10)).foregroundColor(.secondary)
                TextField("PIN", text: $pinField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60)
                    .onSubmit { vm.updatePin(pinField); Task { await vm.poll() } }
                Spacer()
                Button(action: { Task { await vm.discover() } }) {
                    HStack(spacing: 4) {
                        if vm.isDiscovering { ProgressView().controlSize(.small).scaleEffect(0.7) }
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

// MARK: - App

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if !CommandLine.arguments.contains("--dock") {
            NSApp.setActivationPolicy(.accessory)
        }
        Log("APP: Launched")
    }
}

@main
struct RadioBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var vm = RadioViewModel()
    @State private var isMenuPresented = false

    var body: some Scene {
        MenuBarExtra {
            RadioMenuView(vm: vm)
                .introspectMenuBarExtraWindow { window in
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.isMovable = false
                    // Pin to the screen that owns the menubar icon
                    if let screen = window.screen ?? NSApp.keyWindow?.screen {
                        window.setFrame(window.frame, display: true)
                        window.constrainFrameRect(window.frame, to: screen)
                    }
                }
        } label: {
            Image(systemName: vm.isConnected && vm.power ? "radio.fill" : "radio")
        }
        .menuBarExtraAccess(isPresented: $isMenuPresented)
        .menuBarExtraStyle(.window)
    }
}

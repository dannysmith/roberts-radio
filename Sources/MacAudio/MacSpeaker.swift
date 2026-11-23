import AppKit
import IOBluetooth
import Observation

/// Receives the result of an asynchronous Bluetooth connection. Success is confirmed by the audio output appearing.
private final class BluetoothConnectionTarget: NSObject {
    @objc(connectionComplete:status:)
    func connectionComplete(_ device: IOBluetoothDevice?, status: IOReturn) {
        Log("MacSpeaker: Connection to \(device?.nameOrAddress ?? "device") finished with status \(status)")
    }
}

/// Uses the radio as the Mac's Bluetooth speaker, restoring the previous radio mode and audio output afterwards.
@MainActor
@Observable
final class MacSpeaker {
    enum State {
        case off, connecting, connected, disconnecting
    }

    private(set) var state = State.off
    private(set) var problem: String?
    private(set) var needsPairing = false

    @ObservationIgnored private let radio: RadioViewModel
    @ObservationIgnored private var device: IOBluetoothDevice?
    @ObservationIgnored private var connectionTarget: BluetoothConnectionTarget?
    @ObservationIgnored private var radioOutputUID: String?
    @ObservationIgnored private var previousOutputUID: String?
    @ObservationIgnored private var previousModeID: Int?
    @ObservationIgnored private var monitor: Task<Void, Never>?

    init(radio: RadioViewModel) {
        self.radio = radio
    }

    func toggle() async {
        switch state {
        case .off: await connect()
        case .connected: await disconnect()
        case .connecting, .disconnecting: break
        }
    }

    /// Makes the radio discoverable and opens Bluetooth settings for the one-time pairing.
    func beginPairing() async {
        guard let bluetoothMode = radio.bluetoothModeID else { return }
        if await radio.fetchCurrentModeID() != bluetoothMode {
            await radio.setMode(bluetoothMode)
        }
        await radio.makeBluetoothDiscoverable()
        if let settings = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(settings)
        }
        needsPairing = false
        problem = "Connect to \(radio.radioName) in Bluetooth settings, then press Mac Audio."
    }

    private func connect() async {
        problem = nil
        needsPairing = false

        guard let bluetoothMode = radio.bluetoothModeID else {
            problem = "This radio doesn't have a Bluetooth mode."
            return
        }
        guard let pairedRadio, let name = pairedRadio.name else {
            needsPairing = true
            problem = "This Mac isn't paired with \(radio.radioName) yet."
            return
        }

        state = .connecting
        device = pairedRadio
        let currentMode = await radio.fetchCurrentModeID() ?? radio.modeId
        previousModeID = currentMode
        previousOutputUID = AudioOutputs.defaultOutputUID
        if currentMode != bluetoothMode {
            await radio.setMode(bluetoothMode)
        }

        let target = BluetoothConnectionTarget()
        connectionTarget = target
        pairedRadio.openConnection(target)

        guard let outputUID = await waitForOutput(named: name), AudioOutputs.selectOutput(uid: outputUID) else {
            pairedRadio.closeConnection()
            await restoreRadioMode()
            finishSession()
            problem = "Couldn't connect. If a phone is using the radio, disconnect it and try again."
            return
        }

        radioOutputUID = outputUID
        state = .connected
        monitor = Task { await monitorConnection(outputUID: outputUID, deviceName: name) }
    }

    private func disconnect() async {
        state = .disconnecting
        monitor?.cancel()

        if AudioOutputs.defaultOutputUID == radioOutputUID, let previousOutputUID {
            AudioOutputs.selectOutput(uid: previousOutputUID)
        }
        device?.closeConnection()
        await restoreRadioMode()
        finishSession()
    }

    /// Only restores the mode if the radio is still in Bluetooth mode, so a manual mode change is kept.
    private func restoreRadioMode() async {
        guard let previousModeID, let bluetoothMode = radio.bluetoothModeID, previousModeID != bluetoothMode,
              await radio.fetchCurrentModeID() == bluetoothMode
        else { return }
        await radio.setMode(previousModeID)
    }

    private func finishSession() {
        monitor = nil
        device = nil
        connectionTarget = nil
        radioOutputUID = nil
        previousOutputUID = nil
        previousModeID = nil
        state = .off
    }

    private func waitForOutput(named name: String) async -> String? {
        for _ in 0 ..< 60 {
            if let uid = AudioOutputs.bluetoothOutputUID(named: name) {
                return uid
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return nil
    }

    /// Ends the session if the Bluetooth output disappears, leaving macOS to choose the fallback output.
    private func monitorConnection(outputUID: String, deviceName: String) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if AudioOutputs.bluetoothOutputUID(named: deviceName) != outputUID {
                Log("MacSpeaker: Bluetooth output disappeared")
                finishSession()
                problem = "Bluetooth disconnected from the radio."
                return
            }
        }
    }

    private var pairedRadio: IOBluetoothDevice? {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.first { $0.name?.caseInsensitiveCompare(radio.radioName) == .orderedSame }
    }
}

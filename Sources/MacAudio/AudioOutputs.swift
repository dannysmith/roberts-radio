import CoreAudio

/// Reads and changes the Mac's default audio output. System alert sounds are left alone.
enum AudioOutputs {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static var defaultOutputUID: String? {
        guard let device: AudioDeviceID = value(of: kAudioHardwarePropertyDefaultOutputDevice, on: system) else {
            return nil
        }
        return string(of: kAudioDevicePropertyDeviceUID, on: device)
    }

    /// The UID of the Bluetooth output with this name, once macOS has brought it up.
    static func bluetoothOutputUID(named name: String) -> String? {
        for device in allDevices {
            guard let transport: UInt32 = value(of: kAudioDevicePropertyTransportType, on: device),
                  transport == kAudioDeviceTransportTypeBluetooth,
                  hasOutputStreams(device),
                  string(of: kAudioObjectPropertyName, on: device)?.caseInsensitiveCompare(name) == .orderedSame
            else { continue }
            return string(of: kAudioDevicePropertyDeviceUID, on: device)
        }
        return nil
    }

    @discardableResult
    static func selectOutput(uid: String) -> Bool {
        guard var device = device(withUID: uid) else { return false }
        var address = globalAddress(kAudioHardwarePropertyDefaultOutputDevice)
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        return AudioObjectSetPropertyData(system, &address, 0, nil, size, &device) == noErr
    }

    private static var allDevices: [AudioDeviceID] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }

        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices
    }

    private static func device(withUID uid: String) -> AudioDeviceID? {
        var address = globalAddress(kAudioHardwarePropertyTranslateUIDToDevice)
        var identifier = uid as CFString
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafePointer(to: &identifier) { qualifier in
            AudioObjectGetPropertyData(system, &address, UInt32(MemoryLayout<CFString>.size), qualifier, &size, &device)
        }
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func hasOutputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain,
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func value<T: FixedWidthInteger>(of selector: AudioObjectPropertySelector, on object: AudioObjectID) -> T? {
        var address = globalAddress(selector)
        var result = T.zero
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result) == noErr ? result : nil
    }

    private static func string(of selector: AudioObjectPropertySelector, on object: AudioObjectID) -> String? {
        var address = globalAddress(selector)
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &result) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return result?.takeRetainedValue() as String?
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain,
        )
    }
}

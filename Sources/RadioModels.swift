import Foundation

/// Playback state reported by `netRemote.play.status`.
enum PlayStatus: Equatable {
    case stopped, buffering, playing, paused

    init(fsapiValue: String?) {
        switch fsapiValue {
        case "1", "4": self = .buffering
        case "2": self = .playing
        case "3": self = .paused
        default: self = .stopped
        }
    }
}

/// Playback commands the current source supports, from the `netRemote.play.caps` bitmask.
struct PlayCaps: OptionSet, Equatable {
    let rawValue: Int

    static let pause = PlayCaps(rawValue: 1 << 0)
    static let stop = PlayCaps(rawValue: 1 << 1)
    static let skipNext = PlayCaps(rawValue: 1 << 2)
    static let skipPrevious = PlayCaps(rawValue: 1 << 3)
    static let fastForward = PlayCaps(rawValue: 1 << 4)
    static let rewind = PlayCaps(rawValue: 1 << 5)
    static let seek = PlayCaps(rawValue: 1 << 8)
    static let skipForward = PlayCaps(rawValue: 1 << 14)
    static let skipBackward = PlayCaps(rawValue: 1 << 15)

    /// Used when the radio doesn't report capabilities, leaving every control available.
    static let all: PlayCaps = [
        .pause, .stop, .skipNext, .skipPrevious, .fastForward, .rewind, .seek, .skipForward, .skipBackward,
    ]

    var canSkipNext: Bool {
        !isDisjoint(with: [.skipNext, .fastForward, .skipForward])
    }

    var canSkipPrevious: Bool {
        !isDisjoint(with: [.skipPrevious, .rewind, .skipBackward])
    }
}

/// What the main playback button does for the current status and capabilities.
enum PrimaryPlaybackAction: Equatable {
    case play, pause, stop

    /// Live streams can't pause, so the button stops them instead. Nil means no action is available.
    init?(status: PlayStatus, caps: PlayCaps) {
        switch status {
        case .paused, .stopped:
            self = .play
        case .playing, .buffering:
            if caps.contains(.pause) {
                self = .pause
            } else if caps.contains(.stop) {
                self = .stop
            } else {
                return nil
            }
        }
    }
}

/// Why the app isn't connected to a radio.
enum ConnectionProblem: Equatable {
    case radioNotResponding(host: String)
    case wrongPIN
    case noRadioFound

    var message: String {
        switch self {
        case let .radioNotResponding(host):
            "Can't reach your radio at \(host). If it's still playing, try restarting your router."
        case .wrongPIN:
            "The radio rejected this PIN."
        case .noRadioFound:
            "No radio found on this network."
        }
    }
}

struct RadioMode: Identifiable, Equatable {
    let id: Int
    let label: String
}

struct EQPreset: Identifiable, Equatable {
    let id: Int
    let label: String
}

struct RadioPreset: Identifiable, Equatable {
    let id: Int
    let name: String
}

struct BrowseItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let isFolder: Bool
}

/// An alarm from `netRemote.sys.alarm.config`, with its raw fields formatted for display.
struct RadioAlarm: Identifiable, Equatable {
    let id: Int
    let isEnabled: Bool
    let time: String
    let days: String?
    let volume: String?

    init(item: FSAPIListParser.Item) {
        id = item.key
        isEnabled = item.fields["enable"] == "1"
        time = Self.formatTime(item.fields["time"] ?? "")
        days = Self.formatWeekdays(item.fields["weekdays"])
        volume = item.fields["volume"]
    }

    private static func formatTime(_ raw: String) -> String {
        if let secs = Int(raw) {
            return String(format: "%02d:%02d", secs / 3600, (secs % 3600) / 60)
        }
        return raw.isEmpty ? "--:--" : raw
    }

    private static func formatWeekdays(_ raw: String?) -> String? {
        guard let raw, let mask = Int(raw), mask > 0 else { return nil }
        switch mask {
        case 127: return "Every day"
        case 31: return "Weekdays"
        case 96: return "Weekends"
        default:
            let days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            return (0 ..< 7).filter { mask & (1 << $0) != 0 }.map { days[$0] }.joined(separator: " ")
        }
    }
}

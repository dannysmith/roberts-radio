import Foundation

/// Playback state reported by `netRemote.play.status`.
enum PlayStatus: Equatable {
    case stopped, buffering, playing, paused

    init(fsapiValue: String?) {
        switch fsapiValue {
        case "1": self = .buffering
        case "2": self = .playing
        case "3": self = .paused
        default: self = .stopped
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

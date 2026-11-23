import Foundation

// MARK: - Debug Logging

let debugMode = CommandLine.arguments.contains("--debug")

func Log(_ msg: String) {
    guard debugMode else { return }
    let c = Calendar.current, d = Date()
    let ts = String(format: "%02d:%02d:%02d", c.component(.hour, from: d), c.component(.minute, from: d), c.component(.second, from: d))
    fputs("[\(ts)] \(msg)\n", stderr)
}

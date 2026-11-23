import Foundation

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
                if result.isEmpty {
                    return [:]
                }
                break
            }
            result.merge(FSAPIMultiParser.parse(data)) { _, new in new }
        }
        return result
    }
}

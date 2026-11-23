import Network

/// Finds radios advertising `_undok._tcp`. Results can come from the system's Bonjour cache, so they must be verified.
enum BonjourSearch {
    static func hosts(for duration: Duration) async -> [String] {
        let endpoints = await browse(for: duration)
        return await withTaskGroup(of: String?.self) { group in
            for endpoint in endpoints {
                group.addTask { await resolve(endpoint.nwEndpoint) }
            }
            var hosts: [String] = []
            for await host in group {
                if let host {
                    hosts.append(host)
                }
            }
            return hosts
        }
    }

    private static func browse(for duration: Duration) async -> [Bonjour.Endpoint] {
        await withTaskGroup(of: [Bonjour.Endpoint].self) { group in
            group.addTask {
                let browser = NetworkBrowser(for: .bonjour("_undok._tcp"))
                let found = try? await browser.run { endpoints -> NetworkBrowser<Bonjour>.RunResult<[Bonjour.Endpoint]> in
                    endpoints.isEmpty ? .continue : .finish(endpoints)
                }
                return found ?? []
            }
            group.addTask {
                try? await Task.sleep(for: duration)
                return []
            }
            let endpoints = await group.next() ?? []
            group.cancelAll()
            return endpoints
        }
    }

    /// Connects to a Bonjour service to learn its IPv4 address.
    private static func resolve(_ endpoint: NWEndpoint) async -> String? {
        let parameters = NWParameters.tcp
        (parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)?.version = .v4
        let connection = NWConnection(to: endpoint, using: parameters)
        defer { connection.cancel() }

        let states = AsyncStream<NWConnection.State> { continuation in
            connection.stateUpdateHandler = { continuation.yield($0) }
        }
        connection.start(queue: .global())

        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                for await state in states {
                    switch state {
                    case .ready: return ipv4Address(of: connection)
                    case .failed, .cancelled: return nil
                    default: continue
                    }
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }
            let host = await group.next() ?? nil
            group.cancelAll()
            return host
        }
    }

    private static func ipv4Address(of connection: NWConnection) -> String? {
        guard case let .hostPort(host, _)? = connection.currentPath?.remoteEndpoint,
              case let .ipv4(address) = host
        else { return nil }
        return address.rawValue.map(String.init).joined(separator: ".")
    }
}

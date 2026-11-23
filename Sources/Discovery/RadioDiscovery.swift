import Foundation

/// Outcome of searching the local network for a radio.
enum DiscoveryResult: Equatable, Sendable {
    case found(RadioIdentity)
    /// A radio answered but rejected the PIN.
    case wrongPIN(host: String)
    case notFound
}

/// Finds a radio on the local network, trying faster methods first and verifying every candidate.
struct RadioDiscovery: Sendable {
    let pin: String
    /// When set, only this radio is accepted.
    let radioID: String?

    private static let announcementWindow = Duration.milliseconds(2500)
    private static let maxConcurrentChecks = 48

    /// Each stage is slower but more reliable than the one before it.
    private enum Stage: CaseIterable {
        case preferred, announced, subnetScan
    }

    func findRadio(preferring preferredHost: String? = nil) async -> DiscoveryResult {
        let network = await LocalNetwork.current()
        var best = DiscoveryResult.notFound
        var tried = Set<String>()

        for stage in Stage.allCases {
            let candidates = await candidates(for: stage, preferredHost: preferredHost, network: network)
            let hosts = candidates.filter { tried.insert($0).inserted }
            Log("Discovery: \(stage) -> \(hosts.count) candidate(s)")

            let result = await firstMatch(in: hosts)
            if case .found = result {
                return result
            }
            if best == .notFound {
                best = result
            }
            // Without a specific radio to find, one that rejected the PIN is the answer
            if radioID == nil, best != .notFound {
                return best
            }
        }
        return best
    }

    private func candidates(for stage: Stage, preferredHost: String?, network: LocalNetwork?) async -> [String] {
        switch stage {
        case .preferred:
            return preferredHost.map { [$0] } ?? []
        case .announced:
            guard let network else { return [] }
            async let bonjour = BonjourSearch.hosts(for: Self.announcementWindow)
            async let ssdp = SSDPSearch.hosts(localAddress: network.address, for: Self.announcementWindow)
            return await bonjour + ssdp
        case .subnetScan:
            return network?.hosts ?? []
        }
    }

    private func firstMatch(in hosts: [String]) async -> DiscoveryResult {
        let verifier = RadioVerifier(pin: pin)
        return await withTaskGroup(of: RadioVerification.self) { group in
            var best = DiscoveryResult.notFound
            var remaining = hosts.makeIterator()

            for _ in 0 ..< Self.maxConcurrentChecks {
                guard let host = remaining.next() else { break }
                group.addTask { await verifier.verify(host: host) }
            }

            while let verification = await group.next() {
                switch verification {
                case let .verified(identity) where radioID == nil || identity.radioID == radioID:
                    group.cancelAll()
                    return .found(identity)
                case let .wrongPIN(host) where best == .notFound:
                    best = .wrongPIN(host: host)
                default:
                    break
                }
                if let host = remaining.next() {
                    group.addTask { await verifier.verify(host: host) }
                }
            }
            return best
        }
    }
}

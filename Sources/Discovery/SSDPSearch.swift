import Foundation

/// Finds radios with an SSDP multicast search.
/// Uses BSD sockets because Network framework can't receive unicast replies to a multicast send.
enum SSDPSearch {
    private static let targets = [
        "urn:schemas-frontier-silicon-com:undok:fsapi:1",
        "urn:schemas-frontier-silicon-com:fs_reference:fsapi:1",
        "urn:schemas-frontier-silicon-com:invalid:fsapi:1",
    ]
    private static let searchAttempts = 3

    /// Searches on the interface with `localAddress` and returns the address of each radio that replies.
    @concurrent
    static func hosts(localAddress: UInt32, for duration: Duration) async -> [String] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var interface = in_addr(s_addr: localAddress.bigEndian)
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &interface, socklen_t(MemoryLayout<in_addr>.size))
        var ttl: UInt8 = 2
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size))
        _ = fcntl(sock, F_SETFL, O_NONBLOCK)

        var hosts = Set<String>()
        var attempts = 0
        let clock = ContinuousClock()
        let deadline = clock.now + duration

        // UDP multicast is unreliable on Wi-Fi, so repeat the search
        while clock.now < deadline, !Task.isCancelled {
            if attempts < searchAttempts {
                targets.forEach { send(target: $0, on: sock) }
                attempts += 1
            }
            readReplies(from: sock, into: &hosts)
            try? await Task.sleep(for: .milliseconds(250))
        }
        readReplies(from: sock, into: &hosts)
        return Array(hosts)
    }

    /// Whether an SSDP reply came from a Frontier Silicon device.
    static func isRadioReply(_ reply: String) -> Bool {
        let lines = reply.components(separatedBy: "\r\n")
        guard lines.first?.uppercased().hasPrefix("HTTP/1.1 200") == true else { return false }
        return lines.contains { line in
            let upper = line.uppercased()
            guard upper.hasPrefix("ST:") else { return false }
            return upper.dropFirst(3).trimmingCharacters(in: .whitespaces).hasPrefix("URN:SCHEMAS-FRONTIER-SILICON-COM:")
        }
    }

    private static func send(target: String, on sock: Int32) {
        let message = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: \(target)\r\n\r\n"
        let bytes = Array(message.utf8)

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &destination.sin_addr)

        _ = withUnsafePointer(to: &destination) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                sendto(sock, bytes, bytes.count, 0, address, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
    }

    private static func readReplies(from sock: Int32, into hosts: inout Set<String>) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let capacity = buffer.count

        while true {
            var sender = sockaddr_in()
            var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    recvfrom(sock, &buffer, capacity, 0, address, &senderLength)
                }
            }
            guard count > 0 else { return }

            // Trust the sender's address rather than the LOCATION header, which could point anywhere
            if let reply = String(bytes: buffer[0 ..< count], encoding: .utf8), isRadioReply(reply) {
                hosts.insert(LocalNetwork.dottedQuad(UInt32(bigEndian: sender.sin_addr.s_addr)))
            }
        }
    }
}

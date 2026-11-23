import Foundation

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
            let ipBytes = ipBuf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            continuation.resume(returning: String(bytes: ipBytes, encoding: .utf8))
        }
    }
}

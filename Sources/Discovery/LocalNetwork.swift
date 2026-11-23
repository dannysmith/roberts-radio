import Foundation
import Network

/// The Mac's IPv4 address and netmask on its current Wi-Fi or Ethernet network.
struct LocalNetwork: Equatable, Sendable {
    let address: UInt32
    let netmask: UInt32

    /// Every other host address on this subnet, limited to the surrounding /24.
    var hosts: [String] {
        let mask = netmask | 0xFFFF_FF00
        let base = address & mask
        return stride(from: UInt32(1), to: ~mask, by: 1)
            .map { base | $0 }
            .filter { $0 != address }
            .map(Self.dottedQuad)
    }

    static func current() async -> LocalNetwork? {
        guard let path = await NWPathMonitor().first(where: { _ in true }) else { return nil }
        return path.availableInterfaces
            .filter { $0.type == .wifi || $0.type == .wiredEthernet }
            .lazy
            .compactMap { network(onInterface: $0.name) }
            .first
    }

    static func dottedQuad(_ address: UInt32) -> String {
        [24, 16, 8, 0].map { String((address >> $0) & 0xFF) }.joined(separator: ".")
    }

    private static func network(onInterface name: String) -> LocalNetwork? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard String(cString: entry.ifa_name) == name,
                  let address = entry.ifa_addr,
                  let netmask = entry.ifa_netmask,
                  address.pointee.sa_family == sa_family_t(AF_INET)
            else { continue }
            return LocalNetwork(address: ipv4Value(address), netmask: ipv4Value(netmask))
        }
        return nil
    }

    private static func ipv4Value(_ address: UnsafePointer<sockaddr>) -> UInt32 {
        address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
    }
}

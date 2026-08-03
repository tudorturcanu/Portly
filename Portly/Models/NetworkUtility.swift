//
//  NetworkUtility.swift
//  Portly
//

import Foundation

enum NetworkUtility {
    /// Returns the local Wi-Fi or Ethernet IPv4 address (e.g. "192.168.1.150"), or nil if offline / loopback only.
    static var localIPAddress: String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            // Must be IPv4, UP, running, and NOT loopback
            guard addr.sa_family == UInt8(AF_INET) else { continue }
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                ptr.pointee.ifa_addr,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                let ip = String(cString: hostname)
                if !ip.isEmpty && ip != "127.0.0.1" {
                    address = ip
                    let name = String(cString: ptr.pointee.ifa_name)
                    if name == "en0" {
                        break
                    }
                }
            }
        }
        return address
    }
}

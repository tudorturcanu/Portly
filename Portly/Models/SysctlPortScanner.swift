//
//  SysctlPortScanner.swift
//  Portly
//
//  Sandbox-compatible scanner used by the App Store build. Reads the kernel's
//  socket tables via sysctl — the same data source netstat uses — because a
//  sandboxed app can't spawn lsof to inspect other processes.
//

import Foundation

enum SysctlPortScanner {
    static func scan() -> [ListeningPort] {
        var ports = scanTable("net.inet.tcp.pcblist_n", networkProtocol: .tcp)
        ports += scanTable("net.inet.udp.pcblist_n", networkProtocol: .udp)

        // A process listening on IPv4 and IPv6 produces one entry per socket;
        // keep one per pid + port + protocol, matching the lsof backend.
        var seen = Set<String>()
        return ports.filter { seen.insert($0.id).inserted }.sorted()
    }

    // Field offsets within the xinpcb_n / xsocket_n / xtcpcb_n structures
    // emitted by the pcblist_n sysctls (see xnu: netinet/in_pcb.h,
    // sys/socketvar.h, netinet/tcp_var.h). Each block starts with
    // u32 length + u32 kind; blocks for one socket appear consecutively,
    // starting with the inpcb block.
    private enum Kind {
        static let socket: UInt32 = 0x001   // XSO_SOCKET
        static let inpcb: UInt32 = 0x010    // XSO_INPCB
        static let tcpcb: UInt32 = 0x020    // XSO_TCPCB
    }

    // Offsets verified empirically against known sockets (see git history);
    // the kernel packs these structs tighter than a naive C layout suggests.
    private enum Inpcb {                    // xinpcb_n, 104 bytes
        static let minLength = 104
        static let foreignPort = 16         // u16, network byte order
        static let localPort = 18           // u16, network byte order
        static let vflag = 44               // u8: 0x1 = IPv4, 0x2 = IPv6
        static let localAddress = 64        // 16 bytes (in6_addr, or pad[12] + in_addr)
    }

    private enum Socket {                   // xsocket_n, 104 bytes
        static let minLength = 80
        static let uid = 64                 // u32
        static let lastPid = 68             // i32
        static let effectivePid = 72        // i32
    }

    private enum Tcpcb {                    // xtcpcb_n
        static let minLength = 40
        static let state = 36               // i32; TCPS_LISTEN == 1
    }

    private static let tcpStateListen: Int32 = 1
    private static let tcpStateEstablished: Int32 = 4
    private static let headerSize = 24      // struct xinpgen

    private static func scanTable(_ name: String, networkProtocol: NetworkProtocol) -> [ListeningPort] {
        var length = 0
        guard sysctlbyname(name, nil, &length, nil, 0) == 0, length > headerSize else { return [] }

        // Headroom in case the table grows between the two calls.
        length += length / 8
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctlbyname(name, &buffer, &length, nil, 0) == 0 else { return [] }

        let byteCount = length
        return buffer.withUnsafeBytes { raw in
            parse(raw, count: byteCount, networkProtocol: networkProtocol)
        }
    }

    private static func parse(
        _ raw: UnsafeRawBufferPointer,
        count: Int,
        networkProtocol: NetworkProtocol
    ) -> [ListeningPort] {
        var results: [ListeningPort] = []
        var connectionCounts: [Int: Int] = [:]

        var localPort = 0
        var foreignPort = 0
        var address = "*"
        var lastPid: Int32 = 0
        var effectivePid: Int32 = 0
        var uid: uid_t = 0
        var tcpState: Int32 = -1
        var hasRecord = false

        func flushRecord() {
            defer {
                localPort = 0; foreignPort = 0; address = "*"
                lastPid = 0; effectivePid = 0; uid = 0; tcpState = -1; hasRecord = false
            }
            guard hasRecord, localPort > 0 else { return }

            switch networkProtocol {
            case .tcp:
                if tcpState == tcpStateEstablished {
                    connectionCounts[localPort, default: 0] += 1
                    return
                }
                guard tcpState == tcpStateListen else { return }
            case .udp:
                // A UDP socket with a foreign port is connected, not listening.
                guard foreignPort == 0 else { return }
            }

            // The "last pid to touch the socket" can be a dead fork child;
            // fall back to the effective pid when it doesn't resolve.
            var pid = lastPid != 0 ? lastPid : effectivePid
            var path = executablePath(for: pid)
            if path == nil, effectivePid != 0, effectivePid != pid {
                pid = effectivePid
                path = executablePath(for: pid)
            }
            let name = path.map { URL(filePath: $0).lastPathComponent } ?? "pid \(pid)"
            results.append(
                ListeningPort(
                    port: localPort,
                    pid: pid,
                    processName: name,
                    address: address,
                    user: userName(for: uid),
                    networkProtocol: networkProtocol,
                    executablePath: path
                )
            )
        }

        var offset = headerSize
        while offset + 8 <= count {
            let length = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            let kind = raw.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self)
            guard length >= 8, offset + length <= count else { break }

            switch kind {
            case Kind.inpcb where length >= Inpcb.minLength:
                flushRecord()
                hasRecord = true
                localPort = Int(UInt16(bigEndian: raw.loadUnaligned(fromByteOffset: offset + Inpcb.localPort, as: UInt16.self)))
                foreignPort = Int(UInt16(bigEndian: raw.loadUnaligned(fromByteOffset: offset + Inpcb.foreignPort, as: UInt16.self)))
                let vflag = raw.load(fromByteOffset: offset + Inpcb.vflag, as: UInt8.self)
                address = localAddress(raw, at: offset + Inpcb.localAddress, vflag: vflag)
            case Kind.socket where length >= Socket.minLength:
                lastPid = raw.loadUnaligned(fromByteOffset: offset + Socket.lastPid, as: Int32.self)
                effectivePid = raw.loadUnaligned(fromByteOffset: offset + Socket.effectivePid, as: Int32.self)
                uid = raw.loadUnaligned(fromByteOffset: offset + Socket.uid, as: UInt32.self)
            case Kind.tcpcb where length >= Tcpcb.minLength:
                tcpState = raw.loadUnaligned(fromByteOffset: offset + Tcpcb.state, as: Int32.self)
            default:
                break
            }
            // Blocks are written 8-byte aligned; xt_len itself isn't rounded.
            offset += (length + 7) & ~7
        }
        flushRecord()

        return results.map { listener in
            var listener = listener
            if listener.networkProtocol == .tcp {
                listener.establishedConnections = connectionCounts[listener.port] ?? 0
            }
            return listener
        }
    }

    /// Formats the local address of a socket, "*" for the unspecified address.
    private static func localAddress(_ raw: UnsafeRawBufferPointer, at base: Int, vflag: UInt8) -> String {
        if vflag & 0x1 != 0 {
            // IPv4 (in_addr_4in6): the address sits after 12 padding bytes.
            let addr = raw.loadUnaligned(fromByteOffset: base + 12, as: UInt32.self)
            guard addr != 0 else { return "*" }
            var inAddr = in_addr(s_addr: addr)
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &inAddr, &text, socklen_t(text.count))
            return String(cString: text)
        }

        var addr6 = in6_addr()
        withUnsafeMutableBytes(of: &addr6) { destination in
            for index in 0..<16 {
                destination[index] = raw.load(fromByteOffset: base + index, as: UInt8.self)
            }
        }
        let isUnspecified = withUnsafeBytes(of: addr6) { $0.allSatisfy { $0 == 0 } }
        guard !isUnspecified else { return "*" }

        var text = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        _ = withUnsafePointer(to: &addr6) { pointer in
            inet_ntop(AF_INET6, pointer, &text, socklen_t(text.count))
        }
        return String(cString: text)
    }

    private static func executablePath(for pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func userName(for uid: uid_t) -> String? {
        guard let passwd = getpwuid(uid) else { return "uid \(uid)" }
        return String(cString: passwd.pointee.pw_name)
    }
}

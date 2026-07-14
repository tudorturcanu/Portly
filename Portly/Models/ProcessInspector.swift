//
//  ProcessInspector.swift
//  Portly
//

import Foundation

/// Resolves on-demand process facts via libproc and sysctl.
enum ProcessInspector {
    static func details(for pid: Int32) -> ProcessDetails {
        var details = ProcessDetails()
        guard pid > 0 else { return details }

        details.arguments = arguments(for: pid)

        var info = proc_bsdinfo()
        let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize {
            details.startedAt = Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
        }

        var usage = rusage_info_current()
        let usageResult = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
            }
        }
        if usageResult == 0 {
            details.memoryBytes = usage.ri_phys_footprint
            details.cpuTime = machTimeToSeconds(usage.ri_user_time + usage.ri_system_time)
        }

        return details
    }

    /// Reads a process's command line via KERN_PROCARGS2.
    /// Only permitted for the current user's processes; returns nil otherwise.
    private static func arguments(for pid: Int32) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > 4 else { return nil }

        // Layout: argc (Int32), executable path, NUL padding, argv strings.
        let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0 else { return nil }

        var arguments: [String] = []
        var index = 4
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        while index < size, arguments.count < Int(argc) {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments.isEmpty ? nil : arguments
    }

    private static func machTimeToSeconds(_ ticks: UInt64) -> TimeInterval {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        guard timebase.denom != 0 else { return 0 }
        return Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }
}

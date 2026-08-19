//
//  ProcessInspector.swift
//  Portly
//

import Foundation

/// Resolves on-demand process facts via libproc and sysctl.
enum ProcessInspector {
    static func details(for pid: Int32, processName: String? = nil, executablePath: String? = nil) -> ProcessDetails {
        var details = ProcessDetails()
        guard pid > 0 else { return details }

        let (args, env) = procArgs(for: pid)
        details.arguments = args
        details.environmentVariables = env
        details.currentWorkingDirectory = currentWorkingDirectory(for: pid)

        if let args {
            details.smartDescriptor = SmartProcessDescriptor.describe(
                processName: processName ?? "",
                executablePath: executablePath,
                arguments: args
            )
        }

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

    /// Resolves the current working directory of the process via PROC_PIDVNODEPATHINFO.
    static func currentWorkingDirectory(for pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        var pathInfo = proc_vnodepathinfo()
        let infoSize = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        if proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &pathInfo, infoSize) == infoSize {
            let cwd = withUnsafePointer(to: &pathInfo.pvi_cdir.vip_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cStr in
                    String(cString: cStr)
                }
            }
            if !cwd.isEmpty {
                return cwd
            }
        }
        return nil
    }

    /// Reads a process's command line and environment variables via KERN_PROCARGS2.
    /// Only permitted for the current user's processes; returns nil otherwise.
    static func procArgs(for pid: Int32) -> (arguments: [String]?, environment: [EnvironmentVariable]?) {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return (nil, nil) }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > 4 else { return (nil, nil) }

        // Layout: argc (Int32), executable path, NUL padding, argv strings, env strings.
        let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc > 0 else { return (nil, nil) }

        var arguments: [String] = []
        var index = 4
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        while index < size, arguments.count < Int(argc) {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            if start < index {
                arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            }
            index += 1
        }

        var envVars: [EnvironmentVariable] = []
        while index < size {
            while index < size, buffer[index] == 0 { index += 1 }
            if index >= size { break }

            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            if start < index {
                let envString = String(decoding: buffer[start..<index], as: UTF8.self)
                if let equalIndex = envString.firstIndex(of: "=") {
                    let key = String(envString[..<equalIndex])
                    let value = String(envString[envString.index(after: equalIndex)...])
                    if !key.isEmpty {
                        envVars.append(EnvironmentVariable(key: key, value: value))
                    }
                }
            }
            index += 1
        }

        let sortedEnv = envVars.isEmpty ? nil : envVars.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        return (arguments.isEmpty ? nil : arguments, sortedEnv)
    }

    private static func machTimeToSeconds(_ ticks: UInt64) -> TimeInterval {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        guard timebase.denom != 0 else { return 0 }
        return Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }
}

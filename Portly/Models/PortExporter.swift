//
//  PortExporter.swift
//  Portly
//

import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown"
    case json = "JSON"
    case csv = "CSV"

    var id: String { rawValue }
}

enum PortExporter {
    static func export(_ ports: [ListeningPort], format: ExportFormat) -> String {
        switch format {
        case .markdown:
            let header = ["| Port | Proto | Process | Alias | Exposure | PID | Address | Notes |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
            let rows = ports.map { port in
                let aliasStr = port.customAlias ?? "-"
                let noteStr = port.customNote ?? "-"
                return "| :\(port.port) | \(port.networkProtocol.rawValue) | \(port.displayName) | \(aliasStr) | \(port.exposure.rawValue) | \(port.pid) | \(port.displayAddress) | \(noteStr) |"
            }
            return (header + rows).joined(separator: "\n")

        case .json:
            let list = ports.map { port -> [String: Any] in
                var dict: [String: Any] = [
                    "port": port.port,
                    "protocol": port.networkProtocol.rawValue,
                    "processName": port.processName,
                    "displayName": port.displayName,
                    "pid": port.pid,
                    "address": port.address,
                    "exposure": port.exposure.rawValue,
                    "isSystemProcess": port.isSystemProcess
                ]
                if let alias = port.customAlias { dict["alias"] = alias }
                if let note = port.customNote { dict["note"] = note }
                if let hint = port.hint { dict["hint"] = hint }
                if let container = port.containerName { dict["containerName"] = container }
                return dict
            }
            guard let data = try? JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys]),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return "[]"
            }
            return jsonString

        case .csv:
            let header = "Port,Protocol,ProcessName,DisplayName,Alias,Exposure,PID,Address,SystemProcess,Notes"
            let rows = ports.map { p in
                let aliasStr = p.customAlias?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                let noteStr = p.customNote?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                return "\(p.port),\(p.networkProtocol.rawValue),\"\(p.processName)\",\"\(p.displayName)\",\"\(aliasStr)\",\"\(p.exposure.rawValue)\",\(p.pid),\"\(p.displayAddress)\",\(p.isSystemProcess),\"\(noteStr)\""
            }
            return ([header] + rows).joined(separator: "\n")
        }
    }
}

//
//  CustomAction.swift
//  Portly
//

import Foundation

/// A user-defined script / command that can be executed against any listening port or process.
struct CustomAction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var icon: String = "play.fill"
    var targetPort: Int?
    var runInTerminal: Bool = false

    /// Interpolates variable tokens ($PORT, $PID, $CWD, $NAME, $URL, $HOST) into the command.
    func interpolatedCommand(port: ListeningPort, workingDirectory: String? = nil) -> String {
        var result = command
        result = result.replacingOccurrences(of: "$PORT", with: "\(port.port)")
        result = result.replacingOccurrences(of: "$PID", with: "\(port.pid)")
        result = result.replacingOccurrences(of: "$CWD", with: workingDirectory ?? "")
        result = result.replacingOccurrences(of: "$NAME", with: port.displayName)
        result = result.replacingOccurrences(of: "$URL", with: "http://localhost:\(port.port)")
        result = result.replacingOccurrences(of: "$HOST", with: port.address == "*" ? "127.0.0.1" : port.address)
        return result
    }
}

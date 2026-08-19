//
//  TerminalLauncher.swift
//  Portly
//

import AppKit
import Foundation

/// Discovers installed terminals and opens directories in the user's preferred terminal or editor.
enum TerminalLauncher {
    /// Opens the specified directory in the user's available terminal.
    static func openInTerminal(at path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)

        let terminalBundleIDs = [
            "com.mitchellh.ghostty",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "org.alacritty",
            "net.kovidgoyal.kitty",
            "com.apple.Terminal",
        ]

        for bundleID in terminalBundleIDs {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
                return
            }
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }

    /// Opens the directory in the user's code editor (Cursor, VS Code, or Xcode) if available.
    static func openInEditor(at path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let editorBundleIDs = [
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.microsoft.VSCode",          // VS Code
            "com.apple.dt.Xcode",            // Xcode
        ]

        for bundleID in editorBundleIDs {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
                return
            }
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}

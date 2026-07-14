//
//  AppCapabilities.swift
//  Portly
//

/// Differences between the direct-download build and the sandboxed
/// App Store build (compiled with the APPSTORE condition).
enum AppCapabilities {
    /// The App Sandbox forbids sending signals to other processes, so the
    /// App Store build offers "copy kill command" instead of a Stop button.
    static var canTerminateProcesses: Bool {
        #if APPSTORE
        false
        #else
        true
        #endif
    }
}

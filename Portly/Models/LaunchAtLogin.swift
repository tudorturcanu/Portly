//
//  LaunchAtLogin.swift
//  Portly
//

import ServiceManagement

/// Thin wrapper around SMAppService for the "Launch at Login" toggle.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

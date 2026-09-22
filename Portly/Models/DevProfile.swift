//
//  DevProfile.swift
//  Portly
//

import Foundation

/// A named stack of dev server ports representing a project or environment (e.g. "Web Client + API").
struct DevProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var ports: [Int]
}

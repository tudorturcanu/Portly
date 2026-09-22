//
//  DevProfileManager.swift
//  Portly
//

import Foundation
import Observation

/// Manages persistent dev profiles (project stacks) and active profile filtering.
@Observable
@MainActor
final class DevProfileManager {
    static let shared = DevProfileManager()
    static let defaultsKey = "devPortProfiles"

    private(set) var profiles: [DevProfile] = []
    var activeProfileId: UUID?

    init() {
        loadProfiles()
    }

    var activeProfile: DevProfile? {
        guard let id = activeProfileId else { return nil }
        return profiles.first { $0.id == id }
    }

    func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([DevProfile].self, from: data) else {
            profiles = []
            return
        }
        profiles = decoded
    }

    func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func addProfile(name: String, ports: [Int]) {
        let profile = DevProfile(name: name, ports: ports.sorted())
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: DevProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            saveProfiles()
        }
    }

    func deleteProfile(id: UUID) {
        if activeProfileId == id {
            activeProfileId = nil
        }
        profiles.removeAll { $0.id == id }
        saveProfiles()
    }
}

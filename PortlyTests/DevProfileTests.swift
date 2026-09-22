//
//  DevProfileTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

@MainActor
final class DevProfileTests: XCTestCase {
    var manager: DevProfileManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: DevProfileManager.defaultsKey)
        manager = DevProfileManager()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: DevProfileManager.defaultsKey)
        super.tearDown()
    }

    func testProfileCreation() {
        let profile = DevProfile(name: "Web Stack", ports: [3000, 8000, 5432])
        XCTAssertEqual(profile.name, "Web Stack")
        XCTAssertEqual(profile.ports, [3000, 8000, 5432])
        XCTAssertFalse(profile.id.uuidString.isEmpty)
    }

    func testAddAndFindProfile() {
        manager.addProfile(name: "Microservices", ports: [8080, 9090, 50051])
        XCTAssertEqual(manager.profiles.count, 1)

        let profile = manager.profiles.first
        XCTAssertEqual(profile?.name, "Microservices")
        XCTAssertEqual(profile?.ports, [8080, 9090, 50051].sorted())

        manager.activeProfileId = profile?.id
        XCTAssertEqual(manager.activeProfile?.id, profile?.id)
        XCTAssertEqual(manager.activeProfile?.name, "Microservices")
    }

    func testUpdateProfile() {
        manager.addProfile(name: "Frontend", ports: [3000])
        guard var profile = manager.profiles.first else {
            XCTFail("Profile should exist")
            return
        }

        profile.name = "Frontend & Storybook"
        profile.ports = [3000, 6006]
        manager.updateProfile(profile)

        XCTAssertEqual(manager.profiles.first?.name, "Frontend & Storybook")
        XCTAssertEqual(manager.profiles.first?.ports, [3000, 6006])
    }

    func testDeleteProfileClearsActiveProfile() {
        manager.addProfile(name: "Data Pipeline", ports: [6379, 9042])
        guard let profile = manager.profiles.first else {
            XCTFail("Profile should exist")
            return
        }

        manager.activeProfileId = profile.id
        XCTAssertNotNil(manager.activeProfile)

        manager.deleteProfile(id: profile.id)
        XCTAssertTrue(manager.profiles.isEmpty)
        XCTAssertNil(manager.activeProfileId)
        XCTAssertNil(manager.activeProfile)
    }

    func testPersistenceAcrossInstances() {
        manager.addProfile(name: "Mobile Backend", ports: [4000, 4001])

        let freshManager = DevProfileManager()
        XCTAssertEqual(freshManager.profiles.count, 1)
        XCTAssertEqual(freshManager.profiles.first?.name, "Mobile Backend")
        XCTAssertEqual(freshManager.profiles.first?.ports, [4000, 4001])
    }
}

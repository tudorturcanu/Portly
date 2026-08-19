//
//  SmartProcessDescriptorTests.swift
//  PortlyTests
//

import XCTest
@testable import Portly

final class SmartProcessDescriptorTests: XCTestCase {

    func testKubectlPortForwardPod() {
        let args = ["kubectl", "port-forward", "pod/redis-master-0", "6379:6379"]
        let desc = SmartProcessDescriptor.describe(processName: "kubectl", arguments: args)
        XCTAssertEqual(desc, "k8s: pod/redis-master-0")
    }

    func testKubectlPortForwardServiceWithNamespace() {
        let args = ["kubectl", "port-forward", "-n", "production", "svc/payment-api", "8080:80"]
        let desc = SmartProcessDescriptor.describe(processName: "kubectl", arguments: args)
        XCTAssertEqual(desc, "k8s: svc/payment-api (production)")
    }

    func testSSHTunnel() {
        let args = ["ssh", "-N", "-L", "5432:localhost:5432", "deploy@db.internal.net"]
        let desc = SmartProcessDescriptor.describe(processName: "ssh", arguments: args)
        XCTAssertEqual(desc, "ssh: deploy@db.internal.net (5432:localhost:5432)")
    }

    func testNodeFrameworkNextJS() {
        let args = ["node", "/Users/tudor/repo/node_modules/.bin/next", "dev"]
        let desc = SmartProcessDescriptor.describe(processName: "node", arguments: args)
        XCTAssertEqual(desc, "Next.js")
    }

    func testNodeFrameworkVite() {
        let args = ["bun", "vite", "--port", "3000"]
        let desc = SmartProcessDescriptor.describe(processName: "bun", arguments: args)
        XCTAssertEqual(desc, "Vite")
    }

    func testNodeScriptFile() {
        let args = ["node", "dist/server.js"]
        let desc = SmartProcessDescriptor.describe(processName: "node", arguments: args)
        XCTAssertEqual(desc, "server.js")
    }

    func testPythonFastAPI() {
        let args = ["python3", "-m", "uvicorn", "main:app", "--reload"]
        let desc = SmartProcessDescriptor.describe(processName: "python3", arguments: args)
        XCTAssertEqual(desc, "FastAPI / Uvicorn")
    }

    func testPythonDjango() {
        let args = ["python", "manage.py", "runserver", "8000"]
        let desc = SmartProcessDescriptor.describe(processName: "python", arguments: args)
        XCTAssertEqual(desc, "Django")
    }
}

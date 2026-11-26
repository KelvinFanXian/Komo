import XCTest
@testable import KMonitor

final class ServiceDiscoveryTests: XCTestCase {
    func testParsesSeveralPortsWithoutMixingProcesses() {
        let output = """
        p42
        cjava
        u501
        f8
        n127.0.0.1:48090
        f9
        n[::1]:48091
        p43
        cnode
        u501
        f10
        n127.0.0.1:5180
        """
        let processes = LsofParser.parse(output)
        XCTAssertEqual(processes.count, 2)
        XCTAssertEqual(processes[0].ports, [48090, 48091])
        XCTAssertEqual(processes[0].pid, 42)
        XCTAssertEqual(processes[1].ports, [5180])
        XCTAssertEqual(processes[1].command, "node")
    }

    func testRejectsChangedProcessBeforeStop() {
        let original = MonitoredService(pid: 42, command: "node", userID: 501,
                                        worktree: "/project/feature", branch: "feature/a",
                                        ports: [5180], addresses: ["127.0.0.1:5180"])
        let reusedPID = MonitoredService(pid: 42, command: "node", userID: 501,
                                         worktree: "/project/other", branch: "feature/b",
                                         ports: [5180], addresses: ["127.0.0.1:5180"])
        let movedPort = MonitoredService(pid: 42, command: "node", userID: 501,
                                         worktree: "/project/feature", branch: "feature/a",
                                         ports: [5182], addresses: ["127.0.0.1:5182"])
        XCTAssertFalse(original.matchesForStop(reusedPID))
        XCTAssertFalse(original.matchesForStop(movedPort))
        XCTAssertTrue(original.matchesForStop(original))
    }

    func testDefaultScopeExcludesPackageManagersOutsideHome() {
        let home = "/Users/developer"
        XCTAssertFalse(ServiceScope.includes(worktree: "/opt/homebrew", selectedRoot: nil, home: home))
        XCTAssertFalse(ServiceScope.includes(worktree: "/Users/developer/Library/Tools", selectedRoot: nil, home: home))
        XCTAssertTrue(ServiceScope.includes(worktree: "/Users/developer/github/Keen", selectedRoot: nil, home: home))
        XCTAssertTrue(ServiceScope.includes(worktree: "/opt/projects/app", selectedRoot: "/opt/projects", home: home))
    }

    func testLiveServiceAtExpectedPortWhenRequested() throws {
        guard let value = ProcessInfo.processInfo.environment["KMONITOR_EXPECT_PORT"],
              let port = Int(value) else { return }
        let expectedBranch = ProcessInfo.processInfo.environment["KMONITOR_EXPECT_BRANCH"]
        let services = try ServiceScanner.scan(rootFilter: nil)
        let service = try XCTUnwrap(services.first { $0.ports.contains(port) })
        if let expectedBranch { XCTAssertEqual(service.branch, expectedBranch) }
        print("LIVE SERVICE \(port): \(service.worktree) # \(service.branch)")
    }

    func testInfrastructurePortIsExcludedWhenRequested() throws {
        guard let value = ProcessInfo.processInfo.environment["KMONITOR_EXCLUDE_PORT"],
              let port = Int(value) else { return }
        XCTAssertFalse(try ServiceScanner.scan(rootFilter: nil).contains { $0.ports.contains(port) })
    }

    func testStopsOnlyRequestedTemporaryServiceWhenRequested() throws {
        guard let value = ProcessInfo.processInfo.environment["KMONITOR_STOP_PORT"],
              let port = Int(value) else { return }
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        let service = try XCTUnwrap(ServiceScanner.scan(rootFilter: projectRoot).first { $0.ports.contains(port) })
        XCTAssertEqual(service.branch, "feature/branchscope")
        try ServiceController.stop(service)
        let remaining = try ServiceScanner.scan(rootFilter: projectRoot)
        XCTAssertFalse(remaining.contains { $0.pid == service.pid && $0.ports.contains(port) })
    }
}

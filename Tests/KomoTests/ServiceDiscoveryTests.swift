import XCTest
@testable import Komo

final class ServiceDiscoveryTests: XCTestCase {
    private func projectBranch(at root: String) throws -> String {
        let output = try XCTUnwrap(CommandOutput.read("/usr/bin/git", ["-C", root, "branch", "--show-current"]))
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        guard let value = ProcessInfo.processInfo.environment["KOMO_EXPECT_PORT"],
              let port = Int(value) else { return }
        let expectedBranch = ProcessInfo.processInfo.environment["KOMO_EXPECT_BRANCH"]
        let services = try ServiceScanner.scan(rootFilter: nil)
        let service = try XCTUnwrap(services.first { $0.ports.contains(port) })
        if let expectedBranch { XCTAssertEqual(service.branch, expectedBranch) }
        print("LIVE SERVICE \(port): \(service.worktree) # \(service.branch)")
    }

    func testInfrastructurePortIsExcludedWhenRequested() throws {
        guard let value = ProcessInfo.processInfo.environment["KOMO_EXCLUDE_PORT"],
              let port = Int(value) else { return }
        XCTAssertFalse(try ServiceScanner.scan(rootFilter: nil).contains { $0.ports.contains(port) })
    }

    func testStopsOnlyRequestedTemporaryServiceWhenRequested() throws {
        guard let value = ProcessInfo.processInfo.environment["KOMO_STOP_PORT"],
              let port = Int(value) else { return }
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        let service = try XCTUnwrap(ServiceScanner.scan(rootFilter: projectRoot).first { $0.ports.contains(port) })
        XCTAssertEqual(service.branch, try projectBranch(at: projectRoot))
        try ServiceController.stop(service)
        let remaining = try ServiceScanner.scan(rootFilter: projectRoot)
        XCTAssertFalse(remaining.contains { $0.pid == service.pid && $0.ports.contains(port) })
    }

    @MainActor
    func testStopsOnlyVisibleBranchServicesWhenRequested() async throws {
        guard let value = ProcessInfo.processInfo.environment["KOMO_STOP_PORTS"] else { return }
        let ports = Set(value.split(separator: ",").compactMap { Int($0) })
        XCTAssertEqual(ports.count, 2)
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        let targets = try ServiceScanner.scan(rootFilter: projectRoot).filter { !ports.isDisjoint(with: $0.ports) }
        XCTAssertEqual(targets.count, 2)
        let branch = try projectBranch(at: projectRoot)
        XCTAssertTrue(targets.allSatisfy { $0.branch == branch })
        let store = MonitorStore()
        await store.stop(targets)
        XCTAssertFalse(store.isStopping)
        XCTAssertNil(store.message)
        let remaining = try ServiceScanner.scan(rootFilter: projectRoot)
        XCTAssertFalse(remaining.contains { !ports.isDisjoint(with: $0.ports) })
    }
}

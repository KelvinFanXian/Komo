import Darwin
import Foundation

enum CommandOutput {
    static func read(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

enum LsofParser {
    static func parse(_ output: String) -> [ListeningProcess] {
        struct Accumulator {
            var pid: Int32
            var command = ""
            var userID: UInt32 = 0
            var ports = Set<Int>()
            var addresses = Set<String>()
        }

        var result: [ListeningProcess] = []
        var current: Accumulator?

        func finish() {
            guard let value = current, !value.ports.isEmpty else { return }
            result.append(ListeningProcess(
                pid: value.pid,
                command: value.command,
                userID: value.userID,
                ports: value.ports.sorted(),
                addresses: value.addresses.sorted()
            ))
        }

        for rawLine in output.split(separator: "\n") {
            guard let tag = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch tag {
            case "p":
                finish()
                current = Int32(value).map { Accumulator(pid: $0) }
            case "c": current?.command = value
            case "u": current?.userID = UInt32(value) ?? 0
            case "n":
                if let port = port(from: value) {
                    current?.ports.insert(port)
                    current?.addresses.insert(value)
                }
            default: break
            }
        }
        finish()
        return result
    }

    static func port(from address: String) -> Int? {
        guard let colon = address.lastIndex(of: ":"),
              let port = Int(address[address.index(after: colon)...]),
              (1...65535).contains(port) else { return nil }
        return port
    }
}

enum ServiceScanner {
    static func scan(rootFilter: String?) throws -> [MonitoredService] {
        guard let output = CommandOutput.read("/usr/sbin/lsof", ["-nP", "-Fpcun", "-iTCP", "-sTCP:LISTEN"]) else {
            throw MonitorError.lsofFailed
        }
        let ownUserID = UInt32(geteuid())
        let filter = rootFilter.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        var services: [MonitoredService] = []

        for process in LsofParser.parse(output) where process.userID == ownUserID {
            guard let worktree = gitWorktree(for: process.pid),
                  ServiceScope.includes(worktree: worktree, selectedRoot: filter, home: home),
                  let branch = CommandOutput.read("/usr/bin/git", ["-C", worktree, "branch", "--show-current"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            let shownBranch: String
            if branch.isEmpty {
                let hash = CommandOutput.read("/usr/bin/git", ["-C", worktree, "rev-parse", "--short", "HEAD"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知"
                shownBranch = "游离 HEAD · \(hash)"
            } else {
                shownBranch = branch
            }
            services.append(MonitoredService(
                pid: process.pid,
                command: process.command,
                userID: process.userID,
                worktree: worktree,
                branch: shownBranch,
                ports: process.ports,
                addresses: process.addresses
            ))
        }
        return services.sorted {
            if $0.branch != $1.branch { return $0.branch.localizedStandardCompare($1.branch) == .orderedAscending }
            if $0.worktree != $1.worktree { return $0.worktree < $1.worktree }
            return $0.pid < $1.pid
        }
    }

    private static func gitWorktree(for pid: Int32) -> String? {
        guard let output = CommandOutput.read("/usr/sbin/lsof", ["-nP", "-a", "-p", String(pid), "-d", "cwd", "-Fpn"]),
              let cwd = output.split(separator: "\n").first(where: { $0.first == "n" }).map({ String($0.dropFirst()) }),
              let root = CommandOutput.read("/usr/bin/git", ["-C", cwd, "rev-parse", "--show-toplevel"])?
                .trimmingCharacters(in: .whitespacesAndNewlines), !root.isEmpty else { return nil }
        return URL(fileURLWithPath: root).resolvingSymlinksInPath().path
    }
}

enum ServiceScope {
    static func includes(worktree: String, selectedRoot: String?, home: String) -> Bool {
        if let selectedRoot {
            return worktree == selectedRoot || worktree.hasPrefix(selectedRoot + "/")
        }
        guard worktree.hasPrefix(home + "/") else { return false }
        let relative = worktree.dropFirst(home.count + 1)
        guard let first = relative.split(separator: "/").first else { return false }
        return first != "Library" && !first.hasPrefix(".")
    }
}

import Foundation

enum ServiceRuntime: Equatable {
    case node
    case java
    case redis
    case other

    init(command: String) {
        let name = URL(fileURLWithPath: command).lastPathComponent.lowercased()
        switch name {
        case "node", "nodejs": self = .node
        case "java", "javaw": self = .java
        default:
            self = name == "redis" || name.hasPrefix("redis-") ? .redis : .other
        }
    }

    var displayName: String {
        switch self {
        case .node: "Node.js"
        case .java: "Java"
        case .redis: "Redis"
        case .other: "其他进程"
        }
    }
}

struct ListeningProcess: Sendable, Equatable {
    let pid: Int32
    let command: String
    let userID: UInt32
    let ports: [Int]
    let addresses: [String]
}

struct MonitoredService: Identifiable, Sendable, Equatable {
    let pid: Int32
    let command: String
    let userID: UInt32
    let worktree: String
    let branch: String
    let ports: [Int]
    let addresses: [String]

    var id: Int32 { pid }
    var runtime: ServiceRuntime { ServiceRuntime(command: command) }
    var repositoryName: String { URL(fileURLWithPath: worktree).lastPathComponent }
    var primaryPort: Int? { ports.first }
    var localURL: URL? {
        guard let port = primaryPort else { return nil }
        return URL(string: "http://127.0.0.1:\(port)")
    }

    func matchesForStop(_ current: MonitoredService) -> Bool {
        pid == current.pid && userID == current.userID &&
        worktree == current.worktree && command == current.command &&
        Set(ports).isSubset(of: Set(current.ports))
    }
}

enum MonitorError: LocalizedError {
    case lsofFailed
    case processChanged
    case signalFailed(String)
    case stillListening

    var errorDescription: String? {
        switch self {
        case .lsofFailed: "无法读取本机监听进程。请确认 lsof 可用。"
        case .processChanged: "进程或端口已变化，已取消停止。请刷新后重试。"
        case .signalFailed(let detail): "停止信号发送失败：\(detail)"
        case .stillListening: "已发送正常停止信号，但服务仍在监听；请检查进程或启动它的 Agent。"
        }
    }
}

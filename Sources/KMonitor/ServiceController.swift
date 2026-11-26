import Darwin
import Foundation

enum ServiceController {
    static func stop(_ service: MonitoredService) throws {
        guard service.userID == UInt32(geteuid()),
              let current = try ServiceScanner.scan(rootFilter: service.worktree).first(where: { $0.pid == service.pid }),
              service.matchesForStop(current) else {
            throw MonitorError.processChanged
        }

        guard kill(service.pid, SIGTERM) == 0 else {
            throw MonitorError.signalFailed(String(cString: strerror(errno)))
        }
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            guard let remaining = try ServiceScanner.scan(rootFilter: service.worktree).first(where: { $0.pid == service.pid }),
                  service.matchesForStop(remaining) else { return }
        }
        throw MonitorError.stillListening
    }
}

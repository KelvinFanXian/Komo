import AppKit
import Foundation

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var services: [MonitoredService] = []
    @Published private(set) var isScanning = false
    @Published private(set) var stoppingPID: Int32?
    @Published private(set) var lastUpdated: Date?
    @Published var message: String?
    @Published var rootFilter: String? {
        didSet { UserDefaults.standard.set(rootFilter, forKey: "rootFilter") }
    }
    @Published private(set) var hiddenServices: Set<String>

    init() {
        rootFilter = UserDefaults.standard.string(forKey: "rootFilter")
        hiddenServices = Set(UserDefaults.standard.stringArray(forKey: "hiddenServices") ?? [])
    }

    var visibleServices: [MonitoredService] {
        services.filter { !hiddenServices.contains(hideKey(for: $0)) }
    }

    var branches: [String] {
        Array(Set(visibleServices.map(\.branch))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func services(in branch: String, matching search: String) -> [MonitoredService] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleServices.filter { service in
            guard service.branch == branch else { return false }
            guard !query.isEmpty else { return true }
            return [service.repositoryName, service.worktree, service.command, service.branch,
                    service.ports.map(String.init).joined(separator: ",")]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        let filter = rootFilter
        let result = await Task.detached(priority: .utility) {
            Result { try ServiceScanner.scan(rootFilter: filter) }
        }.value
        switch result {
        case .success(let found):
            services = found
            lastUpdated = Date()
        case .failure(let error):
            message = error.localizedDescription
        }
        isScanning = false
    }

    func pollWhileVisible() async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "监控此目录"
        if panel.runModal() == .OK, let path = panel.url?.path {
            rootFilter = path
            Task { await refresh() }
        }
    }

    func clearRoot() {
        rootFilter = nil
        Task { await refresh() }
    }

    func hide(_ service: MonitoredService) {
        hiddenServices.insert(hideKey(for: service))
        UserDefaults.standard.set(Array(hiddenServices).sorted(), forKey: "hiddenServices")
    }

    func restoreHidden() {
        hiddenServices.removeAll()
        UserDefaults.standard.removeObject(forKey: "hiddenServices")
    }

    private func hideKey(for service: MonitoredService) -> String {
        "\(service.worktree)::\(service.command)::\(service.ports.map(String.init).joined(separator: ","))"
    }

    func stop(_ service: MonitoredService) async {
        guard stoppingPID == nil else { return }
        stoppingPID = service.pid
        let result = await Task.detached(priority: .userInitiated) {
            Result { try ServiceController.stop(service) }
        }.value
        await refresh()
        if case .failure(let error) = result { message = error.localizedDescription }
        stoppingPID = nil
    }
}

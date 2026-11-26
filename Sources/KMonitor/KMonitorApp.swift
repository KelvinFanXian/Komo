import SwiftUI

@main
struct KMonitorApp: App {
    @StateObject private var store = MonitorStore()

    var body: some Scene {
        Window("KMonitor", id: "main") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 540)
        }
        .defaultSize(width: 980, height: 690)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新服务") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("KMonitor", systemImage: "eye") {
            MenuPanelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

import SwiftUI

private struct SearchFieldFocusKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearchField: (() -> Void)? {
        get { self[SearchFieldFocusKey.self] }
        set { self[SearchFieldFocusKey.self] = newValue }
    }
}

private struct SearchCommands: Commands {
    @FocusedValue(\.focusSearchField) private var focusSearchField

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("搜索服务") { focusSearchField?() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(focusSearchField == nil)
        }
    }
}

@main
struct KomoApp: App {
    @StateObject private var store = MonitorStore()

    var body: some Scene {
        Window("Komo", id: "main") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 540)
        }
        .defaultSize(width: 980, height: 690)
        .commands {
            SearchCommands()
            CommandGroup(after: .toolbar) {
                Button("刷新服务") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("Komo", systemImage: "eye") {
            MenuPanelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

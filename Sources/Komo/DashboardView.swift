import AppKit
import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.27)
    static let indigo = Color(red: 0.31, green: 0.25, blue: 0.55)
    static let teal = Color(red: 0.05, green: 0.58, blue: 0.61)
    static let paper = Color(red: 0.985, green: 0.977, blue: 0.957)
}

private struct RuntimeLogo: View {
    let runtime: ServiceRuntime
    let command: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor.opacity(0.12))
            switch runtime {
            case .node:
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 18))
                    .overlay {
                        Text("N")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
            case .java:
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 17, weight: .semibold))
            case .redis:
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 17, weight: .semibold))
            case .other:
                Image(systemName: "terminal.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(backgroundColor)
        .frame(width: 25, height: 25)
        .help("\(runtime.displayName) · \(command)")
        .accessibilityLabel("\(runtime.displayName)，进程 \(command)")
    }

    private var backgroundColor: Color {
        switch runtime {
        case .node: Color(red: 0.25, green: 0.55, blue: 0.22)
        case .java: Color(red: 0.80, green: 0.32, blue: 0.12)
        case .redis: Color(red: 0.78, green: 0.19, blue: 0.20)
        case .other: Palette.indigo
        }
    }
}

private struct ActionIconButton: View {
    let title: String
    let symbol: String
    var tint: Color = Palette.indigo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct SearchFieldFrameReader: NSViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onChange = onChange
        DispatchQueue.main.async { view.reportFrame() }
    }

    final class TrackingView: NSView {
        var onChange: ((CGRect) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { self.reportFrame() }
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard window != nil else { return }
            onChange?(convert(bounds, to: nil))
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var search = ""
    @State private var searchFrame: CGRect = .zero
    @FocusState private var searchFocused: Bool
    @State private var clickMonitor: Any?
    @State private var collapsedBranches: Set<String> = []
    @State private var pendingStop: StopRequest?

    private enum StopRequest {
        case service(MonitoredService)
        case branch(String, [MonitoredService])

        var services: [MonitoredService] {
            switch self {
            case .service(let service): [service]
            case .branch(_, let services): services
            }
        }

        var actionTitle: String {
            switch self {
            case .service: "停止服务"
            case .branch: "关闭分支服务"
            }
        }

        var detail: String {
            switch self {
            case .service(let service):
                return "\(service.repositoryName) · PID \(service.pid) · 端口 \(service.ports.map(String.init).joined(separator: ", "))。操作前会重新核对进程身份。"
            case .branch(let branch, let services):
                let names = services.map { "\($0.repositoryName):\($0.ports.map(String.init).joined(separator: ","))" }
                return "\(branch) 的 \(services.count) 个服务：\(names.joined(separator: "、"))。将逐个核对进程身份后停止。"
            }
        }
    }

    private var visibleCount: Int {
        store.branches.reduce(0) { $0 + store.services(in: $1, matching: search).count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.visibleServices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(store.branches, id: \.self) { branch in
                            let items = store.services(in: branch, matching: search)
                            if !items.isEmpty {
                                branchSection(branch, items: items)
                            }
                        }
                        if visibleCount == 0 {
                            ContentUnavailableView.search(text: search)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(26)
                }
            }
            Divider()
            footer
        }
        .background(Palette.paper)
        .defaultFocus($searchFocused, false)
        .focusedSceneValue(\.focusSearchField, { searchFocused = true })
        .task { store.startPolling() }
        .onAppear {
            DispatchQueue.main.async { clearSearchFocus() }
            guard clickMonitor == nil else { return }
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                guard let window = event.window, window.title == "Komo" else { return event }
                guard !searchFrame.contains(event.locationInWindow) else { return event }
                DispatchQueue.main.async { clearSearchFocus() }
                return event
            }
        }
        .onDisappear {
            if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
            clickMonitor = nil
        }
        .alert("停止本地服务？", isPresented: Binding(
            get: { pendingStop != nil },
            set: { if !$0 { pendingStop = nil } }
        )) {
            Button(pendingStop?.actionTitle ?? "停止服务", role: .destructive) {
                guard let request = pendingStop else { return }
                pendingStop = nil
                Task { await store.stop(request.services) }
            }
            Button("取消", role: .cancel) { pendingStop = nil }
        } message: {
            if let request = pendingStop {
                Text(request.detail)
            }
        }
        .alert("Komo", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("知道了") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private func clearSearchFocus() {
        searchFocused = false
        NSApp.windows.first { $0.title == "Komo" }?.makeFirstResponder(nil)
    }

    private var header: some View {
        HStack {
            Spacer()
            TextField("搜索分支、项目或端口", text: $search)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 220)
                .overlay(alignment: .trailing) {
                    if !search.isEmpty {
                        Button {
                            search = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清除搜索")
                        .help("清除搜索")
                        .padding(.trailing, 6)
                    }
                }
                .focused($searchFocused)
                .onExitCommand { clearSearchFocus() }
                .background(SearchFieldFrameReader { frame in
                    if searchFrame != frame { searchFrame = frame }
                })
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 7)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 43, weight: .light))
                .foregroundStyle(Palette.indigo)
            Text("当前没有需要显示的本地服务")
                .font(.title3.weight(.semibold))
            Text("默认显示主目录下开发 worktree 的服务；可选择其他目录，或恢复已隐藏的服务。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if store.rootFilter != nil {
                Button("查看全部 Git 工作区") { store.clearRoot() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func branchSection(_ branch: String, items: [MonitoredService]) -> some View {
        let collapsed = collapsedBranches.contains(branch)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    if collapsed {
                        collapsedBranches.remove(branch)
                    } else {
                        collapsedBranches.insert(branch)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                            .font(.caption.weight(.bold))
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                        Text(branch)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("\(items.count)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Palette.indigo.opacity(0.09), in: Capsule())
                    }
                    .foregroundStyle(Palette.indigo)
                }
                .buttonStyle(.plain)
                .help(collapsed ? "展开 \(branch)" : "折叠 \(branch)")
                Spacer()
                ActionIconButton(title: "关闭 \(branch) 分支的 \(items.count) 个服务", symbol: "power", tint: .red) {
                    pendingStop = .branch(branch, items)
                }
                    .disabled(store.isStopping)
            }
            if !collapsed {
                ForEach(items) { service in
                    serviceCard(service)
                }
            }
        }
    }

    private func serviceCard(_ service: MonitoredService) -> some View {
        HStack(alignment: .center, spacing: 18) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Palette.teal)
                .frame(width: 6, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(service.repositoryName)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Circle()
                        .fill(Palette.teal)
                        .frame(width: 7, height: 7)
                        .help("监听中")
                        .accessibilityLabel("监听中")
                }
                HStack(spacing: 6) {
                    Text(service.worktree)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(service.worktree, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .help("复制完整目录")
                    .accessibilityLabel("复制 \(service.repositoryName) 目录")
                }
                HStack(spacing: 7) {
                    RuntimeLogo(runtime: service.runtime, command: service.command)
                    Text("PID \(service.pid) · \(service.addresses.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: 5) {
                ForEach(service.ports, id: \.self) { port in
                    Text(String(port))
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Palette.indigo)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Palette.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if let url = service.localURL {
                ActionIconButton(title: "打开 \(url.absoluteString)", symbol: "arrow.up.right.square") {
                    NSWorkspace.shared.open(url)
                }
            }
            ActionIconButton(title: "停止 \(service.repositoryName)", symbol: "stop.fill", tint: .red) {
                pendingStop = .service(service)
            }
                .disabled(store.isStopping)
            ActionIconButton(title: "隐藏 \(service.repositoryName)", symbol: "eye.slash", tint: .gray) {
                store.hide(service)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.ink.opacity(0.07)))
    }

    private var footer: some View {
        HStack {
            Label("\(store.visibleServices.count) 个服务 · \(store.branches.count) 个分支", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(Palette.teal)
            Spacer()
            if !store.hiddenServices.isEmpty {
                ActionIconButton(title: "恢复隐藏的服务", symbol: "eye") { store.restoreHidden() }
            }
            if let root = store.rootFilter {
                Label(URL(fileURLWithPath: root).lastPathComponent, systemImage: "folder.fill")
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("当前工作区：\(root)")
                ActionIconButton(title: "清除工作区过滤", symbol: "line.3.horizontal.decrease.circle") {
                    store.clearRoot()
                }
            }
            ActionIconButton(title: "选择工作区", symbol: "folder") { store.chooseRoot() }
            if let date = store.lastUpdated {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .help("更新于 \(date.formatted(date: .omitted, time: .standard))")
                    .accessibilityLabel("更新于 \(date.formatted(date: .omitted, time: .standard))")
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 11)
    }
}

struct MenuPanelView: View {
    @EnvironmentObject private var store: MonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Komo").font(.headline)
                Spacer()
                Text("\(store.visibleServices.count) 个服务")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.branches.prefix(6), id: \.self) { branch in
                HStack {
                    Circle().fill(Palette.teal).frame(width: 7, height: 7)
                    Text(branch).lineLimit(1)
                    Spacer()
                    Text("\(store.services(in: branch, matching: "").count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Divider()
            HStack {
                ActionIconButton(title: "打开服务面板", symbol: "rectangle.on.rectangle") {
                    openWindow(id: "main")
                }
                ActionIconButton(title: "立即刷新", symbol: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
        .task { store.startPolling() }
    }
}

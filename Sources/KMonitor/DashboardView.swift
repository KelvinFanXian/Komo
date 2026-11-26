import AppKit
import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.27)
    static let indigo = Color(red: 0.31, green: 0.25, blue: 0.55)
    static let teal = Color(red: 0.05, green: 0.58, blue: 0.61)
    static let paper = Color(red: 0.985, green: 0.977, blue: 0.957)
}

struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var search = ""
    @State private var pendingStop: MonitoredService?

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
        .task { await store.pollWhileVisible() }
        .alert("停止本地服务？", isPresented: Binding(
            get: { pendingStop != nil },
            set: { if !$0 { pendingStop = nil } }
        )) {
            Button("发送正常停止信号", role: .destructive) {
                guard let service = pendingStop else { return }
                pendingStop = nil
                Task { await store.stop(service) }
            }
            Button("取消", role: .cancel) { pendingStop = nil }
        } message: {
            if let service = pendingStop {
                Text("\(service.repositoryName) · PID \(service.pid) · 端口 \(service.ports.map(String.init).joined(separator: ", "))。操作前会重新核对进程身份。")
            }
        }
        .alert("KMonitor", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("知道了") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
                .flatMap(NSImage.init(contentsOf:)) ?? NSImage())
                .resizable()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("KMonitor")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("心天之眼 · 看清每个服务所在的分支")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("搜索分支、项目或端口", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            Button { Task { await store.refresh() } } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(store.isScanning)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(Palette.indigo)
                Text(branch)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.indigo.opacity(0.09), in: Capsule())
            }
            ForEach(items) { service in
                serviceCard(service)
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
                    Text("监听中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.teal)
                }
                Text(service.worktree)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text("\(service.command) · PID \(service.pid) · \(service.addresses.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
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
                Button("打开") { NSWorkspace.shared.open(url) }
            }
            Button("停止") { pendingStop = service }
                .disabled(store.stoppingPID != nil)
            Button("隐藏") { store.hide(service) }
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
                Button("恢复隐藏的服务") { store.restoreHidden() }
                    .font(.caption)
            }
            if let root = store.rootFilter {
                Text(root)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("清除过滤") { store.clearRoot() }
                    .font(.caption)
            }
            Button("选择工作区…") { store.chooseRoot() }
                .font(.caption)
            if let date = store.lastUpdated {
                Text("更新于 \(date.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                Text("KMonitor").font(.headline)
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
            Button("打开服务面板") { openWindow(id: "main") }
            Button("立即刷新") { Task { await store.refresh() } }
        }
        .padding(16)
        .frame(width: 260)
        .task { await store.refresh() }
    }
}

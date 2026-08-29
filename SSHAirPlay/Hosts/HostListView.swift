import SwiftData
import SwiftUI

struct HostListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: SessionStore
    @Query(sort: \Host.updatedAt, order: .reverse) private var hosts: [Host]

    @State private var editingHost: Host?
    @State private var isCreating = false
    @State private var hostPendingDelete: Host?

    var body: some View {
        NavigationStack {
            Group {
                if hosts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(hosts, id: \.id) { host in
                            Button {
                                sessionStore.connect(host: host)
                            } label: {
                                HostRow(host: host, isConnected: sessionStore.sessions.contains { $0.hostID == host.id && $0.isActive })
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("编辑") { editingHost = host }
                                Button("删除", role: .destructive) { hostPendingDelete = host }
                            }
                            .contextMenu {
                                Button("连接") { sessionStore.connect(host: host) }
                                Button("编辑") { editingHost = host }
                                Button("删除", role: .destructive) { hostPendingDelete = host }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("主机")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加主机")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isCreating) {
                HostEditView(host: nil)
            }
            .sheet(item: $editingHost) { host in
                HostEditView(host: host)
            }
            .alert("删除主机", isPresented: Binding(
                get: { hostPendingDelete != nil },
                set: { if !$0 { hostPendingDelete = nil } }
            )) {
                Button("删除", role: .destructive) {
                    if let host = hostPendingDelete {
                        sessionStore.closeAll(forHostID: host.id)
                        KeychainStore.deleteSecret(account: host.keychainAccount)
                        modelContext.delete(host)
                    }
                    hostPendingDelete = nil
                }
                Button("取消", role: .cancel) { hostPendingDelete = nil }
            } message: {
                Text("将同时断开该主机的活动会话。")
            }
            .alert(
                "无法新建会话",
                isPresented: Binding(
                    get: { sessionStore.sessionLimitMessage != nil },
                    set: { if !$0 { sessionStore.sessionLimitMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(sessionStore.sessionLimitMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有主机", systemImage: "server.rack")
        } description: {
            Text("添加一台服务器后即可开始 SSH。没有电视时也可以完整使用。")
        } actions: {
            Button("添加主机") { isCreating = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct HostRow: View {
    let host: Host
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(host.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundStyle(isConnected ? Color.mint : Color.secondary)
            }
            Text("\(host.username)@\(host.hostname):\(host.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

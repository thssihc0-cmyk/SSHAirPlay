import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var externalDisplay: ExternalDisplayCenter

    var body: some View {
        Group {
            if sessionStore.focusSessionID != nil {
                TerminalScreenView()
            } else {
                HostListView()
            }
        }
        .tint(.mint)
        .alert(
            "连接已中断",
            isPresented: Binding(
                get: { sessionStore.foregroundDisconnectAlert != nil },
                set: { if !$0 { sessionStore.foregroundDisconnectAlert = nil } }
            )
        ) {
            Button("重连") {
                sessionStore.reconnectFailedSessions()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(sessionStore.foregroundDisconnectAlert ?? "点此重连")
        }
        .onChange(of: externalDisplay.isPresented) { _, presented in
            sessionStore.isConsoleLayout = presented
            if presented {
                sessionStore.syncPtyToExternalDisplay()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sessionStore.handleSceneBecameActive()
            }
        }
    }
}

import AVKit
import SwiftUI

struct TerminalScreenView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var externalDisplay: ExternalDisplayCenter
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var keyboard = TerminalKeyboardController()
    @State private var ctrlActive = false
    @State private var pasteCandidate: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let session = sessionStore.focusSession {
                sessionStatusBar(session)
                LocalTerminalRepresentable(
                    session: session,
                    fontSize: sessionStore.isConsoleLayout ? 13 : settings.fontSizeLocal,
                    isReadOnly: false,
                    keyboard: keyboard
                )
                .id(session.id)
                .background(Color.black)
            } else {
                Color.black
            }
            AccessoryKeyBar(
                onSend: handleAccessory,
                onToggleCtrl: toggleCtrl,
                ctrlActive: ctrlActive,
                layout: keyboard.layout,
                isKeyboardVisible: keyboard.isVisible,
                onToggleKeyboard: keyboard.toggleVisibility,
                onToggleLayout: keyboard.toggleLayout
            )
        }
        .background(Color.black.ignoresSafeArea(edges: .top))
        .onAppear { keyboard.show() }
        .alert("粘贴多行？", isPresented: Binding(
            get: { pasteCandidate != nil },
            set: { if !$0 { pasteCandidate = nil } }
        )) {
            Button("粘贴") {
                if let text = pasteCandidate {
                    sendText(text)
                }
                pasteCandidate = nil
            }
            Button("取消", role: .cancel) { pasteCandidate = nil }
        } message: {
            Text("剪贴板包含多行内容，确认发送到终端吗？")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    sessionStore.focusSessionID = nil
                } label: {
                    Label("主机", systemImage: "chevron.left")
                }
                Spacer()
                if externalDisplay.isPresented {
                    Menu {
                        ForEach(ExternalLayoutMode.allCases) { mode in
                            Button(mode.title) {
                                externalDisplay.layoutOverride = mode == .auto ? nil : mode
                            }
                        }
                    } label: {
                        Text("已在电视上显示（非镜像）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.mint)
                    }
                }
                AirPlayRoutePicker()
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            sessionTabs
        }
        .background(Color.black.opacity(0.92))
    }

    private var sessionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sessionStore.sessions) { session in
                    HStack(spacing: 6) {
                        Button {
                            sessionStore.select(sessionID: session.id)
                        } label: {
                            Text(session.title)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(session.id == sessionStore.focusSessionID ? Color.mint.opacity(0.3) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            sessionStore.close(sessionID: session.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func sessionStatusBar(_ session: SSHSession) -> some View {
        HStack {
            Circle()
                .fill(session.state == .connected ? Color.mint : Color.orange)
                .frame(width: 8, height: 8)
            Text(session.statusMessage ?? session.state.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if session.state == .failed {
                Button("重连") {
                    sessionStore.reconnect(session)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }

    private func toggleCtrl() {
        ctrlActive.toggle()
        keyboard.terminal?.controlModifier = ctrlActive
    }

    private func handleAccessory(_ payload: String) {
        if ctrlActive, payload.count == 1, let scalar = payload.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
            let control = UInt8(scalar.value & 0x1f)
            sessionStore.focusSession?.send(ArraySlice([control]))
            ctrlActive = false
            keyboard.terminal?.controlModifier = false
            return
        }
        sendText(payload)
        if ctrlActive {
            ctrlActive = false
            keyboard.terminal?.controlModifier = false
        }
    }

    private func sendText(_ text: String) {
        if settings.confirmMultilinePaste, text.contains("\n"), text.split(separator: "\n").count > 1 {
            pasteCandidate = text
            return
        }
        sessionStore.focusSession?.send(ArraySlice(text.utf8))
    }
}

struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        view.activeTintColor = .systemMint
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

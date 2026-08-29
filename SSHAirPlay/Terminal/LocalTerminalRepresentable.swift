import SwiftTerm
import SwiftUI

struct LocalTerminalRepresentable: UIViewRepresentable {
    @ObservedObject var session: SSHSession
    var fontSize: CGFloat
    var isReadOnly: Bool
    var keyboard: TerminalKeyboardController? = nil
    var fillsDisplay: Bool = false
    var gridCols: Int = 80
    var gridRows: Int = 24

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, isReadOnly: isReadOnly)
    }

    func makeUIView(context: Context) -> ScaledTerminalHostView {
        let host = ScaledTerminalHostView()
        host.terminalView.terminalDelegate = context.coordinator
        host.terminalView.backgroundColor = .black
        host.terminalView.nativeBackgroundColor = .black
        host.terminalView.isOpaque = true
        host.terminalView.inputAccessoryView = nil
        host.applyFont(fontSize)
        context.coordinator.attach(to: host)
        return host
    }

    func updateUIView(_ uiView: ScaledTerminalHostView, context: Context) {
        context.coordinator.session = session
        context.coordinator.isReadOnly = isReadOnly
        uiView.fillsDisplay = fillsDisplay
        uiView.targetCols = fillsDisplay ? gridCols : session.cols
        uiView.targetRows = fillsDisplay ? gridRows : session.rows
        uiView.fontSize = fontSize
        if !fillsDisplay {
            uiView.applyFont(fontSize)
        }
        uiView.setNeedsLayout()
        if context.coordinator.attachedSessionID != session.id {
            context.coordinator.attach(to: uiView)
        }
        uiView.terminalView.isUserInteractionEnabled = !isReadOnly
        uiView.keyboardAnchor.isUserInteractionEnabled = false

        if isReadOnly {
            if uiView.keyboardAnchor.isFirstResponder {
                uiView.keyboardAnchor.resignFirstResponder()
            }
            return
        }

        if let keyboard {
            keyboard.anchor = uiView.keyboardAnchor
            keyboard.terminal = uiView.terminalView
            uiView.keyboardAnchor.layout = keyboard.layout
            uiView.keyboardAnchor.keyboardType = keyboard.layout.keyboardType
            context.coordinator.syncKeyboard(host: uiView, keyboard: keyboard)
        }
    }

    static func dismantleUIView(_ uiView: ScaledTerminalHostView, coordinator: Coordinator) {
        coordinator.detach()
        uiView.terminalView.terminalDelegate = nil
        uiView.keyboardAnchor.resignFirstResponder()
    }

    @MainActor
    final class Coordinator: NSObject, TerminalViewDelegate {
        var session: SSHSession
        var isReadOnly: Bool
        var attachedSessionID: UUID?
        private var consumerID: UUID?
        private weak var terminalView: TerminalView?

        init(session: SSHSession, isReadOnly: Bool) {
            self.session = session
            self.isReadOnly = isReadOnly
        }

        func attach(to host: ScaledTerminalHostView) {
            detach()
            terminalView = host.terminalView
            attachedSessionID = session.id
            consumerID = session.hub.register { [weak self] data in
                self?.terminalView?.feed(byteArray: data)
            }
        }

        func detach() {
            if let consumerID {
                session.hub.unregister(consumerID)
            }
            consumerID = nil
            attachedSessionID = nil
        }

        func syncKeyboard(host: ScaledTerminalHostView, keyboard: TerminalKeyboardController) {
            guard !isReadOnly else { return }
            DispatchQueue.main.async {
                guard host.window != nil else { return }
                if keyboard.isVisible {
                    if !host.keyboardAnchor.isFirstResponder {
                        _ = host.keyboardAnchor.becomeFirstResponder()
                    }
                    host.keyboardAnchor.reloadInputViews()
                } else if host.keyboardAnchor.isFirstResponder {
                    _ = host.keyboardAnchor.resignFirstResponder()
                }
            }
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            guard !isReadOnly else { return }
            if ExternalDisplayCenter.shared.isPresented { return }
            session.resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {
            session.title = title.isEmpty ? session.hostSnapshot.name : title
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            guard !isReadOnly else { return }
            session.send(data)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

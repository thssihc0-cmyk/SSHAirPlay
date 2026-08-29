import Combine
import Foundation
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()
    static let maxConcurrentSessions = 4

    @Published private(set) var sessions: [SSHSession] = []
    @Published var focusSessionID: UUID?
    @Published var isConsoleLayout = false
    @Published var sessionLimitMessage: String?
    @Published var foregroundDisconnectAlert: String?

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var cancellables: [UUID: AnyCancellable] = [:]

    var focusSession: SSHSession? {
        sessions.first(where: { $0.id == focusSessionID })
    }

    func session(id: UUID) -> SSHSession? {
        sessions.first(where: { $0.id == id })
    }

    func connect(host: Host) {
        sessionLimitMessage = nil
        guard sessions.count < Self.maxConcurrentSessions else {
            sessionLimitMessage = "最多同时 \(Self.maxConcurrentSessions) 个会话"
            return
        }

        let session = SSHSession(host: host)
        if ExternalDisplayCenter.shared.isPresented {
            session.resize(
                cols: AppSettings.shared.clampedExternalCols,
                rows: AppSettings.shared.clampedExternalRows
            )
        }
        sessions.append(session)
        focusSessionID = session.id
        observe(session)
        start(session)
    }

    func close(sessionID: UUID) {
        guard let session = session(id: sessionID) else { return }
        session.state = .closed
        session.requestDisconnect()
        tasks[sessionID]?.cancel()
        tasks[sessionID] = nil
        cancellables[sessionID] = nil
        sessions.removeAll { $0.id == sessionID }
        if focusSessionID == sessionID {
            focusSessionID = sessions.last?.id
        }
    }

    func closeAll(forHostID hostID: UUID) {
        for session in sessions where session.hostID == hostID {
            close(sessionID: session.id)
        }
    }

    func select(sessionID: UUID) {
        focusSessionID = sessionID
    }

    func reconnect(_ session: SSHSession) {
        guard session.state == .failed || session.state == .idle else { return }
        start(session)
    }

    func reconnectFailedSessions() {
        for session in sessions where session.state == .failed {
            reconnect(session)
        }
        foregroundDisconnectAlert = nil
    }

    func syncPtyToExternalDisplay() {
        guard ExternalDisplayCenter.shared.isPresented else { return }
        let cols = AppSettings.shared.clampedExternalCols
        let rows = AppSettings.shared.clampedExternalRows
        for session in sessions {
            session.resize(cols: cols, rows: rows)
        }
    }

    func handleSceneBecameActive() {
        let disconnected = sessions.filter { $0.state == .connected }.isEmpty && sessions.contains { $0.state == .failed }
        if disconnected {
            foregroundDisconnectAlert = "连接已中断，点此重连"
        }
    }

    private func start(_ session: SSHSession) {
        tasks[session.id]?.cancel()
        tasks[session.id] = Task { [weak session] in
            guard let session else { return }
            await SSHClientService.runInteractiveShell(session: session)
        }
    }

    private func observe(_ session: SSHSession) {
        cancellables[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

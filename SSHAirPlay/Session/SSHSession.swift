import Foundation

@MainActor
final class SessionTerminalHub {
    private var consumers: [UUID: (ArraySlice<UInt8>) -> Void] = [:]
    private(set) var replayBuffer = Data()
    private let maxReplayBytes = 512 * 1024

    func register(_ consumer: @escaping (ArraySlice<UInt8>) -> Void) -> UUID {
        let id = UUID()
        consumers[id] = consumer
        if !replayBuffer.isEmpty {
            consumer(ArraySlice(replayBuffer))
        }
        return id
    }

    func unregister(_ id: UUID) {
        consumers.removeValue(forKey: id)
    }

    func broadcast(_ data: ArraySlice<UInt8>) {
        if data.count >= maxReplayBytes {
            replayBuffer = Data(data.suffix(maxReplayBytes))
        } else {
            replayBuffer.append(contentsOf: data)
            if replayBuffer.count > maxReplayBytes {
                replayBuffer.removeFirst(replayBuffer.count - maxReplayBytes)
            }
        }
        for consumer in consumers.values {
            consumer(data)
        }
    }
}

@MainActor
final class SSHSession: ObservableObject, Identifiable {
    let id: UUID
    let hostID: UUID
    let hostSnapshot: HostSnapshot
    let hub = SessionTerminalHub()

    @Published var state: SessionState = .idle
    @Published var title: String
    @Published var statusMessage: String?
    @Published var reconnectAttempt = 0
    @Published var cols = 80
    @Published var rows = 24

    var outboundHandler: ((ArraySlice<UInt8>) -> Void)?
    var resizeHandler: ((Int, Int) -> Void)?
    var disconnectHandler: (() -> Void)?

    init(host: Host) {
        self.id = UUID()
        self.hostID = host.id
        self.hostSnapshot = HostSnapshot(host: host)
        self.title = host.name
    }

    var isActive: Bool {
        switch state {
        case .connecting, .authenticating, .connected, .reconnecting:
            true
        default:
            false
        }
    }

    func send(_ data: ArraySlice<UInt8>) {
        outboundHandler?(data)
    }

    func resize(cols: Int, rows: Int) {
        self.cols = max(cols, 20)
        self.rows = max(rows, 8)
        resizeHandler?(self.cols, self.rows)
    }

    func requestDisconnect() {
        disconnectHandler?()
    }
}

struct HostSnapshot: Sendable {
    let id: UUID
    let name: String
    let hostname: String
    let port: Int
    let username: String
    let authMethod: HostAuthMethod
    let keychainAccount: String

    init(host: Host) {
        self.id = host.id
        self.name = host.name
        self.hostname = host.hostname
        self.port = host.port
        self.username = host.username
        self.authMethod = host.authMethod
        self.keychainAccount = host.keychainAccount
    }
}

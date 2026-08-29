import Citadel
import Crypto
import Foundation
import NIO
import NIOSSH

enum SSHClientServiceError: LocalizedError {
    case missingCredential
    case unsupportedPrivateKey
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "找不到保存的密钥或密码"
        case .unsupportedPrivateKey:
            "暂不支持该私钥格式，请使用 Ed25519 或带口令提示的 OpenSSH 私钥"
        case .cancelled:
            "已取消连接"
        }
    }
}

enum SSHClientService {
    static func friendlyMessage(for error: Error) -> String {
        let text = String(describing: error).lowercased()
        if text.contains("auth") || text.contains("permission") || text.contains("denied") {
            return "用户名或密钥/密码被拒绝"
        }
        if text.contains("timeout") || text.contains("timed out") {
            return "连接超时，请检查网络和地址"
        }
        if text.contains("resolve") || text.contains("dns") || text.contains("connection refused") || text.contains("network") {
            return "无法连接到主机，请检查网络和地址"
        }
        return error.localizedDescription
    }

    static func runInteractiveShell(session: SSHSession) async {
        await MainActor.run {
            session.state = .connecting
            session.statusMessage = "正在连接到 \(session.hostSnapshot.hostname)"
        }

        var attempt = 0
        let maxAttempts = 3

        while true {
            let cancelled = await MainActor.run { session.state == .closed }
            if cancelled { return }

            do {
                try await connectOnce(session: session)
                return
            } catch is CancellationError {
                await MainActor.run {
                    session.state = .closed
                    session.statusMessage = nil
                }
                return
            } catch {
                attempt += 1
                let message = friendlyMessage(for: error)
                if attempt >= maxAttempts {
                    await MainActor.run {
                        session.state = .failed
                        session.statusMessage = message
                        session.reconnectAttempt = 0
                    }
                    return
                }

                await MainActor.run {
                    session.state = .reconnecting
                    session.reconnectAttempt = attempt
                    session.statusMessage = "正在重连（第 \(attempt)/\(maxAttempts) 次）"
                }

                let delay = UInt64([1, 2, 4][attempt - 1]) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private static func connectOnce(session: SSHSession) async throws {
        let snapshot = await MainActor.run { session.hostSnapshot }
        let cols = await MainActor.run { session.cols }
        let rows = await MainActor.run { session.rows }

        let secret = try KeychainStore.loadSecret(account: snapshot.keychainAccount)
        let method = try authenticationMethod(username: snapshot.username, authMethod: snapshot.authMethod, secret: secret)

        await MainActor.run {
            session.state = .authenticating
            session.statusMessage = "正在认证"
        }

        let client = try await SSHClient.connect(
            host: snapshot.hostname,
            port: snapshot.port,
            authenticationMethod: method,
            hostKeyValidator: .acceptAnything(),
            reconnect: .never,
            connectTimeout: .seconds(15)
        )

        client.onDisconnect {
            Task { @MainActor in
                if session.state == .connected {
                    session.state = .failed
                    session.statusMessage = "连接已中断，点此重连"
                }
            }
        }

        let request = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: .init([:])
        )

        try await client.withPTY(request) { inbound, outbound in
            await MainActor.run {
                session.state = .connected
                session.statusMessage = nil
                session.reconnectAttempt = 0
                session.outboundHandler = { data in
                    var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                    buffer.writeBytes(data)
                    Task {
                        try? await outbound.write(buffer)
                    }
                }
                session.resizeHandler = { newCols, newRows in
                    Task {
                        try? await outbound.changeSize(cols: newCols, rows: newRows, pixelWidth: 0, pixelHeight: 0)
                    }
                }
                session.disconnectHandler = {
                    Task {
                        try? await client.close()
                    }
                }
            }

            for try await output in inbound {
                let bytes: [UInt8]
                switch output {
                case .stdout(let buffer), .stderr(let buffer):
                    bytes = Array(buffer.readableBytesView)
                }
                guard !bytes.isEmpty else { continue }
                await MainActor.run {
                    session.hub.broadcast(ArraySlice(bytes))
                }
            }
        }

        await MainActor.run {
            session.outboundHandler = nil
            session.resizeHandler = nil
            session.disconnectHandler = nil
            if session.state == .connected {
                session.state = .failed
                session.statusMessage = "连接已中断，点此重连"
            }
        }
    }

    private static func authenticationMethod(
        username: String,
        authMethod: HostAuthMethod,
        secret: String
    ) throws -> SSHAuthenticationMethod {
        switch authMethod {
        case .password:
            return .passwordBased(username: username, password: secret)
        case .privateKey:
            if let key = try? Curve25519.Signing.PrivateKey(sshEd25519PrivateKey: secret) {
                return .ed25519(username: username, privateKey: key)
            }
            if let key = try? P256.Signing.PrivateKey(pemRepresentation: secret) {
                return .p256(username: username, privateKey: key)
            }
            if let key = try? P384.Signing.PrivateKey(pemRepresentation: secret) {
                return .p384(username: username, privateKey: key)
            }
            if let key = try? P521.Signing.PrivateKey(pemRepresentation: secret) {
                return .p521(username: username, privateKey: key)
            }
            throw SSHClientServiceError.unsupportedPrivateKey
        }
    }
}

private extension Curve25519.Signing.PrivateKey {
    init(sshEd25519PrivateKey pem: String) throws {
        let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("BEGIN OPENSSH PRIVATE KEY") {
            throw SSHClientServiceError.unsupportedPrivateKey
        }
        if let data = Data(base64Encoded: trimmed.split(separator: "\n").joined()) {
            self = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
            return
        }
        throw SSHClientServiceError.unsupportedPrivateKey
    }
}

import Foundation
import SwiftData

enum HostAuthMethod: String, Codable, CaseIterable, Identifiable {
    case privateKey
    case password

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateKey: "私钥"
        case .password: "密码"
        }
    }
}

@Model
final class Host {
    @Attribute(.unique) var id: UUID
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var authMethodRaw: String
    var keychainAccount: String
    var note: String
    var tag: String
    var createdAt: Date
    var updatedAt: Date

    var authMethod: HostAuthMethod {
        get { HostAuthMethod(rawValue: authMethodRaw) ?? .privateKey }
        set { authMethodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 22,
        username: String,
        authMethod: HostAuthMethod = .privateKey,
        keychainAccount: String = UUID().uuidString,
        note: String = "",
        tag: String = ""
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethodRaw = authMethod.rawValue
        self.keychainAccount = keychainAccount
        self.note = note
        self.tag = tag
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

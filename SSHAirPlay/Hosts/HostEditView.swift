import SwiftData
import SwiftUI

struct HostEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let host: Host?

    @State private var name = ""
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: HostAuthMethod = .privateKey
    @State private var secret = ""
    @State private var note = ""
    @State private var tag = ""
    @State private var showingKeyImport = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("主机") {
                    TextField("显示名", text: $name)
                    TextField("地址", text: $hostname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("认证") {
                    Picker("方式", selection: $authMethod) {
                        ForEach(HostAuthMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    if authMethod == .password {
                        SecureField("密码", text: $secret)
                    } else {
                        Button("导入或粘贴私钥") { showingKeyImport = true }
                        if !secret.isEmpty {
                            Text("已准备私钥（保存时写入钥匙串）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("可选") {
                    TextField("分组", text: $tag)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(host == nil ? "添加主机" : "编辑主机")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
            .sheet(isPresented: $showingKeyImport) {
                KeyImportView(secret: $secret)
            }
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let host else { return }
        name = host.name
        hostname = host.hostname
        port = String(host.port)
        username = host.username
        authMethod = host.authMethod
        note = host.note
        tag = host.tag
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedPort = Int(port) ?? 22

        guard !trimmedName.isEmpty, !trimmedHost.isEmpty, !trimmedUser.isEmpty else {
            errorMessage = "请填写显示名、地址和用户名"
            return
        }
        guard (1...65535).contains(parsedPort) else {
            errorMessage = "端口无效"
            return
        }

        let target = host ?? Host(name: trimmedName, hostname: trimmedHost, username: trimmedUser)
        target.name = trimmedName
        target.hostname = trimmedHost
        target.port = parsedPort
        target.username = trimmedUser
        target.authMethod = authMethod
        target.note = note
        target.tag = tag
        target.updatedAt = Date()

        if host == nil {
            modelContext.insert(target)
        }

        if !secret.isEmpty {
            do {
                try KeychainStore.saveSecret(secret, account: target.keychainAccount)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } else if host == nil {
            errorMessage = authMethod == .password ? "请填写密码" : "请导入私钥"
            return
        }

        dismiss()
    }
}

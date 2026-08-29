import SwiftUI
import UniformTypeIdentifiers

struct KeyImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var secret: String
    @State private var pasteText = ""
    @State private var isImporterPresented = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴") {
                    TextEditor(text: $pasteText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 160)
                }
                Section {
                    Button("从文件导入") { isImporterPresented = true }
                }
            }
            .navigationTitle("导入私钥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用") {
                        let value = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else {
                            errorMessage = "请粘贴或导入私钥"
                            return
                        }
                        secret = value
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.plainText, .item, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        pasteText = try String(contentsOf: url, encoding: .utf8)
                    } catch {
                        errorMessage = "无法读取文件"
                    }
                case .failure:
                    errorMessage = "无法打开文件"
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

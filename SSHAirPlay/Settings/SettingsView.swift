import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("终端") {
                Stepper(value: $settings.fontSizeLocal, in: 11...22, step: 1) {
                    Text("本机字号 \(Int(settings.fontSizeLocal))")
                }
                Toggle("粘贴多行前确认", isOn: $settings.confirmMultilinePaste)
            }

            Section("第二屏") {
                Picker("默认布局", selection: Binding(
                    get: { settings.externalLayout },
                    set: { settings.externalLayout = $0 }
                )) {
                    ForEach(ExternalLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("分辨率", selection: Binding(
                    get: { settings.externalResolution },
                    set: { settings.externalResolution = $0 }
                )) {
                    ForEach(ExternalResolution.allCases) { resolution in
                        Text(resolution.title).tag(resolution)
                    }
                }

                Stepper(value: $settings.externalCols, in: 40...400, step: 4) {
                    Text("列 \(settings.clampedExternalCols)")
                }
                Stepper(value: $settings.externalRows, in: 16...120, step: 1) {
                    Text("行 \(settings.clampedExternalRows)")
                }

                Text("第二屏使用独立分辨率和列×行，不再按手机终端缩放。连上电视后，SSH 窗口尺寸跟这里的列×行走。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Text("终端渲染使用 SwiftTerm，SSH 使用 Citadel。凭据仅保存在本机钥匙串。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .onChange(of: settings.externalCols) { _, _ in
            settings.objectWillChange.send()
            SessionStore.shared.syncPtyToExternalDisplay()
        }
        .onChange(of: settings.externalRows) { _, _ in
            settings.objectWillChange.send()
            SessionStore.shared.syncPtyToExternalDisplay()
        }
        .onChange(of: settings.externalResolutionRaw) { _, _ in
            settings.objectWillChange.send()
            ExternalDisplayCenter.shared.applyConfiguredResolution()
        }
    }
}

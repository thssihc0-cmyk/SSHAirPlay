import SwiftUI

struct AccessoryKeyBar: View {
    var onSend: (String) -> Void
    var onToggleCtrl: () -> Void
    var ctrlActive: Bool
    var layout: TerminalKeyboardLayout
    var isKeyboardVisible: Bool
    var onToggleKeyboard: () -> Void
    var onToggleLayout: () -> Void

    private let keys: [(title: String, payload: String?)] = [
        ("Esc", "\u{1b}"),
        ("Tab", "\t"),
        ("Ctrl", nil),
        ("Alt", "\u{1b}"),
        ("↑", "\u{1b}[A"),
        ("↓", "\u{1b}[B"),
        ("←", "\u{1b}[D"),
        ("→", "\u{1b}[C"),
        ("`", "`"),
        ("-", "-"),
        ("/", "/"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(keys, id: \.title) { key in
                        Button {
                            if key.title == "Ctrl" {
                                onToggleCtrl()
                            } else if let payload = key.payload {
                                onSend(payload)
                            }
                        } label: {
                            Text(key.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(key.title == "Ctrl" && ctrlActive ? Color.mint.opacity(0.35) : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onToggleLayout) {
                Text(layout.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.mint.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layout == .english ? "切换到系统键盘" : "切换到英文全键盘")

            Button(action: onToggleKeyboard) {
                Image(systemName: isKeyboardVisible ? "keyboard.chevron.compact.down" : "keyboard")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isKeyboardVisible ? "收起键盘" : "显示键盘")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

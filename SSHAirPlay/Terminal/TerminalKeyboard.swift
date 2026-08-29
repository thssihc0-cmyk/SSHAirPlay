import SwiftTerm
import UIKit

enum TerminalKeyboardLayout: String, CaseIterable, Identifiable {
    case english
    case system

    var id: String { rawValue }

    var keyboardType: UIKeyboardType {
        switch self {
        case .english: .asciiCapable
        case .system: .default
        }
    }

    var title: String {
        switch self {
        case .english: "英文"
        case .system: "系统"
        }
    }
}

@MainActor
final class TerminalKeyboardController: ObservableObject {
    @Published var isVisible = true
    @Published var layout: TerminalKeyboardLayout = .english

    weak var anchor: TerminalKeyboardAnchor?
    weak var terminal: TerminalView?

    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardDidHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.anchor?.isFirstResponder != true else { return }
                    self.isVisible = false
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardDidShowNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.anchor?.isFirstResponder == true else { return }
                    self.isVisible = true
                }
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func show() {
        isVisible = true
        apply()
    }

    func hide() {
        isVisible = false
        _ = anchor?.resignFirstResponder()
    }

    func toggleVisibility() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func toggleLayout() {
        layout = layout == .english ? .system : .english
        apply()
    }

    func apply() {
        guard let anchor else { return }
        anchor.layout = layout
        guard isVisible else { return }
        if anchor.window != nil {
            _ = anchor.becomeFirstResponder()
            anchor.reloadInputViews()
        }
    }
}

final class TerminalKeyboardAnchor: UIView, UIKeyInput, UITextInputTraits {
    weak var terminal: TerminalView?

    var layout: TerminalKeyboardLayout = .english {
        didSet { keyboardType = layout.keyboardType }
    }

    var keyboardType: UIKeyboardType = .asciiCapable
    var keyboardAppearance: UIKeyboardAppearance = .dark
    var returnKeyType: UIReturnKeyType = .default
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var enablesReturnKeyAutomatically = false
    var isSecureTextEntry = false
    var textContentType: UITextContentType?

    override var canBecomeFirstResponder: Bool { true }

    var hasText: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }

    required init?(coder: NSCoder) {
        nil
    }

    func insertText(_ text: String) {
        terminal?.insertText(text)
    }

    func deleteBackward() {
        terminal?.deleteBackward()
    }
}

final class SSHTerminalView: TerminalView {
    weak var keyboardAnchor: TerminalKeyboardAnchor?

    override var canBecomeFirstResponder: Bool { false }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        keyboardAnchor?.becomeFirstResponder() ?? false
    }
}

final class TerminalHostView: UIView {
    let terminalView = SSHTerminalView(frame: .zero)
    let keyboardAnchor = TerminalKeyboardAnchor()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        keyboardAnchor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminalView)
        addSubview(keyboardAnchor)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: topAnchor),
            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            keyboardAnchor.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardAnchor.topAnchor.constraint(equalTo: topAnchor),
            keyboardAnchor.widthAnchor.constraint(equalToConstant: 0),
            keyboardAnchor.heightAnchor.constraint(equalToConstant: 0),
        ])
        keyboardAnchor.terminal = terminalView
        terminalView.keyboardAnchor = keyboardAnchor
        terminalView.inputAccessoryView = nil
    }

    required init?(coder: NSCoder) {
        nil
    }
}

/// Independent second-screen grid: fills the view using configured cols×rows, not the phone PTY size.
final class ScaledTerminalHostView: UIView {
    let host = TerminalHostView()
    var fillsDisplay = false
    var targetCols = 80
    var targetRows = 24
    var fontSize: CGFloat = 16 {
        didSet {
            if !fillsDisplay {
                applyFont(fontSize)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        addSubview(host)
    }

    required init?(coder: NSCoder) {
        nil
    }

    var terminalView: SSHTerminalView { host.terminalView }
    var keyboardAnchor: TerminalKeyboardAnchor { host.keyboardAnchor }

    func applyFont(_ size: CGFloat) {
        host.terminalView.font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if fillsDisplay {
            layoutIndependentGrid()
        } else {
            host.transform = .identity
            host.frame = bounds
        }
    }

    private func layoutIndependentGrid() {
        guard bounds.width > 1, bounds.height > 1 else { return }

        let cols = max(targetCols, 20)
        let rows = max(targetRows, 8)
        let fitted = fittedFontSize(cols: CGFloat(cols), rows: CGFloat(rows), in: bounds.size)
        applyFont(fitted)

        host.transform = .identity
        host.frame = bounds
        host.layoutIfNeeded()
        host.terminalView.isScrollEnabled = false

        let terminal = host.terminalView.getTerminal()
        if terminal.cols != cols || terminal.rows != rows {
            host.terminalView.resize(cols: cols, rows: rows)
        }
    }

    private func fittedFontSize(cols: CGFloat, rows: CGFloat, in size: CGSize) -> CGFloat {
        let probe = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        let cell = cellSize(for: probe)
        let byWidth = size.width / cols / (cell.width / 16)
        let byHeight = size.height / rows / (cell.height / 16)
        return max(8, floor(min(byWidth, byHeight)))
    }

    private func cellSize(for font: UIFont) -> CGSize {
        let width = max(1, "W".size(withAttributes: [.font: font]).width)
        let height = max(1, ceil(font.ascender + abs(font.descender) + font.leading))
        return CGSize(width: width, height: height)
    }
}


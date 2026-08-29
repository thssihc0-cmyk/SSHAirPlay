import Combine
import Foundation
import UIKit

@MainActor
final class ExternalDisplayCenter: ObservableObject {
    static let shared = ExternalDisplayCenter()

    @Published var isPresented = false
    @Published var layoutOverride: ExternalLayoutMode?

    weak var windowScene: UIWindowScene?
    weak var window: UIWindow?

    var resolvedLayout: ExternalLayoutMode {
        layoutOverride ?? AppSettings.shared.externalLayout
    }

    private init() {}

    func attach(window: UIWindow, scene: UIWindowScene) {
        self.window = window
        self.windowScene = scene
        isPresented = true
        applyConfiguredResolution()
        SessionStore.shared.syncPtyToExternalDisplay()
    }

    func detach() {
        window = nil
        windowScene = nil
        isPresented = false
    }

    func applyConfiguredResolution() {
        guard let windowScene else { return }
        let screen = windowScene.screen
        if let target = AppSettings.shared.externalResolution.pixelSize {
            let modes = screen.availableModes
            if let best = modes.min(by: {
                hypot($0.size.width - target.width, $0.size.height - target.height)
                    < hypot($1.size.width - target.width, $1.size.height - target.height)
            }), screen.currentMode != best {
                screen.currentMode = best
            }
        }
        window?.frame = windowScene.coordinateSpace.bounds
        window?.rootViewController?.view.frame = window?.bounds ?? .zero
    }
}

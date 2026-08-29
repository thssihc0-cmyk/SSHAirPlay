import SwiftUI
import UIKit

final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let root = ExternalDisplayRootView()
            .environmentObject(SessionStore.shared)
            .environmentObject(ExternalDisplayCenter.shared)
            .environmentObject(AppSettings.shared)

        let hostingController = UIHostingController(rootView: root)
        hostingController.view.backgroundColor = .black
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }

        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.backgroundColor = .black
        window.rootViewController = hostingController
        hostingController.view.frame = window.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.isHidden = false
        self.window = window

        Task { @MainActor in
            ExternalDisplayCenter.shared.attach(window: window, scene: windowScene)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window?.windowScene = nil
        window = nil
        Task { @MainActor in
            ExternalDisplayCenter.shared.detach()
        }
    }
}

import SwiftData
import SwiftUI

@main
struct SSHAirPlayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var sessionStore = SessionStore.shared
    @ObservedObject private var externalDisplay = ExternalDisplayCenter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
                .environmentObject(externalDisplay)
                .preferredColorScheme(.dark)
        }
        .modelContainer(Self.modelContainer)
    }

    private static let modelContainer: ModelContainer = {
        let schema = Schema([Host.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()
}

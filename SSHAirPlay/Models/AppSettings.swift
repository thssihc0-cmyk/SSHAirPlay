import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("fontSizeLocal") var fontSizeLocal: Double = 14
    @AppStorage("confirmMultilinePaste") var confirmMultilinePaste: Bool = true
    @AppStorage("externalLayout") var externalLayoutRaw: String = ExternalLayoutMode.auto.rawValue
    @AppStorage("externalResolution") var externalResolutionRaw: String = ExternalResolution.auto.rawValue
    @AppStorage("externalCols") var externalCols: Int = 160
    @AppStorage("externalRows") var externalRows: Int = 50

    var externalLayout: ExternalLayoutMode {
        get { ExternalLayoutMode(rawValue: externalLayoutRaw) ?? .auto }
        set { externalLayoutRaw = newValue.rawValue }
    }

    var externalResolution: ExternalResolution {
        get { ExternalResolution(rawValue: externalResolutionRaw) ?? .auto }
        set { externalResolutionRaw = newValue.rawValue }
    }

    var clampedExternalCols: Int {
        min(400, max(40, externalCols))
    }

    var clampedExternalRows: Int {
        min(120, max(16, externalRows))
    }

    private init() {}
}

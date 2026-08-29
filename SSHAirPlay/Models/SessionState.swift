import CoreGraphics
import Foundation

enum SessionState: String, Equatable {
    case idle
    case connecting
    case authenticating
    case connected
    case reconnecting
    case failed
    case closed

    var title: String {
        switch self {
        case .idle: "未连接"
        case .connecting: "正在连接"
        case .authenticating: "正在认证"
        case .connected: "已连接"
        case .reconnecting: "正在重连"
        case .failed: "已断开"
        case .closed: "已关闭"
        }
    }
}

enum ExternalLayoutMode: String, CaseIterable, Identifiable {
    case auto
    case focus
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "自动"
        case .focus: "当前会话大屏"
        case .grid: "多会话宫格"
        }
    }
}

enum ExternalResolution: String, CaseIterable, Identifiable {
    case auto
    case hd720
    case hd1080
    case qhd
    case uhd4k

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "自动（设备默认）"
        case .hd720: "1280 × 720"
        case .hd1080: "1920 × 1080"
        case .qhd: "2560 × 1440"
        case .uhd4k: "3840 × 2160"
        }
    }

    var pixelSize: CGSize? {
        switch self {
        case .auto: nil
        case .hd720: CGSize(width: 1280, height: 720)
        case .hd1080: CGSize(width: 1920, height: 1080)
        case .qhd: CGSize(width: 2560, height: 1440)
        case .uhd4k: CGSize(width: 3840, height: 2160)
        }
    }
}


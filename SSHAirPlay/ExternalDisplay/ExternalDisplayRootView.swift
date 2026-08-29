import SwiftUI

struct ExternalDisplayRootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var externalDisplay: ExternalDisplayCenter
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if sessionStore.sessions.isEmpty {
            ExternalWaitingView()
        } else {
            switch resolvedLayout {
            case .auto:
                if sessionStore.sessions.count >= 2 {
                    ExternalGridView()
                } else {
                    ExternalFocusView()
                }
            case .focus:
                ExternalFocusView()
            case .grid:
                ExternalGridView()
            }
        }
    }

    private var resolvedLayout: ExternalLayoutMode {
        externalDisplay.layoutOverride ?? settings.externalLayout
    }
}

struct ExternalWaitingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.mint)
            Text("SSH AirPlay")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("在 iPhone 上连接主机")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.72))
            Text("此屏幕显示独立终端，不是镜像")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.45))
        }
        .multilineTextAlignment(.center)
        .padding(40)
    }
}

struct ExternalFocusView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let session = sessionStore.focusSession ?? sessionStore.sessions.first {
                    ExternalSessionHeader(session: session, compact: false)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                    LocalTerminalRepresentable(
                        session: session,
                        fontSize: 18,
                        isReadOnly: true,
                        fillsDisplay: true,
                        gridCols: settings.clampedExternalCols,
                        gridRows: settings.clampedExternalRows
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id("\(session.id)-\(settings.clampedExternalCols)x\(settings.clampedExternalRows)-\(settings.externalResolutionRaw)")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct ExternalGridView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var settings: AppSettings

    private var cells: [SSHSession?] {
        var items: [SSHSession?] = sessionStore.sessions.map { Optional($0) }
        while items.count < 4 {
            items.append(nil)
        }
        return Array(items.prefix(4))
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 16
            let cellWidth = (proxy.size.width - spacing * 3) / 2
            let cellHeight = (proxy.size.height - spacing * 3) / 2
            let columns = [GridItem(.fixed(cellWidth), spacing: spacing), GridItem(.fixed(cellWidth), spacing: spacing)]

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(0..<4, id: \.self) { index in
                    gridCell(cells[index])
                        .frame(width: cellWidth, height: cellHeight)
                }
            }
            .padding(spacing)
        }
    }

    @ViewBuilder
    private func gridCell(_ session: SSHSession?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
            if let session {
                VStack(spacing: 0) {
                    ExternalSessionHeader(session: session, compact: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    LocalTerminalRepresentable(
                        session: session,
                        fontSize: 14,
                        isReadOnly: true,
                        fillsDisplay: true,
                        gridCols: settings.clampedExternalCols,
                        gridRows: settings.clampedExternalRows
                    )
                        .id(session.id)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(8)
            } else {
                Text("空")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(session?.id == sessionStore.focusSessionID ? Color.mint : Color.clear, lineWidth: 3)
        )
    }
}

private struct ExternalSessionHeader: View {
    @ObservedObject var session: SSHSession
    var compact: Bool

    var body: some View {
        HStack {
            Text(session.title)
                .font(compact ? .headline : .title2.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(session.statusMessage ?? session.state.title)
                .font(compact ? .caption : .headline)
                .foregroundStyle(session.state == .connected ? Color.mint : Color.orange)
        }
    }
}

import AppKit
import SwiftUI

@MainActor
final class DynamicIslandController {
    private var panel: NSPanel?
    private var state: DynamicIslandState = .loading
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.positionPanel()
            }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func update(snapshot: DashboardSnapshot?) {
        state = DynamicIslandState(snapshot: snapshot)
        installOrUpdatePanel()
    }

    private func installOrUpdatePanel() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(rootView: DynamicIslandView(state: state))
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        return panel
    }

    private func positionPanel() {
        guard let panel,
              let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let availableWidth = max(260, screen.visibleFrame.width - 32)
        let size = CGSize(
            width: min(state.preferredSize.width, availableWidth),
            height: state.preferredSize.height
        )
        let origin = CGPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.visibleFrame.maxY - size.height - 6
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private enum DynamicIslandState {
    case loading
    case noInversion
    case recommendations([ClusterRecommendation])

    init(snapshot: DashboardSnapshot?) {
        guard let snapshot else {
            self = .loading
            return
        }
        let recommendations = snapshot.inversionRecommendations
        self = recommendations.isEmpty ? .noInversion : .recommendations(recommendations)
    }

    var preferredSize: CGSize {
        switch self {
        case .loading, .noInversion:
            return CGSize(width: 300, height: 46)
        case let .recommendations(recommendations):
            return CGSize(width: recommendations.count == 1 ? 480 : 820, height: 46)
        }
    }
}

private struct DynamicIslandView: View {
    let state: DynamicIslandState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.yellow)

            switch state {
            case .loading:
                Text("LOADING INTELLIGENCE INVERSIONS")
                    .foregroundStyle(.white.opacity(0.82))
            case .noInversion:
                Text("NO CURRENT INTELLIGENCE INVERSION")
                    .foregroundStyle(.white.opacity(0.82))
            case let .recommendations(recommendations):
                ForEach(recommendations, id: \.cluster) { recommendation in
                    recommendationButton(recommendation)
                }
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.94), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func recommendationButton(_ recommendation: ClusterRecommendation) -> some View {
        Button {
            guard let url = recommendation.recommended.modelURL else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Text("\(clusterName(recommendation.cluster))  \(modelName(recommendation.recommended)) > \(modelName(recommendation.expensivePeer))")
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func clusterName(_ cluster: ModelCluster) -> String {
        switch cluster {
        case .gpt:
            return "GPT"
        case .claude:
            return "CLAUDE"
        }
    }

    private func modelName(_ model: RankedModel) -> String {
        model.name.uppercased()
    }
}

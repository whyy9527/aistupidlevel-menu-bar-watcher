import AppKit
import SwiftUI

@MainActor
final class NotchIslandController {
    private var panel: NSPanel?
    private var recommendations: [ClusterRecommendation] = []
    private var isExpanded = false
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePanel(animated: false)
            }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func update(snapshot: DashboardSnapshot?) {
        recommendations = snapshot?.inversionRecommendations ?? []
        updatePanel(animated: false)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updatePanel(animated: true)
    }

    private func updatePanel(animated: Bool) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(
            rootView: NotchIslandView(
                recommendations: recommendations,
                isExpanded: isExpanded,
                onHover: { [weak self] hovering in
                    self?.setExpanded(hovering)
                }
            )
        )
        position(panel: panel, animated: animated)
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
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        return panel
    }

    private func position(panel: NSPanel, animated: Bool) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let preferredSize = NotchIslandLayout.size(
            for: recommendations.count,
            expanded: isExpanded
        )
        let size = CGSize(
            width: min(preferredSize.width, max(240, screen.frame.width - 32)),
            height: preferredSize.height
        )
        let frame = NSRect(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }
}

private enum NotchIslandLayout {
    static func size(for recommendationCount: Int, expanded: Bool) -> CGSize {
        guard expanded else {
            return CGSize(width: 196, height: 34)
        }
        return CGSize(width: 520, height: recommendationCount > 1 ? 142 : 96)
    }
}

private struct NotchIslandView: View {
    let recommendations: [ClusterRecommendation]
    let isExpanded: Bool
    let onHover: (Bool) -> Void

    var body: some View {
        Group {
            if isExpanded {
                expandedContent
            } else {
                compactContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, in: NotchShape())
        .contentShape(NotchShape())
        .onHover(perform: onHover)
    }

    private var compactContent: some View {
        HStack(spacing: 8) {
            Image(systemName: recommendations.isEmpty ? "bolt.slash.fill" : "bolt.fill")
                .foregroundStyle(recommendations.isEmpty ? .white.opacity(0.55) : .yellow)
            Text("\(recommendations.count)")
                .foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: recommendations.isEmpty ? "bolt.slash.fill" : "bolt.fill")
                    .foregroundStyle(recommendations.isEmpty ? .white.opacity(0.55) : .yellow)
                Text("INTELLIGENCE INVERSION")
                    .foregroundStyle(.white.opacity(0.68))
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))

            if recommendations.isEmpty {
                Text("NO CURRENT INVERSION")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                ForEach(recommendations, id: \.cluster) { recommendation in
                    Button {
                        guard let url = recommendation.recommended.modelURL else { return }
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 10) {
                            Text(modelName(recommendation.recommended))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.yellow)
                            Text(modelName(recommendation.expensivePeer))
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 11)
        .padding(.bottom, 15)
    }

    private func modelName(_ model: RankedModel) -> String {
        model.name.uppercased()
    }
}

private struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius = min(18, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

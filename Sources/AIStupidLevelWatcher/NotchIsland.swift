import AppKit
import SwiftUI

@MainActor
final class NotchIslandController: ObservableObject {
    private enum PreferenceKey {
        static let isEnabled = "notchIsland.isEnabled"
        static let focusedCluster = "notchIsland.focusedCluster"
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var focusedCluster: ModelCluster

    private var panel: NSPanel?
    private var snapshot: DashboardSnapshot?
    private var recommendations: [ClusterRecommendation] = []
    private var isExpanded = false
    private var screenObserver: NSObjectProtocol?

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: PreferenceKey.isEnabled) as? Bool ?? true
        focusedCluster = ModelCluster(rawValue: defaults.string(forKey: PreferenceKey.focusedCluster) ?? "") ?? .gpt
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
        self.snapshot = snapshot
        updateRecommendations()
        updatePanel(animated: false)
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: PreferenceKey.isEnabled)

        guard enabled else {
            isExpanded = false
            panel?.orderOut(nil)
            return
        }
        updatePanel(animated: false)
    }

    func focus(on cluster: ModelCluster) {
        guard focusedCluster != cluster else { return }
        focusedCluster = cluster
        UserDefaults.standard.set(cluster.rawValue, forKey: PreferenceKey.focusedCluster)
        isExpanded = false
        updateRecommendations()
        updatePanel(animated: false)
    }

    private func updateRecommendations() {
        let recommendation: ClusterRecommendation?
        switch focusedCluster {
        case .gpt:
            recommendation = snapshot?.gptRecommendation
        case .claude:
            recommendation = snapshot?.claudeRecommendation
        }
        recommendations = recommendation.map { [$0] } ?? []
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        updatePanel(animated: true)
    }

    private func requestExpansion(_ expanded: Bool) {
        guard isEnabled else { return }
        if expanded {
            DispatchQueue.main.async { [weak self] in
                self?.setExpanded(true)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self,
                  self.panel?.frame.contains(NSEvent.mouseLocation) != true else {
                return
            }
            self.setExpanded(false)
        }
    }

    private func updatePanel(animated: Bool) {
        guard isEnabled else {
            panel?.orderOut(nil)
            return
        }
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(
            rootView: NotchIslandView(
                recommendations: recommendations,
                isExpanded: isExpanded,
                onHover: { [weak self] hovering in
                    self?.requestExpansion(hovering)
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
        panel.isFloatingPanel = true
        // Setting isFloatingPanel after a custom level resets it to floating.
        // The screen-saver auxiliary level occupies the simulated-notch area.
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
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
        if recommendationCount == 0 {
            return CGSize(width: 520, height: 96)
        }
        return CGSize(width: 520, height: recommendationCount > 1 ? 176 : 126)
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
        Button {
            onHover(true)
        } label: {
            HStack(spacing: 7) {
                appIcon
                Text(compactRecommendationNames)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var compactRecommendationNames: String {
        guard !recommendations.isEmpty else {
            return "NO BETTER MODEL"
        }
        return recommendations
            .map { $0.recommended.name.uppercased() }
            .joined(separator: " · ")
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text(modelName(recommendation.recommended))
                                Spacer(minLength: 0)
                                Text(modelMetrics(recommendation.recommended))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.yellow)
                                Text(modelName(recommendation.expensivePeer))
                                Spacer(minLength: 0)
                                Text(modelMetrics(recommendation.expensivePeer))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Text(inversionMetrics(recommendation))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
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

    private func modelMetrics(_ model: RankedModel) -> String {
        let score = model.combined.map { String(format: "C %.0f", $0) } ?? "C —"
        let cost = model.blendedCostPerMillion.map { String(format: "$%.2f/M", $0) } ?? "price unknown"
        return "\(score) · \(cost)"
    }

    private func inversionMetrics(_ recommendation: ClusterRecommendation) -> String {
        let intelligenceGain = String(format: "+%.0f smarter", recommendation.scoreDifference)
        let savings = recommendation.costSavingsFraction.map {
            String(format: "%.0f%% less", $0 * 100)
        } ?? "lower cost"
        return "\(intelligenceGain) · \(savings)"
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

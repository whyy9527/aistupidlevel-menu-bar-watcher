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
    private var models: [RankedModel] = []
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
        updateModels()
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
        updateModels()
        updatePanel(animated: false)
    }

    private func updateModels() {
        let rows: [RankedModel]
        switch focusedCluster {
        case .gpt:
            rows = snapshot?.gptRows ?? []
        case .claude:
            rows = snapshot?.claudeRows ?? []
        }
        models = Array(rows.prefix(3))
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
                models: models,
                cluster: focusedCluster,
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
            for: models.count,
            expanded: isExpanded,
            screen: screen
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
    static func size(for modelCount: Int, expanded: Bool, screen: NSScreen) -> CGSize {
        guard expanded else {
            return CGSize(width: 196, height: compactHeight(on: screen))
        }
        return CGSize(width: 520, height: modelCount == 0 ? 96 : 132)
    }

    private static func compactHeight(on screen: NSScreen) -> CGFloat {
        // A MacBook's camera housing is taller than the menu bar. On a
        // notchless or external display, use the common floating-island size.
        if screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return max(32, NSStatusBar.system.thickness)
    }
}

private enum NotchIslandPalette {
    static let accent = Color(red: 0.76, green: 0.64, blue: 1.00)
}

private struct NotchIslandView: View {
    let models: [RankedModel]
    let cluster: ModelCluster
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
            Text(models.first?.name.uppercased() ?? "\(cluster.notchTitle.uppercased()) TOP 1")
                .foregroundStyle(.white)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(cluster.notchTitle.uppercased()) TOP 3")
                .foregroundStyle(.white.opacity(0.84))
                .font(.system(size: 11, weight: .bold, design: .rounded))

            if models.isEmpty {
                Text("NO \(cluster.notchTitle.uppercased()) MODELS")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                ForEach(models) { model in
                    Button {
                        guard let url = model.modelURL else { return }
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 8) {
                            Text("#\(model.clusterRank ?? 0)")
                                .foregroundStyle(NotchIslandPalette.accent)
                            Text(model.name.uppercased())
                            Spacer(minLength: 0)
                            Text(metrics(for: model))
                                .foregroundStyle(.white.opacity(0.86))
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

    private func metrics(for model: RankedModel) -> String {
        "C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))"
    }

    private func score(_ value: Double?) -> String {
        value.map { String(format: "%.0f", $0) } ?? "—"
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

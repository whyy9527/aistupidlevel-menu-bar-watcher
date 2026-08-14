import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: LeaderboardStore
    @ObservedObject var notchIsland: NotchIslandController

    private let leaderboardURL = URL(
        string: "https://aistupidlevel.info/?mode=leaderboard&period=latest&sortBy=combined"
    )!

    var body: some View {
        if let snapshot = store.snapshot {
            Menu("TOP 20") {
                ForEach(snapshot.top20) { model in
                    Button(modelLabel(model)) {
                        open(model.modelURL)
                    }
                }
            }

            Menu("TOP VALUE") {
                if snapshot.topValue20.isEmpty {
                    Text("No models have a verified price mapping")
                } else {
                    ForEach(snapshot.topValue20) { model in
                        Button(valueLabel(model)) {
                            open(model.modelURL)
                        }
                    }
                }
            }

            Menu(ModelCluster.gpt.menuTitle) {
                clusterContent(rows: snapshot.gptRows)
            }

            Menu(ModelCluster.claude.menuTitle) {
                clusterContent(rows: snapshot.claudeRows)
            }
        } else if store.isRefreshing {
            Text("Loading latest leaderboard…")
        } else {
            Text("No leaderboard snapshot yet")
        }

        if let error = store.lastError {
            Divider()
            Text("⚠️ Update failed: \(error)")
            Text("The last successful snapshot is retained")
        }

        Divider()
        Toggle(
            "Enable Notch Island",
            isOn: Binding(
                get: { notchIsland.isEnabled },
                set: { notchIsland.setEnabled($0) }
            )
        )

        Menu("Notch focus: \(notchIsland.focusedCluster.notchTitle)") {
            Button(notchIsland.focusedCluster == .gpt ? "✓ GPT" : "GPT") {
                notchIsland.focus(on: .gpt)
            }
            Button(notchIsland.focusedCluster == .claude ? "✓ Claude" : "Claude") {
                notchIsland.focus(on: .claude)
            }
        }

        Text(store.refreshStatusTitle)

        Divider()
        Button(store.isRefreshing ? "Refreshing…" : "Refresh") {
            Task { @MainActor in
                await store.refresh()
            }
        }
        .disabled(store.isRefreshing)

        Button("Open leaderboard in browser") {
            open(leaderboardURL)
        }

        Button("Open price-source mapping") {
            open(ModelPriceCatalog.sourceURL)
        }

        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func modelLabel(_ model: RankedModel) -> String {
        "\(modelName(model)) · #\(model.overallRank) · C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))"
    }

    @ViewBuilder
    private func clusterContent(rows: [RankedModel]) -> some View {
        if rows.isEmpty {
            Text("No cluster rows")
        } else {
            ForEach(rows) { model in
                Button(clusterLabel(model)) {
                    open(model.modelURL)
                }
            }
        }
    }

    private func clusterLabel(_ model: RankedModel) -> String {
        let familyRank = model.clusterRank.map { "#\($0)" } ?? "—"
        let trend = model.trend.map { " · \($0)" } ?? ""
        return "\(modelName(model)) · \(familyRank) · overall #\(model.overallRank) · C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))\(trend)"
    }

    private func valueLabel(_ model: RankedModel) -> String {
        let rank = model.valueRank.map { "#\($0)" } ?? "—"
        let cost = model.blendedCostPerMillion.map { String(format: "$%.2f", $0) } ?? "unknown"
        let value = model.valueScore.map { String(format: "%.1f", $0) } ?? "—"
        return "\(modelName(model)) · V \(rank) · \(value) pts/$ · \(cost)/1M"
    }

    private func score(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }

    private func modelName(_ model: RankedModel) -> String {
        model.name.uppercased()
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

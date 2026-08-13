import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: LeaderboardStore

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
                if snapshot.topValue.isEmpty {
                    Text("No models have a verified price mapping")
                } else {
                    ForEach(snapshot.topValue.prefix(20)) { model in
                        Button(valueLabel(model)) {
                            open(model.modelURL)
                        }
                    }
                }
            }

            Menu(ModelCluster.gpt.menuTitle) {
                clusterContent(
                    rows: snapshot.gptRows,
                    recommendation: snapshot.gptRecommendation
                )
            }

            Menu(ModelCluster.claude.menuTitle) {
                clusterContent(
                    rows: snapshot.claudeRows,
                    recommendation: snapshot.claudeRecommendation
                )
            }

            Menu("CLAUDE VS GPT") {
                if let comparison = snapshot.clusterComparison {
                    Button(comparisonScoreLabel(comparison)) {
                        open(comparison.gptScoreLeader.modelURL)
                    }
                    Button(comparisonValueLabel(comparison)) {
                        open(comparison.gptValuePick.modelURL)
                    }
                } else {
                    Text("No comparable GPT and Claude rows")
                }
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
        "#\(model.overallRank) \(model.name) · C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))"
    }

    @ViewBuilder
    private func clusterContent(
        rows: [RankedModel],
        recommendation: ClusterRecommendation?
    ) -> some View {
        if let recommendation {
            Button(recommendationLabel(recommendation)) {
                open(recommendation.recommended.modelURL)
            }
        }
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
        return "\(familyRank) · overall #\(model.overallRank) \(model.name) · C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))\(trend)"
    }

    private func valueLabel(_ model: RankedModel) -> String {
        let rank = model.valueRank.map { "#\($0)" } ?? "—"
        let cost = model.blendedCostPerMillion.map { String(format: "$%.2f", $0) } ?? "unknown"
        let value = model.valueScore.map { String(format: "%.1f", $0) } ?? "—"
        return "\(rank) \(model.name) · \(value) pts/$ · \(cost)/1M"
    }

    private func recommendationLabel(_ recommendation: ClusterRecommendation) -> String {
        let scoreGap = String(format: "%+.0f", recommendation.scoreDifference)
        let saving = String(format: "%.0f%%", recommendation.costSavingFraction * 100)
        let value = String(format: "%.1f×", recommendation.valueMultiplier)
        return "USE \(recommendation.recommended.name) over \(recommendation.expensivePeer.name) · C \(scoreGap) · \(saving) less · \(value) V"
    }

    private func comparisonScoreLabel(_ comparison: ClusterComparison) -> String {
        "TOP · GPT \(comparison.gptScoreLeader.name) \(score(comparison.gptScoreLeader.combined)) · CLAUDE \(comparison.claudeScoreLeader.name) \(score(comparison.claudeScoreLeader.combined))"
    }

    private func comparisonValueLabel(_ comparison: ClusterComparison) -> String {
        "VALUE · GPT \(comparison.gptValuePick.name) \(value(comparison.gptValuePick)) · CLAUDE \(comparison.claudeValuePick.name) \(value(comparison.claudeValuePick))"
    }

    private func score(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }

    private func value(_ model: RankedModel) -> String {
        guard let value = model.valueScore else { return "—" }
        return String(format: "V %.1f", value)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

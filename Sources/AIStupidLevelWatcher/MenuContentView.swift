import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: LeaderboardStore

    private let leaderboardURL = URL(
        string: "https://aistupidlevel.info/?mode=leaderboard&period=latest&sortBy=combined"
    )!

    var body: some View {
        if let snapshot = store.snapshot {
            Text("AI STUPID LEVEL")
            Text("V = combined score / estimated USD cost")
                .font(.caption)

            Menu("TOP VALUE · PRICE/PERFORMANCE") {
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

            Menu("TOP 20 · COMBINED") {
                ForEach(snapshot.top20) { model in
                    Button(modelLabel(model)) {
                        open(model.modelURL)
                    }
                }
            }

            Menu("GPT / OPENAI FAMILY") {
                if snapshot.gptRows.isEmpty {
                    Text("No GPT/OpenAI rows")
                } else {
                    ForEach(snapshot.gptRows) { model in
                        Button(gptLabel(model)) {
                            open(model.modelURL)
                        }
                    }
                }
            }

            Divider()
            Text("Source updated: \(snapshot.sourceUpdatedAt ?? "unknown")")
            Text("Price blend: 40% input + 60% output / 1M tokens")
            if let successful = store.lastSuccessfulFetch {
                Text("Fetched: \(successful.formatted(date: .omitted, time: .shortened))")
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

    private func gptLabel(_ model: RankedModel) -> String {
        let familyRank = model.gptRank.map { "GPT #\($0)" } ?? "GPT"
        let trend = model.trend.map { " · \($0)" } ?? ""
        return "\(familyRank) · overall #\(model.overallRank) \(model.name) · C \(score(model.combined)) · R \(score(model.reasoning)) · T \(score(model.tooling))\(trend)"
    }

    private func valueLabel(_ model: RankedModel) -> String {
        let rank = model.valueRank.map { "#\($0)" } ?? "—"
        let cost = model.blendedCostPerMillion.map { String(format: "$%.2f", $0) } ?? "unknown"
        let value = model.valueScore.map { String(format: "%.1f", $0) } ?? "—"
        return "\(rank) \(model.name) · \(value) pts/$ · \(cost)/1M"
    }

    private func score(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

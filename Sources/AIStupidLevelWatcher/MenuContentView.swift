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
            Text("C combined · R reasoning · T tooling")
                .font(.caption)

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

    private func score(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

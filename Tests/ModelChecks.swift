import Foundation

@main
struct ModelChecks {
    static func main() {
        let combined = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 90),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 73),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 72),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 72),
            ModelScore(id: "codex", name: "gpt-5.3-codex", provider: "openai", currentScore: 70),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 69),
            ModelScore(id: "luna", name: "gpt-5.6-luna", provider: "openai", currentScore: 61)
        ]
        let reasoning = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 40),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 85),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 81),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 78),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 75),
            ModelScore(id: "luna", name: "gpt-5.6-luna", provider: "openai", currentScore: 44)
        ]
        let tooling = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 45),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 95),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 92),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 90),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 88),
            ModelScore(id: "luna", name: "gpt-5.6-luna", provider: "openai", currentScore: 67)
        ]

        guard let snapshot = DashboardSnapshotBuilder.make(
            scoresByView: [
                .combined: combined,
                .reasoning: reasoning,
                .tooling: tooling
            ]
        ) else {
            fatalError("snapshot builder returned nil")
        }

        precondition(snapshot.top20.map(\.name) == ["alpha", "gpt-5.6-terra", "gpt-5.6-sol", "claude-opus-5", "gpt-5.3-codex", "claude-sonnet-5", "gpt-5.6-luna"])
        precondition(snapshot.gptRows.map(\.name) == ["gpt-5.6-terra", "gpt-5.6-sol", "gpt-5.3-codex", "gpt-5.6-luna"])
        precondition(snapshot.claudeRows.map(\.name) == ["claude-opus-5", "claude-sonnet-5"])
        precondition(snapshot.gptRows.prefix(3).map(\.name) == ["gpt-5.6-terra", "gpt-5.6-sol", "gpt-5.3-codex"])
        precondition(snapshot.claudeRows.prefix(3).map(\.name) == ["claude-opus-5", "claude-sonnet-5"])
        precondition(snapshot.gptRows[0].overallRank == 2)
        precondition(snapshot.gptRows[0].clusterRank == 1)
        precondition(snapshot.gptRows[0].reasoning == 85)
        precondition(snapshot.gptRows[0].tooling == 95)
        precondition(snapshot.topValue.map(\.name) == ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.3-codex", "claude-sonnet-5", "claude-opus-5", "gpt-5.6-sol"])
        precondition(snapshot.topValue20.map(\.name) == snapshot.topValue.map(\.name))
        precondition(snapshot.topValue[0].valueRank == 1)
        precondition(abs((snapshot.topValue[1].blendedCostPerMillion ?? 0) - 8) < 0.0001)

        let unavailable = #"{"id":"1","name":"model","provider":"openai","currentScore":"unavailable"}"#.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(ModelScore.self, from: unavailable)
        precondition(decoded.currentScore == nil)

        print("model checks passed")
    }
}

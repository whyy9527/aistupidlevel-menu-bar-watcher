import Foundation

@main
struct ModelChecks {
    static func main() {
        let combined = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 90),
            ModelScore(id: "g", name: "gpt-5.6-terra", provider: "openai", currentScore: 80),
            ModelScore(id: "c", name: "gpt-5.3-codex", provider: "openai", currentScore: 70)
        ]
        let reasoning = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 40),
            ModelScore(id: "g", name: "gpt-5.6-terra", provider: "openai", currentScore: 85),
            ModelScore(id: "c", name: "gpt-5.3-codex", provider: "openai", currentScore: 65)
        ]
        let tooling = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 45),
            ModelScore(id: "g", name: "gpt-5.6-terra", provider: "openai", currentScore: 95),
            ModelScore(id: "c", name: "gpt-5.3-codex", provider: "openai", currentScore: 90)
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

        precondition(snapshot.top20.map(\.name) == ["alpha", "gpt-5.6-terra", "gpt-5.3-codex"])
        precondition(snapshot.gptRows.map(\.name) == ["gpt-5.6-terra", "gpt-5.3-codex"])
        precondition(snapshot.gptRows[0].overallRank == 2)
        precondition(snapshot.gptRows[0].gptRank == 1)
        precondition(snapshot.gptRows[0].reasoning == 85)
        precondition(snapshot.gptRows[0].tooling == 95)

        let unavailable = #"{"id":"1","name":"model","provider":"openai","currentScore":"unavailable"}"#.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(ModelScore.self, from: unavailable)
        precondition(decoded.currentScore == nil)

        print("model checks passed")
    }
}

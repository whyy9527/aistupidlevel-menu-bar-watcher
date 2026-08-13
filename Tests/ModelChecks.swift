import Foundation

@main
struct ModelChecks {
    static func main() {
        let combined = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 90),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 75),
            ModelScore(id: "codex", name: "gpt-5.3-codex", provider: "openai", currentScore: 73),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 73),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 71),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 69)
        ]
        let reasoning = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 40),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 85),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 81),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 78),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 75)
        ]
        let tooling = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 45),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 95),
            ModelScore(id: "terra", name: "gpt-5.6-terra", provider: "openai", currentScore: 92),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 90),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 88)
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

        precondition(snapshot.top20.map(\.name) == ["alpha", "gpt-5.6-sol", "gpt-5.3-codex", "claude-opus-5", "gpt-5.6-terra", "claude-sonnet-5"])
        precondition(snapshot.gptRows.map(\.name) == ["gpt-5.6-sol", "gpt-5.3-codex", "gpt-5.6-terra"])
        precondition(snapshot.claudeRows.map(\.name) == ["claude-opus-5", "claude-sonnet-5"])
        precondition(snapshot.gptRows[0].overallRank == 2)
        precondition(snapshot.gptRows[0].clusterRank == 1)
        precondition(snapshot.gptRows[0].reasoning == 85)
        precondition(snapshot.gptRows[0].tooling == 95)
        precondition(snapshot.topValue.map(\.name) == ["gpt-5.6-terra", "gpt-5.3-codex", "claude-sonnet-5", "claude-opus-5", "gpt-5.6-sol"])
        precondition(snapshot.topValue20.map(\.name) == snapshot.topValue.map(\.name))
        precondition(snapshot.topValue[0].valueRank == 1)
        precondition(abs((snapshot.topValue[0].blendedCostPerMillion ?? 0) - 8) < 0.0001)

        let gptRecommendation = try! require(snapshot.gptRecommendation)
        precondition(gptRecommendation.recommended.name == "gpt-5.6-terra")
        precondition(gptRecommendation.expensivePeer.name == "gpt-5.6-sol")
        precondition(gptRecommendation.scoreDifference == -4)
        precondition(abs(gptRecommendation.costSavingFraction - 0.6) < 0.0001)
        precondition(gptRecommendation.valueMultiplier > 2)

        let claudeRecommendation = try! require(snapshot.claudeRecommendation)
        precondition(claudeRecommendation.recommended.name == "claude-sonnet-5")
        precondition(claudeRecommendation.expensivePeer.name == "claude-opus-5")
        precondition(claudeRecommendation.scoreDifference == -4)
        precondition(claudeRecommendation.valueMultiplier > 1.5)

        let comparison = try! require(snapshot.clusterComparison)
        precondition(comparison.gptScoreLeader.name == "gpt-5.6-sol")
        precondition(comparison.claudeScoreLeader.name == "claude-opus-5")
        precondition(comparison.gptValuePick.name == "gpt-5.6-terra")
        precondition(comparison.claudeValuePick.name == "claude-sonnet-5")

        let top20Peer = RankedModel(
            id: "top20-peer",
            name: "gpt-5.6-sol",
            provider: "openai",
            combined: 75,
            reasoning: nil,
            tooling: nil,
            trend: nil,
            status: nil,
            lastUpdated: nil,
            confidenceLower: nil,
            confidenceUpper: nil,
            standardError: nil,
            overallRank: 1,
            cluster: .gpt,
            clusterRank: 1,
            price: .init(inputPerMillion: 5, outputPerMillion: 30),
            valueRank: 21
        )
        let valueOnlyCandidate = RankedModel(
            id: "value-only-candidate",
            name: "gpt-5.6-terra",
            provider: "openai",
            combined: 71,
            reasoning: nil,
            tooling: nil,
            trend: nil,
            status: nil,
            lastUpdated: nil,
            confidenceLower: nil,
            confidenceUpper: nil,
            standardError: nil,
            overallRank: 21,
            cluster: .gpt,
            clusterRank: 2,
            price: .init(inputPerMillion: 2, outputPerMillion: 12),
            valueRank: 1
        )
        precondition(
            ClusterRecommendationBuilder.best(
                in: .gpt,
                top20: [top20Peer],
                topValue20: [valueOnlyCandidate]
            ) == nil
        )

        let unavailable = #"{"id":"1","name":"model","provider":"openai","currentScore":"unavailable"}"#.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(ModelScore.self, from: unavailable)
        precondition(decoded.currentScore == nil)

        print("model checks passed")
    }

    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw ModelCheckError.missingValue }
        return value
    }
}

private enum ModelCheckError: Error {
    case missingValue
}

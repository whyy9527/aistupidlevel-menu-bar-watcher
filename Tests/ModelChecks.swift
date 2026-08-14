import Foundation

@main
struct ModelChecks {
    static func main() {
        let combined = [
            ModelScore(id: "a", name: "alpha", provider: "other", currentScore: 90),
            ModelScore(
                id: "terra",
                name: "gpt-5.6-terra",
                provider: "openai",
                currentScore: 73,
                confidenceLower: 65,
                confidenceUpper: 80
            ),
            ModelScore(id: "sol", name: "gpt-5.6-sol", provider: "openai", currentScore: 72),
            ModelScore(id: "opus", name: "claude-opus-5", provider: "anthropic", currentScore: 72),
            ModelScore(id: "codex", name: "gpt-5.3-codex", provider: "openai", currentScore: 70),
            ModelScore(id: "sonnet", name: "claude-sonnet-5", provider: "anthropic", currentScore: 69),
            ModelScore(
                id: "luna",
                name: "gpt-5.6-luna",
                provider: "openai",
                currentScore: 61,
                confidenceLower: 60,
                confidenceUpper: 78
            )
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
        precondition(snapshot.gptRows[0].overallRank == 2)
        precondition(snapshot.gptRows[0].clusterRank == 1)
        precondition(snapshot.gptRows[0].reasoning == 85)
        precondition(snapshot.gptRows[0].tooling == 95)
        precondition(snapshot.topValue.map(\.name) == ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.3-codex", "claude-sonnet-5", "claude-opus-5", "gpt-5.6-sol"])
        precondition(snapshot.topValue20.map(\.name) == snapshot.topValue.map(\.name))
        precondition(snapshot.topValue[0].valueRank == 1)
        precondition(abs((snapshot.topValue[1].blendedCostPerMillion ?? 0) - 8) < 0.0001)

        let gptRecommendation = try! require(snapshot.gptRecommendation)
        precondition(gptRecommendation.recommended.name == "gpt-5.6-terra")
        precondition(gptRecommendation.expensivePeer.name == "gpt-5.6-sol")
        precondition(gptRecommendation.scoreDifference == 1)
        precondition(gptRecommendation.recommended.valueRank == 2)

        precondition(snapshot.claudeRecommendation == nil)

        let comparison = try! require(snapshot.clusterComparison)
        precondition(comparison.gptScoreLeader.name == "gpt-5.6-terra")
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

        let slightlyCheaperCandidate = RankedModel(
            id: "slightly-cheaper-candidate",
            name: "gpt-5.6-terra",
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
            price: .init(inputPerMillion: 0.98, outputPerMillion: 8.82),
            valueRank: 1
        )
        let slightlyMoreExpensivePeer = RankedModel(
            id: "slightly-more-expensive-peer",
            name: "gpt-5.5",
            provider: "openai",
            combined: 74,
            reasoning: nil,
            tooling: nil,
            trend: nil,
            status: nil,
            lastUpdated: nil,
            confidenceLower: nil,
            confidenceUpper: nil,
            standardError: nil,
            overallRank: 2,
            cluster: .gpt,
            clusterRank: 2,
            price: .init(inputPerMillion: 1, outputPerMillion: 9),
            valueRank: nil
        )
        let smallSavingRecommendation = try! require(
            ClusterRecommendationBuilder.best(
                in: .gpt,
                top20: [slightlyCheaperCandidate, slightlyMoreExpensivePeer],
                topValue20: [slightlyCheaperCandidate]
            )
        )
        precondition(smallSavingRecommendation.recommended.id == slightlyCheaperCandidate.id)
        precondition(smallSavingRecommendation.expensivePeer.id == slightlyMoreExpensivePeer.id)

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

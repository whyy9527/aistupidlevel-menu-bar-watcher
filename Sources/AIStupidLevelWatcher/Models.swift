import Foundation

enum ScoreView: String, CaseIterable, Hashable {
    case combined
    case reasoning
    case tooling
}

struct ModelScore: Decodable, Hashable {
    let id: String
    let name: String
    let provider: String
    let currentScore: Double?
    let trend: String?
    let status: String?
    let lastUpdated: String?
    let confidenceLower: Double?
    let confidenceUpper: Double?
    let standardError: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case provider
        case vendor
        case currentScore
        case score
        case trend
        case status
        case lastUpdated
        case confidenceLower
        case confidenceUpper
        case standardError
    }

    init(
        id: String,
        name: String,
        provider: String,
        currentScore: Double?,
        trend: String? = nil,
        status: String? = nil,
        lastUpdated: String? = nil,
        confidenceLower: Double? = nil,
        confidenceUpper: Double? = nil,
        standardError: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.currentScore = currentScore
        self.trend = trend
        self.status = status
        self.lastUpdated = lastUpdated
        self.confidenceLower = confidenceLower
        self.confidenceUpper = confidenceUpper
        self.standardError = standardError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let id = Self.decodeText(container, forKey: .id),
              let name = Self.decodeText(container, forKey: .name) else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "A model row must contain id and name"
            )
        }

        self.init(
            id: id,
            name: name,
            provider: Self.decodeText(container, forKey: .provider)
                ?? Self.decodeText(container, forKey: .vendor)
                ?? "unknown",
            currentScore: Self.decodeDouble(container, forKey: .currentScore)
                ?? Self.decodeDouble(container, forKey: .score),
            trend: Self.decodeText(container, forKey: .trend),
            status: Self.decodeText(container, forKey: .status),
            lastUpdated: Self.decodeText(container, forKey: .lastUpdated),
            confidenceLower: Self.decodeDouble(container, forKey: .confidenceLower),
            confidenceUpper: Self.decodeDouble(container, forKey: .confidenceUpper),
            standardError: Self.decodeDouble(container, forKey: .standardError)
        )
    }

    private static func decodeText<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    private static func decodeDouble<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}

struct CachedPayload: Decodable {
    let modelScores: [ModelScore]?
}

struct CachedEnvelope: Decodable {
    let success: Bool?
    let data: CachedPayload?
    let message: String?
    let meta: CacheMetadata?
}

struct ScoreEnvelope: Decodable {
    let success: Bool?
    let data: [ModelScore]?
    let message: String?
}

struct CacheMetadata: Decodable {
    let period: String?
    let sortBy: String?
    let cachedAt: String?
    let includesHistory: Bool?
}

enum ModelCluster: String, CaseIterable, Hashable {
    case gpt
    case claude

    var menuTitle: String {
        switch self {
        case .gpt:
            return "GPT CLUSTER"
        case .claude:
            return "CLAUDE CLUSTER"
        }
    }

    static func resolve(provider: String, name: String) -> Self? {
        let normalizedProvider = provider.lowercased()
        let normalizedName = name.lowercased()

        if normalizedProvider == "openai"
            || normalizedName == "gpt"
            || normalizedName.hasPrefix("gpt-")
            || normalizedName.hasPrefix("gpt") {
            return .gpt
        }
        if normalizedProvider == "anthropic"
            || normalizedName == "claude"
            || normalizedName.hasPrefix("claude-")
            || normalizedName.hasPrefix("claude") {
            return .claude
        }
        return nil
    }
}

struct RankedModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let combined: Double?
    let reasoning: Double?
    let tooling: Double?
    let trend: String?
    let status: String?
    let lastUpdated: String?
    let confidenceLower: Double?
    let confidenceUpper: Double?
    let standardError: Double?
    let overallRank: Int
    let cluster: ModelCluster?
    let clusterRank: Int?
    let price: ModelPrice?
    let valueRank: Int?

    var blendedCostPerMillion: Double? { price?.blendedPerMillion }

    var valueScore: Double? {
        guard let combined, let cost = blendedCostPerMillion, cost > 0 else { return nil }
        return combined / cost
    }

    var modelURL: URL? {
        let slug = name.lowercased()
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            .joined(separator: "-")
        return URL(string: "https://aistupidlevel.info/models/\(slug)")
    }
}

struct ClusterRecommendation: Hashable {
    let cluster: ModelCluster
    let recommended: RankedModel
    let expensivePeer: RankedModel
    let scoreDifference: Double
    let costSavingFraction: Double
    let valueMultiplier: Double
}

struct ClusterComparison: Hashable {
    let gptScoreLeader: RankedModel
    let claudeScoreLeader: RankedModel
    let gptValuePick: RankedModel
    let claudeValuePick: RankedModel
}

struct DashboardSnapshot {
    static let menuLimit = 20

    let rows: [RankedModel]
    let fetchedAt: Date
    let sourceUpdatedAt: String?

    var top20: [RankedModel] {
        Array(rows.prefix(Self.menuLimit))
    }

    var gptRows: [RankedModel] {
        rows.filter { $0.cluster == .gpt }
    }

    var claudeRows: [RankedModel] {
        rows.filter { $0.cluster == .claude }
    }

    var bestCombined: RankedModel? {
        rows.first
    }

    var topValue: [RankedModel] {
        rows.compactMap { $0.valueRank == nil ? nil : $0 }
            .sorted { ($0.valueRank ?? .max) < ($1.valueRank ?? .max) }
    }

    var topValue20: [RankedModel] {
        Array(topValue.prefix(Self.menuLimit))
    }

    var bestValue: RankedModel? {
        topValue20.first
    }

    var gptRecommendation: ClusterRecommendation? {
        recommendation(for: .gpt)
    }

    var claudeRecommendation: ClusterRecommendation? {
        recommendation(for: .claude)
    }

    var clusterComparison: ClusterComparison? {
        guard let gptScoreLeader = gptRows.first,
              let claudeScoreLeader = claudeRows.first,
              let gptValuePick = valuePick(for: .gpt),
              let claudeValuePick = valuePick(for: .claude) else {
            return nil
        }
        return ClusterComparison(
            gptScoreLeader: gptScoreLeader,
            claudeScoreLeader: claudeScoreLeader,
            gptValuePick: gptValuePick,
            claudeValuePick: claudeValuePick
        )
    }

    private func recommendation(for cluster: ModelCluster) -> ClusterRecommendation? {
        ClusterRecommendationBuilder.best(
            in: cluster,
            top20: top20,
            topValue20: topValue20
        )
    }

    private func valuePick(for cluster: ModelCluster) -> RankedModel? {
        if let recommendation = recommendation(for: cluster) {
            return recommendation.recommended
        }
        return topValue20.first { $0.cluster == cluster }
    }
}

enum ClusterRecommendationBuilder {
    /// A candidate must stay near the cluster frontier, then strictly beat a
    /// more expensive peer while saving at least 25% of blended cost and
    /// delivering at least 25% more value.
    private static let minimumCostSavingFraction = 0.25
    private static let minimumValueMultiplier = 1.25
    private static let minimumScoreTolerance = 3.0
    private static let relativeScoreTolerance = 0.07

    static func best(
        in cluster: ModelCluster,
        top20: [RankedModel],
        topValue20: [RankedModel]
    ) -> ClusterRecommendation? {
        let topValueIDs = Set(topValue20.map(\.id))
        let intelligenceRows = top20.filter { $0.cluster == cluster }
        guard let intelligenceLeader = intelligenceRows.first,
              let intelligenceLeaderScore = intelligenceLeader.combined else {
            return nil
        }
        let candidateRows = intelligenceRows.filter { model in
            guard let score = model.combined, topValueIDs.contains(model.id) else {
                return false
            }
            return scoresAreComparable(
                lowerCostScore: score,
                higherCostScore: intelligenceLeaderScore
            )
        }
        var recommendations: [ClusterRecommendation] = []

        for recommended in candidateRows {
            guard let recommendedScore = recommended.combined,
                  let recommendedCost = recommended.blendedCostPerMillion,
                  let recommendedValue = recommended.valueScore,
                  recommendedCost > 0 else {
                continue
            }

            for expensivePeer in intelligenceRows {
                guard recommended.id != expensivePeer.id,
                      let expensiveScore = expensivePeer.combined,
                      let expensiveCost = expensivePeer.blendedCostPerMillion,
                      let expensiveValue = expensivePeer.valueScore,
                      expensiveCost > recommendedCost,
                      expensiveValue > 0 else {
                    continue
                }

                let costSavingFraction = 1 - (recommendedCost / expensiveCost)
                let valueMultiplier = recommendedValue / expensiveValue
                guard recommendedScore > expensiveScore,
                      costSavingFraction >= minimumCostSavingFraction,
                      valueMultiplier >= minimumValueMultiplier else {
                    continue
                }

                recommendations.append(
                    ClusterRecommendation(
                        cluster: cluster,
                        recommended: recommended,
                        expensivePeer: expensivePeer,
                        scoreDifference: recommendedScore - expensiveScore,
                        costSavingFraction: costSavingFraction,
                        valueMultiplier: valueMultiplier
                    )
                )
            }
        }

        return recommendations.sorted { lhs, rhs in
            let leftValueRank = lhs.recommended.valueRank ?? .max
            let rightValueRank = rhs.recommended.valueRank ?? .max
            if leftValueRank != rightValueRank {
                return leftValueRank < rightValueRank
            }
            if lhs.recommended.combined != rhs.recommended.combined {
                return (lhs.recommended.combined ?? -.infinity) > (rhs.recommended.combined ?? -.infinity)
            }
            if lhs.expensivePeer.combined != rhs.expensivePeer.combined {
                return (lhs.expensivePeer.combined ?? -.infinity) > (rhs.expensivePeer.combined ?? -.infinity)
            }
            if lhs.valueMultiplier != rhs.valueMultiplier {
                return lhs.valueMultiplier > rhs.valueMultiplier
            }
            return lhs.recommended.overallRank < rhs.recommended.overallRank
        }.first
    }

    private static func scoresAreComparable(
        lowerCostScore: Double,
        higherCostScore: Double
    ) -> Bool {
        let tolerance = max(
            minimumScoreTolerance,
            abs(higherCostScore) * relativeScoreTolerance
        )
        return lowerCostScore >= higherCostScore - tolerance
    }
}

enum DashboardSnapshotBuilder {
    static func make(
        scoresByView: [ScoreView: [ModelScore]],
        fetchedAt: Date = Date(),
        sourceUpdatedAt: String? = nil
    ) -> DashboardSnapshot? {
        guard let combinedScores = scoresByView[.combined], !combinedScores.isEmpty else {
            return nil
        }

        let reasoningByID = Dictionary(
            uniqueKeysWithValues: (scoresByView[.reasoning] ?? []).map { ($0.id, $0) }
        )
        let toolingByID = Dictionary(
            uniqueKeysWithValues: (scoresByView[.tooling] ?? []).map { ($0.id, $0) }
        )

        var uniqueCombined: [ModelScore] = []
        var seenIDs = Set<String>()
        for model in combinedScores {
            if seenIDs.insert(model.id).inserted {
                uniqueCombined.append(model)
            }
        }

        let sourceOrder = Dictionary(
            uniqueKeysWithValues: uniqueCombined.enumerated().map { ($0.element.id, $0.offset) }
        )
        let sorted = uniqueCombined.sorted { lhs, rhs in
            let leftScore = lhs.currentScore ?? -.infinity
            let rightScore = rhs.currentScore ?? -.infinity
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            return (sourceOrder[lhs.id] ?? 0) < (sourceOrder[rhs.id] ?? 0)
        }
        let overallRanks = Dictionary(
            uniqueKeysWithValues: sorted.enumerated().map { ($0.element.id, $0.offset + 1) }
        )
        let clusterRanks = Dictionary(
            uniqueKeysWithValues: ModelCluster.allCases.flatMap { cluster in
                sorted
                    .filter {
                        ModelCluster.resolve(provider: $0.provider, name: $0.name) == cluster
                    }
                    .enumerated()
                    .map { ("\(cluster.rawValue):\($0.element.id)", $0.offset + 1) }
            }
        )

        let priceByID = Dictionary(uniqueKeysWithValues: sorted.map {
            ($0.id, ModelPriceCatalog.price(for: $0.name, provider: $0.provider))
        })
        let valueModels = sorted.filter { model in
            guard let score = model.currentScore, let price = priceByID[model.id] ?? nil else { return false }
            return score > 0 && price.blendedPerMillion > 0
        }
        let valueRanks = Dictionary(uniqueKeysWithValues: valueModels
            .sorted { lhs, rhs in
                let lhsValue = (lhs.currentScore ?? 0) / (priceByID[lhs.id]!!).blendedPerMillion
                let rhsValue = (rhs.currentScore ?? 0) / (priceByID[rhs.id]!!).blendedPerMillion
                return lhsValue == rhsValue ? (overallRanks[lhs.id] ?? 0) < (overallRanks[rhs.id] ?? 0) : lhsValue > rhsValue
            }
            .enumerated().map { ($0.element.id, $0.offset + 1) }
        )

        let rows = sorted.enumerated().map { _, model in
            RankedModel(
                id: model.id,
                name: model.name,
                provider: model.provider,
                combined: model.currentScore,
                reasoning: reasoningByID[model.id]?.currentScore,
                tooling: toolingByID[model.id]?.currentScore,
                trend: model.trend,
                status: model.status,
                lastUpdated: model.lastUpdated,
                confidenceLower: model.confidenceLower,
                confidenceUpper: model.confidenceUpper,
                standardError: model.standardError,
                overallRank: overallRanks[model.id] ?? 0,
                cluster: ModelCluster.resolve(provider: model.provider, name: model.name),
                clusterRank: ModelCluster
                    .resolve(provider: model.provider, name: model.name)
                    .flatMap { clusterRanks["\($0.rawValue):\(model.id)"] },
                price: priceByID[model.id] ?? nil,
                valueRank: valueRanks[model.id]
            )
        }

        return DashboardSnapshot(
            rows: rows,
            fetchedAt: fetchedAt,
            sourceUpdatedAt: sourceUpdatedAt ?? combinedScores.compactMap(\.lastUpdated).first
        )
    }

}

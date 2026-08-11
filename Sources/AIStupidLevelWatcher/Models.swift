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
    let gptRank: Int?
    let price: ModelPrice?
    let valueRank: Int?

    var blendedCostPerMillion: Double? { price?.blendedPerMillion }

    var valueScore: Double? {
        guard let combined, let cost = blendedCostPerMillion, cost > 0 else { return nil }
        return combined / cost
    }

    var isGPTFamily: Bool {
        let normalizedProvider = provider.lowercased()
        let normalizedName = name.lowercased()
        return normalizedProvider == "openai"
            || normalizedName == "gpt"
            || normalizedName.hasPrefix("gpt-")
            || normalizedName.hasPrefix("gpt")
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

struct DashboardSnapshot {
    let rows: [RankedModel]
    let fetchedAt: Date
    let sourceUpdatedAt: String?

    var top20: [RankedModel] {
        Array(rows.prefix(20))
    }

    var gptRows: [RankedModel] {
        rows.filter(\.isGPTFamily)
    }

    var bestCombined: RankedModel? {
        rows.first
    }

    var topValue: [RankedModel] {
        rows.compactMap { $0.valueRank == nil ? nil : $0 }
            .sorted { ($0.valueRank ?? .max) < ($1.valueRank ?? .max) }
    }

    var bestValue: RankedModel? {
        topValue.first
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
        let gptModels = sorted.filter {
            let provider = $0.provider.lowercased()
            let name = $0.name.lowercased()
            return provider == "openai"
                || name == "gpt"
                || name.hasPrefix("gpt-")
                || name.hasPrefix("gpt")
        }
        let gptRanks = Dictionary(
            uniqueKeysWithValues: gptModels.enumerated().map { ($0.element.id, $0.offset + 1) }
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
                gptRank: gptRanks[model.id],
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

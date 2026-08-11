import Foundation

struct ModelPrice: Hashable {
    let inputPerMillion: Double
    let outputPerMillion: Double

    /// Estimate for a 40% input / 60% output token mix.
    var blendedPerMillion: Double {
        inputPerMillion * 0.4 + outputPerMillion * 0.6
    }
}

enum ModelPriceCatalog {
    static let sourceURL = URL(string: "https://github.com/StudioPlatforms/aistupidmeter-web/blob/main/lib/model-pricing.ts")!

    /// USD list prices per 1M tokens. Unknown models deliberately have no price.
    static func price(for modelName: String, provider: String) -> ModelPrice? {
        let name = modelName.lowercased()
        switch provider.lowercased() {
        case "openai":
            if name.contains("gpt-5.6-terra") { return .init(inputPerMillion: 2, outputPerMillion: 12) }
            if name.contains("gpt-5.6-luna") { return .init(inputPerMillion: 0.20, outputPerMillion: 1.20) }
            if name.contains("gpt-5.6") || name.contains("gpt-5.5") { return .init(inputPerMillion: 5, outputPerMillion: 30) }
            if name.contains("gpt-5.4") { return .init(inputPerMillion: 2.5, outputPerMillion: 15) }
            if name.contains("gpt-5.3") { return .init(inputPerMillion: 1.75, outputPerMillion: 14) }
        case "anthropic":
            if name.contains("fable-5") { return .init(inputPerMillion: 10, outputPerMillion: 50) }
            if name.contains("opus") { return .init(inputPerMillion: 5, outputPerMillion: 25) }
            if name.contains("sonnet") { return .init(inputPerMillion: 3, outputPerMillion: 15) }
            if name.contains("haiku") { return .init(inputPerMillion: 0.25, outputPerMillion: 1.25) }
        case "google":
            if name.contains("3.1-flash-lite") { return .init(inputPerMillion: 0.25, outputPerMillion: 1.5) }
            if name.contains("3.1-flash") { return .init(inputPerMillion: 0.5, outputPerMillion: 3) }
            if name.contains("3.1-pro") { return .init(inputPerMillion: 2, outputPerMillion: 12) }
        case "deepseek":
            if name.contains("v4-pro") { return .init(inputPerMillion: 0.435, outputPerMillion: 0.87) }
            if name.contains("v4-flash") { return .init(inputPerMillion: 0.14, outputPerMillion: 0.28) }
        case "glm":
            if name.contains("5.2") || name.contains("5.1") { return .init(inputPerMillion: 1.4, outputPerMillion: 4.4) }
        case "kimi":
            if name.contains("k3") { return .init(inputPerMillion: 3, outputPerMillion: 15) }
            if name.contains("k2.7-code") { return .init(inputPerMillion: 0.95, outputPerMillion: 4) }
        default:
            break
        }
        return nil
    }
}

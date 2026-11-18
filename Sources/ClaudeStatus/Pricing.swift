import Foundation

/// Public Anthropic API list prices in USD per million tokens.
/// Used only for a local cost estimate. Subscription plans are not billed per token.
enum Pricing {
    struct Rate {
        let input: Double
        let output: Double
        /// Explicit cache-read price. When nil, cache reads cost 10% of input.
        let cacheRead: Double?
    }

    // Most specific keys first: matching uses `contains`.
    private static let table: [(String, Rate)] = [
        ("fable-5-2", Rate(input: 8, output: 40, cacheRead: 0.20)),
        ("mythos-5-2", Rate(input: 8, output: 40, cacheRead: 0.20)),
        ("fable-5-1", Rate(input: 10, output: 50, cacheRead: nil)),
        ("mythos-5-1", Rate(input: 10, output: 50, cacheRead: nil)),
        ("fable-5", Rate(input: 10, output: 50, cacheRead: nil)),
        ("mythos-5", Rate(input: 10, output: 50, cacheRead: nil)),
        ("opus-5-5", Rate(input: 4, output: 20, cacheRead: 0.20)),
        ("opus-5", Rate(input: 5, output: 25, cacheRead: nil)),
        ("opus-4-1", Rate(input: 15, output: 75, cacheRead: nil)),
        ("opus-4-2025", Rate(input: 15, output: 75, cacheRead: nil)),
        ("opus-4", Rate(input: 5, output: 25, cacheRead: nil)),
        ("sonnet-5-5", Rate(input: 2, output: 10, cacheRead: 0.10)),
        ("sonnet-5", Rate(input: 2, output: 10, cacheRead: nil)),
        ("sonnet", Rate(input: 3, output: 15, cacheRead: nil)),
        ("haiku-5-5", Rate(input: 0.10, output: 0.50, cacheRead: nil)),
        ("haiku-4-5", Rate(input: 1, output: 5, cacheRead: nil)),
        ("haiku", Rate(input: 0.80, output: 4, cacheRead: nil)),
    ]

    static func rate(for model: String) -> Rate? {
        let m = model.lowercased()
        return table.first { m.contains($0.0) }?.1
    }

    static func cost(_ e: UsageEntry) -> Double {
        guard let r = rate(for: e.model) else { return 0 }
        let read = r.cacheRead ?? r.input * 0.1
        let usd = Double(e.input) * r.input
            + Double(e.output) * r.output
            + Double(e.cacheWrite5m) * r.input * 1.25
            + Double(e.cacheWrite1h) * r.input * 2
            + Double(e.cacheRead) * read
        return usd / 1_000_000
    }
}

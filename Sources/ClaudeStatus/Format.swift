import Foundation

enum Fmt {
    static func compact(_ n: Int) -> String {
        let d = Double(n)
        switch n {
        case ..<1_000: return "\(n)"
        case ..<10_000: return String(format: "%.1fk", d / 1_000)
        case ..<1_000_000: return String(format: "%.0fk", d / 1_000)
        case ..<10_000_000: return String(format: "%.2fM", d / 1_000_000)
        default: return String(format: "%.1fM", d / 1_000_000)
        }
    }

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func full(_ n: Int) -> String { grouped.string(from: NSNumber(value: n)) ?? "\(n)" }

    static func cost(_ usd: Double) -> String {
        if usd <= 0 { return "$0" }
        if usd < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", usd)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return L("%dh %dm", h, m) }
        if m > 0 { return L("%dm", m) }
        return L("<1m")
    }

    /// Countdown as hh:mm, e.g. "03:19".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 10 { return L("just now") }
        if s < 60 { return L("%ds ago", s) }
        if s < 3600 { return L("%dm ago", s / 60) }
        if s < 86_400 { return L("%dh ago", s / 3600) }
        return L("%dd ago", s / 86_400)
    }

    static func percent(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f%%", v * 100)
    }
}

enum ModelName {
    /// "claude-opus-5-5" → ("Opus", "5.5")
    static func parse(_ id: String) -> (family: String, version: String) {
        var parts = id.lowercased().split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        parts.removeAll { $0.count >= 8 && $0.allSatisfy(\.isNumber) } // date suffix
        guard let first = parts.first else { return (id, "") }
        if first.allSatisfy(\.isNumber) {
            // Older ids: claude-3-5-sonnet
            let family = parts.last(where: { !$0.allSatisfy(\.isNumber) }) ?? first
            let version = parts.filter { $0.allSatisfy(\.isNumber) }.joined(separator: ".")
            return (family.capitalized, version)
        }
        return (first.capitalized, parts.dropFirst().joined(separator: "."))
    }

    static func pretty(_ id: String) -> String {
        let p = parse(id)
        return p.version.isEmpty ? p.family : "\(p.family) \(p.version)"
    }

    static func short(_ id: String) -> String { parse(id).family.uppercased() }
}


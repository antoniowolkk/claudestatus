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
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 10 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3600)h ago" }
        return "\(s / 86_400)d ago"
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

enum Surface {
    static func name(_ entrypoint: String) -> String {
        switch entrypoint {
        case "": return "—"
        case "cli": return "CLI"
        case "claude-desktop": return "Desktop app"
        case "claude-vscode": return "VS Code"
        case let s where s.contains("jetbrains"): return "JetBrains"
        case let s where s.hasPrefix("sdk"): return "Agent SDK"
        case let s where s.contains("web") || s.contains("remote") || s.contains("cloud"): return "Cloud"
        default: return entrypoint
        }
    }

    static func icon(_ entrypoint: String) -> String {
        switch name(entrypoint) {
        case "CLI": return "terminal"
        case "Desktop app": return "macwindow"
        case "VS Code", "JetBrains": return "chevron.left.forwardslash.chevron.right"
        case "Agent SDK": return "shippingbox"
        case "Cloud": return "cloud"
        default: return "questionmark.circle"
        }
    }
}

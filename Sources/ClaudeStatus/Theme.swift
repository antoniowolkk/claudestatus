import SwiftUI
import AppKit

/// Hacker-terminal palette: neon cyan on near-black (dark), teal on paper (light).
/// Light by default; dark when the user turns on Dark mode.
/// Every color adapts to the appearance of the view it's drawn in.
enum Theme {
    static let bg = adaptive(light: (0.94, 0.955, 0.95), dark: (0.035, 0.045, 0.05))
    static let card = adaptive(light: (0.975, 0.985, 0.98), dark: (0.05, 0.068, 0.075))
    static let ink = adaptive(light: (0.04, 0.10, 0.11), dark: (0.84, 0.98, 0.96))
    static let sub = adaptive(light: (0.26, 0.38, 0.39), dark: (0.50, 0.68, 0.66))
    static let faint = adaptive(light: (0.48, 0.57, 0.58), dark: (0.30, 0.42, 0.41))
    static let line = adaptive(light: (0.70, 0.79, 0.79), dark: (0.11, 0.24, 0.24))
    static let hair = adaptive(light: (0.0, 0.30, 0.30), dark: (0.0, 0.90, 0.83), lightAlpha: 0.10, darkAlpha: 0.12)
    static let scan = adaptive(light: (0.0, 0.0, 0.0), dark: (0.0, 1.0, 0.9), lightAlpha: 0.025, darkAlpha: 0.035)

    static let accent = adaptive(light: (0.0, 0.50, 0.50), dark: (0.0, 0.92, 0.84))
    static let violet = adaptive(light: (0.68, 0.10, 0.58), dark: (1.0, 0.27, 0.86))
    static let amber = adaptive(light: (0.70, 0.50, 0.0), dark: (1.0, 0.84, 0.16))
    static let danger = adaptive(light: (0.82, 0.06, 0.32), dark: (1.0, 0.24, 0.45))
    static let live = adaptive(light: (0.02, 0.56, 0.28), dark: (0.36, 1.0, 0.55))

    private typealias RGB = (Double, Double, Double)

    private static func adaptive(light: RGB, dark: RGB, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

/// Faint horizontal scanlines, like an old monitor.
struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y: CGFloat = 0
            while y < size.height {
                p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                y += 3
            }
            ctx.fill(p, with: .color(Theme.scan))
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// App background: theme color plus scanlines.
    func hackerBackground() -> some View {
        background(Theme.bg).overlay(Scanlines())
    }
}

/// HUD box: sharp 1px border, a `// TITLE` label set into the top edge, an optional
/// `[TAG]` on the right, and accent corner ticks.
struct HUDCard<Content: View>: View {
    var title: String? = nil
    var tag: String? = nil
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        let hasHeader = title != nil || tag != nil
        content
            .padding(padding)
            .padding(.top, hasHeader ? 4 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
            .overlay(CornerTicks().stroke(Theme.accent, lineWidth: 1.5))
            .overlay(alignment: .topLeading) {
                if let title {
                    Text("// " + title)
                        .font(Theme.label(9))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 3)
                        .background(Theme.bg)
                        .offset(x: 12, y: -7)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let tag {
                    Text("[" + tag + "]")
                        .font(Theme.label(8))
                        .foregroundStyle(Theme.faint)
                        .padding(.horizontal, 3)
                        .background(Theme.bg)
                        .offset(x: -12, y: -6)
                }
            }
            .padding(.top, hasHeader ? 7 : 0)
    }
}

/// Short accent marks at the top-left and bottom-right corners.
struct CornerTicks: Shape {
    var length: CGFloat = 7
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + length)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + length, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - length, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - length))
        return p
    }
}

/// Text progress bar: `▓▓▓▓▓▓░░░░░░`.
struct AsciiBar: View {
    var progress: Double
    var cells = 26
    var tint: Color? = nil
    var fontSize: CGFloat = 11
    var body: some View {
        let p = max(0, min(progress, 1))
        let filled = Int((p * Double(cells)).rounded())
        return (Text(String(repeating: "▓", count: filled)).foregroundColor(tint ?? (p >= 0.9 ? Theme.danger : Theme.accent))
            + Text(String(repeating: "░", count: cells - filled)).foregroundColor(Theme.line))
            .font(Theme.mono(fontSize))
            .lineLimit(1)
            .fixedSize()
    }
}

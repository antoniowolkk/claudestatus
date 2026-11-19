import SwiftUI
import AppKit

/// Surveillance-HUD palette: white on near-black with a sky-blue accent (dark),
/// near-black on pale gray with a deeper blue accent (light).
/// Light by default; dark when the user turns on Dark mode.
/// Every color adapts to the appearance of the view it's drawn in.
enum Theme {
    static let bg = adaptive(light: (0.925, 0.937, 0.945), dark: (0.035, 0.039, 0.045))
    static let card = adaptive(light: (0.975, 0.98, 0.985), dark: (0.075, 0.082, 0.092))
    static let ink = adaptive(light: (0.04, 0.05, 0.06), dark: (0.95, 0.96, 0.965))
    static let sub = adaptive(light: (0.30, 0.34, 0.38), dark: (0.66, 0.70, 0.73))
    static let faint = adaptive(light: (0.50, 0.54, 0.58), dark: (0.42, 0.46, 0.50))
    static let line = adaptive(light: (0.0, 0.0, 0.0), dark: (1.0, 1.0, 1.0), lightAlpha: 0.14, darkAlpha: 0.13)
    static let hair = adaptive(light: (0.0, 0.0, 0.0), dark: (1.0, 1.0, 1.0), lightAlpha: 0.06, darkAlpha: 0.06)
    static let dots = adaptive(light: (0.0, 0.0, 0.0), dark: (1.0, 1.0, 1.0), lightAlpha: 0.05, darkAlpha: 0.045)

    /// Highlight bar: white with black text in dark mode, black with white text in light mode.
    static let barFill = adaptive(light: (0.06, 0.07, 0.08), dark: (0.96, 0.97, 0.975))
    static let barInk = adaptive(light: (0.97, 0.98, 0.985), dark: (0.03, 0.035, 0.04))

    static let accent = adaptive(light: (0.06, 0.52, 0.80), dark: (0.33, 0.74, 0.95))
    static let violet = adaptive(light: (0.70, 0.12, 0.55), dark: (0.98, 0.40, 0.80))
    static let amber = adaptive(light: (0.80, 0.50, 0.0), dark: (1.0, 0.70, 0.16))
    static let danger = adaptive(light: (0.82, 0.14, 0.16), dark: (1.0, 0.33, 0.33))
    static let live = adaptive(light: (0.05, 0.58, 0.30), dark: (0.36, 0.90, 0.52))

    private typealias RGB = (Double, Double, Double)

    private static func adaptive(light: RGB, dark: RGB, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    /// Numbers, commands, IDs.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Body text and names.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Small uppercase labels and tags.
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold)
    }
}

/// Fine dot texture behind panels.
struct DotTexture: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y: CGFloat = 1
            while y < size.height {
                var x: CGFloat = (Int(y) / 4) % 2 == 0 ? 1 : 3
                while x < size.width {
                    p.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                    x += 4
                }
                y += 4
            }
            ctx.fill(p, with: .color(Theme.dots))
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// App background: theme color plus dot texture.
    func hackerBackground() -> some View {
        background(Theme.bg).overlay(DotTexture())
    }
}

/// HUD panel: a title tab with an accent edge on top, a dark body with a hairline border,
/// white corner ticks, and an optional tag on the right.
struct HUDCard<Content: View>: View {
    var title: String? = nil
    var tag: String? = nil
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || tag != nil {
                HStack(spacing: 7) {
                    Rectangle().fill(Theme.accent).frame(width: 3, height: 12)
                    if let title {
                        Text(title)
                            .font(Theme.label(10))
                            .tracking(0.6)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let tag {
                        Text(tag)
                            .font(Theme.mono(8, .medium))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .padding(.bottom, 6)
            }
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                .overlay(CornerTicks().stroke(Theme.ink.opacity(0.85), lineWidth: 1.5))
        }
    }
}

/// Short marks at the top-left and bottom-right corners.
struct CornerTicks: Shape {
    var length: CGFloat = 7
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + length)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + length, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - length, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - length))
        return p
    }
}

/// Segmented meter: a row of small blocks, filled in the accent color.
struct AsciiBar: View {
    var progress: Double
    var cells = 26
    var tint: Color? = nil
    var fontSize: CGFloat = 11
    var body: some View {
        let p = max(0, min(progress, 1))
        let filled = Int((p * Double(cells)).rounded())
        let color = tint ?? (p >= 0.9 ? Theme.danger : Theme.accent)
        let h = fontSize * 0.75
        return HStack(spacing: 2) {
            ForEach(0..<cells, id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? color : Theme.line)
                    .frame(width: max(3, h * 0.42), height: h)
            }
        }
        .fixedSize()
    }
}

/// Hexagon marker: ⬡ outline, or filled when active.
struct HexMark: View {
    var color: Color
    var filled = false
    var size: CGFloat = 10
    var body: some View {
        Text(filled ? "⬢" : "⬡")
            .font(.system(size: size))
            .foregroundStyle(color)
    }
}

/// White (or black in light mode) label bar with dark text: the "key fact" row.
struct HighlightBar: View {
    var text: String
    var body: some View {
        Text(text)
            .font(Theme.sans(11, .semibold))
            .foregroundStyle(Theme.barInk)
            .lineLimit(1).truncationMode(.tail)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.barFill)
    }
}

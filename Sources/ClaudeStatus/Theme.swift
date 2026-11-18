import SwiftUI
import AppKit

/// Clean, slightly sci-fi palette. Light by default; dark when the user turns on Dark mode.
/// Every color adapts to the appearance of the view it's drawn in.
enum Theme {
    static let bg = adaptive(light: (0.975, 0.98, 0.99), dark: (0.045, 0.06, 0.09))
    static let card = adaptive(light: (1, 1, 1), dark: (0.075, 0.095, 0.14))
    static let ink = adaptive(light: (0.08, 0.10, 0.14), dark: (0.90, 0.93, 0.97))
    static let sub = adaptive(light: (0.38, 0.42, 0.50), dark: (0.60, 0.65, 0.74))
    static let faint = adaptive(light: (0.60, 0.64, 0.70), dark: (0.40, 0.45, 0.54))
    static let hair = adaptive(light: (0.08, 0.12, 0.22), dark: (0.55, 0.70, 1.0), lightAlpha: 0.09, darkAlpha: 0.12)

    static let accent = adaptive(light: (0.05, 0.45, 0.95), dark: (0.25, 0.60, 1.0))
    static let cyan = Color(red: 0.00, green: 0.76, blue: 0.86)
    static let violet = adaptive(light: (0.45, 0.36, 0.95), dark: (0.60, 0.52, 1.0))
    static let amber = Color(red: 0.88, green: 0.56, blue: 0.05)
    static let danger = adaptive(light: (0.90, 0.22, 0.30), dark: (1.0, 0.40, 0.45))
    static let live = adaptive(light: (0.10, 0.75, 0.45), dark: (0.20, 0.85, 0.55))

    private typealias RGB = (Double, Double, Double)

    private static func adaptive(light: RGB, dark: RGB, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    static let ring = AngularGradient(
        colors: [cyan, accent, violet, cyan],
        center: .center
    )

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}


/// HUD-style corner brackets.
struct CornerBrackets: Shape {
    var length: CGFloat = 8
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = length
        p.move(to: .init(x: r.minX, y: r.minY + l)); p.addLine(to: .init(x: r.minX, y: r.minY)); p.addLine(to: .init(x: r.minX + l, y: r.minY))
        p.move(to: .init(x: r.maxX - l, y: r.minY)); p.addLine(to: .init(x: r.maxX, y: r.minY)); p.addLine(to: .init(x: r.maxX, y: r.minY + l))
        p.move(to: .init(x: r.maxX, y: r.maxY - l)); p.addLine(to: .init(x: r.maxX, y: r.maxY)); p.addLine(to: .init(x: r.maxX - l, y: r.maxY))
        p.move(to: .init(x: r.minX + l, y: r.maxY)); p.addLine(to: .init(x: r.minX, y: r.maxY)); p.addLine(to: .init(x: r.minX, y: r.maxY - l))
        return p
    }
}

struct HUDCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.hair, lineWidth: 0.5))
            .overlay(CornerBrackets().stroke(Theme.accent.opacity(0.55), lineWidth: 1.2).padding(3))
            .shadow(color: Theme.accent.opacity(0.06), radius: 10, y: 3)
    }
}

struct RingGauge: View {
    var progress: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { i in
                Rectangle()
                    .fill(Theme.hair)
                    .frame(width: 1, height: i % 4 == 0 ? 5 : 3)
                    .offset(y: -(lineWidth + 34))
                    .rotationEffect(.degrees(Double(i) / 48 * 360))
            }
            Circle().stroke(Theme.hair, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, min(progress, 1)))
                .stroke(Theme.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.cyan.opacity(0.35), radius: 4)
        }
    }
}



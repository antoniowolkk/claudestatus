import SwiftUI

/// Light, clean, slightly sci-fi palette. The app always renders in light mode.
enum Theme {
    static let bg = Color(red: 0.975, green: 0.98, blue: 0.99)
    static let card = Color.white
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let sub = Color(red: 0.38, green: 0.42, blue: 0.50)
    static let faint = Color(red: 0.60, green: 0.64, blue: 0.70)
    static let hair = Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.09)
    static let grid = Color(red: 0.10, green: 0.40, blue: 0.80).opacity(0.045)

    static let accent = Color(red: 0.05, green: 0.45, blue: 0.95)
    static let cyan = Color(red: 0.00, green: 0.76, blue: 0.86)
    static let violet = Color(red: 0.45, green: 0.36, blue: 0.95)
    static let amber = Color(red: 0.88, green: 0.56, blue: 0.05)
    static let danger = Color(red: 0.90, green: 0.22, blue: 0.30)
    static let live = Color(red: 0.10, green: 0.75, blue: 0.45)

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

/// Faint blueprint grid behind panels.
struct GridBackground: View {
    var spacing: CGFloat = 14
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += spacing }
            ctx.stroke(path, with: .color(Theme.grid), lineWidth: 0.5)
        }
        .background(Theme.bg)
        .allowsHitTesting(false)
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



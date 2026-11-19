import SwiftUI

/// What Wolkky feels, from what Claude is doing.
enum WolkkyMood: Equatable {
    case idle, running, done, worried, sleeping

    /// Wolkky's line next to the art when nothing else is said.
    var line: String {
        switch self {
        case .idle: return L("watching your tokens")
        case .running: return L("on it…")
        case .done: return L("done!")
        case .worried: return L("slow down, budget!")
        case .sleeping: return L("zZ… wake me up")
        }
    }
}

extension UsageStore {
    func wolkkyMood(now: Date) -> WolkkyMood {
        let snap = snapshot
        let budget = UserDefaults.standard.integer(forKey: Prefs.tokenBudget)
        if budget > 0, let b = snap.block, b.isActive,
           Double(b.totals.tokens(includeCacheReads: includeCacheReads)) / Double(budget) >= 0.8 {
            return .worried
        }
        if snap.projects.contains(where: { $0.activities.contains { $0.isRunning(now: now) } }) { return .running }
        if snap.turnEnds.contains(where: { now.timeIntervalSince($0.end) < 120 }) { return .done }
        guard let last = snap.context?.lastActivity, now.timeIntervalSince(last) < 1800 else { return .sleeping }
        return .idle
    }
}

/// True for the off-screen copy of the panel used only to measure its height.
private struct MeasuringKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isMeasuring: Bool {
        get { self[MeasuringKey.self] }
        set { self[MeasuringKey.self] = newValue }
    }
}

/// Wolkky drawn in text. Blinks, glances around, reacts to Claude, wiggles on hover
/// and jumps when clicked. Always the same size, so it never changes the layout.
struct WolkkyASCII: View {
    var animated: Bool
    var fontSize: CGFloat = 10
    var showsLine = true

    @EnvironmentObject var store: UsageStore
    @Environment(\.isMeasuring) private var measuring
    @State private var hovering = false
    @State private var jumpAt: Date?
    @State private var speech: String?
    @State private var speechUntil = Date.distantPast

    /// Neon outline, bright face, violet extras (zZ, sweat, sparkle, dots).
    private static func colored(_ line: String, face: Set<Character>) -> Text {
        let body = String(line.prefix(22)), extra = String(line.dropFirst(22))
        var t = Text("")
        for c in body {
            t = t + Text(String(c)).foregroundColor(face.contains(c) ? Theme.ink : Theme.accent)
        }
        return t + Text(extra).foregroundColor(Theme.violet)
    }

    private static let chatter = ["hi!", "beep boop", "tokens go brrr", "ship it!", "need coffee?", "I'm Wolkky ☁", "*poke*", "pssst: wolkk.com"]

    var body: some View {
        if animated && !measuring {
            TimelineView(.periodic(from: .now, by: 0.18)) { tl in frame(tl.date) }
        } else {
            frame(Date())
        }
    }

    private func frame(_ now: Date) -> some View {
        let mood = store.wolkkyMood(now: now)
        let t = now.timeIntervalSinceReferenceDate
        let live = animated && !measuring
        let tick = live ? Int(t / 0.36) : 0

        // Eyes
        let blink = live && t.truncatingRemainder(dividingBy: 4.3) < 0.2
        var eye = "•"
        switch mood {
        case .done: eye = "^"
        case .sleeping: eye = "-"
        case .worried: eye = "°"
        default: break
        }
        if blink { eye = "-" }
        let jumping = jumpAt.map { now.timeIntervalSince($0) < 0.5 } ?? false
        if jumping { eye = "^" }

        // Glance left / right now and then (not while sleeping)
        let phase = live ? Int(t / 2.4) % 7 : 0
        let eyes: String
        if mood != .sleeping && phase == 2 { eyes = "   \(eye)      \(eye)     " }
        else if mood != .sleeping && phase == 5 { eyes = "     \(eye)      \(eye)   " }
        else { eyes = "    \(eye)      \(eye)    " }

        // Mouth
        var mouth = "‿"
        switch mood {
        case .done: mouth = "◡"
        case .worried: mouth = "~"
        case .sleeping: mouth = "."
        default: break
        }
        if jumping { mouth = "o" }

        // Little extras to the right of the head
        var extra = ["   ", "   ", "   ", "   ", "   "]
        switch mood {
        case .sleeping: extra[0] = tick % 2 == 0 ? " zZ" : " Zz"
        case .worried: extra[2] = tick % 2 == 0 ? " ' " : "  '"
        case .running: extra[3] = " " + String(repeating: ".", count: tick % 4).padding(toLength: 2, withPad: " ", startingAt: 0)
        case .done: extra[1] = tick % 2 == 0 ? " * " : " + "
        case .idle: break
        }

        let art = [
            "      .--.   .-.      " + extra[0],
            "   .-(    `-'   )-.   " + extra[1],
            "  (" + eyes + ")  " + extra[2],
            "   `-.    " + mouth + "     .-'   " + extra[3],
            "      `---------'     " + extra[4],
        ]
        let face: Set<Character> = [Character(eye), Character(mouth)]

        // Motion: jump on click, wiggle while hovered
        let jumpY: CGFloat = jumpAt.map { start in
            let p = now.timeIntervalSince(start) / 0.5
            return p < 1 ? -CGFloat(sin(p * .pi)) * 5 : 0
        } ?? 0
        let wiggleX: CGFloat = hovering && live ? (tick % 2 == 0 ? -1.5 : 1.5) : 0
        let said = now < speechUntil ? speech : nil

        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<art.count, id: \.self) { i in
                    Self.colored(art[i], face: (i == 2 || i == 3) ? face : [])
                }
            }
            .font(Theme.mono(fontSize, .medium))
            .fixedSize()
            .offset(x: wiggleX, y: jumpY)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture {
                jumpAt = Date()
                speech = Self.chatter.randomElement()
                speechUntil = Date().addingTimeInterval(2.5)
            }
            .help("Wolkky")

            if showsLine {
                // Objective-style chip: hexagon icon + line
                HStack(spacing: 6) {
                    HexMark(color: said != nil ? Theme.violet : Theme.ink, size: 11)
                    Text(said ?? mood.line)
                        .font(Theme.sans(11, .medium))
                        .foregroundStyle(said != nil ? Theme.violet : Theme.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.card)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink.opacity(0.6)).frame(height: 1) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wolkky: " + mood.line)
    }
}

/// Text that briefly scrambles (glitches) when `trigger` changes, and optionally now and then.
struct GlitchText: View {
    let text: String
    var trigger: AnyHashable = 0
    var auto = false

    @EnvironmentObject var store: UsageStore
    @Environment(\.isMeasuring) private var measuring
    @State private var frame = 0

    private static let noise = Array("#%&$@!/\\|<>*+=01░▒▓")

    var body: some View {
        Text(frame == 0 ? text : Self.scramble(text, frame: frame))
            .onChange(of: trigger) { run() }
            .task(id: auto) {
                guard auto, !measuring else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 7...13)))
                    if store.panelVisible { run() }
                }
            }
    }

    private func run() {
        guard !measuring else { return }
        Task { @MainActor in
            for f in 1...4 {
                frame = f
                try? await Task.sleep(for: .milliseconds(70))
            }
            frame = 0
        }
    }

    /// Same length as the original, so the layout never moves.
    static func scramble(_ s: String, frame: Int) -> String {
        var rng = SystemRandomNumberGenerator()
        return String(s.map { c in
            c == " " || Int.random(in: 0..<10, using: &rng) > 3 ? c : noise.randomElement(using: &rng)!
        })
    }
}

/// Text that types itself in the first time a given id is shown.
struct TypewriterText: View {
    let text: String
    let id: String

    @EnvironmentObject var store: UsageStore
    @Environment(\.isMeasuring) private var measuring
    @State private var shown: Int?

    var body: some View {
        Text(shown.map { String(text.prefix($0)) + ($0 < text.count ? "▌" : "") } ?? text)
            .onAppear {
                guard !measuring, store.panelVisible, !store.typed.contains(id) else { return }
                store.typed.insert(id)
                let n = text.count
                guard n > 0 else { return }
                shown = 0
                Task { @MainActor in
                    let step = max(1, n / 24)
                    var i = 0
                    while i < n {
                        i = min(n, i + step)
                        shown = i
                        try? await Task.sleep(for: .milliseconds(18))
                    }
                    shown = nil
                }
            }
    }
}

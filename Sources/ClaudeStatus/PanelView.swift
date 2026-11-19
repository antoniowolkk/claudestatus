import SwiftUI
import AppKit

/// The menu bar panel, in a terminal / ASCII style.
struct PanelView: View {
    static let width: CGFloat = 360
    /// wolkk.com with campaign tags, so Wolkk can see visits that came from the app.
    /// The tags only name the app and the button; nothing about you is added.
    static func wolkkURL(_ path: String = "", from placement: String) -> URL {
        var c = URLComponents(string: "https://wolkk.com/" + path)!
        c.queryItems = [
            URLQueryItem(name: "utm_source", value: "wolkky-claude-status"),
            URLQueryItem(name: "utm_medium", value: "app"),
            URLQueryItem(name: "utm_content", value: placement),
        ]
        return c.url!
    }

    @EnvironmentObject var store: UsageStore
    @AppStorage(Prefs.tokenBudget) private var budget = 0
    @AppStorage(Prefs.includeCacheReads) private var includeCacheReads = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { tl in
            content(now: tl.date)
        }
        .frame(width: Self.width)
        .hackerBackground()
        .appAppearance()
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let snap = store.snapshot
        VStack(alignment: .leading, spacing: 12) {
            header(snap, now: now)
            if let err = snap.error {
                messageBox(title: L("Logs not found"), body: err.message + " " + L("Run a Claude Code session, then refresh."))
            } else if snap.context == nil {
                messageBox(title: snap.updatedAt == nil ? L("Scanning logs") : L("No recent activity"),
                           body: L("Usage shows up here after your next Claude Code message."))
            } else {
                window(snap, now: now)
                stats(snap)
                if !snap.projects.isEmpty { projects(snap, now: now) }
            }
            footer(snap, now: now)
        }
        .padding(14)
    }

    // MARK: Header

    private func header(_ snap: UsageSnapshot, now: Date) -> some View {
        let last = snap.context?.lastActivity
        let live = last.map { now.timeIntervalSince($0) < 120 } ?? false
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                GlitchText(text: "WOLKKY // CLAUDE STATUS", trigger: snap.updatedAt, auto: true)
                    .font(Theme.label(10))
                    .tracking(1.6)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(live ? "● LINK " + L("LIVE") : (last.map { "○ " + L("IDLE · %@", Fmt.ago($0, now: now)) } ?? "○ " + L("IDLE")))
                    .font(Theme.label(9))
                    .foregroundStyle(live ? Theme.live : Theme.faint)
                    .lineLimit(1)
            }
            WolkkyASCII(animated: store.panelVisible)
        }
    }

    // MARK: 5-hour window

    private func window(_ snap: UsageSnapshot, now: Date) -> some View {
        let block = snap.block.flatMap { $0.isActive ? $0 : nil }
        let tokens = block?.totals.tokens(includeCacheReads: includeCacheReads) ?? 0
        let progress: Double
        let right: String
        if budget > 0 {
            progress = Double(tokens) / Double(budget)
            right = Fmt.percent(progress)
        } else if let b = block {
            progress = now.timeIntervalSince(b.start) / SnapshotBuilder.blockLength
            right = Fmt.percent(progress)
        } else {
            progress = 0
            right = "—"
        }

        return HUDCard(title: L("5-HOUR WINDOW"), tag: "SYS.USAGE", padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.full(tokens))
                        .font(Theme.mono(24, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(includeCacheReads ? L("tokens incl. cache reads") : L("tokens"))
                        .font(Theme.mono(11)).foregroundStyle(Theme.sub)
                    Spacer(minLength: 4)
                    if let b = block {
                        Text("≈" + Fmt.cost(b.totals.cost)).font(Theme.mono(11)).foregroundStyle(Theme.sub)
                    }
                }
                HStack(spacing: 8) {
                    AsciiBar(progress: progress)
                    Text(right).font(Theme.mono(11, .medium)).foregroundStyle(Theme.ink)
                }
                Group {
                    if let b = block {
                        Text(">> T-" + Fmt.clock(b.end.timeIntervalSince(now)) + " · " + L("resets %@", b.end.formatted(date: .omitted, time: .shortened)))
                    } else {
                        Text(">> " + L("Starts with your next message"))
                    }
                }
                .font(Theme.mono(10))
                .foregroundStyle(Theme.faint)
                if let b = block {
                    let f = Forecast(tokens: tokens, block: b, budget: budget, now: now)
                    Text(">> " + f.text).font(Theme.mono(10)).foregroundStyle(f.warning ? Theme.danger : Theme.sub)
                }
            }
        }
    }

    // MARK: Stats

    private func stats(_ snap: UsageSnapshot) -> some View {
        HUDCard(tag: "SYS.STATS", padding: 0) {
            HStack(spacing: 0) {
                stat(L("SESSION"), Fmt.compact(snap.session.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.session.cost))
                divider
                stat(L("TODAY"), Fmt.compact(snap.today.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.today.cost))
                divider
                stat(L("7 DAYS"), Fmt.compact(snap.week.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.week.cost))
                divider
                stat(L("CACHE"), Fmt.percent(snap.today.cacheHitRate), L("hit today"))
            }
            // Dividers would otherwise stretch to any height offered when measuring the panel.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: 1) }

    private func stat(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.label(8)).foregroundStyle(Theme.faint).lineLimit(1)
            Text(value).font(Theme.mono(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Projects (accordion)

    private static let maxProjects = 6

    private func projects(_ snap: UsageSnapshot, now: Date) -> some View {
        let shown = Array(snap.projects.prefix(Self.maxProjects))
        let hidden = snap.projects.count - shown.count
        let current = snap.context.map { ProjectPath.root($0.cwd) }
        return HUDCard(title: L("ACTIVE PROJECTS") + " · " + L("LAST 24H"), tag: "NODES:\(snap.projects.count)", padding: 6) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, p in
                    if i > 0 { dashedRule }
                    projectRow(p, isCurrent: current.map { $0 == p.root || $0.hasPrefix(p.root + "/") } ?? false, now: now)
                }
                if hidden > 0 {
                    Text(L("+%d more", hidden))
                        .font(Theme.mono(10)).foregroundStyle(Theme.faint)
                        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
                }
            }
        }
    }

    private var dashedRule: some View {
        Line()
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.horizontal, 6)
    }

    private func projectRow(_ p: ProjectActivity, isCurrent: Bool, now: Date) -> some View {
        let open = store.expanded.contains(p.root)
        let age = now.timeIntervalSince(p.lastActivity)
        let running = p.activities.contains { $0.isRunning(now: now) }
        let state: (String, Color) = running ? (L("RUN"), Theme.live)
            : age < 120 ? (L("LIVE"), Theme.live)
            : age < 1800 ? (L("ACTIVE"), Theme.accent)
            : (Fmt.ago(p.lastActivity, now: now), Theme.faint)
        var detail = Self.branchText(p.branch)
        if p.worktrees > 0 { detail += " · " + L(p.worktrees == 1 ? "%d worktree" : "%d worktrees", p.worktrees) }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                store.toggleExpanded(p.root)
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Text(open ? "▾" : "▸")
                        .font(Theme.mono(11)).foregroundStyle(Theme.accent)
                        .frame(width: 10, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text((isCurrent ? "> " : "") + p.name)
                                .font(Theme.mono(12, isCurrent ? .semibold : .regular))
                                .foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.middle)
                            Text(Self.hexID(p.root))
                                .font(Theme.mono(8)).foregroundStyle(Theme.faint)
                        }
                        Text(detail)
                            .font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Fmt.compact(p.totals.tokens(includeCacheReads: includeCacheReads)))
                            .font(Theme.mono(12)).foregroundStyle(Theme.ink)
                        Text("[" + state.0 + "]")
                            .font(Theme.label(8)).foregroundStyle(state.1)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
                .background(isCurrent ? Theme.accent.opacity(0.07) : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(p.root)

            if open { activityList(p, now: now) }
        }
    }

    private func activityList(_ p: ProjectActivity, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if p.contextLimit > 0 {
                let used = Double(p.contextTokens) / Double(p.contextLimit)
                let tint = used >= 0.8 ? Theme.danger : used >= 0.6 ? Theme.amber : Theme.accent
                HStack(spacing: 6) {
                    Text(L("context")).foregroundStyle(Theme.faint)
                    AsciiBar(progress: used, cells: 14, tint: tint, fontSize: 10)
                    Text(Fmt.percent(used)).foregroundStyle(tint)
                    Text(Fmt.compact(p.contextTokens) + "/" + Fmt.compact(p.contextLimit)).foregroundStyle(Theme.faint)
                }
                .font(Theme.mono(10))
                .help(used >= 0.8 ? L("Context almost full. Consider /compact.") : L("Context window use of the latest session."))
                .padding(.bottom, 3)
            }
            if p.activities.isEmpty {
                Text("└ " + L("No commands in the last 24 hours"))
                    .font(Theme.mono(10)).foregroundStyle(Theme.faint)
            }
            ForEach(Array(p.activities.enumerated()), id: \.element.id) { i, a in
                let last = i == p.activities.count - 1
                let status: (String, Color) = a.isRunning(now: now) ? (L("run"), Theme.live)
                    : a.status == .failed ? (L("err"), Theme.danger)
                    : a.status == .running ? (L("stop"), Theme.faint)
                    : (L("ok"), Theme.faint)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(last ? "└" : "├").foregroundStyle(Theme.line)
                    Text(a.tool).foregroundStyle(Theme.accent)
                    TypewriterText(text: a.detail.isEmpty ? "—" : a.detail, id: a.id)
                        .foregroundStyle(a.isRunning(now: now) ? Theme.ink : Theme.sub)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(status.0).foregroundStyle(status.1)
                    Text(Fmt.ago(a.time, now: now)).foregroundStyle(Theme.faint)
                }
                .font(Theme.mono(10))
                .help(a.detail)
            }
        }
        .padding(.leading, 22).padding(.trailing, 6).padding(.bottom, 8)
    }

    /// Short stable hex tag for a project, purely decorative: `#A3F1`.
    static func hexID(_ s: String) -> String {
        var h: UInt32 = 2166136261
        for b in s.utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return "#" + String(format: "%04X", h & 0xFFFF)
    }

    private static func branchText(_ branch: String) -> String {
        branch.isEmpty || branch == "HEAD" ? L("no branch") : branch
    }

    // MARK: Messages + footer

    private func messageBox(title: String, body: String) -> some View {
        HUDCard(title: title, padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("> " + body)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                AsciiButton(label: L("Open setup")) { WindowManager.shared.showOnboarding() }
            }
        }
    }

    private func footer(_ snap: UsageSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AsciiButton(label: L("refresh")) { Task { await store.refresh() } }
                AsciiButton(label: L("settings")) { WindowManager.shared.showSettings() }
                Spacer()
                AsciiButton(label: L("quit")) { NSApp.terminate(nil) }
            }
            HStack(spacing: 0) {
                Text(L("powered by") + " ").foregroundStyle(Theme.faint)
                Button {
                    NSWorkspace.shared.open(Self.wolkkURL(from: "panel-footer"))
                } label: {
                    Text("Wolkk").underline().foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                .help("wolkk.com")
                Spacer()
                Text(snap.updatedAt.map { L("SYNC %@", Fmt.ago($0, now: now).uppercased()) } ?? L("SYNCING"))
                    .foregroundStyle(Theme.faint)
            }
            .font(Theme.label(9))
        }
    }
}

/// Horizontal line shape (used dashed).
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Terminal-style text button: `[ refresh ]`.
struct AsciiButton: View {
    var label: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text("[ " + label + " ]")
                .font(Theme.label(10))
                .foregroundStyle(hover ? Theme.bg : Theme.accent)
                .padding(.vertical, 2)
                .background(hover ? Theme.accent : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(label)
    }
}

/// Where the current 5-hour window is heading at the current pace.
struct Forecast {
    let text: String
    let warning: Bool

    init(tokens: Int, block: BlockInfo, budget: Int, now: Date) {
        let elapsed = now.timeIntervalSince(block.start)
        let remaining = max(0, block.end.timeIntervalSince(now))
        guard elapsed >= 600, tokens > 0 else {
            text = L("measuring pace…"); warning = false; return
        }
        let perSecond = Double(tokens) / elapsed
        let projected = Int(Double(tokens) + perSecond * remaining)
        let pace = Fmt.compact(Int(perSecond * 60))
        guard budget > 0 else {
            text = L("pace %@/min · ≈%@ by reset", pace, Fmt.compact(projected)); warning = false; return
        }
        if tokens >= budget {
            text = L("over budget"); warning = true
        } else if projected >= budget {
            let hit = now.addingTimeInterval(Double(budget - tokens) / perSecond)
            text = L("at this pace: limit ≈ %@", hit.formatted(date: .omitted, time: .shortened)); warning = true
        } else {
            text = L("on pace for %@ by reset", Fmt.percent(Double(projected) / Double(budget))); warning = false
        }
    }
}

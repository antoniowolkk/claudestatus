import SwiftUI
import AppKit

/// The menu bar panel, styled as a surveillance HUD.
struct PanelView: View {
    static let width: CGFloat = 540

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
                // 5-hour window on the left, 2×2 stats on the right, same height.
                HStack(alignment: .top, spacing: 10) {
                    window(snap, now: now)
                    stats(snap).frame(width: 196)
                }
                .fixedSize(horizontal: false, vertical: true)
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
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(nsImage: WolkkLogoImage.image)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: 20)
                    .help("Wolkk")
                GlitchText(text: "// CLAUDE STATUS", trigger: snap.updatedAt, auto: true)
                    .font(Theme.mono(10, .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    HexMark(color: live ? Theme.live : Theme.faint, filled: live, size: 9)
                    Text(live ? L("LIVE") : (last.map { L("IDLE · %@", Fmt.ago($0, now: now)) } ?? L("IDLE")))
                        .font(Theme.label(9))
                        .foregroundStyle(live ? Theme.live : Theme.faint)
                        .lineLimit(1)
                }
            }
            WolkkyASCII(animated: store.panelVisible)
        }
    }

    // MARK: 5-hour window

    private func window(_ snap: UsageSnapshot, now: Date) -> some View {
        let block = snap.block.flatMap { $0.isActive ? $0 : nil }
        let tokens = block?.totals.tokens(includeCacheReads: includeCacheReads) ?? 0
        let progress: Double
        if budget > 0 {
            progress = Double(tokens) / Double(budget)
        } else if let b = block {
            progress = now.timeIntervalSince(b.start) / SnapshotBuilder.blockLength
        } else {
            progress = 0
        }

        return HUDCard(title: L("5-HOUR WINDOW"), tag: "SYS.USAGE", padding: 12, fillHeight: true) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.full(tokens))
                        .font(Theme.mono(24, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(includeCacheReads ? L("tokens incl. cache reads") : L("tokens"))
                        .font(Theme.sans(11)).foregroundStyle(Theme.sub)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .layoutPriority(-1)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    AsciiBar(progress: progress, cells: 30)
                    Text(block == nil ? "—" : Fmt.percent(progress))
                        .font(Theme.mono(11, .semibold)).foregroundStyle(Theme.ink)
                }
                if let b = block {
                    let f = Forecast(tokens: tokens, block: b, budget: budget, now: now)
                    HighlightBar(text: f.text)
                        .overlay(alignment: .leading) {
                            if f.warning { Rectangle().fill(Theme.danger).frame(width: 3) }
                        }
                    HStack(spacing: 0) {
                        Text("T-" + Fmt.clock(b.end.timeIntervalSince(now)) + "  ·  " + L("resets %@", b.end.formatted(date: .omitted, time: .shortened)))
                            .foregroundStyle(Theme.faint)
                        Spacer(minLength: 6)
                        Text("≈" + Fmt.cost(b.totals.cost)).foregroundStyle(Theme.sub)
                    }
                    .font(Theme.mono(10))
                } else {
                    Text(L("Starts with your next message"))
                        .font(Theme.sans(10)).foregroundStyle(Theme.faint)
                }
            }
        }
    }

    // MARK: Stats

    private func stats(_ snap: UsageSnapshot) -> some View {
        HUDCard(title: L("STATS"), tag: "SYS.STATS", padding: 0, fillHeight: true) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    stat(L("SESSION"), Fmt.compact(snap.session.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.session.cost))
                    divider
                    stat(L("TODAY"), Fmt.compact(snap.today.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.today.cost))
                }
                .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 0) {
                    stat(L("7 DAYS"), Fmt.compact(snap.week.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.week.cost))
                    divider
                    stat(L("CACHE"), Fmt.percent(snap.today.cacheHitRate), L("hit today"))
                }
                // Dividers would otherwise stretch to any height offered when measuring the panel.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: 1) }

    private func stat(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.label(8)).tracking(0.5).foregroundStyle(Theme.accent).lineLimit(1)
            Text(value).font(Theme.mono(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Projects (accordion with profiler cards)

    private static let maxProjects = 6

    private func projects(_ snap: UsageSnapshot, now: Date) -> some View {
        let shown = Array(snap.projects.prefix(Self.maxProjects))
        let hidden = snap.projects.count - shown.count
        let current = snap.context.map { ProjectPath.root($0.cwd) }
        return HUDCard(title: L("ACTIVE PROJECTS") + " · " + L("LAST 24H"), tag: "NODES:\(snap.projects.count)", padding: 6) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, p in
                    if i > 0 { Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 6) }
                    projectRow(p, isCurrent: current.map { $0 == p.root || $0.hasPrefix(p.root + "/") } ?? false, now: now)
                }
                if hidden > 0 {
                    Text(L("+%d more", hidden))
                        .font(Theme.sans(10)).foregroundStyle(Theme.faint)
                        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
                }
            }
        }
    }

    private func projectState(_ p: ProjectActivity, now: Date) -> (String, Color) {
        let age = now.timeIntervalSince(p.lastActivity)
        if p.activities.contains(where: { $0.isRunning(now: now) }) { return (L("RUN"), Theme.live) }
        if age < 120 { return (L("LIVE"), Theme.live) }
        if age < 1800 { return (L("ACTIVE"), Theme.accent) }
        return (Fmt.ago(p.lastActivity, now: now), Theme.faint)
    }

    private func projectRow(_ p: ProjectActivity, isCurrent: Bool, now: Date) -> some View {
        let open = store.expanded.contains(p.root)
        let state = projectState(p, now: now)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                store.toggleExpanded(p.root)
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    HexMark(color: state.1, filled: isCurrent || state.1 == Theme.live, size: 11)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(p.name)
                                .font(Theme.sans(12, isCurrent ? .bold : .medium))
                                .foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.middle)
                            Text(Self.hexID(p.root))
                                .font(Theme.mono(8)).foregroundStyle(Theme.faint)
                        }
                        Text(Self.branchText(p.branch))
                            .font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Fmt.compact(p.totals.tokens(includeCacheReads: includeCacheReads)))
                            .font(Theme.mono(12)).foregroundStyle(Theme.ink)
                        Text(state.0)
                            .font(Theme.label(8)).foregroundStyle(state.1)
                    }
                    Text(open ? "▾" : "▸")
                        .font(Theme.sans(10)).foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 6).padding(.vertical, 7)
                .background(isCurrent ? Theme.accent.opacity(0.10) : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(p.root)

            if open { profiler(p, now: now) }
        }
    }

    /// Stacked label bars: blue name bar, white key-fact bar, dark detail bars, then commands.
    private func profiler(_ p: ProjectActivity, now: Date) -> some View {
        let latest = p.activities.first
        let fact: String = {
            guard let a = latest else { return L("No commands in the last 24 hours") }
            let line = (a.tool == "$" ? "$ " : a.tool + " ") + (a.detail.isEmpty ? "—" : a.detail)
            return (a.isRunning(now: now) ? L("Running:") : L("Last:")) + " " + line
        }()
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(p.name).font(Theme.sans(11, .bold))
                Spacer(minLength: 4)
                Text(Self.hexID(p.root)).font(Theme.mono(9, .semibold))
            }
            .foregroundStyle(Theme.barInk)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent)

            HighlightBar(text: fact)

            detailBar(L("Branch"), Self.branchText(p.branch))
            detailBar(L("Tokens (24h)"), Fmt.compact(p.totals.tokens(includeCacheReads: includeCacheReads)) + "  ·  ≈" + Fmt.cost(p.totals.cost))
            if p.worktrees > 0 { detailBar(L("Worktrees"), "\(p.worktrees)") }
            if p.contextLimit > 0 { contextBar(p) }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(p.activities.enumerated()), id: \.element.id) { i, a in
                    let last = i == p.activities.count - 1
                    let status: (String, Color) = a.isRunning(now: now) ? (L("run"), Theme.live)
                        : a.status == .failed ? (L("err"), Theme.danger)
                        : a.status == .running ? (L("stop"), Theme.faint)
                        : (L("ok"), Theme.faint)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(last ? "└" : "├").foregroundStyle(Theme.faint)
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
            .padding(.top, 6)
        }
        .padding(.leading, 24).padding(.trailing, 6).padding(.bottom, 10)
    }

    private func detailBar(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":").font(Theme.sans(10)).foregroundStyle(Theme.sub)
            Text(value).font(Theme.mono(10)).foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Theme.ink.opacity(0.07))
    }

    private func contextBar(_ p: ProjectActivity) -> some View {
        let used = Double(p.contextTokens) / Double(p.contextLimit)
        let tint = used >= 0.8 ? Theme.danger : used >= 0.6 ? Theme.amber : Theme.accent
        return HStack(spacing: 6) {
            Text(L("Context") + ":").font(Theme.sans(10)).foregroundStyle(Theme.sub)
            AsciiBar(progress: used, cells: 16, tint: tint, fontSize: 10)
            Text(Fmt.percent(used)).font(Theme.mono(10, .semibold)).foregroundStyle(tint)
            Text(Fmt.compact(p.contextTokens) + "/" + Fmt.compact(p.contextLimit)).font(Theme.mono(9)).foregroundStyle(Theme.faint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Theme.ink.opacity(0.07))
        .help(used >= 0.8 ? L("Context almost full. Consider /compact.") : L("Context window use of the latest session."))
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
                Text(body)
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                AsciiButton(label: L("Open setup")) { WindowManager.shared.showOnboarding() }
            }
        }
    }

    private func footer(_ snap: UsageSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                AsciiButton(label: L("Refresh"), key: "R") { Task { await store.refresh() } }
                AsciiButton(label: L("Settings"), key: "S") { WindowManager.shared.showSettings() }
                Spacer()
                AsciiButton(label: L("Quit"), key: "Q") { NSApp.terminate(nil) }
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

/// Key-hint button: a keycap chip plus a label, e.g. `[R] Refresh`.
/// Without a key it shows a bordered label.
struct AsciiButton: View {
    var label: String
    var key: String? = nil
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let key {
                    Text(key)
                        .font(Theme.mono(9, .bold))
                        .foregroundStyle(Theme.barInk)
                        .frame(minWidth: 14)
                        .padding(.vertical, 1)
                        .background(hover ? Theme.accent : Theme.barFill)
                }
                Text(label)
                    .font(Theme.label(10))
                    .foregroundStyle(hover ? Theme.accent : Theme.ink)
                    .padding(.horizontal, key == nil ? 6 : 0)
                    .padding(.vertical, key == nil ? 2 : 0)
                    .overlay {
                        if key == nil { Rectangle().stroke(hover ? Theme.accent : Theme.line, lineWidth: 1) }
                    }
            }
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

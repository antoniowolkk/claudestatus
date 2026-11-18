import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject var store: UsageStore
    @AppStorage(Prefs.tokenBudget) private var budget = 0
    @AppStorage(Prefs.includeCacheReads) private var includeCacheReads = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { tl in
            content(now: tl.date)
        }
        .frame(width: 340)
        .background(Theme.bg)
        .appAppearance()
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let snap = store.snapshot
        VStack(alignment: .leading, spacing: 12) {
            header(snap, now: now)
            if let err = snap.error {
                messageCard(icon: "exclamationmark.triangle", title: L("Logs not found"), body: err.message + " Run a Claude Code session, then refresh.")
            } else if snap.context == nil {
                messageCard(icon: "hourglass", title: snap.updatedAt == nil ? L("Scanning logs") : L("No recent activity"), body: L("Usage shows up here after your next Claude Code message."))
            } else {
                hero(snap, now: now)
                stats(snap)
                if !snap.projects.isEmpty { projectsCard(snap, now: now) }
            }
            footer(snap, now: now)
        }
        .padding(14)
    }

    // MARK: Header

    private func header(_ snap: UsageSnapshot, now: Date) -> some View {
        let last = snap.context?.lastActivity
        let live = last.map { now.timeIntervalSince($0) < 120 } ?? false
        return HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ring)
            Text("CLAUDE // STATUS")
                .font(Theme.label(10))
                .tracking(2.4)
                .foregroundStyle(Theme.sub)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(live ? Theme.live : Theme.faint).frame(width: 6, height: 6)
                Text(live ? L("LIVE") : (last.map { L("IDLE · %@", Fmt.ago($0, now: now)) } ?? L("IDLE")))
                    .font(Theme.label(9))
                    .tracking(1.2)
                    .foregroundStyle(live ? Theme.live : Theme.faint)
            }
        }
    }

    // MARK: Hero

    private func hero(_ snap: UsageSnapshot, now: Date) -> some View {
        let block = snap.block.flatMap { $0.isActive ? $0 : nil }
        let tokens = block?.totals.tokens(includeCacheReads: includeCacheReads) ?? 0
        let remaining = block.map { $0.end.timeIntervalSince(now) } ?? 0
        let progress: Double
        let ringTop: String
        let ringBottom: String
        if budget > 0 {
            progress = Double(tokens) / Double(budget)
            ringTop = Fmt.percent(progress)
            ringBottom = L("BUDGET")
        } else if let b = block {
            progress = now.timeIntervalSince(b.start) / SnapshotBuilder.blockLength
            ringTop = Fmt.duration(remaining)
            ringBottom = L("LEFT")
        } else {
            progress = 0
            ringTop = "—"
            ringBottom = L("IDLE")
        }

        return HUDCard(padding: 14) {
            HStack(spacing: 16) {
                ZStack {
                    RingGauge(progress: progress)
                        .frame(width: 74, height: 74)
                    VStack(spacing: 1) {
                        Text(ringTop).font(Theme.mono(12, .semibold)).foregroundStyle(Theme.ink)
                        Text(ringBottom).font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.faint)
                    }
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L("5-HOUR WINDOW"))
                        .font(Theme.label(9)).tracking(1.6).foregroundStyle(Theme.accent)
                    Text(Fmt.full(tokens))
                        .font(Theme.mono(26, .semibold))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(includeCacheReads ? L("tokens incl. cache reads") : L("tokens"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                    if let b = block {
                        Text("≈\(Fmt.cost(b.totals.cost)) · " + L("resets %@", b.end.formatted(date: .omitted, time: .shortened)))
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.faint)
                            .padding(.top, 2)
                    } else {
                        Text(L("Starts with your next message"))
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.faint)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Stats

    private func stats(_ snap: UsageSnapshot) -> some View {
        HStack(spacing: 8) {
            tile(L("SESSION"), Fmt.compact(snap.session.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.session.cost))
            tile(L("TODAY"), Fmt.compact(snap.today.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.today.cost))
            tile(L("7 DAYS"), Fmt.compact(snap.week.tokens(includeCacheReads: includeCacheReads)), Fmt.cost(snap.week.cost))
            tile(L("CACHE"), Fmt.percent(snap.today.cacheHitRate), L("hit today"))
        }
    }

    private func tile(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.faint)
            Text(value).font(Theme.mono(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hair, lineWidth: 0.5))
    }

    // MARK: Projects

    private static let maxProjects = 6

    private func projectsCard(_ snap: UsageSnapshot, now: Date) -> some View {
        let shown = Array(snap.projects.prefix(Self.maxProjects))
        let hidden = snap.projects.count - shown.count
        let current = snap.context.map { ProjectPath.root($0.cwd) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("ACTIVE PROJECTS")).font(Theme.label(9)).tracking(1.6).foregroundStyle(Theme.accent)
                Spacer()
                Text(L("LAST 24H")).font(Theme.label(8)).tracking(1.2).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 2)
            HUDCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Rectangle().fill(Theme.hair).frame(height: 0.5).padding(.horizontal, 6) }
                        projectRow(p, isCurrent: current.map { $0 == p.root || $0.hasPrefix(p.root + "/") } ?? false, now: now)
                    }
                    if hidden > 0 {
                        Text(L("+%d more", hidden))
                            .font(Theme.mono(10)).foregroundStyle(Theme.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
                    }
                }
            }
        }
    }

    private func projectRow(_ p: ProjectActivity, isCurrent: Bool, now: Date) -> some View {
        let age = now.timeIntervalSince(p.lastActivity)
        let state: (String, Color) = age < 120 ? (L("LIVE"), Theme.live) : age < 1800 ? (L("ACTIVE"), Theme.accent) : (Fmt.ago(p.lastActivity, now: now), Theme.faint)
        var detail = Self.branchText(p.branch)
        if p.worktrees > 0 { detail += " · " + L(p.worktrees == 1 ? "%d worktree" : "%d worktrees", p.worktrees) }

        return HStack(spacing: 9) {
            Circle().fill(state.1).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name)
                    .font(Theme.mono(12, isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.middle)
                Text(detail)
                    .font(Theme.mono(9)).foregroundStyle(Theme.sub).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.compact(p.totals.tokens(includeCacheReads: includeCacheReads)))
                    .font(Theme.mono(12)).foregroundStyle(Theme.ink)
                Text(state.0)
                    .font(Theme.label(8)).tracking(1).foregroundStyle(state.1)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(isCurrent ? Theme.accent.opacity(0.06) : .clear))
        .help(p.root)
    }

    private static func branchText(_ branch: String) -> String {
        branch.isEmpty || branch == "HEAD" ? L("no branch") : branch
    }

    // MARK: Messages + footer

    private func messageCard(icon: String, title: String, body: String) -> some View {
        HUDCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Open setup")) { WindowManager.shared.showOnboarding() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
        }
    }

    private func footer(_ snap: UsageSnapshot, now: Date) -> some View {
        HStack(spacing: 4) {
            Text(snap.updatedAt.map { L("SYNC %@", Fmt.ago($0, now: now).uppercased()) } ?? L("SYNCING"))
                .font(Theme.label(9)).tracking(1.2).foregroundStyle(Theme.faint)
            Spacer()
            IconButton(icon: "arrow.clockwise", help: L("Refresh")) {
                Task { await store.refresh() }
            }
            IconButton(icon: "gearshape", help: L("Settings")) { WindowManager.shared.showSettings() }
            IconButton(icon: "power", help: L("Quit Claude Status")) { NSApp.terminate(nil) }
        }
    }
}

struct IconButton: View {
    var icon: String
    var help: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hover ? Theme.accent : Theme.sub)
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Theme.accent.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

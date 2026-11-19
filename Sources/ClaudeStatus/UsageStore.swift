import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published private(set) var isRefreshing = false
    /// Project rows open in the panel (by project root).
    @Published var expanded: Set<String> = []

    func toggleExpanded(_ root: String) {
        if expanded.contains(root) { expanded.remove(root) } else { expanded.insert(root) }
    }

    private let scanner = LogScanner()
    private var loop: Task<Void, Never>?

    private init() {
        Prefs.registerDefaults()
        start()
    }

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = max(5, UserDefaults.standard.integer(forKey: Prefs.refreshInterval))
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private var inFlight: Task<Void, Never>?

    /// Rescans logs. Concurrent callers share one scan.
    func refresh() async {
        if let running = inFlight { return await running.value }
        let task = Task { [scanner] in
            isRefreshing = true
            snapshot = await scanner.snapshot(now: Date())
            isRefreshing = false
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// Fake numbers for README screenshots (`--snapshot out.png --demo`).
    func loadDemo() {
        loop?.cancel()
        let now = Date()
        func t(_ i: Int, _ o: Int, _ w: Int, _ r: Int, _ c: Double) -> UsageTotals {
            UsageTotals(input: i, output: o, cacheWrite: w, cacheRead: r, cost: c, messages: 1)
        }
        let start = Calendar.current.dateInterval(of: .hour, for: now.addingTimeInterval(-5_400))!.start
        snapshot = UsageSnapshot(
            block: BlockInfo(start: start, end: start.addingTimeInterval(SnapshotBuilder.blockLength),
                             totals: t(12_400, 9_908, 19_800, 640_000, 1.84), isActive: true),
            session: t(2_100, 2_300, 3_800, 90_000, 0.31),
            today: t(40_000, 52_000, 94_000, 1_900_000, 6.12),
            week: t(210_000, 300_000, 590_000, 11_000_000, 38.40),
            context: ContextInfo(model: "claude-opus-5-5", cwd: "/Users/you/work/orbit-api",
                                 branch: "feat/telemetry", entrypoint: "cli", sessionId: "demo",
                                 lastActivity: now.addingTimeInterval(-20)),
            projects: [
                ProjectActivity(root: "/Users/you/work/orbit-api", name: "orbit-api", branch: "feat/telemetry",
                                lastActivity: now.addingTimeInterval(-20), totals: t(9_000, 14_000, 21_000, 0, 1.10), worktrees: 2, sessions: 3,
                                activities: [
                                    ToolActivity(id: "d1", time: now.addingTimeInterval(-8), cwd: "", tool: "$", detail: "swift test --filter TelemetryTests", status: .running),
                                    ToolActivity(id: "d2", time: now.addingTimeInterval(-40), cwd: "", tool: "edit", detail: "TelemetryClient.swift", status: .done),
                                    ToolActivity(id: "d3", time: now.addingTimeInterval(-75), cwd: "", tool: "grep", detail: "emitEvent\\(", status: .done),
                                    ToolActivity(id: "d4", time: now.addingTimeInterval(-130), cwd: "", tool: "$", detail: "swift build -c release", status: .failed),
                                    ToolActivity(id: "d5", time: now.addingTimeInterval(-200), cwd: "", tool: "read", detail: "Package.swift", status: .done),
                                ]),
                ProjectActivity(root: "/Users/you/work/nova-web", name: "nova-web", branch: "main",
                                lastActivity: now.addingTimeInterval(-900), totals: t(6_000, 9_500, 12_000, 0, 0.74), sessions: 1),
                ProjectActivity(root: "/Users/you/lab/pulse-cli", name: "pulse-cli", branch: "fix/parser",
                                lastActivity: now.addingTimeInterval(-11_000), totals: t(4_000, 6_000, 8_000, 0, 0.41), worktrees: 1, sessions: 2),
            ],
            filesScanned: 12, updatedAt: now, error: nil
        )
    }

    var includeCacheReads: Bool { UserDefaults.standard.bool(forKey: Prefs.includeCacheReads) }

    /// Hover tooltip for the menu bar icon: "Claude · 42.1k · Opus 5.5 · claudestatus".
    var menuBarText: String {
        var parts = ["Claude"]
        let t = snapshot.block.map { $0.isActive ? $0.totals.tokens(includeCacheReads: includeCacheReads) : 0 } ?? 0
        parts.append(L("%@ tokens", Fmt.compact(t)))
        if let m = snapshot.context?.model { parts.append(ModelName.pretty(m)) }
        if let p = snapshot.context?.project { parts.append(p) }
        return parts.joined(separator: " · ")
    }
}

import AppKit
import UserNotifications

/// Sends "Claude is done", "Claude needs you" and usage-limit notifications.
/// Everything is decided locally from the log snapshot; nothing leaves the Mac.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Turns shorter than this don't notify: you were probably still watching.
    static let minTurn: TimeInterval = 60

    private var seen = Set<String>()
    private var primed = false
    private var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter needs a real app bundle (not the bare dev binary).
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func start() {
        center?.delegate = self
        if anyEnabled { requestAuthorization() }
    }

    var anyEnabled: Bool {
        let d = UserDefaults.standard
        return d.bool(forKey: Prefs.notifyDone) || d.bool(forKey: Prefs.notifyQuestion) || d.bool(forKey: Prefs.notifyLimit)
    }

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Checks a fresh snapshot for new events. The first call only records what already happened.
    func process(_ snap: UsageSnapshot, now: Date = Date()) {
        let d = UserDefaults.standard
        let budget = d.integer(forKey: Prefs.tokenBudget)
        let includeCache = d.bool(forKey: Prefs.includeCacheReads)
        let limitKeys = limitEvents(snap, budget: budget, includeCache: includeCache)

        guard primed else {
            snap.turnEnds.forEach { seen.insert($0.id) }
            snap.questions.forEach { seen.insert($0.id) }
            limitKeys.forEach { seen.insert($0.key) }
            primed = true
            return
        }

        if d.bool(forKey: Prefs.notifyDone) {
            for t in snap.turnEnds where !seen.contains(t.id) {
                seen.insert(t.id)
                guard t.duration >= Self.minTurn, now.timeIntervalSince(t.end) < 300, !hostIsFrontmost(t.entrypoint) else { continue }
                post(id: t.id,
                     title: L("%@ is done", projectName(t.cwd)),
                     body: L("Claude finished after %@.", Fmt.duration(t.duration)))
            }
        }
        if d.bool(forKey: Prefs.notifyQuestion) {
            for q in snap.questions where !seen.contains(q.id) {
                seen.insert(q.id)
                guard now.timeIntervalSince(q.time) < 300, !hostIsFrontmost(q.entrypoint) else { continue }
                post(id: q.id,
                     title: L("%@ needs you", projectName(q.cwd)),
                     body: L("Claude is waiting for your answer."))
            }
        }
        if d.bool(forKey: Prefs.notifyLimit) {
            for e in limitKeys where !seen.contains(e.key) {
                seen.insert(e.key)
                post(id: e.key, title: e.title, body: e.body)
            }
        }
    }

    private func limitEvents(_ snap: UsageSnapshot, budget: Int, includeCache: Bool) -> [(key: String, title: String, body: String)] {
        guard budget > 0, let b = snap.block, b.isActive else { return [] }
        let used = Double(b.totals.tokens(includeCacheReads: includeCache)) / Double(budget)
        let blockKey = String(Int(b.start.timeIntervalSince1970))
        return [0.8, 0.9, 1.0].filter { used >= $0 }.map { level in
            let pct = Int(level * 100)
            return (key: "limit-\(blockKey)-\(pct)",
                    title: L("%d%% of your 5-hour budget used", pct),
                    body: L("Resets at %@.", b.end.formatted(date: .omitted, time: .shortened)))
        }
    }

    /// Sends a sample notification (`--notify-test`).
    func test() {
        post(id: "test-\(Date().timeIntervalSince1970)", title: L("%@ is done", "claudestatus"),
             body: L("Claude finished after %@.", Fmt.duration(272)))
    }

    private func projectName(_ cwd: String) -> String { ProjectPath.name(ProjectPath.root(cwd)) }

    /// True when the app that runs this Claude session is in front (you're already looking).
    private func hostIsFrontmost(_ entrypoint: String) -> Bool {
        guard UserDefaults.standard.bool(forKey: Prefs.notifyOnlyAway),
              let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() else { return false }
        switch entrypoint {
        case "claude-desktop": return front.contains("anthropic") || front.contains("claude")
        case "claude-vscode": return front.contains("vscode") || front.contains("cursor") || front.contains("windsurf")
        case let s where s.contains("jetbrains"): return front.contains("jetbrains")
        default: // CLI: any common terminal
            let terminals = ["com.apple.terminal", "com.googlecode.iterm2", "dev.warp", "com.mitchellh.ghostty",
                             "net.kovidgoyal.kitty", "io.alacritty", "com.github.wez.wezterm", "co.zeit.hyper"]
            return terminals.contains { front.hasPrefix($0) }
        }
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center?.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in StatusController.shared.open() }
        completionHandler()
    }
}

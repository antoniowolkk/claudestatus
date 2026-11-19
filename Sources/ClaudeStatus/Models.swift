import Foundation

/// One deduplicated assistant response read from a Claude Code session log.
struct UsageEntry: Sendable {
    let key: String
    let time: Date
    let model: String
    let input: Int
    let output: Int
    let cacheWrite5m: Int
    let cacheWrite1h: Int
    let cacheRead: Int
    let sessionId: String
    let cwd: String
    let branch: String
    let entrypoint: String
    /// "end_turn" when Claude finished and handed back to you; "tool_use" mid-task.
    var stopReason: String = ""
    /// Subagent traffic, not the main conversation.
    var isSidechain = false

    var cacheWrite: Int { cacheWrite5m + cacheWrite1h }
    /// Tokens Claude read as the prompt for this message: the size of the context window in use.
    var contextSize: Int { input + cacheWrite + cacheRead }
}

/// Claude finished a turn (stopped and handed back to you).
struct TurnEnd: Sendable, Equatable, Identifiable {
    let id: String
    let sessionId: String
    let cwd: String
    let entrypoint: String
    let start: Date
    let end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Claude is waiting on you: a question or a plan to approve.
struct PendingQuestion: Sendable, Equatable, Identifiable {
    let id: String
    let time: Date
    let cwd: String
    let entrypoint: String
}

enum ContextWindow {
    /// Context window size for a model id.
    static func limit(for model: String) -> Int {
        let m = model.lowercased()
        let million = ["fable", "mythos", "opus-5", "opus-4-6", "opus-4-7", "opus-4-8", "sonnet-5", "sonnet-4-6", "haiku-5"]
        return million.contains { m.contains($0) } ? 1_000_000 : 200_000
    }
}

struct UsageTotals: Sendable, Equatable {
    var input = 0
    var output = 0
    var cacheWrite = 0
    var cacheRead = 0
    var cost: Double = 0
    var messages = 0

    mutating func add(_ e: UsageEntry) {
        input += e.input
        output += e.output
        cacheWrite += e.cacheWrite
        cacheRead += e.cacheRead
        cost += Pricing.cost(e)
        messages += 1
    }

    func tokens(includeCacheReads: Bool) -> Int {
        input + output + cacheWrite + (includeCacheReads ? cacheRead : 0)
    }

    /// Share of prompt tokens served from cache.
    var cacheHitRate: Double? {
        let prompt = input + cacheWrite + cacheRead
        return prompt > 0 ? Double(cacheRead) / Double(prompt) : nil
    }
}

/// What Claude is doing right now, taken from the most recent log entry.
struct ContextInfo: Sendable, Equatable {
    var model: String
    var cwd: String
    var branch: String
    var entrypoint: String
    var sessionId: String
    var lastActivity: Date

    var project: String { ProjectPath.name(ProjectPath.root(cwd)) }
    var worktree: String? { ProjectPath.worktree(cwd) }
}

/// Maps a working folder to the project it belongs to.
/// Claude Code worktrees (`<repo>/.claude/worktrees/<name>`) count as their repo.
enum ProjectPath {
    static let worktreeMarker = "/.claude/worktrees/"

    static func root(_ cwd: String) -> String {
        if let r = cwd.range(of: worktreeMarker) { return String(cwd[..<r.lowerBound]) }
        return cwd
    }

    static func worktree(_ cwd: String) -> String? {
        guard let r = cwd.range(of: worktreeMarker) else { return nil }
        return cwd[r.upperBound...].split(separator: "/").first.map(String.init)
    }

    static func name(_ root: String) -> String {
        let n = (root as NSString).lastPathComponent
        return n.isEmpty ? "—" : n
    }
}

/// One tool call Claude made (a shell command, a file edit, a search, …).
/// Only a one-line summary is kept, in memory.
struct ToolActivity: Sendable, Equatable, Identifiable {
    enum Status: Sendable, Equatable { case running, done, failed }

    let id: String
    let time: Date
    let cwd: String
    let tool: String
    let detail: String
    var status: Status

    /// A call with no result after this long was most likely interrupted.
    static let staleAfter: TimeInterval = 15 * 60

    func isRunning(now: Date) -> Bool {
        status == .running && now.timeIntervalSince(time) < Self.staleAfter
    }
}

/// One project folder Claude worked in recently.
struct ProjectActivity: Sendable, Equatable, Identifiable {
    var id: String { root }
    var root: String
    var name: String
    var branch: String
    var worktree: String?
    var lastActivity: Date
    var totals = UsageTotals()
    var worktrees = 0
    var sessions = 0
    /// Latest tool calls in this project, newest first.
    var activities: [ToolActivity] = []
    /// Context window use of the project's most recent session.
    var contextTokens = 0
    var contextLimit = 0
}

/// A rolling 5-hour usage window, the same shape Claude plans use for limits.
struct BlockInfo: Sendable, Equatable {
    var start: Date
    var end: Date
    var totals: UsageTotals
    var isActive: Bool
}

enum ScanError: Sendable, Equatable {
    case notFound(String)
    case unreadable(String)

    var message: String {
        switch self {
        case .notFound(let p): return L("No Claude Code logs found at %@.", p)
        case .unreadable(let p): return L("Can't read %@.", p)
        }
    }
}

struct UsageSnapshot: Sendable, Equatable {
    var block: BlockInfo?
    var session = UsageTotals()
    var today = UsageTotals()
    var week = UsageTotals()
    var context: ContextInfo?
    /// Projects active in the last 24 hours, most recent first.
    var projects: [ProjectActivity] = []
    /// Recently finished turns and open questions, for notifications.
    var turnEnds: [TurnEnd] = []
    var questions: [PendingQuestion] = []
    /// Busiest 5-hour window in the scanned history.
    var peakBlock = UsageTotals()
    var filesScanned = 0
    var updatedAt: Date?
    var error: ScanError?

    static let empty = UsageSnapshot()
}

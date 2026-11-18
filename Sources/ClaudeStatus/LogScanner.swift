import Foundation

/// Reads Claude Code session logs (`~/.claude/projects/**/*.jsonl`) incrementally.
///
/// Security notes:
/// - Read-only. Never writes, moves or deletes anything in `~/.claude`.
/// - Skips symbolic links so a link can't point the scanner outside the folder.
/// - Only keeps token counts and context metadata in memory; message text is discarded.
actor LogScanner {
    private struct FileState {
        var offset: UInt64
    }

    private var files: [String: FileState] = [:]
    private var entries: [String: UsageEntry] = [:]
    private let retention: TimeInterval = 8 * 24 * 3600
    private let maxLineBytes = 32 << 20
    private let chunkBytes = 4 << 20

    private let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// The user's real home folder, even when the app runs in the App Sandbox.
    static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    static var projectsDir: String { realHome + "/.claude/projects" }

    func snapshot(now: Date = Date()) -> UsageSnapshot {
        let (count, error) = scan(now: now)
        var snap = SnapshotBuilder.build(entries: Array(entries.values), now: now)
        snap.filesScanned = count
        snap.error = error
        snap.updatedAt = now
        return snap
    }

    private func scan(now: Date) -> (Int, ScanError?) {
        let fm = FileManager.default
        let root = Self.projectsDir
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
            return (0, .notFound(root))
        }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard fm.isReadableFile(atPath: root),
              let walker = fm.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        else {
            return (0, .unreadable(root))
        }

        let cutoff = now.addingTimeInterval(-retention)
        var seen = Set<String>()
        for case let url as URL in walker {
            guard url.pathExtension == "jsonl",
                  let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true, v.isSymbolicLink != true,
                  (v.contentModificationDate ?? .distantPast) >= cutoff
            else { continue }

            let path = url.path
            let size = UInt64(v.fileSize ?? 0)
            seen.insert(path)
            var state = files[path] ?? FileState(offset: 0)
            if size < state.offset { state.offset = 0 } // file was truncated or replaced
            if size > state.offset {
                state.offset = readNewLines(path: path, from: state.offset)
            }
            files[path] = state
        }

        files = files.filter { seen.contains($0.key) }
        entries = entries.filter { $0.value.time >= cutoff }
        return (seen.count, nil)
    }

    /// Reads complete lines after `start` and returns the offset just past the last full line.
    private func readNewLines(path: String, from start: UInt64) -> UInt64 {
        guard let fh = FileHandle(forReadingAtPath: path) else { return start }
        defer { try? fh.close() }
        do { try fh.seek(toOffset: start) } catch { return start }

        var offset = start
        var carry = Data()
        while true {
            guard let chunk = autoreleasepool(invoking: { try? fh.read(upToCount: chunkBytes) }),
                  !chunk.isEmpty else { break }
            var buffer = carry
            buffer.append(chunk)
            guard let lastNL = buffer.lastIndex(of: 0x0A) else {
                carry = buffer
                if carry.count > maxLineBytes { // runaway line: skip it
                    offset += UInt64(carry.count)
                    carry.removeAll()
                }
                continue
            }
            let complete = buffer[buffer.startIndex...lastNL]
            for line in complete.split(separator: 0x0A, omittingEmptySubsequences: true) {
                // Foundation JSON objects are autoreleased; drain per line to keep memory flat.
                autoreleasepool { parse(line: line) }
            }
            offset += UInt64(complete.count)
            carry = Data(buffer[buffer.index(after: lastNL)...])
        }
        return offset
    }

    private static let usageMarker = Data("\"usage\"".utf8)
    private static let assistantMarker = Data("\"type\":\"assistant\"".utf8)

    private func parse(line: Data.SubSequence) {
        guard line.range(of: Self.assistantMarker) != nil,
              line.range(of: Self.usageMarker) != nil,
              let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
              obj["type"] as? String == "assistant",
              let msg = obj["message"] as? [String: Any],
              let usage = msg["usage"] as? [String: Any],
              let model = msg["model"] as? String, !model.hasPrefix("<"),
              let ts = obj["timestamp"] as? String,
              let time = isoFrac.date(from: ts) ?? iso.date(from: ts)
        else { return }

        func int(_ d: [String: Any]?, _ k: String) -> Int { (d?[k] as? NSNumber)?.intValue ?? 0 }

        let cacheCreation = usage["cache_creation"] as? [String: Any]
        let write5m: Int
        let write1h: Int
        if let cc = cacheCreation {
            write5m = int(cc, "ephemeral_5m_input_tokens")
            write1h = int(cc, "ephemeral_1h_input_tokens")
        } else {
            write5m = int(usage, "cache_creation_input_tokens")
            write1h = 0
        }

        let msgId = msg["id"] as? String ?? (obj["uuid"] as? String ?? UUID().uuidString)
        let key = msgId + "|" + (obj["requestId"] as? String ?? "")
        let entry = UsageEntry(
            key: key,
            time: time,
            model: model,
            input: int(usage, "input_tokens"),
            output: int(usage, "output_tokens"),
            cacheWrite5m: write5m,
            cacheWrite1h: write1h,
            cacheRead: int(usage, "cache_read_input_tokens"),
            sessionId: obj["sessionId"] as? String ?? "",
            cwd: obj["cwd"] as? String ?? "",
            branch: obj["gitBranch"] as? String ?? "",
            entrypoint: obj["entrypoint"] as? String ?? ""
        )
        // One response can be logged once per content block. Keep the most complete copy.
        if let old = entries[key], old.output > entry.output { return }
        entries[key] = entry
    }
}

enum SnapshotBuilder {
    static let blockLength: TimeInterval = 5 * 3600

    static func build(entries: [UsageEntry], now: Date) -> UsageSnapshot {
        var snap = UsageSnapshot()
        let sorted = entries.sorted { $0.time < $1.time }
        guard let last = sorted.last else { return snap }

        snap.context = ContextInfo(
            model: last.model, cwd: last.cwd, branch: last.branch,
            entrypoint: last.entrypoint, sessionId: last.sessionId, lastActivity: last.time
        )

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let weekStart = now.addingTimeInterval(-7 * 24 * 3600)

        var blockStart: Date?
        var lastTime: Date?
        var blockTotals = UsageTotals()

        for e in sorted {
            if e.sessionId == last.sessionId { snap.session.add(e) }
            if e.time >= dayStart { snap.today.add(e) }
            if e.time >= weekStart { snap.week.add(e) }

            if let s = blockStart, let l = lastTime,
               e.time < s.addingTimeInterval(blockLength),
               e.time.timeIntervalSince(l) < blockLength {
                blockTotals.add(e)
            } else {
                blockStart = cal.dateInterval(of: .hour, for: e.time)?.start ?? e.time
                blockTotals = UsageTotals()
                blockTotals.add(e)
            }
            lastTime = e.time
        }

        if let s = blockStart {
            let end = s.addingTimeInterval(blockLength)
            snap.block = BlockInfo(start: s, end: end, totals: blockTotals, isActive: end > now)
        }
        snap.projects = projects(sorted.filter { $0.time >= now.addingTimeInterval(-24 * 3600) && !$0.cwd.isEmpty })
        return snap
    }

    /// Groups entries by project. Subfolders and worktrees fold into their repo.
    private static func projects(_ entries: [UsageEntry]) -> [ProjectActivity] {
        // Shortest roots first so a subfolder maps onto its parent project.
        let roots = Set(entries.map { ProjectPath.root($0.cwd) }).sorted { $0.count < $1.count }
        var canonical: [String: String] = [:]
        for r in roots {
            canonical[r] = roots.first { r == $0 || r.hasPrefix($0 + "/") } ?? r
        }

        var byRoot: [String: ProjectActivity] = [:]
        var worktrees: [String: Set<String>] = [:]
        var sessions: [String: Set<String>] = [:]
        for e in entries { // sorted oldest → newest, so the last write is the latest state
            let root = canonical[ProjectPath.root(e.cwd)] ?? e.cwd
            var p = byRoot[root] ?? ProjectActivity(root: root, name: ProjectPath.name(root), branch: e.branch, lastActivity: e.time)
            p.totals.add(e)
            p.lastActivity = e.time
            p.branch = e.branch
            p.worktree = ProjectPath.worktree(e.cwd)
            byRoot[root] = p
            if let w = ProjectPath.worktree(e.cwd) { worktrees[root, default: []].insert(w) }
            sessions[root, default: []].insert(e.sessionId)
        }
        return byRoot.values
            .map { p in
                var p = p
                p.worktrees = worktrees[p.root]?.count ?? 0
                p.sessions = sessions[p.root]?.count ?? 0
                return p
            }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
}

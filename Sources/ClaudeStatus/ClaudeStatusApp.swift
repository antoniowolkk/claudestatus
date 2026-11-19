import SwiftUI
import AppKit
import ServiceManagement

@main
struct ClaudeStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The menu bar item is a plain NSStatusItem (see StatusController) so it opens instantly.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        NSApp.setActivationPolicy(.accessory)
        // Light unless the user turned on Dark mode (independent of the system setting).
        NSApp.appearance = AppAppearance.nsAppearance

        // Developer helper: `ClaudeStatus --dump` prints what the scanner found and exits.
        if CommandLine.arguments.contains("--dump") {
            Task { @MainActor in
                await UsageStore.shared.refresh()
                let s = UsageStore.shared.snapshot
                print("peak 5h window:", s.peakBlock.tokens(includeCacheReads: false))
                let day = await UsageStore.shared.scanner.turnEnds(since: Date().addingTimeInterval(-24 * 3600))
                print("turn ends 24h:", day.count, "· 1+ min:", day.filter { $0.duration >= Notifier.minTurn }.count)
                for t in day.suffix(3) { print("  e.g.", ProjectPath.name(ProjectPath.root(t.cwd)), Fmt.duration(t.duration)) }
                for t in s.turnEnds { print("turn end:", ProjectPath.name(ProjectPath.root(t.cwd)), Int(t.duration), "s", t.end) }
                for q in s.questions { print("question:", ProjectPath.name(ProjectPath.root(q.cwd)), q.time) }
                for p in s.projects.prefix(8) {
                    print("project:", p.name, "context", p.contextTokens, "/", p.contextLimit, "running", p.activities.filter { $0.isRunning(now: Date()) }.count)
                }
                exit(0)
            }
            return
        }
        // Developer helper: `ClaudeStatus --snapshot out.png` renders the panel and exits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Task { @MainActor in
                await UsageStore.shared.refresh()
                if args.contains("--demo") { UsageStore.shared.loadDemo() }
                if args.contains("--expand"), let first = UsageStore.shared.snapshot.projects.first {
                    UsageStore.shared.expanded = [first.root]
                }
                Snapshotter.render(to: args[i + 1])
                exit(0)
            }
            return
        }

        Task { @MainActor in
            StatusController.shared.install()
            Notifier.shared.start()
            if CommandLine.arguments.contains("--notify-test") { // testing aid
                try? await Task.sleep(for: .seconds(2))
                Notifier.shared.test()
            }
            if CommandLine.arguments.contains("--open-panel") { // testing aid
                try? await Task.sleep(for: .seconds(1))
                StatusController.shared.open()
                if CommandLine.arguments.contains("--expand") {
                    try? await Task.sleep(for: .seconds(4))
                    if let first = UsageStore.shared.snapshot.projects.first { UsageStore.shared.toggleExpanded(first.root) }
                }
            }
            if !UserDefaults.standard.bool(forKey: Prefs.onboarded) {
                WindowManager.shared.showOnboarding()
            }
        }
    }
}

@MainActor
enum Snapshotter {
    static func render(to path: String) {
        let view = Group {
            if CommandLine.arguments.contains("--wolkk-tab") {
                WolkkSettings().padding(20).frame(width: 520).background(Theme.bg)
            } else {
                PanelView()
            }
        }
            .environmentObject(UsageStore.shared)
            .appAppearance()
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

/// Opens regular windows (setup + settings) for a menu-bar-only app.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func showOnboarding() {
        show(id: "onboarding", title: L("Welcome to Wolkky Claude Status"), size: CGSize(width: 560, height: 500)) {
            AnyView(OnboardingView())
        }
    }

    func showSettings() {
        show(id: "settings", title: L("Wolkky Claude Status Settings"), size: CGSize(width: 520, height: 460)) {
            AnyView(SettingsView())
        }
    }

    func close(_ id: String) { windows[id]?.close() }

    private func show(id: String, title: String, size: CGSize, content: () -> AnyView) {
        if let w = windows[id] {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = content()
            .environmentObject(UsageStore.shared)
            .appAppearance()
        let view = NSHostingView(rootView: root)
        view.sizingOptions = [] // fixed-size windows; no automatic window resizing
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.contentView = view
        w.title = title
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.appearance = AppAppearance.nsAppearance
        w.isReleasedWhenClosed = false
        w.setContentSize(size)
        w.center()
        windows[id] = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

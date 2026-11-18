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
        // Always light, whatever the system appearance.
        NSApp.appearance = NSAppearance(named: .aqua)

        // Developer helper: `ClaudeStatus --snapshot out.png` renders the panel and exits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            Task { @MainActor in
                await UsageStore.shared.refresh()
                if args.contains("--demo") { UsageStore.shared.loadDemo() }
                Snapshotter.render(to: args[i + 1])
                exit(0)
            }
            return
        }

        Task { @MainActor in
            StatusController.shared.install()
            if CommandLine.arguments.contains("--open-panel") { // testing aid
                try? await Task.sleep(for: .seconds(1))
                StatusController.shared.open()
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
        let view = PanelView()
            .environmentObject(UsageStore.shared)
            .environment(\.colorScheme, .light)
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
        show(id: "onboarding", title: "Welcome to Claude Status", size: CGSize(width: 560, height: 440)) {
            AnyView(OnboardingView())
        }
    }

    func showSettings() {
        show(id: "settings", title: "Claude Status Settings", size: CGSize(width: 520, height: 460)) {
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
            .environment(\.colorScheme, .light)
        let view = NSHostingView(rootView: root)
        view.sizingOptions = [] // fixed-size windows; no automatic window resizing
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.contentView = view
        w.title = title
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.appearance = NSAppearance(named: .aqua)
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

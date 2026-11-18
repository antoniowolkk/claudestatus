import AppKit
import Combine
import SwiftUI

/// Borderless panel that appears instantly under the menu bar item. No open/close animation.
final class StatusPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        animationBehavior = .none
        hidesOnDeactivate = false
        isMovable = false
        appearance = NSAppearance(named: .aqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
}

/// Owns the menu bar item and its panel.
@MainActor
final class StatusController: NSObject {
    static let shared = StatusController()

    private var item: NSStatusItem?
    private var panel: StatusPanel?
    private var host: NSHostingController<AnyView>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var bag = Set<AnyCancellable>()

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.icon
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Claude Status")
        self.item = item

        let store = UsageStore.shared
        store.$snapshot.map { _ in () }
            .merge(with: NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateTitle() }
            .store(in: &bag)
        updateTitle()
    }

    private func updateTitle() {
        guard let button = item?.button else { return }
        let text = UsageStore.shared.menuBarText
        button.attributedTitle = NSAttributedString(
            string: text.isEmpty ? "" : " " + text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)]
        )
    }

    // MARK: Panel

    @objc func toggle() {
        if panel?.isVisible == true { close() } else { open() }
    }

    func open() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if let host {
            panel.setContentSize(host.view.fittingSize)
        }
        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        item?.button?.highlight(true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.close(); return nil } // Esc
            return e
        }
        Task { await UsageStore.shared.refresh() }
    }

    func close() {
        panel?.orderOut(nil)
        item?.button?.highlight(false)
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        clickMonitor = nil
        keyMonitor = nil
    }

    private func makePanel() -> StatusPanel {
        let root = AnyView(
            PanelView()
                .environmentObject(UsageStore.shared)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hair, lineWidth: 0.5))
                .environment(\.colorScheme, .light)
                .transaction { $0.animation = nil }
        )
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.preferredContentSize]
        self.host = host

        let panel = StatusPanel()
        panel.contentViewController = host
        // Keep the panel pinned under the menu bar when its content height changes.
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let p = self.panel else { return }
                self.position(p)
            }
        }
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let button = item?.button, let bw = button.window else { return }
        let anchor = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = bw.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = panel.frame.size
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = anchor.minY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: Icon

    /// Full-color gradient spark (not a template image, so macOS doesn't tint it black or white).
    static let icon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude Status")?
            .withSymbolConfiguration(config) else { return NSImage() }
        let size = symbol.size
        let image = NSImage(size: size, flipped: false) { rect in
            let gradient = NSGradient(colors: [
                NSColor(red: 0.00, green: 0.76, blue: 0.86, alpha: 1),
                NSColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 1),
                NSColor(red: 0.45, green: 0.36, blue: 0.95, alpha: 1),
            ])
            gradient?.draw(in: rect, angle: -45)
            symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        image.isTemplate = false
        return image
    }()
}

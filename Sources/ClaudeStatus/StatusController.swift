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
    private var hostView: NSHostingView<AnyView>?
    /// Off-window copy of the panel content, used only to measure its height.
    private var measurer: NSHostingController<AnyView>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var bag = Set<AnyCancellable>()
    private var resizeScheduled = false

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.icon
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Claude Status")
        self.item = item

        // Icon only in the menu bar; the summary shows as a tooltip. When the panel is
        // open, refit it to new content on the next run loop turn (never during layout).
        UsageStore.shared.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.item?.button?.toolTip = UsageStore.shared.menuBarText
                self?.scheduleResize()
            }
            .store(in: &bag)
    }

    // MARK: Panel

    @objc func toggle() {
        if panel?.isVisible == true { close() } else { open() }
    }

    func open() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        fit(panel)
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
        measurer = NSHostingController(rootView: root)
        let view = NSHostingView(rootView: root)
        // The hosting view must never resize the window on its own: doing so while the
        // window lays out recurses until the stack overflows. We size it in fit(_:).
        view.sizingOptions = []
        hostView = view

        let panel = StatusPanel()
        panel.contentView = view
        return panel
    }

    private func scheduleResize() {
        guard panel?.isVisible == true, !resizeScheduled else { return }
        resizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resizeScheduled = false
            if let p = self.panel, p.isVisible { self.fit(p) }
        }
    }

    /// Sizes the panel to its content and pins its top edge under the menu bar icon.
    private func fit(_ panel: NSPanel) {
        guard let measurer else { return }
        let fitted = measurer.sizeThatFits(in: NSSize(width: 340, height: 4000))
        let size = NSSize(width: 340, height: ceil(fitted.height))
        guard size.height > 0 else { return }

        // An accessory app often has no key window, so NSScreen.main can be nil.
        let screen = item?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        // Default: top-right, just under the menu bar.
        var origin = NSPoint(x: visible.maxX - size.width - 8, y: visible.maxY - size.height - 6)
        if let button = item?.button, let bw = button.window, bw.frame.width > 0 {
            let anchor = bw.convertToScreen(button.convert(button.bounds, to: nil))
            var x = anchor.midX - size.width / 2
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
            origin = NSPoint(x: x, y: min(anchor.minY, visible.maxY) - size.height - 6)
        }
        let frame = NSRect(origin: origin, size: size)
        if panel.frame != frame { panel.setFrame(frame, display: true, animate: false) }
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

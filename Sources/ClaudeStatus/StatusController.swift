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
        appearance = AppAppearance.nsAppearance
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.icon
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Wolkky Claude Status")
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
        UsageStore.shared.$expanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleResize() }
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
        UsageStore.shared.panelVisible = true
        panel.orderFrontRegardless()
        panel.makeKey()
        item?.button?.highlight(true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { self?.close(); return nil } // Esc
            // Key hints shown in the panel footer: R refresh, S settings, Q quit.
            guard e.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return e }
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "r": Task { await UsageStore.shared.refresh() }; return nil
            case "s": self?.close(); WindowManager.shared.showSettings(); return nil
            case "q": NSApp.terminate(nil); return nil
            default: return e
            }
        }
        Task { await UsageStore.shared.refresh() }
    }

    func close() {
        panel?.orderOut(nil)
        UsageStore.shared.panelVisible = false
        item?.button?.highlight(false)
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        clickMonitor = nil
        keyMonitor = nil
    }

    private func makePanel() -> StatusPanel {
        let content = PanelView()
            .environmentObject(UsageStore.shared)
            .appAppearance()
            .transaction { $0.animation = nil }
        // Measured without a scroll view to get the natural height…
        measurer = NSHostingController(rootView: AnyView(content.environment(\.isMeasuring, true)))
        // …shown inside one, so a panel taller than the screen scrolls instead of being cut off.
        let root = AnyView(
            ScrollView(.vertical) { content }
                .scrollIndicators(.never)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hair, lineWidth: 0.5))
                .appAppearance()
        )
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
        let fitted = measurer.sizeThatFits(in: NSSize(width: PanelView.width, height: 4000))
        // An accessory app often has no key window, so NSScreen.main can be nil.
        let screen = item?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        // Never taller than the screen; the scroll view takes the rest.
        let maxHeight = visible.height > 0 ? visible.height - 12 : 4000
        let size = NSSize(width: PanelView.width, height: min(ceil(fitted.height), maxHeight))
        guard size.height > 0 else { return }
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

    /// Wolkky, Wolkk's mascot, sized for the menu bar. Full color (not a template image).
    static let icon: NSImage = {
        let src = WolkkyImage.image
        guard src.size.width > 0 else { return src }
        let h: CGFloat = 15
        let size = NSSize(width: (src.size.width / src.size.height * h).rounded(), height: h)
        let img = NSImage(size: size, flipped: false) { rect in
            src.draw(in: rect)
            return true
        }
        img.isTemplate = false
        img.accessibilityDescription = "Wolkky Claude Status"
        return img
    }()
}

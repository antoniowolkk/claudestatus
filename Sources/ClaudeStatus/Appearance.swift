import AppKit
import SwiftUI

/// Light by default; dark when the user turns on Dark mode in Settings.
/// Independent of the system appearance.
enum AppAppearance {
    static var isDark: Bool { UserDefaults.standard.bool(forKey: Prefs.darkMode) }

    static var nsAppearance: NSAppearance? {
        NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// Applies the current choice to the whole app and every open window.
    @MainActor
    static func apply() {
        let a = nsAppearance
        NSApp.appearance = a
        for w in NSApp.windows { w.appearance = a }
    }
}

/// Sets SwiftUI's color scheme from the Dark mode setting and follows changes live.
struct AppearanceScope: ViewModifier {
    @AppStorage(Prefs.darkMode) private var dark = false
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, dark ? .dark : .light)
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppearanceScope()) }
}

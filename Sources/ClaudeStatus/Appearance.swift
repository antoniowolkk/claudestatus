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

/// Applies the Dark mode and Language settings and follows changes live.
/// Changing the language rebuilds the view so every `L(...)` string is re-read.
struct AppearanceScope: ViewModifier {
    @AppStorage(Prefs.darkMode) private var dark = false
    @AppStorage(Prefs.language) private var language = "system"
    func body(content: Content) -> some View {
        content
            .id(language)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.locale, Locale(identifier: AppLanguage.resolved.rawValue))
    }
}

struct LanguagePicker: View {
    @AppStorage(Prefs.language) private var language = "system"
    var body: some View {
        Picker(L("Language"), selection: $language) {
            ForEach(AppLanguage.allCases) { Text($0.label).tag($0.rawValue) }
        }
    }
}

extension View {
    func appAppearance() -> some View { modifier(AppearanceScope()) }
}

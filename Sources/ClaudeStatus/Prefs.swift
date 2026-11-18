import Foundation

/// UserDefaults keys. Settings live in the app's own sandbox container.
enum Prefs {
    static let refreshInterval = "refreshInterval"
    static let includeCacheReads = "includeCacheReads"
    static let tokenBudget = "tokenBudget"
    static let darkMode = "darkMode"
    static let onboarded = "onboarded"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            refreshInterval: 20,
            includeCacheReads: false,
            tokenBudget: 0,
            darkMode: false,
            onboarded: false,
        ])
    }
}

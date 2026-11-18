import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS").font(Theme.label(11)).tracking(2.4).foregroundStyle(Theme.sub)
                Spacer()
                Picker("", selection: $tab) {
                    Text("General").tag(0)
                    Text("Privacy").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
            .padding(.horizontal, 20)
            .padding(.top, 34)
            .padding(.bottom, 14)

            ScrollView {
                Group {
                    switch tab {
                    case 0: GeneralSettings()
                    default: PrivacySettings()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 520, height: 460)
        .background(GridBackground())
    }
}

private struct Section<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(Theme.label(9)).tracking(1.6).foregroundStyle(Theme.accent)
            HUDCard { VStack(alignment: .leading, spacing: 10) { content } }
        }
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject var store: UsageStore
    @AppStorage(Prefs.includeCacheReads) private var includeCacheReads = false
    @AppStorage(Prefs.refreshInterval) private var refresh = 20
    @AppStorage(Prefs.tokenBudget) private var budget = 0
    @AppStorage(Prefs.darkMode) private var darkMode = false
    @State private var login = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section(title: "Appearance") {
                Toggle("Dark mode", isOn: $darkMode)
                    .onChange(of: darkMode) { AppAppearance.apply() }
                Text("Off keeps the app light, whatever your Mac is set to.")
                    .font(.system(size: 11)).foregroundStyle(Theme.sub)
            }
            Section(title: "Usage") {
                Toggle("Count cache reads as tokens", isOn: $includeCacheReads)
                Text("Cache reads are cheap and can be very large. Off shows input, output and cache writes.")
                    .font(.system(size: 11)).foregroundStyle(Theme.sub)
                HStack {
                    Text("5-hour token budget")
                    Spacer()
                    TextField("0", value: $budget, format: .number)
                        .frame(width: 110)
                        .multilineTextAlignment(.trailing)
                }
                Text("Set a budget to show the ring as % used. 0 shows time left instead.")
                    .font(.system(size: 11)).foregroundStyle(Theme.sub)
                Picker("Refresh every", selection: $refresh) {
                    Text("10 seconds").tag(10)
                    Text("20 seconds").tag(20)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
                .onChange(of: refresh) { store.start() }
            }
            Section(title: "Startup") {
                Toggle("Open at login", isOn: $login)
                    .onChange(of: login) { _, on in
                        loginError = LoginItem.set(on)
                        login = LoginItem.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.system(size: 11)).foregroundStyle(Theme.danger)
                }
                Button("Run setup again") { WindowManager.shared.showOnboarding() }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 12))
    }
}

private struct PrivacySettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section(title: "What this app reads") {
                bullet("doc.text.magnifyingglass", "Claude Code logs in ~/.claude/projects, read-only. Only token counts, model, project folder, branch and surface are kept, in memory.")
            }
            Section(title: "What it never does") {
                bullet("wifi.slash", "No network access. The App Sandbox blocks it.")
                bullet("key", "No API keys, passwords or accounts.")
                bullet("eye.slash", "No telemetry, analytics or crash reporting.")
                bullet("pencil.slash", "Never writes to your Claude files.")
            }
            HStack {
                Button("Show logs folder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: LogScanner.projectsDir)
                }
                Spacer()
                Text("Cost is an estimate from public API prices.")
                    .font(.system(size: 10)).foregroundStyle(Theme.faint)
            }
        }
        .font(.system(size: 12))
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 16)
            Text(text).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}

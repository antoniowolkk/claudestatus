import SwiftUI
import AppKit

/// First-run setup: checks access to logs, picks menu bar and startup options.
struct OnboardingView: View {
    @EnvironmentObject var store: UsageStore
    @State private var step = 0
    @AppStorage(Prefs.showTokens) private var showTokens = true
    @AppStorage(Prefs.showModel) private var showModel = true
    @AppStorage(Prefs.showProject) private var showProject = true
    @State private var login = LoginItem.isEnabled
    @State private var loginError: String?

    private let steps = ["Welcome", "Data", "Menu bar"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
                .padding(.horizontal, 28)
                .padding(.top, 38)

            Group {
                switch step {
                case 0: welcome
                case 1: data
                default: menuBar
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                Button(step == steps.count - 1 ? "Finish" : "Continue") {
                    if step == steps.count - 1 { finish() } else { step += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding(20)
        }
        .frame(width: 560, height: 440)
        .background(GridBackground())
        .font(.system(size: 13))
        .toggleStyle(.switch)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Capsule()
                        .fill(i <= step ? AnyShapeStyle(Theme.ring) : AnyShapeStyle(Theme.hair))
                        .frame(height: 3)
                    Text("\(String(format: "%02d", i + 1)) \(steps[i].uppercased())")
                        .font(Theme.label(9)).tracking(1.2)
                        .foregroundStyle(i == step ? Theme.accent : Theme.faint)
                }
            }
        }
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(sub).foregroundStyle(Theme.sub).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 14)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Claude Status", "A light menu bar readout for Claude Code: token usage in your 5-hour window, the model you're on, and which project folders Claude is working in.")
            feature("gauge.with.needle", "Live token usage", "Session, today, 7 days and the current 5-hour window.")
            feature("folder", "Projects at a glance", "The folder you're in now, plus every project active in the last 24 hours.")
            feature("lock.shield", "Private by design", "Reads local logs only. No network, no keys, no telemetry.")
        }
    }

    private var data: some View {
        let snap = store.snapshot
        let ok = snap.error == nil && snap.filesScanned > 0
        return VStack(alignment: .leading, spacing: 12) {
            title("Check data access", "Claude Status reads Claude Code's session logs, read-only.")
            HUDCard(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ok ? Theme.live : Theme.amber)
                        Text(ok ? "Logs found" : "No logs yet").font(.system(size: 13, weight: .semibold))
                    }
                    Text(LogScanner.projectsDir).font(Theme.mono(11)).foregroundStyle(Theme.sub).textSelection(.enabled)
                    if ok {
                        Text("\(snap.filesScanned) recent session files · \(Fmt.compact(snap.week.tokens(includeCacheReads: false))) tokens in the last 7 days")
                            .font(Theme.mono(11)).foregroundStyle(Theme.ink)
                    } else {
                        Text(snap.error?.message ?? "Run a Claude Code session, then check again.")
                            .font(.system(size: 12)).foregroundStyle(Theme.sub)
                    }
                }
            }
            Button {
                Task { await store.refresh() }
            } label: { Label("Check again", systemImage: "arrow.clockwise") }
        }
    }

    private var menuBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Menu bar", "Pick what shows next to the icon. Click the icon any time for the full panel.")
            HUDCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Tokens", isOn: $showTokens)
                    Toggle("Model", isOn: $showModel)
                    Toggle("Project folder", isOn: $showProject)
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                        Text(store.menuBarText.isEmpty ? " " : store.menuBarText)
                    }
                    .font(Theme.mono(12, .medium))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.hair))
                    Divider()
                    Toggle("Open at login", isOn: $login)
                        .onChange(of: login) { _, on in
                            loginError = LoginItem.set(on)
                            login = LoginItem.isEnabled
                        }
                    if let loginError {
                        Text(loginError).font(.system(size: 11)).foregroundStyle(Theme.danger)
                    }
                }
            }
        }
    }

    private func feature(_ icon: String, _ head: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ring)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent.opacity(0.07)))
            VStack(alignment: .leading, spacing: 2) {
                Text(head).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(body).font(.system(size: 12)).foregroundStyle(Theme.sub)
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Prefs.onboarded)
        WindowManager.shared.close("onboarding")
    }
}

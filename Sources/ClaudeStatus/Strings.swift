import Foundation

/// App languages. "System" follows the Mac's preferred language and falls back to English.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, de, ja

    var id: String { rawValue }

    /// Shown in the language picker, each in its own language.
    var label: String {
        switch self {
        case .system: return L("System")
        case .en: return "English"
        case .de: return "Deutsch"
        case .ja: return "日本語"
        }
    }

    static var resolved: AppLanguage {
        let pref = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Prefs.language) ?? "system") ?? .system
        if pref != .system { return pref }
        for code in Locale.preferredLanguages {
            if code.hasPrefix("de") { return .de }
            if code.hasPrefix("ja") { return .ja }
            if code.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// Translates an English UI string. Unknown keys fall back to English.
/// Supports `String(format:)` placeholders: `L("%d more", 3)`.
func L(_ key: String, _ args: CVarArg...) -> String {
    let lang = AppLanguage.resolved
    let template: String
    switch lang {
    case .de: template = Strings.table[key]?.de ?? key
    case .ja: template = Strings.table[key]?.ja ?? key
    default: template = key
    }
    return args.isEmpty ? template : String(format: template, arguments: args)
}

enum Strings {
    static let table: [String: (de: String, ja: String)] = [
        // Panel
        "Logs not found": ("Keine Logs gefunden", "ログが見つかりません"),
        "No Claude Code logs found at %@.": ("Keine Claude-Code-Logs unter %@ gefunden.", "%@ に Claude Code のログが見つかりません。"),
        "Can't read %@.": ("%@ kann nicht gelesen werden.", "%@ を読み取れません。"),
        "Run a Claude Code session, then refresh.": ("Starte eine Claude-Code-Sitzung und aktualisiere dann.", "Claude Code のセッションを実行してから更新してください。"),
        "Scanning logs": ("Logs werden gelesen", "ログを読み込み中"),
        "No recent activity": ("Keine aktuelle Aktivität", "最近のアクティビティはありません"),
        "Usage shows up here after your next Claude Code message.": ("Die Nutzung erscheint hier nach deiner nächsten Claude-Code-Nachricht.", "次の Claude Code メッセージの後に使用量がここに表示されます。"),
        "LIVE": ("LIVE", "稼働中"),
        "IDLE": ("INAKTIV", "待機中"),
        "IDLE · %@": ("INAKTIV · %@", "待機中 · %@"),
        "BUDGET": ("BUDGET", "予算"),
        "LEFT": ("ÜBRIG", "残り"),
        "5-HOUR WINDOW": ("5-STUNDEN-FENSTER", "5時間ウィンドウ"),
        "tokens": ("Tokens", "トークン"),
        "tokens incl. cache reads": ("Tokens inkl. Cache-Lesezugriffe", "トークン（キャッシュ読み込みを含む）"),
        "resets %@": ("Reset %@", "%@ にリセット"),
        "Starts with your next message": ("Startet mit deiner nächsten Nachricht", "次のメッセージで開始します"),
        "SESSION": ("SITZUNG", "セッション"),
        "TODAY": ("HEUTE", "今日"),
        "7 DAYS": ("7 TAGE", "7日間"),
        "CACHE": ("CACHE", "キャッシュ"),
        "hit today": ("Treffer", "ヒット率"),
        "ACTIVE PROJECTS": ("AKTIVE PROJEKTE", "アクティブなプロジェクト"),
        "LAST 24H": ("LETZTE 24 STD.", "過去24時間"),
        "+%d more": ("+%d weitere", "他 %d 件"),
        "ACTIVE": ("AKTIV", "作業中"),
        "%d worktree": ("%d Worktree", "ワークツリー %d 個"),
        "%d worktrees": ("%d Worktrees", "ワークツリー %d 個"),
        "no branch": ("kein Branch", "ブランチなし"),
        "Open setup": ("Einrichtung öffnen", "セットアップを開く"),
        "SYNC %@": ("SYNC %@", "同期 %@"),
        "SYNCING": ("SYNCHRONISIERE", "同期中"),
        "Refresh": ("Aktualisieren", "更新"),
        "Settings": ("Einstellungen", "設定"),
        "Quit Claude Status": ("Claude Status beenden", "Claude Status を終了"),
        "%@ tokens": ("%@ Tokens", "%@ トークン"),

        // Time
        "just now": ("gerade eben", "たった今"),
        "%ds ago": ("vor %d s", "%d秒前"),
        "%dm ago": ("vor %d Min.", "%d分前"),
        "%dh ago": ("vor %d Std.", "%d時間前"),
        "%dd ago": ("vor %d T.", "%d日前"),
        "%dh %dm": ("%dh %dm", "%d時間%d分"),
        "%dm": ("%d Min.", "%d分"),
        "<1m": ("<1 Min.", "1分未満"),


        // Settings
        "SETTINGS": ("EINSTELLUNGEN", "設定"),
        "General": ("Allgemein", "一般"),
        "Privacy": ("Datenschutz", "プライバシー"),
        "Appearance": ("Darstellung", "外観"),
        "Dark mode": ("Dunkelmodus", "ダークモード"),
        "Off keeps the app light, whatever your Mac is set to.": ("Aus: Die App bleibt hell, egal wie dein Mac eingestellt ist.", "オフの場合、Mac の設定に関係なくライト表示になります。"),
        "Language": ("Sprache", "言語"),
        "System": ("System", "システム"),
        "Usage": ("Nutzung", "使用量"),
        "Count cache reads as tokens": ("Cache-Lesezugriffe als Tokens zählen", "キャッシュ読み込みをトークンに含める"),
        "Cache reads are cheap and can be very large. Off shows input, output and cache writes.": ("Cache-Lesezugriffe sind günstig, können aber sehr groß sein. Aus zeigt Eingabe, Ausgabe und Cache-Schreibzugriffe.", "キャッシュ読み込みは安価ですが、非常に大きくなることがあります。オフの場合は入力・出力・キャッシュ書き込みを表示します。"),
        "5-hour token budget": ("Token-Budget pro 5 Stunden", "5時間あたりのトークン予算"),
        "Set a budget to show the ring as % used. 0 shows time left instead.": ("Mit Budget zeigt der Ring den Verbrauch in %. 0 zeigt stattdessen die Restzeit.", "予算を設定するとリングに使用率（%）を表示します。0 の場合は残り時間を表示します。"),
        "Refresh every": ("Aktualisieren alle", "更新間隔"),
        "10 seconds": ("10 Sekunden", "10秒"),
        "20 seconds": ("20 Sekunden", "20秒"),
        "1 minute": ("1 Minute", "1分"),
        "5 minutes": ("5 Minuten", "5分"),
        "Startup": ("Start", "起動"),
        "Open at login": ("Bei Anmeldung öffnen", "ログイン時に開く"),
        "Run setup again": ("Einrichtung erneut starten", "セットアップをやり直す"),
        "What this app reads": ("Was diese App liest", "このアプリが読み取るもの"),
        "Claude Code logs in ~/.claude/projects, read-only. Only token counts, model, project folder, branch and surface are kept, in memory.": ("Claude-Code-Logs in ~/.claude/projects, nur lesend. Nur Token-Zahlen, Modell, Projektordner, Branch und Umgebung bleiben erhalten – im Arbeitsspeicher.", "~/.claude/projects 内の Claude Code ログ（読み取り専用）。トークン数、モデル、プロジェクトフォルダ、ブランチ、実行環境のみをメモリ上に保持します。"),
        "What it never does": ("Was sie nie tut", "このアプリが行わないこと"),
        "No network access. The App Sandbox blocks it.": ("Kein Netzwerkzugriff. Die App-Sandbox blockiert ihn.", "ネットワークにはアクセスしません。App Sandbox によりブロックされています。"),
        "No API keys, passwords or accounts.": ("Keine API-Schlüssel, Passwörter oder Konten.", "API キー、パスワード、アカウントは使用しません。"),
        "No telemetry, analytics or crash reporting.": ("Keine Telemetrie, Analysen oder Absturzberichte.", "テレメトリ、分析、クラッシュレポートは送信しません。"),
        "Never writes to your Claude files.": ("Schreibt nie in deine Claude-Dateien.", "Claude のファイルに書き込むことはありません。"),
        "Show logs folder": ("Log-Ordner zeigen", "ログフォルダを表示"),
        "Cost is an estimate from public API prices.": ("Kosten sind eine Schätzung anhand öffentlicher API-Preise.", "コストは公開 API 価格に基づく概算です。"),

        // Setup
        "Welcome": ("Willkommen", "ようこそ"),
        "Data": ("Daten", "データ"),
        "Menu bar": ("Menüleiste", "メニューバー"),
        "Back": ("Zurück", "戻る"),
        "Finish": ("Fertig", "完了"),
        "Continue": ("Weiter", "続ける"),
        "A light menu bar readout for Claude Code: token usage in your 5-hour window, the model you're on, and which project folders Claude is working in.": ("Eine leichte Menüleisten-Anzeige für Claude Code: Token-Nutzung im 5-Stunden-Fenster, das aktuelle Modell und die Projektordner, in denen Claude gerade arbeitet.", "Claude Code のための軽量なメニューバー表示。5時間ウィンドウのトークン使用量、使用中のモデル、Claude が作業中のプロジェクトフォルダがわかります。"),
        "Live token usage": ("Token-Nutzung live", "リアルタイムのトークン使用量"),
        "Session, today, 7 days and the current 5-hour window.": ("Sitzung, heute, 7 Tage und das aktuelle 5-Stunden-Fenster.", "セッション、今日、7日間、現在の5時間ウィンドウ。"),
        "Projects at a glance": ("Projekte auf einen Blick", "プロジェクトをひと目で"),
        "The folder you're in now, plus every project active in the last 24 hours.": ("Der Ordner, in dem du gerade arbeitest, und jedes Projekt der letzten 24 Stunden.", "現在のフォルダと、過去24時間に作業したすべてのプロジェクト。"),
        "Private by design": ("Privat von Grund auf", "プライバシー重視の設計"),
        "Reads local logs only. No network, no keys, no telemetry.": ("Liest nur lokale Logs. Kein Netzwerk, keine Schlüssel, keine Telemetrie.", "ローカルのログのみを読み取ります。ネットワーク、キー、テレメトリは使いません。"),
        "Check data access": ("Datenzugriff prüfen", "データへのアクセスを確認"),
        "Claude Status reads Claude Code's session logs, read-only.": ("Claude Status liest die Sitzungs-Logs von Claude Code – nur lesend.", "Claude Status は Claude Code のセッションログを読み取り専用で読み込みます。"),
        "Logs found": ("Logs gefunden", "ログが見つかりました"),
        "No logs yet": ("Noch keine Logs", "まだログがありません"),
        "%d recent session files · %@ tokens in the last 7 days": ("%d aktuelle Sitzungsdateien · %@ Tokens in den letzten 7 Tagen", "最近のセッションファイル %d 件 · 過去7日間で %@ トークン"),
        "Run a Claude Code session, then check again.": ("Starte eine Claude-Code-Sitzung und prüfe dann erneut.", "Claude Code のセッションを実行してから、もう一度確認してください。"),
        "Check again": ("Erneut prüfen", "再確認"),
        "Claude Status lives in your menu bar as a single icon. Click it for the full panel; hover it for a quick summary.": ("Claude Status sitzt als einzelnes Symbol in deiner Menüleiste. Klicke darauf für das ganze Panel, fahre darüber für eine kurze Übersicht.", "Claude Status はメニューバーにアイコンとして表示されます。クリックでパネルを開き、カーソルを合わせると概要を表示します。"),
        "Look for this icon at the top right of your screen.": ("Du findest dieses Symbol oben rechts auf deinem Bildschirm.", "画面右上にあるこのアイコンを探してください。"),
        "Welcome to Claude Status": ("Willkommen bei Claude Status", "Claude Status へようこそ"),
        "Claude Status Settings": ("Claude Status – Einstellungen", "Claude Status の設定"),
    ]
}

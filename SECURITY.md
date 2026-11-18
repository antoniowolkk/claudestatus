# Security

## Design

Claude Status is built to need as little trust as possible:

- **App Sandbox on, no network entitlement.** The app can't open network connections.
- **Read-only file access** to exactly one folder, `~/.claude/projects/` (Claude Code session logs), declared in [`Resources/ClaudeStatus.entitlements`](Resources/ClaudeStatus.entitlements).
- **Hardened runtime** signing.
- **Minimal data in memory.** The parser keeps token counts, model, project folder, branch and surface. Message text, tool inputs and outputs are discarded.
- **No secrets.** The app never asks for or stores API keys, tokens or passwords.
- **No telemetry** of any kind.
- **Defensive parsing.** Symlinks are skipped, oversized lines are dropped, and invalid JSON is ignored.
- **Source install.** `install.sh` builds from the code in this repository. It downloads nothing and only uses `sudo` when you choose `/Applications` and it isn't writable.

You can check the sandbox yourself:

```bash
codesign -d --entitlements - "$HOME/Applications/Claude Status.app"
```

## Reporting a vulnerability

Please report security issues privately through
[GitHub Security Advisories](https://github.com/antoniowolkk/claudestatus/security/advisories/new)
rather than a public issue. Include steps to reproduce and the macOS version.

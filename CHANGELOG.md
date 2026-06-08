# Changelog

All notable changes to ledger are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [1.0.0] — 2026-06-08

First public release.

### Added
- **Living files** — `SESSION.md`, `TRACKER.md`, `GOALS.md`, `DECISIONS.md`, `MISTAKES.md`, `LOG.md` as the source of truth for project state.
- **Auto-catchup** (`ledger-catchup.sh`, SessionStart) — injects a briefing with the exact next step, in-progress + blocked tasks, and a commits-since-last-session delta.
- **Auto-checkpoint** (`ledger-checkpoint.sh`, PreCompact + SessionEnd) — snapshots `SESSION.md`, appends `LOG.md`, commits the living files. Preserves a rich `/ledger handoff` instead of overwriting it.
- **Drift nudge** (`ledger-drift.sh`, UserPromptSubmit) — debounced reminder, only when state lags behind the work.
- **HTML dashboard** (`ledger-dashboard.sh` + `state-dashboard.ts`) — auto-regenerated, read-only view of the board. Optional; degrades silently without a TS runtime.
- **`/ledger` skill** with `handoff`, `catchup`, `status`, `board`, `dashboard`, and `init` modes.
- **`/ledger init`** (`ledger-init.sh`) — idempotent, opt-in per-project bootstrap of the living files.
- Plugin packaging with auto-registering `hooks/hooks.json`, plus a standalone-skill install path.

### Design
- All hooks are **non-blocking** — no `Stop` hook (avoids the extended-thinking API conflict).
- The tracking core is **zero-dependency** (bash + git); only the dashboard wants `bun`/`tsx`.
- Commits **only** the living Markdown files, never your code.
- Creates **no** files until `/ledger init` — tracking is opt-in per project.

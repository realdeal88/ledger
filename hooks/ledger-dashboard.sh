#!/bin/bash
# ledger-dashboard.sh — PostToolUse Edit|Write (async). Debounced state.html regen.
# Instant no-op unless the edited file is a living file. Debounced (45s) to avoid per-edit CPU.
# Self-locating (finds the bundled dashboard script) + runtime-detected (bun→tsx). The HTML
# dashboard is optional eye-candy; if no TS runtime is present this simply does nothing and
# the Markdown living files remain the full source of truth.
set -u

INPUT="$(cat 2>/dev/null)"
FILE="$(printf '%s' "$INPUT" | (command -v jq >/dev/null 2>&1 && jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true))"
[ -z "$FILE" ] && exit 0

case "$(basename "$FILE")" in
  SESSION.md|TRACKER.md|GOALS.md|LOG.md|DECISIONS.md|MISTAKES.md) : ;;
  *) exit 0 ;;
esac

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
PLUGIN_ROOT="$(dirname "$SELF_DIR")"
DASH_TS="$PLUGIN_ROOT/skills/ledger/scripts/state-dashboard.ts"
[ -f "$DASH_TS" ] || exit 0

DIR="$(dirname "$FILE")"
# climb to the project root (the dir that actually holds the living-file set)
[ -f "$DIR/TRACKER.md" ] || DIR="$(dirname "$DIR")"

STATE_DIR="${TMPDIR:-/tmp}/ledger-hooks"; mkdir -p "$STATE_DIR" 2>/dev/null
KEY="$(printf '%s' "$DIR" | sed 's#/#-#g')"
LOCK="$STATE_DIR/$KEY.dash"
NOW="$(date +%s)"; LAST=0; [ -f "$LOCK" ] && LAST="$(cat "$LOCK" 2>/dev/null || echo 0)"
[ $((NOW - LAST)) -lt 45 ] && exit 0
echo "$NOW" > "$LOCK"

# Portable timeout: macOS ships neither `timeout` nor `gtimeout` without coreutils.
TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 12"; command -v gtimeout >/dev/null 2>&1 && TO="gtimeout 12"
if command -v bun >/dev/null 2>&1; then
  $TO bun "$DASH_TS" "$DIR" >/dev/null 2>&1 || true
elif command -v npx >/dev/null 2>&1; then
  $TO npx --yes tsx "$DASH_TS" "$DIR" >/dev/null 2>&1 || true
fi
exit 0

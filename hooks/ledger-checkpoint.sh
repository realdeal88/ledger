#!/bin/bash
# ledger-checkpoint.sh [precompact|sessionend] — unified, non-blocking state checkpoint.
# Fires at PreCompact and SessionEnd. One project-type detection pass:
#
#   living-file project (GOALS+TRACKER+LOG): snapshot SESSION.md (unless a RICH one was
#       written this session by the skill), append LOG, commit the living files, regen dashboard.
#   canon project (CLAUDE.md+SESSION.md, no trio): append a marker, never overwrite.
#
# Always safe: writes files + git-commits the living files ONLY (never code); never blocks.
# Self-locating — finds the bundled dashboard script relative to itself, so it is portable
# whether installed as a plugin or run directly. Dashboard regen is best-effort (bun→tsx).
set -u

MODE="${1:-checkpoint}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
PLUGIN_ROOT="$(dirname "$SELF_DIR")"
DASH_TS="$PLUGIN_ROOT/skills/ledger/scripts/state-dashboard.ts"

CWD="${PWD:-$(pwd)}"
case "$CWD" in "$HOME"|"/tmp"*|"/var"*|"/") exit 0 ;; esac

# Climb one level if invoked from a subdirectory (src/, etc.)
if [ ! -f "$CWD/GOALS.md" ] && [ ! -f "$CWD/CLAUDE.md" ]; then
  P="$(dirname "$CWD")"
  if [ -f "$P/GOALS.md" ] || [ -f "$P/CLAUDE.md" ]; then CWD="$P"; fi
fi
cd "$CWD" 2>/dev/null || exit 0

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE="$(date -u +%Y-%m-%d)"
PROJECT="$(basename "$CWD")"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo no-git)"
LAST_COMMIT="$(git log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"
UNCOMMITTED="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
MODE_UC="$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"

regen_dashboard() {
  [ -f "$DASH_TS" ] || return 0
  # Portable timeout (macOS ships neither without coreutils).
  local TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 12"; command -v gtimeout >/dev/null 2>&1 && TO="gtimeout 12"
  if command -v bun >/dev/null 2>&1; then
    $TO bun "$DASH_TS" "$CWD" >/dev/null 2>&1 || true
  elif command -v npx >/dev/null 2>&1; then
    $TO npx --yes tsx "$DASH_TS" "$CWD" >/dev/null 2>&1 || true
  fi
}

# ── canon project (no living-file trio) ──
if [ ! -f "GOALS.md" ] || [ ! -f "TRACKER.md" ] || [ ! -f "LOG.md" ]; then
  if [ -f "CLAUDE.md" ] && [ -f "SESSION.md" ]; then
    printf '\n<!-- LEDGER %s %s | branch:%s | last:%s | uncommitted:%s | continuity lives in the canon files — re-read after compaction; nothing important is lost. -->\n' \
      "$MODE_UC" "$TS" "$GIT_BRANCH" "$LAST_COMMIT" "$UNCOMMITTED" >> "SESSION.md" 2>/dev/null
  fi
  exit 0
fi

# ── living-file project ──
[ -f MISTAKES.md ] || printf '# MISTAKES — append-only failure log\n\n---\n' > MISTAKES.md
[ -f DECISIONS.md ] || printf '# DECISIONS — append-only architecture decision log\n\n---\n' > DECISIONS.md

ACTIVE_TASKS="$(grep -E '^\- \[~\]' TRACKER.md 2>/dev/null | head -10)"
BLOCKED_TASKS="$(grep -E '^\- \[!\]' TRACKER.md 2>/dev/null | head -5)"

# Preserve a rich SESSION.md written this session by the ledger/handoff skill.
RICH=false
if [ -f SESSION.md ] && grep -m1 '^source:' SESSION.md 2>/dev/null | grep -qiE 'ledger-handoff|rich|/handoff'; then
  RICH=true
fi

if [ "$RICH" = true ]; then
  printf '\n<!-- LEDGER %s %s | rich SESSION.md preserved | branch:%s | uncommitted:%s -->\n' \
    "$MODE_UC" "$TS" "$GIT_BRANCH" "$UNCOMMITTED" >> SESSION.md
  printf '\n- %s — %s checkpoint (rich SESSION.md preserved)\n' "$TS" "$MODE" >> LOG.md
else
  GIT_STAT="$(git diff --stat 2>/dev/null | tail -15)"
  GIT_STATUS_SHORT="$(git status --short 2>/dev/null | head -12)"
  cat > SESSION.md << EOF
---
handoff_time: ${TS}
session_topic: ${MODE} auto-snapshot
project: ${PROJECT}
source: ledger-checkpoint (shell-level — run /ledger for a rich handoff next time)
---

## Active Tasks (resume these)
${ACTIVE_TASKS:-No [~] tasks in TRACKER.md at checkpoint}

## Blocked
${BLOCKED_TASKS:-None}

## Git State
Branch: ${GIT_BRANCH} · Uncommitted: ${UNCOMMITTED} files
Last commit: ${LAST_COMMIT}

Diff stat:
${GIT_STAT:-clean}

Status:
${GIT_STATUS_SHORT:-clean}

## Exact Next Step
[shell snapshot — not a rich handoff] Read TRACKER.md [~] tasks and resume the first.
Run /ledger for full restoration.

## Context to Preserve
[shell snapshot cannot capture in-session reasoning] Check git diff + LOG.md tail.
EOF
  {
    printf '\n---\n\n## %s — %s checkpoint at %s\n\n' "$DATE" "$MODE" "$TS"
    printf -- '- Branch: %s · last: %s · uncommitted: %s files\n' "$GIT_BRANCH" "$LAST_COMMIT" "$UNCOMMITTED"
    [ -n "$ACTIVE_TASKS" ] && printf -- '- Active: %s in-progress\n' "$(printf '%s' "$ACTIVE_TASKS" | grep -c .)"
    printf -- '- SESSION.md snapshot written · resume with /ledger\n'
  } >> LOG.md
fi

# Stage + commit the living files only (never code).
for f in SESSION.md LOG.md GOALS.md TRACKER.md MISTAKES.md DECISIONS.md RULES.md; do
  [ -f "$f" ] && git add "$f" 2>/dev/null
done
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "docs: ledger ${MODE} checkpoint — ${TS}" --no-verify >/dev/null 2>&1 || true
fi

regen_dashboard
exit 0

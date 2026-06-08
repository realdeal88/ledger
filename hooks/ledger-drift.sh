#!/bin/bash
# ledger-drift.sh — UserPromptSubmit (sync, must be FAST).
# Smart, debounced nudge to keep state current. Silent on the vast majority of prompts.
# Only speaks when: living-file project, >25min since the last nudge, there ARE uncommitted
# CODE changes, and NONE of them are living files (i.e. state is drifting behind the work).
# Zero dependencies. State (the debounce timer) lives in a throwaway tmp dir.
set -u

CWD="${PWD:-$(pwd)}"
case "$CWD" in "$HOME"|"/tmp"*|"/var"*|"/") exit 0 ;; esac
[ -f "$CWD/TRACKER.md" ] && [ -f "$CWD/LOG.md" ] || exit 0

NOW="$(date +%s)"
STATE_DIR="${TMPDIR:-/tmp}/ledger-hooks"; mkdir -p "$STATE_DIR" 2>/dev/null
KEY="$(printf '%s' "$CWD" | sed 's#/#-#g')"
NUDGE_FILE="$STATE_DIR/$KEY.nudge"
LAST=0; [ -f "$NUDGE_FILE" ] && LAST="$(cat "$NUDGE_FILE" 2>/dev/null || echo 0)"
INTERVAL=1500   # 25 min

[ $((NOW - LAST)) -lt $INTERVAL ] && exit 0

PORC="$(git -C "$CWD" status --porcelain 2>/dev/null)"
DIRTY="$(printf '%s' "$PORC" | grep -c . )"
[ "${DIRTY:-0}" -lt 1 ] && exit 0

# If a living file is among the changes, state IS being kept — stay silent.
if printf '%s' "$PORC" | grep -qE '(SESSION|TRACKER|GOALS|LOG|DECISIONS|MISTAKES)\.md'; then
  echo "$NOW" > "$NUDGE_FILE"   # reset timer; work is being tracked
  exit 0
fi

echo "$NOW" > "$NUDGE_FILE"
echo "── ledger nudge ── ${DIRTY} uncommitted change(s) and the living files haven't moved. Mark the task [~]/[x] in TRACKER.md and note anything load-bearing — it auto-snapshots at compaction/session-end regardless, but a one-line update now resumes far better."
exit 0

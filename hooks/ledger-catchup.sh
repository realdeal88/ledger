#!/bin/bash
# ledger-catchup.sh — SessionStart (sync, non-blocking).
# Injects an auto-catchup briefing for living-file / canon projects: the exact next step
# from SESSION.md, in-progress + blocked tasks, and a "since last session" delta.
# Pure text on stdout (context injection) — never blocks, never returns decision:block.
# Zero dependencies (bash + git). Safe-by-default: silent unless the project opted in
# by running /ledger init (i.e. the living files already exist).
set -u

CWD="${PWD:-$(pwd)}"
case "$CWD" in "$HOME"|"/tmp"*|"/var"*|"/") exit 0 ;; esac

LF=false; CANON=false
if [ -f "$CWD/GOALS.md" ] && [ -f "$CWD/TRACKER.md" ] && [ -f "$CWD/LOG.md" ]; then
  LF=true
elif [ -f "$CWD/CLAUDE.md" ] && [ -f "$CWD/SESSION.md" ]; then
  CANON=true
else
  exit 0
fi

echo "── ledger · auto-catchup ──"

if [ -f "$CWD/SESSION.md" ]; then
  TOPIC="$(grep -m1 '^session_topic:' "$CWD/SESSION.md" 2>/dev/null | sed 's/^session_topic:[[:space:]]*//')"
  [ -n "$TOPIC" ] && echo "• Last session: ${TOPIC}"
  NEXT="$(awk '/^## Exact Next Step/{f=1;next} /^## /{f=0} f' "$CWD/SESSION.md" 2>/dev/null | grep -vE '^[[:space:]]*$|<!--' | head -4)"
  [ -n "$NEXT" ] && { echo "• Exact next step:"; printf '%s\n' "$NEXT" | sed 's/^/    /'; }
fi

if [ "$LF" = true ]; then
  ACTIVE="$(grep -E '^\- \[~\]' "$CWD/TRACKER.md" 2>/dev/null | head -5)"
  BLOCKED="$(grep -E '^\- \[!\]' "$CWD/TRACKER.md" 2>/dev/null | head -3)"
  [ -n "$ACTIVE" ] && { echo "• In progress:"; printf '%s\n' "$ACTIVE" | sed 's/^/    /'; }
  [ -n "$BLOCKED" ] && { echo "• Blocked:"; printf '%s\n' "$BLOCKED" | sed 's/^/    /'; }
fi

LASTSNAP="$(grep -m1 '^handoff_time:' "$CWD/SESSION.md" 2>/dev/null | sed 's/^handoff_time:[[:space:]]*//')"
COMMITS_SINCE="$(git -C "$CWD" log --oneline --since="${LASTSNAP:-1 day ago}" 2>/dev/null | head -5)"
[ -n "$COMMITS_SINCE" ] && { echo "• Commits since last session:"; printf '%s\n' "$COMMITS_SINCE" | sed 's/^/    /'; }

DIRTY="$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
DASH="$CWD/.claude/state.html"
echo "• Working tree: ${DIRTY:-0} uncommitted file(s)."
[ -f "$DASH" ] && echo "• State dashboard: $DASH"
echo "• For a full restore run /ledger. Anything you 'remember' from before a restart is stale-by-default — verify against git + the living files."
exit 0

#!/bin/bash
# ledger-init.sh — bootstrap the canonical living files for the current project.
# Idempotent: only creates files that don't exist; never overwrites. Run by `/ledger init`,
# or by hand. Seeds GOALS.md from .claude/PROJECT.md if an intake exists. Zero dependencies.
set -u

CWD="${PWD:-$(pwd)}"
case "$CWD" in "$HOME"|"/tmp"*|"/var"*|"/") echo "ledger: refusing to init in $CWD"; exit 1 ;; esac
cd "$CWD" || exit 1

DATE="$(date -u +%Y-%m-%d)"
made=0
mk() { [ -f "$1" ] && return 0; printf '%s' "$2" > "$1"; echo "  + $1"; made=$((made+1)); }

mk GOALS.md "# GOALS

## Sprint: (name your current sprint)
**Goal:** (the one outcome this sprint is driving toward.)

### Must-haves
- [ ] (verifiable criterion 1)
- [ ] (verifiable criterion 2)

## ✅ Achieved
(completed must-haves move here with a date.)
"

mk TRACKER.md "# TRACKER

> Status grammar: \`[ ]\` todo · \`[~]\` in progress · \`[x]\` done · \`[!]\` blocked — reason · \`[-]\` deferred

## Now
- [~] (the task being worked on right now)

## Next
- [ ] (the next task)

## Done
- [x] ${DATE} — ledger initialized
"

mk LOG.md "# LOG — append-only history

- ${DATE} — ledger initialized.
"

mk DECISIONS.md "# DECISIONS — append-only architecture decision log

---
"

mk MISTAKES.md "# MISTAKES — append-only failure log

Format: date · what failed · why · detection signal · do-instead.

---
"

# Seed a richer GOALS.md goal line from an existing intake, if present and we just made GOALS.
if [ -f .claude/PROJECT.md ] && [ "$made" -gt 0 ]; then
  echo "  · .claude/PROJECT.md found — fold its goal + success criteria into GOALS.md."
fi

if [ "$made" -eq 0 ]; then
  echo "ledger: all living files already present — nothing to do."
else
  echo "ledger: initialized $made file(s). Edit GOALS.md + TRACKER.md, then just work — ledger keeps them current."
fi
exit 0

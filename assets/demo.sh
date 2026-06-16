#!/usr/bin/env bash
# Scripted demo of ledger for the README gif (rendered with assets/demo.tape via VHS).
# Output mirrors ledger's real session-start catchup briefing.
set -u

ACCENT=$'\033[38;2;79;182;163m'
GREEN=$'\033[38;2;126;200;140m'
YELLOW=$'\033[38;2;227;192;120m'
DIM=$'\033[38;2;140;140;150m'
BOLD=$'\033[1;38;2;236;236;241m'
WHITE=$'\033[38;2;210;210;218m'
R=$'\033[0m'

p() { printf '%b\n' "$1"; sleep "${2:-0.16}"; }

sleep 0.3
p "${DIM}new session — ledger runs itself${R}" 0.5
echo
p "${ACCENT}▌${R} ${BOLD}ledger${R} ${DIM}·${R} ${WHITE}catching up${R}" 0.4
echo
p "  ${DIM}last session${R}   ${WHITE}2h ago — shipped a plugin to GitHub, v1.0.0${R}"
p "  ${DIM}in flight${R}      ${WHITE}README demo gifs across the skill repos${R}"
p "  ${DIM}open decision${R}  ${WHITE}terminal-gif tool → settled on VHS${R}"
echo
p "  ${GREEN}✓${R} ${BOLD}living files${R}   ${WHITE}PROJECT.md · DECISIONS.md · STATE.md${R}  ${DIM}current${R}"
p "  ${GREEN}✓${R} ${BOLD}dashboard${R}      ${WHITE}.claude/state.html${R}  ${DIM}regenerated${R}"
p "  ${GREEN}✓${R} ${BOLD}handoff${R}        ${WHITE}auto-written on compact + session end${R}"
echo
sleep 0.3
p "  ${ACCENT}►${R} ${BOLD}resuming exactly where you left off${R}" 0.6
echo
sleep 1.2

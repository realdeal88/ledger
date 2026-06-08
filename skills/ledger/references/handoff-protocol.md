# Handoff & catchup protocol

A handoff and a catchup are two ends of the same wire. The handoff writes the state the *next* context window will wake up to; the catchup reads it back and reconciles it against ground truth (git, the files). This file is the schema for both — the exact `SESSION.md` shape to write, the order to read it back in, and the delta to compute on resume.

The thing to internalize: **the next session is the customer.** It wakes up cold — no memory of this conversation, only what's on disk. Everything expensive to rediscover (the exact next step, the dead-ends already ruled out, the load-bearing decision) has to be *written*, or it's lost. A shell snapshot is the floor; a rich handoff is the goal.

## The rich SESSION.md (8 sections)

`/ledger handoff` (and "save state" / "hand off") writes this. It **overwrites** `SESSION.md` — this is the one living file that is a fresh snapshot each time, not a growing log. Stamp it `source: ledger-handoff` in the header so `ledger-checkpoint.sh` knows a rich handoff already exists this session and preserves it instead of overwriting with a shell snapshot.

```markdown
# SESSION — <project>
<!-- source: ledger-handoff · <ISO date> -->

## 1. Goal
The one-sentence "why we're here" for this stretch of work. Pulled from GOALS.md's
sprint goal; restated so the next session needs zero other files to understand intent.

## 2. Where we are
Current state in 2–4 lines. What works now that didn't before. What's half-built.
The honest status — not "making progress" but "auth flow works end-to-end except the
refresh-token path, which 401s."

## 3. Exact next step
The single most important section. The literal next action, concrete enough to start
typing against. A file + function, a command to run, a specific decision to make.
"Wire the 401-retry interceptor in src/lib/api.ts:refresh() — the SW race is why the
cookie approach was abandoned (see §4)." NOT "continue working on auth."

## 4. What we tried (dead-ends)
The approaches already walked and abandoned, each with *why*. This is what stops the
next session re-walking a dead-end you already paid for. Mirror these to LOG.md as
`TRIED:` lines too (greppable). Omit only if nothing was abandoned.

## 5. Key decisions
The load-bearing "why"s made this session, with the alternative rejected. One line each.
These also belong in DECISIONS.md (append-only) — this is the digest, that is the record.

## 6. Evidence / verification state
What's actually been verified vs. assumed. "tests green (bun test, 24 pass) · typecheck
clean · OAuth flow NOT yet tested against real Google console." The next session must
know what it can trust and what it has to re-check.

## 7. Watch out for
Traps, sharp edges, things that look done but aren't, environmental gotchas (a flaky
service, a seed step, a required env var). Pulled forward from MISTAKES.md if relevant.

## 8. Quick start
The 1–3 commands to get from cold to working: `cd <dir> && bun dev`, the test account,
the seeded state. So the next session is productive in one paste, not ten minutes of setup.
```

Sections collapse to the work that exists — a 20-minute styling session doesn't need a dead-ends section. But §1, §3, and §6 (goal, next step, evidence) are always present: intent, the literal next action, and what's actually been proven. Those three are the irreducible core of a handoff.

## The catchup read-order

`/ledger catchup` (and the `ledger-catchup.sh` auto-briefing) restores context in this order — most volatile and highest-value first, so even a partial read orients you:

1. **`SESSION.md`** — the snapshot. The exact next step and current state. If a rich handoff was written, this alone is ~80% of the picture.
2. **`MISTAKES.md`** (tail) — what's already been learned the hard way, so you don't repeat it. Read *before* touching code.
3. **`TRACKER.md`** — the live board: what's `[~]` in progress, what's `[!]` blocked and why. This is "what's left."
4. **`GOALS.md`** — the sprint goal and must-have progress, to frame the next step against the larger target.
5. **`DECISIONS.md`** (tail) — the recent "why"s, so you don't re-litigate settled architecture or contradict a past call.

Then **reconcile against ground truth** — the files describe intent, git describes reality, and they drift:

## The delta (files vs. git)

Anything you "remember" or read from the files is **stale-by-default** until checked against the repo. Compute the delta on resume:

- **Commits since the handoff** — `git log --oneline <last-known>..HEAD`. Work may have landed (or a teammate pushed) after the snapshot was written. The auto-catchup hook surfaces the count; widen it when it's non-zero.
- **Working-tree state** — `git status --porcelain`. Uncommitted work means the last session stopped mid-change; that diff is usually *exactly* where the next step lives. Read it before trusting `SESSION.md`'s "where we are."
- **Branch** — confirm you're on the branch the handoff assumed. A handoff written on `feat/auth` is misleading if you woke up on `main`.

When the files and git disagree, **git wins for "what exists," the files win for "what we intended."** Reconcile out loud in the briefing: "SESSION says next step is the interceptor, but there are 3 uncommitted files in src/lib/ — looks like it was started. Reading the diff first."

## Why hook-enforced, not model-remembered

Every tracking system that depends on the model *remembering* to update state fails the same way: the one session that forgets is the one that crashes, and the state is gone. ledger's checkpoint fires mechanically at PreCompact and SessionEnd whether or not anyone remembered — so a snapshot **always exists**. The model's job isn't to remember to write; it's to make the guaranteed write *rich*. Floor guaranteed by the hook, ceiling raised by you.

---
name: ledger
description: The project's always-on memory — a living-files tracking system. Keeps GOALS/TRACKER/DECISIONS/MISTAKES/LOG/SESSION current so every session knows what's done, what's in progress, what's blocked, and the exact next step. Runs itself: auto-catchup at session start, auto-handoff at every compaction and session end, an auto-regenerating HTML dashboard. Replaces manual catchup/handoff with automatic hooks. Use /ledger to force a rich handoff now, restore context, show project state, open the dashboard, or initialize tracking. Triggers on "/ledger", "where are we", "what's left", "save state", "catch me up", "hand off", "update the tracker", or when resuming a project.
---

# ledger — the project's living memory

ledger is a **tracking system**, not an autonomy engine. Its only job is to remember: it keeps a small set of **living files** current so that any session — yours, or one after a compaction or restart — instantly knows what the project is, what's done, what's in progress, what's blocked, and the exact next step. Nothing it does forces work or continues on its own. It watches state and saves/restores it.

It runs **automatically** through non-blocking hooks (auto-catchup at start, auto-handoff at every compaction and session end, a debounced HTML dashboard). You rarely invoke it. `/ledger` is here for when you want to *force* a rich handoff, restore full context, or look at the board.

> **catchup and handoff are now phases of one system**, not commands you remember to run: catchup = session-start, handoff = session-end. Both fire on their own through hooks. The big upgrade over calling `/catchup` and `/handoff` by hand: **you no longer have to** — a snapshot is guaranteed whether or not anyone remembered.

> **First time in a project?** Run `/ledger init` once to lay down the living files. After that, ledger keeps them current automatically. It never creates files in a repo on its own — tracking is opt-in per project.

## The living files (the source of truth)

Markdown is the truth; everything else is derived. The canonical set lives at the **project root** (`PROJECT.md` lives in `.claude/`). ledger conforms to whatever a project already has — it never invents a parallel set or clobbers existing structure.

| File | Mutability | Holds |
|---|---|---|
| `SESSION.md` | overwrite | The volatile snapshot: exact next step + context-to-not-lose. The one file rewritten each session. |
| `TRACKER.md` | edit in place | Tasks by status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked · `[-]` deferred. **The heart of "what's left."** |
| `GOALS.md` | edit in place | Sprint goal + must-haves; ✅ Achieved archive. |
| `DECISIONS.md` | **append-only** | Every significant "why" — context, choice, alternatives rejected. |
| `MISTAKES.md` | **append-only** | Every real failure: what, why, the detection signal, what to do instead. |
| `LOG.md` | **append-only** | Chronological history of sessions/events. |
| `PROJECT.md` (`.claude/`) | edit in place | Durable intake: goal, verifiable success criteria, stack, taste. |

Full schema, the status grammar, and how ledger **adapts to differently-structured projects** (living-file vs CANON vs bare): `references/living-files.md`. Read it before bootstrapping or reconciling a project.

## How it runs itself (the mechanism)

The discipline is **hook-enforced, not memory-dependent** — the failure mode of every tracking system is relying on the model to "remember to update," so ledger guarantees the writes mechanically and lets you enrich them.

- **Session start → auto-catchup.** `ledger-catchup.sh` injects a briefing: last session's topic, the exact next step, in-progress + blocked tasks, and a *since-last-session* delta (new commits, working-tree state). You're oriented before your first message. *(Anything you "remember" from before a restart is stale-by-default — verify against git + the files.)*
- **As you work → keep it current.** When you finish/refocus a task, move its `TRACKER.md` marker (`[~]`→`[x]`, add `[!] reason` when blocked); append a one-liner to `LOG.md`; log a real "why" to `DECISIONS.md` and a real dead-end to `MISTAKES.md`. A debounced nudge surfaces only if work is drifting ahead of the files.
- **Every run → auto-handoff.** `ledger-checkpoint.sh` fires at **PreCompact and SessionEnd**: snapshots `SESSION.md`, appends `LOG.md`, commits the living files, regenerates the dashboard. You never call handoff. It **preserves** a rich handoff if you wrote one this session, and writes a shell-level one otherwise.
- **On living-file edits → dashboard.** `ledger-dashboard.sh` (debounced) regenerates `.claude/state.html` — a warm, read-only view of the board, goals, next step, and recent decisions/mistakes. Markdown stays the source of truth; the HTML is just a picture of it.

## When invoked (`/ledger [mode]`)

Default — **read the state and report**: run the catchup protocol (`references/handoff-protocol.md`), then give the tight briefing. Don't ask what to work on; infer it from `TRACKER.md` `[~]` and `SESSION.md`'s next step.

- `/ledger handoff` (or "save state", "hand off") — write a **rich** SESSION.md now (the 8-section schema in `references/handoff-protocol.md`), append LOG, log any decision/mistake, commit, regenerate the dashboard. Mark `source: ledger-handoff` so the checkpoint hook preserves it.
- `/ledger catchup` (or "catch me up", "where are we") — full context restore: read SESSION → MISTAKES → TRACKER → GOALS → DECISIONS, check git + the delta, then brief.
- `/ledger status` / `/ledger board` — summarize the board (counts + the in-progress and blocked items) and the must-have progress.
- `/ledger dashboard` — regenerate and report the path to `.claude/state.html`. Run the bundled `scripts/state-dashboard.ts` against the project dir with `bun` (or `npx tsx`). The dashboard is optional: if no TS runtime is installed, the Markdown living files remain the full source of truth.
- `/ledger init` — bootstrap the living files for a project that has none (runs the bundled `scripts/ledger-init.sh`, which is idempotent and never overwrites). Seeds from `.claude/PROJECT.md` if an intake exists.

## Principles

- **Track, never coerce.** ledger records state; it does not decide to keep working. Continuity ≠ autonomy.
- **Mechanism over memory.** The hooks guarantee a snapshot exists; your job is to make it *rich* (the exact next step, the why, the dead-end). A shell snapshot is the floor, not the goal.
- **Conform, don't clobber.** Adapt to each project's structure; never overwrite a human edit or force a layout. Append-only files are inviolable — correct by appending, never by editing.
- **Smallest honest state.** Keep the files lean and current. A stale or bloated living file is worse than none — it lies with confidence. Move done items to archives; don't let `SESSION.md` sprawl.
- **The next session is the customer.** Write the handoff for the context window that picks this up cold. The exact next step and the dead-ends you already ruled out are the most valuable lines.

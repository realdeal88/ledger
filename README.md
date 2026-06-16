<div align="center">

# ledger

### Your project's memory, between sessions.

**Claude Code forgets everything when the context window resets.**
A `/compact`, a `/clear`, a closed terminal — and the goals, the decisions, the dead-ends you already ruled out, the exact line you were about to type all vanish. You spend the first ten minutes of every session re-explaining where you were.

**ledger fixes that.** It keeps a small set of **living files** that update themselves — so every session, even one that wakes up cold after a compaction, knows precisely what's done, what's in progress, what's blocked, and the exact next step.

It runs itself. You never call it.

[Install](#install) · [How it works](#how-it-works) · [The living files](#the-living-files) · [Safety](#safety--design-principles) · [FAQ](#faq)

`MIT` · Claude Code plugin + standalone skill · zero-dependency core

<br>

<img src="assets/demo.gif" alt="ledger catching up at the start of a new session — surfacing the last session, what's in flight, the open decision, and the living files, then resuming exactly where you left off" width="840">

</div>

---

## The 30-second version

```
┌─ you open Claude Code in your project ──────────────────────────────┐
│                                                                      │
│  ── ledger · auto-catchup ──                                         │
│  • Last session: auth refresh flow                                   │
│  • Exact next step:                                                  │
│      Wire the 401-retry interceptor in src/lib/api.ts:refresh()      │
│      — the cookie approach was abandoned (service-worker race).      │
│  • In progress:                                                      │
│      - [~] wire 401-retry interceptor in src/lib/api.ts              │
│  • Blocked:                                                          │
│      - [!] OAuth callback — blocked: Google console access pending   │
│  • Commits since last session:  3a1f2e9 add refresh stub             │
│  • Working tree: 1 uncommitted file(s).                              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

That briefing appears **before your first message** — injected automatically at session start. You didn't ask for it. You don't have to remember the dead-end you already walked. You just continue.

When the session ends — or Claude Code compacts mid-task — ledger snapshots everything back to disk, automatically. The loop closes. Nothing is lost.

---

## Install

ledger ships two ways. The **plugin** is the one most people want: it wires the automation for you.

### As a plugin (recommended — it runs itself)

```bash
# in Claude Code:
/plugin marketplace add realdeal88/ledger
/plugin install ledger@ledger
```

That's it. The five hooks register on install. Open any project, run `/ledger init` once, and tracking is live.

### As a standalone skill (the `/ledger` command, no auto-hooks)

If you only want the `/ledger` command and would rather not install hooks, drop the skill in:

```bash
git clone https://github.com/realdeal88/ledger
cp -r ledger/skills/ledger ~/.claude/skills/ledger
```

Now `/ledger`, `/ledger handoff`, `/ledger catchup`, and `/ledger init` work. You call them by hand — the auto-catchup and auto-snapshot magic comes from the plugin's hooks, so for the full hands-off experience, prefer the plugin.

> **Heads up on namespacing.** Installed as a plugin, the command is `/ledger:ledger` (Claude Code namespaces plugin skills). Installed as a standalone skill, it's just `/ledger`.

---

## Quickstart

```bash
# 1. open Claude Code in a project
# 2. lay down the living files (once per project — never overwrites anything):
/ledger init
# 3. ...just work.
```

From here you do nothing special. As you go, ledger keeps the files current. The next time you open the project — or the moment Claude Code compacts — your state is already saved and already read back.

To force a rich, hand-written handoff before you walk away:

```bash
/ledger handoff
```

To restore full context on demand:

```bash
/ledger          # or:  /ledger catchup
```

---

## How it works

The design rule is one line: **the discipline is hook-enforced, not memory-dependent.** Every tracking system that relies on the model *remembering to update state* fails the same way — the one session that forgets is the one that crashes, and the state is gone. ledger guarantees the writes mechanically through five **non-blocking** hooks, and lets you enrich them.

| When | Hook | What happens |
|---|---|---|
| **Session start** | `ledger-catchup.sh` | Injects the auto-catchup briefing — last topic, exact next step, in-progress + blocked tasks, and a *commits-since-last-session* delta. You're oriented before you type. |
| **As you work** | `ledger-drift.sh` | A debounced nudge (max once / 25 min) — *only* if code is changing and the living files haven't moved. Silent the other 99% of the time. |
| **On living-file edits** | `ledger-dashboard.sh` | Regenerates the HTML dashboard (debounced). Optional — see below. |
| **Before a compaction** | `ledger-checkpoint.sh` | Snapshots `SESSION.md`, appends `LOG.md`, commits the living files. So the post-compact context wakes up knowing everything. |
| **At session end** | `ledger-checkpoint.sh` | Same snapshot, so a fresh terminal tomorrow resumes cold without a beat lost. |

Two things make this trustworthy:

- **None of the hooks can block you.** They never return a blocking decision — they only inject text or write files. (This matters: a blocking `Stop` hook combined with extended thinking throws an API error in Claude Code. ledger deliberately has no `Stop` hook.)
- **A snapshot always exists, but *you* make it rich.** The shell-level checkpoint is the floor — it captures git state and the task board. When you run `/ledger handoff`, you write the 8-section version with the *why* and the dead-ends. ledger preserves your rich handoff and never clobbers it with a shell snapshot.

---

## The living files

Markdown is the source of truth. Everything else — the dashboard, the briefing — is derived from these. They live at your **project root** (`PROJECT.md` lives in `.claude/`).

| File | Mutability | Holds |
|---|---|---|
| `SESSION.md` | overwrite | The volatile snapshot: exact next step + context-to-not-lose. The one file rewritten each session. |
| `TRACKER.md` | edit in place | Tasks by status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked · `[-]` deferred. **The heart of "what's left."** |
| `GOALS.md` | edit in place | Sprint goal + must-haves; a ✅ Achieved archive. |
| `DECISIONS.md` | **append-only** | Every significant "why" — context, choice, alternatives rejected. |
| `MISTAKES.md` | **append-only** | Every real failure: what, why, the detection signal, what to do instead. |
| `LOG.md` | **append-only** | Chronological history of sessions and events. |

The **status grammar** in `TRACKER.md` is what the briefing and dashboard parse:

```markdown
- [ ] todo
- [~] in progress        ← surfaces as "what's being done"
- [x] done
- [!] blocked — reason   ← always write the reason inline
- [-] deferred
```

> The single most valuable line you can leave the next session is a blocker with its reason, or a `TRIED:` note in `LOG.md` recording a dead-end. Those are the things most expensive to rediscover.

Full schema, the blocker convention, the "tried" thread, and how ledger adapts to projects with different layouts: [`skills/ledger/references/living-files.md`](skills/ledger/references/living-files.md). The handoff/catchup protocol: [`skills/ledger/references/handoff-protocol.md`](skills/ledger/references/handoff-protocol.md).

---

## The dashboard

Every time a living file changes, ledger regenerates `.claude/state.html` — a warm, read-only view of the board, goals, the exact next step, and recent decisions and mistakes. Open it in a browser to see your project at a glance.

It's **optional eye-candy.** The dashboard needs a TypeScript runtime (`bun`, or `npx tsx`). If you don't have one, ledger skips it silently and the Markdown files remain the full source of truth. The dashboard is auto-added to `.claude/.gitignore` — it's derived, so it never pollutes your git history.

---

## Safety & design principles

ledger is intentionally conservative. It's a *tracking* system, not an autonomy engine — it remembers, it never decides to keep working.

- **Track, never coerce.** ledger records state. It does not push you to continue, override your stopping, or run anything on its own. Continuity ≠ autonomy.
- **Opt-in per project.** It creates **zero** files until you run `/ledger init`. Open a repo just to read it, and ledger does nothing. The hooks are no-ops until the living files exist.
- **Commits only its own files.** The checkpoint stages and commits `SESSION.md`, `TRACKER.md`, `GOALS.md`, `LOG.md`, `DECISIONS.md`, `MISTAKES.md` — **never your code.** Your working tree and your commits are yours.
- **Conform, don't clobber.** It adapts to a project's existing structure and never overwrites a human edit. Append-only files are inviolable — corrections are appended, never edited in place.
- **Zero-dependency core.** Catchup, checkpoint, and drift are pure `bash` + `git`. No Node, no install step, nothing to break. Only the optional HTML dashboard wants a TS runtime.
- **The next session is the customer.** Every design choice optimizes for the context window that picks this up cold.

---

## FAQ

**Does this work without `bun`/Node?**
Yes. The entire tracking core is pure bash + git. Only the HTML dashboard needs `bun` or `npx tsx`, and it degrades silently if neither is present.

**Will it commit my code or push anything?**
No. It only ever `git add`s the six living Markdown files, commits them locally, and never pushes. Your code is never staged.

**What if I structure my project differently?**
ledger detects three project shapes — full living-file, a `CLAUDE.md`+`SESSION.md` "canon" layout, and bare — and adapts. It never forces its layout onto a project that has its own.

**Does it slow down my session?**
No. The hooks are non-blocking and debounced. The dashboard runs async; the drift nudge fires at most once every 25 minutes and only when state is actually drifting.

**How is this different from just writing notes?**
Notes rely on you remembering to write and read them. ledger *guarantees* the snapshot at the moments you'd otherwise lose state (compaction, session end) and *reads it back automatically* at session start. The discipline is mechanical, not willpower.

**Can I uninstall cleanly?**
`/plugin uninstall ledger@ledger`. Your living files are plain Markdown and stay in your repo — they're useful with or without ledger installed.

---

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Good first contributions: new project-shape adapters, dashboard themes, and additional runtime fallbacks for the dashboard renderer.

## License

[MIT](LICENSE) © realdeal88

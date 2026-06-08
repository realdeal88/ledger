# Living files — schema & adaptation

The living files are the project's durable state. This is the schema ledger maintains, the status grammar it parses, and — most important — how it **adapts to projects it didn't create** without clobbering them.

## The canonical set

At the **project root** (except `PROJECT.md`):

- **`SESSION.md`** — *overwrite.* The volatile snapshot for the next session. Rewritten each handoff. Carries the exact next step and the context that would be expensive to rediscover. The only file that is overwritten rather than appended/edited.
- **`TRACKER.md`** — *edit in place.* The task list. Move tasks between sections; never delete (move `[x]` to a Done section with a date). This is the answer to "what's left / what's being done."
- **`GOALS.md`** — *edit in place.* The sprint goal + must-haves checklist, and a `✅ Achieved` archive. Move completed must-haves to the archive; don't delete.
- **`DECISIONS.md`** — *append-only.* Every significant architectural "why." Correct a past decision by appending a new dated entry, never by editing the old one.
- **`MISTAKES.md`** — *append-only.* Every real failure and the lesson. Format: date · what failed · why · detection signal · do-instead.
- **`LOG.md`** — *append-only.* Chronological history. New entries at the bottom.
- **`PROJECT.md`** (in `.claude/`) — *edit in place.* The durable intake: goal, verifiable success criteria, stack, taste, risk tolerance, definition of done. Filled by `/project-intake`.

`RULES.md` (optional, edit-in-place) holds project-specific operating rules.

## Status grammar (TRACKER.md)

Tasks are list items with a status box. ledger and the dashboard parse exactly these:

```
- [ ] todo
- [~] in progress        ← "what's being done"
- [x] done
- [!] blocked — reason   ← put the blocker reason inline after an em-dash
- [-] deferred
```

**Blocker convention:** always write the reason inline — `- [!] wire OAuth callback — blocked: Google console access pending`. Blockers are the highest-value thing to persist across a restart; an unexplained `[!]` is nearly useless to the next session.

## The "tried" thread (dead-ends)

The most expensive thing to rediscover is what *didn't* work. When you abandon an approach, append one line to `LOG.md` prefixed `TRIED:` — `TRIED: server-side cookie refresh — race with the SW, abandoned for a 401-retry interceptor`. It's greppable and it stops the next session (or the next you) from re-walking a dead-end. Never delete these.

## Project-type adaptation (conform, don't clobber)

Projects have different structures. ledger detects which kind it's in and acts accordingly — it never forces the canonical layout onto a project that has its own.

1. **Living-file project** — has `GOALS.md` + `TRACKER.md` + `LOG.md`. Full treatment: snapshot `SESSION.md`, append `LOG`, commit the living files, regenerate the dashboard. This is the default `/ledger init` lays down.

2. **CANON project** — has `CLAUDE.md` + `SESSION.md` but **not** the living-file trio (e.g. a project whose `CLAUDE.md` is a read-every-session canon and whose `SESSION.md` is maintained continuously). Here ledger **never overwrites** `SESSION.md` — it appends a timestamped marker at the bottom and points continuity at the canon files. Detection and handling are unified in `ledger-checkpoint.sh` (one detection pass — this is what eliminated the old two-hook race).

3. **Bare project** — has a project marker (`package.json`, `Cargo.toml`, etc.) but no living files. `/ledger init` bootstraps the canonical set on demand, seeding `GOALS.md` from `PROJECT.md` if intake has run.

**Rules that hold across all three:**
- Bootstrap a missing file; **never overwrite an existing one** except `SESSION.md` (and only when no rich handoff was written this session — the hook checks `source:`).
- Append-only files are inviolable: `LOG.md`, `DECISIONS.md`, `MISTAKES.md`.
- Stage and commit **only** living files — never code — when checkpointing.
- If the project isn't a project (home dir, `/tmp`, no marker), do nothing.

## Reconciliation (closing real gaps)

When invoked, ledger can reconcile the views that drift apart:

- **TRACKER ↔ `features.json`**: if a project has a `features.json` (binary `passes:` checklist), a task moving to `[x]` should flip the matching feature to `passes: true`. Surface mismatches; reconcile on request.
- **GOALS ↔ `/goal`**: Claude Code's native `/goal` is **session-scoped and never written to disk** — it can't be persisted or synced. Instead, offer to *set* a `/goal` whose condition points at the durable files (e.g. "all `GOALS.md` must-haves checked and `TRACKER.md` has no `[~]`"). The living files remain the durable backing.
- **Sprint rotation**: when every must-have in `GOALS.md` is checked, propose archiving the sprint to `✅ Achieved` + `LOG.md` and seeding the next sprint from `PROJECT.md`. Don't rotate silently.

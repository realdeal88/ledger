# Contributing to ledger

Thanks for considering a contribution. ledger is small and deliberately conservative — the bar for changes is "does this make the next session resume better, without adding risk or dependencies?"

## Principles to preserve

Any change must hold these invariants:

- **Hooks never block.** No hook may return a blocking decision. No `Stop` hook, ever (it conflicts with extended thinking in Claude Code).
- **Commit only living files.** The checkpoint stages `SESSION/TRACKER/GOALS/LOG/DECISIONS/MISTAKES/RULES.md` and nothing else. Never stage user code.
- **Zero-dependency core.** Catchup, checkpoint, and drift stay pure bash + git. New runtime requirements belong only in the optional dashboard path, behind a `command -v` guard.
- **Opt-in, never clobber.** No hook may create files in a project that hasn't run `/ledger init`. Append-only files (`LOG`, `DECISIONS`, `MISTAKES`) are never edited in place.
- **Portable.** Scripts self-locate (via `BASH_SOURCE`) and must run on macOS (BSD userland, no GNU `timeout`) and Linux alike.

## Local development

```bash
git clone https://github.com/realdeal88/ledger
claude --plugin-dir ./ledger      # load it without installing
```

Then in a scratch git repo: `/ledger init`, do some edits, trigger a compaction, and confirm `SESSION.md` snapshots and the catchup briefing reads back.

Before opening a PR:

```bash
bash -n hooks/*.sh skills/ledger/scripts/*.sh   # syntax
jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json
shellcheck hooks/*.sh                            # if installed
```

## Good first contributions

- New project-shape adapters (beyond living-file / canon / bare).
- Dashboard themes, or a no-runtime (pure-bash) dashboard fallback.
- Additional dashboard runtime fallbacks (deno, ts-node).
- Localized documentation.

## Commit style

Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`). One logical change per commit.

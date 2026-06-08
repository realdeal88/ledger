<!-- Thanks for contributing to ledger. Keep changes small and invariant-preserving. -->

## What & why

<!-- One or two lines: what this changes and what it improves about resuming a session. -->

## Invariants (check all)

- [ ] No blocking hook added (no `Stop` hook).
- [ ] Checkpoint still stages **only** the living Markdown files, never user code.
- [ ] Tracking core stays zero-dependency (any new runtime is dashboard-only, behind a `command -v` guard).
- [ ] Opt-in preserved — no hook creates files before `/ledger init`.
- [ ] Append-only files (`LOG`/`DECISIONS`/`MISTAKES`) are never edited in place.

## Verification

```
bash -n hooks/*.sh skills/ledger/scripts/*.sh
jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json
# round-trip: /ledger init → edit → checkpoint → catchup reads it back
```

<!-- Paste the relevant output. -->

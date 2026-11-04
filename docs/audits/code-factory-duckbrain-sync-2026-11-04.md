# Sync lane audit — code-factory-duckbrain, tick `code-factory-duckbrain-2026-11-04-01-21-33`

Lane: sync (board/repo drift reconciliation). Namespace: `code-factory`.
Measured at published tip `f49d85b98aa90fcb3346a3edc40fe398a50a5d95` on 2026-11-04T01:36Z.

## Root and ownership

The scheduler locator `~/code-factory` resolves to itself and to its own Git top level, is on an
attached `main`, carries no rebase/merge/cherry-pick/revert marker, and is level with
`origin/main` (`git rev-list --left-right --count origin/main...HEAD` = `0 0`).

The checkout was nevertheless not written to this tick. Two sibling lanes of the same family
were live at dispatch time (`code-factory-pm` and `code-factory-sync`, both `status=running`,
ticks `…-2026-11-04-01-21-15`), which is a family-wide stand-down barrier for the shared
checkout. The work was done in a fresh `git clone` of `git@github.com:coding-hermes/code-factory.git`
at `f49d85b` (parity `0 0` against `origin/main`), and the locator was left untouched.

`.coding-hermes/board/.lock` exists in the locator: 0 bytes, mtime 2026-11-03T07:40:02-05:00,
`fuser -v` reports no holder, and `grep -rn 'flock\|fcntl' scripts/boardctl scripts/*.py` returns
no consumer. Recorded as residue, not a held lock, and not deleted.

## Census

| check | result |
|---|---|
| `tasks.jsonl` lines / parsed rows | 114 / 114 (`jq -c .` exit 0) |
| `events.jsonl` lines / parsed rows | 162 / 162 (`jq -c .` exit 0) |
| duplicate task ids | none |
| working file vs `git show HEAD:` sha256 | identical (`f6e782c0…`) |
| status histogram | 38 complete, 4 in_progress, 72 pending |

## Complete rows: evidence binding

38 rows are `complete`.

- `commit_hash` missing or unresolvable: **1** — `CF-053` (`commit_hash: null`, config-only
  change in another repository). Already tracked by CF-130.
- commit not an ancestor of `origin/main`: **0**.
- evidence artifacts that do not resolve in the committed tree: **2 entries on 2 rows**, both the
  historical entry of `CF-011` and `CF-013` citing an absolute scratch log outside the tree. Both
  rows carry a later superseding entry pointing at
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md`, which exists in the tree. History
  preserved by design; no action.
- `complete` rows with no `task_completed` event: **2** — `CF-034`, `CF-041`. Already tracked by
  CF-130; not re-filed and not minted, because neither closure was witnessed by this tick.
- Completion-event duplicates: 9 task ids carry two `task_completed` events. This is the board's
  established minimal+rich closure shape (the writer's own minimal event plus the lane's rich
  `--detail` event), not drift.

Field-name note for later ticks: events carry `event_type` (never `type`); the first pass of this
audit keyed on `type`, read 162 nulls, and produced a false "9 completion events with no row".
Re-running with `event_type` in a private scratch path showed the true set. `detail` is an object
on 83 rows, a string on 3, and null on 28 — normalize per row before traversing it.

## Docs drift found and fixed

`docs/BOARD.md` carried a hand-typed `Current measured state` block pinned to tip `21d3265`:

- frozen pre-fix pair — 104 task rows, 148 events, `RESULT: OK (45 warning(s))`,
  `PASS 104/104 rows parse`;
- measured at `f49d85b` — 114 task rows, 162 events, `RESULT: OK (46 warning(s))`,
  `PASS 114/114 rows parse`.

The block was restated at the measured tip with measured values only, and it now names CF-081 as
the structural fix (a committed check that derives the counts and fails on a mismatch). CF-081 stays
pending: this tick corrects the numbers, it does not build the guard. The pre-fix pair is frozen
above so CF-081's red arm still has a reproducible fixture.

## Gates run at `f49d85b`

```
bash scripts/boardctl validate
  RESULT: OK (46 warning(s))                     rc=0
bash tests/selftest.sh
  PASS  114/114 rows parse
  SELFTEST: PASS                                  rc=0
```

The 46 validator warnings are pre-existing vocabulary/graph warnings: 43 rows carrying a free-form
`probe` key, CF-034's `guard_result`/`ci_result` prose, and the headerless board.

## Open, not touched

CF-130 (completion-transition gaps, CF-053 stale closure, CF-005 stale `in_progress`), CF-081
(hand-typed measured-state block), CF-086 (absolute host paths in board rows) remain pending and are
the owning lanes' work. This repo runs no GitHub Actions; the CI-equivalent gate is the selftest
above.

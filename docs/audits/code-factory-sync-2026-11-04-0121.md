# Sync lane evidence — 2026-11-04T01:21-05:00 (tick `code-factory-sync-2026-11-04-01-21-15`)

Board/repo consistency pass for code-factory. Four sibling code-factory lanes were `running` on the
shared checkout when this tick started, so nothing was written in `~/code-factory`: the
whole tick ran in a dedicated clone of `origin/main` in the tick scratch. The registered checkout
was read only.

A sibling sync lane landed its own restatement of the same docs block while this tick ran
(`ceff295`), and a PM lane filed `CF-141` for an unrelated adapter finding (`df0c8fc`). This work
was rebuilt on top of `df0c8fc` rather than rebased through those rows, so nothing of theirs was
rewritten; this tick's own board row is `CF-142`.

## Identity and publication

| Check | Measured |
|---|---|
| `realpath ~/code-factory` vs `git rev-parse --show-toplevel` | equal (`~/code-factory`) |
| registered `repo_url` (scheduler project row) | `local:~/code-factory` — matches the locator |
| branch / operation markers | `main`, attached; no `rebase-merge`/`rebase-apply`/`MERGE_HEAD`/`CHERRY_PICK_HEAD`/`REVERT_HEAD` |
| tracked working tree | clean; 48 untracked paths = 0-byte `board/.lock` plus unpublished `.gitreins/history/2026-11-03/*` bundles. The lock is residue, not a barrier: `fuser -v .coding-hermes/board/.lock` reports no holder, no repo script opens it (`grep -rn 'flock\|fcntl' scripts/boardctl*` = 0 hits), and this tick's `boardctl` writes in the clone succeeded — which is also where a fresh 0-byte lock appeared |
| sibling lanes `running` on this repo at tick start | `code-factory-duckbrain` (01:21:33), `code-factory-duckbrain-sync` (01:21:15), `code-factory-perf` (01:21:15), `code-factory-pm` (01:21:15) |
| `HEAD` vs `origin/main` at start | `f49d85b` = `f49d85b`, ahead 0 / behind 0 |
| host load beside the gate runs | loadavg 30.36 / 36.89 / 36.57 |

## Board parse (deliverable 1)

| Check | Command | Result |
|---|---|---|
| line count | `wc -l .coding-hermes/board/tasks.jsonl` | 114 at start; 116 at this tree after the two rows below |
| per-line JSON | `jq -c . <board>` | parses, exit 0 |
| duplicate ids | `jq -r .id \| sort \| uniq -d` | none |
| status census | `jq -r .status \| sort \| uniq -c` | 38 `complete`, 4 `in_progress`, 72 `pending` at start |
| events | `wc -l`; every line parses | 162 at start, 168 at this tree |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (47 warning(s))` — 44 free-form `probe` rows, one legacy free-form `guard_result`/`ci_result` row, headerless board |

## Complete-row evidence audit (deliverable 2)

Every `complete` row's `commit_hash` was resolved with `git cat-file -e <sha>^{commit}` and
`git merge-base --is-ancestor <sha> origin/main`. 37 of 38 bound a commit reachable from
`origin/main`; the 7-character prefixes (CF-052, CF-055, CF-096, CF-123) resolve to full objects
and are valid bindings.

Drift found and fixed: **CF-053** was `complete` with `commit_hash: null` and
`worker_status: pending`. It now carries `80fca8bf3a7be28899cc13a1041a7869693d677e` — the commit
whose subject closes it (`board: close CF-053 — 18 satellite lanes now resolve to the project
checkout`) — and its worker status agrees with `complete`. The repoint was re-verified today rather
than inherited: the 19 code-factory lanes were exported from the scheduler DB
(`sqlite3 -json ~/.hermes/coding-hermes/scheduler.db "select name, workdir, repo_url from projects
where name like 'code-factory%'"`) and scanned with `python3 scripts/lane_target.py scan <file>`
→ `bad: 0`, `ok: true`, rc 0.

Every `detail.evidence[].artifacts` path was resolved inside the committed tree with
`git cat-file -e origin/main:<path>`. The only absolute paths left on the board are the historical
first-run entries of **CF-011** and **CF-013**
(`~/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log`); both rows
already carry a superseding `sync-20261103-*` entry pointing at the committed
`docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md`, so the dead entry is preserved
history, not an open gap. Nothing was erased.

Completion-event coverage: **CF-034** (`complete`, `573488fa`, updated `2026-10-31T15:22:00Z`) and
**CF-041** (`complete`, `fbf1f3a7`, updated `2026-11-03T12:54:24Z`) have no `task_completed` event —
only `task_created` (CF-041 additionally one `audit`). Event 168 records the gap. No completion
transition was minted for either id: an append-only log must not record a transition its writer did
not witness.

**CF-130** (filed by an earlier sync tick for exactly these three conditions) is annotated, not
closed. Its verbatim probe at this tip prints
`stale_inprogress=CF-005 CF-137 CF-138 CF-139`,
`complete_without_completion_event=CF-034 CF-041`,
`complete_with_worker_status_pending=` (empty). Leg 2 is therefore closed mechanically; leg 1 is
satisfied only under the row's own text (an audit naming the closure), because the probe counts just
`task_completed`; leg 3 (CF-005) is an acceptance judgement about five criteria, and this lane does
not decide acceptance. CF-137/CF-138/CF-139 are a live sibling lane's work in progress, not stale.

`pending` rows are **not** reported as landed on `git log --grep` alone: the grep hits come mostly
from board-filing commits that name a row without implementing it, so the pending population is left
as pending.

## Docs status tables (deliverable 3)

The sibling's restatement (`ceff295`) pinned the block to `f49d85b` (114 rows / 162 events). This
tree re-measures it: 116 rows / 168 events, `RESULT: OK (47 warning(s))`, `PASS 116/116 rows parse`,
`SELFTEST: PASS` (88 `PASS` rows, 19 `FAIL` lines inside negative fixtures). The CF-053 binding, the
CF-034/CF-041 event gap and the gate's nondeterminism (CF-142) are recorded in the same block so the
next tick reads them as state, not as a surprise.

`docs/ACCEPTANCE-PLAN.md` cites `CF-101…CF-112`; those are PRD requirement numbers, not board rows
(`jq` over the board for `^CF-1(0[1-9]|1[12])$` returns no rows), so no board/tree disagreement is
implied and no row was filed for them.

## Drift found by the gate itself: filed as CF-142

`tests/selftest.sh` is the CI-equivalent gate and it is not deterministic. Four runs on the same
tree this tick: PASS (88 `PASS` rows), then **FAIL (1)** — `FAIL auth marker
{"auth_required":trueish} was not refused (exit 0)` — then PASS, then PASS. The only intervening
change was two board-only `boardctl update` calls, which cannot affect `scripts/verify-node.sh`.
**CF-142** files the flake with the acceptance criterion that 20 consecutive runs must agree and
that loadavg be recorded beside them (30–36 during this tick).

## Gates at this tree

| Gate | Command | Result |
|---|---|---|
| board schema | `bash scripts/boardctl validate` | `RESULT: OK (47 warning(s))`, rc 0 |
| CI-equivalent | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, `PASS 116/116 rows parse`, 88 `PASS` rows (one non-reproducing FAIL in 4 runs, filed as CF-142) |
| GitHub Actions | `gh run list --repo coding-hermes/code-factory --limit 3 --json status,conclusion,...` | `[]` — this repository ships no workflows; the no-workflow state is healthy by documented contract |

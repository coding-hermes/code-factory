# Sync lane evidence — 2026-11-04T04:00Z (tick `code-factory-sync-2026-11-04-04-00-08`)

Board/repo consistency pass for code-factory, run **in the registered checkout**
`/home/kara/code-factory` because the ownership gate came back clean this time: attached `main`,
no operation markers, no tracked edits (staged or unstaged), tip in parity with `origin/main`, and
the board bytes identical to the published board. No clone transport was needed.

## Identity and barrier

| Check | Measured |
|---|---|
| `realpath /home/kara/code-factory` vs `git -C … rev-parse --show-toplevel` | equal (`/home/kara/code-factory`) |
| registered `workdir` / `repo_url` (scheduler project row `code-factory-sync`) | `/home/kara/code-factory` / `local:/home/kara/code-factory` — matches the locator |
| `origin` | `git@github.com:coding-hermes/code-factory.git` (the registered project repo) |
| branch / operation markers | `main`, attached; no `MERGE_HEAD`/`REBASE_HEAD`/`CHERRY_PICK_HEAD`/`REVERT_HEAD`/`BISECT_LOG`/`rebase-merge`/`rebase-apply` |
| `HEAD` / `origin/main` / `ls-remote` | `79e9b59` / `79e9b59` / `79e9b59c8286` — parity `0 0` |
| tracked index and worktree | empty — zero staged and zero unstaged tracked edits |
| untracked residue | 53 paths, every one under `.gitreins/history/2026-11-03/` (unpublished judge bundles, newest mtime 19:08). Not read, not cleaned, not adopted |
| board lock | `.coding-hermes/board/.lock`, 0 bytes, mtime `2026-11-03 07:40:02` — residue, not a barrier: `fuser -v` reports no holder and commits landed through it afterwards. Left in place |
| live writer census (`scripts/checkout-writer-census.sh`) | `CENSUS_COUNT=1`, and that hit is this tick's own `tail` pipeline stage (`comm=tail`, started at this tick's second) — no foreign writer in the tree |
| sibling lanes | re-read by single-project GET immediately before the write: `code-factory-dogfood` `running` (tick `…-2026-11-04-03-58-57`), every other family lane `failed`/`complete`. The dogfood lane has no process in this checkout (census above) and its deliverable is a read-only walk |
| host load | loadavg 8.39 during the gate run |

Per-tick receipt series followed: `docs/audits/code-factory-sync-<date>-<HHMM>.md`
(`…-0004`, `…-0241`, this file).

## Board parse (deliverable 1)

| Check | Command | Result |
|---|---|---|
| task line count | `wc -l < .coding-hermes/board/tasks.jsonl` | 134 |
| per-line JSON | `jq -c . <.coding-hermes/board/tasks.jsonl > /dev/null` | parses, rc 0, 0 bad lines |
| duplicate task ids | `jq -r .id … \| sort \| uniq -d` | none (ids `CF-001` … `PERF-015`) |
| status census | `jq -r .status … \| sort \| uniq -c` | 45 `complete`, 6 `in_progress`, 83 `pending` |
| event line count | `wc -l < .coding-hermes/board/events.jsonl` | 219 before this tick's own audit event |
| row count matches the last commit | working-tree board vs `git show origin/main:.coding-hermes/board/tasks.jsonl` | byte-identical, `sha256 05e5b2f364a2876e30a0f55295db45cc37f6cb8f8b8a25e23f514b93b8a820a1` on both sides |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 — CF-034's free-form `guard_result`/`ci_result`, plus the headerless board; `key uniformity: 134/134 rows carry only canon keys (0 drift)` |

## Complete-row evidence audit (deliverable 2)

`ROWS=134 COMPLETE=45 BADLINES=0`; a per-row pass over every `complete` row's
`detail.evidence[].artifacts` and `commit_hash` (`board_audit.py` in the tick scratch).

| Check | Result |
|---|---|
| `complete` rows with no evidence artifacts | 0 |
| `complete` rows with no `commit_hash` | 0 |
| `commit_hash` objects missing from the repo (`git cat-file -e <sha>^{commit}`) | 0 of 45 |
| `detail.evidence[].artifacts` paths that do not resolve in the tree | 3 entries on 3 rows |

The three unresolvable entries are all pre-adjudicated history, **not new gaps**, and no row was
re-filed for them:

- `CF-011`, `CF-013` — both point at `/home/kara/.hermes/cache/scratch/code-factory-pm-20261031-114422-final-selftest.log`,
  a pruned scratch log. Each row already carries a second, superseding evidence entry
  (`run_id: sync-20261103-cf011` / `…-cf013`) whose artifact is the committed
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` — verified present in the tree, and
  the rebind document itself lists both rows at lines 25–26 and 81–82.
- `CF-034` — its artifact value is a test reference (`tests/selftest.sh::clone-error-classification`),
  not a path. That is the row's legacy shape, and it is the same row the validator still warns about.

**Evidence still runs.** Three commands named as evidence by many complete rows were re-run at this
exact head, not quoted from history:

| Command | Result at `79e9b59` |
|---|---|
| `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 103 `PASS` rows, 33 numbered sections, loadavg 8.39 |
| `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0 |
| `bash docs/audits/cf089-census-recipe.sh` (the CF-157 / CF-089 evidence command) | rc 0, 20 lines, `enabled=false` on exactly 1 row (`code-factory-qa`) — CF-157's corrected wording still holds |

**Measurement-scope note, so the next tick does not file a phantom row.** A narrow scan over
`acceptance_criteria` alone reports 33 older `complete` rows whose AC text carries no backticked
command (`CF-009`–`CF-039` era). That is a scope artifact, not a gap: the lane's contract is that
*evidence* names a re-runnable command, so the check runs across
`worker_summary`/`foreman_note`/`reasoning`/`acceptance_criteria`/`detail`. Both arms were run this
tick with `audit_command_named.py`:

| Arm | Board | Result |
|---|---|---|
| GREEN | the real board at `79e9b59` | `rows=134 complete=45 rows_naming_no_command=0` |
| RED | `red-arm/tasks.jsonl` — the same board with one row's (`CF-157`) command-bearing fields replaced by prose, `CF-158` left intact as the control | `rows_naming_no_command=1` / `NOCMD CF-157`, control still clean |

No row was filed for the 33 narrow-scan hits.

## Docs status tables (deliverable 3)

| Doc | State found | Action |
|---|---|---|
| `docs/ACCEPTANCE-PLAN.md` evidence block | newest delta block read 127 rows / 193 events at `dae4e7a` (03:01); board now reads 134 / 219 | **fixed by delta append**: new block at the head of the series carries the `79e9b59` measurement (134/219, 45-83-6, `OK (3 warning(s))`, `SELFTEST: PASS` 103 rows over 33 sections). The earlier snapshots are left standing so the move is visible as a moved tip, not a lost closure |
| `docs/BOARD.md` | operation contract, carries no row statuses | no drift possible; untouched |
| `docs/SECURITY-TRIAGE.md` | cites `CF-119` prose, no status table | no drift; untouched |
| `README.md` status rows | the CF-157 fix landed at 03:50 and its census recipe re-ran green above | consistent; untouched |

## Board writes

One append: an `audit` event recording this pass (counts, gate results, the 3 pre-adjudicated
artifact entries and their disposition). **No task row was filed** — the pass found no new gap that
survives verification, and row `status` fields were not rewritten: the sync lane's contract is
*append or rewrite only the target rows*, and there were no target rows.

## Not run, and why

| Leg | Status | Reason |
|---|---|---|
| publishing the 53 untracked `.gitreins/history/2026-11-03/*` bundles | not run | no board row points at them (every referenced artifact resolves), so publishing them is not required for evidence binding; left exactly as found and disclosed rather than folded into a sync commit |
| deletion of `.coding-hermes/board/.lock` | not run | residue is recorded, never deleted, by lane contract |
| worker dispatch | not run | this lane's deliverable is reconciliation; no implementation was needed |

## Gates and publication

Filled at the landing commit — see the receipt below.

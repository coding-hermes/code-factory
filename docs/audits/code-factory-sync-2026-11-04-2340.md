# Sync lane tick — 2026-11-04T23:40Z (tick `code-factory-sync-2026-11-04-23-34-25`)

Lane: `code-factory-sync`. Scope: board integrity, completion evidence, docs/board reconciliation.
All measurements below were taken from a **throwaway clone of the published tip**, not the
registered checkout, because a sibling lane of this family was live for the whole tick (see
"Barrier"). Every number names the tip it was measured at: `53d39f4`.

```sh
git clone git@github.com:coding-hermes/code-factory.git "$S/repo"   # 53d39f4, porcelain 0
```

## Barrier (why the clone transport)

| Probe | Measured at | Reading |
|---|---|---|
| `GET /api/v1/projects/code-factory-qa` → `latest_tick` | 23:37Z | `status=running`, `code-factory-qa-2026-11-04-00-07-40-nudge1`, spawned `18:33:20-05:00` |
| `~/.hermes/state.db` sessions started inside 20 min | 23:37Z | five `api_server` sessions with growing `tool_call_count` in the same 18:32–18:34 window |
| `git -C ~/code-factory status --porcelain -uall` | 23:36Z | 88 untracked paths, **all** `.gitreins/history/2026-11-03/*` verdict residue; 0 tracked edits |
| `.coding-hermes/board/.lock` | 23:36Z | 0 bytes, mtime 2026-11-03T07:40:02-05:00, `fuser` empty → residue, **not** a held lock (the CF-119 class) |
| `git -C ~/code-factory rev-parse HEAD` vs `git ls-remote … refs/heads/main` | 23:40Z | both `53d39f4` — the registered checkout is **not** behind at sample time |

The sibling lane was running at tick start, so the registered checkout was left untouched (no writes,
no fast-forward — there was nothing to fast-forward) and the whole read/write leg ran in the clone.
Sibling liveness is a state, not a verdict: it is reported as "running at 18:33:20-05:00".

## Board integrity at `53d39f4`

| Check | Command | Result |
|---|---|---|
| every line parses | `jq -c . .coding-hermes/board/tasks.jsonl` (per line via the audit script) | 179 lines, 0 parse failures, trailing newline present |
| events parse | `jq -c . .coding-hermes/board/events.jsonl` | 364 lines, 0 failures |
| row count = committed copy | `wc -l` vs `git show HEAD:…` | 179 = 179 tasks, 364 = 364 events, worktree bytes identical |
| duplicate ids | `jq -r .id \| sort \| uniq -d` | tasks 0; events 1 (id **336** on lines 336/337 — benign legacy duplicate, owned by **CF-196**) |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))`, `key uniformity: 179/179 rows carry only canon keys (0 drift)` |
| published parity | `python3 scripts/board_drift.py check --workdir . --ref main` | `RESULT: OK` — byte parity on both files, 179 vs 179 rows, 0 divergent ids, HEAD ancestry pass |
| status census | `jq -r .status \| sort \| uniq -c` | 62 `complete`, 9 `in_progress`, 108 `pending` |

## Completion evidence at `53d39f4`

| Check | Result |
|---|---|
| every `complete` row carries a resolving `commit_hash` | 62/62 resolve via `git cat-file -e <sha>^{commit}`; 0 empty |
| every artifact named by the newest evidence entry exists in the tree | 70 artifact pointers across 62 rows, `missing=0` (the only non-path pointer is `CF-034`'s `tests/selftest.sh::clone-error-classification`, a section reference by design) |
| completion-event coverage | 58/62 complete rows carry a `task_completed` event; **CF-034, CF-041, CF-182, CF-197** do not |
| verdict binding sweep | `python3 docs/audits/cf181-verdict-binding-sweep.py` → `complete_rows=62 verdict_artifacts_checked=35 orphan_count=1`, the orphan `CF-077` binding `1dfb58b8` (owned by pending **CF-181**) |
| PRD/plan drift probe | `bash docs/audits/cf099-prd-drift-probe.sh` → `OK: milestone, plan snapshot and layer arms agree at 53d39f4`, rc 0 |
| standing gate | `bash tests/selftest.sh` → `SELFTEST: PASS`, rc 0, `PASS 179/179 rows parse`, 195 `PASS` rows, 50 `FAIL` rows all inside negative fixtures, 39 numbered sections + `4b`/`7b`/`31b` (42 arms) |
| CI surface | `gh run list --repo coding-hermes/code-factory --limit 3` → `[]` (the repo ships no GitHub Actions; the gate is the selftest plus the gitreins guard — an empty list is not a green CI) |

## Drift found and fixed (this commit)

`docs/BOARD.md` §"Current measured state" carried the **08:52Z `7232954` snapshot** (158 rows / 300
events / 51 `complete`) as its newest entry while the published tip had moved to `53d39f4`
(179 / 364 / 62). The block's own instruction is to measure rather than quote an older snapshot, and
its previous entry had already been relabelled historical for the same reason. Fix: a fresh snapshot
for `53d39f4` was added above it, and the `7232954` entry was relabelled "Earlier snapshot … (historical,
not current)". No earlier bullet was edited.

**No board event was appended for this tick.** The refreshed block cites the event count (364), and an
`audit` event appended in the same commit would move that count past the number the block publishes,
re-staling it inside its own commit. The tick record therefore lives in this file only; the structural
fix for the hand-typed block remains **CF-081**.

## Drift measured and left with its owner (no duplicate rows filed)

- **CF-034, CF-041, CF-182, CF-197** are `complete` without a `task_completed` event. Class already
  owned by **CF-130**, whose AC1 requires that *every* complete row be represented in `events.jsonl`
  (the probe's `complete_without_completion_event` line prints empty), so `CF-182`/`CF-197` fall inside
  its existing scope and were not re-filed.
- **Duplicate event id 336** is owned by **CF-196**; it is the only new warning versus the previous
  snapshot's `OK (3 warning(s))` → now `OK (4 warning(s))`.
- **`CF-077` orphaned verdict** (binds `1dfb58b8`, the pre-rewrite copy of the landed commit) is owned
  by pending **CF-181**; unchanged from the previous tick.
- **Six board rows store `detail` as `null`/bare string** (owned by **CF-200**) — every scanning
  instrument must tolerate it; this tick's audit script does.

## Verification of the fix

```sh
grep -c 'Re-measured 2026-11-04T23:40Z at tip `53d39f4`' docs/BOARD.md    # 1
grep -c 'Earlier snapshot, 2026-11-04T08:52Z at tip `7232954` (historical, not current)' docs/BOARD.md   # 1
bash docs/audits/cf099-prd-drift-probe.sh    # OK at the landed tip
bash tests/selftest.sh                       # SELFTEST: PASS
python3 scripts/board_drift.py check --workdir . --ref main   # RESULT: OK
```

## Addendum — rebase over a sibling landing, and one flaky selftest run

The first push was refused: a sibling landed `1124ae0` (`board(qa): file CF-205`) while this tick
ran, so the tick's commit was rebased onto it (`git pull --rebase origin main`, clean, no conflict)
and every count in the published snapshot was **re-measured at the rebased tip `ac844cb`** rather
than carried over: 180 task rows, 365 events (max event id 364), 62 `complete`, 9 `in_progress`,
109 `pending`; `key uniformity: 180/180`; board_drift parity 180 vs 180 rows.

`bash tests/selftest.sh` returned `SELFTEST: FAIL (1)` on the first run at the rebased tip: the
`gateway_start — -> 503 (see ~/.node-serve-10800.log)` row, i.e. the arm that follows the CF-071
real-value red control, with 197 `PASS` / 53 `FAIL` rows against the baseline's 195 / 50. The
immediate re-run on the same unchanged tree printed `SELFTEST: PASS` (rc 0) with 195 `PASS` /
50 `FAIL` rows and `PASS 180/180 rows parse`, at loadavg 24.15 (the failed run was at loadavg
34.52; nothing was listening on `:10800` when the arm failed, and the log was empty). That is the
nondeterministic-under-load class already owned by **CF-142** ("before believing a single red,
re-run it; before believing a single green, note the load") — no new row was filed for it, and the
snapshot records the green run with its loadavg.

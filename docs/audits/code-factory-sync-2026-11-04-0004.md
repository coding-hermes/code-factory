# Sync lane evidence — 2026-11-04T00:04Z (tick `code-factory-duckbrain-sync-2026-11-03-23-48-25`)

Re-fire evidence. A previous fire of the same tick id landed its closeout at
`2026-11-03T18:53:45-05:00` (`21d3265`, event 148); this fire re-ran the sync lane's checks
independently, found no regression of that work, and fixed the one drift it left behind.

## Identity and publication

| Check | Measured |
|---|---|
| `realpath ~/code-factory` vs `git rev-parse --show-toplevel` | equal (`~/code-factory`) |
| branch / markers | `main`, attached; no `MERGE_HEAD`/`REBASE_HEAD`/`CHERRY_PICK_HEAD`/`REVERT_HEAD`/`BISECT_LOG`/`rebase-merge`/`rebase-apply` |
| `origin` | `git@github.com:coding-hermes/code-factory.git` |
| `HEAD` vs `origin/main` at start | `21d3265` = `21d3265`, ahead 0 / behind 0 |
| board byte parity | `tasks.jsonl` sha256 `954dcd69…fa9a` and `events.jsonl` sha256 `b96bb443…ba4e6` identical to `git show origin/main:<path>` |

## Board parse (deliverable 1)

| Check | Command | Result |
|---|---|---|
| line count | `wc -l .coding-hermes/board/tasks.jsonl` | 104 (origin/main 104) |
| per-line JSON | `jq -c .` | parses, exit 0 |
| duplicate ids | `jq -r .id \| sort \| uniq -d` | none |
| status census | `jq -r .status \| sort \| uniq -c` | 38 `complete`, 1 `in_progress`, 65 `pending` |
| events | `wc -l .coding-hermes/board/events.jsonl`; `jq -c .` | 148 rows, parses, max id 148 |
| schema gate | `scripts/boardctl validate` | `RESULT: OK (45 warning(s))` |

## Complete-row evidence audit (deliverable 2)

All 38 `complete` rows name a runnable command in their evidence fields. The command cited by
every one of them is `tests/selftest.sh`, and it still runs:

```
$ bash tests/selftest.sh ; echo EXIT=$?
  PASS  104/104 rows parse
...
SELFTEST: PASS
EXIT=0
```

29 sections, 88 `  PASS` lines, 19 `  FAIL` lines — every `  FAIL` line sits inside a negative
fixture that asserts a failure arm (for example `  FAIL  2 of 3 rows parse`, which proves the parse
gate can go red). The suite verdict is `SELFTEST: PASS`, exit 0.

Cited repository paths: all resolve except `tests/secrets`, which is a regex false positive — the
CF-055 text is `tier1 PASS (lint/tests/secrets)`, a GitReins tier list, not a path.

Commit refs: 37 of 38 `complete` rows resolve with `git cat-file -e <sha>^{commit}`. The exception
is CF-053 (`commit_hash: null`), already filed as part of CF-130.

## Drift found and fixes applied (deliverable 3)

| # | Drift | Disposition |
|---|---|---|
| 1 | `docs/BOARD.md` "Current measured state" claimed 61 task rows / 66 events / `RESULT: OK (17 warning(s))` / `PASS 61/61 rows parse` at tip `d4eec41`. Measured at `21d3265`: 104 / 148 / 45 warnings / `PASS 104/104`. The quoted numbers were the pre-repair stale-workdir reading described in the paragraph above it, presented as current. | **Fixed this tick.** Section is now a named-tip snapshot plus the three commands that produce the values, and states that the 19 `  FAIL` lines are fixture arms. |
| 2 | CF-053 is `complete` with `worker_status: pending` and `commit_hash: null`; its evidence names `lane_target.py scan lanes.jsonl`, and no `lanes.jsonl` exists in this repo. | Already filed — CF-130 AC2 names exactly this condition. Not re-filed. |
| 3 | CF-034 and CF-041 are `complete` with no `task_completed` event; CF-005 is the only `in_progress` row, untouched since 2026-10-29. | Already filed — CF-130 AC1 and AC3. Not re-filed. |
| 4 | `docs/ACCEPTANCE-PLAN.md` carries an "Evidence snapshot (re-measured 2026-11-03 at tip `80fca8b`)" with 85 rows / 115 events / 28 warnings. | **Left intact deliberately.** It is an acceptance-run measurement bound to a named tip, not a current-state claim; overwriting it with this tick's numbers would falsify a dated measurement. Its tip is named, so a reader can date it. |

No row was rewritten wholesale; the only repository change is the `docs/BOARD.md` section.

## Residue (disclosed, not cleaned)

- `.coding-hermes/board/.lock` — 0 bytes, untracked, mtime 2026-11-03T07:40:02-05:00, no holder.
- 47 untracked `.gitreins/history/2026-11-03/*` bundle files from earlier ticks (verdict/commit
  patches). Not this tick's evidence; left in place as the earlier ticks' record.

## Gates at the committed tree

```
bash tests/selftest.sh        -> SELFTEST: PASS (exit 0)
scripts/boardctl validate     -> RESULT: OK (45 warning(s))
python3 scripts/board_drift.py check --workdir . --ref origin/main  -> RESULT: OK (exit 0;
  byte parity on both board files, 104 vs 104 rows, 0 divergent ids, HEAD ancestor of origin/main)
```

# Sync lane re-fire evidence — 2026-11-04T08:42Z (tick `code-factory-sync-2026-11-04-08-24-10`)

Re-fire of a tick whose first fire landed its receipt at `docs/audits/code-factory-sync-2026-11-04-0824.md`
(published tip `202fb61`). This pass re-ran the lane's checks independently at the published tip and
fixed the one figure the first fire left stale.

## Where the checks ran

`/home/kara/code-factory` was **not** written, fetched into, or cleaned. It is behind the published tip
and carries a sibling lane's unpublished work: `docs/ACCEPTANCE-PLAN.md`,
`docs/audits/cf099-prd-drift-probe.sh` and `tests/selftest.sh` are modified in the worktree by the
`code-factory-docs` lane's in-flight CF-155 worker (scratch
`~/.hermes/cache/scratch/cf-docs-20261104.feoD6j`, no exit marker yet), and a `code-factory-dogfood`
tick holds another worker. All measurements below are from a scratch clone of the published tip:

```sh
git clone /home/kara/code-factory land && cd land
git remote add gh git@github.com:coding-hermes/code-factory.git
git fetch gh main && git checkout -B main gh/main    # 202fb61, porcelain 0
```

## Deliverable 1 — the board parses and the row count matches the commit

| Check | Command | Result |
|---|---|---|
| per-line JSON, tasks | `jq -c . .coding-hermes/board/tasks.jsonl >/dev/null` | rc 0 |
| per-line JSON, events | `jq -c . .coding-hermes/board/events.jsonl >/dev/null` | rc 0 |
| task rows | `wc -l < .coding-hermes/board/tasks.jsonl` | 156 (= the committed copy; tree is clean at `202fb61`) |
| event rows | `wc -l < .coding-hermes/board/events.jsonl` | 295, max id 295, no gap-free claim made |
| duplicate task ids | `jq -r .id … \| sort \| uniq -d` | none |
| duplicate event ids | `jq -r .id … \| sort -n \| uniq -d` | none |
| status census | `jq -r .status … \| sort \| uniq -c` | 50 `complete`, 8 `in_progress`, 98 `pending` |
| schema gate | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))`, rc 0; `key uniformity: 156/156 rows carry only canon keys (0 drift)` |

## Deliverable 2 — every `complete` row's evidence resolves

- `commit_hash`: 50 of 50 `complete` rows carry one, and all 50 resolve with `git cat-file -e <sha>^{commit}`.
  No `NULL`, no unresolved object.
- completion events: 48 of 50 carry a `task_completed` event. The two without one are `CF-034` and
  `CF-041`, already measured by the `01:21` tick (event 168) and owned by **CF-130**; not re-filed,
  and no completion transition was minted for either id.
- approval-shape events are real reopens, not drift: `CF-053` (event 115 complete → event 181
  `task_updated` `in_progress`) and `CF-079` (event 188 complete → event 197 `in_progress`) both carry
  a later `task_updated` that the row's `updated_at` matches. A census keyed only on "has a
  `task_completed` event" reads them as closed; the row is the authority and it says open.
- the standing completion command still runs: `bash tests/selftest.sh` → exit 0, `SELFTEST: PASS`,
  `PASS 156/156 rows parse`, 119 `PASS` rows, 19 `FAIL` rows (every one an intentional negative
  fixture), 36 numbered sections + `4b`/`7b` = 38 arms, loadavg 6.79 (1 min) at run time.
- verdict binding (`docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl main`):
  `verdict_artifacts_checked=22`, `orphan_count=1` — `CF-077` still binds pre-rewrite `1dfb58b8`, which
  no branch contains. Already filed as **CF-181** (pending); not re-filed.

## Deliverable 3 — docs against the board

| Doc | Claim | Measured at `202fb61` | Disposition |
|---|---|---|---|
| `docs/BOARD.md` "Current measured state" | 127 rows / 193 events / 40 complete / 5 in_progress / 82 pending at `dae4e7a` | 156 rows / 295 events / 50 / 8 / 98 | **Fixed this commit** — the stale bullet is re-labelled historical and a current named-tip snapshot sits above it |
| `docs/ACCEPTANCE-PLAN.md` "Current state" | 36 sections, 38 arms, 119 `PASS`, 154 rows / 291 events at `8b81369` | 36 sections, 38 arms, 119 `PASS` at `202fb61`; that tip's board is 154 / 291 | **No change** — internally correct at the tip it names; a moved tip is not drift |
| `docs/audits/cf099-prd-drift-probe.sh` | plan snapshot vs working tree | `OK: milestone, plan snapshot and layer arms agree at 202fb61`, rc 0 | **No change** |

No requirement table maps a board task id to a status word, so the "complete row, pending table"
case does not occur in this tree. Note for any future checker: `CF-101`–`CF-112` in
`docs/PRD-code-factory.md` and `docs/ACCEPTANCE-PLAN.md` are *requirement* ids, not task ids — joining
them to board rows by id produces false drift, which is what **CF-182** (pending) records.

The `docs/BOARD.md` block stays hand-typed after this commit: **CF-081** still owns replacing it with
a committed check that fails on a mismatch, and **CF-154** still owns the warning-count claim. This
commit corrects the numbers, not the class.

## Gates at the landing tree

```
bash tests/selftest.sh                    -> SELFTEST: PASS (exit 0)
bash scripts/boardctl validate            -> RESULT: OK (3 warning(s)) (exit 0)
bash docs/audits/cf099-prd-drift-probe.sh -> OK at 202fb61 (exit 0)
python3 docs/audits/cf181-verdict-binding-sweep.py … -> verdict_artifacts_checked=22, orphan_count=1
gh run list --repo coding-hermes/code-factory --limit 3 -> [] (no GitHub Actions in this repo; the
  CI-equivalent gate is tests/selftest.sh plus the gitreins guard, and an empty run list is not
  evidence of health)
```

## Residue (disclosed, not cleaned)

- `/home/kara/code-factory` remains behind the published tip with a sibling's three modified files and
  its untracked `.gitreins/history/` bundles; none were read as this tick's evidence or touched.
- `docs/BOARD.md` keeps its older 116-row/168-event bullet verbatim; it is labelled an earlier
  snapshot, and CF-154 owns the `44 probe rows` sentence it quotes.

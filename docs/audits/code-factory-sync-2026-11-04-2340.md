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

## Addendum — re-execution of the same tick: the cited tip did not resolve

Tick `code-factory-sync-2026-11-04-23-34-25` ran a second time (the scheduler row still reads
`status=running` for that id, and the first execution's commits `6da74d3` and this file are on
`origin/main`, so this is the same tick resumed, not a new lane). The durable claims above were
verified rather than re-derived, and one of them did not hold.

**The tip label above was wrong.** `ac844cb` resolves to no object in this repository:

```sh
$ git cat-file -e 'ac844cb^{commit}'; echo rc=$?
fatal: Not a valid object name ac844cb^{commit}
rc=128
$ git cat-file --batch-all-objects --batch-check | grep -c '^ac844c'
0
$ git rev-parse 6da74d3^
1124ae0c7e457dd2c80ea9196c84eb37709b385f      # the commit that wrote the block
$ git show 1124ae0:.coding-hermes/board/tasks.jsonl | wc -l
180                                            # so the 180 rows it reported were 1124ae0's board
```

It is the pre-rebase local tip that `git pull --rebase` discarded: real at measurement time, never
published, and unverifiable to every later reader. The counts were honest; the label was not, and the
same phantom SHA appears in the addendum above (a historical record, left as written).

**Correction.** "Current measured state" is re-measured at published tip `3f6115e` — 181 task rows,
366 events (max id 365, one benign duplicate 336 owned by CF-196), 62 `complete` / 9 `in_progress` /
110 `pending` — and the block now says the tip label is hand-typed too, with **CF-081** owning both
the counters and the label (a derived check emits the measured tip and asserts it resolves, so the
existing row covers this instance; no second row was filed).

Re-verified at `3f6115e` in a fresh clone, porcelain 0:

| Check | Command | Result |
|---|---|---|
| board parses | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))`; `key uniformity: 181/181 rows carry only canon keys (0 drift)` |
| board = published | `python3 scripts/board_drift.py check --workdir . --ref main` | `RESULT: OK`, `181 vs 181 rows; 0 divergent ids` |
| gate | `bash tests/selftest.sh` | `SELFTEST: PASS` (rc 0), `PASS 181/181 rows parse`, 195 PASS / 50 FAIL rows (all in negative fixtures) |
| arms | `bash docs/audits/cf198-section-mapping.sh` | `arms_plan=42 arms_tree=42`, `RESULT: OK` |
| complete rows bind real commits | `git cat-file -e <sha>^{commit}` + `git merge-base --is-ancestor <sha> origin/main` over all 62 | 62/62 present, 62/62 ancestors of `origin/main` |
| completion evidence is in-tree | artifacts test over all 75 evidence entries | 0 rows whose artifacts are all prunable scratch paths; CF-011/CF-013 rebind (2026-11-03) still holds |
| cited tip resolves | `git cat-file -e 3f6115e^{commit}` | exit 0; `git show 3f6115e:.coding-hermes/board/{tasks,events}.jsonl \| wc -l` = 181 / 366 |

Residual, not filed (each already owned): 35 of 62 `complete` rows carry no `probe` (the
convention gap behind CF-074), one evidence entry on CF-153 lacks `tree_fp` while 74 of 75 peers
carry one, and CF-032/CF-041 each carry one artifact-less entry beside artifact-bearing ones.
Loadavg at measurement: 26.37 (1 min); sibling lanes on this host.

---

## Addendum 3 — 2026-11-05T00:41Z, third execution of the same tick id

This tick id had already run twice (this document is the record of the second pass, and its
DuckBrain receipt `14ef5f98-1121-4d8d-b889-fd0a9c273d88` names the first). This pass implemented
nothing that a previous pass closed. It re-measured the **new** published tip, which neither
earlier pass saw.

Why a third sample was worth taking: the published tip moved twice while this session was
measuring it. `3343b58` (the previous pass's verdict-bundle commit) was the tip at 00:33Z;
the ops lane then landed `d227eff` (the CF-206 census fix, re-committed — the earlier local
`dc9e0ea` never reached the remote) and `84dadf3` (CF-206 closure + verdict bundle). At 00:36Z
the registered checkout read `0 0` against `origin/main` with a clean tracked tree, so the
barrier that forced the clone transport on the previous pass had cleared.

Method: a fresh `git clone` of the published remote into tick scratch, `HEAD` = `84dadf3`,
porcelain 0. The registered checkout was **not** written to — it was dirty with four unpushed
rows (`CF-207`–`CF-210`) and an active writer at the start of this pass, and a live sibling
committed `d227eff` + `84dadf3` into it while this pass was running (board line counts sampled
`185/369` at 00:32Z, `185/372` at 00:35Z — the events file grew under observation).

| Check | Command | Result |
|---|---|---|
| board parses | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))`, `key uniformity: 185/185 rows carry only canon keys (0 drift)` |
| board = published | `python3 scripts/board_drift.py check --workdir . --ref origin/main` | `RESULT: OK`, `185 vs 185 rows; 0 divergent ids` |
| line integrity | per-line `json.loads` over both files | tasks 185 parsed / 0 failures / 185 unique ids; events 372 parsed / 0 failures / max id 371 / one benign duplicate 336 (CF-196) |
| status census | `jq` equivalent over `status` | 63 `complete`, 9 `in_progress`, 113 `pending` |
| complete rows bind real commits | `git cat-file -e <sha>^{commit}` + `git merge-base --is-ancestor <sha> origin/main` over all 63 | 63/63 present, 63/63 ancestors of `origin/main` |
| completion evidence resolves | artifact walk over every `detail.evidence[].artifacts` pointer | 85 pointers, **0** missing committed artifacts; 1 section reference (`CF-034` `tests/selftest.sh::clone-error-classification`, by design) |
| verdict binding | `python3 docs/audits/cf181-verdict-binding-sweep.py` | `complete_rows=63 verdict_artifacts_checked=36 orphan_count=2` |
| arms | `bash docs/audits/cf198-section-mapping.sh` | `arms_plan=42 arms_tree=42`, `RESULT: OK` |
| PRD drift | `bash docs/audits/cf099-prd-drift-probe.sh` | `OK: milestone, plan snapshot and layer arms agree at 84dadf3` |
| standing gate | `bash tests/selftest.sh`, three back-to-back runs | PASS (rc 0) / PASS (rc 0) / **FAIL (1)** — intermittent, see below |

### Finding 1 — the standing gate is intermittent at the published tip

Three consecutive runs of `bash tests/selftest.sh` at `84dadf3` (loadavg 30.5, 1 min) printed
`SELFTEST: PASS`, `SELFTEST: PASS`, `SELFTEST: FAIL (1)`. The failing arm is §18:

```
  FAIL  node-create missing-marker admitted an unverified node or rejected control (exit 1)
```

That arm asserts through `printf '%s\n' "$out" | grep -q …` inside a `{ … }` condition
(`tests/selftest.sh:890-892`). Under the suite's `set -uo pipefail`, a `grep -q` that matches and
exits early can hand the writer a SIGPIPE and the pipeline status 141 — so a PASSING condition
grades as a FAIL. This is exactly the class already filed as **CF-168** (pending), which names the
same shape in §7b. **No new row was filed**: attaching a second id to a class CF-168 owns would
split its closure. The concrete new datum for CF-168 is that the hazard is not confined to §7b —
§18 is a second site, and it fires on a loaded host.

Operational consequence, recorded here because the block above quotes this gate: a single red run
of `tests/selftest.sh` on this tree is a candidate false red until it repeats.

### Finding 2 — CF-181's acceptance criterion no longer reproduces

The sweep now reports `orphan_count=2`, and the second orphan is new since the previous pass:

```
CF-077 run=410022a2 artifact=…/410022a2/verdict.json commit=1dfb58b8aa passed=True
CF-206 run=18ef167d artifact=…/18ef167d/verdict.json commit=dc9e0eafa1 passed=True
```

`CF-206` closed as `complete` with `commit_hash=d227eff`, but its verdict bundle binds `dc9e0ea`,
the local commit the ops lane discarded when it re-landed the same patch onto the published tip.
`dc9e0ea` is not an ancestor of `origin/main`, so the closure evidence points at a commit no clone
has — the precise failure mode CF-181 exists to catch.

Pending **CF-181**'s AC0 asserts that the sweep "prints `verdict_artifacts_checked=21` … and
`orphan_count=1`". Both literals are now false (`36`, `2`). Not repaired here: rewriting another
live row's acceptance criteria is a design change, not a sync-lane bookkeeping fix, and CF-181's
own fixer must re-measure anyway. Recorded so that fixer is not surprised by a criterion that
cannot go green.

### Drift found and fixed by this addendum

`docs/BOARD.md` §"Current measured state" carried `3f6115e` / 181 rows / 366 events / 62 `complete`
as its newest entry while the published tip was `84dadf3` / 185 / 372 / 63. A fresh snapshot for
`84dadf3` was added above it and the `3f6115e` entry was relabelled "Earlier snapshot … (historical,
not current)". No earlier bullet was edited. **No board event was appended**: the refreshed block
cites the event count (372) and an `audit` event in the same commit would move that count past the
number the block just published.

Known residual, unchanged and already owned: 35 of 63 `complete` rows carry no `probe` field
(CF-074 class); `CF-011`/`CF-013` each keep one absolute `~/.hermes/cache/scratch/…` log
pointer that no longer exists beside a committed artifact.



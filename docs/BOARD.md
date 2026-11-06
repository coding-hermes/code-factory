# Board operation contract

The project board is Git-tracked JSONL:

- `.coding-hermes/board/tasks.jsonl` — task rows (one JSON object per line).
- `.coding-hermes/board/events.jsonl` — append-only audit events.

Use the repository entrypoint from the repository root:

```sh
scripts/boardctl validate
scripts/boardctl list --json --all
scripts/boardctl show CF-001 --events
scripts/boardctl create --id CF-009 --title "..." --priority P1 \
  --reasoning "..." --acceptance-criteria "1. ..."
scripts/boardctl update CF-009 --status in_progress
scripts/boardctl event --type audit --task-id CF-009 --actor foreman \
  --detail-text "..."
```

`scripts/boardctl` is a project-owned entrypoint, not a second board engine. It invokes the
coding-hermes `boardctl` executable with this repository as its board root. This keeps the
JSONL parser, schema checks, evidence binding, event format and concurrent-write handling in the
canonical tool rather than implementing a weaker duplicate here. The executable must be installed
and on `PATH`; absence fails closed with exit 127. Its upstream project/release is the source of
truth for installation and updates. Do not copy private fleet binaries or credentials into this
public repo.

## Write rules

1. Validate before and after a batch of board edits: `scripts/boardctl validate`.
2. Use `create` to add a row and `update` to change a row's status; do not rewrite either JSONL
   file wholesale or edit them with ad-hoc scripts.
3. A `complete` status requires a bound run/evidence artifact accepted by the CLI. A commit message
   is not completion evidence.
4. Record meaningful transitions with `event`; do not include credentials, private endpoints or
   raw sensitive logs in a public board.
5. Keep task IDs unique and acceptance criteria falsifiable. `tests/selftest.sh` checks row parsing;
   the boardctl validator is the schema/consistency gate.

## Board lock adjudication

`.coding-hermes/board/.lock` can exist in a working tree as untracked 0-byte residue. A
present lock file is **not** proof of a held lock: no shipped script opens it, board
commits land straight through it, and lanes that stand down on the file alone lose whole
ticks to a barrier nobody enforces (CF-119). Before treating the path as held, classify it
with the shipped adjudicator:

```sh
python3 scripts/board_lock.py            # default path .coding-hermes/board/.lock
python3 scripts/board_lock.py <path>     # any lock path
```

It prints exactly one verdict line and exits 0, and never creates, truncates or deletes
the lock:

- `ABSENT` — nothing exists at the path.
- `HELD holder=<pid>` — a live process holds an open fd on the path, or a non-blocking
  exclusive `flock` probe failed with `EWOULDBLOCK`. A held lock means wait.
- `RESIDUE consumers=<n> commits_after_mtime=<n|unknown>` — no holder is proven. Proceed
  with the board write, and **do not delete the file**: residue is recorded, not removed
  (CF-049 tracks the separate handoff that clears it from the registered workdir).

`commits_after_mtime` counts board commits whose commit time is after the lock's mtime —
the number that proves the file never excluded a writer (`unknown` when Git cannot
answer). The file is git-ignored so a clone never carries it as untracked noise.
`tests/selftest.sh` arm 33 proves both arms on fixtures: an unheld 0-byte lock reports
`RESIDUE`, and a lock held by a live `flock` reports `HELD`.

## Publish-drift census

Before editing a checkout's board, run the offline, read-only repository check (local refs
must already be current; the check never fetches):

```sh
python3 scripts/board_drift.py check --workdir <path> --ref origin/main
```

PASS means both board files are readable and byte-identical to the published ref, the task
census agrees, and the workdir's HEAD is an ancestor of that ref **as resolved in the workdir**.
FAIL names the measured mismatch, divergent task IDs, missing files or invalid line numbers; a
zero-row task board is always a FAIL. The final verdict is `RESULT: OK` (exit 0) or
`RESULT: DRIFT` with a failure count (exit 1).

The two legs read Git from two different flags, and naming one does not satisfy the other:

- the **published bytes** come from `--repo <path>` — `git -C <repo> show <ref>:<file>`
  (`scripts/board_drift.py:98,111`); `--repo` defaults to the workdir;
- the **HEAD/ancestry leg** is measured in `--workdir` — `git rev-parse HEAD`,
  `git rev-parse --verify <ref>^{commit}` and `git merge-base --is-ancestor HEAD <ref>` all run
  with `-C <workdir>` (`scripts/board_drift.py:167–172`).

So a workdir that carries no ref named `<ref>` prints `FAIL HEAD ancestry — git rev-parse
--verify origin/main^{commit}: exit 128` and `RESULT: DRIFT (1 failed)` even when `--repo` names
a repository that has the ref; the identical run with `--no-head` prints `RESULT: OK`. Measured
on 2026-11-04 against a workdir fixture holding byte-identical 126-row board files with no
`origin/main` ref (CF-129; transcript `docs/audits/code-factory-docs-2026-11-04-CF-129.md`).
Pass `--no-head` when the ref lives only in `--repo`. `--published-dir <dir>` reads fixture files
instead of Git and implies `--no-head`.

Observed on 2026-11-03 before the workdir repair: the registered code-factory workdir
(`~/proj-wt-code-factory-bankai-20261030`) carried 61 tasks rows / 66 events rows against
88 / 124 at `origin/main` `6e8621f`. CF-053, CF-064, CF-065, CF-075 and PERF-014 read
`pending` there while `complete` at `origin/main`. This is a dated observation, not a current
health claim. `scripts/board_drift.py` is the re-runnable tool; `tests/selftest.sh` arm 29
proves its divergent, identical, empty, missing-file and malformed-record fixture paths.

## Current measured state (newest snapshot names the tip it was measured at)

Every count below is an output value that moves with each folded row, so measure it instead of
quoting an older snapshot. The numbers are still typed by hand — CF-081 tracks replacing this block
with a committed check that derives them and fails on a mismatch. The tip label is typed by hand as
well, so check that it resolves before trusting the block: the 2026-11-04T23:40Z revision cited
`ac844cb`, which is not an object in this repository — the commit that wrote it (`6da74d3`) has
parent `1124ae0`, and the 180 rows it reported are that parent's board, not a tip of its own.

```sh
wc -l .coding-hermes/board/tasks.jsonl .coding-hermes/board/events.jsonl
scripts/boardctl validate
bash tests/selftest.sh | grep -E 'rows parse|^SELFTEST'
```

- **Re-measured 2026-11-06T00:06Z at tip `4d84d5a`:** 344 task rows, 462 events (max event id 461;
  one benign duplicate id 336, owned by **CF-196**) — 70 `complete`, 14 `in_progress`, 260 `pending`,
  no duplicate task ids. Both board files are byte-identical to their `origin/main` copies
  (`python3 scripts/board_drift.py check --workdir . --ref origin/main` prints `RESULT: OK`,
  344 vs 344 rows, 0 divergent ids). `scripts/boardctl validate` prints `RESULT: OK (6 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result`, CF-150's and CF-192's title/priority drift, the
  duplicate event id 336 and the headerless board) and
  `key uniformity: 344/344 rows carry only canon keys (0 drift)`. 70/70 `complete` rows bind a commit
  that exists and is an ancestor of `origin/main`, and 79 evidence artifact pointers (71 unique
  paths) resolve: 78 as bare paths, plus CF-034's single anchored pointer
  `tests/selftest.sh::clone-error-classification`, whose file part exists and whose anchor occurs
  once in that file — a `test -e` on the whole string reports it as missing and is wrong.
  `tests/selftest.sh` printed `SELFTEST: PASS` (rc 0) on a CLEAN WORKTREE of this tip,
  `PASS 344/344 rows parse`, 342 `PASS` rows and 58 `FAIL` rows that all sit inside negative
  fixtures, at loadavg 25.25 (1 min) — the same suite run against the shared checkout's dirty tree
  printed `SELFTEST: FAIL (18)` because a sibling lane had `scripts/harness/harness-vars.sh`
  untracked while `install-hermes.sh` referenced it (`staged_set` arms); the tip is green, the
  dirty tree was not the tip. The verdict-binding sweep prints
  `complete_rows=70 verdict_artifacts_checked=42 orphan_count=1`: only **CF-077** (owned by pending
  **CF-181**), down from the 2 this block recorded at `bc02e2c`, so CF-181's AC0 — which asserts
  `orphan_count=1` — reproduces again as written. Three sibling rows still own the structural fixes
  for this block: **CF-081** (the hand-typed counts and the hand-typed tip label), **CF-154** (the
  warning count does not follow from the board) and **CF-196** (duplicate event ids).
- **Earlier snapshot, 2026-11-05T10:07Z at tip `bc02e2c` (historical, not current):** 214 task rows, 403 events (max event id 402;
  one benign duplicate id 336, owned by **CF-196**) — 63 `complete`, 11 `in_progress`, 140 `pending`,
  no duplicate task ids. Both board files are byte-identical to their `origin/main` copies
  (`python3 scripts/board_drift.py check --workdir . --ref origin/main` prints `RESULT: OK`,
  214 vs 214 rows, 0 divergent ids). `scripts/boardctl validate` prints `RESULT: OK (4 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result`, the duplicate event id 336 and the headerless board)
  and `key uniformity: 214/214 rows carry only canon keys (0 drift)`. 63/63 `complete` rows bind a
  commit that exists and is an ancestor of `origin/main`, and 71 evidence artifact pointers
  (62 unique paths) resolve in the tree (0 missing). `tests/selftest.sh` printed `SELFTEST: PASS`
  (rc 0) on three consecutive runs, `PASS 214/214 rows parse`, 284 `PASS` rows and 57 `FAIL` rows that
  all sit inside negative fixtures, at loadavg 8.62 / 7.51 / 6.82 (1 min) — deterministic at this tip,
  unlike the intermittent runs recorded against `84dadf3`. The verdict-binding sweep prints
  `complete_rows=63 verdict_artifacts_checked=36 orphan_count=2`: **CF-077** (owned by pending
  **CF-181**) and **CF-206**, whose bundle binds `dc9e0ea`, a commit the ops lane superseded with
  `d227eff` — so CF-181's own AC0, which asserts `orphan_count=1`, no longer reproduces as written.
  Four `complete` rows (**CF-034**, **CF-041**, **CF-182**, **CF-197**) carry no `task_completed`
  event, unchanged and owned by **CF-130**. Three sibling rows still own the structural fixes for this
  block: **CF-081** (the hand-typed counts and the hand-typed tip label), **CF-154** (the warning
  count does not follow from the board) and **CF-196** (duplicate event ids).
- **Earlier snapshot, 2026-11-05T00:41Z at tip `84dadf3` (historical, not current):** 185 task rows, 372 events (max event id 371;
  one benign duplicate id 336, owned by **CF-196**) — 63 `complete`, 9 `in_progress`, 113 `pending`,
  no duplicate task ids. Both board files are byte-identical to their `origin/main` copies
  (`python3 scripts/board_drift.py check --workdir . --ref origin/main` prints `RESULT: OK`,
  185 vs 185 rows, 0 divergent ids). `scripts/boardctl validate` prints `RESULT: OK (4 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result`, the duplicate event id 336 and the headerless board)
  and `key uniformity: 185/185 rows carry only canon keys (0 drift)`. 63/63 `complete` rows bind a
  commit that exists and is an ancestor of `origin/main`, and 85 evidence artifact pointers resolve
  in the tree (0 missing; the two prunable absolute scratch logs on **CF-011**/**CF-013** sit beside
  committed artifacts on the same rows). `tests/selftest.sh` is **intermittent** at this tip: three
  back-to-back runs printed `SELFTEST: PASS` (rc 0), `PASS` (rc 0), then `SELFTEST: FAIL (1)` on the
  §18 arm `node-create missing-marker admitted an unverified node or rejected control` — a
  `printf | grep -q` assertion that answers 141 on SIGPIPE under `set -uo pipefail`, the **CF-168**
  class (which names the same shape in §7b). Read one red run as a candidate false red until it
  repeats. The verdict-binding sweep prints `complete_rows=63 verdict_artifacts_checked=36
  orphan_count=2`: **CF-077** (owned by pending **CF-181**) and **CF-206**, whose bundle binds
  `dc9e0ea`, a commit the ops lane superseded with `d227eff` — so CF-181's own AC0, which asserts
  `orphan_count=1`, no longer reproduces as written. Three sibling rows still own the structural
  fixes for this block: **CF-081** (the hand-typed counts and the hand-typed tip label), **CF-154**
  (the warning count does not follow from the board) and **CF-196** (duplicate event ids).
- **Earlier snapshot, 2026-11-04T23:53Z at tip `3f6115e` (historical, not current):** 181 task rows, 366 events (max event id 365;
  one benign duplicate id 336, owned by **CF-196**) — 62 `complete`, 9 `in_progress`, 110 `pending`,
  no duplicate task ids. Both board files are byte-identical to their `origin/main` copies
  (`python3 scripts/board_drift.py check --workdir . --ref main` prints `RESULT: OK`, 181 vs 181 rows,
  0 divergent ids). `scripts/boardctl validate` prints `RESULT: OK (4 warning(s))` (CF-034's free-form
  `guard_result`/`ci_result`, the duplicate event id 336 and the headerless board) and
  `key uniformity: 181/181 rows carry only canon keys (0 drift)`. `tests/selftest.sh` prints
  `SELFTEST: PASS` (exit 0), `PASS 181/181 rows parse`, 195 `PASS` rows and 50 `FAIL` rows that all sit
  inside negative fixtures (gateway public-bind refusals, the board-gate rejects, `2 of 3 rows parse`,
  the disk-floor empty-PATH arm) over 39 numbered sections plus lettered arms `4b`/`7b`/`31b`
  (42 arms; `bash docs/audits/cf198-section-mapping.sh` prints `arms_plan=42 arms_tree=42`,
  `RESULT: OK`), at loadavg 26.37 (1 min; sibling
  lanes and judges on this host, not a suite property). Three sibling rows still own the structural
  fixes for this block: **CF-081** (the hand-typed counts and the hand-typed tip label), **CF-154**
  (the warning count does not follow from the board) and **CF-196** (duplicate event ids).
- **Earlier snapshot, 2026-11-04T08:52Z at tip `7232954` (historical, not current):** 158 task rows, 300 events — 51 `complete`,
  8 `in_progress`, 99 `pending`, no duplicate task or event ids. `scripts/boardctl validate` prints
  `RESULT: OK (3 warning(s))` (CF-034's free-form `guard_result`/`ci_result` plus the headerless
  board) and `key uniformity: 158/158 rows carry only canon keys (0 drift)`. `tests/selftest.sh`
  prints `SELFTEST: PASS` (exit 0), `PASS 158/158 rows parse`, 119 `PASS` rows and 19
  intentional-fixture `FAIL` rows, 36 numbered sections plus lettered arms `4b`/`7b` (38 arms), at
  loadavg 6.77 (1 min; host load, not a suite property). Three sibling rows own the structural
  fixes for this block: **CF-081** (the hand-typed counts), **CF-154** (the warning count does not
  follow from the board) and **CF-155** (the plan's section count).
- **Earlier snapshot, 2026-11-04T08:42Z at tip `202fb61` (historical, not current):** 156 task rows, 295 events — 50 `complete`,
  8 `in_progress`, 98 `pending`. `scripts/boardctl validate` prints `RESULT: OK (3 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result` plus the headerless board) and
  `key uniformity: 156/156 rows carry only canon keys (0 drift)`. `tests/selftest.sh` prints
  `SELFTEST: PASS`, `PASS 156/156 rows parse`, 119 `PASS` rows and 19 intentional-fixture `FAIL`
  rows, 36 numbered sections plus lettered arms `4b`/`7b` (38 arms), at loadavg 6.79 (1 min; host
  load, not a suite property). Two sibling rows own the structural fix for this block: **CF-154**
  (the warning count does not follow from the board) and **CF-155** (the plan's section count).
- **Earlier snapshot, 2026-11-04T03:01Z at tip `dae4e7a` (historical, not current):** 127 task rows, 193 events — 40 `complete`,
  5 `in_progress`, 82 `pending`. `scripts/boardctl validate` prints `RESULT: OK (3 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result` plus the headerless board); the 44 `probe`-key
  warnings are gone because CF-129 relanded canon keys (`key uniformity: 127/127 rows`).
  `tests/selftest.sh` prints `SELFTEST: PASS`, `PASS 127/127 rows parse`, 92 `PASS` rows, 30
  numbered sections plus lettered arms `4b`/`7b`, at loadavg 15.60.
- At this tree (earlier snapshot, 116 task rows, 168 events): `scripts/boardctl validate` prints
  `RESULT: OK (47 warning(s))` — 44 rows carrying a free-form `probe` key, CF-034's free-form
  `guard_result`/`ci_result` prose, and the headerless board (no `board.jsonl`), so header-counter
  checks are skipped.
- `tests/selftest.sh` prints `PASS 116/116 rows parse` and `SELFTEST: PASS` (exit 0; 29 numbered
  sections plus lettered arms 4b and 7b — 31 arms).
  Nineteen `  FAIL` lines appear *inside* negative fixtures that assert a failure arm; count
  `SELFTEST:` and the per-section verdicts, never a raw `grep -c '^  FAIL'`.
- A `complete` row must bind the commit that carried it, not only an evidence artifact: CF-053
  reached `complete` with `commit_hash: null` and `worker_status: pending`, and now carries
  `80fca8b` (the commit that closed it) with the repoint re-verified by
  `scripts/lane_target.py scan` over the 19 code-factory lanes (`bad: 0`, `ok: true`).
- Two rows (CF-034, CF-041) are `complete` and commit-bound but carry no `task_completed` event;
  event 168 (audit, 2026-11-04) records the gap and CF-130 owns the reconciliation. No completion
  transition was minted for either id, because the log must not record a transition its writer did
  not witness.
- The CI-equivalent gate is not deterministic under load: `tests/selftest.sh` returned
  `SELFTEST: FAIL (1)` once in four runs at one tip on an unchanged tree, on the auth-marker arm.
  CF-142 tracks the reproduction and requires 20 consecutive agreeing runs plus a recorded loadavg.
  Before believing a single red, re-run it; before believing a single green, note the load.
- Completion evidence must live in this repository. Two rows (CF-011, CF-013) once cited an
  absolute scratch log outside the tree; the sync lane rebound them to a committed artifact —
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` records the re-run commands and
  captured output.
- CF-012 is complete on the published tip with `docs/traceability-doctrine.md` and its committed
  evidence artifact; the row's closeout is bound to the board evidence record and GitReins verdict.
- The project wrapper is a dispatch shim; the authoritative board implementation remains the
  external coding-hermes `boardctl` package.

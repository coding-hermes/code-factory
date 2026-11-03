# Verdict: CF-117-QA2

**Task:** QA filing repair: CF-117/CF-118 AC1 count-relative, no absolute row-count literals
**Evaluated:** 2026-11-03T20:36:28.350177
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ CF-117-QA2 grades a FILING REPAIR, not a fix. Do NOT evaluate the underlying defects and do NOT require either fix to exist: both rows are `pending` by definition. This task exists because CF-117-QA1 (verdict 2c542a5d) correctly rejected the first filing: its acceptance criteria quoted absolute row counts (`91 vs 90`, `90 vs 90`) measured on the pre-filing 90-row board, so the probe output can never match again. The repair makes AC1 count-relative. Grade only that the repair landed and that the probes reproduce with the literals gone.

Leg 1 — the repair commit is board-only and carries the repair. `git show --name-status HEAD` must name only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl. Then `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117" or .id=="CF-118") | [.id,.status,((.acceptance_criteria|test("N\\+1 vs N rows|N vs N rows"))|tostring),((.acceptance_criteria|test("91 vs 90|90 vs 90 rows"))|tostring)] | @tsv'` must print two lines that both read: the id, `pending`, `true` for the count-relative phrasing, and `false` for the absolute-count phrasing.

Leg 2 — re-run CF-117's probe, extracted from the COMMITTED board, from the repo root:
`P=$(git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117").probe'); printf '%s\n' "$P" > /tmp/cf117-probe.sh; bash /tmp/cf117-probe.sh`
It must print today, matching these PATTERNS (exact row counts are expected to move with the board and are NOT graded):
  FAIL  board extra ids — CF-999
  FAIL  board rows — <N+1> vs <N> rows; 1 divergent ids: CF-999
  RESULT: DRIFT (3 failed)
  drift_rc=1
A line reading `91 vs 90` is NOT required and must not be required; only the named id and the `N+1 vs N` shape with one divergent id.

Leg 3 — re-run CF-118's probe the same way (`select(.id=="CF-118").probe`). It must print today:
  FAIL  byte parity tasks.jsonl — bytes differ
  PASS  board rows — <N> vs <N> rows; 0 divergent ids: none
  RESULT: DRIFT (1 failed)
  named_ids=0
  drift_rc=1

Leg 4 — gates at the repair commit: `bash tests/selftest.sh` ends `SELFTEST: PASS` (exit 0); `scripts/boardctl validate` prints `RESULT: OK` (exit 0); `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` exits 0; `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.

Pass only if legs 1-4 hold. Fail if either committed row still quotes `91 vs 90` or `90 vs 90 rows` inside its acceptance criteria, or if a probe's named-id lines do not reproduce.: Leg 1: `git show --name-status HEAD` (c842d0b) lists only `M .coding-hermes/board/events.jsonl` and `M .coding-hermes/board/tasks.jsonl`. The jq check printed exactly `CF-117\tpending\ttrue\tfalse` and `CF-118\tpending\ttrue\tfalse` — both rows pending, count-relative phrasing present, absolute-count phrasing absent; AC text now reads `N+1 vs N rows; 1 divergent ids: CF-999` (CF-117) and `N vs N rows; 0 divergent ids: none` (CF-118), with no `91 vs 90` / `90 vs 90 rows` literals. Leg 2: CF-117 probe from committed board printed `FAIL  board extra ids — CF-999`, `FAIL  board rows — 93 vs 92 rows; 1 divergent ids: CF-999`, `RESULT: DRIFT (3 failed)`, `drift_rc=1` — all required patterns, N+1 vs N shape, no literal required. Leg 3: CF-118 probe printed `FAIL  byte parity tasks.jsonl — bytes differ`, `PASS  board rows — 92 vs 92 rows; 0 divergent ids: none`, `RESULT: DRIFT (1 failed)`, `named_ids=0`, `drift_rc=1`. Leg 4: `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0; `scripts/boardctl validate` -> `RESULT: OK (33 warning(s))`, exit 0; `jq -c . .coding-hermes/board/tasks.jsonl` exit 0; duplicate-id check printed nothing (DUPES_LEN=0). All four legs hold; no fix was required or evaluated.
The board-only repair commit landed: both CF-117/CF-118 AC1s are count-relative with the absolute literals gone, both probes reproduce their required named-id/DRIFT shapes, and all four gates pass at HEAD.

## Summary

Judge Result: CF-117-QA2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ CF-117-QA2 grades a FILING REPAIR, not a fix. Do NOT evaluate the underlying defects and do NOT require either fix to exist: both rows are `pending` by definition. This task exists because CF-117-QA1 (verdict 2c542a5d) correctly rejected the first filing: its acceptance criteria quoted absolute row counts (`91 vs 90`, `90 vs 90`) measured on the pre-filing 90-row board, so the probe output can never match again. The repair makes AC1 count-relative. Grade only that the repair landed and that the probes reproduce with the literals gone.

Leg 1 — the repair commit is board-only and carries the repair. `git show --name-status HEAD` must name only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl. Then `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117" or .id=="CF-118") | [.id,.status,((.acceptance_criteria|test("N\\+1 vs N rows|N vs N rows"))|tostring),((.acceptance_criteria|test("91 vs 90|90 vs 90 rows"))|tostring)] | @tsv'` must print two lines that both read: the id, `pending`, `true` for the count-relative phrasing, and `false` for the absolute-count phrasing.

Leg 2 — re-run CF-117's probe, extracted from the COMMITTED board, from the repo root:
`P=$(git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117").probe'); printf '%s\n' "$P" > /tmp/cf117-probe.sh; bash /tmp/cf117-probe.sh`
It must print today, matching these PATTERNS (exact row counts are expected to move with the board and are NOT graded):
  FAIL  board extra ids — CF-999
  FAIL  board rows — <N+1> vs <N> rows; 1 divergent ids: CF-999
  RESULT: DRIFT (3 failed)
  drift_rc=1
A line reading `91 vs 90` is NOT required and must not be required; only the named id and the `N+1 vs N` shape with one divergent id.

Leg 3 — re-run CF-118's probe the same way (`select(.id=="CF-118").probe`). It must print today:
  FAIL  byte parity tasks.jsonl — bytes differ
  PASS  board rows — <N> vs <N> rows; 0 divergent ids: none
  RESULT: DRIFT (1 failed)
  named_ids=0
  drift_rc=1

Leg 4 — gates at the repair commit: `bash tests/selftest.sh` ends `SELFTEST: PASS` (exit 0); `scripts/boardctl validate` prints `RESULT: OK` (exit 0); `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` exits 0; `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.

Pass only if legs 1-4 hold. Fail if either committed row still quotes `91 vs 90` or `90 vs 90 rows` inside its acceptance criteria, or if a probe's named-id lines do not reproduce.: Leg 1: `git show --name-status HEAD` (c842d0b) lists only `M .coding-hermes/board/events.jsonl` and `M .coding-hermes/board/tasks.jsonl`. The jq check printed exactly `CF-117\tpending\ttrue\tfalse` and `CF-118\tpending\ttrue\tfalse` — both rows pending, count-relative phrasing present, absolute-count phrasing absent; AC text now reads `N+1 vs N rows; 1 divergent ids: CF-999` (CF-117) and `N vs N rows; 0 divergent ids: none` (CF-118), with no `91 vs 90` / `90 vs 90 rows` literals. Leg 2: CF-117 probe from committed board printed `FAIL  board extra ids — CF-999`, `FAIL  board rows — 93 vs 92 rows; 1 divergent ids: CF-999`, `RESULT: DRIFT (3 failed)`, `drift_rc=1` — all required patterns, N+1 vs N shape, no literal required. Leg 3: CF-118 probe printed `FAIL  byte parity tasks.jsonl — bytes differ`, `PASS  board rows — 92 vs 92 rows; 0 divergent ids: none`, `RESULT: DRIFT (1 failed)`, `named_ids=0`, `drift_rc=1`. Leg 4: `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0; `scripts/boardctl validate` -> `RESULT: OK (33 warning(s))`, exit 0; `jq -c . .coding-hermes/board/tasks.jsonl` exit 0; duplicate-id check printed nothing (DUPES_LEN=0). All four legs hold; no fix was required or evaluated.
The board-only repair commit landed: both CF-117/CF-118 AC1s are count-relative with the absolute literals gone, both probes reproduce their required named-id/DRIFT shapes, and all four gates pass at HEAD.

Overall: PASS ✓

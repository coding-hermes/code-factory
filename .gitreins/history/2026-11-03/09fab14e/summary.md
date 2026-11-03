# Verdict: CF-117-QA1

**Task:** QA filing: the publish-drift census cannot tell ahead from stale, and names no row on content-only drift
**Evaluated:** 2026-11-03T20:33:57.197503
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ CF-117-QA1 grades a FILING, not a fix. Do NOT evaluate the underlying defects and do NOT require either fix to exist: both filed rows are `pending` by definition. Grade only that the filing landed and that its probes reproduce.

Leg 1 — the filing commit is board-only and carried both rows. Run `git show --stat HEAD` and `git show --name-status HEAD`: it must touch only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl, with 2 added tasks rows and 2 added events rows and 0 deletions. Then `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117" or .id=="CF-118") | [.id,.status,(.probe|length)] | @tsv'` must print two lines, both `pending`, with a non-empty probe length.

Leg 2 — re-run CF-117's probe, extracted from the COMMITTED board, from the repo root:
`P=$(git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117").probe'); printf '%s\n' "$P" > /tmp/cf117-probe.sh; bash /tmp/cf117-probe.sh`
It must print, today, on the current tree:
  FAIL  byte parity tasks.jsonl — bytes differ
  FAIL  board extra ids — CF-999
  FAIL  board rows — 91 vs 90 rows; 1 divergent ids: CF-999
  RESULT: DRIFT (3 failed)
  drift_rc=1

Leg 3 — re-run CF-118's probe the same way (`select(.id=="CF-118").probe`). It must print, today:
  FAIL  byte parity tasks.jsonl — bytes differ
  PASS  board rows — 90 vs 90 rows; 0 divergent ids: none
  RESULT: DRIFT (1 failed)
  named_ids=0
  drift_rc=1

Leg 4 — the gates at the filing commit: `bash tests/selftest.sh` ends `SELFTEST: PASS` (exit 0) and `scripts/boardctl validate` prints `RESULT: OK` (exit 0). The board parses whole: `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` exits 0, and every id is unique: `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.

Pass only if legs 1-4 reproduce. A probe whose printed lines differ from the literals above, or a commit that carries anything beyond the two board files, is a FAIL of this filing.: Leg 1 PASS: `git show --numstat HEAD` = `2 0 .coding-hermes/board/events.jsonl` and `2 0 .coding-hermes/board/tasks.jsonl` (only those two files, 2 added / 0 deleted each); jq on committed board prints `CF-117\tpending\t566` and `CF-118\tpending\t560` (both pending, non-empty probes). Leg 4 PASS: `bash tests/selftest.sh` -> exit 0, tail `SELFTEST: PASS`; `scripts/boardctl validate` -> exit 0, `RESULT: OK (33 warning(s))`; `jq -c . .coding-hermes/board/tasks.jsonl` -> jq_rc=0; `jq -r .id ... | sort | uniq -d` printed nothing (92 rows, all unique). Leg 2 FAIL: probe output was `FAIL  byte parity tasks.jsonl — bytes differ` / `FAIL  board extra ids — CF-999` / `FAIL  board rows — 93 vs 92 rows; 1 divergent ids: CF-999` / `RESULT: DRIFT (3 failed)` / `drift_rc=1` — the row-count line reads 93 vs 92, not the required literal `91 vs 90 rows`. Leg 3 FAIL: probe output was `FAIL  byte parity tasks.jsonl — bytes differ` / `PASS  board rows — 92 vs 92 rows; 0 divergent ids: none` / `RESULT: DRIFT (1 failed)` / `named_ids=0` / `drift_rc=1` — the row-count line reads 92 vs 92, not the required literal `90 vs 90 rows`. The probes' expected row counts were baked at the pre-filing 90-row board and no longer reproduce on the current 92-row tree, so the criterion's explicit rule ('A probe whose printed lines differ from the literals above ... is a FAIL of this filing') is triggered.
The filing commit is board-only with both rows pending and all gates green, but both probes print row-count lines (93 vs 92 and 92 vs 92) that differ from the required literals (91 vs 90 and 90 vs 90), so legs 2 and 3 do not reproduce.

## Summary

Judge Result: CF-117-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ CF-117-QA1 grades a FILING, not a fix. Do NOT evaluate the underlying defects and do NOT require either fix to exist: both filed rows are `pending` by definition. Grade only that the filing landed and that its probes reproduce.

Leg 1 — the filing commit is board-only and carried both rows. Run `git show --stat HEAD` and `git show --name-status HEAD`: it must touch only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl, with 2 added tasks rows and 2 added events rows and 0 deletions. Then `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117" or .id=="CF-118") | [.id,.status,(.probe|length)] | @tsv'` must print two lines, both `pending`, with a non-empty probe length.

Leg 2 — re-run CF-117's probe, extracted from the COMMITTED board, from the repo root:
`P=$(git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-117").probe'); printf '%s\n' "$P" > /tmp/cf117-probe.sh; bash /tmp/cf117-probe.sh`
It must print, today, on the current tree:
  FAIL  byte parity tasks.jsonl — bytes differ
  FAIL  board extra ids — CF-999
  FAIL  board rows — 91 vs 90 rows; 1 divergent ids: CF-999
  RESULT: DRIFT (3 failed)
  drift_rc=1

Leg 3 — re-run CF-118's probe the same way (`select(.id=="CF-118").probe`). It must print, today:
  FAIL  byte parity tasks.jsonl — bytes differ
  PASS  board rows — 90 vs 90 rows; 0 divergent ids: none
  RESULT: DRIFT (1 failed)
  named_ids=0
  drift_rc=1

Leg 4 — the gates at the filing commit: `bash tests/selftest.sh` ends `SELFTEST: PASS` (exit 0) and `scripts/boardctl validate` prints `RESULT: OK` (exit 0). The board parses whole: `jq -c . .coding-hermes/board/tasks.jsonl > /dev/null` exits 0, and every id is unique: `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.

Pass only if legs 1-4 reproduce. A probe whose printed lines differ from the literals above, or a commit that carries anything beyond the two board files, is a FAIL of this filing.: Leg 1 PASS: `git show --numstat HEAD` = `2 0 .coding-hermes/board/events.jsonl` and `2 0 .coding-hermes/board/tasks.jsonl` (only those two files, 2 added / 0 deleted each); jq on committed board prints `CF-117\tpending\t566` and `CF-118\tpending\t560` (both pending, non-empty probes). Leg 4 PASS: `bash tests/selftest.sh` -> exit 0, tail `SELFTEST: PASS`; `scripts/boardctl validate` -> exit 0, `RESULT: OK (33 warning(s))`; `jq -c . .coding-hermes/board/tasks.jsonl` -> jq_rc=0; `jq -r .id ... | sort | uniq -d` printed nothing (92 rows, all unique). Leg 2 FAIL: probe output was `FAIL  byte parity tasks.jsonl — bytes differ` / `FAIL  board extra ids — CF-999` / `FAIL  board rows — 93 vs 92 rows; 1 divergent ids: CF-999` / `RESULT: DRIFT (3 failed)` / `drift_rc=1` — the row-count line reads 93 vs 92, not the required literal `91 vs 90 rows`. Leg 3 FAIL: probe output was `FAIL  byte parity tasks.jsonl — bytes differ` / `PASS  board rows — 92 vs 92 rows; 0 divergent ids: none` / `RESULT: DRIFT (1 failed)` / `named_ids=0` / `drift_rc=1` — the row-count line reads 92 vs 92, not the required literal `90 vs 90 rows`. The probes' expected row counts were baked at the pre-filing 90-row board and no longer reproduce on the current 92-row tree, so the criterion's explicit rule ('A probe whose printed lines differ from the literals above ... is a FAIL of this filing') is triggered.
The filing commit is board-only with both rows pending and all gates green, but both probes print row-count lines (93 vs 92 and 92 vs 92) that differ from the required literals (91 vs 90 and 90 vs 90), so legs 2 and 3 do not reproduce.

Overall: FAIL ✗

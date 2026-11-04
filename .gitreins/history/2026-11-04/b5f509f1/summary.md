# Verdict: CF-155-QA1

**Task:** QA filing: docs/ACCEPTANCE-PLAN.md is stale by one selftest section (§30) and the CF-099 drift probe exits 1 at HEAD
**Evaluated:** 2026-11-04T03:03:34.393522
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ This task grades a QA FILING, not the underlying fix. Do not evaluate whether the documented drift is repaired; the filed row is pending by definition.: Graded as a filing only: CF-155 row in e9f3085 has status="pending" (verified via `git show e9f3085:.coding-hermes/board/tasks.jsonl | jq -c '{id,status}'` -> "status":"pending"). No evaluation of whether docs/ACCEPTANCE-PLAN.md was repaired; the probe still reds at HEAD (probe_rc=1), which is expected for a pending filing.
  ✓ 1. The filing commit in the graded tree changes exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (plus nothing else): `git show --stat <commit>` lists only board files. State the stat.: `git show --stat e9f3085` output: '.coding-hermes/board/events.jsonl | 2 ++' and '.coding-hermes/board/tasks.jsonl | 3 ++-' -> '2 files changed, 4 insertions(+), 1 deletion(-)'. Only board files; no source/docs files touched. Diff content confirms: tasks.jsonl -1/+2 (CF-079 status line rewritten, CF-155 row appended), events.jsonl +2 (event 196 task_created CF-155, event 197 task_updated CF-079).
  ✓ 2. The committed board carries a row whose title begins `P4 — docs/ACCEPTANCE-PLAN.md still states 29 selftest sections` exactly once (`git show <commit>:.coding-hermes/board/tasks.jsonl | grep -c 'still states 29 selftest sections'` prints 1), the row's `status` is `pending`, and its `probe` field is non-empty.: `git show e9f3085:.coding-hermes/board/tasks.jsonl | grep -c 'still states 29 selftest sections'` printed exactly `1` (rc=0). The row: id=CF-155, title="P4 — docs/ACCEPTANCE-PLAN.md still states 29 selftest sections while tests/selftest.sh has 30: §30 landed at 1b4b0b6 and the row's own shipped drift probe exits 1 at HEAD", status="pending", probe length 230 chars (non-empty).
  ✓ 3. Extract that probe from the COMMITTED tree and run it from the repo root: `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="<row>").probe' > /tmp/p.sh; bash /tmp/p.sh` prints, in order: `30`; a line `7:29 sections — plus two lettered sub-arms`; a line `61:`d02916e`, `tests/selftest.sh` has 29 numbered sections`; `DRIFT: plan says 29 sections, tests/selftest.sh has 30`; `probe_rc=1`. Paste the verbatim output.: Extracted from committed tree and run from repo root. Verbatim output:
30
7:29 sections — plus two lettered sub-arms, §4b and §7b, which the section regex `^say "[0-9]+\.` does
61:`d02916e`, `tests/selftest.sh` has 29 numbered sections plus two lettered sub-arms (§4b, §7b) —
DRIFT: plan says 29 sections, tests/selftest.sh has 30
measured: tip=d02916e rows=117 events=171 sections=30 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-126 CF-131 CF-132 CF-133 CF-136 CF-139 
probe_rc=1
All five required lines appear in the required order; probe_rc=1 as specified.
  ✓ 4. The committed row's id matches `^CF-[0-9]{3}$`, is unique in the committed board (`jq -r .id | sort | uniq -d` prints nothing), and the board line count equals the pre-filing count plus 1.: id=CF-155 matches ^CF-[0-9]{3}$ (grep -E returned CF-155). `git show e9f3085:.coding-hermes/board/tasks.jsonl | jq -r .id | sort | uniq -d` printed nothing (no duplicate ids). Line counts: committed board = 129 lines, parent (e9f3085^) = 128 lines -> 128 + 1 = 129.
  ✓ 5. The same committed board reformatted as JSONL parses (`.coding-hermes/board/tasks.jsonl` every line `jq -c .` rc 0) and `bash scripts/boardctl validate` prints `RESULT: OK`.: Every line of the committed tasks.jsonl piped through `jq -c .` succeeded (loop_rc=0, zero BAD lines). `bash scripts/boardctl validate` printed 'rows: 129 tasks, 197 events, 0 fixtures', 'key uniformity: 129/129 rows carry only canon keys (0 drift)', and 'RESULT: OK (3 warning(s))' with rc=0. The 3 warnings are pre-existing (CF-034 free-form guard_result/ci_result at line 20, headerless board) and unrelated to the CF-155 filing row.
  ✓ 6. The row's `reasoning` field names both commits that make the drift (`1b4b0b6` added §30, `c9848d7` reconciled the snapshot without updating the count) and states the dedupe boundary against CF-113, CF-115 and CF-121.: reasoning (from committed tree) states: '`say "30. README Status rows 1 and 3 cite the interpreter-qualified --check"` landed at 1b4b0b6 (2026-11-03 21:35:05, 'Addresses CF-093'), and the later c9848d7 ('docs(sync): reconcile the board census and the ACCEPTANCE-PLAN snapshot at 2c48149') re-anchored the row/event deltas while leaving the section count and the §29-terminated table untouched.' Dedupe boundary: 'DISTINCT FROM CF-113 (the census regex cannot see LETTERED sub-arms, §7b) and CF-121 (the probe's snapshot leg is a tautology) and CF-115 (legs the probe certifies without measuring)'. All three ids and both commits named.
All six legs verified with live command output: the filing commit e9f3085 touches only the two board files, adds exactly one unique pending CF-155 row with a non-empty probe that reproduces the exact required output (30 / 7: / 61: / DRIFT / probe_rc=1) from the committed tree, board parses and validates RESULT: OK, and the reasoning names 1b4b0b6, c9848d7 and the CF-113/CF-115/CF-121 dedupe boundary.

## Summary

Judge Result: CF-155-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ This task grades a QA FILING, not the underlying fix. Do not evaluate whether the documented drift is repaired; the filed row is pending by definition.: Graded as a filing only: CF-155 row in e9f3085 has status="pending" (verified via `git show e9f3085:.coding-hermes/board/tasks.jsonl | jq -c '{id,status}'` -> "status":"pending"). No evaluation of whether docs/ACCEPTANCE-PLAN.md was repaired; the probe still reds at HEAD (probe_rc=1), which is expected for a pending filing.
  ✓ 1. The filing commit in the graded tree changes exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (plus nothing else): `git show --stat <commit>` lists only board files. State the stat.: `git show --stat e9f3085` output: '.coding-hermes/board/events.jsonl | 2 ++' and '.coding-hermes/board/tasks.jsonl | 3 ++-' -> '2 files changed, 4 insertions(+), 1 deletion(-)'. Only board files; no source/docs files touched. Diff content confirms: tasks.jsonl -1/+2 (CF-079 status line rewritten, CF-155 row appended), events.jsonl +2 (event 196 task_created CF-155, event 197 task_updated CF-079).
  ✓ 2. The committed board carries a row whose title begins `P4 — docs/ACCEPTANCE-PLAN.md still states 29 selftest sections` exactly once (`git show <commit>:.coding-hermes/board/tasks.jsonl | grep -c 'still states 29 selftest sections'` prints 1), the row's `status` is `pending`, and its `probe` field is non-empty.: `git show e9f3085:.coding-hermes/board/tasks.jsonl | grep -c 'still states 29 selftest sections'` printed exactly `1` (rc=0). The row: id=CF-155, title="P4 — docs/ACCEPTANCE-PLAN.md still states 29 selftest sections while tests/selftest.sh has 30: §30 landed at 1b4b0b6 and the row's own shipped drift probe exits 1 at HEAD", status="pending", probe length 230 chars (non-empty).
  ✓ 3. Extract that probe from the COMMITTED tree and run it from the repo root: `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="<row>").probe' > /tmp/p.sh; bash /tmp/p.sh` prints, in order: `30`; a line `7:29 sections — plus two lettered sub-arms`; a line `61:`d02916e`, `tests/selftest.sh` has 29 numbered sections`; `DRIFT: plan says 29 sections, tests/selftest.sh has 30`; `probe_rc=1`. Paste the verbatim output.: Extracted from committed tree and run from repo root. Verbatim output:
30
7:29 sections — plus two lettered sub-arms, §4b and §7b, which the section regex `^say "[0-9]+\.` does
61:`d02916e`, `tests/selftest.sh` has 29 numbered sections plus two lettered sub-arms (§4b, §7b) —
DRIFT: plan says 29 sections, tests/selftest.sh has 30
measured: tip=d02916e rows=117 events=171 sections=30 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-126 CF-131 CF-132 CF-133 CF-136 CF-139 
probe_rc=1
All five required lines appear in the required order; probe_rc=1 as specified.
  ✓ 4. The committed row's id matches `^CF-[0-9]{3}$`, is unique in the committed board (`jq -r .id | sort | uniq -d` prints nothing), and the board line count equals the pre-filing count plus 1.: id=CF-155 matches ^CF-[0-9]{3}$ (grep -E returned CF-155). `git show e9f3085:.coding-hermes/board/tasks.jsonl | jq -r .id | sort | uniq -d` printed nothing (no duplicate ids). Line counts: committed board = 129 lines, parent (e9f3085^) = 128 lines -> 128 + 1 = 129.
  ✓ 5. The same committed board reformatted as JSONL parses (`.coding-hermes/board/tasks.jsonl` every line `jq -c .` rc 0) and `bash scripts/boardctl validate` prints `RESULT: OK`.: Every line of the committed tasks.jsonl piped through `jq -c .` succeeded (loop_rc=0, zero BAD lines). `bash scripts/boardctl validate` printed 'rows: 129 tasks, 197 events, 0 fixtures', 'key uniformity: 129/129 rows carry only canon keys (0 drift)', and 'RESULT: OK (3 warning(s))' with rc=0. The 3 warnings are pre-existing (CF-034 free-form guard_result/ci_result at line 20, headerless board) and unrelated to the CF-155 filing row.
  ✓ 6. The row's `reasoning` field names both commits that make the drift (`1b4b0b6` added §30, `c9848d7` reconciled the snapshot without updating the count) and states the dedupe boundary against CF-113, CF-115 and CF-121.: reasoning (from committed tree) states: '`say "30. README Status rows 1 and 3 cite the interpreter-qualified --check"` landed at 1b4b0b6 (2026-11-03 21:35:05, 'Addresses CF-093'), and the later c9848d7 ('docs(sync): reconcile the board census and the ACCEPTANCE-PLAN snapshot at 2c48149') re-anchored the row/event deltas while leaving the section count and the §29-terminated table untouched.' Dedupe boundary: 'DISTINCT FROM CF-113 (the census regex cannot see LETTERED sub-arms, §7b) and CF-121 (the probe's snapshot leg is a tautology) and CF-115 (legs the probe certifies without measuring)'. All three ids and both commits named.
All six legs verified with live command output: the filing commit e9f3085 touches only the two board files, adds exactly one unique pending CF-155 row with a non-empty probe that reproduces the exact required output (30 / 7: / 61: / DRIFT / probe_rc=1) from the committed tree, board parses and validates RESULT: OK, and the reasoning names 1b4b0b6, c9848d7 and the CF-113/CF-115/CF-121 dedupe boundary.

Overall: PASS ✓

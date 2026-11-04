# Verdict: CF-SYNC-20261104-0958

**Task:** sync lane: reconcile board/docs at published tip e0e73bd
**Evaluated:** 2026-11-04T10:05:40.029484
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ At the commit this task lands in: bash scripts/boardctl validate prints RESULT: OK; bash tests/selftest.sh exits 0 with SELFTEST: PASS; .coding-hermes/board/tasks.jsonl and events.jsonl parse line by line and are byte-identical to their origin/main copies; the seven-class evidence census over every complete row reports zero findings; and docs/ACCEPTANCE-PLAN.md carries a delta bullet stamped 2026-11-04T09:58Z naming tip e0e73bd, the row/event counts and the selftest arm count those commands measure there.: Partial pass, but two required legs fail at commit 4295860. (a) PASS: `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, exit 0 (166 tasks, 335 events). (b) PASS: `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`, 190 `  PASS` rows / 50 `  FAIL` rows (fixture rejections), 37 numbered sections + 4b/7b/31b = 40 arms. (c) PASS parse: all 166 tasks.jsonl and 335 events.jsonl lines parse via json.loads, zero duplicate ids. (d) FAIL byte-identical to origin/main: `python3 scripts/board_drift.py check --workdir . --ref origin/main` -> `FAIL byte parity tasks.jsonl — bytes differ`, `FAIL byte parity events.jsonl — bytes differ`, `FAIL board extra ids — CF-192`, `FAIL board rows — 166 vs 165 rows`, `FAIL HEAD ancestry — ... not an ancestor`, `RESULT: DRIFT (5 failed)`, exit 1. `git diff origin/main HEAD` shows tasks.jsonl +1 row (CF-192) and events.jsonl +2 rows (ids 334, 335). (e) PASS census: `board-evidence-census.sh . .coding-hermes/board/tasks.jsonl origin/main` -> `complete_rows=56 finding_lines=0` with NO_SHA/NO_OBJECT/NOT_ON_REF/NO_EVIDENCE/NO_ARTIFACT_LATEST/ABSOLUTE_PATH/NOT_IN_TREE all 0. (f) FAIL counts in the doc bullet: docs/ACCEPTANCE-PLAN.md line 9 reads `**Delta measured 2026-11-04T09:58Z at tip `e0e73bd` (sync lane):** the board carries 165 task rows and 333 events (56 `complete`, 101 `pending`, 8 `in_progress`) ... so **40 arms**`, but at this commit the board measures 166 rows / 335 events (56 complete, 102 pending, 8 in_progress) — the row/event counts do not match what the commands measure here, and the same stale 165/333 figures are repeated in the audit event 335 detail. The stamp, tip and 40-arm figure are correct; the row/event counts are not.
boardctl validate, selftest (40 arms), JSONL parsing and the seven-class census (56 rows, 0 findings) all pass, but the board files are not byte-identical to origin/main (board_drift.py -> RESULT: DRIFT, 166 vs 165 rows, extra CF-192, 335 vs 334 events) and the 09:58Z delta bullet states 165 rows/333 events instead of the 166/335 measured at this commit.

## Summary

Judge Result: CF-SYNC-20261104-0958

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ At the commit this task lands in: bash scripts/boardctl validate prints RESULT: OK; bash tests/selftest.sh exits 0 with SELFTEST: PASS; .coding-hermes/board/tasks.jsonl and events.jsonl parse line by line and are byte-identical to their origin/main copies; the seven-class evidence census over every complete row reports zero findings; and docs/ACCEPTANCE-PLAN.md carries a delta bullet stamped 2026-11-04T09:58Z naming tip e0e73bd, the row/event counts and the selftest arm count those commands measure there.: Partial pass, but two required legs fail at commit 4295860. (a) PASS: `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, exit 0 (166 tasks, 335 events). (b) PASS: `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`, 190 `  PASS` rows / 50 `  FAIL` rows (fixture rejections), 37 numbered sections + 4b/7b/31b = 40 arms. (c) PASS parse: all 166 tasks.jsonl and 335 events.jsonl lines parse via json.loads, zero duplicate ids. (d) FAIL byte-identical to origin/main: `python3 scripts/board_drift.py check --workdir . --ref origin/main` -> `FAIL byte parity tasks.jsonl — bytes differ`, `FAIL byte parity events.jsonl — bytes differ`, `FAIL board extra ids — CF-192`, `FAIL board rows — 166 vs 165 rows`, `FAIL HEAD ancestry — ... not an ancestor`, `RESULT: DRIFT (5 failed)`, exit 1. `git diff origin/main HEAD` shows tasks.jsonl +1 row (CF-192) and events.jsonl +2 rows (ids 334, 335). (e) PASS census: `board-evidence-census.sh . .coding-hermes/board/tasks.jsonl origin/main` -> `complete_rows=56 finding_lines=0` with NO_SHA/NO_OBJECT/NOT_ON_REF/NO_EVIDENCE/NO_ARTIFACT_LATEST/ABSOLUTE_PATH/NOT_IN_TREE all 0. (f) FAIL counts in the doc bullet: docs/ACCEPTANCE-PLAN.md line 9 reads `**Delta measured 2026-11-04T09:58Z at tip `e0e73bd` (sync lane):** the board carries 165 task rows and 333 events (56 `complete`, 101 `pending`, 8 `in_progress`) ... so **40 arms**`, but at this commit the board measures 166 rows / 335 events (56 complete, 102 pending, 8 in_progress) — the row/event counts do not match what the commands measure here, and the same stale 165/333 figures are repeated in the audit event 335 detail. The stamp, tip and 40-arm figure are correct; the row/event counts are not.
boardctl validate, selftest (40 arms), JSONL parsing and the seven-class census (56 rows, 0 findings) all pass, but the board files are not byte-identical to origin/main (board_drift.py -> RESULT: DRIFT, 166 vs 165 rows, extra CF-192, 335 vs 334 events) and the 09:58Z delta bullet states 165 rows/333 events instead of the 166/335 measured at this commit.

Overall: FAIL ✗

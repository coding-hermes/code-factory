# Verdict: CF-088

**Task:** Board gate: selftest must reject non-object / duplicate-id / bad-status rows
**Evaluated:** 2026-11-03T19:43:52.107386
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ tests/selftest.sh board arm fails on a line that is valid JSON but not an object, naming the 1-based line number: tests/selftest.sh:184 enumerates rows with 1-based index; :190-192 `if not isinstance(record, dict): print(f"  FAIL  board line {line}: expected JSON object, got {json.dumps(record)}")`. Live run of `bash tests/selftest.sh` (exit 0) printed: 'FAIL  board line 2: expected JSON object, got null', 'got []', 'got "fixture"', 'got 42', and the multi-record fixture arm printed 'PASS  all four offending line numbers reported in one board run' (lines 1-4).
  ✓ a duplicate .id and an out-of-vocabulary .status fail the gate, and a row with no .status is an error not a pass: tests/selftest.sh:200-203 duplicate id -> "FAIL  board duplicate id 'CF-001': lines 1 and 2"; :205-207 missing status -> "FAIL  board line 2: missing status" with valid=False; :207-209 status not in (pending,in_progress,blocked,complete) -> "FAIL  board line 2: invalid status \"done\"". Live run shows all three fixtures rejected with exit 1 and 'FAIL  2 of 3 rows parse' (no PASS line).
  ✓ the negative arms do not depend on boardctl being installed: tests/selftest.sh:161-219 board_arm() is a self-contained bash function using only python3; section 7b (lines 224-262) invokes board_arm on mktemp fixtures only. boardctl appears solely in the separate section 8 arm. Live run: all 9 negative fixtures rejected with exit 1 without any boardctl call.
  ✓ a numbered selftest section prints n/n rows parse for the clean board and each negative fixture prints a gate FAIL: Live run output: '7. the board is valid JSONL' -> '  PASS  85/85 rows parse'; '7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)' -> for each of null/array/string/number/missing-id/duplicate-id/bad-status/missing-status/invalid-json: 'PASS  <arm> fixture rejected, exit 1' followed by 'FAIL  board line 2: ...' and 'FAIL  2 of 3 rows parse'.
  ✓ bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK at the fixed tip: `bash tests/selftest.sh` exit_code=0, stdout tail 'SELFTEST: PASS'. `scripts/boardctl validate` exit_code=0, output 'RESULT: OK (28 warning(s))'.
All five criteria verified by code inspection of tests/selftest.sh and fresh runs: selftest exits 0 with SELFTEST: PASS (85/85 rows, 9 negative fixtures each printing a line-numbered gate FAIL) and boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-088

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ tests/selftest.sh board arm fails on a line that is valid JSON but not an object, naming the 1-based line number: tests/selftest.sh:184 enumerates rows with 1-based index; :190-192 `if not isinstance(record, dict): print(f"  FAIL  board line {line}: expected JSON object, got {json.dumps(record)}")`. Live run of `bash tests/selftest.sh` (exit 0) printed: 'FAIL  board line 2: expected JSON object, got null', 'got []', 'got "fixture"', 'got 42', and the multi-record fixture arm printed 'PASS  all four offending line numbers reported in one board run' (lines 1-4).
  ✓ a duplicate .id and an out-of-vocabulary .status fail the gate, and a row with no .status is an error not a pass: tests/selftest.sh:200-203 duplicate id -> "FAIL  board duplicate id 'CF-001': lines 1 and 2"; :205-207 missing status -> "FAIL  board line 2: missing status" with valid=False; :207-209 status not in (pending,in_progress,blocked,complete) -> "FAIL  board line 2: invalid status \"done\"". Live run shows all three fixtures rejected with exit 1 and 'FAIL  2 of 3 rows parse' (no PASS line).
  ✓ the negative arms do not depend on boardctl being installed: tests/selftest.sh:161-219 board_arm() is a self-contained bash function using only python3; section 7b (lines 224-262) invokes board_arm on mktemp fixtures only. boardctl appears solely in the separate section 8 arm. Live run: all 9 negative fixtures rejected with exit 1 without any boardctl call.
  ✓ a numbered selftest section prints n/n rows parse for the clean board and each negative fixture prints a gate FAIL: Live run output: '7. the board is valid JSONL' -> '  PASS  85/85 rows parse'; '7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)' -> for each of null/array/string/number/missing-id/duplicate-id/bad-status/missing-status/invalid-json: 'PASS  <arm> fixture rejected, exit 1' followed by 'FAIL  board line 2: ...' and 'FAIL  2 of 3 rows parse'.
  ✓ bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK at the fixed tip: `bash tests/selftest.sh` exit_code=0, stdout tail 'SELFTEST: PASS'. `scripts/boardctl validate` exit_code=0, output 'RESULT: OK (28 warning(s))'.
All five criteria verified by code inspection of tests/selftest.sh and fresh runs: selftest exits 0 with SELFTEST: PASS (85/85 rows, 9 negative fixtures each printing a line-numbered gate FAIL) and boardctl validate prints RESULT: OK.

Overall: PASS ✓

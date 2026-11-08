# Verdict: CF-128

**Task:** selftest §29 ancestry legs: add --ref/no-published-dir arm plus disabled-block control
**Evaluated:** 2026-11-08T01:46:32.040384
**Result:** ✗ FAIL

## Criteria

- — **tests/selftest.sh section 29 gains an arm that runs scripts/board_drift.py check with a real --ref and NO --published-dir and NO --no-head on a fixture whose HEAD is not an ancestor of the ref, asserting a 'FAIL  HEAD ancestry' row plus RESULT: DRIFT; the same section asserts the green direction ('PASS  HEAD ancestry', RESULT: OK) on a fixture whose HEAD is an ancestor of the ref; with the ancestry block forced disabled the suite prints SELFTEST: FAIL naming the ancestry arm; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the fixed tip; the seven existing --published-dir arms still pass unchanged.**
  - Not examined — evaluation ended before this criterion was reached (no judgement was made about it)

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  — tests/selftest.sh section 29 gains an arm that runs scripts/board_drift.py check with a real --ref and NO --published-dir and NO --no-head on a fixture whose HEAD is not an ancestor of the ref, asserting a 'FAIL  HEAD ancestry' row plus RESULT: DRIFT; the same section asserts the green direction ('PASS  HEAD ancestry', RESULT: OK) on a fixture whose HEAD is an ancestor of the ref; with the ancestry block forced disabled the suite prints SELFTEST: FAIL naming the ancestry arm; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the fixed tip; the seven existing --published-dir arms still pass unchanged.: Not examined — evaluation ended before this criterion was reached (no judgement was made about it)
  ✗ Coverage FAILED — not passing: tests/selftest.sh section 29 gains an arm that runs scripts/board_drift.py check with a real --ref and NO --published-dir and NO --no-head on a fixture whose HEAD is not an ancestor of the ref, asserting a 'FAIL  HEAD ancestry' row plus RESULT: DRIFT; the same section asserts the green direction ('PASS  HEAD ancestry', RESULT: OK) on a fixture whose HEAD is an ancestor of the ref; with the ancestry block forced disabled the suite prints SELFTEST: FAIL naming the ancestry arm; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the fixed tip; the seven existing --published-dir arms still pass unchanged.
Cap exceeded: Iteration cap (100) reached (100.6 used). Increase max_iterations or split criteria. Partial verdict — 0 of 1 criteria graded, 1 ungraded. The run spent 3,191,956 in / 13,967 out over 100.6 iterations.

## Summary

Judge Result: CF-128

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  — tests/selftest.sh section 29 gains an arm that runs scripts/board_drift.py check with a real --ref and NO --published-dir and NO --no-head on a fixture whose HEAD is not an ancestor of the ref, asserting a 'FAIL  HEAD ancestry' row plus RESULT: DRIFT; the same section asserts the green direction ('PASS  HEAD ancestry', RESULT: OK) on a fixture whose HEAD is an ancestor of the ref; with the ancestry block forced disabled the suite prints SELFTEST: FAIL naming the ancestry arm; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the fixed tip; the seven existing --published-dir arms still pass unchanged.: Not examined — evaluation ended before this criterion was reached (no judgement was made about it)
  ✗ Coverage FAILED — not passing: tests/selftest.sh section 29 gains an arm that runs scripts/board_drift.py check with a real --ref and NO --published-dir and NO --no-head on a fixture whose HEAD is not an ancestor of the ref, asserting a 'FAIL  HEAD ancestry' row plus RESULT: DRIFT; the same section asserts the green direction ('PASS  HEAD ancestry', RESULT: OK) on a fixture whose HEAD is an ancestor of the ref; with the ancestry block forced disabled the suite prints SELFTEST: FAIL naming the ancestry arm; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the fixed tip; the seven existing --published-dir arms still pass unchanged.
Cap exceeded: Iteration cap (100) reached (100.6 used). Increase max_iterations or split criteria. Partial verdict — 0 of 1 criteria graded, 1 ungraded. The run spent 3,191,956 in / 13,967 out over 100.6 iterations.

Overall: FAIL ✗

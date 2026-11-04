# Verdict: CF-176-QA1

**Task:** QA filing: land CF-176/177/178 from the docs-QA tick and prove each row carries a reproducing probe
**Evaluated:** 2026-11-04T08:11:38.165243
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 5. Gate at the same tree: `bash tests/selftest.sh` prints SELFTEST: PASS with rc 0, and `bash scripts/boardctl validate` prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: `bash tests/selftest.sh` => SELFTEST_RC=0, tail output 'SELFTEST: PASS' (all 35 sections PASS, e.g. 'PASS  ref 're'lease' crosses the transport as --ref 're'\''lease''). `bash scripts/boardctl validate` => BOARDCTL_RC=0, 'RESULT: OK (3 warning(s))'. The 3 warnings are the CF-034 free-form guard_result/ci_result pair plus the headerless-board note; the CF-034 row and its 2 free-form warnings are present at 7ff8810^ (parent), confirming they are pre-existing legacy-row warnings as the criterion allows.
All five criteria pass: commit 7ff8810 touches only the two board files with 3 appended lines each and 0 deletions, files CF-176/177/178 exactly once each as pending with non-empty probes, all three probes reproduce their named contradictions verbatim from the repo root, and both gates pass (SELFTEST: PASS rc 0; RESULT: OK rc 0 with only pre-existing legacy warnings).

## Summary

Judge Result: CF-176-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 5. Gate at the same tree: `bash tests/selftest.sh` prints SELFTEST: PASS with rc 0, and `bash scripts/boardctl validate` prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: `bash tests/selftest.sh` => SELFTEST_RC=0, tail output 'SELFTEST: PASS' (all 35 sections PASS, e.g. 'PASS  ref 're'lease' crosses the transport as --ref 're'\''lease''). `bash scripts/boardctl validate` => BOARDCTL_RC=0, 'RESULT: OK (3 warning(s))'. The 3 warnings are the CF-034 free-form guard_result/ci_result pair plus the headerless-board note; the CF-034 row and its 2 free-form warnings are present at 7ff8810^ (parent), confirming they are pre-existing legacy-row warnings as the criterion allows.
All five criteria pass: commit 7ff8810 touches only the two board files with 3 appended lines each and 0 deletions, files CF-176/177/178 exactly once each as pending with non-empty probes, all three probes reproduce their named contradictions verbatim from the repo root, and both gates pass (SELFTEST: PASS rc 0; RESULT: OK rc 0 with only pre-existing legacy warnings).

Overall: PASS ✓

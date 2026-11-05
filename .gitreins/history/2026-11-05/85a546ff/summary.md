# Verdict: CF-302

**Task:** land-node-branch.sh pushes HEAD under --no-ff, so unrelated local main commits land
**Evaluated:** 2026-11-05T23:44:18.196085
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE

(auto-parsed from non-JSON response — JSON parse failed: Expecting ',' delimiter: line 3 column 701 (char 842)) 342 PASS rows, final line `SELFTEST: PASS`, and no unindented FAIL lines (all FAILs are expected negative-fixture output from passing legs).

{"verdict":"COMPLETE","items":[{"criterion":"bash -n scripts/land-node-branch.sh is clean, tests/selftest.sh passes, and a fixture proves an extra local main 

## Summary

Judge Result: CF-302

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE

(auto-parsed from non-JSON response — JSON parse failed: Expecting ',' delimiter: line 3 column 701 (char 842)) 342 PASS rows, final line `SELFTEST: PASS`, and no unindented FAIL lines (all FAILs are expected negative-fixture output from passing legs).

{"verdict":"COMPLETE","items":[{"criterion":"bash -n scripts/land-node-branch.sh is clean, tests/selftest.sh passes, and a fixture proves an extra local main 

Overall: PASS ✓

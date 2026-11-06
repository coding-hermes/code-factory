# Verdict: CF-245

**Task:** close CF-245 - the disabled-pair pin is corrected fleet-wide and the lane runs; the surviving 503 class is CF-252
**Evaluated:** 2026-11-06T04:40:56.349738
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (100) reached (100.8 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-245

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (100) reached (100.8 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

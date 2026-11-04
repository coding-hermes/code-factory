# Verdict: CF-186-PM2

**Task:** PM lane (corrected criterion): the acceptance plan's arm census after CF-155's gate arm was deleted by 4ce1e48, and the filed restoration row
**Evaluated:** 2026-11-04T09:30:31.666910
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (100) reached (100.6 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-186-PM2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (100) reached (100.6 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

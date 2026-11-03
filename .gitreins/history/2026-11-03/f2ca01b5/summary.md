# Verdict: CF-076-QA1

**Task:** PERF-013 PASS verdict is bound to a commit that does not contain the graded change
**Evaluated:** 2026-11-03T15:26:41.728640
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.9 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-076-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.9 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

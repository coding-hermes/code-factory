# Verdict: CF-041

**Task:** README quick-start audit: verify CF-041's three reported defects against origin/main
**Evaluated:** 2026-11-03T12:51:13.443138
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.8 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-041

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.8 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

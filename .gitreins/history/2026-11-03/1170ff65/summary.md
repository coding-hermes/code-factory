# Verdict: CF-119-QA1

**Task:** QA re-verification: file the tautological-snapshot and behind-workdir census gaps
**Evaluated:** 2026-11-03T20:44:56.664044
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (40) reached (40.0 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-119-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (40) reached (40.0 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

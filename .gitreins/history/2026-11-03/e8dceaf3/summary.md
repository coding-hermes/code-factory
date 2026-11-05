# Verdict: CF-073-QA1

**Task:** QA filing: three complete rows (CF-052, PERF-012, CF-058) carry closure digests that resolve to no git object
**Evaluated:** 2026-11-03T14:56:34.393230
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.1 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-073-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.1 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

# Verdict: PERF-013

**Task:** Selftest gate spends ~85% of CPU on full node-provision runs that assert a single layer
**Evaluated:** 2026-11-03T15:08:17.660067
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.6 used). Increase max_iterations or split criteria.

## Summary

Judge Result: PERF-013

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (15) reached (15.6 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

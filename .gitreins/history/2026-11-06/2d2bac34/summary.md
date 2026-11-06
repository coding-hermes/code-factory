# Verdict: CF-225

**Task:** claude-code conformance legs: resolve the harness binary where the adapter installed it, not only on PATH
**Evaluated:** 2026-11-06T10:33:20.011476
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

## Summary

Judge Result: CF-225

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Overall: PASS ✓

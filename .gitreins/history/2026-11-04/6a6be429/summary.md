# Verdict: CF-159

**Task:** node-create/verify-node/lib.sh interpolate values into remote bash -lc unescaped (shell injection on the node)
**Evaluated:** 2026-11-04T08:54:48.580831
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✗ tests: scanners: nice=nice -n 10

## Summary

Judge Result: CF-159

Stage tier1: FAIL
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✗ tests: scanners: nice=nice -n 10

Overall: FAIL ✗

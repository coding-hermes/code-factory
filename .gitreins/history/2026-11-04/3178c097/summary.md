# Verdict: CF-166-DOC1

**Task:** Correct the node-create environment contract in the runbook (CRIER_URL gate, CF-126)
**Evaluated:** 2026-11-04T06:26:50.912266
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Cap exceeded: Iteration cap (40) reached (40.2 used). Increase max_iterations or split criteria.

## Summary

Judge Result: CF-166-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Cap exceeded: Iteration cap (40) reached (40.2 used). Increase max_iterations or split criteria.

Overall: FAIL ✗

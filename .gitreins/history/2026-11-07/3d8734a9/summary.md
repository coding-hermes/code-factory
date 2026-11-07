# Verdict: CF-379

**Task:** Seed record declaring zero files must not pass
**Evaluated:** 2026-11-07T17:11:46.828915
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE

(auto-parsed from non-JSON response — JSON parse failed: Expecting ',' delimiter: line 1 column 3263 (char 3262)) {"verdict":"COMPLETE","items":[{"criterion":"Verify by running the real scripts: (1) python3 -B scripts/node_seed_drift.py --home <fixture with .hermes/seed-applied.json containing {\"files\": []}> exits NON-ZERO and its row names that the record declares no files; (2) the same fixture through bash 

## Summary

Judge Result: CF-379

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE

(auto-parsed from non-JSON response — JSON parse failed: Expecting ',' delimiter: line 1 column 3263 (char 3262)) {"verdict":"COMPLETE","items":[{"criterion":"Verify by running the real scripts: (1) python3 -B scripts/node_seed_drift.py --home <fixture with .hermes/seed-applied.json containing {\"files\": []}> exits NON-ZERO and its row names that the record declares no files; (2) the same fixture through bash 

Overall: PASS ✓

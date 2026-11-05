# Verdict: PERF-013

**Task:** Selftest gate spends ~85% of CPU on full node-provision runs that assert a single layer
**Evaluated:** 2026-11-03T15:07:20.269316
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. project-node.sh accepts --layers 20,40 and rejects an unknown layer with exit 2 and usage text. 2. A scoped run prints a SCOPE line and SKIP rows for unnamed layers, and never writes .node/node.json. 3. Unscoped behaviour unchanged: bash tests/selftest.sh prints SELFTEST: PASS with 34 PASS rows and the real provision still prints 3 FAIL rows -> NODE: FAIL (3). 4. Fixtures 4/4b/14/15 use --layers and their exact-row assertions are unchanged. 5. Measured: selftest user+sys below 1.2 s on three consecutive runs, from 2.49 s measured at d5f7fb2.: PASS: --layers 20,40 accepted (SCOPE line printed, exit 1 from real FAIL rows); --layers 20,99 -> usage text + exit 2; --layers 20, -> exit 2; --layers "" -> exit 2. scripts/project-node.sh:54-80 validation.
Partial verdict — all verified criteria passed

## Summary

Judge Result: PERF-013

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. project-node.sh accepts --layers 20,40 and rejects an unknown layer with exit 2 and usage text. 2. A scoped run prints a SCOPE line and SKIP rows for unnamed layers, and never writes .node/node.json. 3. Unscoped behaviour unchanged: bash tests/selftest.sh prints SELFTEST: PASS with 34 PASS rows and the real provision still prints 3 FAIL rows -> NODE: FAIL (3). 4. Fixtures 4/4b/14/15 use --layers and their exact-row assertions are unchanged. 5. Measured: selftest user+sys below 1.2 s on three consecutive runs, from 2.49 s measured at d5f7fb2.: PASS: --layers 20,40 accepted (SCOPE line printed, exit 1 from real FAIL rows); --layers 20,99 -> usage text + exit 2; --layers 20, -> exit 2; --layers "" -> exit 2. scripts/project-node.sh:54-80 validation.
Partial verdict — all verified criteria passed

Overall: PASS ✓

# Verdict: CF-159

**Task:** node-create/verify-node/lib.sh interpolate values into remote bash -lc unescaped (shell injection on the node)
**Evaluated:** 2026-11-04T08:49:42.290348
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: Probe at HEAD 8b81369: INJECTION_EXECUTED=no (rc 0). Escaping: node-create.sh:78-83 shq for all six fields, used at :120-121; verify-node.sh:62 shq ARTIFACT; lib.sh:54-57 shq helper. Remaining bash -lc sites literal (node-create.sh:108,114; verify-node.sh:32,39). Selftest §36 cf159-escaping exists at tests/selftest.sh:1437-1569. Still need: RED-at-pre-fix demonstration + SELFTEST: PASS run.
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-159

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: Probe at HEAD 8b81369: INJECTION_EXECUTED=no (rc 0). Escaping: node-create.sh:78-83 shq for all six fields, used at :120-121; verify-node.sh:62 shq ARTIFACT; lib.sh:54-57 shq helper. Remaining bash -lc sites literal (node-create.sh:108,114; verify-node.sh:32,39). Selftest §36 cf159-escaping exists at tests/selftest.sh:1437-1569. Still need: RED-at-pre-fix demonstration + SELFTEST: PASS run.
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

# Verdict: CF-159

**Task:** node-create/verify-node/lib.sh interpolate values into remote bash -lc unescaped (shell injection on the node)
**Evaluated:** 2026-11-04T08:36:20.073550
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: Probe at fix commit: INJECTION_EXECUTED=no (rc=0). Escaping sites: node-create.sh:120-121 all six fields via shq; verify-node.sh:62 ARTIFACT via shq; lib.sh:54-57 shq helper. Remaining bash -lc sites are literal (node-create.sh:108,114; verify-node.sh:32,39). Need: selftest arm + SELFTEST: PASS.
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-159

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: Probe at fix commit: INJECTION_EXECUTED=no (rc=0). Escaping sites: node-create.sh:120-121 all six fields via shq; verify-node.sh:62 ARTIFACT via shq; lib.sh:54-57 shq helper. Remaining bash -lc sites are literal (node-create.sh:108,114; verify-node.sh:32,39). Need: selftest arm + SELFTEST: PASS.
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

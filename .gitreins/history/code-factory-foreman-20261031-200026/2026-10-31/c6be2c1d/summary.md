# Verdict: CF-034

**Task:** Fix project-node clone error classification
**Evaluated:** 2026-10-31T20:20:33.109928
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Implement CF-034 acceptance: missing ref errors name the requested --ref and avoid claiming a private repository; genuine private clone failures retain a deploy-key diagnostic; tests/selftest.sh proves both and passes; include a fresh ch:trace row=CF-034 marker in the committed evidence.: PARTIAL: selftest passes (EXIT=0, "SELFTEST: PASS", check 4 both PASS). ch:trace row=CF-034 present at tests/selftest.sh:37 committed. Need to verify script logic correctness (ls-remote exit code handling) and whether marker is "fresh".
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-034

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Implement CF-034 acceptance: missing ref errors name the requested --ref and avoid claiming a private repository; genuine private clone failures retain a deploy-key diagnostic; tests/selftest.sh proves both and passes; include a fresh ch:trace row=CF-034 marker in the committed evidence.: PARTIAL: selftest passes (EXIT=0, "SELFTEST: PASS", check 4 both PASS). ch:trace row=CF-034 present at tests/selftest.sh:37 committed. Need to verify script logic correctness (ls-remote exit code handling) and whether marker is "fresh".
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

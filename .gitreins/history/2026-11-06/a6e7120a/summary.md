# Verdict: CF-245

**Task:** Verification closeout: the lane-pin-vs-registry guard for the 503 unservable-rating class exists and passes
**Evaluated:** 2026-11-06T06:02:25.595810
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✓ AC1: the guard lives in the scheduler repo - commit 572b111f adds internal/config/pin_registry.go + pin_registry_test.go, is an ancestor of that repo's origin/main, and its 4 pin tests pass (go test ./internal/config -run 'TestValidatePins|TestLanePinProblems|TestWarnUnservablePins' -count=1).: PASS: repo ~/coding-hermes-scheduler/coding-herms-scheduler. commit 572b111f23fb2813288de7cf944b5bcf14d67da0 "fix(config): name every lane pin the router cannot serve (CF-245)" adds internal/config/pin_registry.go (203 lines) + pin_registry_test.go (166 lines) + loader.go. `git merge-base --is-ancestor 572b111f origin/main` -> IS_ANCESTOR: yes (origin/main = e46f2252). go test ./internal/config -run 'TestValidatePins|TestLanePinProblems|TestWarnUnservablePins' -count=1 -v -> 4/4 PASS, exit 0, "ok github.com/coding-hermes/scheduler/internal/config 0.008s".
  — AC2: the class is measurably gone at the config layer: sqlite3 ~/.hermes/scheduler.db counts 198 ticks carrying unservable-rating before the 2026-11-06T00:04:52Z correction and 0 after, and every one of the 251 lanes pinned in ~/.hermes/fleet.toml resolves to a (model,provider) row the router registry marks enabled.: Not examined — evaluation ended before this criterion was reached (no judgement was made about it)
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-245

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✓ AC1: the guard lives in the scheduler repo - commit 572b111f adds internal/config/pin_registry.go + pin_registry_test.go, is an ancestor of that repo's origin/main, and its 4 pin tests pass (go test ./internal/config -run 'TestValidatePins|TestLanePinProblems|TestWarnUnservablePins' -count=1).: PASS: repo ~/coding-hermes-scheduler/coding-herms-scheduler. commit 572b111f23fb2813288de7cf944b5bcf14d67da0 "fix(config): name every lane pin the router cannot serve (CF-245)" adds internal/config/pin_registry.go (203 lines) + pin_registry_test.go (166 lines) + loader.go. `git merge-base --is-ancestor 572b111f origin/main` -> IS_ANCESTOR: yes (origin/main = e46f2252). go test ./internal/config -run 'TestValidatePins|TestLanePinProblems|TestWarnUnservablePins' -count=1 -v -> 4/4 PASS, exit 0, "ok github.com/coding-hermes/scheduler/internal/config 0.008s".
  — AC2: the class is measurably gone at the config layer: sqlite3 ~/.hermes/scheduler.db counts 198 ticks carrying unservable-rating before the 2026-11-06T00:04:52Z correction and 0 after, and every one of the 251 lanes pinned in ~/.hermes/fleet.toml resolves to a (model,provider) row the router registry marks enabled.: Not examined — evaluation ended before this criterion was reached (no judgement was made about it)
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

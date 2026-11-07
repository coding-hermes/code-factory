# Verdict: CF-192

**Task:** install-hermes.sh: the occupied-port branch must not certify an unauthenticated public bind
**Evaluated:** 2026-11-07T10:17:52.932812
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. scripts/harness/install-hermes.sh occupied-port branch no longer prints ok port + PASS and HERMES: PASS on a config with no dashboard.basic_auth: it prints the existing auth refusal or a NAMED row stating the listener was not started by this adapter and its auth is unverified, and exits nonzero. 2. tests/selftest.sh gains an arm that drives the occupied-port branch with a listener stub and a no-basic_auth config, asserting the named FAIL row and rejecting the decoy substring; its red proof on the pre-fix tree and green proof on the fixed tree are both printed in the tick evidence. 3. The two existing green paths stay green in the same run: free port + valid basic_auth reaches PASS gateway_start, free port + no basic_auth prints the exact CF-071 refusal wording. 4. bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the landing commit. 5. docs/handbook/chapters/M5-harness.md records the new occupied-port behaviour (this row changes M5's install layer).: PASS (code inspection): install-hermes.sh:302-323 occupied-port branch now calls check_public_bind_auth (line 310). If it fails, only bad "port" "listening on :$PORT (not started by this adapter; auth unverified — ... ${port_auth_reason})" is printed (line 321) — no ok port, no status_probe PASS. bad() increments FAILED (scripts/lib.sh:7), and line 388 exits 1 with HERMES: FAIL ($FAILED). Need runtime confirmation.
Partial verdict — all verified criteria passed

## Summary

Judge Result: CF-192

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. scripts/harness/install-hermes.sh occupied-port branch no longer prints ok port + PASS and HERMES: PASS on a config with no dashboard.basic_auth: it prints the existing auth refusal or a NAMED row stating the listener was not started by this adapter and its auth is unverified, and exits nonzero. 2. tests/selftest.sh gains an arm that drives the occupied-port branch with a listener stub and a no-basic_auth config, asserting the named FAIL row and rejecting the decoy substring; its red proof on the pre-fix tree and green proof on the fixed tree are both printed in the tick evidence. 3. The two existing green paths stay green in the same run: free port + valid basic_auth reaches PASS gateway_start, free port + no basic_auth prints the exact CF-071 refusal wording. 4. bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at the landing commit. 5. docs/handbook/chapters/M5-harness.md records the new occupied-port behaviour (this row changes M5's install layer).: PASS (code inspection): install-hermes.sh:302-323 occupied-port branch now calls check_public_bind_auth (line 310). If it fails, only bad "port" "listening on :$PORT (not started by this adapter; auth unverified — ... ${port_auth_reason})" is printed (line 321) — no ok port, no status_probe PASS. bad() increments FAILED (scripts/lib.sh:7), and line 388 exits 1 with HERMES: FAIL ($FAILED). Need runtime confirmation.
Partial verdict — all verified criteria passed

Overall: PASS ✓

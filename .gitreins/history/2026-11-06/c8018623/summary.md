# Verdict: CF-229

**Task:** Uniform CF_* harness variable contract across every installer, the node bus worker, and the conformance battery
**Evaluated:** 2026-11-06T00:49:24.479603
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Every script under scripts/harness accepts the specs/HARNESS-MATRIX.md section 5 CF_* set, documents it in --help, and refuses a credential passed as a VALUE with a named failure while accepting only a path; node-bus-worker.py passes the set from the directive to the harness and records which values it passed; and the conformance battery carries a vars leg that is green for every harness row and red when one declared variable is dropped.: Partial evidence:
- vars-contract-test.sh: 22 pass, 0 fail, 1 skip -> PASS (all 4 installers document 12 vars in --help, refuse credential VALUE by name, refuse ambient key, flags set vars; GREEN/RED/RESTORED arms for conformance vars leg).
- harness-conformance.sh --vars-only: 6 pass, 2 FAIL -> deepseek:vars and pi-agent:vars FAIL "no adapter at scripts/harness/install-deepseek.sh" / "install-pi-agent.sh". Battery overall exit 1.
- node-bus-worker.py: SECTION5_VARS list (lines 89-100), directive_vars() 487-543, section5_receipt() 545-550, harness_env() 553-558 scrubs CF_*, result["vars"]=section5_receipt(values) at 1044/1086/1115.
- docs/HARNESS-CONFORMANCE.md has no vars column (generated before the vars leg).

Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-229

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Every script under scripts/harness accepts the specs/HARNESS-MATRIX.md section 5 CF_* set, documents it in --help, and refuses a credential passed as a VALUE with a named failure while accepting only a path; node-bus-worker.py passes the set from the directive to the harness and records which values it passed; and the conformance battery carries a vars leg that is green for every harness row and red when one declared variable is dropped.: Partial evidence:
- vars-contract-test.sh: 22 pass, 0 fail, 1 skip -> PASS (all 4 installers document 12 vars in --help, refuse credential VALUE by name, refuse ambient key, flags set vars; GREEN/RED/RESTORED arms for conformance vars leg).
- harness-conformance.sh --vars-only: 6 pass, 2 FAIL -> deepseek:vars and pi-agent:vars FAIL "no adapter at scripts/harness/install-deepseek.sh" / "install-pi-agent.sh". Battery overall exit 1.
- node-bus-worker.py: SECTION5_VARS list (lines 89-100), directive_vars() 487-543, section5_receipt() 545-550, harness_env() 553-558 scrubs CF_*, result["vars"]=section5_receipt(values) at 1044/1086/1115.
- docs/HARNESS-CONFORMANCE.md has no vars column (generated before the vars leg).

Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

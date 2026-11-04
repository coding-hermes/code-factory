# Verdict: CF-126

**Task:** Forward CRIER_URL into the node and refuse an unset bus before spawn
**Evaluated:** 2026-11-04T02:55:58.560070
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1) node-create forwards CRIER_URL to the node-side provisioning exec so layer 00 prints PASS crier_url naming the value; 2) with CRIER_URL unset, node-create exits non-zero with a named FAIL crier_url row and creates no bunker agent; 3) tests/selftest.sh carries two named arms (handoff + refusal-before-spawn) that can each fail; 4) bash tests/selftest.sh prints SELFTEST: PASS rc=0 at the committed tree.: (1) scripts/node-create.sh:109 forwards `CRIER_URL='$CRIER_QUOTED'` (quote-escaped at :74) into the node-side `bash -lc` exec of ~/node-scripts/project-node.sh; scripts/project-node.sh:189 adds `ok "crier_url" "$CRIER"` in layer 00, so it prints `  PASS  crier_url — <value>`. Live selftest arm A printed "PASS  crier_url handoff preserves exported URL and shell metacharacters", asserting the exact `  PASS  crier_url — $crier_value` line for both a plain URL and one containing a quote/$( )/;/& (no injection file created). (2) scripts/node-create.sh:69-72 refuses before any bunker call: `if [ -z "${CRIER_URL:-}" ]; then bad "crier_url" "CRIER_URL unset or empty — ..."; exit 1; fi`, placed before staged_files/spawn; bad() (scripts/lib.sh:7) prints `  FAIL  crier_url — ...`. Live selftest arm B printed "PASS  crier_url refusal rejects unset and empty bus before bunker invocation", asserting rc==1, the named FAIL row, and an empty bunker log (no spawn/create/exec). (3) tests/selftest.sh:577-610 "CF-126 ARM A" (handoff) and :612-634 "CF-126 ARM B" (refusal-before-spawn); each sets handoff_ok/refusal_ok=0 and does `say "  FAIL ..."; fails=$((fails+1))` on mismatch, so each can fail. (4) `bash tests/selftest.sh` at the clean committed tree (git status --porcelain empty) exited RC=0 with stdout ending "SELFTEST: PASS" (only a benign fixture digest-mismatch line on stderr from a negative test).


## Summary

Judge Result: CF-126

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1) node-create forwards CRIER_URL to the node-side provisioning exec so layer 00 prints PASS crier_url naming the value; 2) with CRIER_URL unset, node-create exits non-zero with a named FAIL crier_url row and creates no bunker agent; 3) tests/selftest.sh carries two named arms (handoff + refusal-before-spawn) that can each fail; 4) bash tests/selftest.sh prints SELFTEST: PASS rc=0 at the committed tree.: (1) scripts/node-create.sh:109 forwards `CRIER_URL='$CRIER_QUOTED'` (quote-escaped at :74) into the node-side `bash -lc` exec of ~/node-scripts/project-node.sh; scripts/project-node.sh:189 adds `ok "crier_url" "$CRIER"` in layer 00, so it prints `  PASS  crier_url — <value>`. Live selftest arm A printed "PASS  crier_url handoff preserves exported URL and shell metacharacters", asserting the exact `  PASS  crier_url — $crier_value` line for both a plain URL and one containing a quote/$( )/;/& (no injection file created). (2) scripts/node-create.sh:69-72 refuses before any bunker call: `if [ -z "${CRIER_URL:-}" ]; then bad "crier_url" "CRIER_URL unset or empty — ..."; exit 1; fi`, placed before staged_files/spawn; bad() (scripts/lib.sh:7) prints `  FAIL  crier_url — ...`. Live selftest arm B printed "PASS  crier_url refusal rejects unset and empty bus before bunker invocation", asserting rc==1, the named FAIL row, and an empty bunker log (no spawn/create/exec). (3) tests/selftest.sh:577-610 "CF-126 ARM A" (handoff) and :612-634 "CF-126 ARM B" (refusal-before-spawn); each sets handoff_ok/refusal_ok=0 and does `say "  FAIL ..."; fails=$((fails+1))` on mismatch, so each can fail. (4) `bash tests/selftest.sh` at the clean committed tree (git status --porcelain empty) exited RC=0 with stdout ending "SELFTEST: PASS" (only a benign fixture digest-mismatch line on stderr from a negative test).


Overall: PASS ✓

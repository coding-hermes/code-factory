# Verdict: CF-145

**Task:** README fresh-host promise: two Quick start commands abort in ${VAR:?} instead of printing a named check row
**Evaluated:** 2026-11-04T03:07:01.609198
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: Ran `env -u CRIER_URL -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> '  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to' + 'RESULT: FAIL (1)', EXIT=1, no 'line 14:' abort (scripts/bunker-server-install.sh:14-19 now uses ${BUNKER_SERVER:-} + bad()/exit 1; row format matches lib.sh:7). Ran `env -u CRIER_URL -u BUNKER_SERVER bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> '  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on' + 'NODE INCOMPLETE (1)', EXIT=1, no 'line 70:' abort (scripts/node-create.sh:70-73). tests/selftest.sh:1007-1033 adds §31 (CF-145) which pins PATH/HOME, requires nonzero rc, greps '^  FAIL  .*BUNKER_SERVER' and the closing line, and rejects 'line [0-9]+:' and 'unbound variable'; full run `bash tests/selftest.sh` EXIT=0 with '  PASS  bunker-server-install without BUNKER_SERVER -> named FAIL row, exit 1', '  PASS  node-create without BUNKER_SERVER -> named FAIL row, exit 1', 'SELFTEST: PASS'. Red proof reproduced: restoring ${BUNKER_SERVER:?} made §31 emit '  FAIL  bunker-server-install aborted or did not name BUNKER_SERVER (exit 1)' and 'SELFTEST: FAIL (1)'; file restored via git checkout, tree clean. `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', EXIT=0.
Both Quick start scripts now emit a repo-convention named FAIL row for BUNKER_SERVER and exit nonzero without a bash abort, the new selftest §31 arm proves the guard can fail (verified red then green), SELFTEST: PASS, and boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-145

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: Ran `env -u CRIER_URL -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> '  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to' + 'RESULT: FAIL (1)', EXIT=1, no 'line 14:' abort (scripts/bunker-server-install.sh:14-19 now uses ${BUNKER_SERVER:-} + bad()/exit 1; row format matches lib.sh:7). Ran `env -u CRIER_URL -u BUNKER_SERVER bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> '  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on' + 'NODE INCOMPLETE (1)', EXIT=1, no 'line 70:' abort (scripts/node-create.sh:70-73). tests/selftest.sh:1007-1033 adds §31 (CF-145) which pins PATH/HOME, requires nonzero rc, greps '^  FAIL  .*BUNKER_SERVER' and the closing line, and rejects 'line [0-9]+:' and 'unbound variable'; full run `bash tests/selftest.sh` EXIT=0 with '  PASS  bunker-server-install without BUNKER_SERVER -> named FAIL row, exit 1', '  PASS  node-create without BUNKER_SERVER -> named FAIL row, exit 1', 'SELFTEST: PASS'. Red proof reproduced: restoring ${BUNKER_SERVER:?} made §31 emit '  FAIL  bunker-server-install aborted or did not name BUNKER_SERVER (exit 1)' and 'SELFTEST: FAIL (1)'; file restored via git checkout, tree clean. `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', EXIT=0.
Both Quick start scripts now emit a repo-convention named FAIL row for BUNKER_SERVER and exit nonzero without a bash abort, the new selftest §31 arm proves the guard can fail (verified red then green), SELFTEST: PASS, and boardctl validate prints RESULT: OK.

Overall: PASS ✓

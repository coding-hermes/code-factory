# Verdict: CF-145

**Task:** README fresh-host promise: two Quick start commands abort in ${VAR:?} instead of printing a named check row
**Evaluated:** 2026-11-04T03:19:45.354527
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: bunker-server-install.sh:14 now `SERVER="${BUNKER_SERVER:-}"` with lines 18-23 emitting `bad "server_declared" "BUNKER_SERVER unset — the client has no server to talk to"` + `RESULT: FAIL (1)` + exit 1; measured `env -u CRIER_URL -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> '  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to' / 'RESULT: FAIL (1)' / EXIT=1, no 'line 14:'. node-create.sh:15 `SERVER="${BUNKER_SERVER:-}"` with lines 76-79 `bad "server_declared" "BUNKER_SERVER unset — no agent host to create the node on"` then `incomplete` -> 'NODE INCOMPLETE (1)', EXIT=1, no 'line 70:'; measured with CRIER_URL pinned (node-create's CF-126 CRIER_URL gate at line 69 precedes the server gate, so with both unset only the crier_url row prints — the BUNKER_SERVER row appears as soon as CRIER_URL is set, which is what the selftest arm pins). tests/selftest.sh:1228-1258 adds §32 asserting rc!=0, `^  FAIL  .*BUNKER_SERVER`, the closing line, and rejecting 'line [0-9]+:'/'unbound variable'; I reproduced the red proof by restoring `${BUNKER_SERVER:?}` in bunker-server-install.sh — §32 printed '  FAIL  bunker-server-install aborted or did not name BUNKER_SERVER (exit 1)' and 'SELFTEST: FAIL (1)', and after restoring the file `bash tests/selftest.sh` EXIT=0 with tail 'SELFTEST: PASS' (both arms PASS). `bash -n $(git ls-files "*.sh")` LINT_EXIT=0. `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))' EXIT=0.
Both Quick start scripts now emit named BUNKER_SERVER FAIL rows with nonzero exits and no bash aborts, the new selftest §32 arm demonstrably fails when the abort is restored and the suite prints SELFTEST: PASS, and boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-145

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: bunker-server-install.sh:14 now `SERVER="${BUNKER_SERVER:-}"` with lines 18-23 emitting `bad "server_declared" "BUNKER_SERVER unset — the client has no server to talk to"` + `RESULT: FAIL (1)` + exit 1; measured `env -u CRIER_URL -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> '  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to' / 'RESULT: FAIL (1)' / EXIT=1, no 'line 14:'. node-create.sh:15 `SERVER="${BUNKER_SERVER:-}"` with lines 76-79 `bad "server_declared" "BUNKER_SERVER unset — no agent host to create the node on"` then `incomplete` -> 'NODE INCOMPLETE (1)', EXIT=1, no 'line 70:'; measured with CRIER_URL pinned (node-create's CF-126 CRIER_URL gate at line 69 precedes the server gate, so with both unset only the crier_url row prints — the BUNKER_SERVER row appears as soon as CRIER_URL is set, which is what the selftest arm pins). tests/selftest.sh:1228-1258 adds §32 asserting rc!=0, `^  FAIL  .*BUNKER_SERVER`, the closing line, and rejecting 'line [0-9]+:'/'unbound variable'; I reproduced the red proof by restoring `${BUNKER_SERVER:?}` in bunker-server-install.sh — §32 printed '  FAIL  bunker-server-install aborted or did not name BUNKER_SERVER (exit 1)' and 'SELFTEST: FAIL (1)', and after restoring the file `bash tests/selftest.sh` EXIT=0 with tail 'SELFTEST: PASS' (both arms PASS). `bash -n $(git ls-files "*.sh")` LINT_EXIT=0. `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))' EXIT=0.
Both Quick start scripts now emit named BUNKER_SERVER FAIL rows with nonzero exits and no bash aborts, the new selftest §32 arm demonstrably fails when the abort is restored and the suite prints SELFTEST: PASS, and boardctl validate prints RESULT: OK.

Overall: PASS ✓

# Verdict: CF-145

**Task:** README fresh-host promise: two Quick start commands abort in ${VAR:?} instead of printing a named check row
**Evaluated:** 2026-11-04T03:13:00.737120
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: Ran with env -u CRIER_URL -u BUNKER_SERVER: `bash scripts/bunker-server-install.sh --check` -> `  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to` / `RESULT: FAIL (1)`, EXIT=1, no 'line 14:' abort (scripts/bunker-server-install.sh:14-20 replaced ${BUNKER_SERVER:?} with bad()/RESULT: FAIL/exit 1). `bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` with both unset -> `  FAIL  crier_url — CRIER_URL unset or empty ...`, EXIT=1 (CF-126 gate at scripts/node-create.sh:69-72 fires first, no abort); with only BUNKER_SERVER unset (CRIER_URL=http://crier.example:8767) -> `  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on` + `NODE INCOMPLETE (1)`, EXIT=1, no 'line 70:' abort (scripts/node-create.sh:76-79; git show 5cf6c03 shows ${SERVER:?} removed). tests/selftest.sh:1081-1108 adds §31 with two arms asserting nonzero exit, `^  FAIL  .*BUNKER_SERVER`, the closing line, and rejecting `line [0-9]+:` / 'unbound variable'; I red-proved it by restoring `: "${SERVER:?...}"` in node-create.sh -> `FAIL  node-create aborted or did not name BUNKER_SERVER (exit 1)` and `SELFTEST: FAIL (1)`, then restored via git checkout (git status clean). Full suite `bash tests/selftest.sh` (guards.test_command) -> `SELFTEST: PASS`, EXIT=0, both §31 arms PASS. `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, EXIT=0. Caveat: the criterion's literal 'both unset' wording for node-create yields a CRIER_URL-named row (CF-126 gate precedes the server gate), which is why §31 pins CRIER_URL; the substantive requirement (named FAIL row, nonzero exit, no bash abort) holds for both scripts.
Both Quick start scripts now emit repo-convention named FAIL rows with nonzero exits and no bash aborts, §31 proves the guards can go red, selftest prints SELFTEST: PASS, and boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-145

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ With CRIER_URL and BUNKER_SERVER unset, scripts/bunker-server-install.sh --check prints a repo-convention '  FAIL  <name> — ... BUNKER_SERVER ...' row and exits nonzero with no 'line 14:' bash abort, and scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes prints a named FAIL row naming BUNKER_SERVER and exits nonzero with no 'line 70:' bash abort; tests/selftest.sh gains an arm proving those guards can FAIL and still prints SELFTEST: PASS; bash scripts/boardctl validate prints RESULT: OK.: Ran with env -u CRIER_URL -u BUNKER_SERVER: `bash scripts/bunker-server-install.sh --check` -> `  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to` / `RESULT: FAIL (1)`, EXIT=1, no 'line 14:' abort (scripts/bunker-server-install.sh:14-20 replaced ${BUNKER_SERVER:?} with bad()/RESULT: FAIL/exit 1). `bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` with both unset -> `  FAIL  crier_url — CRIER_URL unset or empty ...`, EXIT=1 (CF-126 gate at scripts/node-create.sh:69-72 fires first, no abort); with only BUNKER_SERVER unset (CRIER_URL=http://crier.example:8767) -> `  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on` + `NODE INCOMPLETE (1)`, EXIT=1, no 'line 70:' abort (scripts/node-create.sh:76-79; git show 5cf6c03 shows ${SERVER:?} removed). tests/selftest.sh:1081-1108 adds §31 with two arms asserting nonzero exit, `^  FAIL  .*BUNKER_SERVER`, the closing line, and rejecting `line [0-9]+:` / 'unbound variable'; I red-proved it by restoring `: "${SERVER:?...}"` in node-create.sh -> `FAIL  node-create aborted or did not name BUNKER_SERVER (exit 1)` and `SELFTEST: FAIL (1)`, then restored via git checkout (git status clean). Full suite `bash tests/selftest.sh` (guards.test_command) -> `SELFTEST: PASS`, EXIT=0, both §31 arms PASS. `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, EXIT=0. Caveat: the criterion's literal 'both unset' wording for node-create yields a CRIER_URL-named row (CF-126 gate precedes the server gate), which is why §31 pins CRIER_URL; the substantive requirement (named FAIL row, nonzero exit, no bash abort) holds for both scripts.
Both Quick start scripts now emit repo-convention named FAIL rows with nonzero exits and no bash aborts, §31 proves the guards can go red, selftest prints SELFTEST: PASS, and boardctl validate prints RESULT: OK.

Overall: PASS ✓

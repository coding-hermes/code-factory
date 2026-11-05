# Verdict: CF-159

**Task:** node-create/verify-node/lib.sh interpolate values into remote bash -lc unescaped (shell injection on the node)
**Evaluated:** 2026-11-04T08:52:15.478456
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: (1) Bound probe: `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-159").probe' > /tmp/cf159.sh; bash /tmp/cf159.sh` at HEAD 7ebc4bc (contains fix 8b81369) prints `INJECTION_EXECUTED=no`, rc=0, with payload `NODE_PROJECT='p'\''; touch $HOME/PWNED; echo '\''' ...`; the same probe at pre-fix 1fea92d prints `INJECTION_EXECUTED=yes` (payload `NODE_PROJECT='p'; touch $HOME/PWNED; echo ''`), rc=0 — both directions reproduced. (2) Escaping: scripts/lib.sh:54-57 adds `shq()`; scripts/node-create.sh:78-83 quotes all six data values (PROJECT/PORT/CRIER_URL/HARNESS/REPO/REF) and node-create.sh:120-121 interpolates only the *_QUOTED forms; scripts/verify-node.sh:62 uses `sha256sum $(shq "$ARTIFACT")`. Remaining `bash -lc` sites are literal constants with no interpolation (node-create.sh:108,114; verify-node.sh:32,39) and lib.sh:64 `bunker_exec` is documented as trusted command text (lib.sh:59-61). (3) Arm: tests/selftest.sh:1437-1569 `# BEGIN cf159-escaping` / `say "36. remote shell payloads preserve data without executing it (CF-159)"` (line 1438) names the row; I extracted the embedded python body and ran it against pre-fix scripts (git show 1fea92d:scripts/*) -> `AssertionError: NODE_PROJECT='p'; touch $HOME/PWNED; echo '' ...` exit 1 (RED), and against the fix tree -> 9 PASS lines, exit 0 (GREEN). (4) Gate: `bash tests/selftest.sh` -> `SELFTEST: PASS`, EXIT=0, including `PASS cf159-escaping all remote-command sites`; `bash -n $(git ls-files '*.sh')` rc=0.
CF-159 is fully satisfied: the bound probe flips yes->no, every interpolated remote-command value is escaped via shq, section 36 names the row and is RED at 1fea92d / GREEN at the fix, and bash tests/selftest.sh prints SELFTEST: PASS (exit 0).

## Summary

Judge Result: CF-159

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: (1) Bound probe: `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-159").probe' > /tmp/cf159.sh; bash /tmp/cf159.sh` at HEAD 7ebc4bc (contains fix 8b81369) prints `INJECTION_EXECUTED=no`, rc=0, with payload `NODE_PROJECT='p'\''; touch $HOME/PWNED; echo '\''' ...`; the same probe at pre-fix 1fea92d prints `INJECTION_EXECUTED=yes` (payload `NODE_PROJECT='p'; touch $HOME/PWNED; echo ''`), rc=0 — both directions reproduced. (2) Escaping: scripts/lib.sh:54-57 adds `shq()`; scripts/node-create.sh:78-83 quotes all six data values (PROJECT/PORT/CRIER_URL/HARNESS/REPO/REF) and node-create.sh:120-121 interpolates only the *_QUOTED forms; scripts/verify-node.sh:62 uses `sha256sum $(shq "$ARTIFACT")`. Remaining `bash -lc` sites are literal constants with no interpolation (node-create.sh:108,114; verify-node.sh:32,39) and lib.sh:64 `bunker_exec` is documented as trusted command text (lib.sh:59-61). (3) Arm: tests/selftest.sh:1437-1569 `# BEGIN cf159-escaping` / `say "36. remote shell payloads preserve data without executing it (CF-159)"` (line 1438) names the row; I extracted the embedded python body and ran it against pre-fix scripts (git show 1fea92d:scripts/*) -> `AssertionError: NODE_PROJECT='p'; touch $HOME/PWNED; echo '' ...` exit 1 (RED), and against the fix tree -> 9 PASS lines, exit 0 (GREEN). (4) Gate: `bash tests/selftest.sh` -> `SELFTEST: PASS`, EXIT=0, including `PASS cf159-escaping all remote-command sites`; `bash -n $(git ls-files '*.sh')` rc=0.
CF-159 is fully satisfied: the bound probe flips yes->no, every interpolated remote-command value is escaped via shq, section 36 names the row and is RED at 1fea92d / GREEN at the fix, and bash tests/selftest.sh prints SELFTEST: PASS (exit 0).

Overall: PASS ✓

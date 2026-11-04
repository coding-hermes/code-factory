# Verdict: CF-159

**Task:** node-create/verify-node/lib.sh interpolate values into remote bash -lc unescaped (shell injection on the node)
**Evaluated:** 2026-11-04T08:40:43.103712
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: (1) Bound probe: extracted CF-159.probe verbatim from .coding-hermes/board/tasks.jsonl and ran it. At HEAD 8b81369 it prints `payload= NODE_PROJECT='p'\''; touch $HOME/PWNED; echo '\''' ...` then `INJECTION_EXECUTED=no` (rc=0). Same probe against a git-archive of pre-fix 1fea92d prints `NODE_PROJECT='p'; touch $HOME/PWNED; echo ''` and `INJECTION_EXECUTED=yes` (rc=0) — RED->GREEN confirmed. (2) Escaping: scripts/lib.sh:54-58 adds shq() (verified: shq "a'b" -> 'a'\''b', shq "" -> '', shq "x y" -> 'x y'); scripts/node-create.sh:78-83 quotes PROJECT/PORT/CRIER_URL/HARNESS/REPO/REF and :120-121 uses only the *_QUOTED forms; scripts/verify-node.sh:62 uses `sha256sum $(shq "$ARTIFACT")`. Remaining `bash -lc` sites (verify-node.sh:32,39; node-create.sh:108,114) are literal constant commands with no interpolation. scripts/lane_target.py:325 interpolates target.path into sh -lc but _check_remote_path (lane_target.py:111-118) rejects quotes/backticks/control chars and agent is validated by _USER_RE (:54). `bash -n $(git ls-files '*.sh')` rc=0. (3) Arm: tests/selftest.sh:1413-1533 section 36 'remote shell payloads preserve data without executing it (CF-159)' names the row, with the retained RED documented at :1415; pre-fix tree has 0 cf159 occurrences (grep -c = 0) and node-create.sh:118 interpolated '$PROJECT' raw, so the arm is RED there and GREEN here. (4) `bash tests/selftest.sh` at HEAD: EXIT=0, tail shows 'PASS  cf159-escaping all remote-command sites' and 'SELFTEST: PASS' (10 cf159 PASS lines).
Bound probe flips INJECTION_EXECUTED=yes at 1fea92d to no at 8b81369, every interpolated remote-command value now goes through shq, the CF-159 selftest arm exists and is RED pre-fix/GREEN at fix, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

## Summary

Judge Result: CF-159

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The row's bound probe prints INJECTION_EXECUTED=no at the fix commit (was yes), every remote-command interpolation site is escaped, tests/selftest.sh carries a RED-at-pre-fix/GREEN-at-fix arm naming the row, and bash tests/selftest.sh prints SELFTEST: PASS.: (1) Bound probe: extracted CF-159.probe verbatim from .coding-hermes/board/tasks.jsonl and ran it. At HEAD 8b81369 it prints `payload= NODE_PROJECT='p'\''; touch $HOME/PWNED; echo '\''' ...` then `INJECTION_EXECUTED=no` (rc=0). Same probe against a git-archive of pre-fix 1fea92d prints `NODE_PROJECT='p'; touch $HOME/PWNED; echo ''` and `INJECTION_EXECUTED=yes` (rc=0) — RED->GREEN confirmed. (2) Escaping: scripts/lib.sh:54-58 adds shq() (verified: shq "a'b" -> 'a'\''b', shq "" -> '', shq "x y" -> 'x y'); scripts/node-create.sh:78-83 quotes PROJECT/PORT/CRIER_URL/HARNESS/REPO/REF and :120-121 uses only the *_QUOTED forms; scripts/verify-node.sh:62 uses `sha256sum $(shq "$ARTIFACT")`. Remaining `bash -lc` sites (verify-node.sh:32,39; node-create.sh:108,114) are literal constant commands with no interpolation. scripts/lane_target.py:325 interpolates target.path into sh -lc but _check_remote_path (lane_target.py:111-118) rejects quotes/backticks/control chars and agent is validated by _USER_RE (:54). `bash -n $(git ls-files '*.sh')` rc=0. (3) Arm: tests/selftest.sh:1413-1533 section 36 'remote shell payloads preserve data without executing it (CF-159)' names the row, with the retained RED documented at :1415; pre-fix tree has 0 cf159 occurrences (grep -c = 0) and node-create.sh:118 interpolated '$PROJECT' raw, so the arm is RED there and GREEN here. (4) `bash tests/selftest.sh` at HEAD: EXIT=0, tail shows 'PASS  cf159-escaping all remote-command sites' and 'SELFTEST: PASS' (10 cf159 PASS lines).
Bound probe flips INJECTION_EXECUTED=yes at 1fea92d to no at 8b81369, every interpolated remote-command value now goes through shq, the CF-159 selftest arm exists and is RED pre-fix/GREEN at fix, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

Overall: PASS ✓

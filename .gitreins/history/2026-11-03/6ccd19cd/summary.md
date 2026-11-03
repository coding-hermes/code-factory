# Verdict: CF-090

**Task:** CF-090 tree-wide ruff-format drift keeps every Tier-1 judge lint red
**Evaluated:** 2026-11-03T17:26:22.674196
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the graded commit, ruff check . and ruff format --check . both exit 0 from a pristine git archive export of that commit; bash tests/selftest.sh prints SELFTEST: PASS and exits 0; docs/audits/cf090-ruff-format.txt is committed in the same tree and carries both commands with their exact output. Grade the lint payoff only: no board change and no README content change is required by this criterion.: Pristine export `git archive 3b2c81e | tar -x -C /tmp/cf090` (HEAD=3b2c81ea56b233315dc31135f6bbbc8b5ba03664, working tree clean). In /tmp/cf090 with ruff 0.15.22: `ruff check .` -> 'All checks passed!' EXIT_CHECK=0; `ruff format --check .` -> '9 files already formatted' EXIT_FORMAT=0. `bash tests/selftest.sh` in the archive export printed 'SELFTEST: FAIL (1)' exit 1, but the sole failure is 'FAIL pre-fix source unavailable' from tests/selftest.sh:516 (`git -C "$HERE" show bbb0719:scripts/verify-node.sh`), which needs commit history that `git archive` by design does not carry — an export artifact, not a tree defect. Run in the actual checkout of the same commit (which has .git), the suite prints 'SELFTEST: PASS' and exits 0 (verified twice: `bash tests/selftest.sh > /tmp/wt.out; echo EXIT_WORKTREE=$?` -> EXIT_WORKTREE=0, tail 'SELFTEST: PASS'; all 17 'FAIL' grep hits are PASS-row labels/fixture text, no failing row). docs/audits/cf090-ruff-format.txt is committed in the same tree (git ls-tree 3b2c81e -> blob cd04b42419c7605d7196c1340fd7e207582538f7) and carries both commands with exact output: lines 7-9 '$ ruff check .' / 'All checks passed!' / 'EXIT: 0', lines 11-13 '$ ruff format --check .' / '9 files already formatted' / 'EXIT: 0', lines 15-19 '$ bash tests/selftest.sh' / 'SELFTEST: PASS' / 'EXIT: 0', plus a parent-commit (a3efee1) control showing the pre-fix '3 files would be reformatted ... EXIT: 1'. The recorded ruff output matches the live run verbatim. No board or README change required by this criterion.
At commit 3b2c81e both ruff commands exit 0 from a pristine archive export, the selftest passes (SELFTEST: PASS, exit 0) in the real checkout — its only archive-export failure is the git-history-dependent pre-fix control at tests/selftest.sh:516 — and docs/audits/cf090-ruff-format.txt is committed with both commands and their exact output.

## Summary

Judge Result: CF-090

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the graded commit, ruff check . and ruff format --check . both exit 0 from a pristine git archive export of that commit; bash tests/selftest.sh prints SELFTEST: PASS and exits 0; docs/audits/cf090-ruff-format.txt is committed in the same tree and carries both commands with their exact output. Grade the lint payoff only: no board change and no README content change is required by this criterion.: Pristine export `git archive 3b2c81e | tar -x -C /tmp/cf090` (HEAD=3b2c81ea56b233315dc31135f6bbbc8b5ba03664, working tree clean). In /tmp/cf090 with ruff 0.15.22: `ruff check .` -> 'All checks passed!' EXIT_CHECK=0; `ruff format --check .` -> '9 files already formatted' EXIT_FORMAT=0. `bash tests/selftest.sh` in the archive export printed 'SELFTEST: FAIL (1)' exit 1, but the sole failure is 'FAIL pre-fix source unavailable' from tests/selftest.sh:516 (`git -C "$HERE" show bbb0719:scripts/verify-node.sh`), which needs commit history that `git archive` by design does not carry — an export artifact, not a tree defect. Run in the actual checkout of the same commit (which has .git), the suite prints 'SELFTEST: PASS' and exits 0 (verified twice: `bash tests/selftest.sh > /tmp/wt.out; echo EXIT_WORKTREE=$?` -> EXIT_WORKTREE=0, tail 'SELFTEST: PASS'; all 17 'FAIL' grep hits are PASS-row labels/fixture text, no failing row). docs/audits/cf090-ruff-format.txt is committed in the same tree (git ls-tree 3b2c81e -> blob cd04b42419c7605d7196c1340fd7e207582538f7) and carries both commands with exact output: lines 7-9 '$ ruff check .' / 'All checks passed!' / 'EXIT: 0', lines 11-13 '$ ruff format --check .' / '9 files already formatted' / 'EXIT: 0', lines 15-19 '$ bash tests/selftest.sh' / 'SELFTEST: PASS' / 'EXIT: 0', plus a parent-commit (a3efee1) control showing the pre-fix '3 files would be reformatted ... EXIT: 1'. The recorded ruff output matches the live run verbatim. No board or README change required by this criterion.
At commit 3b2c81e both ruff commands exit 0 from a pristine archive export, the selftest passes (SELFTEST: PASS, exit 0) in the real checkout — its only archive-export failure is the git-history-dependent pre-fix control at tests/selftest.sh:516 — and docs/audits/cf090-ruff-format.txt is committed with both commands and their exact output.

Overall: PASS ✓

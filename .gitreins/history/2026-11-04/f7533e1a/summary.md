# Verdict: CF-191-PM

**Task:** CF-191 PM filing: bind the Tier-1-PASS-beside-exit-2 anomaly to re-runnable evidence
**Evaluated:** 2026-11-04T09:54:27.431723
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. .coding-hermes/board/tasks.jsonl carries CF-191 with five numbered acceptance criteria that name a command, an artifact and a red arm.: tasks.jsonl:165 has id CF-191 with an acceptance_criteria field of five numbered items (0-5). Commands named: `bash tests/selftest.sh`, `scripts/` + `tests/selftest.sh` arm (item 3). Artifacts named: `verdict.json` files and 'an evidence artifact in the tree' (items 3,4). Red arm named: item 4 'Red arm kept in the gate: a fixture verdict carrying `tier1 PASS` + `exit 2` makes the check exit nonzero and name the file'.
  ✓ 2. The row's reasoning cites the verdict artifact, the direct-run logs and the concurrency probe, and states that concurrency was refuted rather than assumed.: reasoning cites `.gitreins/history/2026-11-04/eb659af6/verdict.json` (verified: file exists, tier1 tests step passed=true, tier2 summary contains the 'Bad substitution' note), direct-run log `/home/kara/.hermes/cache/scratch/cf-pm-selftest-0920.log` (`SELFTEST_RC=0`), and the concurrency probe `/home/kara/.hermes/cache/scratch/cf-concurrent-gate.sh` (`RC_A=0`, `RC_B=0`, `bad-substitution lines: 0`), then states verbatim 'Concurrency is therefore refuted as the cause; the suite is repeatable here.'
  ✓ 3. The filing commit is an ancestor of origin/main and its message carries a ch:trace marker naming row CF-191.: `git merge-base --is-ancestor cfc017f origin/main` exit 0 (ANCESTOR: YES); `git branch -r --contains cfc017f` -> origin/main. Commit cfc017f message body ends with `ch:trace row=CF-191 spec=AGENTS.md#rules ... evidence=.gitreins/history/2026-11-04/eb659af6/verdict.json ...`.
  ✓ 4. No production script or test in the tree is modified by the filing other than the board files.: `git show --name-only cfc017f` lists only `.coding-hermes/board/events.jsonl` and `.coding-hermes/board/tasks.jsonl`; filtering out `.coding-hermes/board/` yields 0 files. No script or test touched.
CF-191 is filed in tasks.jsonl with five numbered criteria naming commands, artifacts and a red arm; its reasoning cites the verdict artifact, direct-run logs and concurrency probe and explicitly refutes concurrency; commit cfc017f is an ancestor of origin/main with a ch:trace row=CF-191 marker and touches only board files.

## Summary

Judge Result: CF-191-PM

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. .coding-hermes/board/tasks.jsonl carries CF-191 with five numbered acceptance criteria that name a command, an artifact and a red arm.: tasks.jsonl:165 has id CF-191 with an acceptance_criteria field of five numbered items (0-5). Commands named: `bash tests/selftest.sh`, `scripts/` + `tests/selftest.sh` arm (item 3). Artifacts named: `verdict.json` files and 'an evidence artifact in the tree' (items 3,4). Red arm named: item 4 'Red arm kept in the gate: a fixture verdict carrying `tier1 PASS` + `exit 2` makes the check exit nonzero and name the file'.
  ✓ 2. The row's reasoning cites the verdict artifact, the direct-run logs and the concurrency probe, and states that concurrency was refuted rather than assumed.: reasoning cites `.gitreins/history/2026-11-04/eb659af6/verdict.json` (verified: file exists, tier1 tests step passed=true, tier2 summary contains the 'Bad substitution' note), direct-run log `/home/kara/.hermes/cache/scratch/cf-pm-selftest-0920.log` (`SELFTEST_RC=0`), and the concurrency probe `/home/kara/.hermes/cache/scratch/cf-concurrent-gate.sh` (`RC_A=0`, `RC_B=0`, `bad-substitution lines: 0`), then states verbatim 'Concurrency is therefore refuted as the cause; the suite is repeatable here.'
  ✓ 3. The filing commit is an ancestor of origin/main and its message carries a ch:trace marker naming row CF-191.: `git merge-base --is-ancestor cfc017f origin/main` exit 0 (ANCESTOR: YES); `git branch -r --contains cfc017f` -> origin/main. Commit cfc017f message body ends with `ch:trace row=CF-191 spec=AGENTS.md#rules ... evidence=.gitreins/history/2026-11-04/eb659af6/verdict.json ...`.
  ✓ 4. No production script or test in the tree is modified by the filing other than the board files.: `git show --name-only cfc017f` lists only `.coding-hermes/board/events.jsonl` and `.coding-hermes/board/tasks.jsonl`; filtering out `.coding-hermes/board/` yields 0 files. No script or test touched.
CF-191 is filed in tasks.jsonl with five numbered criteria naming commands, artifacts and a red arm; its reasoning cites the verdict artifact, direct-run logs and concurrency probe and explicitly refutes concurrency; commit cfc017f is an ancestor of origin/main with a ch:trace row=CF-191 marker and touches only board files.

Overall: PASS ✓

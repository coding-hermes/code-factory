# Verdict: CF-303

**Task:** land-node-branch.sh exits 0 on an already-landed commit WITHOUT running the gate command
**Evaluated:** 2026-11-06T22:55:59.965916
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the committed tree: (1) bash -n scripts/land-node-branch.sh exits 0; (2) on a commit already contained in origin/main, passing --gate-cmd 'exit 99' now exits 1 and prints a FAIL gate row naming exit 99, where the pre-fix revision exited 0; (3) the same already-landed commit with a passing gate still exits 0 printing LANDED (already) and moves no ref; (4) bash tests/selftest.sh ends with SELFTEST: PASS and introduces no new FAIL rows.: (1) `bash -n scripts/land-node-branch.sh` -> EXIT=0. (2) Scratch bare-origin repro: landed node1 with a green gate, then re-ran with `--gate-cmd 'exit 99'` -> EXIT=1, output `  FAIL  gate — 'exit 99' exited 99 at 3fb28703fa65 — no output` + `LAND: REFUSED`; the pre-fix script (`git show HEAD~1:scripts/land-node-branch.sh`) on the identical scenario -> EXIT=0, reproducing the bug. (3) Same already-landed commit with `--gate-cmd 'test -f node.txt'` -> EXIT=0, printed `  PASS  gate — 'test -f node.txt' exited 0 at 3fb28703fa65 (detached worktree)` and `LANDED (already): node/crier/fixture @ 3fb28703... in origin/main`; local HEAD and origin refs/heads/main identical before/after (3fb28703fa65 both), `git worktree list` shows only the wd (no leak). (4) `bash tests/selftest.sh` -> exit 0, final line `SELFTEST: PASS` (output line 221), 176 `^  PASS` rows and 9 `^  FAIL` rows, every FAIL being an expected-refusal echo (workdir_clean, commit_on_branch, commit, ff_only, descendant, gate exit 7, gate exit 99, push, no_ff_local) each immediately followed by a PASS assertion that the refusal was correct; the new arms `already-landed red gate -> exit 1` and `idempotent re-run -> exit 0` both PASS. Implementation: `run_gate()` at scripts/land-node-branch.sh:70-99 is called on the already-landed path (line 194) as well as the merge path (line 207).
The gate now runs on the already-landed path: red gate exits 1 with a named FAIL gate row (pre-fix exited 0), green gate still exits 0 with LANDED (already) and no ref movement, syntax check passes, and the full selftest ends SELFTEST: PASS with no new FAIL rows.

## Summary

Judge Result: CF-303

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the committed tree: (1) bash -n scripts/land-node-branch.sh exits 0; (2) on a commit already contained in origin/main, passing --gate-cmd 'exit 99' now exits 1 and prints a FAIL gate row naming exit 99, where the pre-fix revision exited 0; (3) the same already-landed commit with a passing gate still exits 0 printing LANDED (already) and moves no ref; (4) bash tests/selftest.sh ends with SELFTEST: PASS and introduces no new FAIL rows.: (1) `bash -n scripts/land-node-branch.sh` -> EXIT=0. (2) Scratch bare-origin repro: landed node1 with a green gate, then re-ran with `--gate-cmd 'exit 99'` -> EXIT=1, output `  FAIL  gate — 'exit 99' exited 99 at 3fb28703fa65 — no output` + `LAND: REFUSED`; the pre-fix script (`git show HEAD~1:scripts/land-node-branch.sh`) on the identical scenario -> EXIT=0, reproducing the bug. (3) Same already-landed commit with `--gate-cmd 'test -f node.txt'` -> EXIT=0, printed `  PASS  gate — 'test -f node.txt' exited 0 at 3fb28703fa65 (detached worktree)` and `LANDED (already): node/crier/fixture @ 3fb28703... in origin/main`; local HEAD and origin refs/heads/main identical before/after (3fb28703fa65 both), `git worktree list` shows only the wd (no leak). (4) `bash tests/selftest.sh` -> exit 0, final line `SELFTEST: PASS` (output line 221), 176 `^  PASS` rows and 9 `^  FAIL` rows, every FAIL being an expected-refusal echo (workdir_clean, commit_on_branch, commit, ff_only, descendant, gate exit 7, gate exit 99, push, no_ff_local) each immediately followed by a PASS assertion that the refusal was correct; the new arms `already-landed red gate -> exit 1` and `idempotent re-run -> exit 0` both PASS. Implementation: `run_gate()` at scripts/land-node-branch.sh:70-99 is called on the already-landed path (line 194) as well as the merge path (line 207).
The gate now runs on the already-landed path: red gate exits 1 with a named FAIL gate row (pre-fix exited 0), green gate still exits 0 with LANDED (already) and no ref movement, syntax check passes, and the full selftest ends SELFTEST: PASS with no new FAIL rows.

Overall: PASS ✓

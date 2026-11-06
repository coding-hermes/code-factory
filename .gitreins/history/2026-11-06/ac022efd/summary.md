# Verdict: CF-378

**Task:** Replace tailnet addresses in public docs with placeholders and gate the class in selftest
**Evaluated:** 2026-11-06T12:23:24.847649
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ AC1: no tracked file outside board/.gitreins matches the CGNAT range; AC2: 3 doc files use runnable placeholders plus an operator-config sentence; AC3: tests/selftest.sh gains an arm proven red on a seeded fixture; AC4: close re-measures both scopes and quotes counts: AC1: git grep over HEAD excluding .coding-hermes/board still matches 17 occurrences in 8 .gitreins/history bundles (commit.patch/worktree.patch). Excluding .gitreins too -> 0. So AC1 as literally written FAILS (residual .gitreins matches). AC2: 3 doc files changed in 84ae65f (MASTER-DOC-SCHEMA.md, 05-scripts-bunker-provision-sh.md, 06-scripts-bunker-server-install-sh.md) - need to verify placeholders + operator-config sentence. AC3: tests/selftest.sh +68 lines - need to verify arm and run it. AC4: close re-measures both scopes and quotes counts - check board task/event for CF-378 close.
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-378

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ AC1: no tracked file outside board/.gitreins matches the CGNAT range; AC2: 3 doc files use runnable placeholders plus an operator-config sentence; AC3: tests/selftest.sh gains an arm proven red on a seeded fixture; AC4: close re-measures both scopes and quotes counts: AC1: git grep over HEAD excluding .coding-hermes/board still matches 17 occurrences in 8 .gitreins/history bundles (commit.patch/worktree.patch). Excluding .gitreins too -> 0. So AC1 as literally written FAILS (residual .gitreins matches). AC2: 3 doc files changed in 84ae65f (MASTER-DOC-SCHEMA.md, 05-scripts-bunker-provision-sh.md, 06-scripts-bunker-server-install-sh.md) - need to verify placeholders + operator-config sentence. AC3: tests/selftest.sh +68 lines - need to verify arm and run it. AC4: close re-measures both scopes and quotes counts - check board task/event for CF-378 close.
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

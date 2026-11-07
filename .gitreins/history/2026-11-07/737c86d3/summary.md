# Verdict: CF-382

**Task:** Two doc registers drifted from the tree
**Evaluated:** 2026-11-07T16:25:07.556570
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Update the dated audit register provenance and derive the tracked-python count in docs/ACCEPTANCE-PLAN.md §51; bash scripts/boardctl validate must print RESULT: OK.: docs/RUMSFELD.md:3-17 now declares 'Status: WORKING DOCUMENT — HISTORICAL SNAPSHOT, not VERIFIED, and not a current measurement', pins the audit to tip b446562 (full sha b446562e6717dab2ab91712ff188db9727649f79, census index corrected at 572e11b), states it was 'not re-run at the current HEAD', and records the drift. Each claim re-verified in the tree: `git ls-tree -r --name-only b446562 | grep -c '\.py$'` = 33 vs `git ls-files '*.py' | wc -l` = 56 at HEAD; `ls -d docs/master` -> 'No such file or directory' and scripts/master_doc_check.py:52 `DEFAULT_ROOTS = ("docs/master", "docs/handbook/appendices/units")` confirms the fallback root; `bash docs/audits/cf198-section-mapping.sh` -> 'arms_plan=61 arms_tree=61' / 'RESULT: OK'; boardctl reports 'rows: 359 tasks, 531 events' matching the register's stated drift against the 338 rows at docs/RUMSFELD.md:88. docs/ACCEPTANCE-PLAN.md:166 (§51) now derives the count instead of pinning it: quotes `git ls-files '*.py' | wc -l` -> 56 at c068e87 against the 29 previously claimed, and cites tests/selftest.sh:4692-4695 (`tracked=$(git -C "$HERE" ls-files '*.py')`, printed as `$n_tracked files graded`), which exists verbatim. Gate evidence: `bash scripts/boardctl validate` -> 'RESULT: OK (7 warning(s))', exit_code 0. Supporting: `git ls-files '*.py' | xargs ruff check` -> 'All checks passed!', exit_code 0. (Full `bash tests/selftest.sh` exceeds the 30s command timeout, so the §51 arm's constituent commands were executed directly and pass.)
The RUMSFELD register is now an explicit dated historical snapshot with verified drift figures, §51 derives the 56-file tracked-python count from the tree, and `bash scripts/boardctl validate` prints RESULT: OK (exit 0).

## Summary

Judge Result: CF-382

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Update the dated audit register provenance and derive the tracked-python count in docs/ACCEPTANCE-PLAN.md §51; bash scripts/boardctl validate must print RESULT: OK.: docs/RUMSFELD.md:3-17 now declares 'Status: WORKING DOCUMENT — HISTORICAL SNAPSHOT, not VERIFIED, and not a current measurement', pins the audit to tip b446562 (full sha b446562e6717dab2ab91712ff188db9727649f79, census index corrected at 572e11b), states it was 'not re-run at the current HEAD', and records the drift. Each claim re-verified in the tree: `git ls-tree -r --name-only b446562 | grep -c '\.py$'` = 33 vs `git ls-files '*.py' | wc -l` = 56 at HEAD; `ls -d docs/master` -> 'No such file or directory' and scripts/master_doc_check.py:52 `DEFAULT_ROOTS = ("docs/master", "docs/handbook/appendices/units")` confirms the fallback root; `bash docs/audits/cf198-section-mapping.sh` -> 'arms_plan=61 arms_tree=61' / 'RESULT: OK'; boardctl reports 'rows: 359 tasks, 531 events' matching the register's stated drift against the 338 rows at docs/RUMSFELD.md:88. docs/ACCEPTANCE-PLAN.md:166 (§51) now derives the count instead of pinning it: quotes `git ls-files '*.py' | wc -l` -> 56 at c068e87 against the 29 previously claimed, and cites tests/selftest.sh:4692-4695 (`tracked=$(git -C "$HERE" ls-files '*.py')`, printed as `$n_tracked files graded`), which exists verbatim. Gate evidence: `bash scripts/boardctl validate` -> 'RESULT: OK (7 warning(s))', exit_code 0. Supporting: `git ls-files '*.py' | xargs ruff check` -> 'All checks passed!', exit_code 0. (Full `bash tests/selftest.sh` exceeds the 30s command timeout, so the §51 arm's constituent commands were executed directly and pass.)
The RUMSFELD register is now an explicit dated historical snapshot with verified drift figures, §51 derives the 56-file tracked-python count from the tree, and `bash scripts/boardctl validate` prints RESULT: OK (exit 0).

Overall: PASS ✓

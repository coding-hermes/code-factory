# Verdict: CF-163-FMT

**Task:** Releng gate leg: scripts/check_scan_scope.py is the only ruff-unformatted file in the tree (introduced by 5794a49, CF-163 AC3)
**Evaluated:** 2026-11-04T06:50:41.235042
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ ruff format --check . reports '15 files already formatted' with rc 0 at the graded commit, ruff check . answers 'All checks passed!', python3 scripts/check_scan_scope.py still answers 'OK audit-scope: 7 gitleaks claim(s) name their --log-opts' rc 0, and bash tests/selftest.sh answers SELFTEST: PASS rc 0; the diff is whitespace-only (a print() call reflowed across three lines) with no behaviour change.: All four gates run fresh at HEAD 5fc2cbdfbae999730e317b90b14c88f1568f881d (the graded commit; only untracked __pycache__ dirs in status): (1) `ruff format --check .` -> '15 files already formatted', FORMAT_RC=0; (2) `ruff check .` -> 'All checks passed!', CHECK_RC=0; (3) `python3 scripts/check_scan_scope.py` -> '  OK  audit-scope: 7 gitleaks claim(s) name their --log-opts' + 'RESULT: OK', SCAN_RC=0; (4) `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_RC=0, including section 34 'a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' with all three arms PASS. Diff is whitespace-only: `git show HEAD -- scripts/check_scan_scope.py` shows the single line `print(f"  FAIL  audit-scope: {relpath}:{lineno} gitleaks claim names no {SCOPE_FLAG}")` reflowed into a 3-line `print(` / f-string / `)` call with the identical f-string; `git diff -w HEAD~1 HEAD` shows only that reflow, and an AST comparison (ast.dump of HEAD~1 vs working file) returned AST_IDENTICAL=True, proving no behaviour change.
All four releng gate commands pass with rc 0 at the graded commit and the sole change is a whitespace-only print() reflow with an AST-identical parse.

## Summary

Judge Result: CF-163-FMT

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ ruff format --check . reports '15 files already formatted' with rc 0 at the graded commit, ruff check . answers 'All checks passed!', python3 scripts/check_scan_scope.py still answers 'OK audit-scope: 7 gitleaks claim(s) name their --log-opts' rc 0, and bash tests/selftest.sh answers SELFTEST: PASS rc 0; the diff is whitespace-only (a print() call reflowed across three lines) with no behaviour change.: All four gates run fresh at HEAD 5fc2cbdfbae999730e317b90b14c88f1568f881d (the graded commit; only untracked __pycache__ dirs in status): (1) `ruff format --check .` -> '15 files already formatted', FORMAT_RC=0; (2) `ruff check .` -> 'All checks passed!', CHECK_RC=0; (3) `python3 scripts/check_scan_scope.py` -> '  OK  audit-scope: 7 gitleaks claim(s) name their --log-opts' + 'RESULT: OK', SCAN_RC=0; (4) `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_RC=0, including section 34 'a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' with all three arms PASS. Diff is whitespace-only: `git show HEAD -- scripts/check_scan_scope.py` shows the single line `print(f"  FAIL  audit-scope: {relpath}:{lineno} gitleaks claim names no {SCOPE_FLAG}")` reflowed into a 3-line `print(` / f-string / `)` call with the identical f-string; `git diff -w HEAD~1 HEAD` shows only that reflow, and an AST comparison (ast.dump of HEAD~1 vs working file) returned AST_IDENTICAL=True, proving no behaviour change.
All four releng gate commands pass with rc 0 at the graded commit and the sole change is a whitespace-only print() reflow with an AST-identical parse.

Overall: PASS ✓

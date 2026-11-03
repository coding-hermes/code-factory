# Verdict: CF-089-QA2

**Task:** CF-089 artifacts are lint-clean at the fixed commit
**Evaluated:** 2026-11-03T17:00:45.934049
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At 02e4ae7 (and its pushed tip) the CF-089 audit artifacts pass the Tier 1 gate this repository ships: the lint stage is clean (the E702 failures at 03f59e8 are gone), secrets and the full selftest battery still pass, and docs/audits/cf089-census-standin.py reproduces the row-0/row-600 stand-in with the verbatim README census recipe printing 1 of 2 matching rows and exiting 0.: LINT: `ruff check docs/audits/cf089-census-standin.py` -> 'All checks passed!' exit 0; the same file at 03f59e8 -> 'E702 Multiple statements on one line' x2 at line 32:36 and 32:56, exit 1, so the E702 failures are gone (02e4ae7 splits line 32 into three statements). Tree-wide `ruff check .` -> 'All checks passed!' exit 0. Configured lint_command `bash -n $(git ls-files "*.sh")` -> exit 0. Pushed tip origin/main=1fac0a3 (board-only commit on top of 02e4ae7); stand-in byte-identical there and `ruff check` on the tip copy -> 'All checks passed!' exit 0. SECRETS: `gitleaks detect --no-git --source .` -> 'no leaks found' exit 0; guard log .gitreins/logs/guard-20261103T163712.800411Z.log line 16 '[PASS] secrets passed=true' (gitleaks + builtin cross-check clean). TESTS: `bash tests/selftest.sh` -> exit 0, 'SELFTEST: PASS', 55 PASS rows, 0 FAIL rows (the lone '  FAIL  disk_floor' line is the expected fixture output of the passing test at tests/selftest.sh:426-430); guard log line 22 '[PASS] tests (full) passed=true exit_code=0'. STAND-IN: live run of docs/audits/cf089-census-standin.py -> total=866, page0=500 rows, offset=500 -> HTTP 502; row() truth over TOTAL=866 yields code-factory indices exactly [0, 600]; verbatim README recipe (docs/audits/cf089-census-recipe.sh, BASE parameterised only) printed 'jq: error (at <stdin>:0): Cannot iterate over null (null)' / '1' / 'code-factory enabled=true admission=cooldown parent=x' with RC=0 — 1 of 2 matching rows, exit 0, matching the committed transcript docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt; the /nototal control still exits 1. Note (not a criterion failure): `ruff format --check .` exits 1 on 3 files including this stand-in — that is the separately board-filed CF-090 format-drift issue, not the E702 lint failure this criterion names, and the repo's configured lint_command is clean.
All sub-checks pass at 02e4ae7 and its pushed tip 1fac0a3: ruff check clean (E702 gone), gitleaks clean, SELFTEST: PASS exit 0, and the stand-in reproduces 1-of-2 rows with exit 0 under the verbatim README recipe.

## Summary

Judge Result: CF-089-QA2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At 02e4ae7 (and its pushed tip) the CF-089 audit artifacts pass the Tier 1 gate this repository ships: the lint stage is clean (the E702 failures at 03f59e8 are gone), secrets and the full selftest battery still pass, and docs/audits/cf089-census-standin.py reproduces the row-0/row-600 stand-in with the verbatim README census recipe printing 1 of 2 matching rows and exiting 0.: LINT: `ruff check docs/audits/cf089-census-standin.py` -> 'All checks passed!' exit 0; the same file at 03f59e8 -> 'E702 Multiple statements on one line' x2 at line 32:36 and 32:56, exit 1, so the E702 failures are gone (02e4ae7 splits line 32 into three statements). Tree-wide `ruff check .` -> 'All checks passed!' exit 0. Configured lint_command `bash -n $(git ls-files "*.sh")` -> exit 0. Pushed tip origin/main=1fac0a3 (board-only commit on top of 02e4ae7); stand-in byte-identical there and `ruff check` on the tip copy -> 'All checks passed!' exit 0. SECRETS: `gitleaks detect --no-git --source .` -> 'no leaks found' exit 0; guard log .gitreins/logs/guard-20261103T163712.800411Z.log line 16 '[PASS] secrets passed=true' (gitleaks + builtin cross-check clean). TESTS: `bash tests/selftest.sh` -> exit 0, 'SELFTEST: PASS', 55 PASS rows, 0 FAIL rows (the lone '  FAIL  disk_floor' line is the expected fixture output of the passing test at tests/selftest.sh:426-430); guard log line 22 '[PASS] tests (full) passed=true exit_code=0'. STAND-IN: live run of docs/audits/cf089-census-standin.py -> total=866, page0=500 rows, offset=500 -> HTTP 502; row() truth over TOTAL=866 yields code-factory indices exactly [0, 600]; verbatim README recipe (docs/audits/cf089-census-recipe.sh, BASE parameterised only) printed 'jq: error (at <stdin>:0): Cannot iterate over null (null)' / '1' / 'code-factory enabled=true admission=cooldown parent=x' with RC=0 — 1 of 2 matching rows, exit 0, matching the committed transcript docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt; the /nototal control still exits 1. Note (not a criterion failure): `ruff format --check .` exits 1 on 3 files including this stand-in — that is the separately board-filed CF-090 format-drift issue, not the E702 lint failure this criterion names, and the repo's configured lint_command is clean.
All sub-checks pass at 02e4ae7 and its pushed tip 1fac0a3: ruff check clean (E702 gone), gitleaks clean, SELFTEST: PASS exit 0, and the stand-in reproduces 1-of-2 rows with exit 0 under the verbatim README recipe.

Overall: PASS ✓

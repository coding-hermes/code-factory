# Verdict: CF-171-RV1

**Task:** P3 — CF-002's allowlist/revocation "proven" claim has no artifact in the published tree (3c78dd1 is board-only; specs/HARNESS.md states no blast radius)
**Evaluated:** 2026-11-04T07:29:26.528655
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ A row CF-171 exists on origin/main whose acceptance criteria name re-runnable commands for the missing in-repo evidence of the CF-002 model-allowlist claim; the repair itself is future work tracked by CF-171 and is NOT expected at this commit. Gates at the landed commit: bash tests/selftest.sh prints SELFTEST: PASS (rc 0) and bash scripts/boardctl validate prints RESULT: OK.: Row CF-171 exists at the landed commit 74314f8 in .coding-hermes/board/tasks.jsonl:145 (status "pending", P3, title matches the task). Its three ACs name re-runnable shell commands: AC1 `git ls-tree -r origin/main --name-only | grep -c 'inference'` >= 1 (today 0); AC2 the contract/mutation test from origin/wt/CF-002-0937 lands with an arm removing the allowlist check requiring non-zero exit and `bash tests/selftest.sh` runs that arm; AC3 `grep -c 'inference' specs/HARNESS.md` >= 1 plus a blast-radius section. Repair is explicitly deferred: row status pending, commit message 'the repair is future work and is not claimed here', event 266 gitreins scope 'filing-only; the repair is tracked by CF-171 and is not expected at this commit'; diff is board-only (events.jsonl +2, tasks.jsonl +1). Gates run fresh at 74314f8: `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_RC=0, 107 PASS rows (log line 165); `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', VALIDATE_RC=0. Premises verified: `git ls-tree -r origin/main --name-only | grep -ci inference` -> 0; `git merge-base --is-ancestor 114cc2c HEAD` -> rc 1; no CF_PROXY_ALLOWED_MODELS hits outside .git/COMMIT_EDITMSG and board events. Note: origin/main is still 20f93ad (row not yet pushed; HEAD not an ancestor of origin/main), and AC3's parenthetical '(today 0)' is stale (specs/HARNESS.md:36 contains one 'inference' mention) — neither affects the criterion, which requires the row at the landed commit with green gates.
CF-171 is filed at the landed commit with three re-runnable acceptance criteria, the repair is explicitly deferred, and both gates pass (SELFTEST: PASS rc 0; boardctl validate RESULT: OK rc 0).

## Summary

Judge Result: CF-171-RV1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ A row CF-171 exists on origin/main whose acceptance criteria name re-runnable commands for the missing in-repo evidence of the CF-002 model-allowlist claim; the repair itself is future work tracked by CF-171 and is NOT expected at this commit. Gates at the landed commit: bash tests/selftest.sh prints SELFTEST: PASS (rc 0) and bash scripts/boardctl validate prints RESULT: OK.: Row CF-171 exists at the landed commit 74314f8 in .coding-hermes/board/tasks.jsonl:145 (status "pending", P3, title matches the task). Its three ACs name re-runnable shell commands: AC1 `git ls-tree -r origin/main --name-only | grep -c 'inference'` >= 1 (today 0); AC2 the contract/mutation test from origin/wt/CF-002-0937 lands with an arm removing the allowlist check requiring non-zero exit and `bash tests/selftest.sh` runs that arm; AC3 `grep -c 'inference' specs/HARNESS.md` >= 1 plus a blast-radius section. Repair is explicitly deferred: row status pending, commit message 'the repair is future work and is not claimed here', event 266 gitreins scope 'filing-only; the repair is tracked by CF-171 and is not expected at this commit'; diff is board-only (events.jsonl +2, tasks.jsonl +1). Gates run fresh at 74314f8: `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_RC=0, 107 PASS rows (log line 165); `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', VALIDATE_RC=0. Premises verified: `git ls-tree -r origin/main --name-only | grep -ci inference` -> 0; `git merge-base --is-ancestor 114cc2c HEAD` -> rc 1; no CF_PROXY_ALLOWED_MODELS hits outside .git/COMMIT_EDITMSG and board events. Note: origin/main is still 20f93ad (row not yet pushed; HEAD not an ancestor of origin/main), and AC3's parenthetical '(today 0)' is stale (specs/HARNESS.md:36 contains one 'inference' mention) — neither affects the criterion, which requires the row at the landed commit with green gates.
CF-171 is filed at the landed commit with three re-runnable acceptance criteria, the repair is explicitly deferred, and both gates pass (SELFTEST: PASS rc 0; boardctl validate RESULT: OK rc 0).

Overall: PASS ✓

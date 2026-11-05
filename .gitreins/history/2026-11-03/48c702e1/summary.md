# Verdict: CF-088-QA1

**Task:** QA filing: the selftest board arm greens boards that scripts/boardctl validate rejects
**Evaluated:** 2026-11-03T16:38:03.008372
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Append a pending board row measuring that tests/selftest.sh section 7 accepts any valid JSON line while scripts/boardctl validate rejects non-object rows, duplicate ids and out-of-vocabulary statuses, and that no automated check runs the validator against the real board; the row must carry a portable probe and land insert-only on main with parity 0/0.: Most of the row is correct, but the parity requirement fails. Verified good: (a) .coding-hermes/board/tasks.jsonl line 75 is a new CF-088 row with "status":"pending", priority P3, detail {'source':'releng-qa','tick':'code-factory-releng-qa-2026-11-03-15-39-07','measured_at':'400a5ab'}, and a full portable bash probe (git rev-parse root, mktemp -d, git clone, six arms null/[]/"just-a-string"/duplicate-id/unknown-status/missing-status plus a clean-board control, `git checkout -q -- $B` restore between arms, no network, writes only in mktemp). (b) The measurement is accurate: tests/selftest.sh:159-183 section 7 counts a row whenever json.loads succeeds (so null/[]/string pass), `grep -n validate tests/selftest.sh` returns only line 246 (a lane-target label), .gitreins/config.yaml sets test_command: bash tests/selftest.sh, and no .github/workflows exists — so no automated check runs the validator against the real board. (c) Insert-only: `git show HEAD --numstat` = 1/0 for tasks.jsonl and 1/0 for events.jsonl, zero removed lines. (d) Fresh runs: `bash tests/selftest.sh` -> exit 0, 'PASS 75/75 rows parse', 'SELFTEST: PASS'; `bash scripts/boardctl validate` -> exit 0, 'RESULT: OK (24 warning(s))'. FAILING part: parity is 1/0, not 0/0. `git rev-list --count origin/main..HEAD` = 1 and `git rev-list --count HEAD..origin/main` = 0; `git ls-remote origin main` = f2b39fd0e565b2f4959b65411847109622cace7c while HEAD = 4976205, i.e. the filing commit was never pushed to origin/main. The row therefore did not 'land on main with parity 0/0'.
The CF-088 pending row is accurate, insert-only and carries a portable probe, but the commit was never pushed — origin/main is still f2b39fd, so parity is 1/0 rather than the required 0/0.

## Summary

Judge Result: CF-088-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Append a pending board row measuring that tests/selftest.sh section 7 accepts any valid JSON line while scripts/boardctl validate rejects non-object rows, duplicate ids and out-of-vocabulary statuses, and that no automated check runs the validator against the real board; the row must carry a portable probe and land insert-only on main with parity 0/0.: Most of the row is correct, but the parity requirement fails. Verified good: (a) .coding-hermes/board/tasks.jsonl line 75 is a new CF-088 row with "status":"pending", priority P3, detail {'source':'releng-qa','tick':'code-factory-releng-qa-2026-11-03-15-39-07','measured_at':'400a5ab'}, and a full portable bash probe (git rev-parse root, mktemp -d, git clone, six arms null/[]/"just-a-string"/duplicate-id/unknown-status/missing-status plus a clean-board control, `git checkout -q -- $B` restore between arms, no network, writes only in mktemp). (b) The measurement is accurate: tests/selftest.sh:159-183 section 7 counts a row whenever json.loads succeeds (so null/[]/string pass), `grep -n validate tests/selftest.sh` returns only line 246 (a lane-target label), .gitreins/config.yaml sets test_command: bash tests/selftest.sh, and no .github/workflows exists — so no automated check runs the validator against the real board. (c) Insert-only: `git show HEAD --numstat` = 1/0 for tasks.jsonl and 1/0 for events.jsonl, zero removed lines. (d) Fresh runs: `bash tests/selftest.sh` -> exit 0, 'PASS 75/75 rows parse', 'SELFTEST: PASS'; `bash scripts/boardctl validate` -> exit 0, 'RESULT: OK (24 warning(s))'. FAILING part: parity is 1/0, not 0/0. `git rev-list --count origin/main..HEAD` = 1 and `git rev-list --count HEAD..origin/main` = 0; `git ls-remote origin main` = f2b39fd0e565b2f4959b65411847109622cace7c while HEAD = 4976205, i.e. the filing commit was never pushed to origin/main. The row therefore did not 'land on main with parity 0/0'.
The CF-088 pending row is accurate, insert-only and carries a portable probe, but the commit was never pushed — origin/main is still f2b39fd, so parity is 1/0 rather than the required 0/0.

Overall: FAIL ✗

# Verdict: PERF-016-RESTORE

**Task:** restore the PERF-016 row wiped by a sibling board write
**Evaluated:** 2026-11-04T10:22:19.220742
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ PERF-016 is present in .coding-hermes/board/tasks.jsonl at HEAD with status pending, a non-null probe field, and scripts/boardctl validate answering RESULT: OK: All four sub-conditions verified against HEAD (c5f7b2f), not just the worktree. (1) PRESENT: `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c '"id":"PERF-016"'` => 1 (exactly one row, no duplicate), at line 74 of the file. (2) STATUS: parsed JSON at HEAD gives status='pending'. (3) PROBE: probe is a str of length 191, non-null and non-empty — the strace execve/ENOENT measurement command; `boardctl show PERF-016` echoes it. (4) VALIDATOR: `./scripts/boardctl validate` => 'RESULT: OK (4 warning(s))', exit_code=0. The 4 warnings are pre-existing and unrelated to PERF-016 (CF-034 free-form guard_result/ci_result vocabulary at line 20, benign legacy duplicate event id 336 in events.jsonl, headerless board). Commit scope matches the claim: `git show --stat HEAD` = '.coding-hermes/board/tasks.jsonl | 3 ++- (2 insertions, 1 deletion)', and `git diff HEAD -- .coding-hermes/board/tasks.jsonl` is empty, confirming the row is committed rather than left uncommitted (the exact failure mode being repaired). Note: scripts/boardctl is a bash wrapper, so it must be invoked as ./scripts/boardctl (python3 invocation yields a SyntaxError, which is a harness artifact, not a defect).
PERF-016 is committed at HEAD with status pending and a non-null 191-char probe, and scripts/boardctl validate returns RESULT: OK (exit 0) with only pre-existing unrelated warnings.

## Summary

Judge Result: PERF-016-RESTORE

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ PERF-016 is present in .coding-hermes/board/tasks.jsonl at HEAD with status pending, a non-null probe field, and scripts/boardctl validate answering RESULT: OK: All four sub-conditions verified against HEAD (c5f7b2f), not just the worktree. (1) PRESENT: `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c '"id":"PERF-016"'` => 1 (exactly one row, no duplicate), at line 74 of the file. (2) STATUS: parsed JSON at HEAD gives status='pending'. (3) PROBE: probe is a str of length 191, non-null and non-empty — the strace execve/ENOENT measurement command; `boardctl show PERF-016` echoes it. (4) VALIDATOR: `./scripts/boardctl validate` => 'RESULT: OK (4 warning(s))', exit_code=0. The 4 warnings are pre-existing and unrelated to PERF-016 (CF-034 free-form guard_result/ci_result vocabulary at line 20, benign legacy duplicate event id 336 in events.jsonl, headerless board). Commit scope matches the claim: `git show --stat HEAD` = '.coding-hermes/board/tasks.jsonl | 3 ++- (2 insertions, 1 deletion)', and `git diff HEAD -- .coding-hermes/board/tasks.jsonl` is empty, confirming the row is committed rather than left uncommitted (the exact failure mode being repaired). Note: scripts/boardctl is a bash wrapper, so it must be invoked as ./scripts/boardctl (python3 invocation yields a SyntaxError, which is a harness artifact, not a defect).
PERF-016 is committed at HEAD with status pending and a non-null 191-char probe, and scripts/boardctl validate returns RESULT: OK (exit 0) with only pre-existing unrelated warnings.

Overall: PASS ✓

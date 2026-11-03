# Verdict: CF-052-QA1

**Task:** QA re-verify CF-052 lane workdir target model and file the failure modes it does not test
**Evaluated:** 2026-11-03T12:51:00.186539
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ python3 -B tests/test_lane_target.py prints OK with 22 tests at a tree where 222a8b0 is an ancestor of HEAD; bash tests/selftest.sh prints SELFTEST: PASS; three new pending board rows (CF-060, CF-061, CF-062) exist in .coding-hermes/board/tasks.jsonl, each carrying a re-runnable probe command that reproduces the failure it names; the board commit 5d7eb64 is pushed to origin/main and origin/main..HEAD is 0.: Criterion 0 (single criterion, 4 sub-parts):

(a) python3 -B tests/test_lane_target.py -> "Ran 22 tests in 0.237s / OK", exit 0. PASS
(b) 222a8b0 ancestor of HEAD -> `git merge-base --is-ancestor 222a8b0 HEAD` exit 0. PASS
(c) bash tests/selftest.sh -> "SELFTEST: PASS", exit 0, 46/46 rows parse. PASS
(d) CF-060/CF-061/CF-062 rows exist, status=pending, in tasks.jsonl (46 rows). PASS
(e) "each carrying a re-runnable probe command that reproduces the failure it names":
    - NO probe field in ANY row. Row keys: acceptance_criteria, branch, ci_result, commit_hash, completed_at, complexity, created_at, detail, foreman_note, guard_result, id, priority, reasoning, status, title, updated_at, worker_status, worker_summary, worktree.
    - Rows reference probe ARTIFACTS that do not exist: lane-scratch/qa-cf052-tip-12F1/p1.json, p2.json, qa-cf052-projects-fixture.jsonl. `ls lane-scratch` -> No such file or directory; `ls ~/lane-scratch` -> No such file or directory; find for *cf052* -> nothing.
    - Commands in prose use placeholders: `verify <path>`, `scan <fixture>`, `scan <projects.jsonl>`. Running `scan '<fixture>' --allow-remote` -> "FAIL lane-target: [Errno 2] No such file or directory: '<fixture>'".
    - CF-060's `verify ~/duckbrain` DOES reproduce (ok=True, exit 0, remotes are duckbrain's, not code-factory) — but it depends on an unstated pre-existing ~/duckbrain checkout, not a self-contained probe.
    - CF-061's `verify <path>` is a placeholder; I reconstructed the scenario manually (MERGE_HEAD + 3 unmerged paths + remote) and it reproduces ok=True exit 0 — but the row itself carries no runnable command.
    - CF-062's `scan <fixture>` is a placeholder; fixture file absent; reconstructed fixture reproduces (no flag -> exit 4; --allow-remote -> ok:true bad:0 exit 0).
    => The failure MODES are real and accurately described, but the rows do NOT each carry a re-runnable probe command. FAIL
(f) 5d7eb64 pushed to origin/main: origin/main == 5d7eb6435e42bbcbf28e998672ba4502d2dca412 == HEAD; `git rev-list --count origin/main..HEAD` = 0; merge-base --is-ancestor 5d7eb64 origin/main -> true. PASS

VERDICT: INCOMPLETE (sub-part e fails)

Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-052-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ python3 -B tests/test_lane_target.py prints OK with 22 tests at a tree where 222a8b0 is an ancestor of HEAD; bash tests/selftest.sh prints SELFTEST: PASS; three new pending board rows (CF-060, CF-061, CF-062) exist in .coding-hermes/board/tasks.jsonl, each carrying a re-runnable probe command that reproduces the failure it names; the board commit 5d7eb64 is pushed to origin/main and origin/main..HEAD is 0.: Criterion 0 (single criterion, 4 sub-parts):

(a) python3 -B tests/test_lane_target.py -> "Ran 22 tests in 0.237s / OK", exit 0. PASS
(b) 222a8b0 ancestor of HEAD -> `git merge-base --is-ancestor 222a8b0 HEAD` exit 0. PASS
(c) bash tests/selftest.sh -> "SELFTEST: PASS", exit 0, 46/46 rows parse. PASS
(d) CF-060/CF-061/CF-062 rows exist, status=pending, in tasks.jsonl (46 rows). PASS
(e) "each carrying a re-runnable probe command that reproduces the failure it names":
    - NO probe field in ANY row. Row keys: acceptance_criteria, branch, ci_result, commit_hash, completed_at, complexity, created_at, detail, foreman_note, guard_result, id, priority, reasoning, status, title, updated_at, worker_status, worker_summary, worktree.
    - Rows reference probe ARTIFACTS that do not exist: lane-scratch/qa-cf052-tip-12F1/p1.json, p2.json, qa-cf052-projects-fixture.jsonl. `ls lane-scratch` -> No such file or directory; `ls ~/lane-scratch` -> No such file or directory; find for *cf052* -> nothing.
    - Commands in prose use placeholders: `verify <path>`, `scan <fixture>`, `scan <projects.jsonl>`. Running `scan '<fixture>' --allow-remote` -> "FAIL lane-target: [Errno 2] No such file or directory: '<fixture>'".
    - CF-060's `verify ~/duckbrain` DOES reproduce (ok=True, exit 0, remotes are duckbrain's, not code-factory) — but it depends on an unstated pre-existing ~/duckbrain checkout, not a self-contained probe.
    - CF-061's `verify <path>` is a placeholder; I reconstructed the scenario manually (MERGE_HEAD + 3 unmerged paths + remote) and it reproduces ok=True exit 0 — but the row itself carries no runnable command.
    - CF-062's `scan <fixture>` is a placeholder; fixture file absent; reconstructed fixture reproduces (no flag -> exit 4; --allow-remote -> ok:true bad:0 exit 0).
    => The failure MODES are real and accurately described, but the rows do NOT each carry a re-runnable probe command. FAIL
(f) 5d7eb64 pushed to origin/main: origin/main == 5d7eb6435e42bbcbf28e998672ba4502d2dca412 == HEAD; `git rev-list --count origin/main..HEAD` = 0; merge-base --is-ancestor 5d7eb64 origin/main -> true. PASS

VERDICT: INCOMPLETE (sub-part e fails)

Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

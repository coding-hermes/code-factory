# Verdict: CF-076-QA2

**Task:** CF-076 is filed on the published tree and its probe reproduces the misbound verdicts
**Evaluated:** 2026-11-03T15:28:03.652337
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. At HEAD .coding-hermes/board/tasks.jsonl holds 62 rows and 62 unique ids, including CF-076 with status pending, priority P3 and a non-empty probe; commit 199e5dd adds exactly one line to tasks.jsonl and one to events.jsonl and changes no .sh, .py, .md or spec file. 2. Running the CF-076 probe verbatim from the repo root prints touches_named_path=0 for PERF-013/88e945ac, CF-055/c75a3783 and CF-058/9bd93bd8, plus layers_in_graded_tree=0, layers_in_fix=5 and row_status_PERF-013=pending. 3. git show 4720cdc:scripts/project-node.sh | grep -c -- --layers prints 0 while git show e21f2ce:scripts/project-node.sh prints 5. 4. bash tests/selftest.sh prints SELFTEST: PASS with 62/62 rows parse and scripts/boardctl validate prints RESULT: OK. 5. git rev-list --count origin/main..HEAD prints 0.: (1) `wc -l .coding-hermes/board/tasks.jsonl` = 62; python parse -> rows 62, unique ids 62; CF-076 row has status=pending, priority=P3, probe len 790 chars (keys include 'probe'). `git show --numstat 199e5dd` = `1 0 .coding-hermes/board/events.jsonl` + `1 0 .coding-hermes/board/tasks.jsonl`, 2 files changed / 2 insertions, no .sh/.py/.md/spec files. (2) Probe extracted verbatim from the row and run from /home/kara/code-factory (exit 0): 'PERF-013 run=88e945ac passed=true graded=4720cdcd touches_named_path=0', 'CF-055 run=c75a3783 passed=true graded=ddff6bc2 touches_named_path=0', 'CF-058 run=9bd93bd8 passed=true graded=d15205ea touches_named_path=0', 'layers_in_graded_tree=0', 'layers_in_fix=5', 'row_status_PERF-013=pending'. (3) `git show 4720cdc:scripts/project-node.sh | grep -c -- --layers` = 0; `git show e21f2ce:scripts/project-node.sh | grep -c -- --layers` = 5. (4) `bash tests/selftest.sh` exit 0, line 52 'SELFTEST: PASS', line 27 'PASS  62/62 rows parse'; `bash scripts/boardctl validate` exit 0, 'RESULT: OK (18 warning(s))'. (5) `git rev-list --count origin/main..HEAD` = 0.
All five sub-criteria verified by live command output: board is 62/62 with CF-076 pending/P3/probe, 199e5dd is a board-only 1+1 line commit, the probe reproduces all six expected values, 4720cdc has 0 --layers vs e21f2ce's 5, selftest and boardctl validate both pass, and HEAD is level with origin/main.

## Summary

Judge Result: CF-076-QA2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. At HEAD .coding-hermes/board/tasks.jsonl holds 62 rows and 62 unique ids, including CF-076 with status pending, priority P3 and a non-empty probe; commit 199e5dd adds exactly one line to tasks.jsonl and one to events.jsonl and changes no .sh, .py, .md or spec file. 2. Running the CF-076 probe verbatim from the repo root prints touches_named_path=0 for PERF-013/88e945ac, CF-055/c75a3783 and CF-058/9bd93bd8, plus layers_in_graded_tree=0, layers_in_fix=5 and row_status_PERF-013=pending. 3. git show 4720cdc:scripts/project-node.sh | grep -c -- --layers prints 0 while git show e21f2ce:scripts/project-node.sh prints 5. 4. bash tests/selftest.sh prints SELFTEST: PASS with 62/62 rows parse and scripts/boardctl validate prints RESULT: OK. 5. git rev-list --count origin/main..HEAD prints 0.: (1) `wc -l .coding-hermes/board/tasks.jsonl` = 62; python parse -> rows 62, unique ids 62; CF-076 row has status=pending, priority=P3, probe len 790 chars (keys include 'probe'). `git show --numstat 199e5dd` = `1 0 .coding-hermes/board/events.jsonl` + `1 0 .coding-hermes/board/tasks.jsonl`, 2 files changed / 2 insertions, no .sh/.py/.md/spec files. (2) Probe extracted verbatim from the row and run from /home/kara/code-factory (exit 0): 'PERF-013 run=88e945ac passed=true graded=4720cdcd touches_named_path=0', 'CF-055 run=c75a3783 passed=true graded=ddff6bc2 touches_named_path=0', 'CF-058 run=9bd93bd8 passed=true graded=d15205ea touches_named_path=0', 'layers_in_graded_tree=0', 'layers_in_fix=5', 'row_status_PERF-013=pending'. (3) `git show 4720cdc:scripts/project-node.sh | grep -c -- --layers` = 0; `git show e21f2ce:scripts/project-node.sh | grep -c -- --layers` = 5. (4) `bash tests/selftest.sh` exit 0, line 52 'SELFTEST: PASS', line 27 'PASS  62/62 rows parse'; `bash scripts/boardctl validate` exit 0, 'RESULT: OK (18 warning(s))'. (5) `git rev-list --count origin/main..HEAD` = 0.
All five sub-criteria verified by live command output: board is 62/62 with CF-076 pending/P3/probe, 199e5dd is a board-only 1+1 line commit, the probe reproduces all six expected values, 4720cdc has 0 --layers vs e21f2ce's 5, selftest and boardctl validate both pass, and HEAD is level with origin/main.

Overall: PASS ✓

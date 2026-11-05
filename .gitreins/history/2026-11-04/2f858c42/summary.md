# Verdict: CF-176-QA1

**Task:** QA filing: land CF-176/177/178 from the docs-QA tick and prove each row carries a reproducing probe
**Evaluated:** 2026-11-04T08:03:36.566126
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✗ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING VERIFICATION ONLY. The three rows filed by this commit are pending by definition; the repair of the defects they describe is FUTURE work tracked by those pending rows and is explicitly NOT expected at this commit. Do not evaluate, require, or withhold credit for the underlying fixes; grade only that the rows were filed correctly and that their probes reproduce today.

At the committed tip on origin/main:

1. `git show --stat --oneline HEAD` shows only the two board files changed (.coding-hermes/board/tasks.jsonl appended exactly 3 lines, .coding-hermes/board/events.jsonl appended), with 0 deletions.

2. `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-176" or .id=="CF-177" or .id=="CF-178") | [.id,.status,(.probe|length)] | @tsv'` prints exactly three lines, every status=pending, every probe length > 0, and each of the three ids appears exactly once in the whole file.

3. The CF-176 probe, extracted from the committed board (`jq -r 'select(.id=="CF-176").probe'`), run from the repo root, prints the contradiction it names: the line `55:  and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.` from docs/SCHEDULER-ADMISSION.md and the row `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)` from the live scheduler DB.

4. The CF-177 probe similarly prints `2`, `0`, `pin_census_done` (the same paragraph cites scheduler line ranges twice and pins no scheduler commit), and the CF-178 probe prints `0`, `code-factory-qa|0|auto-disable`, `enabled = true` (the repo's lane loader never reads disabled_at while the durable pin still says enabled).

5. Gate at the same tree: `bash tests/selftest.sh` prints SELFTEST: PASS with rc 0, and `bash scripts/boardctl validate` prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: All five sub-checks verified at HEAD 7ff8810. (1) `git show --stat --oneline HEAD` = 2 files changed, 6 insertions(+), 0 deletions; `--numstat` = `3 0 .coding-hermes/board/events.jsonl` and `3 0 .coding-hermes/board/tasks.jsonl`. Appended task rows are exactly CF-176/CF-177/CF-178 (all status=pending) and appended events are exactly 278/279/280. (2) jq prints exactly three lines: `CF-176 pending 240`, `CF-177 pending 152`, `CF-178 pending 254`; per-id occurrence count = 1 for each. (3) CF-176 probe run from repo root (/home/kara/code-factory) prints `55:  and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.` and `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`. (4) CF-177 probe prints `2`, `0`, `pin_census_done`; CF-178 probe prints `0`, `code-factory-qa|0|auto-disable`, `enabled = true`. (5) `bash tests/selftest.sh` -> `SELFTEST: PASS` with RC=0; `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))` with rc=0, and the 3 warnings are on legacy row CF-034 (free-form guard_result/ci_result + headerless board), byte-identical at HEAD~1, i.e. pre-existing as the criterion allows. Per the filing-only scope, the underlying CF-176/177/178 fixes were not required and were not graded.
All five criteria pass: the commit appends exactly 3 pending rows and 3 events with 0 deletions, each row's probe reproduces its named contradiction verbatim at the committed tip, and both gates (SELFTEST: PASS rc 0, boardctl RESULT: OK rc 0) are green.

## Summary

Judge Result: CF-176-QA1

Stage tier1: FAIL
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✗ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING VERIFICATION ONLY. The three rows filed by this commit are pending by definition; the repair of the defects they describe is FUTURE work tracked by those pending rows and is explicitly NOT expected at this commit. Do not evaluate, require, or withhold credit for the underlying fixes; grade only that the rows were filed correctly and that their probes reproduce today.

At the committed tip on origin/main:

1. `git show --stat --oneline HEAD` shows only the two board files changed (.coding-hermes/board/tasks.jsonl appended exactly 3 lines, .coding-hermes/board/events.jsonl appended), with 0 deletions.

2. `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-176" or .id=="CF-177" or .id=="CF-178") | [.id,.status,(.probe|length)] | @tsv'` prints exactly three lines, every status=pending, every probe length > 0, and each of the three ids appears exactly once in the whole file.

3. The CF-176 probe, extracted from the committed board (`jq -r 'select(.id=="CF-176").probe'`), run from the repo root, prints the contradiction it names: the line `55:  and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.` from docs/SCHEDULER-ADMISSION.md and the row `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)` from the live scheduler DB.

4. The CF-177 probe similarly prints `2`, `0`, `pin_census_done` (the same paragraph cites scheduler line ranges twice and pins no scheduler commit), and the CF-178 probe prints `0`, `code-factory-qa|0|auto-disable`, `enabled = true` (the repo's lane loader never reads disabled_at while the durable pin still says enabled).

5. Gate at the same tree: `bash tests/selftest.sh` prints SELFTEST: PASS with rc 0, and `bash scripts/boardctl validate` prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: All five sub-checks verified at HEAD 7ff8810. (1) `git show --stat --oneline HEAD` = 2 files changed, 6 insertions(+), 0 deletions; `--numstat` = `3 0 .coding-hermes/board/events.jsonl` and `3 0 .coding-hermes/board/tasks.jsonl`. Appended task rows are exactly CF-176/CF-177/CF-178 (all status=pending) and appended events are exactly 278/279/280. (2) jq prints exactly three lines: `CF-176 pending 240`, `CF-177 pending 152`, `CF-178 pending 254`; per-id occurrence count = 1 for each. (3) CF-176 probe run from repo root (/home/kara/code-factory) prints `55:  and 576×, every row enabled. Read the pair back after arming; the API will not check it for you.` and `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`. (4) CF-177 probe prints `2`, `0`, `pin_census_done`; CF-178 probe prints `0`, `code-factory-qa|0|auto-disable`, `enabled = true`. (5) `bash tests/selftest.sh` -> `SELFTEST: PASS` with RC=0; `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))` with rc=0, and the 3 warnings are on legacy row CF-034 (free-form guard_result/ci_result + headerless board), byte-identical at HEAD~1, i.e. pre-existing as the criterion allows. Per the filing-only scope, the underlying CF-176/177/178 fixes were not required and were not graded.
All five criteria pass: the commit appends exactly 3 pending rows and 3 events with 0 deletions, each row's probe reproduces its named contradiction verbatim at the committed tip, and both gates (SELFTEST: PASS rc 0, boardctl RESULT: OK rc 0) are green.

Overall: FAIL ✗

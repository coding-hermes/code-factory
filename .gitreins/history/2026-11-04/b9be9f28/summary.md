# Verdict: CF-PM-20261104-0840

**Task:** File CF-181: PRD milestone blocker list cites CF-110/CF-112 that have never existed as board rows
**Evaluated:** 2026-11-04T08:33:54.106025
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing scope only; do NOT grade a fix — the repair is future work tracked by the pending row.
At the committed tree, all of the following must hold:
1. Row CF-181 is present in .coding-hermes/board/tasks.jsonl, status=pending, priority=P3, and carries a non-empty probe, reasoning and acceptance_criteria; it appears exactly once in the whole file.: jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl returns {id:CF-181, status:pending, priority:P3, probe_len:553, reasoning_len:1847, ac_len:1729}. grep -c '"id":"CF-181"' = 1 and jq select count = 1, so it appears exactly once. Commit is filing-only: git show --stat HEAD touches only the two board files, no doc/script/test.
  ✓ 2. The row's own probe, extracted from the committed board with jq -r 'select(.id=="CF-181").probe' and run from the repo root, prints req_ids_in_prd greater than 0, cf110_row 0, cf112_row 0, cf110_events 0, cited_in_milestone greater than 0, namespace_legend 0, and exits 0.: Extracted with jq -r 'select(.id=="CF-181").probe' and executed from repo root: 'req_ids_in_prd: 12 / cf110_row: 0 / cf112_row: 0 / cf110_events: 0 / cited_in_milestone: 4 / namespace_legend: 0', RC=0. All thresholds met (12>0, 4>0, zeros as required).
  ✓ 3. The claim's history half reproduces: git log --all --oneline -S'"id":"CF-110"' -- .coding-hermes/board/tasks.jsonl prints nothing, so no ref has ever carried a CF-110 row.: git log --all --oneline -S'"id":"CF-110"' -- .coding-hermes/board/tasks.jsonl produced empty output (rc 0) — no ref has ever carried a CF-110 row.
  ✓ 4. The commit is board-only: git show --stat HEAD lists .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl only, with exactly one appended task row and exactly one appended task_created event, no duplicate ids in either file, and every line still parses under jq.: git show --stat HEAD: '.coding-hermes/board/events.jsonl | 1 +' and '.coding-hermes/board/tasks.jsonl | 1 +' (2 files, 2 insertions, nothing else). Added lines: 1 task row and 1 event {"id":289,"event_type":"task_created","task_id":"CF-181"}. jq -r '.id' | sort | uniq -d is empty for both tasks.jsonl and events.jsonl. jq -e . parses both files (tasks_ok, events_ok).
  ✓ 5. The gate of record is unchanged by the write: bash tests/selftest.sh prints SELFTEST: PASS with rc 0, and bash scripts/boardctl validate prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: bash tests/selftest.sh -> 'SELFTEST: PASS', RC=0 (an initial FAIL reading was an artifact of piping through tail in a sh subshell; direct run with output redirected gives RC=0 and SELFTEST: PASS). bash scripts/boardctl validate -> RC=0, 'RESULT: OK (3 warning(s))'; the 3 warnings are pre-existing free-form vocabulary on legacy row CF-034 (tasks.jsonl line 20) plus the headerless-board note, unrelated to CF-181.
All five criteria verified at commit 2be1c9a: CF-181 filed once as pending/P3 with non-empty probe/reasoning/acceptance_criteria, its probe reproduces the claimed measurements with rc 0, the CF-110 history search is empty, the commit is board-only with one row and one task_created event and no duplicate ids, and both selftest and boardctl validate pass.

## Summary

Judge Result: CF-PM-20261104-0840

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing scope only; do NOT grade a fix — the repair is future work tracked by the pending row.
At the committed tree, all of the following must hold:
1. Row CF-181 is present in .coding-hermes/board/tasks.jsonl, status=pending, priority=P3, and carries a non-empty probe, reasoning and acceptance_criteria; it appears exactly once in the whole file.: jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl returns {id:CF-181, status:pending, priority:P3, probe_len:553, reasoning_len:1847, ac_len:1729}. grep -c '"id":"CF-181"' = 1 and jq select count = 1, so it appears exactly once. Commit is filing-only: git show --stat HEAD touches only the two board files, no doc/script/test.
  ✓ 2. The row's own probe, extracted from the committed board with jq -r 'select(.id=="CF-181").probe' and run from the repo root, prints req_ids_in_prd greater than 0, cf110_row 0, cf112_row 0, cf110_events 0, cited_in_milestone greater than 0, namespace_legend 0, and exits 0.: Extracted with jq -r 'select(.id=="CF-181").probe' and executed from repo root: 'req_ids_in_prd: 12 / cf110_row: 0 / cf112_row: 0 / cf110_events: 0 / cited_in_milestone: 4 / namespace_legend: 0', RC=0. All thresholds met (12>0, 4>0, zeros as required).
  ✓ 3. The claim's history half reproduces: git log --all --oneline -S'"id":"CF-110"' -- .coding-hermes/board/tasks.jsonl prints nothing, so no ref has ever carried a CF-110 row.: git log --all --oneline -S'"id":"CF-110"' -- .coding-hermes/board/tasks.jsonl produced empty output (rc 0) — no ref has ever carried a CF-110 row.
  ✓ 4. The commit is board-only: git show --stat HEAD lists .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl only, with exactly one appended task row and exactly one appended task_created event, no duplicate ids in either file, and every line still parses under jq.: git show --stat HEAD: '.coding-hermes/board/events.jsonl | 1 +' and '.coding-hermes/board/tasks.jsonl | 1 +' (2 files, 2 insertions, nothing else). Added lines: 1 task row and 1 event {"id":289,"event_type":"task_created","task_id":"CF-181"}. jq -r '.id' | sort | uniq -d is empty for both tasks.jsonl and events.jsonl. jq -e . parses both files (tasks_ok, events_ok).
  ✓ 5. The gate of record is unchanged by the write: bash tests/selftest.sh prints SELFTEST: PASS with rc 0, and bash scripts/boardctl validate prints RESULT: OK (free-form-vocabulary warnings on legacy rows are pre-existing).: bash tests/selftest.sh -> 'SELFTEST: PASS', RC=0 (an initial FAIL reading was an artifact of piping through tail in a sh subshell; direct run with output redirected gives RC=0 and SELFTEST: PASS). bash scripts/boardctl validate -> RC=0, 'RESULT: OK (3 warning(s))'; the 3 warnings are pre-existing free-form vocabulary on legacy row CF-034 (tasks.jsonl line 20) plus the headerless-board note, unrelated to CF-181.
All five criteria verified at commit 2be1c9a: CF-181 filed once as pending/P3 with non-empty probe/reasoning/acceptance_criteria, its probe reproduces the claimed measurements with rc 0, the CF-110 history search is empty, the commit is board-only with one row and one task_created event and no duplicate ids, and both selftest and boardctl validate pass.

Overall: PASS ✓

# Verdict: CF-SYNC-2026110402-QA1

**Task:** Re-judge the sync pass at 9f01441: census strings now present in the audit doc
**Evaluated:** 2026-11-04T02:51:57.850424
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✓ 1. At the graded commit, `bash tests/selftest.sh` prints a final line starting `SELFTEST: PASS` and exits 0.: Ran `bash tests/selftest.sh` at HEAD 9f01441: final line `SELFTEST: PASS`, EXIT=0 (all 30 sections PASS, e.g. `PASS 126/126 rows parse`).
  ✓ 2. At the graded commit, `bash scripts/boardctl validate` prints a final line matching `RESULT: OK` and exits 0.: Ran `bash scripts/boardctl validate`: final line `RESULT: OK (55 warning(s))`, EXIT=0 (rows: 126 tasks, 189 events).
  ✓ 3. Both `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl` parse with `jq -c . <file>` (exit 0), and `jq -r .id <file> | sort | uniq -d` prints nothing for each file.: tasks.jsonl: parse_exit=0, dup output empty; events.jsonl: parse_exit=0, dup output empty (189 lines, ids 1..189 unique).
  ✓ 4. `docs/audits/code-factory-sync-2026-11-04-0241.md` exists in the graded tree, contains the string `2c48149`, and contains the census `125 task rows`, `185 before this tick's own audit event` and `38 complete, 82 pending, 5 in_progress`.: File exists (9606 bytes). grep -c `2c48149` = 3; grep -cF `125 task rows` = 1; `185 before this tick's own audit event` = 2; `38 complete, 82 pending, 5 in_progress` = 1.
  ✗ 5. `docs/ACCEPTANCE-PLAN.md` contains `Delta measured 2026-11-04 03:02 at tip` and `CF-053`, and `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` reports zero deleted lines while reporting more than zero inserted lines.: String checks pass (grep -cF `Delta measured 2026-11-04 03:02 at tip` = 1, `CF-053` = 1), but `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` prints NOTHING (exit 0) — the graded commit 9f01441 touches only docs/audits/code-factory-sync-2026-11-04-0241.md (`3 0`). Inserted lines = 0, not >0; the ACCEPTANCE-PLAN edit lives in an earlier commit (c9848d7), so the 'more than zero inserted lines' clause is unmet at HEAD.
  ✗ 6. `.coding-hermes/board/events.jsonl` ends with an `audit` event whose `actor` is `code-factory-sync`, whose `id` appears exactly once in the file, and whose `detail`, parsed with `jq -r '.detail | fromjson'`, carries `lane` equal to `code-factory-duckbrain-sync` and a non-empty `tip_measured`.: Last line of events.jsonl is `{"id":189,"event_type":"audit","actor":"docs"}` with detail lane=`docs` and no `tip_measured` (null). The matching event (actor `code-factory-sync`, lane `code-factory-duckbrain-sync`, tip_measured `2c48149a...`) is id 186, which is 3 lines from the end — followed by id 187 (task_created/docs-qa) and id 188 (task_completed/foreman). The file does not END with the required audit event.
  ✓ 7. `git show --numstat --format= HEAD` reports zero deleted lines across every changed path of the graded commit.: `git show --numstat --format= HEAD` -> single line `3	0	docs/audits/code-factory-sync-2026-11-04-0241.md`; awk sum: deleted=0, added=3. Zero deletions across all changed paths.
Selftest, boardctl validate, JSONL integrity, audit-doc census strings and zero-deletion checks pass, but the graded commit does not modify docs/ACCEPTANCE-PLAN.md (0 inserted lines) and events.jsonl ends with a `docs`-actor audit event rather than the required `code-factory-sync` / `code-factory-duckbrain-sync` event with tip_measured.

## Summary

Judge Result: CF-SYNC-2026110402-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✓ 1. At the graded commit, `bash tests/selftest.sh` prints a final line starting `SELFTEST: PASS` and exits 0.: Ran `bash tests/selftest.sh` at HEAD 9f01441: final line `SELFTEST: PASS`, EXIT=0 (all 30 sections PASS, e.g. `PASS 126/126 rows parse`).
  ✓ 2. At the graded commit, `bash scripts/boardctl validate` prints a final line matching `RESULT: OK` and exits 0.: Ran `bash scripts/boardctl validate`: final line `RESULT: OK (55 warning(s))`, EXIT=0 (rows: 126 tasks, 189 events).
  ✓ 3. Both `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl` parse with `jq -c . <file>` (exit 0), and `jq -r .id <file> | sort | uniq -d` prints nothing for each file.: tasks.jsonl: parse_exit=0, dup output empty; events.jsonl: parse_exit=0, dup output empty (189 lines, ids 1..189 unique).
  ✓ 4. `docs/audits/code-factory-sync-2026-11-04-0241.md` exists in the graded tree, contains the string `2c48149`, and contains the census `125 task rows`, `185 before this tick's own audit event` and `38 complete, 82 pending, 5 in_progress`.: File exists (9606 bytes). grep -c `2c48149` = 3; grep -cF `125 task rows` = 1; `185 before this tick's own audit event` = 2; `38 complete, 82 pending, 5 in_progress` = 1.
  ✗ 5. `docs/ACCEPTANCE-PLAN.md` contains `Delta measured 2026-11-04 03:02 at tip` and `CF-053`, and `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` reports zero deleted lines while reporting more than zero inserted lines.: String checks pass (grep -cF `Delta measured 2026-11-04 03:02 at tip` = 1, `CF-053` = 1), but `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` prints NOTHING (exit 0) — the graded commit 9f01441 touches only docs/audits/code-factory-sync-2026-11-04-0241.md (`3 0`). Inserted lines = 0, not >0; the ACCEPTANCE-PLAN edit lives in an earlier commit (c9848d7), so the 'more than zero inserted lines' clause is unmet at HEAD.
  ✗ 6. `.coding-hermes/board/events.jsonl` ends with an `audit` event whose `actor` is `code-factory-sync`, whose `id` appears exactly once in the file, and whose `detail`, parsed with `jq -r '.detail | fromjson'`, carries `lane` equal to `code-factory-duckbrain-sync` and a non-empty `tip_measured`.: Last line of events.jsonl is `{"id":189,"event_type":"audit","actor":"docs"}` with detail lane=`docs` and no `tip_measured` (null). The matching event (actor `code-factory-sync`, lane `code-factory-duckbrain-sync`, tip_measured `2c48149a...`) is id 186, which is 3 lines from the end — followed by id 187 (task_created/docs-qa) and id 188 (task_completed/foreman). The file does not END with the required audit event.
  ✓ 7. `git show --numstat --format= HEAD` reports zero deleted lines across every changed path of the graded commit.: `git show --numstat --format= HEAD` -> single line `3	0	docs/audits/code-factory-sync-2026-11-04-0241.md`; awk sum: deleted=0, added=3. Zero deletions across all changed paths.
Selftest, boardctl validate, JSONL integrity, audit-doc census strings and zero-deletion checks pass, but the graded commit does not modify docs/ACCEPTANCE-PLAN.md (0 inserted lines) and events.jsonl ends with a `docs`-actor audit event rather than the required `code-factory-sync` / `code-factory-duckbrain-sync` event with tip_measured.

Overall: FAIL ✗

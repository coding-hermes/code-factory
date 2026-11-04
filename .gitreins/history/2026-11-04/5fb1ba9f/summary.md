# Verdict: CF-195-QA1

**Task:** QA re-verification of CF-195 (doc line-pin rot) at published tip aa1277e
**Evaluated:** 2026-11-04T10:52:05.936589
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Criterion 1: the commit contains an appended `task_verified` event for task CF-195 whose detail is machine-parseable and names the published tip it measured plus the literal value `stale_pins=5`.: HEAD d93d98b appends events.jsonl line 355: {"id":354,"event_type":"task_verified","task_id":"CF-195","actor":"qa","detail":"{...}"}. Python json.loads parses both the outer line and the nested detail string; detail keys = [tick, execution, tip_measured, probe_output, probe_rc, liveness, rows_reverified, mutation_arms, rows_reopened, rows_filed, superseded, scoped_out, event_id_collision]. tip_measured = "aa1277e83589f802e4f4f68d4dfb846d53a87951" (the published tip aa1277e) and probe_output = "stale_pins=5" with probe_rc=0; the literal substring 'stale_pins=5' is present in the raw detail.
  ✓ Criterion 2: tests/selftest.sh prints `SELFTEST: PASS` in the same tree and `bash scripts/boardctl validate` prints `RESULT: OK`.: Ran in the graded tree (HEAD d93d98b, clean working tree): `bash tests/selftest.sh` -> exit_code 0, 195 '  PASS' rows, line 291 prints 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> exit_code 0, line 8 prints 'RESULT: OK (4 warning(s))' (warnings are pre-existing legacy items: CF-034 free-form guard_result/ci_result, duplicate event id 336, headerless board).
  ✓ Criterion 3: the event append is insert-only for .coding-hermes/board/events.jsonl (one added line per the commit diff, no modified or deleted lines) and the board gains no duplicate task ids.: `git diff HEAD~1 HEAD --numstat` = '1\t0\t.coding-hermes/board/events.jsonl' (1 insertion, 0 deletions); raw diff contains exactly 1 '+' line and 0 '-' lines; tasks.jsonl is untouched. events.jsonl 354 -> 355 lines, event id 354 absent at HEAD~1. tasks.jsonl: 176 rows at both HEAD~1 and HEAD, added ids = set(), removed ids = set(), duplicate task ids at HEAD = {} (none). The only duplicate id on the board is a pre-existing benign duplicate EVENT id 336 (lines 336/337), which boardctl explicitly labels 'benign legacy duplicates' and which this commit did not introduce.
  ✓ Criterion 4: the committed event does not claim any row was closed, reopened or re-filed: CF-195 must still read `pending` at the graded commit.: Event 354 detail: rows_reopened=[] , rows_filed=[] , liveness="finding still reproduces at the measured tip; row left pending", superseded="draft CF-193 dropped ... no duplicate row minted" — no close/reopen/re-file claim. `git show HEAD:.coding-hermes/board/tasks.jsonl` for CF-195: status=pending, closed_at=None, updated_at=2026-11-04T10:09:59Z (unchanged by this commit, since tasks.jsonl has no diff). The only CF-195 events are 336 task_created (status pending) and 354 task_verified.
All four criteria pass: event 354 is a machine-parseable task_verified for CF-195 naming tip aa1277e with stale_pins=5, selftest prints SELFTEST: PASS and boardctl validate prints RESULT: OK, the append is strictly one added line with no duplicate task ids, and CF-195 remains pending.

## Summary

Judge Result: CF-195-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Criterion 1: the commit contains an appended `task_verified` event for task CF-195 whose detail is machine-parseable and names the published tip it measured plus the literal value `stale_pins=5`.: HEAD d93d98b appends events.jsonl line 355: {"id":354,"event_type":"task_verified","task_id":"CF-195","actor":"qa","detail":"{...}"}. Python json.loads parses both the outer line and the nested detail string; detail keys = [tick, execution, tip_measured, probe_output, probe_rc, liveness, rows_reverified, mutation_arms, rows_reopened, rows_filed, superseded, scoped_out, event_id_collision]. tip_measured = "aa1277e83589f802e4f4f68d4dfb846d53a87951" (the published tip aa1277e) and probe_output = "stale_pins=5" with probe_rc=0; the literal substring 'stale_pins=5' is present in the raw detail.
  ✓ Criterion 2: tests/selftest.sh prints `SELFTEST: PASS` in the same tree and `bash scripts/boardctl validate` prints `RESULT: OK`.: Ran in the graded tree (HEAD d93d98b, clean working tree): `bash tests/selftest.sh` -> exit_code 0, 195 '  PASS' rows, line 291 prints 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> exit_code 0, line 8 prints 'RESULT: OK (4 warning(s))' (warnings are pre-existing legacy items: CF-034 free-form guard_result/ci_result, duplicate event id 336, headerless board).
  ✓ Criterion 3: the event append is insert-only for .coding-hermes/board/events.jsonl (one added line per the commit diff, no modified or deleted lines) and the board gains no duplicate task ids.: `git diff HEAD~1 HEAD --numstat` = '1\t0\t.coding-hermes/board/events.jsonl' (1 insertion, 0 deletions); raw diff contains exactly 1 '+' line and 0 '-' lines; tasks.jsonl is untouched. events.jsonl 354 -> 355 lines, event id 354 absent at HEAD~1. tasks.jsonl: 176 rows at both HEAD~1 and HEAD, added ids = set(), removed ids = set(), duplicate task ids at HEAD = {} (none). The only duplicate id on the board is a pre-existing benign duplicate EVENT id 336 (lines 336/337), which boardctl explicitly labels 'benign legacy duplicates' and which this commit did not introduce.
  ✓ Criterion 4: the committed event does not claim any row was closed, reopened or re-filed: CF-195 must still read `pending` at the graded commit.: Event 354 detail: rows_reopened=[] , rows_filed=[] , liveness="finding still reproduces at the measured tip; row left pending", superseded="draft CF-193 dropped ... no duplicate row minted" — no close/reopen/re-file claim. `git show HEAD:.coding-hermes/board/tasks.jsonl` for CF-195: status=pending, closed_at=None, updated_at=2026-11-04T10:09:59Z (unchanged by this commit, since tasks.jsonl has no diff). The only CF-195 events are 336 task_created (status pending) and 354 task_verified.
All four criteria pass: event 354 is a machine-parseable task_verified for CF-195 naming tip aa1277e with stale_pins=5, selftest prints SELFTEST: PASS and boardctl validate prints RESULT: OK, the append is strictly one added line with no duplicate task ids, and CF-195 remains pending.

Overall: PASS ✓

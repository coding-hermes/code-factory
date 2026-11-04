# Verdict: CF-SYNC-2026110402

**Task:** Sync pass at 2c48149: board census, complete-row evidence bindings, docs snapshot delta
**Evaluated:** 2026-11-04T02:50:11.927148
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✓ 1. At the graded commit, `bash tests/selftest.sh` prints a final line starting `SELFTEST: PASS` and exits 0.: Ran `bash tests/selftest.sh` at HEAD c9848d7: EXIT=0, final stdout line is exactly `SELFTEST: PASS` (tail -3 shows `  PASS  unqualified Status rows refused (...)` then blank then `SELFTEST: PASS`).
  ✓ 2. At the graded commit, `bash scripts/boardctl validate` prints a final line matching `RESULT: OK` and exits 0.: Ran `bash scripts/boardctl validate` at HEAD c9848d7: EXIT=0, final stdout line `RESULT: OK (54 warning(s))` — matches `RESULT: OK`.
  ✓ 3. Both `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl` parse with `jq -c . <file>` (exit 0), and `jq -r .id <file> | sort | uniq -d` prints nothing for each file.: tasks.jsonl: jq_exit=0, `uniq -d` output empty (125 lines). events.jsonl: jq_exit=0, `uniq -d` output empty (186 lines). No duplicate ids in either file.
  ✗ 4. `docs/audits/code-factory-sync-2026-11-04-0241.md` exists in the graded tree, contains the string `2c48149`, and contains the census `125 task rows`, `185 before this tick's own audit event` and `38 complete, 82 pending, 5 in_progress`.: File exists (9386 bytes) and contains `2c48149` (3x) and `185 before this tick's own audit event` (line 46). But two required literal strings are absent: `grep -F '125 task rows'` => NOT FOUND, and `grep -F '38 complete, 82 pending, 5 in_progress'` => NOT FOUND. The doc instead writes the census as `38 `complete`, 82 `pending`, 5 `in_progress`` with backticks (line 45) and `125 rows / 185 events / 38-82-5` (line 105), so the exact census strings the criterion demands never appear.
  ✓ 5. `docs/ACCEPTANCE-PLAN.md` contains `Delta measured 2026-11-04 03:02 at tip` and `CF-053`, and `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` reports zero deleted lines while reporting more than zero inserted lines.: grep -cF 'Delta measured 2026-11-04 03:02 at tip' => 1; grep -cF 'CF-053' => 1. `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` => `8	0	docs/ACCEPTANCE-PLAN.md` (8 inserted, 0 deleted).
  ✓ 6. `.coding-hermes/board/events.jsonl` ends with an `audit` event whose `actor` is `code-factory-sync`, whose `id` appears exactly once in the file, and whose `detail`, parsed with `jq -r '.detail | fromjson'`, carries `lane` equal to `code-factory-duckbrain-sync` and a non-empty `tip_measured`.: Last line: event_type=audit, actor=code-factory-sync, id=186 (field is `event_type`, not `type`; 38 audit events total). `jq -r 'select(.id==186)|.id' | wc -l` => 1 (appears exactly once). `.detail|fromjson` => lane=`code-factory-duckbrain-sync`, tip_measured=`2c48149a7778730cc2593e16755a7138df306144` (length 40, non-empty).
  ✓ 7. `git show --numstat --format= HEAD` reports zero deleted lines across every changed path of the graded commit.: `git show --numstat --format= HEAD` => `.coding-hermes/board/events.jsonl 1/0`, `docs/ACCEPTANCE-PLAN.md 8/0`, `docs/audits/code-factory-sync-2026-11-04-0241.md 135/0`. Sum of deleted column = 0 across all three changed paths.
Gates, board integrity, ACCEPTANCE-PLAN delta, audit event and zero-deletion checks all pass, but criterion 4 fails because the audit doc never contains the exact census strings `125 task rows` or `38 complete, 82 pending, 5 in_progress`.

## Summary

Judge Result: CF-SYNC-2026110402

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✓ 1. At the graded commit, `bash tests/selftest.sh` prints a final line starting `SELFTEST: PASS` and exits 0.: Ran `bash tests/selftest.sh` at HEAD c9848d7: EXIT=0, final stdout line is exactly `SELFTEST: PASS` (tail -3 shows `  PASS  unqualified Status rows refused (...)` then blank then `SELFTEST: PASS`).
  ✓ 2. At the graded commit, `bash scripts/boardctl validate` prints a final line matching `RESULT: OK` and exits 0.: Ran `bash scripts/boardctl validate` at HEAD c9848d7: EXIT=0, final stdout line `RESULT: OK (54 warning(s))` — matches `RESULT: OK`.
  ✓ 3. Both `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl` parse with `jq -c . <file>` (exit 0), and `jq -r .id <file> | sort | uniq -d` prints nothing for each file.: tasks.jsonl: jq_exit=0, `uniq -d` output empty (125 lines). events.jsonl: jq_exit=0, `uniq -d` output empty (186 lines). No duplicate ids in either file.
  ✗ 4. `docs/audits/code-factory-sync-2026-11-04-0241.md` exists in the graded tree, contains the string `2c48149`, and contains the census `125 task rows`, `185 before this tick's own audit event` and `38 complete, 82 pending, 5 in_progress`.: File exists (9386 bytes) and contains `2c48149` (3x) and `185 before this tick's own audit event` (line 46). But two required literal strings are absent: `grep -F '125 task rows'` => NOT FOUND, and `grep -F '38 complete, 82 pending, 5 in_progress'` => NOT FOUND. The doc instead writes the census as `38 `complete`, 82 `pending`, 5 `in_progress`` with backticks (line 45) and `125 rows / 185 events / 38-82-5` (line 105), so the exact census strings the criterion demands never appear.
  ✓ 5. `docs/ACCEPTANCE-PLAN.md` contains `Delta measured 2026-11-04 03:02 at tip` and `CF-053`, and `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` reports zero deleted lines while reporting more than zero inserted lines.: grep -cF 'Delta measured 2026-11-04 03:02 at tip' => 1; grep -cF 'CF-053' => 1. `git show --numstat --format= HEAD -- docs/ACCEPTANCE-PLAN.md` => `8	0	docs/ACCEPTANCE-PLAN.md` (8 inserted, 0 deleted).
  ✓ 6. `.coding-hermes/board/events.jsonl` ends with an `audit` event whose `actor` is `code-factory-sync`, whose `id` appears exactly once in the file, and whose `detail`, parsed with `jq -r '.detail | fromjson'`, carries `lane` equal to `code-factory-duckbrain-sync` and a non-empty `tip_measured`.: Last line: event_type=audit, actor=code-factory-sync, id=186 (field is `event_type`, not `type`; 38 audit events total). `jq -r 'select(.id==186)|.id' | wc -l` => 1 (appears exactly once). `.detail|fromjson` => lane=`code-factory-duckbrain-sync`, tip_measured=`2c48149a7778730cc2593e16755a7138df306144` (length 40, non-empty).
  ✓ 7. `git show --numstat --format= HEAD` reports zero deleted lines across every changed path of the graded commit.: `git show --numstat --format= HEAD` => `.coding-hermes/board/events.jsonl 1/0`, `docs/ACCEPTANCE-PLAN.md 8/0`, `docs/audits/code-factory-sync-2026-11-04-0241.md 135/0`. Sum of deleted column = 0 across all three changed paths.
Gates, board integrity, ACCEPTANCE-PLAN delta, audit event and zero-deletion checks all pass, but criterion 4 fails because the audit doc never contains the exact census strings `125 task rows` or `38 complete, 82 pending, 5 in_progress`.

Overall: FAIL ✗

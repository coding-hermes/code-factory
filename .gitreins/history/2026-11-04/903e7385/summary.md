# Verdict: CF-147-RV1

**Task:** Review filing: the CF-123 census-port property is protected by no gate arm (row CF-147)
**Evaluated:** 2026-11-04T02:42:29.554472
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ FILING-ONLY task. The repair is future work tracked by the pending board row and is NOT expected at this commit; do not grade the fix and do not implement it.

This commit files one review-lane board row (CF-147) on the public code-factory board. Verify the filing:

1. The committed board carries the row exactly once: `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-147")'` prints one object with status "pending", a non-empty title, non-empty reasoning, non-empty acceptance_criteria, and a non-empty probe field.
2. The probe is re-runnable by a stranger. Extracted from the committed board with `jq -r 'select(.id=="CF-147").probe'` and executed with `bash <file>` from the repo root, it prints "mutated-single rc=0" plus two concurrent lines reading rc=1. That output is the defect being filed (a single-token revert of the CF-123 census-port call site keeps the single-run gate green while concurrent runs red each other).
3. `bash scripts/boardctl validate` prints RESULT: OK.
4. `bash tests/selftest.sh` prints SELFTEST: PASS and exits 0.
5. The commit is board-only and insert-only: git show --stat names only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl, the board row count grew by exactly one, and there are no duplicate ids.: Sub-checks 1-4 PASS, sub-check 5 FAILS. (1) `git show bdadeb9:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-147")'` returns exactly 1 object: status="pending", title_len=176, reasoning_len=3646, acceptance_criteria len=2454, probe len=444 — all non-empty. (2) Probe extracted with `jq -r 'select(.id=="CF-147").probe'` and run via `bash /tmp/cf147_probe.sh` from repo root printed exactly: `mutated-single rc=0`, `conc-a rc=1`, `conc-b rc=1` — reproduces the filed defect. (3) `bash scripts/boardctl validate` -> `RESULT: OK (54 warning(s))`, exit 0. (4) `bash tests/selftest.sh` -> `SELFTEST: PASS`, EXIT=0 (89 PASS lines). (5) FAIL: `git show --name-only bdadeb9` does name only the two board files, and `uniq -d` on ids is empty (no duplicates), BUT the commit is neither insert-only nor +1: `git show --numstat bdadeb9` gives tasks.jsonl `4 0`... actually `4 1` (4 added, 1 deleted); diffing ids parent->commit yields three new rows `CF-147`, `CF-148`, `CF-149`; row count went 120 -> 123 (+3, not +1); and one pre-existing row was modified in place: CF-053 status `complete` -> `in_progress`. The commit message itself discloses this ('the QA lane appended its own rows CF-148 and CF-149 ... and flipped CF-053 complete -> in_progress ... those three lines and their events ride in this commit'), but the criterion requires the row count to grow by exactly one and the commit to be insert-only, which it is not.
The CF-147 row is well-formed, its probe reproduces the defect exactly, and boardctl/selftest are green, but the commit is not insert-only and grew the board by three rows (CF-147/148/149) plus an in-place CF-053 status flip, failing criterion 5.

## Summary

Judge Result: CF-147-RV1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ FILING-ONLY task. The repair is future work tracked by the pending board row and is NOT expected at this commit; do not grade the fix and do not implement it.

This commit files one review-lane board row (CF-147) on the public code-factory board. Verify the filing:

1. The committed board carries the row exactly once: `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-147")'` prints one object with status "pending", a non-empty title, non-empty reasoning, non-empty acceptance_criteria, and a non-empty probe field.
2. The probe is re-runnable by a stranger. Extracted from the committed board with `jq -r 'select(.id=="CF-147").probe'` and executed with `bash <file>` from the repo root, it prints "mutated-single rc=0" plus two concurrent lines reading rc=1. That output is the defect being filed (a single-token revert of the CF-123 census-port call site keeps the single-run gate green while concurrent runs red each other).
3. `bash scripts/boardctl validate` prints RESULT: OK.
4. `bash tests/selftest.sh` prints SELFTEST: PASS and exits 0.
5. The commit is board-only and insert-only: git show --stat names only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl, the board row count grew by exactly one, and there are no duplicate ids.: Sub-checks 1-4 PASS, sub-check 5 FAILS. (1) `git show bdadeb9:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-147")'` returns exactly 1 object: status="pending", title_len=176, reasoning_len=3646, acceptance_criteria len=2454, probe len=444 — all non-empty. (2) Probe extracted with `jq -r 'select(.id=="CF-147").probe'` and run via `bash /tmp/cf147_probe.sh` from repo root printed exactly: `mutated-single rc=0`, `conc-a rc=1`, `conc-b rc=1` — reproduces the filed defect. (3) `bash scripts/boardctl validate` -> `RESULT: OK (54 warning(s))`, exit 0. (4) `bash tests/selftest.sh` -> `SELFTEST: PASS`, EXIT=0 (89 PASS lines). (5) FAIL: `git show --name-only bdadeb9` does name only the two board files, and `uniq -d` on ids is empty (no duplicates), BUT the commit is neither insert-only nor +1: `git show --numstat bdadeb9` gives tasks.jsonl `4 0`... actually `4 1` (4 added, 1 deleted); diffing ids parent->commit yields three new rows `CF-147`, `CF-148`, `CF-149`; row count went 120 -> 123 (+3, not +1); and one pre-existing row was modified in place: CF-053 status `complete` -> `in_progress`. The commit message itself discloses this ('the QA lane appended its own rows CF-148 and CF-149 ... and flipped CF-053 complete -> in_progress ... those three lines and their events ride in this commit'), but the criterion requires the row count to grow by exactly one and the commit to be insert-only, which it is not.
The CF-147 row is well-formed, its probe reproduces the defect exactly, and boardctl/selftest are green, but the commit is not insert-only and grew the board by three rows (CF-147/148/149) plus an in-place CF-053 status flip, failing criterion 5.

Overall: FAIL ✗

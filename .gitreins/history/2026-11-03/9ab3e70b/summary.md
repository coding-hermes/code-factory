# Verdict: CF-081-REV1

**Task:** File CF-081 — docs/BOARD.md 'Current measured state' is hand-typed: 61 rows/66 events/17 warnings claimed, 66/72/19 measured at 7cf19b0
**Evaluated:** 2026-11-03T15:51:28.232173
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING-ONLY criterion. Judge the FILING, not the repair: CF-081 is a pending row and implementing the guard is future work — do NOT fail this task because docs/BOARD.md is still stale or because no gate exists yet.

On the graded commit:

1. The COMMITTED board (.coding-hermes/board/tasks.jsonl at that commit) parses and contains exactly one row with id CF-081: status pending, a non-empty acceptance_criteria, and a non-empty probe field holding the row's one paste-runnable command. `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -s '[.[]|select(.id=="CF-081")]|length'` prints 1.

2. Run that probe verbatim from the repository root. It must print the doc's claimed pair DIFFERENT from the measured pair, followed by the literal line "DRIFT: docs/BOARD.md measured-state block is stale". Measured by this tick at 7cf19b0: doc=61 66, measured=66 72, warnings=19.

3. The row's acceptance_criteria require BOTH: (a) a committed check that derives task-row and event counts from the board and exits nonzero when docs/BOARD.md's "Current measured state" block disagrees, with a red arm proving a deliberately wrong count fails; and (b) the existing gate stays green after that change — bash tests/selftest.sh prints SELFTEST: PASS with no FAIL rows and bash scripts/boardctl validate prints RESULT: OK.

4. The commit is board-only and its message discloses the CF-031 guard bypass (core.hooksPath=/dev/null) that the board-only lint skip requires, naming the DEGRADED PASS and the skipped lint stage.: (1) `git show c09b62c:.coding-hermes/board/tasks.jsonl | jq -s '[.[]|select(.id=="CF-081")]|length'` -> 1; row has status="pending", non-empty acceptance_criteria (6 numbered items), non-empty single-command probe. (2) Probe run verbatim from repo root at 7cf19b0 prints `doc=61 66 measured=66 72 warnings=19` then `DRIFT: docs/BOARD.md measured-state block is stale` — exactly the criterion's stated values (doc pair 61 66 differs from measured 66 72); at graded commit c09b62c it prints `doc=61 66 measured=67 73 warnings=20` + the same literal DRIFT line. (3) acceptance_criteria items 2-3 require the committed count-deriving check with a red arm proving a deliberately wrong count fails, and item 5 requires `bash tests/selftest.sh` -> SELFTEST: PASS with no FAIL rows plus `bash scripts/boardctl validate` -> RESULT: OK; verified live: selftest prints `SELFTEST: PASS`, 34 PASS rows, 0 FAIL rows (exit 0), boardctl prints `RESULT: OK (20 warning(s))` (exit 0). (4) `git show --name-only c09b62c` lists only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (board-only); message lines 38-41 state: "Guard: the pre-commit hook refuses board-only diffs (Tier 1 DEGRADED PASS, secrets clean, tests (full) PASS, lint skipped \"no staged files\" — CF-031, still pending). Disclosed bypass used: git -c core.hooksPath=/dev/null commit." — names DEGRADED PASS, the skipped lint stage, CF-031 and the bypass command.
CF-081 is correctly filed as a pending board row whose probe reproduces the documented drift (doc=61 66 vs measured=66 72, warnings=19 at 7cf19b0) with the literal DRIFT line, its acceptance criteria demand the count-deriving check with a red arm plus a green selftest/boardctl gate, and the board-only commit discloses the CF-031 core.hooksPath=/dev/null bypass and DEGRADED PASS with lint skipped.

## Summary

Judge Result: CF-081-REV1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING-ONLY criterion. Judge the FILING, not the repair: CF-081 is a pending row and implementing the guard is future work — do NOT fail this task because docs/BOARD.md is still stale or because no gate exists yet.

On the graded commit:

1. The COMMITTED board (.coding-hermes/board/tasks.jsonl at that commit) parses and contains exactly one row with id CF-081: status pending, a non-empty acceptance_criteria, and a non-empty probe field holding the row's one paste-runnable command. `git show <commit>:.coding-hermes/board/tasks.jsonl | jq -s '[.[]|select(.id=="CF-081")]|length'` prints 1.

2. Run that probe verbatim from the repository root. It must print the doc's claimed pair DIFFERENT from the measured pair, followed by the literal line "DRIFT: docs/BOARD.md measured-state block is stale". Measured by this tick at 7cf19b0: doc=61 66, measured=66 72, warnings=19.

3. The row's acceptance_criteria require BOTH: (a) a committed check that derives task-row and event counts from the board and exits nonzero when docs/BOARD.md's "Current measured state" block disagrees, with a red arm proving a deliberately wrong count fails; and (b) the existing gate stays green after that change — bash tests/selftest.sh prints SELFTEST: PASS with no FAIL rows and bash scripts/boardctl validate prints RESULT: OK.

4. The commit is board-only and its message discloses the CF-031 guard bypass (core.hooksPath=/dev/null) that the board-only lint skip requires, naming the DEGRADED PASS and the skipped lint stage.: (1) `git show c09b62c:.coding-hermes/board/tasks.jsonl | jq -s '[.[]|select(.id=="CF-081")]|length'` -> 1; row has status="pending", non-empty acceptance_criteria (6 numbered items), non-empty single-command probe. (2) Probe run verbatim from repo root at 7cf19b0 prints `doc=61 66 measured=66 72 warnings=19` then `DRIFT: docs/BOARD.md measured-state block is stale` — exactly the criterion's stated values (doc pair 61 66 differs from measured 66 72); at graded commit c09b62c it prints `doc=61 66 measured=67 73 warnings=20` + the same literal DRIFT line. (3) acceptance_criteria items 2-3 require the committed count-deriving check with a red arm proving a deliberately wrong count fails, and item 5 requires `bash tests/selftest.sh` -> SELFTEST: PASS with no FAIL rows plus `bash scripts/boardctl validate` -> RESULT: OK; verified live: selftest prints `SELFTEST: PASS`, 34 PASS rows, 0 FAIL rows (exit 0), boardctl prints `RESULT: OK (20 warning(s))` (exit 0). (4) `git show --name-only c09b62c` lists only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (board-only); message lines 38-41 state: "Guard: the pre-commit hook refuses board-only diffs (Tier 1 DEGRADED PASS, secrets clean, tests (full) PASS, lint skipped \"no staged files\" — CF-031, still pending). Disclosed bypass used: git -c core.hooksPath=/dev/null commit." — names DEGRADED PASS, the skipped lint stage, CF-031 and the bypass command.
CF-081 is correctly filed as a pending board row whose probe reproduces the documented drift (doc=61 66 vs measured=66 72, warnings=19 at 7cf19b0) with the literal DRIFT line, its acceptance criteria demand the count-deriving check with a red arm plus a green selftest/boardctl gate, and the board-only commit discloses the CF-031 core.hooksPath=/dev/null bypass and DEGRADED PASS with lint skipped.

Overall: PASS ✓

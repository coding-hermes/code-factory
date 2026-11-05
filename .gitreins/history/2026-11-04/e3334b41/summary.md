# Verdict: CF-158-RV1

**Task:** Review filing: CF-158 — the CF-119 lock adjudicator classifies an open fd (and a shared lock) as HELD
**Evaluated:** 2026-11-04T03:51:28.632352
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Review-lane FILING deliverable for CF-158. Grade the FILING ONLY: the underlying defect in scripts/board_lock.py is NOT expected to be repaired at this commit, and CF-158 must remain status=pending. A criterion conjunct that requires the fix is a criterion-wording error, not a merit failure.

Legs, all runnable at the committed HEAD:
1. `git show --name-status --format=%s HEAD` names `.coding-hermes/board/tasks.jsonl`, `.coding-hermes/board/events.jsonl` and `docs/audits/code-factory-review-CF-158.md`, and changes NO file under `scripts/`, `tests/`, or `.gitignore` (the reviewed code is untouched by this commit).
2. `jq -r 'select(.id=="CF-158")|.status' .coding-hermes/board/tasks.jsonl` prints `pending`, and the same selector on `.probe` prints one non-empty physical line containing `mktemp` and no `<path>`/`/home/` placeholder.
3. The row's own probe reproduces the refutation at this tree: `P=$(jq -r 'select(.id=="CF-158").probe' .coding-hermes/board/tasks.jsonl); bash -c "$P"` prints `unheld=RESIDUE consumers=0 commits_after_mtime=unknown` followed by `reader_only=HELD holder=pid-<digits>` and exits 0 — i.e. a process that only OPENS the lock path (no flock) is still classified HELD.
4. Control that the classifier is otherwise intact at this tree: `python3 -B scripts/board_lock.py /nonexistent/lock` prints `ABSENT`.
5. `bash scripts/boardctl validate` ends `RESULT: OK` and `bash tests/selftest.sh` ends `SELFTEST: PASS`.
6. `git rev-list --count origin/main..HEAD` prints 0 (the commit is pushed) and `git merge-base --is-ancestor HEAD origin/main` exits 0.: All six legs verified with actual command output at HEAD 238cd0e. Leg1: `git show --name-status --format=%s HEAD` -> `M .coding-hermes/board/events.jsonl`, `M .coding-hermes/board/tasks.jsonl`, `A docs/audits/code-factory-review-CF-158.md`; zero files under scripts/, tests/, or .gitignore (reviewed code untouched). Leg2: status selector prints `pending`; probe selector prints exactly one physical line containing `mktemp` and no `<path>`/`/home/` placeholder (verified via cat -A). Leg3: `bash -c "$P"` printed `unheld=RESIDUE consumers=0 commits_after_mtime=unknown` then `reader_only=HELD holder=pid-2923662` (plus `shared_lock=HELD holder=pid-2924053`), EXIT=0 — an open-fd-only process is still classified HELD, reproducing the refutation. Leg4: `python3 -B scripts/board_lock.py /nonexistent/lock` -> `ABSENT`, exit 0. Leg5: `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))` (warnings are pre-existing CF-034 free-form fields, not failures); `bash tests/selftest.sh` -> `SELFTEST: PASS`, SELFTEST_EXIT=0, including section 33 rows `PASS unheld 0-byte lock -> RESIDUE` and `PASS flock-held lock -> HELD`. Leg6: `git rev-list --count origin/main..HEAD` -> `0`; `git merge-base --is-ancestor HEAD origin/main` -> exit 0. The deliverable is a genuine filing: docs/audits/code-factory-review-CF-158.md is 179 lines and explicitly states 'This document is the review receipt, not the repair', and CF-158 remains status=pending as required.
The CF-158 review filing is complete and correct: all six legs pass at HEAD 238cd0e — the commit touches only board/audit files, CF-158 is pending with a runnable mktemp-based probe that reproduces the open-fd-classified-HELD refutation (exit 0), the ABSENT control holds, boardctl validate and selftest both pass, and the commit is pushed to origin/main.

## Summary

Judge Result: CF-158-RV1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Review-lane FILING deliverable for CF-158. Grade the FILING ONLY: the underlying defect in scripts/board_lock.py is NOT expected to be repaired at this commit, and CF-158 must remain status=pending. A criterion conjunct that requires the fix is a criterion-wording error, not a merit failure.

Legs, all runnable at the committed HEAD:
1. `git show --name-status --format=%s HEAD` names `.coding-hermes/board/tasks.jsonl`, `.coding-hermes/board/events.jsonl` and `docs/audits/code-factory-review-CF-158.md`, and changes NO file under `scripts/`, `tests/`, or `.gitignore` (the reviewed code is untouched by this commit).
2. `jq -r 'select(.id=="CF-158")|.status' .coding-hermes/board/tasks.jsonl` prints `pending`, and the same selector on `.probe` prints one non-empty physical line containing `mktemp` and no `<path>`/`/home/` placeholder.
3. The row's own probe reproduces the refutation at this tree: `P=$(jq -r 'select(.id=="CF-158").probe' .coding-hermes/board/tasks.jsonl); bash -c "$P"` prints `unheld=RESIDUE consumers=0 commits_after_mtime=unknown` followed by `reader_only=HELD holder=pid-<digits>` and exits 0 — i.e. a process that only OPENS the lock path (no flock) is still classified HELD.
4. Control that the classifier is otherwise intact at this tree: `python3 -B scripts/board_lock.py /nonexistent/lock` prints `ABSENT`.
5. `bash scripts/boardctl validate` ends `RESULT: OK` and `bash tests/selftest.sh` ends `SELFTEST: PASS`.
6. `git rev-list --count origin/main..HEAD` prints 0 (the commit is pushed) and `git merge-base --is-ancestor HEAD origin/main` exits 0.: All six legs verified with actual command output at HEAD 238cd0e. Leg1: `git show --name-status --format=%s HEAD` -> `M .coding-hermes/board/events.jsonl`, `M .coding-hermes/board/tasks.jsonl`, `A docs/audits/code-factory-review-CF-158.md`; zero files under scripts/, tests/, or .gitignore (reviewed code untouched). Leg2: status selector prints `pending`; probe selector prints exactly one physical line containing `mktemp` and no `<path>`/`/home/` placeholder (verified via cat -A). Leg3: `bash -c "$P"` printed `unheld=RESIDUE consumers=0 commits_after_mtime=unknown` then `reader_only=HELD holder=pid-2923662` (plus `shared_lock=HELD holder=pid-2924053`), EXIT=0 — an open-fd-only process is still classified HELD, reproducing the refutation. Leg4: `python3 -B scripts/board_lock.py /nonexistent/lock` -> `ABSENT`, exit 0. Leg5: `bash scripts/boardctl validate` -> `RESULT: OK (3 warning(s))` (warnings are pre-existing CF-034 free-form fields, not failures); `bash tests/selftest.sh` -> `SELFTEST: PASS`, SELFTEST_EXIT=0, including section 33 rows `PASS unheld 0-byte lock -> RESIDUE` and `PASS flock-held lock -> HELD`. Leg6: `git rev-list --count origin/main..HEAD` -> `0`; `git merge-base --is-ancestor HEAD origin/main` -> exit 0. The deliverable is a genuine filing: docs/audits/code-factory-review-CF-158.md is 179 lines and explicitly states 'This document is the review receipt, not the repair', and CF-158 remains status=pending as required.
The CF-158 review filing is complete and correct: all six legs pass at HEAD 238cd0e — the commit touches only board/audit files, CF-158 is pending with a runnable mktemp-based probe that reproduces the open-fd-classified-HELD refutation (exit 0), the ABSENT control holds, boardctl validate and selftest both pass, and the commit is pushed to origin/main.

Overall: PASS ✓

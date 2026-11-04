# Verdict: CF-185-QA1

**Task:** CF-185 QA filing: add_family_lanes.py has no read-only mode and no overridable target
**Evaluated:** 2026-11-04T09:10:19.258325
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-scoped: this task grades the QA FILING only — do NOT evaluate or implement the underlying fix. Assert at the graded commit: (1) `git show --stat --oneline HEAD` shows a board-only commit whose diff touches only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (a following chore(gitreins) verdict-bundle commit is expected and is not the graded change); (2) `git show <board-commit>:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-185")'` prints exactly ONE row with status pending, a non-empty probe field, and acceptance_criteria containing the phrase Read-only mode; (3) running that row's probe verbatim from the repository root prints argv_handling=0, api_base=API = "http://127.0.0.1:9090", api_write_calls=1, a FileNotFoundError line naming '/proc/0/environ', and rc=1; (4) `bash scripts/boardctl validate` prints RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS at the graded tree. The script scripts/add_family_lanes.py is NOT expected to be fixed by this task.: All four sub-assertions verified at graded commit HEAD=62756a5 in a clean detached worktree (/tmp/cf185_head). (1) `git show --stat --oneline HEAD` -> '62756a5 board(qa): file CF-185 ...' with exactly '.coding-hermes/board/events.jsonl | 1 +' and '.coding-hermes/board/tasks.jsonl | 1 +' (2 files changed, 2 insertions); `git show --name-only --format="" HEAD` lists only those two paths — board-only. (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-185")' | wc -l` -> 1; row fields: {"id":"CF-185","status":"pending","probe_ok":true,"ac_has":true} — probe is 501 chars, acceptance_criteria contains 'Read-only mode is the DEFAULT'. (3) Probe extracted verbatim via `jq -r '.probe'` and run from repo root printed exactly: 'argv_handling=0', 'api_base=API = "http://127.0.0.1:9090"', 'api_write_calls=1', "FileNotFoundError: [Errno 2] No such file or directory: '/proc/0/environ'", 'rc=1'. (4) In the clean worktree at HEAD: `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))' and `bash tests/selftest.sh` -> 'SELFTEST: PASS'. Note: the dirty working tree carries uncommitted edits to tests/selftest.sh and scripts/harness/install-hermes.sh (unrelated to CF-185) that make selftest report 'SELFTEST: FAIL (9)'; the graded tree itself is clean and passes. scripts/add_family_lanes.py is correctly left unfixed — the probe still reproduces the defect.
The CF-185 QA filing is complete and correct at graded commit 62756a5: a board-only commit adding exactly one pending CF-185 row whose probe verbatim reproduces argv_handling=0 / api_base=API = "http://127.0.0.1:9090" / api_write_calls=1 / FileNotFoundError '/proc/0/environ' / rc=1, with boardctl validate printing RESULT: OK and selftest printing SELFTEST: PASS at the graded tree.

## Summary

Judge Result: CF-185-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-scoped: this task grades the QA FILING only — do NOT evaluate or implement the underlying fix. Assert at the graded commit: (1) `git show --stat --oneline HEAD` shows a board-only commit whose diff touches only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl (a following chore(gitreins) verdict-bundle commit is expected and is not the graded change); (2) `git show <board-commit>:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-185")'` prints exactly ONE row with status pending, a non-empty probe field, and acceptance_criteria containing the phrase Read-only mode; (3) running that row's probe verbatim from the repository root prints argv_handling=0, api_base=API = "http://127.0.0.1:9090", api_write_calls=1, a FileNotFoundError line naming '/proc/0/environ', and rc=1; (4) `bash scripts/boardctl validate` prints RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS at the graded tree. The script scripts/add_family_lanes.py is NOT expected to be fixed by this task.: All four sub-assertions verified at graded commit HEAD=62756a5 in a clean detached worktree (/tmp/cf185_head). (1) `git show --stat --oneline HEAD` -> '62756a5 board(qa): file CF-185 ...' with exactly '.coding-hermes/board/events.jsonl | 1 +' and '.coding-hermes/board/tasks.jsonl | 1 +' (2 files changed, 2 insertions); `git show --name-only --format="" HEAD` lists only those two paths — board-only. (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-185")' | wc -l` -> 1; row fields: {"id":"CF-185","status":"pending","probe_ok":true,"ac_has":true} — probe is 501 chars, acceptance_criteria contains 'Read-only mode is the DEFAULT'. (3) Probe extracted verbatim via `jq -r '.probe'` and run from repo root printed exactly: 'argv_handling=0', 'api_base=API = "http://127.0.0.1:9090"', 'api_write_calls=1', "FileNotFoundError: [Errno 2] No such file or directory: '/proc/0/environ'", 'rc=1'. (4) In the clean worktree at HEAD: `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))' and `bash tests/selftest.sh` -> 'SELFTEST: PASS'. Note: the dirty working tree carries uncommitted edits to tests/selftest.sh and scripts/harness/install-hermes.sh (unrelated to CF-185) that make selftest report 'SELFTEST: FAIL (9)'; the graded tree itself is clean and passes. scripts/add_family_lanes.py is correctly left unfixed — the probe still reproduces the defect.
The CF-185 QA filing is complete and correct at graded commit 62756a5: a board-only commit adding exactly one pending CF-185 row whose probe verbatim reproduces argv_handling=0 / api_base=API = "http://127.0.0.1:9090" / api_write_calls=1 / FileNotFoundError '/proc/0/environ' / rc=1, with boardctl validate printing RESULT: OK and selftest printing SELFTEST: PASS at the graded tree.

Overall: PASS ✓

# Verdict: CF-093-QA1

**Task:** CF-093 is filed on the published tree and its probe reproduces the unenforced README Status rows
**Evaluated:** 2026-11-03T17:40:27.110790
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only QA task: do NOT evaluate the underlying fix, CF-093 is pending by design. (1) The filing commit is the tip of origin/main and touches exactly .coding-hermes/board/tasks.jsonl (+1 line) and .coding-hermes/board/events.jsonl (+1 line) -- git show --stat <sha> shows 2 files changed, 2 insertions(+), 0 deletions(-). (2) git show <sha>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-093") | [.status,.priority,(.probe|length)] | @tsv' prints a line starting 'pending' 'P4' with a non-zero probe length, and the id occurs exactly once in the committed board. (3) Re-running that row's own probe verbatim from the repo root prints exactly three lines of interest: qualified_command_occurrences=0, SELFTEST: PASS, SELFTEST_EXIT=0, and leaves README.md unmodified (git status --porcelain README.md prints nothing). (4) At the same commit bash tests/selftest.sh prints SELFTEST: PASS with exit 0, and scripts/boardctl validate prints RESULT: OK.: (1) `git rev-parse HEAD` = 4d9912775dcb8ae3f09f4d207a39afaf6a6c9314 and `git rev-parse origin/main` = same sha (tip of origin/main). `git show --stat 4d99127` output: '.coding-hermes/board/events.jsonl | 1 +', '.coding-hermes/board/tasks.jsonl | 1 +', '2 files changed, 2 insertions(+)' — exactly 2 files, +1 each, 0 deletions. (2) `git show 4d99127:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-093") | [.status,.priority,(.probe|length)] | @tsv'` printed 'pending	P4	436' (exit 0) — status pending, priority P4, probe length 436 (non-zero). `grep -c '"id":"CF-093"'` on the committed board = 1, so the id occurs exactly once. Row is pending by design (title: 'P4 - README Status rows 1 and 3 are enforced by nothing...'), and the underlying fix was not evaluated. (3) Probe extracted verbatim from the row and run from repo root printed exactly the three expected lines: 'qualified_command_occurrences=0', 'SELFTEST: PASS', 'SELFTEST_EXIT=0'. Immediately after, `git status --porcelain README.md` printed nothing (empty output) — README.md unmodified (probe's trap restored it). (4) `bash tests/selftest.sh` at 4d99127 printed 'SELFTEST: PASS' with 'SELFTEST_EXIT=0' (exit_code 0; all 19 arms PASS). `scripts/boardctl validate` printed 'RESULT: OK (26 warning(s))' with BOARDCTL_EXIT=0 (warnings are pre-existing canon-drift/headerless-board notices, not failures).
Filing commit 4d99127 is the tip of origin/main with a board-only 2-file/+2-line diff, CF-093 is pending/P4 with a 436-char probe occurring once, the probe reproduces qualified_command_occurrences=0 / SELFTEST: PASS / SELFTEST_EXIT=0 without touching README.md, and both selftest.sh and boardctl validate pass at that commit.

## Summary

Judge Result: CF-093-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only QA task: do NOT evaluate the underlying fix, CF-093 is pending by design. (1) The filing commit is the tip of origin/main and touches exactly .coding-hermes/board/tasks.jsonl (+1 line) and .coding-hermes/board/events.jsonl (+1 line) -- git show --stat <sha> shows 2 files changed, 2 insertions(+), 0 deletions(-). (2) git show <sha>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-093") | [.status,.priority,(.probe|length)] | @tsv' prints a line starting 'pending' 'P4' with a non-zero probe length, and the id occurs exactly once in the committed board. (3) Re-running that row's own probe verbatim from the repo root prints exactly three lines of interest: qualified_command_occurrences=0, SELFTEST: PASS, SELFTEST_EXIT=0, and leaves README.md unmodified (git status --porcelain README.md prints nothing). (4) At the same commit bash tests/selftest.sh prints SELFTEST: PASS with exit 0, and scripts/boardctl validate prints RESULT: OK.: (1) `git rev-parse HEAD` = 4d9912775dcb8ae3f09f4d207a39afaf6a6c9314 and `git rev-parse origin/main` = same sha (tip of origin/main). `git show --stat 4d99127` output: '.coding-hermes/board/events.jsonl | 1 +', '.coding-hermes/board/tasks.jsonl | 1 +', '2 files changed, 2 insertions(+)' — exactly 2 files, +1 each, 0 deletions. (2) `git show 4d99127:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-093") | [.status,.priority,(.probe|length)] | @tsv'` printed 'pending	P4	436' (exit 0) — status pending, priority P4, probe length 436 (non-zero). `grep -c '"id":"CF-093"'` on the committed board = 1, so the id occurs exactly once. Row is pending by design (title: 'P4 - README Status rows 1 and 3 are enforced by nothing...'), and the underlying fix was not evaluated. (3) Probe extracted verbatim from the row and run from repo root printed exactly the three expected lines: 'qualified_command_occurrences=0', 'SELFTEST: PASS', 'SELFTEST_EXIT=0'. Immediately after, `git status --porcelain README.md` printed nothing (empty output) — README.md unmodified (probe's trap restored it). (4) `bash tests/selftest.sh` at 4d99127 printed 'SELFTEST: PASS' with 'SELFTEST_EXIT=0' (exit_code 0; all 19 arms PASS). `scripts/boardctl validate` printed 'RESULT: OK (26 warning(s))' with BOARDCTL_EXIT=0 (warnings are pre-existing canon-drift/headerless-board notices, not failures).
Filing commit 4d99127 is the tip of origin/main with a board-only 2-file/+2-line diff, CF-093 is pending/P4 with a 436-char probe occurring once, the probe reproduces qualified_command_occurrences=0 / SELFTEST: PASS / SELFTEST_EXIT=0 without touching README.md, and both selftest.sh and boardctl validate pass at that commit.

Overall: PASS ✓

# Verdict: CF-242-QA1

**Task:** QA filing: CF-242 section-mapping census cannot see a duplicate-numbered or indented section header
**Evaluated:** 2026-11-05T11:56:02.371824
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only verification tick, graded at the commit this task lands in. (1) `git show --stat HEAD` names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl and nothing else. (2) `jq -e 'select(.id=="CF-242") | select(.status=="pending") | select((.probe|length)>0)' .coding-hermes/board/tasks.jsonl` exits 0. (3) Extracting that row's probe from the COMMITTED board and running it from the repo root prints `at_column_headers=50 indented_headers=1`, then `arms_plan=49 arms_tree=49`, then `RESULT: OK`, and exits 0 — that output is the defect: two appended section spellings (a duplicate number at column 0 and an indented header) leave the mapping gate green. (4) `bash scripts/boardctl validate` prints RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS at that commit. The repair (making the section census a multiset over at-column headers and failing with a named row for a duplicated number or an indented header) is future work tracked by pending row CF-242 and is NOT expected at this commit; do not evaluate the fix.: (1) `git show --stat HEAD` (commit 057fbe2) lists ONLY .coding-hermes/board/events.jsonl (+2) and .coding-hermes/board/tasks.jsonl (+1), nothing else; exit 0. (2) `jq -e 'select(.id=="CF-242") | select(.status=="pending") | select((.probe|length)>0)' .coding-hermes/board/tasks.jsonl` -> exit 0, printing the single pending CF-242 row with a non-empty bash probe. (3) Probe re-extracted verbatim from the COMMITTED board (`git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-242") | .probe'`), run with bash from the repo root on the clean tree: output exactly `at_column_headers=50 indented_headers=1` / `arms_plan=49 arms_tree=49` / `RESULT: OK`, PROBE_EXIT=0 — the two appended spellings (duplicate `say "45.` at column 0, indented `say "47.`) leave the cf198-section-mapping gate green as specified. (4) `bash scripts/boardctl validate` -> exit 0, prints `RESULT: OK (4 warning(s))` (pre-existing warnings, matching the commit message); `bash tests/selftest.sh` -> exit 0, final line `SELFTEST: PASS`. Repair is future work in pending row CF-242, not expected at this commit, and was not evaluated.
CF-242 QA filing verified: commit touches only the two board files, the committed pending row's probe reproduces the silent-gate defect verbatim (50/1 headers, arms 49/49, RESULT: OK, rc=0), and both shipped gates pass at this commit.

## Summary

Judge Result: CF-242-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only verification tick, graded at the commit this task lands in. (1) `git show --stat HEAD` names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl and nothing else. (2) `jq -e 'select(.id=="CF-242") | select(.status=="pending") | select((.probe|length)>0)' .coding-hermes/board/tasks.jsonl` exits 0. (3) Extracting that row's probe from the COMMITTED board and running it from the repo root prints `at_column_headers=50 indented_headers=1`, then `arms_plan=49 arms_tree=49`, then `RESULT: OK`, and exits 0 — that output is the defect: two appended section spellings (a duplicate number at column 0 and an indented header) leave the mapping gate green. (4) `bash scripts/boardctl validate` prints RESULT: OK and `bash tests/selftest.sh` prints SELFTEST: PASS at that commit. The repair (making the section census a multiset over at-column headers and failing with a named row for a duplicated number or an indented header) is future work tracked by pending row CF-242 and is NOT expected at this commit; do not evaluate the fix.: (1) `git show --stat HEAD` (commit 057fbe2) lists ONLY .coding-hermes/board/events.jsonl (+2) and .coding-hermes/board/tasks.jsonl (+1), nothing else; exit 0. (2) `jq -e 'select(.id=="CF-242") | select(.status=="pending") | select((.probe|length)>0)' .coding-hermes/board/tasks.jsonl` -> exit 0, printing the single pending CF-242 row with a non-empty bash probe. (3) Probe re-extracted verbatim from the COMMITTED board (`git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-242") | .probe'`), run with bash from the repo root on the clean tree: output exactly `at_column_headers=50 indented_headers=1` / `arms_plan=49 arms_tree=49` / `RESULT: OK`, PROBE_EXIT=0 — the two appended spellings (duplicate `say "45.` at column 0, indented `say "47.`) leave the cf198-section-mapping gate green as specified. (4) `bash scripts/boardctl validate` -> exit 0, prints `RESULT: OK (4 warning(s))` (pre-existing warnings, matching the commit message); `bash tests/selftest.sh` -> exit 0, final line `SELFTEST: PASS`. Repair is future work in pending row CF-242, not expected at this commit, and was not evaluated.
CF-242 QA filing verified: commit touches only the two board files, the committed pending row's probe reproduces the silent-gate defect verbatim (50/1 headers, arms 49/49, RESULT: OK, rc=0), and both shipped gates pass at this commit.

Overall: PASS ✓

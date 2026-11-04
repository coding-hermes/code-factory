# Verdict: CF-144-QA1

**Task:** CF-144 filing verification (unique id: the plain CF-144 task belongs to a sibling lane's dogfood finding)
**Evaluated:** 2026-11-04T02:29:17.360809
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only verification of commit 51efb66 ("board: file CF-144 — the closure-evidence rule conflates three tree_fp instruments").

Do NOT evaluate the underlying repair: CF-144 is a PENDING board row by design, so the closure-evidence rule it describes is future work. Grade ONLY whether the filing is correct and reproducible.

A previous task named exactly CF-144 was created by a different lane for a different finding (a dogfood finding about bunker-server-install.sh). Its verdict does not apply to this commit. Grade THIS criterion only.

1. `git show --stat 51efb66` names only `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl`, with additions and ZERO deletions.
2. In the committed tree: `git show 51efb66:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-144") | [.id,.status,.priority,(.probe|length)] | @tsv'` prints `CF-144 pending P3 <n>` with n > 100.
3. Extract the probe FROM THE COMMITTED BOARD and run it from the repo root: `git show 51efb66:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-144").probe' > /tmp/p.sh && bash /tmp/p.sh`. It must print `instrument_census: declared_sha256_of_artifact=4 bare_64hex=37 tree_oid_40hex=5 other=1` and must print a `git_cat_file_t=fatal: Not a valid object name` line for each of CF-064, CF-065, CF-091 and CF-092, and for CF-052.
4. The probe is portable: zero occurrences of `/home/`, zero occurrences of `<path>`, `<fixture>` or `/path/to`, at least one `mktemp`, and `bash -n` succeeds.
5. `bash tests/selftest.sh` prints SELFTEST: PASS and `scripts/boardctl validate` prints RESULT: OK.
6. CF-144 is present on `origin/main` and `git rev-list --count origin/main..51efb66` is 0.: All six sub-checks verified with live command output. (1) `git show --stat 51efb66` lists only `.coding-hermes/board/events.jsonl | 1 +` and `.coding-hermes/board/tasks.jsonl | 1 +`, summary `2 files changed, 2 insertions(+)` — zero deletions. (2) jq on the committed tree prints `CF-144	pending	P3	814` (n=814 > 100). (3) Probe extracted from committed board and run from repo root (exit 0) printed exactly `instrument_census: declared_sha256_of_artifact=4 bare_64hex=37 tree_oid_40hex=5 other=1`, plus `git_cat_file_t=fatal: Not a valid object name` lines for CF-064 (476e40d5...), CF-065 (df0b3ffa...), CF-091 (e03725f0...), CF-092 (3ca5e2b5...) and CF-052 (0000...). (4) grep counts on /tmp/p.sh: `/home/`=0, `<path>`=0, `<fixture>`=0, `/path/to`=0, `mktemp`=1; `bash -n /tmp/p.sh` succeeded (BASH_N_OK). (5) `bash tests/selftest.sh` printed `SELFTEST: PASS` (all 29 groups PASS); `scripts/boardctl validate` printed `RESULT: OK (49 warning(s))` with exit_code 0. (6) `git show origin/main:.coding-hermes/board/tasks.jsonl | jq` returns `CF-144	pending	P3`; `git rev-list --count origin/main..51efb66` = 0; `git branch -r --contains 51efb66` lists origin/main.


## Summary

Judge Result: CF-144-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only verification of commit 51efb66 ("board: file CF-144 — the closure-evidence rule conflates three tree_fp instruments").

Do NOT evaluate the underlying repair: CF-144 is a PENDING board row by design, so the closure-evidence rule it describes is future work. Grade ONLY whether the filing is correct and reproducible.

A previous task named exactly CF-144 was created by a different lane for a different finding (a dogfood finding about bunker-server-install.sh). Its verdict does not apply to this commit. Grade THIS criterion only.

1. `git show --stat 51efb66` names only `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl`, with additions and ZERO deletions.
2. In the committed tree: `git show 51efb66:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-144") | [.id,.status,.priority,(.probe|length)] | @tsv'` prints `CF-144 pending P3 <n>` with n > 100.
3. Extract the probe FROM THE COMMITTED BOARD and run it from the repo root: `git show 51efb66:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-144").probe' > /tmp/p.sh && bash /tmp/p.sh`. It must print `instrument_census: declared_sha256_of_artifact=4 bare_64hex=37 tree_oid_40hex=5 other=1` and must print a `git_cat_file_t=fatal: Not a valid object name` line for each of CF-064, CF-065, CF-091 and CF-092, and for CF-052.
4. The probe is portable: zero occurrences of `/home/`, zero occurrences of `<path>`, `<fixture>` or `/path/to`, at least one `mktemp`, and `bash -n` succeeds.
5. `bash tests/selftest.sh` prints SELFTEST: PASS and `scripts/boardctl validate` prints RESULT: OK.
6. CF-144 is present on `origin/main` and `git rev-list --count origin/main..51efb66` is 0.: All six sub-checks verified with live command output. (1) `git show --stat 51efb66` lists only `.coding-hermes/board/events.jsonl | 1 +` and `.coding-hermes/board/tasks.jsonl | 1 +`, summary `2 files changed, 2 insertions(+)` — zero deletions. (2) jq on the committed tree prints `CF-144	pending	P3	814` (n=814 > 100). (3) Probe extracted from committed board and run from repo root (exit 0) printed exactly `instrument_census: declared_sha256_of_artifact=4 bare_64hex=37 tree_oid_40hex=5 other=1`, plus `git_cat_file_t=fatal: Not a valid object name` lines for CF-064 (476e40d5...), CF-065 (df0b3ffa...), CF-091 (e03725f0...), CF-092 (3ca5e2b5...) and CF-052 (0000...). (4) grep counts on /tmp/p.sh: `/home/`=0, `<path>`=0, `<fixture>`=0, `/path/to`=0, `mktemp`=1; `bash -n /tmp/p.sh` succeeded (BASH_N_OK). (5) `bash tests/selftest.sh` printed `SELFTEST: PASS` (all 29 groups PASS); `scripts/boardctl validate` printed `RESULT: OK (49 warning(s))` with exit_code 0. (6) `git show origin/main:.coding-hermes/board/tasks.jsonl | jq` returns `CF-144	pending	P3`; `git rev-list --count origin/main..51efb66` = 0; `git branch -r --contains 51efb66` lists origin/main.


Overall: PASS ✓

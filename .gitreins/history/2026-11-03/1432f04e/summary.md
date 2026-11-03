# Verdict: CF-088-QA1

**Task:** QA filing: the selftest board arm greens boards that scripts/boardctl validate rejects
**Evaluated:** 2026-11-03T16:39:16.986183
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Append a pending board row measuring that tests/selftest.sh section 7 accepts any valid JSON line while scripts/boardctl validate rejects non-object rows, duplicate ids and out-of-vocabulary statuses, and that no automated check runs the validator against the real board; the row must carry a portable probe and land insert-only on main with parity 0/0.: Row appended: .coding-hermes/board/tasks.jsonl last line is id CF-088, status "pending", priority P3, detail.source=releng-qa, measured_at 400a5ab, with a full "probe" field; matching .coding-hermes/board/events.jsonl line 85 task_created. Insert-only: `git show HEAD --stat` = 2 files changed, 2 insertions(+), 0 deletions. Parity: `git rev-list --count origin/main..HEAD` = 0 and `HEAD..origin/main` = 0 on branch main (HEAD 4976205 == origin/main). Probe extracted from the row, `bash -n` clean, ran to exit 0 and reproduced every measured claim: null-line/array-line/string-line -> gate "PASS 76/76 rows parse SELFTEST: PASS" vs validator "[error] tasks.jsonl: line 76: row is not a JSON object RESULT: FAIL"; duplicate-id -> gate PASS vs "[error] duplicate task id \"CF-082\" (also line 68) RESULT: FAIL"; unknown-status -> gate PASS vs "[error] status \"bogus_status\" not in vocabulary {blocked,complete,failed,in_progress,pending,review} RESULT: FAIL"; missing-status -> gate PASS vs "RESULT: OK (26 warning(s))"; clean-board control -> "PASS 75/75 rows parse SELFTEST: PASS" / "RESULT: OK (24 warning(s))". Root cause confirmed at tests/selftest.sh:160-183 (section 7 counts a row when json.loads succeeds only). No automated check runs the validator: grep for validate across tests/ and scripts/ returns only tests/selftest.sh:246 (a lane-target label) plus unrelated hits; .gitreins/config.yaml test_command = "bash tests/selftest.sh"; no .github workflows ship (only .gitreins/*.yaml). Probe is portable: only git/mktemp/bash/grep/jq, writes solely inside mktemp, no network, and guards a missing validator with "validator arm SKIPPED (boardctl absent)". Repo state verified: `bash tests/selftest.sh` -> EXIT=0, "PASS 75/75 rows parse", "SELFTEST: PASS"; `bash scripts/boardctl validate` -> "RESULT: OK (24 warning(s))", EXIT=0.
The CF-088 pending row landed insert-only on main with parity 0/0 and carries a portable probe that, when run, reproduces the exact divergence between selftest section 7 and scripts/boardctl validate on non-object, duplicate-id and out-of-vocabulary fixtures.

## Summary

Judge Result: CF-088-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Append a pending board row measuring that tests/selftest.sh section 7 accepts any valid JSON line while scripts/boardctl validate rejects non-object rows, duplicate ids and out-of-vocabulary statuses, and that no automated check runs the validator against the real board; the row must carry a portable probe and land insert-only on main with parity 0/0.: Row appended: .coding-hermes/board/tasks.jsonl last line is id CF-088, status "pending", priority P3, detail.source=releng-qa, measured_at 400a5ab, with a full "probe" field; matching .coding-hermes/board/events.jsonl line 85 task_created. Insert-only: `git show HEAD --stat` = 2 files changed, 2 insertions(+), 0 deletions. Parity: `git rev-list --count origin/main..HEAD` = 0 and `HEAD..origin/main` = 0 on branch main (HEAD 4976205 == origin/main). Probe extracted from the row, `bash -n` clean, ran to exit 0 and reproduced every measured claim: null-line/array-line/string-line -> gate "PASS 76/76 rows parse SELFTEST: PASS" vs validator "[error] tasks.jsonl: line 76: row is not a JSON object RESULT: FAIL"; duplicate-id -> gate PASS vs "[error] duplicate task id \"CF-082\" (also line 68) RESULT: FAIL"; unknown-status -> gate PASS vs "[error] status \"bogus_status\" not in vocabulary {blocked,complete,failed,in_progress,pending,review} RESULT: FAIL"; missing-status -> gate PASS vs "RESULT: OK (26 warning(s))"; clean-board control -> "PASS 75/75 rows parse SELFTEST: PASS" / "RESULT: OK (24 warning(s))". Root cause confirmed at tests/selftest.sh:160-183 (section 7 counts a row when json.loads succeeds only). No automated check runs the validator: grep for validate across tests/ and scripts/ returns only tests/selftest.sh:246 (a lane-target label) plus unrelated hits; .gitreins/config.yaml test_command = "bash tests/selftest.sh"; no .github workflows ship (only .gitreins/*.yaml). Probe is portable: only git/mktemp/bash/grep/jq, writes solely inside mktemp, no network, and guards a missing validator with "validator arm SKIPPED (boardctl absent)". Repo state verified: `bash tests/selftest.sh` -> EXIT=0, "PASS 75/75 rows parse", "SELFTEST: PASS"; `bash scripts/boardctl validate` -> "RESULT: OK (24 warning(s))", EXIT=0.
The CF-088 pending row landed insert-only on main with parity 0/0 and carries a portable probe that, when run, reproduces the exact divergence between selftest section 7 and scripts/boardctl validate on non-object, duplicate-id and out-of-vocabulary fixtures.

Overall: PASS ✓

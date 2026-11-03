# Verdict: CF-052-QA1

**Task:** QA re-verify CF-052 lane workdir target model and file the failure modes it does not test
**Evaluated:** 2026-11-03T12:53:44.867841
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ python3 -B tests/test_lane_target.py prints OK with 22 tests at a tree where 222a8b0 is an ancestor of HEAD; bash tests/selftest.sh prints SELFTEST: PASS; three new pending board rows (CF-060, CF-061, CF-062) exist in .coding-hermes/board/tasks.jsonl, each carrying a re-runnable probe command that reproduces the failure it names; the board commit ddff6bc (supersedes 5d7eb64, which the judge failed for placeholder probes) is pushed to origin/main and origin/main..HEAD is 0; selftest at that tree prints SELFTEST: PASS.: All sub-conditions verified with fresh command output. (1) `git merge-base --is-ancestor 222a8b0 HEAD` -> "222a8b0 IS ancestor". (2) `python3 -B tests/test_lane_target.py` -> "Ran 22 tests in 0.146s / OK", exit 0. (3) `bash tests/selftest.sh` -> exit 0, 31 PASS lines, final line "SELFTEST: PASS" (run fresh at HEAD ddff6bc). (4) .coding-hermes/board/tasks.jsonl (46 rows, no duplicate ids) contains CF-060, CF-061, CF-062, all status "pending", each with a non-placeholder self-contained `probe` field; I extracted and executed each probe: CF-060 probe builds a checkout whose only remote is https://github.com/example/unrelated.git and `lane_target.py verify` returns "ok": true, rc=0 (reproduces the wrong-repo defect); CF-061 probe prints "MERGE_HEAD present, branch main, unmerged 3" then verify returns "ok": true, rc=0 (reproduces the mid-merge defect); CF-062 probe runs `scan --allow-remote` on a remote-lane row and prints {"bad":0,"ok":true}, rc=0 (reproduces the structural-only defect). (5) HEAD == ddff6bc2a26d8d873faab1d633c8f8467ffbbea5, `git rev-parse origin/main` == ddff6bc, `git rev-list --count origin/main..HEAD` = 0, and `git merge-base --is-ancestor 5d7eb64 ddff6bc` -> YES (supersedes).


## Summary

Judge Result: CF-052-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ python3 -B tests/test_lane_target.py prints OK with 22 tests at a tree where 222a8b0 is an ancestor of HEAD; bash tests/selftest.sh prints SELFTEST: PASS; three new pending board rows (CF-060, CF-061, CF-062) exist in .coding-hermes/board/tasks.jsonl, each carrying a re-runnable probe command that reproduces the failure it names; the board commit ddff6bc (supersedes 5d7eb64, which the judge failed for placeholder probes) is pushed to origin/main and origin/main..HEAD is 0; selftest at that tree prints SELFTEST: PASS.: All sub-conditions verified with fresh command output. (1) `git merge-base --is-ancestor 222a8b0 HEAD` -> "222a8b0 IS ancestor". (2) `python3 -B tests/test_lane_target.py` -> "Ran 22 tests in 0.146s / OK", exit 0. (3) `bash tests/selftest.sh` -> exit 0, 31 PASS lines, final line "SELFTEST: PASS" (run fresh at HEAD ddff6bc). (4) .coding-hermes/board/tasks.jsonl (46 rows, no duplicate ids) contains CF-060, CF-061, CF-062, all status "pending", each with a non-placeholder self-contained `probe` field; I extracted and executed each probe: CF-060 probe builds a checkout whose only remote is https://github.com/example/unrelated.git and `lane_target.py verify` returns "ok": true, rc=0 (reproduces the wrong-repo defect); CF-061 probe prints "MERGE_HEAD present, branch main, unmerged 3" then verify returns "ok": true, rc=0 (reproduces the mid-merge defect); CF-062 probe runs `scan --allow-remote` on a remote-lane row and prints {"bad":0,"ok":true}, rc=0 (reproduces the structural-only defect). (5) HEAD == ddff6bc2a26d8d873faab1d633c8f8467ffbbea5, `git rev-parse origin/main` == ddff6bc, `git rev-list --count origin/main..HEAD` = 0, and `git merge-base --is-ancestor 5d7eb64 ddff6bc` -> YES (supersedes).


Overall: PASS ✓

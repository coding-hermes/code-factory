# Verdict: CF-161-REL1

**Task:** File CF-161: the repo has no release contract (zero published tags, two local-only safety tags)
**Evaluated:** 2026-11-04T04:12:28.519046
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Row CF-161 is present on the published tree exactly once with status=pending, priority=P3 and a non-empty acceptance_criteria that names the two local-only tag targets (6598ec3, e270fb3) and the two re-runnable measurements (git ls-remote --tags origin prints nothing; a bare clone of the remote lists no tags). The board diff is insert-only (one added line, zero removed) and no other row changes; bash scripts/boardctl validate prints RESULT: OK; bash tests/selftest.sh prints SELFTEST: PASS at the filed commit; and git show origin/main:.coding-hermes/board/tasks.jsonl contains the row id CF-161.: Row: .coding-hermes/board/tasks.jsonl:135 is the only CF-161 line (grep -c = 1); parsed JSON gives status=pending, priority=P3, acceptance_criteria length 1752 chars containing all of 6598ec3, e270fb3, 'git ls-remote --tags origin', 'prints NOTHING', 'clone --bare', 'tag -l' (python check all True). Insert-only: `git show HEAD --numstat` = '1 0 .coding-hermes/board/tasks.jsonl', '1 0 .coding-hermes/board/events.jsonl', '64 0 docs/audits/...CF-161.md'; grep of removed lines in tasks.jsonl = 0, added = 1; diff of parent (134 lines) vs HEAD (135 lines) shows only '134a135 > {"id":"CF-161"...' — no other row touched; events.jsonl adds one task_created CF-161 event. Validate: `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', exit 0 (warnings are pre-existing CF-034 free-form fields and headerless board, unrelated to CF-161). Selftest: `bash tests/selftest.sh` -> 'SELFTEST: PASS' (33 sections, all PASS). Published tree: the published remote is `gh` (git@github.com:coding-hermes/code-factory.git); `git rev-parse gh/main` = c2a6a45 = HEAD, and `git show gh/main:.coding-hermes/board/tasks.jsonl | grep -c CF-161` = 1. A fresh bare clone of the GitHub remote (`git clone --bare git@github.com:coding-hermes/code-factory.git`) lists 0 tags (TAGCOUNT=0) and its main tasks.jsonl contains CF-161 (count=1), confirming the row is on the published tree. Note: the literal `origin/main` ref is a local path remote (/home/kara/code-factory) still at 79e9b59 and lacks the row, but `origin` is not the published remote — `gh` is, and it carries the row; the criterion's intent (row present on the published tree) is met.
CF-161 is filed exactly once as a pending P3 row with full acceptance criteria naming both local-only tag targets and both re-runnable measurements, the board diff is strictly insert-only, boardctl validate prints RESULT: OK, selftest prints SELFTEST: PASS, and the row is present on the published GitHub remote (gh/main = c2a6a45, bare clone of the remote lists zero tags).

## Summary

Judge Result: CF-161-REL1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Row CF-161 is present on the published tree exactly once with status=pending, priority=P3 and a non-empty acceptance_criteria that names the two local-only tag targets (6598ec3, e270fb3) and the two re-runnable measurements (git ls-remote --tags origin prints nothing; a bare clone of the remote lists no tags). The board diff is insert-only (one added line, zero removed) and no other row changes; bash scripts/boardctl validate prints RESULT: OK; bash tests/selftest.sh prints SELFTEST: PASS at the filed commit; and git show origin/main:.coding-hermes/board/tasks.jsonl contains the row id CF-161.: Row: .coding-hermes/board/tasks.jsonl:135 is the only CF-161 line (grep -c = 1); parsed JSON gives status=pending, priority=P3, acceptance_criteria length 1752 chars containing all of 6598ec3, e270fb3, 'git ls-remote --tags origin', 'prints NOTHING', 'clone --bare', 'tag -l' (python check all True). Insert-only: `git show HEAD --numstat` = '1 0 .coding-hermes/board/tasks.jsonl', '1 0 .coding-hermes/board/events.jsonl', '64 0 docs/audits/...CF-161.md'; grep of removed lines in tasks.jsonl = 0, added = 1; diff of parent (134 lines) vs HEAD (135 lines) shows only '134a135 > {"id":"CF-161"...' — no other row touched; events.jsonl adds one task_created CF-161 event. Validate: `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', exit 0 (warnings are pre-existing CF-034 free-form fields and headerless board, unrelated to CF-161). Selftest: `bash tests/selftest.sh` -> 'SELFTEST: PASS' (33 sections, all PASS). Published tree: the published remote is `gh` (git@github.com:coding-hermes/code-factory.git); `git rev-parse gh/main` = c2a6a45 = HEAD, and `git show gh/main:.coding-hermes/board/tasks.jsonl | grep -c CF-161` = 1. A fresh bare clone of the GitHub remote (`git clone --bare git@github.com:coding-hermes/code-factory.git`) lists 0 tags (TAGCOUNT=0) and its main tasks.jsonl contains CF-161 (count=1), confirming the row is on the published tree. Note: the literal `origin/main` ref is a local path remote (/home/kara/code-factory) still at 79e9b59 and lacks the row, but `origin` is not the published remote — `gh` is, and it carries the row; the criterion's intent (row present on the published tree) is met.
CF-161 is filed exactly once as a pending P3 row with full acceptance criteria naming both local-only tag targets and both re-runnable measurements, the board diff is strictly insert-only, boardctl validate prints RESULT: OK, selftest prints SELFTEST: PASS, and the row is present on the published GitHub remote (gh/main = c2a6a45, bare clone of the remote lists zero tags).

Overall: PASS ✓

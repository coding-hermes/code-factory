# Verdict: CF-087-QA1

**Task:** QA filing: node-create staged-set validator coverage (CF-087)
**Evaluated:** 2026-11-03T16:32:50.420107
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The commit adds exactly one board row CF-087 (status pending, non-empty probe, priority P3) to .coding-hermes/board/tasks.jsonl, insert-only (line count +1, zero deletions), and CF-087 appears exactly once in the COMMITTED tree. Its probe, extracted from the committed board with jq, runs from the repo root and prints 'braced-entry rc=0', 'literal-lib rc=0' and a four-line manifest — i.e. scripts/node-create.sh --staged-files accepts a ${HERE}/ reference in project-node.sh and a $HERE/ reference in scripts/lib.sh without a FAIL row. scripts/boardctl validate prints RESULT: OK and bash tests/selftest.sh prints SELFTEST: PASS at the same tip. This criterion grades the FILING only: the underlying validator fix is future work tracked by pending row CF-087 and is NOT expected at this commit.: Row shape: `git show HEAD -- .coding-hermes/board/tasks.jsonl | grep '^+' | python3 -c json.loads` -> id: CF-087, status: pending, priority: P3, probe len: 597 (non-empty). Insert-only: `git show HEAD --numstat` -> `1	0	.coding-hermes/board/tasks.jsonl` and `1	0	.coding-hermes/board/events.jsonl` (2 insertions, 0 deletions); line count `git show HEAD^:...tasks.jsonl | wc -l` = 73 vs `git show HEAD:...` = 74 (+1). Uniqueness: `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c CF-087` = 1 (git grep -c on committed tree also = 1). Probe run from repo root (/home/kara/code-factory) via `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-087") | .probe' > /tmp/p.sh; bash /tmp/p.sh` -> EXIT=0, stdout exactly 4 lines: 'braced-entry rc=0', 'literal-lib rc=0', 'harness/install-hermes.sh', 'harness/install-hermes.sh'; stderr empty; `grep -i fail` on probe output -> 'no FAIL rows'. scripts/boardctl validate -> 'RESULT: OK (23 warning(s))', exit 0 (warnings are the pre-existing probe-key-outside-canon class, incl. line 74 CF-087). bash tests/selftest.sh -> 'SELFTEST: PASS', exit 0, 40 '  PASS' rows; the single '  FAIL  disk_floor — resolver missing or unreadable' line at output line 54 is the intentional fixture output of the missing-disk-floor arm (tests/selftest.sh:423-433), immediately followed by its PASS row and NODE: FAIL (1).
Commit 839b773 adds exactly one insert-only CF-087 row (pending, P3, 597-char probe) whose jq-extracted probe prints the two rc=0 lines plus a four-line manifest with no FAIL row, and boardctl validate (RESULT: OK) and tests/selftest.sh (SELFTEST: PASS) both pass at the same tip.

## Summary

Judge Result: CF-087-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The commit adds exactly one board row CF-087 (status pending, non-empty probe, priority P3) to .coding-hermes/board/tasks.jsonl, insert-only (line count +1, zero deletions), and CF-087 appears exactly once in the COMMITTED tree. Its probe, extracted from the committed board with jq, runs from the repo root and prints 'braced-entry rc=0', 'literal-lib rc=0' and a four-line manifest — i.e. scripts/node-create.sh --staged-files accepts a ${HERE}/ reference in project-node.sh and a $HERE/ reference in scripts/lib.sh without a FAIL row. scripts/boardctl validate prints RESULT: OK and bash tests/selftest.sh prints SELFTEST: PASS at the same tip. This criterion grades the FILING only: the underlying validator fix is future work tracked by pending row CF-087 and is NOT expected at this commit.: Row shape: `git show HEAD -- .coding-hermes/board/tasks.jsonl | grep '^+' | python3 -c json.loads` -> id: CF-087, status: pending, priority: P3, probe len: 597 (non-empty). Insert-only: `git show HEAD --numstat` -> `1	0	.coding-hermes/board/tasks.jsonl` and `1	0	.coding-hermes/board/events.jsonl` (2 insertions, 0 deletions); line count `git show HEAD^:...tasks.jsonl | wc -l` = 73 vs `git show HEAD:...` = 74 (+1). Uniqueness: `git show HEAD:.coding-hermes/board/tasks.jsonl | grep -c CF-087` = 1 (git grep -c on committed tree also = 1). Probe run from repo root (/home/kara/code-factory) via `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-087") | .probe' > /tmp/p.sh; bash /tmp/p.sh` -> EXIT=0, stdout exactly 4 lines: 'braced-entry rc=0', 'literal-lib rc=0', 'harness/install-hermes.sh', 'harness/install-hermes.sh'; stderr empty; `grep -i fail` on probe output -> 'no FAIL rows'. scripts/boardctl validate -> 'RESULT: OK (23 warning(s))', exit 0 (warnings are the pre-existing probe-key-outside-canon class, incl. line 74 CF-087). bash tests/selftest.sh -> 'SELFTEST: PASS', exit 0, 40 '  PASS' rows; the single '  FAIL  disk_floor — resolver missing or unreadable' line at output line 54 is the intentional fixture output of the missing-disk-floor arm (tests/selftest.sh:423-433), immediately followed by its PASS row and NODE: FAIL (1).
Commit 839b773 adds exactly one insert-only CF-087 row (pending, P3, 597-char probe) whose jq-extracted probe prints the two rc=0 lines plus a four-line manifest with no FAIL row, and boardctl validate (RESULT: OK) and tests/selftest.sh (SELFTEST: PASS) both pass at the same tip.

Overall: PASS ✓

# Verdict: CF-SYNC-0842REFIRE

**Task:** sync re-fire: refresh docs/BOARD.md measured-state block to the published tip
**Evaluated:** 2026-11-04T08:44:28.145355
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. docs/BOARD.md Current measured state names tip 202fb61 with 156 task rows / 295 events / 50 complete / 8 in_progress / 98 pending, each equal to wc -l and jq census on .coding-hermes/board/*.jsonl at that tip.: docs/BOARD.md:120-121 reads '**Re-measured 2026-11-04T08:42Z at tip `202fb61`:** 156 task rows, 295 events — 50 `complete`, 8 `in_progress`, 98 `pending`.' Independently reproduced at that tip: `git show 202fb61:.coding-hermes/board/tasks.jsonl | wc -l` = 156, events = 295, `jq -r .status | sort | uniq -c` = 50 complete / 8 in_progress / 98 pending. `git diff --stat 202fb61 HEAD -- .coding-hermes/board/` is empty, so the working-tree census (same numbers) is the tip's census.
  ✓ 2. The superseded dae4e7a bullet is retained and labelled historical.: docs/BOARD.md:128 retains the bullet, relabelled '**Earlier snapshot, 2026-11-04T03:01Z at tip `dae4e7a` (historical, not current):** 127 task rows, 193 events — 40 `complete`, 5 `in_progress`, 82 `pending`.' `git show d1342ac -- docs/BOARD.md` shows only the label line changed; the old figures are kept verbatim, and `git cat-file -t dae4e7a` confirms the commit exists.
  ✓ 3. bash tests/selftest.sh prints SELFTEST: PASS and PASS 156/156 rows parse.: Ran `bash tests/selftest.sh` (the .gitreins/config.yaml test_command) fresh: exit=0, output contains 'SELFTEST: PASS' and '  PASS  156/156 rows parse'; 119 '  PASS' rows and 19 '  FAIL' rows (all inside intentional negative fixtures), matching BOARD.md:124.
  ✓ 4. bash scripts/boardctl validate prints RESULT: OK.: Ran `bash scripts/boardctl validate`: exit=0, output 'rows: 156 tasks, 295 events, 0 fixtures', 'key uniformity: 156/156 rows carry only canon keys (0 drift)', 'RESULT: OK (3 warning(s))' — exactly the claim at docs/BOARD.md:121-123.
  ✓ 5. docs/audits/code-factory-sync-2026-11-04-0842-refire.md records the commands and outputs quoted.: docs/audits/code-factory-sync-2026-11-04-0842-refire.md:24-35 tabulates the commands and outputs: `wc -l` tasks=156 / events=295, `jq -r .status | sort | uniq -c` = 50 complete / 8 in_progress / 98 pending, `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', rc 0, 'key uniformity: 156/156 rows carry only canon keys (0 drift)'; lines 47-49 and the 'Gates at the landing tree' block record `bash tests/selftest.sh` -> 'SELFTEST: PASS', 'PASS 156/156 rows parse', 119 PASS / 19 FAIL rows. Every quoted figure was independently reproduced above.
All five criteria verified: BOARD.md names tip 202fb61 with counts matching the actual wc -l/jq census at that tip, the dae4e7a bullet is retained and labelled historical, selftest prints SELFTEST: PASS and PASS 156/156 rows parse, boardctl validate prints RESULT: OK, and the audit artifact records the commands and outputs.

## Summary

Judge Result: CF-SYNC-0842REFIRE

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. docs/BOARD.md Current measured state names tip 202fb61 with 156 task rows / 295 events / 50 complete / 8 in_progress / 98 pending, each equal to wc -l and jq census on .coding-hermes/board/*.jsonl at that tip.: docs/BOARD.md:120-121 reads '**Re-measured 2026-11-04T08:42Z at tip `202fb61`:** 156 task rows, 295 events — 50 `complete`, 8 `in_progress`, 98 `pending`.' Independently reproduced at that tip: `git show 202fb61:.coding-hermes/board/tasks.jsonl | wc -l` = 156, events = 295, `jq -r .status | sort | uniq -c` = 50 complete / 8 in_progress / 98 pending. `git diff --stat 202fb61 HEAD -- .coding-hermes/board/` is empty, so the working-tree census (same numbers) is the tip's census.
  ✓ 2. The superseded dae4e7a bullet is retained and labelled historical.: docs/BOARD.md:128 retains the bullet, relabelled '**Earlier snapshot, 2026-11-04T03:01Z at tip `dae4e7a` (historical, not current):** 127 task rows, 193 events — 40 `complete`, 5 `in_progress`, 82 `pending`.' `git show d1342ac -- docs/BOARD.md` shows only the label line changed; the old figures are kept verbatim, and `git cat-file -t dae4e7a` confirms the commit exists.
  ✓ 3. bash tests/selftest.sh prints SELFTEST: PASS and PASS 156/156 rows parse.: Ran `bash tests/selftest.sh` (the .gitreins/config.yaml test_command) fresh: exit=0, output contains 'SELFTEST: PASS' and '  PASS  156/156 rows parse'; 119 '  PASS' rows and 19 '  FAIL' rows (all inside intentional negative fixtures), matching BOARD.md:124.
  ✓ 4. bash scripts/boardctl validate prints RESULT: OK.: Ran `bash scripts/boardctl validate`: exit=0, output 'rows: 156 tasks, 295 events, 0 fixtures', 'key uniformity: 156/156 rows carry only canon keys (0 drift)', 'RESULT: OK (3 warning(s))' — exactly the claim at docs/BOARD.md:121-123.
  ✓ 5. docs/audits/code-factory-sync-2026-11-04-0842-refire.md records the commands and outputs quoted.: docs/audits/code-factory-sync-2026-11-04-0842-refire.md:24-35 tabulates the commands and outputs: `wc -l` tasks=156 / events=295, `jq -r .status | sort | uniq -c` = 50 complete / 8 in_progress / 98 pending, `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', rc 0, 'key uniformity: 156/156 rows carry only canon keys (0 drift)'; lines 47-49 and the 'Gates at the landing tree' block record `bash tests/selftest.sh` -> 'SELFTEST: PASS', 'PASS 156/156 rows parse', 119 PASS / 19 FAIL rows. Every quoted figure was independently reproduced above.
All five criteria verified: BOARD.md names tip 202fb61 with counts matching the actual wc -l/jq census at that tip, the dae4e7a bullet is retained and labelled historical, selftest prints SELFTEST: PASS and PASS 156/156 rows parse, boardctl validate prints RESULT: OK, and the audit artifact records the commands and outputs.

Overall: PASS ✓

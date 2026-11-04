# Verdict: CFDB-SYNC-2026110403-R3

**Task:** Sync re-fire landed at 4bf29e9 graded on the landed tree
**Evaluated:** 2026-11-04T03:06:21.391987
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ docs/audits/code-factory-duckbrain-sync-2026-11-04.md carries a 'Verification addendum' and a 'Landing-tip delta' section for tick code-factory-duckbrain-sync-2026-11-04-02-39-26, and every census figure it states is labelled with the tip it was measured at; docs/BOARD.md and docs/ACCEPTANCE-PLAN.md name CF-154 and CF-155 as the rows owning the structural fix; on the graded tree tasks.jsonl parses with no duplicate ids and every complete row carries a commit_hash that is reachable from origin/main, and events.jsonl parses.: Audit doc: line 163 '## Verification addendum — re-fire of tick `code-factory-duckbrain-sync-2026-11-04-02-39-26`' (measured at dae4e7a); line 241 '### Landing-tip delta — the board moved during this tick's rebase' (measured again at e9f3085). Census figures are tip-labelled: addendum tables header 'Result at `dae4e7a`', delta table header 'At `e9f3085`'; docs/BOARD.md:92 'Re-measured 2026-11-04T03:01Z at tip `dae4e7a`'; docs/ACCEPTANCE-PLAN.md:19 'Delta measured 2026-11-04 03:01 at tip `dae4e7a`'. Owning rows: docs/BOARD.md:97-98 '**CF-154** (the warning count does not follow from the board) and **CF-155** (the plan is stale by one selftest section)'; docs/ACCEPTANCE-PLAN.md:22 'CF-154 and CF-155 own the structural fix for this block.' Graded tree at 4bf29e9 (working tree clean): python json parse of .coding-hermes/board/tasks.jsonl -> 'rows 129 parse_fail 0', 'dup ids []', 'complete 40', 'complete missing commit_hash []', 'unreachable []' (each sha checked with `git cat-file -e <sha>^{commit}` and `git merge-base --is-ancestor <sha> origin/main`); events.jsonl -> 'events 199 bad 0 dup event ids []'. Test evidence: `bash tests/selftest.sh` exit_code 0, output 'SELFTEST: PASS' and 'PASS 129/129 rows parse'; `bash scripts/boardctl validate` exit_code 0, 'RESULT: OK (3 warning(s))'.


## Summary

Judge Result: CFDB-SYNC-2026110403-R3

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ docs/audits/code-factory-duckbrain-sync-2026-11-04.md carries a 'Verification addendum' and a 'Landing-tip delta' section for tick code-factory-duckbrain-sync-2026-11-04-02-39-26, and every census figure it states is labelled with the tip it was measured at; docs/BOARD.md and docs/ACCEPTANCE-PLAN.md name CF-154 and CF-155 as the rows owning the structural fix; on the graded tree tasks.jsonl parses with no duplicate ids and every complete row carries a commit_hash that is reachable from origin/main, and events.jsonl parses.: Audit doc: line 163 '## Verification addendum — re-fire of tick `code-factory-duckbrain-sync-2026-11-04-02-39-26`' (measured at dae4e7a); line 241 '### Landing-tip delta — the board moved during this tick's rebase' (measured again at e9f3085). Census figures are tip-labelled: addendum tables header 'Result at `dae4e7a`', delta table header 'At `e9f3085`'; docs/BOARD.md:92 'Re-measured 2026-11-04T03:01Z at tip `dae4e7a`'; docs/ACCEPTANCE-PLAN.md:19 'Delta measured 2026-11-04 03:01 at tip `dae4e7a`'. Owning rows: docs/BOARD.md:97-98 '**CF-154** (the warning count does not follow from the board) and **CF-155** (the plan is stale by one selftest section)'; docs/ACCEPTANCE-PLAN.md:22 'CF-154 and CF-155 own the structural fix for this block.' Graded tree at 4bf29e9 (working tree clean): python json parse of .coding-hermes/board/tasks.jsonl -> 'rows 129 parse_fail 0', 'dup ids []', 'complete 40', 'complete missing commit_hash []', 'unreachable []' (each sha checked with `git cat-file -e <sha>^{commit}` and `git merge-base --is-ancestor <sha> origin/main`); events.jsonl -> 'events 199 bad 0 dup event ids []'. Test evidence: `bash tests/selftest.sh` exit_code 0, output 'SELFTEST: PASS' and 'PASS 129/129 rows parse'; `bash scripts/boardctl validate` exit_code 0, 'RESULT: OK (3 warning(s))'.


Overall: PASS ✓

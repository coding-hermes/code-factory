# Verdict: CF-181

**Task:** File CF-181: CF-077's closure verdict binds a rewritten commit, a class the board census cannot see
**Evaluated:** 2026-11-04T08:36:02.465620
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ CF-181 board row, its reproduction tool and the sync evidence artifact land in one board/docs commit; at that commit `jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl` prints one pending row whose acceptance_criteria carries the numbered legs including the orphan reproduction, `python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl origin/main` prints verdict_artifacts_checked=21 with exactly one ORPHANED line naming CF-077 and orphan_count=1, `bash scripts/boardctl validate` prints RESULT: OK, and `bash tests/selftest.sh` exits 0 (SELFTEST: PASS).: All sub-checks verified at HEAD 0e44db9 (git status --porcelain empty). (a) One commit: `git show --name-only HEAD` lists .coding-hermes/board/tasks.jsonl, .coding-hermes/board/events.jsonl, docs/ACCEPTANCE-PLAN.md, docs/audits/cf181-verdict-binding-sweep.py, docs/audits/code-factory-sync-2026-11-04-0824.md plus 4 fixtures — board row + reproduction tool + sync evidence artifact in a single board/docs commit. (b) `jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl` prints exactly one row: {"id":"CF-181",...,"status":"pending",...} with acceptance_criteria carrying numbered legs 0–4, leg 0 being the orphan reproduction command and leg 2 the red-arm fixtures (also confirmed from the committed blob via `git show HEAD:.coding-hermes/board/tasks.jsonl`). (c) `python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl origin/main` exit 0, output: 'ref=origin/main complete_rows=49' / 'verdict_artifacts_checked=21' / '=== ORPHANED ===' / 'CF-077 run=410022a2 artifact=.gitreins/history/2026-11-03/410022a2/verdict.json commit=1dfb58b8aa passed=True' (exactly one ORPHANED line) / 'orphan_count=1'. (d) `bash scripts/boardctl validate` exit 0, prints 'RESULT: OK (3 warning(s))' (warnings are pre-existing CF-034 free-form guard_result/ci_result and headerless board). (e) `bash tests/selftest.sh` exit 0 with tail 'SELFTEST: PASS'. Supporting evidence also reproduced: fixture clean arm prints orphan_count=0, orphan fixture prints one ORPHANED line naming CF-009 with orphan_count=1; `git merge-base --is-ancestor 1dfb58b8… origin/main` exits 1 while `…1232f7a0…` exits 0, and the verdict envelope/jq row hashes match the claimed SHAs.
CF-181's board row, reproduction tool and sync evidence artifact land in one commit, and at that commit the sweep prints verdict_artifacts_checked=21 with exactly one ORPHANED CF-077 line and orphan_count=1, boardctl validate prints RESULT: OK, and selftest exits 0 with SELFTEST: PASS.

## Summary

Judge Result: CF-181

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ CF-181 board row, its reproduction tool and the sync evidence artifact land in one board/docs commit; at that commit `jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl` prints one pending row whose acceptance_criteria carries the numbered legs including the orphan reproduction, `python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl origin/main` prints verdict_artifacts_checked=21 with exactly one ORPHANED line naming CF-077 and orphan_count=1, `bash scripts/boardctl validate` prints RESULT: OK, and `bash tests/selftest.sh` exits 0 (SELFTEST: PASS).: All sub-checks verified at HEAD 0e44db9 (git status --porcelain empty). (a) One commit: `git show --name-only HEAD` lists .coding-hermes/board/tasks.jsonl, .coding-hermes/board/events.jsonl, docs/ACCEPTANCE-PLAN.md, docs/audits/cf181-verdict-binding-sweep.py, docs/audits/code-factory-sync-2026-11-04-0824.md plus 4 fixtures — board row + reproduction tool + sync evidence artifact in a single board/docs commit. (b) `jq -c 'select(.id=="CF-181")' .coding-hermes/board/tasks.jsonl` prints exactly one row: {"id":"CF-181",...,"status":"pending",...} with acceptance_criteria carrying numbered legs 0–4, leg 0 being the orphan reproduction command and leg 2 the red-arm fixtures (also confirmed from the committed blob via `git show HEAD:.coding-hermes/board/tasks.jsonl`). (c) `python3 docs/audits/cf181-verdict-binding-sweep.py . .coding-hermes/board/tasks.jsonl origin/main` exit 0, output: 'ref=origin/main complete_rows=49' / 'verdict_artifacts_checked=21' / '=== ORPHANED ===' / 'CF-077 run=410022a2 artifact=.gitreins/history/2026-11-03/410022a2/verdict.json commit=1dfb58b8aa passed=True' (exactly one ORPHANED line) / 'orphan_count=1'. (d) `bash scripts/boardctl validate` exit 0, prints 'RESULT: OK (3 warning(s))' (warnings are pre-existing CF-034 free-form guard_result/ci_result and headerless board). (e) `bash tests/selftest.sh` exit 0 with tail 'SELFTEST: PASS'. Supporting evidence also reproduced: fixture clean arm prints orphan_count=0, orphan fixture prints one ORPHANED line naming CF-009 with orphan_count=1; `git merge-base --is-ancestor 1dfb58b8… origin/main` exits 1 while `…1232f7a0…` exits 0, and the verdict envelope/jq row hashes match the claimed SHAs.
CF-181's board row, reproduction tool and sync evidence artifact land in one commit, and at that commit the sweep prints verdict_artifacts_checked=21 with exactly one ORPHANED CF-077 line and orphan_count=1, boardctl validate prints RESULT: OK, and selftest exits 0 with SELFTEST: PASS.

Overall: PASS ✓

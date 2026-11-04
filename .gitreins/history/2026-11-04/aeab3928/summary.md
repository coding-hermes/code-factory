# Verdict: CF-206-OPS1

**Task:** P2 — the fleet ops census classifies code-factory as `docs` and judges it on nothing, so this family operational surface is outside every ops check
**Evaluated:** 2026-11-04T23:53:26.963514
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing, not fix. On a clean tip the board diff is insert-only: `git show --stat --oneline HEAD` names only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl with 1 insertion and 0 deletions each. The row is present in the COMMITTED tree: `jq -r 'select(.id=="CF-206") | .probe' .coding-hermes/board/tasks.jsonl` prints one non-empty physical line, and `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-206") | .probe'` prints the same line. Running that exact printed line from the repository root prints `docs` and exits 0 (today). `bash scripts/boardctl validate` reports RESULT: OK and `bash tests/selftest.sh` reports SELFTEST: PASS at the same tip. The census misclassification itself is PENDING by definition - do not evaluate or grade the fix, only the filing.: All sub-checks pass at tip 3f6115e (working tree clean except untracked .gitreins evaluator artifacts). (1) git show --stat --oneline HEAD names ONLY .coding-hermes/board/events.jsonl (1 +) and .coding-hermes/board/tasks.jsonl (1 +), "2 files changed, 2 insertions(+)", 0 deletions — insert-only. (2) jq extraction of .probe prints exactly 1 non-empty line (wc -l = 1) and git show HEAD:.coding-hermes/board/tasks.jsonl | jq output is byte-identical (cmp: BYTE_IDENTICAL, diff clean). (3) The exact printed line `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` was run from the repo root: printed `docs`, exit_code 0; raw --json confirms the documented misclassification (family code-factory, kind "docs", lanes include code-factory-ops, evidence container/orchestration/supervision empty and server_entrypoint false, gaps []) — misclassification is filed as PENDING and was not graded. (4) bash scripts/boardctl validate -> exit 0, RESULT: OK (4 warning(s)) with pre-existing legacy warnings on unrelated rows (CF-034 line 20, duplicate event id 337, headerless board). (5) bash tests/selftest.sh -> exit 0, final line SELFTEST: PASS (181/181 board rows parse; section 7b FAIL lines are expected negative-control gate output).
CF-206 is properly filed as an insert-only board commit at a clean tip whose probe reproduces the docs misclassification today, with both board validate and the selftest passing at tip 3f6115e.

## Summary

Judge Result: CF-206-OPS1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing, not fix. On a clean tip the board diff is insert-only: `git show --stat --oneline HEAD` names only .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl with 1 insertion and 0 deletions each. The row is present in the COMMITTED tree: `jq -r 'select(.id=="CF-206") | .probe' .coding-hermes/board/tasks.jsonl` prints one non-empty physical line, and `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-206") | .probe'` prints the same line. Running that exact printed line from the repository root prints `docs` and exits 0 (today). `bash scripts/boardctl validate` reports RESULT: OK and `bash tests/selftest.sh` reports SELFTEST: PASS at the same tip. The census misclassification itself is PENDING by definition - do not evaluate or grade the fix, only the filing.: All sub-checks pass at tip 3f6115e (working tree clean except untracked .gitreins evaluator artifacts). (1) git show --stat --oneline HEAD names ONLY .coding-hermes/board/events.jsonl (1 +) and .coding-hermes/board/tasks.jsonl (1 +), "2 files changed, 2 insertions(+)", 0 deletions — insert-only. (2) jq extraction of .probe prints exactly 1 non-empty line (wc -l = 1) and git show HEAD:.coding-hermes/board/tasks.jsonl | jq output is byte-identical (cmp: BYTE_IDENTICAL, diff clean). (3) The exact printed line `python3 ~/.hermes/scripts/fleet_ops_check.py --project code-factory --json | jq -r '.[0].kind'` was run from the repo root: printed `docs`, exit_code 0; raw --json confirms the documented misclassification (family code-factory, kind "docs", lanes include code-factory-ops, evidence container/orchestration/supervision empty and server_entrypoint false, gaps []) — misclassification is filed as PENDING and was not graded. (4) bash scripts/boardctl validate -> exit 0, RESULT: OK (4 warning(s)) with pre-existing legacy warnings on unrelated rows (CF-034 line 20, duplicate event id 337, headerless board). (5) bash tests/selftest.sh -> exit 0, final line SELFTEST: PASS (181/181 board rows parse; section 7b FAIL lines are expected negative-control gate output).
CF-206 is properly filed as an insert-only board commit at a clean tip whose probe reproduces the docs misclassification today, with both board validate and the selftest passing at tip 3f6115e.

Overall: PASS ✓

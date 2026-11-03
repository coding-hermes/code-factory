# Verdict: CF-SYNC-20261103

**Task:** Sync lane: rebind CF-011/CF-013 completion evidence to committed re-runnable artifacts
**Evaluated:** 2026-11-03T15:16:47.074264
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md records the re-run commands and captured output; boardctl validate RESULT OK; tests/selftest.sh PASS; both rows carry an evidence run whose artifact path exists in the committed tree.: (1) Doc exists and is committed: `git ls-files docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` returns the path and `git cat-file -e HEAD:docs/audits/...` => IN HEAD TREE. It records re-run commands + captured output for both rows, and every recorded command reproduces exactly: `grep -n 'CF-002' AGENTS.md` => `41: ... (CF-002).`; `grep -c 'CF-108' AGENTS.md` => 0; `grep -c 'historical measurement' README.md` => 1; the awk status-table check => `table rows: 6` with no MISSING COMMAND lines. (2) `boardctl validate` => `rows: 61 tasks, 66 events, 0 fixtures` / `RESULT: OK (17 warning(s))`, exit_code 0 — matches the doc verbatim. (3) `bash tests/selftest.sh` => `PASS  61/61 rows parse` and `SELFTEST: PASS`, exit_code 0 — matches the doc verbatim. (4) Board rows: `jq` on .coding-hermes/board/tasks.jsonl shows CF-011 and CF-013 each carry a second evidence run (`sync-20261103-cf011`, `sync-20261103-cf013`, ts 2026-11-03T15:14:56Z) with `artifacts:["docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md"]`, and that path exists in the committed tree (verified above); the historical run is preserved, not erased. Doc's provenance also checks out: `git rev-parse d4eec41^{tree}` => e0e7d250bcf9661cd924ab82fa586e419866081d, exactly the tree the doc claims. docs/BOARD.md was updated consistently (61 rows / 66 events / 17 warnings / 61-61 selftest) and the board diff touches only the CF-011/CF-013/CF-031 rows with no status changes.
The evidence-rebind audit doc is committed, its recorded commands and output reproduce exactly, boardctl validate returns RESULT: OK and tests/selftest.sh returns SELFTEST: PASS (both exit 0), and CF-011/CF-013 each carry a new evidence run pointing at that committed artifact.

## Summary

Judge Result: CF-SYNC-20261103

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md records the re-run commands and captured output; boardctl validate RESULT OK; tests/selftest.sh PASS; both rows carry an evidence run whose artifact path exists in the committed tree.: (1) Doc exists and is committed: `git ls-files docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` returns the path and `git cat-file -e HEAD:docs/audits/...` => IN HEAD TREE. It records re-run commands + captured output for both rows, and every recorded command reproduces exactly: `grep -n 'CF-002' AGENTS.md` => `41: ... (CF-002).`; `grep -c 'CF-108' AGENTS.md` => 0; `grep -c 'historical measurement' README.md` => 1; the awk status-table check => `table rows: 6` with no MISSING COMMAND lines. (2) `boardctl validate` => `rows: 61 tasks, 66 events, 0 fixtures` / `RESULT: OK (17 warning(s))`, exit_code 0 — matches the doc verbatim. (3) `bash tests/selftest.sh` => `PASS  61/61 rows parse` and `SELFTEST: PASS`, exit_code 0 — matches the doc verbatim. (4) Board rows: `jq` on .coding-hermes/board/tasks.jsonl shows CF-011 and CF-013 each carry a second evidence run (`sync-20261103-cf011`, `sync-20261103-cf013`, ts 2026-11-03T15:14:56Z) with `artifacts:["docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md"]`, and that path exists in the committed tree (verified above); the historical run is preserved, not erased. Doc's provenance also checks out: `git rev-parse d4eec41^{tree}` => e0e7d250bcf9661cd924ab82fa586e419866081d, exactly the tree the doc claims. docs/BOARD.md was updated consistently (61 rows / 66 events / 17 warnings / 61-61 selftest) and the board diff touches only the CF-011/CF-013/CF-031 rows with no status changes.
The evidence-rebind audit doc is committed, its recorded commands and output reproduce exactly, boardctl validate returns RESULT: OK and tests/selftest.sh returns SELFTEST: PASS (both exit 0), and CF-011/CF-013 each carry a new evidence run pointing at that committed artifact.

Overall: PASS ✓

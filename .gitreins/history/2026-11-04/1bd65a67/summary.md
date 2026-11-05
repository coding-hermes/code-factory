# Verdict: CF-071-QA

**Task:** QA re-verification of CF-071 public-bind auth gate
**Evaluated:** 2026-11-04T10:09:00.599963
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Re-run CF-071's own acceptance evidence at the published tip (43/43 CF-071 selftest rows PASS, SELFTEST: PASS from a clean worktree), then file a board row for each public-bind auth failure mode the row did not test, each with a falsifiable acceptance criterion; no source file may be modified by this QA task.: IN PROGRESS. Commit 7510b79 touches ONLY .coding-hermes/board/tasks.jsonl (2 insertions) -> no source file modified. Rows filed: CF-193 (P2, YAML-subset reader refuses list/flow/block-scalar configs -> "block absent (invalid YAML)"), CF-194 (P3, gate reads $HOME/.hermes/config.yaml vs HERMES_HOME). Both have falsifiable ACs (numbered, with commands/exit codes). CF-192 (occupied-port branch) was filed by a sibling lane at e5f52c5 and is disclosed as superseded/dropped as duplicate. Remaining: verify 43/43 CF-071 rows + SELFTEST: PASS at e0e73bd from clean worktree; verify the two rows' claims are real (not already covered by CF-071 arms); check board validity.
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-071-QA

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Re-run CF-071's own acceptance evidence at the published tip (43/43 CF-071 selftest rows PASS, SELFTEST: PASS from a clean worktree), then file a board row for each public-bind auth failure mode the row did not test, each with a falsifiable acceptance criterion; no source file may be modified by this QA task.: IN PROGRESS. Commit 7510b79 touches ONLY .coding-hermes/board/tasks.jsonl (2 insertions) -> no source file modified. Rows filed: CF-193 (P2, YAML-subset reader refuses list/flow/block-scalar configs -> "block absent (invalid YAML)"), CF-194 (P3, gate reads $HOME/.hermes/config.yaml vs HERMES_HOME). Both have falsifiable ACs (numbered, with commands/exit codes). CF-192 (occupied-port branch) was filed by a sibling lane at e5f52c5 and is disclosed as superseded/dropped as duplicate. Remaining: verify 43/43 CF-071 rows + SELFTEST: PASS at e0e73bd from clean worktree; verify the two rows' claims are real (not already covered by CF-071 arms); check board validity.
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

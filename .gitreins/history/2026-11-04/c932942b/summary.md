# Verdict: CF-182

**Task:** PRD blocker-list ids resolve in exactly one namespace, with a committed check and a red gate arm
**Evaluated:** 2026-11-04T10:09:15.649474
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ A committed docs/audits/prd-blocker-resolution.sh prints row=<status> or requirement-only for every CF-nnn cited in the PRD milestone blocker list and exits 0 at the tree, and exits nonzero when a cited id resolves to neither namespace; tests/selftest.sh carries an arm that prints PASS prd-blocker on the real PRD and PASS prd-blocker-red on a fixture citing CF-999, and SELFTEST: PASS with rc 0.: Script is committed (git ls-files lists docs/audits/prd-blocker-resolution.sh; last commit 6f110d8 'gate(prd): resolve every milestone blocker id in one namespace (CF-182)'; git status clean). Real run `bash docs/audits/prd-blocker-resolution.sh` -> EXIT=0 with one line per cited id: CF-001 row=in_progress, CF-002 row=in_progress, CF-004 row=pending, CF-080 row=pending, CF-110 requirement-only, CF-112 requirement-only, CF-131/132/133/136 row=pending, CF-137/138/139 row=in_progress, CF-150 row=pending, then 'RESULT: OK (14 ids: 12 rows, 2 requirement-only)'. The 14 ids exactly match the ids inside the PRD region docs/PRD-code-factory.md:73-96 (milestone-blockers:begin/end) — no cited id is skipped. Red path: injecting `CF-999` into the marker region on a copy of the real PRD yields 'CF-999 UNRESOLVED' + 'FAIL prd-blocker: CF-999 unresolved — neither a board row nor a requirements-table row carries it' + 'RESULT: FAIL (1)' with EXIT=1 (script lines 120-123, 47-48). tests/selftest.sh:1866-1913 carries the arms (real PRD at :1873, CF-999 fixture at :1885-1888, plus a closed-row arm at :1894-1909). Fresh full run of the configured test command `bash tests/selftest.sh` -> EXIT=0; log lines 284-286: 'PASS  prd-blocker — 14 cited ids, 12 rows, 2 requirement-only, exit 0', 'PASS  prd-blocker-red — CF-999 unresolved, exit 1', 'PASS  prd-blocker-closed — CF-009 complete, exit 1', followed by 'SELFTEST: PASS'.
The committed prd-blocker-resolution.sh resolves all 14 PRD-cited ids (12 row=<status>, 2 requirement-only) with exit 0, exits 1 on an unresolved CF-999, and tests/selftest.sh prints PASS prd-blocker and PASS prd-blocker-red with SELFTEST: PASS at rc 0.

## Summary

Judge Result: CF-182

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ A committed docs/audits/prd-blocker-resolution.sh prints row=<status> or requirement-only for every CF-nnn cited in the PRD milestone blocker list and exits 0 at the tree, and exits nonzero when a cited id resolves to neither namespace; tests/selftest.sh carries an arm that prints PASS prd-blocker on the real PRD and PASS prd-blocker-red on a fixture citing CF-999, and SELFTEST: PASS with rc 0.: Script is committed (git ls-files lists docs/audits/prd-blocker-resolution.sh; last commit 6f110d8 'gate(prd): resolve every milestone blocker id in one namespace (CF-182)'; git status clean). Real run `bash docs/audits/prd-blocker-resolution.sh` -> EXIT=0 with one line per cited id: CF-001 row=in_progress, CF-002 row=in_progress, CF-004 row=pending, CF-080 row=pending, CF-110 requirement-only, CF-112 requirement-only, CF-131/132/133/136 row=pending, CF-137/138/139 row=in_progress, CF-150 row=pending, then 'RESULT: OK (14 ids: 12 rows, 2 requirement-only)'. The 14 ids exactly match the ids inside the PRD region docs/PRD-code-factory.md:73-96 (milestone-blockers:begin/end) — no cited id is skipped. Red path: injecting `CF-999` into the marker region on a copy of the real PRD yields 'CF-999 UNRESOLVED' + 'FAIL prd-blocker: CF-999 unresolved — neither a board row nor a requirements-table row carries it' + 'RESULT: FAIL (1)' with EXIT=1 (script lines 120-123, 47-48). tests/selftest.sh:1866-1913 carries the arms (real PRD at :1873, CF-999 fixture at :1885-1888, plus a closed-row arm at :1894-1909). Fresh full run of the configured test command `bash tests/selftest.sh` -> EXIT=0; log lines 284-286: 'PASS  prd-blocker — 14 cited ids, 12 rows, 2 requirement-only, exit 0', 'PASS  prd-blocker-red — CF-999 unresolved, exit 1', 'PASS  prd-blocker-closed — CF-009 complete, exit 1', followed by 'SELFTEST: PASS'.
The committed prd-blocker-resolution.sh resolves all 14 PRD-cited ids (12 row=<status>, 2 requirement-only) with exit 0, exits 1 on an unresolved CF-999, and tests/selftest.sh prints PASS prd-blocker and PASS prd-blocker-red with SELFTEST: PASS at rc 0.

Overall: PASS ✓

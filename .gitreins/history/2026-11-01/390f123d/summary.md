# Verdict: CF-007

**Task:** Node sizing and disk policy
**Evaluated:** 2026-11-01T03:54:42.103511
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Implement CF-007 acceptance: documented measured floor; below-floor refusal names number before install; eligible reclaim and remeasure; boundary tests; residue reaping/reporting boundary; preserve no-root and check purity. Include fresh row-specific trace artifact and verify selftest, disk contract, board validation.: Multiple hard failures. (1) Disk contract is red: `python3 -B tests/disk-contract.py` -> `Ran 18 tests ... FAILED (failures=53)`, exit 2; 17 of 18 tests fail (only test_helper_rejects_caller_selected_reclaim_root passes). Key errors: `unknown arg: --reclaim-disposable` (tests/disk-contract.py:233,244,426), `AssertionError: 0 != 1` at tests/disk-contract.py:554 (refusal-removal mutation needle absent), and `'invalid disk policy arguments' not found in '  FAIL  disk —  GB free < floor 5 GB ...'`. (2) Reclaim/remeasure is not wired into provisioning: scripts/project-node.sh:45 is `require_disk "$HOME" "$FLOOR" || true` — it never calls scripts/disk-policy.py, has no `--reclaim-disposable` flag (arg parser at project-node.sh:23-31 rejects it with `unknown arg`), and `|| true` swallows the refusal so install/clone continue below floor. scripts/node-create.sh contains no floor/reclaim forwarding (grep for reclaim/disk-policy in scripts/*.sh returns only lib.sh:35 and project-node.sh:45). (3) Boundary tests are absent from the mandated suite: `grep -n disk tests/selftest.sh` returns no matches, so the selftest has no disk-floor boundary fixture (docs/ACCEPTANCE-PLAN.md:21 still records CF-109 as PARTIAL: 'Current selftest has no disk-floor boundary fixture'). (4) Board validation: `grep -n 'CF-007' docs/BOARD.md` returns nothing — no CF-007 row exists to validate. (5) Trace artifact is not fresh/row-specific to this commit: docs/audits/code-factory-CF-007-160038.md and -verdict.json cite `commit=37ee7c9d41d1d80741836455f797d70b4b9a1ed6`, which is not in the current history (HEAD is c078906), and the last commit c078906 is a tree-restore that reverted the disk-policy wiring. (6) Selftest does pass (`bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0, 36/36 board rows parse), but it exercises none of the CF-007 disk predicates, so it cannot evidence this criterion. Documented floor text exists (docs/OPERATIONS.md:36, specs/NODE.md:42-46, lib.sh:34-44 names the number), but the acceptance as a whole is not implemented.
CF-007 is not implemented: the disk contract fails 53 assertions across 17/18 tests, project-node.sh never invokes disk-policy.py or supports --reclaim-disposable, selftest has no disk boundary fixtures, the board has no CF-007 row, and the trace artifact points at a commit absent from history.

## Summary

Judge Result: CF-007

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Implement CF-007 acceptance: documented measured floor; below-floor refusal names number before install; eligible reclaim and remeasure; boundary tests; residue reaping/reporting boundary; preserve no-root and check purity. Include fresh row-specific trace artifact and verify selftest, disk contract, board validation.: Multiple hard failures. (1) Disk contract is red: `python3 -B tests/disk-contract.py` -> `Ran 18 tests ... FAILED (failures=53)`, exit 2; 17 of 18 tests fail (only test_helper_rejects_caller_selected_reclaim_root passes). Key errors: `unknown arg: --reclaim-disposable` (tests/disk-contract.py:233,244,426), `AssertionError: 0 != 1` at tests/disk-contract.py:554 (refusal-removal mutation needle absent), and `'invalid disk policy arguments' not found in '  FAIL  disk —  GB free < floor 5 GB ...'`. (2) Reclaim/remeasure is not wired into provisioning: scripts/project-node.sh:45 is `require_disk "$HOME" "$FLOOR" || true` — it never calls scripts/disk-policy.py, has no `--reclaim-disposable` flag (arg parser at project-node.sh:23-31 rejects it with `unknown arg`), and `|| true` swallows the refusal so install/clone continue below floor. scripts/node-create.sh contains no floor/reclaim forwarding (grep for reclaim/disk-policy in scripts/*.sh returns only lib.sh:35 and project-node.sh:45). (3) Boundary tests are absent from the mandated suite: `grep -n disk tests/selftest.sh` returns no matches, so the selftest has no disk-floor boundary fixture (docs/ACCEPTANCE-PLAN.md:21 still records CF-109 as PARTIAL: 'Current selftest has no disk-floor boundary fixture'). (4) Board validation: `grep -n 'CF-007' docs/BOARD.md` returns nothing — no CF-007 row exists to validate. (5) Trace artifact is not fresh/row-specific to this commit: docs/audits/code-factory-CF-007-160038.md and -verdict.json cite `commit=37ee7c9d41d1d80741836455f797d70b4b9a1ed6`, which is not in the current history (HEAD is c078906), and the last commit c078906 is a tree-restore that reverted the disk-policy wiring. (6) Selftest does pass (`bash tests/selftest.sh` -> `SELFTEST: PASS`, exit 0, 36/36 board rows parse), but it exercises none of the CF-007 disk predicates, so it cannot evidence this criterion. Documented floor text exists (docs/OPERATIONS.md:36, specs/NODE.md:42-46, lib.sh:34-44 names the number), but the acceptance as a whole is not implemented.
CF-007 is not implemented: the disk contract fails 53 assertions across 17/18 tests, project-node.sh never invokes disk-policy.py or supports --reclaim-disposable, selftest has no disk boundary fixtures, the board has no CF-007 row, and the trace artifact points at a commit absent from history.

Overall: FAIL ✗

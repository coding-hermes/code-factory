# Verdict: CF-003

**Task:** Per-repo deploy key + node runtime + shared module cache
**Evaluated:** 2026-11-07T17:59:06.245267
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Advance CF-003 acceptance criteria with tested implementation; preserve live handbook-owned paths; commit code and tests.: TESTED IMPLEMENTATION: `python3 tests/test_node_provisioning.py` -> "Ran 23 tests in 4.642s / OK" (exit 0). Fresh `bash tests/selftest.sh` -> "SELFTEST: PASS", EXIT=0, 429 PASS rows / 61 FAIL rows (all negative fixtures) / 0 SKIP — matching the commit message exactly. Section 58 all 12 rows PASS, including the 6 new spawn-gate arms (public.key, junk.key, encrypted key, HTTPS remote each refused with exit 1 before any agent exists; a green control admits a usable key and continues to server_declared; a red proof that pre-fix 4f32a50 accepted the public key). `bash -n $(git ls-files "*.sh")` -> LINT_OK. `bash scripts/boardctl validate` -> "RESULT: OK (7 warning(s))" (pre-existing only). ACCEPTANCE CRITERIA ADVANCED: docs/ACCEPTANCE-PLAN.md §58 row rewritten in HEAD to name the `deploy_key:loadable` / `deploy_key:repo` refusals and the 4f32a50 red proof; specs/NODE.md credentials section now documents the ssh-keygen -y loadability and SSH-remote requirements; scripts/node-create.sh:115-141 implements the gate ahead of the spawn at :199, keeping the pre-existing unreadable/0644/no-repo refusals. HANDBOOK-OWNED PATHS PRESERVED: HEAD (5ffb87b) touches zero docs/handbook/ files — only docs/ACCEPTANCE-PLAN.md, scripts/node-create.sh, specs/NODE.md, tests/selftest.sh — and it moved the ch:trace spec= OFF the non-resolving docs/handbook/OUTLINE.md#part-iii-m1-m5-f2 anchor onto specs/NODE.md#credentials--per-repo-deploy-keys; `git status --porcelain` returns 0 lines, so no live/uncommitted handbook workstream was disturbed. COMMITTED CODE AND TESTS: commit 5ffb87b, 4 files, +133/-9, including tests/selftest.sh (+86) and scripts/node-create.sh (+43), with "ch:trace: CF-003" in the message.
CF-003 advances with a real, discriminating spawn-gate fix backed by a fresh green selftest (429 PASS / 0 SKIP, exit 0) and 23 passing unit tests, leaves every docs/handbook/ path untouched, and commits both code and tests.

## Summary

Judge Result: CF-003

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Advance CF-003 acceptance criteria with tested implementation; preserve live handbook-owned paths; commit code and tests.: TESTED IMPLEMENTATION: `python3 tests/test_node_provisioning.py` -> "Ran 23 tests in 4.642s / OK" (exit 0). Fresh `bash tests/selftest.sh` -> "SELFTEST: PASS", EXIT=0, 429 PASS rows / 61 FAIL rows (all negative fixtures) / 0 SKIP — matching the commit message exactly. Section 58 all 12 rows PASS, including the 6 new spawn-gate arms (public.key, junk.key, encrypted key, HTTPS remote each refused with exit 1 before any agent exists; a green control admits a usable key and continues to server_declared; a red proof that pre-fix 4f32a50 accepted the public key). `bash -n $(git ls-files "*.sh")` -> LINT_OK. `bash scripts/boardctl validate` -> "RESULT: OK (7 warning(s))" (pre-existing only). ACCEPTANCE CRITERIA ADVANCED: docs/ACCEPTANCE-PLAN.md §58 row rewritten in HEAD to name the `deploy_key:loadable` / `deploy_key:repo` refusals and the 4f32a50 red proof; specs/NODE.md credentials section now documents the ssh-keygen -y loadability and SSH-remote requirements; scripts/node-create.sh:115-141 implements the gate ahead of the spawn at :199, keeping the pre-existing unreadable/0644/no-repo refusals. HANDBOOK-OWNED PATHS PRESERVED: HEAD (5ffb87b) touches zero docs/handbook/ files — only docs/ACCEPTANCE-PLAN.md, scripts/node-create.sh, specs/NODE.md, tests/selftest.sh — and it moved the ch:trace spec= OFF the non-resolving docs/handbook/OUTLINE.md#part-iii-m1-m5-f2 anchor onto specs/NODE.md#credentials--per-repo-deploy-keys; `git status --porcelain` returns 0 lines, so no live/uncommitted handbook workstream was disturbed. COMMITTED CODE AND TESTS: commit 5ffb87b, 4 files, +133/-9, including tests/selftest.sh (+86) and scripts/node-create.sh (+43), with "ch:trace: CF-003" in the message.
CF-003 advances with a real, discriminating spawn-gate fix backed by a fresh green selftest (429 PASS / 0 SKIP, exit 0) and 23 passing unit tests, leaves every docs/handbook/ path untouched, and commits both code and tests.

Overall: PASS ✓

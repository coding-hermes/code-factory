# Verdict: SCHED-GAP-16989

**Task:** Fleet ops census deploy-doc arm grades filename spelling not the deploy path
**Evaluated:** 2026-11-07T01:23:53.106972
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ fleet_ops_check.py deploy-doc check accepts a deploy-path artifact by basename hint under deploy/ or docs/ (deploy/README.md, docs/runbook-<topic>.md, INSTALL.md), the repo's existing seven canonical filenames still pass, a repo with no deploy artifact still reports P2, the patch chain in patches/ rebuilds to the live script digest, and the fleet census deploy-doc family count drops from 35 with no family gaining a new gap.: (a) Basename-hint acceptance: live ~/.hermes/scripts/fleet_ops_check.py:246-276 adds deploy_doc_hits() (DEPLOY_DOC_NAME_HINTS/DIR_HINTS/EXTS/DEPTH/SKIP_DIRS at :56-61), wired into the deploy-doc arm at :388-390. `python3 patches/fleet-ops-deploy-doc.test.py` exit_code=0, '7/7 arms passed': A deploy/README.md, B docs/runbook-drain-restart.md, C INSTALL.md all -> 'no gap'. (b) Canonical seven unchanged: DEPLOY_DOC tuple at :47-48 still lists DEPLOY.md/docs/deploy.md/docs/deployment.md/RUNBOOK.md/docs/runbook.md/OPERATIONS.md/docs/operations.md and exists_any/exists_ci are still consulted first (:388); arm D 'canonical docs/operations.md' PASS. (c) No-artifact repo still P2: arm E 'repo with no deploy artifact' want gap got gap PASS; add('deploy-doc', ..., 'P2' if kind=='service' else 'P3') at :390-391. (d) Chain rebuild: `bash scripts/verify-patch.sh` exit_code=0 — 'PASS base b0054326...', 'PASS stage shell-toolkit 82a3bf34...', 'PASS stage backup-heuristic 77d1deb2...', 'PASS stage ci-markers f393a681...', 'PASS stage deploy-doc 57432007...', 'PASS live: /home/kara/.hermes/scripts/fleet_ops_check.py matches the shipped chain (5 stages, 4 patches, 57432007b324f382a90bf7405a8bb50735a87a145ed95f5e0e5b782b964e7687)'. (e) Census drop: rebuilt the pre-fix module from patches/base through shell-toolkit+backup-heuristic+ci-markers (sha256 f393a681... = recorded ci-markers digest) and ran both modules with --json over the same 88 families: deploy-doc families 35 (pre-fix) -> 4 (post-fix: chimera-v2, coding-hermes-tools, hermes-canopy, musterflow); diff of gap sets shows zero families gaining a new gap (gained=[]), 31 families losing only the deploy-doc gap. Note: guards.test_command is `bash tests/selftest.sh`, but the module is not in the tree (patches/README.md), so the committed patch regression arms are the executable proof and they pass.
All legs verified: basename-hint deploy docs accepted, canonical seven and no-artifact P2 preserved, patch chain rebuilds to the live digest 57432007..., and the census deploy-doc family count drops 35 -> 4 with no family gaining a new gap.

## Summary

Judge Result: SCHED-GAP-16989

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ fleet_ops_check.py deploy-doc check accepts a deploy-path artifact by basename hint under deploy/ or docs/ (deploy/README.md, docs/runbook-<topic>.md, INSTALL.md), the repo's existing seven canonical filenames still pass, a repo with no deploy artifact still reports P2, the patch chain in patches/ rebuilds to the live script digest, and the fleet census deploy-doc family count drops from 35 with no family gaining a new gap.: (a) Basename-hint acceptance: live ~/.hermes/scripts/fleet_ops_check.py:246-276 adds deploy_doc_hits() (DEPLOY_DOC_NAME_HINTS/DIR_HINTS/EXTS/DEPTH/SKIP_DIRS at :56-61), wired into the deploy-doc arm at :388-390. `python3 patches/fleet-ops-deploy-doc.test.py` exit_code=0, '7/7 arms passed': A deploy/README.md, B docs/runbook-drain-restart.md, C INSTALL.md all -> 'no gap'. (b) Canonical seven unchanged: DEPLOY_DOC tuple at :47-48 still lists DEPLOY.md/docs/deploy.md/docs/deployment.md/RUNBOOK.md/docs/runbook.md/OPERATIONS.md/docs/operations.md and exists_any/exists_ci are still consulted first (:388); arm D 'canonical docs/operations.md' PASS. (c) No-artifact repo still P2: arm E 'repo with no deploy artifact' want gap got gap PASS; add('deploy-doc', ..., 'P2' if kind=='service' else 'P3') at :390-391. (d) Chain rebuild: `bash scripts/verify-patch.sh` exit_code=0 — 'PASS base b0054326...', 'PASS stage shell-toolkit 82a3bf34...', 'PASS stage backup-heuristic 77d1deb2...', 'PASS stage ci-markers f393a681...', 'PASS stage deploy-doc 57432007...', 'PASS live: /home/kara/.hermes/scripts/fleet_ops_check.py matches the shipped chain (5 stages, 4 patches, 57432007b324f382a90bf7405a8bb50735a87a145ed95f5e0e5b782b964e7687)'. (e) Census drop: rebuilt the pre-fix module from patches/base through shell-toolkit+backup-heuristic+ci-markers (sha256 f393a681... = recorded ci-markers digest) and ran both modules with --json over the same 88 families: deploy-doc families 35 (pre-fix) -> 4 (post-fix: chimera-v2, coding-hermes-tools, hermes-canopy, musterflow); diff of gap sets shows zero families gaining a new gap (gained=[]), 31 families losing only the deploy-doc gap. Note: guards.test_command is `bash tests/selftest.sh`, but the module is not in the tree (patches/README.md), so the committed patch regression arms are the executable proof and they pass.
All legs verified: basename-hint deploy docs accepted, canonical seven and no-artifact P2 preserved, patch chain rebuilds to the live digest 57432007..., and the census deploy-doc family count drops 35 -> 4 with no family gaining a new gap.

Overall: PASS ✓

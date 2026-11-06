# Verdict: CF-378-R1

**Task:** CF-378 verification close: the tailnet-address scrub and its selftest gate are present at HEAD
**Evaluated:** 2026-11-06T12:33:29.107922
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The CF-378 fix is present in the tree at HEAD and nothing else is claimed. Three facts each hold: (1) docs/MASTER-DOC-SCHEMA.md, docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md and docs/handbook/appendices/units/06-scripts-bunker-server-install-sh.md use <crier-host>, <duckbrain-host> and <ci-box> placeholders and each names the operator's own config as where the real value lives; (2) tests/selftest.sh carries a tailnet-address arm that prints a PASS row reporting 0 hits across the tracked tree outside .coding-hermes/board and .gitreins, and that arm asserts its own seeded-fixture FAIL row verbatim; (3) the only remaining matches of the CGNAT range are inside .gitreins/history verdict bundles, which are the surface of a different row (CF-050, stop publishing .gitreins) and are excluded from this row's criterion by amendment. The repair under grading is the doc scrub plus the gate, not any further change; do not require the .gitreins bundles to be rewritten and do not require any board write.: All three facts hold at HEAD (c42692c; fix commit 84ae65f touches only the 3 docs + tests/selftest.sh). (1) docs/MASTER-DOC-SCHEMA.md:125 `http://<crier-host>:8767` with :127-128 "the real value lives in the operator's own config on the control host"; 05-scripts-bunker-provision-sh.md:62,182,217 use `<crier-host>`/`<duckbrain-host>` with :174-178 "the real addresses live in the operator's own config (CRIER_URL/DUCKBRAIN_URL ...)"; 06-scripts-bunker-server-install-sh.md:208-210 "reads `http://<ci-box>:10001`: the real address is the one the operator's own `~/.config/bunker/config.yaml` names", :232 placeholder. (2) tests/selftest.sh:159-224 tailnet-address-gate; live run `bash tests/selftest.sh` (/tmp/selftest3.out:40-42) printed: "section 6 tailnet-address (CF-378): no tracked file outside the board publishes a tailnet address" / "PASS  tailnet-address — 0 tailnet-address hits in 278 tracked file(s) outside .coding-hermes/board and .gitreins" / "PASS  seeded fixture -> FAIL names docs/seeded.md:3; the out-of-range subnet stays green"; the arm asserts its seeded FAIL row verbatim via `grep -Fxc -- "$expected"` at selftest.sh:216-218 against the exact string at :215. (3) `git grep -lIE '100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' HEAD` returns only .coding-hermes/board (2 files) and 8 files under .gitreins/history/*/commit.patch|worktree.patch; excluding board+gitreins the same grep exits 1 with 0 lines, so no other surface carries the range. No board write or .gitreins rewrite is required by this row.
CF-378 is present at HEAD: the three docs carry the placeholders with operator-config pointers, the selftest tailnet arm prints a 0-hit PASS row and verbatim-asserts its seeded FAIL row (verified by a live suite run), and the only residual CGNAT matches are the CF-050-owned .gitreins/history bundles.

## Summary

Judge Result: CF-378-R1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The CF-378 fix is present in the tree at HEAD and nothing else is claimed. Three facts each hold: (1) docs/MASTER-DOC-SCHEMA.md, docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md and docs/handbook/appendices/units/06-scripts-bunker-server-install-sh.md use <crier-host>, <duckbrain-host> and <ci-box> placeholders and each names the operator's own config as where the real value lives; (2) tests/selftest.sh carries a tailnet-address arm that prints a PASS row reporting 0 hits across the tracked tree outside .coding-hermes/board and .gitreins, and that arm asserts its own seeded-fixture FAIL row verbatim; (3) the only remaining matches of the CGNAT range are inside .gitreins/history verdict bundles, which are the surface of a different row (CF-050, stop publishing .gitreins) and are excluded from this row's criterion by amendment. The repair under grading is the doc scrub plus the gate, not any further change; do not require the .gitreins bundles to be rewritten and do not require any board write.: All three facts hold at HEAD (c42692c; fix commit 84ae65f touches only the 3 docs + tests/selftest.sh). (1) docs/MASTER-DOC-SCHEMA.md:125 `http://<crier-host>:8767` with :127-128 "the real value lives in the operator's own config on the control host"; 05-scripts-bunker-provision-sh.md:62,182,217 use `<crier-host>`/`<duckbrain-host>` with :174-178 "the real addresses live in the operator's own config (CRIER_URL/DUCKBRAIN_URL ...)"; 06-scripts-bunker-server-install-sh.md:208-210 "reads `http://<ci-box>:10001`: the real address is the one the operator's own `~/.config/bunker/config.yaml` names", :232 placeholder. (2) tests/selftest.sh:159-224 tailnet-address-gate; live run `bash tests/selftest.sh` (/tmp/selftest3.out:40-42) printed: "section 6 tailnet-address (CF-378): no tracked file outside the board publishes a tailnet address" / "PASS  tailnet-address — 0 tailnet-address hits in 278 tracked file(s) outside .coding-hermes/board and .gitreins" / "PASS  seeded fixture -> FAIL names docs/seeded.md:3; the out-of-range subnet stays green"; the arm asserts its seeded FAIL row verbatim via `grep -Fxc -- "$expected"` at selftest.sh:216-218 against the exact string at :215. (3) `git grep -lIE '100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' HEAD` returns only .coding-hermes/board (2 files) and 8 files under .gitreins/history/*/commit.patch|worktree.patch; excluding board+gitreins the same grep exits 1 with 0 lines, so no other surface carries the range. No board write or .gitreins rewrite is required by this row.
CF-378 is present at HEAD: the three docs carry the placeholders with operator-config pointers, the selftest tailnet arm prints a 0-hit PASS row and verbatim-asserts its seeded FAIL row (verified by a live suite run), and the only residual CGNAT matches are the CF-050-owned .gitreins/history bundles.

Overall: PASS ✓

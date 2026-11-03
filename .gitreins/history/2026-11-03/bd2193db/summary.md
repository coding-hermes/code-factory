# Verdict: CF-032

**Task:** Narrow node layer 40 to the clone - spec and README claimed a build no script performs
**Evaluated:** 2026-11-03T08:40:03.848779
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the integrated HEAD: specs/NODE.md layer 40 row and README Status row claim clone-only with no build or build-cache claim; scripts/project-node.sh layer 40 prints clone evidence and no build claim; bash tests/selftest.sh exits 0 printing SELFTEST: PASS: HEAD 8f1e8c1, working tree clean. specs/NODE.md:30 layer 40 row now reads '| 40 repo | the repo cloned at a pinned ref | base |' (the 'build cache present' claim was removed in 6f75e28); NODE.md:44 states 'Build cache is not provisioned by shipped scripts and is excluded.' README.md:74 Status row reads 'Layer 40 clones only; no build step is shipped.' scripts/project-node.sh:88-118 layer 40 emits clone evidence only — ok "repo" "$RP @ $(git -C "$RP" rev-parse --short HEAD)" and ok "repo_clone" "$RP @ ..."; grep -i 'build|cache' on the script returns no matches. Test run: `bash tests/selftest.sh` -> EXIT=0 and output ends with 'SELFTEST: PASS' (grep -c = 1), including 'PASS missing ref names main and --ref without a private-repo hint' and 'PASS repository access failure retains deploy-key hint'.
Layer 40 is narrowed to clone-only in specs/NODE.md:30, README.md:74 and scripts/project-node.sh:88-118 with no build/build-cache claims, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS at HEAD 8f1e8c1.

## Summary

Judge Result: CF-032

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the integrated HEAD: specs/NODE.md layer 40 row and README Status row claim clone-only with no build or build-cache claim; scripts/project-node.sh layer 40 prints clone evidence and no build claim; bash tests/selftest.sh exits 0 printing SELFTEST: PASS: HEAD 8f1e8c1, working tree clean. specs/NODE.md:30 layer 40 row now reads '| 40 repo | the repo cloned at a pinned ref | base |' (the 'build cache present' claim was removed in 6f75e28); NODE.md:44 states 'Build cache is not provisioned by shipped scripts and is excluded.' README.md:74 Status row reads 'Layer 40 clones only; no build step is shipped.' scripts/project-node.sh:88-118 layer 40 emits clone evidence only — ok "repo" "$RP @ $(git -C "$RP" rev-parse --short HEAD)" and ok "repo_clone" "$RP @ ..."; grep -i 'build|cache' on the script returns no matches. Test run: `bash tests/selftest.sh` -> EXIT=0 and output ends with 'SELFTEST: PASS' (grep -c = 1), including 'PASS missing ref names main and --ref without a private-repo hint' and 'PASS repository access failure retains deploy-key hint'.
Layer 40 is narrowed to clone-only in specs/NODE.md:30, README.md:74 and scripts/project-node.sh:88-118 with no build/build-cache claims, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS at HEAD 8f1e8c1.

Overall: PASS ✓

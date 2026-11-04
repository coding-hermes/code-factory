# Verdict: CF-079-DOC1

**Task:** specs/NODE.md layer 30/90 cells name only shipped behaviour
**Evaluated:** 2026-11-04T02:47:38.719208
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Correct specs/NODE.md layer table cells 30 and 90 so each names only shipped behaviour, and add the paragraph that hands the unshipped capabilities to CF-004 and CF-068. Reproduce with: (a) `grep -n 'pull worker' specs/NODE.md` prints nothing (0 matching lines); (b) `grep -n '30 bus' specs/NODE.md` names only a crier identity file and its mode 600, `grep -n '90 verify' specs/NODE.md` names only the node manifest; (c) the paragraph names CF-004 and CF-068. Path that proves it: scripts/project-node.sh:241-252 prints only crier_identity/crier_mode for layer 30, and :288-316 prints only '[90] manifest' — run `HOME=$(mktemp -d) ./scripts/project-node.sh --check --project p --layers 30` and see the FAIL crier_identity row with no worker row. Gate: `bash tests/selftest.sh` prints SELFTEST: PASS (exit 0) and `bash scripts/boardctl validate` prints RESULT: OK. Evidence file: docs/audits/code-factory-docs-2026-11-04.md, which also states what is not measured. Do NOT evaluate CF-004's unbuilt round trip or CF-068's file-existence weakness; this change is documentation-only and those rows remain open.: (a) `grep -n 'pull worker' specs/NODE.md` -> exit=1, zero matching lines. (b) specs/NODE.md:29 `| 30 bus | a crier identity file at $HOME/.node/crier.json and its mode 600 | harness |` (identity file + mode 600 only, no worker); specs/NODE.md:31 `| 90 verify | the node manifest ($HOME/.node/node.json), written only when every layer passed | all |` (manifest only, no digest round trip). (c) New paragraph specs/NODE.md:33-48 names CF-068 at line 39 ('CF-068 owns the file-existence weakness this layer still has') and CF-004 at line 43 ('CF-004 owns building it'). Path proof confirmed by reading scripts/project-node.sh:241-252 (layer 30 emits only ok/bad crier_identity and crier_mode via `stat -c '%a'` vs 600; no process/socket/worker check) and :288-316 (prints `[90] manifest`, writes $STATE/node.json, no digest). Live run `HOME=$(mktemp -d) ./scripts/project-node.sh --check --project p --layers 30` -> exit=1, output `[30] bus` / `FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` with no worker row. Gates: `bash tests/selftest.sh` -> exit=0, line 145 `SELFTEST: PASS`; `bash scripts/boardctl validate` -> exit=0, `RESULT: OK (54 warning(s))`. Evidence file docs/audits/code-factory-docs-2026-11-04.md:99-105 has section 'Claims I could not verify — stated as not measured' covering the bus worker ('not measured') and the control-host digest round trip ('not measured, and not buildable from this repo; CF-004 owns it'), plus lines 18-19 naming CF-004 and CF-068. Diff is documentation-only (specs/NODE.md +20/-2, audit file +116).
specs/NODE.md layer 30/90 cells now name only shipped behaviour, the CF-004/CF-068 handoff paragraph is present, and both gates pass (SELFTEST: PASS exit 0, boardctl RESULT: OK).

## Summary

Judge Result: CF-079-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Correct specs/NODE.md layer table cells 30 and 90 so each names only shipped behaviour, and add the paragraph that hands the unshipped capabilities to CF-004 and CF-068. Reproduce with: (a) `grep -n 'pull worker' specs/NODE.md` prints nothing (0 matching lines); (b) `grep -n '30 bus' specs/NODE.md` names only a crier identity file and its mode 600, `grep -n '90 verify' specs/NODE.md` names only the node manifest; (c) the paragraph names CF-004 and CF-068. Path that proves it: scripts/project-node.sh:241-252 prints only crier_identity/crier_mode for layer 30, and :288-316 prints only '[90] manifest' — run `HOME=$(mktemp -d) ./scripts/project-node.sh --check --project p --layers 30` and see the FAIL crier_identity row with no worker row. Gate: `bash tests/selftest.sh` prints SELFTEST: PASS (exit 0) and `bash scripts/boardctl validate` prints RESULT: OK. Evidence file: docs/audits/code-factory-docs-2026-11-04.md, which also states what is not measured. Do NOT evaluate CF-004's unbuilt round trip or CF-068's file-existence weakness; this change is documentation-only and those rows remain open.: (a) `grep -n 'pull worker' specs/NODE.md` -> exit=1, zero matching lines. (b) specs/NODE.md:29 `| 30 bus | a crier identity file at $HOME/.node/crier.json and its mode 600 | harness |` (identity file + mode 600 only, no worker); specs/NODE.md:31 `| 90 verify | the node manifest ($HOME/.node/node.json), written only when every layer passed | all |` (manifest only, no digest round trip). (c) New paragraph specs/NODE.md:33-48 names CF-068 at line 39 ('CF-068 owns the file-existence weakness this layer still has') and CF-004 at line 43 ('CF-004 owns building it'). Path proof confirmed by reading scripts/project-node.sh:241-252 (layer 30 emits only ok/bad crier_identity and crier_mode via `stat -c '%a'` vs 600; no process/socket/worker check) and :288-316 (prints `[90] manifest`, writes $STATE/node.json, no digest). Live run `HOME=$(mktemp -d) ./scripts/project-node.sh --check --project p --layers 30` -> exit=1, output `[30] bus` / `FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` with no worker row. Gates: `bash tests/selftest.sh` -> exit=0, line 145 `SELFTEST: PASS`; `bash scripts/boardctl validate` -> exit=0, `RESULT: OK (54 warning(s))`. Evidence file docs/audits/code-factory-docs-2026-11-04.md:99-105 has section 'Claims I could not verify — stated as not measured' covering the bus worker ('not measured') and the control-host digest round trip ('not measured, and not buildable from this repo; CF-004 owns it'), plus lines 18-19 naming CF-004 and CF-068. Diff is documentation-only (specs/NODE.md +20/-2, audit file +116).
specs/NODE.md layer 30/90 cells now name only shipped behaviour, the CF-004/CF-068 handoff paragraph is present, and both gates pass (SELFTEST: PASS exit 0, boardctl RESULT: OK).

Overall: PASS ✓

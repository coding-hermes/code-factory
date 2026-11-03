# Verdict: CF-125-DOG1

**Task:** Dogfood walk: node-create cannot distinguish a typo'd harness from a documented-but-unmeasured one
**Evaluated:** 2026-11-03T20:59:08.453486
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The dogfood lane's walk of README.md Quick start on a clean HOME filed three net-new rows on origin/main at 8df6b38 with a committed transcript, docs/audits/code-factory-dogfood-2026-11-03-20-47-54.probe.txt. For CF-125 (the row this task is named for): the transcript's section 6 must show both commands and both outputs ('--harness codex' and '--harness not-a-harness') producing the same 'FAIL staged_set — missing scripts/harness/install-<name>.sh' shape, and the row's premise must be visible in the tree at scripts/node-create.sh lines 20-22, where the staged set is built as harness/install-$HARNESS.sh with no validation of the harness name against specs/HARNESS.md's adapter table. CF-126 and CF-127 ride the same committed artifact (sections 7b and 7a).: Commit 8df6b38 (HEAD) adds docs/audits/code-factory-dogfood-2026-11-03-20-47-54.probe.txt (317 lines), 3 net-new rows in .coding-hermes/board/tasks.jsonl lines 99-101 (CF-125/CF-126/CF-127, board 98->101) and 3 task_created events at events.jsonl:141-143 (140->143), no existing line touched. Transcript section 6 (lines 149-171) shows both commands and both outputs: `--harness codex` -> 'FAIL staged_set — missing scripts/harness/install-codex.sh' rc=1, and `--harness not-a-harness` -> 'FAIL staged_set — missing scripts/harness/install-not-a-harness.sh' rc=1 — same shape. Reproduced live: `BUNKER_SERVER=fake scripts/node-create.sh ... --harness codex` and `--harness not-a-harness` both printed exactly those FAIL staged_set lines with rc=1. Premise visible in tree: scripts/node-create.sh:20 `local -a staged=(project-node.sh lib.sh disk_floor.py reclaim_disk.py "harness/install-$HARNESS.sh")`, :23 `bad "staged_set" "missing scripts/$file"`; grep of HARNESS in node-create.sh shows no lookup of specs/HARNESS.md or any adapter allowlist (only :15 default, :20/:27/:35 interpolation, :60 parse, :103 forward). specs/HARNESS.md:23 declares codex ('not measured here'), while scripts/harness/ contains only install-claude-code.sh, install-hermes.sh, install-opencode.sh. Sections 7a (CF-127: /tmp/hermes-install.log Permission denied, leftover from bunker-cf-node) and 7b (CF-126: CRIER_URL unset at layer 00; node-create.sh:103 forwards only NODE_PROJECT/NODE_GATEWAY_PORT) are present in the same artifact. Tests: `bash tests/selftest.sh` -> 'SELFTEST: PASS', exit 0.
Commit 8df6b38 commits the dogfood transcript with section 6 showing byte-identical staged_set refusals for codex and not-a-harness, the premise is confirmed at scripts/node-create.sh:20-23 with no adapter-table validation, sections 7a/7b carry CF-127/CF-126, and the selftest passes (exit 0).

## Summary

Judge Result: CF-125-DOG1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The dogfood lane's walk of README.md Quick start on a clean HOME filed three net-new rows on origin/main at 8df6b38 with a committed transcript, docs/audits/code-factory-dogfood-2026-11-03-20-47-54.probe.txt. For CF-125 (the row this task is named for): the transcript's section 6 must show both commands and both outputs ('--harness codex' and '--harness not-a-harness') producing the same 'FAIL staged_set — missing scripts/harness/install-<name>.sh' shape, and the row's premise must be visible in the tree at scripts/node-create.sh lines 20-22, where the staged set is built as harness/install-$HARNESS.sh with no validation of the harness name against specs/HARNESS.md's adapter table. CF-126 and CF-127 ride the same committed artifact (sections 7b and 7a).: Commit 8df6b38 (HEAD) adds docs/audits/code-factory-dogfood-2026-11-03-20-47-54.probe.txt (317 lines), 3 net-new rows in .coding-hermes/board/tasks.jsonl lines 99-101 (CF-125/CF-126/CF-127, board 98->101) and 3 task_created events at events.jsonl:141-143 (140->143), no existing line touched. Transcript section 6 (lines 149-171) shows both commands and both outputs: `--harness codex` -> 'FAIL staged_set — missing scripts/harness/install-codex.sh' rc=1, and `--harness not-a-harness` -> 'FAIL staged_set — missing scripts/harness/install-not-a-harness.sh' rc=1 — same shape. Reproduced live: `BUNKER_SERVER=fake scripts/node-create.sh ... --harness codex` and `--harness not-a-harness` both printed exactly those FAIL staged_set lines with rc=1. Premise visible in tree: scripts/node-create.sh:20 `local -a staged=(project-node.sh lib.sh disk_floor.py reclaim_disk.py "harness/install-$HARNESS.sh")`, :23 `bad "staged_set" "missing scripts/$file"`; grep of HARNESS in node-create.sh shows no lookup of specs/HARNESS.md or any adapter allowlist (only :15 default, :20/:27/:35 interpolation, :60 parse, :103 forward). specs/HARNESS.md:23 declares codex ('not measured here'), while scripts/harness/ contains only install-claude-code.sh, install-hermes.sh, install-opencode.sh. Sections 7a (CF-127: /tmp/hermes-install.log Permission denied, leftover from bunker-cf-node) and 7b (CF-126: CRIER_URL unset at layer 00; node-create.sh:103 forwards only NODE_PROJECT/NODE_GATEWAY_PORT) are present in the same artifact. Tests: `bash tests/selftest.sh` -> 'SELFTEST: PASS', exit 0.
Commit 8df6b38 commits the dogfood transcript with section 6 showing byte-identical staged_set refusals for codex and not-a-harness, the premise is confirmed at scripts/node-create.sh:20-23 with no adapter-table validation, sections 7a/7b carry CF-127/CF-126, and the selftest passes (exit 0).

Overall: PASS ✓

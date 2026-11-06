# Verdict: CF-288-OPS1

**Task:** node_seed apply reports every file it replaces and preserves locally edited files unless --force
**Evaluated:** 2026-11-06T01:50:25.618472
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ scripts/node_seed.py apply prints one named line per installed tree and per replaced, removed or preserved file path; without --force a locally modified target file survives the re-apply byte-identical; with --force it is replaced and the replacement is named; a selftest arm proves the edit survives a re-apply and that rmtree-without-report is gone: scripts/node_seed.py:254-318 classifies each path (new/changed/removed/local_only) and prints one named line per path plus a 'PASS seed_install — <tree>/ installed (N files)' line per tree; shutil.rmtree on the destination now exists only inside `if args.force:` (line 290), the non-force branch copies only new files (lines 296-298). Manual run in /tmp/cf288: fresh apply printed '.. new prompts/foreman.md' / '.. new skills/fake-skill.md' with per-tree seed_install lines; re-apply without --force printed '.. preserved prompts/foreman.md (changed locally; --force to replace)' and '.. preserved prompts/local-notes.md (locally modified; --force to replace)' with foreman.md sha256 unchanged (0aff79b5… before and after) and local-notes.md intact; --force printed '.. changed prompts/foreman.md' and '.. local-only prompts/local-notes.md (removed by --force)' and restored foreman.md to the seed digest 5d1aa573…. Selftest arms at tests/selftest.sh:3257-3318; full suite run `bash tests/selftest.sh` output: 'PASS  re-apply without --force preserves a changed prompt and a local note, naming both (exit 0)', 'PASS  re-apply with --force overwrites the changed prompt and names it (exit 0)', final line 'SELFTEST: PASS' with zero FAIL lines (exit 0).
node_seed.py apply now reports every installed tree and every new/changed/removed/preserved path, preserves local edits byte-identically without --force and replaces+naming them with --force, proven by passing selftest arms and a full green suite run.

## Summary

Judge Result: CF-288-OPS1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ scripts/node_seed.py apply prints one named line per installed tree and per replaced, removed or preserved file path; without --force a locally modified target file survives the re-apply byte-identical; with --force it is replaced and the replacement is named; a selftest arm proves the edit survives a re-apply and that rmtree-without-report is gone: scripts/node_seed.py:254-318 classifies each path (new/changed/removed/local_only) and prints one named line per path plus a 'PASS seed_install — <tree>/ installed (N files)' line per tree; shutil.rmtree on the destination now exists only inside `if args.force:` (line 290), the non-force branch copies only new files (lines 296-298). Manual run in /tmp/cf288: fresh apply printed '.. new prompts/foreman.md' / '.. new skills/fake-skill.md' with per-tree seed_install lines; re-apply without --force printed '.. preserved prompts/foreman.md (changed locally; --force to replace)' and '.. preserved prompts/local-notes.md (locally modified; --force to replace)' with foreman.md sha256 unchanged (0aff79b5… before and after) and local-notes.md intact; --force printed '.. changed prompts/foreman.md' and '.. local-only prompts/local-notes.md (removed by --force)' and restored foreman.md to the seed digest 5d1aa573…. Selftest arms at tests/selftest.sh:3257-3318; full suite run `bash tests/selftest.sh` output: 'PASS  re-apply without --force preserves a changed prompt and a local note, naming both (exit 0)', 'PASS  re-apply with --force overwrites the changed prompt and names it (exit 0)', final line 'SELFTEST: PASS' with zero FAIL lines (exit 0).
node_seed.py apply now reports every installed tree and every new/changed/removed/preserved path, preserves local edits byte-identically without --force and replaces+naming them with --force, proven by passing selftest arms and a full green suite run.

Overall: PASS ✓

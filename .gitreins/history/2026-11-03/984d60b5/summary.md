# Verdict: PERF-013

**Task:** Selftest gate spends ~85% of CPU on full node-provision runs that assert a single layer
**Evaluated:** 2026-11-03T15:11:57.146898
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✓ 1. project-node.sh accepts --layers 20,40 and rejects an unknown layer with exit 2 and usage text.: scripts/project-node.sh:58-84 parses --layers and validates before any layer runs. Ran: `--check --project demo --layers 20,40` -> accepted, printed SCOPE line and ran layers 20/40 (rc=1 only from environment FAILs). `--layers 20,99` -> `usage: scripts/project-node.sh --check|--apply ... [--layers 00,10,20,30,40]` on stderr, RC=2. Also `--layers 20,` -> RC=2 and `--layers ''` -> RC=2.
  ✓ 2. A scoped run prints a SCOPE line and SKIP rows for unnamed layers, and never writes .node/node.json.: Scoped run output: `SCOPE: layers 20,40 (fixture mode — not a node certification)`, `  SKIP  layer 00 (out of scope)`, `  SKIP  layer 10 (out of scope)`, `  SKIP  layer 30 (out of scope)`, `  SKIP  layer 90 (fixture mode: no manifest)`. After the run `ls -la $HOME/.node` showed only `.` and `..` — no node.json (scripts/project-node.sh:250-270 gates layer 90 on SCOPED).
  ✓ 3. Unscoped behaviour unchanged: bash tests/selftest.sh prints SELFTEST: PASS with 34 PASS rows and the real provision still prints 3 FAIL rows -> NODE: FAIL (3).: `bash tests/selftest.sh` -> RC=0, final line `SELFTEST: PASS`, `grep -c 'PASS '` = 34. Real provision `HOME=$(mktemp -d) ./scripts/project-node.sh --apply --project perfprobe --repo https://github.com/github/gitignore --ref main` -> RC=1, exactly 3 `^  FAIL` rows (crier_url, python, crier_identity) and `NODE: FAIL (3)`. Note: one run under loadavg ~21 transiently failed §2 (`FAIL no FAIL rows`), but 5 direct repeats of the empty-PATH invocation each produced 5 `^  FAIL  tool:` rows, so it is host-load flakiness, not a regression.
  ✓ 4. Fixtures 4/4b/14/15 use --layers and their exact-row assertions are unchanged.: tests/selftest.sh:39 (§3 --layers 00), :62/:84/:128 (§4 missing-ref, §4 private-repo, §4b resolved-ref --layers 40), :300/:317 (§14 red+green adapter --layers 20), :370 (§15 masking arm --layers 30,40). `git show HEAD -- tests/selftest.sh` shows only the invocation lines changed; every `expected=` grep -Fxc string and rc expectation is untouched, and all 34 rows pass.
  ✗ 5. Measured: selftest user+sys below 1.2 s on three consecutive runs, from 2.49 s measured at d5f7fb2.: Measured on HEAD e21f2ce with `/usr/bin/time -p bash tests/selftest.sh`: user+sys = 1.68 / 1.49 / 1.55 s (repeat: 1.67 / 1.56 / 1.61 s) — every run is above the 1.2 s bar. Baseline d5f7fb2 in a clean worktree measured 2.48 / 2.49 / 2.45 s, so the ~38% improvement is real, but the absolute target is not met; the commit message itself claims 1.58 s, which is also above 1.2 s.
The --layers surface, SCOPE/SKIP rows, no-manifest guarantee, unchanged unscoped behaviour and unchanged fixture assertions all verify, but the measured selftest CPU is 1.49-1.68 s user+sys, above the required 1.2 s.

## Summary

Judge Result: PERF-013

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✓ 1. project-node.sh accepts --layers 20,40 and rejects an unknown layer with exit 2 and usage text.: scripts/project-node.sh:58-84 parses --layers and validates before any layer runs. Ran: `--check --project demo --layers 20,40` -> accepted, printed SCOPE line and ran layers 20/40 (rc=1 only from environment FAILs). `--layers 20,99` -> `usage: scripts/project-node.sh --check|--apply ... [--layers 00,10,20,30,40]` on stderr, RC=2. Also `--layers 20,` -> RC=2 and `--layers ''` -> RC=2.
  ✓ 2. A scoped run prints a SCOPE line and SKIP rows for unnamed layers, and never writes .node/node.json.: Scoped run output: `SCOPE: layers 20,40 (fixture mode — not a node certification)`, `  SKIP  layer 00 (out of scope)`, `  SKIP  layer 10 (out of scope)`, `  SKIP  layer 30 (out of scope)`, `  SKIP  layer 90 (fixture mode: no manifest)`. After the run `ls -la $HOME/.node` showed only `.` and `..` — no node.json (scripts/project-node.sh:250-270 gates layer 90 on SCOPED).
  ✓ 3. Unscoped behaviour unchanged: bash tests/selftest.sh prints SELFTEST: PASS with 34 PASS rows and the real provision still prints 3 FAIL rows -> NODE: FAIL (3).: `bash tests/selftest.sh` -> RC=0, final line `SELFTEST: PASS`, `grep -c 'PASS '` = 34. Real provision `HOME=$(mktemp -d) ./scripts/project-node.sh --apply --project perfprobe --repo https://github.com/github/gitignore --ref main` -> RC=1, exactly 3 `^  FAIL` rows (crier_url, python, crier_identity) and `NODE: FAIL (3)`. Note: one run under loadavg ~21 transiently failed §2 (`FAIL no FAIL rows`), but 5 direct repeats of the empty-PATH invocation each produced 5 `^  FAIL  tool:` rows, so it is host-load flakiness, not a regression.
  ✓ 4. Fixtures 4/4b/14/15 use --layers and their exact-row assertions are unchanged.: tests/selftest.sh:39 (§3 --layers 00), :62/:84/:128 (§4 missing-ref, §4 private-repo, §4b resolved-ref --layers 40), :300/:317 (§14 red+green adapter --layers 20), :370 (§15 masking arm --layers 30,40). `git show HEAD -- tests/selftest.sh` shows only the invocation lines changed; every `expected=` grep -Fxc string and rc expectation is untouched, and all 34 rows pass.
  ✗ 5. Measured: selftest user+sys below 1.2 s on three consecutive runs, from 2.49 s measured at d5f7fb2.: Measured on HEAD e21f2ce with `/usr/bin/time -p bash tests/selftest.sh`: user+sys = 1.68 / 1.49 / 1.55 s (repeat: 1.67 / 1.56 / 1.61 s) — every run is above the 1.2 s bar. Baseline d5f7fb2 in a clean worktree measured 2.48 / 2.49 / 2.45 s, so the ~38% improvement is real, but the absolute target is not met; the commit message itself claims 1.58 s, which is also above 1.2 s.
The --layers surface, SCOPE/SKIP rows, no-manifest guarantee, unchanged unscoped behaviour and unchanged fixture assertions all verify, but the measured selftest CPU is 1.49-1.68 s user+sys, above the required 1.2 s.

Overall: FAIL ✗

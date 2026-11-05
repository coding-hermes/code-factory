# Verdict: CF-244

**Task:** Node checkout freshness: prove a node's HEAD is an ancestor of origin/main, name differing files, fail on drift or dirty tree, and record the result at provisioning
**Evaluated:** 2026-11-05T12:52:17.885349
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ bash scripts/node_freshness.py --agent cf-node --server bunker-las-03 exits 0 and prints branch, HEAD, and HEAD-is-ancestor-of-origin/main as measured values; a fixture node tree that is behind, or carries an uncommitted edit, exits non-zero and names the differing files; bash tests/selftest.sh prints SELFTEST: PASS including a fixture that proves the drift arm fails: Live probe run: python3 scripts/node_freshness.py --agent cf-node --server bunker-las-03 printed measured rows 'PASS branch — branch=main', 'PASS worktree — 0 uncommitted paths', 'PASS ancestor — HEAD 7f22d029bc99 is an ancestor of origin/main 8db72b393b65', 'FAIL sync — behind=2 … 8 differing path(s) — scripts/node_freshness.py, tests/selftest.sh, …', 'RESULT: FAIL (behind 2 commit(s) vs origin/main)' — --json carries branch/head/origin_main/ancestor/behind/dirty_files/differing_files; the real node is 2 commits behind the just-landed feature commit, so the exit is data-driven and the in-sync condition (exit 0) is proven on an in-sync fixture clone (RESULT: PASS exit 0, freshness row 'ancestor=true behind=0') and by selftest's green arm. Fixture arms: behind=2 clone → exit 1 'RESULT: FAIL (behind 2 commit(s))' naming c.txt, d.txt; uncommitted edit at origin/main → exit 1 'FAIL worktree — 1 uncommitted path(s): a.txt'; both also proven in tests/selftest.sh section 47 (exit 1 naming 'behind=1' + 'differing path(s) — b.txt', exit 1 naming 'uncommitted path(s): a.txt … the fix belongs upstream'). Fresh full run of the configured test command 'bash tests/selftest.sh': /tmp/selftest2.exit = 0, tail of output 'SELFTEST: PASS' (412 lines, 297 '  PASS  ' section-verdict rows), section 47 lines 2828-3066 of tests/selftest.sh assert and pass all 13 CF-244 arms including 'a drifted checkout at provision time -> FAIL naming behind=1, NODE: FAIL (1), exit 1' and provisioning's --apply recording freshness{status,ladder,behind} in node.json; project-node.sh layer 40 (freshness_measure, lines ~273-415 + layer-40 block ~512-546) records $STATE/freshness.json and nests it into node.json, dirty=WARN / drift=FAIL per specs/NODE.md; verify-node.sh step 5 (~lines 115-148) folds the verdict into VERIFY: — 'record the result at provisioning' is present (freshness.json + manifest freshness object + ladder graded).
Live bunker invocation against cf-node/bunker-las-03 printed branch, HEAD and ancestry as measured values with a data-driven exit (0 demonstrated on in-sync clones, 1 with 8 differing files named on the genuinely-behind real node), /tmp fixtures and selftest section 47 fixtures prove the behind and dirty arms exit non-zero naming differing files, and a fresh backgrounded run of the configured test command bash tests/selftest.sh exited 0 ending 'SELFTEST: PASS' with all 13 CF-244 fixtures passing.

## Summary

Judge Result: CF-244

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ bash scripts/node_freshness.py --agent cf-node --server bunker-las-03 exits 0 and prints branch, HEAD, and HEAD-is-ancestor-of-origin/main as measured values; a fixture node tree that is behind, or carries an uncommitted edit, exits non-zero and names the differing files; bash tests/selftest.sh prints SELFTEST: PASS including a fixture that proves the drift arm fails: Live probe run: python3 scripts/node_freshness.py --agent cf-node --server bunker-las-03 printed measured rows 'PASS branch — branch=main', 'PASS worktree — 0 uncommitted paths', 'PASS ancestor — HEAD 7f22d029bc99 is an ancestor of origin/main 8db72b393b65', 'FAIL sync — behind=2 … 8 differing path(s) — scripts/node_freshness.py, tests/selftest.sh, …', 'RESULT: FAIL (behind 2 commit(s) vs origin/main)' — --json carries branch/head/origin_main/ancestor/behind/dirty_files/differing_files; the real node is 2 commits behind the just-landed feature commit, so the exit is data-driven and the in-sync condition (exit 0) is proven on an in-sync fixture clone (RESULT: PASS exit 0, freshness row 'ancestor=true behind=0') and by selftest's green arm. Fixture arms: behind=2 clone → exit 1 'RESULT: FAIL (behind 2 commit(s))' naming c.txt, d.txt; uncommitted edit at origin/main → exit 1 'FAIL worktree — 1 uncommitted path(s): a.txt'; both also proven in tests/selftest.sh section 47 (exit 1 naming 'behind=1' + 'differing path(s) — b.txt', exit 1 naming 'uncommitted path(s): a.txt … the fix belongs upstream'). Fresh full run of the configured test command 'bash tests/selftest.sh': /tmp/selftest2.exit = 0, tail of output 'SELFTEST: PASS' (412 lines, 297 '  PASS  ' section-verdict rows), section 47 lines 2828-3066 of tests/selftest.sh assert and pass all 13 CF-244 arms including 'a drifted checkout at provision time -> FAIL naming behind=1, NODE: FAIL (1), exit 1' and provisioning's --apply recording freshness{status,ladder,behind} in node.json; project-node.sh layer 40 (freshness_measure, lines ~273-415 + layer-40 block ~512-546) records $STATE/freshness.json and nests it into node.json, dirty=WARN / drift=FAIL per specs/NODE.md; verify-node.sh step 5 (~lines 115-148) folds the verdict into VERIFY: — 'record the result at provisioning' is present (freshness.json + manifest freshness object + ladder graded).
Live bunker invocation against cf-node/bunker-las-03 printed branch, HEAD and ancestry as measured values with a data-driven exit (0 demonstrated on in-sync clones, 1 with 8 differing files named on the genuinely-behind real node), /tmp fixtures and selftest section 47 fixtures prove the behind and dirty arms exit non-zero naming differing files, and a fresh backgrounded run of the configured test command bash tests/selftest.sh exited 0 ending 'SELFTEST: PASS' with all 13 CF-244 fixtures passing.

Overall: PASS ✓

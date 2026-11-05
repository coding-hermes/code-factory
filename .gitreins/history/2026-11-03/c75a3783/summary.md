# Verdict: CF-055

**Task:** project-node.sh FAIL summary must count harness-adapter failures
**Evaluated:** 2026-11-03T12:52:53.240721
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ tests: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
- ✓ **tier2**
  - COMPLETE
  ✓ 1. A fixture in tests/selftest.sh forces scripts/harness/install-<x>.sh to emit FAIL rows and asserts the project-node.sh summary integer equals grep -c of printed FAIL rows (parent + adapter). 2. The same fixture goes green with a passing adapter and exit 0. 3. Exit codes unchanged: nonzero when any FAIL printed. 4. bash tests/selftest.sh prints SELFTEST: PASS at the committed tip.: All four sub-parts verified with real command output. (1) tests/selftest.sh:262-316 (section 14) builds a temp tree, copies real project-node.sh/lib.sh/disk_floor.py, and writes scripts/harness/install-fixture.sh that calls the real lib.sh bad() twice (lib.sh:7 `bad() { printf '  FAIL  %s — %s\n' ...; FAILED=$((FAILED+1)); }`). It then asserts `summary = fail_rows` via `grep -oE '^NODE: FAIL \([0-9]+\)$'` vs `grep -c '^  FAIL'`. Live run output: `PASS  adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)`. Red proof I ran manually against HEAD~1's project-node.sh: printed 2 FAIL rows but `NODE: PASS` with rc=0 — the fixture genuinely catches the bug. (2) selftest.sh:305-316 sed-rewrites bad->ok and exit 1->exit 0, asserting rc==0, zero FAIL rows, and `NODE: PASS`; live output: `PASS  passing adapter keeps NODE: PASS and exit 0`. (3) scripts/project-node.sh:197 is unchanged: `if [ "$FAILED" -eq 0 ]; then say "NODE: PASS"; exit 0; else say "NODE: FAIL ($FAILED)"; exit 1; fi`; my manual run of the fixed script with the failing adapter gave `NEW rc=1` / `NODE: FAIL (2)`, and the passing-adapter arm gave rc=0. The fix only adds `FAILED=$((FAILED + adapter_fails))` at project-node.sh:132, feeding the existing counter. (4) `bash tests/selftest.sh` printed `SELFTEST: PASS` with all 14 sections green, including section 14's two PASS lines (the trailing `/bin/sh: Bad substitution` came from my own PIPESTATUS echo, not the script).
CF-055 is fully implemented and verified: the adapter's FAIL rows are now counted into the parent summary (2 rows -> NODE: FAIL (2), exit 1), the passing-adapter arm stays green with exit 0, exit-code semantics are unchanged, and bash tests/selftest.sh prints SELFTEST: PASS at the committed tip.

## Summary

Judge Result: CF-055

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ tests: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check

Stage tier2: PASS
  COMPLETE
  ✓ 1. A fixture in tests/selftest.sh forces scripts/harness/install-<x>.sh to emit FAIL rows and asserts the project-node.sh summary integer equals grep -c of printed FAIL rows (parent + adapter). 2. The same fixture goes green with a passing adapter and exit 0. 3. Exit codes unchanged: nonzero when any FAIL printed. 4. bash tests/selftest.sh prints SELFTEST: PASS at the committed tip.: All four sub-parts verified with real command output. (1) tests/selftest.sh:262-316 (section 14) builds a temp tree, copies real project-node.sh/lib.sh/disk_floor.py, and writes scripts/harness/install-fixture.sh that calls the real lib.sh bad() twice (lib.sh:7 `bad() { printf '  FAIL  %s — %s\n' ...; FAILED=$((FAILED+1)); }`). It then asserts `summary = fail_rows` via `grep -oE '^NODE: FAIL \([0-9]+\)$'` vs `grep -c '^  FAIL'`. Live run output: `PASS  adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)`. Red proof I ran manually against HEAD~1's project-node.sh: printed 2 FAIL rows but `NODE: PASS` with rc=0 — the fixture genuinely catches the bug. (2) selftest.sh:305-316 sed-rewrites bad->ok and exit 1->exit 0, asserting rc==0, zero FAIL rows, and `NODE: PASS`; live output: `PASS  passing adapter keeps NODE: PASS and exit 0`. (3) scripts/project-node.sh:197 is unchanged: `if [ "$FAILED" -eq 0 ]; then say "NODE: PASS"; exit 0; else say "NODE: FAIL ($FAILED)"; exit 1; fi`; my manual run of the fixed script with the failing adapter gave `NEW rc=1` / `NODE: FAIL (2)`, and the passing-adapter arm gave rc=0. The fix only adds `FAILED=$((FAILED + adapter_fails))` at project-node.sh:132, feeding the existing counter. (4) `bash tests/selftest.sh` printed `SELFTEST: PASS` with all 14 sections green, including section 14's two PASS lines (the trailing `/bin/sh: Bad substitution` came from my own PIPESTATUS echo, not the script).
CF-055 is fully implemented and verified: the adapter's FAIL rows are now counted into the parent summary (2 rows -> NODE: FAIL (2), exit 1), the passing-adapter arm stays green with exit 0, exit-code semantics are unchanged, and bash tests/selftest.sh prints SELFTEST: PASS at the committed tip.

Overall: PASS ✓

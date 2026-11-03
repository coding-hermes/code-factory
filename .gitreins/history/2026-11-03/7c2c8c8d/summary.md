# Verdict: CF-096

**Task:** Ruff-format drift at origin/main af67c3b re-reds the tree-wide Tier-1 lint arm
**Evaluated:** 2026-11-03T19:00:13.585403
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ ruff format --check . exits 1 at origin/main af67c3b on scripts/lane_target.py and tests/test_lane_target.py only; ruff format --check . exits 0 and ruff check . exits 0 after the fix, python3 -B tests/test_lane_target.py passes, and bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip. The change is formatting only (ruff format --diff shows wrapping, no semantic change).: At af67c3b (pristine `git archive` export to /tmp/af67): `ruff format --check .` -> "Would reformat: scripts/lane_target.py / Would reformat: tests/test_lane_target.py / 2 files would be reformatted, 9 files already formatted", exit_code=1 — exactly those two files. At fixed tip 2f24e54: `ruff format --check .` -> "11 files already formatted" exit_code=0; `ruff check .` -> "All checks passed!" exit_code=0; `python3 -B tests/test_lane_target.py` -> "Ran 40 tests ... OK" exit_code=0; `bash tests/selftest.sh` -> exit_code=0 with line 103 "SELFTEST: PASS" (71 PASS lines). Formatting-only confirmed: `ruff format --diff` at af67c3b shows only argument wrapping (verify_bunker signature, subprocess.run call, p2.add_argument calls, Target(...) kwargs, plan.append dict, test main() argv list), and ast.dump comparison of scripts/lane_target.py and tests/test_lane_target.py between af67c3b and 2f24e54 is identical (True/True) — no semantic change.
Ruff-format drift at af67c3b reproduced on exactly the two named files and fully resolved at the fixed tip with format/check/tests/selftest all green and AST-identical (formatting-only) changes.

## Summary

Judge Result: CF-096

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ ruff format --check . exits 1 at origin/main af67c3b on scripts/lane_target.py and tests/test_lane_target.py only; ruff format --check . exits 0 and ruff check . exits 0 after the fix, python3 -B tests/test_lane_target.py passes, and bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip. The change is formatting only (ruff format --diff shows wrapping, no semantic change).: At af67c3b (pristine `git archive` export to /tmp/af67): `ruff format --check .` -> "Would reformat: scripts/lane_target.py / Would reformat: tests/test_lane_target.py / 2 files would be reformatted, 9 files already formatted", exit_code=1 — exactly those two files. At fixed tip 2f24e54: `ruff format --check .` -> "11 files already formatted" exit_code=0; `ruff check .` -> "All checks passed!" exit_code=0; `python3 -B tests/test_lane_target.py` -> "Ran 40 tests ... OK" exit_code=0; `bash tests/selftest.sh` -> exit_code=0 with line 103 "SELFTEST: PASS" (71 PASS lines). Formatting-only confirmed: `ruff format --diff` at af67c3b shows only argument wrapping (verify_bunker signature, subprocess.run call, p2.add_argument calls, Target(...) kwargs, plan.append dict, test main() argv list), and ast.dump comparison of scripts/lane_target.py and tests/test_lane_target.py between af67c3b and 2f24e54 is identical (True/True) — no semantic change.
Ruff-format drift at af67c3b reproduced on exactly the two named files and fully resolved at the fixed tip with format/check/tests/selftest all green and AST-identical (formatting-only) changes.

Overall: PASS ✓

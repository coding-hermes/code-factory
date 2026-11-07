# Verdict: CF-150

**Task:** Documented node create path must stage dashboard.basic_auth before the gateway gate
**Evaluated:** 2026-11-07T06:58:43.214593
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ install-hermes.sh --apply in a fresh HOME reaches the launch path instead of 'refused: a public bind needs dashboard.basic_auth'; negative control still refuses with the exact wording; README/OPS name the command; selftest has a section that fails pre-fix: Partial: selftest PASS (bash tests/selftest.sh -> SELFTEST: PASS, section 55 lines 526-531 all PASS). Need: pre-fix failure proof, README/OPS naming, fresh-HOME launch path.
Partial verdict — evaluation hit resource cap before all criteria verified

## Summary

Judge Result: CF-150

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ install-hermes.sh --apply in a fresh HOME reaches the launch path instead of 'refused: a public bind needs dashboard.basic_auth'; negative control still refuses with the exact wording; README/OPS name the command; selftest has a section that fails pre-fix: Partial: selftest PASS (bash tests/selftest.sh -> SELFTEST: PASS, section 55 lines 526-531 all PASS). Need: pre-fix failure proof, README/OPS naming, fresh-HOME launch path.
Partial verdict — evaluation hit resource cap before all criteria verified

Overall: FAIL ✗

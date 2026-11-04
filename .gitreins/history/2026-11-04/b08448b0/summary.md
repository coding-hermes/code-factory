# Verdict: CF-093

**Task:** README Status rows 1 and 3 are enforced by a selftest arm (interpreter-qualified --check)
**Evaluated:** 2026-11-04T02:40:31.170562
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ tests/selftest.sh gains an arm that binds README Status rows 1 and 3 to the interpreter-qualified form: it FAILS when either row re-run cell offers only scripts/harness/install-hermes.sh --check without HERMES_PYTHON_BIN=python3.12. The arm prints a FAIL row naming the regressed row for a mutated README copy with the qualified form stripped, and a PASS row for the shipped README. At the fixed tree bash tests/selftest.sh prints SELFTEST: PASS and exits 0; against the stripped copy the same suite exits nonzero. scripts/boardctl validate prints RESULT: OK.: tests/selftest.sh section 30 (added in commit 1b4b0b6, ~lines 972-1004) defines status_rows_missing_qualifier() which greps the two Status rows ('Hermes in a bunker + HTTP gateway over tailnet', 'Node inference credential') for the literal 'HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check' and reports absent-row/missing-qualifier. Fixed tree: `bash tests/selftest.sh` -> 'PASS  README Status rows 1 and 3 cite the interpreter-qualified --check' ... 'SELFTEST: PASS', EXIT=0. Mutated copy (/tmp/mut, sed 's/HERMES_PYTHON_BIN=python3\.12 //g' on README.md) -> 'FAIL  README Status row lost its interpreter-qualified --check: missing-qualifier: Hermes in a bunker + HTTP gateway over tailnet missing-qualifier: Node inference credential', 'SELFTEST: FAIL (1)', MUTATED_EXIT=1. Second mutation (/tmp/mut2, qualified command replaced by bare 'scripts/harness/install-hermes.sh --check') also FAILs naming both rows, exit 1. `scripts/boardctl validate` -> 'RESULT: OK (48 warning(s))', exit 0.
Section 30 of tests/selftest.sh binds README Status rows 1 and 3 to the interpreter-qualified --check, passing on the shipped tree (SELFTEST: PASS, exit 0) and failing with a row-naming FAIL on stripped copies (exit 1), with boardctl validate reporting RESULT: OK.

## Summary

Judge Result: CF-093

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ tests/selftest.sh gains an arm that binds README Status rows 1 and 3 to the interpreter-qualified form: it FAILS when either row re-run cell offers only scripts/harness/install-hermes.sh --check without HERMES_PYTHON_BIN=python3.12. The arm prints a FAIL row naming the regressed row for a mutated README copy with the qualified form stripped, and a PASS row for the shipped README. At the fixed tree bash tests/selftest.sh prints SELFTEST: PASS and exits 0; against the stripped copy the same suite exits nonzero. scripts/boardctl validate prints RESULT: OK.: tests/selftest.sh section 30 (added in commit 1b4b0b6, ~lines 972-1004) defines status_rows_missing_qualifier() which greps the two Status rows ('Hermes in a bunker + HTTP gateway over tailnet', 'Node inference credential') for the literal 'HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check' and reports absent-row/missing-qualifier. Fixed tree: `bash tests/selftest.sh` -> 'PASS  README Status rows 1 and 3 cite the interpreter-qualified --check' ... 'SELFTEST: PASS', EXIT=0. Mutated copy (/tmp/mut, sed 's/HERMES_PYTHON_BIN=python3\.12 //g' on README.md) -> 'FAIL  README Status row lost its interpreter-qualified --check: missing-qualifier: Hermes in a bunker + HTTP gateway over tailnet missing-qualifier: Node inference credential', 'SELFTEST: FAIL (1)', MUTATED_EXIT=1. Second mutation (/tmp/mut2, qualified command replaced by bare 'scripts/harness/install-hermes.sh --check') also FAILs naming both rows, exit 1. `scripts/boardctl validate` -> 'RESULT: OK (48 warning(s))', exit 0.
Section 30 of tests/selftest.sh binds README Status rows 1 and 3 to the interpreter-qualified --check, passing on the shipped tree (SELFTEST: PASS, exit 0) and failing with a row-naming FAIL on stripped copies (exit 1), with boardctl validate reporting RESULT: OK.

Overall: PASS ✓

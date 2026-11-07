# Verdict: CF-082-R1

**Task:** CF-082 narrow re-judge: decimal floor preserved
**Evaluated:** 2026-11-07T11:19:34.798525
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Grade the committed tree at HEAD 785dbbd on four legs only, by running them: (1) python3 scripts/disk_floor.py resolve --cli 5.9G --explain prints a JSON object with floor_gib 5.9 and source cli, and --cli 5G --explain prints floor_gib 5; (2) --cli 5.1G, 5.5G and 5.9G --explain print three distinct floor_gib values 5.1, 5.5, 5.9; (3) python3 -m unittest discover -s tests -p test_disk_floor.py exits 0 and carries a test asserting 5.9G is preserved, and against the pre-fix resolver (git show deafbc3:scripts/disk_floor.py copied over a scratch copy) the same test file fails; (4) the module docstring in scripts/disk_floor.py states a decimal is preserved rather than truncated. Do NOT run tests/selftest.sh in this evaluation: tier 1 already ran it at this commit and it printed SELFTEST: PASS.: All four legs run at HEAD 785dbbd (working tree clean apart from an untracked .gitreins history dir). Leg1: `python3 scripts/disk_floor.py resolve --cli 5.9G --explain` -> {"role": "worker", "floor_gib": 5.9, "source": "cli"} exit 0; `--cli 5G --explain` -> {"role": "worker", "floor_gib": 5, "source": "cli"} exit 0. Leg2: 5.1G/5.5G/5.9G -> floor_gib 5.1, 5.5, 5.9 (three distinct values). Leg3: `python3 -m unittest discover -s tests -p test_disk_floor.py` EXIT=0, output 'Ran 18 tests in 0.004s / OK'; tests/test_disk_floor.py:31-36 test_decimal_is_preserved_not_truncated asserts parse_value("5.9G")==5.9 (also "5.9" and 5.9), and :48-49 asserts [5.1,5.5,5.9]; against the pre-fix resolver copied from `git show deafbc3:scripts/disk_floor.py` into /tmp/prefix with the same test file, the run EXIT=1 with 'FAILED (failures=5, errors=1)' and e.g. 'AssertionError: Tuples differ: (5, \'cli\') != (5.1, \'cli\')' at test_disk_floor.py:133. Leg4: scripts/disk_floor.py module docstring lines 16-18 read 'A decimal is PRESERVED, never truncated: "5.9G" is a 5.9 GiB floor, so the number admission enforces is the number the operator wrote.' tests/selftest.sh was NOT run, per instruction.
All four legs verified by execution at HEAD 785dbbd: decimal floors 5.1/5.5/5.9 are preserved end-to-end, the unit suite exits 0 with a 5.9G-preservation test that fails against the deafbc3 pre-fix resolver, and the docstring states decimals are preserved rather than truncated.

## Summary

Judge Result: CF-082-R1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Grade the committed tree at HEAD 785dbbd on four legs only, by running them: (1) python3 scripts/disk_floor.py resolve --cli 5.9G --explain prints a JSON object with floor_gib 5.9 and source cli, and --cli 5G --explain prints floor_gib 5; (2) --cli 5.1G, 5.5G and 5.9G --explain print three distinct floor_gib values 5.1, 5.5, 5.9; (3) python3 -m unittest discover -s tests -p test_disk_floor.py exits 0 and carries a test asserting 5.9G is preserved, and against the pre-fix resolver (git show deafbc3:scripts/disk_floor.py copied over a scratch copy) the same test file fails; (4) the module docstring in scripts/disk_floor.py states a decimal is preserved rather than truncated. Do NOT run tests/selftest.sh in this evaluation: tier 1 already ran it at this commit and it printed SELFTEST: PASS.: All four legs run at HEAD 785dbbd (working tree clean apart from an untracked .gitreins history dir). Leg1: `python3 scripts/disk_floor.py resolve --cli 5.9G --explain` -> {"role": "worker", "floor_gib": 5.9, "source": "cli"} exit 0; `--cli 5G --explain` -> {"role": "worker", "floor_gib": 5, "source": "cli"} exit 0. Leg2: 5.1G/5.5G/5.9G -> floor_gib 5.1, 5.5, 5.9 (three distinct values). Leg3: `python3 -m unittest discover -s tests -p test_disk_floor.py` EXIT=0, output 'Ran 18 tests in 0.004s / OK'; tests/test_disk_floor.py:31-36 test_decimal_is_preserved_not_truncated asserts parse_value("5.9G")==5.9 (also "5.9" and 5.9), and :48-49 asserts [5.1,5.5,5.9]; against the pre-fix resolver copied from `git show deafbc3:scripts/disk_floor.py` into /tmp/prefix with the same test file, the run EXIT=1 with 'FAILED (failures=5, errors=1)' and e.g. 'AssertionError: Tuples differ: (5, \'cli\') != (5.1, \'cli\')' at test_disk_floor.py:133. Leg4: scripts/disk_floor.py module docstring lines 16-18 read 'A decimal is PRESERVED, never truncated: "5.9G" is a 5.9 GiB floor, so the number admission enforces is the number the operator wrote.' tests/selftest.sh was NOT run, per instruction.
All four legs verified by execution at HEAD 785dbbd: decimal floors 5.1/5.5/5.9 are preserved end-to-end, the unit suite exits 0 with a 5.9G-preservation test that fails against the deafbc3 pre-fix resolver, and the docstring states decimals are preserved rather than truncated.

Overall: PASS ✓

# Verdict: CF-229-V2

**Task:** Gate the receiving side of the §5 variable contract: the bus worker must record which values it passed, and that arm must be able to fail
**Evaluated:** 2026-11-06T11:52:35.401444
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ CF-229: gate the RECEIVING side of the specs/HARNESS-MATRIX.md §5 variable contract. This task grades the test change and the gate at this commit. The board row's own closure lands in a SEPARATE later commit that cites this verdict — do NOT grade the row's status here, and do not require the row to read `complete` in this tree.

1. `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_section5_receipt.py` exits 0 and prints `Ran 6 tests` then `OK`. The six tests prove, against scripts/node-bus-worker.py: all twelve §5 names are accepted from a dispatch's `vars` object with no problem reported; `section5_receipt` covers every declared name with exactly {set, len} and never records a value (the credential path must not appear in it); a name the directive did not carry reads as `set: false` rather than vanishing; `harness_env` carries exactly the directive's values and drops an ambient `CF_*` the directive never named; and the two refusal arms go red by name (an undeclared name, and a credential sent as a value, whose refusal must not echo the secret).

2. `bash tests/selftest.sh` prints `SELFTEST: PASS` with `> 350` `  PASS` rows, and one of those rows reads `PASS  §5 set accepted from the directive, receipt records name/set/len only, ambient CF_* scrubbed`.

3. The new arm is INSIDE the existing section 44, so the section count the drift probe reads must not move: `grep -c '^say "[0-9]*\.' tests/selftest.sh` prints `52`, and `bash docs/audits/cf099-prd-drift-probe.sh` prints `OK:` at this tip.

4. The arm can fail: move `tests/test_section5_receipt.py` aside in a scratch copy (or break one assertion) and the same `bash tests/selftest.sh` section must print `FAIL  the §5 contract on the receiving side (tests/test_section5_receipt.py)`; a check that cannot print FAIL is decoration (AGENTS.md rule 2).

5. `bash scripts/boardctl validate` prints `RESULT: OK` and `git log -1 --format=%s` names the test change under commit style `<type>: <what> — <why>. Addresses CF-229.`: PASS: `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_section5_receipt.py` exit 0, "Ran 6 tests" + "OK". Six tests: all 12 SECTION5_VARS accepted (test_every_declared_name_is_accepted_from_the_directive), receipt covers declared set with exactly {set,len} and no credential path (test_receipt_records_which_values_were_passed_without_recording_them), partial set reads set:false (test_partial_set_is_still_reported_name_by_name), harness_env carries directive values + drops ambient CF_SMUGGLED (test_harness_env_carries_the_directive_set_and_scrubs_ambient_cf), two refusal arms by name (CF_NOT_DECLARED, CF_API_KEY_FILE secret not echoed). Worker impl at scripts/node-bus-worker.py:489 directive_vars, :559 section5_receipt, :571 harness_env.
Partial verdict — all verified criteria passed

## Summary

Judge Result: CF-229-V2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ CF-229: gate the RECEIVING side of the specs/HARNESS-MATRIX.md §5 variable contract. This task grades the test change and the gate at this commit. The board row's own closure lands in a SEPARATE later commit that cites this verdict — do NOT grade the row's status here, and do not require the row to read `complete` in this tree.

1. `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_section5_receipt.py` exits 0 and prints `Ran 6 tests` then `OK`. The six tests prove, against scripts/node-bus-worker.py: all twelve §5 names are accepted from a dispatch's `vars` object with no problem reported; `section5_receipt` covers every declared name with exactly {set, len} and never records a value (the credential path must not appear in it); a name the directive did not carry reads as `set: false` rather than vanishing; `harness_env` carries exactly the directive's values and drops an ambient `CF_*` the directive never named; and the two refusal arms go red by name (an undeclared name, and a credential sent as a value, whose refusal must not echo the secret).

2. `bash tests/selftest.sh` prints `SELFTEST: PASS` with `> 350` `  PASS` rows, and one of those rows reads `PASS  §5 set accepted from the directive, receipt records name/set/len only, ambient CF_* scrubbed`.

3. The new arm is INSIDE the existing section 44, so the section count the drift probe reads must not move: `grep -c '^say "[0-9]*\.' tests/selftest.sh` prints `52`, and `bash docs/audits/cf099-prd-drift-probe.sh` prints `OK:` at this tip.

4. The arm can fail: move `tests/test_section5_receipt.py` aside in a scratch copy (or break one assertion) and the same `bash tests/selftest.sh` section must print `FAIL  the §5 contract on the receiving side (tests/test_section5_receipt.py)`; a check that cannot print FAIL is decoration (AGENTS.md rule 2).

5. `bash scripts/boardctl validate` prints `RESULT: OK` and `git log -1 --format=%s` names the test change under commit style `<type>: <what> — <why>. Addresses CF-229.`: PASS: `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_section5_receipt.py` exit 0, "Ran 6 tests" + "OK". Six tests: all 12 SECTION5_VARS accepted (test_every_declared_name_is_accepted_from_the_directive), receipt covers declared set with exactly {set,len} and no credential path (test_receipt_records_which_values_were_passed_without_recording_them), partial set reads set:false (test_partial_set_is_still_reported_name_by_name), harness_env carries directive values + drops ambient CF_SMUGGLED (test_harness_env_carries_the_directive_set_and_scrubs_ambient_cf), two refusal arms by name (CF_NOT_DECLARED, CF_API_KEY_FILE secret not echoed). Worker impl at scripts/node-bus-worker.py:489 directive_vars, :559 section5_receipt, :571 harness_env.
Partial verdict — all verified criteria passed

Overall: PASS ✓

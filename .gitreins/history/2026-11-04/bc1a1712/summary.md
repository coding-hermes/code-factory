# Verdict: CF-176-DOC2

**Task:** docs(SCHEDULER-ADMISSION): the family census reports a disabled row, not a fully armed family
**Evaluated:** 2026-11-04T08:22:10.779935
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ In docs/SCHEDULER-ADMISSION.md the measured-census sentence no longer claims the whole code-factory family is enabled: a grep for that removed assertion returns 0 matches, and the replacement states the measured enabled count from the live scheduler census (17 ceiling-bearing rows, 16 enabled, code-factory-qa enabled=0 via auto-disable) together with the read-back SQL that produced it. docs/audits/code-factory-docs-2026-11-04-CF-176.md exists at this commit and quotes the grep output (no match), the sqlite census rows, and the literal SELFTEST: PASS output from bash tests/selftest.sh at this commit.: Removed assertion gone: `grep -c 'every row enabled' docs/SCHEDULER-ADMISSION.md` returns 0 (exit 1); the only remaining occurrences are inside the audit file quoting the before-state. Replacement at docs/SCHEDULER-ADMISSION.md:53-61 reads '...and 576x, across 17 ceiling-bearing rows of which 16 were enabled: `code-factory-qa` read `enabled=0`, set by `auto-disable` on `failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`' and carries the read-back SQL `sqlite3 ~/.hermes/coding-hermes/scheduler.db "select name, enabled, cooldown_floor_s, cooldown_ceiling_s, disabled_by from projects where name like '<family>%' and cooldown_ceiling_s>0;"`. docs/audits/code-factory-docs-2026-11-04-CF-176.md exists at HEAD (blob e5f09ea, 133 lines, added in commit 9149ff8) and quotes: the grep output (`$ grep -c 'every row enabled' docs/SCHEDULER-ADMISSION.md` -> `0`, plus `NO_MATCHES_ANY_DOC`), the sqlite census (17 code-factory rows with non-zero ceiling, exactly one enabled=0: `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`), and the literal `SELFTEST: PASS`, exit 0 at base 1fea92d and at this commit (lines 112-113). Fresh run of `bash tests/selftest.sh` in the working tree ends with `SELFTEST: PASS`.
The false 'every row enabled' claim is removed (grep = 0 matches), replaced with the measured 17-rows/16-enabled census naming code-factory-qa's auto-disable plus the read-back SQL, and the CF-176 audit file at HEAD quotes the grep, sqlite rows, and SELFTEST: PASS output.

## Summary

Judge Result: CF-176-DOC2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ In docs/SCHEDULER-ADMISSION.md the measured-census sentence no longer claims the whole code-factory family is enabled: a grep for that removed assertion returns 0 matches, and the replacement states the measured enabled count from the live scheduler census (17 ceiling-bearing rows, 16 enabled, code-factory-qa enabled=0 via auto-disable) together with the read-back SQL that produced it. docs/audits/code-factory-docs-2026-11-04-CF-176.md exists at this commit and quotes the grep output (no match), the sqlite census rows, and the literal SELFTEST: PASS output from bash tests/selftest.sh at this commit.: Removed assertion gone: `grep -c 'every row enabled' docs/SCHEDULER-ADMISSION.md` returns 0 (exit 1); the only remaining occurrences are inside the audit file quoting the before-state. Replacement at docs/SCHEDULER-ADMISSION.md:53-61 reads '...and 576x, across 17 ceiling-bearing rows of which 16 were enabled: `code-factory-qa` read `enabled=0`, set by `auto-disable` on `failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`' and carries the read-back SQL `sqlite3 ~/.hermes/coding-hermes/scheduler.db "select name, enabled, cooldown_floor_s, cooldown_ceiling_s, disabled_by from projects where name like '<family>%' and cooldown_ceiling_s>0;"`. docs/audits/code-factory-docs-2026-11-04-CF-176.md exists at HEAD (blob e5f09ea, 133 lines, added in commit 9149ff8) and quotes: the grep output (`$ grep -c 'every row enabled' docs/SCHEDULER-ADMISSION.md` -> `0`, plus `NO_MATCHES_ANY_DOC`), the sqlite census (17 code-factory rows with non-zero ceiling, exactly one enabled=0: `code-factory-qa|0|auto-disable|failure rate 91.3% (84/92 ticks, window 100, threshold 0.90)`), and the literal `SELFTEST: PASS`, exit 0 at base 1fea92d and at this commit (lines 112-113). Fresh run of `bash tests/selftest.sh` in the working tree ends with `SELFTEST: PASS`.
The false 'every row enabled' claim is removed (grep = 0 matches), replaced with the measured 17-rows/16-enabled census naming code-factory-qa's auto-disable plus the read-back SQL, and the CF-176 audit file at HEAD quotes the grep, sqlite rows, and SELFTEST: PASS output.

Overall: PASS ✓

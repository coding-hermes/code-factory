# Verdict: CF-291

**Task:** seed WARN must not pass the node gate
**Evaluated:** 2026-11-06T14:41:35.754519
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ bash tests/selftest.sh at HEAD is green and now contains fixtures driving the REAL scripts/verify-node.sh with a stub bunker: an absent seed record, an empty record, and a corrupt record each yield a non-zero UNVERIFIED verdict (exit 3) instead of VERIFY: PASS exit 0, a missing node_seed_drift.py yields FAIL exit 1, and the same absent record under --strict-seed still yields FAIL exit 1 with the pre-existing wording preserved: Ran `bash tests/selftest.sh` fresh at HEAD 9d6efc8: exit_code 0, final line `SELFTEST: PASS` (169 lines). Section 48 (tests/selftest.sh:3737-3899) drives the REAL scripts/verify-node.sh through vn_run() with a stub bunker (`exec bash -c "${!#}"`) and stub curl over a fixture HOME carrying the applied record plus a real checkout, so only the seed leg moves. Observed PASS lines: 'a node whose seed matches its record -> VERIFY: PASS, exit 0'; 'a 0-byte seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift (not a PASS)'; 'pre-fix 436def5 certifies the same unmeasured seed: VERIFY: PASS, exit 0 (the fixture detects CF-291)'; 'an unparseable seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift and the path'; 'an absent seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift and the path'; 'an absent record under --strict-seed is still a FAIL, exit 1 (wording preserved)'; 'a missing seeder -> exit 1, VERIFY: FAIL naming the unmeasured seed'; 'seeder and record restored -> VERIFY: PASS, exit 0 again'. Code backing it: scripts/verify-node.sh:195-198 adds `unverified "seed_drift: ..."` on the WARN branch, :207-211 prints `VERIFY: UNVERIFIED — ${UNVERIFIED_WHY}` and exits 3, :170-172 makes a missing node_seed_drift.py a `bad` -> `VERIFY: FAIL (1)` exit 1, and :190-191 keeps the --strict-seed FAIL wording '(--strict-seed: unknown is not a pass)'. scripts/node_seed_drift.py:109-113 also fixes the argv order so a 0-byte record is correctly reported as unparseable.
Fresh `bash tests/selftest.sh` at HEAD exits 0 with SELFTEST: PASS, and its new section 48 drives the real verify-node.sh with a stub bunker proving absent/empty/corrupt seed records now yield exit 3 UNVERIFIED (with a pre-fix 436def5 control showing the old exit 0 PASS), a missing seeder yields FAIL exit 1, and --strict-seed still yields FAIL exit 1 with the original wording.

## Summary

Judge Result: CF-291

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ bash tests/selftest.sh at HEAD is green and now contains fixtures driving the REAL scripts/verify-node.sh with a stub bunker: an absent seed record, an empty record, and a corrupt record each yield a non-zero UNVERIFIED verdict (exit 3) instead of VERIFY: PASS exit 0, a missing node_seed_drift.py yields FAIL exit 1, and the same absent record under --strict-seed still yields FAIL exit 1 with the pre-existing wording preserved: Ran `bash tests/selftest.sh` fresh at HEAD 9d6efc8: exit_code 0, final line `SELFTEST: PASS` (169 lines). Section 48 (tests/selftest.sh:3737-3899) drives the REAL scripts/verify-node.sh through vn_run() with a stub bunker (`exec bash -c "${!#}"`) and stub curl over a fixture HOME carrying the applied record plus a real checkout, so only the seed leg moves. Observed PASS lines: 'a node whose seed matches its record -> VERIFY: PASS, exit 0'; 'a 0-byte seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift (not a PASS)'; 'pre-fix 436def5 certifies the same unmeasured seed: VERIFY: PASS, exit 0 (the fixture detects CF-291)'; 'an unparseable seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift and the path'; 'an absent seed record -> exit 3, VERIFY: UNVERIFIED naming seed_drift and the path'; 'an absent record under --strict-seed is still a FAIL, exit 1 (wording preserved)'; 'a missing seeder -> exit 1, VERIFY: FAIL naming the unmeasured seed'; 'seeder and record restored -> VERIFY: PASS, exit 0 again'. Code backing it: scripts/verify-node.sh:195-198 adds `unverified "seed_drift: ..."` on the WARN branch, :207-211 prints `VERIFY: UNVERIFIED — ${UNVERIFIED_WHY}` and exits 3, :170-172 makes a missing node_seed_drift.py a `bad` -> `VERIFY: FAIL (1)` exit 1, and :190-191 keeps the --strict-seed FAIL wording '(--strict-seed: unknown is not a pass)'. scripts/node_seed_drift.py:109-113 also fixes the argv order so a 0-byte record is correctly reported as unparseable.
Fresh `bash tests/selftest.sh` at HEAD exits 0 with SELFTEST: PASS, and its new section 48 drives the real verify-node.sh with a stub bunker proving absent/empty/corrupt seed records now yield exit 3 UNVERIFIED (with a pre-fix 436def5 control showing the old exit 0 PASS), a missing seeder yields FAIL exit 1, and --strict-seed still yields FAIL exit 1 with the original wording.

Overall: PASS ✓

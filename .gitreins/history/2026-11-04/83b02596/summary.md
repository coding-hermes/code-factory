# Verdict: CF-119

**Task:** Board lock is a phantom ownership barrier: give it an ignore rule and a holder-proof adjudicator
**Evaluated:** 2026-11-04T03:22:39.066257
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ git check-ignore -q .coding-hermes/board/.lock exits 0; a repo-shipped adjudicator classifies an unheld 0-byte lock as RESIDUE and a flock-held lock as HELD; both arms appear as named PASS rows in tests/selftest.sh which still prints SELFTEST: PASS: (a) `git check-ignore -q .coding-hermes/board/.lock; echo $?` -> `ignore_rc=0`; rule is the last line of .gitignore (`.coding-hermes/board/.lock`). (b) scripts/board_lock.py is repo-shipped (confirmed by `git ls-files scripts/board_lock.py`); independent runs: unheld 0-byte lock -> `RESIDUE consumers=0 commits_after_mtime=unknown`, rc=0, file still 0 bytes (never mutated); live flock holder -> `HELD holder=pid-2356385`, rc=0 (holder proven via /proc fd scan / EWOULDBLOCK probe, scripts/board_lock.py:69-96). (c) tests/selftest.sh:1081-1134 section 31 contains the two named rows: `PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)` and `PASS  flock-held lock -> HELD (HELD holder=pid-2350223)`. Full suite run `bash tests/selftest.sh` (the configured guards.test_command) exited rc=0 with final line `SELFTEST: PASS`, 95 PASS rows; the only FAIL strings in the log are intentional negative-fixture output (e.g. section 7b board-gate fixtures).
Ignore rule returns 0, the shipped scripts/board_lock.py correctly yields RESIDUE for an unheld 0-byte lock and HELD for a flock-held lock, and both arms are named PASS rows in a selftest that ends with SELFTEST: PASS (rc=0).

## Summary

Judge Result: CF-119

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ git check-ignore -q .coding-hermes/board/.lock exits 0; a repo-shipped adjudicator classifies an unheld 0-byte lock as RESIDUE and a flock-held lock as HELD; both arms appear as named PASS rows in tests/selftest.sh which still prints SELFTEST: PASS: (a) `git check-ignore -q .coding-hermes/board/.lock; echo $?` -> `ignore_rc=0`; rule is the last line of .gitignore (`.coding-hermes/board/.lock`). (b) scripts/board_lock.py is repo-shipped (confirmed by `git ls-files scripts/board_lock.py`); independent runs: unheld 0-byte lock -> `RESIDUE consumers=0 commits_after_mtime=unknown`, rc=0, file still 0 bytes (never mutated); live flock holder -> `HELD holder=pid-2356385`, rc=0 (holder proven via /proc fd scan / EWOULDBLOCK probe, scripts/board_lock.py:69-96). (c) tests/selftest.sh:1081-1134 section 31 contains the two named rows: `PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)` and `PASS  flock-held lock -> HELD (HELD holder=pid-2350223)`. Full suite run `bash tests/selftest.sh` (the configured guards.test_command) exited rc=0 with final line `SELFTEST: PASS`, 95 PASS rows; the only FAIL strings in the log are intentional negative-fixture output (e.g. section 7b board-gate fixtures).
Ignore rule returns 0, the shipped scripts/board_lock.py correctly yields RESIDUE for an unheld 0-byte lock and HELD for a flock-held lock, and both arms are named PASS rows in a selftest that ends with SELFTEST: PASS (rc=0).

Overall: PASS ✓

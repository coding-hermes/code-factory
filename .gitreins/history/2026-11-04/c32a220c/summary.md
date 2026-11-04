# Verdict: CF-119-L1

**Task:** CF-119 landed as section 33 on the moved tip: ignore rule + holder-proof adjudicator
**Evaluated:** 2026-11-04T03:25:20.092737
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ commit a012d02 ignores .coding-hermes/board/.lock (git check-ignore exits 0), ships scripts/board_lock.py which proves a holder before reporting HELD and otherwise RESIDUE, prints both fixtures as named PASS rows in selftest section 33, keeps sibling sections 31/32, and bash tests/selftest.sh prints SELFTEST: PASS at that commit: HEAD is a012d02180c1ea53e979b65b545d9533f7d2da07. (1) Ignore rule: `git check-ignore -v .coding-hermes/board/.lock` -> `.gitignore:20:.coding-hermes/board/.lock`, exit=0; the commit adds that line to .gitignore. (2) scripts/board_lock.py (177 lines) adjudicate() reports HELD only on proven holder — fd_holders() /proc/<pid>/fd scan excluding self, or flock_probe() failing EWOULDBLOCK/EAGAIN — else `RESIDUE consumers=<n> commits_after_mtime=<n|unknown>`, ABSENT when missing; it only os.open(O_RDONLY)+flock probes, never creates/truncates/deletes. Verified live: with a real flock holder -> `HELD holder=pid-2427236` rc=0; after reaping the holder, same file -> `RESIDUE consumers=0 commits_after_mtime=unknown` rc=0 (proves holder-proof, not presence). Unheld 0-byte fixture -> RESIDUE rc=0 with file still 0 bytes. (3) tests/selftest.sh:1260 section 33 prints both named PASS rows: `PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)` and `PASS  flock-held lock -> HELD (HELD holder=pid-2422294)`. (4) Siblings intact: line 1082 `31. Hermes pip logs ... (CF-127)` and line 1229 `32. the Quick start control-host commands name BUNKER_SERVER (CF-145)`, both with their PASS rows in the run. (5) `bash tests/selftest.sh` (the configured guards.test_command) -> SELFTEST_EXIT=0, 103 PASS rows, /tmp/st.log:161 `SELFTEST: PASS`.
Commit a012d02 satisfies every sub-claim: check-ignore exits 0, board_lock.py adjudicates HELD only on a proven live holder and RESIDUE otherwise, section 33 prints both named PASS rows with sections 31/32 intact, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS.

## Summary

Judge Result: CF-119-L1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ commit a012d02 ignores .coding-hermes/board/.lock (git check-ignore exits 0), ships scripts/board_lock.py which proves a holder before reporting HELD and otherwise RESIDUE, prints both fixtures as named PASS rows in selftest section 33, keeps sibling sections 31/32, and bash tests/selftest.sh prints SELFTEST: PASS at that commit: HEAD is a012d02180c1ea53e979b65b545d9533f7d2da07. (1) Ignore rule: `git check-ignore -v .coding-hermes/board/.lock` -> `.gitignore:20:.coding-hermes/board/.lock`, exit=0; the commit adds that line to .gitignore. (2) scripts/board_lock.py (177 lines) adjudicate() reports HELD only on proven holder — fd_holders() /proc/<pid>/fd scan excluding self, or flock_probe() failing EWOULDBLOCK/EAGAIN — else `RESIDUE consumers=<n> commits_after_mtime=<n|unknown>`, ABSENT when missing; it only os.open(O_RDONLY)+flock probes, never creates/truncates/deletes. Verified live: with a real flock holder -> `HELD holder=pid-2427236` rc=0; after reaping the holder, same file -> `RESIDUE consumers=0 commits_after_mtime=unknown` rc=0 (proves holder-proof, not presence). Unheld 0-byte fixture -> RESIDUE rc=0 with file still 0 bytes. (3) tests/selftest.sh:1260 section 33 prints both named PASS rows: `PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)` and `PASS  flock-held lock -> HELD (HELD holder=pid-2422294)`. (4) Siblings intact: line 1082 `31. Hermes pip logs ... (CF-127)` and line 1229 `32. the Quick start control-host commands name BUNKER_SERVER (CF-145)`, both with their PASS rows in the run. (5) `bash tests/selftest.sh` (the configured guards.test_command) -> SELFTEST_EXIT=0, 103 PASS rows, /tmp/st.log:161 `SELFTEST: PASS`.
Commit a012d02 satisfies every sub-claim: check-ignore exits 0, board_lock.py adjudicates HELD only on a proven live holder and RESIDUE otherwise, section 33 prints both named PASS rows with sections 31/32 intact, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS.

Overall: PASS ✓

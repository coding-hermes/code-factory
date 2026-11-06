# Verdict: CF-357

**Task:** clone_lane --to equal to --from must refuse before any write
**Evaluated:** 2026-11-06T04:22:48.698942
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ clone_lane.py refuses when --to equals --from: exit 2, a named error naming both arguments, and a fixture scheduler DB proves the source lane row is byte-identical after the refused run. tests/test_clone_lane.py is wired into tests/selftest.sh, and bash tests/selftest.sh prints SELFTEST: PASS at the closing commit.: scripts/clone_lane.py:68 calls refuse_same_lane(a.dst) before sqlite3.connect at line 70; refuse_same_lane (lines 38-46) prints 'REFUSED: --to and --from are the same lane (<lane>); refusing to rewrite the source row' plus '  --from=<lane> --to=<lane>' to stderr and raises SystemExit(2). Manual verification against a fixture scheduler DB: `python3 scripts/clone_lane.py --from lane-a --to lane-a ... --db $T/f.db` -> stderr 'REFUSED: --to and --from are the same lane (lane-a); refusing to rewrite the source row' / '  --from=lane-a --to=lane-a', EXIT=2, and the post-run SELECT * returned the identical row ('lane-a','local:/x','/w',1,'ns','p','BODY','append','t','t','','','ok',0). tests/test_clone_lane.py runs 4 tests, all OK (exit 0): exit-2 + stderr naming --to/--from/lane, full SELECT * dump identical before/after, no DB file created when --db names a nonexistent path, and a positive control genuine clone. tests/selftest.sh:527-531 invokes tests/test_clone_lane.py inside section 12. Full suite run `bash tests/selftest.sh` (test_command from .gitreins/config.yaml) printed '  PASS  CF-357 clone_lane same-lane clone refused before the DB open, source row intact, genuine clone still lands' (line 167) and 'SELFTEST: PASS' (line 483). The three files are unchanged between the closing commit cfc1067 and HEAD 5186ee0 (git diff --stat empty), so the PASS holds at the closing commit.
clone_lane.py refuses --to == --from with exit 2 and a named stderr error before opening sqlite3, the fixture DB row is unchanged, the test is wired into selftest.sh, and bash tests/selftest.sh prints SELFTEST: PASS.

## Summary

Judge Result: CF-357

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ clone_lane.py refuses when --to equals --from: exit 2, a named error naming both arguments, and a fixture scheduler DB proves the source lane row is byte-identical after the refused run. tests/test_clone_lane.py is wired into tests/selftest.sh, and bash tests/selftest.sh prints SELFTEST: PASS at the closing commit.: scripts/clone_lane.py:68 calls refuse_same_lane(a.dst) before sqlite3.connect at line 70; refuse_same_lane (lines 38-46) prints 'REFUSED: --to and --from are the same lane (<lane>); refusing to rewrite the source row' plus '  --from=<lane> --to=<lane>' to stderr and raises SystemExit(2). Manual verification against a fixture scheduler DB: `python3 scripts/clone_lane.py --from lane-a --to lane-a ... --db $T/f.db` -> stderr 'REFUSED: --to and --from are the same lane (lane-a); refusing to rewrite the source row' / '  --from=lane-a --to=lane-a', EXIT=2, and the post-run SELECT * returned the identical row ('lane-a','local:/x','/w',1,'ns','p','BODY','append','t','t','','','ok',0). tests/test_clone_lane.py runs 4 tests, all OK (exit 0): exit-2 + stderr naming --to/--from/lane, full SELECT * dump identical before/after, no DB file created when --db names a nonexistent path, and a positive control genuine clone. tests/selftest.sh:527-531 invokes tests/test_clone_lane.py inside section 12. Full suite run `bash tests/selftest.sh` (test_command from .gitreins/config.yaml) printed '  PASS  CF-357 clone_lane same-lane clone refused before the DB open, source row intact, genuine clone still lands' (line 167) and 'SELFTEST: PASS' (line 483). The three files are unchanged between the closing commit cfc1067 and HEAD 5186ee0 (git diff --stat empty), so the PASS holds at the closing commit.
clone_lane.py refuses --to == --from with exit 2 and a named stderr error before opening sqlite3, the fixture DB row is unchanged, the test is wired into selftest.sh, and bash tests/selftest.sh prints SELFTEST: PASS.

Overall: PASS ✓

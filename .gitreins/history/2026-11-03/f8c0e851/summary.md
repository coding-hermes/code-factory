# Verdict: CF-117

**Task:** Make the selftest gate concurrency-safe: census fixtures must bind ephemeral ports instead of literal 19022-19029
**Evaluated:** 2026-11-03T20:48:59.976166
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ tests/selftest.sh cf089_run plus docs/audits/cf089-census-standin.py obtain the port the stand-in actually bound; every §22-§27 named PASS row and expected message string is preserved, §28 still passes, and the committed documentation records the before/after concurrent-arm receipt (before: one of two simultaneous runs red with 7 'Failed to connect to 127.0.0.1 port 1902x' census rows; after: both SELFTEST: PASS). No assertion deleted, renamed or loosened.: Port is obtained from the bound socket: docs/audits/cf089-census-standin.py:96-105 binds HTTPServer(("127.0.0.1", args.port), H) then writes server.server_port to PATH.tmp, fsyncs and os.replace()s onto --port-file (and prints it to stdout); tests/selftest.sh:774-806 cf089_run starts it with `--port 0 --port-file "$tmpd/port"`, polls `port=$(head -n 1 "$tmpd/port")` inside the same 50x0.05s budget, and uses that $port for the readiness curl, the BASE handed to cf089-census-recipe.sh, and the failure text. `grep -n 1902 tests/selftest.sh docs/audits/cf089-census-standin.py` -> no hits (rc=1). Syntax: `bash -n tests/selftest.sh` rc=0, `python3 -m py_compile docs/audits/cf089-census-standin.py` rc=0. Test run: `bash tests/selftest.sh` -> EXIT=0, final line `SELFTEST: PASS`, with §22-§28 all PASS (census fetch failure, HTTP 502, missing-projects/wrong-projects/nonjson, short page 865!=866, healthy 2 rows, missing total, and §28 'census README/mirror byte parity'). No assertion deleted/renamed/loosened: 53 `say "  PASS` sites at 25d1e71 and 53 at HEAD, and `diff` of the sorted PASS row-name sets and of the sorted `census: ...` expected-message sets between 25d1e71 and HEAD is empty (ROWNAMES_IDENTICAL / MSG_IDENTICAL). Documentation: docs/audits/code-factory-perf-2026-11-03-concurrency.md:57-61 records the before receipt (arm A rc=1 SELFTEST: FAIL (7) with all seven census rows red on 'Failed to connect to 127.0.0.1 port 1902{2,3,4,5,6,7,9}', arm B rc=0 SELFTEST: PASS) and lines 143-197 record the after receipt (four rounds of two simultaneous whole-gate runs, both arms rc=0 SELFTEST: PASS, port_red_lines=0). Independent live check: two simultaneous `bash tests/selftest.sh` runs at HEAD each printed 9/9 census PASS rows with 0 'Failed to connect to 127.0.0.1 port 190' lines; the residual reds in those arms were auth-marker/disk_floor rows (the CF-072 class the doc attributes), not census.
The census fixtures now bind ephemeral ports and publish the bound port via --port-file, the gate passes with all §22-§28 rows and message strings byte-identical to the pre-fix tree, and the committed audit doc carries both the before (7 red census rows on port 1902x) and after (both arms SELFTEST: PASS) concurrent receipts.

## Summary

Judge Result: CF-117

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ tests/selftest.sh cf089_run plus docs/audits/cf089-census-standin.py obtain the port the stand-in actually bound; every §22-§27 named PASS row and expected message string is preserved, §28 still passes, and the committed documentation records the before/after concurrent-arm receipt (before: one of two simultaneous runs red with 7 'Failed to connect to 127.0.0.1 port 1902x' census rows; after: both SELFTEST: PASS). No assertion deleted, renamed or loosened.: Port is obtained from the bound socket: docs/audits/cf089-census-standin.py:96-105 binds HTTPServer(("127.0.0.1", args.port), H) then writes server.server_port to PATH.tmp, fsyncs and os.replace()s onto --port-file (and prints it to stdout); tests/selftest.sh:774-806 cf089_run starts it with `--port 0 --port-file "$tmpd/port"`, polls `port=$(head -n 1 "$tmpd/port")` inside the same 50x0.05s budget, and uses that $port for the readiness curl, the BASE handed to cf089-census-recipe.sh, and the failure text. `grep -n 1902 tests/selftest.sh docs/audits/cf089-census-standin.py` -> no hits (rc=1). Syntax: `bash -n tests/selftest.sh` rc=0, `python3 -m py_compile docs/audits/cf089-census-standin.py` rc=0. Test run: `bash tests/selftest.sh` -> EXIT=0, final line `SELFTEST: PASS`, with §22-§28 all PASS (census fetch failure, HTTP 502, missing-projects/wrong-projects/nonjson, short page 865!=866, healthy 2 rows, missing total, and §28 'census README/mirror byte parity'). No assertion deleted/renamed/loosened: 53 `say "  PASS` sites at 25d1e71 and 53 at HEAD, and `diff` of the sorted PASS row-name sets and of the sorted `census: ...` expected-message sets between 25d1e71 and HEAD is empty (ROWNAMES_IDENTICAL / MSG_IDENTICAL). Documentation: docs/audits/code-factory-perf-2026-11-03-concurrency.md:57-61 records the before receipt (arm A rc=1 SELFTEST: FAIL (7) with all seven census rows red on 'Failed to connect to 127.0.0.1 port 1902{2,3,4,5,6,7,9}', arm B rc=0 SELFTEST: PASS) and lines 143-197 record the after receipt (four rounds of two simultaneous whole-gate runs, both arms rc=0 SELFTEST: PASS, port_red_lines=0). Independent live check: two simultaneous `bash tests/selftest.sh` runs at HEAD each printed 9/9 census PASS rows with 0 'Failed to connect to 127.0.0.1 port 190' lines; the residual reds in those arms were auth-marker/disk_floor rows (the CF-072 class the doc attributes), not census.
The census fixtures now bind ephemeral ports and publish the bound port via --port-file, the gate passes with all §22-§28 rows and message strings byte-identical to the pre-fix tree, and the committed audit doc carries both the before (7 red census rows on port 1902x) and after (both arms SELFTEST: PASS) concurrent receipts.

Overall: PASS ✓

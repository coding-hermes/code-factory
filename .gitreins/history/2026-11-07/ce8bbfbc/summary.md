# Verdict: CF-270

**Task:** verify-node.sh interpolates --port unescaped into a remote bash -lc
**Evaluated:** 2026-11-07T00:03:18.729311
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. The port is validated as digits before use (rejected with exit 2 otherwise). 2. A fixture proves a non-numeric port never reaches the remote command. 3. The remote invocation quotes every interpolated value. Gate: bash tests/selftest.sh prints SELFTEST: PASS.: (1) scripts/verify-node.sh:40-55 validates PORT immediately after the arg loop and before any use: `case "$PORT" in ''|*[!0-9]*) PORT_VALID=0` plus a <=5-digit length check, then `printf 'verify-node: --port must be digits 1-65535 (got: %s)' >&2; exit 2`, then `PORT=$((10#$PORT))` and a 1..65535 range check that also exits 2. (2) tests/selftest.sh:4099-4210 adds a stub-transport fixture that records argv and never executes it; arms cover not-a-port (line 4133), 0/65536/empty/' 10800' (4146), the measured injection `10800'; touch <canary>; echo '` (4160), a valid 10800 run (4179), and a pre-fix red control (4195) proving the fixture detects the defect. I re-ran the fixture manually: not-a-port, injection, 0, 65536 and empty each gave `RC=2`, `RECORDS=0`, canary absent. (3) scripts/verify-node.sh:95 `inside() { bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$1$2"' _ "$PORT" "$1" 2>/dev/null; }` — the remote body is a fixed single-quoted script and both values cross as positional args; recorded argv was `... bash -lc curl ... "http://127.0.0.1:$1$2" _ 10800 /api/status` with 0 occurrences of the canary and 0 of `127.0.0.1:10800'`. Gate: `bash tests/selftest.sh` exit 0, final line `SELFTEST: PASS`, 0 `  FAIL` lines, and all six CF-270 arms printed PASS (output lines 65-70).
Port is digit-validated with exit 2 before any use, the remote body is a fixed single-quoted script taking port/path as positional args, the fixture proves non-numeric ports never reach the transport, and `bash tests/selftest.sh` prints SELFTEST: PASS with all CF-270 arms green.

## Summary

Judge Result: CF-270

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. The port is validated as digits before use (rejected with exit 2 otherwise). 2. A fixture proves a non-numeric port never reaches the remote command. 3. The remote invocation quotes every interpolated value. Gate: bash tests/selftest.sh prints SELFTEST: PASS.: (1) scripts/verify-node.sh:40-55 validates PORT immediately after the arg loop and before any use: `case "$PORT" in ''|*[!0-9]*) PORT_VALID=0` plus a <=5-digit length check, then `printf 'verify-node: --port must be digits 1-65535 (got: %s)' >&2; exit 2`, then `PORT=$((10#$PORT))` and a 1..65535 range check that also exits 2. (2) tests/selftest.sh:4099-4210 adds a stub-transport fixture that records argv and never executes it; arms cover not-a-port (line 4133), 0/65536/empty/' 10800' (4146), the measured injection `10800'; touch <canary>; echo '` (4160), a valid 10800 run (4179), and a pre-fix red control (4195) proving the fixture detects the defect. I re-ran the fixture manually: not-a-port, injection, 0, 65536 and empty each gave `RC=2`, `RECORDS=0`, canary absent. (3) scripts/verify-node.sh:95 `inside() { bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$1$2"' _ "$PORT" "$1" 2>/dev/null; }` — the remote body is a fixed single-quoted script and both values cross as positional args; recorded argv was `... bash -lc curl ... "http://127.0.0.1:$1$2" _ 10800 /api/status` with 0 occurrences of the canary and 0 of `127.0.0.1:10800'`. Gate: `bash tests/selftest.sh` exit 0, final line `SELFTEST: PASS`, 0 `  FAIL` lines, and all six CF-270 arms printed PASS (output lines 65-70).
Port is digit-validated with exit 2 before any use, the remote body is a fixed single-quoted script taking port/path as positional args, the fixture proves non-numeric ports never reach the transport, and `bash tests/selftest.sh` prints SELFTEST: PASS with all CF-270 arms green.

Overall: PASS ✓

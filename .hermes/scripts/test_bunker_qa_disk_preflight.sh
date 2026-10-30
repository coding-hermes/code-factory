#!/bin/bash
# QA-AUGER-15 — regression test for the bunker-qa.sh DISK-CAPACITY preflight.
#
# Why this test exists: auger's clean-machine battery on bunker-mvp (95% used,
# 7.5 GB free) recorded `ci-pass FAIL native rc=120` / `upgrade FAIL rc=120` with
# EMPTY output plus `chaos-resource UNVERIFIED`, all of it caused by ENOSPC on the
# HOST before any command could run — i.e. a product-FAIL-shaped verdict produced
# by a full server. The gate must refuse such a server BEFORE the spawn and
# record exactly one harness-class `run_battery` row.
#
# The decision half is pure (df text → OK/LOW/UNKNOWN), so all three arms are
# provable offline through the harness's own `__parse-disk-free` / `__disk-gate`
# hooks. The lockstep block at the bottom fails if the harness loses the gate or
# renames a seam this test drives.
#
# Usage: bash test_bunker_qa_disk_preflight.sh [harness-path]
#   default harness = $HOME/.hermes/scripts/bunker-qa.sh
#   RED proof: pass a pre-fix copy (e.g. `git -C ~/.hermes show HEAD:scripts/bunker-qa.sh > /tmp/pre.sh`)
set -uo pipefail

HARNESS="${1:-${BUNKER_QA_SH:-$HOME/.hermes/scripts/bunker-qa.sh}}"
pass=0; fail=0
check() { # <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok   $1 -> $3"; pass=$((pass+1))
  else echo "  FAIL $1: expected [$2] got [$3]"; fail=$((fail+1)); fi
}

echo "harness: $HARNESS"
if [ ! -f "$HARNESS" ]; then echo "  FAIL harness missing"; echo; echo "RESULT: 0 passed, 1 failed"; exit 1; fi

HDR='Filesystem     1024-blocks      Used Available Capacity Mounted on'
gate() { bash "$HARNESS" __disk-gate "$1" "${2:-10}" 2>/dev/null; }

# ── arm 1: a healthy server admits the battery ───────────────────────────────
# 63,794,400 KB available ≈ 60 GB, 59% used.
check "healthy server (60 GB free) is OK" \
  "OK 60 59" \
  "$(gate "$HDR
/dev/sda1 153428672 89634272 63794400 59% /")"

# ── arm 2: the MEASURED failure shape is refused ─────────────────────────────
# bunker-mvp at 95% used / 7,070,208 KB ≈ 6 GB free — the shape that produced
# rc=120 cells with no output. 6 GB floor-10 → LOW.
check "ENOSPC-shaped server (6 GB free, 96%) is LOW" \
  "LOW 6 96" \
  "$(gate "$HDR
/dev/sda1 153428672 146358272 7070208 96% /")"

# ── arm 3: the floor boundary is exact (>= floor passes, one GB under fails) ──
# 10,485,760 KB = exactly 10 GB → OK at floor 10 (the gate is a >= floor test).
check "exactly at the floor (10 GB free) is OK" \
  "OK 10 50" \
  "$(gate "$HDR
/dev/sda1 20971520 10485760 10485760 50% /" 10)"
# 9,528,524 KB ≈ 9 GB free → LOW at floor 10, the off-by-one direction that
# must never silently pass.
check "one GB under the floor (9 GB free) is LOW" \
  "LOW 9 50" \
  "$(gate "$HDR
/dev/sda1 20971520 11425000 9528524 50% /" 10)"

# ── arm 4: the floor is overridable, and an override really moves the verdict ─
# Same healthy 60 GB reading, floor raised to 100 GB → LOW.
check "raised floor (100 GB) refuses the healthy server" \
  "LOW 60 59" \
  "$(gate "$HDR
/dev/sda1 153428672 89634272 63794400 59% /" 100)"
# Lowered floor (5 GB) admits the 6 GB ENOSPC-shaped reading — proves the arm is
# floor-driven and not a hardcoded threshold.
check "lowered floor (5 GB) admits the 6 GB server" \
  "OK 6 96" \
  "$(gate "$HDR
/dev/sda1 153428672 146358272 7070208 96% /" 5)"

# ── arm 5: an unreadable probe is UNKNOWN, never a refusal ───────────────────
# A probe hiccup must not manufacture a LOW verdict (same policy as the agent
# capacity probe: unknown ≠ full, warn and continue).
check "garbage df output is UNKNOWN"      "UNKNOWN - -" "$(gate 'not a df line')"
check "empty df output is UNKNOWN"        "UNKNOWN - -" "$(gate '')"
check "header-only df output is UNKNOWN"  "UNKNOWN - -" "$(gate "$HDR")"
# A non-numeric available column (some df variants print human units) is
# unparseable, not "0 GB free".
check "human-unit available column is UNKNOWN" "UNKNOWN - -" \
  "$(gate "$HDR
/dev/sda1 150G 84G 61G 59% /")"

# ── arm 6: the harness still carries the gate, in the right place ────────────
# Lockstep: these greps fail the moment the gate is dropped or a seam this test
# drives is renamed. They assert the REFUSAL PATH, not just the helper's presence.
lock() { # <desc> <fixed-string> <file>
  if grep -Fq -- "$2" "$3"; then echo "  ok   $1"; pass=$((pass+1))
  else echo "  FAIL $1: harness no longer contains [$2]"; fail=$((fail+1)); fi
}
lock "pure parser present"            'parse_disk_free_gb() {'        "$HARNESS"
lock "pure verdict present"           'disk_gate_verdict() {'        "$HARNESS"
lock "host probe present"             'bunker_disk() {'               "$HARNESS"
lock "floor env override present"     'BUNKER_QA_MIN_FREE_GB'         "$HARNESS"
lock "refusal row is run_battery"     '"cell":"run_battery","status":"FAIL","detail":"server %s is LOW ON DISK' "$HARNESS"
lock "refusal names the harness class" 'HARNESS-class and no product cell was produced' "$HARNESS"
lock "no-spawn refusal exits 2"       'refusing to spawn (disk-capacity error, QA-AUGER-15)' "$HARNESS"
lock "probe seam __parse-disk-free"   '__parse-disk-free)'            "$HARNESS"
lock "gate seam __disk-gate"          '__disk-gate)'                  "$HARNESS"

# The gate must live in the shared preflights() block that BOTH run() and
# launch() call — a gate installed only in one verb leaves the other ungated.
# (Capture first: `awk … | grep -q` under `set -o pipefail` fails on EPIPE once
# grep exits at its first match, which would read as a missing gate.)
pre_block=$(awk '/^preflights\(\) \{/,/^\}/' "$HARNESS")
if printf '%s\n' "$pre_block" | grep -Fq 'disk_gate_verdict'; then
  check "gate is inside preflights()" yes yes
else
  check "gate is inside preflights()" yes no
fi
# …and the disk refusal must sit AFTER the ssh reachability gate (no point
# probing df on an unreachable host) and BEFORE any spawn attempt.
sp_line=$(grep -n 'refusing to spawn (disk-capacity error' "$HARNESS" | head -1 | cut -d: -f1)
ssh_line=$(grep -n 'unreachable via ssh (tailscale) preflight' "$HARNESS" | head -1 | cut -d: -f1)
spawn_line=$(grep -n 'agent=$(spawn_agent' "$HARNESS" | head -1 | cut -d: -f1)
if [ -n "$sp_line" ] && [ -n "$ssh_line" ] && [ -n "$spawn_line" ] \
   && [ "$sp_line" -gt "$ssh_line" ] && [ "$sp_line" -lt "$spawn_line" ]; then
  check "disk gate ordered reachability → disk → spawn" yes yes
else
  check "disk gate ordered reachability → disk → spawn" \
    yes "no (disk=$sp_line ssh=$ssh_line spawn=$spawn_line)"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

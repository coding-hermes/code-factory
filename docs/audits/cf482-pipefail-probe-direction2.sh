#!/usr/bin/env bash
# CF-482 direction 2: under pipefail, `! printf | grep -q '^  PASS'` can report TRUE even
# when a PASS row IS present, because grep exits on the early match and printf takes SIGPIPE.
# That direction is a FALSE PASS: a fixture that leaked a PASS row reads as rejected.
set -uo pipefail
say() { printf '%s\n' "$*"; }

out=$(printf '  PASS  2/3 rows parse\n%s\n' "$(head -c 2000000 /dev/zero | tr '\0' 'x')")
say "payload_bytes=${#out}; a '  PASS' row IS present on line 1"

tries=${TRIES:-20}
shipped_true=0
case_true=0
for _ in $(seq 1 "$tries"); do
  # shipped shape: the arm's `! printf | grep -q '^  PASS'` clause
  if ! printf '%s\n' "$out" | grep -q '^  PASS'; then shipped_true=$((shipped_true + 1)); fi
  # case shape
  leaked=0
  case $'\n'"$out" in *$'\n'"  PASS"*) leaked=1 ;; esac
  [ "$leaked" -eq 0 ] && case_true=$((case_true + 1))
done
say "RESULTS over $tries iterations:"
say "  shipped shape (! printf|grep -q '^  PASS') reported 'no PASS row' = $shipped_true/$tries  (TRUE here = FALSE PASS)"
say "  case glob  reported 'no PASS row' = $case_true/$tries  (correct answer is 0)"

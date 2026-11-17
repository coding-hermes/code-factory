#!/usr/bin/env bash
# CF-482 direction 2: under pipefail, `! printf | grep -q '^  PASS'` can report TRUE even
# when a PASS row IS present, because grep exits on the early match and printf takes SIGPIPE.
# That direction is a FALSE PASS: a fixture that leaked a PASS row reads as rejected.
#
# CF-485: one ordering is not enough. The old probe put the PASS row first and stopped there, so
# the comparison only ever covered the shape where the early match exists to race. Two orderings
# now run side by side — a PASS row on line 1, and no PASS row anywhere — and each one names the
# correct answer, so a shape that is wrong for the OPPOSITE reason (reporting "no PASS row" when
# there is none, i.e. a false rejection) cannot hide behind the first ordering's result.
set -uo pipefail
say() { printf '%s\n' "$*"; }

tries=${TRIES:-20}
say "iterations per ordering: $tries"

# $1 = ordering label, $2 = payload, $3 = the correct number of "no PASS row" answers,
# $4 = prose describing where the PASS row is (or is not).
probe_ordering() {
  local label=$1 out=$2 correct=$3 where=$4 i shipped_true=0 case_true=0 leaked
  local shipped_word case_word
  say ""
  say "=== $label ==="
  say "  payload_bytes=${#out}; $where"
  for i in $(seq 1 "$tries"); do
    # shipped shape: the arm's `! printf | grep -q '^  PASS'` clause
    if ! printf '%s\n' "$out" | grep -q '^  PASS'; then shipped_true=$((shipped_true + 1)); fi
    # case shape
    leaked=0
    case $'\n'"$out" in *$'\n'"  PASS"*) leaked=1 ;; esac
    [ "$leaked" -eq 0 ] && case_true=$((case_true + 1))
  done
  say "  RESULTS over $tries iterations:"
  say "  shipped shape (! printf|grep -q '^  PASS') reported 'no PASS row' = $shipped_true/$tries  (correct answer: $correct)"
  say "  case glob  reported 'no PASS row' = $case_true/$tries  (correct answer: $correct)"
  # Side by side, one line, so the two shapes' answers and the right one read together.
  [ "$shipped_true" -eq 0 ] && shipped_word='a PASS row is present' || shipped_word='no PASS row'
  [ "$case_true" -eq 0 ] && case_word='a PASS row is present' || case_word='no PASS row'
  say "  side by side: grep-shape -> '$shipped_word' ($shipped_true/$tries) | case-shape -> '$case_word' ($case_true/$tries) | correct: 'no PASS row' on exactly $correct of $tries"
  if [ "$shipped_true" -eq "$correct" ]; then
    say "  verdict: grep shape agrees with the correct answer here"
  else
    say "  verdict: grep shape is WRONG here ($shipped_true/$tries vs correct $correct/$tries)"
  fi
  [ "$case_true" -eq "$correct" ] || { say "  FAIL  case shape disagreed with the correct answer"; return 1; }
  return 0
}

# Ordering 1 (kept from the original probe): a PASS row IS present, on line 1, ahead of a 2MB tail.
# The grep clause matches on line 1 and exits, printf takes SIGPIPE, `! ...` reads TRUE, so the
# shape reports "no PASS row" — a FALSE PASS. Correct answer: 0 of `tries`.
out1=$(printf '  PASS  2/3 rows parse\n%s\n' "$(head -c 2000000 /dev/zero | tr '\0' 'x')")
probe_ordering "ORDERING 1 — a PASS row IS present, on line 1" "$out1" 0 \
  "a '  PASS' row IS present on line 1"; rc1=$?

# Ordering 2: no PASS row at all, same 2MB tail. Both shapes must answer "no PASS row" every
# iteration, so the correct answer is `tries` — the shape that was accidentally right in
# ordering 1 has to be right for the right reason here.
out2=$(printf '  FAIL  board duplicate id %s: lines 1 and 2\n  FAIL  2 of 3 rows parse\n%s\n' \
  "'CF-001'" "$(head -c 2000000 /dev/zero | tr '\0' 'x')")
probe_ordering "ORDERING 2 — no PASS row anywhere" "$out2" "$tries" \
  "no '  PASS' row is present"; rc2=$?

say ""
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ]; then
  say "RESULT: OK (both orderings measured; the case shape matched the correct answer in both)"
  exit 0
fi
say "RESULT: DEFECT (the case shape disagreed with the correct answer in an ordering)"
exit 1

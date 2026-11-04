#!/usr/bin/env bash
set -uo pipefail

plan=docs/ACCEPTANCE-PLAN.md
selftest=tests/selftest.sh
while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan)
      if [ "$#" -lt 2 ]; then printf 'FAIL section-mapping: --plan requires a path\n'; exit 2; fi
      plan=$2; shift 2 ;;
    --selftest)
      if [ "$#" -lt 2 ]; then printf 'FAIL section-mapping: --selftest requires a path\n'; exit 2; fi
      selftest=$2; shift 2 ;;
    *) printf 'FAIL section-mapping: unknown argument %s\n' "$1"; exit 2 ;;
  esac
done

failures=0
fail() { printf '  FAIL  section-mapping — %s\n' "$1"; failures=$((failures + 1)); }
if [ ! -r "$plan" ]; then fail "plan file missing or unreadable: $plan"; fi
if [ ! -r "$selftest" ]; then fail "selftest file missing or unreadable: $selftest"; fi
if [ "$failures" -gt 0 ]; then printf 'RESULT: DRIFT (%s)\n' "$failures"; exit 1; fi

numbered=$(grep -oE '^say "[0-9]+\.' "$selftest" | grep -oE '[0-9]+' | sort -nu)
lettered=$(grep -oE '^say "[0-9]+[a-z]\.' "$selftest" | grep -oE '[0-9]+' | sort -nu)
# Mapping rows may name one section ("| §39 …") or a closed range ("| §22–§28 …").
# A range names every section inside it, so expand it rather than counting the first
# number only: counting the left end alone reports §23–§28 as unmapped and turns a
# legitimate range row into six false failures.
plan_sections=$(grep -oE '^\| §[0-9]+(–§?[0-9]+)?' "$plan" | sed 's/^| §//' \
  | awk -F'–§?' '{ if (NF > 1) { for (i = $1 + 0; i <= $NF + 0; i++) print i } else { print $1 + 0 } }' \
  | sort -nu)

claim_matches=$(grep -Eo 'current tree carries [0-9]+ arms' "$plan" || true)
if [ "$(printf '%s\n' "$claim_matches" | grep -c .)" -ne 1 ]; then
  fail "prose arm-count claim missing or ambiguous (expected one 'current tree carries N arms')"
  arms_plan=0
else
  arms_plan=$(printf '%s\n' "$claim_matches" | grep -oE '[0-9]+')
fi
num_count=$(printf '%s\n' "$numbered" | grep -c . || true)
letter_count=$(printf '%s\n' "$lettered" | grep -c . || true)
arms_tree=$((num_count + letter_count))

for section in $numbered; do
  if printf '%s\n' "$plan_sections" | grep -Fxq "$section"; then
    printf 'OK §%s — plan row present\n' "$section"
  else
    printf 'MISSING §%s — tree carries it, plan mapping table does not\n' "$section"
    fail "§$section missing from plan mapping table"
  fi
done
for section in $plan_sections; do
  if printf '%s\n' "$numbered" | grep -Fxq "$section"; then :; else
    printf 'EXTRA §%s — plan names it, tree has no such section\n' "$section"
    fail "tree has no section named by plan §$section"
  fi
done
printf 'arms_plan=%s arms_tree=%s\n' "$arms_plan" "$arms_tree"
if [ "$arms_plan" -ne "$arms_tree" ]; then fail "prose claims $arms_plan arms but tree carries $arms_tree"; fi
if [ "$failures" -eq 0 ]; then printf 'RESULT: OK\n'; exit 0; fi
printf 'RESULT: DRIFT (%s)\n' "$failures"
exit 1

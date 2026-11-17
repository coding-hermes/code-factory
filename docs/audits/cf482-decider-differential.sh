#!/usr/bin/env bash
# CF-482 differential: the SAME payload judged by the decider extracted from two trees.
#   pre  = tests/selftest.sh at $pre_ref (default ca013e7c, the parent of the CF-482 fix)
#   post = the working tree               (the board_fixture_verdict helper)
# Nothing is hand-copied: both deciders are extracted from the real blobs at run time.
#
# CF-485 — every path here fails CLOSED (an instrument that cannot measure must refuse, not pass):
#   * the pre blob is read from a named PRE-FIX commit. It used to be origin/main, whose
#     tests/selftest.sh already carries the CF-482 helper, so the "pre-fix" extraction measured
#     nothing and its first `[ "$rc" -eq 1 ]` belonged to a different arm. A failed read is now a
#     REFUSED exit 2, never an empty condition.
#   * the condition comes from inside the section 7b block only: this suite carries 60
#     `^  if [ "$rc" -eq 1 ]` lines, and an unbounded extraction silently grades another arm.
#   * the extracted fragment is validated (non-empty, no whitespace surprise, names the
#     `  FAIL  2 of 3 rows parse` row) BEFORE it is evaluated — eval '' returns 0, and every row
#     would read PASS.
#   * each decider is graded on its PRINTED verdict as well as its exit status: a helper that
#     returns 0 while printing a FAIL reason is a defect, and a planted helper proves the grader
#     fires.
set -uo pipefail
say() { printf '%s\n' "$*"; }

repo=${1:?usage: cf482-decider-differential.sh <repo-root>}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# CF-485: the extracted fragment is a piece of a suite arm and may reference the suite's own
# scratch root. Define one in THIS scope so the fragment is runnable (under `set -u` an unset
# `$tmpd` aborts the decider); if it still cannot run, the preflight below refuses.
tmpd=$tmp

pre_ref=${PRE_REF:-ca013e7c54fd0b284b3a40ca77e28693192669da}
refuse() { say "REFUSED: $*"; exit 2; }

# --- the pre blob, read from the pre-fix commit and refused when unreadable -------------------
pre_err=$(git -C "$repo" show "$pre_ref":tests/selftest.sh 2>&1 >"$tmp/pre.sh"); pre_rc=$?
if [ "$pre_rc" -ne 0 ]; then
  refuse "cannot read the pre-fix blob '$pre_ref:tests/selftest.sh' — ref '$pre_ref' is unresolved here; git said: $(printf '%s' "${pre_err:-no message}" | tr '\n' ' ')"
fi
[ -s "$tmp/pre.sh" ] \
  || refuse "the pre-fix blob '$pre_ref:tests/selftest.sh' is empty — an empty tree yields an empty condition, and eval '' returns 0"
cp "$repo/tests/selftest.sh" "$tmp/post.sh" \
  || refuse "cannot read the working tree's tests/selftest.sh under '$repo'"

# --- section 7b block boundaries (one rule, shared with tests/selftest.sh section 77) --------
# The block starts at the line matching `^say "7b\.` and ends at the line before the next
# `^say "` at column 0. That boundary is deliberately literal: the nested progress line
# `say "  ..    CF-482 ...` at the end of the block is itself a `^say "` line, so the block ends
# there. The arms that follow it inside section 7b (the unterminated-tail loop) compare exact
# output with producer-piped `grep -Fxq` on purpose and are outside the range this decider and
# the §77 scanner grade.
extract_7b() {  # $1=selftest file -> block on stdout; 0 ok, 3 no block
  awk '
    /^say "7b\./ { seen = 1 }
    seen && /^say "/ && !/^say "7b\./ { done_ = 1 }
    seen && !done_ { print; n++ }
    END { if (!seen) exit 3 }
  ' "$1"
}

extract_7b "$tmp/pre.sh" > "$tmp/pre_7b.sh"; rc7b=$?
if [ "$rc7b" -ne 0 ]; then
  refuse "no section 7b block in the pre-fix blob '$pre_ref:tests/selftest.sh' (rc=$rc7b) — nothing matches ^say \"7b\\., so the pre-fix decider cannot be extracted"
fi
pre7b_lines=$(wc -l < "$tmp/pre_7b.sh")
[ "$pre7b_lines" -gt 0 ] || refuse "the section 7b block of '$pre_ref:tests/selftest.sh' is empty — the pre-fix decider cannot be extracted"

# pre: the inline condition, from `if [ "$rc" -eq 1 ]` up to (not including) `; then`,
# searched INSIDE the 7b block only.
awk '/^  if \[ "\$rc" -eq 1 \]/{f=1} f{print} f&&/; then$/{exit} END{if(!f) exit 3}' \
  "$tmp/pre_7b.sh" > "$tmp/pre_cond.raw"; ac_rc=$?
[ "$ac_rc" -eq 0 ] \
  || refuse "the section 7b block of '$pre_ref:tests/selftest.sh' carries no ^  if [ \"\$rc\" -eq 1 ] decider (rc=$ac_rc)"
sed 's/^  if //; s/; then$//' "$tmp/pre_cond.raw" > "$tmp/pre_cond.sh"
# post: the single helper call that replaced it
grep -m1 -F 'if verdict=$(board_fixture_verdict "$out" "$rc" "$expected"); then' "$tmp/post.sh" \
  | sed 's/^  if //; s/; then$//' > "$tmp/post_cond.sh"
# post: the helper itself, extracted verbatim
awk '/^board_fixture_verdict\(\) \{/{f=1} f{print} f&&/^}$/{exit}' "$tmp/post.sh" > "$tmp/helper.sh"

# --- validate the extraction before anything evaluates it -----------------------------------
pre_cond_lines=$(wc -l < "$tmp/pre_cond.sh")
[ "$pre_cond_lines" -gt 0 ] \
  || refuse "the extracted pre-fix condition is empty — eval '' returns 0 and every row would read PASS, so nothing is decided"
pre_first=$(head -1 "$tmp/pre_cond.sh")
case $pre_first in
  [[:space:]]*) refuse "the extracted pre-fix condition starts with whitespace ('$pre_first') — the leading \`  if \` strip did not apply, so this is not a condition" ;;
esac
case $pre_first in
  *'-eq 1'*) ;;
  *) refuse "the extracted pre-fix condition does not test the exit status ('$pre_first') — the extraction picked the wrong line" ;;
esac
grep -Fq '2 of 3 rows parse' "$tmp/pre_cond.sh" \
  || refuse "the extracted pre-fix condition does not name the '  FAIL  2 of 3 rows parse' row — section 7b's decider must assert both FAIL rows"
grep -Fq 'grep' "$tmp/pre_cond.sh" \
  || refuse "the extracted pre-fix condition carries no grep term — this is not section 7b's decider"
[ -s "$tmp/post_cond.sh" ] \
  || refuse "the working tree's section 7b no longer carries the board_fixture_verdict call — nothing to compare the pre-fix decider against"
[ -s "$tmp/helper.sh" ] \
  || refuse "the working tree's tests/selftest.sh carries no board_fixture_verdict() helper"

say "=== extracted pre-fix condition ($pre_ref section 7b: $pre7b_lines lines) ==="
sed 's/^/  | /' "$tmp/pre_cond.sh"
say "=== extracted post-fix condition ==="
sed 's/^/  | /' "$tmp/post_cond.sh"
say "=== helper lines: $(wc -l < "$tmp/helper.sh") ==="

# shellcheck disable=SC1091
. "$tmp/helper.sh"
pre_cond=$(cat "$tmp/pre_cond.sh")
post_cond=$(cat "$tmp/post_cond.sh")

# --- preflight: a fragment that cannot RUN is a refusal, not a verdict ----------------------
# `set -u` turns an unset suite variable into an abort whose status is indistinguishable from a
# legitimate "condition false", so the error text is what separates them. The probe payload
# satisfies the row assertions the real condition makes, so evaluation reaches every term —
# a short-circuiting probe would only ever exercise the first one and would miss exactly the
# unset-variable abort this check exists for.
preflight_ok=1
probe_out=$( ( out="  FAIL  board duplicate id 'CF-001': lines 1 and 2
  FAIL  2 of 3 rows parse"; rc=1; expected="board duplicate id 'CF-001': lines 1 and 2"
           arm=duplicate-id; eval "$pre_cond" ) 2>"$tmp/probe.err" )
probe_err=$(cat "$tmp/probe.err")
case $probe_err in
  *'unbound variable'*|*'command not found'*|*'syntax error'*)
    preflight_ok=0
    refuse "the extracted pre-fix condition cannot run in this scope: $(printf '%s' "$probe_err" | tr '\n' ' ' | sed 's/  */ /g')" ;;
esac
say "=== preflight: pre-fix condition runs under set -u (probe_ok=$preflight_ok) ==="

# --- deciders: each prints the helper's own text and returns the helper's status ------------
# The decider is the subject, so its stdout is the evidence and its status is the verdict; the
# wrapper below keeps BOTH instead of discarding the text the way the old decide_post did.
pre_decider() {  # $1=out $2=rc $3=expected -> prints nothing (the inline condition has no text)
  out=$1; rc=$2; expected=$3; arm=duplicate-id
  eval "$pre_cond"
}
post_decider() {  # $1=out $2=rc $3=expected -> prints board_fixture_verdict's decision
  local st=0
  out=$1; rc=$2; expected=$3; arm=duplicate-id; verdict=""
  eval "$post_cond" || st=$?
  printf '%s' "$verdict"
  return "$st"
}
planted_decider() {  # $1=out $2=rc $3=expected -> the planted helper, through the same path
  out=$1; rc=$2; expected=$3
  planted_fixture_verdict "$out" "$rc" "$expected"
}

# CF-485 planted helper: returns 0 — the value a PASS is read from — while printing the helper's
# own FAIL reason. The differential must name this a defect, not a pass.
cat > "$tmp/planted_helper.sh" <<'PLANT'
planted_fixture_verdict() {  # $1=out $2=rc $3=expected
  printf 'rc=%s; named FAIL row absent' "$2"
  return 0
}
PLANT
# shellcheck disable=SC1091
. "$tmp/planted_helper.sh"

dec_ok=1; dec_status=; dec_printed=; dec_err=
run_decider() {  # $1=decider fn, $2=out $3=rc $4=expected -> sets dec_status/dec_printed/dec_ok
  dec_err=
  dec_printed=$("$1" "$2" "$3" "$4" 2>"$tmp/dec.err"); dec_status=$?
  dec_err=$(cat "$tmp/dec.err")
  dec_ok=1
  case $dec_err in
    *'unbound variable'*|*'command not found'*|*'syntax error'*) dec_ok=0 ;;
  esac
  [ "$dec_ok" -eq 1 ] \
    || refuse "decider $1 could not run (status $dec_status): $(printf '%s' "$dec_err" | tr '\n' ' ' | sed 's/  */ /g')"
}

# --- the grader: the printed verdict is graded, not only the exit status ---------------------
# The helper's success sentence is quoted verbatim, so the bare word "leaked" inside it is not
# mistaken for the FAIL reason "board_arm leaked a PASS row".
success_sentence='named FAIL row present; 2-of-3 row present; no PASS row leaked'
grade=
grade_decider() {  # $1=status $2=printed -> sets grade; returns 1 when the pair is a defect
  local st=$1 txt=$2 is_success=0
  case $txt in *"$success_sentence"*) is_success=1 ;; esac
  if [ "$st" -eq 0 ] && [ "$is_success" -eq 0 ]; then
    case $txt in
      *absent*|*leaked*|*'exit '*)
        grade='DEFECT (helper printed a FAIL reason with exit 0)'
        return 1 ;;
    esac
  fi
  if [ "$st" -ne 0 ] && [ "$is_success" -eq 1 ]; then
    grade="DEFECT (helper printed the success sentence with exit $st)"
    return 1
  fi
  grade=CLEAN
  return 0
}

cases=0; post_wrong=0; case_fail=0; planted_caught=no
# row <label> <correct answer> [expected-grade]
# Prints one decided row and asserts the grade against `expected-grade` (default CLEAN). The
# planted helper is the one case whose EXPECTED grade is a defect: it exists to prove the grader
# fires, so catching it is a pass and missing it is the failure.
row() {
  local label=$1 correct=$2 expect=${3:-CLEAN} flat decision
  flat=$(printf '%s' "$dec_printed" | tr '\n' ' ')
  if [ "$dec_status" -eq 0 ]; then decision=PASS; else decision=FAIL; fi
  grade_decider "$dec_status" "$dec_printed"
  say "  $label -> status=$dec_status decision=$decision printed='$flat'  probe_ok=$dec_ok  (correct answer: $correct)  grader=$grade"
  cases=$((cases + 1))
  [ "$grade" = "$expect" ] || { say "  FAIL  $label grader='$grade', expected '$expect'"; return 1; }
  return 0
}
# post_row also asserts the post decider AGREES with the correct answer: the CF-482 claim is that
# the helper decides these cases, so a disagreement is an instrument failure, not data.
post_row() {
  local correct=$2
  row "$1" "$correct" CLEAN || return 1
  if { [ "$correct" = PASS ] && [ "$dec_status" -ne 0 ]; } \
     || { [ "$correct" = FAIL ] && [ "$dec_status" -eq 0 ]; }; then
    say "  FAIL  post decider disagrees with the correct answer ($correct) on this case"
    post_wrong=$((post_wrong + 1))
    return 1
  fi
  return 0
}
check() { "$@" || case_fail=$((case_fail + 1)); }

exp="board duplicate id 'CF-001': lines 1 and 2"
base='  FAIL  board duplicate id '"'"'CF-001'"'"': lines 1 and 2
  FAIL  2 of 3 rows parse'
tailbytes=${TAILBYTES:-2000000}
tail=$(head -c "$tailbytes" /dev/zero | tr '\0' 'x')

say ""
say "--- case A: a correct rejection (matching payload, ~${tailbytes}B tail) ---"
payload_a="$base
$tail"
run_decider pre_decider  "$payload_a" 1 "$exp"; check row      pre  PASS
run_decider post_decider "$payload_a" 1 "$exp"; check post_row post PASS

say ""
say "--- case B: a fixture that LEAKED a PASS row (must be refused) ---"
payload_b="  PASS  3/3 rows parse
$base
$tail"
run_decider pre_decider  "$payload_b" 1 "$exp"; check row      pre  FAIL
run_decider post_decider "$payload_b" 1 "$exp"; check post_row post FAIL

say ""
say "--- case C: wrong exit status ---"
run_decider pre_decider  "$base" 0 "$exp"; check row      pre  FAIL
run_decider post_decider "$base" 0 "$exp"; check post_row post FAIL

say ""
say "--- case D: right-looking output, missing the named FAIL row ---"
run_decider pre_decider  '  FAIL  2 of 3 rows parse' 1 "$exp"; check row      pre  FAIL
run_decider post_decider '  FAIL  2 of 3 rows parse' 1 "$exp"; check post_row post FAIL

say ""
say "--- case E: the small payload the suite really produces, 200 iterations each ---"
small="$base"
pre_div=0; post_div=0; pre_pass=0; post_pass=0
for _ in $(seq 1 200); do
  run_decider pre_decider "$small" 1 "$exp"
  [ "$dec_status" -eq 0 ] && pre_pass=$((pre_pass + 1)) || pre_div=$((pre_div + 1))
  run_decider post_decider "$small" 1 "$exp"
  [ "$dec_status" -eq 0 ] && post_pass=$((post_pass + 1)) || post_div=$((post_div + 1))
done
say "  pre  PASS $pre_pass/200, disagreed with itself $pre_div/200   (0 = deterministic at this size)"
say "  post PASS $post_pass/200, disagreed with itself $post_div/200  (200 = deterministic at this size)"
[ "$post_div" -eq 0 ] || { say "  FAIL  post decider was not deterministic over 200 identical runs"; post_wrong=$((post_wrong + 1)); }
[ "$pre_div" -eq 0 ] || say "  note  the pre-fix decider disagrees with itself at this size (the CF-482 flake)"

say ""
say "--- case F: a leaked PASS row FIRST, the two FAIL rows last, ~2MB between them ---"
# Ordering: the negated clause matches on line 1 and exits (SIGPIPE), while the two
# affirmative greps must read to EOF to find their rows, so they still succeed.
# All three conditions then read TRUE and a fixture that leaked PASS is certified.
payload_f="  PASS  3/3 rows parse
$tail
$base"
run_decider pre_decider  "$payload_f" 1 "$exp"; check row      pre  FAIL
run_decider post_decider "$payload_f" 1 "$exp"; check post_row post FAIL

say ""
say "--- case G: planted helper — prints a FAIL reason, returns 0 ---"
# The planted helper answers PASS (status 0) to a payload whose correct answer is FAIL, so it is
# a false green by construction. Catching it is this case's PASS condition; missing it means the
# grader is decoration.
run_decider planted_decider "$base" 1 "$exp"
check row planted FAIL 'DEFECT (helper printed a FAIL reason with exit 0)'
case $grade in DEFECT*) planted_caught=yes ;; esac

say ""
say "--- real helper, graded on its printed verdict ---"
run_decider post_decider "$base" 1 "$exp"
grade_decider "$dec_status" "$dec_printed"
say "  post printed '$dec_printed' (exit $dec_status) -> grader=$grade"

say ""
say "cases decided: $cases; planted helper caught: $planted_caught; post disagreements: $post_wrong; failed rows: $case_fail"
if [ "$case_fail" -eq 0 ] && [ "$post_wrong" -eq 0 ] && [ "$planted_caught" = yes ]; then
  say "RESULT: OK (every case decided, the planted helper was caught, the real helper graded clean)"
  exit 0
fi
say "RESULT: DEFECT — the differential itself is unsound (see the rows above)"
exit 1

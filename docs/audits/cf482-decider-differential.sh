#!/usr/bin/env bash
# CF-482 differential: the SAME payload judged by the decider extracted from two trees.
#   pre  = origin/main:tests/selftest.sh  (the inline three-condition pipeline)
#   post = the working tree               (the board_fixture_verdict helper)
# Nothing is hand-copied: both deciders are sed-extracted from the real blobs at run time.
set -uo pipefail
say() { printf '%s\n' "$*"; }

repo=${1:?usage: cf482-decider-differential.sh <repo-root>}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git -C "$repo" show origin/main:tests/selftest.sh > "$tmp/pre.sh"
cp "$repo/tests/selftest.sh" "$tmp/post.sh"

# pre: the inline condition, from `if [ "$rc" -eq 1 ]` up to (not including) `; then`
awk '/^  if \[ "\$rc" -eq 1 \]/{f=1} f{print} f&&/; then$/{exit}' "$tmp/pre.sh" \
  | sed 's/^  if //; s/; then$//' > "$tmp/pre_cond.sh"
# post: the single helper call that replaced it
grep -m1 -F 'if verdict=$(board_fixture_verdict "$out" "$rc" "$expected"); then' "$tmp/post.sh" \
  | sed 's/^  if //; s/; then$//' > "$tmp/post_cond.sh"
# post: the helper itself, extracted verbatim
awk '/^board_fixture_verdict\(\) \{/{f=1} f{print} f&&/^}$/{exit}' "$tmp/post.sh" > "$tmp/helper.sh"

say "=== extracted pre-fix condition ==="; sed 's/^/  | /' "$tmp/pre_cond.sh"
say "=== extracted post-fix condition ==="; sed 's/^/  | /' "$tmp/post_cond.sh"
say "=== helper lines: $(wc -l < "$tmp/helper.sh") ==="

# shellcheck disable=SC1091
. "$tmp/helper.sh"
pre_cond=$(cat "$tmp/pre_cond.sh")
post_cond=$(cat "$tmp/post_cond.sh")

decide_pre()  { out="$1"; rc="$2"; expected="$3"; arm=duplicate-id
                if eval "$pre_cond"; then printf 'PASS'; else printf 'FAIL'; fi; }
decide_post() { out="$1"; rc="$2"; expected="$3"; arm=duplicate-id; verdict=""
                if eval "$post_cond"; then printf 'PASS'; else printf 'FAIL'; fi; }

exp="board duplicate id 'CF-001': lines 1 and 2"
base='  FAIL  board duplicate id '"'"'CF-001'"'"': lines 1 and 2
  FAIL  2 of 3 rows parse'
tailbytes=${TAILBYTES:-2000000}
tail=$(head -c "$tailbytes" /dev/zero | tr '\0' 'x')

say ""
say "--- case A: a correct rejection (matching payload, ~${tailbytes}B tail) ---"
payload_a="$base
$tail"
say "  pre  -> $(decide_pre  "$payload_a" 1 "$exp")   (correct answer: PASS)"
say "  post -> $(decide_post "$payload_a" 1 "$exp")   (correct answer: PASS)"

say ""
say "--- case B: a fixture that LEAKED a PASS row (must be refused) ---"
payload_b="  PASS  3/3 rows parse
$base
$tail"
say "  pre  -> $(decide_pre  "$payload_b" 1 "$exp")   (correct answer: FAIL)"
say "  post -> $(decide_post "$payload_b" 1 "$exp")   (correct answer: FAIL)"

say ""
say "--- case C: wrong exit status ---"
say "  pre  -> $(decide_pre  "$base" 0 "$exp")   (correct answer: FAIL)"
say "  post -> $(decide_post "$base" 0 "$exp")   (correct answer: FAIL)"

say ""
say "--- case D: right-looking output, missing the named FAIL row ---"
say "  pre  -> $(decide_pre  '  FAIL  2 of 3 rows parse' 1 "$exp")   (correct answer: FAIL)"
say "  post -> $(decide_post '  FAIL  2 of 3 rows parse' 1 "$exp")   (correct answer: FAIL)"

say ""
say "--- case E: the small payload the suite really produces, 200 iterations each ---"
small="$base"
pre_div=0; post_div=0
for _ in $(seq 1 200); do
  [ "$(decide_pre  "$small" 1 "$exp")" = PASS ] || pre_div=$((pre_div + 1))
  [ "$(decide_post "$small" 1 "$exp")" = PASS ] || post_div=$((post_div + 1))
done
say "  pre  disagreed with itself $pre_div/200   (0 = deterministic at this size)"
say "  post disagreed with itself $post_div/200  (0 = deterministic at this size)"

say ""
say "--- case F: a leaked PASS row FIRST, the two FAIL rows last, ~2MB between them ---"
# Ordering: the negated clause matches on line 1 and exits (SIGPIPE), while the two
# affirmative greps must read to EOF to find their rows, so they still succeed.
# All three conditions then read TRUE and a fixture that leaked PASS is certified.
payload_f="  PASS  3/3 rows parse
$tail
$base"
say "  pre  -> $(decide_pre  "$payload_f" 1 "$exp")   (correct answer: FAIL)"
say "  post -> $(decide_post "$payload_f" 1 "$exp")   (correct answer: FAIL)"

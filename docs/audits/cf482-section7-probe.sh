#!/usr/bin/env bash
# Fast targeted run of section 7 + 7b only, using the REAL blocks extracted from the tree.
# The full suite is the authority; this exists so the arm can be re-probed in seconds.
set -uo pipefail
repo=${1:?usage: cf482-section7-probe.sh <repo-root>}
HERE="$repo"
. "$HERE/scripts/lib.sh"
fails=0
tmpd=$(mktemp -d)
trap 'rm -rf "$tmpd"' EXIT

sed -n '/^# BEGIN board-arm/,/^# END board-arm/p' "$HERE/tests/selftest.sh" > "$tmpd/arm.sh"
sed -n '/^board_fixture_verdict() {/,/^}$/p' "$HERE/tests/selftest.sh" > "$tmpd/helper.sh"
sed -n '/^say "7\. the board is valid JSONL"/,/^rm -rf "\$tmpd"$/p' "$HERE/tests/selftest.sh" \
  | sed '$d' > "$tmpd/driver.sh"

say "blocks: arm=$(wc -l < "$tmpd/arm.sh") helper=$(wc -l < "$tmpd/helper.sh") driver=$(wc -l < "$tmpd/driver.sh")"
# shellcheck disable=SC1090
. "$tmpd/arm.sh"
# shellcheck disable=SC1090
. "$tmpd/helper.sh"
# shellcheck disable=SC1090
. "$tmpd/driver.sh"

say "TARGETED_FAILS=$fails"
[ "$fails" -eq 0 ]

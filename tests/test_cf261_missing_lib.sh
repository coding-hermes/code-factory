#!/usr/bin/env bash
# CF-261: the control-host provisioner must refuse a missing bootstrap library.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT
mkdir -p "$tmpd/fixture" "$tmpd/home" || exit 1
cp "$ROOT/scripts/bunker-provision.sh" "$tmpd/fixture/bunker-provision.sh" || exit 1
printf 'PROJECT=fixture\nREPO=https://example.invalid/x.git\n' > "$tmpd/config"
out=$(env -i PATH=/usr/bin:/bin HOME="$tmpd/home" bash \
  "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config" --check 2>&1); rc=$?
expected="  FAIL  lib.sh — missing or unreadable: $tmpd/fixture/lib.sh"
fail() {
  printf 'CF-261 FAIL: %s; rc=%s; output follows\n%s\n' "$1" "$rc" "$out"
  exit 1
}
[ "$rc" -ne 0 ] || fail 'missing library reported success'
printf '%s\n' "$out" | grep -Fxq "$expected" || fail 'missing exact named lib.sh refusal'
if printf '%s\n' "$out" | grep -q '^  PASS  '; then
  fail 'missing library emitted a PASS row'
fi
if printf '%s\n' "$out" | grep -q 'command not found'; then
  fail 'missing library reached an undefined helper'
fi
printf 'CF-261 PASS\n'

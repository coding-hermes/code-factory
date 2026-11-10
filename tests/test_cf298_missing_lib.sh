#!/usr/bin/env bash
# CF-298: missing bootstrap library must fail closed, with or without nounset.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT
mkdir -p "$tmpd/normal" "$tmpd/no-nounset" "$tmpd/home"
cp "$ROOT/scripts/project-node.sh" "$tmpd/normal/project-node.sh"
awk '{ if ($0 == "set -uo pipefail") print "set -o pipefail"; else print }' \
  "$ROOT/scripts/project-node.sh" > "$tmpd/no-nounset/project-node.sh"
for variant in normal no-nounset; do
  out=$(env -i PATH=/nonexistent HOME="$tmpd/home" /bin/bash \
    "$tmpd/$variant/project-node.sh" --check --project fixture --layers 10 2>&1); rc=$?
  expected="  FAIL  lib.sh — missing or unreadable: $tmpd/$variant/lib.sh"
  if [ "$rc" -ne 1 ] || ! printf '%s\n' "$out" | /bin/grep -Fxq "$expected"; then
    printf 'CF-298 FAIL: %s rc=%s; output follows\n%s\n' "$variant" "$rc" "$out"
    exit 1
  fi
  printf '  PASS  %s: named lib.sh FAIL, exit %s\n' "$variant" "$rc"
done
printf 'CF-298 PASS\n'

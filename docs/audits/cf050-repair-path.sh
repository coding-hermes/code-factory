#!/usr/bin/env bash
# CF-050 repair-path probe: exercise the publication gate in offline fixtures.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/scripts/lib.sh"

EXIT=0
tmpd=$(mktemp -d)
trap 'rm -rf "$tmpd"' EXIT

gate_src=$(sed -n '/^cf050_publish_gate()/,/^}/p' "$ROOT/tests/selftest.sh")
eval "$gate_src"

fixture_init() {
  local dir="$1"
  git init -q -b trunk "$dir"
  git -C "$dir" config user.name fixture
  git -C "$dir" config user.email fixture@example.invalid
  mkdir -p "$dir/docs"
}

leak_line=$(printf '/%s/%s/leak\n' home "${USER:-user}")

# A: the committed leak is removed in the index, so publication is safe.
repair="$tmpd/repair"
fixture_init "$repair"
printf '%s' "$leak_line" > "$repair/docs/leak.md"
git -C "$repair" add docs/leak.md
git -C "$repair" commit -qm fixture
git -C "$repair" rm -q docs/leak.md
out=$(cf050_publish_gate "$repair" 0 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq 'REPAIR: 1 committed path staged for removal: docs/leak.md'; then
  say 'REPAIR: allowed'
else
  printf '%s\n' "$out"
  EXIT=1
fi

# B: a fresh leak staged for publication remains refused.
fresh="$tmpd/fresh"
fixture_init "$fresh"
printf '%s' "$leak_line" > "$fresh/docs/leak.md"
git -C "$fresh" add docs/leak.md
out=$(cf050_publish_gate "$fresh" 0 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'paths: docs/leak.md'; then
  say 'LEAK: refused'
else
  printf '%s\n' "$out"
  EXIT=1
fi

# C: a committed leak still carried by the index remains refused.
untouched="$tmpd/untouched"
fixture_init "$untouched"
printf '%s' "$leak_line" > "$untouched/docs/leak.md"
git -C "$untouched" add docs/leak.md
git -C "$untouched" commit -qm fixture
out=$(cf050_publish_gate "$untouched" 0 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'paths: docs/leak.md'; then
  say 'LEAK: refused'
else
  printf '%s\n' "$out"
  EXIT=1
fi

say "EXIT=$EXIT"
exit "$EXIT"

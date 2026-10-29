#!/usr/bin/env bash
# install-opencode.sh — adapter for the opencode harness.
#
# UNVERIFIED: this repo has not measured an opencode install inside a bunker. The method is
# documented and the check is real; --apply is refused until someone runs it and records the
# ladder in specs/HARNESS.md. An unverified installer must not pretend to be supported.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"

MODE="${1:---check}"
say "harness: opencode (UNVERIFIED adapter)"

p=$(have opencode)
if [ -n "$p" ]; then
  ok "binary" "$p"
  ok "version" "$("$p" --version 2>/dev/null | head -1)"
else
  bad "binary" "absent — no opencode in this node"
fi

if [ -x "$HOME/.opencode/bin/opencode" ]; then ok "user_space_binary" "$HOME/.opencode/bin/opencode"; else warn "user_space_binary" "not installed under \$HOME"; fi

# Its non-interactive surface is the contract (specs/HARNESS.md §"what a foreign harness must gain").
if [ -n "$p" ] && "$p" --help 2>/dev/null | grep -qi 'run\|exec\|serve'; then
  ok "non_interactive" "a run/exec/serve mode is advertised"
else
  warn "non_interactive" "could not confirm a non-interactive mode"
fi

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — the opencode install ladder is unmeasured here. Measure it, record it in specs/HARNESS.md, then implement this leg."
  say ""; say "OPENCODE: FAIL ($FAILED)"; exit 1
fi

say ""
[ "$FAILED" -eq 0 ] && { say "OPENCODE: PASS"; exit 0; } || { say "OPENCODE: FAIL ($FAILED)"; exit 1; }

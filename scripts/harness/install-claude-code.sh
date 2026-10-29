#!/usr/bin/env bash
# install-claude-code.sh — adapter for Claude Code.
#
# The binding constraint is node: claude-code ships via npm, and node is absent from the base
# image. This adapter therefore proves the *prerequisite* first and refuses --apply without it.
# UNVERIFIED: no claude-code install has been measured inside a bunker yet.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"

MODE="${1:---check}"
say "harness: claude-code (UNVERIFIED adapter)"

p=$(have claude)
if [ -n "$p" ]; then
  ok "binary" "$p"
  ok "version" "$("$p" --version 2>/dev/null | head -1)"
else
  bad "binary" "absent"
fi

n=$(have node); np=$(have npm)
if [ -n "$n" ]; then ok "node" "$n ($("$n" --version 2>/dev/null))"; else bad "node" "absent — claude-code cannot install without it"; fi
if [ -n "$np" ]; then ok "npm" "$np"; else bad "npm" "absent"; fi

# Auth surface: an API key or a login token must exist, or the harness cannot run unattended.
if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -f "$HOME/.claude/.credentials.json" ]; then
  ok "auth" "a credential surface exists (value not read)"
else
  warn "auth" "no ANTHROPIC_API_KEY and no ~/.claude/.credentials.json — unattended runs will fail"
fi

if [ "$MODE" = "--apply" ]; then
  if [ -z "$n" ]; then
    bad "apply" "refused — install node first (user-space tarball, pinned); claude-code depends on it"
  else
    bad "apply" "refused — the claude-code ladder is unmeasured here; measure and record it first"
  fi
  say ""; say "CLAUDE-CODE: FAIL ($FAILED)"; exit 1
fi

say ""
[ "$FAILED" -eq 0 ] && { say "CLAUDE-CODE: PASS"; exit 0; } || { say "CLAUDE-CODE: FAIL ($FAILED)"; exit 1; }

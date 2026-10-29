#!/usr/bin/env bash
# bunker-server-install.sh — the control-host side: is this machine able to run the factory?
#
#   ./bunker-server-install.sh --check     # measure, exit non-zero on a gap
#   ./bunker-server-install.sh --apply     # install what is missing (user-space)
#
# A "bunker server" is the daemon that hosts agents. It is NOT the same machine as the
# scheduler: the control host designs work, the bunker server runs nodes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

SERVER="${BUNKER_SERVER:-bunker-mvp}"
JSON=0
[ "${1:-}" = "--json" ] && JSON=1

say "bunker server: $SERVER"

# 1. the client
b=$(have bunker)
if [ -n "$b" ]; then
  v=$("$b" --version 2>/dev/null | head -1)
  ok "bunker_client" "$b ${v:-（version not reported）}"
else
  bad "bunker_client" "missing — no way to create or reach agents"
fi

# 2. the config that names the server
cfg="${BUNKER_CONFIG:-$HOME/.config/bunker/config.yaml}"
if [ -f "$cfg" ]; then
  ok "bunker_config" "$cfg"
  if grep -q "$SERVER" "$cfg" 2>/dev/null; then ok "server_declared" "$SERVER present in config"; else bad "server_declared" "$SERVER not found in $cfg"; fi
else
  bad "bunker_config" "missing ($cfg) — the client has no server to talk to"
fi

# 3. the server answers
if [ -n "$b" ]; then
  out=$("$b" list --server "$SERVER" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    n=$(printf '%s\n' "$out" | grep -cE '^\s{2}[a-z0-9][a-z0-9-]{2,}' || true)
    ok "server_reachable" "$SERVER answered (agents listed: ${n:-0})"
    running=$(printf '%s\n' "$out" | grep -c 'running' || true)
    ok "agents_running" "${running:-0} running"
  else
    bad "server_reachable" "$SERVER did not answer: $(printf '%s' "$out" | head -1)"
  fi
fi

# 4. capacity: the host, not this machine
if [ -n "$b" ] && [ "${rc:-1}" -eq 0 ]; then
  st=$("$b" status --server "$SERVER" 2>&1 | head -20)
  say "$st" | sed 's/^/  ..    /'
  say "$st" | grep -qi 'orphan' && warn "residue" "orphan homes/keys reported by the server — reap before scaling"
fi

# 5. the control host's own prerequisites
for t in python3 git curl jq; do
  p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (needed for the control-side scripts)"
done
require_disk "$HOME" 5 || true

say ""
if [ "$FAILED" -eq 0 ]; then say "RESULT: PASS"; exit 0; else say "RESULT: FAIL ($FAILED)"; exit 1; fi

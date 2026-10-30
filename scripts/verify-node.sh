#!/usr/bin/env bash
# verify-node.sh — control host: is this node actually usable?
#
#   ./verify-node.sh --agent <id> [--server <name>] [--port 10800] --artifact <path-on-node>
#
# Checks, in order of what they prove:
#   1. the agent is alive and exec-able
#   2. the gateway answers from HERE over the tailnet (not from inside itself)
#   3. the gateway's auth gate is closed (unauthenticated request must be 401/302)
#   4. (optional) an artifact on the node hashes the same on both sides
# A version string is not evidence: step 2 must be a live HTTP answer from this host.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

AGENT="" SERVER="${BUNKER_SERVER:?set BUNKER_SERVER to your bunker server name}" PORT=10800 ARTIFACT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --artifact) ARTIFACT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$AGENT" ] && { echo "usage: $0 --agent ID [--port P] --artifact PATH"; exit 2; }
[ -z "$ARTIFACT" ] && { echo "--artifact is required: verification must include a control-host digest" >&2; exit 2; }

say "verify node $AGENT"

# 1. alive
out=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'echo ALIVE $(hostname)' 2>&1)
case "$out" in
  ALIVE*) ok "agent_alive" "$(printf '%s' "$out" | head -1)" ;;
  *) bad "agent_alive" "$(printf '%s' "$out" | head -1)"; say ""; say "RESULT: FAIL"; exit 1 ;;
esac

# 2. gateway reachable from the control host
ip=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'hostname -I' 2>/dev/null | awk '{print $1}')
if [ -z "$ip" ]; then bad "node_ip" "could not read hostname -I"; else ok "node_ip" "$ip"; fi
url="http://$ip:$PORT/api/status"
code=$(curl -s -o /tmp/node-status.json -w '%{http_code}' --max-time 8 "$url" 2>/dev/null || echo 000)
if [ "$code" = 200 ]; then
  ok "gateway_reachable" "$url -> 200"
  grep -q '"auth_required":true' /tmp/node-status.json 2>/dev/null \
    && ok "auth_gate" "auth_required:true (a public bind must not be open)" \
    || bad "auth_gate" "auth_required is not true — check dashboard.basic_auth"
else
  bad "gateway_reachable" "$url -> $code (is the harness running on 0.0.0.0:$PORT?)"
fi

# 3. unauthenticated access must be refused
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://$ip:$PORT/api/system/stats" 2>/dev/null || echo 000)
case "$code" in
  401|302|403) ok "unauth_refused" "/api/system/stats -> $code" ;;
  200) bad "unauth_refused" "/api/system/stats -> 200 — the node is OPEN to the tailnet" ;;
  *) bad "unauth_refused" "/api/system/stats -> $code — expected 401, 302, or 403" ;;
esac

# 4. artifact integrity: the node-reported hash is compared with bytes pulled here.
case "$ARTIFACT" in
  *[!A-Za-z0-9_./~:-]*) echo "--artifact contains unsupported shell characters" >&2; exit 2 ;;
esac
remote=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc "sha256sum -- $ARTIFACT 2>/dev/null | cut -d' ' -f1")
tmp=$(mktemp)
if bunker exec --server "$SERVER" "$AGENT" --raw -- bash -lc "cat -- $ARTIFACT" > "$tmp" 2>/dev/null; then
  local_h=$(sha256sum "$tmp" | cut -d' ' -f1)
else
  local_h=""
fi
rm -f "$tmp"
if [ -n "$remote" ] && [ "$remote" = "$local_h" ]; then
  ok "artifact_digest" "$(basename "$ARTIFACT") ${local_h:0:12} on both sides"
else
  bad "artifact_digest" "node ${remote:0:12} vs host ${local_h:0:12} — bytes differ or file missing"
fi

say ""
if [ "$FAILED" -eq 0 ]; then say "VERIFY: PASS"; exit 0; else say "VERIFY: FAIL ($FAILED)"; exit 1; fi

#!/usr/bin/env bash
# Control-host plumbing checks and scoped artifact snapshot; not a work round trip.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
AGENT="" SERVER="${BUNKER_SERVER:-}" PORT=10800 ARTIFACT="" DISPATCH=""
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || { echo "missing value: $1" >&2; exit 2; }
  case "$1" in
    --agent) AGENT="$2" ;;
    --server) SERVER="$2" ;;
    --port) PORT="$2" ;;
    --artifact) ARTIFACT="$2" ;;
    --dispatch-id) DISPATCH="$2" ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift 2
done
if ! python3 "$HERE/node-contract.py" verify-input "$AGENT" "$SERVER" "$PORT" ||
   ! python3 "$HERE/node-contract.py" artifact-path "$ARTIFACT" "$DISPATCH"; then
  bad "artifact_scope" "invalid options or path outside dispatch/manifest contract"; exit 2
fi

scratch=$(mktemp -d) || exit 1
trap 'rm -rf "$scratch"' EXIT
say "verify node $AGENT"
# Before ANY remote shell command, inspect and read through no-follow directory
# descriptors using a direct python argv. Send source, not a path to an untrusted helper.
if ! bunker exec --server "$SERVER" "$AGENT" --raw -- python3 -c "$(<"$HERE/node-contract.py")" \
    artifact-read "$ARTIFACT" "$DISPATCH" >"$scratch/artifact.json"; then
  bad "artifact_scope" "remote no-follow read refused or transfer failed"; exit 1
fi
if local_h=$(python3 "$HERE/node-contract.py" artifact-verify "$scratch/artifact.json"); then
  ok "artifact_digest" "${local_h:0:12} recomputed from transferred snapshot"
else
  bad "artifact_digest" "invalid snapshot or bytes differ"; exit 1
fi

out=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'echo ALIVE $(hostname)' 2>&1)
case "$out" in
  ALIVE*) ok "agent_alive" "$(printf '%s' "$out" | head -1)" ;;
  *) bad "agent_alive" "$(printf '%s' "$out" | head -1)"; exit 1 ;;
esac
ip=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'hostname -I' 2>/dev/null | awk '{print $1}')
if [ -z "$ip" ]; then bad "node_ip" "could not read hostname -I"; exit 1; else ok "node_ip" "$ip"; fi
url="http://$ip:$PORT/api/status"
code=$(curl -s -o "$scratch/status.json" -w '%{http_code}' --max-time 8 "$url" 2>/dev/null || echo 000)
if [ "$code" = 200 ]; then
  ok "gateway_reachable" "$url -> 200"
  python3 - "$scratch/status.json" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as stream:
        valid = json.load(stream).get('auth_required') is True
except (ValueError, OSError, AttributeError):
    valid = False
sys.exit(0 if valid else 1)
PY
  [ "$?" -eq 0 ] && ok "auth_gate" "auth_required:true" || bad "auth_gate" "auth_required is not true"
else
  bad "gateway_reachable" "$url -> $code"
fi
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://$ip:$PORT/api/system/stats" 2>/dev/null || echo 000)
case "$code" in
  401|302|403) ok "unauth_refused" "/api/system/stats -> $code" ;;
  *) bad "unauth_refused" "/api/system/stats -> $code — expected 401, 302, or 403" ;;
esac
if [ "$FAILED" -eq 0 ]; then say "VERIFY: PASS"; exit 0; else say "VERIFY: FAIL ($FAILED)"; exit 1; fi

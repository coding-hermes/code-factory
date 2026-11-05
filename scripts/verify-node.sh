#!/usr/bin/env bash
# verify-node.sh — control host: is this node actually usable?
#
#   ./verify-node.sh --agent <id> [--server <name>] [--port 10800]
#   ./verify-node.sh --agent <id> --artifact <path-on-node>
#   ./verify-node.sh --agent <id> --strict-freshness
#
# Checks, in order of what they prove:
#   1. the agent is alive and exec-able
#   2. the gateway answers from HERE over the tailnet (not from inside itself)
#   3. the gateway's auth gate is closed (unauthenticated request must be 401/302/403)
#   4. (optional) an artifact on the node hashes the same on both sides
#   5. the checkout the node will work is the tree origin/main has (CF-244)
# A version string is not evidence: step 2 must be a live HTTP answer from this host.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

AGENT="" SERVER="${BUNKER_SERVER:-}" PORT=10800 ARTIFACT="" STRICT_FRESHNESS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --artifact) ARTIFACT="$2"; shift 2 ;;
    --strict-freshness) STRICT_FRESHNESS=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$AGENT" ] && { echo "usage: $0 --agent ID [--server NAME] [--port P] [--artifact PATH] [--strict-freshness]"; exit 2; }
# The old guard used ${VAR:?} at assignment time, so --server could never be used without the
# environment variable being set first: the documented flag was dead.
[ -z "$SERVER" ] && { echo "set BUNKER_SERVER or pass --server <name>" >&2; exit 2; }

UNVERIFIED=0
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
# curl writes 000 itself on failure; appending `|| echo 000` produced "000000", which matched no
# case and fell through to a FAIL that named a code no HTTP server can return.
code=$(curl -s -o /tmp/node-status.json -w '%{http_code}' --max-time 8 "$url" 2>/dev/null); code=${code:-000}

# A bunker container has no address the control host can reach unless a transport is published, so
# "000" here means UNVERIFIED, not broken. The distinction matters: FAIL sends an operator to fix a
# node that works, PASS would be a lie, so UNVERIFIED is its own verdict (CF-224) — and it must name
# the transport it could not use.
inside() { bunker exec --server "$SERVER" "$AGENT" -- bash -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 5 'http://127.0.0.1:$PORT$1'" 2>/dev/null; }

if [ "$code" = 200 ]; then
  ok "gateway_reachable" "$url -> 200"
  grep -Eq '"auth_required"[[:space:]]*:[[:space:]]*true[[:space:]]*[,}]' /tmp/node-status.json 2>/dev/null \
    && ok "auth_gate" "auth_required:true (a public bind must not be open)" \
    || bad "auth_gate" "/api/status -> $code; auth_required:true not measured — check dashboard.basic_auth"
elif [ "$code" = 000 ]; then
  in_code=$(inside /api/status)
  case "$in_code" in
    200)
      warn "gateway_reachable" "no transport from this host to $ip:$PORT — the gateway answers 200 INSIDE the node, so this is unverified, not failed (CF-224: publish a port or define the transport)"
      UNVERIFIED=1 ;;
    *)
      warn "gateway_reachable" "no transport to $ip:$PORT, and the gateway does not answer inside the node either ($in_code) — the harness is not up"
      UNVERIFIED=1 ;;
  esac
else
  bad "gateway_reachable" "$url -> $code (is the harness running on 0.0.0.0:$PORT?)"
fi

# 3. unauthenticated access must be refused
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://$ip:$PORT/api/system/stats" 2>/dev/null); code=${code:-000}
case "$code" in
  401|302|403) ok "unauth_refused" "/api/system/stats -> $code" ;;
  200) bad "unauth_refused" "/api/system/stats -> 200 — the node is OPEN to the tailnet" ;;
  000)
    in_code=$(inside /api/system/stats)
    case "$in_code" in
      401|302|403) warn "unauth_refused" "unverified from here (no transport); inside the node it answers $in_code" ;;
      200)         bad "unauth_refused" "/api/system/stats -> 200 INSIDE the node — the gateway is open" ;;
      *)           warn "unauth_refused" "unverified: no transport from here, and $in_code inside the node" ;;
    esac
    UNVERIFIED=1 ;;
  *) bad "unauth_refused" "/api/system/stats -> $code — auth refusal not verified" ;;
esac

# 4. optional artifact integrity
if [ -n "$ARTIFACT" ]; then
  remote=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc "sha256sum $(shq "$ARTIFACT") 2>/dev/null | cut -d' ' -f1")
  tmp=$(mktemp)
  bunker exec --server "$SERVER" "$AGENT" --raw -- cat "$ARTIFACT" > "$tmp" 2>/dev/null
  local_h=$(sha256sum "$tmp" | cut -d' ' -f1); rm -f "$tmp"
  if [ -n "$remote" ] && [ "$remote" = "$local_h" ]; then
    ok "artifact_digest" "$(basename "$ARTIFACT") ${local_h:0:12} on both sides"
  else
    bad "artifact_digest" "node ${remote:0:12} vs host ${local_h:0:12} — bytes differ or file missing"
  fi
fi

# 5. the checkout the node will work (CF-244)
# Steps 1-4 prove the agent answers, the gateway is up and the gate is closed —
# none of them looks at the tree. A node one commit behind origin/main, or one
# carrying a local edit that blocks its own fast-forward, passed every one of
# them. scripts/node_freshness.py measures branch/HEAD/ancestor/lag/uncommitted
# paths in ONE bunker exec and its verdict is folded in here, so `VERIFY: PASS`
# is unreachable for a drifted node.
#
# Default mapping: PASS -> PASS, drift or dirty -> FAIL, unmeasurable -> WARN
# (a node still being provisioned has no checkout yet, and "cannot measure" is
# not proof of staleness — the same doctrine as repo_freshness.py). With
# --strict-freshness an unmeasurable checkout is a FAIL, so a gate can refuse on
# "unknown" as well as on "drifted".
FRESH="$HERE/node_freshness.py"
if [ ! -r "$FRESH" ]; then
  bad "checkout_freshness" "$FRESH missing — the checkout's git state is unmeasured"
else
  fresh_rows=$(mktemp); fresh_json=$(mktemp)
  python3 -B "$FRESH" --agent "$AGENT" --server "$SERVER" --json >"$fresh_json" 2>"$fresh_rows"
  frc=$?
  case "$frc" in
    0)
      ok "checkout_freshness" "$(grep -F '  PASS  freshness — ' "$fresh_rows" | sed -e 's/^  PASS  freshness — //' | head -1)"
      ;;
    1)
      bad "checkout_freshness" "$(grep -E '^  FAIL  ' "$fresh_rows" | sed -e 's/^  *FAIL  //' | paste -sd '|' - | sed -e 's/|/ | /g' | cut -c1-500)"
      ;;
    *)
      detail=$(grep -E '^RESULT: ' "$fresh_rows" | head -1 | sed -e 's/^RESULT: //')
      if [ "${STRICT_FRESHNESS:-0}" -eq 1 ]; then
        bad "checkout_freshness" "${detail:-unmeasurable} (--strict-freshness: unknown is not a pass)"
      else
        warn "checkout_freshness" "${detail:-unmeasurable} — the checkout could not be measured; pass --strict-freshness to refuse it"
      fi
      ;;
  esac
  rm -f "$fresh_rows" "$fresh_json"
fi

say ""
if [ "$FAILED" -gt 0 ]; then say "VERIFY: FAIL ($FAILED)"; exit 1; fi
if [ "${UNVERIFIED:-0}" -gt 0 ]; then
  say "VERIFY: UNVERIFIED — the node answered inside itself, but this host has no transport to it"
  say "        (distinct from FAIL on purpose: nothing is broken and nothing is proven — CF-224)"
  exit 3
fi
say "VERIFY: PASS"; exit 0

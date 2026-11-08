#!/usr/bin/env bash
# bunker-crier-connect.sh — control host: put ONE bunker agent on the crier bus and prove it.
#
#   bunker-crier-connect.sh --agent cf-node --server bunker-las-03 --url http://<control-host>:8767 \
#                           --project code-factory --check
#   bunker-crier-connect.sh ... --apply
#   bunker-crier-connect.sh ... --stage     (write the identity only; probe deferred)
#
# Separate from provisioning on purpose: connecting is its own failure surface (identity not
# accepted, route missing, guard refusing) and it must be re-runnable without touching the
# clone, the harness or the credentials.
#
# --apply writes $HOME/.node/crier.json inside the agent (names only, mode 600) and then
# PROBES the inbox route. It reports CONNECTED only when the route answers 200 for that
# agent id; any other answer is a FAIL naming the code (403 GUARD_BLOCKED, 404, 000).
#
# Idempotent: rewrites the identity file only when a value differs, and never restarts
# anything on the node.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

AGENT="" SERVER="" URL="" PROJECT="" MODE="" TIMEOUT=10

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

probe() {  # probe -> prints the http code for this agent's inbox
  local code
  code=$(curl -s -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "$URL/agents/$AGENT/inbox?limit=1" 2>/dev/null || true)
  printf '%s' "${code:-000}"
}

check() {
  SIGNED_READ=0
say "crier-connect --check — agent=$AGENT url=$URL"
  [ -n "$AGENT" ] || { bad "agent" "AGENT unset"; return 1; }
  [ -n "$URL" ] || { bad "url" "URL unset"; return 1; }

  local health code
  health=$(curl -s -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "$URL/health" 2>/dev/null || true)
  case "${health:-000}" in
    200) ok "bus_health" "$URL/health -> 200" ;;
    *)   bad "bus_health" "$URL/health -> ${health:-000} (bus not answering)" ;;
  esac

  # A hardened bus answers 401 to an unsigned GET by design, so an unsigned probe cannot
  # distinguish "not registered" from "not signed". When the node holds its key and bearer,
  # probe FROM the node with the worker, which signs; only fall back to the plain read when it
  # cannot, and then 401 is a WARN with the reason rather than a failure.
  local via_node=""
  if [ -x "$(command -v bunker 2>/dev/null)" ] && [ -n "$SERVER" ]; then
    via_node=$(timeout 45 bunker exec --server "$SERVER" "$AGENT" -- bash -lc \
      'if [ -s "$HOME/.node/agent.key" ] && [ -s "$HOME/.node/auth/crier.token" ] && [ -f "$HOME/node-bus-worker.py" ]; then CRIER_URL='"$URL"' python3 "$HOME/node-bus-worker.py" --check 2>&1 | grep -E "PASS  inbox|FAIL  inbox" | head -1; fi' 2>/dev/null || true)
  fi
  if [ -n "$via_node" ]; then
    case "$via_node" in
      *"PASS  inbox"*)
        ok "inbox" "signed read accepted on the node: $via_node"; SIGNED_READ=1
        # The requirement names <crier>/agents/<agent>/inbox, so that exact route is measured from
        # this host as well and its code named. It is a note, not a gate: a hardened bus answers 401
        # to an unsigned read even for a registered agent, so it can never by itself prove connection.
        note "inbox_host $URL/agents/$AGENT/inbox -> $(probe) (unsigned, from this control host)" ;;
      *)               bad "inbox" "the node's own signed probe failed: $via_node" ;;
    esac
    if [ "${FAILED:-0}" -gt 0 ]; then
      say ""
      say "CRIER: NOT CONNECTED (${FAILED})"
      return 1
    fi
  else
  code=$(probe)
  case "$code" in
    200) ok "inbox" "$URL/agents/$AGENT/inbox -> 200 (unsigned: proves the route, not this agent's key)" ;;
    401) warn "inbox" "$URL/agents/$AGENT/inbox -> 401 — expected for an unsigned read (crier checks the signer before it looks the agent up); the signed probe needs agent.key + crier.token on the node" ;;
    403) bad "inbox" "$URL/agents/$AGENT/inbox -> 403 (owner mismatch or guard refused)" ;;
    404) bad "inbox" "$URL/agents/$AGENT/inbox -> 404 (agent is genuinely not registered on the bus)" ;;
    000) bad "inbox" "$URL/agents/$AGENT/inbox -> 000 (no answer: refused, unresolvable or timed out — the URL or the route to it, not the agent)" ;;
    *)   bad "inbox" "$URL/agents/$AGENT/inbox -> $code" ;;
  esac
  fi

  # the node-side identity must agree with the host we just probed
  local b json
  b=$(have bunker) || { bad "identity" "no bunker client on PATH"; return 1; }
  json=$(timeout 45 "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'cat "$HOME/.node/crier.json" 2>/dev/null || echo absent' 2>/dev/null || echo absent)
  case "$json" in
    absent) bad "identity" "\$HOME/.node/crier.json absent — run --apply" ;;
    *"$AGENT"*) case "$json" in
                  *"$URL"*) ok "identity" "node points at $URL as $AGENT" ;;
                  *) bad "identity" "node points elsewhere: $json" ;;
                esac ;;
    *) bad "identity" "node identity names a different agent: $json" ;;
  esac

  say ""
  # CONNECTED is a claim about a SIGNED read. An unsigned 200 (a bus without auth) and an unsigned 401
  # (a hardened bus, which is the normal answer) both prove nothing about this agent's key, so neither
  # may print CONNECTED: that would be the requirement weakened to fit a probe (quorum round 2, B3).
  if [ "$FAILED" -ne 0 ]; then
    say "CRIER: NOT CONNECTED ($FAILED)"
  elif [ "${SIGNED_READ:-0}" -eq 1 ]; then
    say "CRIER: CONNECTED — $AGENT at $URL (signed read accepted)"
  else
    say "CRIER: UNVERIFIED — $AGENT at $URL: the bus answered an UNSIGNED read, so this node's key and"
    say "        bearer were not exercised. Install $HOME/.node/agent.key and ~/.node/auth/crier.token"
    say "        and stage the bus worker, then re-run --check."
    return 3
  fi
  [ "$FAILED" -eq 0 ]
}

stage() {
  local b tmp
  b=$(have bunker)
  [ -n "$b" ] || { bad "bunker_cli" "no bunker client on PATH"; return 1; }
  tmp=$(mktemp); chmod 600 "$tmp"
  printf '{"agent":"%s","project":"%s","url":"%s","staged_at":"%s"}\n' \
    "$AGENT" "${PROJECT:-$AGENT}" "$URL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  if "$b" cp "$tmp" "$AGENT:.node/crier.json" --server "$SERVER" >/dev/null 2>&1 &&
     "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod 600 "$HOME/.node/crier.json"' >/dev/null 2>&1; then
    ok "identity" "staged \$HOME/.node/crier.json (agent=$AGENT url=$URL)"
  else
    bad "identity" "could not stage \$HOME/.node/crier.json"; rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"
}

apply() {
  local b tmp
  say "crier-connect --apply — agent=$AGENT url=$URL"
  b=$(have bunker)
  [ -n "$b" ] || { bad "bunker_cli" "no bunker client on PATH"; return 1; }
  tmp=$(mktemp); chmod 600 "$tmp"
  printf '{"agent":"%s","project":"%s","url":"%s","connected_at":"%s"}\n' \
    "$AGENT" "${PROJECT:-$AGENT}" "$URL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  if "$b" cp "$tmp" "$AGENT:.node/crier.json" --server "$SERVER" >/dev/null 2>&1 &&
     "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod 600 "$HOME/.node/crier.json"' >/dev/null 2>&1; then
    ok "identity" "wrote \$HOME/.node/crier.json (agent=$AGENT)"
  else
    bad "identity" "could not write \$HOME/.node/crier.json"; rm -f "$tmp"; return 1
  fi
  rm -f "$tmp"
  # probing is the only thing that can say CONNECTED
  check
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --url|--crier-url) URL="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --check|--apply|--stage) MODE="${1#--}"; shift ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done

[ -n "$MODE" ] || usage 2
[ -n "$SERVER" ] || { say "--server is required (the agent's bunker host)"; exit 2; }
case "$MODE" in check) check ;; apply) apply ;; stage) stage ;; esac

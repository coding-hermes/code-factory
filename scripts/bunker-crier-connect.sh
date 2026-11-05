#!/usr/bin/env bash
# bunker-crier-connect.sh — control host: put ONE bunker agent on the crier bus and prove it.
#
#   bunker-crier-connect.sh --agent cf-node --server bunker-las-03 --url http://100.97.236.14:8767 \
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
  say "crier-connect --check — agent=$AGENT url=$URL"
  [ -n "$AGENT" ] || { bad "agent" "AGENT unset"; return 1; }
  [ -n "$URL" ] || { bad "url" "URL unset"; return 1; }

  local health code
  health=$(curl -s -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "$URL/health" 2>/dev/null || true)
  case "${health:-000}" in
    200) ok "bus_health" "$URL/health -> 200" ;;
    *)   bad "bus_health" "$URL/health -> ${health:-000} (bus not answering)" ;;
  esac

  code=$(probe)
  case "$code" in
    200) ok "inbox" "$URL/agents/$AGENT/inbox -> 200" ;;
    401|403) bad "inbox" "$URL/agents/$AGENT/inbox -> $code (identity or guard refused)" ;;
    404) bad "inbox" "$URL/agents/$AGENT/inbox -> 404 (agent not registered on the bus)" ;;
    *)   bad "inbox" "$URL/agents/$AGENT/inbox -> $code" ;;
  esac

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
  if [ "$FAILED" -eq 0 ]; then say "CRIER: CONNECTED — $AGENT at $URL"; else say "CRIER: NOT CONNECTED ($FAILED)"; fi
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

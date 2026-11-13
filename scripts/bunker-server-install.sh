#!/usr/bin/env bash
# bunker-server-install.sh — the control-host side: is this machine able to run the factory?
#
#   ./bunker-server-install.sh --check [--json]        # measure, exit non-zero on a gap
#   ./bunker-server-install.sh --reap-orphans [--json] # remove named orphan homes and keys (CF-003)
#
# Accepted flags are --check, --json, and --reap-orphans. The unimplemented generic
# install mode is recognized only to refuse --apply explicitly; it is not a usage mode.
#
# A "bunker server" is the daemon that hosts agents. It is NOT the same machine as the
# scheduler: the control host designs work, the bunker server runs nodes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

SERVER="${BUNKER_SERVER:-}"
JSON=0
REAP_ORPHANS=0
APPLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) ;;
    --json) JSON=1 ;;
    --reap-orphans) REAP_ORPHANS=1 ;;
    --apply) APPLY=1 ;;
    *)
      printf '  FAIL  usage — unsupported option %s; accepted: --check, --json, --reap-orphans\n' "$1"
      printf 'RESULT: FAIL (usage)\n'
      exit 2
      ;;
  esac
  shift
done

if [ "$APPLY" -eq 1 ]; then
  printf '  FAIL  apply — unsupported: no measured user-space install path exists for bunker-server-install.sh\n'
  printf 'RESULT: FAIL (apply unsupported)\n'
  exit 2
fi

if [ -z "$SERVER" ]; then
  bad "server_declared" "BUNKER_SERVER unset — the client has no server to talk to"
  say ""
  say "RESULT: FAIL ($FAILED)"
  exit 1
fi

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
  # CF-003: an orphan home/key is disk the next node needs. With the server's homes/keys
  # directories named, the reaper measures them against the live agent list; without them
  # this stays the WARN it has always been (the layout is declared, never guessed).
  if [ -n "${BUNKER_HOMES_DIR:-}" ] || [ -n "${BUNKER_KEYS_DIR:-}" ]; then
    reg_tmp=$(mktemp) || reg_tmp=""
    if [ -n "$reg_tmp" ]; then
      printf '%s\n' "$("$b" list --server "$SERVER" 2>/dev/null)" > "$reg_tmp"
      reap_args=(reap --registry "$reg_tmp")
      [ -n "${BUNKER_HOMES_DIR:-}" ] && reap_args+=(--homes-dir "$BUNKER_HOMES_DIR")
      [ -n "${BUNKER_KEYS_DIR:-}" ] && reap_args+=(--keys-dir "$BUNKER_KEYS_DIR")
      [ "${REAP_ORPHANS:-0}" -eq 1 ] && reap_args+=(--apply)
      if reap_out=$(python3 "$HERE/node_hygiene.py" "${reap_args[@]}" 2>&1); then
        printf '%s\n' "$reap_out"
      else
        printf '%s\n' "$reap_out"
        reap_fails=$(printf '%s\n' "$reap_out" | grep -c '^  FAIL') || true
        FAILED=$((FAILED + reap_fails))
        [ "$reap_fails" -eq 0 ] && bad "residue" "reaper exited non-zero without a FAIL row"
      fi
      rm -f "$reg_tmp"
    fi
  else
    say "$st" | grep -qi 'orphan' && warn "residue" "orphan homes/keys reported by the server — set BUNKER_HOMES_DIR/BUNKER_KEYS_DIR and re-run with --reap-orphans"
  fi
fi

# 5. the control host's own prerequisites
for t in python3 git curl jq; do
  p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (needed for the control-side scripts)"
done
require_disk "$HOME" 5 || true

say ""
if [ "$FAILED" -eq 0 ]; then say "RESULT: PASS"; exit 0; else say "RESULT: FAIL ($FAILED)"; exit 1; fi

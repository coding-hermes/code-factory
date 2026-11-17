#!/usr/bin/env bash
# bunker-server-install.sh — the control-host side: is this machine able to run the factory?
#
#   ./bunker-server-install.sh --check [--json]        # measure, exit non-zero on a gap
#   ./bunker-server-install.sh --reap-orphans [--json] # remove named orphan homes and keys (CF-003)
#   ./bunker-server-install.sh --apply                # refuse: no measured install path exists
#
# Accepted flags are --check, --json, --reap-orphans, and --apply. The generic install
# mode is recognized only to refuse --apply explicitly; it is not a usage mode.
#
# --check exit status. A leaking host is not a warning: any non-zero server-reported
# residue count (orphan users / orphan homes / orphan keys / stale linger entries) is a
# counted FAIL row, so the run ends `RESULT: FAIL (N)` and exits 1. All-zero counts end
# `RESULT: PASS` and exit 0, and an unparseable status block stays a WARN with exit 0
# (residue unmeasured, not clean).
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

# CF-483: the server's status block LABELS its counts with the word "orphan", so matching that word
# measures nothing — it printed the same WARN on a host reporting 0 orphans and on one leaking a home
# per destroyed node. Parse the four numbers and let the numbers decide. Prints "users homes keys
# linger"; prints nothing and exits 1 when the block does not carry that shape, because "unmeasured"
# must never be read as "0" (that is the same defect in a new place). The caller below is the only
# consumer: read the four fields in that order.
residue_counts() {  # residue_counts <status text>
  printf '%s\n' "${1:-}" | awk '
    /^[[:space:]]*Residue:/ { if (!found) { found = 1; line = $0 } }
    END {
      if (!found) exit 1
      sub(/^.*Residue:[[:space:]]*/, "", line)
      if (split(line, got, ",") < 4) exit 1
      split("orphan users,orphan homes,orphan keys,stale linger entr", want, ",")
      out = ""
      for (i = 1; i <= 4; i++) {
        f = tolower(got[i])
        if (index(f, want[i]) == 0) exit 1
        if (!match(f, /[0-9]+/)) exit 1
        out = (i == 1) ? substr(f, RSTART, RLENGTH) : out " " substr(f, RSTART, RLENGTH)
      }
      print out
    }'
}

# 4. capacity: the host, not this machine
if [ -n "$b" ] && [ "${rc:-1}" -eq 0 ]; then
  st=$("$b" status --server "$SERVER" 2>&1 | head -20)
  say "$st" | sed 's/^/  ..    /'
  # CF-003: an orphan home/key is disk the next node needs. With the server's homes/keys
  # directories named, the reaper measures them against the live agent list; without them
  # this stays the WARN it has always been (the layout is declared, never guessed).
  if [ -n "${BUNKER_HOMES_DIR:-}" ] || [ -n "${BUNKER_KEYS_DIR:-}" ]; then
    # Reuse the successful list response above. A second list call could fail after the
    # reachability check and produce an empty registry, which would make every old entry
    # look orphaned. An empty or missing registry is never a safe deletion authority.
    reg_tmp=$(mktemp) || reg_tmp=""
    if [ -z "$reg_tmp" ]; then
      bad "residue" "cannot create a temporary registry snapshot — refusing cleanup"
    else
      printf '%s\n' "$out" > "$reg_tmp"
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
  elif [ "$REAP_ORPHANS" -eq 1 ]; then
    bad "residue" "--reap-orphans requires BUNKER_HOMES_DIR or BUNKER_KEYS_DIR — refusing unmeasured cleanup"
  else
    residue_values=$(residue_counts "$st" 2>/dev/null) || residue_values=""
    if [ -n "$residue_values" ]; then
      read -r orphan_users orphan_homes orphan_keys stale_linger <<< "$residue_values"
      residue_report="$orphan_users orphan users, $orphan_homes orphan homes, $orphan_keys orphan keys, $stale_linger stale linger entries (server-reported)"
      if [ "$orphan_users" -eq 0 ] && [ "$orphan_homes" -eq 0 ] \
        && [ "$orphan_keys" -eq 0 ] && [ "$stale_linger" -eq 0 ]; then
        ok "residue" "$residue_report"
      else
        # A measured leak is a counted FAIL, not a warning: automation reads the exit
        # status, and a WARN here made a leaking host indistinguishable from a clean one
        # (CF-495).
        bad "residue" "$residue_report — inspect/reap with node_hygiene.py reap (CF-003); BUNKER_HOMES_DIR/BUNKER_KEYS_DIR must name server-side directories accessible from this control host"
      fi
    else
      warn "residue" "server-reported counts could not be parsed — residue is unmeasured; inspect bunker status --server $SERVER and use node_hygiene.py reap (CF-003) with the server-side directories accessible from this control host"
    fi
  fi
fi

# 5. the control host's own prerequisites
for t in python3 git curl jq; do
  p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (needed for the control-side scripts)"
done
require_disk "$HOME" 5 || true

say ""
if [ "$FAILED" -eq 0 ]; then say "RESULT: PASS"; exit 0; else say "RESULT: FAIL ($FAILED)"; exit 1; fi

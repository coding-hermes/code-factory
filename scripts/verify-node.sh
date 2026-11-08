#!/usr/bin/env bash
# verify-node.sh — control host: is this node actually usable?
#
#   ./verify-node.sh --agent <id> [--server <name>] [--port 10800]
#                    [--transport node-address|published-port|tunnel|bunker-exec [--transport-address HOST:PORT]]
#   ./verify-node.sh --agent <id> --artifact <path-on-node>
#   ./verify-node.sh --agent <id> --strict-freshness
#
# Checks, in order of what they prove:
#   1. the agent is alive and exec-able
#   2. the gateway answers from HERE over a NAMED transport (never from inside the node — CF-224)
#   3. the gateway's auth gate is closed (unauthenticated request must be 401/302/403)
#   4. (optional) an artifact on the node hashes the same on both sides
#   5. the checkout the node will work is the tree origin/main has (CF-244)
#   6. the seed the node carries is the digests its seed record still names (CF-250)
#   7. the harness the manifest records is the one on the node (CF-006)
# A version string is not evidence: step 2 must be a live HTTP answer from this host.
# A bunker node has NO LAN address by default, so its own address is not a transport this host can
# use: --transport published-port (a port published on the bunker host) or --transport tunnel (an
# SSH forward opened here) carries the probe; --transport bunker-exec runs it inside the node and
# can therefore never certify one. specs/NODE.md "Transport" is the contract.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

AGENT="" SERVER="${BUNKER_SERVER:-}" PORT=10800 ARTIFACT="" STRICT_FRESHNESS=0 STRICT_SEED=0
# CF-224: the transport that carries the gateway probe. Default is the node's own address (the LAN
# case, unchanged). NODE_TRANSPORT / NODE_TRANSPORT_ADDRESS let a spawn path (node-create.sh, which
# inherits this environment) declare a bunker transport without new argv plumbing; the flags win.
TRANSPORT="${NODE_TRANSPORT:-node-address}"
TRANSPORT_ADDR="${NODE_TRANSPORT_ADDRESS:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --transport) TRANSPORT="$2"; shift 2 ;;
    --transport-address) TRANSPORT_ADDR="$2"; shift 2 ;;
    --artifact) ARTIFACT="$2"; shift 2 ;;
    --strict-freshness) STRICT_FRESHNESS=1; shift ;;
    --strict-seed) STRICT_SEED=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$AGENT" ] && { echo "usage: $0 --agent ID [--server NAME] [--port P] [--transport T [--transport-address HOST:PORT]] [--artifact PATH] [--strict-freshness] [--strict-seed]"; exit 2; }
# CF-270: --port was taken verbatim into PORT and then expanded LOCALLY inside a double-quoted
# string that was handed to a REMOTE `bash -lc`, so
#     --port "10800'; touch /tmp/cf270-canary; echo '"
# broke out of the single quotes and executed on the node (measured: the remote command became
# `... 'http://127.0.0.1:10800'; touch /tmp/cf270-canary; echo '/api/status'`). A port is an
# integer in 1..65535 or it is a usage error, and 2 is the code `unknown arg` and a missing
# --agent already use. Validate it HERE, before ANY use of it.
case "$PORT" in
  ''|*[!0-9]*) PORT_VALID=0 ;;
  *) PORT_VALID=1 ;;
esac
# Five digits is the widest possible port; refusing a longer string keeps the base-10 expansion
# below inside the shell's integer range instead of making it print its own overflow error.
[ "${#PORT}" -le 5 ] || PORT_VALID=0
if [ "$PORT_VALID" -ne 1 ]; then
  printf 'verify-node: --port must be digits 1-65535 (got: %s)\n' "$PORT" >&2
  exit 2
fi
PORT=$((10#$PORT))
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  printf 'verify-node: --port must be digits 1-65535 (got: %s)\n' "$PORT" >&2
  exit 2
fi
# The old guard used ${VAR:?} at assignment time, so --server could never be used without the
# environment variable being set first: the documented flag was dead.
[ -z "$SERVER" ] && { echo "set BUNKER_SERVER or pass --server <name>" >&2; exit 2; }

# CF-224: resolve/validate the transport BEFORE any probe, so a bad value is a usage refusal naming
# the accepted set instead of a run that probes something nobody declared.
case "$TRANSPORT" in
  node-address|published-port|tunnel|bunker-exec) : ;;
  *)
    printf 'verify-node: --transport must be node-address, published-port, tunnel or bunker-exec (got: %s)\n' "$TRANSPORT" >&2
    exit 2 ;;
esac
T_HOST="" T_PORT=""
case "$TRANSPORT" in
  published-port|tunnel)
    case "$TRANSPORT_ADDR" in
      '') printf 'verify-node: --transport %s needs --transport-address HOST:PORT — the endpoint on THIS host that forwards to the node (nothing is invented)\n' "$TRANSPORT" >&2; exit 2 ;;
    esac
    case "$TRANSPORT_ADDR" in
      *:*) T_HOST="${TRANSPORT_ADDR%:*}" T_PORT="${TRANSPORT_ADDR##*:}" ;;
      *) T_HOST="" T_PORT="" ;;
    esac
    if [ -z "$T_HOST" ] || [ -z "$T_PORT" ]; then
      printf 'verify-node: --transport-address must be HOST:PORT (got: %s)\n' "$TRANSPORT_ADDR" >&2
      exit 2
    fi
    # The same digit rule as --port, for the same reason: a value that reaches a shell must be an
    # integer and nothing else. This one is only ever used by the LOCAL curl (never interpolated
    # into a remote body), but a silent non-numeric port would still make curl report a transport
    # gap that is really a typo.
    case "$T_PORT" in
      ''|*[!0-9]*) T_PORT_OK=0 ;;
      *) T_PORT_OK=1 ;;
    esac
    [ "${#T_PORT}" -le 5 ] || T_PORT_OK=0
    if [ "$T_PORT_OK" -ne 1 ]; then
      printf 'verify-node: --transport-address port must be digits 1-65535 (got: %s)\n' "$T_PORT" >&2
      exit 2
    fi
    T_PORT=$((10#$T_PORT))
    if [ "$T_PORT" -lt 1 ] || [ "$T_PORT" -gt 65535 ]; then
      printf 'verify-node: --transport-address port must be digits 1-65535 (got: %s)\n' "$T_PORT" >&2
      exit 2
    fi
    ;;
  *)
    # An address with no transport that uses one is a half-declaration: refuse it rather than
    # ignore a value the operator believes is in force.
    [ -z "$TRANSPORT_ADDR" ] || {
      printf 'verify-node: --transport-address is used by --transport published-port|tunnel only (got --transport %s)\n' "$TRANSPORT" >&2
      exit 2
    } ;;
esac

# UNVERIFIED is not one story: a leg can be unmeasurable because this host has no transport to
# the node (CF-224) or because the thing it measures cannot be read at all (CF-291, the seed).
# Each unmeasurable leg therefore NAMES itself here, and the final line repeats the reasons, so
# the operator is not told "transport" for a cause that has nothing to do with transport.
UNVERIFIED=0
UNVERIFIED_WHY=""
unverified() {  # unverified <why this leg could not be measured>
  UNVERIFIED=$((UNVERIFIED+1))
  UNVERIFIED_WHY="${UNVERIFIED_WHY:+$UNVERIFIED_WHY; }$1"
}
say "verify node $AGENT"

# 1. alive
out=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'echo ALIVE $(hostname)' 2>&1)
case "$out" in
  ALIVE*) ok "agent_alive" "$(printf '%s' "$out" | head -1)" ;;
  *) bad "agent_alive" "$(printf '%s' "$out" | head -1)"; say ""; say "RESULT: FAIL"; exit 1 ;;
esac

# 2. gateway reachable from the control host, through a NAMED transport (CF-224)
#
# The failure this closes: the verifier read `hostname -I` off the node and then probed that address
# from here. On a LAN node that is a real measurement. On a bunker it is not — the agent runs in its
# own network namespace, so the address it reports is one this host cannot route to, and the only
# other probe available was `curl 127.0.0.1` run INSIDE the node, which answers whatever the node's
# own loopback answers and proves nothing about reachability. So:
#   * the probe always runs HERE, in this shell's own process tree, never through `bunker exec`;
#   * a loopback answer measured inside the node is a FAIL, not a PASS (`--transport bunker-exec`);
#   * every row names the transport that carried it, and an unavailable transport is named
#     ("no published port for cf-node:10800") instead of printing a bare 000.
# Transports (contract: specs/NODE.md "Transport"):
#   node-address    the node's own address, `hostname -I` — the LAN case, unchanged default
#   published-port  a port published on the bunker host, probed from HERE (--transport-address)
#   tunnel          an SSH forward opened on THIS host, probed from HERE (--transport-address)
#   bunker-exec     the probe runs INSIDE the node — diagnostic only, it cannot certify a node
# CF-270: the port and the path travel as POSITIONAL ARGUMENTS to the remote shell, so neither
# value can be re-parsed as shell syntax: the remote body is a FIXED single-quoted string that
# only reads its own "$1"/"$2". The old form expanded $PORT locally inside a double-quoted
# string, and a value carrying a quote closed the single quotes and ran on the node.
inside() { bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$1$2"' _ "$PORT" "$1" 2>/dev/null; }
# Which transport is in force, printed before the probe so a run cannot be read as a LAN check when
# it was not one.
T_WHY=""
case "$TRANSPORT" in
  node-address)
    ip=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc 'hostname -I' 2>/dev/null | awk '{print $1}')
    case "$ip" in
      '')
        T_WHY="no address for $AGENT (hostname -I could not be read)"
        bad "node_ip" "could not read hostname -I" ;;
      127.*|::1|localhost)
        # A node that reports only loopback has no address this host can use; probing it from here
        # would hit THIS host's own loopback and could certify the wrong process.
        T_WHY="no LAN address for $AGENT (hostname -I -> $ip: a request from this host would probe THIS host's loopback, not the node)"
        warn "node_ip" "$ip is a loopback address — the node reports no address this host can use (a bunker node has no LAN address by default)"
        warn "transport" "node-address $ip:$PORT — refused: a probe to a loopback address measures this host, not the node; pass --transport published-port or --transport tunnel" ;;
      *)
        T_HOST="$ip" T_PORT="$PORT"
        ok "node_ip" "$ip"
        ok "transport" "node-address $T_HOST:$T_PORT — the node's own address, probed from this host (the LAN case; a bunker node has no LAN address by default)" ;;
    esac
    ;;
  published-port)
    ok "transport" "published-port $T_HOST:$T_PORT — a port published on the bunker host, probed from this host (never inside the node)" ;;
  tunnel)
    ok "transport" "tunnel $T_HOST:$T_PORT — an SSH forward opened on this host; the probe leaves this host and re-enters the node" ;;
  bunker-exec)
    T_WHY="transport bunker-exec runs the probe INSIDE the node (127.0.0.1:$PORT): it proves the harness answers its own loopback, not that anything outside the node can reach it"
    ;;
esac

if [ "$TRANSPORT" = bunker-exec ]; then
  # Criterion: a loopback check inside the node is a FAIL, not a PASS. It is reported with the code
  # it measured so the operator sees the harness is up, and it still refuses to certify the node.
  in_status=$(inside /api/status)
  bad "transport" "$T_WHY"
  bad "gateway_reachable" "loopback inside the node -> ${in_status:-no answer} (transport: bunker-exec) — a request that did not leave the node proves nothing about reachability, so this is a FAIL, not a PASS"
  note "auth_gate and unauth_refused are not attempted: no request from this host reaches the node"
elif [ -n "$T_HOST" ]; then
  url="http://$T_HOST:$T_PORT/api/status"
  # curl writes 000 itself on failure; appending `|| echo 000` produced "000000", which matched no
  # case and fell through to a FAIL that named a code no HTTP server can return.
  status_body=$(mktemp)
  code=$(curl -s -o "$status_body" -w '%{http_code}' --max-time 8 "$url" 2>/dev/null); code=${code:-000}
  case "$code" in
    200)
      ok "gateway_reachable" "$url -> 200 (transport: $TRANSPORT)"
      grep -Eq '"auth_required"[[:space:]]*:[[:space:]]*true[[:space:]]*[,}]' "$status_body" 2>/dev/null \
        && ok "auth_gate" "auth_required:true (a public bind must not be open)" \
        || bad "auth_gate" "/api/status -> $code; auth_required:true not measured — check dashboard.basic_auth"
      ;;
    000)
      # Nothing answered at the declared endpoint. That is UNVERIFIED, not FAIL: the node may work
      # perfectly behind a transport this host has not been given — but the row must say WHICH
      # transport it could not use, and a bare 000 names nothing.
      case "$TRANSPORT" in
        published-port) T_WHY="no published port for $AGENT:$PORT (nothing answered at $T_HOST:$T_PORT)" ;;
        tunnel)         T_WHY="no tunnel endpoint for $AGENT:$PORT (nothing answered at $T_HOST:$T_PORT)" ;;
        *)              T_WHY="no route from this host to $T_HOST:$T_PORT (the node's own address is unreachable from here; a bunker node has no LAN address by default — pass --transport published-port or --transport tunnel)" ;;
      esac
      in_code=$(inside /api/status)
      case "$in_code" in
        200) warn "gateway_reachable" "$T_WHY — the gateway answers 200 INSIDE the node, so this is unverified, not failed (transport: $TRANSPORT)" ;;
        *)   warn "gateway_reachable" "$T_WHY — and the gateway does not answer inside the node either (${in_code:-no answer}) — the harness is not up" ;;
      esac
      unverified "gateway_reachable: $T_WHY" ;;
    *) bad "gateway_reachable" "$url -> $code (transport: $TRANSPORT; is the harness running on 0.0.0.0:$PORT?)" ;;
  esac
  rm -f "$status_body"
else
  # No endpoint was probed: the transport row above already named the reason (loopback address, or
  # an address that could not be read). Still a measured absence, so it is not a pass.
  warn "gateway_reachable" "unverified — $T_WHY (transport: $TRANSPORT)"
  unverified "gateway_reachable: $T_WHY"
fi

# 3. unauthenticated access must be refused
if [ "$TRANSPORT" = bunker-exec ]; then
  :  # not measured from outside; the note in step 2 says so
elif [ -n "$T_HOST" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://$T_HOST:$T_PORT/api/system/stats" 2>/dev/null); code=${code:-000}
  case "$code" in
    401|302|403) ok "unauth_refused" "/api/system/stats -> $code" ;;
    200) bad "unauth_refused" "/api/system/stats -> 200 — the node is OPEN (transport: $TRANSPORT)" ;;
    000)
      case "$TRANSPORT" in
        published-port) T_WHY="no published port for $AGENT:$PORT (nothing answered at $T_HOST:$T_PORT)" ;;
        tunnel)         T_WHY="no tunnel endpoint for $AGENT:$PORT (nothing answered at $T_HOST:$T_PORT)" ;;
        *)              T_WHY="no route from this host to $T_HOST:$T_PORT (a bunker node has no LAN address by default)" ;;
      esac
      in_code=$(inside /api/system/stats)
      case "$in_code" in
        401|302|403) warn "unauth_refused" "unverified — $T_WHY; inside the node it answers $in_code" ;;
        200)         bad "unauth_refused" "/api/system/stats -> 200 INSIDE the node — the gateway is open" ;;
        *)           warn "unauth_refused" "unverified — $T_WHY; and ${in_code:-no answer} inside the node" ;;
      esac
      unverified "unauth_refused: $T_WHY" ;;
    *) bad "unauth_refused" "/api/system/stats -> $code — auth refusal not verified" ;;
  esac
else
  warn "unauth_refused" "unverified — $T_WHY (transport: $TRANSPORT)"
  unverified "unauth_refused: $T_WHY"
fi

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

# 6. the seeded prompts and skills are the digests the seed recorded (CF-250)
# Steps 1-5 never open the seed record: a node whose agent answers, whose
# gateway is up and whose gate is closed can still carry `prompts/foreman.md`
# with a foreman's hand-edited procedure in it, because provisioning deletes
# the node-side copy of the seeder after it applies. scripts/node_seed_drift.py
# runs that seeder's own check — staged to the node in ONE bunker exec and
# removed in the same one — and its verdict is folded in here, so a drifted
# seed drives VERIFY: FAIL on its own.
#
# Default mapping: PASS -> PASS, drift -> FAIL. An unmeasurable seed (or a node with no seed
# record yet) is a WARN row, because "cannot measure" is not proof of a broken copy, the same
# doctrine as the freshness leg above — but a WARN is NOT a pass: it sets UNVERIFIED, so the gate
# answers VERIFY: UNVERIFIED and exits 3 rather than printing PASS for a seed nobody read
# (CF-291: an empty or unparseable record used to end in `VERIFY: PASS`, exit 0). With
# --strict-seed the same case is a FAIL instead, so a gate can refuse on "unknown" outright.
# CF-379: a record that PARSES but declares no files is neither of those. The checker refuses it
# itself with a FAIL row naming the empty collection and exit 1 — the case below already folds
# exit 1 into `bad`, so the gate answers VERIFY: FAIL with no new verb and no new branch here. A
# record that declares nothing cannot be a peer of one that declares a digest set: `0 files present
# and matching` used to reach VERIFY: PASS for a node whose seed applied nothing.
SEEDCHK="$HERE/node_seed_drift.py"
if [ ! -r "$SEEDCHK" ]; then
  bad "seed_drift" "$SEEDCHK missing — the node's seed is unmeasured"
else
  seed_rows=$(mktemp); seed_json=$(mktemp)
  strict_seed_argv=""
  [ "${STRICT_SEED:-0}" -eq 1 ] && strict_seed_argv="--strict-seed"
  # The strict sentence belongs to the CHECKER, not to this script (QA-CODE-FACTORY-2). On exit 1 the
  # row below quotes node_seed_drift.py verbatim, so that path is safe by construction; the exit-3
  # branch is not — a record the checker cannot read (0 bytes, unparseable) is EXIT_UNMEASURABLE
  # whatever --strict-seed says, so this verifier has to write that FAIL row itself, and the wording
  # re-typed here had drifted to `unknown is not a pass` (one word short). The selftest arm that greps
  # the canonical phrase therefore went red whenever the seed leg could not be measured on an
  # otherwise identical tree — measured 2026-11-06: PASS, PASS, FAIL, PASS across four guard runs of
  # one hour. Ask the owning file for its sentence instead of keeping a second copy.
  strict_seed_note=""
  if [ "${STRICT_SEED:-0}" -eq 1 ]; then
    strict_seed_note=$(python3 -B "$SEEDCHK" --strict-note 2>/dev/null)
    # No fallback copy of the wording on purpose: if the owner cannot speak, the row says that rather
    # than printing a sentence that no file owns — a fallback IS the drift this removes.
    [ -z "$strict_seed_note" ] &&
      strict_seed_note="(the checker did not answer --strict-note — its strict wording is unavailable)"
  fi
  python3 -B "$SEEDCHK" --agent "$AGENT" --server "$SERVER" $strict_seed_argv --json >"$seed_json" 2>"$seed_rows"
  src=$?
  case "$src" in
    0)
      ok "seed_drift" "$(grep -F '  PASS  seed_drift — ' "$seed_rows" | sed -e 's/^  PASS  seed_drift — //' | head -1)"
      ;;
    1)
      bad "seed_drift" "$(grep -E '^  FAIL  seed_drift — ' "$seed_rows" | sed -e 's/^ *FAIL  seed_drift — //' | paste -sd '|' - | sed -e 's/|/ | /g' | cut -c1-500)"
      ;;
    *)
      detail=$(grep -E '^  WARN  seed_drift — ' "$seed_rows" | sed -e 's/^  WARN  seed_drift — //' | head -1)
      [ -z "$detail" ] && detail=$(grep -E '^RESULT: ' "$seed_rows" | head -1 | sed -e 's/^RESULT: //')
      if [ "${STRICT_SEED:-0}" -eq 1 ]; then
        bad "seed_drift" "${detail:-unmeasurable}${strict_seed_note:+ $strict_seed_note}"
      else
        warn "seed_drift" "${detail:-unmeasurable} — the seed could not be measured; pass --strict-seed to refuse it"
        # A WARN row is not a pass and not a FAIL: the seed was never read, so VERIFY: PASS here
        # would certify a copy nobody looked at (CF-291). Refuse to call it verified instead, and
        # name it, so the final line does not blame the transport for a seed problem.
        unverified "seed_drift: ${detail:-unmeasurable}"
      fi
      ;;
  esac
  rm -f "$seed_rows" "$seed_json"
fi

# 7. the harness the manifest records is the one on the node (CF-006)
# Steps 1-6 prove the agent answers, the gateway is up, the gate is closed and the tree and seed
# are the ones recorded — none of them reads the manifest's harness block. A node provisioned with
# `codex` whose manifest names codex 0.166.0 passed every earlier step with a different harness on
# it (or with the binary gone), because the harness was only ever a name in a JSON file. The values
# come from layer 20 of project-node.sh, which quotes the adapter's own `PASS version` row; this leg
# re-measures the node and compares. A manifest that recorded NO version is a WARN + UNVERIFIED
# rather than a silent pass (an unknown build is not a measured one). Two round trips: the binary's
# path is only known after the manifest is parsed here.
HM=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc '
  if [ -r "$HOME/.node/node.json" ]; then
    printf "PRESENT\n"
    cat "$HOME/.node/node.json"
  else
    printf "ABSENT\n"
  fi' 2>/dev/null)
case "${HM%%$'\n'*}" in
  PRESENT)
    hm_file=$(mktemp)
    printf '%s\n' "${HM#*$'\n'}" > "$hm_file"
    # Fields are joined with \x1f, not a tab: IFS treats tab (and space/newline) as WHITESPACE and
    # collapses runs of it, so a manifest with an empty version shifted every later field by one and
    # this row compared the binary PATH as if it were the version.
    hm_parsed=$(python3 -B - "$hm_file" <<'PY'
import json, sys
SEP = "\x1f"


def clean(value):
    return str(value or "").replace(SEP, " ").replace("\t", " ").replace("\n", " ")


try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        doc = json.load(handle)
except (OSError, ValueError) as exc:
    print(SEP.join(["UNREADABLE", "", "", clean(exc), ""]))
    raise SystemExit(0)
if not isinstance(doc, dict):
    print(SEP.join(["UNREADABLE", "", "", "not a JSON object", ""]))
    raise SystemExit(0)
harness = doc.get("harness") or {}
if not isinstance(harness, dict):
    print(SEP.join(["UNREADABLE", "", "", "harness is not an object", ""]))
    raise SystemExit(0)
version = harness.get("version")
print(SEP.join(["OK", clean(harness.get("name")), clean(version if isinstance(version, str) else ""),
                clean(harness.get("version_reason")), clean(harness.get("binary"))]))
PY
)
    rm -f "$hm_file"
    hm_status="" hm_name="" hm_version="" hm_reason="" hm_bin=""
    IFS=$'\x1f' read -r hm_status hm_name hm_version hm_reason hm_bin <<EOF
$hm_parsed
EOF
    case "$hm_status" in
      UNREADABLE)
        bad "harness_identity" "~/.node/node.json cannot be read as a manifest (${hm_reason:-no reason given}) — this node's identity record is broken; re-run --apply"
        ;;
      OK)
        if [ -z "$hm_name" ]; then
          bad "harness_identity" "~/.node/node.json names no harness (harness.name absent or empty) — nothing says what runs this node"
        elif [ -z "$hm_version" ]; then
          warn "harness_identity" "manifest names harness $hm_name with no measured version (${hm_reason:-no reason recorded}) — the build on this node is unmeasured"
          unverified "harness_identity: the manifest records harness $hm_name but no measured version"
        else
          hm_target="${hm_bin:-$hm_name}"
          # The recorded path travels as a POSITIONAL argument to a FIXED remote body, so a value
          # read from the node's own manifest cannot be re-parsed as shell syntax.
          hm_out=$(bunker exec --server "$SERVER" "$AGENT" -- bash -lc '
            p="${1:-}"
            [ -n "$p" ] || exit 4
            case "$p" in
              */*) : ;;
              *) p=$(command -v "$p" 2>/dev/null) || exit 3 ;;
            esac
            [ -x "$p" ] || exit 3
            printf "%s\t" "$p"
            "$p" --version 2>/dev/null | head -1' _ "$hm_target" 2>/dev/null)
          hm_rc=$?
          hm_path="${hm_out%%$'\t'*}"
          hm_measured="${hm_out#*$'\t'}"
          hm_measured="$(printf '%s' "$hm_measured" | head -1)"
          if [ "$hm_rc" -eq 3 ] || [ -z "$hm_measured" ]; then
            bad "harness_identity" "manifest names harness $hm_name $hm_version at ${hm_target:-no path}, but nothing executable there answers --version — the harness the node claims is not on the node"
          else
            case "$hm_measured" in
              *"$hm_version"*)
                ok "harness_identity" "$hm_name $hm_version (manifest) measured at $hm_path — $hm_measured" ;;
              *)
                bad "harness_identity" "manifest says $hm_name $hm_version, but $hm_path measures '$hm_measured' — the node is not running the harness it recorded (re-run --apply, or fix the manifest)" ;;
            esac
          fi
        fi
        ;;
      *)
        bad "harness_identity" "~/.node/node.json could not be parsed locally (parser returned nothing) — the harness the node claims is unmeasured"
        ;;
    esac
    ;;
  ABSENT|*)
    # Nothing is provisioned yet: legs 5 and 6 already carry that story, and a note here says
    # exactly what was NOT checked instead of letting a missing manifest look like a passing leg.
    note "harness_identity — no ~/.node/node.json on the node, so the manifest's harness name and version are not checked"
    ;;
esac

say ""
if [ "$FAILED" -gt 0 ]; then say "VERIFY: FAIL ($FAILED)"; exit 1; fi
if [ "${UNVERIFIED:-0}" -gt 0 ]; then
  # Name the legs that produced it: the transport sentence alone was a lie once the seed leg could
  # also be the cause (CF-291). A seed WARN now reads `... seed_drift: <what could not be read>`.
  say "VERIFY: UNVERIFIED — ${UNVERIFIED_WHY:-some legs could not be measured}"
  say "        (distinct from FAIL on purpose: nothing is broken and nothing is proven — CF-224)"
  exit 3
fi
say "VERIFY: PASS"; exit 0

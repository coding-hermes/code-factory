#!/usr/bin/env bash
# node-create.sh — control host: create a node from a project + repo + harness triple.
#
#   ./node-create.sh --project crier --repo git@… --harness hermes [--agent <id>] [--ttl 6h]
#
# Spawns the agent if needed, stages the scripts into it, runs project-node.sh --apply inside,
# then runs verify-node.sh. Idempotent: an existing agent is reused, not respawned.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PROJECT="" REPO="" HARNESS="hermes" AGENT="" TTL="6h" SERVER="${BUNKER_SERVER:?set BUNKER_SERVER to your bunker server name}" PORT=10800

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$PROJECT" ] && { echo "usage: $0 --project P --repo URL [--harness H] [--agent ID]"; exit 2; }

b=$(have bunker) || { echo "bunker client missing" >&2; exit 1; }

say "node-create — project=$PROJECT harness=$HARNESS server=$SERVER"

# 1. an agent to live in
if [ -z "$AGENT" ]; then
  AGENT="node-$PROJECT-$(date +%H%M%S)"
  say "  ..    spawning $AGENT (ttl $TTL)"
  "$b" spawn "$AGENT" --server "$SERVER" --ttl "$TTL" >/tmp/spawn.log 2>&1 || { bad "spawn" "$(tail -1 /tmp/spawn.log)"; exit 1; }
  ok "spawn" "$AGENT"
else
  ok "spawn" "reusing $AGENT"
fi

# 2. stage the provisioner INTO the node (scripts run there, they do not reach back)
say "  ..    staging scripts"
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'mkdir -p ~/node-scripts/harness' >/dev/null 2>&1
"$b" cp "$HERE/project-node.sh" "$AGENT:node-scripts/project-node.sh" --server "$SERVER" >/dev/null 2>&1
"$b" cp "$HERE/lib.sh" "$AGENT:node-scripts/lib.sh" --server "$SERVER" >/dev/null 2>&1
"$b" cp "$HERE/harness/install-$HARNESS.sh" "$AGENT:node-scripts/harness/install-$HARNESS.sh" --server "$SERVER" >/dev/null 2>&1
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-scripts/project-node.sh ~/node-scripts/harness/*.sh' >/dev/null 2>&1
ok "staged" "project-node.sh + harness/install-$HARNESS.sh"

# 3. provision inside
say "  ..    provisioning inside the node"
if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
     "NODE_PROJECT='$PROJECT' NODE_GATEWAY_PORT='$PORT' ~/node-scripts/project-node.sh --apply --project '$PROJECT' --harness '$HARNESS' --repo '$REPO'"; then
  ok "provision" "node reports PASS"
else
  bad "provision" "node reported FAIL — see the output above"
fi

# 4. verify from here
say "  ..    verifying from the control host"
"$HERE/verify-node.sh" --agent "$AGENT" --server "$SERVER" --port "$PORT" || bad "verify" "round trip failed"

say ""
[ "$FAILED" -eq 0 ] && { say "NODE CREATED: $AGENT"; say "manifest: /home/<uid>/.node/node.json"; exit 0; }
say "NODE INCOMPLETE ($FAILED)"; exit 1

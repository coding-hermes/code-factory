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
FLOOR="${NODE_DISK_FLOOR-5}"
RECLAIM=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project|--repo|--harness|--agent|--ttl|--port|--disk-floor)
      [ $# -ge 2 ] || { echo "missing value: $1" >&2; exit 2; } ;;
  esac
  case "$1" in
    --disk-floor) FLOOR="$2"; shift 2 ;;
    --reclaim-disposable) RECLAIM=1; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$PROJECT" ] && { echo "usage: $0 --project P --repo URL [--harness H] [--agent ID] [--disk-floor GiB] [--reclaim-disposable]"; exit 2; }
# Match disk-policy.py's bounded decimal grammar before any remote operation.
if ! [[ "$FLOOR" =~ ^[0-9]{1,9}(\.[0-9]{1,9})?$ ]]; then
  bad "disk" "invalid floor; expected unsigned decimal GiB (1-9 digits per part)"; exit 2
fi

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
if ! "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'mkdir -p ~/node-scripts/harness' >/dev/null 2>&1; then
  bad "stage_dir" "could not create ~/node-scripts/harness"; exit 1
fi
for source in project-node.sh lib.sh node-contract.py disk-policy.py "harness/install-$HARNESS.sh"; do
  if ! "$b" cp "$HERE/$source" "$AGENT:node-scripts/$source" --server "$SERVER" >/dev/null 2>&1; then
    if [ "$source" = disk-policy.py ]; then
      bad "stage_disk_policy" "copy failed"
    else
      bad "stage_script" "copy failed: $source"
    fi
    exit 1
  fi
done
if ! "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-scripts/project-node.sh ~/node-scripts/harness/*.sh' >/dev/null 2>&1; then
  bad "stage_mode" "could not mark staged scripts executable"; exit 1
fi
ok "staged" "project-node.sh + harness/install-$HARNESS.sh"

# 3. provision inside
say "  ..    provisioning inside the node"
printf -v q_project '%q' "$PROJECT"
printf -v q_harness '%q' "$HARNESS"
printf -v q_repo '%q' "$REPO"
printf -v q_port '%q' "$PORT"
printf -v q_floor '%q' "$FLOOR"
provision_cmd="NODE_PROJECT=$q_project NODE_GATEWAY_PORT=$q_port NODE_DISK_FLOOR=$q_floor ~/node-scripts/project-node.sh --apply --project $q_project --harness $q_harness --repo $q_repo"
[ "$RECLAIM" -eq 0 ] || provision_cmd+=" --reclaim-disposable"
if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc "$provision_cmd"; then
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

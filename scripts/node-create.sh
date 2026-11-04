#!/usr/bin/env bash
# node-create.sh — control host: create a node from a project + repo + harness triple.
#
#   ./node-create.sh --project crier --repo git@… --harness hermes [--ref <branch-or-tag>] \
#                    [--agent <id>] [--ttl 6h]
#
# Spawns the agent if needed, stages the scripts into it, runs project-node.sh --apply inside,
# then runs verify-node.sh. Idempotent: an existing agent is reused, not respawned.
# --ref is the branch or tag the node clones; it defaults to main (or $NODE_REF) and is the
# remedy project-node.sh names when a repo's default branch is not main.
# On failure, retain a newly spawned agent for diagnosis and print its exact, explicit-server
# destroy command. Never suggest destroying an agent supplied with --agent.
# --staged-files validates runtime references and prints the staging manifest without bunker.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PROJECT="" REPO="" REF="${NODE_REF:-main}" HARNESS="hermes" AGENT="" TTL="6h" SERVER="${BUNKER_SERVER:-}" PORT=10800
LIST_STAGED=0 SPAWNED=0

staged_files() {
  local file source line ref base rest
  local -a staged=(project-node.sh lib.sh disk_floor.py reclaim_disk.py "harness/install-$HARNESS.sh")
  local pattern='\$HERE/([a-zA-Z0-9_./$-]+)'
  for file in "${staged[@]}"; do
    [ -f "$HERE/$file" ] || { bad "staged_set" "missing scripts/$file" >&2; return 1; }
  done
  # Validate every HERE-relative reference in the entry point and selected adapter.
  # Resolve the adapter's ../lib.sh and the entry point's selected $HARNESS literally.
  for source in project-node.sh "harness/install-$HARNESS.sh"; do
    base="${source%/*}"
    [ "$base" = "$source" ] && base=.
    while IFS= read -r line; do
      rest="$line"
      while [[ "$rest" =~ $pattern ]]; do
        ref="${BASH_REMATCH[1]}"
        rest="${rest#*"${BASH_REMATCH[0]}"}"
        ref="${ref//\$HARNESS/$HARNESS}"
        [ "$base" = harness ] && ref="harness/$ref"
        ref="${ref#harness/../}"
        case " ${staged[*]} " in
          *" $ref "*) ;;
          *) bad "staged_set" "$source references unstaged $ref" >&2; return 1 ;;
        esac
      done
    done < "$HERE/$source"
  done
  printf '%s\n' "${staged[@]}"
}

incomplete() {
  say "NODE INCOMPLETE ($FAILED)"
  if [ "$SPAWNED" -eq 1 ]; then
    printf 'cleanup required: bunker destroy %q --server %q\n' "$AGENT" "$SERVER"
  fi
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --staged-files) LIST_STAGED=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [ "$LIST_STAGED" -eq 1 ]; then staged_files; exit $?; fi
if [ -z "${CRIER_URL:-}" ]; then
  bad "crier_url" "CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767"
  exit 1
fi
# Every data value crossing into the node's shell uses the shared escaper.
PROJECT_QUOTED=$(shq "$PROJECT")
PORT_QUOTED=$(shq "$PORT")
CRIER_QUOTED=$(shq "$CRIER_URL")
HARNESS_QUOTED=$(shq "$HARNESS")
REPO_QUOTED=$(shq "$REPO")
REF_QUOTED=$(shq "$REF")
STAGED="$(staged_files)" || exit 1
if [ -z "$SERVER" ]; then
  bad "server_declared" "BUNKER_SERVER unset — no agent host to create the node on"
  incomplete
fi
[ -z "$PROJECT" ] && { echo "usage: $0 --project P --repo URL [--ref R] [--harness H] [--agent ID]"; exit 2; }

b=$(have bunker) || { echo "bunker client missing" >&2; exit 1; }

say "node-create — project=$PROJECT harness=$HARNESS server=$SERVER"

# 1. an agent to live in
if [ -z "$AGENT" ]; then
  AGENT="node-$PROJECT-$(date +%H%M%S)"
  say "  ..    spawning $AGENT (ttl $TTL)"
  "$b" spawn "$AGENT" --server "$SERVER" --ttl "$TTL" >/tmp/spawn.log 2>&1 || { bad "spawn" "$(tail -1 /tmp/spawn.log)"; exit 1; }
  SPAWNED=1
  ok "spawn" "$AGENT"
else
  ok "spawn" "reusing $AGENT"
fi

# 2. stage the provisioner INTO the node (scripts run there, they do not reach back)
say "  ..    staging scripts"
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'mkdir -p ~/node-scripts/harness' \
  || { bad "staged" "cannot create node-scripts directory"; incomplete; }
while IFS= read -r file; do
  "$b" cp "$HERE/$file" "$AGENT:node-scripts/$file" --server "$SERVER" \
    || { bad "staged" "copy failed: $file"; incomplete; }
done <<< "$STAGED"
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-scripts/project-node.sh ~/node-scripts/harness/*.sh' \
  || { bad "staged" "cannot set script permissions"; incomplete; }
ok "staged" "${STAGED//$'\n'/ + }"

# 3. provision inside
say "  ..    provisioning inside the node"
if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
     "NODE_PROJECT=$PROJECT_QUOTED NODE_GATEWAY_PORT=$PORT_QUOTED CRIER_URL=$CRIER_QUOTED ~/node-scripts/project-node.sh --apply --project $PROJECT_QUOTED --harness $HARNESS_QUOTED --repo $REPO_QUOTED --ref $REF_QUOTED"; then
  ok "provision" "node reports PASS"
else
  bad "provision" "node reported FAIL — see the output above"
fi

# 4. verify from here
say "  ..    verifying from the control host"
"$HERE/verify-node.sh" --agent "$AGENT" --server "$SERVER" --port "$PORT" \
  || { bad "verify" "round trip failed — node remains unverified"; incomplete; }

say ""
[ "$FAILED" -eq 0 ] && { say "NODE CREATED: $AGENT"; say "manifest: /home/<uid>/.node/node.json"; exit 0; }
incomplete

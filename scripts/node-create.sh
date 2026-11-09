#!/usr/bin/env bash
# node-create.sh — control host: create a node from a project + repo + harness triple.
#
#   ./node-create.sh --project crier --repo git@… --harness hermes [--ref <branch-or-tag>] \
#                    [--agent <id>] [--ttl 6h]
#
# Spawns the agent if needed, stages the scripts into it, runs project-node.sh --apply inside,
# then runs verify-node.sh. Idempotent: an existing agent is reused, not respawned.
# --agent reuses an agent that must ALREADY exist on the server: it is proved with `bunker info`
# before any success row and before staging, never spawned, and a missing id is a named
# `FAIL agent` that names the remedy and exits 1 without touching the agent (CF-051).
# --ref is the branch or tag the node clones; it defaults to main (or $NODE_REF) and is the
# remedy project-node.sh names when a repo's default branch is not main.
# --deploy-key <file> injects a read-only per-repo SSH deploy key: the credential is validated
# here BEFORE any agent is spawned — readable, mode 600, loads as an unencrypted private key
# (ssh-keygen), and the remote is an SSH URL. A `.pub`, a junk file, an encrypted key or an
# HTTPS/local remote is a named refusal, not a clone that fails after the agent exists. The key
# is then copied to the node, installed through
# scripts/deploy_key.py as $HOME/.node/keys/<project>.key (mode 600) with a generated
# $HOME/.node/keys/ssh_config, and handed to project-node.sh as NODE_DEPLOY_KEY. The key's
# bytes are never an argv value and never printed. --gomodcache <node path> points the node
# at a sealed shared Go module cache instead of its own 656 MB copy.
# On failure, retain a newly spawned agent for diagnosis and print its exact, explicit-server
# destroy command. Never suggest destroying an agent supplied with --agent.
# --staged-files validates runtime references and prints the staging manifest without bunker.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PROJECT="" REPO="" REF="${NODE_REF:-main}" HARNESS="hermes" AGENT="" TTL="6h" SERVER="${BUNKER_SERVER:-}" PORT=10800
LIST_STAGED=0 SPAWNED=0 DEPLOY_KEY="" GOMODCACHE=""

staged_files() {
  local file source line ref base rest
  # node_gateway_auth.py is here because project-node.sh layer 20 runs it: the harness adapter
  # refuses a public bind without dashboard.basic_auth, and no other stage writes it (CF-150).
  # install-node.sh/node_hygiene.py/gomodcache.py are layer 10/00 dependencies of the runtime,
  # footprint and shared-cache rows; deploy_key.py is the injector --deploy-key runs here
  # (CF-003). A reference to an unstaged file is a FAIL below, not a node that half-works.
  local -a staged=(project-node.sh install-go.sh install-node.sh lib.sh disk_floor.py reclaim_disk.py
                   node_gateway_auth.py node_hygiene.py gomodcache.py deploy_key.py
                   harness/harness-vars.sh "harness/install-$HARNESS.sh")
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
    --deploy-key) DEPLOY_KEY="$2"; shift 2 ;;
    --gomodcache) GOMODCACHE="$2"; shift 2 ;;
    --staged-files) LIST_STAGED=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [ "$LIST_STAGED" -eq 1 ]; then staged_files; exit $?; fi
if [ -z "${CRIER_URL:-}" ]; then
  bad "crier_url" "CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767"
  exit 1
fi
# A credential is validated before an agent exists: a key that is unreadable, readable by
# group/other, or that ssh cannot load is a named refusal here, not a clone failure 40
# seconds later on the node.
if [ -n "$DEPLOY_KEY" ]; then
  if [ -z "$REPO" ]; then
    bad "deploy_key" "$DEPLOY_KEY given with no --repo — a deploy key belongs to one repository"
    exit 1
  fi
  if [ ! -r "$DEPLOY_KEY" ]; then
    bad "deploy_key" "$DEPLOY_KEY is unreadable — the node would clone without a credential"
    exit 1
  fi
  dk_mode=$(stat -c '%a' "$DEPLOY_KEY" 2>/dev/null || echo '?')
  case "$dk_mode" in
    600|400) ok "deploy_key" "$DEPLOY_KEY mode $dk_mode" ;;
    *) bad "deploy_key" "$DEPLOY_KEY mode $dk_mode — group/other can read it (chmod 600)"; exit 1 ;;
  esac
  # A readable 0600 file is not yet a credential (CF-003). deploy_key.py refuses a public key, a
  # non-key file and a passphrase-protected key INSIDE the node — that is after the agent exists
  # and the bytes have been copied. Ask the client that will present the key instead: ssh-keygen
  # loads it, so a mode-600 `.pub`, a junk file and an encrypted key are each a named refusal on
  # the control host, before the spawn. The public half it derives is discarded, never printed.
  skg=$(have ssh-keygen) || {
    bad "deploy_key" "ssh-keygen absent — cannot prove $DEPLOY_KEY is a private key (install openssh-client)"
    exit 1
  }
  if ! "$skg" -y -P '' -f "$DEPLOY_KEY" </dev/null >/dev/null 2>&1; then
    bad "deploy_key:loadable" "$DEPLOY_KEY does not load as an unencrypted private key (ssh-keygen -y refuses it) — a public key, an encrypted key or a non-key file cannot authenticate the clone"
    exit 1
  fi
  ok "deploy_key:loadable" "$DEPLOY_KEY loads as an unencrypted private key"
  # The remote form is the other half of the same credential: a deploy key authenticates SSH and
  # nothing else, so the classes that provably cannot work are refused here rather than by
  # deploy_key.py install after the spawn. The exact SSH form stays the install step's job, so a
  # form this gate does not recognise gets no row rather than a PASS it did not measure.
  case "$REPO" in
    https://*|http://*|file://*)
      bad "deploy_key:repo" "$REPO is not an SSH remote — a deploy key authenticates SSH only; use git@<host>:<group>/<repo>.git (or drop --deploy-key)"
      exit 1 ;;
    /*|~*|./*|../*)
      bad "deploy_key:repo" "$REPO is a local path — no key is needed or injected (drop --deploy-key)"
      exit 1 ;;
    ssh://*|*@*:*) ok "deploy_key:repo" "$REPO is an SSH remote" ;;
  esac
fi
if [ -n "$GOMODCACHE" ]; then
  case "$GOMODCACHE" in
    /*) ok "gomodcache" "$GOMODCACHE (node path)" ;;
    *) bad "gomodcache" "$GOMODCACHE is relative — name the path as it exists ON the node"; exit 1 ;;
  esac
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
[ -z "$PROJECT" ] && { echo "usage: $0 --project P --repo URL [--ref R] [--harness H] [--agent ID] [--deploy-key FILE] [--gomodcache PATH]"; echo "       --agent ID reuses an agent that must already exist on the server; it is never spawned"; echo "       --deploy-key FILE injects a read-only per-repo key (mode 600, never in argv)"; echo "       --gomodcache PATH points the node at a sealed shared Go module cache"; exit 2; }

b=$(have bunker) || { bad "bunker_cli" "no bunker client on PATH — install the bunker client; without it no agent can be spawned, staged or verified (nothing was attempted)"; incomplete; }

say "node-create — project=$PROJECT harness=$HARNESS server=$SERVER"

# 1. an agent to live in — spawned when unnamed, reused (and proved to exist) when --agent is given
if [ -z "$AGENT" ]; then
  AGENT="node-$PROJECT-$(date +%H%M%S)"
  say "  ..    spawning $AGENT (ttl $TTL)"
  "$b" spawn "$AGENT" --server "$SERVER" --ttl "$TTL" >/tmp/spawn.log 2>&1 || { bad "spawn" "$(tail -1 /tmp/spawn.log)"; exit 1; }
  SPAWNED=1
  ok "spawn" "$AGENT"
else
  # A supplied agent is reused and never spawned, so it has to exist. Prove that before the
  # success row and before any staging call: otherwise a typo is reported as a reuse, work
  # proceeds into a nonexistent agent, and the operator learns the truth from an unrelated
  # downstream failure (CF-051).
  if ! "$b" info "$AGENT" --server "$SERVER" >/dev/null 2>&1; then
    bad "agent" "$AGENT not found on $SERVER — spawn it (drop --agent) or pass an existing agent id"
    exit 1
  fi
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
"$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'chmod +x ~/node-scripts/project-node.sh ~/node-scripts/install-go.sh ~/node-scripts/install-node.sh ~/node-scripts/harness/*.sh' \
  || { bad "staged" "cannot set script permissions"; incomplete; }
ok "staged" "${STAGED//$'\n'/ + }"

# 2b. the per-repo credential, when one was named (CF-003). It is copied as a file (never an
# argv value), installed by deploy_key.py so the key is 0600 and the generated ssh_config
# offers it under `IdentitiesOnly yes`, and the incoming copy is removed in the same round
# trip — an unused bundle left on the node is a credential with no purpose (AGENTS.md rule 8).
if [ -n "$DEPLOY_KEY" ]; then
  say "  ..    injecting the deploy key for $PROJECT"
  "$b" cp "$DEPLOY_KEY" "$AGENT:node-scripts/deploy.key" --server "$SERVER" \
    || { bad "deploy_key" "copy into the node failed"; incomplete; }
  if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
       "python3 ~/node-scripts/deploy_key.py install --home \$HOME --repo $REPO_QUOTED --key ~/node-scripts/deploy.key --name $PROJECT_QUOTED; rc=\$?; rm -f ~/node-scripts/deploy.key; exit \$rc"; then
    ok "deploy_key" "installed at ~/.node/keys/$PROJECT.key (mode 600) + ssh_config"
    DEPLOY_ENV="NODE_DEPLOY_KEY=\"\$HOME/.node/keys/$PROJECT.key\" NODE_SSH_CONFIG=\"\$HOME/.node/keys/ssh_config\" "
  else
    bad "deploy_key" "deploy_key.py install failed inside the node — the clone will be refused"
    DEPLOY_ENV=""
  fi
else
  DEPLOY_ENV=""
fi
if [ -n "$GOMODCACHE" ]; then
  DEPLOY_ENV="${DEPLOY_ENV}NODE_GOMODCACHE=$(shq "$GOMODCACHE") "
  ok "gomodcache" "node will use the shared cache at $GOMODCACHE"
fi

# 3. provision inside
say "  ..    provisioning inside the node"
if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
     "${DEPLOY_ENV}NODE_PROJECT=$PROJECT_QUOTED NODE_GATEWAY_PORT=$PORT_QUOTED CRIER_URL=$CRIER_QUOTED ~/node-scripts/project-node.sh --apply --project $PROJECT_QUOTED --harness $HARNESS_QUOTED --repo $REPO_QUOTED --ref $REF_QUOTED"; then
  ok "provision" "node reports PASS"
else
  bad "provision" "node reported FAIL — see the output above"
fi

# 4. verify from here
say "  ..    verifying from the control host"
verify_rc=0
"$HERE/verify-node.sh" --agent "$AGENT" --server "$SERVER" --port "$PORT" || verify_rc=$?
case "$verify_rc" in
  0) ok "verify" "round trip proven from the control host" ;;
  3) warn "verify" "UNVERIFIED — a leg could not be measured from this host (no transport, or an unreadable seed; see the VERIFY line for which) — the node is not marked failed (CF-224/CF-291)" ;;
  *) bad "verify" "round trip failed — node remains unverified"; incomplete ;;
esac

say ""
[ "$FAILED" -eq 0 ] && { say "NODE CREATED: $AGENT"; say "manifest: /home/<uid>/.node/node.json"; exit 0; }
incomplete

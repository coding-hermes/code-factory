#!/usr/bin/env bash
# bunker-provision.sh — control host: provision ONE project's bunker from a config file,
# with CLI overrides, and destroy it again. The config names the target; the CLI wins.
#
#   bunker-provision.sh --config cf-bunker.conf --check
#   bunker-provision.sh --config cf-bunker.conf --apply   [--agent A] [--server S] ...
#   bunker-provision.sh --config cf-bunker.conf --destroy --yes
#
# The config file is DATA, never executed: every non-comment line must be KEY=VALUE with
# KEY matching [A-Z_][A-Z0-9_]*. Anything else is a FAIL, so a stray shell line cannot run.
#
# Secrets never travel in this file or on the command line: the config names token files,
# this script reads them into ONE bundle of mode 600, copies it in, installs it, and deletes
# both copies. No value is ever printed (CF-002).
#
# Keys (all optional except PROJECT and REPO):
#   PROJECT  AGENT  SERVER  REPO  REF  HARNESS  NAMESPACE  TTL
#   GITHUB_TOKEN_FILE  DUCKBRAIN_TOKEN_FILE  S3_ENV_FILE
#   CRIER_URL  DUCKBRAIN_URL
#
# Idempotent: an existing agent is reused, an existing clone is fast-forwarded, an existing
# node.json is rewritten only when a value differs. --check is read-only and names every
# measured value; it never writes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

CONFIG="" MODE="" AGENT="" PROJECT="" SERVER="" REPO="" REF="" HARNESS="" NAMESPACE="" TTL=""
GITHUB_TOKEN_FILE="" DUCKBRAIN_TOKEN_FILE="" S3_ENV_FILE="" CRIER_URL="" DUCKBRAIN_URL=""
YES=0
CLI_PROJECT="" CLI_AGENT="" CLI_SERVER="" CLI_REPO="" CLI_REF="" CLI_HARNESS="" CLI_NAMESPACE="" CLI_CRIER=""

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

# --- config: parse, never source ------------------------------------------------------------
load_config() {
  local file="$1" line key val n=0
  [ -r "$file" ] || { bad "config" "cannot read $file"; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n+1))
    case "$line" in ''|'#'*) continue ;; esac
    line="${line%$'\r'}"
    if ! [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
      bad "config" "$file:$n is not KEY=VALUE — refusing to run it"
      return 1
    fi
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    case "$key" in
      PROJECT|AGENT|SERVER|REPO|REF|HARNESS|NAMESPACE|TTL|CRIER_URL|DUCKBRAIN_URL)
        printf -v "$key" '%s' "$val" ;;
      GITHUB_TOKEN_FILE|DUCKBRAIN_TOKEN_FILE|S3_ENV_FILE)
        case "$val" in "~/"*) val="$HOME/${val#\~/}" ;; esac
        printf -v "$key" '%s' "$val" ;;
      *) bad "config" "$file:$n unknown key $key"; return 1 ;;
    esac
  done < "$file"
  ok "config" "$(basename "$file") — $n lines, KEY=VALUE only"
}

# --- check: read-only, every row names what it measured --------------------------------------
bunker_ok=0
check() {
  local b info sha branch dirty harness_bin code
  say "bunker-provision --check — project=${PROJECT:-<unset>} agent=${AGENT:-<unset>} server=${SERVER:-<unset>}"
  note "resolved repo=${REPO:-<unset>} ref=${REF:-main} harness=${HARNESS:-hermes} ns=${NAMESPACE:-$PROJECT} ttl=${TTL:-default(6h)}"

  b=$(have bunker)
  [ -n "$b" ] || { bad "bunker_cli" "no bunker client on PATH"; return 1; }
  bunker_ok=1
  ok "bunker_cli" "$b"

  [ -n "$SERVER" ] || { bad "server" "SERVER unset — no host to provision on"; return 1; }
  if timeout 45 "$b" list 2>/dev/null | grep -q -- "$SERVER"; then
    ok "server" "$SERVER reachable"
  else
    bad "server" "$SERVER not listed by 'bunker list'"
  fi

  [ -n "$AGENT" ] || { bad "agent" "AGENT unset"; return 1; }
  if info=$(timeout 45 "$b" info "$AGENT" --server "$SERVER" 2>&1); then
    ok "agent" "$AGENT exists ($(printf '%s' "$info" | head -1 | cut -c1-60))"
  else
    bad "agent" "$AGENT absent — run --apply to create it"
    return 1
  fi

  # repo, identity and harness, measured inside the node
  local probe
  probe=$(timeout 60 "$b" exec --server "$SERVER" "$AGENT" -- bash -lc '
    cd "$HOME/repo" 2>/dev/null || { echo "repo=absent"; exit 0; }
    echo "repo=present"
    echo "sha=$(git rev-parse --short HEAD 2>/dev/null)"
    echo "branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "dirty=$(git status --porcelain 2>/dev/null | grep -vc "^??" || true)"
    echo "node_json=$([ -f "$HOME/.node/node.json" ] && echo present || echo absent)"
    echo "github=$([ -s "$HOME/.node/auth/github.token" ] && echo present || echo absent)"
    echo "duckbrain=$([ -s "$HOME/.node/auth/duckbrain.token" ] && echo present || echo absent)"
    echo "crier_json=$([ -f "$HOME/.node/crier.json" ] && echo present || echo absent)"
    echo "gitcred=$([ -s "$HOME/.git-credentials" ] && echo present || echo absent)"
    echo "hermes=$(if [ -x "$HOME/hermes-venv/bin/hermes" ] || [ -x "$HOME/.local/bin/hermes" ] || command -v hermes >/dev/null 2>&1; then echo present; else echo absent; fi)"
    echo "gw_auth=$(grep -q "basic_auth:" "$HOME/.hermes/config.yaml" 2>/dev/null && echo present || echo absent)"
  ' 2>/dev/null) || true

  case "$probe" in *repo=present*) ok "repo" "clone present ($(printf '%s' "$probe" | sed -n 's/^sha=//p') branch $(printf '%s' "$probe" | sed -n 's/^branch=//p'), $(printf '%s' "$probe" | sed -n 's/^dirty=//p') dirty)" ;;
    *) bad "repo" "no clone at \$HOME/repo — run --apply" ;; esac
  case "$probe" in *node_json=present*) ok "node_json" "identity written" ;;
    *) bad "node_json" "\$HOME/.node/node.json absent" ;; esac
  case "$probe" in *github=present*) ok "auth_github" "token file installed, mode 600 (value not read)" ;;
    *) bad "auth_github" "no \$HOME/.node/auth/github.token" ;; esac
  case "$probe" in *duckbrain=present*) ok "auth_duckbrain" "token file installed (value not read)" ;;
    *) bad "auth_duckbrain" "no \$HOME/.node/auth/duckbrain.token" ;; esac
  case "$probe" in *gitcred=present*) ok "git_credential" "\$HOME/.git-credentials present, mode 600 store" ;;
    *) bad "git_credential" "no \$HOME/.git-credentials — the clone cannot authenticate" ;; esac
  case "$probe" in *gw_auth=present*) ok "gateway_auth" "dashboard.basic_auth present — a public bind is legal" ;;
    *) bad "gateway_auth" "no dashboard.basic_auth — the gateway will refuse to bind (CF-150)" ;; esac
  case "$probe" in *hermes=present*) ok "harness" "$HARNESS binary present" ;;
    *) bad "harness" "no $HARNESS binary on the node" ;; esac

  # crier: the inbox route is the only thing that proves reachability
  [ -n "$CRIER_URL" ] || { warn "crier" "CRIER_URL unset — reachability unproven"; return 0; }
  code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "$CRIER_URL/agents/$AGENT/inbox?limit=1" 2>/dev/null || echo 000)
  case "$code" in
    200) ok "crier" "$CRIER_URL/agents/$AGENT/inbox -> 200" ;;
    000) bad "crier" "$CRIER_URL unreachable (no answer in 8 s)" ;;
    *)   bad "crier" "$CRIER_URL/agents/$AGENT/inbox -> $code (identity not accepted)" ;;
  esac

  if [ -n "$DUCKBRAIN_URL" ] && [ -r "$DUCKBRAIN_TOKEN_FILE" ]; then
    code=$(curl -s -o /dev/null -m 8 -w '%{http_code}' -H "x-api-key: $(cat "$DUCKBRAIN_TOKEN_FILE")" \
      "$DUCKBRAIN_URL/api/memories/key/x?namespace=$NAMESPACE" 2>/dev/null || echo 000)
    case "$code" in
      200|404) ok "duckbrain" "$DUCKBRAIN_URL namespace=$NAMESPACE -> $code" ;;
      *) bad "duckbrain" "$DUCKBRAIN_URL namespace=$NAMESPACE -> $code" ;;
    esac
  else
    warn "duckbrain" "DUCKBRAIN_URL or token file unset — namespace unproven"
  fi

  say ""
  if [ "$FAILED" -eq 0 ]; then say "BUNKER: PASS — every row above measured"; else say "BUNKER: FAIL ($FAILED)"; fi
  [ "$FAILED" -eq 0 ]
}

# --- apply --------------------------------------------------------------------------------
bundle_paths() {  # bundle_paths <dest-on-node-relative>
  local dest="$1" out=""
  [ -n "$GITHUB_TOKEN_FILE" ] && [ -r "$GITHUB_TOKEN_FILE" ] && out+="github=$(head -c 4096 "$GITHUB_TOKEN_FILE" | tr -d '\r\n')"$'\n'
  [ -n "$DUCKBRAIN_TOKEN_FILE" ] && [ -r "$DUCKBRAIN_TOKEN_FILE" ] && out+="duckbrain=$(head -c 4096 "$DUCKBRAIN_TOKEN_FILE" | tr -d '\r\n')"$'\n' 
  if [ -n "$S3_ENV_FILE" ] && [ -r "$S3_ENV_FILE" ]; then
    out+="s3="$'\n'"$(sed -e 's/^/  /' "$S3_ENV_FILE")"$'\n'
  fi
  printf '%s' "$out"
}

apply() {
  local b tmp rc=0
  say "bunker-provision --apply — project=$PROJECT agent=$AGENT server=$SERVER"

  [ -n "$PROJECT" ] || { bad "project" "PROJECT unset in config"; return 1; }
  [ -n "$REPO" ] || { bad "repo" "REPO unset in config"; return 1; }
  [ -n "$SERVER" ] || { bad "server" "SERVER unset"; return 1; }
  # A node that cannot reach a bus is half a node: refuse before touching the host rather than
  # provisioning something that has to be re-provisioned the moment it is used.
  [ -n "$CRIER_URL" ] || { bad "crier_url" "CRIER_URL unset — a node must know its bus (set it in the config or --crier-url)"; return 1; }

  b=$(have bunker)
  [ -n "$b" ] || return 1

  # 1. an agent to hold the rest — spawn only when absent, so a re-run never creates a second
  if timeout 45 "$b" info "$AGENT" --server "$SERVER" >/dev/null 2>&1; then
    ok "agent" "$AGENT reused (no second agent)"
  else
    say "  ..    spawning $AGENT (ttl ${TTL:-6h})"
    if "$b" spawn "$AGENT" --server "$SERVER" --ttl "${TTL:-6h}" >/tmp/cf-spawn.log 2>&1; then
      ok "agent" "$AGENT spawned on $SERVER"
    else
      bad "agent" "spawn failed: $(tail -1 /tmp/cf-spawn.log 2>/dev/null)"; return 1
    fi
  fi

  # 2. credentials BEFORE the clone: the repo layer authenticates with what lands here
  tmp=$(mktemp); chmod 600 "$tmp"
  bundle_paths x > "$tmp"
  if [ -s "$tmp" ]; then
    say "  ..    installing auth bundle (before the clone)"
    if "$b" cp "$tmp" "$AGENT:cf-auth.bundle" --server "$SERVER" >/dev/null 2>&1 &&
       "$b" exec --server "$SERVER" "$AGENT" -- bash -lc '
         set -e
         mkdir -p "$HOME/.node/auth"; chmod 700 "$HOME/.node" "$HOME/.node/auth"
         umask 077
         g=$(sed -n "s/^github=//p" "$HOME/cf-auth.bundle" | head -1)
         d=$(sed -n "s/^duckbrain=//p" "$HOME/cf-auth.bundle" | head -1)
         [ -n "$g" ] && printf "%s\n" "$g" > "$HOME/.node/auth/github.token"
         [ -n "$d" ] && printf "%s\n" "$d" > "$HOME/.node/auth/duckbrain.token"
         sed -n "/^s3=$/,\$p" "$HOME/cf-auth.bundle" | tail -n +2 | sed "s/^  //" > "$HOME/.node/auth/s3.env" 2>/dev/null || true
         [ -s "$HOME/.node/auth/s3.env" ] || rm -f "$HOME/.node/auth/s3.env"
         chmod 600 "$HOME/.node/auth/"* 2>/dev/null || true
         if [ -s "$HOME/.node/auth/github.token" ]; then
           printf "https://x-access-token:%s@github.com\n" "$(cat "$HOME/.node/auth/github.token")" > "$HOME/.git-credentials"
           chmod 600 "$HOME/.git-credentials"
           git config --global credential.helper "store --file=$HOME/.git-credentials"
         fi
         for f in "$HOME/.node/auth/"*; do [ -e "$f" ] && printf "  %s mode %s\n" "$(basename "$f")" "$(stat -c %a "$f")"; done
       ' 2>&1 | sed 's/^/  ..    /'
    then ok "auth" "installed under \$HOME/.node/auth, mode 600"
    else bad "auth" "bundle install failed"; rc=1; fi
    "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/cf-auth.bundle"' >/dev/null 2>&1 || true
  else
    warn "auth" "no token files named in config — the clone will run unauthenticated"
  fi
  rm -f "$tmp"

  # 3. crier identity BEFORE provisioning: the node's bus layer refuses without it
  if [ -n "$CRIER_URL" ]; then
    "$HERE/bunker-crier-connect.sh" --agent "$AGENT" --server "$SERVER" --url "$CRIER_URL" \
      --project "$PROJECT" --stage 2>&1 | sed 's/^/  ..    /' \
      || { bad "crier_stage" "could not stage the crier identity"; rc=1; }
  fi

  # 4. gateway auth BEFORE the harness layer: a public bind is refused without it (CF-150)
  if [ "${HARNESS:-hermes}" = "hermes" ]; then
    say "  ..    ensuring dashboard.basic_auth"
    tmp=$(mktemp); chmod 600 "$tmp"; cp "$HERE/node_gateway_auth.py" "$tmp"
    local gw_out gw_rc
    if "$b" cp "$tmp" "$AGENT:node_gateway_auth.py" --server "$SERVER" >/dev/null 2>&1; then
      gw_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
        "python3 \$HOME/node_gateway_auth.py \$HOME/.hermes/config.yaml \$HOME/.node/auth/gateway.pass \$AGENT" 2>&1)
      gw_rc=$?
      printf '%s\n' "$gw_out" | sed 's/^/  ..    /'
      [ "$gw_rc" -eq 0 ] && ok "gateway_auth" "dashboard.basic_auth ensured (password on the node only)" \
                          || { bad "gateway_auth" "could not ensure dashboard.basic_auth (exit $gw_rc)"; rc=1; }
    else
      bad "gateway_auth" "could not stage node_gateway_auth.py"; rc=1
    fi
    "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/node_gateway_auth.py"' >/dev/null 2>&1 || true
    rm -f "$tmp"
  fi

  # 5. node plumbing: the tested path (repo + harness + layers), now with credentials in place
  say "  ..    node plumbing (node-create.sh)"
  local -a create_args=(--project "$PROJECT" --repo "$REPO" --ref "${REF:-main}"
                        --harness "${HARNESS:-hermes}" --agent "$AGENT")
  [ -n "$TTL" ] && create_args+=(--ttl "$TTL")
  if BUNKER_SERVER="$SERVER" CRIER_URL="$CRIER_URL" "$HERE/node-create.sh" "${create_args[@]}"; then
    ok "node_create" "$AGENT provisioned by node-create.sh"
  else
    bad "node_create" "node-create.sh failed — see its rows above"; return 1
  fi

  # 6. identity: MERGE into node.json — project-node.sh owns that file's schema, so a
  #    wholesale rewrite would delete node_id/repo/harness/bus and break its consumers.
  say "  ..    merging node identity"
  tmp=$(mktemp); chmod 600 "$tmp"
  cp "$HERE/node_identity.py" "$tmp"
  local ident_out ident_rc
  if "$b" cp "$tmp" "$AGENT:node_identity.py" --server "$SERVER" >/dev/null 2>&1; then
    ident_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
      "python3 \$HOME/node_identity.py \$HOME/.node/node.json namespace='${NAMESPACE:-$PROJECT}' provisioned_by=bunker-provision provisioned_at='$(date -u +%Y-%m-%dT%H:%M:%SZ)'${CRIER_URL:+ bus.base='$CRIER_URL'}" 2>&1)
    ident_rc=$?
    printf '%s\n' "$ident_out" | sed 's/^/  ..    /'
    if [ "$ident_rc" -eq 0 ]; then
      ok "node_json" "merged namespace=${NAMESPACE:-$PROJECT} (schema preserved)"
    else
      bad "node_json" "merge refused by the node (exit $ident_rc)"; rc=1
    fi
  else
    bad "node_json" "could not stage node_identity.py"; rc=1
  fi
  "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/node_identity.py"' >/dev/null 2>&1 || true
  rm -f "$tmp"

  # 7. crier proof — a separate script, because connecting is its own failure surface
  if [ -n "$CRIER_URL" ]; then
    say "  ..    connecting to crier"
    "$HERE/bunker-crier-connect.sh" --agent "$AGENT" --server "$SERVER" --url "$CRIER_URL" --project "$PROJECT" --apply \
      || { bad "crier_connect" "bunker-crier-connect.sh failed"; rc=1; }
  else
    warn "crier_connect" "CRIER_URL unset — node provisioned but not on the bus"
  fi

  say ""
  if [ "$rc" -eq 0 ] && [ "$FAILED" -eq 0 ]; then say "BUNKER APPLIED: $AGENT"; else say "BUNKER INCOMPLETE ($FAILED)"; fi
  [ "$rc" -eq 0 ] && [ "$FAILED" -eq 0 ]
}

destroy() {
  local b
  [ "$YES" -eq 1 ] || { say "refusing to destroy without --yes (would remove agent $AGENT on $SERVER)"; exit 2; }
  [ -n "$AGENT" ] || { say "refusing to destroy: AGENT unset"; exit 2; }
  b=$(have bunker)
  [ -n "$b" ] || { say "bunker client missing"; exit 1; }
  say "destroying $AGENT on $SERVER"
  "$b" destroy "$AGENT" --server "$SERVER" || { bad "destroy" "bunker destroy failed"; exit 1; }
  ok "destroy" "$AGENT removed from $SERVER"
}

# --- args ---------------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:-}"; shift 2 ;;
    --check|--apply|--destroy) MODE="${1#--}"; shift ;;
    --project) CLI_PROJECT="$2"; shift 2 ;;
    --agent) CLI_AGENT="$2"; shift 2 ;;
    --server) CLI_SERVER="$2"; shift 2 ;;
    --repo) CLI_REPO="$2"; shift 2 ;;
    --ref) CLI_REF="$2"; shift 2 ;;
    --harness) CLI_HARNESS="$2"; shift 2 ;;
    --namespace) CLI_NAMESPACE="$2"; shift 2 ;;
    --crier-url) CLI_CRIER="$2"; shift 2 ;;
    --duckbrain-url) DUCKBRAIN_URL="$2"; shift 2 ;;
    --github-token-file) GITHUB_TOKEN_FILE="$2"; shift 2 ;;
    --duckbrain-token-file) DUCKBRAIN_TOKEN_FILE="$2"; shift 2 ;;
    --s3-env-file) S3_ENV_FILE="$2"; shift 2 ;;
    --yes) YES=1; shift ;;
    -h|--help) usage 0 ;;
    *) say "unknown argument: $1"; usage 2 ;;
  esac
done

# config first, then the CLI re-applies on top: the command line always wins
[ -n "$CONFIG" ] && { load_config "$CONFIG" || exit 1; }
[ -n "$CLI_PROJECT" ] && PROJECT="$CLI_PROJECT"
[ -n "$CLI_AGENT" ] && AGENT="$CLI_AGENT"
[ -n "$CLI_SERVER" ] && SERVER="$CLI_SERVER"
[ -n "$CLI_REPO" ] && REPO="$CLI_REPO"
[ -n "$CLI_REF" ] && REF="$CLI_REF"
[ -n "$CLI_HARNESS" ] && HARNESS="$CLI_HARNESS"
[ -n "$CLI_NAMESPACE" ] && NAMESPACE="$CLI_NAMESPACE"
[ -n "$CLI_CRIER" ] && CRIER_URL="$CLI_CRIER"

[ -n "$MODE" ] || usage 2
case "$MODE" in
  check) check ;;
  apply) check >/dev/null 2>&1 || note "preflight rows were not all green; --apply repairs what it can"; apply ;;
  destroy) destroy ;;
esac

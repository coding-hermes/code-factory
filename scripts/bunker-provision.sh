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
# GITHUB_AUTH_MODE picks where the node's git credential comes from:
#   token (default)  GITHUB_TOKEN_FILE is a long-lived PAT.
#   app              a GitHub App installation token, minted here from GITHUB_APP_ENV_FILE.
#                    The node receives only the 3600s token; arm github-app-refresh.sh so it
#                    keeps push rights after the first hour.
#
# Keys (all optional except PROJECT and REPO):
#   PROJECT  AGENT  SERVER  REPO  REF  HARNESS  NAMESPACES  TTL
#   GIT_AUTHOR_NAME  GIT_AUTHOR_EMAIL  [GIT_CO_AUTHOR]   (required for --apply: the node commits)
#   GITHUB_AUTH_MODE  GITHUB_TOKEN_FILE  GITHUB_APP_ENV_FILE  DUCKBRAIN_TOKEN_FILE  S3_ENV_FILE
#   CRIER_AGENT_KEY_FILE  CRIER_AUTH_TOKEN_FILE   (the bus credentials: without them a node
#                                                   cannot read its own inbox at all)
#   CRIER_URL  DUCKBRAIN_URL
#   NODE_ENV_FILE  CONFIG_SET_MODEL_PROVIDER  CONFIG_SET_MODEL_NAME
#   CONFIG_SET_GATEWAY_BIND  CONFIG_SET_GATEWAY_PORT  CONFIG_SET_AGENT_MAX_ITERATIONS
#
# NODE_ENV_FILE names a profile (ENV_<NAME>=<value> or @<path>, see config/node.env.example)
# that scripts/node_env.py applies ON the node — the variables in ~/.hermes/.env plus the five
# CONFIG_SET_* scalars in ~/.hermes/config.yaml — BEFORE the harness layer starts a gateway.
# Without it a node's environment is hand-edited state that cannot be diffed or re-applied.
#
# Idempotent: an existing agent is reused, an existing clone is fast-forwarded, an existing
# node.json is rewritten only when a value differs, and a second profile apply changes nothing.
# --check is read-only and names every measured value; it never writes.
# ch:trace row=CF-214 spec=docs/handbook/OUTLINE.md#M1-PROVISIONING wave=none:serial-worker test=tests/selftest.sh::CF-214 evidence=none:worker-implementation-awaits-foreman-gitreins witness=none:live-node-not-authorized verdict=none:foreman-judge-pending commit=none:worker-sha memory=none:foreman-closeout
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

CONFIG="" MODE="" AGENT="" PROJECT="" SERVER="" REPO="" REF="" HARNESS="" NAMESPACE="" NAMESPACES="" TTL=""
GIT_AUTHOR_NAME="" GIT_AUTHOR_EMAIL="" GIT_CO_AUTHOR=""
GITHUB_AUTH_MODE="" GITHUB_APP_ENV_FILE="" GITHUB_TOKEN_FILE="" DUCKBRAIN_TOKEN_FILE="" S3_ENV_FILE="" CRIER_URL="" DUCKBRAIN_URL=""
CRIER_AGENT_KEY_FILE="" GITHUB_APP_TOKEN_TMP="" CRIER_AUTH_TOKEN_FILE=""
NODE_ENV_FILE=""
CONFIG_SET_MODEL_PROVIDER="" CONFIG_SET_MODEL_NAME="" CONFIG_SET_GATEWAY_BIND=""
CONFIG_SET_GATEWAY_PORT="" CONFIG_SET_AGENT_MAX_ITERATIONS=""
YES=0
CLI_PROJECT="" CLI_AGENT="" CLI_SERVER="" CLI_REPO="" CLI_REF="" CLI_HARNESS="" CLI_NAMESPACE="" CLI_NAMESPACES="" CLI_CRIER=""
CLI_NODE_ENV_FILE="" CLI_GITHUB_AUTH_MODE="" CLI_GITHUB_APP_ENV_FILE=""
CLI_DUCKBRAIN_URL="" CLI_GITHUB_TOKEN_FILE="" CLI_DUCKBRAIN_TOKEN_FILE=""
CLI_CRIER_AGENT_KEY_FILE="" CLI_CRIER_AUTH_TOKEN_FILE="" CLI_S3_ENV_FILE=""
CLI_CONFIG_SET=()

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

# A CLI path with a leading ~/ is not expanded by the shell when it arrives as a quoted argument;
# without this a --*-token-file ~/... silently reads as the literal string and the leg is skipped.
expand_tilde() { case "$1" in "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;; *) printf '%s' "$1" ;; esac }

# --- namespaces: a project may need more than one DuckBrain namespace -------------------------
# NAMESPACES is a comma list; NAMESPACE is the single-namespace alias kept for older configs.
# The primary (first) entry is what NAMESPACE resolves to. Order is preserved: the first is
# "the" namespace a component reaching for one without asking should get.
resolve_namespaces() {
  local raw ns out=""
  raw="${NAMESPACES:-${NAMESPACE:-$PROJECT}}"
  if [ -z "$raw" ]; then
    bad "namespaces" "no namespace declared and PROJECT is unset — a node without one has no memory"
    return 1
  fi
  local IFS=,
  for ns in $raw; do
    ns="$(printf '%s' "$ns" | tr -d '[:space:]')"
    [ -n "$ns" ] || continue
    case "$ns" in
      [a-z0-9]*|[A-Z0-9]*) ;;
      *) bad "namespaces" "'$ns' is not a namespace slug (expected letters, digits, dot, dash, underscore)"; return 1 ;;
    esac
    case "$ns" in
      *[!A-Za-z0-9._-]*) bad "namespaces" "'$ns' is not a namespace slug (expected letters, digits, dot, dash, underscore)"; return 1 ;;
    esac
    case ",$out," in *",$ns,"*) warn "namespaces" "'$ns' declared twice — collapsed"; continue ;; esac
    out="${out:+$out,}$ns"
  done
  if [ -z "$out" ]; then
    bad "namespaces" "the declaration parsed to nothing"
    return 1
  fi
  NAMESPACES="$out"
  NAMESPACE="${NAMESPACES%%,*}"
  return 0
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
      PROJECT|AGENT|SERVER|REPO|REF|HARNESS|NAMESPACE|NAMESPACES|TTL|CRIER_URL|DUCKBRAIN_URL|GITHUB_AUTH_MODE)
        printf -v "$key" '%s' "$val" ;;
      GIT_AUTHOR_NAME|GIT_AUTHOR_EMAIL|GIT_CO_AUTHOR)
        printf -v "$key" '%s' "$val" ;;
      CONFIG_SET_MODEL_PROVIDER|CONFIG_SET_MODEL_NAME|CONFIG_SET_GATEWAY_BIND|CONFIG_SET_GATEWAY_PORT|CONFIG_SET_AGENT_MAX_ITERATIONS)
        printf -v "$key" '%s' "$val" ;;
      GITHUB_TOKEN_FILE|GITHUB_APP_ENV_FILE|DUCKBRAIN_TOKEN_FILE|S3_ENV_FILE|NODE_ENV_FILE|CRIER_AGENT_KEY_FILE|CRIER_AUTH_TOKEN_FILE)
        case "$val" in "~/"*) val="$HOME/${val#\~/}" ;; esac
        printf -v "$key" '%s' "$val" ;;
      *) bad "config" "$file:$n unknown key $key"; return 1 ;;
    esac
  done < "$file"
  ok "config" "$(basename "$file") — $n lines, KEY=VALUE only"
}

# The declared config.yaml scalars, one <dotted.key>=<value> per line. The file's values come
# first and the command line's last, because node_env.py takes the last value for a repeated
# path — so an override on the CLI wins without a second parser here.
config_set_args() {
  [ -n "$CONFIG_SET_MODEL_PROVIDER" ] && printf 'model.provider=%s\n' "$CONFIG_SET_MODEL_PROVIDER"
  [ -n "$CONFIG_SET_MODEL_NAME" ] && printf 'model.name=%s\n' "$CONFIG_SET_MODEL_NAME"
  [ -n "$CONFIG_SET_GATEWAY_BIND" ] && printf 'gateway.bind=%s\n' "$CONFIG_SET_GATEWAY_BIND"
  [ -n "$CONFIG_SET_GATEWAY_PORT" ] && printf 'gateway.port=%s\n' "$CONFIG_SET_GATEWAY_PORT"
  [ -n "$CONFIG_SET_AGENT_MAX_ITERATIONS" ] && printf 'agent.max_iterations=%s\n' "$CONFIG_SET_AGENT_MAX_ITERATIONS"
  [ "${#CLI_CONFIG_SET[@]}" -gt 0 ] && printf '%s\n' "${CLI_CONFIG_SET[@]}"
  return 0
}

# Parse the declaration against an EMPTY home, locally, before any host is touched: every key
# must be declared, never inherited, and a refusal — an unknown config path, a literal secret,
# a non-ENV line — is a config error. Exit 1 is drift, which is exactly what an empty home is.
env_lint() {
  local home out rc
  local -a args=()
  home=$(mktemp -d)
  [ -n "$NODE_ENV_FILE" ] && args+=(--env-file "$NODE_ENV_FILE")
  while IFS= read -r kv; do args+=(--config-set "$kv"); done < <(config_set_args)
  out=$(env -i HOME="$home" PATH="$PATH" python3 "$HERE/node_env.py" "${args[@]}" --check 2>&1); rc=$?
  rm -rf "$home"
  case "$rc" in
    0|1) ok "env_profile" "$(printf '%s\n' "$out" | sed -n 's/^  \.\.    declared /declared /p' | head -1) — applied on the node before the harness layer" ;;
    2)   bad "env_profile" "$(printf '%s\n' "$out" | grep '^  FAIL' | head -1 | sed -e 's/^  FAIL  env — //' -e 's/^  FAIL  config — /config: /' -e 's/^  FAIL  //')" ;;
    *)   bad "env_profile" "node_env.py --check exited $rc on the declaration" ;;
  esac
}

# --- GitHub authentication -----------------------------------------------------------------
printf_repo_slug() {
  local repo="$1"
  case "$repo" in
    *github.com[:/]*) repo="${repo#*github.com}"; repo="${repo#[:/]}"; repo="${repo%.git}"; printf '%s' "$repo" ;;
    *) printf '' ;;
  esac
}

resolve_github_auth() {
  GITHUB_AUTH_MODE="${GITHUB_AUTH_MODE:-token}"
  GITHUB_APP_ENV_FILE="${GITHUB_APP_ENV_FILE:-$HOME/.config/code-factory/github-app.env}"
  case "$GITHUB_AUTH_MODE" in
    token|app) return 0 ;;
    *) bad "github_auth_mode" "GITHUB_AUTH_MODE='$GITHUB_AUTH_MODE' is not app|token"; return 1 ;;
  esac
}

arm_github_app_refresh() {
  local refresh_out refresh_rc cron_line
  say "  ..    arming GitHub App refresh timer"
  refresh_out=$("$HERE/github-app-refresh.sh" --install-timer --node "$AGENT" --server "$SERVER" --min-age 2400 2>&1)
  refresh_rc=$?
  printf '%s\n' "$refresh_out" | sed 's/^/  ..    /'
  if [ "$refresh_rc" -eq 0 ]; then
    if "${CF_SYSTEMCTL:-systemctl}" --user enable --now "cf-github-app-refresh-$AGENT.timer"; then
      ok "github_app_refresh" "refresh timer enabled for $AGENT (20-minute cadence)"
      return 0
    fi
  fi
  cron_line="*/20 * * * * $HERE/github-app-refresh.sh --node $AGENT --server $SERVER --min-age 2400 --quiet"
  warn "github_app_refresh" "timer installation or enable failed; add this cron entry: $cron_line"
  return 1
}

# --- check: read-only, every row names what it measured --------------------------------------
bunker_ok=0
check() {
  # Every credential and profile the apply will READ must exist here, now. Discovering it at bundle
  # time is a failed provision ten minutes into a host touch, and it is also the only row that proves
  # a --flag actually reached the variable (the flags used to be overwritten by the config file).
  local missing="" readable=""
  for pair in "GITHUB_TOKEN_FILE:$GITHUB_TOKEN_FILE" "DUCKBRAIN_TOKEN_FILE:$DUCKBRAIN_TOKEN_FILE" \
              "CRIER_AGENT_KEY_FILE:$CRIER_AGENT_KEY_FILE" "CRIER_AUTH_TOKEN_FILE:$CRIER_AUTH_TOKEN_FILE" \
              "S3_ENV_FILE:$S3_ENV_FILE" "NODE_ENV_FILE:$NODE_ENV_FILE"; do
    local name="${pair%%:*}" f="${pair#*:}"
    [ -z "$f" ] && continue
    [ -r "$f" ] || missing="$missing $name($f)"
    # The passing row names the files too: a row that says "every file is readable" without
    # naming one cannot prove that a --flag reached the variable instead of the config.
    [ -r "$f" ] && readable="${readable:+$readable }$name=$f"
  done
  if [ -z "$missing" ]; then
    ok "inputs" "readable: ${readable:-none declared}"
  else
    bad "inputs" "not readable:$missing"
  fi

  local b info sha branch dirty harness_bin code
  resolve_namespaces || return 1
  say "bunker-provision --check — project=${PROJECT:-<unset>} agent=${AGENT:-<unset>} server=${SERVER:-<unset>}"
  note "resolved repo=${REPO:-<unset>} ref=${REF:-main} harness=${HARNESS:-hermes} namespaces=${NAMESPACES:-$PROJECT} (primary ${NAMESPACE:-$PROJECT}) ttl=${TTL:-default(6h)} crier=${CRIER_URL:-unset} duckbrain=${DUCKBRAIN_URL:-unset}"
  resolve_github_auth || return 1
  case "$GITHUB_AUTH_MODE" in
    app)
      if [ ! -r "$GITHUB_APP_ENV_FILE" ]; then
        bad "github_app" "mode=app but GITHUB_APP_ENV_FILE $GITHUB_APP_ENV_FILE is unreadable"
      else
        local app_out app_rc app_slug
        app_slug=$(printf_repo_slug "$REPO")
        if [ -n "$app_slug" ]; then
          app_out=$(python3 "$HERE/github-app-token.py" check --env-file "$GITHUB_APP_ENV_FILE" --repo "$app_slug" 2>&1)
        else
          app_out=$(python3 "$HERE/github-app-token.py" check --env-file "$GITHUB_APP_ENV_FILE" 2>&1)
        fi
        app_rc=$?
        if [ "$app_rc" -eq 0 ]; then
          ok "github_app" "mode=app: freshly minted installation token reads ${app_slug:-the configured repo}; token value never printed"
        else
          bad "github_app" "$(printf '%s\n' "$app_out" | grep '^  FAIL' | head -1 | sed 's/^  FAIL  //')"
        fi
      fi ;;
    token)
      if [ -n "$GITHUB_TOKEN_FILE" ] && [ -r "$GITHUB_TOKEN_FILE" ]; then
        ok "github_auth" "mode=token, PAT file readable: $GITHUB_TOKEN_FILE"
      elif [ -n "$GITHUB_TOKEN_FILE" ]; then
        bad "github_auth" "GITHUB_TOKEN_FILE $GITHUB_TOKEN_FILE is unreadable"
      else
        warn "github_auth" "mode=token with no GITHUB_TOKEN_FILE — clone may be unauthenticated"
      fi ;;
  esac

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
  # The probe is STAGED, not inlined. A single-quoted heredoc full of escaped quotes shipped
  # literal backslashes to the node, every path failed there, and the check reported a fully
  # provisioned node as empty — a false negative that would have sent an operator to re-provision.
  local pf pfname="cf-probe.$$.sh"
  pf=$(mktemp)
  cat > "$pf" <<'CFPROBE'
    cd "$HOME/repo" 2>/dev/null || { echo "repo=absent"; exit 0; }
    echo "repo=present"
    echo "sha=$(git rev-parse --short HEAD 2>/dev/null)"
    echo "branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "dirty=$(git status --porcelain 2>/dev/null | grep -vc "^??" || true)"
    echo "node_json=$([ -f "$HOME/.node/node.json" ] && echo present || echo absent)"
    echo "github=$([ -s "$HOME/.node/auth/github.token" ] && echo present || echo absent)"
    echo "duckbrain=$([ -s "$HOME/.node/auth/duckbrain.token" ] && echo present || echo absent)"
    echo "crier_json=$([ -f "$HOME/.node/crier.json" ] && echo present || echo absent)"
    echo "crier_key=$([ -s "$HOME/.node/agent.key" ] && echo present || echo absent)"
    echo "crier_bearer=$([ -s "$HOME/.node/auth/crier.token" ] && echo present || echo absent)"
    echo "gitcred=$([ -s "$HOME/.git-credentials" ] && echo present || echo absent)"
    echo "gitreins=$(if [ -x "$HOME/gitreins-venv/bin/gitreins" ]; then "$HOME/gitreins-venv/bin/gitreins" --version 2>/dev/null | awk '{print $2}'; elif command -v gitreins >/dev/null 2>&1; then gitreins --version 2>/dev/null | awk '{print $2}'; else echo absent; fi)"
    echo "precommit=$([ -x "$HOME/repo/.git/hooks/pre-commit" ] && echo present || echo absent)"
    echo "hermes=$(if [ -x "$HOME/hermes-venv/bin/hermes" ] || [ -x "$HOME/.local/bin/hermes" ] || command -v hermes >/dev/null 2>&1; then echo present; else echo absent; fi)"
    echo "gw_auth=$(grep -q basic_auth: "$HOME/.hermes/config.yaml" 2>/dev/null && echo present || echo absent)"
CFPROBE
  timeout 60 "$b" cp "$pf" "$AGENT:$pfname" --server "$SERVER" >/dev/null 2>&1 || true
  probe=$(timeout 60 "$b" exec --server "$SERVER" "$AGENT" -- bash -lc "bash \"\$HOME/$pfname\"" 2>/dev/null) || true
  # --check must leave nothing behind. The probe has to travel as a FILE (bunker's exec does not
  # forward stdin), so it is removed again in the same run; before CF-214 every check left a
  # cf-probe.sh in the node's home for good, which made "read-only" a claim about intent only.
  timeout 60 "$b" exec --server "$SERVER" "$AGENT" -- bash -lc "rm -f \"\$HOME/$pfname\"" >/dev/null 2>&1 \
    || bad "probe" "could not remove the staged probe $pfname from the node — this --check left a file behind"
  rm -f "$pf"

  case "$probe" in *repo=present*) ok "repo" "clone present ($(printf '%s' "$probe" | sed -n 's/^sha=//p') branch $(printf '%s' "$probe" | sed -n 's/^branch=//p'), $(printf '%s' "$probe" | sed -n 's/^dirty=//p') dirty)" ;;
    *) bad "repo" "no clone at \$HOME/repo — run --apply" ;; esac
  case "$probe" in *node_json=present*) ok "node_json" "identity written" ;;
    *) bad "node_json" "\$HOME/.node/node.json absent" ;; esac
  case "$probe" in *github=present*) ok "auth_github" "token file installed, mode 600 (value not read)" ;;
    *) bad "auth_github" "no \$HOME/.node/auth/github.token" ;; esac
  case "$probe" in *duckbrain=present*) ok "auth_duckbrain" "token file installed (value not read)" ;;
    *) bad "auth_duckbrain" "no \$HOME/.node/auth/duckbrain.token" ;; esac
  case "$probe" in *crier_key=present*) ok "crier_key" "agent key installed at 600 (the bus verifies its signature)" ;;
    *) bad "crier_key" "no \$HOME/.node/agent.key — the inbox answers 401 to every read" ;; esac
  case "$probe" in *crier_bearer=present*) ok "crier_bearer" "bus bearer installed at 600" ;;
    *) bad "crier_bearer" "no \$HOME/.node/auth/crier.token — a signed read still needs the bearer" ;; esac
  case "$probe" in *gitcred=present*) ok "git_credential" "\$HOME/.git-credentials present, mode 600 store" ;;
    *) bad "git_credential" "no \$HOME/.git-credentials — the clone cannot authenticate" ;; esac
  case "$probe" in *gw_auth=present*) ok "gateway_auth" "dashboard.basic_auth present — a public bind is legal" ;;
    *) bad "gateway_auth" "no dashboard.basic_auth — the gateway will refuse to bind (CF-150)" ;; esac
  case "$probe" in *gitreins=absent*|*gitreins=) bad "gitreins" "absent on the node — commits from this host are ungraded" ;;
    *gitreins=*) ok "gitreins" "version $(printf '%s' "$probe" | sed -n 's/^gitreins=//p')" ;; esac
  case "$probe" in *precommit=present*) ok "commit_hook" "pre-commit installed in the clone" ;;
    *) bad "commit_hook" "no pre-commit hook — the gate is not armed" ;; esac
  case "$probe" in *hermes=present*) ok "harness" "$HARNESS binary present" ;;
    *) bad "harness" "no $HARNESS binary on the node" ;; esac

  # the declared environment: parsed here and applied on the node by --apply, so a refused
  # declaration is named before a host is touched
  if [ -n "$NODE_ENV_FILE" ] && [ ! -r "$NODE_ENV_FILE" ]; then
    bad "env_profile" "NODE_ENV_FILE $NODE_ENV_FILE is unreadable"
  elif [ -n "$NODE_ENV_FILE" ] || [ -n "$(config_set_args)" ]; then
    env_lint
  else
    warn "env_profile" "no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere"
  fi

  # crier: delegate to the one script that knows how to prove a signed read. This block used to
  # re-implement the probe with a curl, which can only ever see 401 on a hardened bus (the signer is
  # checked before the agent is looked up) and reported a wired node as not connected.
  if [ -z "$CRIER_URL" ]; then
    warn "crier" "CRIER_URL unset — reachability unproven"
  else
    crier_out=$(timeout 120 "$HERE/bunker-crier-connect.sh" --check \
      --agent "$AGENT" --server "$SERVER" --url "$CRIER_URL" --project "$PROJECT" 2>&1) || true
    case "$crier_out" in
      *"CRIER: CONNECTED"*)
        local signed_row
        signed_row=$(printf '%s' "$crier_out" | grep -E '^  PASS  signed_read —' | head -1 | sed 's/^ *//')
        if [ -n "$signed_row" ]; then
          ok "crier" "signed read accepted: $signed_row"
        else
          warn "crier" "host inbox route answered 200, unsigned; signed read was not measured (node-side probe skipped)"
        fi ;;
      *)
        bad "crier" "$(printf '%s' "$crier_out" | grep -E 'FAIL ' | head -1 | sed 's/^ *//')" ;;
    esac
  fi

  if [ -n "$DUCKBRAIN_URL" ] && [ -r "$DUCKBRAIN_TOKEN_FILE" ]; then
    local ns
    local IFS=,
    for ns in ${NAMESPACES:-$NAMESPACE}; do
      case ",$NAMESPACES," in
        *",$ns,"*) ;;
        *) continue ;;
      esac
      # The token goes to curl on STDIN (-K -), never in argv: a header on the command line is
      # visible to every local user through ps, which is exactly what "credentials never travel as
      # arguments" forbids (AGENTS.md r8). Found by a quorum seat reading this line against the docs.
      code=$(printf 'header = "x-api-key: %s"\nurl = "%s"\n' \
               "$(head -c 4096 "$DUCKBRAIN_TOKEN_FILE" | tr -d '\r\n')" \
               "$DUCKBRAIN_URL/api/memories/key/x?namespace=$ns" \
             | curl -s -K - -o /dev/null -m 8 -w '%{http_code}' 2>/dev/null); code=${code:-000}
      case "$code" in
        200|404) ok "duckbrain:$ns" "$DUCKBRAIN_URL namespace=$ns -> $code" ;;
        *) bad "duckbrain:$ns" "$DUCKBRAIN_URL namespace=$ns -> $code" ;;
      esac
    done
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
  if [ -n "$CRIER_AGENT_KEY_FILE" ] && [ -r "$CRIER_AGENT_KEY_FILE" ]; then
    out+="agentkey_b64=$(base64 -w0 "$CRIER_AGENT_KEY_FILE")"$'\n'
  fi
  if [ -n "$CRIER_AUTH_TOKEN_FILE" ] && [ -r "$CRIER_AUTH_TOKEN_FILE" ]; then
    # The bearer may live in a plain token file OR in an EnvironmentFile that also holds other
    # keys (the crier unit reads one). Extract the value in the second case rather than asking an
    # operator to copy the secret to a second path.
    local tok
    tok=$(head -c 4096 "$CRIER_AUTH_TOKEN_FILE" | tr -d '\r')
    case "$tok" in
      *CR_AUTH_TOKEN=*) tok="${tok##*CR_AUTH_TOKEN=}"; tok="${tok%%$'\n'*}" ;;
    esac
    tok=$(printf '%s' "$tok" | tr -d '\n')
    [ -n "$tok" ] && out+="crierbearer=$tok"$'\n'
  fi
  if [ -n "$S3_ENV_FILE" ] && [ -r "$S3_ENV_FILE" ]; then
    out+="s3="$'\n'"$(sed -e 's/^/  /' "$S3_ENV_FILE")"$'\n'
  fi
  printf '%s' "$out"
}

apply() {
  local b tmp rc=0
  resolve_namespaces || return 1
  say "bunker-provision --apply — project=$PROJECT agent=$AGENT server=$SERVER"

  [ -n "$PROJECT" ] || { bad "project" "PROJECT unset in config"; return 1; }
  [ -n "$REPO" ] || { bad "repo" "REPO unset in config"; return 1; }
  [ -n "$SERVER" ] || { bad "server" "SERVER unset"; return 1; }
  # A node that cannot reach a bus is half a node: refuse before touching the host rather than
  # provisioning something that has to be re-provisioned the moment it is used.

  # This used to `return 1` from the middle of check(), which skipped every row ordered after it —
  # including the DuckBrain namespaces and the final tally. A missing bus is one FAIL, not an early exit.
  [ -n "$CRIER_URL" ] || bad "crier_url" "CRIER_URL unset — a node must know its bus (set it in the config or --crier-url)"

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

  # 2. credentials BEFORE the clone: app mode mints the 3600s installation token before
  # building the same auth bundle used by token mode. The App key never enters the bundle.
  resolve_github_auth || return 1
  if [ "$GITHUB_AUTH_MODE" = app ]; then
    [ -r "$GITHUB_APP_ENV_FILE" ] || { bad "github_app" "GITHUB_APP_ENV_FILE $GITHUB_APP_ENV_FILE is unreadable"; return 1; }
    GITHUB_APP_TOKEN_TMP=$(mktemp); chmod 600 "$GITHUB_APP_TOKEN_TMP"
    if ! python3 "$HERE/github-app-token.py" token --env-file "$GITHUB_APP_ENV_FILE" --out "$GITHUB_APP_TOKEN_TMP" >"${GITHUB_APP_TOKEN_TMP}.log" 2>&1; then
      bad "github_app" "installation token mint failed — nothing was installed on the node"
      rm -f "$GITHUB_APP_TOKEN_TMP"; GITHUB_APP_TOKEN_TMP=""; return 1
    fi
    GITHUB_TOKEN_FILE="$GITHUB_APP_TOKEN_TMP"
    ok "github_app" "installation token minted before the auth bundle (valid 3600s; App key stays on control host)"
  fi
  tmp=$(mktemp); chmod 600 "$tmp"
  bundle_paths x > "$tmp"
  if [ -s "$tmp" ]; then
    say "  ..    installing auth bundle (before the clone)"
    if ! "$b" cp "$tmp" "$AGENT:cf-auth.bundle" --server "$SERVER" >/dev/null 2>&1; then
      bad "auth" "could not copy the bundle into $AGENT"; rc=1
    else
      # The row must follow what the NODE measured. It used to print "installed under
      # $HOME/.node/auth, mode 600" as a literal: nothing compared the modes the snippet reports,
      # and the node-side delete was a `|| true`, so a bundle left behind was silent (CF-214).
      local auth_out auth_rc modes off
      auth_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc '
         set -e
         mkdir -p "$HOME/.node/auth"; chmod 700 "$HOME/.node" "$HOME/.node/auth"
         umask 077
         g=$(sed -n "s/^github=//p" "$HOME/cf-auth.bundle" | head -1)
         d=$(sed -n "s/^duckbrain=//p" "$HOME/cf-auth.bundle" | head -1)
         [ -n "$g" ] && printf "%s\n" "$g" > "$HOME/.node/auth/github.token"
         [ -n "$d" ] && printf "%s\n" "$d" > "$HOME/.node/auth/duckbrain.token"
         sed -n "/^s3=$/,\$p" "$HOME/cf-auth.bundle" | tail -n +2 | sed "s/^  //" > "$HOME/.node/auth/s3.env" 2>/dev/null || true
         [ -s "$HOME/.node/auth/s3.env" ] || rm -f "$HOME/.node/auth/s3.env"
         k=$(sed -n "s/^agentkey_b64=//p" "$HOME/cf-auth.bundle" | head -1)
         [ -n "$k" ] && printf "%s" "$k" | base64 -d > "$HOME/.node/agent.key" && chmod 600 "$HOME/.node/agent.key"
         t=$(sed -n "s/^crierbearer=//p" "$HOME/cf-auth.bundle" | head -1)
         [ -n "$t" ] && printf "%s\n" "$t" > "$HOME/.node/auth/crier.token" && chmod 600 "$HOME/.node/auth/crier.token"
         chmod 600 "$HOME/.node/auth/"* 2>/dev/null || true
         if [ -s "$HOME/.node/auth/github.token" ]; then
           printf "https://x-access-token:%s@github.com\n" "$(cat "$HOME/.node/auth/github.token")" > "$HOME/.git-credentials"
           chmod 600 "$HOME/.git-credentials"
           git config --global credential.helper "store --file=$HOME/.git-credentials"
         fi
         for f in "$HOME/.node/auth/"*; do [ -e "$f" ] && printf "  %s mode %s\n" "$(basename "$f")" "$(stat -c %a "$f")"; done
       ' 2>&1); auth_rc=$?
      printf '%s\n' "$auth_out" | sed 's/^/  ..    /'
      modes=$(printf '%s\n' "$auth_out" | sed -n 's/^  \([A-Za-z0-9._-]*\) mode \([0-7]*\)$/\1=\2/p')
      off=$(printf '%s\n' "$modes" | grep -v '=600$' | tr '\n' ' ')
      if [ "$auth_rc" -ne 0 ]; then
        bad "auth" "the bundle install failed on the node (exit $auth_rc) — rows above"; rc=1
      elif [ -z "$modes" ]; then
        bad "auth" "the node installed no file it could measure — nothing was proven"; rc=1
      elif [ -n "$off" ]; then
        bad "auth" "installed but not mode 600: $off"; rc=1
      else
        ok "auth" "installed under \$HOME/.node/auth at mode 600: $(printf '%s' "$modes" | tr '\n' ' ')"
      fi
      # Deletion is part of the contract, not cleanup advice: a bundle left behind is a credential
      # leak with a friendly name (the skill's own rule). Prove it is gone instead of `|| true`-ing it.
      if "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/cf-auth.bundle"; [ ! -e "$HOME/cf-auth.bundle" ]' >/dev/null 2>&1; then
        ok "auth_bundle" "staged bundle deleted on the node; the local copy is removed too"
      else
        bad "auth_bundle" "could not delete \$HOME/cf-auth.bundle from the node — credential residue"; rc=1
      fi
    fi
  else
    warn "auth" "no token files named in config — the clone will run unauthenticated"
  fi
  rm -f "$tmp"
  if [ -n "$GITHUB_APP_TOKEN_TMP" ]; then
    rm -f "$GITHUB_APP_TOKEN_TMP" "${GITHUB_APP_TOKEN_TMP}.log"
    GITHUB_APP_TOKEN_TMP=""
  fi

  if [ "$GITHUB_AUTH_MODE" = app ] && [ "$rc" -eq 0 ]; then
    arm_github_app_refresh || rc=1
  fi

  # 3. crier identity BEFORE provisioning: the node's bus layer refuses without it
  if [ -n "$CRIER_URL" ]; then
    "$HERE/bunker-crier-connect.sh" --agent "$AGENT" --server "$SERVER" --url "$CRIER_URL" \
      --project "$PROJECT" --stage 2>&1 | sed 's/^/  ..    /' \
      || { bad "crier_stage" "could not stage the crier identity"; rc=1; }
  fi

  # 4. the declared node environment BEFORE the harness layer: the gateway reads ~/.hermes/.env
  #    and config.yaml at start, so a profile applied afterwards is a profile the run contradicts.
  #    The profile is data (a secret is only ever an @file path), so staging it in clear is safe
  #    and both staged files are removed either way.
  if [ -n "$NODE_ENV_FILE" ] || [ -n "$(config_set_args)" ]; then
    say "  ..    node environment profile (before the harness layer)"
    local prof_args="" env_out env_rc
    if [ -n "$NODE_ENV_FILE" ]; then
      if [ ! -r "$NODE_ENV_FILE" ]; then
        bad "env_profile" "NODE_ENV_FILE $NODE_ENV_FILE is unreadable"; rc=1
      elif "$b" cp "$NODE_ENV_FILE" "$AGENT:node.env" --server "$SERVER" >/dev/null 2>&1; then
        prof_args+=" --env-file \$HOME/node.env"
      else
        bad "env_profile" "could not stage $NODE_ENV_FILE"; rc=1
      fi
    fi
    while IFS= read -r kv; do prof_args+=" --config-set $(shq "$kv")"; done < <(config_set_args)
    if [ -n "$prof_args" ]; then
      tmp=$(mktemp); chmod 600 "$tmp"; cp "$HERE/node_env.py" "$tmp"
      if "$b" cp "$tmp" "$AGENT:node_env.py" --server "$SERVER" >/dev/null 2>&1; then
        env_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc "python3 \$HOME/node_env.py --apply$prof_args" 2>&1)
        env_rc=$?
        printf '%s\n' "$env_out" | sed 's/^/  ..    /'
        if [ "$env_rc" -eq 0 ]; then
          ok "env_profile" "declared environment applied (a second run reports no change)"
        else
          bad "env_profile" "node_env.py --apply exited $env_rc on the node — rows above"; rc=1
        fi
      else
        bad "env_profile" "could not stage node_env.py"; rc=1
      fi
      rm -f "$tmp"
    else
      note "nothing stageable to apply — the profile above could not be read"
    fi
    "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/node_env.py" "$HOME/node.env"' >/dev/null 2>&1 || true
  else
    warn "env_profile" "no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere"
  fi

  # 4b. seed the prompts and the declared skills (CF-220). A node with a harness
  # and no procedure is a node whose foreman reports "this run's tools are on the
  # host". The seed is a declared list with digests: it refuses a file outside
  # the list, a file over the budget, and an archive whose digest disagrees.
  seed_manifest="$HERE/../config/node-seed.txt"
  if [ -f "$seed_manifest" ]; then
    say "  ..    seeding prompts and skills"
    seed_dir=$(mktemp -d)
    if python3 "$HERE/node_seed.py" build --manifest "$seed_manifest" \
         --repo-root "$HERE/.." --out "$seed_dir/seed.tar" >"$seed_dir/build.log" 2>&1; then
      if "$b" cp "$seed_dir/seed.tar" "$AGENT:seed.tar" --server "$SERVER" >/dev/null 2>&1 \
         && "$b" cp "$seed_dir/seed.tar.json" "$AGENT:seed.tar.json" --server "$SERVER" >/dev/null 2>&1 \
         && "$b" cp "$HERE/node_seed.py" "$AGENT:node_seed.py" --server "$SERVER" >/dev/null 2>&1; then
        seed_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
          'python3 \$HOME/node_seed.py apply --tar \$HOME/seed.tar --record \$HOME/seed.tar.json --home \$HOME' 2>&1); seed_rc=$?
        if [ "$seed_rc" -eq 0 ]; then
          ok "node_seed" "$(printf '%s\n' "$seed_out" | grep -c '  PASS  ') rows passed on the node"
        else
          bad "node_seed" "apply exited $seed_rc on the node — rows above"
        fi
        "$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
          'rm -f \$HOME/seed.tar \$HOME/seed.tar.json \$HOME/node_seed.py' >/dev/null 2>&1 || true
      else
        bad "node_seed" "could not stage the seed"
      fi
    else
      bad "node_seed" "build refused the declared seed — see the row above"
      sed 's/^/    | /' "$seed_dir/build.log" | head -5
    fi
    rm -rf "$seed_dir"
  else
    warn "node_seed" "config/node-seed.txt is absent — nothing declares what a node receives"
  fi

  # 5. gateway auth BEFORE the harness layer: a public bind is refused without it (CF-150)
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

  # 6. node plumbing: the tested path (repo + harness + layers), now with credentials in place
  say "  ..    node plumbing (node-create.sh)"
  local -a create_args=(--project "$PROJECT" --repo "$REPO" --ref "${REF:-main}"
                        --harness "${HARNESS:-hermes}" --agent "$AGENT")
  [ -n "$TTL" ] && create_args+=(--ttl "$TTL")
  if BUNKER_SERVER="$SERVER" CRIER_URL="$CRIER_URL" "$HERE/node-create.sh" "${create_args[@]}"; then
    ok "node_create" "$AGENT provisioned by node-create.sh"
  else
    # Keep going: node-create also owns the control-host round-trip check, and a node whose
    # ladder is green but whose port is not reachable from here still deserves its identity
    # written. The failure is carried to the exit status, not used to skip the rest.
    bad "node_create" "node-create.sh reported FAIL — see its rows; continuing with the identity"
    rc=1
  fi

  # 7. identity: MERGE into node.json — project-node.sh owns that file's schema, so a
  #    wholesale rewrite would delete node_id/repo/harness/bus and break its consumers.
  say "  ..    merging node identity"
  tmp=$(mktemp); chmod 600 "$tmp"
  cp "$HERE/node_identity.py" "$tmp"
  local ident_out ident_rc
  if "$b" cp "$tmp" "$AGENT:node_identity.py" --server "$SERVER" >/dev/null 2>&1; then
    ident_out=$("$b" exec --server "$SERVER" "$AGENT" -- bash -lc \
      "python3 \$HOME/node_identity.py \$HOME/.node/node.json namespace='${NAMESPACE:-$PROJECT}' 'duckbrain.namespaces[]=${NAMESPACES:-$PROJECT}' provisioned_by=bunker-provision provisioned_at='$(date -u +%Y-%m-%dT%H:%M:%SZ)'${CRIER_URL:+ bus.base='$CRIER_URL'}" 2>&1)
    ident_rc=$?
    printf '%s\n' "$ident_out" | sed 's/^/  ..    /'
    if [ "$ident_rc" -eq 0 ]; then
      ok "node_json" "merged namespaces=${NAMESPACES:-$PROJECT} (primary ${NAMESPACE:-$PROJECT}; schema preserved)"
    else
      bad "node_json" "merge refused by the node (exit $ident_rc)"; rc=1
    fi
  else
    bad "node_json" "could not stage node_identity.py"; rc=1
  fi
  "$b" exec --server "$SERVER" "$AGENT" -- bash -lc 'rm -f "$HOME/node_identity.py"' >/dev/null 2>&1 || true
  rm -f "$tmp"

  # 8. crier proof — a separate script, because connecting is its own failure surface
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
    --namespaces) CLI_NAMESPACES="$2"; shift 2 ;;
    --crier-url) CLI_CRIER="$2"; shift 2 ;;
    --duckbrain-url) CLI_DUCKBRAIN_URL="$2"; shift 2 ;;
    --github-auth-mode) CLI_GITHUB_AUTH_MODE="$2"; shift 2 ;;
    --github-app-env-file) CLI_GITHUB_APP_ENV_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --github-token-file) CLI_GITHUB_TOKEN_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --duckbrain-token-file) CLI_DUCKBRAIN_TOKEN_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --crier-agent-key-file) CLI_CRIER_AGENT_KEY_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --crier-auth-token-file) CLI_CRIER_AUTH_TOKEN_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --s3-env-file) CLI_S3_ENV_FILE="$(expand_tilde "$2")"; shift 2 ;;
    --node-env-file) CLI_NODE_ENV_FILE="$2"; shift 2 ;;
    --config-set) CLI_CONFIG_SET+=("$2"); shift 2 ;;
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
[ -n "$CLI_NAMESPACES" ] && NAMESPACES="$CLI_NAMESPACES"
[ -n "$CLI_CRIER" ] && CRIER_URL="$CLI_CRIER"
[ -n "$CLI_NODE_ENV_FILE" ] && NODE_ENV_FILE="$CLI_NODE_ENV_FILE"
[ -n "$CLI_GITHUB_AUTH_MODE" ] && GITHUB_AUTH_MODE="$CLI_GITHUB_AUTH_MODE"
[ -n "$CLI_GITHUB_APP_ENV_FILE" ] && GITHUB_APP_ENV_FILE="$CLI_GITHUB_APP_ENV_FILE"
# These five were assigned during flag parsing and then overwritten by load_config, so a documented
# flag was silently ignored whenever a config was also passed. They are applied AFTER the config now,
# which is the precedence the SKILL claims: the command line wins.
[ -n "$CLI_DUCKBRAIN_URL" ] && DUCKBRAIN_URL="$CLI_DUCKBRAIN_URL"
[ -n "$CLI_GITHUB_TOKEN_FILE" ] && GITHUB_TOKEN_FILE="$CLI_GITHUB_TOKEN_FILE"
[ -n "$CLI_DUCKBRAIN_TOKEN_FILE" ] && DUCKBRAIN_TOKEN_FILE="$CLI_DUCKBRAIN_TOKEN_FILE"
[ -n "$CLI_CRIER_AGENT_KEY_FILE" ] && CRIER_AGENT_KEY_FILE="$CLI_CRIER_AGENT_KEY_FILE"
[ -n "$CLI_CRIER_AUTH_TOKEN_FILE" ] && CRIER_AUTH_TOKEN_FILE="$CLI_CRIER_AUTH_TOKEN_FILE"
[ -n "$CLI_S3_ENV_FILE" ] && S3_ENV_FILE="$CLI_S3_ENV_FILE"

[ -n "$MODE" ] || usage 2
trap 'if [ -n "${GITHUB_APP_TOKEN_TMP:-}" ]; then rm -f "$GITHUB_APP_TOKEN_TMP" "${GITHUB_APP_TOKEN_TMP}.log"; fi' EXIT
case "$MODE" in
  check) check ;;
  apply)
    # Run the preflight in a SUBSHELL: its bad() rows must not land in this run's FAILED
    # counter, or a repaired preflight still reports as thirteen failures at the end.
    ( check >/dev/null 2>&1 ) || note "preflight rows were not all green; --apply repairs what it can"
    apply ;;
  destroy) destroy ;;
esac

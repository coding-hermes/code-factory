#!/usr/bin/env bash
# install-codex.sh — the codex adapter for code-factory (CF-227).
#
# The adapter exists in crier (internal/harness/codex/codex.go) and the host had no binary
# and this repo had no installer. This script closes that gap, and it is measured, not
# documented: the ladder below was run on a Linux x86_64 host on 2026-11-04.
#
#   install-codex.sh --check        report binary, pin, the exec contract, auth, workdir
#   install-codex.sh --apply        install the pinned artefact under $HOME; idempotent
#   install-codex.sh --turn         ONE real turn in CF_WORKDIR that must write CF_TURN_TOKEN
#   install-codex.sh --app-server   start the app-server sidecar on stdio and probe initialize
#
# Exit codes: 0 PASS · 1 FAIL · 2 REFUSED (a named refusal; nothing was installed or run).
#
# WHAT CODEX ACTUALLY OFFERS (measured with rust-v0.166.0 on this host, 2026-11-04)
#
#   exec        `codex exec --json [--skip-git-repo-check] -s <sandbox> -m <model> -- <text>`
#               Non-interactive. This is the surface crier uses: `--json` emits the
#               `{"type":"thread.started","thread_id":...}` event the adapter parses, `-` reads
#               the prompt from stdin, and `codex exec resume <id>` continues a thread.
#               Measured: a turn wrote the requested file, and `thread.started` carried a uuid.
#   app-server  `codex app-server` speaks JSON-RPC on stdio — but it is labelled
#               `[experimental]` in `codex --help`, and NOTHING IN CRIER USES IT: `grep -rn
#               app-server` over crier@6422c851 returns no hits, and codex.go's own doc comment
#               names "two verified surfaces: exec create / exec resume". The brief that said
#               "the scheduler expects an app-server sidecar" is not what the tree says.
#               Measured anyway, because the claim is cheap to test: `initialize` over stdio
#               answers with {"result":{"userAgent":"…cf/0.166.0…"}}, so the sidecar works if
#               someone wires it. `--app-server` is that probe; it is not required for a turn.
#
# THE PIN is a GitHub release tarball, not npm (npm ships a JS shim plus per-platform optional
# deps and would drag node into a node-less image). The digest below was measured here from a
# TLS download and is what `fetch_verified` enforces; a mismatch is a hard failure, never a
# retry. rust-v0.166.0 publishes x86_64 linux only (no aarch64 linux asset), so --apply refuses
# by name on any other arch rather than installing something that cannot run.
#
# CREDENTIALS: never a value in argv, never read from the ambient environment (AGENTS.md r8,
# specs/HARNESS-MATRIX.md §5). A key arrives as CF_API_KEY_FILE — a path, mode 600 — or as the
# host's own `$HOME/.codex/auth.json` login, which is reported as ambient because it is.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"

# CF-229 centralises the CF_* contract in scripts/harness/harness-vars.sh. Until that lands the
# same flags are parsed below; if the sibling's file is present it is sourced first so its
# defaults can apply (a value it sets is overridden by an explicit flag, never the reverse).
if [ -f "$HERE/harness-vars.sh" ]; then . "$HERE/harness-vars.sh"; fi

PIN="${CF_CODEX_PIN:-0.166.0}"
RELEASE="rust-v${PIN}"
SHA256="a0bf572d2f93f056c6712a6da348e96078dc84f3885fd7be67807ef389cb3978"
INSTALL_ROOT="$HOME/.local/codex"
PREFIX="$INSTALL_ROOT/$PIN"
BIN="$PREFIX/bin/codex"
SHIM="$HOME/.local/bin/codex"
DISK_FLOOR_GB=1.0
DEFAULT_SANDBOX="workspace-write"
TURN_TOKEN="${CF_TURN_TOKEN:-CF-227-TOKEN-7f3a9c}"
TURN_FILE="${CF_TURN_FILE:-codex-turn.txt}"
TIMEOUT_S="${CF_TIMEOUT_S:-300}"
MODE="--check"
DEEP=0

# The required set from specs/HARNESS-MATRIX.md §5. CF_API_KEY_FILE is required for a paid
# provider; CF_SKILLS_DIR and CF_HARNESS_OPTS are accepted and recorded (codex has its own
# AGENTS.md convention for skills, and the options bag is recorded so two runs are comparable).
declare -A VAR=( [CF_MODEL]="${CF_MODEL:-}" [CF_PROVIDER]="${CF_PROVIDER:-}"
                 [CF_BASE_URL]="${CF_BASE_URL:-}" [CF_API_KEY_FILE]="${CF_API_KEY_FILE:-}"
                 [CF_WORKDIR]="${CF_WORKDIR:-}" [CF_NAMESPACE]="${CF_NAMESPACE:-}"
                 [CF_RUN_ID]="${CF_RUN_ID:-}" [CF_LANE]="${CF_LANE:-}"
                 [CF_SKILLS_DIR]="${CF_SKILLS_DIR:-}" [CF_HARNESS_OPTS]="${CF_HARNESS_OPTS:-}"
                 [CF_MAX_TURNS]="${CF_MAX_TURNS:-}" )
REQUIRED=(CF_MODEL CF_PROVIDER CF_WORKDIR CF_NAMESPACE CF_RUN_ID CF_LANE)

refuse() {  # refuse <leg> <reason> — a named refusal; nothing is installed or run
  printf '  FAIL  %s — refused: %s\n' "$1" "$2"
  printf 'CODEX: REFUSED (%s)\n' "$1"
  exit 2
}

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'CODEX_VARS'
THE VARIABLE CONTRACT (specs/HARNESS-MATRIX.md §5). Each name is accepted as the flag AND as the
CF_* environment variable; the directive is the only source, so nothing is inferred or inherited.
  CF_MODEL          --model          model id requested by task-router                    (required)
  CF_PROVIDER       --provider       provider lane (anthropic, openai-codex, deepseek, …) (required)
  CF_BASE_URL       --base-url       endpoint the harness must talk to                    (optional)
  CF_API_KEY_FILE   --api-key-file   PATH to a mode-600 key file — never a value          (paid lanes)
  CF_WORKDIR        --workdir        the clone the harness may write in; must be in $HOME (required)
  CF_NAMESPACE      --namespace      DuckBrain namespace for the run's writes             (required)
  CF_RUN_ID         --run-id         correlation id from the bus envelope                 (required)
  CF_LANE           --lane           lane name (e.g. code-factory-qa)                     (required)
  CF_SKILLS_DIR     --skills-dir     seeded skills root on the node                       (optional)
  CF_HARNESS_OPTS   --harness-opts   key=value,key=value — recorded verbatim              (optional)
  CF_MAX_TURNS      --max-turns      turn budget, default 40                              (optional)
  CF_TIMEOUT_S      --timeout-s      wall-clock budget for one turn, default 1800         (optional)
CODEX_VARS
}

# --- the CF_* argument surface ---------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --*=*)
      _k="${1%%=*}"; _v="${1#*=}"
      shift
      set -- "$_k" "$_v" "$@"
      continue
      ;;
  esac
  case "$1" in
    --check|--apply|--turn|--app-server) MODE="$1"; shift ;;
    --deep) DEEP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    # A credential as a VALUE is a FAIL, and the value is never echoed.
    --api-key|--key|--token|--openai-api-key)
      refuse "credential_argv" "a credential may never travel as an argument (AGENTS.md r8) — pass --api-key-file <path> instead" ;;
    --model|--provider|--base-url|--api-key-file|--workdir|--namespace|--run-id|--lane|--skills-dir|--harness-opts|--max-turns|--timeout-s)
      _flag="$1"
      if [ "$#" -lt 2 ] || [ "${2#--}" != "$2" ]; then refuse "args" "$_flag needs a value"; fi
      _v="$2"
      case "$_flag" in
        --model) VAR[CF_MODEL]="$_v" ;;
        --provider) VAR[CF_PROVIDER]="$_v" ;;
        --base-url) VAR[CF_BASE_URL]="$_v" ;;
        --api-key-file) VAR[CF_API_KEY_FILE]="$_v" ;;
        --workdir) VAR[CF_WORKDIR]="$_v" ;;
        --namespace) VAR[CF_NAMESPACE]="$_v" ;;
        --run-id) VAR[CF_RUN_ID]="$_v" ;;
        --lane) VAR[CF_LANE]="$_v" ;;
        --skills-dir) VAR[CF_SKILLS_DIR]="$_v" ;;
        --harness-opts) VAR[CF_HARNESS_OPTS]="$_v" ;;
        --max-turns) VAR[CF_MAX_TURNS]="$_v" ;;
        --timeout-s) TIMEOUT_S="$_v" ;;
      esac
      shift 2
      ;;
    *) refuse "args" "unknown argument '$1' — see --help" ;;
  esac
done

# The ambient environment is not a credential channel. Refusing here is the point: two lanes on
# one node must not be able to contaminate each other through an exported key.
if [ -n "${CF_API_KEY:-}" ]; then
  refuse "credential_ambient" "CF_API_KEY is set in the environment — unset it and pass --api-key-file <path>"
fi
if [ -n "${OPENAI_API_KEY:-}" ]; then
  refuse "credential_ambient" "OPENAI_API_KEY is set in the environment; a harness may not read a key from ambient state — unset it and pass --api-key-file <path>"
fi

# --- helpers ---------------------------------------------------------------------------------
bin_for_run() { if [ -x "$BIN" ]; then printf '%s' "$BIN"; else have codex; fi; }

# codex prints "codex-cli 0.166.0"; the pin is the bare version.
codex_version() {
  local raw
  raw=$("$1" --version 2>/dev/null) || return 1
  raw="${raw%%$'\n'*}"
  printf '%s\n' "${raw##* }"
}

at_pin() { [ -n "${1:-}" ] && [ "$1" = "$PIN" ]; }

# Provider names in the CF contract map onto codex's built-in provider ids.
codex_provider() {
  case "${1:-}" in
    openai|openai-codex|codex) printf 'openai' ;;
    *) printf '%s' "${1:-openai}" ;;
  esac
}

target_triple() {  # prints the release triple this pin has a MEASURED digest for, else fails
  # rust-v0.166.0 publishes several targets, but this installer carries a digest for exactly
  # one of them (x86_64 linux musl). Claiming an artefact whose digest was never measured is
  # how a "pinned" install stops being pinned, so everything else refuses by name.
  local arch="${CF_CODEX_ARCH:-$(uname -m)}" os
  os="$(uname -s)"
  case "$arch" in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) return 1 ;;
  esac
  case "$os/$arch" in
    Linux/x86_64) printf 'x86_64-unknown-linux-musl' ;;
    *) return 1 ;;
  esac
}

# The required set is validated whenever any of it is supplied; --turn always needs all of it.
validate_vars() {
  local supplied=0 missing=() v rid
  for v in "${REQUIRED[@]}" CF_SKILLS_DIR CF_BASE_URL CF_HARNESS_OPTS CF_MAX_TURNS; do
    [ -n "${VAR[$v]:-}" ] && supplied=1
  done
  if [ "$MODE" != "--turn" ] && [ "$supplied" -eq 0 ]; then return 0; fi
  for v in "${REQUIRED[@]}"; do
    if [ -z "${VAR[$v]:-}" ]; then missing+=("$v"); fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    refuse "vars" "the CF_* set from specs/HARNESS-MATRIX.md §5 is incomplete; missing: ${missing[*]} (a value in argv for a credential is always a FAIL)"
  fi
  # CF-277: CF_RUN_ID is a correlation id, not a path. It is admitted only as a bare identifier —
  # a value carrying a separator or a dot-dot segment can escape any directory it is joined to,
  # and admission is the one place that can fail closed before anything is created or removed.
  # The value is echoed back truncated: a refusal still has to name what it refused.
  rid="${VAR[CF_RUN_ID]:-}"
  if [ -n "$rid" ]; then
    if [ "${#rid}" -gt 128 ] || [[ ! "$rid" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      refuse "run_id" "CF_RUN_ID must be a bare identifier (^[A-Za-z0-9][A-Za-z0-9._-]*\$, max 128 chars); got '$(printf '%.64s' "$rid")' (${#rid} chars)"
    fi
  fi
  if [ "$MODE" = "--turn" ] && [ -z "${VAR[CF_API_KEY_FILE]:-}" ]; then
    note "CF_API_KEY_FILE unset — the turn will use the host login at \$HOME/.codex/auth.json (ambient, named as such)"
  fi
  [ -n "${VAR[CF_MAX_TURNS]:-}" ] && [[ ! "${VAR[CF_MAX_TURNS]}" =~ ^[0-9]+$ ]] &&
    refuse "vars" "CF_MAX_TURNS must be an integer, got '${VAR[CF_MAX_TURNS]}'"
  # The options bag is recorded verbatim, so it is public: it may never carry a credential.
  if [ -n "${VAR[CF_HARNESS_OPTS]:-}" ]; then
    if printf '%s' "${VAR[CF_HARNESS_OPTS]}" | grep -Eqi 'sk-|api[_-]?key=|token=|secret=|password='; then
      refuse "vars" "CF_HARNESS_OPTS looks like it carries a credential; options are recorded, so they are public"
    fi
    if ! printf '%s' "${VAR[CF_HARNESS_OPTS]}" | grep -Eq '^[A-Za-z0-9_.-]+=[^,]+(,[A-Za-z0-9_.-]+=[^,]+)*$'; then
      refuse "vars" "CF_HARNESS_OPTS must be key=value[,key=value]"
    fi
  fi
  # Record the accepted set by name: a variable this adapter cannot act on is still named, so it is
  # never accepted and silently ignored (matrix §5, row CF-229). CF_API_KEY_FILE is recorded as a
  # boolean, never as its content: it may arrive as a value by mistake, and a refusal must not
  # become the leak it exists to prevent.
  for v in "${REQUIRED[@]}" CF_BASE_URL CF_SKILLS_DIR CF_HARNESS_OPTS; do
    note "contract:$v = ${VAR[$v]:-unset}"
  done
  if [ -n "${VAR[CF_API_KEY_FILE]:-}" ]; then
    note "contract:CF_API_KEY_FILE = <set: ${#VAR[CF_API_KEY_FILE]} chars; content never recorded>"
  else
    note "contract:CF_API_KEY_FILE = unset"
  fi
  note "contract:CF_MAX_TURNS = ${VAR[CF_MAX_TURNS]:-40}   CF_TIMEOUT_S = ${TIMEOUT_S:-300}"
}

inside_home() {  # inside_home <abs path>
  case "$1" in "$HOME"/*) return 0 ;; *) return 1 ;; esac
}

# The turn cache root (CF-277), and the only tree a turn may create or remove under.
turn_cache_root() { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/cf-codex"; }

# inside_turn_cache <abs path> — true only for one mktemp leaf directly under the cache root.
# Both the EXIT trap and any delete ask this before touching a directory, so a path is removable
# only when it is provably inside the cache root.
inside_turn_cache() {
  local root leaf
  root="$(turn_cache_root)"
  case "${1:-}" in "$root"/run.?*) ;; *) return 1 ;; esac
  leaf="${1#"$root"/}"
  case "$leaf" in */*) return 1 ;; esac
  return 0
}

check_api_key_file() {
  local path="${VAR[CF_API_KEY_FILE]:-}" mode
  [ -n "$path" ] || return 0
  # A VALUE is refused before anything looks it up, and the value is never echoed (matrix §5,
  # AGENTS.md r8): a key-shaped string, or a bare opaque token with no path separator.
  case "$path" in
    sk-*|sk_*|ghp_*|gho_*|xox[abp]-*|AIza*|*' '*)
      refuse "credential" "CF_API_KEY_FILE carries a credential VALUE, not a path (length ${#path}; the value is not printed) — pass a mode-600 file path" ;;
    */*) : ;;
    *) [ "${#path}" -ge 20 ] &&
         refuse "credential" "CF_API_KEY_FILE carries a credential VALUE, not a path (length ${#path}; the value is not printed) — pass a mode-600 file path" ;;
  esac
  [ -e "$path" ] || refuse "credential" "CF_API_KEY_FILE does not exist: $path"
  [ -f "$path" ] || refuse "credential" "CF_API_KEY_FILE is not a regular file: $path"
  [ -r "$path" ] || refuse "credential" "CF_API_KEY_FILE is not readable by this user: $path"
  inside_home "$path" || refuse "credential" "CF_API_KEY_FILE must live inside \$HOME: $path"
  mode=$(stat -c '%a' "$path" 2>/dev/null || echo '')
  case "$mode" in
    600|400) : ;;
    '') refuse "credential" "cannot read the mode of $path" ;;
    *) refuse "credential" "CF_API_KEY_FILE must be mode 600 (AGENTS.md r8), found $mode: $path" ;;
  esac
  [ -s "$path" ] || refuse "credential" "CF_API_KEY_FILE is empty: $path"
  # The key is written into a copy of auth.json for an isolated CODEX_HOME, so it must not be
  # able to break out of a JSON string.
  if LC_ALL=C grep -q '[^A-Za-z0-9._-]' "$path" 2>/dev/null; then
    refuse "credential" "CF_API_KEY_FILE contains characters that are not a bare key token — refusing to copy it"
  fi
  ok "credential" "CF_API_KEY_FILE is a mode $mode file inside \$HOME (value not read)"
}

check_workdir() {
  local dir="${VAR[CF_WORKDIR]:-}"
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] || refuse "workdir" "CF_WORKDIR does not exist as a directory: $dir"
  inside_home "$dir" || refuse "workdir" "CF_WORKDIR must be inside \$HOME and must not be an ancestor of it: $dir"
  # Measured: codex refuses "Not inside a trusted directory" without --skip-git-repo-check, and
  # crier's adapter does not pass that flag — the workdir is specified as a clone, so a clone is
  # what is required. A silent --skip-git-repo-check here would hide the adapter's real shape.
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "workdir" "$dir is a git work tree"
  else
    refuse "workdir" "$dir is not a git work tree — codex refuses 'Not inside a trusted directory' and crier does not pass --skip-git-repo-check"
  fi
}

# --- check legs ------------------------------------------------------------------------------
report_auth() {
  local host_login="$HOME/.codex/auth.json" mode
  if [ -n "${VAR[CF_API_KEY_FILE]:-}" ]; then return 0; fi          # validated and reported above
  if [ -f "$host_login" ]; then
    mode=$(stat -c '%a' "$host_login" 2>/dev/null || echo '?')
    warn "auth" "\$HOME/.codex/auth.json exists (mode $mode) — a host login is ambient state, not a directive; fine for a measured turn, not for a node"
  else
    warn "auth" "no CF_API_KEY_FILE and no \$HOME/.codex/auth.json — an unattended turn will fail at auth"
  fi
}

report_exec_contract() {  # report_exec_contract <binary>
  local b="$1" h missing=0
  h=$("$b" exec --help 2>/dev/null)
  [ -n "$h" ] || { bad "exec_contract" "codex exec --help produced nothing"; return 1; }
  case "$h" in
    *--json*) ok "exec_contract" "exec --json (the adapter's thread.started event)" ;;
    *) bad "exec_contract" "exec --json missing — crier cannot read the thread id"; missing=1 ;;
  esac
  case "$h" in
    *--sandbox*) ok "exec_contract" "exec -s/--sandbox (the mode is never inherited from config)" ;;
    *) bad "exec_contract" "exec -s/--sandbox missing — the delivery would inherit ~/.codex/config.toml"; missing=1 ;;
  esac
  if "$b" exec resume --help >/dev/null 2>&1; then
    ok "exec_contract" "exec resume <id> (continue a thread)"
  else
    bad "exec_contract" "exec resume missing — crier's continue path cannot work"; missing=1
  fi
  case "$h" in
    *--skip-git-repo-check*)
      note "  exec --skip-git-repo-check is advertised; crier does not pass it, so CF_WORKDIR must be a clone" ;;
  esac
  return "$missing"
}

report_app_server() {  # report_app_server <binary>
  local b="$1" h
  h=$("$b" app-server --help 2>/dev/null)
  case "$h" in
    *app\ server*|*app-server*)
      warn "app_server" "[experimental] app-server subcommand present — crier@6422c851 does not use it (exec mode); probe with --app-server" ;;
    *) bad "app_server" "no app-server subcommand (a sidecar consumer could not be served)"; return 1 ;;
  esac
}

report_doctor() {  # report_doctor <binary> — honest, optional, and slow
  local b="$1" out status
  # doctor exits non-zero when a check fails; the report is still the evidence, so keep it.
  out=$(timeout 60 "$b" doctor --json 2>/dev/null || true)
  [ -n "$out" ] || { warn "doctor" "doctor --json produced nothing"; return 0; }
  status=$(printf '%s' "$out" | sed -n 's/.*"overallStatus": *"\([a-z]*\)".*/\1/p' | head -1)
  case "$status" in
    ok|pass) ok "doctor" "overallStatus: $status" ;;
    '') warn "doctor" "doctor --json output carried no overallStatus" ;;
    *) warn "doctor" "overallStatus: $status — name the failing check before blaming the harness" ;;
  esac
}

# --- modes -----------------------------------------------------------------------------------
say "harness: codex (pin $PIN, mode $MODE)"

if [ "$MODE" = "--check" ] || [ "$MODE" = "--apply" ]; then
  validate_vars
  check_api_key_file
  check_workdir
fi

if [ "$MODE" = "--turn" ]; then
  validate_vars
  check_api_key_file
  check_workdir
fi

case "$MODE" in
  --check)
    if ! target=$(target_triple); then
      target="none"
      warn "artefact" "no codex artefact for ${CF_CODEX_ARCH:-$(uname -m)}/$(uname -s) in $RELEASE — --apply would refuse"
    fi
    b="$(bin_for_run)"
    if [ -x "$BIN" ]; then
      ok "binary" "$BIN (installed by this adapter)"
    elif [ -n "$b" ]; then
      bad "binary" "host-provided $b — not installed by this adapter, so the pin is unowned (run --apply)"
    else
      bad "binary" "absent — run --apply (pin $PIN, $target)"
    fi
    if [ -n "$b" ]; then
      v=$(codex_version "$b") || v="unknown"
      if at_pin "$v"; then ok "version" "$v (pin $PIN)"
      else bad "version" "${v:-unreadable} != pin $PIN"; fi
      report_exec_contract "$b"
      report_app_server "$b"
      [ "$DEEP" -eq 1 ] && report_doctor "$b"
    else
      bad "version" "unreadable — no binary"
      bad "exec_contract" "unverified — no binary"
      bad "app_server" "unverified — no binary"
    fi
    report_auth
    say ""
    verdict CODEX
    exit $?
    ;;

  --apply)
    target=$(target_triple) || refuse "arch" \
      "no measured codex artefact for ${CF_CODEX_ARCH:-$(uname -m)}/$(uname -s) in $RELEASE — this installer pins x86_64-unknown-linux-musl only"
    require_disk "$HOME" "$DISK_FLOOR_GB" || { say ""; verdict CODEX action; exit $?; }
    if [ -x "$BIN" ]; then
      v=$(codex_version "$BIN") || v="unknown"
      if at_pin "$v"; then
        note "already installed: $BIN ($v) — nothing to do"
        ok "install" "$BIN ($v) unchanged"
        at_pin "$v" && ok "version" "$v (pin $PIN)" || bad "version" "$v != pin $PIN"
      else
        note "$BIN reports ${v:-unreadable} != pin $PIN — replacing"
        rm -rf "$PREFIX" || { bad "install" "cannot remove $PREFIX"; say ""; verdict CODEX action; exit $?; }
      fi
    fi
    if [ ! -x "$BIN" ]; then
      url="${CF_CODEX_URL:-https://github.com/openai/codex/releases/download/$RELEASE/codex-$target.tar.gz}"
      want="${CF_CODEX_SHA256:-$SHA256}"
      say "apply"
      note "fetching $url"
      tmpdir=$(umask 077; mktemp -d) || { bad "download" "cannot create a temp dir"; say ""; verdict CODEX action; exit $?; }
      tarball="$tmpdir/codex.tar.gz"
      if ! fetch_verified "$url" "$tarball" "$want"; then
        rm -rf "$tmpdir"
        bad "download" "download or digest check failed for $url (want sha256 $want)"
        say ""; verdict CODEX action; exit $?
      fi
      ok "download" "sha256 matches the pin ($want)"
      member=$(tar tzf "$tarball" 2>/dev/null | grep -E "^codex-[^/]+$" | head -1)
      if [ -z "$member" ]; then
        rm -rf "$tmpdir"; bad "layout" "tarball has no top-level codex-<target> member"; say ""; verdict CODEX action; exit $?
      fi
      mkdir -p "$PREFIX/bin" || { rm -rf "$tmpdir"; bad "install" "cannot create $PREFIX/bin"; say ""; verdict CODEX action; exit $?; }
      if ! tar xzf "$tarball" -C "$tmpdir" "$member" 2>/dev/null; then
        rm -rf "$tmpdir"; bad "install" "extraction failed for $member"; say ""; verdict CODEX action; exit $?
      fi
      install -m 0755 "$tmpdir/$member" "$BIN" || { rm -rf "$tmpdir"; bad "install" "cannot place $BIN"; say ""; verdict CODEX action; exit $?; }
      rm -rf "$tmpdir"
      v=$(codex_version "$BIN") || v="unknown"
      if at_pin "$v"; then
        ok "install" "$BIN (read back $v)"
        ok "version" "$v (pin $PIN)"
      else
        rm -rf "$PREFIX"
        bad "version" "installed binary reads back '${v:-unreadable}' != pin $PIN — removed"
      fi
    fi
    # CF-006: --apply names the binary it placed. The node manifest records this path, so
    # verify-node.sh measures THAT binary on the node instead of whatever PATH happens to resolve
    # — an owned pin under $HOME is frequently not on PATH at all.
    [ -x "$BIN" ] && ok "binary" "$BIN"
    # The shim is what makes crier's LookupBinary find the pin on PATH. Never overwrite a real
    # host binary: the adapter labels it host-provided, and so does this.
    if [ -x "$BIN" ]; then
      if [ -L "$SHIM" ]; then
        ln -sfn "$BIN" "$SHIM" && ok "path" "$SHIM -> $BIN"
      elif [ -e "$SHIM" ]; then
        warn "path" "$SHIM is a host-provided file — left alone; put $PREFIX/bin first on PATH instead"
      else
        mkdir -p "$(dirname "$SHIM")" && ln -sfn "$BIN" "$SHIM" && ok "path" "$SHIM -> $BIN"
      fi
      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ok "path_env" "\$HOME/.local/bin is on PATH" ;;
        *) warn "path_env" "\$HOME/.local/bin is not on PATH — export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
      esac
    fi
    report_auth
    say ""
    verdict CODEX action
    exit $?
    ;;

  --app-server)
    b="$(bin_for_run)"
    [ -n "$b" ] || { bad "app_server" "no binary — run --apply first"; say ""; verdict CODEX action; exit $?; }
    v=$(codex_version "$b") || v="unknown"
    note "binary $b ($v)"
    coproc CF_AS { "$b" app-server 2>/dev/null; }
    printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"code-factory","version":"0.1.0"}}}\n' >&"${CF_AS[1]}"
    line=""
    read -r -t 30 line <&"${CF_AS[0]}" || true
    exec {CF_AS[1]}>&- 2>/dev/null || true
    kill "$CF_AS_PID" 2>/dev/null || true
    wait "$CF_AS_PID" 2>/dev/null || true
    case "$line" in
      *'"userAgent"'*)
        ok "app_server" "initialize answered: $(printf '%s' "$line" | sed -n 's/.*"userAgent":"\([^"]*\)".*/\1/p')" ;;
      '') bad "app_server" "no initialize answer within 30 s (sidecar exited or spoke another protocol)" ;;
      *) bad "app_server" "unexpected initialize answer: $(printf '%.120s' "$line")" ;;
    esac
    say ""
    verdict CODEX action
    exit $?
    ;;

  --turn)
    b="$(bin_for_run)"
    [ -n "$b" ] || { bad "turn" "no codex binary — run --apply first"; say ""; verdict CODEX action; exit $?; }
    v=$(codex_version "$b") || v="unknown"
    [ -x "$BIN" ] && ok "binary" "$BIN ($v)" \
      || warn "binary" "host-provided $b ($v) — the pin is unowned"
    workdir="${VAR[CF_WORKDIR]}"
    provider="$(codex_provider "${VAR[CF_PROVIDER]}")"
    model="${VAR[CF_MODEL]}"

    # CODEX_HOME: an isolated one per run when a key file is supplied, so neither the model nor
    # the key can come from the host's ~/.codex. With no key file the host login is the only
    # credential that exists, and it is used — named, not assumed.
    #
    # CF-277: the turn home is a fresh mktemp directory under the turn cache root — never a path
    # built from CF_RUN_ID — and the EXIT trap removes it only when inside_turn_cache agrees the
    # path is one leaf under that root. There is no delete before the directory is created.
    turn_home=""
    cache_root="$(turn_cache_root)"
    cleanup() {
      [ -n "$turn_home" ] || return 0
      inside_turn_cache "$turn_home" || return 0    # outside the cache root: never removed
      rm -rf -- "$turn_home"
    }
    trap cleanup EXIT INT TERM
    if [ -n "${VAR[CF_API_KEY_FILE]:-}" ]; then
      mkdir -p "$cache_root" && chmod 700 "$cache_root" \
        || { bad "turn_home" "cannot create the turn cache root $cache_root"; say ""; verdict CODEX action; exit $?; }
      turn_home=$(umask 077; mktemp -d "$cache_root/run.XXXXXXXX") \
        || { turn_home=""; bad "turn_home" "cannot create a turn directory under $cache_root"; say ""; verdict CODEX action; exit $?; }
      {
        printf 'model = "%s"\n' "$model"
        printf 'model_provider = "%s"\n' "$provider"
        printf 'sandbox_mode = "%s"\n' "$DEFAULT_SANDBOX"
        printf 'approval_policy = "never"\n'
      } >"$turn_home/config.toml" && chmod 600 "$turn_home/config.toml"
      # The copy is deleted by the EXIT trap (CF-108: a credential file is deleted after use).
      { printf '{"OPENAI_API_KEY":"'; cat "${VAR[CF_API_KEY_FILE]}"; printf '"}\n'; } >"$turn_home/auth.json"
      chmod 600 "$turn_home/auth.json"
      ok "turn_home" "$turn_home (isolated config + key, mode 600, deleted on exit)"
    else
      ok "turn_home" "\$HOME/.codex (host login; the model and provider are still pinned on argv)"
    fi

    rm -f "$workdir/$TURN_FILE"
    prompt="Create a file named $TURN_FILE in the current working directory whose entire content is exactly this one line and nothing else: $TURN_TOKEN"
    stdout_f="$workdir/.cf-codex-turn.out"
    stderr_f="$workdir/.cf-codex-turn.err"
    note "one turn: model=$model provider=$provider workdir=$workdir timeout=${TIMEOUT_S}s"
    rc=0
    if [ -n "$turn_home" ]; then
      ( cd "$workdir" && timeout "$TIMEOUT_S" env -u OPENAI_API_KEY CODEX_HOME="$turn_home" \
          "$b" exec --json -s "$DEFAULT_SANDBOX" -c "model_provider=\"$provider\"" -m "$model" \
          -- "$prompt" ) >"$stdout_f" 2>"$stderr_f" </dev/null || rc=$?
    else
      ( cd "$workdir" && timeout "$TIMEOUT_S" env -u OPENAI_API_KEY \
          "$b" exec --json -s "$DEFAULT_SANDBOX" -c "model_provider=\"$provider\"" -m "$model" \
          -- "$prompt" ) >"$stdout_f" 2>"$stderr_f" </dev/null || rc=$?
    fi
    [ "$rc" -eq 0 ] && ok "turn_exit" "exit 0" || bad "turn_exit" "exit $rc — $(head -c 300 "$stderr_f" 2>/dev/null | tr '\n' ' ')"

    tid=$(sed -n 's/.*"type":"thread.started","thread_id":"\([^"]*\)".*/\1/p' "$stdout_f" 2>/dev/null | head -1)
    [ -n "$tid" ] && ok "thread" "$tid (parsed from the thread.started event, as crier does)" \
      || bad "thread" "no thread.started thread_id in --json output"

    # model_served is read from codex's own rollout record, not inferred from the request.
    served=""
    if [ -n "$tid" ]; then
      root="${turn_home:-$HOME/.codex}"
      rollout=$(find "$root/sessions" -name "*$tid.jsonl" -print 2>/dev/null | head -1)
      [ -n "$rollout" ] && served=$(sed -n 's/.*"thread_settings":{[^}]*"model": *"\([^"]*\)".*/\1/p' "$rollout" 2>/dev/null | head -1)
    fi
    if [ -n "$served" ]; then
      ok "model_served" "requested $model → served $served"
    else
      warn "model_served" "requested $model → served unknown (no rollout record found); exec --json does not report it"
    fi

    if [ -f "$workdir/$TURN_FILE" ]; then
      got=$(tr -d '\r' <"$workdir/$TURN_FILE" | sed -e 's/[[:space:]]*$//')
      if [ "$got" = "$TURN_TOKEN" ]; then
        ok "artifact" "$workdir/$TURN_FILE contains the fixed token (sha256 $(sha256sum "$workdir/$TURN_FILE" | cut -d' ' -f1))"
      else
        bad "artifact" "$workdir/$TURN_FILE does not contain the fixed token"
      fi
    else
      bad "artifact" "$workdir/$TURN_FILE was not written"
    fi
    rm -f "$stdout_f" "$stderr_f"
    say ""
    verdict CODEX action
    exit $?
    ;;
esac

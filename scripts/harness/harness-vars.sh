#!/usr/bin/env bash
# harness-vars.sh — ONE implementation of the variable contract, specs/HARNESS-MATRIX.md §5.
#
# Sourced, never executed, and side-effect free on load (install-codex.sh sources it
# opportunistically when it is present): it defines functions and two arrays and nothing else, so
# an installer that picks it up behaves exactly as it did before when no CF_* input is supplied.
#
# What it implements, in the spec's own words:
#   * the same twelve names arrive as a flag OR a CF_* environment variable — both are accepted,
#     and every one of them is recorded by name, so nothing is accepted and then silently ignored;
#   * a credential is a PATH (CF_API_KEY_FILE, mode 600). A VALUE is a named refusal, exit 2;
#   * CF_API_KEY set at all, or OPENAI_API_KEY / ANTHROPIC_API_KEY in the ambient environment, is
#     a named refusal: the directive is the only source, so two lanes on one node cannot
#     contaminate each other (matrix §5, AGENTS.md r8);
#   * CF_WORKDIR must exist and resolve inside $HOME;
#   * CF_MAX_TURNS / CF_TIMEOUT_S are integers in 1..1000 / 1..86400.
#
# Usage from an installer:
#   . "$HERE/harness-vars.sh"
#   cfv_load_env                 # read the CF_* names from the environment (never inferred)
#   cfv_parse_args "$@"          # validates argv; sets CFV_MODE (check|apply|contract) and CFV_HELP
#   cfv_validate "$CFV_MODE"     # prints one row per check; sets CFV_FAILED
#   cfv_refused && exit 2        # a refusal is named, and nothing was installed or run
#
# Codes: 1 → the contract refusal counter; 2 → usage/refusal exit (the caller exits it).

# The declared set, in the spec's order (specs/HARNESS-MATRIX.md §5).
CFV_DECLARED=(CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE
              CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S)
# The run-scoped subset the spec marks "required"; --contract mode refuses when one is missing.
CFV_REQUIRED=(CF_MODEL CF_PROVIDER CF_WORKDIR CF_NAMESPACE CF_RUN_ID CF_LANE)
# Provider keys that must never be read from the node's ambient environment (matrix §5).
CFV_AMBIENT_KEYS=(OPENAI_API_KEY ANTHROPIC_API_KEY)
declare -A CFV_VALUE=()   # associative: CFV_VALUE[CF_MODEL]="…"
CFV_FAILED=0
CFV_MODE="check"
CFV_HELP=0

cfv_declared() { printf '%s\n' "${CFV_DECLARED[@]}"; }

cfv_help_block() {
  cat <<'CFV_HELP_BLOCK'
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

  --contract         Validate the §5 set and exit 0 (or 2 with a named refusal). Installing
                     nothing and running nothing: validating the contract is not an install.
CFV_HELP_BLOCK
}

# A refusal: names the rule, touches nothing, exits 2 (the caller's usage exit code).
cfv_refuse() {  # cfv_refuse <leg> <reason>
  printf '  FAIL  %s — refused: %s\n' "$1" "$2"
  printf 'CONTRACT: REFUSED (%s)\n' "$1"
  exit 2
}

cfv_fail() { bad "$1" "$2"; CFV_FAILED=$((CFV_FAILED + 1)); }
cfv_refused() { [ "${CFV_FAILED:-0}" -gt 0 ]; }

cfv_path_shaped() {
  case "$1" in
    /*|./*|../*|~/*) return 0 ;;
    */*) return 0 ;;
    *) return 1 ;;
  esac
}

# A credential VALUE, not a path: a known key prefix, or a bare opaque token.
cfv_secret_shaped() {
  local v="$1"
  case "$v" in sk-*|sk_*|xox[abp]-*|ghp_*|gho_*|AIza*) return 0 ;; esac
  case "$v" in */*|*' '*) return 1 ;; esac
  [ ${#v} -ge 20 ] && printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_+=.-]+$'
}

cfv_flag_for() {  # <flag> -> the CF_* name it sets
  case "$1" in
    --model) printf 'CF_MODEL' ;;
    --provider) printf 'CF_PROVIDER' ;;
    --base-url) printf 'CF_BASE_URL' ;;
    --api-key-file) printf 'CF_API_KEY_FILE' ;;
    --workdir) printf 'CF_WORKDIR' ;;
    --namespace) printf 'CF_NAMESPACE' ;;
    --run-id) printf 'CF_RUN_ID' ;;
    --lane) printf 'CF_LANE' ;;
    --skills-dir) printf 'CF_SKILLS_DIR' ;;
    --harness-opts) printf 'CF_HARNESS_OPTS' ;;
    --max-turns) printf 'CF_MAX_TURNS' ;;
    --timeout-s) printf 'CF_TIMEOUT_S' ;;
    *) return 1 ;;
  esac
}

# Read one declared variable from the environment. The names are spelled out because bash treats an
# unset *indirect* expansion as an error under `set -u`, and every installer here runs with -u.
cfv_env_value() {
  case "$1" in
    CF_MODEL) printf '%s' "${CF_MODEL:-}" ;;
    CF_PROVIDER) printf '%s' "${CF_PROVIDER:-}" ;;
    CF_BASE_URL) printf '%s' "${CF_BASE_URL:-}" ;;
    CF_API_KEY_FILE) printf '%s' "${CF_API_KEY_FILE:-}" ;;
    CF_WORKDIR) printf '%s' "${CF_WORKDIR:-}" ;;
    CF_NAMESPACE) printf '%s' "${CF_NAMESPACE:-}" ;;
    CF_RUN_ID) printf '%s' "${CF_RUN_ID:-}" ;;
    CF_LANE) printf '%s' "${CF_LANE:-}" ;;
    CF_SKILLS_DIR) printf '%s' "${CF_SKILLS_DIR:-}" ;;
    CF_HARNESS_OPTS) printf '%s' "${CF_HARNESS_OPTS:-}" ;;
    CF_MAX_TURNS) printf '%s' "${CF_MAX_TURNS:-}" ;;
    CF_TIMEOUT_S) printf '%s' "${CF_TIMEOUT_S:-}" ;;
    CF_API_KEY) printf '%s' "${CF_API_KEY:-}" ;;
    OPENAI_API_KEY) printf '%s' "${OPENAI_API_KEY:-}" ;;
    ANTHROPIC_API_KEY) printf '%s' "${ANTHROPIC_API_KEY:-}" ;;
    *) printf '' ;;
  esac
}

# Read the declared set from the environment. Only these twelve names are ever read here.
cfv_load_env() {
  local k v
  for k in "${CFV_DECLARED[@]}"; do
    if [ -z "${CFV_VALUE[$k]:-}" ]; then
      v="$(cfv_env_value "$k")"
      [ -z "$v" ] || CFV_VALUE[$k]="$v"
    fi
  done
}

cfv_parse_args() {
  local flag name
  while [ $# -gt 0 ]; do
    case "$1" in
      --*=*)                                  # --flag=value
        flag="${1%%=*}"; name="${1#*=}"; shift
        set -- "$flag" "$name" "$@"
        continue
        ;;
    esac
    case "$1" in
      --check) CFV_MODE="check"; shift ;;
      --apply) CFV_MODE="apply"; shift ;;
      --contract) CFV_MODE="contract"; shift ;;
      --help|-h) CFV_HELP=1; shift ;;
      # A credential already unpacked into argv is past the point where a path can be enforced.
      --api-key|--key|--token|--openai-api-key|--anthropic-api-key)
        cfv_refuse "credential_argv" \
          "a credential may never travel as an argument (AGENTS.md r8) — pass --api-key-file <path>" ;;
      --model|--provider|--base-url|--api-key-file|--workdir|--namespace|--run-id|--lane|--skills-dir|--harness-opts|--max-turns|--timeout-s)
        [ $# -ge 2 ] || cfv_refuse "args" "$1 needs a value"
        name="$(cfv_flag_for "$1")"
        CFV_VALUE[$name]="$2"
        shift 2
        ;;
      *) cfv_refuse "args" "unknown argument '$1' — see --help" ;;
    esac
  done
}

# ---------------------------------------------------------------- contract (§5)
cfv_validate() {  # cfv_validate <check|apply|contract>
  local mode="${1:-check}" v k real work m missing=""

  # ---- no credential as a value, and no credential from the ambient environment
  if [ -n "$(cfv_env_value CF_API_KEY)" ]; then
    cfv_fail "contract:CF_API_KEY" \
      "refused — CF_API_KEY is a VALUE and is not in the contract; pass CF_API_KEY_FILE=<path> (matrix §5, AGENTS.md r8)"
  fi
  for k in "${CFV_AMBIENT_KEYS[@]}"; do
    if [ -n "$(cfv_env_value "$k")" ]; then
      cfv_fail "contract:ambient" \
        "refused — $k is set in the ambient environment; the directive is the only source, so two lanes on one node cannot contaminate each other (matrix §5). unset $k and pass CF_API_KEY_FILE/CF_BASE_URL"
    fi
  done

  # ---- CF_API_KEY_FILE: a path to a mode-600 file, checked and never read
  v="${CFV_VALUE[CF_API_KEY_FILE]:-}"
  if [ -n "$v" ]; then
    if cfv_secret_shaped "$v"; then
      cfv_fail "contract:CF_API_KEY_FILE" \
        "refused — a credential VALUE was passed, not a path; the contract is path-only (length ${#v}, value not printed)"
    elif ! cfv_path_shaped "$v"; then
      cfv_fail "contract:CF_API_KEY_FILE" \
        "refused — '$v' is not a path (expected /abs/path or ~/path); values are refused, paths are required"
    elif [ ! -f "$v" ]; then
      cfv_fail "contract:CF_API_KEY_FILE" "refused — no such key file: $v"
    elif [ ! -s "$v" ]; then
      cfv_fail "contract:CF_API_KEY_FILE" "refused — key file is empty: $v"
    else
      m="$(stat -c '%a' "$v" 2>/dev/null || echo '?')"
      case "$m" in
        [0-7]00) ok "contract:CF_API_KEY_FILE" "$v (mode $m, content not read)" ;;
        *) cfv_fail "contract:CF_API_KEY_FILE" "refused — $v is mode $m; a key file must be 600 (chmod 600 $v)" ;;
      esac
    fi
  else
    note "contract:CF_API_KEY_FILE — unset (no credential path; a paid lane supplies one)"
  fi

  # ---- CF_BASE_URL: an http(s) endpoint, and never a credential in a URL
  v="${CFV_VALUE[CF_BASE_URL]:-}"
  if [ -n "$v" ]; then
    case "$v" in
      http://*|https://*) ;;
      *) cfv_fail "contract:CF_BASE_URL" "refused — '$v' is not an http(s) URL" ;;
    esac
    case "${v#*://}" in
      *@*) cfv_fail "contract:CF_BASE_URL" "refused — the URL carries userinfo; a credential in a URL is still a credential as a value" ;;
    esac
  fi

  # ---- the named set: shape only, because the spec fixes the shape
  v="${CFV_VALUE[CF_MODEL]:-}"
  case "$v" in *' '*) cfv_fail "contract:CF_MODEL" "refused — a model id contains no spaces: '$v'" ;; esac
  for k in CF_PROVIDER CF_NAMESPACE CF_LANE; do
    v="${CFV_VALUE[$k]:-}"
    if [ -n "$v" ]; then
      printf '%s' "$v" | grep -Eq '^[a-z0-9][a-z0-9._-]*$' \
        || cfv_fail "contract:$k" "refused — '$v' is not a lane/namespace name (lowercase, [a-z0-9._-])"
    fi
  done
  v="${CFV_VALUE[CF_RUN_ID]:-}"
  if [ -n "$v" ]; then
    printf '%s' "$v" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:-]*$' \
      || cfv_fail "contract:CF_RUN_ID" "refused — '$v' is not an id ([A-Za-z0-9._:-])"
  fi

  # ---- CF_WORKDIR: it must exist, and it must resolve inside $HOME
  v="${CFV_VALUE[CF_WORKDIR]:-}"
  if [ -n "$v" ]; then
    real="$(cd "$v" 2>/dev/null && pwd -P)" || real=""
    if [ -z "$real" ]; then
      cfv_fail "contract:CF_WORKDIR" "refused — no such directory: $v"
    else
      work="$(cd "$HOME" 2>/dev/null && pwd -P)"
      case "$real" in
        "$work"/*) ok "contract:CF_WORKDIR" "$real (inside \$HOME)" ;;
        *) cfv_fail "contract:CF_WORKDIR" "refused — $real is outside \$HOME ($work); a harness writes only inside \$HOME" ;;
      esac
    fi
  fi

  # ---- CF_SKILLS_DIR: a path, recorded; the node may seed it later
  v="${CFV_VALUE[CF_SKILLS_DIR]:-}"
  if [ -n "$v" ]; then
    if ! cfv_path_shaped "$v"; then
      cfv_fail "contract:CF_SKILLS_DIR" "refused — '$v' is not a path"
    elif [ ! -d "$v" ]; then
      warn "contract:CF_SKILLS_DIR" "$v does not exist yet (the node seeds it before a turn)"
    fi
  fi

  # ---- CF_HARNESS_OPTS: recorded verbatim, so it can never carry a secret
  v="${CFV_VALUE[CF_HARNESS_OPTS]:-}"
  if [ -n "$v" ]; then
    if printf '%s' "$v" | grep -Eqi 'sk-|api[_-]?key=|token=|secret=|password='; then
      cfv_fail "contract:CF_HARNESS_OPTS" \
        "refused — the options bag looks like it carries a credential; options are recorded, so they are public"
    elif ! printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_.-]+=[^,]+(,[A-Za-z0-9_.-]+=[^,]+)*$'; then
      cfv_fail "contract:CF_HARNESS_OPTS" "refused — not key=value[,key=value]: '$v'"
    fi
  fi

  # ---- the budget: integers, in range, with the matrix's defaults
  CFV_MAX_TURNS="${CFV_VALUE[CF_MAX_TURNS]:-40}"
  CFV_TIMEOUT_S="${CFV_VALUE[CF_TIMEOUT_S]:-1800}"
  case "$CFV_MAX_TURNS" in
    ''|*[!0-9]*) cfv_fail "contract:CF_MAX_TURNS" "refused — not an integer: '$CFV_MAX_TURNS'" ;;
    *) if [ "$CFV_MAX_TURNS" -lt 1 ] || [ "$CFV_MAX_TURNS" -gt 1000 ]; then
         cfv_fail "contract:CF_MAX_TURNS" "refused — out of range 1..1000: '$CFV_MAX_TURNS'"
       fi ;;
  esac
  case "$CFV_TIMEOUT_S" in
    ''|*[!0-9]*) cfv_fail "contract:CF_TIMEOUT_S" "refused — not an integer: '$CFV_TIMEOUT_S'" ;;
    *) if [ "$CFV_TIMEOUT_S" -lt 1 ] || [ "$CFV_TIMEOUT_S" -gt 86400 ]; then
         cfv_fail "contract:CF_TIMEOUT_S" "refused — out of range 1..86400: '$CFV_TIMEOUT_S'"
       fi ;;
  esac

  # ---- record the whole declared set: a variable this installer cannot act on is still named,
  # so it is never accepted and silently ignored (matrix §5, row CF-229). CF_API_KEY_FILE is
  # recorded as a boolean, never as its content: it may arrive as a value by mistake, and a
  # refusal must not become the leak it exists to prevent.
  for k in "${CFV_DECLARED[@]}"; do
    if [ "$k" = "CF_API_KEY_FILE" ]; then
      if [ -n "${CFV_VALUE[$k]:-}" ]; then
        note "contract:$k = <set: ${#CFV_VALUE[$k]} chars; content never recorded>"
      else
        note "contract:$k = unset"
      fi
    else
      note "contract:$k = ${CFV_VALUE[$k]:-unset}"
    fi
  done

  # ---- --contract is the acceptance check: the declared set is complete, or it is refused
  if [ "$mode" = "contract" ]; then
    for k in "${CFV_REQUIRED[@]}"; do
      [ -n "${CFV_VALUE[$k]:-}" ] || missing="$missing $k"
    done
    if [ -n "$missing" ]; then
      cfv_fail "contract:required" "refused — the §5 run set is incomplete; dropped:$missing"
    else
      ok "contract:required" "the §5 run set is complete (${#CFV_DECLARED[@]} declared, ${#CFV_REQUIRED[@]} required)"
    fi
  fi
}

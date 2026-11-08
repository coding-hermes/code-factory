#!/usr/bin/env bash
# install-claude-code.sh — pinned, user-space installer and adapter probe for Claude Code (CF-225).
#
# Contract: specs/HARNESS-MATRIX.md §5 (the CF_* set, "no credential as a value", "no key from the
# ambient environment"). Adapter obligations: specs/HARNESS.md (install/version/invoke/report/fail/
# idempotent). Selection, support and the DuckBrain record belong to the matrix, not here.
#
#   install-claude-code.sh --check    read-only: installed? which pin? offline-safe.
#   install-claude-code.sh --apply    install the PIN into $HOME/.local/harness/npm. Idempotent.
#   install-claude-code.sh --turn     one unattended turn in CF_WORKDIR (needs a credential).
#
# Provenance of the pin, measured 2026-11-04 against registry.npmjs.org:
#   package            @anthropic-ai/claude-code
#   version            2.1.318        (dist-tags: latest=2.1.318, stable=2.1.311, next=2.1.318)
#   homepage           https://github.com/anthropics/claude-code   (the ONLY upstream)
#   maintainers        all @anthropic.com addresses (claude-code-npm@anthropic.com, …)
#   dist.shasum        c11067a3db95abe50d0d004e030e418146d3270a
#   dist.integrity     sha512-OTJgLxcvWefv8IdTsq5n90Z2IxEhLwKqHUBhwZYE4odXzKA/Tb6p2Zb5Iy9Vq7JIVcNZzn9cPxW5sb42wLF95Q==
#   dist.signatures    keyid SHA256:DhQ8wR5APBvFHLF/+Tc+AYvPOdTpcIDqOhxsBHRwC7U
#   engines            node >= 22.0.0
# Measured install (this repo's control host, node 22.22.3 / npm 10.9.8): 8 s, 323 MB, and
# `claude --version` reads back "2.1.318 (Claude Code)".
#
# THREE RULES THAT ARE NOT NEGOTIABLE HERE
#   1. user-space: npm --prefix under $HOME, an explicit --prefix on every npm call (a stray
#      ~/.npmrc can point the global prefix at /var/tmp — measured on the control host), never
#      root, never `curl … | sh`.
#   2. a credential is a PATH, never a VALUE: CF_API_KEY_FILE only. A value in argv, or a key
#      exported into the ambient environment, is a hard refusal (AGENTS.md r8, matrix §5).
#   3. the version is read back from the installed binary after install, and a mismatch names
#      both numbers (HARNESS.md: "a version mismatch names both the measured value and the pin").
#
# Exit codes: 0 ok · 1 fail/refused · 2 usage · 3 skip (nothing measurable, e.g. no credential).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"

CLAUDE_CODE_PKG="@anthropic-ai/claude-code"
CLAUDE_CODE_PIN="2.1.318"
CLAUDE_CODE_SHASUM="c11067a3db95abe50d0d004e030e418146d3270a"
CLAUDE_CODE_INTEGRITY="sha512-OTJgLxcvWefv8IdTsq5n90Z2IxEhLwKqHUBhwZYE4odXzKA/Tb6p2Zb5Iy9Vq7JIVcNZzn9cPxW5sb42wLF95Q=="
CLAUDE_CODE_HOMEPAGE="https://github.com/anthropics/claude-code"
NODE_MIN_MAJOR=22

# Derived from HOME only. No override: a run that installs outside $HOME is not user-space.
PREFIX="$HOME/.local/harness/npm"
BIN="$PREFIX/bin/claude"
PKG_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"

MODE="--check"
PROMPT=""
PROMPT_FILE=""
MAX_TURNS=""
TIMEOUT_S=""

usage() {
  cat <<'CLAUDE_CODE_USAGE'
install-claude-code.sh — pinned user-space installer/probe for Claude Code.

USAGE
  install-claude-code.sh [--check | --apply | --turn] [options]

MODES
  --check            (default) Read-only. Reports the binary honestly (absent / host-provided /
                     installed by this adapter), its measured version against the pin, the node
                     and npm it would use, and whether a credential surface exists. Never touches
                     the network. Exit 0 only when the pin is installed here.
  --apply            Install @anthropic-ai/claude-code at the pin under $HOME/.local/harness/npm
                     with an explicit npm --prefix. Verifies the registry metadata for the pin
                     before downloading, then reads the version back from the binary. Re-running
                     it changes nothing: an installed pin is a no-op.
  --turn             One unattended turn in $CF_WORKDIR. Non-interactive (-p), isolated from the
                     user's ~/.claude settings, credential injected from $CF_API_KEY_FILE only.
                     Refuses when no credential exists, and says which one is missing.

OPTIONS
  --prompt TEXT      Directive for --turn (argv is fine: a directive is not a secret).
  --prompt-file F    Read the directive from a file instead.
  --help, -h         This text. Default directive for --turn is stdin when neither is given.

THE VARIABLE CONTRACT (specs/HARNESS-MATRIX.md §5). Read from the directive, never inferred.
  CF_MODEL           model id requested by task-router. Required for --turn.
  CF_PROVIDER        provider lane (anthropic, openai-codex, deepseek, pi, zai, …). Required for --turn.
  CF_BASE_URL        endpoint the harness must talk to (node router / gateway / Anthropic-shaped
                     shim). Optional; unset = Anthropic's own API. Recorded as the provider_binding:
                     provider anthropic + no base URL = "native", anything else = "shim/<host>".
  CF_API_KEY_FILE    PATH to a mode-600 file holding the key. Required for --turn. A VALUE here
                     (sk-…, a bare token) is refused: the contract is a path, and a key in argv is
                     a FAIL. The file's content is never printed, never passed as argv, never logged.
  CF_WORKDIR         the clone the harness may write in. Required for --turn; must be inside $HOME.
  CF_NAMESPACE       DuckBrain namespace for the run's writes. Required for --turn; echoed, not written.
  CF_RUN_ID          correlation id from the bus envelope. Required for --turn; echoed.
  CF_LANE            lane name (e.g. code-factory-qa). Required for --turn; echoed.
  CF_SKILLS_DIR      seeded skills root on the node. Optional; recorded (claude-code has no
                     documented flag for it at this pin, so it is a record field, not a mount).
  CF_HARNESS_OPTS    harness-specific bag, key=value,key=value. Optional and recorded, because an
                     unrecorded option makes two runs incomparable. Refused if it carries a secret.
  CF_MAX_TURNS       turn budget. Optional, default 40. Passed as a CLI flag only if this pin's
                     `--help` advertises it (2.1.318 does not); otherwise recorded as not enforced,
                     with the timeout as the enforced budget.
  CF_TIMEOUT_S       wall-clock budget for one turn. Optional, default 1800, enforced with timeout(1).

REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE, or CF_API_KEY set at all (not in the contract);
  * a credential exported into the ambient environment (ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN /
    CLAUDE_CODE_OAUTH_TOKEN) or an ambient ANTHROPIC_BASE_URL — the directive is the only source;
  * CF_WORKDIR outside $HOME, or not an existing directory for --turn;
  * CF_BASE_URL carrying userinfo (http://user:pass@host) — that is a credential in a URL;
  * a CF_API_KEY_FILE that is missing, empty, or readable by group/other (mode must be 600);
  * running as root; an npm prefix outside $HOME; node older than 22 (the pin's engines field);
  * a provenance check that cannot confirm the pin, or a version read back that differs from it.

ENVIRONMENT OVERRIDE (re-measurement only, not a run input)
  none. Re-pinning is an edit to this file with fresh registry evidence in the header, so a pin
  cannot be silently swapped by an operator's shell.

NON-CLAIMS
  * crier has no claude adapter yet (CRIER-HARNESS-11): this installer/contract half does not make
    claude-code a *supported* harness (matrix I4 needs the five conformance legs on a real node).
  * no DuckBrain write happens here (leg `memory`); this script echoes the record fields it must
    hand to the caller, and says so, rather than pretending to have written it.
CLAUDE_CODE_USAGE
}

die_usage() { say "install-claude-code: $*" >&2; say "try --help" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply|--turn) MODE="$1"; shift ;;
    --prompt) [ $# -ge 2 ] || die_usage "--prompt needs a value"; PROMPT="$2"; shift 2 ;;
    --prompt-file) [ $# -ge 2 ] || die_usage "--prompt-file needs a path"; PROMPT_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

# ---------------------------------------------------------------- small helpers

# The version token the binary reports: "2.1.318 (Claude Code)" -> "2.1.318".
bin_version() {
  local bin="$1" raw
  raw=$("$bin" --version 2>/dev/null) || return 1
  raw=${raw%%$'\n'*}
  case "$raw" in
    *[0-9].[0-9]*) ;;
    *) printf '%s' "${raw:-unknown}"; return 1 ;;
  esac
  printf '%s' "${raw%% *}"
}

node_major() {
  local n="$1" v
  v=$("$n" --version 2>/dev/null) || return 1
  v=${v#v}
  printf '%s' "${v%%.*}"
}

is_path_shaped() {
  case "$1" in
    /*|./*|../*|~/*) return 0 ;;
    */*) return 0 ;;
    *) return 1 ;;
  esac
}

is_secret_shaped() {
  local v="$1"
  case "$v" in sk-*|sk_*|xox[abp]-*|ghp_*|gho_*|AIza*) return 0 ;; esac
  # A bare opaque token: long, no path separator, no whitespace.
  case "$v" in */*|*' '*) return 1 ;; esac
  [ ${#v} -ge 20 ] && printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_+=.-]+$'
}

mode_of() { stat -c '%a' "$1" 2>/dev/null || echo '?'; }

# ---------------------------------------------------------------- contract (§5)

MISSING_TURN_VARS=""

need_turn_var() {
  local name="$1" value="$2"
  if [ -z "$value" ]; then MISSING_TURN_VARS="$MISSING_TURN_VARS $name"; return 1; fi
  return 0
}

validate_contract() {
  local v

  # No credential as a value — the rule that has no exceptions.
  if [ -n "${CF_API_KEY:-}" ]; then
    bad "contract:CF_API_KEY" "refused — CF_API_KEY is a VALUE and is not in the contract; pass CF_API_KEY_FILE=<path> (matrix §5, AGENTS.md r8)"
  fi
  for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL; do
    if [ -n "${!v:-}" ]; then
      bad "contract:ambient" "refused — $v is set in the ambient environment; the directive is the only source, so two lanes on one node cannot contaminate each other (matrix §5). unset $v and pass CF_API_KEY_FILE/CF_BASE_URL."
    fi
  done

  # CF_API_KEY_FILE: a path to a mode-600 file. Checked, never read.
  v="${CF_API_KEY_FILE:-}"
  if [ -n "$v" ]; then
    local m
    if is_secret_shaped "$v"; then
      bad "contract:CF_API_KEY_FILE" "refused — a credential VALUE was passed, not a path; the contract is path-only (length ${#v}, value not printed)"
    elif ! is_path_shaped "$v"; then
      bad "contract:CF_API_KEY_FILE" "refused — '$v' is not a path (expected /abs/path or ~/path); values are refused, paths are required"
    elif [ ! -f "$v" ]; then
      bad "contract:CF_API_KEY_FILE" "refused — no such key file: $v"
    elif [ ! -s "$v" ]; then
      bad "contract:CF_API_KEY_FILE" "refused — key file is empty: $v"
    else
      m=$(mode_of "$v")
      case "$m" in
        [0-7]00) ok "contract:CF_API_KEY_FILE" "$v (mode $m, content not read)" ;;
        *) bad "contract:CF_API_KEY_FILE" "refused — $v is mode $m; a key file must be 600 (chmod 600 $v)" ;;
      esac
    fi
  else
    note "contract:CF_API_KEY_FILE — unset (no credential path; --turn will skip)"
  fi

  # CF_BASE_URL: optional endpoint; never carry userinfo.
  v="${CF_BASE_URL:-}"
  if [ -n "$v" ]; then
    case "$v" in
      http://*|https://*) ;;
      *) bad "contract:CF_BASE_URL" "refused — '$v' is not an http(s) URL" ;;
    esac
    case "${v#*://}" in
      *@*) bad "contract:CF_BASE_URL" "refused — the URL carries userinfo; a credential in a URL is still a credential as a value" ;;
    esac
  fi

  # The run-scoped set. Required for --turn; validated whenever present.
  v="${CF_MODEL:-}"
  case "$v" in *' '*) bad "contract:CF_MODEL" "refused — a model id contains no spaces: '$v'" ;; esac
  v="${CF_PROVIDER:-}"
  if [ -n "$v" ]; then
    printf '%s' "$v" | grep -Eq '^[a-z0-9][a-z0-9._-]*$' \
      || bad "contract:CF_PROVIDER" "refused — '$v' is not a lane name (lowercase, [a-z0-9._-])"
  fi
  v="${CF_NAMESPACE:-}"
  if [ -n "$v" ]; then
    printf '%s' "$v" | grep -Eq '^[a-z0-9][a-z0-9._-]*$' \
      || bad "contract:CF_NAMESPACE" "refused — '$v' is not a namespace (lowercase, [a-z0-9._-])"
  fi
  v="${CF_LANE:-}"
  if [ -n "$v" ]; then
    printf '%s' "$v" | grep -Eq '^[a-z0-9][a-z0-9._-]*$' \
      || bad "contract:CF_LANE" "refused — '$v' is not a lane name (lowercase, [a-z0-9._-])"
  fi
  v="${CF_RUN_ID:-}"
  if [ -n "$v" ]; then
    printf '%s' "$v" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:-]*$' \
      || bad "contract:CF_RUN_ID" "refused — '$v' is not an id ([A-Za-z0-9._:-])"
  fi

  # CF_WORKDIR: required for --turn, and never outside $HOME.
  v="${CF_WORKDIR:-}"
  if [ -n "$v" ]; then
    local real work
    real=$(cd "$v" 2>/dev/null && pwd -P) || real=""
    if [ -z "$real" ]; then
      if [ "$MODE" = "--turn" ]; then
        bad "contract:CF_WORKDIR" "refused — no such directory: $v"
      else
        warn "contract:CF_WORKDIR" "$v does not exist yet (only --turn needs it)"
      fi
    else
      work=$(cd "$HOME" 2>/dev/null && pwd -P)
      case "$real" in
        "$work"/*) note "contract:CF_WORKDIR — $real (inside \$HOME)" ;;
        *) bad "contract:CF_WORKDIR" "refused — $real is outside \$HOME ($work); a harness writes only inside \$HOME" ;;
      esac
    fi
  fi

  # CF_HARNESS_OPTS: recorded; never a place to smuggle a key.
  v="${CF_HARNESS_OPTS:-}"
  if [ -n "$v" ]; then
    if printf '%s' "$v" | grep -Eqi 'sk-|api[_-]?key=|token=|secret=|password='; then
      bad "contract:CF_HARNESS_OPTS" "refused — the options bag looks like it carries a credential; options are recorded, so they are public"
    elif ! printf '%s' "$v" | grep -Eq '^[A-Za-z0-9_.-]+=[^,]+(,[A-Za-z0-9_.-]+=[^,]+)*$'; then
      bad "contract:CF_HARNESS_OPTS" "refused — not key=value[,key=value]: '$v'"
    fi
  fi

  # The budget. Defaults are the matrix's (40 turns / 1800 s).
  MAX_TURNS="${CF_MAX_TURNS:-40}"
  TIMEOUT_S="${CF_TIMEOUT_S:-1800}"
  case "$MAX_TURNS" in ''|*[!0-9]*) bad "contract:CF_MAX_TURNS" "refused — not an integer: '$MAX_TURNS'" ;; esac
  case "$TIMEOUT_S" in ''|*[!0-9]*) bad "contract:CF_TIMEOUT_S" "refused — not an integer: '$TIMEOUT_S'" ;; esac
  if [ "$MAX_TURNS" -ge 1 ] 2>/dev/null && [ "$MAX_TURNS" -le 1000 ] 2>/dev/null; then :; else
    bad "contract:CF_MAX_TURNS" "refused — out of range 1..1000: '$MAX_TURNS'"
  fi
  if [ "$TIMEOUT_S" -ge 1 ] 2>/dev/null && [ "$TIMEOUT_S" -le 86400 ] 2>/dev/null; then :; else
    bad "contract:CF_TIMEOUT_S" "refused — out of range 1..86400: '$TIMEOUT_S'"
  fi

  # Record the whole set. Every value here is a path, an id or an endpoint — never a secret.
  local k
  for k in CF_MODEL CF_PROVIDER CF_BASE_URL CF_WORKDIR CF_NAMESPACE CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS; do
    note "contract:$k = ${!k:-unset}"
  done
  note "contract:CF_MAX_TURNS = $MAX_TURNS   CF_TIMEOUT_S = $TIMEOUT_S"
}

require_turn_vars() {
  need_turn_var CF_MODEL "${CF_MODEL:-}"
  need_turn_var CF_PROVIDER "${CF_PROVIDER:-}"
  need_turn_var CF_WORKDIR "${CF_WORKDIR:-}"
  need_turn_var CF_NAMESPACE "${CF_NAMESPACE:-}"
  need_turn_var CF_RUN_ID "${CF_RUN_ID:-}"
  need_turn_var CF_LANE "${CF_LANE:-}"
  if [ -n "$MISSING_TURN_VARS" ]; then
    bad "contract:required" "refused — --turn needs the §5 run set; missing:$MISSING_TURN_VARS"
    return 1
  fi
  ok "contract:required" "the §5 run set is complete"
}

# ---------------------------------------------------------------- probes

probe_node() {
  local n np major
  n=$(have node); np=$(have npm)
  if [ -z "$n" ]; then
    bad "node" "absent — $CLAUDE_CODE_PKG needs node >= $NODE_MIN_MAJOR (its engines field)"
    return 1
  fi
  major=$(node_major "$n") || major=""
  if [ -n "$major" ] && [ "$major" -ge "$NODE_MIN_MAJOR" ] 2>/dev/null; then
    ok "node" "$n ($("$n" --version 2>/dev/null), pin requires >= $NODE_MIN_MAJOR)"
  else
    bad "node" "$n reports $("$n" --version 2>/dev/null) but the pin requires node >= $NODE_MIN_MAJOR"
  fi
  if [ -n "$np" ]; then
    ok "npm" "$np ($("$np" --version 2>/dev/null))"
  else
    bad "npm" "absent — the pin is an npm package"
  fi
  [ -n "$n" ] && [ -n "$np" ]
}

probe_prefix() {
  case "$HOME" in ''|/) bad "prefix" "refused — \$HOME is '$HOME'"; return 1 ;; esac
  case "$PREFIX" in
    "$HOME"/*) ok "prefix" "$PREFIX (user-space, under \$HOME)" ;;
    *) bad "prefix" "refused — $PREFIX is not under \$HOME"; return 1 ;;
  esac
}

probe_binary() {
  local v p
  if [ -x "$BIN" ]; then
    ok "binary" "$BIN (installed by this adapter)"
    v=$(bin_version "$BIN")
    if [ "$v" = "$CLAUDE_CODE_PIN" ]; then
      ok "version" "$v (pin $CLAUDE_CODE_PIN)"
    else
      bad "version" "${v:-unreadable} != pin $CLAUDE_CODE_PIN — run --apply"
    fi
    return 0
  fi
  p=$(have claude)
  case "$p" in
    '') bad "binary" "absent (no $BIN and no claude on PATH) — run --apply"; return 1 ;;
  esac
  # `have` ends in `|| true` (lib.sh), so it never signals absence by status: test the path.
  # HARNESS.md: a PATH-provided binary is labelled host-provided and FAILs the binary row,
  # even when its version matches — this adapter did not install it at the pin.
  bad "binary" "host-provided $p (not installed by this adapter — run --apply)"
  v=$(bin_version "$p")
  note "version — host-provided reports ${v:-unreadable}; pin is $CLAUDE_CODE_PIN"
  return 1
}

probe_auth() {
  local found=0
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    warn "auth" "ANTHROPIC_API_KEY is exported — refused as ambient contamination; use CF_API_KEY_FILE"
    found=1
  fi
  if [ -n "${CF_API_KEY_FILE:-}" ] && [ -f "${CF_API_KEY_FILE:-}" ]; then
    ok "auth" "CF_API_KEY_FILE=$CF_API_KEY_FILE (path only, content not read)"
    found=1
  fi
  if [ -s "$HOME/.claude/.credentials.json" ]; then
    ok "auth" "$HOME/.claude/.credentials.json present (OAuth login; --turn uses --bare and does not read it)"
    found=1
  fi
  [ "$found" -eq 1 ] && return 0
  # CF-006: a missing credential is a NOTE in --check, not a WARN. --check certifies the install
  # (this adapter's own contract: "Exit 0 only when the pin is installed here"), and a credential
  # is a RUN input, not an install condition — the missing one is already reported where it
  # decides something, as `CLAUDE-CODE: SKIP (no credential …)` exit 3 from --turn. Classifying it
  # as a WARN here made the check leg unable to pass on any host without an Anthropic credential,
  # even with the pin installed and version read back. An ambient exported key above stays a WARN:
  # that is contamination of the directive, which does block an unattended run.
  note "auth — no credential: ANTHROPIC_API_KEY unset, CF_API_KEY_FILE unset, $HOME/.claude/.credentials.json absent; --turn will SKIP and name it (a credential is a run input, not an install condition)"
  return 1
}

probe_ambient_settings() {
  local s="$HOME/.claude/settings.json"
  [ -f "$s" ] || return 0
  if grep -q 'ANTHROPIC_BASE_URL\|ANTHROPIC_API_BASE_URL\|apiKeyHelper' "$s" 2>/dev/null; then
    note "ambient settings — $s sets a base URL or an apiKeyHelper; --turn runs with '--setting-sources local' and '--bare' so a run does not inherit another lane's wiring"
  fi
}

# ---------------------------------------------------------------- apply

provenance_check() {
  local meta got_integrity got_shasum got_version
  if ! meta=$(npm view "$CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN" version dist.integrity dist.shasum --json 2>/dev/null); then
    bad "provenance" "refused — registry metadata for $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN is unreachable, so the pin cannot be confirmed"
    return 1
  fi
  # `npm view <pkg> version dist.integrity` answers with literal dotted keys ("dist.integrity"),
  # not a nested object — measured, and a nested-only parser silently read empty and refused a
  # correct pin. Accept both shapes.
  got_version=$(printf '%s' "$meta" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).version||""))}catch(e){}})')
  got_integrity=$(printf '%s' "$meta" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j["dist.integrity"]||(j.dist&&j.dist.integrity)||""))}catch(e){}})')
  got_shasum=$(printf '%s' "$meta" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j["dist.shasum"]||(j.dist&&j.dist.shasum)||""))}catch(e){}})')
  if [ "$got_version" != "$CLAUDE_CODE_PIN" ]; then
    bad "provenance" "refused — the registry serves version '$got_version' for the pin $CLAUDE_CODE_PIN"
    return 1
  fi
  if [ "$got_integrity" != "$CLAUDE_CODE_INTEGRITY" ]; then
    bad "provenance" "refused — dist.integrity for $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN is not the recorded one (recorded ${CLAUDE_CODE_INTEGRITY:0:24}…, registry ${got_integrity:0:24}…)"
    return 1
  fi
  if [ "$got_shasum" != "$CLAUDE_CODE_SHASUM" ]; then
    bad "provenance" "refused — dist.shasum mismatch (recorded $CLAUDE_CODE_SHASUM, registry $got_shasum)"
    return 1
  fi
  ok "provenance" "$CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN — registry integrity + shasum match the recorded pin; upstream $CLAUDE_CODE_HOMEPAGE"
}

installed_package_identity() {
  local pj="$PKG_DIR/package.json" name version
  if [ ! -f "$pj" ]; then bad "identity" "no $pj after install"; return 1; fi
  name=$(node -e 'try{process.stdout.write(String(require(process.argv[1]).name||""))}catch(e){}' "$pj")
  version=$(node -e 'try{process.stdout.write(String(require(process.argv[1]).version||""))}catch(e){}' "$pj")
  if [ "$name" = "$CLAUDE_CODE_PKG" ] && [ "$version" = "$CLAUDE_CODE_PIN" ]; then
    ok "identity" "$name@$version at $PKG_DIR"
  else
    bad "identity" "installed package is '$name@$version', expected $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN"
    return 1
  fi
}

do_apply() {
  local v log rc size
  if [ "$(id -u)" -eq 0 ]; then
    bad "root" "refused — this installer is user-space; run it as the owning user, never as root"
    return 1
  fi
  probe_prefix || return 1

  v=$(bin_version "$BIN" 2>/dev/null) || v=""
  if [ -x "$BIN" ] && [ "$v" = "$CLAUDE_CODE_PIN" ]; then
    note "already installed at pin $CLAUDE_CODE_PIN — nothing to do (idempotent)"
    installed_package_identity || true
    # CF-006: the idempotent path names the binary too, so a node manifest records where the
    # harness lives on a second --apply exactly as it does on the first.
    ok "binary" "$BIN"
    return 0
  fi
  [ -x "$BIN" ] && note "installed version ${v:-unreadable} != pin $CLAUDE_CODE_PIN — installing the pin"

  probe_node || return 1
  provenance_check || return 1

  if ! log=$(umask 077; mktemp "${TMPDIR:-/tmp}/claude-code-npm.XXXXXXXX.log"); then
    bad "install" "cannot create a private npm log in ${TMPDIR:-/tmp}"; return 1
  fi
  say "  ..    npm install -g --prefix $PREFIX $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN"
  # An explicit --prefix on every call: the global prefix is ambient (a ~/.npmrc was measured
  # pointing at /var/tmp on this host), and honoring it would install outside $HOME.
  npm install --global --prefix "$PREFIX" --no-fund --no-audit --loglevel=error \
    "$CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN" >"$log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "install" "npm exited $rc — log: $log"
    sed -n '1,12p' "$log" | sed 's/^/        /'
    return 1
  fi
  ok "install" "npm exited 0"
  installed_package_identity || return 1

  v=$(bin_version "$BIN") || v=""
  if [ "$v" = "$CLAUDE_CODE_PIN" ]; then
    ok "version_readback" "$("$BIN" --version 2>/dev/null | head -1) — matches pin $CLAUDE_CODE_PIN"
  else
    bad "version_readback" "${v:-unreadable} != pin $CLAUDE_CODE_PIN after install"
    return 1
  fi
  size=$(du -sh "$PREFIX" 2>/dev/null | cut -f1)
  ok "footprint" "$PREFIX — ${size:-unknown} under \$HOME"
  if "$BIN" --help >/dev/null 2>&1; then
    ok "binary" "$BIN runs"
  else
    bad "binary" "$BIN does not run"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------- turn

skip_reason() {
  local missing=""
  [ -z "${ANTHROPIC_API_KEY:-}" ] && missing="$missing ANTHROPIC_API_KEY"
  [ -z "${CF_API_KEY_FILE:-}" ] && missing="$missing CF_API_KEY_FILE"
  [ -s "$HOME/.claude/.credentials.json" ] || missing="$missing ~/.claude/.credentials.json"
  printf '%s' "${missing# }"
}

do_turn() {
  local keyfile prompt_file="" out err rc served binding host started
  if [ "$(id -u)" -eq 0 ]; then
    bad "root" "refused — a turn runs as the owning user, never as root"; return 1
  fi
  if [ ! -x "$BIN" ] || [ "$(bin_version "$BIN" 2>/dev/null || echo '')" != "$CLAUDE_CODE_PIN" ]; then
    bad "turn" "refused — the pin is not installed at $BIN; run --apply first"; return 1
  fi

  # The credential is a path, and only a path. An exported key is never trusted as a value.
  if [ -n "${CF_API_KEY_FILE:-}" ] && [ -s "${CF_API_KEY_FILE:-}" ]; then
    keyfile="$CF_API_KEY_FILE"
  else
    say "  SKIP  turn — no credential to run with. Missing: $(skip_reason)"
    say "        (a lane passes CF_API_KEY_FILE=<mode-600 path> from the directive)"
    SKIPPED=1; return 0
  fi
  require_turn_vars || return 1

  if [ -n "$PROMPT_FILE" ]; then
    if [ ! -r "$PROMPT_FILE" ]; then bad "turn" "cannot read --prompt-file $PROMPT_FILE"; return 1; fi
    prompt_file="$PROMPT_FILE"
  elif [ -z "$PROMPT" ]; then
    if [ -t 0 ]; then bad "turn" "no directive: pass --prompt, --prompt-file, or stdin"; return 1; fi
    if ! prompt_file=$(umask 077; mktemp "${TMPDIR:-/tmp}/claude-code-prompt.XXXXXXXX"); then
      bad "turn" "cannot stage stdin"; return 1
    fi
    cat > "$prompt_file" || { bad "turn" "cannot read stdin"; return 1; }
  fi

  # A shim is a fact, not a guess: record it. Anthropic + no base URL = native.
  binding="native"
  if [ -n "${CF_BASE_URL:-}" ]; then
    host="${CF_BASE_URL#*://}"; host="${host%%/*}"
    if [ "${CF_PROVIDER:-}" = "anthropic" ]; then
      binding="anthropic-custom-endpoint/$host"
    else
      binding="shim/$host"
    fi
  fi

  if ! out=$(umask 077; mktemp "${TMPDIR:-/tmp}/claude-code-out.XXXXXXXX"); then
    bad "turn" "cannot stage output"; return 1
  fi
  if ! err=$(umask 077; mktemp "${TMPDIR:-/tmp}/claude-code-err.XXXXXXXX"); then
    bad "turn" "cannot stage stderr"; return 1
  fi

  # --bare: skip hooks/plugins/auto-discovery, never read the keychain.
  # --setting-sources local: do not inherit the user's ~/.claude/settings.json (measured: this
  # host's settings.json points ANTHROPIC_API_BASE_URL at a dead local router).
  local cli=(--print --output-format json --bare --setting-sources local
             --permission-mode acceptEdits --model "${CF_MODEL:-}")
  # The pin does not implement --max-turns; do not invent a flag it will reject.
  if "$BIN" --help 2>/dev/null | grep -q -- '--max-turns'; then
    cli+=(--max-turns "$MAX_TURNS")
    note "budget — --max-turns $MAX_TURNS (advertised by this pin)"
  else
    note "budget — CF_MAX_TURNS=$MAX_TURNS recorded but not enforced: pin $CLAUDE_CODE_PIN advertises no --max-turns; CF_TIMEOUT_S=$TIMEOUT_S is the enforced budget"
  fi

  started=$(date -u +%FT%TZ)
  say "  ..    turn: $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN in $CF_WORKDIR (model ${CF_MODEL}, timeout ${TIMEOUT_S}s)"
  (
    cd "${CF_WORKDIR}" || exit 1
    # Scrub anything ambient that could redirect the run, then inject from the key file only.
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN \
          ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL 2>/dev/null
    # Exported, never argv: the value lives in this subshell's environment, not on a command line.
    ANTHROPIC_API_KEY="$(cat "$keyfile")"; export ANTHROPIC_API_KEY
    if [ -n "${CF_BASE_URL:-}" ]; then ANTHROPIC_BASE_URL="$CF_BASE_URL"; export ANTHROPIC_BASE_URL; fi
    if [ -n "$prompt_file" ]; then
      timeout "$TIMEOUT_S" "$BIN" "${cli[@]}" < "$prompt_file" > "$out" 2> "$err"
    else
      timeout "$TIMEOUT_S" "$BIN" "${cli[@]}" "$PROMPT" > "$out" 2> "$err"
    fi
  )
  rc=$?

  if [ "$rc" -ne 0 ]; then
    # The CLI reports API-level failures as JSON on stdout with a non-zero exit (measured:
    # "Invalid API key · Fix external API key", terminal_reason=api_error). stderr is often
    # empty, so quoting only stderr made every failure look like "exit 1 — ".
    local detail
    detail=$(node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);
  process.stdout.write([j.terminal_reason,j.api_error_status,j.result,j.subtype]
    .filter(v=>v!==undefined&&v!==null&&v!=="").join(" · "))}catch(e){}})' < "$out" 2>/dev/null)
    [ -n "$detail" ] || detail=$(tail -3 "$err" 2>/dev/null | tr '\n' ' ')
    if [ "$rc" -eq 124 ]; then
      bad "turn" "timed out after ${TIMEOUT_S}s — ${detail:-no output}"
    else
      bad "turn" "exit $rc — $(printf '%s' "$detail" | cut -c1-300)"
    fi
    return 1
  fi
  ok "turn" "exit 0 (started ${started}Z)"

  # model_served: requested vs served is the reportable fact (HARNESS.md).
  served=$(node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  try{const j=JSON.parse(s);
    const mu=j.modelUsage&&Object.keys(j.modelUsage);
    process.stdout.write(String(j.model||(mu&&mu[0])||"unknown"));
  }catch(e){process.stdout.write("unparsed")}})' < "$out" 2>/dev/null)
  if [ -z "$served" ] || [ "$served" = "unparsed" ]; then
    bad "report" "could not read model_served from the JSON result (first 200 bytes: $(head -c 200 "$out" | tr '\n' ' '))"
    return 1
  fi
  ok "model_served" "$served (requested ${CF_MODEL})"
  say "record harness=claude-code harness_version=$CLAUDE_CODE_PIN model_requested=$CF_MODEL model_served=$served provider_binding=$binding run_id=$CF_RUN_ID lane=$CF_LANE namespace=$CF_NAMESPACE workdir=$CF_WORKDIR"
  say "record memory=not-written (leg 'memory' belongs to the foreman; this adapter echoes the fields it must hand over)"
  return 0
}

# ---------------------------------------------------------------- main

SKIPPED=0
say "harness: claude-code (pin $CLAUDE_CODE_PIN, package $CLAUDE_CODE_PKG, prefix $PREFIX)"

validate_contract
if [ "$FAILED" -gt 0 ]; then
  say ""
  say "CLAUDE-CODE: FAIL ($FAILED) — contract refused; nothing was installed or run"
  exit 1
fi

case "$MODE" in
  --check)
    probe_node || true
    probe_binary || true
    probe_auth || true
    probe_ambient_settings
    ;;
  --apply)
    # Do not count a FAIL for a state this run is about to change (install-hermes.sh does the
    # same): the pre-existing absence is reported by --check, and the summary here is about the
    # end state.
    probe_auth || true
    do_apply || true
    say "  ..    after apply:"
    probe_node || true
    probe_binary || true
    ;;
  --turn)
    probe_binary || true
    probe_auth || true
    probe_ambient_settings
    do_turn || true
    ;;
esac

say ""
if [ "$SKIPPED" -eq 1 ]; then
  say "CLAUDE-CODE: SKIP (no credential — nothing measured, nothing claimed)"
  exit 3
fi
if [ "$MODE" = "--check" ]; then verdict CLAUDE-CODE; else verdict CLAUDE-CODE action; fi
exit $?

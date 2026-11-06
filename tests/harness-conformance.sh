#!/usr/bin/env bash
# harness-conformance.sh — one battery, one matrix.
#
# For every harness the factory names, prove or refute four legs:
#
#   check  the adapter's own --check, quoted with the value it measured
#   apply  the adapter's --apply in a throwaway HOME (only with --install)
#   vars   the §5 variable contract: --help documents the declared set, the full set is accepted,
#          a credential VALUE and an ambient provider key are each refused by name, and no
#          declared variable is accepted and then silently dropped (row CF-229)
#   smoke  a REAL turn in a scratch directory that must leave a file containing a
#          token this script chose, verified by bytes on the control host. The binary
#          is the one the adapter's own --check measured (its "PASS binary" row),
#          so an installer that puts the binary under a $HOME prefix that is not
#          on PATH is still smokeable; PATH is the fallback, not the oracle.
#
# A leg prints `  PASS  <harness>:<leg> — <measured value>`, `  FAIL  … — <measured
# value>` or `  SKIP  <harness>:<leg> — <the exact credential or binary that is
# missing>`. Nothing here can pass on an empty value: every row goes through
# emit(), which rewrites an empty PASS into a FAIL and an empty SKIP into a FAIL.
#
#   tests/harness-conformance.sh                     # check + vars + smoke, no installs
#   tests/harness-conformance.sh --install           # also run each --apply in a scratch HOME
#   tests/harness-conformance.sh --vars-only         # only the §5 variable-contract leg
#   tests/harness-conformance.sh --write-doc         # regenerate docs/HARNESS-CONFORMANCE.md
#   tests/harness-conformance.sh --only hermes,codex # subset by id
#   tests/harness-conformance.sh --adapter-dir DIR   # fixture hook (tests/selftest.sh §45)
#
# The battery never installs anything without --install, never writes outside $HOME,
# never reads a credential value (existence and validity only), and never invents a
# turn for a harness whose non-interactive surface this repo has not measured.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"

MODE_INSTALL=0
WRITE_DOC=0
VARS_ONLY=0
ONLY=""
ADAPTER_DIR="$HERE/scripts/harness"
DOC="$HERE/docs/HARNESS-CONFORMANCE.md"
TIMEOUT="${HC_TIMEOUT:-300}"
APPLY_TIMEOUT="${HC_APPLY_TIMEOUT:-600}"
SKIPPED=0
ARGS="$*"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install) MODE_INSTALL=1; shift ;;
    --write-doc) WRITE_DOC=1; shift ;;
    --vars-only) VARS_ONLY=1; shift ;;
    --only) ONLY="${2:-}"; [ -n "$ONLY" ] || { printf 'FAIL battery: --only needs an id\n'; exit 2; }; shift 2 ;;
    --adapter-dir) ADAPTER_DIR="${2:-}"; [ -n "$ADAPTER_DIR" ] || { printf 'FAIL battery: --adapter-dir needs a path\n'; exit 2; }; shift 2 ;;
    --doc) DOC="${2:-}"; [ -n "$DOC" ] || { printf 'FAIL battery: --doc needs a path\n'; exit 2; }; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'FAIL battery: unknown argument %s\n' "$1"; exit 2 ;;
  esac
done

# Work root must sit under the real $HOME: the smoke turns write their artifact
# there, and the apply legs install there. Nothing lands in a system temp dir.
WORK="${HC_WORK_ROOT:-$HOME/.harness-conformance}/run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$WORK" || { printf 'FAIL battery: cannot create %s\n' "$WORK"; exit 2; }
RESULTS="$WORK/results.tsv"
: > "$RESULTS"
trap 'kill_gateways 2>/dev/null || true' EXIT

clean() { printf '%s' "$1" | tr '\t\n' '  ' | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'; }

# Join stdin lines with "; ". `paste -sd'; '` cycles its delimiter list one character at a
# time (`;`, ` `, `;` …), which silently drops the space on every other join.
joinrows() { awk 'BEGIN{sep=""} {printf "%s%s", sep, $0; sep="; "} END{if (NR) print ""}'; }

# The single choke point for every row this battery prints.
emit() {  # emit <harness> <leg> <verdict> <value>
  local id="$1" leg="$2" verdict="$3" value
  value="$(clean "${4:-}")"
  if [ -z "$value" ]; then
    case "$verdict" in
      PASS) verdict=FAIL; value="guard: a PASS carried no measured value" ;;
      SKIP) verdict=FAIL; value="guard: a SKIP did not name what is missing" ;;
      *)    verdict=FAIL; value="guard: row carried no measured value" ;;
    esac
  fi
  case "$verdict" in
    PASS) ok "$id:$leg" "$value" ;;
    FAIL) bad "$id:$leg" "$value" ;;
    SKIP) printf '  SKIP  %s:%s — %s\n' "$id" "$leg" "$value"; SKIPPED=$((SKIPPED+1)) ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$id" "$leg" "$verdict" "$value" >> "$RESULTS"
}

note_row() { printf '  ..    %s\n' "$*"; printf 'note\t-\tNOTE\t%s\n' "$(clean "$*")" >> "$RESULTS"; }

# ---------------------------------------------------------------- harness table
# id | adapter file | binary | generation | non-interactive smoke | smoke measured here
HARNESSES="hermes|install-hermes.sh|hermes|0|hermes -z \"<prompt>\"|1
claude-code|install-claude-code.sh|claude|0|claude -p \"<prompt>\"|1
codex|install-codex.sh|codex|0|codex exec --skip-git-repo-check -s workspace-write \"<prompt>\"|1
opencode|install-opencode.sh|opencode|1|opencode run \"<prompt>\"|1
opencode-v2|install-opencode.sh|opencode|2|opencode run \"<prompt>\"|0
deepseek|install-deepseek.sh|deepseek|0|(none documented)|0
pi-agent|install-pi-agent.sh|pi|0|pi -p --no-session \"<prompt>\"|1"

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

ver_of() {  # first dotted version in the first line of --version
  local raw
  raw="$("$1" --version 2>&1 | head -1)" || return 1
  printf '%s\n' "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^[:space:]]*' | head -1
}

adapter_row() {  # adapter_row <output> <PASS|FAIL> <preferred name>  -> "<name> <value>"
  local out="$1" want="$2" pref="$3" line
  line="$(printf '%s\n' "$out" | grep -F "  $want  $pref" | head -1)"
  [ -n "$line" ] || line="$(printf '%s\n' "$out" | awk -v w="  $want  " 'index($0,w)==1' | head -1)"
  printf '%s' "${line#"  $want  "}"
}

empty_adapter_rows() {  # PASS rows whose measured value is empty or missing the separator
  local out="$1"
  printf '%s\n' "$out" | awk '
    index($0, "  PASS  ") == 1 {
      rest = substr($0, 9)
      i = index(rest, " — ")
      if (i == 0) { print rest " (no value)"; next }
      value = substr(rest, i + 4)
      gsub(/^ +| +$/, "", value)
      if (value == "") print substr(rest, 1, i - 1) " (empty)"
    }'
}

# ------------------------------------------------------------- credential probes
# Each returns 0 and prints the credential it found, or 1 and prints what is missing.
cred_hermes() {
  if [ -f "$HOME/.hermes/.env" ] && grep -qE '^[A-Z_]+_API_KEY=' "$HOME/.hermes/.env" 2>/dev/null; then
    printf 'a provider key in ~/.hermes/.env (value not read)'
  else
    printf 'a provider key in ~/.hermes/.env'
    return 1
  fi
}
cred_claude() {
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then printf 'ANTHROPIC_API_KEY is set'
  elif [ -f "$HOME/.claude/.credentials.json" ]; then printf '~/.claude/.credentials.json'
  else printf 'ANTHROPIC_API_KEY or ~/.claude/.credentials.json'; return 1; fi
}
cred_codex() {
  if [ -s "$HOME/.codex/auth.json" ] && jq -e . "$HOME/.codex/auth.json" >/dev/null 2>&1; then
    printf '~/.codex/auth.json (%s)' "$(jq -r 'keys|join(",")' "$HOME/.codex/auth.json" 2>/dev/null)"
  else
    printf '~/.codex/auth.json (OAuth tokens or OPENAI_API_KEY)'; return 1
  fi
}
cred_opencode() {
  local f="$HOME/.local/share/opencode/auth.json"
  if [ -s "$f" ] && jq -e 'length > 0' "$f" >/dev/null 2>&1; then
    printf '~/.local/share/opencode/auth.json (%s)' "$(jq -r 'keys|join(",")' "$f" 2>/dev/null)"
  else
    printf '~/.local/share/opencode/auth.json with at least one provider'; return 1
  fi
}
cred_deepseek() {
  if [ -n "${DEEPSEEK_API_KEY:-}" ]; then printf 'DEEPSEEK_API_KEY is set'
  else printf 'DEEPSEEK_API_KEY'; return 1; fi
}
cred_pi() {
  local f="$HOME/.pi/agent/auth.json" providers p out valid=""
  if [ ! -s "$f" ]; then printf '~/.pi/agent/auth.json'; return 1; fi
  providers="$(jq -r 'keys[]' "$f" 2>/dev/null | paste -sd, -)"
  [ -n "$providers" ] || { printf 'providers in ~/.pi/agent/auth.json'; return 1; }
  for p in $(printf '%s' "$providers" | tr ',' ' '); do
    out="$(pi auth check --provider "$p" --no-refresh 2>&1 | head -1)"
    [ "$out" = valid ] && valid="$valid $p"
  done
  if [ -n "$valid" ]; then printf 'pi auth check valid for:%s' "$valid"
  else printf 'a provider pi auth check accepts (~/.pi/agent/auth.json names %s, all report `invalid`)' "$providers"; return 1; fi
}

# ------------------------------------------------------------------- smoke turns
smoke_turn() {  # smoke_turn <id> <dir> <prompt>
  local id="$1" dir="$2" prompt="$3"
  case "$id" in
    # stdin is closed for every turn: `codex exec` and `opencode run` treat a piped stdin as
    # the message, and this script's own stdin carries the harness table.
    hermes)     ( cd "$dir" && timeout "$TIMEOUT" hermes -z "$prompt" </dev/null ) ;;
    claude-code)( cd "$dir" && timeout "$TIMEOUT" claude -p "$prompt" </dev/null ) ;;
    codex)      ( cd "$dir" && timeout "$TIMEOUT" codex exec --skip-git-repo-check -s workspace-write "$prompt" </dev/null ) ;;
    opencode|opencode-v2) ( cd "$dir" && timeout "$TIMEOUT" opencode run "$prompt" </dev/null ) ;;
    pi-agent)   ( cd "$dir" && timeout "$TIMEOUT" pi -p --no-session "$prompt" </dev/null ) ;;
    *)          return 127 ;;
  esac
}

kill_gateways() {
  # The adapter starts the gateway as `<venv>/bin/python <venv>/bin/hermes serve`, so an
  # anchored pattern on the hermes path never matches the argv[0]. Match the run's apply
  # directory instead: no shell of ours carries that path in its own command line.
  local pid
  for pid in $(pgrep -f "$WORK/apply/" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null || true
  done
}

# ------------------------------------------------------- the §5 variable contract (vars, CF-229)
# The declared set is the spec's: it is parsed out of specs/HARNESS-MATRIX.md §5 rather than copied
# here, so a spec edit reaches the leg without an edit to this file. CONTRACT_VARS is the set this
# battery actually SENDS; when the two disagree the leg goes red and names the variable — which is
# what makes "drop one declared variable and the leg must fail" a provable claim.
CONTRACT_VARS=(CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE
               CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S)
SPEC="$HERE/specs/HARNESS-MATRIX.md"
VARS_DIR="$WORK/vars"
VARS_KEY="$VARS_DIR/api.key"
VARS_WORKDIR="$VARS_DIR/workdir"
VARS_SKILLS="$VARS_DIR/skills"
# A synthetic credential and synthetic ambient keys, built from parts so no line in this file looks
# like a literal key to the tree-hygiene grep (AGENTS.md r8). Neither value is ever a real secret.
SYNTH_SECRET="sk-$(printf 'cf229-%s' 'not-a-real-credential')"
HC_ENV=()      # extra environment for one hc_run (never the directive's set)
RUN_ENV=()     # the §5 set under test, as NAME=value assignments

spec_declared() {  # the §5 table's variable names, in the spec's own order
  [ -f "$SPEC" ] || return 1
  awk '/^## 5\./{f=1;next} /^## 6\./{f=0} f' "$SPEC" | grep -oE '`CF_[A-Z_]+`' | tr -d '`' \
    | awk '!seen[$0]++'
}

declared_drift() {  # every disagreement between the spec's set and the set this battery sends
  local v
  for v in "${CONTRACT_VARS[@]}"; do
    spec_declared | grep -qx -- "$v" \
      || printf 'this battery checks %s, which §5 does not declare; ' "$v"
  done
  while read -r v; do
    printf '%s\n' "${CONTRACT_VARS[@]}" | grep -qx -- "$v" \
      || printf '§5 declares %s and this battery drops it; ' "$v"
  done < <(spec_declared)
}

vars_value() {  # the synthetic value this battery sends for one declared variable
  case "$1" in
    CF_MODEL) printf 'fixture-model-1' ;;
    CF_PROVIDER) printf 'fixture' ;;
    CF_BASE_URL) printf 'http://127.0.0.1:9/v1' ;;
    CF_API_KEY_FILE) printf '%s' "$VARS_KEY" ;;
    CF_WORKDIR) printf '%s' "$VARS_WORKDIR" ;;
    CF_NAMESPACE) printf 'code-factory-qa' ;;
    CF_RUN_ID) printf 'cf229-vars-run' ;;
    CF_LANE) printf 'code-factory-qa' ;;
    CF_SKILLS_DIR) printf '%s' "$VARS_SKILLS" ;;
    CF_HARNESS_OPTS) printf 'sandbox=workspace-write,approval=never' ;;
    CF_MAX_TURNS) printf '40' ;;
    CF_TIMEOUT_S) printf '1800' ;;
    *) printf 'unset' ;;
  esac
}

vars_args() {  # the full declared set, as NAME=value assignments, in CONTRACT_VARS order
  local v
  for v in "${CONTRACT_VARS[@]}"; do printf '%s=%s\n' "$v" "$(vars_value "$v")"; done
}

vars_fixture() {  # the workdir + key file the acceptance run needs, both inside $HOME
  [ -d "$VARS_WORKDIR" ] && [ -s "$VARS_KEY" ] && return 0
  mkdir -p "$VARS_WORKDIR" "$VARS_SKILLS" || return 1
  git -C "$VARS_WORKDIR" init -q -b main >/dev/null 2>&1 || return 1
  (umask 077; printf '%s\n' "$(printf 'synthetic-%s' 'not-a-credential')" > "$VARS_KEY") || return 1
  chmod 600 "$VARS_KEY" || return 1
}

hc_run() {  # hc_run <adapter> [args...] — a scrubbed env: this battery's set is the only source
  local adapter="$1"; shift
  env -i PATH="$PATH" HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" LANG=C \
    "${RUN_ENV[@]}" "${HC_ENV[@]}" bash "$adapter" "$@"
}

leg_vars() {  # <id> <adapter file>
  local id="$1" file="$2" path help out rc mode problems="" missing="" silent="" v
  local base_env=() swap=()
  path="$ADAPTER_DIR/$file"
  if [ ! -f "$path" ]; then
    emit "$id" vars FAIL "no adapter at scripts/harness/$file — no installer to hold to the §5 contract"
    return 0
  fi
  if ! bash -n "$path" 2>/dev/null; then
    emit "$id" vars FAIL "scripts/harness/$file is not valid bash"
    return 0
  fi
  if ! vars_fixture; then
    emit "$id" vars FAIL "cannot stage the fixture workdir/key under $VARS_DIR (both must be inside \$HOME)"
    return 0
  fi
  mapfile -t base_env < <(vars_args)
  RUN_ENV=()

  # (a) --help documents every variable the SPEC declares.
  help="$(hc_run "$path" --help 2>&1)"; rc=$?
  printf '%s\n' "$help" > "$WORK/$id.vars-help.txt"
  if [ "$rc" -ne 0 ]; then
    emit "$id" vars FAIL "--help exited $rc — the installer cannot document its own contract"
    return 0
  fi
  while read -r v; do
    case "$help" in *"$v"*) ;; *) missing="$missing $v" ;; esac
  done < <(spec_declared)
  [ -z "$missing" ] || problems="$problems --help does not document:$missing;"

  # (b) the full declared set is accepted. --contract is the acceptance mode where an installer
  # offers one; otherwise the leg requires that --check does not refuse the contract, because a
  # harness that is simply not installed on this host must still accept the inputs it was given.
  case "$help" in *--contract*) mode="--contract" ;; *) mode="--check" ;; esac
  RUN_ENV=("${base_env[@]}")
  out="$(hc_run "$path" "$mode" 2>&1)"; rc=$?
  printf '%s\n' "$out" > "$WORK/$id.vars.txt"
  if [ "$mode" = "--contract" ]; then
    [ "$rc" -eq 0 ] || problems="$problems $mode exited $rc on the full set (want 0);"
  else
    [ "$rc" -ne 2 ] || problems="$problems $mode refused the full set (exit $rc);"
    if printf '%s\n' "$out" | grep -q '^  FAIL  contract:'; then
      problems="$problems $mode refused a contract row: $(printf '%s\n' "$out" | awk 'index($0,"  FAIL  contract:")==1' | head -1 | sed 's/^  FAIL  //;s/ — .*//');"
    fi
  fi

  # (c) nothing is accepted and then silently dropped: every declared name is recorded by the run.
  while read -r v; do
    printf '%s\n' "$out" | grep -q -- "$v" || silent="$silent $v"
  done < <(spec_declared)
  [ -z "$silent" ] || problems="$problems accepted but never recorded:$silent;"

  # (d) the two negative cases the spec's `vars` leg names: a credential VALUE, and an ambient key.
  for v in "${base_env[@]}"; do
    case "$v" in CF_API_KEY_FILE=*) swap+=("CF_API_KEY_FILE=$SYNTH_SECRET") ;; *) swap+=("$v") ;; esac
  done
  printf '%s\n' "${swap[@]}" | grep -q '^CF_API_KEY_FILE=' || swap+=("CF_API_KEY_FILE=$SYNTH_SECRET")
  RUN_ENV=("${swap[@]}")
  out="$(hc_run "$path" "$mode" 2>&1)"; rc=$?
  printf '%s\n' "$out" > "$WORK/$id.vars-value.txt"
  if [ "$rc" -eq 0 ]; then
    problems="$problems a credential VALUE was accepted (exit 0);"
  elif ! printf '%s\n' "$out" | grep -qE 'CF_API_KEY_FILE|credential'; then
    problems="$problems a credential VALUE was refused without naming it;"
  fi
  if printf '%s\n' "$out" | grep -qF -- "$SYNTH_SECRET"; then
    problems="$problems the refused credential value was echoed into the log;"
  fi

  RUN_ENV=("${base_env[@]}")
  HC_ENV=("OPENAI_API_KEY=$SYNTH_SECRET" "ANTHROPIC_API_KEY=$SYNTH_SECRET")
  out="$(hc_run "$path" "$mode" 2>&1)"; rc=$?
  HC_ENV=()
  RUN_ENV=()
  printf '%s\n' "$out" > "$WORK/$id.vars-ambient.txt"
  if [ "$rc" -eq 0 ]; then
    problems="$problems an ambient provider key was accepted (exit 0);"
  elif ! printf '%s\n' "$out" | grep -qE 'OPENAI_API_KEY|ANTHROPIC_API_KEY|contract:ambient'; then
    problems="$problems an ambient provider key was refused without naming it;"
  fi
  if printf '%s\n' "$out" | grep -qF -- "$SYNTH_SECRET"; then
    problems="$problems the ambient key value was echoed into the log;"
  fi

  if [ -n "$problems" ]; then
    emit "$id" vars FAIL "$(printf '%s' "$problems" | sed 's/^ //;s/;$//')"
  else
    emit "$id" vars PASS "§5 set accepted in $mode (${#CONTRACT_VARS[@]} declared); a credential VALUE and an ambient key are both refused by name; every name is recorded"
  fi
  return 0
}

# ----------------------------------------------------------------------- legs
leg_check() {  # <id> <adapter file> <binary> <generation>
  local id="$1" file="$2" bin="$3" gen="$4" path out rc value bad_rows empty
  path="$ADAPTER_DIR/$file"
  if [ ! -f "$path" ]; then
    emit "$id" check FAIL "no adapter at scripts/harness/$file — the harness is named and cannot be certified"
    return 0
  fi
  if ! bash -n "$path" 2>/dev/null; then
    emit "$id" check FAIL "scripts/harness/$file is not valid bash"
    return 0
  fi
  out="$(bash "$path" --check 2>&1)"; rc=$?
  printf '%s\n' "$out" > "$WORK/$id.check.txt"

  # A PASS with no measured value is a lie regardless of the adapter's exit code.
  empty="$(empty_adapter_rows "$out" | joinrows)"
  if [ -n "$empty" ]; then
    emit "$id" check FAIL "adapter printed PASS with no measured value: $empty"
    return 0
  fi

  if [ "$rc" -eq 0 ]; then
    value="$(adapter_row "$out" PASS version)"
    [ -n "$value" ] || value="$(adapter_row "$out" PASS binary)"
    [ -n "$value" ] || value="$(adapter_row "$out" PASS harness)"
    [ -n "$value" ] || { emit "$id" check FAIL "adapter exited 0 but printed no PASS row to quote"; return 0; }
    # Generation gate: an adapter that cannot tell v1 from v2 must not certify v2.
    if [ "$gen" != "0" ] && [ -n "$(have "$bin")" ]; then
      local ver major
      ver="$(ver_of "$bin")"
      major="${ver%%.*}"
      if [ "${major:-}" != "$gen" ]; then
        emit "$id" check FAIL "adapter passes on $bin $ver but this harness is the v$gen generation — the adapter has no generation gate"
        return 0
      fi
    fi
    emit "$id" check PASS "adapter exit 0 — $value"
  else
    bad_rows="$(printf '%s\n' "$out" | awk 'index($0,"  FAIL  ")==1' | sed 's/^  FAIL  //' | joinrows)"
    emit "$id" check FAIL "adapter exit $rc — ${bad_rows:-no FAIL row printed}"
  fi
  # Report, do not repair: an adapter row that warns while the capability exists.
  if [ "$id" = opencode ] && printf '%s\n' "$out" | grep -q 'WARN  non_interactive'; then
    if ( cd "$WORK" && timeout 30 opencode run --help >/dev/null 2>&1 </dev/null ); then
      note_row "$id: the adapter warned non_interactive could not be confirmed while \`opencode run --help\` exits 0 — its probe greps stdout and opencode writes help to stderr"
    fi
  fi
  # A refusal of the interpreter is worth naming with the knob that moves past it,
  # because the adapter stops before it measures anything else.
  if [ "$id" = hermes ] && printf '%s\n' "$out" | grep -qE '^  FAIL  python — ' \
     && command -v python3.12 >/dev/null 2>&1; then
    note_row "$id: the adapter refused \`python3\` ($(python3 --version 2>&1 | head -1)); python3.12 is on PATH, so HERMES_PYTHON_BIN=python3.12 reaches the binary/version/port rows"
  fi
  return 0
}

leg_smoke() {  # <id> <binary> <generation> <measured>
  local id="$1" bin="$2" gen="$3" measured="$4" dir cred rc token out sum want prompt attempt
  local path="" stated="" source="" rundir=""
  # Resolve the binary from the adapter's own measurement first (CF-225). leg_check already ran
  # --check and stored its "PASS binary" row in $WORK/$id.check.txt; an adapter whose installer
  # writes under a $HOME prefix (claude-code: ~/.local/harness/npm/bin) has measured a real,
  # owned binary that PATH knows nothing about, and a smoke leg that re-resolves with
  # `command -v` alone refuses to test the harness our own installer installed. PATH is read
  # only when the adapter names no path, or names one that is not executable -- and the row
  # always quotes the path it used, so a resolution that is never invoked cannot look green.
  if [ -f "$WORK/$id.check.txt" ]; then
    stated="$(adapter_row "$(cat "$WORK/$id.check.txt")" PASS binary \
      | tr ' \t' '\n\n' | grep -m1 '^/' || true)"
  fi
  if [ -n "$stated" ] && [ -x "$stated" ]; then
    path="$stated"; source="the path its --check measured"
  else
    path="$(command -v "$bin" 2>/dev/null || true)"
    if [ -n "$path" ] && [ -n "$stated" ]; then
      source="PATH fallback: the adapter named $stated, which is not executable"
    elif [ -n "$path" ]; then
      source="PATH fallback: the adapter named no binary path"
    fi
  fi
  if [ -z "$path" ]; then
    if [ -n "$stated" ]; then
      emit "$id" smoke SKIP "binary \`$bin\` absent: the adapter's --check named $stated, which is not executable, and no \`$bin\` is on PATH"
    else
      emit "$id" smoke SKIP "binary \`$bin\` absent: the adapter's --check names no binary path and no \`$bin\` is on PATH"
    fi
    return 0
  fi
  if [ "$gen" != "0" ]; then
    local ver major
    ver="$(ver_of "$path")"; major="${ver%%.*}"
    if [ "${major:-}" != "$gen" ]; then
      emit "$id" smoke SKIP "no $bin $gen.x binary at $path (measured $ver is v${major:-unknown}); a v1 binary cannot smoke a v2 harness"
      return 0
    fi
  fi
  if [ "$measured" != "1" ]; then
    emit "$id" smoke SKIP "$bin is present at $path but this repo has measured no non-interactive surface for it (specs/HARNESS.md): refusing to invent a turn"
    return 0
  fi
  cred=""; cred_rc=0
  case "$id" in
    hermes) cred="$(cred_hermes)" || cred_rc=$? ;;
    claude-code) cred="$(cred_claude)" || cred_rc=$? ;;
    codex) cred="$(cred_codex)" || cred_rc=$? ;;
    opencode|opencode-v2) cred="$(cred_opencode)" || cred_rc=$? ;;
    deepseek) cred="$(cred_deepseek)" || cred_rc=$? ;;
    pi-agent) cred="$(cred_pi)" || cred_rc=$? ;;
  esac
  if [ "$cred_rc" -ne 0 ]; then
    emit "$id" smoke SKIP "$cred"
    return 0
  fi

  dir="$WORK/smoke/$id"
  rm -rf "$dir"; mkdir -p "$dir"
  token="CF-CONF-${id//[^a-zA-Z0-9]/}-$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  prompt="Create a file named smoke.txt in the current working directory whose entire contents are exactly: $token. Do not do anything else."
  # smoke_turn invokes a bare name (`claude -p ...`), so the resolved path is put in front of
  # PATH for that subshell -- and the identity of the bare name is asserted first, because a
  # path that is resolved and printed but never invoked is decoration.
  rundir="$(dirname "$path")"
  if [ "$(PATH="$rundir:$PATH" command -v "$bin" 2>/dev/null || true)" != "$path" ]; then
    emit "$id" smoke FAIL "resolved $path but a bare \`$bin\` with $rundir first on PATH answers '$(PATH="$rundir:$PATH" command -v "$bin" 2>/dev/null || printf 'nothing')' -- the turn would run a different binary"
    return 0
  fi
  attempt=1
  while : ; do
    out="$( export PATH="$rundir:$PATH"; smoke_turn "$id" "$dir" "$prompt" 2>&1 )"; rc=$?
    printf '%s\n' "$out" > "$WORK/$id.smoke-$attempt.log"
    [ -f "$dir/smoke.txt" ] && break
    [ "$rc" -eq 0 ] && break
    [ "$attempt" -ge 2 ] && break
    [ "$rc" -eq 124 ] && break   # a hang is not transient; a second window proves nothing
    note_row "$id: smoke attempt $attempt exited $rc with no artifact — retried once"
    attempt=$((attempt+1)); sleep 2
  done
  if [ "$rc" -ne 0 ] && [ ! -f "$dir/smoke.txt" ]; then
    emit "$id" smoke FAIL "turn exited $rc and wrote no smoke.txt after $attempt attempt(s) — $(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -1)"
    return 0
  fi
  if [ ! -f "$dir/smoke.txt" ]; then
    emit "$id" smoke FAIL "turn exited $rc but left no smoke.txt in $dir"
    return 0
  fi
  if ! grep -qF -- "$token" "$dir/smoke.txt"; then
    emit "$id" smoke FAIL "smoke.txt does not contain the token it was asked for ($(wc -c < "$dir/smoke.txt") B, sha256 $(sha256sum "$dir/smoke.txt" | cut -c1-12)…, exit $rc)"
    return 0
  fi
  sum="$(sha256sum "$dir/smoke.txt" | cut -c1-12)"
  want="$(printf '%s' "$token" | sha256sum | cut -c1-12)"
  emit "$id" smoke PASS "smoke.txt contains $token ($(wc -c < "$dir/smoke.txt") B, sha256 $sum..., exit $rc; token sha256 $want...; binary $path ($source))"
  return 0
}

leg_apply() {  # <id> <adapter file>
  local id="$1" file="$2" path home out rc port value waited code check_out
  path="$ADAPTER_DIR/$file"
  if [ ! -f "$path" ]; then
    emit "$id" apply FAIL "no adapter at scripts/harness/$file — nothing can install this harness"
    return 0
  fi
  if [ "$MODE_INSTALL" -ne 1 ]; then
    emit "$id" apply SKIP "not attempted: --install was not requested (this battery installs nothing without it)"
    return 0
  fi
  home="$WORK/apply/$id/home"
  mkdir -p "$home/.hermes"
  # A public bind needs an auth block; this is a scratch credential, never a real one.
  if [ ! -f "$home/.hermes/config.yaml" ]; then
    printf 'dashboard:\n  basic_auth:\n    username: conformance\n    password: scratch-only-not-a-secret\n' > "$home/.hermes/config.yaml"
    chmod 600 "$home/.hermes/config.yaml"
  fi
  port="$(sed -n 's/.*port \([0-9][0-9]*\)).*/\1/p' "$WORK/$id.check.txt" 2>/dev/null | head -1)"
  [ -n "$port" ] || port=10800
  out="$(HOME="$home" timeout "$APPLY_TIMEOUT" bash "$path" --apply 2>&1)"; rc=$?
  printf '%s\n' "$out" > "$WORK/$id.apply.txt"

  if [ "$rc" -eq 0 ]; then
    value="$(adapter_row "$out" PASS install)"
    [ -n "$value" ] || value="$(adapter_row "$out" PASS gateway_start)"
    [ -n "$value" ] || { emit "$id" apply FAIL "adapter --apply exited 0 but printed no install or gateway row"; return 0; }
    emit "$id" apply PASS "exit 0 in scratch HOME — $value"
  else
    value="$(printf '%s\n' "$out" | awk 'index($0,"  FAIL  ")==1' | sed 's/^  FAIL  //' | joinrows)"
    emit "$id" apply FAIL "adapter --apply exit $rc in scratch HOME — ${value:-no FAIL row printed}"
    # A readiness race is a measurement, not an excuse: re-probe the port and say when it answered.
    if [ -n "$port" ] && printf '%s\n' "$out" | grep -q '^  FAIL  gateway_start'; then
      waited=0
      while [ "$waited" -lt 30 ]; do
        code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/api/status" 2>/dev/null)"
        [ "$code" = 200 ] && break
        sleep 2; waited=$((waited+2))
      done
      if [ "$code" = 200 ]; then
        note_row "$id: the adapter reported gateway_start FAIL, but /api/status answered 200 on :$port ${waited}s later — the gateway came up after the adapter's own probe, so that FAIL measures the probe, not the install"
      else
        note_row "$id: gateway_start FAIL and /api/status still not 200 on :$port after ${waited}s"
      fi
    fi
  fi
  if printf '%s\n' "$out" | grep -q 'FAIL  inference_key'; then
    note_row "$id: inference_key is absent in the throwaway HOME by construction — the adapter counts that row toward its exit status, so --apply cannot be green there without copying a real credential, which this battery will not do"
  fi
  # Post-apply state is the honest evidence for an install ladder.
  check_out="$(HOME="$home" bash "$path" --check 2>&1)"
  printf '%s\n' "$check_out" > "$WORK/$id.postcheck.txt"
  local post
  post="$(printf '%s\n' "$check_out" | awk 'index($0,"  FAIL  ")==1||index($0,"  SKIP  ")==1' | sed 's/^  //' | joinrows)"
  [ -n "$post" ] || post="all rows PASS ($(adapter_row "$check_out" PASS version))"
  note_row "$id: post-apply --check — $post"
  kill_gateways
  [ "${HC_KEEP_APPLY:-0}" = 1 ] || rm -rf "$WORK/apply/$id"
  return 0
}

# ------------------------------------------------------------------------ doc
write_doc() {
  local stamp sha host row
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sha="$(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  git -C "$HERE" status --porcelain --untracked-files=no 2>/dev/null | grep -q . \
    && sha="$sha + uncommitted changes"
  host="$(uname -srm)"
  mkdir -p "$(dirname "$DOC")"
  {
    printf '# Harness conformance matrix\n\n'
    printf '**Generated by `tests/harness-conformance.sh --write-doc` at %s on `%s` (%s, commit `%s`).\n' "$stamp" "$(uname -n)" "$host" "$sha"
    printf 'Do not hand-edit this file: the next run overwrites it. Change the battery, or the adapter, instead.**\n\n'
    printf 'Command: `tests/harness-conformance.sh %s` with `HERMES_PYTHON_BIN=%s`, `HC_TIMEOUT=%s`, `HC_APPLY_TIMEOUT=%s`.\n\n' \
      "${ARGS:-}" "${HERMES_PYTHON_BIN:-unset}" "$TIMEOUT" "$APPLY_TIMEOUT"
    printf 'Every cell is one leg for one harness. `PASS` quotes the value that was measured, `FAIL`\n'
    printf 'quotes the value that contradicted it, and `SKIP` names the exact credential, binary or\n'
    printf 'capability that is missing here. A SKIP is **not** evidence of support: it says this host\n'
    printf 'could not test the harness, and the row names what would have to exist to test it.\n\n'
    printf '## The matrix\n\n'
    printf '| harness | check | apply | smoke |\n|---|---|---|---|\n'
    while IFS='|' read -r id adapter bin gen smoke measured <&3; do
      [ -n "$id" ] || continue
      printf '| `%s` |' "$id"
      for leg in check apply smoke; do
        row="$(awk -F'	' -v i="$id" -v l="$leg" '$1==i && $2==l {print $3 "|" $4; exit}' "$RESULTS")"
        verdict="${row%%|*}"; value="${row#*|}"
        value="${value//|/\\|}"
        printf ' `%s` — %s |' "${verdict:-NOT RUN}" "${value:-no row recorded}"
      done
      printf '\n'
    done 3< <(printf "%s\n" "$HARNESSES")
    printf '\n## The vars leg (specs/HARNESS-MATRIX.md §5)\n\n'
    printf 'The declared set is parsed out of the spec above, so this leg cannot drift from it. A row is\n'
    printf '`PASS` only when the installer documents every declared variable in `--help`, accepts the full\n'
    printf 'set, refuses a credential VALUE and an ambient provider key by name, and records every name it\n'
    printf 'accepted — a declared variable that is accepted and then silently dropped fails the row.\n\n'
    printf '| harness | vars |\n|---|---|\n'
    while IFS='|' read -r id _rest <&3; do
      [ -n "$id" ] || continue
      row="$(awk -F'\t' -v i="$id" -v l="vars" '$1==i && $2==l {print $3 "|" $4; exit}' "$RESULTS")"
      verdict="${row%%|*}"; value="${row#*|}"
      value="${value//|/\\|}"
      printf '| `%s` | `%s` — %s |\n' "$id" "${verdict:-NOT RUN}" "${value:-no row recorded}"
    done 3< <(printf "%s\n" "$HARNESSES")
    printf '\n## The rows as printed\n\n```\n'
    awk -F'\t' '$1!="note" {printf "  %-4s  %s:%s — %s\n", $3, $1, $2, $4}' "$RESULTS"
    printf '```\n\n'
    printf '## Measured findings (auto)\n\n'
    local notes
    notes="$(awk -F'\t' '$1=="note" {print $4}' "$RESULTS")"
    if [ -n "$notes" ]; then
      printf '%s\n' "$notes" | sed 's/^/- /'
    else
      printf '_No leg recorded a finding beyond the rows above._\n'
    fi
    cat <<'TEXT'

## How to run it

```bash
tests/harness-conformance.sh                  # check + smoke, installs nothing
tests/harness-conformance.sh --write-doc      # regenerate this file
tests/harness-conformance.sh --install        # also run each adapter --apply in a throwaway HOME
HERMES_PYTHON_BIN=python3.12 tests/harness-conformance.sh   # when python3 on PATH is >=3.14
```

Exit code is 0 only when no leg FAILs; SKIPs do not fail the run. The smoke turns write into
`$HOME/.harness-conformance/run-*/smoke/<harness>/` so the artifact and its sha256 stay on the
control host. `--install` installs into `$HOME/.harness-conformance/run-*/apply/<harness>/home`
and removes that HOME afterwards unless `HC_KEEP_APPLY=1`.

## What a green matrix proves

- Each adapter, run as shipped, exits 0 on `--check` and quotes a version it measured; no adapter
  PASS row is empty.
- Each smoke leg produced a file containing a token the battery chose and the battery verified the
  bytes on the control host — a real turn through that harness, not a version string.
- With `--install`, each `--apply` reached exit 0 in a HOME that held no prior state, and the
  post-apply `--check` is quoted next to it.

## What a green matrix does not prove

- **Not a node.** The battery runs on the control host against the host's own credentials. It does
  not prove the credential bundle, the crier bus, the repo layer or the scheduler path.
- **Not the pinned ladder.** A green `check` means "this host's binary satisfies the adapter", not
  "the adapter's pin installs". Only `--install` on a clean node measures that, and the pin can be
  older than what a developer box runs.
- **Not every harness.** A SKIP row is an untested harness. A matrix with SKIPs is honest, not
  conformant; read the SKIP column before quoting this file.
- **Not autonomy.** One smoke turn proves the harness answers a directive and can write a file. It
  does not prove unattended operation under crier, timeouts, retries or a hostile prompt.
- **Not a gate on its own.** `tests/selftest.sh` §44 proves this battery can go red. A battery that
  cannot report FAIL is decoration, and the fixture arms are what keep it honest.
TEXT
  } > "$DOC"
  note_row "doc written: ${DOC#"$HERE"/}"
}

# ----------------------------------------------------------------------- main
say "harness conformance — $(date -u +%Y-%m-%dT%H:%M:%SZ), adapters from ${ADAPTER_DIR#"$HERE"/}"
say "  work: $WORK"
say "  installs: $([ "$MODE_INSTALL" -eq 1 ] && echo 'enabled (scratch HOME)' || echo 'disabled (--install to enable)')"
say ""
say "the §5 variable contract (specs/HARNESS-MATRIX.md §5)"
declared_count="$(spec_declared 2>/dev/null | grep -c . || true)"
drift="$(declared_drift)"
if [ "${declared_count:-0}" -lt 1 ]; then
  emit "battery" "vars-declared" FAIL "specs/HARNESS-MATRIX.md §5 declares no CF_* variables (the §5 table was not found) — the vars leg has no authority to check against"
elif [ -n "$drift" ]; then
  emit "battery" "vars-declared" FAIL "$(printf '%s' "$drift" | sed 's/; $//') — the set this battery checks is not the set §5 declares"
else
  emit "battery" "vars-declared" PASS "all $declared_count variables §5 declares are checked, and only those"
fi
say ""

while IFS='|' read -r id adapter bin gen smoke measured <&3; do
  [ -n "$id" ] || continue
  selected "$id" || continue
  say "$id"
  if [ "$VARS_ONLY" -eq 0 ]; then
    leg_check "$id" "$adapter" "$bin" "$gen"
    leg_apply "$id" "$adapter"
  fi
  leg_vars "$id" "$adapter"
  [ "$VARS_ONLY" -eq 0 ] && leg_smoke "$id" "$bin" "$gen" "$measured"
  say ""
done 3< <(printf '%s\n' "$HARNESSES")

# Belt and braces: nothing may have written a PASS with an empty value.
leaks="$(awk -F'\t' '$3=="PASS" && ($4=="" || $4 ~ /^[[:space:]]*$/) {print $1":"$2}' "$RESULTS")"
if [ -n "$leaks" ]; then
  bad "battery:empty-value" "$leaks passed with no measured value"
fi

if [ "$WRITE_DOC" -eq 1 ]; then
  write_doc
fi

say ""
say "summary: $(awk -F'\t' '$3=="PASS"' "$RESULTS" | wc -l) pass, $(awk -F'\t' '$3=="FAIL"' "$RESULTS" | grep -c .) fail, $SKIPPED skip"
[ "$FAILED" -eq 0 ] && { say "HARNESS CONFORMANCE: PASS"; exit 0; } \
  || { say "HARNESS CONFORMANCE: FAIL ($FAILED)"; exit 1; }

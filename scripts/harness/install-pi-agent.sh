#!/usr/bin/env bash
# install-pi-agent.sh — pinned, fixture-backed oh-my-pi adapter (CF-228).
#
# LIVE STATUS: UNVERIFIED. No reachable upstream measurement is recorded in this repository.
# The repository-owned fixture proves only the user-space ladder, version readback, idempotence,
# credential contract, and turn wiring; it is never presented as an upstream release.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/harness-vars.sh"

PI_PKG="@oh-my-pi/pi-coding-agent"
PI_PIN="18.16.0"
PI_BUN_PIN="1.4.4"
PI_INSTALL_ROOT="$HOME/.local/harness/oh-my-pi/$PI_PIN"
PI_PACKAGE_ROOT="$PI_INSTALL_ROOT/package"
PI_BUN="$PI_INSTALL_ROOT/bun/bin/bun"
PI_BIN="$PI_INSTALL_ROOT/bin/pi"
PI_FIXTURE_DIR="${PI_FIXTURE_DIR:-}"
MODE="--check"
PROMPT=""

usage() {
  cat <<'PI_AGENT_USAGE'
install-pi-agent.sh — pinned, fixture-backed oh-my-pi adapter.

USAGE
  install-pi-agent.sh [--check | --apply | --turn | --contract] [options]

MODES
  --check       Read-only. Measures the installed oh-my-pi package, pi launcher, and pinned Bun
                runtime under $HOME/.local/harness/oh-my-pi/18.16.0. A PATH binary is reported as
                host state and never as this install ladder.
  --apply       Installs the repository-owned fixture at PI_FIXTURE_DIR under $HOME. Without a
                fixture this leg is UNVERIFIED and refuses to pretend an upstream install occurred.
                The fixture must identify $PI_PKG at pin $PI_PIN and Bun $PI_BUN_PIN.
  --turn        Runs one unattended pi turn in CF_WORKDIR. The fixture must write CF_TURN_FILE
                containing CF_TURN_TOKEN and emit model_served; a missing credential is SKIP exit 3.
  --contract    Validate the §5 set, without installing or running anything.
  --help, -h    This text.

FIXTURE
  PI_FIXTURE_DIR is a test-only source tree containing package/, bun/bin/bun and bin/pi. It is not
  an upstream download or a live measurement. Live upstream install and live turn remain UNVERIFIED.
PI_AGENT_USAGE
  cfv_help_block
  cat <<'PI_AGENT_TAIL'

REFUSALS
  * credentials are paths to mode-600 files, never values or argv;
  * ambient OPENAI_API_KEY / ANTHROPIC_API_KEY are refused;
  * CF_WORKDIR must exist inside $HOME;
  * CF_BASE_URL must be http(s) without userinfo; budgets must be bounded integers.
PI_AGENT_TAIL
}

die_usage() { say "install-pi-agent: $*" >&2; say "try --help" >&2; exit 2; }

# Pull adapter-only options out before the shared §5 parser sees them.
cfv_argv=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check|--apply|--contract) cfv_argv+=("$1"); shift ;;
    --turn) MODE="--turn"; shift ;;
    --prompt) [ "$#" -ge 2 ] || die_usage "--prompt needs a value"; PROMPT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) cfv_argv+=("$1"); shift ;;
  esac
done
cfv_load_env
cfv_parse_args "${cfv_argv[@]}"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
[ "$MODE" != "--check" ] || MODE="--$CFV_MODE"

# The fixture is deliberately strict: a test cannot accidentally certify a host's pi binary.
fixture_file() { [ -n "$PI_FIXTURE_DIR" ] && [ -e "$PI_FIXTURE_DIR/$1" ]; }
version_of() { "$1" --version 2>/dev/null | head -1; }
package_value() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$PI_PACKAGE_ROOT/package.json" | head -1; }

validate_fixture() {
  local package_name package_version bun_version
  if [ -z "$PI_FIXTURE_DIR" ]; then
    bad "fixture" "absent — live upstream measurement is unavailable; set PI_FIXTURE_DIR for the hermetic fixture"
    return 1
  fi
  for f in package/package.json bun/bin/bun bin/pi; do
    fixture_file "$f" || { bad "fixture" "missing $PI_FIXTURE_DIR/$f"; return 1; }
  done
  package_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PI_FIXTURE_DIR/package/package.json" | head -1)"
  package_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PI_FIXTURE_DIR/package/package.json" | head -1)"
  [ "$package_name" = "$PI_PKG" ] || { bad "fixture_package" "name $package_name (want $PI_PKG)"; return 1; }
  [ "$package_version" = "$PI_PIN" ] || { bad "fixture_package" "version $package_version (want $PI_PIN)"; return 1; }
  chmod +x "$PI_FIXTURE_DIR/bun/bin/bun" "$PI_FIXTURE_DIR/bin/pi" 2>/dev/null || true
  bun_version="$(version_of "$PI_FIXTURE_DIR/bun/bin/bun")"
  [ "$bun_version" = "$PI_BUN_PIN" ] || { bad "fixture_bun" "version $bun_version (want $PI_BUN_PIN)"; return 1; }
  ok "fixture" "$PI_PKG@$PI_PIN with Bun $PI_BUN_PIN"
}

check_install() {
  local package_name package_version bun_version pi_version
  if [ ! -x "$PI_BIN" ] || [ ! -x "$PI_BUN" ] || [ ! -f "$PI_PACKAGE_ROOT/package.json" ]; then
    bad "package" "absent at $PI_INSTALL_ROOT — no fixture-backed install is present"
    return 1
  fi
  package_name="$(package_value name)"; package_version="$(package_value version)"
  [ "$package_name" = "$PI_PKG" ] || { bad "package" "measured $package_name (want $PI_PKG) at $PI_PACKAGE_ROOT"; return 1; }
  [ "$package_version" = "$PI_PIN" ] || { bad "package" "measured $package_version (want $PI_PIN) at $PI_PACKAGE_ROOT"; return 1; }
  ok "package" "$package_name@$package_version at $PI_PACKAGE_ROOT"
  bun_version="$(version_of "$PI_BUN")"
  [ "$bun_version" = "$PI_BUN_PIN" ] || { bad "bun" "measured $bun_version (want $PI_BUN_PIN) at $PI_BUN"; return 1; }
  ok "bun" "$bun_version at $PI_BUN"
  pi_version="$(version_of "$PI_BIN")"
  [ -n "$pi_version" ] || { bad "version" "pi at $PI_BIN returned no version"; return 1; }
  ok "version" "$pi_version from install root $PI_BIN"
  if "$PI_BIN" --help 2>&1 | grep -q -- '-p'; then
    ok "non_interactive" "pi -p --no-session surface advertised by $PI_BIN"
  else
    bad "non_interactive" "pi at $PI_BIN does not advertise -p"
  fi
  return 0
}

say "harness: pi-agent / oh-my-pi (LIVE UNVERIFIED; fixture-backed)"
cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""; say "PI-AGENT: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"; exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""; say "PI-AGENT: CONTRACT PASS — the §5 set is accepted; nothing installed"; exit 0
fi

if [ "$MODE" = "--apply" ]; then
  if [ -z "$PI_FIXTURE_DIR" ]; then
    bad "apply" "refused — no measured upstream ladder; set PI_FIXTURE_DIR for the hermetic fixture-backed ladder"
    say ""; verdict PI-AGENT; exit $?
  fi
  # Validate the source before touching the destination, then publish one complete tree atomically.
  if ! validate_fixture; then say ""; verdict PI-AGENT; exit $?; fi
  if [ -x "$PI_BIN" ] && [ -x "$PI_BUN" ] && [ -f "$PI_PACKAGE_ROOT/package.json" ]; then
    if check_install >/dev/null 2>&1; then
      note "install — already installed at pin $PI_PIN (idempotent; no source copied)"
      say ""; verdict PI-AGENT action; exit $?
    fi
  fi
  stage="$PI_INSTALL_ROOT.stage.$$"
  rm -rf "$stage"
  mkdir -p "$stage"
  cp -a "$PI_FIXTURE_DIR/." "$stage/" || { rm -rf "$stage"; bad "install" "fixture copy failed"; say ""; verdict PI-AGENT; exit $?; }
  chmod +x "$stage/bun/bin/bun" "$stage/bin/pi"
  mkdir -p "$(dirname "$PI_INSTALL_ROOT")"
  rm -rf "$PI_INSTALL_ROOT"
  mv "$stage" "$PI_INSTALL_ROOT" || { rm -rf "$stage"; bad "install" "could not publish user-space tree"; say ""; verdict PI-AGENT; exit $?; }
  if check_install; then ok "install" "fixture published under $PI_INSTALL_ROOT (user-space)"; else bad "install" "post-install readback failed"; fi
  say ""; verdict PI_AGENT action; exit $?
fi

if [ "$MODE" = "--turn" ]; then
  if [ -z "${CF_API_KEY_FILE:-}" ]; then
    say "PI-AGENT: SKIP (no CF_API_KEY_FILE credential path; live and fixture turns are unverified)"; exit 3
  fi
  work="${CF_WORKDIR:-}"; [ -d "$work" ] || { bad "turn" "CF_WORKDIR is required and must exist"; say ""; verdict PI-AGENT action; exit $?; }
  if ! check_install >/dev/null 2>&1; then bad "turn" "fixture-backed install is absent; run --apply with PI_FIXTURE_DIR"; say ""; verdict PI-AGENT action; exit $?; fi
  prompt="${PROMPT:-Create the requested artifact in the current working directory.}"
  out="$(cd "$work" && CF_MODEL="${CF_MODEL:-unknown}" CF_TURN_TOKEN="${CF_TURN_TOKEN:-CF-228-TOKEN}" CF_TURN_FILE="${CF_TURN_FILE:-pi-turn.txt}" timeout "${CFV_TIMEOUT_S:-1800}" "$PI_BIN" -p --no-session "$prompt" 2>&1)"; rc=$?
  printf '%s\n' "$out"
  file="$work/${CF_TURN_FILE:-pi-turn.txt}"
  if [ "$rc" -ne 0 ] || [ ! -f "$file" ]; then bad "turn" "pi exited $rc or did not write $file"; else ok "artifact" "$file"; fi
  if printf '%s\n' "$out" | grep -q 'model_served='; then ok "model_served" "$(printf '%s\n' "$out" | sed -n 's/.*model_served=//p' | head -1)"; else warn "model_served" "fixture did not report model_served"; fi
  say ""; verdict PI-AGENT action; exit $?
fi

p="$(have pi 2>/dev/null || true)"
if [ -x "$PI_BIN" ]; then check_install
elif [ -n "$p" ]; then
  ok "binary" "$p (host-provided; not this adapter's install root)"
  v="$(version_of "$p")"; [ -n "$v" ] && ok "version" "$v from host-provided $p" || warn "version" "host binary returned no version"
  if "$p" --help 2>&1 | grep -q -- '-p'; then ok "non_interactive" "pi -p / --no-session surface advertised"; else warn "non_interactive" "could not confirm -p surface"; fi
else
  bad "binary" "absent — no install root and no pi on PATH"
fi
if [ -s "$HOME/.pi/agent/auth.json" ]; then
  if [ -n "$p" ]; then
    note "credential_file — $HOME/.pi/agent/auth.json present (credential is a run input, not an install)"
  else
    warn "credential_file" "$HOME/.pi/agent/auth.json is present, but a credential file is not a binary — the binary row above is the one that decides"
  fi
else
  note "credential_file — no ~/.pi/agent/auth.json in this \$HOME"
fi
say ""
verdict PI-AGENT
exit $?

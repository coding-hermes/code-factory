#!/usr/bin/env bash
# install-opencode.sh — adapter for the opencode harness.
#
# UNVERIFIED: this repo has not measured an opencode install inside a bunker. The method is
# documented and the check is real; --apply is refused until someone runs it and records the
# ladder in specs/HARNESS.md. An unverified installer must not pretend to be supported.
#
# The §5 input contract is one implementation, scripts/harness/harness-vars.sh: every declared
# variable is accepted as a flag and as a CF_* environment variable, a credential is a PATH (never
# a value, never ambient), and every accepted name is recorded (CF-229). Validating the contract
# is not installing, so --contract is honest here even while --apply refuses.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/harness-vars.sh"

MODE="--check"

usage() {
  cat <<'OPENCODE_USAGE'
install-opencode.sh — the opencode adapter (UNVERIFIED install ladder).

USAGE
  install-opencode.sh [--check | --contract | --apply] [CF_* options]

MODES
  --check      (default) Read-only. Reports the binary and the version it measured, whether it
               lives under $HOME, and whether a non-interactive surface is advertised. Never
               touches the network.
  --contract   Validate the §5 set below and exit 0, or exit 2 with a named refusal. Installs
               nothing, runs nothing: the acceptance check the conformance battery calls.
  --apply      REFUSED. The opencode install ladder is unmeasured in this repo; measure it,
               record it in specs/HARNESS.md, then implement this leg. A named refusal, not a
               silent success.
  --help, -h   This text.

OPENCODE_USAGE
  cfv_help_block
  cat <<'OPENCODE_TAIL'
REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE or as --api-key, and CF_API_KEY set at all (not in the
    contract) — a key travels as a mode-600 PATH, never as a value (AGENTS.md r8);
  * OPENAI_API_KEY / ANTHROPIC_API_KEY exported into the ambient environment — the directive is
    the only source, so two lanes on one node cannot contaminate each other (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * CF_BASE_URL that is not http(s), or that carries userinfo (a credential in a URL).

WHAT THIS ADAPTER DOES WITH THE SET
  opencode has no measured invocation here, so the run-scoped names (model, provider, namespace,
  run id, lane, skills root, options bag) are recorded rather than passed. Recording is what keeps
  them from being accepted and silently ignored, and it is what two runs are compared on.
OPENCODE_TAIL
}

cfv_load_env
cfv_parse_args "$@"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
MODE="--$CFV_MODE"

say "harness: opencode (UNVERIFIED adapter)"

cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""
  say "OPENCODE: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"
  exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""
  say "OPENCODE: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed"
  exit 0
fi

p=$(have opencode)
if [ -n "$p" ]; then
  ok "binary" "$p"
  ok "version" "$("$p" --version 2>/dev/null | head -1)"
else
  bad "binary" "absent — no opencode in this node"
fi

if [ -x "$HOME/.opencode/bin/opencode" ]; then ok "user_space_binary" "$HOME/.opencode/bin/opencode"; else warn "user_space_binary" "not installed under \$HOME"; fi

# Its non-interactive surface is the contract (specs/HARNESS.md §"what a foreign harness must gain").
if [ -n "$p" ] && "$p" --help 2>/dev/null | grep -qi 'run\|exec\|serve'; then
  ok "non_interactive" "a run/exec/serve mode is advertised"
else
  warn "non_interactive" "could not confirm a non-interactive mode"
fi

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — the opencode install ladder is unmeasured here. Measure it, record it in specs/HARNESS.md, then implement this leg."
  say ""; say "OPENCODE: FAIL ($FAILED)"; exit 1
fi

say ""
[ "$FAILED" -eq 0 ] && { say "OPENCODE: PASS"; exit 0; } || { say "OPENCODE: FAIL ($FAILED)"; exit 1; }

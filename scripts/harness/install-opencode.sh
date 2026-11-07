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

# Resolve the binary the way the §"conformance is measured" rule requires: the `$HOME`-owned prefix
# first, PATH second. opencode's own installer places it at ~/.opencode/bin/opencode, which
# `command -v` cannot see unless that directory is exported — a name-only resolution reported
# "absent" for a binary the very next row reported as installed under $HOME, and the conformance
# battery's smoke leg then had no measured path to execute.
owned="$HOME/.opencode/bin/opencode"
p=""
from_path=0
if [ -x "$owned" ]; then
  p="$owned"
else
  p=$(have opencode)
  [ -n "$p" ] && from_path=1
fi
v=""
if [ -n "$p" ]; then
  ok "binary" "$p"
  v="$("$p" --version 2>/dev/null | head -1)"
  # A PASS with no measured value is a lie (tests/harness-conformance.sh `empty_adapter_rows`
  # turns one into a FAIL); deepseek and pi-agent warn here, and this adapter printed an empty
  # version row instead. Probe first, then report what the probe actually returned.
  if [ -n "$v" ]; then ok "version" "$v"; else warn "version" "binary answered no --version"; fi
  if [ "$from_path" = 1 ]; then
    note "binary_provenance — PATH-provided; this repo records no opencode install ladder, so a PATH binary is host state, not an install it made"
  fi
else
  bad "binary" "absent — no opencode at $owned and none on PATH"
fi

if [ -x "$HOME/.opencode/bin/opencode" ]; then ok "user_space_binary" "$HOME/.opencode/bin/opencode"; else warn "user_space_binary" "not installed under \$HOME"; fi

# `generation`: the conformance table carries a generation column because opencode v1 and v2 share a
# binary name, so a v1 binary must never certify the v2 row. Reporting the measured major gives that
# row an adapter-measured value instead of a battery-side guess about whether a gate exists.
if [ -n "$v" ]; then
  major="${v%%.*}"
  case "$major" in
    ''|*[!0-9]*) warn "generation" "no major version in '$v' — this build's generation cannot be certified" ;;
    *) ok "generation" "v$major (measured $v)" ;;
  esac
else
  warn "generation" "no measured version — the generation cannot be certified"
fi

# Its non-interactive surface is the contract (specs/HARNESS.md §"what a foreign harness must gain").
# These CLIs write --help to STDERR (measured on opencode 1.18.29: 4285 B on stderr, 0 B on stdout,
# and `run --help` likewise), so a stdout-only probe answered "could not confirm" for a binary whose
# own help advertises `run` in those same bytes — a false negative in a machine-readable row. Read
# both streams and quote the word that matched, so the row carries a measurement.
if [ -n "$p" ]; then
  help=$({ "$p" --help; "$p" run --help; } 2>&1)
  surface=$(printf '%s\n' "$help" | grep -oiE '(^|[[:space:]])(run|exec|serve)([[:space:]]|$)' | head -1 | tr -d '[:space:]')
  surface="${surface:-}"
  if [ -n "$surface" ]; then
    ok "non_interactive" "the \`$surface\` surface is advertised (help read from stdout and stderr)"
  else
    warn "non_interactive" "neither \`--help\` nor \`run --help\` advertises run/exec/serve, on stdout or stderr"
  fi
else
  warn "non_interactive" "no binary to probe"
fi

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — the opencode install ladder is unmeasured here. Measure it, record it in specs/HARNESS.md, then implement this leg."
  say ""; verdict OPENCODE; exit $?
fi

say ""
verdict OPENCODE
exit $?

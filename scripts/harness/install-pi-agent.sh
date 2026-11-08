#!/usr/bin/env bash
# install-pi-agent.sh — adapter for the pi-agent harness (binary `pi`).
#
# UNVERIFIED: this repo records no install ladder for pi (no pin, no artifact digest, no recorded
# --apply), so nothing here can reproduce an install. A `pi` binary does exist on some hosts' PATH
# and a `~/.pi/agent/auth.json` on others — that is host state this adapter reports, not a ladder
# it measured. specs/HARNESS-MATRIX.md names oh-my-pi at npm `@oh-my-pi/pi-coding-agent`; the
# conformance row probes the binary `pi`.
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
  cat <<'PI_AGENT_USAGE'
install-pi-agent.sh — the pi-agent adapter (UNVERIFIED install ladder).

USAGE
  install-pi-agent.sh [--check | --contract | --apply] [CF_* options]

MODES
  --check      (default) Read-only. Resolves the `pi` binary and, only when one is found, reports
               the version it measured. An absent binary is a named FAIL, never a PASS. A
               ~/.pi/agent/auth.json is reported as what it is — a credential file, not a binary.
  --contract   Validate the §5 set below and exit 0, or exit 2 with a named refusal. Installs
               nothing, runs nothing: the acceptance check the conformance battery calls.
  --apply      REFUSED. This repo has measured no `pi` install ladder — no pin, no artifact digest,
               nothing recorded in specs/HARNESS.md — so there is nothing here to apply that could
               be reproduced. A binary on PATH is one host's state, not an installer. A named
               refusal, not a silent success.
  --help, -h   This text.

PI_AGENT_USAGE
  cfv_help_block
  cat <<'PI_AGENT_TAIL'
REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE or as --api-key, and CF_API_KEY set at all (not in the
    contract) — a key travels as a mode-600 PATH, never as a value (AGENTS.md r8);
  * OPENAI_API_KEY / ANTHROPIC_API_KEY exported into the ambient environment — the directive is
    the only source, so two lanes on one node cannot contaminate each other (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * CF_BASE_URL that is not http(s), or that carries userinfo (a credential in a URL).

WHAT THIS ADAPTER DOES WITH THE SET
  The only non-interactive surface the matrix records is `pi -p --no-session "<prompt>"`, and with
  no binary on PATH nothing here can prove it, so the run-scoped names (model, provider,
  namespace, run id, lane, skills root, options bag) are recorded rather than passed. Recording is
  what keeps them from being accepted and silently ignored. The declared names are, in the spec's
  order: CF_MODEL, CF_PROVIDER, CF_BASE_URL, CF_API_KEY_FILE, CF_WORKDIR, CF_NAMESPACE, CF_RUN_ID,
  CF_LANE, CF_SKILLS_DIR, CF_HARNESS_OPTS, CF_MAX_TURNS, CF_TIMEOUT_S.
PI_AGENT_TAIL
}

cfv_load_env
cfv_parse_args "$@"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
MODE="--$CFV_MODE"

say "harness: pi-agent (UNVERIFIED adapter)"

cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""
  say "PI-AGENT: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"
  exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""
  say "PI-AGENT: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed"
  exit 0
fi

p=$(have pi)
if [ -n "$p" ]; then
  ok "binary" "$p"
  v="$("$p" --version 2>/dev/null | head -1)"
  if [ -n "$v" ]; then ok "version" "$v"; else warn "version" "binary answered no --version"; fi
  # Host state, reported as such: this repo certifies no pi install it can reproduce.
  note "binary_provenance — PATH-provided, not an install this repo measured (no pin, no digest)"
else
  bad "binary" "absent — no pi in this node (specs/HARNESS-MATRIX.md names oh-my-pi at npm @oh-my-pi/pi-coding-agent; nothing here installs it)"
fi

# An auth file is a credential, not a binary, and a credential alone certifies nothing. Its
# CLASS depends on what the row is next to (CF-006): with a measured binary above it, the auth
# file is a host FACT the check does not need and cannot block anything — a note. With no binary,
# the same file is the difference between "nothing to authenticate with" and "a credential whose
# harness is missing", so it stays a WARN beside the named `FAIL binary` (the verdict is FAIL
# either way, and the row keeps the credential visible instead of pretending it is an install).
if [ -s "$HOME/.pi/agent/auth.json" ]; then
  if [ -n "$p" ]; then
    note "credential_file — $HOME/.pi/agent/auth.json present (host state; a credential file is not a binary, and the measured binary above is what --check certifies)"
  else
    warn "credential_file" "$HOME/.pi/agent/auth.json is present, but a credential file is not a binary — the binary row above is the one that decides"
  fi
else
  note "credential_file — no ~/.pi/agent/auth.json in this \$HOME"
fi

# The matrix records `pi -p --no-session "<prompt>"` as its non-interactive surface; with no binary
# there is nothing to probe, and this adapter does not report a mode it could not observe.
if [ -n "$p" ] && "$p" --help 2>/dev/null | grep -q -- '-p'; then
  ok "non_interactive" "a -p / --no-session surface is advertised"
else
  warn "non_interactive" "could not confirm the documented \`pi -p --no-session\` surface (no binary, or it advertises no -p flag)"
fi

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — no measured pi install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md); a binary on PATH is a host state, not an installer. Measure a ladder, record it, then implement this leg."
  say ""; verdict PI-AGENT; exit $?
fi

say ""
verdict PI-AGENT
exit $?

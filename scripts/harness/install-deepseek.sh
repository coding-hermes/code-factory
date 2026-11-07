#!/usr/bin/env bash
# install-deepseek.sh — adapter for the deepseek harness.
#
# UNVERIFIED: this repo has measured no `deepseek` binary on any node it owns and records no
# install ladder for one. The matrix names DeepSeek's own harness as npm `@deepseek-ai/dsh`
# (CLI `dsh`, 0.2.1-rc.5), reported absent from both trees (specs/HARNESS-MATRIX.md); the
# conformance table probes the binary name `deepseek`, which is what this adapter resolves. So
# --check is real, --contract is honest, and --apply refuses by name instead of pretending to
# install something nobody has measured.
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
  cat <<'DEEPSEEK_USAGE'
install-deepseek.sh — the deepseek adapter (UNVERIFIED install ladder).

USAGE
  install-deepseek.sh [--check | --contract | --apply] [CF_* options]

MODES
  --check      (default) Read-only. Resolves the `deepseek` binary and, only when one is found,
               reports the version it measured. An absent binary is a named FAIL, never a PASS.
               Never touches the network.
  --contract   Validate the §5 set below and exit 0, or exit 2 with a named refusal. Installs
               nothing, runs nothing: the acceptance check the conformance battery calls.
  --apply      REFUSED. This repo has measured no `deepseek` binary and no install ladder for
               one (specs/HARNESS-MATRIX.md names npm `@deepseek-ai/dsh`, CLI `dsh`, as absent
               from both trees). Measure a ladder, record it in specs/HARNESS.md, then implement
               this leg. A named refusal, not a silent success.
  --help, -h   This text.

DEEPSEEK_USAGE
  cfv_help_block
  cat <<'DEEPSEEK_TAIL'
REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE or as --api-key, and CF_API_KEY set at all (not in the
    contract) — a key travels as a mode-600 PATH, never as a value (AGENTS.md r8);
  * OPENAI_API_KEY / ANTHROPIC_API_KEY exported into the ambient environment — the directive is
    the only source, so two lanes on one node cannot contaminate each other (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * CF_BASE_URL that is not http(s), or that carries userinfo (a credential in a URL).

WHAT THIS ADAPTER DOES WITH THE SET
  There is no measured deepseek invocation here, so the run-scoped names (model, provider,
  namespace, run id, lane, skills root, options bag) are recorded rather than passed. Recording is
  what keeps them from being accepted and silently ignored, and it is what two runs are compared
  on. The declared names are, in the spec's order: CF_MODEL, CF_PROVIDER, CF_BASE_URL,
  CF_API_KEY_FILE, CF_WORKDIR, CF_NAMESPACE, CF_RUN_ID, CF_LANE, CF_SKILLS_DIR, CF_HARNESS_OPTS,
  CF_MAX_TURNS, CF_TIMEOUT_S.
DEEPSEEK_TAIL
}

cfv_load_env
cfv_parse_args "$@"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
MODE="--$CFV_MODE"

say "harness: deepseek (UNVERIFIED adapter)"

cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""
  say "DEEPSEEK: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"
  exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""
  say "DEEPSEEK: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed"
  exit 0
fi

p=$(have deepseek)
if [ -n "$p" ]; then
  ok "binary" "$p"
  v="$("$p" --version 2>/dev/null | head -1)"
  if [ -n "$v" ]; then ok "version" "$v"; else warn "version" "binary answered no --version"; fi
else
  bad "binary" "absent — no deepseek in this node (the matrix measures no binary here; the package it names is npm @deepseek-ai/dsh, CLI dsh)"
fi

# Neither spec documents a non-interactive surface for the `deepseek` row, so there is nothing to
# probe: inventing one would be a claim this adapter cannot keep.
note "non_interactive — none documented for this harness row (tests/harness-conformance.sh); no surface to advertise"

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — no measured deepseek install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md). Measure a ladder, record it, then implement this leg."
  say ""; verdict DEEPSEEK; exit $?
fi

say ""
verdict DEEPSEEK
exit $?

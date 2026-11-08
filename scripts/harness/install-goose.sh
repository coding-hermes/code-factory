#!/usr/bin/env bash
# install-goose.sh — adapter for the goose harness (binary `goose`).
#
# DOCUMENTED BUT UNMEASURED: the method this repo records for goose is a standalone release
# binary (specs/HARNESS.md "Adapters and their measured state"). That is a DOCUMENTED method, NOT a
# measured ladder: nobody has run it on a node this repo owns, no release tag, no artefact digest
# and no non-interactive surface are recorded, and nothing here downloads anything. So `--check` is
# real, `--contract` is honest, and `--apply` refuses by name instead of pretending to install
# something nobody has measured. A harness named in specs/HARNESS.md with no adapter file was the
# defect this file closes (CF-006); an adapter that invented a ladder would be the same defect
# wearing a script.
#
# The §5 input contract is one implementation, scripts/harness/harness-vars.sh: every declared
# variable is accepted as a flag and as a CF_* environment variable, a credential is a PATH (never
# a value, never ambient), and every accepted name is recorded (CF-229). Validating the contract
# is not installing, so --contract is honest here even while --apply refuses.
#
# ch:trace row=CF-006 spec=specs/HARNESS.md#adapters-and-their-measured-state wave=none:serial-worker test=tests/selftest.sh::aider-goose-adapter doc=docs/handbook/chapters/M5-harness.md prompt=none:worker-brief evidence=tests/selftest.sh witness=none:local-fixture verdict=none:foreman-will-run-gitreins commit=none:worker-commit memory=none:foreman-closeout
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/harness-vars.sh"

MODE="--check"

usage() {
  cat <<'GOOSE_USAGE'
install-goose.sh — the goose adapter (DOCUMENTED method, UNMEASURED install ladder).

USAGE
  install-goose.sh [--check | --contract | --apply] [CF_* options]

MODES
  --check      (default) Read-only. Resolves the `goose` binary and, only when one is found,
               reports the version it measured. An absent binary is a named FAIL, never a PASS.
               Never touches the network and installs nothing.
  --contract   Validate the §5 set below and exit 0, or exit 2 with a named refusal. Installs
               nothing, runs nothing: the acceptance check the conformance battery calls.
  --apply      REFUSED. The goose install ladder is unmeasured in this repo: the documented method
               is a standalone release binary, but no release tag, no artefact digest and no
               measured non-interactive surface are recorded. Measure a ladder, record it in
               specs/HARNESS.md, then implement this leg. A named refusal, not a silent success.
  --help, -h   This text.

GOOSE_USAGE
  cfv_help_block
  cat <<'GOOSE_TAIL'
REFUSALS (each one names the rule, not just "invalid")
  * a credential value in CF_API_KEY_FILE or as --api-key, and CF_API_KEY set at all (not in the
    contract) — a key travels as a mode-600 PATH, never as a value (AGENTS.md r8);
  * OPENAI_API_KEY / ANTHROPIC_API_KEY exported into the ambient environment — the directive is
    the only source, so two lanes on one node cannot contaminate each other (matrix §5);
  * CF_WORKDIR that does not exist, or that resolves outside $HOME;
  * CF_MAX_TURNS / CF_TIMEOUT_S that are not integers, or outside 1..1000 / 1..86400;
  * CF_BASE_URL that is not http(s), or that carries userinfo (a credential in a URL).

WHAT THIS ADAPTER DOES WITH THE SET
  There is no measured goose invocation here, so the run-scoped names (model, provider, namespace,
  run id, lane, skills root, options bag) are recorded rather than passed. Recording is what keeps
  them from being accepted and silently ignored, and it is what two runs are compared on. The
  declared names are, in the spec's order: CF_MODEL, CF_PROVIDER, CF_BASE_URL, CF_API_KEY_FILE,
  CF_WORKDIR, CF_NAMESPACE, CF_RUN_ID, CF_LANE, CF_SKILLS_DIR, CF_HARNESS_OPTS, CF_MAX_TURNS,
  CF_TIMEOUT_S.
GOOSE_TAIL
}

cfv_load_env
cfv_parse_args "$@"
[ "$CFV_HELP" -eq 0 ] || { usage; exit 0; }
MODE="--$CFV_MODE"

say "harness: goose (UNVERIFIED adapter)"

cfv_validate "$CFV_MODE"
if cfv_refused; then
  say ""
  say "GOOSE: FAIL ($CFV_FAILED) — contract refused; nothing was installed or run"
  exit 2
fi
if [ "$CFV_MODE" = "contract" ]; then
  say ""
  say "GOOSE: CONTRACT PASS — the §5 set is accepted (specs/HARNESS-MATRIX.md §5); nothing installed"
  exit 0
fi

p=$(have goose)
if [ -n "$p" ]; then
  ok "binary" "$p"
  v="$("$p" --version 2>/dev/null | head -1)"
  if [ -n "$v" ]; then ok "version" "$v"; else warn "version" "binary answered no --version"; fi
else
  bad "binary" "absent — no goose in this node (this repo records no goose install ladder; the documented method is a standalone release binary)"
fi

# The method is recorded so the refusal below is auditable, and it is labelled as documentation
# rather than a measurement: a note is not a row that certifies anything.
note "install_method — DOCUMENTED, not measured: a standalone release binary (specs/HARNESS.md); no release tag, no artefact digest, no node where this repo ran it, and this adapter downloads nothing"

# goose advertises non-interactive forms of its own (`goose run -t`), but this repo has measured
# none of them, so there is nothing to probe: inventing a surface would be a claim this adapter
# cannot keep, and the conformance row marks its smoke column unmeasured.
note "non_interactive — none measured for this harness row (tests/harness-conformance.sh smoke column 0); no surface to advertise"

if [ "$MODE" = "--apply" ]; then
  bad "apply" "refused — the goose install ladder is unmeasured in this repo. The documented method is a standalone release binary, but no release tag, no artefact digest and no measured surface are recorded. Measure it, record it in specs/HARNESS.md, then implement this leg; nothing was placed on disk."
  say ""; verdict GOOSE; exit $?
fi

say ""
verdict GOOSE
exit $?

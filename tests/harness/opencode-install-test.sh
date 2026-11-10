#!/usr/bin/env bash
# tests/harness/opencode-install-test.sh — standalone proof for scripts/harness/install-opencode.sh.
# ch:trace row=CF-006 spec=specs/HARNESS.md#the-contract-every-adapter test=tests/harness/opencode-install-test.sh doc=specs/HARNESS.md prompt=none:local-fixture evidence=tests/harness/opencode-install-test.sh witness=none:local-fixture verdict=none:foreman-will-run-gitreins commit=HEAD memory=none:foreman-closeout
# ch:trace row=CF-240 spec=docs/handbook/chapters/M5-harness.md#M5.S2 wave=none:single-row test=tests/harness/opencode-install-test.sh doc=specs/HARNESS.md prompt=CF-240-brief evidence=tests/harness/opencode-install-test.sh witness=focused-test verdict=none:foreman-judge commit=none:worker-commit memory=none:foreman
# STATUS: partial
# TIER: T1
# EVIDENCE: tests/harness/opencode-install-test.sh
#
# Offline by construction: no network, no credential, no model, no install ladder. Every arm runs
# against a throwaway $HOME and a stub `opencode` binary that reports whatever version/surface the
# case needs — which is how the failure paths can be exercised on purpose:
#
#   A  refusals — a credential as a VALUE, an ambient provider key, a workdir outside $HOME, argv;
#      and --contract accepting the §5 run set
#   B  the absent-binary failure path — a named FAIL, never a PASS, never a PASS with no value
#   C  a v1 stub whose --help goes to STDERR only (what 1.18.29 does): version, generation and
#      non_interactive are each measured and quoted; C3 is the red control — the PRE-FIX adapter
#      (git show 45bd4bd:...) on the same stub warns, so arm C's PASS discriminates
#   D  a v2 stub: the generation row names v2, the value the conformance table compares
#   E  a stub that answers no --version: WARN rows, and no empty PASS row (the battery turns an
#      empty PASS into a FAIL, so this arm is what keeps that from shipping)
#   F  a stub that advertises no surface on either stream: a WARN naming both probes
#   G  --apply refuses by name, exits 1, and places nothing in the throwaway HOME
#   H  an owned $HOME prefix that is not on PATH is resolved and measured, not reported absent
#
# The verdict line follows the ROWS (specs/HARNESS.md "The verdict line", CF-141): every case whose
# rows include a WARN must end `OPENCODE: UNVERIFIED` and exit 3, and only the all-PASS case (H, an
# owned binary advertising a surface) may end `OPENCODE: PASS` with exit 0.
#
# Exit 0 only when every non-skipped assertion passed.

set -uo pipefail
HERE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SUT="$HERE_REPO/scripts/harness/install-opencode.sh"
PREFIX_SHA=45bd4bdfe284b74fc0631d36a2447b76bc885a0b

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$*"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$*"; }
say()  { printf '%s\n' "$*"; }

# A synthetic value that is not a credential, assembled from parts so no line in this file reads as
# a literal key to the tree-hygiene grep (AGENTS.md r8).
SYNTH_KEY="sk-$(printf 'cf006-test-%s' 'not-a-real-credential')"

SB="$(mktemp -d "${TMPDIR:-/tmp}/cf006-opencode-test.XXXXXXXX")" || exit 1
cleanup() { [ "${KEEP:-0}" = "1" ] || rm -rf "$SB"; }
trap cleanup EXIT INT TERM

say "opencode adapter test (CF-006) — subject: $SUT"
[ -f "$SUT" ] || { say "  FAIL  no such subject: $SUT"; exit 1; }

# Every case runs with a clean environment: an inherited key, CF_* value or PATH binary must never
# be the thing that makes a case pass.
runp() {  # runp <bin-dir> <home> <outfile> <arg...>  -> echoes the exit code
  local dir="$1" home="$2" out="$3"; shift 3
  env -i PATH="$dir:/usr/bin:/bin" HOME="$home" STUB_LOG="$SB/stub.log" \
    /bin/bash "$SUT" "$@" >"$out" 2>&1
  printf '%s' "$?"
}
runp_env() {  # runp_env <bin-dir> <home> <outfile> <K=V> <arg...>
  local dir="$1" home="$2" out="$3" pair="$4"; shift 4
  env -i PATH="$dir:/usr/bin:/bin" HOME="$home" STUB_LOG="$SB/stub.log" "$pair" \
    /bin/bash "$SUT" "$@" >"$out" 2>&1
  printf '%s' "$?"
}

mkdir -p "$SB/home/work" "$SB/nobin" "$SB/v1/bin" "$SB/v2/bin" "$SB/nover/bin" "$SB/nosurf/bin"

# The v1 stub: --help and `run --help` write to STDERR only, because that is what the real binary
# does (measured on 1.18.29: 4285 B on stderr, 0 B on stdout). It appends every call to $STUB_LOG,
# so an arm can prove the resolved path was the thing that executed.
cat > "$SB/v1/bin/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LOG:?}"
case "${1:-}" in
  --version) printf '1.18.29\n' ;;
  *) printf 'opencode — commands:\n  opencode run <prompt>\n  opencode serve\n' >&2 ;;
esac
STUB
chmod +x "$SB/v1/bin/opencode"

# The v2 stub advertises its surface on STDOUT, so the arm also proves the probe is not merely
# reading the other stream by habit.
cat > "$SB/v2/bin/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LOG:?}"
case "${1:-}" in
  --version) printf '2.3.1\n' ;;
  *) printf 'opencode — commands:\n  opencode run <prompt>\n' ;;
esac
STUB
chmod +x "$SB/v2/bin/opencode"

# A binary that answers --version with nothing at all (exit 0, no output).
cat > "$SB/nover/bin/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LOG:?}"
case "${1:-}" in
  --version) : ;;
  *) printf 'opencode — commands:\n  opencode run <prompt>\n' >&2 ;;
esac
STUB
chmod +x "$SB/nover/bin/opencode"

# A binary that advertises none of run/exec/serve on either stream.
cat > "$SB/nosurf/bin/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LOG:?}"
case "${1:-}" in
  --version) printf '1.18.29\n' ;;
  *) printf 'opencode — no subcommands here\n' >&2 ;;
esac
STUB
chmod +x "$SB/nosurf/bin/opencode"

# ---------------------------------------------------------------------------- 0. surface
say ""
say "0. the script is valid bash and documents both modes and the whole §5 set"
bash -n "$SUT" && ok "bash -n is clean" || no "bash -n reports a syntax error"
help_out="$(env -i PATH=/usr/bin:/bin HOME="$SB/home" /bin/bash "$SUT" --help 2>&1)"
missing=""
for v in CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE \
         CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S; do
  printf '%s' "$help_out" | grep -q -- "$v" || missing="$missing $v"
done
[ -z "$missing" ] && ok "--help names all 12 §5 variables" \
  || no "--help does not document:$missing"
if printf '%s' "$help_out" | grep -q -- '--check' && printf '%s' "$help_out" | grep -q -- '--apply'; then
  ok "--help documents --check and --apply"
else
  no "--help does not document both modes"
fi

# ---------------------------------------------------------------------------- A. refusals
say ""
say "A. refusals name the rule, touch nothing, and never echo the value"
O="$SB/a1.out"; rc=$(runp "$SB/nobin" "$SB/home" "$O" --check --api-key "$SYNTH_KEY")
if [ "$rc" = "2" ] && grep -qF 'CONTRACT: REFUSED' "$O" && grep -qF 'credential_argv' "$O"; then
  ok "A1 --api-key <value> is refused (exit 2) and named"
else
  no "A1 --api-key <value> was not refused by name (exit $rc)"
fi
grep -qF -- "$SYNTH_KEY" "$O" && no "A1 the credential value was echoed into the output" \
  || ok "A1 the credential value never appears in the output"

O="$SB/a2.out"; rc=$(runp_env "$SB/nobin" "$SB/home" "$O" "CF_API_KEY=$SYNTH_KEY" --check)
if [ "$rc" = "2" ] && grep -qF 'refused — CF_API_KEY is a VALUE' "$O"; then
  ok "A2 CF_API_KEY in the environment is refused (exit 2)"
else
  no "A2 CF_API_KEY in the environment was not refused (exit $rc)"
fi
grep -qF -- "$SYNTH_KEY" "$O" && no "A2 the ambient credential value was echoed" \
  || ok "A2 the ambient credential value never appears in the output"

O="$SB/a3.out"; rc=$(runp_env "$SB/nobin" "$SB/home" "$O" "OPENAI_API_KEY=$SYNTH_KEY" --check)
if [ "$rc" = "2" ] && grep -qF 'OPENAI_API_KEY is set in the ambient environment' "$O"; then
  ok "A3 an ambient OPENAI_API_KEY is refused by name (exit 2)"
else
  no "A3 an ambient OPENAI_API_KEY was not refused by name (exit $rc)"
fi

O="$SB/a4.out"; rc=$(runp "$SB/nobin" "$SB/home" "$O" --check --workdir /etc)
if [ "$rc" = "2" ] && grep -qF 'outside' "$O" && grep -qF 'CF_WORKDIR' "$O"; then
  ok "A4 a --workdir outside \$HOME is refused by name (exit 2)"
else
  no "A4 a --workdir outside \$HOME was not refused by name (exit $rc)"
fi

O="$SB/a5.out"; rc=$(runp "$SB/nobin" "$SB/home" "$O" --check --frobnicate)
if [ "$rc" = "2" ] && grep -qF "unknown argument" "$O"; then
  ok "A5 an unknown argument is refused (exit 2)"
else
  no "A5 an unknown argument was not refused (exit $rc)"
fi

O="$SB/a6.out"
rc=$(runp "$SB/nobin" "$SB/home" "$O" --contract --model m-1 --provider openai \
      --workdir "$SB/home/work" --namespace code-factory --run-id r-1 --lane cf-qa)
if [ "$rc" = "0" ] && grep -qF 'OPENCODE: CONTRACT PASS' "$O" \
   && grep -qF 'PASS  contract:required' "$O"; then
  ok "A6 --contract accepts the complete §5 run set (exit 0)"
else
  no "A6 --contract did not accept a complete run set (exit $rc)"
fi

# ---------------------------------------------------------------------------- B. absent binary
say ""
say "B. an absent binary is a named FAIL, not a quiet PASS"
O="$SB/b1.out"; rc=$(runp "$SB/nobin" "$SB/home" "$O" --check)
if [ "$rc" = "1" ] && grep -qF 'FAIL  binary — absent' "$O" \
   && ! grep -q '^  PASS  version' "$O" && ! grep -q '^  PASS  non_interactive' "$O" \
   && grep -qF 'OPENCODE: FAIL (1)' "$O"; then
  ok "B1 exit 1 with 'FAIL binary — absent' and no PASS row that needs a binary"
else
  no "B1 the absent-binary path did not report absence by name (exit $rc)"
fi
grep -q '^  PASS  [a-z_]* — $' "$O" && no "B1 a PASS row carried an empty measured value" \
  || ok "B1 no PASS row carried an empty value"

# ---------------------------------------------------------------------------- C. v1 stub
say ""
say "C. a v1 stub whose help goes to stderr is measured, not warned about"
O="$SB/c1.out"; rc=$(runp "$SB/v1/bin" "$SB/home" "$O" --check)
if [ "$rc" = "3" ] && grep -qF "PASS  binary — $SB/v1/bin/opencode" "$O" \
   && grep -qF 'PASS  version — 1.18.29' "$O" \
   && grep -qF 'PASS  generation — v1 (measured 1.18.29)' "$O" \
   && grep -qF 'PASS  non_interactive — the `run` surface is advertised' "$O" \
   && grep -qF 'WARN  user_space_binary' "$O" \
   && grep -qF 'OPENCODE: UNVERIFIED' "$O" && ! grep -qF 'OPENCODE: PASS' "$O"; then
  ok "C1 version, generation and non_interactive are each measured and quoted (exit 3: a PATH stub is not a \$HOME install, so UNVERIFIED — never PASS)"
else
  no "C1 the v1 stub was not measured on every row (exit $rc)"
  printf '%s\n' "$(printf '%s\n' "$(sed -n '/PASS\|WARN\|FAIL/p' "$O")" | sed 's/^/    | /')"
fi
if grep -qF -- '--version' "$SB/stub.log" && grep -qF -- 'run --help' "$SB/stub.log"; then
  ok "C2 the resolved binary is the one that executed the probes (its own call log)"
else
  no "C2 the stub's call log does not show the probes it answered"
fi

# C3 — the red control. The adapter as it shipped before this change (45bd4bd) reads --help from
# stdout only, so on this same stub it warns while the surface is there. Proving that keeps C1 from
# passing on a file that never measured anything.
mkdir -p "$SB/prefix/scripts/harness"
ln -sfn "$HERE_REPO/scripts/lib.sh" "$SB/prefix/scripts/lib.sh"
ln -sfn "$HERE_REPO/scripts/harness/harness-vars.sh" "$SB/prefix/scripts/harness/harness-vars.sh"
if git -C "$HERE_REPO" show "$PREFIX_SHA:scripts/harness/install-opencode.sh" \
     > "$SB/prefix/scripts/harness/install-opencode.sh" 2>/dev/null \
   && [ -s "$SB/prefix/scripts/harness/install-opencode.sh" ]; then
  pref_out="$(env -i PATH="$SB/v1/bin:/usr/bin:/bin" HOME="$SB/home" \
    /bin/bash "$SB/prefix/scripts/harness/install-opencode.sh" --check 2>&1)"
  if printf '%s\n' "$pref_out" | grep -qF 'WARN  non_interactive — could not confirm a non-interactive mode' \
     && ! printf '%s\n' "$pref_out" | grep -q '^  PASS  non_interactive'; then
    ok "C3 the pre-fix adapter ($PREFIX_SHA) warns on the same stub — C1 is a real change"
  else
    no "C3 the pre-fix adapter did not reproduce the false negative, so C1 proves nothing"
  fi
  printf '%s\n' "$pref_out" | grep -q '^  PASS  generation' \
    && no "C3 the pre-fix adapter already printed a generation row" \
    || ok "C3 the pre-fix adapter printed no generation row — that row is new"
else
  skip "C3 the pre-fix adapter is not readable from git ($PREFIX_SHA) — red control not reproduced"
fi

# ---------------------------------------------------------------------------- D. v2 stub
say ""
say "D. the generation row follows the measured version, whichever stream the help uses"
O="$SB/d1.out"; rc=$(runp "$SB/v2/bin" "$SB/home" "$O" --check)
if [ "$rc" = "3" ] && grep -qF 'PASS  version — 2.3.1' "$O" \
   && grep -qF 'PASS  generation — v2 (measured 2.3.1)' "$O" \
   && grep -qF 'PASS  non_interactive — the `run` surface is advertised' "$O" \
   && grep -qF 'OPENCODE: UNVERIFIED' "$O"; then
  ok "D1 a v2 binary is reported as v2 (exit 3: the PATH stub is not an owned install, so UNVERIFIED)"
else
  no "D1 a v2 binary was not reported as v2 (exit $rc)"
fi

# ---------------------------------------------------------------------------- E. empty version
say ""
say "E. a binary that answers no --version gets WARN rows, never an empty PASS"
O="$SB/e1.out"; rc=$(runp "$SB/nover/bin" "$SB/home" "$O" --check)
if [ "$rc" = "3" ] && grep -qF 'WARN  version — binary answered no --version' "$O" \
   && grep -qF 'WARN  generation — no measured version' "$O" \
   && grep -qF 'OPENCODE: UNVERIFIED' "$O" && ! grep -qF 'OPENCODE: PASS' "$O" \
   && ! grep -q '^  PASS  version' "$O" && ! grep -q '^  PASS  generation' "$O"; then
  ok "E1 the unmeasurable version is a named WARN (exit 3, OPENCODE: UNVERIFIED), not a PASS with no value"
else
  no "E1 an unmeasurable version did not warn by name (exit $rc)"
fi

# ---------------------------------------------------------------------------- F. no surface
say ""
say "F. a binary that advertises no surface is warned about, naming both probes"
O="$SB/f1.out"; rc=$(runp "$SB/nosurf/bin" "$SB/home" "$O" --check)
if [ "$rc" = "3" ] \
   && grep -qF 'WARN  non_interactive — neither `--help` nor `run --help` advertises run/exec/serve, on stdout or stderr' "$O" \
   && grep -qF 'OPENCODE: UNVERIFIED' "$O" && ! grep -qF 'OPENCODE: PASS' "$O"; then
  ok "F1 the absent surface is named with both probes (exit 3, OPENCODE: UNVERIFIED)"
else
  no "F1 the absent surface was not named with both probes (exit $rc)"
fi

# ---------------------------------------------------------------------------- G. apply refusal
say ""
say "G. --apply refuses by name and installs nothing"
G_HOME="$SB/ghome"; mkdir -p "$G_HOME"
O="$SB/g1.out"; rc=$(runp "$SB/v1/bin" "$G_HOME" "$O" --apply)
placed="$(find "$G_HOME" -type f -perm -u+x 2>/dev/null | wc -l)"
if [ "$rc" = "1" ] && grep -qF 'FAIL  apply — refused' "$O" \
   && grep -qF 'ladder' "$O" && [ "$placed" = "0" ] \
   && ! grep -q '^  PASS  install' "$O"; then
  ok "G1 --apply refused by name (exit 1), placed $placed executable(s), no install row"
else
  no "G1 --apply did not refuse cleanly (exit $rc, ${placed:-?} executable(s) placed)"
fi

# ---------------------------------------------------------------------------- H. owned prefix
say ""
say "H. a binary under the \$HOME prefix is resolved even when PATH cannot see it"
H_HOME="$SB/hhome"; mkdir -p "$H_HOME/.opencode/bin"
cp "$SB/v1/bin/opencode" "$H_HOME/.opencode/bin/opencode"
O="$SB/h1.out"; rc=$(runp "$SB/nobin" "$H_HOME" "$O" --check)
if [ "$rc" = "0" ] && grep -qF "PASS  binary — $H_HOME/.opencode/bin/opencode" "$O" \
   && grep -qF 'PASS  user_space_binary' "$O" && grep -qF 'PASS  version — 1.18.29' "$O" \
   && grep -qF 'OPENCODE: PASS' "$O" \
   && ! grep -qF 'binary_provenance' "$O"; then
  ok "H1 the \$HOME-owned binary is named by path and measured — every row PASS, 'OPENCODE: PASS', exit 0"
else
  no "H1 a \$HOME-owned binary that is not on PATH was not measured (exit $rc)"
fi

# Explicit requests use a different seam from measuring an installed binary.
O="$SB/v2-request.out"; rc=$(runp "$SB/v1/bin" "$SB/home" "$O" --check --generation v2)
if [ "$rc" = 2 ] && grep -qF 'CRIER-HARNESS-10: opencode v2 request refused' "$O"; then
  ok "I1 v2 request is refused by name"
else
  no "I1 v2 request was not refused by name (exit $rc)"
fi
O="$SB/v1-request.out"; rc=$(runp "$SB/nobin" "$H_HOME" "$O" --check --generation=v1)
if [ "$rc" = 0 ] && grep -qF 'PASS  version — 1.18.29' "$O"; then
  ok "I2 explicit v1 request measures the owned fixture"
else
  no "I2 explicit v1 request failed (exit $rc)"
fi
O="$SB/repeated-request.out"; rc=$(runp "$SB/v1/bin" "$SB/home" "$O" --check --generation v2 --generation v1)
if [ "$rc" = 2 ] && grep -qF 'FAIL  generation' "$O"; then
  ok "I3 duplicate generation requests are refused"
else
  no "I3 duplicate generation request was accepted (exit $rc)"
fi

O="$SB/v1-wrong-binary.out"; rc=$(runp "$SB/v2/bin" "$SB/home" "$O" --check --generation v1)
if [ "$rc" = 1 ] && grep -qF 'FAIL  generation — requested v1 but measured v2 (2.3.1)' "$O"; then
  ok "I4 explicit v1 rejects a measured v2 binary"
else
  no "I4 explicit v1 did not reject a v2 binary (exit $rc)"
fi

# ---------------------------------------------------------------------------- summary
say ""
say "summary: $PASS pass, $FAIL fail, $SKIP skip"
[ "$FAIL" -eq 0 ] && { say "OPENCODE ADAPTER: PASS"; exit 0; }
say "OPENCODE ADAPTER: FAIL ($FAIL)"
exit 1

#!/usr/bin/env bash
# tests/harness/dsh-install-test.sh — standalone proof for CF-226.
#
# Proves five things about scripts/harness/install-dsh.sh, each of which can FAIL:
#   (0) --help documents the whole §5 set, states the path-not-value rule, and states how an RC
#       pin is re-measured;
#   (a) --check on a HOME with no install names the missing package/binary honestly, exits
#       non-zero, and CREATES NOTHING in $DSH_HOME (the pinned launcher scaffolds a profile when it
#       composes, so a --check that composes in place would not be read-only);
#   (b) a credential VALUE, an ambient DEEPSEEK_API_KEY, a mode-644 key file and a workdir outside
#       $HOME are each refused by name, and no value is ever echoed;
#   (c) --apply is idempotent — a second run changes nothing on disk. This arm downloads 858 MB, so
#       it runs only with CF_DSH_TEST_APPLY=1; otherwise it SKIPs and names the knob.
#   (d) a PLUGIN-LAYER failure is reported per layer, naming the layer: a profile whose patch layer
#       disables `llm` must FAIL layer:enabled naming llm, and a profile declaring a bundle that is
#       not installed must FAIL layer:package naming the bundle. Later layers must say "not
#       measured", never "broken".
#   (e) if a DeepSeek credential is obtainable on this host, ONE real turn writes the fixed token
#       and reports the model dsh recorded; if not, SKIP naming exactly what is missing. A skipped
#       turn is never reported as a pass, and no turn is ever simulated.
#
#   bash tests/harness/dsh-install-test.sh                        # arms 0,1,2,4,5 (no install)
#   CF_DSH_TEST_APPLY=1 bash tests/harness/dsh-install-test.sh    # also prove --apply idempotence
#   KEEP=1 bash tests/harness/dsh-install-test.sh                 # keep the scratch tree
#
# Exit: 0 all legs passed (SKIP is not a failure), 1 any leg failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
SUT="$HERE/scripts/harness/install-dsh.sh"

PASSED=0
FAILED=0
SKIPPED=0

pass() { printf '  PASS  %s\n' "$*"; PASSED=$((PASSED+1)); }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=$((FAILED+1)); }
skip() { printf '  SKIP  %s\n' "$*"; SKIPPED=$((SKIPPED+1)); }
head_() { printf '\n%s\n' "$*"; }

[ -f "$SUT" ] || { printf 'no such subject: %s\n' "$SUT" >&2; exit 1; }
bash -n "$SUT" 2>/dev/null || { printf '%s is not valid bash\n' "$SUT" >&2; exit 1; }

PIN=$(sed -n 's/^DSH_PIN="\([^"]*\)".*/\1/p' "$SUT" | head -1)
[ -n "$PIN" ] || { printf 'cannot read DSH_PIN from %s\n' "$SUT" >&2; exit 1; }
case "$PIN" in
  *-*) pass "the pin is an exact RC version ($PIN), not a range" ;;
  *)   fail "the pin '$PIN' carries no prerelease tag — this harness is an RC and must be pinned as one" ;;
esac

# The subject refuses a CF_WORKDIR outside $HOME (§5), so the scratch tree lives inside $HOME too:
# a test that stages its fixture where its subject must refuse would measure the fixture, not the
# subject. Removed on exit unless KEEP=1.
WORK="$(mktemp -d "$HOME/.cf226-dsh-test.XXXXXX")" || exit 1
SCRATCH_HOME="$WORK/home"
mkdir -p "$SCRATCH_HOME"
cleanup() { [ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"; }
trap cleanup EXIT

printf 'CF-226 dsh installer test\n'
printf '  subject : %s\n' "$SUT"
printf '  pin     : %s\n' "$PIN"
printf '  scratch : %s\n' "$WORK"

# ------------------------------------------------------------------ (0) help / contract docs

head_ "0. --help documents the §5 contract, the path rule and the RC re-measure path"
help_out=$("$SUT" --help 2>&1)
missing_docs=""
for v in CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE \
         CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S; do
  printf '%s' "$help_out" | grep -q -- "$v" || missing_docs="$missing_docs $v"
done
[ -z "$missing_docs" ] && pass "--help names all 12 §5 variables" \
  || fail "--help does not document:$missing_docs"
printf '%s' "$help_out" | grep -qi 'never a value\|PATH to a mode-600' \
  && pass "--help states that a credential is a path, not a value" \
  || fail "--help does not state the credential-as-path rule"
printf '%s' "$help_out" | grep -q -- '--pin-status' \
  && pass "--help documents the RC re-measure mode (--pin-status)" \
  || fail "--help does not document how the RC pin is re-measured"
printf '%s' "$help_out" | grep -q -- '--layers' \
  && pass "--help documents the per-layer diagnosis (--layers)" \
  || fail "--help does not document the per-layer diagnosis"

# ------------------------------------------------------------------ (a) honest absence, read-only

head_ "1. --check on a HOME with no install: honest absence, non-zero, and nothing written"
out=$(HOME="$SCRATCH_HOME" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "--check exits non-zero when the pin is absent (exit $rc)" \
  || fail "--check exited 0 with nothing installed"
printf '%s' "$out" | grep -q '^  FAIL  package — absent' \
  && pass "the package row says 'absent'" \
  || fail "the package row does not say 'absent'; got: $(printf '%s' "$out" | grep 'package' | head -1)"
printf '%s' "$out" | grep -q '^  FAIL  binary — absent' \
  && pass "the binary row says 'absent'" \
  || fail "the binary row does not say 'absent'"
printf '%s' "$out" | grep -q 'DSH: FAIL' && pass "the summary is FAIL, not PASS" \
  || fail "the summary is not FAIL"
printf '%s' "$out" | grep -q "pin $PIN" && pass "--check names the pin it expects ($PIN)" \
  || fail "--check does not name the pin ($PIN)"

RO_HOME="$WORK/ro-home"
mkdir -p "$RO_HOME"
HOME="$SCRATCH_HOME" DSH_HOME="$RO_HOME" "$SUT" --check >/dev/null 2>&1
if [ -z "$(find "$RO_HOME" -mindepth 1 2>/dev/null | head -1)" ]; then
  pass "--check created nothing in \$DSH_HOME (composition ran against a throwaway copy)"
else
  fail "--check wrote into \$DSH_HOME: $(find "$RO_HOME" -mindepth 1 | head -3 | tr '\n' ' ')"
fi

# ------------------------------------------------------------------ (b) refusals

head_ "2. credential and path refusals name the rule and never echo the value"
# A credential-shaped fixture, assembled from parts so no line in this file is itself a
# credential literal the secret scanner must judge (the repo allowlists specs/docs, not tests/).
FAKE_KEY="sk-$(printf 'cf226-%s' 'not-a-real-credential-0123456789')"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$FAKE_KEY" "$SUT" --check 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "a credential VALUE in CF_API_KEY_FILE is refused with exit 2 (exit $rc)" \
  || fail "a credential value was not refused with exit 2 (exit $rc)"
printf '%s' "$out" | grep -q 'VALUE was passed, not a path' \
  && pass "the refusal distinguishes a value from a path" \
  || fail "the refusal does not distinguish value from path"
printf '%s' "$out" | grep -qF -- "$FAKE_KEY" \
  && fail "the credential value was echoed into the output (leak)" \
  || pass "the credential value never appears in the output"

out=$(HOME="$SCRATCH_HOME" DEEPSEEK_API_KEY="synthetic-ambient-not-a-real-key" "$SUT" --check 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "an ambient DEEPSEEK_API_KEY is refused with exit 2 (exit $rc)" \
  || fail "an ambient DEEPSEEK_API_KEY was accepted (exit $rc)"
printf '%s' "$out" | grep -q 'DEEPSEEK_API_KEY is set in the ambient environment' \
  && pass "the refusal names the ambient key and the rule it breaks" \
  || fail "the ambient refusal does not name DEEPSEEK_API_KEY"
printf '%s' "$out" | grep -qF -- 'synthetic-ambient-not-a-real-key' \
  && fail "the ambient key value was echoed into the output (leak)" \
  || pass "the ambient key value never appears in the output"

key644="$WORK/key-0644"
printf 'not-a-real-key-just-a-fixture\n' > "$key644"
chmod 644 "$key644"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$key644" "$SUT" --check 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "a world-readable key file (644) is refused (exit $rc)" \
  || fail "a 644 key file was accepted (exit $rc)"
printf '%s' "$out" | grep -q 'mode 644' && pass "the refusal measures the mode (644)" \
  || fail "the refusal does not name the measured mode"

key600="$WORK/key-0600"
printf 'not-a-real-key-just-a-fixture\n' > "$key600"
chmod 600 "$key600"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$key600" "$SUT" --check 2>&1)
printf '%s' "$out" | grep -q 'PASS  contract:CF_API_KEY_FILE' \
  && pass "a mode-600 path is accepted (paths pass, values do not)" \
  || fail "a valid mode-600 key path was not accepted"

out=$(HOME="$SCRATCH_HOME" CF_WORKDIR=/etc "$SUT" --check 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "a CF_WORKDIR outside \$HOME is refused (exit $rc)" \
  || fail "a workdir outside \$HOME was accepted (exit $rc)"

out=$(HOME="$SCRATCH_HOME" CF_HARNESS_OPTS='profile=../etc' "$SUT" --check 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "a profile name in CF_HARNESS_OPTS that is not a name is refused (exit $rc)" \
  || fail "a path-shaped profile name was accepted (exit $rc)"

# ------------------------------------------------------------------ (c) install + idempotency

head_ "3. --apply installs the pin user-space, and a second run changes nothing"
if [ "${CF_DSH_TEST_APPLY:-0}" != "1" ]; then
  skip "--apply idempotence not attempted: it installs a 618-package, 858 MB tree; set CF_DSH_TEST_APPLY=1 to run it"
else
  fingerprint() { find "$1" -printf '%p|%s|%T@\n' 2>/dev/null | LC_ALL=C sort | sha256sum | cut -d' ' -f1; }
  out=$(HOME="$SCRATCH_HOME" "$SUT" --apply 2>&1); rc=$?
  printf '%s\n' "$out" | sed 's/^/        /'
  [ "$rc" -eq 0 ] && pass "--apply exits 0 (first run)" || fail "--apply exited $rc on the first run"
  PREFIX="$SCRATCH_HOME/.local/harness/dsh"
  [ -x "$PREFIX/bin/dsh" ] && pass "the launcher is at \$HOME/.local/harness/dsh/bin/dsh (user-space)" \
    || fail "no launcher at $PREFIX/bin/dsh after --apply"
  printf '%s' "$out" | grep -q "PASS  provenance" && pass "registry integrity + shasum verified before download" \
    || fail "provenance was not verified"
  printf '%s' "$out" | grep -q "version_readback.*$PIN" && pass "the version was read back and matches the pin ($PIN)" \
    || fail "no version read back matching pin $PIN"
  before=$(fingerprint "$PREFIX")
  out2=$(HOME="$SCRATCH_HOME" "$SUT" --apply 2>&1); rc2=$?
  after=$(fingerprint "$PREFIX")
  [ "$rc2" -eq 0 ] && pass "--apply exits 0 on the second run (idempotent)" \
    || fail "--apply exited $rc2 on the second run"
  printf '%s' "$out2" | grep -q 'already installed at pin' \
    && pass "the second run says 'already installed at pin' (no npm call)" \
    || fail "the second run did not report an installed pin"
  [ -n "$before" ] && [ "$before" = "$after" ] \
    && pass "the installed tree is byte-for-byte unchanged ($before)" \
    || fail "the second run changed the installed tree ($before -> $after)"
  rm -rf "$SCRATCH_HOME/.local/harness/dsh"
fi

# ------------------------------------------------------------------ (d) per-layer attribution

head_ "4. a plugin-layer failure is reported PER LAYER, naming the layer"
# These arms need the pin: they boot the real launcher against a scratch DSH_HOME. If the pin is
# not installed in the real HOME, the arm SKIPs and names what is missing — it never fakes a boot.
if HOME="$HOME" "$SUT" --check >/dev/null 2>&1; then
  # 4a: a patch layer that disables a plugin the tree needs. The pin names what waits on it.
  LAY="$WORK/layer-disabled"
  mkdir -p "$LAY"
  DSH_HOME="$LAY" "$SUT" --apply >/dev/null 2>&1      # idempotent install path + profile scaffold
  if [ -f "$LAY/profiles/headless/cordis.patch.yml" ]; then
    printf -- '- id: llm\n  disabled: true\n' > "$LAY/profiles/headless/cordis.patch.yml"
    out=$(DSH_HOME="$LAY" "$SUT" --layers 2>&1); rc=$?
    [ "$rc" -eq 1 ] && pass "a disabled required plugin fails --layers (exit $rc)" \
      || fail "a disabled required plugin did not fail --layers (exit $rc)"
    printf '%s' "$out" | grep -q '^  FAIL  layer:enabled' \
      && pass "the failing layer is named: layer:enabled" \
      || fail "the failure is not attributed to layer:enabled; got: $(printf '%s' "$out" | grep -E '^  FAIL' | head -2 | tr '\n' ' ')"
    printf '%s' "$out" | grep -q "plugin(s) llm DISABLED" \
      && pass "the row names the disabled plugin (llm)" \
      || fail "the row does not name the disabled plugin"
    printf '%s' "$out" | grep -q 'agent-loop→llm' \
      && pass "the row quotes the pin's own waiting table (what depends on the missing service)" \
      || fail "the row does not quote the pin's waiting table"
    printf '%s' "$out" | grep -q 'layer:tool, layer:permission — not measured' \
      && pass "layers after the failing one are 'not measured', not 'broken'" \
      || fail "later layers are not reported as not measured"
    printf '%s' "$out" | grep -qi 'dsh is broken' \
      && fail "the failure was reported as 'dsh is broken'" \
      || pass "the failure is never reported as 'dsh is broken'"
  else
    skip "protocol: DSH_HOME=$LAY was not scaffolded, so the disabled-plugin arm could not run"
  fi

  # 4b: a profile that declares a bundle which is not installed. Measured: the pin SKIPS it, says so
  # on stderr, and STILL EXITS 0 — so the attribution has to come from the composition, not the code.
  LPKG="$WORK/layer-bundle"
  mkdir -p "$LPKG"
  DSH_HOME="$LPKG" "$SUT" --apply >/dev/null 2>&1
  if [ -f "$LPKG/profiles/headless/package.json" ]; then
    cat > "$LPKG/profiles/headless/package.json" <<'JSON'
{
  "name": "dsh-profile-headless",
  "private": true,
  "dependencies": {},
  "dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-missing-bundle"] } }
}
JSON
    out=$(DSH_HOME="$LPKG" "$SUT" --layers 2>&1); rc=$?
    [ "$rc" -eq 1 ] && pass "an unresolvable bundle fails --layers (exit $rc)" \
      || fail "an unresolvable bundle did not fail --layers (exit $rc)"
    printf '%s' "$out" | grep -q '^  FAIL  layer:package' \
      && pass "the failing layer is named: layer:package" \
      || fail "the bundle failure is not attributed to layer:package"
    printf '%s' "$out" | grep -q '@deepseek-ai/dsh-missing-bundle' \
      && pass "the row names the bundle that did not resolve" \
      || fail "the row does not name the unresolvable bundle"
    out=$(DSH_HOME="$LPKG" "$SUT" --check 2>&1); rc=$?
    [ "$rc" -ne 0 ] && pass "--check also fails on the partial tree (exit $rc), rather than trusting the exit code" \
      || fail "--check passed on a partial tree — exit 0 from --dump-config was taken as evidence"
    printf '%s' "$out" | grep -q 'bundle(s) did not resolve' \
      && pass "--check names the unresolved bundle from the composition's stderr" \
      || fail "--check does not report the unresolved bundle"
  else
    skip "protocol: DSH_HOME=$LPKG was not scaffolded, so the missing-bundle arm could not run"
  fi
else
  skip "the pin is not installed in \$HOME ($HOME/.local/harness/dsh), so no boot can be measured for the layer arms"
fi

# ------------------------------------------------------------------ (e) one real turn, or a SKIP

head_ "5. one real turn producing a fixed token (or an honest SKIP)"
KEYFILE=""
STAGED_KEY=""
if [ -n "${CF_API_KEY_FILE:-}" ] && [ -s "${CF_API_KEY_FILE:-}" ]; then
  KEYFILE="$CF_API_KEY_FILE"
elif [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  # The contract is a PATH: an exported key is staged into a 0600 file under the scratch tree,
  # never printed, and removed on exit. A value in argv is the thing this contract forbids.
  KEYFILE="$WORK/deepseek-key"
  (umask 077; printf '%s' "$DEEPSEEK_API_KEY" > "$KEYFILE")
  chmod 600 "$KEYFILE"
  STAGED_KEY="$KEYFILE"
fi
TURN_WORK="$WORK/turn-workdir"
mkdir -p "$TURN_WORK"

if [ -z "$KEYFILE" ]; then
  skip "no DeepSeek credential on this host — missing both CF_API_KEY_FILE and DEEPSEEK_API_KEY (checked HOME=$HOME); --turn would SKIP with exit 3"
  # The exact invocation the CF-226 verdict reproduced: no credential, and none of the §5 run set
  # either. The documented answer is the SKIP with exit 3 (specs/HARNESS.md "The verdict line"),
  # because a credential is a RUN input and the run set is only required of a turn that will run.
  #
  # It runs against a HOME holding a STUB launcher that reports the pin. That measures the
  # ADAPTER's ordering — which gate is reached first — on every host, without a real credential, a
  # network call or a model turn. The stub logs each invocation, so "nothing was started" is
  # measured instead of asserted.
  STUB_HOME="$WORK/stub-home"
  STUB_LOG="$WORK/stub-invocations.log"
  mkdir -p "$STUB_HOME/.local/harness/dsh/bin"
  cat > "$STUB_HOME/.local/harness/dsh/bin/dsh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$STUB_LOG"
[ "\${1:-}" = "--version" ] && { printf '%s\n' "$PIN"; exit 0; }
exit 1
STUB
  chmod +x "$STUB_HOME/.local/harness/dsh/bin/dsh"
  # stub_ran_only_version — true when the launcher was called at most for --version, i.e. the
  # adapter never booted a profile. An absent or empty log is the strongest form of that.
  stub_ran_only_version() {
    [ -s "$STUB_LOG" ] || return 0
    ! grep -qvx -- '--version' "$STUB_LOG"
  }
  SCRUB=(env -u DEEPSEEK_API_KEY -u CF_API_KEY_FILE -u CF_API_KEY -u DSH_API_KEY
         -u CF_MODEL -u CF_PROVIDER -u CF_WORKDIR -u CF_NAMESPACE -u CF_RUN_ID -u CF_LANE)
  out=$(HOME="$STUB_HOME" "${SCRUB[@]}" "$SUT" --turn --prompt 'noop' 2>&1); rc=$?
  [ "$rc" -eq 3 ] && pass "--turn reports SKIP with exit 3 when no credential exists (exit $rc)" \
    || fail "--turn returned $rc instead of skip-exit 3"
  printf '%s' "$out" | grep -q 'DSH: SKIP' && pass "the summary says SKIP, not PASS" \
    || fail "the summary is not SKIP"
  printf '%s' "$out" | grep -q 'DSH: PASS' && fail "a skipped turn was reported as PASS" \
    || pass "a skipped turn is never reported as PASS"
  printf '%s' "$out" | grep -q 'CF_API_KEY_FILE' && pass "the SKIP names the missing input" \
    || fail "the SKIP does not name what is missing"
  # The defect CF-226 was reworked for: the run-set check must not pre-empt the credential gate.
  printf '%s' "$out" | grep -q 'contract:required' \
    && fail "--turn refused the §5 run set before the credential gate (contract:required), so it never reached the SKIP path" \
    || pass "the run-set check does not pre-empt the credential gate (no contract:required row)"
  if stub_ran_only_version; then
    pass "the skipped turn started nothing (the only launcher call was --version)"
  else
    fail "the skipped turn invoked the launcher beyond --version: $(tr '\n' ';' < "$STUB_LOG" 2>/dev/null)"
  fi
  # The other half of the same rule: a credential PATH means the turn WILL run, so an incomplete §5
  # run set is still refused by name — exit 2, and nothing is started.
  : > "$STUB_LOG"
  out=$(HOME="$STUB_HOME" "${SCRUB[@]}" CF_API_KEY_FILE="$key600" \
    "$SUT" --turn --prompt 'noop' 2>&1); rc=$?
  [ "$rc" -eq 2 ] && pass "a credential-present --turn with no §5 run set is still refused (exit $rc)" \
    || fail "a credential-present --turn missing the run set returned $rc, not the documented refusal (2)"
  printf '%s' "$out" | grep -q 'contract:required' \
    && pass "the refusal is contract:required, by name" \
    || fail "the refusal does not name contract:required"
  printf '%s' "$out" | grep -q 'CF_MODEL CF_PROVIDER CF_WORKDIR CF_NAMESPACE CF_RUN_ID CF_LANE' \
    && pass "the refusal names every missing §5 run-set variable" \
    || fail "the refusal does not name the missing run-set variables"
  if stub_ran_only_version; then
    pass "the refused turn started nothing (no profile boot)"
  else
    fail "a refused turn booted the harness anyway: $(tr '\n' ';' < "$STUB_LOG" 2>/dev/null)"
  fi
else
  out=$(CF_API_KEY_FILE="$KEYFILE" \
    CF_MODEL="${CF_MODEL:-deepseek-flash}" \
    CF_PROVIDER=deepseek \
    CF_WORKDIR="$TURN_WORK" \
    CF_NAMESPACE=code-factory \
    CF_RUN_ID="cf226-turn-$(date -u +%Y%m%dT%H%M%SZ)" \
    CF_LANE=code-factory-qa \
    CF_MAX_TURNS=6 \
    CF_TIMEOUT_S="${CF_TURN_TIMEOUT_S:-600}" \
    "$SUT" --turn 2>&1); rc=$?
  printf '%s\n' "$out" | sed 's/^/        /'
  proof="$TURN_WORK/dsh-turn.txt"
  if [ -f "$proof" ]; then
    pass "the turn produced dsh-turn.txt"
    grep -q 'CF-226-TOKEN-4e8b1d' "$proof" && pass "dsh-turn.txt contains the fixed token" \
      || fail "dsh-turn.txt does not contain the fixed token"
  else
    fail "the turn produced no dsh-turn.txt (exit $rc)"
  fi
  printf '%s' "$out" | grep -q 'PASS  model_served' && pass "the turn reported the model dsh recorded" \
    || fail "the turn did not report a model"
  printf '%s' "$out" | grep -q "turn/end reason.kind=completed" \
    && pass "the turn's outcome is quoted from dsh's own record" \
    || fail "the turn does not quote the pin's own outcome"
  # The pattern comes from a file, never from argv: a key on a command line is the thing this
  # contract forbids, including inside the test that checks for it.
  if [ -n "${STAGED_KEY:-}" ] && printf '%s' "$out" | grep -qF -f "$STAGED_KEY"; then
    fail "the credential value appeared in the turn output (leak)"
  else
    pass "the credential value never appears in the turn output"
  fi
  [ -n "${STAGED_KEY:-}" ] && rm -f "$STAGED_KEY"
fi

# ------------------------------------------------------------------ summary

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'DSH-INSTALL-TEST: PASS (%d passed, %d skipped)\n' "$PASSED" "$SKIPPED"
  exit 0
fi
printf 'DSH-INSTALL-TEST: FAIL (%d failed, %d passed, %d skipped)\n' "$FAILED" "$PASSED" "$SKIPPED"
exit 1

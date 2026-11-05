#!/usr/bin/env bash
# tests/harness/claude-code-install-test.sh — standalone proof for CF-225.
#
# Proves four things about scripts/harness/install-claude-code.sh, each of which can FAIL:
#   (a) --check names the missing binary honestly ("absent"), not a generic failure;
#   (b) a credential passed as a VALUE is refused, and the value is never echoed;
#   (c) --apply is idempotent — a second run changes nothing on disk;
#   (d) if a real Anthropic credential exists on this host, ONE real turn produces a file with a
#       fixed token; if not, SKIP naming the exact missing credential. A skipped turn is never
#       reported as a pass, and no turn is ever simulated.
#
# Runs against a scratch $HOME so it neither needs nor disturbs the host's install.
#   bash tests/harness/claude-code-install-test.sh          # normal
#   KEEP=1 bash tests/harness/claude-code-install-test.sh  # keep the scratch tree for inspection
#
# Exit: 0 all legs passed (SKIP is not a failure), 1 any leg failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
SUT="$HERE/scripts/harness/install-claude-code.sh"

PASSED=0
FAILED=0
SKIPPED=0

pass() { printf '  PASS  %s\n' "$*"; PASSED=$((PASSED+1)); }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=$((FAILED+1)); }
skip() { printf '  SKIP  %s\n' "$*"; SKIPPED=$((SKIPPED+1)); }
head_() { printf '\n%s\n' "$*"; }

[ -f "$SUT" ] || { printf 'no such subject: %s\n' "$SUT" >&2; exit 1; }

PIN=$(sed -n 's/^CLAUDE_CODE_PIN="\([^"]*\)".*/\1/p' "$SUT" | head -1)
[ -n "$PIN" ] || { printf 'cannot read CLAUDE_CODE_PIN from %s\n' "$SUT" >&2; exit 1; }

WORK="${TMPDIR:-/tmp}/cf225-claude-code-test.$$"
mkdir -p "$WORK" || exit 1
SCRATCH_HOME="$WORK/home"
mkdir -p "$SCRATCH_HOME"
cleanup() { [ "${KEEP:-0}" = "1" ] || rm -rf "$WORK"; }
trap cleanup EXIT

printf 'CF-225 claude-code installer test\n'
printf '  subject : %s\n' "$SUT"
printf '  pin     : %s\n' "$PIN"
printf '  scratch : %s\n' "$WORK"

# ------------------------------------------------------------------ (0) help/docs

head_ "0. --help documents the whole CF_* contract"
help_out=$("$SUT" --help 2>&1)
missing_docs=""
for v in CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE \
         CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S; do
  printf '%s' "$help_out" | grep -q -- "$v" || missing_docs="$missing_docs $v"
done
if [ -z "$missing_docs" ]; then
  pass "--help names all 12 §5 variables"
else
  fail "--help does not document:$missing_docs"
fi
if printf '%s' "$help_out" | grep -qi 'path'; then
  pass "--help states the credential rule (path, not value)"
else
  fail "--help does not state that a credential is a path"
fi

# ------------------------------------------------------------------ (a) honest absence

head_ "1. --check on a HOME with no install names the missing binary honestly"
out=$(HOME="$SCRATCH_HOME" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "--check exits non-zero when the pin is absent (exit $rc)" \
  || fail "--check exited 0 with no binary installed"
if printf '%s' "$out" | grep -q '^  FAIL  binary — absent'; then
  pass "the binary row says 'absent'"
else
  fail "the binary row does not say 'absent'; got: $(printf '%s' "$out" | grep 'binary' | head -1)"
fi
printf '%s' "$out" | grep -q 'CLAUDE-CODE: FAIL' && pass "the summary is FAIL, not PASS" \
  || fail "the summary is not FAIL"
printf '%s' "$out" | grep -q "pin $PIN" && pass "--check names the pin it expects ($PIN)" \
  || fail "--check does not name the pin ($PIN)"

head_ "1b. a host-provided binary on PATH never earns 'installed by this adapter'"
mkdir -p "$WORK/fakebin"
cat > "$WORK/fakebin/claude" <<'FAKE'
#!/usr/bin/env bash
printf '9.9.9 (Claude Code)\n'
FAKE
chmod +x "$WORK/fakebin/claude"
out=$(HOME="$SCRATCH_HOME" PATH="$WORK/fakebin:$PATH" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "a PATH binary outside the adapter's prefix exits non-zero (exit $rc)" \
  || fail "a host-provided binary was accepted as installed"
printf '%s' "$out" | grep -q 'host-provided' && pass "the binary row says 'host-provided'" \
  || fail "the binary row does not say 'host-provided'"
printf '%s' "$out" | grep -q '9.9.9' && pass "the measured version is named (9.9.9)" \
  || fail "the measured version is not named"
printf '%s' "$out" | grep -q "pin $PIN" && pass "the pin is named beside the mismatch ($PIN)" \
  || fail "the pin is not named beside the mismatch"

# ------------------------------------------------------------------ (b) credential refusals

head_ "2. a credential passed as a VALUE is refused (and never echoed)"
FAKE_KEY="credential-value-not-a-path-0123456789abcdef"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$FAKE_KEY" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "a value in CF_API_KEY_FILE exits non-zero (exit $rc)" \
  || fail "a credential value was accepted"
printf '%s' "$out" | grep -q 'refused' && pass "the refusal says 'refused'" \
  || fail "no refusal text"
printf '%s' "$out" | grep -q 'VALUE' && pass "the refusal explains it is a value, not a path" \
  || fail "the refusal does not distinguish value from path"
if printf '%s' "$out" | grep -qF "$FAKE_KEY"; then
  fail "the credential value was echoed into the output (leak)"
else
  pass "the credential value never appears in the output"
fi

out=$(HOME="$SCRATCH_HOME" ANTHROPIC_API_KEY="$FAKE_KEY" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "an ambient ANTHROPIC_API_KEY exits non-zero (exit $rc)" \
  || fail "an ambient key was accepted"
printf '%s' "$out" | grep -q 'ambient' && pass "the refusal names the ambient-contamination rule" \
  || fail "the ambient refusal does not name the rule"
if printf '%s' "$out" | grep -qF "$FAKE_KEY"; then
  fail "the ambient key value was echoed into the output (leak)"
else
  pass "the ambient key value never appears in the output"
fi

key644="$WORK/key-0644"
printf 'not-a-real-key-just-a-fixture\n' > "$key644"
chmod 644 "$key644"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$key644" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "a world-readable key file (644) exits non-zero (exit $rc)" \
  || fail "a 644 key file was accepted"
printf '%s' "$out" | grep -q 'mode 644' && pass "the refusal measures the mode (644)" \
  || fail "the refusal does not name the measured mode"

out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="ghp_SHORTfixturenotarealkey" "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "a known-prefix token (ghp_) is refused by the prefix rule (exit $rc)" \
  || fail "a ghp_ prefixed value was accepted by the prefix rule"

key600="$WORK/key-0600"
printf 'not-a-real-key-just-a-fixture\n' > "$key600"
chmod 600 "$key600"
out=$(HOME="$SCRATCH_HOME" CF_API_KEY_FILE="$key600" "$SUT" --check 2>&1); rc=$?
printf '%s' "$out" | grep -q 'PASS  contract:CF_API_KEY_FILE' \
  && pass "a mode-600 path is accepted (paths pass, values do not)" \
  || fail "a valid mode-600 key path was not accepted"
printf '%s' "$out" | grep -q 'content not read' \
  && pass "the accepted path is reported without reading its content" \
  || fail "the accepted path is not reported as not-read"

out=$(HOME="$SCRATCH_HOME" CF_WORKDIR=/etc "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "a CF_WORKDIR outside \$HOME exits non-zero (exit $rc)" \
  || fail "a workdir outside \$HOME was accepted"

# ------------------------------------------------------------------ (c) install + idempotency

head_ "3. --apply installs the pin user-space, and a second run changes nothing"
fingerprint() { find "$1" -printf '%p|%s|%T@\n' 2>/dev/null | LC_ALL=C sort | sha256sum | cut -d' ' -f1; }

out=$(HOME="$SCRATCH_HOME" "$SUT" --apply 2>&1); rc=$?
printf '%s\n' "$out" | sed 's/^/        /'
if [ "$rc" -eq 0 ]; then
  pass "--apply exits 0 (first run)"
else
  fail "--apply exited $rc on the first run"
fi
PREFIX="$SCRATCH_HOME/.local/harness/npm"
BIN="$PREFIX/bin/claude"
if [ -x "$BIN" ]; then
  pass "the binary is at \$HOME/.local/harness/npm/bin/claude (user-space)"
else
  fail "no binary at $BIN after --apply"
fi
if printf '%s' "$out" | grep -q "version_readback.*$PIN\|$PIN (Claude Code)"; then
  pass "the version was read back from the binary and matches the pin ($PIN)"
else
  fail "no version read back matching pin $PIN"
fi
if printf '%s' "$out" | grep -q 'PASS  provenance'; then
  pass "the registry metadata for the pin was verified before downloading"
else
  fail "provenance was not verified"
fi
case "$PREFIX" in
  "$SCRATCH_HOME"/*) pass "the npm prefix is under \$HOME (never root, never /usr)" ;;
  *) fail "the npm prefix is outside \$HOME: $PREFIX" ;;
esac

before=$(fingerprint "$PREFIX")
out2=$(HOME="$SCRATCH_HOME" "$SUT" --apply 2>&1); rc2=$?
after=$(fingerprint "$PREFIX")
[ "$rc2" -eq 0 ] && pass "--apply exits 0 on the second run (idempotent)" \
  || fail "--apply exited $rc2 on the second run"
printf '%s' "$out2" | grep -q 'already installed at pin' \
  && pass "the second run says 'already installed at pin' (no npm call)" \
  || fail "the second run did not report an installed pin: $(printf '%s' "$out2" | tail -3 | tr '\n' ' ')"
if [ -n "$before" ] && [ "$before" = "$after" ]; then
  pass "the installed tree is byte-for-byte unchanged (fingerprint $before)"
else
  fail "the second run changed the installed tree ($before -> $after)"
fi

out3=$(HOME="$SCRATCH_HOME" "$SUT" --check 2>&1); rc3=$?
[ "$rc3" -eq 0 ] && pass "--check now exits 0" || fail "--check still fails after --apply (exit $rc3)"
printf '%s' "$out3" | grep -q "PASS  version — $PIN" && pass "--check reports the measured version $PIN" \
  || fail "--check does not report the measured version $PIN"

# ------------------------------------------------------------------ (d) one real turn, or an honest SKIP

head_ "4. one real turn producing a fixed token (or an honest SKIP)"
STAGED_KEY=""
KEYFILE=""
OAUTH_ONLY=0
if [ -n "${CF_API_KEY_FILE:-}" ] && [ -s "${CF_API_KEY_FILE:-}" ]; then
  KEYFILE="$CF_API_KEY_FILE"
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  # Stage the exported key into a mode-600 file: the contract is a path, and a value in argv is
  # a FAIL. The value is written 0600 under the scratch tree, never printed, removed on exit.
  KEYFILE="$WORK/anthropic-key"
  (umask 077; printf '%s' "$ANTHROPIC_API_KEY" > "$KEYFILE")
  chmod 600 "$KEYFILE"
  STAGED_KEY="$KEYFILE"
elif [ -s "$HOME/.claude/.credentials.json" ]; then
  OAUTH_ONLY=1
fi

if [ -z "$KEYFILE" ]; then
  if [ "$OAUTH_ONLY" -eq 1 ]; then
    skip "an OAuth login exists at $HOME/.claude/.credentials.json, but --turn runs '--bare' (ANTHROPIC_API_KEY only, keychain never read): missing ANTHROPIC_API_KEY or CF_API_KEY_FILE"
  else
    skip "no Anthropic credential on this host — missing all of: ANTHROPIC_API_KEY, CF_API_KEY_FILE, ~/.claude/.credentials.json (checked HOME=$HOME)"
  fi
  out=$(HOME="$SCRATCH_HOME" env -u ANTHROPIC_API_KEY -u CF_API_KEY_FILE -u CF_API_KEY \
    "$SUT" --turn --prompt 'noop' 2>&1); rc=$?
  [ "$rc" -eq 3 ] && pass "--turn reports SKIP with exit 3 when no credential exists (exit $rc)" \
    || fail "--turn returned $rc instead of skip-exit 3 with no credential"
  for name in ANTHROPIC_API_KEY CF_API_KEY_FILE credentials.json; do
    printf '%s' "$out" | grep -q -- "$name" \
      && pass "the SKIP names $name" || fail "the SKIP does not name $name"
  done
  printf '%s' "$out" | grep -q 'CLAUDE-CODE: SKIP' && pass "the summary says SKIP, not PASS" \
    || fail "the summary is not SKIP"
  if printf '%s' "$out" | grep -q 'CLAUDE-CODE: PASS'; then
    fail "a skipped turn was reported as PASS"
  else
    pass "a skipped turn is never reported as PASS"
  fi
else
  TURN_WORK="$WORK/turn-workdir"
  mkdir -p "$TURN_WORK"
  out=$(HOME="$SCRATCH_HOME" \
    CF_API_KEY_FILE="$KEYFILE" \
    CF_MODEL="${CF_MODEL:-sonnet}" \
    CF_PROVIDER=anthropic \
    CF_WORKDIR="$TURN_WORK" \
    CF_NAMESPACE=code-factory \
    CF_RUN_ID="cf225-turn-$(date -u +%Y%m%dT%H%M%SZ)" \
    CF_LANE=code-factory-qa \
    CF_MAX_TURNS=6 \
    CF_TIMEOUT_S="${CF_TURN_TIMEOUT_S:-600}" \
    "$SUT" --turn --prompt 'Create a file named turn-proof.txt in the current directory whose entire content is the single line CF225-TURN-OK. Do nothing else.' 2>&1); rc=$?
  printf '%s\n' "$out" | sed 's/^/        /'
  proof="$TURN_WORK/turn-proof.txt"
  if [ -f "$proof" ]; then
    pass "the turn produced turn-proof.txt"
    grep -q 'CF225-TURN-OK' "$proof" && pass "turn-proof.txt contains the fixed token CF225-TURN-OK" \
      || fail "turn-proof.txt does not contain the fixed token"
  else
    fail "the turn produced no turn-proof.txt (exit $rc)"
  fi
  printf '%s' "$out" | grep -q 'PASS  model_served' && pass "the turn reported model_served" \
    || fail "the turn did not report model_served"
  # The pattern comes from a file (-f), never from argv: a key on a command line is the very
  # thing this contract forbids, including inside the test that checks for it.
  if [ -n "$STAGED_KEY" ] && printf '%s' "$out" | grep -qF -f "$STAGED_KEY"; then
    fail "the credential value appeared in the turn output (leak)"
  else
    pass "the credential value never appears in the turn output"
  fi
  [ -n "$STAGED_KEY" ] && rm -f "$STAGED_KEY"
fi

# ------------------------------------------------------------------ summary

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'CLAUDE-CODE-INSTALL-TEST: PASS (%d passed, %d skipped)\n' "$PASSED" "$SKIPPED"
  exit 0
fi
printf 'CLAUDE-CODE-INSTALL-TEST: FAIL (%d failed, %d passed, %d skipped)\n' "$FAILED" "$PASSED" "$SKIPPED"
exit 1

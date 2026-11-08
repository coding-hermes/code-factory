#!/usr/bin/env bash
# tests/harness/adapter-check-classification-test.sh — CF-006.
#
# A `--check` row must be classified by the question specs/HARNESS.md asks: "does the ABSENCE of
# the thing this row reports stop a run of the surface the adapter is measured on?" Two adapters
# answered that wrong, in opposite directions, and both made the conformance battery red on a host
# that had measured the harness:
#
#   claude-code  `auth`  a missing credential is a RUN input, not an install condition. The pin
#                        was installed and its version read back, and the adapter still ended
#                        `CLAUDE-CODE: UNVERIFIED` (exit 3) because no Anthropic credential
#                        existed — while its own usage contract says "--check … Exit 0 only when
#                        the pin is installed here", and `--turn` already reports the missing
#                        credential as `CLAUDE-CODE: SKIP (…)` exit 3. The row is a note now; an
#                        AMBIENT exported key is still refused (contamination blocks a run).
#
#   pi-agent     `credential_file`  the branch warned "a credential file is not a binary — the
#                        binary row above is the one that decides" while the binary row had just
#                        PASSed with a version. Its own text said the binary decides; the verdict
#                        said otherwise. With a measured binary the row is a note; with NO binary
#                        it stays a WARN beside the named `FAIL binary`.
#
# Each fixed arm is paired with the PRE-FIX adapter from the same fixture, so an arm cannot go
# green because the fixture changed. The negative arms (`ambient key`, `credential without a
# binary`) prove the fix did not silence a real blocker.
#
#   bash tests/harness/adapter-check-classification-test.sh
#   CF006_PREFIX_REV=<rev> bash tests/harness/adapter-check-classification-test.sh   # pre-fix tree
#
# Exit 0 only when every arm passes; a SKIP is used only when the pre-fix revision is unavailable.
set -uo pipefail
HERE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PREFIX_REV="${CF006_PREFIX_REV:-dc7641f}"

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$*"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$*"; }
say()  { printf '%s\n' "$*"; }

SB="$(mktemp -d "${TMPDIR:-/tmp}/cf006-classification.XXXXXXXX")"
cleanup() { rm -rf "$SB"; }
trap cleanup EXIT INT TERM

# A clean credential environment: an inherited key must never be what makes an arm pass.
clean_env() { env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u CLAUDE_CODE_OAUTH_TOKEN \
                  -u ANTHROPIC_BASE_URL -u ANTHROPIC_API_BASE_URL -u CF_API_KEY "$@"; }

# ---------------------------------------------------------------- pre-fix trees
# The pre-fix adapter sources scripts/lib.sh relative to itself, so each revision is placed in a
# minimal tree that carries the same lib.sh the tree uses today. A control that cannot run is a
# SKIP with the reason, never a silent green.
prefix_tree() {  # prefix_tree <dir> <adapter basename>
  local dir="$1" name="$2"
  mkdir -p "$dir/scripts/harness"
  cp "$HERE_REPO/scripts/lib.sh" "$dir/scripts/lib.sh" || return 1
  # Adapters that source the §5 contract need that file too; take the pre-fix revision where one
  # exists so the control is the whole old tree, not the old adapter against new helpers.
  if ! git -C "$HERE_REPO" show "$PREFIX_REV:scripts/harness/harness-vars.sh" >"$dir/scripts/harness/harness-vars.sh" 2>/dev/null; then
    cp "$HERE_REPO/scripts/harness/harness-vars.sh" "$dir/scripts/harness/harness-vars.sh" || return 1
  fi
  git -C "$HERE_REPO" show "$PREFIX_REV:scripts/harness/$name" >"$dir/scripts/harness/$name" 2>/dev/null \
    || { rm -rf "$dir"; return 1; }
  chmod +x "$dir/scripts/harness/$name"
}

say "adapter --check classification (CF-006) — pre-fix revision: $PREFIX_REV"

# ================================================================ claude-code
say ""
say "1. claude-code — a missing credential is a note; the install is what --check certifies"
CL_HOME="$SB/claude-home"
CL_BIN="$CL_HOME/.local/harness/npm/bin/claude"
mkdir -p "$(dirname "$CL_BIN")" "$SB/bin"
cat >"$CL_BIN" <<'CLSTUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf '2.1.318 (Claude Code)\n'; exit 0 ;;
  --help) printf 'claude [options]\n  --print  non-interactive\n'; exit 0 ;;
  *) exit 0 ;;
esac
CLSTUB
chmod +x "$CL_BIN"
# node/npm stand-ins: the adapter probes them and the pin's engines field needs node >= 22, which
# is host state this test does not want to depend on.
printf '#!/usr/bin/env bash\nprintf "v22.22.3\\n"\n' >"$SB/bin/node"
printf '#!/usr/bin/env bash\nprintf "10.9.8\\n"\n' >"$SB/bin/npm"
chmod +x "$SB/bin/node" "$SB/bin/npm"
CL_PATH="$SB/bin:/usr/local/bin:/usr/bin:/bin"

O="$SB/claude-check.out"
rc=$(clean_env HOME="$CL_HOME" PATH="$CL_PATH" "$HERE_REPO/scripts/harness/install-claude-code.sh" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "0" ] && grep -qx 'CLAUDE-CODE: PASS' "$O" \
   && grep -q '^  PASS  version — 2.1.318 (pin 2.1.318)' "$O" \
   && grep -q '^  \.\.    auth — no credential' "$O" \
   && [ "$(grep -c '^  WARN  ' "$O")" = 0 ]; then
  ok "claude-code: the pin installed with no credential reaches 'CLAUDE-CODE: PASS' (exit 0); auth is a note, 0 WARN rows"
else
  no "claude-code: --check did not reach PASS on an installed pin without a credential (rc=$rc)"; sed 's/^/        /' "$O" | tail -14
fi

if prefix_tree "$SB/prefix-claude" install-claude-code.sh; then
  O="$SB/claude-prefix.out"
  rc=$(clean_env HOME="$CL_HOME" PATH="$CL_PATH" "$SB/prefix-claude/scripts/harness/install-claude-code.sh" --check >"$O" 2>&1; echo $?)
  if [ "$rc" = "3" ] && grep -qx 'CLAUDE-CODE: UNVERIFIED' "$O" \
     && grep -q '^  WARN  auth — no credential' "$O"; then
    ok "claude-code: the pre-fix adapter ($PREFIX_REV) calls the same installed pin 'CLAUDE-CODE: UNVERIFIED' (exit 3) — the arm is falsifiable"
  else
    no "claude-code: the pre-fix control did not reproduce UNVERIFIED (rc=$rc)"; sed 's/^/        /' "$O" | tail -10
  fi
else
  skip "claude-code: pre-fix revision $PREFIX_REV is unavailable here"
fi

# Negative arm: an AMBIENT exported key is contamination, and it must still stop the run — the
# classification change above is about a MISSING credential, not about accepting ambient state.
O="$SB/claude-ambient.out"
SYNTH="$(printf 'sk-%s' 'cf006-not-a-real-credential')"
rc=$(clean_env ANTHROPIC_API_KEY="$SYNTH" HOME="$CL_HOME" PATH="$CL_PATH" \
     "$HERE_REPO/scripts/harness/install-claude-code.sh" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "1" ] && grep -q '^  FAIL  contract:ambient' "$O" \
   && grep -q 'contract refused' "$O" && ! grep -qF -- "$SYNTH" "$O"; then
  ok "claude-code: an ambient exported key is still refused by name (exit 1) and its value is never echoed"
else
  no "claude-code: an ambient key was not refused as contamination (rc=$rc)"; sed 's/^/        /' "$O" | tail -10
fi

# ================================================================ pi-agent
say ""
say "2. pi-agent — a credential FILE beside a measured binary is a note; without a binary it warns"
PI_HOME="$SB/pi-home"
mkdir -p "$PI_HOME/.pi/agent"
printf '%s\n' '{"fixture":{"note":"placeholder — no credential value"}}' >"$PI_HOME/.pi/agent/auth.json"
PI_BIN="$SB/pi-bin"
mkdir -p "$PI_BIN"
cat >"$PI_BIN/pi" <<'PISTUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf '1.5.0\n'; exit 0 ;;
  --help) printf 'pi [options]\n  -p, --print        non-interactive prompt\n  --no-session       do not persist a session\n'; exit 0 ;;
  *) exit 0 ;;
esac
PISTUB
chmod +x "$PI_BIN/pi"
PI_PATH="$PI_BIN:/usr/local/bin:/usr/bin:/bin"

O="$SB/pi-check.out"
rc=$(clean_env HOME="$PI_HOME" PATH="$PI_PATH" "$HERE_REPO/scripts/harness/install-pi-agent.sh" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "0" ] && grep -qx 'PI-AGENT: PASS' "$O" \
   && grep -q '^  PASS  binary — ' "$O" && grep -q '^  PASS  version — 1.5.0' "$O" \
   && grep -q '^  \.\.    credential_file — .*auth.json present' "$O" \
   && [ "$(grep -c '^  WARN  ' "$O")" = 0 ]; then
  ok "pi-agent: a measured binary with an auth.json reaches 'PI-AGENT: PASS' (exit 0); credential_file is a note, 0 WARN rows"
else
  no "pi-agent: --check did not reach PASS beside a credential file (rc=$rc)"; sed 's/^/        /' "$O" | tail -14
fi

if prefix_tree "$SB/prefix-pi" install-pi-agent.sh; then
  O="$SB/pi-prefix.out"
  rc=$(clean_env HOME="$PI_HOME" PATH="$PI_PATH" "$SB/prefix-pi/scripts/harness/install-pi-agent.sh" --check >"$O" 2>&1; echo $?)
  if [ "$rc" = "3" ] && grep -qx 'PI-AGENT: UNVERIFIED' "$O" \
     && grep -q '^  WARN  credential_file — ' "$O"; then
    ok "pi-agent: the pre-fix adapter ($PREFIX_REV) calls the same measured binary 'PI-AGENT: UNVERIFIED' (exit 3) — the arm is falsifiable"
  else
    no "pi-agent: the pre-fix control did not reproduce UNVERIFIED (rc=$rc)"; sed 's/^/        /' "$O" | tail -10
  fi
else
  skip "pi-agent: pre-fix revision $PREFIX_REV is unavailable here"
fi

# Negative arm: no binary, credential present. The credential must not stand in for an install,
# and the row must still be visible as the difference between the two absences.
NOPI="$SB/empty-bin"; mkdir -p "$NOPI"
O="$SB/pi-nobin.out"
rc=$(clean_env HOME="$PI_HOME" PATH="$NOPI:/usr/local/bin:/usr/bin:/bin" \
     "$HERE_REPO/scripts/harness/install-pi-agent.sh" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "1" ] && grep -qx 'PI-AGENT: FAIL (1)' "$O" \
   && grep -q '^  FAIL  binary — absent' "$O" \
   && grep -q '^  WARN  credential_file — ' "$O"; then
  ok "pi-agent: a credential file with no binary is still 'PI-AGENT: FAIL (1)' with a named FAIL binary (the credential certifies nothing)"
else
  no "pi-agent: a credential without a binary was not a named FAIL (rc=$rc)"; sed 's/^/        /' "$O" | tail -10
fi

say ""
say "classification test: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] && { say "RESULT: PASS"; exit 0; } || { say "RESULT: FAIL"; exit 1; }

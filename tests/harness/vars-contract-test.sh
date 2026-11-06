#!/usr/bin/env bash
# tests/harness/vars-contract-test.sh — the §5 variable contract, proven per installer (CF-229).
#
# One focused battery. Every line below is measured, and each one can FAIL:
#
#   (a) per installer: --help lists every variable specs/HARNESS-MATRIX.md §5 declares;
#   (b) per installer: a credential passed as a VALUE is REFUSED with a named failure — both the
#       CF_API_KEY_FILE=<value> form and the --api-key <value> form — and the value is not echoed;
#   (c) per installer: a bogus ambient provider key is not used — the installer refuses and names
#       the variable, and the bogus value never reaches the output;
#   (d) per installer with a flag surface: the flags set the same variables the §5 names say;
#   (e) the conformance `vars` leg goes RED when one declared variable is dropped from the set the
#       battery checks, and GREEN when the shipped file is used — both arms run here.
#
# Every installer is invoked under `env -i`: the set under test is the only set, so nothing here
# depends on this host's ambient keys or CF_* state.
#
#   bash tests/harness/vars-contract-test.sh          # normal
#   KEEP=1 bash tests/harness/vars-contract-test.sh   # keep the scratch tree
#
# Exit: 0 every ledger row passed (SKIP is not a failure), 1 any row failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
SPEC="$HERE/specs/HARNESS-MATRIX.md"
CONF="$HERE/tests/harness-conformance.sh"
INSTALLERS=(install-hermes.sh install-opencode.sh install-claude-code.sh install-codex.sh)

PASSED=0
FAILED=0
SKIPPED=0
pass() { printf '  PASS  %s\n' "$*"; PASSED=$((PASSED+1)); }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=$((FAILED+1)); }
skip() { printf '  SKIP  %s\n' "$*"; SKIPPED=$((SKIPPED+1)); }
say()  { printf '%s\n' "$*"; }

[ -f "$SPEC" ] || { printf 'no spec at %s\n' "$SPEC" >&2; exit 1; }
[ -f "$CONF" ] || { printf 'no battery at %s\n' "$CONF" >&2; exit 1; }

# The declared set is the spec's, parsed — never a second copy of the truth. A spec that gains or
# loses a variable changes this count, and this test then says so instead of quietly narrowing.
mapfile -t DECLARED < <(awk '/^## 5\./{f=1;next} /^## 6\./{f=0} f' "$SPEC" \
  | grep -oE '`CF_[A-Z_]+`' | tr -d '`' | awk '!seen[$0]++')
EXPECTED_DECLARED=12
if [ "${#DECLARED[@]}" -ne "$EXPECTED_DECLARED" ]; then
  say "  FAIL  specs/HARNESS-MATRIX.md §5 declares ${#DECLARED[@]} variables, expected $EXPECTED_DECLARED — the test is anchored on a set it cannot see"
  exit 1
fi
say "the §5 set: ${DECLARED[*]}"

# A synthetic credential and synthetic ambient keys, built from parts so no line in this file looks
# like a literal key to the tree-hygiene grep (AGENTS.md r8). Neither value is ever a real secret.
SYNTH_SECRET="sk-$(printf 'cf229-%s' 'not-a-real-credential')"

T="$(mktemp -d "${TMPDIR:-/tmp}/cf229-vars.XXXXXXXX")" || exit 1
cleanup() { [ "${KEEP:-0}" = "1" ] || rm -rf "$T"; }
trap cleanup EXIT INT TERM
HOMEFIX="$T/home"
mkdir -p "$HOMEFIX" "$T/tmp" "$HOMEFIX/wd" "$HOMEFIX/skills" || exit 1
git -C "$HOMEFIX/wd" init -q -b main >/dev/null 2>&1 || { printf 'cannot stage a fixture git work tree\n' >&2; exit 1; }
(umask 077; printf '%s\n' "$(printf 'synthetic-%s' 'not-a-credential')" > "$HOMEFIX/key") || exit 1

run() { env -i PATH="$PATH" HOME="$HOMEFIX" TMPDIR="$T/tmp" LANG=C "$@"; }

# The full declared set as NAME=value assignments, one per line, with a synthetic value each.
vars_env() {
  local v val
  for v in "${DECLARED[@]}"; do
    case "$v" in
      CF_MODEL) val=fixture-model-1 ;;
      CF_PROVIDER) val=fixture ;;
      CF_BASE_URL) val=http://127.0.0.1:9/v1 ;;
      CF_API_KEY_FILE) val="$HOMEFIX/key" ;;
      CF_WORKDIR) val="$HOMEFIX/wd" ;;
      CF_NAMESPACE) val=code-factory-qa ;;
      CF_RUN_ID) val=cf229-vars-run ;;
      CF_LANE) val=code-factory-qa ;;
      CF_SKILLS_DIR) val="$HOMEFIX/skills" ;;
      CF_HARNESS_OPTS) val='sandbox=workspace-write,approval=never' ;;
      CF_MAX_TURNS) val=40 ;;
      CF_TIMEOUT_S) val=1800 ;;
      *) val=unset ;;
    esac
    printf '%s=%s\n' "$v" "$val"
  done
}
mapfile -t FULL_ENV < <(vars_env)

# The flags an installer advertises are read from its own --help, so an installer that documents
# only the CF_* environment is not failed for a surface it never claimed.

# ---------------------------------------------------------------------------- per installer
for inst in "${INSTALLERS[@]}"; do
  path="$HERE/scripts/harness/$inst"
  say ""
  say "$inst"
  if [ ! -f "$path" ]; then
    fail "$inst is missing from scripts/harness — there is no installer to hold to §5"
    continue
  fi

  # (a) --help documents every declared variable.
  helpout="$(run bash "$path" --help 2>&1)"; rc=$?
  missing=""
  [ "$rc" -eq 0 ] || missing="(--help exit $rc)"
  for v in "${DECLARED[@]}"; do
    case "$helpout" in *"$v"*) ;; *) missing="$missing $v" ;; esac
  done
  if [ -z "$missing" ]; then
    pass "$inst: --help lists all ${#DECLARED[@]} declared variables and exits 0"
  else
    fail "$inst: --help does not document:$missing"
  fi
  case "$helpout" in *--contract*) mode="--contract" ;; *) mode="--check" ;; esac

  # (b1) a credential VALUE in CF_API_KEY_FILE is refused, by name, and never echoed.
  swap=()
  for v in "${FULL_ENV[@]}"; do
    case "$v" in CF_API_KEY_FILE=*) swap+=("CF_API_KEY_FILE=$SYNTH_SECRET") ;; *) swap+=("$v") ;; esac
  done
  out="$(run "${swap[@]}" bash "$path" "$mode" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$inst: CF_API_KEY_FILE=<credential value> was ACCEPTED (exit 0) — a value is never a path"
  elif ! printf '%s\n' "$out" | grep -qE 'CF_API_KEY_FILE|credential'; then
    fail "$inst: CF_API_KEY_FILE=<value> was refused without naming the variable"
  elif printf '%s\n' "$out" | grep -qF -- "$SYNTH_SECRET"; then
    fail "$inst: the refused credential value was echoed into the output"
  else
    pass "$inst: CF_API_KEY_FILE=<value> refused by name (exit $rc), value not echoed"
  fi

  # (b2) a credential in argv is refused, by name, and never echoed.
  out="$(run bash "$path" --api-key "$SYNTH_SECRET" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$inst: --api-key <credential> was ACCEPTED (exit 0)"
  elif ! printf '%s\n' "$out" | grep -qE 'api-key|credential|unknown argument'; then
    fail "$inst: --api-key <value> was refused without naming the rule"
  elif printf '%s\n' "$out" | grep -qF -- "$SYNTH_SECRET"; then
    fail "$inst: the refused --api-key value was echoed into the output"
  else
    pass "$inst: --api-key <value> refused by name (exit $rc), value not echoed"
  fi

  # (c) a bogus ambient provider key is not used: the installer refuses and names it.
  out="$(run OPENAI_API_KEY="$SYNTH_SECRET" ANTHROPIC_API_KEY="$SYNTH_SECRET" \
    "${FULL_ENV[@]}" bash "$path" "$mode" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$inst: a bogus ambient provider key was ACCEPTED (exit 0) — the directive is the only source"
  elif ! printf '%s\n' "$out" | grep -qE 'OPENAI_API_KEY|ANTHROPIC_API_KEY|contract:ambient'; then
    fail "$inst: an ambient provider key was refused without naming the variable"
  elif printf '%s\n' "$out" | grep -qF -- "$SYNTH_SECRET"; then
    fail "$inst: the ambient key value was echoed into the output"
  else
    pass "$inst: a bogus ambient provider key is refused by name (exit $rc), never used and never echoed"
  fi

  # (d) the flag surface sets the same variables. Only installers that advertise the flags get this
  # arm; claude-code documents the CF_* environment only, and that is a stated choice, not a drop.
  case "$helpout" in
    *--api-key-file*)
      flags=(--model fixture-model-1 --provider fixture --base-url http://127.0.0.1:9/v1
             --api-key-file "$HOMEFIX/key" --workdir "$HOMEFIX/wd" --namespace code-factory-qa
             --run-id cf229-vars-run --lane code-factory-qa --skills-dir "$HOMEFIX/skills"
             --harness-opts sandbox=workspace-write,approval=never --max-turns 40 --timeout-s 1800)
      fout="$(run bash "$path" "$mode" "${flags[@]}" 2>&1)"; frc=$?
      fmissing=""
      for v in "${DECLARED[@]}"; do
        case "$fout" in *"$v"*) ;; *) fmissing="$fmissing $v" ;; esac
      done
      if [ "$frc" -eq 2 ]; then
        fail "$inst: the flag form was REFUSED (exit 2): $(printf '%s\n' "$fout" | grep -E '^  FAIL' | head -1 | sed 's/^  FAIL  //')"
      elif [ "$mode" = "--contract" ] && [ "$frc" -ne 0 ]; then
        fail "$inst: the flag form exited $frc on the full set (want 0)"
      elif printf '%s\n' "$fout" | grep -q '^  FAIL  contract:'; then
        fail "$inst: the flag form was refused: $(printf '%s\n' "$fout" | grep -E '^  FAIL  contract:' | head -1 | sed 's/^  FAIL  //')"
      elif [ -n "$fmissing" ]; then
        fail "$inst: the flag form accepted but never recorded:$fmissing"
      else
        pass "$inst: every declared flag sets its variable (${#DECLARED[@]}/${#DECLARED[@]} recorded, exit $frc)"
      fi
      ;;
    *)
      skip "$inst: no flag surface advertised (CF_* environment only) — the flag arm does not apply"
      ;;
  esac
done

# ------------------------------------------------- (e) the conformance vars leg can go red AND green
say ""
say "the conformance vars leg"
SB="$T/conf"
mkdir -p "$SB/tests" "$SB/scripts" "$SB/specs" "$SB/docs" || exit 1
cp "$CONF" "$SB/tests/harness-conformance.sh" || exit 1
cp "$HERE/scripts/lib.sh" "$SB/scripts/lib.sh" || exit 1
cp -r "$HERE/scripts/harness" "$SB/scripts/harness" || exit 1
cp "$SPEC" "$SB/specs/HARNESS-MATRIX.md" || exit 1

# GREEN: the shipped battery, one harness, vars leg only.
out="$(run bash "$CONF" --vars-only --only hermes 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^  PASS  hermes:vars — '; then
  pass "GREEN arm: the shipped battery passes hermes:vars (exit 0)"
else
  fail "GREEN arm: the shipped battery did not pass hermes:vars (exit $rc): $(printf '%s\n' "$out" | grep -E 'hermes:vars|vars-declared' | head -2 | tr '\n' ' ')"
fi

# RED: one declared variable dropped from the set the battery checks. The drift row must name it.
sed -i 's/ CF_LANE / /' "$SB/tests/harness-conformance.sh"
if grep -q 'CF_LANE' "$SB/tests/harness-conformance.sh" \
  && grep -q 'CONTRACT_VARS=(CF_MODEL CF_PROVIDER' "$SB/tests/harness-conformance.sh"; then
  out="$(run bash "$SB/tests/harness-conformance.sh" --vars-only --only hermes 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  battery:vars-declared — §5 declares CF_LANE and this battery drops it'; then
    pass "RED arm: dropping CF_LANE from the set the battery checks fails the vars leg by name (exit $rc)"
  else
    fail "RED arm: dropping CF_LANE did not produce the named FAIL (exit $rc): $(printf '%s\n' "$out" | grep -E 'FAIL' | head -2 | tr '\n' ' ')"
  fi
  # RESTORED: the same copy with the variable put back must go green again.
  cp "$CONF" "$SB/tests/harness-conformance.sh"
  out="$(run bash "$SB/tests/harness-conformance.sh" --vars-only --only hermes 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^  PASS  hermes:vars — '; then
    pass "RESTORED arm: CF_LANE back in the set -> the vars leg is green again (exit 0)"
  else
    fail "RESTORED arm: the copy did not go green after restoring CF_LANE (exit $rc): $(printf '%s\n' "$out" | grep -E '^  FAIL' | head -2 | tr '\n' ' ')"
  fi
else
  # The mutation itself must be visible, or the red arm is vacuous.
  fail "could not find 'CF_LANE' and the CONTRACT_VARS assignment in the battery copy — the red arm cannot be staged"
fi

say ""
say "vars-contract: $PASSED pass, $FAILED fail, $SKIPPED skip"
[ "$FAILED" -eq 0 ] && { say "VARS CONTRACT: PASS"; exit 0; }
say "VARS CONTRACT: FAIL ($FAILED)"
exit 1

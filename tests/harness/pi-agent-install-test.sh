#!/usr/bin/env bash
# Hermetic CF-228 proof for the fixture-backed oh-my-pi adapter.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
SUT="$HERE/scripts/harness/install-pi-agent.sh"
WORK="$(mktemp -d "$HOME/.cf228-pi-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FIX="$WORK/fixture"
HOME_TEST="$WORK/home"
mkdir -p "$FIX/package" "$FIX/bun/bin" "$FIX/bin" "$HOME_TEST/work"

pass() { printf '  PASS  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; exit 1; }
skip() { printf '  SKIP  %s\n' "$*"; }

cat > "$FIX/package/package.json" <<'JSON'
{"name":"@oh-my-pi/pi-coding-agent","version":"18.16.0","private":true}
JSON
cat > "$FIX/bun/bin/bun" <<'BUN'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && { printf '1.4.4\n'; exit 0; }
exit 0
BUN
cat > "$FIX/bin/pi" <<'PI'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf '1.5.0-fixture\n'; exit 0 ;;
  --help) printf '%s\n' 'pi -p --no-session --mode json'; exit 0 ;;
  -p)
    token="${CF_TURN_TOKEN:-CF-228-TOKEN}"
    file="${CF_TURN_FILE:-pi-turn.txt}"
    printf '%s\n' "$token" > "$file"
    printf 'model_served=%s\n' "${CF_MODEL:-fixture-model}"
    exit 0
    ;;
esac
exit 2
PI
chmod +x "$FIX/bun/bin/bun" "$FIX/bin/pi"

[ -x "$SUT" ] || fail "missing executable installer: $SUT"
bash -n "$SUT" || fail "installer is not valid bash"

help_out=$("$SUT" --help 2>&1) || fail "--help failed"
for v in CF_MODEL CF_PROVIDER CF_BASE_URL CF_API_KEY_FILE CF_WORKDIR CF_NAMESPACE CF_RUN_ID CF_LANE CF_SKILLS_DIR CF_HARNESS_OPTS CF_MAX_TURNS CF_TIMEOUT_S; do
  printf '%s' "$help_out" | grep -q "$v" || fail "--help omits $v"
done
printf '%s' "$help_out" | grep -q 'PATH to a mode-600' || fail "--help omits credential path rule"
pass "--help documents the §5 variables and path-only credential rule"

out=$(HOME="$HOME_TEST" PATH=/usr/bin:/bin "$SUT" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] || fail "absent install passed --check"
printf '%s' "$out" | grep -q '^  FAIL  binary — absent' || fail "absent install did not name binary failure"
pass "--check is read-only and fails honestly when the install root is absent"
[ ! -e "$HOME_TEST/.local/harness/oh-my-pi" ] || fail "--check wrote the install root"

out=$(HOME="$HOME_TEST" PATH=/usr/bin:/bin "$SUT" --apply 2>&1); rc=$?
[ "$rc" -eq 1 ] || fail "fixtureless --apply returned $rc instead of refusal exit 1"
printf '%s' "$out" | grep -q '^  FAIL  apply — refused' || fail "fixtureless --apply did not print the named refusal"
printf '%s' "$out" | grep -qi 'ladder' || fail "fixtureless --apply refusal did not name the missing ladder"
pass "fixtureless --apply refuses the unverified upstream ladder by name"

out=$(HOME="$HOME_TEST" PI_FIXTURE_DIR="$FIX" "$SUT" --apply 2>&1); rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
[ "$rc" -eq 0 ] || fail "fixture --apply failed (exit $rc)"
prefix="$HOME_TEST/.local/harness/oh-my-pi/18.16.0"
[ -x "$prefix/bin/pi" ] || fail "pi was not installed under HOME"
[ -x "$prefix/bun/bin/bun" ] || fail "bun was not installed under HOME"
printf '%s' "$out" | grep -q 'PASS  version — 1.5.0-fixture from install root' || fail "version was not read back from install root"
pass "fixture --apply is user-space and reads back pi version from the install root"

fingerprint() { find "$1" -printf '%P|%s|%T@\n' | LC_ALL=C sort | sha256sum | cut -d' ' -f1; }
before=$(fingerprint "$prefix")
out2=$(HOME="$HOME_TEST" PI_FIXTURE_DIR="$FIX" "$SUT" --apply 2>&1); rc2=$?
after=$(fingerprint "$prefix")
[ "$rc2" -eq 0 ] || fail "second fixture --apply failed (exit $rc2)"
[ "$before" = "$after" ] || fail "second --apply changed the installed tree"
printf '%s' "$out2" | grep -q 'already installed at pin' || fail "second --apply did not report idempotence"
pass "second fixture --apply is idempotent ($before)"

key="$WORK/key"
printf 'fixture-key-not-read\n' > "$key"
chmod 600 "$key"
work="$HOME_TEST/work"
out=$(HOME="$HOME_TEST" PI_FIXTURE_DIR="$FIX" CF_API_KEY_FILE="$key" CF_WORKDIR="$work" CF_MODEL=fixture-model CF_PROVIDER=fixture CF_NAMESPACE=cf228 CF_RUN_ID=cf228-test CF_LANE=fixture CF_TURN_FILE=pi-turn.txt CF_TURN_TOKEN=CF228FIXTURE "$SUT" --turn --prompt fixture 2>&1); rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
[ "$rc" -eq 0 ] || fail "fixture turn failed (exit $rc)"
[ "$(cat "$work/pi-turn.txt")" = CF228FIXTURE ] || fail "fixture turn artifact token mismatch"
printf '%s' "$out" | grep -q 'PASS  model_served — fixture-model' || fail "model_served was not reported"
pass "fixture turn writes the token artifact and reports model_served"

out=$(HOME="$HOME_TEST" PI_FIXTURE_DIR="$FIX" CF_WORKDIR="$work" "$SUT" --turn --prompt no-credential 2>&1); rc=$?
[ "$rc" -eq 3 ] || fail "credentialless turn returned $rc instead of SKIP exit 3"
printf '%s' "$out" | grep -q 'PI-AGENT: SKIP' || fail "credentialless turn did not report SKIP"
skip "live upstream install/turn and credentialless external turn are UNVERIFIED; fixture leg is proven"

# ch:trace row=CF-228 spec=specs/HARNESS-MATRIX.md#5-the-variable-contract wave=none:serial test=tests/harness/pi-agent-install-test.sh doc=docs/handbook/chapters/M5-harness.md evidence=tests/harness/pi-agent-install-test.sh witness=none:live-node-and-credentialless-external-turn-unavailable verdict=none:foreman-runs-judge commit=none:stable-implementation-sha-bound-after-commit memory=none:foreman-closeout
printf 'PI-AGENT INSTALL TEST: PASS\n'

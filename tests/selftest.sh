#!/usr/bin/env bash
# selftest.sh — prove the checks in this repo can FAIL. A green that cannot go red is decoration.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
fails=0
t() { if eval "$2" >/dev/null 2>&1; then say "  PASS  $1"; else say "  FAIL  $1"; fails=$((fails+1)); fi; }

say "1. every script parses"
for f in "$HERE"/scripts/*.sh "$HERE"/scripts/harness/*.sh "$HERE"/tests/*.sh; do
  bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }
done

say "2. the node checker FAILS on an empty PATH"
out=$(env -i PATH=/nonexistent HOME="$HOME" NODE_PROJECT=t /bin/bash "$HERE/scripts/project-node.sh" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && say "  PASS  empty PATH -> exit $rc" || { say "  FAIL  empty PATH reported success"; fails=$((fails+1)); }
# The rows must be REAL named checks, not a bootstrap crash that happens to contain
# the substring FAIL (CF-005 AC2: "FAILED: unbound variable" is not a FAIL row).
if printf '%s' "$out" | grep -q 'unbound variable'; then
  say "  FAIL  report is a bootstrap crash, not named FAIL rows"; fails=$((fails+1))
elif printf '%s' "$out" | grep -Eq '^  FAIL  tool:'; then
  say "  PASS  report contains named FAIL rows"
else
  say "  FAIL  no FAIL rows"; fails=$((fails+1))
fi

say "3. unreachable Crier reports one HTTP status code"
tmpd=$(mktemp -d)
cat > "$tmpd/curl" <<'EOF'
#!/usr/bin/env bash
printf '000'
exit 7
EOF
chmod +x "$tmpd/curl"
# The row under test is layer 00's `reach:` FAIL — one row per unreachable URL, not two.
# PERF-013: a full run (base/harness/bus/repo) costs several times the CPU of the row it
# proves here, so the fixture runs only that layer.
out=$(env PATH="$tmpd:$PATH" HOME="$tmpd/home" NODE_PROJECT=demo CRIER_URL=http://closed.test:8767 \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 00 2>&1); rc=$?
expected='  FAIL  reach:http://closed.test:8767/health — -> 000'
if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
  say "  PASS  unreachable URL -> one 000 status"
else
  say "  FAIL  unreachable URL status was duplicated or missing"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# ch:trace row=CF-034 spec=README.md#status wave=none:serial test=tests/selftest.sh::clone-error-classification doc=README.md prompt=prompts/readme.md evidence=tests/selftest.sh::clone-error-classification witness=none:local-fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unresolved-namespace
say "4. clone errors distinguish missing refs from repository access"
# Both arms assert the classification of a layer-40 `repo_clone` row; no other layer can
# change that verdict, so each runs only layer 40 (PERF-013).
tmpd=$(mktemp -d)
git init -q -b trunk "$tmpd/work"
git -C "$tmpd/work" config user.email fixture@example.invalid
git -C "$tmpd/work" config user.name fixture
echo fixture > "$tmpd/work/README"
git -C "$tmpd/work" add README
git -C "$tmpd/work" commit -qm fixture
git clone -q --bare "$tmpd/work" "$tmpd/origin.git"
missing_ref=$(env HOME="$tmpd/missing-home" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --apply --project demo --harness fixture \
  --repo "file://$tmpd/origin.git" --layers 40 2>&1); rc=$?
expected="  FAIL  repo_clone — ref 'main' was not found; pass --ref <branch-or-tag>"
if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$missing_ref" | grep -Fxc -- "$expected")" = 1 ] \
  && ! printf '%s\n' "$missing_ref" | grep -Fq 'private repos need a deploy key'; then
  say "  PASS  missing ref names main and --ref without a private-repo hint"
else
  say "  FAIL  missing ref was not distinguished from repository access"; fails=$((fails+1))
fi
mkdir "$tmpd/bin"
cat > "$tmpd/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  clone|ls-remote)
    echo 'fatal: Authentication required for fixture' >&2
    exit 128
    ;;
  *) exec "${REAL_GIT:?}" "$@" ;;
esac
EOF
chmod +x "$tmpd/bin/git"
private_repo=$(env PATH="$tmpd/bin:$PATH" REAL_GIT="$(command -v git)" HOME="$tmpd/private-home" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --apply --project demo --harness fixture \
  --repo https://private.fixture.invalid/repo.git --layers 40 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$private_repo" | grep -Fq 'private repos need a deploy key'; then
  say "  PASS  repository access failure retains deploy-key hint"
else
  say "  FAIL  repository access failure lost deploy-key hint"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-039 resolved-ref-clone-failure: exercise the real node script with local git only.
# BEGIN resolved-ref-clone-failure
say "4b. clone failure after successful ref resolution is not an access failure"
tmpd=$(mktemp -d)
mkdir "$tmpd/bin"
cat > "$tmpd/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  clone)
    [ "$#" -eq 7 ] && [ "$2" = --depth ] && [ "$3" = 1 ] \
      && [ "$4" = --branch ] && [ "$5" = main ] && [ "$6" = "${FIXTURE_REPO:?}" ] || exit 99
    "${REAL_GIT:?}" ls-remote --exit-code "$6" refs/heads/main refs/tags/main >/dev/null || exit 99
    printf '%s\n' 'clone: refs/heads/main resolved; refusing clone' >> "${FIXTURE_LOG:?}"
    echo 'fatal: fixture checkout write failed' >&2
    exit 128
    ;;
  ls-remote)
    [ "$#" -eq 5 ] && [ "$2" = --exit-code ] && [ "$3" = "${FIXTURE_REPO:?}" ] \
      && [ "$4" = refs/heads/main ] && [ "$5" = refs/tags/main ] || exit 99
    "${REAL_GIT:?}" "$@" || exit 99
    printf '%s\n' 'ls-remote: refs/heads/main refs/tags/main resolved' >> "${FIXTURE_LOG:?}"
    ;;
  *) exec "${REAL_GIT:?}" "$@" ;;
esac
EOF
chmod +x "$tmpd/bin/git"
git init -q -b main "$tmpd/work"
git -C "$tmpd/work" config user.email fixture@example.invalid
git -C "$tmpd/work" config user.name fixture
echo fixture > "$tmpd/work/README"
git -C "$tmpd/work" add README
git -C "$tmpd/work" commit -qm fixture
resolved_ref=$(env PATH="$tmpd/bin:$PATH" REAL_GIT="$(command -v git)" \
  FIXTURE_REPO="file://$tmpd/work" FIXTURE_LOG="$tmpd/git.log" \
  HOME="$tmpd/resolved-home" NODE_PROJECT=demo CRIER_URL= \
  /bin/bash "$HERE/scripts/project-node.sh" --apply --project demo --harness fixture \
  --repo "file://$tmpd/work" --ref main --layers 40 2>&1); rc=$?
expected="  FAIL  repo_clone — fatal: fixture checkout write failed (clone failed after ref 'main' resolved)"
expected_calls=$(printf '%s\n' 'clone: refs/heads/main resolved; refusing clone' \
  'ls-remote: refs/heads/main refs/tags/main resolved')
if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$resolved_ref" | grep -Fxc -- "$expected")" = 1 ] \
  && [ "$(cat "$tmpd/git.log" 2>/dev/null)" = "$expected_calls" ] \
  && ! printf '%s\n' "$resolved_ref" | grep -Fq "ref 'main' was not found" \
  && ! printf '%s\n' "$resolved_ref" | grep -Fq 'private repos need a deploy key'; then
  say "  PASS  resolved main clone failure names the ref without missing-ref or private-repo hints"
else
  say "  FAIL  resolved-ref clone failure was misclassified"; fails=$((fails+1))
  printf '%s\n' "$resolved_ref" | grep -F 'repo_clone'
fi
rm -rf "$tmpd"
# END resolved-ref-clone-failure

say "5. fetch_verified refuses a wrong digest"
tmpd=$(mktemp -d); echo hello > "$tmpd/src"
want=$(sha256sum "$tmpd/src" | cut -d' ' -f1)
fetch_verified "file://$tmpd/src" "$tmpd/out" "$want" && say "  PASS  correct digest accepted" || { say "  FAIL  correct digest refused"; fails=$((fails+1)); }
fetch_verified "file://$tmpd/src" "$tmpd/out2" "0000000000000000000000000000000000000000000000000000000000000000" \
  && { say "  FAIL  wrong digest accepted"; fails=$((fails+1)); } || say "  PASS  wrong digest refused"
rm -rf "$tmpd"

say "6. no literal credential assignments"
if grep -rnE '^[A-Z_]*(API_KEY|TOKEN|SECRET)=[^$"[:space:]]' "$HERE"/scripts "$HERE"/specs "$HERE"/docs 2>/dev/null | grep -v 'example' | head -3 | grep -q .; then
  say "  FAIL  a literal credential assignment is in the tree"; fails=$((fails+1))
else
  say "  PASS  none found"
fi

# BEGIN board-arm
# CF-088: share the actual gate with fixtures, without requiring boardctl.
board_arm() {
  local b="$1"
  if [ ! -f "$b" ]; then
    say "  FAIL  board missing"
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    say "  FAIL  board parser: python3 missing"
    return 1
  fi
  # One parser process for the whole board (PERF-012), not python3 per row.
  # Preserve `while read` semantics: skip an unterminated last line; empty is 0/0.
  python3 - "$b" <<'PY'
import json, sys
try:
    data = open(sys.argv[1], "rb").read()
except OSError as exc:
    print(f"  FAIL  board unreadable: {exc}")
    sys.exit(1)
rows = data.split(b"\n")[:-1]
statuses = ("pending", "in_progress", "blocked", "complete")
seen = {}
good = 0
for line, row in enumerate(rows, 1):
    try:
        record = json.loads(row.decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        print(f"  FAIL  board line {line}: invalid JSON: {exc}")
        continue
    if not isinstance(record, dict):
        print(f"  FAIL  board line {line}: expected JSON object, got {json.dumps(record)}")
        continue
    valid = True
    if "id" not in record:
        print(f"  FAIL  board line {line}: missing id")
        valid = False
    elif not isinstance(record["id"], str) or not record["id"]:
        print(f"  FAIL  board line {line}: invalid id {json.dumps(record['id'])}")
        valid = False
    elif record["id"] in seen:
        print(f"  FAIL  board duplicate id {record['id']!r}: lines {seen[record['id']]} and {line}")
        valid = False
    else:
        seen[record["id"]] = line
    if "status" not in record:
        print(f"  FAIL  board line {line}: missing status")
        valid = False
    elif record["status"] not in statuses:
        print(f"  FAIL  board line {line}: invalid status {json.dumps(record['status'])}")
        valid = False
    good += valid
if good != len(rows):
    print(f"  FAIL  {good} of {len(rows)} rows parse")
    sys.exit(1)
print(f"  PASS  {good}/{len(rows)} rows parse")
PY
}
# END board-arm

say "7. the board is valid JSONL"
b="$HERE/.coding-hermes/board/tasks.jsonl"
board_arm "$b" || fails=$((fails+1))

say "7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)"
tmpd=$(mktemp -d)
# Every fixture has the same valid first/last rows; only the middle record changes.
for arm in null array string number missing-id duplicate-id bad-status missing-status invalid-json; do
  case "$arm" in
    null) middle='null'; expected='board line 2: expected JSON object, got null' ;;
    array) middle='[]'; expected='board line 2: expected JSON object, got []' ;;
    string) middle='"fixture"'; expected='board line 2: expected JSON object, got "fixture"' ;;
    number) middle='42'; expected='board line 2: expected JSON object, got 42' ;;
    missing-id) middle='{"status":"pending"}'; expected='board line 2: missing id' ;;
    duplicate-id) middle='{"id":"CF-001","status":"pending"}'; expected="board duplicate id 'CF-001': lines 1 and 2" ;;
    bad-status) middle='{"id":"CF-002","status":"done"}'; expected='board line 2: invalid status "done"' ;;
    missing-status) middle='{"id":"CF-002"}'; expected='board line 2: missing status' ;;
    invalid-json) middle='{'; expected='board line 2: invalid JSON:' ;;
  esac
  printf '%s\n' '{"id":"CF-001","status":"pending"}' "$middle" \
    '{"id":"CF-003","status":"complete"}' > "$tmpd/$arm.jsonl"
  out=$(board_arm "$tmpd/$arm.jsonl" 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "  FAIL  $expected" \
    && printf '%s\n' "$out" | grep -Fxq '  FAIL  2 of 3 rows parse' \
    && ! printf '%s\n' "$out" | grep -q '^  PASS'; then
    say "  PASS  $arm fixture rejected, exit $rc"
    printf '%s\n' "$out"
  else
    say "  FAIL  $arm fixture escaped the board gate (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out"
  fi
done
# A single run must report every bad record, not stop at the first one.
printf '%s\n' null '[]' '"fixture"' 42 > "$tmpd/multiple.jsonl"
out=$(board_arm "$tmpd/multiple.jsonl" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  board line [1-4]: expected JSON object,')" = 4 ]; then
  say "  PASS  all four offending line numbers reported in one board run"
else
  say "  FAIL  board gate skipped offending records (exit $rc)"; fails=$((fails+1))
fi
out=$(PATH=/nonexistent board_arm "$b" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ "$out" = '  FAIL  board parser: python3 missing' ]; then
  say "  PASS  missing python3 -> named FAIL, exit $rc"
else
  say "  FAIL  missing python3 escaped the board gate (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

say "8. project board entrypoint is real and fails closed without dependency"
bash -n "$HERE/scripts/boardctl" && say "  PASS  bash -n scripts/boardctl" || { say "  FAIL  bash syntax"; fails=$((fails+1)); }
"$HERE/scripts/boardctl" --help >/dev/null 2>&1 && say "  PASS  local help" || { say "  FAIL  help"; fails=$((fails+1)); }
missing=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/boardctl" list 2>&1); rc=$?
if [ "$rc" -eq 127 ] && printf '%s' "$missing" | grep -q 'FAIL boardctl'; then
  say "  PASS  missing boardctl -> explicit FAIL, exit 127"
else
  say "  FAIL  missing dependency was not surfaced"; fails=$((fails+1))
fi

say "9. every prompt file the README relies on exists"
# The README's lane section names prompts/<name>.md files and the loaders copy them into the
# scheduler. A rename that misses one side leaves a lane loading a prompt that is not shipped.
prompt_refs_missing() {  # $1=README $2=repo root -> prints each absent prompt, returns 1 if any
  local readme="$1" root="$2" rc=0 p
  for p in $(grep -oE 'prompts/[a-z0-9-]+\.md' "$readme" | sort -u); do
    [ -f "$root/$p" ] || { echo "absent: $p"; rc=1; }
  done
  return $rc
}
if prompt_refs_missing "$HERE/README.md" "$HERE" >/dev/null; then
  say "  PASS  every prompts/*.md named by README.md exists"
else
  say "  FAIL  README names a prompt file that is not shipped: $(prompt_refs_missing "$HERE/README.md" "$HERE" | tr '\n' ' ')"
  fails=$((fails+1))
fi
# negative fixture: a README that names a prompt nobody ships must be refused
tmpd=$(mktemp -d)
sed 's#prompts/qa\.md#prompts/ghost-lane.md#' "$HERE/README.md" > "$tmpd/README.md"
if prompt_refs_missing "$tmpd/README.md" "$HERE" >/dev/null; then
  say "  FAIL  a README naming an absent prompt was accepted"; fails=$((fails+1))
else
  say "  PASS  absent prompt refused ($(prompt_refs_missing "$tmpd/README.md" "$HERE" | head -1))"
fi
rm -rf "$tmpd"

say "10. Hermes refuses an unsupported Python without pip or network"
tmpd=$(mktemp -d)
cat > "$tmpd/python-3.14" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then
  printf '%s\n' 'Python 3.14.9'
  exit 0
fi
printf 'unexpected interpreter invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$tmpd/python-3.14"
out=$(env HOME="$tmpd/home" HERMES_PYTHON_BIN="$tmpd/python-3.14" \
  /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -Fq 'hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9' \
  && ! printf '%s\n' "$out" | grep -Fq 'pip failed'; then
  say "  PASS  Python 3.14 refusal names the supported range without pip"
else
  say "  FAIL  unsupported Python refusal was missing or reached pip"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# ch:trace row=CF-071 spec=specs/HARNESS.md wave=none:serial test=tests/selftest.sh::public-bind-auth doc=none:no-doc-change prompt=none:worker-brief evidence=tests/selftest.sh::public-bind-auth witness=none:local-fixture verdict=none:foreman-verifies commit=none:self-referential-hash memory=none:foreman-owns
# BEGIN public-bind-auth
# Part of section 10: no new numbered section or census change.
tmpd=$(mktemp -d)
auth_python=$(command -v python3)
if "$auth_python" - "$tmpd" "$HERE" <<'PY'
import os
from pathlib import Path
import sys

# Fixture generation must work on the same stdlib-only hosts as the gate.
root = Path(sys.argv[1])
(root / "bin").mkdir()
home = root / "home"
(home / ".hermes").mkdir(parents=True)
(home / "hermes-venv/bin").mkdir(parents=True)
# Random throwaway values stay in the private fixture, never in output or argv.
username, password = (os.urandom(16).hex() for _ in range(2))
auth = f"    username: '{username}'\n    password: '{password}'\n"
configs = {
    "commented": "# dashboard:\n#   basic_auth:\n#     username: ignored\n#     password: ignored\n",
    "empty-value": "dashboard:\n  basic_auth:\n",
    "real-value": "dashboard:\n  basic_auth:\n" + auth,
    "block-absent": "dashboard: {}\n",
    "wrong-key": "other:\n  basic_auth:\n" + auth,
    "empty-username": f'dashboard:\n  basic_auth:\n    username: ""\n    password: \'{password}\'\n',
    "empty-password": f'dashboard:\n  basic_auth:\n    username: \'{username}\'\n    password: ""\n',
    "missing-password": f"dashboard:\n  basic_auth:\n    username: '{username}'\n",
    "missing-username": f"dashboard:\n  basic_auth:\n    password: '{password}'\n",
    "wrong-indent": "dashboard:\nother:\n  basic_auth:\n" + auth,
    "invalid-yaml": "dashboard: [\n",
    "invalid-scalar": f"dashboard:\n  basic_auth:\n    username: - invalid\n    password: '{password}'\n",
    "duplicate-key": "dashboard:\n  basic_auth:\n" + auth + '    username: ""\n',
    "bad-indent": "dashboard:\n  basic_auth:\n" + auth + "   extra: invalid\n",
    "tab-indent": "dashboard:\n\tbasic_auth:\n" + auth,
    "non-string": f"dashboard:\n  basic_auth:\n    username: true\n    password: '{password}'\n",
    "trailing-comments": "dashboard: # comment\n  basic_auth: # comment\n" + auth.replace("\n", " # comment\n"),
    "quoted-hash": f'dashboard:\n  basic_auth:\n    username: "{username} # literal" # comment\n    password: \'{password} # literal\' # comment\n',
    "plain-value": f"dashboard:\n  basic_auth:\n    username: u{username}\n    password: p{password}\n",
}
for name, text in configs.items():
    (root / name).write_text(text)
(root / "credentials").write_text(username + "\n" + password + "\n")
python = home / "hermes-venv/bin/python"
python.write_text('''#!/usr/bin/env bash
if [ "${AUTH_ISOLATED:-0}" = 1 ]; then exec "${AUTH_PYTHON:?}" -I -S "$@"; fi
exec "${AUTH_PYTHON:?}" "$@"
''')
python.chmod(0o755)
stubs = {
    "python": '''#!/usr/bin/env bash
if [ "$1" = --version ]; then echo 'Python 3.12.3'; exit 0; fi
exec "${AUTH_PYTHON:?}" "$@"
''',
    "hermes": '''#!/usr/bin/env bash
if [ "$1" = --version ]; then echo 'hermes 0.19.0'; exit 0; fi
[ "$*" = 'serve --host 0.0.0.0 --port 10800 --skip-build' ] || exit 99
printf '%s\\n' 'serve launch reached' > "${AUTH_FIXTURE:?}/launch"
''',
    "ss": "#!/usr/bin/env bash\nexit 1\n",
    "nohup": '#!/usr/bin/env bash\nexec "$@"\n',
    "sleep": '''#!/usr/bin/env bash
for ((i=0; i<100; i++)); do
  [ ! -f "${AUTH_FIXTURE:?}/launch" ] || exit 0
  /bin/sleep 0.01
done
exit 1
''',
    "curl": '#!/usr/bin/env bash\nprintf "%s" "${AUTH_HTTP_CODE:?}"\n',
}
for name, text in stubs.items():
    path = root / "bin" / name
    path.write_text(text)
    path.chmod(0o755)
(home / "hermes-venv/bin/hermes").symlink_to(root / "bin/hermes")
# Exercise the historical bypass and an always-refuse mutation through the same oracle.
repo = Path(sys.argv[2])
source = (repo / "scripts/harness/install-hermes.sh").read_text()
start = source.index("check_public_bind_auth() {")
end = source.index('\nsay "harness:', start)
for name, body in {
    "grep-bypass": '''check_public_bind_auth() {
  grep -q 'basic_auth:' "$HOME/.hermes/config.yaml"
}
''',
    "always-refuse": '''check_public_bind_auth() {
  echo 'block absent'
  return 1
}
''',
}.items():
    scripts = root / name / "scripts"
    (scripts / "harness").mkdir(parents=True)
    (scripts / "harness/install-hermes.sh").write_text(source[:start] + body + source[end:])
    (scripts / "lib.sh").write_text((repo / "scripts/lib.sh").read_text())
PY
then
  auth_fixture_run() {
    cp "$tmpd/$1" "$tmpd/home/.hermes/config.yaml"
    rm -f "$tmpd/launch"
    env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" HERMES_PYTHON_BIN="$tmpd/bin/python" \
      HERMES_PIN=0.19.0 NODE_GATEWAY_PORT=10800 FAILED=0 AUTH_FIXTURE="$tmpd" \
      AUTH_PYTHON="$auth_python" AUTH_ISOLATED="$auth_isolated" AUTH_HTTP_CODE="${2:-200}" \
      /bin/bash "${3:-$HERE/scripts/harness/install-hermes.sh}" --apply
  }
  auth_fixture_check() {
    local arm="$1" out rc reason expected launch_expected expected_rc launch_observed
    out=$(auth_fixture_run "$arm" 200 "${2:-$HERE/scripts/harness/install-hermes.sh}" 2>&1); rc=$?
    case "$arm" in
      commented) reason=commented ;;
      block-absent|wrong-key|wrong-indent) reason='block absent' ;;
      invalid-yaml|invalid-scalar|duplicate-key|bad-indent|tab-indent) reason='block absent (invalid YAML)' ;;
      *) reason='empty value (username and password must both be non-empty)' ;;
    esac
    case "$arm" in
      real-value|trailing-comments|quoted-hash|plain-value)
        expected='  PASS  gateway_start — /api/status -> 200'
        launch_expected='serve launch reached' ;;
      *)
        expected="  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — $reason"
        launch_expected='' ;;
    esac
    # Every arm exits 1: the fixture home carries no provider key, so `inference_key` fails
    # whether or not the gateway starts. Grade gateway_start and launch separately.
    expected_rc=1
    launch_observed=$(cat "$tmpd/launch" 2>/dev/null || true)
    if [ "$rc" -eq "$expected_rc" ] \
      && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ] \
      && [ "$launch_observed" = "$launch_expected" ] \
      && ! printf '%s\n' "$out" | grep -Fqf "$tmpd/credentials"; then
      say "  PASS  CF-071 $auth_mode $arm: exit $rc, launch=${launch_observed:-not reached}"
      printf '%s\n' "$expected"
    else
      say "  FAIL  CF-071 $auth_mode $arm: exit $rc, launch=${launch_observed:-not reached}, expected gateway_start row missing or credentials exposed"
      printf '%s\n' "$out" | grep -E "PASS|FAIL" | tail -4 | sed 's/^/          got: /' 
      return 1
    fi
  }
  auth_default_python="$auth_python"
  for auth_mode in no-PyYAML installed; do
    auth_python="$auth_default_python"
    auth_isolated=0
    if [ "$auth_mode" = no-PyYAML ]; then
      # Prefer the stock supported interpreter; -I -S makes this deterministic on all hosts.
      auth_python=$(command -v python3.12 || printf '%s' "$auth_default_python")
      auth_isolated=1
    fi
    for arm in commented empty-value real-value block-absent wrong-key empty-username empty-password \
      missing-password missing-username wrong-indent invalid-yaml invalid-scalar duplicate-key bad-indent tab-indent \
      non-string trailing-comments quoted-hash plain-value; do
      auth_fixture_check "$arm" || fails=$((fails+1))
    done
    for mutation in grep-bypass always-refuse; do
      arm=commented
      [ "$mutation" != always-refuse ] || arm=real-value
      if auth_fixture_check "$arm" "$tmpd/$mutation/scripts/harness/install-hermes.sh" >/dev/null; then
        say "  FAIL  CF-071 $auth_mode accepted $mutation mutation"; fails=$((fails+1))
      else
        say "  PASS  CF-071 $auth_mode rejected $mutation mutation"
      fi
    done
  done
  # The same valid config must produce a red measured gateway_start when HTTP is 503.
  out=$(auth_fixture_run real-value 503 2>&1); rc=$?
  expected='  FAIL  gateway_start — -> 503 (see ~/.node-serve-10800.log)'
  if [ "$rc" -eq 1 ] && [ "$(cat "$tmpd/launch" 2>/dev/null)" = 'serve launch reached' ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
    say "  PASS  CF-071 real-value red control: exit $rc, launch reached, HTTP 503"
    printf '%s\n' "$expected"
  else
    say "  FAIL  CF-071 real-value red control did not fail on HTTP 503 (exit $rc)"; fails=$((fails+1))
  fi
  unset -f auth_fixture_run auth_fixture_check
else
  say "  FAIL  CF-071 public-bind-auth fixture setup (stdlib Python required)"; fails=$((fails+1))
fi
rm -rf "$tmpd"
# END public-bind-auth

say "11. lane workdir targets: local paths AND remote user@host/scheme targets"
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_lane_target.py" >/dev/null 2>&1; then
  say "  PASS  lane target parse/validate, home-repo rejection, remote structural-only"
else
  say "  FAIL  lane target contract"; fails=$((fails+1))
fi
say "12. node disk floor resolves from CLI/env/config with fail-closed values"
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_disk_floor.py" >/dev/null 2>&1; then
  say "  PASS  floor precedence, role defaults, malformed values refused"
else
  say "  FAIL  disk floor contract"; fails=$((fails+1))
fi
# CF-230: harness selection resolves in one place (specs/HARNESS-MATRIX.md §4). Part of
# section 12: no new numbered section and no census change (arms_tree stays 55). The test
# drives the real CLI and reads the shipped matrix, so a hardcoded table or a silent
# fallback goes red here.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_harness_resolve.py" >/dev/null 2>&1; then
  say "  PASS  CF-230 harness resolution: directive > lane > matrix > hermes, every reason recorded"
else
  say "  FAIL  CF-230 harness resolution contract (refusals, order, spec sync)"; fails=$((fails+1))
fi
say "13. node provisioning names its resolved floor and refuses below it"
tmpd=$(mktemp -d)
out=$(env HOME="$tmpd/home" NODE_DISK_FLOOR=999999 /bin/bash "$HERE/scripts/project-node.sh" --check --project fixture 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'FAIL disk-floor'; then
  say "  PASS  malformed floor refused before any install"
else
  say "  FAIL  malformed floor was accepted or not named"; fails=$((fails+1))
fi
rm -rf "$tmpd"

say "14. harness-adapter FAIL rows are counted in the node summary (CF-055)"
# The adapter runs as a child process, so the FAILED counter it increments
# (lib.sh) never reached the parent: a run could print k FAIL rows and
# summarise a smaller number — or even NODE: PASS. The fixture copies the real
# scripts into a temp tree (so project-node.sh resolves its own $HERE) and
# points them at a fixture adapter that fails through the real lib.sh bad()
# path; the counted rows are the real failure path, not a mock of the counter.
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts/harness" "$tmpd/home/.node" "$tmpd/home/repo" "$tmpd/bin"
cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" "$tmpd/scripts/"
# green node inputs: bus identity, a local repo, and a fake curl answering 200. Layers
# 00/10/30/40 are out of scope (PERF-013: only layer 20 rows are asserted here), but the
# inputs stay staged so this fixture still works as written if it is ever unscoped.
printf '{"agent":"fixture"}' > "$tmpd/home/.node/crier.json"; chmod 600 "$tmpd/home/.node/crier.json"
git -C "$tmpd/home/repo" init -q -b main
git -C "$tmpd/home/repo" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm fixture --allow-empty
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
chmod +x "$tmpd/bin/curl"
cat > "$tmpd/scripts/harness/install-fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
say "harness: fixture (cf-055)"
bad "harness:fixture/a" "simulated adapter failure one"
bad "harness:fixture/b" "simulated adapter failure two"
exit 1
EOF
chmod +x "$tmpd/scripts/harness/install-fixture.sh"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=fixture \
  NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
  /bin/bash "$tmpd/scripts/project-node.sh" --check --layers 20 2>&1); rc=$?
fail_rows=$(printf '%s\n' "$out" | grep -c '^  FAIL')
summary=$(printf '%s\n' "$out" | grep -oE '^NODE: FAIL \([0-9]+\)$' | grep -oE '[0-9]+')
if [ "$rc" -ne 0 ] && [ -n "$summary" ] && [ "$summary" = "$fail_rows" ] && [ "$fail_rows" -ge 2 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  harness:fixture/a — simulated adapter failure one'; then
  say "  PASS  adapter FAIL rows counted: $fail_rows rows -> NODE: FAIL ($summary)"
else
  say "  FAIL  summary said $summary but the run printed $fail_rows FAIL rows"; fails=$((fails+1))
fi
# the same fixture goes green: a passing adapter must keep NODE: PASS and exit 0
sed -e 's/^bad /ok /' -e 's/failure one/pass one/' -e 's/failure two/pass two/' \
  -e 's/^exit 1$/exit 0/' "$tmpd/scripts/harness/install-fixture.sh" \
  > "$tmpd/scripts/harness/install-fixture.sh.new"
mv "$tmpd/scripts/harness/install-fixture.sh.new" "$tmpd/scripts/harness/install-fixture.sh"
chmod +x "$tmpd/scripts/harness/install-fixture.sh"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=fixture \
  NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
  /bin/bash "$tmpd/scripts/project-node.sh" --check --layers 20 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL')" = 0 ] \
  && printf '%s\n' "$out" | grep -Fq 'NODE: PASS'; then
  say "  PASS  passing adapter keeps NODE: PASS and exit 0"
else
  say "  FAIL  passing adapter produced FAIL rows or a nonzero exit"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# ch:trace row=CF-054 spec=README.md#status wave=none:serial test=tests/selftest.sh::readme-rerun-line-carries-status doc=README.md prompt=prompts/readme.md evidence=tests/selftest.sh::readme-rerun-line-carries-status witness=none:local-fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unresolved-namespace
say "15. the README status re-run line carries the node check's exit status (CF-054)"
# The documented re-run used to end in `; git -C "$home/repo" rev-parse HEAD`, so a run that
# printed NODE: FAIL still exited 0 — the read-back's status became the line's status. This
# probe binds the documented command span and then proves the masking on a local fixture:
# the clone succeeds (so the read-back would succeed) while the bus layer fails.
doc_cmd=$(tr '`' '\n' < "$HERE/README.md" | grep -F 'project-node.sh --apply --project myproject' | head -1)
if [ -n "$doc_cmd" ] && printf '%s' "$doc_cmd" | grep -Fq 'CRIER_URL=' \
  && ! printf '%s' "$doc_cmd" | grep -Fq 'rev-parse'; then
  say "  PASS  documented line carries CRIER_URL= and no trailing read-back"
else
  say "  FAIL  documented line still relies on an export it does not carry, or ends in a read-back"; fails=$((fails+1))
fi
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts/harness" "$tmpd/bin"
cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" "$tmpd/scripts/"
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
cat > "$tmpd/scripts/harness/install-fixture.sh" <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
say "harness: fixture (cf-054)"
ok "harness:fixture" "simulated passing adapter"
exit 0
EOF
chmod +x "$tmpd/bin/curl" "$tmpd/scripts/harness/install-fixture.sh"
git init -q -b main "$tmpd/work"
git -C "$tmpd/work" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm fixture --allow-empty
git clone -q --bare "$tmpd/work" "$tmpd/origin.git"
# $1 = line shape, $2 = HOME, $3 = green (stage a 600 crier bundle) | red
cf054_run() {
  [ "$3" = green ] && { mkdir -p "$2/.node"; printf '{"agent":"fixture"}' > "$2/.node/crier.json"; chmod 600 "$2/.node/crier.json"; }
  env -i HOME="$2" PATH="$tmpd/bin:/usr/local/bin:/usr/bin:/bin" NODE_DISK_FLOOR=1 \
    NODE_PROJECT=myproject NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 \
    /bin/bash -c "$1" >"$2/out.log" 2>&1
  echo $?
}
node_call="bash '$tmpd/scripts/project-node.sh' --apply --project myproject --repo file://$tmpd/origin.git --ref main"
# The masking arm proves the trailing read-back's status wins over a NODE: FAIL. It needs
# the clone to succeed (layer 40) and the bus to fail (layer 30); 00/10/20 cannot change
# either outcome, so that arm runs 30,40 only (PERF-013). The two documented-shape arms
# below run the documented command as written and stay unscoped on purpose.
node_call_masking="$node_call --layers 30,40"
h=$(mktemp -d); rc=$(cf054_run "$node_call_masking; git -C '$h/repo' rev-parse HEAD" "$h" red)
old_summary=$(grep -E '^NODE: ' "$h/out.log" | tail -1)
if [ "$rc" = 0 ] && printf '%s' "$old_summary" | grep -Fq 'NODE: FAIL' \
  && git -C "$h/repo" rev-parse HEAD >/dev/null 2>&1; then
  say "  PASS  old shape exits 0 on a failed check ($old_summary) — the defect is real"
else
  say "  FAIL  old shape no longer masks a failed check; re-measure CF-054"; fails=$((fails+1))
fi
h=$(mktemp -d); rc=$(cf054_run "$node_call" "$h" red)
red_summary=$(grep -E '^NODE: ' "$h/out.log" | tail -1)
if [ "$rc" = 1 ] && printf '%s' "$red_summary" | grep -Fq 'NODE: FAIL'; then
  say "  PASS  documented shape exits $rc on a failed check ($red_summary)"
else
  say "  FAIL  documented shape exited $rc on a failed check"; fails=$((fails+1))
fi
h=$(mktemp -d); rc=$(cf054_run "$node_call" "$h" green)
green_summary=$(grep -E '^NODE: ' "$h/out.log" | tail -1)
if [ "$rc" = 0 ] && printf '%s' "$green_summary" | grep -Fq 'NODE: PASS'; then
  say "  PASS  documented shape exits 0 on a passing fixture ($green_summary)"
else
  say "  FAIL  documented shape exited $rc on a passing fixture ($green_summary)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-075 node-create-staged-set: real entry point and adapter, no network or installs.
say "16. node-create staged set covers the disk floor and names missing dependencies"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts/harness" "$tmpd/bin"
staged=$(bash "$HERE/scripts/node-create.sh" --staged-files); rc=$?
if [ "$rc" -eq 0 ]; then
  while IFS= read -r file; do
    cp "$HERE/scripts/$file" "$tmpd/scripts/$file" || fails=$((fails+1))
  done <<< "$staged"
else
  say "  FAIL  staging manifest validation exited $rc"; fails=$((fails+1))
fi
# Layer 00 resolves the real floor, but an impossible admission floor prevents installs.
# Both runs use fresh HOME and a deterministic df, regardless of host free space.
cat > "$tmpd/bin/df" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' 'fixture 1048576 0 1048576 0% /'
EOF
chmod +x "$tmpd/bin/df"
out=$(env -i HOME="$tmpd/home" PATH="$tmpd/bin:$PATH" NODE_DISK_FLOOR=4096 \
  /bin/bash "$tmpd/scripts/project-node.sh" --apply --project fixture --harness hermes 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq '  PASS  disk_floor — 4096 GiB from env' \
  && printf '%s\n' "$out" | grep -Fq 'NODE: FAIL (disk admission)' \
  && ! printf '%s\n' "$out" | grep -Fq "can't open file"; then
  say "  PASS  staged disk floor resolves: 4096 GiB from env; admission refuses before installs"
else
  say "  FAIL  staged disk floor missing or not named (exit $rc)"; fails=$((fails+1))
fi
rm "$tmpd/scripts/disk_floor.py"
out=$(env -i HOME="$tmpd/missing-home" PATH="$tmpd/bin:$PATH" \
  /bin/bash "$tmpd/scripts/project-node.sh" --apply --project fixture --harness hermes 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  disk_floor — resolver missing or unreadable:')" = 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (1)' \
  && ! printf '%s\n' "$out" | grep -Fq "can't open file"; then
  say "  PASS  missing disk floor -> one countable FAIL row, NODE: FAIL (1), exit $rc"
  printf '%s\n' "$out"
else
  say "  FAIL  missing disk floor crashed or escaped counting (exit $rc)"; fails=$((fails+1))
fi
# Mutation: keep the dependency on disk, remove it ONLY from a scratch manifest.
cp "$HERE/scripts/disk_floor.py" "$tmpd/scripts/"
sed 's/lib.sh disk_floor.py/lib.sh/' "$HERE/scripts/node-create.sh" > "$tmpd/scripts/node-create.sh"
out=$(bash "$tmpd/scripts/node-create.sh" --staged-files 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'references unstaged disk_floor.py'; then
  say "  PASS  disk floor omitted from scratch manifest -> validation exit $rc"
else
  say "  FAIL  incomplete staging manifest accepted (exit $rc)"; fails=$((fails+1))
fi
# Stub only the bunker transport and control-host verifier. Provisioning fails, while
# staging succeeds (or cp fails explicitly); cleanup must identify only owned agents.
cp "$HERE/scripts/node-create.sh" "$tmpd/scripts/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpd/scripts/verify-node.sh"
chmod +x "$tmpd/scripts/verify-node.sh"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
if [ -n "${FIXTURE_LOG:-}" ]; then
  printf '%s\0' "$@" >> "$FIXTURE_LOG"
  printf '\n' >> "$FIXTURE_LOG"
fi
case "$1" in
  spawn) printf '%s\n' "$2" > "$FIXTURE_AGENT" ;;
  cp) [ "${FIXTURE_CP_FAIL:-0}" = 0 ] || { echo 'fixture copy refused' >&2; exit 1; } ;;
  exec) case "$*" in *NODE_PROJECT=*)
    if [ -n "${FIXTURE_SCRIPTS:-}" ]; then
      cmd="${!#}"
      cmd="${cmd/\~\/node-scripts\/project-node.sh/\'$FIXTURE_SCRIPTS\/project-node.sh\'}"
      # Model a separate node environment: the control host's export cannot leak in.
      env -u CRIER_URL HOME="$FIXTURE_NODE_HOME" /bin/bash -c \
        "$cmd --check --layers 00 --disk-floor 1"
      exit $?
    fi
    exit 1 ;;
  esac ;;
  *) echo 'unexpected bunker command' >&2; exit 99 ;;
esac
EOF
chmod +x "$tmpd/bin/bunker"
for arm in owned reused copy-failure; do
  agent_args=()
  cp_fail=0
  [ "$arm" = reused ] && agent_args=(--agent fixture-existing)
  [ "$arm" = copy-failure ] && cp_fail=1
  out=$(env -i HOME="$tmpd/control-home" PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture-server \
    FIXTURE_AGENT="$tmpd/agent" FIXTURE_CP_FAIL="$cp_fail" CRIER_URL=http://fixture.invalid:8767 \
    /bin/bash "$tmpd/scripts/node-create.sh" --project fixture "${agent_args[@]}" 2>&1); rc=$?
  if [ "$arm" = reused ]; then
    if [ "$rc" -eq 1 ] && ! printf '%s\n' "$out" | grep -Fq 'bunker destroy'; then
      say "  PASS  reused agent failure does not request destruction"
    else
      say "  FAIL  reused agent cleanup ownership (exit $rc)"; fails=$((fails+1))
    fi
  elif [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq "cleanup required: bunker destroy $(cat "$tmpd/agent") --server fixture-server" \
    && { [ "$arm" != copy-failure ] || printf '%s\n' "$out" | grep -Fq '  FAIL  staged — copy failed:'; }; then
    say "  PASS  $arm failure names spawned agent and explicit-server destroy command"
  else
    say "  FAIL  $arm failure lost cleanup command or staging error (exit $rc)"; fails=$((fails+1))
  fi
done

# CF-126 ARM A: the same transport fixture executes the real, staged layer 00.
# No install or network access: only the scoped checker runs, with curl stubbed.
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
chmod +x "$tmpd/bin/curl"
handoff_ok=1
for crier_value in 'http://fixture.invalid:8767' \
  "http://fixture.invalid:8767/a'b?x=\$(touch '$tmpd/injected')&y=one;two"; do
  : > "$tmpd/bunker-handoff.log"
  out=$(env -i HOME="$tmpd/control-home" PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture-server \
    CRIER_URL="$crier_value" FIXTURE_LOG="$tmpd/bunker-handoff.log" FIXTURE_AGENT="$tmpd/agent" \
    FIXTURE_SCRIPTS="$tmpd/scripts" FIXTURE_NODE_HOME="$tmpd/node-home" \
    /bin/bash "$tmpd/scripts/node-create.sh" --project fixture 2>&1); rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -aFq "CRIER_URL=" "$tmpd/bunker-handoff.log" \
    && { [ "$crier_value" != http://fixture.invalid:8767 ] \
      || grep -aFq "CRIER_URL='$crier_value'" "$tmpd/bunker-handoff.log"; } \
    && printf '%s\n' "$out" | grep -Eq '^  PASS  crier_url — ' \
    && printf '%s\n' "$out" | grep -Fxq "  PASS  crier_url — $crier_value" \
    && printf '%s\n' "$out" | grep -Eq '^NODE CREATED: node-fixture-' \
    && [ ! -e "$tmpd/injected" ]; then
    :
  else
    handoff_ok=0
    printf '%s\n' "$out"
  fi
done
if [ "$handoff_ok" -eq 1 ]; then
  say "  PASS  crier_url handoff preserves exported URL and shell metacharacters"
else
  say "  FAIL  crier_url handoff missing assignment or named node PASS"; fails=$((fails+1))
fi

# CF-126 ARM B: neither an unset nor an empty bus may cost a bunker invocation.
refusal_ok=1
for bus_state in unset empty; do
  bus_args=()
  [ "$bus_state" = empty ] && bus_args=(CRIER_URL=)
  : > "$tmpd/bunker-refusal.log"
  out=$(env -i HOME="$tmpd/control-home" PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture-server \
    FIXTURE_LOG="$tmpd/bunker-refusal.log" FIXTURE_AGENT="$tmpd/agent" "${bus_args[@]}" \
    /bin/bash "$tmpd/scripts/node-create.sh" --project fixture 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Eq '^  FAIL  crier_url — CRIER_URL (unset|empty)' \
    && [ ! -s "$tmpd/bunker-refusal.log" ] \
    && ! grep -aEq '^(spawn|create|exec)' "$tmpd/bunker-refusal.log"; then
    :
  else
    refusal_ok=0
    printf '%s\n' "$out"
  fi
done
if [ "$refusal_ok" -eq 1 ]; then
  say "  PASS  crier_url refusal rejects unset and empty bus before bunker invocation"
else
  say "  FAIL  crier_url refusal missing named FAIL or invoked bunker"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-077: stub transport only; exercise the real verifier and node-create admission.
say "17. auth verification fails closed, with a pre-fix detector control"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/bin" "$tmpd/before"
cp "$HERE/scripts/lib.sh" "$tmpd/before/"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in *hostname\ -I*) echo 127.0.0.1; exit 0 ;; esac
done
echo ALIVE fixture
EOF
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
o="" u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) o="$2"; shift 2 ;;
    -*) shift ;;
    *) u="$1"; shift ;;
  esac
done
case "$u" in */api/system/stats) c="${STATS_CODE:-404}" ;; *) c=200 ;; esac
if [ -n "$o" ] && [ "$o" != /dev/null ]; then
  printf '%s' "${STATUS_BODY:?}" > "$o"
fi
printf '%s' "$c"
EOF
chmod +x "$tmpd/bin/bunker" "$tmpd/bin/curl"
cf077_run() {
  env PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture CRIER_URL=http://fixture.invalid:8767 \
    STATS_CODE="$1" STATUS_BODY="$2" \
    /bin/bash "$3" "${@:4}" 2>&1
}
body='{"status":"ok","auth_required":true}'
# Immutable pre-fix source, not a mock of the failure or the current implementation.
if git -C "$HERE" show bbb0719:scripts/verify-node.sh > "$tmpd/before/verify-node.sh"; then
  out=$(cf077_run 404 "$body" "$tmpd/before/verify-node.sh" --agent f); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
    && printf '%s\n' "$out" | grep -Eq '^  WARN  unauth_refused — /api/system/stats -> 404$'; then
    say "  PASS  pre-fix 404 incorrectly passes: fixture detects CF-077"
  else
    say "  FAIL  pre-fix 404 detector control (exit $rc)"; fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source unavailable"; fails=$((fails+1))
fi
# 000 is its own verdict now: an unreachable port with the gateway answering inside the node is
# UNVERIFIED (exit 3), not FAIL — a transport gap is not a broken node, and calling it a failure is
# what trained operators to ignore the last line (CF-224).
out=$(cf077_run 000 "$body" "$HERE/scripts/verify-node.sh" --agent f); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Eq '^  WARN  unauth_refused — unverified' \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED' \
  && printf '%s\n' "$out" | grep -Eq '^  PASS  agent_alive'; then
  say "  PASS  auth stats 000 -> WARN gateway_reachable, exit $rc (UNVERIFIED, not FAIL)"
else
  say "  FAIL  auth stats 000 was not reported as UNVERIFIED (exit $rc): $(printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN)|^VERIFY' | head -4 | tr '\n' ' ')"
  fails=$((fails+1))
fi

for c in 401 302 403 404 500 200; do
  out=$(cf077_run "$c" "$body" "$HERE/scripts/verify-node.sh" --agent f); rc=$?
  case "$c" in 401|302|403) want=0; row=PASS; summary='VERIFY: PASS' ;; *) want=1; row=FAIL; summary='VERIFY: FAIL (1)' ;; esac
  if [ "$rc" -eq "$want" ] && printf '%s\n' "$out" | grep -Fxq "$summary" \
    && printf '%s\n' "$out" | grep -Eq "^  $row  unauth_refused — /api/system/stats -> $c( |$)" \
    && printf '%s\n' "$out" | grep -Eq '^  PASS  auth_gate'; then
    say "  PASS  auth stats $c -> $row, exit $rc"
  else
    say "  FAIL  auth stats $c did not produce named $row (exit $rc)"; fails=$((fails+1))
  fi
done
for body in '{"status":"ok"}' '{"auth_required":false}' '{"auth_required":trueish}'; do
  out=$(cf077_run 401 "$body" "$HERE/scripts/verify-node.sh" --agent f); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Eq '^  FAIL  auth_gate — /api/status -> 200;' \
    && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
    && printf '%s\n' "$out" | grep -Eq '^  PASS  unauth_refused'; then
    say "  PASS  auth marker $body -> named auth_gate FAIL, exit $rc"
  else
    say "  FAIL  auth marker $body was not refused (exit $rc)"; fails=$((fails+1))
  fi
done
say "18. node creation requires both auth legs, not just successful provisioning"
for arm in refused missing-marker closed; do
  c=401; body='{"auth_required":true}'; want=0; summary='NODE CREATED: f'
  [ "$arm" = refused ] && c=404
  [ "$arm" = missing-marker ] && body='{"status":"ok"}'
  [ "$arm" != closed ] && { want=1; summary='NODE INCOMPLETE (1)'; }
  out=$(cf077_run "$c" "$body" "$HERE/scripts/node-create.sh" --project f \
    --repo git@example.invalid:x/y.git --harness hermes --agent f); rc=$?
  row=unauth_refused; [ "$arm" = missing-marker ] && row=auth_gate
  if [ "$rc" -eq "$want" ] && printf '%s\n' "$out" | grep -Fxq "$summary" \
    && { [ "$want" -eq 0 ] || { printf '%s\n' "$out" | grep -Eq "^  FAIL  $row" \
      && ! printf '%s\n' "$out" | grep -q '^NODE CREATED:'; }; }; then
    say "  PASS  node-create $arm -> $summary, exit $rc"
  else
    say "  FAIL  node-create $arm admitted an unverified node or rejected control (exit $rc)"; fails=$((fails+1))
  fi
done
rm -rf "$tmpd"

say "19. project repo_url must name a real git root (CF-085)"
tmpd=$(mktemp -d)
git init -q -b main "$tmpd/repo"
git -C "$tmpd/repo" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
accepted=$(python3 -B "$HERE/scripts/lane_target.py" repo-url "local:$tmpd/repo" 2>&1); accepted_rc=$?
rejected=$(python3 -B "$HERE/scripts/lane_target.py" repo-url "local:$tmpd/phantom" 2>&1); rejected_rc=$?
head=$(git -C "$tmpd/repo" rev-parse HEAD)
if [ "$accepted_rc" -eq 0 ] && [ "$rejected_rc" -eq 4 ] \
  && printf '%s\n' "$accepted" | grep -Fxq "PASS repo_url 'local:$tmpd/repo' — root '$tmpd/repo' HEAD $head" \
  && printf '%s\n' "$accepted" | grep -Fxq 'repo_url: 0 rejected, 1 accepted' \
  && printf '%s\n' "$rejected" | grep -Fxq "FAIL repo_url 'local:$tmpd/phantom' — path does not exist or is not a directory" \
  && printf '%s\n' "$rejected" | grep -Fxq 'repo_url: 1 rejected, 0 accepted'; then
  say "  PASS  repo_url guard rejects a phantom local: root (1 rejected, 1 accepted)"
else
  say "  FAIL  repo_url guard fixture (accepted exit $accepted_rc, rejected exit $rejected_rc)"
  fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-007 AC3: reclaim-before-refusal, using the shipped scripts in a local HOME.
say "20. reclaim runs before disk refusal, while check never reaps"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts" "$tmpd/bin" "$tmpd/home/.cache/pip"
cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" \
  "$HERE/scripts/reclaim_disk.py" "$tmpd/scripts/"
dd if=/dev/zero of="$tmpd/home/.cache/pip/payload" bs=4096 count=2 2>/dev/null
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
chmod +x "$tmpd/bin/curl"
out=$(env -i PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_DISK_FLOOR=4096 \
  CRIER_URL=http://fixture.invalid /bin/bash "$tmpd/scripts/project-node.sh" \
  --apply --project fixture --layers 00 2>&1); rc=$?
reap_line=$(printf '%s\n' "$out" | awk '/^  reap  .cache\/pip —/{print NR; exit}')
fail_line=$(printf '%s\n' "$out" | awk '/^  FAIL  disk —/{print NR; exit}')
if [ "$rc" -ne 0 ] && [ -n "$reap_line" ] && [ -n "$fail_line" ] \
  && [ "$reap_line" -lt "$fail_line" ] && [ ! -e "$tmpd/home/.cache/pip" ] \
  && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  disk —')" = 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (disk admission)'; then
  say "  PASS  pip cache reaped before one final disk FAIL; admission still refuses"
else
  say "  FAIL  reclaim-before-refusal ordering or deletion (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
mkdir -p "$tmpd/home/.cache/pip"
dd if=/dev/zero of="$tmpd/home/.cache/pip/payload" bs=4096 count=2 2>/dev/null
out=$(env -i PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_DISK_FLOOR=4096 \
  CRIER_URL=http://fixture.invalid /bin/bash "$tmpd/scripts/project-node.sh" \
  --check --project fixture --layers 00 2>&1); rc=$?
if [ "$rc" -ne 0 ] && [ -f "$tmpd/home/.cache/pip/payload" ] \
  && [ "$(wc -c < "$tmpd/home/.cache/pip/payload")" = 8192 ] \
  && printf '%s\n' "$out" | grep -Fq 'check mode never mutates' \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (1)' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  reach:https://pypi.org/simple/'; then
  say "  PASS  check preserves pip bytes, counts one disk failure and continues preflight"
else
  say "  FAIL  check mutated the cache or stopped measuring (exit $rc)"; fails=$((fails+1))
fi
# Positive control: df becomes green only after the real reclaimer removes pip.
cat > "$tmpd/bin/df" <<'EOF'
#!/usr/bin/env bash
blocks=0
[ ! -e "$HOME/.cache/pip" ] && blocks=2097152
printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' "fixture 2097152 0 $blocks 0% /"
EOF
chmod +x "$tmpd/bin/df"
out=$(env -i PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_DISK_FLOOR=1 \
  CRIER_URL=http://fixture.invalid /bin/bash "$tmpd/scripts/project-node.sh" \
  --apply --project fixture --layers 00 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '2.0 GB free after reclaim (freed ' \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS' \
  && ! printf '%s\n' "$out" | grep -q '^  FAIL'; then
  say "  PASS  re-measure admits a recovered node without a stale FAIL row"
else
  say "  FAIL  recovered node was not admitted (exit $rc)"; fails=$((fails+1))
fi
rm "$tmpd/scripts/reclaim_disk.py"
out=$(env -i PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_DISK_FLOOR=4096 \
  /bin/bash "$tmpd/scripts/project-node.sh" --apply --project fixture --layers 00 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  disk_floor — reclaimer missing or unreadable:')" = 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (1)'; then
  say "  PASS  missing reclaimer fails closed with one counted row"
else
  say "  FAIL  missing reclaimer escaped counting (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_reclaim.py" >/dev/null 2>&1; then
  say "  PASS  reclaim targets, TTL, symlink safety, protected files, dry-run and idempotence"
else
  say "  FAIL  reclaim contract"; fails=$((fails+1))
fi
# CF-091 intra-family repo_url agreement: satellites of one family must carry the
# primary's repo_url, not just any valid git root (two different-but-valid roots
# both PASS per row, which is the defect this arm pins).
say "21. project repo_url satellites must agree with their primary (CF-091)"
tmpd=$(mktemp -d)
git init -q -b main "$tmpd/repo-a"
git -C "$tmpd/repo-a" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
git init -q -b main "$tmpd/repo-b"
git -C "$tmpd/repo-b" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
printf '[{"name":"fixture-primary","repo_url":"local:%s"},{"name":"fixture-primary-qa","repo_url":"local:%s"}]' \
  "$tmpd/repo-a" "$tmpd/repo-b" > "$tmpd/diverged.json"
printf '[{"name":"fixture-primary","repo_url":"local:%s"},{"name":"fixture-primary-qa","repo_url":"local:%s"}]' \
  "$tmpd/repo-a" "$tmpd/repo-a" > "$tmpd/aligned.json"
diverged=$(python3 -B "$HERE/scripts/lane_target.py" repo-url --row "$tmpd/diverged.json" 2>&1); diverged_rc=$?
aligned=$(python3 -B "$HERE/scripts/lane_target.py" repo-url --row "$tmpd/aligned.json" 2>&1); aligned_rc=$?
if [ "$diverged_rc" -ne 0 ] \
  && printf '%s\n' "$diverged" | grep -Fq "repo_url diverges from primary 'fixture-primary'" \
  && printf '%s\n' "$diverged" | grep -Fq '[fixture-primary]' \
  && printf '%s\n' "$diverged" | grep -Fq '[fixture-primary-qa]' \
  && [ "$aligned_rc" -eq 0 ] \
  && printf '%s\n' "$aligned" | grep -Fq 'repo_url: 0 rejected, 2 accepted'; then
  say "  PASS  repo_url family agreement: diverged fixture rejected naming both lanes, aligned accepted"
else
  say "  FAIL  repo_url family agreement (diverged exit $diverged_rc, aligned exit $aligned_rc)"
  fails=$((fails+1))
fi
rm -rf "$tmpd"

# BEGIN census-fail-closed
# CF-089: exercise the mirrored README recipe through real curl/jq, not stubs.
# Each invocation owns a timeout-bounded server and its cleanup.
# CF-117: the fixture binds an EPHEMERAL port and publishes it via --port-file, so two
# gate instances running in the same scheduler slot cannot bind, or answer, each other's port.
cf089_run() {
  local mode="$1" fixture ready=0 attempt port=
  local tmpd
  tmpd=$(mktemp -d)
  timeout 20s python3 -B "$HERE/docs/audits/cf089-census-standin.py" \
    --mode "$mode" --port 0 --port-file "$tmpd/port" >"$tmpd/server.log" 2>&1 &
  fixture=$!
  for attempt in {1..50}; do
    port=$(head -n 1 "$tmpd/port" 2>/dev/null || :)
    if [ -n "$port" ] \
      && curl -fsS --max-time 1 "http://127.0.0.1:$port/api/v1/projects?limit=1" >/dev/null 2>&1; then
      ready=1; break
    fi
    kill -0 "$fixture" 2>/dev/null || break
    sleep 0.05
  done
  if [ "$ready" -eq 1 ] && kill -0 "$fixture" 2>/dev/null; then
    BASE="http://127.0.0.1:$port" timeout 10s bash "$HERE/docs/audits/cf089-census-recipe.sh" \
      >"$tmpd/stdout" 2>"$tmpd/stderr"; rc=$?
    census_stdout=$(cat "$tmpd/stdout")
    out=$(cat "$tmpd/stderr")
  else
    rc=99; census_stdout=
    out="fixture did not start on port ${port:-unknown}: $(cat "$tmpd/server.log")"
  fi
  kill "$fixture" 2>/dev/null || :
  wait "$fixture" 2>/dev/null || :
  rm -rf "$tmpd"
}

say "22. census refuses a failed fetch at a later offset"
cf089_run fetch
if [ "$rc" -eq 1 ] && [ -z "$census_stdout" ] \
  && printf '%s\n' "$out" | grep -Fxq 'census: fetch failed at offset=500'; then
  say "  PASS  census fetch failure -> offset=500, exit $rc, no census printed"
else
  say "  FAIL  census fetch guard (exit $rc): $out"; fails=$((fails+1))
fi

say "23. census refuses a non-2xx page"
cf089_run broken
if [ "$rc" -eq 1 ] && [ -z "$census_stdout" ] \
  && [ "$out" = 'census: HTTP 502 at offset=500; refusing to count' ]; then
  say "  PASS  census HTTP 502 -> offset=500, exit $rc, no census printed"
else
  say "  FAIL  census HTTP guard (exit $rc): $out"; fails=$((fails+1))
fi

say "24. census requires a projects array even on HTTP 200"
for mode in missing-projects wrong-projects nonjson; do
  cf089_run "$mode"
  if [ "$rc" -eq 1 ] && [ -z "$census_stdout" ] \
    && [ "$out" = 'census: missing or invalid .projects array at offset=500' ]; then
    say "  PASS  census $mode -> named .projects refusal, exit $rc, no census printed"
  else
    say "  FAIL  census .projects guard ($mode, exit $rc): $out"; fails=$((fails+1))
  fi
done

say "25. census compares all received rows with the first reported total"
cf089_run short
if [ "$rc" -eq 1 ] && [ -z "$census_stdout" ] \
  && [ "$out" = 'census: rows received=865 != total reported=866; refusing to count' ]; then
  say "  PASS  census short page -> rows received=865, total reported=866, exit $rc, no census printed"
else
  say "  FAIL  census row-total guard (exit $rc): $out"; fails=$((fails+1))
fi

say "26. healthy census counts matching rows on both sides of the page boundary"
cf089_run healthy
expected=$(printf '%s\n' 2 'code-factory enabled=true admission=cooldown parent=x' \
  'code-factory enabled=true admission=cooldown parent=x')
if [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$census_stdout" = "$expected" ]; then
  say "  PASS  census healthy -> 2 matching rows, exact row format, exit $rc"
else
  say "  FAIL  census healthy path (exit $rc): $out / $census_stdout"; fails=$((fails+1))
fi

say "27. census still refuses a missing total"
cf089_run nototal
if [ "$rc" -eq 1 ] && [ -z "$census_stdout" ] \
  && [ "$out" = 'census: the scheduler answered without a total; refusing to count' ]; then
  say "  PASS  census missing total -> named refusal, exit $rc, no census printed"
else
  say "  FAIL  census missing-total guard (exit $rc): $out"; fails=$((fails+1))
fi

say "28. README census and executable mirror agree except for BASE"
if python3 - "$HERE" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
lanes = (root / "README.md").read_text().split("## The lanes\n", 1)[1]
block = lanes.split("```bash\n", 1)[1].split("\n```", 1)[0]
mirror = (root / "docs/audits/cf089-census-recipe.sh").read_text().splitlines()
assert mirror[0] == "#!/usr/bin/env bash"
assert mirror[1].startswith('# Verbatim README.md "The lanes" census recipe')
assert block.splitlines()[1] == "BASE=http://127.0.0.1:9090"
assert mirror[3] == 'BASE="${BASE:-http://127.0.0.1:9090}"'
mirror[3] = "BASE=http://127.0.0.1:9090"
assert "\n".join(mirror[2:]) == block, "README census differs from executable mirror"
PY
then
  say "  PASS  census README/mirror byte parity (BASE parameterisation only)"
else
  say "  FAIL  census README/mirror drift"; fails=$((fails+1))
fi
# END census-fail-closed

say "29. a workdir board that is not the published board is named as drift (CF-114)"
tmpd=$(mktemp -d)
if python3 - "$HERE" "$tmpd" <<'PY'
from pathlib import Path
import json
import shutil
import sys

root, fixture = map(Path, sys.argv[1:])
board = Path(".coding-hermes/board")
published = fixture / "published"
published.mkdir()
for name in ("tasks.jsonl", "events.jsonl"):
    shutil.copyfile(root / board / name, published / name)
lines = (published / "tasks.jsonl").read_bytes().splitlines(keepends=True)
records = [json.loads(line) for line in lines]
flipped = next(i for i, row in enumerate(records) if row["status"] == "complete")
deleted = next(i for i in reversed(range(len(records))) if i != flipped)
(fixture / "expected").write_text(
    f"{records[flipped]['id']} {records[deleted]['id']} {len(lines) - 1} {len(lines)}\n"
)
for arm in ("red", "green", "zero", "missing", "malformed", "nonobject", "event-drift"):
    target = fixture / arm / board
    target.mkdir(parents=True)
    for name in ("tasks.jsonl", "events.jsonl"):
        shutil.copyfile(published / name, target / name)
    if arm == "red":
        mutated = lines.copy()
        row = dict(records[flipped], status="pending")
        mutated[flipped] = (json.dumps(row) + "\n").encode()
        del mutated[deleted]
        (target / "tasks.jsonl").write_bytes(b"".join(mutated))
    elif arm == "zero":
        (target / "tasks.jsonl").write_bytes(b"")
    elif arm == "missing":
        (target / "events.jsonl").unlink()
    elif arm in ("malformed", "nonobject"):
        mutated = lines.copy()
        mutated[1] = b"{\n" if arm == "malformed" else b"null\n"
        (target / "tasks.jsonl").write_bytes(b"".join(mutated))
    elif arm == "event-drift":
        with (target / "events.jsonl").open("ab") as stream:
            stream.write(b"\n")
PY
then
  read -r flipped deleted red_count published_count < "$tmpd/expected"
  for arm in red green zero missing malformed nonobject event-drift; do
    expected_rc=1
    expected_result='RESULT: DRIFT ('
    case "$arm" in
      red) expected="FAIL  board rows — $red_count vs $published_count rows; 2 divergent ids: " ;;
      green) expected_rc=0; expected_result='RESULT: OK'; expected="PASS  board rows — $published_count vs $published_count rows; 0 divergent ids: none" ;;
      zero) expected='FAIL  board rows — tasks.jsonl has 0 rows' ;;
      missing) expected='FAIL  workdir files — events.jsonl:' ;;
      malformed) expected='FAIL  workdir tasks.jsonl line 2 — invalid JSON:' ;;
      nonobject) expected='FAIL  workdir tasks.jsonl line 2 — expected JSON object' ;;
      event-drift) expected='FAIL  byte parity events.jsonl — bytes differ' ;;
    esac
    out=$(python3 -B "$HERE/scripts/board_drift.py" check --workdir "$tmpd/$arm" \
      --published-dir "$tmpd/published" 2>&1); rc=$?
    if [ "$rc" -eq "$expected_rc" ] \
      && printf '%s\n' "$out" | grep -Fq "$expected" \
      && printf '%s\n' "$out" | grep -Fq "$expected_result" \
      && ! printf '%s\n' "$out" | grep -Fq 'Traceback (most recent call last)'; then
      if [ "$arm" = red ] \
        && { ! printf '%s\n' "$out" | grep -Fq "$flipped: workdir=pending published=complete" \
          || ! printf '%s\n' "$out" | grep -Fxq "FAIL  board missing ids — $deleted" \
          || ! printf '%s\n' "$out" | grep -E "^FAIL  board rows —" | grep -Fq "$flipped" \
          || ! printf '%s\n' "$out" | grep -E "^FAIL  board rows —" | grep -Fq "$deleted"; }; then
        say "  FAIL  publish-drift red fixture omitted a divergent id"; fails=$((fails+1))
        printf '%s\n' "$out"
      else
        say "  PASS  publish-drift $arm fixture, exit $rc"
      fi
    else
      say "  FAIL  publish-drift $arm fixture (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out"
    fi
  done
else
  say "  FAIL  publish-drift fixture setup"; fails=$((fails+1))
fi
rm -rf "$tmpd"

say "30. README Status rows 1 and 3 cite the interpreter-qualified --check"
# Status rows "Hermes in a bunker + HTTP gateway over tailnet" and "Node inference credential"
# bind to `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check`: on this
# host's default python3 (3.14) the unqualified command stops at `FAIL python` and never
# reaches the `inference_key` row they are cited for. A row's prose may also mention the bare
# variable — only the qualified command binds the row, so that is what this arm requires.
# A renamed row must be re-bound, not silently dropped (CF-093).
status_rows_missing_qualifier() {  # $1=README $2=repo root -> prints one line per offending Status row, returns 1 if any
  local readme="$1" rc=0 label row
  for label in 'Hermes in a bunker + HTTP gateway over tailnet' 'Node inference credential'; do
    row=$(grep '^|' "$readme" | grep -F "$label" | head -1)
    if [ -z "$row" ]; then
      echo "absent-row: $label"; rc=1
    elif ! printf '%s' "$row" | grep -Fq 'HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check'; then
      echo "missing-qualifier: $label"; rc=1
    fi
  done
  return $rc
}
if status_rows_missing_qualifier "$HERE/README.md" "$HERE" >/dev/null; then
  say "  PASS  README Status rows 1 and 3 cite the interpreter-qualified --check"
else
  say "  FAIL  README Status row lost its interpreter-qualified --check: $(status_rows_missing_qualifier "$HERE/README.md" "$HERE" | tr '\n' ' ')"
  fails=$((fails+1))
fi
# negative fixture: a README whose Status rows lost the qualified command must be refused
tmpd=$(mktemp -d)
sed 's/HERMES_PYTHON_BIN=python3\.12 //g' "$HERE/README.md" > "$tmpd/README.md"
if status_rows_missing_qualifier "$tmpd/README.md" "$HERE" >/dev/null; then
  say "  FAIL  a README whose Status rows lost the qualified command was accepted"; fails=$((fails+1))
else
  say "  PASS  unqualified Status rows refused ($(status_rows_missing_qualifier "$tmpd/README.md" "$HERE" | tr '\n' ' '))"
fi
rm -rf "$tmpd"
# ch:trace row=CF-127 spec=specs/HARNESS.md wave=none:serial test=tests/selftest.sh::pip-log-path doc=docs/audits/code-factory-CF-127-fix-2026-11-03.md prompt=none:foreman-brief evidence=docs/audits/code-factory-CF-127-fix-2026-11-03.md witness=tests/selftest.sh::pip-log-path verdict=none:foreman-judges commit=none:self-referential-hash memory=none:foreman-writes
# BEGIN pip-log-path
say "31. Hermes pip logs are private per run and distinguish filesystem failures (CF-127)"
tmpd=$(mktemp -d)
# Use a private equivalent of /tmp/hermes-install.log here: the suite must not
# modify a host's existing log. The audit captures the literal /tmp reproduction.
if python3 - "$HERE" "$tmpd" <<'PY'
from pathlib import Path
import shutil
import sys

root, fixture = map(Path, sys.argv[1:])
(fixture / "bin").mkdir()
(fixture / "home").mkdir()
(fixture / "scripts" / "harness").mkdir(parents=True)
shutil.copyfile(root / "scripts/lib.sh", fixture / "scripts/lib.sh")
source = (root / "scripts/harness/install-hermes.sh").read_text()
start = source.index('    "$PYTHON_BIN" -m venv')
end = source.index('\n  else\n    note "already installed:', start)
legacy = '''    "$PYTHON_BIN" -m venv "$VENV" || { bad "venv" "creation failed"; exit 1; }
    "$VENV/bin/python" -m pip install --no-cache-dir "hermes-agent==$PIN" >"$PIP_FIXTURE/hermes-install.log" 2>&1 \\
      && ok "install" "$("$VENV/bin/hermes" --version 2>/dev/null | head -1)" \\
      || { bad "install" "pip failed — /tmp/hermes-install.log"; exit 1; }'''
(fixture / "scripts/harness/old.sh").write_text(source[:start] + legacy + source[end:])
fixed = fixture / "hermes-install.log"
fixed.touch(mode=0o600)
fixed.chmod(0o444)
stubs = {
    "python3": '''#!/usr/bin/env bash
set -uo pipefail
case "$*" in
  --version) echo 'Python 3.12.3' ;;
  '-m venv '*)
    mkdir -p "$3/bin"
    cp "$PIP_FIXTURE/bin/python3" "$3/bin/python"
    ;;
  '-m pip install --no-cache-dir hermes-agent==0.19.0')
    echo 'pip invoked' >> "$PIP_FIXTURE/pip.calls"
    echo 'fixture pip output'
    if [ "${FIXTURE_PIP_RC:-23}" -eq 0 ]; then
      cp "$PIP_FIXTURE/bin/hermes.stub" "$HOME/hermes-venv/bin/hermes"
    fi
    exit "${FIXTURE_PIP_RC:-23}"
    ;;
  *) exit 99 ;;
esac
''',
    "hermes.stub": "#!/usr/bin/env bash\necho 'hermes fixture 0.19.0'\n",
    "ss": "#!/usr/bin/env bash\nexit 1\n",
    "mktemp": '''#!/usr/bin/env bash
if [ "${FIXTURE_LOG_DENY:-0}" = 1 ]; then
  echo "fixture: $1: Permission denied" >&2
  exit 1
fi
exec /usr/bin/mktemp "$@"
''',
}
for name, text in stubs.items():
    path = fixture / "bin" / name
    path.write_text(text)
    path.chmod(0o755)
PY
then
  pip_fixture_run() {
    env LC_ALL=C PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
      PIP_FIXTURE="$tmpd" HERMES_PYTHON_BIN=python3 HERMES_PIN=0.19.0 \
      NODE_GATEWAY_PORT=10800 FAILED=0 FIXTURE_PIP_RC="${pip_fixture_rc:-23}" \
      FIXTURE_LOG_DENY="${pip_fixture_deny:-0}" /bin/bash "$@"
  }
  old_out=$(pip_fixture_run "$tmpd/scripts/harness/old.sh" --apply 2>&1); rc=$?
  expected="$(grep -nF '>"$PIP_FIXTURE/hermes-install.log"' "$tmpd/scripts/harness/old.sh" | cut -d: -f1)"
  expected="$tmpd/scripts/harness/old.sh: line $expected: $tmpd/hermes-install.log: Permission denied"
  if [ "$rc" -eq 1 ] && [ ! -e "$tmpd/pip.calls" ] \
    && [ "$(printf '%s\n' "$old_out" | grep -Fxc -- "$expected")" = 1 ] \
    && [ "$(printf '%s\n' "$old_out" | grep -Fxc '  FAIL  install — pip failed — /tmp/hermes-install.log')" = 1 ]; then
    say "  PASS  pip-log old shape: permission denied, exact misleading row, pip not invoked"
  else
    say "  FAIL  pip-log old shape did not reproduce the red fixture"; fails=$((fails+1))
  fi
  before_check=$(pip_fixture_run "$HERE/scripts/harness/install-hermes.sh" --check 2>&1); rc=$?
  shopt -s nullglob
  logs=("$tmpd/home"/.hermes-install-*.log)
  expected='  FAIL  binary — absent — run --apply'
  if [ "$rc" -eq 1 ] && [ "${#logs[@]}" -eq 0 ] && [ ! -e "$tmpd/pip.calls" ] \
    && [ "$(printf '%s\n' "$before_check" | grep -Fxc -- "$expected")" = 1 ] \
    && [ "$(printf '%s\n' "$before_check" | grep -Fxc 'HERMES: FAIL (3)')" = 1 ]; then
    say "  PASS  pip-log --check: unchanged absent-binary rows, no log or pip invocation"
  else
    say "  FAIL  pip-log --check wrote a log or changed check behaviour"; fails=$((fails+1))
  fi
  for run in 1 2; do
    out=$(pip_fixture_run "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
    logs=("$tmpd/home"/.hermes-install-*.log)
    pip_log=$(printf '%s\n' "$out" | sed -n 's/^  FAIL  install — pip exited 23 — log: //p')
    expected="  FAIL  install — pip exited 23 — log: $pip_log"
    if [ "$rc" -eq 1 ] && [ "${#logs[@]}" -eq "$run" ] \
      && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ] \
      && [[ "$pip_log" == "$tmpd/home/.hermes-install-10800."*.log ]] \
      && [ "$(stat -c %a "$pip_log" 2>/dev/null)" = 600 ] \
      && [ "$(grep -Fxc 'fixture pip output' "$pip_log" 2>/dev/null)" = 1 ] \
      && [ "$(grep -Fxc 'pip invoked' "$tmpd/pip.calls" 2>/dev/null)" -eq "$run" ] \
      && [ "$(stat -c %a "$tmpd/hermes-install.log")" = 444 ]; then
      say "  PASS  pip-log new shape run $run: pip rc 23, distinct HOME log mode 600, fixed file untouched"
    else
      say "  FAIL  pip-log new shape run $run did not distinguish pip's failure"; fails=$((fails+1))
    fi
  done
  pip_fixture_deny=1
  out=$(pip_fixture_run "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  template="$tmpd/home/.hermes-install-10800.XXXXXXXX.log"
  expected="  FAIL  install_log — cannot create $template — fixture: $template: Permission denied"
  if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ] \
    && [ "$(grep -Fxc 'pip invoked' "$tmpd/pip.calls")" = 2 ]; then
    say "  PASS  pip-log creation failure: exact filesystem row, pip not invoked"
  else
    say "  FAIL  pip-log creation failure was misreported"; fails=$((fails+1))
  fi
  pip_fixture_deny=0
  pip_fixture_rc=0
  out=$(pip_fixture_run "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  expected='  PASS  install — hermes fixture 0.19.0'
  logs=("$tmpd/home"/.hermes-install-*.log)
  if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ] \
    && [ "${#logs[@]}" -eq 3 ] && [ "$(grep -Fxc 'pip invoked' "$tmpd/pip.calls")" = 3 ]; then
    say "  PASS  pip-log successful install proceeds despite the unwritable fixed file"
  else
    say "  FAIL  pip-log successful install did not proceed"; fails=$((fails+1))
  fi
  after_check=$(pip_fixture_run "$HERE/scripts/harness/install-hermes.sh" --check 2>&1); rc=$?
  logs=("$tmpd/home"/.hermes-install-*.log)
  expected="  PASS  binary — $tmpd/home/hermes-venv/bin/hermes"
  if [ "$rc" -eq 1 ] && [ "${#logs[@]}" -eq 3 ] \
    && [ "$(grep -Fxc 'pip invoked' "$tmpd/pip.calls")" = 3 ] \
    && [ "$(printf '%s\n' "$after_check" | grep -Fxc -- "$expected")" = 1 ] \
    && [ "$(printf '%s\n' "$after_check" | grep -Fxc 'HERMES: FAIL (2)')" = 1 ]; then
    say "  PASS  pip-log installed --check: unchanged binary rows, no new log or pip invocation"
  else
    say "  FAIL  pip-log installed --check changed behaviour"; fails=$((fails+1))
  fi
  shopt -u nullglob
  unset -f pip_fixture_run
  unset pip_fixture_rc pip_fixture_deny
else
  say "  FAIL  pip-log fixture setup"; fails=$((fails+1))
fi
rm -rf "$tmpd"
# END pip-log-path

# BEGIN cf183-pinned-harness
say "31b. Hermes certifies the pinned venv binary, not a host-provided command (CF-183)"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/bin"
cat > "$tmpd/bin/hermes" <<'EOF'
#!/bin/sh
echo 'Hermes Agent v9.9.9-not-the-pin'
EOF
cat > "$tmpd/bin/hermes.pin" <<'EOF'
#!/bin/sh
echo 'hermes fixture 0.19.0'
EOF
cat > "$tmpd/bin/python" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  --version) echo 'Python 3.12.3' ;;
  '-m venv '*)
    echo venv >> "$CF183_FIXTURE/calls"
    mkdir -p "$3/bin"
    cp "$CF183_FIXTURE/bin/python" "$3/bin/python"
    ;;
  '-m pip install --no-cache-dir hermes-agent==0.19.0')
    echo 'pip hermes-agent==0.19.0' >> "$CF183_FIXTURE/calls"
    cp "$CF183_FIXTURE/bin/hermes.pin" "$HOME/hermes-venv/bin/hermes"
    ;;
  *) exit 99 ;;
esac
EOF
printf '#!/bin/sh\nexit 1\n' > "$tmpd/bin/ss"
chmod +x "$tmpd/bin/"*
cf183_run() {
  env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$cf183_home" TMPDIR="$tmpd" \
    HERMES_PYTHON_BIN="$tmpd/bin/python" HERMES_PIN=0.19.0 \
    NODE_GATEWAY_PORT=10800 CF183_FIXTURE="$tmpd" \
    /bin/bash "$HERE/scripts/harness/install-hermes.sh" "$@"
}
for arm in host-mismatch host-pin venv-mismatch venv-pin host-banner venv-banner; do
  cf183_home="$tmpd/$arm"
  mkdir -p "$cf183_home"
  : > "$tmpd/calls"
  cp "$tmpd/bin/hermes.pin" "$tmpd/bin/hermes"
  if [[ "$arm" = *mismatch ]]; then
    printf '#!/bin/sh\necho "Hermes Agent v9.9.9-not-the-pin"\n' > "$tmpd/bin/hermes"
  elif [[ "$arm" = *banner ]]; then
    printf '#!/bin/sh\necho "Hermes Agent v0.19.0 (2026.7.20) · upstream c419cf7c · local 770a952c (+1 carried commit)"\n' > "$tmpd/bin/hermes"
  fi
  if [[ "$arm" = venv-* ]]; then
    mkdir -p "$cf183_home/hermes-venv/bin"
    cp "$tmpd/bin/hermes" "$cf183_home/hermes-venv/bin/hermes"
    expected="  PASS  binary — $cf183_home/hermes-venv/bin/hermes"
  else
    expected="  FAIL  binary — host-provided $tmpd/bin/hermes (not installed by this adapter — run --apply)"
  fi
  out=$(cf183_run --check 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq "$expected" \
    && { if [[ "$arm" = *mismatch ]]; then
      printf '%s\n' "$out" | grep -Fxq '  FAIL  version — 9.9.9-not-the-pin != pin 0.19.0' \
        && ! printf '%s\n' "$out" | grep -q '^  PASS  version'
    else
      printf '%s\n' "$out" | grep -Fxq '  PASS  version — 0.19.0 (pin 0.19.0)'
    fi; }; then
    say "  PASS  cf183 $arm --check: ownership and measured version vs pin"
  else
    say "  FAIL  cf183 $arm --check (exit $rc): $out"; fails=$((fails+1))
  fi
  out=$(cf183_run --apply 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && [ -x "$cf183_home/hermes-venv/bin/hermes" ] \
    && { if [ "$arm" = venv-pin ] || [ "$arm" = venv-banner ]; then
      [ ! -s "$tmpd/calls" ] && printf '%s\n' "$out" | grep -Fq 'already installed:'
    else
      [ "$(grep -Fxc venv "$tmpd/calls")" = 1 ] \
        && [ "$(grep -Fxc 'pip hermes-agent==0.19.0' "$tmpd/calls")" = 1 ] \
        && ! printf '%s\n' "$out" | grep -Fq 'already installed:' \
        && { [ "$arm" != venv-mismatch ] \
          || printf '%s\n' "$out" | grep -Fq 'venv version 9.9.9-not-the-pin != pin 0.19.0 — installing pin'; }
    fi; }; then
    say "  PASS  cf183 $arm --apply: pinned venv installed or matching venv retained"
  else
    say "  FAIL  cf183 $arm --apply (exit $rc): $out"; fails=$((fails+1))
  fi
  out=$(cf183_run --check 2>&1); rc=$?
  if [ "$rc" -eq 1 ] \
    && printf '%s\n' "$out" | grep -Fxq "  PASS  binary — $cf183_home/hermes-venv/bin/hermes" \
    && printf '%s\n' "$out" | grep -Fxq '  PASS  version — 0.19.0 (pin 0.19.0)' \
    && printf '%s\n' "$out" | grep -Fxq 'HERMES: FAIL (2)'; then
    say "  PASS  cf183 $arm installed --check: owned pin passes, missing port/key still fail"
  else
    say "  FAIL  cf183 $arm installed --check (exit $rc): $out"; fails=$((fails+1))
  fi
done
unset -f cf183_run
unset cf183_home
rm -rf "$tmpd"
# END cf183-pinned-harness

# ch:trace row=CF-145 spec=README.md#quick-start test=tests/selftest.sh::quick-start-names-bunker-server doc=README.md prompt=prompts/readme.md evidence=tests/selftest.sh §32 witness=none:local-fixture verdict=none:open-until-judged commit=none:self-referential-hash memory=none:no-lane-role-token
say "32. the Quick start control-host commands name BUNKER_SERVER in a check row (CF-145)"
# README's fresh-host promise: with no bunker server, no Crier and no repo, all three Quick
# start commands reach their checkers and fail with the missing value named. The first and
# third used to die in ${BUNKER_SERVER:?} expansion before any checker ran — the value was
# named, but as a bash abort ("line N:") that no PASS/FAIL parser can see. The fixture pins
# PATH and HOME so the arm measures the script, not the host's tools (section 2's pattern).
tmpd=$(mktemp -d)
for arm in bunker-server-install node-create; do
  extra=()
  case "$arm" in
    bunker-server-install) args=(--check); closing='RESULT: FAIL (' ;;
    # node-create refuses an unset CRIER_URL before it reaches the server gate (CF-126),
    # so pin the bus to isolate the value this arm measures.
    node-create) args=(--project myrepo --repo https://github.com/you/myrepo --harness hermes);
                 closing='NODE INCOMPLETE ('; extra=(CRIER_URL=http://crier.example:8767) ;;
  esac
  out=$(env -i PATH=/usr/local/bin:/usr/bin:/bin HOME="$tmpd/home" "${extra[@]}" \
    /bin/bash "$HERE/scripts/$arm.sh" "${args[@]}" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] \
    && printf '%s\n' "$out" | grep -Eq '^  FAIL  .*BUNKER_SERVER' \
    && printf '%s\n' "$out" | grep -Fq "$closing" \
    && ! printf '%s\n' "$out" | grep -Eq 'line [0-9]+:' \
    && ! printf '%s\n' "$out" | grep -Fq 'unbound variable'; then
    say "  PASS  $arm without BUNKER_SERVER -> named FAIL row, exit $rc"
  else
    say "  FAIL  $arm aborted or did not name BUNKER_SERVER (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out"
  fi
done
rm -rf "$tmpd"

say "33. the board lock adjudicator proves a holder before calling a lock held (CF-119)"
# `.coding-hermes/board/.lock` is 0-byte residue with no shipped consumer and, before
# CF-119, no ignore rule, yet lanes stood down on its presence. scripts/board_lock.py
# must classify an unheld file as RESIDUE, call a lock HELD only when a live process
# proves it, and never mutate the file (a classifier that deletes would be a second
# defect). Verdict token is asserted, not the counts: the fixture lock lives outside a
# git repository, so commits_after_mtime is honestly `unknown` there.
tmpd=$(mktemp -d)
mkdir -p "$tmpd/board"
: > "$tmpd/board/.lock"
size_before=$(stat -c %s "$tmpd/board/.lock")
out=$(python3 -B "$HERE/scripts/board_lock.py" "$tmpd/board/.lock" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Eq '^RESIDUE consumers=[0-9]+ commits_after_mtime=' \
  && [ "$(stat -c %s "$tmpd/board/.lock")" = "$size_before" ]; then
  say "  PASS  unheld 0-byte lock -> RESIDUE, file untouched ($out)"
else
  say "  FAIL  unheld 0-byte lock not classified RESIDUE (rc=$rc): $out"; fails=$((fails+1))
fi
# HELD arm: a live process takes an exclusive flock and stays alive until reaped; the
# adjudicator must prove the holder (fd scan or EWOULDBLOCK), not the file's presence.
ready="$tmpd/ready"
python3 -B - "$tmpd/board/.lock" "$ready" <<'PY' &
import fcntl
import os
import sys
import time

lock, ready = sys.argv[1], sys.argv[2]
fd = os.open(lock, os.O_RDONLY)
fcntl.flock(fd, fcntl.LOCK_EX)
with open(ready, "w") as stream:
    stream.write("held\n")
deadline = time.time() + 10
while os.path.exists(ready) and time.time() < deadline:
    time.sleep(0.05)
PY
holder=$!
holder_ready=no
for _ in $(seq 1 30); do [ -f "$ready" ] && { holder_ready=yes; break; }; sleep 0.1; done
out=$(python3 -B "$HERE/scripts/board_lock.py" "$tmpd/board/.lock" 2>&1); rc=$?
rm -f "$ready"
kill "$holder" 2>/dev/null
wait "$holder" 2>/dev/null
if [ "$holder_ready" = yes ] \
  && [ "$rc" -eq 0 ] \
  && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Eq '^HELD holder='; then
  say "  PASS  flock-held lock -> HELD ($out)"
else
  say "  FAIL  flock-held lock not classified HELD (holder_ready=$holder_ready rc=$rc): $out"
  fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-163 AC3: a secret-scan claim must name its scope. The public repo also publishes
# an unrelated `master` lineage (547 gitleaks findings on 64 commits, none an ancestor
# of main), so a green with no recorded --log-opts is not a posture claim. Arm 1
# measures the real tree; arms 2 and 3 red/green one fixture line.
say "34. a posture doc's gitleaks claim names its scan scope (CF-163 AC3)"
out=$(python3 -B "$HERE/scripts/check_scan_scope.py" "$HERE" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: OK'; then
  say "  PASS  posture docs name their scan scope"
else
  say "  FAIL  posture docs scan-scope checker not green (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
tmpd=$(mktemp -d)
mkdir -p "$tmpd/docs/audits"
printf '%s\n' '| Secrets | `gitleaks detect -c .gitleaks.toml --redact` | clean |' \
  > "$tmpd/docs/audits/code-factory-releng-fixture.md"
out=$(python3 -B "$HERE/scripts/check_scan_scope.py" "$tmpd" 2>&1); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Eq '^  FAIL  audit-scope: .*:1 gitleaks claim names no --log-opts'; then
  say "  PASS  unscoped claim -> FAIL audit-scope"
else
  say "  FAIL  unscoped claim escaped the scan-scope gate (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
sed 's/--redact`/ --log-opts="--all"`/' "$tmpd/docs/audits/code-factory-releng-fixture.md" \
  > "$tmpd/docs/audits/code-factory-releng-fixture.md.new"
mv "$tmpd/docs/audits/code-factory-releng-fixture.md.new" \
  "$tmpd/docs/audits/code-factory-releng-fixture.md"
out=$(python3 -B "$HERE/scripts/check_scan_scope.py" "$tmpd" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: OK'; then
  say "  PASS  scoped claim -> OK"
else
  say "  FAIL  scoped claim not accepted (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
rm -rf "$tmpd"

# CF-153: the node-side checker tells the operator to "pass --ref <branch-or-tag>", so the
# documented control-host create command must accept that exact flag and carry it across the
# transport. Pre-fix, node-create.sh printed `unknown arg: --ref` and exited 2, so arm (a) below
# was red on that tree; the remedy its own error printed could not be followed.
say "35. node-create accepts and forwards --ref (CF-153)"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts/harness" "$tmpd/bin"
no_ref=$(bash "$HERE/scripts/node-create.sh" --staged-files 2>&1); no_rc=$?
with_ref=$(bash "$HERE/scripts/node-create.sh" --staged-files --ref master 2>&1); ref_rc=$?
if [ "$no_rc" -eq 0 ] && [ "$ref_rc" -eq 0 ] && [ "$with_ref" = "$no_ref" ] \
  && [ "$(printf '%s\n' "$with_ref" | grep -c .)" -eq 6 ] \
  && ! printf '%s\n' "$with_ref" | grep -Fq 'unknown arg:'; then
  say "  PASS  --staged-files --ref master -> exit 0, same six-file staged set"
else
  say "  FAIL  --ref rejected or changed the staged set (exit $no_rc/$ref_rc)"; fails=$((fails+1))
fi
# Stub transport only: the same node-create.sh the operator runs, a bunker that records argv
# and keeps the payload it was handed. No network, no agent, no installation.
while IFS= read -r file; do
  cp "$HERE/scripts/$file" "$tmpd/scripts/$file" || fails=$((fails+1))
done <<< "$no_ref"
cp "$HERE/scripts/node-create.sh" "$tmpd/scripts/" || fails=$((fails+1))
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpd/scripts/verify-node.sh"
chmod +x "$tmpd/scripts/verify-node.sh"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
if [ -n "${FIXTURE_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$FIXTURE_LOG"
fi
case "$1" in
  spawn) printf '%s\n' "$2" > "$FIXTURE_AGENT" ;;
  cp) exit 0 ;;
  exec) case "${!#}" in *NODE_PROJECT=*) printf '%s\n' "${!#}" > "$FIXTURE_PAYLOAD" ;; esac ;;
  *) echo 'unexpected bunker command' >&2; exit 99 ;;
esac
EOF
chmod +x "$tmpd/bin/bunker"
for ref_value in master "re'lease"; do
  # A plain assertion on the recorded bytes: the expected quoting is written literally, so
  # this never executes anything the fixture supplied.
  case "$ref_value" in
    master) want_ref="--ref 'master'" ;;
    *) want_ref="--ref 're'\''lease'" ;;
  esac
  : > "$tmpd/payload"
  out=$(env -i HOME="$tmpd/control-home" PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture-server \
    CRIER_URL=http://fixture.invalid:8767 FIXTURE_LOG="$tmpd/bunker.log" \
    FIXTURE_AGENT="$tmpd/agent" FIXTURE_PAYLOAD="$tmpd/payload" \
    /bin/bash "$tmpd/scripts/node-create.sh" --project fixture \
    --repo https://github.com/git/git --harness hermes --ref "$ref_value" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Eq '^NODE CREATED: node-fixture-' \
    && grep -aFq -- "--repo 'https://github.com/git/git' $want_ref" "$tmpd/payload"; then
    say "  PASS  ref '$ref_value' crosses the transport as $want_ref"
  else
    say "  FAIL  ref '$ref_value' was dropped or unquoted in the payload (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out"
  fi
done
rm -rf "$tmpd"

# BEGIN cf159-escaping
say "36. remote shell payloads preserve data without executing it (CF-159)"
# The foreman's retained RED at 1fea92d printed INJECTION_EXECUTED=yes.
# Capture transport text, then execute it only against disposable node-side stubs.
if python3 -B - "$HERE" <<'PY'
import hashlib
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])


def run(argv, env, cwd):
    return subprocess.run(argv, env=env, cwd=cwd, text=True, capture_output=True)


with tempfile.TemporaryDirectory(prefix="cf159-") as directory:
    fixture = Path(directory)
    home = fixture / "home"
    scripts = fixture / "scripts"
    binary = fixture / "bin"
    for path in (home / "node-scripts", scripts / "harness", binary):
        path.mkdir(parents=True)

    def executable(path, text):
        path.write_text(text)
        path.chmod(0o755)

    for name in ("node-create.sh", "lib.sh", "project-node.sh", "install-go.sh", "disk_floor.py", "reclaim_disk.py"):
        shutil.copyfile(root / "scripts" / name, scripts / name)
    shutil.copyfile(root / "scripts/harness/install-hermes.sh", scripts / "harness/install-hermes.sh")
    executable(scripts / "verify-node.sh", "#!/bin/bash\nexit 0\n")
    executable(binary / "bunker", '''#!/bin/bash
case "$1" in
  cp) exit 0 ;;
  exec)
    case "${!#}" in
      *NODE_PROJECT=*|sha256sum*) printf '%s' "${!#}" > "$FIXTURE_PAYLOAD" ;;
      'echo ALIVE '*) printf 'ALIVE fixture\\n' ;;
      'hostname -I') printf '127.0.0.1\\n' ;;
    esac ;;
  *) exit 99 ;;
esac
''')
    executable(binary / "curl", "#!/bin/bash\nprintf 000\n")
    executable(home / "node-scripts/project-node.sh", '''#!/bin/bash
printf '%s\\0' "$NODE_PROJECT" "$NODE_GATEWAY_PORT" "$CRIER_URL" "$@" > "$FIXTURE_VALUES"
''')
    env = dict(os.environ, HOME=str(home), PATH=f"{binary}:/usr/bin:/bin",
               BUNKER_SERVER="fixture-server", CRIER_URL="http://fixture.invalid:8767",
               FIXTURE_PAYLOAD=str(fixture / "payload"), FIXTURE_VALUES=str(fixture / "values"))
    malicious = "p'; touch $HOME/PWNED; echo '"
    normal = dict(project="fixture", port="10800", harness="hermes",
                  repo="https://fixture.invalid/repo.git", ref="main", crier=env["CRIER_URL"])
    # Include every data field, not just the reported project exploit. A harmless
    # adapter fixture lets an unusual harness name pass the staging precondition.
    for field, value in [("project", malicious), ("project", "my proj's")] + [
        (field, malicious) for field in ("port", "harness", "repo", "ref", "crier")
    ]:
        values = dict(normal, **{field: value})
        adapter = scripts / f"harness/install-{values['harness']}.sh"
        if not adapter.exists():
            adapter.parent.mkdir(parents=True, exist_ok=True)
            adapter.write_text("# fixture adapter: no provisioning\n")
        env["CRIER_URL"] = values["crier"]
        payload_path = fixture / "payload"
        payload_path.unlink(missing_ok=True)
        args = ["bash", str(scripts / "node-create.sh"), "--agent", "fixture-agent"]
        for flag in ("project", "port", "harness", "repo", "ref"):
            args.extend([f"--{flag}", values[flag]])
        created = run(args, env, fixture)
        assert created.returncode == 0, created.stdout + created.stderr
        payload = payload_path.read_text()
        # Independent token oracle: no quote may expose an extra shell command.
        assert shlex.split(payload) == [
            f"NODE_PROJECT={values['project']}", f"NODE_GATEWAY_PORT={values['port']}",
            f"CRIER_URL={values['crier']}", "~/node-scripts/project-node.sh", "--apply",
            "--project", values["project"], "--harness", values["harness"],
            "--repo", values["repo"], "--ref", values["ref"],
        ], payload
        executed = run(["bash", "-lc", payload], env, fixture)
        assert executed.returncode == 0, executed.stderr
        assert not (home / "PWNED").exists(), "node-create injection executed"
        expected = [values["project"], values["port"], values["crier"], "--apply",
                    "--project", values["project"], "--harness", values["harness"],
                    "--repo", values["repo"], "--ref", values["ref"]]
        arrived = (fixture / "values").read_bytes().split(b"\0")[:-1]
        assert arrived == [item.encode() for item in expected], arrived
        if field == "project" and value != malicious:
            print(f"  PASS  cf159 positive control NODE_PROJECT={arrived[0].decode()} --project={arrived[5].decode()}")
        else:
            print(f"  PASS  cf159 node-create {field} payload is data, not code")

    # Exercise the real optional-artifact branch with transport and HTTP stubbed.
    artifact = "artifact'; touch $HOME/PWNED; echo '"
    artifact_path = fixture / artifact
    artifact_path.parent.mkdir(parents=True, exist_ok=True)
    artifact_path.write_text("fixture artifact\n")
    verified = run(["bash", str(root / "scripts/verify-node.sh"), "--agent", "fixture-agent",
                    "--artifact", artifact], env, fixture)
    assert verified.returncode == 1 and "gateway_reachable" in verified.stdout, verified
    payload = (fixture / "payload").read_text()
    assert shlex.split(payload) == ["sha256sum", artifact, "2>/dev/null", "|", "cut", "-d ", "-f1"], payload
    executed = run(["bash", "-lc", payload], env, fixture)
    assert executed.returncode == 0 and executed.stdout.strip() == hashlib.sha256(b"fixture artifact\n").hexdigest(), executed
    assert not (home / "PWNED").exists(), "artifact injection executed"
    print("  PASS  cf159 verify-node artifact payload is data, not code; digest intact")

    # bunker_exec deliberately accepts shell text: compose values with shq while
    # retaining pipelines and literal commands. Also pin empty/multiline values.
    helper = r'''. "$1"
bunker_exec fixture-server fixture-agent "printf '%s' $(shq "$2") | cat"
'''
    executable(binary / "bunker", '#!/bin/bash\nprintf "%s" "${!#}" > "$FIXTURE_PAYLOAD"\n')
    for value in (malicious, "my proj's", "", "line\n'\\$();\n"):
        captured = run(["bash", "-c", helper, "cf159", str(root / "scripts/lib.sh"), value], env, fixture)
        assert captured.returncode == 0, captured.stderr
        executed = run(["bash", "-lc", (fixture / "payload").read_text()], env, fixture)
        assert executed.returncode == 0 and executed.stdout == value, executed
        assert not (home / "PWNED").exists(), "bunker_exec injection executed"
    print("  PASS  cf159 bunker_exec trusted command text preserves quoted values and literal pipelines")
PY
then
  say "  PASS  cf159-escaping all remote-command sites"
else
  say "  FAIL  cf159-escaping remote-command fixture"; fails=$((fails+1))
fi
# END cf159-escaping

# BEGIN cf151-node-credential-scope
say "37. the node credential row scopes its contradiction to the node (CF-151)"
# The Status row "Node inference credential" asserts a NODE state. The inference_key gate
# (scripts/harness/install-hermes.sh) reads $HOME/.hermes/.env of whichever environment runs
# it, so the same command witnesses the node's key when run inside the node and the control
# host's own key when run here. The pre-fix row (baseline 276b0b0) cited the bare control-host
# `FAIL inference_key` as the contradiction; on a keyed control host that command prints PASS
# and contradicts the row's own **missing** state. RED proof at authoring time: this arm run
# against the pre-fix README failed all three assertions (worker transcript, not committed
# as code).
cf151_row_scope() {  # $1=README -> prints one line per offense, returns 1 if any
  local readme="$1" rc=0 row
  row=$(grep '^|' "$readme" | grep -F '| Node inference credential |' | head -1)
  if [ -z "$row" ]; then
    echo "absent-row: Node inference credential"; return 1
  fi
  if printf '%s' "$row" | grep -Fq -- '-> `FAIL inference_key`' \
    && ! printf '%s' "$row" | grep -Fqi "this host's own key"; then
    echo "unlabelled-control-host-fail: Node inference credential"; rc=1
  fi
  if ! printf '%s' "$row" | grep -Fqi "this host's own key"; then
    echo "missing-control-host-label: Node inference credential"; rc=1
  fi
  if ! printf '%s' "$row" | grep -Fq 'node-scripts/project-node.sh --check' \
    && ! printf '%s' "$row" | grep -Fq 'not measurable from the control host'; then
    echo "missing-node-scoped-measurement: Node inference credential"; rc=1
  fi
  return $rc
}
if cf151_row_scope "$HERE/README.md" >/dev/null; then
  say "  PASS  node credential row labels control-host evidence and names the node measurement"
else
  say "  FAIL  node credential row mis-scoped: $(cf151_row_scope "$HERE/README.md" | tr '\n' ' ')"
  fails=$((fails+1))
fi
# negative fixture: the pre-fix row bytes, verbatim, must be refused
tmpd=$(mktemp -d)
cat > "$tmpd/prefix-row" <<'EOF'
| Node inference credential | **missing** — a turn dies at `No inference provider configured`; the node needs its own key, never an operator key | `scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`. That row prints only on an interpreter inside the pin's range; the default `python3` here is 3.14 and stops at `FAIL python` first, so name one explicitly: `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`. Both arms are transcripted in `docs/audits/code-factory-CF-064.probe.txt` (CF-064). |
EOF
if cf151_row_scope "$tmpd/prefix-row" >/dev/null; then
  say "  FAIL  the pre-fix node credential row was accepted"; fails=$((fails+1))
else
  say "  PASS  pre-fix node credential row refused ($(cf151_row_scope "$tmpd/prefix-row" | tr '\n' ' '))"
fi
rm -rf "$tmpd"
# END cf151-node-credential-scope

say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"
# docs/audits/prd-blocker-resolution.sh decides each CF-nnn cited between the
# milestone-blockers markers as `row=<status>` (board) or `requirement-only` (the PRD's
# requirements table), and exits 1 on an unresolved id, a cited row that is already
# complete, or a requirement-only row with no `Verified by` cell. Three arms, each able to
# fail on its own: an absent script or an unconditional exit 0 reds (b) and (c), while a
# checker that never looks at the requirements table reds the real arm on CF-110/CF-112.
out=$(bash "$HERE/docs/audits/prd-blocker-resolution.sh" 2>&1); rc=$?
summary=$(printf '%s\n' "$out" | sed -n 's/^RESULT: OK (\([0-9][0-9]*\) ids: \([0-9][0-9]*\) rows, \([0-9][0-9]*\) requirement-only)$/\1 cited ids, \2 rows, \3 requirement-only/p')
if [ "$rc" -eq 0 ] && [ -n "$summary" ]; then
  say "  PASS  prd-blocker — $summary, exit $rc"
else
  say "  FAIL  prd-blocker — exit $rc: $(printf '%s\n' "$out" | tail -3 | tr '\n' ' ')"
  fails=$((fails+1))
fi
tmpd=$(mktemp -d)
# (b) an id in neither namespace, cited inside its own marker pair on a copy of the real PRD
cp "$HERE/docs/PRD-code-factory.md" "$tmpd/prd-unresolved"
printf '<!-- milestone-blockers:begin -->\n%s\n<!-- milestone-blockers:end -->\n' '`CF-999`' >> "$tmpd/prd-unresolved"
out=$(bash "$HERE/docs/audits/prd-blocker-resolution.sh" "$tmpd/prd-unresolved" \
  "$HERE/.coding-hermes/board/tasks.jsonl" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^FAIL prd-blocker: CF-999 '; then
  say "  PASS  prd-blocker-red — CF-999 unresolved, exit $rc"
else
  say "  FAIL  prd-blocker-red — CF-999 accepted or not named (exit $rc): $(printf '%s\n' "$out" | tail -2 | tr '\n' ' ')"
  fails=$((fails+1))
fi
# (c) a region that cites a row the board already closed — a stale citation, not a blocker
closed=$(jq -r 'select(.status=="complete")|.id' "$HERE/.coding-hermes/board/tasks.jsonl" 2>/dev/null | head -1)
if [ -z "$closed" ]; then
  say "  FAIL  prd-blocker-closed — the board carries no complete row to cite"
  fails=$((fails+1))
else
  awk -v id="$closed" '
    /^<!-- milestone-blockers:begin -->$/ { print; print "`" id "`"; inb=1; next }
    /^<!-- milestone-blockers:end -->$/   { inb=0; print; next }
    !inb { print }
  ' "$HERE/docs/PRD-code-factory.md" > "$tmpd/prd-closed"
  out=$(bash "$HERE/docs/audits/prd-blocker-resolution.sh" "$tmpd/prd-closed" \
    "$HERE/.coding-hermes/board/tasks.jsonl" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "^FAIL prd-blocker: $closed "; then
    say "  PASS  prd-blocker-closed — $closed complete, exit $rc"
  else
    say "  FAIL  prd-blocker-closed — $closed accepted as a blocker (exit $rc): $(printf '%s\n' "$out" | tail -2 | tr '\n' ' ')"
    fails=$((fails+1))
  fi
fi
rm -rf "$tmpd"
# END cf182-milestone-blockers

say "39. acceptance-plan section mapping covers the tree (CF-198)"
out=$(bash "$HERE/docs/audits/cf198-section-mapping.sh" 2>&1); rc=$?
counts=$(printf '%s\n' "$out" | sed -n 's/^arms_plan=\([0-9][0-9]*\) arms_tree=\([0-9][0-9]*\)$/\1 \2/p')
ap=${counts%% *}
at=${counts##* }
# Compare the two DERIVED counts against each other, never against a frozen literal:
# a hard-coded total turns every legitimate section addition (mapping row + prose both
# updated, checker green) into a red arm and pushes the next agent to edit the number.
if [ "$rc" -eq 0 ] && [ -n "$counts" ] && [ "${ap:-0}" -gt 0 ] && [ "$ap" = "$at" ] \
  && printf '%s\n' "$out" | grep -qx 'RESULT: OK'; then
  say "  PASS  section-mapping-real — green verdict, arms_plan=$ap arms_tree=$at"
else
  say "  FAIL  section-mapping-real — expected RESULT: OK with arms_plan == arms_tree (exit $rc): $(printf '%s\n' "$out" | tail -3 | tr '\n' ' ')"
  fails=$((fails+1))
fi
tmpd=$(mktemp -d)
awk '!/^\| §38 /' "$HERE/docs/ACCEPTANCE-PLAN.md" > "$tmpd/plan-missing-row"
out=$(bash "$HERE/docs/audits/cf198-section-mapping.sh" --plan "$tmpd/plan-missing-row" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -qi 'unbound variable' \
  && printf '%s\n' "$out" | grep -Eq '^  FAIL  section-mapping.*§38.*plan'; then
  say "  PASS  section-mapping-red — missing §38 names plan side, exit $rc"
else
  say "  FAIL  section-mapping-red — missing §38 was not named as plan-side drift (exit $rc): $(printf '%s\n' "$out" | tail -3 | tr '\n' ' ')"
  fails=$((fails+1))
fi
rm -rf "$tmpd"

say "40. the bunker provisioner fails closed, and its config file is data not code (CF-214)"
bash -n "$HERE/scripts/bunker-provision.sh" && say "  PASS  bash -n scripts/bunker-provision.sh" || { say "  FAIL  provision syntax"; fails=$((fails+1)); }
bash -n "$HERE/scripts/bunker-crier-connect.sh" && say "  PASS  bash -n scripts/bunker-crier-connect.sh" || { say "  FAIL  crier-connect syntax"; fails=$((fails+1)); }

out=$(/bin/bash "$HERE/scripts/bunker-provision.sh" --config /nonexistent.conf --check 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'FAIL  config — cannot read'; then
  say "  PASS  absent config -> named FAIL, exit $rc"
else
  say "  FAIL  absent config was not refused (exit $rc)"; fails=$((fails+1))
fi

tmpd=$(mktemp -d)
printf 'PROJECT=demo\nrm -rf /tmp/should-never-run\n' > "$tmpd/shell.conf"
out=$(/bin/bash "$HERE/scripts/bunker-provision.sh" --config "$tmpd/shell.conf" --check 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'is not KEY=VALUE'; then
  say "  PASS  a shell line in the config is refused, never executed, exit $rc"
else
  say "  FAIL  config parser accepted a shell line (exit $rc)"; fails=$((fails+1))
fi
[ -e /tmp/should-never-run ] && { say "  FAIL  the config file was EXECUTED"; fails=$((fails+1)); rm -rf /tmp/should-never-run; }

out=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/bunker-provision.sh" --check --project demo 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'FAIL  bunker_cli'; then
  say "  PASS  no bunker client -> named FAIL, exit $rc (a vacuous PASS would be the bug)"
else
  say "  FAIL  missing bunker client did not surface (exit $rc)"; fails=$((fails+1))
fi

# a flag handler may only assign CLI_* variables: anything else is overwritten by load_config and the
# documented flag silently does nothing (four of them did, including --github-token-file)
direct=$(awk '/^while \[ \$# -gt 0 \]/,/^done/' "$HERE/scripts/bunker-provision.sh" \
  | grep -E '^\s+--[a-z-]+\)' | grep -vE 'CLI_|usage|YES=|CONFIG=|MODE=' | head -3)
if [ -z "$direct" ]; then
  say "  PASS  every flag handler assigns only CLI_* (so the command line survives load_config)"
else
  say "  FAIL  a flag assigns a variable the config will overwrite: $(printf '%s' "$direct" | tr '\n' ' ')"
  fails=$((fails+1))
fi

# the preflight must validate the credential FILES it will read, before it touches a host
if grep -q 'every named credential and profile file is readable' "$HERE/scripts/bunker-provision.sh"; then
  say "  PASS  the preflight names every credential file it cannot read"
else
  say "  FAIL  the preflight reads credential files it never validated"; fails=$((fails+1))
fi

# every documented config key must parse: a key that exists in the variables but not in the
# parser's allowlist is a control that silently cannot be set (it happened twice)
tmpd=$(mktemp -d)
cat > "$tmpd/all.conf" <<'CONF'
PROJECT=demo
AGENT=demo-node
SERVER=demo-server
REPO=https://example.invalid/x.git
REF=main
HARNESS=hermes
NAMESPACE=demo
NAMESPACES=demo,extra
TTL=1d
GIT_AUTHOR_NAME=A
GIT_AUTHOR_EMAIL=a@example.invalid
GIT_CO_AUTHOR=B <b@example.invalid>
GITHUB_TOKEN_FILE=/dev/null
DUCKBRAIN_TOKEN_FILE=/dev/null
S3_ENV_FILE=/dev/null
NODE_ENV_FILE=/dev/null
CRIER_AGENT_KEY_FILE=/dev/null
CRIER_AUTH_TOKEN_FILE=/dev/null
CRIER_URL=http://example.invalid:8767
DUCKBRAIN_URL=http://example.invalid:3000
CONFIG_SET_MODEL_PROVIDER=custom:x
CONFIG_SET_MODEL_NAME=m
CONFIG_SET_GATEWAY_BIND=0.0.0.0
CONFIG_SET_GATEWAY_PORT=10800
CONFIG_SET_AGENT_MAX_ITERATIONS=40
CONF
out=$(/bin/bash "$HERE/scripts/bunker-provision.sh" --config "$tmpd/all.conf" --check 2>&1)
if printf '%s\n' "$out" | grep -q '  PASS  config' && ! printf '%s\n' "$out" | grep -q 'unknown key'; then
  say "  PASS  every documented config key parses ($(grep -c '=' "$tmpd/all.conf") keys, no unknown-key row)"
else
  say "  FAIL  a documented config key is not accepted: $(printf '%s\n' "$out" | grep 'unknown key' | head -2 | tr '\n' ' ')"
  fails=$((fails+1))
fi
rm -rf "$tmpd"

# the node-side gate refuses to install without an identity to commit under
bash -n "$HERE/scripts/install-gitreins.sh" || { say "  FAIL  install-gitreins syntax"; fails=$((fails+1)); }
out=$(/bin/bash "$HERE/scripts/install-gitreins.sh" --apply --repo "$HERE" --author-name "" --author-email "" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "identity — --author-name and --author-email are required"; then
  say "  PASS  gitreins installer refuses an anonymous node, exit $rc"
else
  say "  FAIL  gitreins installer accepted an empty identity (exit $rc)"; fails=$((fails+1))
fi

# a namespace declaration is validated before any host is touched
out=$(/bin/bash "$HERE/scripts/bunker-provision.sh" --check --project demo --agent a --server s --namespaces 'bad slug!' 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "FAIL  namespaces — .* not a namespace slug"; then
  say "  PASS  a bad namespace slug is refused before the host is touched, exit $rc"
else
  say "  FAIL  a bad namespace slug was accepted (exit $rc)"; fails=$((fails+1))
fi

# several namespaces are probed separately, and the merge writes them as a list
tmpd=$(mktemp -d)
printf '{"node_id":"h1","project":"demo"}\n' > "$tmpd/node.json"
out=$(python3 "$HERE/scripts/node_identity.py" "$tmpd/node.json" 'duckbrain.namespaces[]=demo,coder' 2>&1); rc=$?
listed=$(python3 -c 'import json,sys;print(",".join(json.load(open(sys.argv[1]))["duckbrain"]["namespaces"]))' "$tmpd/node.json" 2>/dev/null)
out2=$(python3 "$HERE/scripts/node_identity.py" "$tmpd/node.json" 'duckbrain.namespaces[]=demo,coder' 2>&1); rc2=$?
if [ "$rc" -eq 0 ] && [ "$listed" = "demo,coder" ] && [ "$rc2" -eq 0 ] && printf '%s\n' "$out2" | grep -q "already carries every value"; then
  say "  PASS  node identity carries several namespaces as a list, idempotently ($listed)"
else
  say "  FAIL  multi-namespace identity merge ($listed, rc=$rc/$rc2)"; fails=$((fails+1))
fi
out=$(python3 "$HERE/scripts/node_identity.py" "$tmpd/node.json" 'duckbrain.namespaces[]=' 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "declared empty"; then
  say "  PASS  an empty namespace list is refused, exit $rc"
else
  say "  FAIL  an empty namespace list was accepted (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

out=$(/bin/bash "$HERE/scripts/bunker-provision.sh" --destroy --project demo --agent a --server s 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'refusing to destroy without --yes'; then
  say "  PASS  destroy without --yes is refused, exit $rc"
else
  say "  FAIL  destroy ran without confirmation (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-212: the control host dispatches into local workdirs that nothing refreshes, so a
# lane can work a stale tree. The probe enumerates workdirs from the scheduler DB,
# measures the lag, and refuses beyond a bound. Fixture: a trunk-default remote, one
# clone 2 commits behind, one fresh, and every tolerated defect (detached HEAD, no
# remote, non-git dir, missing path, a plain file, a disabled project sharing a workdir).
say "41. repo freshness probe measures lag per workdir and refuses beyond the bound (CF-212)"
FRESH="$HERE/scripts/repo_freshness.py"
if python3 -B -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$FRESH"; then
  say "  PASS  scripts/repo_freshness.py parses (python3 -B, stdlib only)"
else
  say "  FAIL  scripts/repo_freshness.py does not parse"; fails=$((fails+1))
fi
tmpd=$(mktemp -d)
git init -q -b trunk "$tmpd/seed"
git -C "$tmpd/seed" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm one --allow-empty
git init -q --bare "$tmpd/origin.git"
git -C "$tmpd/origin.git" symbolic-ref HEAD refs/heads/trunk
git -C "$tmpd/seed" push -q "$tmpd/origin.git" trunk
git clone -q "$tmpd/origin.git" "$tmpd/stale"
git -C "$tmpd/seed" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm two --allow-empty
git -C "$tmpd/seed" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm three --allow-empty
git -C "$tmpd/seed" push -q "$tmpd/origin.git" trunk
git clone -q "$tmpd/origin.git" "$tmpd/fresh"
git clone -q "$tmpd/origin.git" "$tmpd/det"
git -C "$tmpd/det" checkout -q --detach HEAD
git init -q -b main "$tmpd/lonely"
git -C "$tmpd/lonely" -c user.email=fixture@example.invalid -c user.name=fixture commit -qm x --allow-empty
mkdir -p "$tmpd/notgit"
printf 'a workdir must be a directory\n' > "$tmpd/afile"
git init -q --bare "$tmpd/bare.git"
python3 -B - "$tmpd" <<'PY'
import os, sqlite3, sys
tmpd = sys.argv[1]
con = sqlite3.connect(os.path.join(tmpd, "sched.db"))
con.execute("create table projects (name text, workdir text, enabled integer)")
rows = [
    ("cf-stale", os.path.join(tmpd, "stale"), 1),
    ("cf-fresh", os.path.join(tmpd, "fresh"), 1),
    ("cf-fresh-qa", os.path.join(tmpd, "fresh"), 1),
    ("cf-det", os.path.join(tmpd, "det"), 1),
    ("cf-lonely", os.path.join(tmpd, "lonely"), 1),
    ("cf-notgit", os.path.join(tmpd, "notgit"), 1),
    ("cf-missing", os.path.join(tmpd, "absent"), 1),
    ("cf-file", os.path.join(tmpd, "afile"), 1),
    ("cf-bare", os.path.join(tmpd, "bare.git"), 1),
    ("cf-disabled", os.path.join(tmpd, "stale"), 0),
]
con.executemany("insert into projects values (?,?,?)", rows)
con.commit()
PY

out=$(python3 -B "$FRESH" --db "$tmpd/sched.db" --gate --jobs 2 2>&1); rc=$?
fail_rows=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
if [ "$rc" -eq 1 ] && [ "$fail_rows" = 1 ] \
  && [ "$(printf '%s\n' "$out" | grep -Fc '  FAIL  cf-stale — lag 2 > bound 0 (trunk vs origin/trunk)')" = 1 ]; then
  say "  PASS  workdir behind 2 commits -> one FAIL naming lag 2, --gate exit $rc"
else
  say "  FAIL  stale workdir was not refused with a lag row (exit $rc, $fail_rows FAIL rows)"; fails=$((fails+1))
fi
if printf '%s\n' "$out" | grep -Fq '  PASS  cf-fresh — lag 0, ahead 0, trunk vs origin/trunk'; then
  say "  PASS  a non-main default branch (trunk) is measured against origin/trunk"
else
  say "  FAIL  non-main default branch was not measured"; fails=$((fails+1))
fi
warn_n=$(printf '%s\n' "$out" | grep -c '^  WARN  ')
warn_missing=0
for want in cf-det cf-lonely cf-notgit cf-missing cf-file cf-bare; do
  printf '%s\n' "$out" | grep -Fq "  WARN  $want — " || warn_missing=$((warn_missing+1))
done
if [ "$warn_n" = 6 ] && [ "$warn_missing" = 0 ] \
  && printf '%s\n' "$out" | grep -Fq '  WARN  cf-bare — bare repository at'; then
  say "  PASS  detached HEAD, no remote, non-git, bare, missing and non-directory workdirs -> 6 named WARN rows, no crash"
else
  say "  FAIL  tolerated-defect rows were missing or duplicated ($warn_n WARN rows, $warn_missing unnamed)"; fails=$((fails+1))
fi
if printf '%s\n' "$out" | grep -Fq ', 9 enabled projects, 8 unique workdirs,' \
  && printf '%s\n' "$out" | grep -Fq '[2 lanes: cf-fresh, cf-fresh-qa]' \
  && ! printf '%s\n' "$out" | grep -Fq 'cf-disabled'; then
  say "  PASS  workdirs enumerated from the DB: 9 enabled projects, 8 unique workdirs, disabled project skipped"
else
  say "  FAIL  DB enumeration/dedupe/enabled filter is wrong"; fails=$((fails+1))
fi
out=$(python3 -B "$FRESH" --db "$tmpd/sched.db" --no-fetch --gate --bound 5 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  PASS  cf-stale — lag 2, ahead 0'; then
  say "  PASS  the same workdir clears --bound 5 (bound is policy, not a constant), exit $rc"
else
  say "  FAIL  --bound 5 still refused the workdir (exit $rc)"; fails=$((fails+1))
fi
out=$(python3 -B "$FRESH" --workdir "$tmpd/stale" --no-fetch --gate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq '  FAIL  stale — lag 2 > bound 0'; then
  say "  PASS  one workdir probes on its own (--workdir) and refuses, exit $rc"
else
  say "  FAIL  --workdir mode did not measure $tmpd/stale (exit $rc)"; fails=$((fails+1))
fi
# --no-fetch must not touch the remote: move it away and the lag must still be counted.
mv "$tmpd/origin.git" "$tmpd/origin.away"
out=$(python3 -B "$FRESH" --db "$tmpd/sched.db" --no-fetch --jobs 2 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  FAIL  cf-stale — lag 2 > bound 0' \
  && ! printf '%s\n' "$out" | grep -Fq 'fetch failed:'; then
  say "  PASS  --no-fetch measured lag 2 with the remote absent: no network call, exit $rc without --gate"
else
  say "  FAIL  --no-fetch reached for the absent remote (exit $rc)"; fails=$((fails+1))
fi
out=$(python3 -B "$FRESH" --workdir "$tmpd/stale" --jobs 1 2>&1); rc=$?
if printf '%s\n' "$out" | grep -Fq 'fetch failed:'; then
  say "  PASS  with the remote absent a fetch names the failure instead of inventing freshness"
else
  say "  FAIL  a failed fetch did not surface a named reason (exit $rc)"; fails=$((fails+1))
fi
mv "$tmpd/origin.away" "$tmpd/origin.git"
out=$(python3 -B "$FRESH" --db "$tmpd/sched.db" --no-fetch --gate --strict --jobs 2 2>&1); rc=$?
fail_rows=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
if [ "$rc" -eq 1 ] && [ "$fail_rows" = 7 ]; then
  say "  PASS  --strict escalates the 6 unmeasurable rows: $fail_rows FAIL, exit $rc"
else
  say "  FAIL  --strict did not refuse the unmeasurable workdirs ($fail_rows FAIL, exit $rc)"; fails=$((fails+1))
fi
if [ "$(python3 -B - "$tmpd" "$FRESH" <<'PY'
import json, subprocess, sys
tmpd, script = sys.argv[1], sys.argv[2]
def run():
    proc = subprocess.run([sys.executable, "-B", script, "--db", tmpd + "/sched.db",
                           "--no-fetch", "--json"], capture_output=True, text=True, check=False)
    data = json.loads(proc.stdout)
    return [(w["name"], w["status"], w["lag"], w["fetch_ts"]) for w in data["workdirs"]], data
first, payload = run()
second, _ = run()
print("ok" if first == second and len(first) == 8 and payload["failed"] == 1 else "diff")
PY
)" = ok ]; then
  say "  PASS  --json is parseable, lists 8 workdirs, and two runs agree (idempotent)"
else
  say "  FAIL  --json output is unparseable, incomplete or not idempotent"; fails=$((fails+1))
fi
out=$(python3 -B "$FRESH" --db "$tmpd/absent.db" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -Fq '  FAIL  scheduler-db — scheduler database not found'; then
  say "  PASS  an absent scheduler DB is a named FAIL, exit $rc"
else
  say "  FAIL  absent scheduler DB did not fail closed (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"
# BEGIN cf213-land-node-branch
say "42. a node branch lands on main with real gates, or refuses naming the reason (CF-213)"
# Nothing in this repo merged a result envelope's branch+commit, so a finished node task had no
# path into origin/main. The arm builds a real local origin and drives the real script: every
# refusal leg asserts the measured reason, and the success leg re-clones the remote to prove the
# push, not the merge, is what the PASS row reports.
bash -n "$HERE/scripts/land-node-branch.sh" \
  && say "  PASS  bash -n scripts/land-node-branch.sh" \
  || { say "  FAIL  land-node-branch syntax"; fails=$((fails+1)); }
tmpd=$(mktemp -d)
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
cf213() {  # cf213 <label> <expect-rc> <needle> [args...]
  local label="$1" want="$2" needle="$3"; shift 3
  out=$(/bin/bash "$HERE/scripts/land-node-branch.sh" "$@" 2>&1); rc=$?
  if [ "$rc" -eq "$want" ] && printf '%s\n' "$out" | grep -Fq -- "$needle"; then
    say "  PASS  $label -> exit $rc"
    printf '%s\n' "$out" | grep -F -- "$needle"
  else
    say "  FAIL  $label -> exit $rc, expected '$needle'"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}
git init -q -b main "$tmpd/src"
printf 'base\n' > "$tmpd/src/README"
git -C "$tmpd/src" add README && git -C "$tmpd/src" commit -qm base
git clone -q --bare "$tmpd/src" "$tmpd/origin.git"
git clone -q "$tmpd/origin.git" "$tmpd/wd"
git -C "$tmpd/src" remote add origin "$tmpd/origin.git"
base=$(git -C "$tmpd/wd" rev-parse HEAD)
# the node's branch, pushed the way a node pushes it
git -C "$tmpd/wd" checkout -q -b node/crier/fixture
printf 'node work\n' > "$tmpd/wd/node.txt"
git -C "$tmpd/wd" add node.txt && git -C "$tmpd/wd" commit -qm "node: land this"
node1=$(git -C "$tmpd/wd" rev-parse HEAD)
git -C "$tmpd/wd" push -q origin node/crier/fixture:refs/heads/node/crier/fixture
git -C "$tmpd/wd" checkout -q -b elsewhere main
printf 'elsewhere\n' > "$tmpd/wd/elsewhere.txt"
git -C "$tmpd/wd" add elsewhere.txt && git -C "$tmpd/wd" commit -qm elsewhere
other=$(git -C "$tmpd/wd" rev-parse HEAD)
git -C "$tmpd/wd" checkout -q main

# a0. usage is not a landing
cf213 "usage" 2 "usage: $HERE/scripts/land-node-branch.sh --workdir DIR" --branch node/crier/fixture

# a. a dirty workdir is refused before anything is measured against the remote
printf 'scratch\n' > "$tmpd/wd/untracked.txt"
cf213 "dirty workdir" 1 "  FAIL  workdir_clean — 1 uncommitted path(s) in $tmpd/wd (first: ?? untracked.txt) — commit or stash them first" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node1"
rm -f "$tmpd/wd/untracked.txt"

# b. the envelope's commit must be on the envelope's branch
cf213 "commit off the branch" 1 "  FAIL  commit_on_branch — $other is not reachable from refs/remotes/origin/node/crier/fixture (tip ${node1:0:12})" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$other"
# c. a commit this clone has never seen cannot be landed, and the row says so
cf213 "unfetched commit" 1 "  FAIL  commit — 0123456789abcdef0123456789abcdef01234567 is not a commit in $tmpd/wd" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit 0123456789abcdef0123456789abcdef01234567

# d. --ff-only is the default: local main ahead of the remote is not fast-forwardable
printf 'local\n' > "$tmpd/wd/local.txt"
git -C "$tmpd/wd" add local.txt && git -C "$tmpd/wd" commit -qm local
local_sha=$(git -C "$tmpd/wd" rev-parse HEAD)
cf213 "ff-only refused" 1 "  FAIL  ff_only — main at ${local_sha:0:12} is not an ancestor of $node1 (1 local commit(s) on main are not in the branch) — not fast-forwardable" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node1"
git -C "$tmpd/wd" reset -q --hard "$base"

# e. a branch that has not seen a newer main is refused, and the remedy is named
printf 'sibling\n' > "$tmpd/src/sibling.txt"
git -C "$tmpd/src" add sibling.txt && git -C "$tmpd/src" commit -qm sibling
git -C "$tmpd/src" push -q origin main
sibling=$(git -C "$tmpd/src" rev-parse HEAD)
cf213 "stale branch" 1 "  FAIL  descendant — refs/remotes/origin/node/crier/fixture ${node1:0:12} is not a descendant of origin/main ${sibling:0:12} — 1 commit(s) on origin/main are not in the branch" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node1"

# the refusal's own remedy, run for real
git -C "$tmpd/wd" fetch -q origin
git -C "$tmpd/wd" checkout -q node/crier/fixture
git -C "$tmpd/wd" rebase -q origin/main
node2=$(git -C "$tmpd/wd" rev-parse HEAD)
git -C "$tmpd/wd" push -q --force-with-lease origin node/crier/fixture:refs/heads/node/crier/fixture
git -C "$tmpd/wd" checkout -q main

# f. a red gate lands nothing: neither ref moves
cf213 "red gate" 1 "  FAIL  gate — 'echo fixture gate refused; exit 7' exited 7 at ${node2:0:12} — fixture gate refused" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" --gate-cmd 'echo fixture gate refused; exit 7'
if [ "$(git -C "$tmpd/wd" rev-parse HEAD)" = "$base" ] \
  && [ "$(git -C "$tmpd/origin.git" rev-parse refs/heads/main)" = "$sibling" ]; then
  say "  PASS  red gate moved no ref — main ${base:0:12}, origin/main ${sibling:0:12}"
else
  say "  FAIL  red gate moved a ref"; fails=$((fails+1))
fi

# g. --dry-run predicts the exact commands and changes nothing
wt_before=$(git -C "$tmpd/wd" worktree list | wc -l)
cf213 "dry run" 0 "LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" --gate-cmd 'test -f node.txt' --dry-run
if printf '%s\n' "$out" | grep -Fq "  git -C $tmpd/wd merge --ff-only $node2" \
  && printf '%s\n' "$out" | grep -Fq "  git -C $tmpd/wd push origin $node2:refs/heads/main" \
  && [ "$(git -C "$tmpd/wd" rev-parse HEAD)" = "$base" ] \
  && [ "$(git -C "$tmpd/origin.git" rev-parse refs/heads/main)" = "$sibling" ] \
  && [ "$(git -C "$tmpd/wd" worktree list | wc -l)" = "$wt_before" ]; then
  say "  PASS  dry run named the merge and the push; no ref or worktree moved"
else
  say "  FAIL  dry run mutated the tree or did not name its commands"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# h. the landing: the gate runs on the NODE's tree (node.txt exists on neither ref here)
cf213 "landing" 0 "  PASS  landed — $node2 is an ancestor of origin/main" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" \
  --gate-cmd 'test -f node.txt && grep -q "node work" node.txt'
if printf '%s\n' "$out" | grep -Fq "  PASS  gate — 'test -f node.txt" \
  && printf '%s\n' "$out" | grep -Fq "LANDED: node/crier/fixture @ $node2 in origin/main" \
  && printf '%s\n' "$out" | grep -Fq "  PASS  push — origin refs/heads/main accepted $node2 (this run's merge tip)"; then
  say "  PASS  the gate row and the LANDED line name the node commit, and the push row names the sha it pushed"
else
  say "  FAIL  the landing did not report its gate row or its LANDED line"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
git clone -q "$tmpd/origin.git" "$tmpd/verify" 2>/dev/null
if git -C "$tmpd/verify" merge-base --is-ancestor "$node2" HEAD 2>/dev/null \
  && [ -f "$tmpd/verify/node.txt" ] && [ -f "$tmpd/verify/sibling.txt" ]; then
  say "  PASS  a fresh clone of the remote contains $node2 and the node's file"
else
  say "  FAIL  the remote does not contain the landed commit"; fails=$((fails+1))
fi

# i. the same command twice changes nothing (the second run does not even run the gate)
head_before=$(git -C "$tmpd/wd" rev-parse HEAD)
cf213 "idempotent re-run" 0 "  PASS  landed — $node2 is an ancestor of origin/main" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" --gate-cmd 'exit 99'
if printf '%s\n' "$out" | grep -Fq "LANDED (already)" \
  && [ "$(git -C "$tmpd/wd" rev-parse HEAD)" = "$head_before" ]; then
  say "  PASS  second run exited $rc with no merge and no push"
else
  say "  FAIL  second run changed the tree"; fails=$((fails+1))
fi

# j. a push the remote refuses must not print a success row: the merge is local, the landing not
git -C "$tmpd/wd" checkout -q node/crier/fixture
printf 'third\n' > "$tmpd/wd/third.txt"
git -C "$tmpd/wd" add third.txt && git -C "$tmpd/wd" commit -qm "node: third"
node3=$(git -C "$tmpd/wd" rev-parse HEAD)
git -C "$tmpd/wd" push -q origin node/crier/fixture:refs/heads/node/crier/fixture
git -C "$tmpd/wd" checkout -q main
printf '#!/bin/sh\necho "rejected by fixture hook" >&2\nexit 1\n' > "$tmpd/origin.git/hooks/pre-receive"
chmod +x "$tmpd/origin.git/hooks/pre-receive"
cf213 "refused push" 1 "  FAIL  push — git push origin ${node3}:refs/heads/main failed — remote: rejected by fixture hook" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node3"
if printf '%s\n' "$out" | grep -Fq "merged locally, NOT landed" \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  landed' \
  && ! printf '%s\n' "$out" | grep -q '^LANDED'; then
  say "  PASS  refused push printed no landed row and no LANDED line"
else
  say "  FAIL  a failed push printed a success row"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -f "$tmpd/origin.git/hooks/pre-receive"

# k/l/m (CF-302). The push used to be `HEAD:refs/heads/<main>`, and under --no-ff HEAD is a merge
# commit whose first parent is the control clone's main — so any commit sitting on local main but
# not on origin/main rode into remote history. The guard is the only thing stopping that; these legs
# prove it refuses, that the refusal is a real refusal (nothing merged, nothing pushed, a fresh clone
# of the remote does not have the stray), and that a clean --no-ff lands by naming an explicit sha.
n_src="$tmpd/noff-src"; n_origin="$tmpd/noff-origin.git"; n_wd="$tmpd/noff-wd"
git init -q -b main "$n_src"
printf 'base\n' > "$n_src/README"
git -C "$n_src" add README && git -C "$n_src" commit -qm base
git clone -q --bare "$n_src" "$n_origin"
git clone -q "$n_origin" "$n_wd"
n_base=$(git -C "$n_wd" rev-parse HEAD)
git -C "$n_wd" checkout -q -b node/crier/noff
printf 'no-ff work\n' > "$n_wd/noff.txt"
git -C "$n_wd" add noff.txt && git -C "$n_wd" commit -qm "node: no-ff work"
n_node=$(git -C "$n_wd" rev-parse HEAD)
git -C "$n_wd" push -q origin node/crier/noff:refs/heads/node/crier/noff

# k. --no-ff with a commit that exists nowhere but local main refuses before it merges anything
git -C "$n_wd" checkout -q main
printf 'stray\n' > "$n_wd/stray.txt"
git -C "$n_wd" add stray.txt && git -C "$n_wd" commit -qm "control: stray"
stray=$(git -C "$n_wd" rev-parse HEAD)
cf213 "no-ff over a local-only main" 1 "  FAIL  no_ff_local — main at ${stray:0:12} is ahead of origin/main ${n_base:0:12} — 1 local commit(s) on main are not on origin/main (${stray:0:12}) and a --no-ff merge would publish them on its push; push or reset main, or land those commits first" \
  --workdir "$n_wd" --branch node/crier/noff --commit "$n_node" --no-ff
if [ "$(git -C "$n_origin" rev-parse refs/heads/main)" = "$n_base" ] \
  && [ "$(git -C "$n_wd" rev-parse HEAD)" = "$stray" ] \
  && [ ! -e "$n_wd/.git/MERGE_HEAD" ]; then
  say "  PASS  no_ff_local merged nothing and moved no ref — origin/main ${n_base:0:12}, local main ${stray:0:12}"
else
  say "  FAIL  no_ff_local merged or pushed before refusing"; fails=$((fails+1))
fi
git clone -q "$n_origin" "$tmpd/noff-stray-clone"
if git -C "$tmpd/noff-stray-clone" cat-file -e "$stray^{commit}" 2>/dev/null; then
  say "  FAIL  a fresh clone of the remote contains the stray commit ${stray:0:12}"; fails=$((fails+1))
else
  say "  PASS  a fresh clone of the remote does not contain the stray commit ${stray:0:12}"
fi

# l. the same landing with local main == origin/main: --no-ff lands, and every claim names the sha
# it pushed. The remedy the refusal names (reset main onto the remote) is run for real, as in leg e.
git -C "$n_wd" reset -q --hard origin/main
cf213 "dry run --no-ff" 0 "LAND: DRY-RUN — 0 commands run, nothing merged or pushed, no ref moved" \
  --workdir "$n_wd" --branch node/crier/noff --commit "$n_node" --no-ff --dry-run
if printf '%s\n' "$out" | grep -Fq "  merge_sha=\$(git -C $n_wd rev-parse --verify HEAD)" \
  && printf '%s\n' "$out" | grep -Fq "  git -C $n_wd push origin \$merge_sha:refs/heads/main" \
  && [ "$(git -C "$n_wd" rev-parse HEAD)" = "$n_base" ] \
  && [ "$(git -C "$n_origin" rev-parse refs/heads/main)" = "$n_base" ]; then
  say "  PASS  the --no-ff dry run named the capture and the explicit-sha push; no ref moved"
else
  say "  FAIL  the --no-ff dry run did not name the explicit-sha push or moved a ref"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
cf213 "no-ff landing" 0 "  PASS  landed — $n_node is an ancestor of origin/main" \
  --workdir "$n_wd" --branch node/crier/noff --commit "$n_node" --no-ff
n_merge=$(git -C "$n_wd" rev-parse HEAD)
if printf '%s\n' "$out" | grep -Fq "  PASS  push — origin refs/heads/main accepted $n_merge (this run's merge tip)" \
  && printf '%s\n' "$out" | grep -Fq "LANDED: node/crier/noff @ $n_node in origin/main (pushed $n_merge, tip $n_merge)" \
  && [ "$(git -C "$n_wd" rev-parse HEAD^2)" = "$n_node" ] \
  && [ "$(git -C "$n_origin" rev-parse refs/heads/main)" = "$n_merge" ]; then
  say "  PASS  the push row and the LANDED line named ${n_merge:0:12}, and that is the remote's tip"
else
  say "  FAIL  the --no-ff landing did not name the sha it pushed, or pushed another object"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
git clone -q "$n_origin" "$tmpd/noff-verify"
if git -C "$tmpd/noff-verify" cat-file -e "$n_merge^{commit}" 2>/dev/null \
  && git -C "$tmpd/noff-verify" merge-base --is-ancestor "$n_node" HEAD \
  && [ -f "$tmpd/noff-verify/noff.txt" ]; then
  say "  PASS  a fresh clone of the remote contains the merge commit ${n_merge:0:12} and the node's file"
else
  say "  FAIL  the remote does not contain the --no-ff merge commit"; fails=$((fails+1))
fi

# m. the negative direction: the stray commit is in no remote ref at all. Remove the guard and this
# arm goes red — with `HEAD:refs/heads/main` the stray was in origin's history at the landed tip.
n_all=$(git -C "$n_origin" rev-list --all)
# `case`, not `printf | grep -q`: under `set -o pipefail` an early-exiting grep can turn a match
# into a failed pipeline, which would make this arm report a false PASS.
stray_on_remote=0
case "$n_all" in *"$stray"*) stray_on_remote=1 ;; esac
if [ "$stray_on_remote" -eq 1 ]; then
  say "  FAIL  the stray commit ${stray:0:12} is in the remote's history — the guard did not hold"; fails=$((fails+1))
elif git -C "$tmpd/noff-verify" merge-base --is-ancestor "$stray" HEAD 2>/dev/null; then
  say "  FAIL  the stray commit ${stray:0:12} is an ancestor of the landed tip"; fails=$((fails+1))
else
  say "  PASS  no ref in the remote ($(printf '%s\n' "$n_all" | wc -l | tr -d ' ') commits reachable from --all) carries ${stray:0:12}"
fi
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
unset -f cf213
rm -rf "$tmpd"
# END cf213-land-node-branch

# A node's environment is declared data — the applier must refuse what cannot be
# declared, diff what drifted, write nothing on --check, and be a no-op on the second run.
say "43. the node environment profile applies idempotently and refuses what cannot be declared"
bash -n "$HERE/scripts/bunker-provision.sh" && say "  PASS  bash -n scripts/bunker-provision.sh" || { say "  FAIL  provision syntax"; fails=$((fails+1)); }
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$HERE/scripts/node_env.py" \
  && say "  PASS  scripts/node_env.py compiles" || { say "  FAIL  node_env.py does not compile"; fails=$((fails+1)); }

envtmp=$(mktemp -d)
mkdir -p "$envtmp/node"
printf 'cf-selftest-secret-0001\n' > "$envtmp/secret"; chmod 600 "$envtmp/secret"
printf 'ENV_CF_PROXY_API_KEY=@%s\nENV_MODEL_NAME=selftest-model\n' "$envtmp/secret" > "$envtmp/node.env"
envrun() { env -i HOME="$envtmp/node" PATH="$PATH" python3 "$HERE/scripts/node_env.py" "$@"; }

out=$(envrun --env-file "$envtmp/absent.env" --check 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'FAIL  env — cannot read the profile'; then
  say "  PASS  absent profile -> named FAIL, exit $rc"
else
  say "  FAIL  absent profile was not refused by name (exit $rc): $(printf '%s' "$out" | tail -1)"; fails=$((fails+1))
fi

printf 'ENV_CF_PROXY_API_KEY=cf-selftest-inline-0001\n' > "$envtmp/inline.env"
out=$(envrun --env-file "$envtmp/inline.env" --check 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'looks secret and carries a literal value' \
  && printf '%s\n' "$out" | grep -q 'ENV_CF_PROXY_API_KEY' \
  && ! printf '%s\n' "$out" | grep -q 'cf-selftest-inline-0001'; then
  say "  PASS  a secret declared inline is refused by name, and the value is never echoed, exit $rc"
else
  say "  FAIL  an inline secret was accepted or echoed (exit $rc): $(printf '%s' "$out" | tail -1)"; fails=$((fails+1))
fi

out=$(envrun --config-set logging.level=debug --check 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q "unknown config path 'logging.level'" \
  && printf '%s\n' "$out" | grep -q 'model.provider'; then
  say "  PASS  an unknown CONFIG_SET path is refused and the allowed set is named, exit $rc"
else
  say "  FAIL  an unknown config path was invented or accepted (exit $rc): $(printf '%s' "$out" | tail -1)"; fails=$((fails+1))
fi

# --check: drift measured, nothing written, and the secret only ever appears as ***
out=$(envrun --env-file "$envtmp/node.env" --config-set model.provider=cf-proxy --config-set gateway.port=10800 --check 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'DIFF  env:CF_PROXY_API_KEY' \
  && printf '%s\n' "$out" | grep -q 'DIFF  config:gateway.port' \
  && printf '%s\n' "$out" | grep -q 'ENV: DRIFT' \
  && ! printf '%s\n' "$out" | grep -q 'cf-selftest-secret-0001' \
  && [ ! -e "$envtmp/node/.hermes/.env" ] && [ ! -e "$envtmp/node/.hermes/config.yaml" ] && [ ! -d "$envtmp/node/.hermes" ]; then
  say "  PASS  --check prints the diff (secret masked as ***), exits 1, and writes nothing"
else
  say "  FAIL  --check was not read-only or not diagnostic (exit $rc): $(printf '%s' "$out" | tail -1)"; fails=$((fails+1))
fi

# a pre-existing config the profile only partly owns: the unrelated keys must survive
mkdir -p "$envtmp/node/.hermes"
printf '# operator notes\nLEFTOVER_VAR=carry-forward\n' > "$envtmp/node/.hermes/.env"
cat > "$envtmp/node/.hermes/config.yaml" <<'YAML'
agent:
  max_iterations: 40
custom_providers:
- name: cf-proxy
  base_url: http://proxy.invalid:4000/v1
model:
  provider: openrouter
  name: old-model
YAML
out=$(envrun --env-file "$envtmp/node.env" --config-set model.provider=cf-proxy --config-set gateway.port=10800 --config-set gateway.bind=0.0.0.0 --apply 2>&1); rc=$?
first=$(sha256sum "$envtmp/node/.hermes/.env" "$envtmp/node/.hermes/config.yaml" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'ENV: APPLIED' \
  && grep -q '^CF_PROXY_API_KEY=cf-selftest-secret-0001$' "$envtmp/node/.hermes/.env" \
  && grep -q '^# operator notes$' "$envtmp/node/.hermes/.env" \
  && grep -q '^LEFTOVER_VAR=carry-forward$' "$envtmp/node/.hermes/.env" \
  && grep -q '^  base_url: http://proxy.invalid:4000/v1$' "$envtmp/node/.hermes/config.yaml" \
  && grep -q '^  name: old-model$' "$envtmp/node/.hermes/config.yaml" \
  && grep -q '^  provider: cf-proxy$' "$envtmp/node/.hermes/config.yaml" \
  && [ "$(stat -c %a "$envtmp/node/.hermes/.env")" = 600 ] \
  && [ "$(stat -c %a "$envtmp/node/.hermes/config.yaml")" = 600 ]; then
  say "  PASS  --apply writes both files at mode 600 and keeps every line it does not own"
else
  say "  FAIL  --apply rewrote or lost state it does not own (exit $rc)"; fails=$((fails+1))
fi

# the second run must change nothing, exit 0, and still report the unmanaged var as a WARN
out=$(envrun --env-file "$envtmp/node.env" --config-set model.provider=cf-proxy --config-set gateway.port=10800 --config-set gateway.bind=0.0.0.0 --apply 2>&1); rc=$?
second=$(sha256sum "$envtmp/node/.hermes/.env" "$envtmp/node/.hermes/config.yaml" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'ENV: PASS — already matches (no change)' \
  && [ "$first" = "$second" ] && [ -n "$first" ] \
  && printf '%s\n' "$out" | grep -q 'WARN  unmanaged:LEFTOVER_VAR'; then
  say "  PASS  a second --apply changes nothing (sha256 unchanged), exits 0, and names the unmanaged var"
else
  say "  FAIL  the second --apply was not a no-op or dropped the unmanaged report (exit $rc)"; fails=$((fails+1))
fi

out=$(envrun --env-file "$envtmp/node.env" --config-set model.provider=cf-proxy --config-set gateway.port=10800 --config-set gateway.bind=0.0.0.0 --check 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'ENV: PASS — declared environment matches'; then
  say "  PASS  --check is green after --apply, and unmanaged vars alone are not drift (exit $rc)"
else
  say "  FAIL  --check after --apply was not green (exit $rc): $(printf '%s' "$out" | tail -1)"; fails=$((fails+1))
fi

# the provisioner must reach the same refusal locally, before it touches a host
mkdir -p "$envtmp/bin"
cat > "$envtmp/bin/bunker" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) echo "bunker-selftest-01" ;;
  info) echo "agent selftest 6h" ;;
  exec) exit 0 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$envtmp/bin/bunker"
cat > "$envtmp/provision.conf" <<CONF
PROJECT=demo
AGENT=selftest
SERVER=bunker-selftest-01
REPO=git@example.invalid:org/repo.git
CRIER_URL=http://crier.invalid:8767
NODE_ENV_FILE=$envtmp/inline.env
CONF
out=$(env PATH="$envtmp/bin:$PATH" /bin/bash "$HERE/scripts/bunker-provision.sh" --config "$envtmp/provision.conf" --check 2>&1)
if printf '%s\n' "$out" | grep -q 'FAIL  env_profile — ' \
  && printf '%s\n' "$out" | grep -q 'looks secret and carries a literal value'; then
  say "  PASS  NODE_ENV_FILE with an inline secret -> named env_profile FAIL from --check"
else
  say "  FAIL  the provisioner did not refuse an inline secret in NODE_ENV_FILE"; fails=$((fails+1))
fi
rm -rf "$envtmp"

say "44. the node bus worker names the refusal it cannot proceed past (CF-215)"
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$HERE/scripts/node-bus-worker.py" \
  && say "  PASS  scripts/node-bus-worker.py compiles" || { say "  FAIL  node-bus-worker.py does not compile"; fails=$((fails+1)); }

buswtmp=$(mktemp -d)
worker="$HERE/scripts/node-bus-worker.py"
# one throwaway PKCS#8 ed25519 key, generated here and nowhere committed: the worker never
# invents key material, so a leg that needs a key has to supply one.
busk() {
  python3 - "$1" <<'PROBE'
import base64, os, sys
seed = os.urandom(32)
der = bytes.fromhex("302e020100300506032b657004220420") + seed
body = base64.b64encode(der).decode()
open(sys.argv[1], "w").write("-----BEGIN PRIVATE KEY-----\n" + body + "\n-----END PRIVATE KEY-----\n")
PROBE
  chmod 600 "$1"
}
busfix() {  # busfix <home> <node-project> <bus-project> <url> [key|nokey]
  rm -rf "$1"; mkdir -p "$1/.node/auth"
  printf '{"node_id":"fixture","project":"%s","repo":{"path":"%s/repo"},"harness":{"name":"fixture"}}\n' "$2" "$1" > "$1/.node/node.json"
  printf '{"agent":"fixture-node","project":"%s","url":"%s"}\n' "$3" "$4" > "$1/.node/crier.json"
  chmod 600 "$1/.node/node.json" "$1/.node/crier.json"
  printf 'fixture-token\n' > "$1/.node/auth/crier.token"; chmod 600 "$1/.node/auth/crier.token"
  mkdir -p "$1/repo"
  [ "${5:-nokey}" = key ] && busk "$1/.node/agent.key"
}
busrun() { env -i HOME="$1" PATH="$PATH" python3 "$worker" "${@:2}" 2>&1; }

# (1) the two identity files disagree about the project
busfix "$buswtmp/a" demo-a demo-b http://127.0.0.1:1
out=$(busrun "$buswtmp/a" --once); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  project — ' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  bus_health'; then
  say "  PASS  project mismatch -> named FAIL, exit $rc, no bus contact"
else
  say "  FAIL  project mismatch was not refused before the network (exit $rc)"; fails=$((fails+1))
fi

# (2) an unreadable identity file
busfix "$buswtmp/b" demo demo http://127.0.0.1:1 key
printf 'not json at all\n' > "$buswtmp/b/.node/node.json"
out=$(busrun "$buswtmp/b" --check); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  identity — .*not readable JSON'; then
  say "  PASS  unreadable identity -> named FAIL, exit $rc"
else
  say "  FAIL  an unreadable identity was not refused by name (exit $rc)"; fails=$((fails+1))
fi

# (3) no key material on the node — the failure the bus makes unavoidable
busfix "$buswtmp/c" demo demo http://127.0.0.1:1 nokey
out=$(busrun "$buswtmp/c" --once); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  signing_key — .*agent.key absent' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  bus_health' \
  && ! printf '%s\n' "$out" | grep -q 'BEGIN PRIVATE KEY'; then
  say "  PASS  absent key -> named FAIL naming the file, exit $rc, nothing invented, no bus contact"
else
  say "  FAIL  an absent key was not refused before the network (exit $rc)"; fails=$((fails+1))
fi

# (4) a bus that does not answer from this node
busfix "$buswtmp/d" demo demo http://127.0.0.1:1 key
out=$(busrun "$buswtmp/d" --once --timeout 2); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  bus_health — .*-> 000' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  inbox'; then
  say "  PASS  unreachable bus -> named FAIL with 000, exit $rc, no inbox read attempted"
else
  say "  FAIL  an unreachable bus was not refused by name (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$buswtmp"
# ch:trace row=CF-006 spec=specs/HARNESS.md#the-contract-every-adapter test=tests/selftest.sh::harness-conformance-battery doc=docs/HARNESS-CONFORMANCE.md prompt=none:fixture evidence=tests/harness-conformance.sh witness=none:local-fixture verdict=none:self-referential-hash commit=none:self-referential-hash memory=none:unresolved-namespace
say "45. the harness conformance battery can go red (fixture mode)"
# The battery is a checker; a checker that cannot print FAIL is decoration (AGENTS.md rule 2).
# Every leg below runs it against a fixture adapter dir and a fixture HOME: no credential, no
# network, no install. A green matrix is only worth the fixtures that can turn it red.
tmpd=$(mktemp -d)
mkdir -p "$tmpd/adapters" "$tmpd/empty" "$tmpd/home" "$tmpd/bin"
# The fixture harness binary exists so the smoke leg gets past "binary absent" and reaches the
# credential probe — that is the row under test in the first arm.
cat > "$tmpd/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '9.9.9-fixture\n'
STUB
chmod +x "$tmpd/bin/claude"
# A fixture adapter that measures something, so the same battery can also go GREEN.
cat > "$tmpd/adapters/install-claude-code.sh" <<'FIX'
#!/usr/bin/env bash
case "${1:---check}" in
  --check)
    printf 'harness: claude-code (fixture)\n'
    printf '  PASS  binary — %s/bin/claude\n' "$FIXTURE_BIN"
    printf '  PASS  version — 9.9.9-fixture\n'
    printf '\nCLAUDE-CODE: PASS\n' ;;
  *) printf '  FAIL  apply — fixture adapter has no ladder\n'; exit 1 ;;
esac
FIX
runb() {  # runb <adapter-dir> <only> [extra args...]
  local dir="$1" only="$2"; shift 2
  env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" FIXTURE_BIN="$tmpd" \
    /bin/bash "$HERE/tests/harness-conformance.sh" --only "$only" --adapter-dir "$dir" "$@" 2>&1
}
out=$(runb "$tmpd/adapters" claude-code --write-doc --doc "$tmpd/doc.md")
# (a) a credential that is absent is a SKIP naming it, never a PASS, and the fixture can go green.
if printf '%s\n' "$out" | grep -q '^  PASS  claude-code:check — adapter exit 0 — version — 9.9.9-fixture$' \
  && printf '%s\n' "$out" | grep -qE '^  SKIP  claude-code:smoke — ANTHROPIC_API_KEY or ~/\.claude/\.credentials\.json$' \
  && ! printf '%s\n' "$out" | grep -q 'claude-code:smoke — .*PASS'; then
  say "  PASS  absent credential -> SKIP naming it, while the same adapter's check leg goes green"
else
  say "  FAIL  an absent credential did not produce a named SKIP (or the fixture could not go green): $(printf '%s\n' "$out" | grep 'claude-code:' | tr '\n' ' ')"
  fails=$((fails+1))
fi
# --write-doc must carry the matrix and the SKIP, not a claim of support.
if [ -f "$tmpd/doc.md" ] && grep -q '^| harness | check | apply | smoke |$' "$tmpd/doc.md" \
  && grep -qF 'ANTHROPIC_API_KEY or ~/.claude/.credentials.json' "$tmpd/doc.md"; then
  say "  PASS  --write-doc wrote a matrix carrying the measured SKIP"
else
  say "  FAIL  --write-doc did not write a matrix carrying the SKIP"; fails=$((fails+1))
fi
# (b) a harness with no adapter is a FAIL, not a silent skip.
out=$(runb "$tmpd/adapters" deepseek); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  deepseek:check — no adapter at ' \
  && ! printf '%s\n' "$out" | grep -q '^  SKIP  deepseek:check'; then
  say "  PASS  missing adapter -> FAIL 'no adapter at', exit $rc"
else
  say "  FAIL  a missing adapter was not a named FAIL (exit $rc)"; fails=$((fails+1))
fi
# (c) an adapter that prints PASS with an empty value is caught, not quoted.
cat > "$tmpd/empty/install-hermes.sh" <<'FIX'
#!/usr/bin/env bash
printf 'harness: hermes (fixture)\n'
printf '  PASS  version — \n'
printf '\nHERMES: PASS\n'
exit 0
FIX
out=$(runb "$tmpd/empty" hermes); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^  FAIL  hermes:check — adapter printed PASS with no measured value: version (empty)$'; then
  say "  PASS  empty adapter value -> FAIL from the empty-value guard, exit $rc"
else
  say "  FAIL  a PASS with an empty value survived (exit $rc): $(printf '%s\n' "$out" | grep 'hermes:' | tr '\n' ' ')"; fails=$((fails+1))
fi

# One provisioning config per project, derived from the registry. Hand-written
# configs drift (a typo in a repo URL, one agent name on two projects, a
# namespace the registry no longer agrees with), so the configs are generated
# from the sqlite `projects` table instead. Every leg below can red on its own:
# the phantom repo, the duplicate agent, the ambiguous group, the idempotent
# re-run, the mutated file and the --check row that has to name the drifted key.
say "46. one provisioning config per project is generated from the registry, or refused"
GEN="$HERE/scripts/bunker_config_gen.py"
if python3 -B -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$GEN"; then
  say "  PASS  scripts/bunker_config_gen.py parses (python3 -B, stdlib only)"
else
  say "  FAIL  scripts/bunker_config_gen.py does not parse"; fails=$((fails+1))
fi

tmpd=$(mktemp -d)
mkdir -p "$tmpd/repo" "$tmpd/demoB" "$tmpd/demoC" "$tmpd/demoD"
python3 -B - "$tmpd" <<'PY'
import os, sqlite3, sys
tmpd = sys.argv[1]
schema = (
    "create table projects (name text primary key, repo_url text not null, "
    "workdir text not null, enabled integer not null default 1, "
    "namespace_id text, parent text not null default '')"
)
repo = "local:" + os.path.join(tmpd, "repo")
fixtures = {
    # a healthy family: a primary and two satellites sharing one clone
    "ok.db": [
        ("demo", repo, os.path.join(tmpd, "repo"), 1, "demo", ""),
        ("demo-qa", repo, os.path.join(tmpd, "repo"), 1, "demo", "demo"),
        ("demo-docs", repo, os.path.join(tmpd, "repo"), 0, "demo", "demo"),
    ],
    # one lane whose repo_url names a path that does not exist
    "phantom.db": [
        ("demo", repo, os.path.join(tmpd, "repo"), 1, "demo", ""),
        ("ghost", "local:" + os.path.join(tmpd, "gone"), tmpd, 1, "ghost", ""),
    ],
    # two projects whose names normalize to the same agent id
    "dup.db": [
        ("demo--alpha", "local:" + os.path.join(tmpd, "demoB"), tmpd, 1, "a", ""),
        ("demo-alpha", "local:" + os.path.join(tmpd, "demoC"), tmpd, 1, "b", ""),
    ],
    # two lanes in one clone with no name that is a prefix of the other
    "amb.db": [
        ("beta-one", "local:" + os.path.join(tmpd, "demoD"), tmpd, 1, "beta", ""),
        ("gamma-two", "local:" + os.path.join(tmpd, "demoD"), tmpd, 1, "gamma", ""),
    ],
}
for leaf, rows in fixtures.items():
    con = sqlite3.connect(os.path.join(tmpd, leaf))
    # throwaway fixture: no journal, no fsync — a bulk-mounted TMPDIR makes four
    # default-durability databases cost ~5 s each, and nothing here survives the arm
    con.execute("pragma journal_mode=off")
    con.execute("pragma synchronous=off")
    con.execute(schema)
    con.executemany("insert into projects values (?,?,?,?,?,?)", rows)
    con.commit()
    con.close()
PY

gen() {
  local db="$1" out="$2"; shift 2
  python3 -B "$GEN" --db "$db" --server bunker-01 --projects "$out" "$@"
}

# a dry run prints the config and creates nothing
out=$(gen "$tmpd/ok.db" "$tmpd/out-dry" --dry-run 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx 'PROJECT=demo' \
  && printf '%s\n' "$out" | grep -qx "REPO=$tmpd/repo" && [ ! -e "$tmpd/out-dry" ]; then
  say "  PASS  --dry-run prints the config on stdout and creates no directory, exit $rc"
else
  say "  FAIL  --dry-run wrote something or printed no config (exit $rc)"; fails=$((fails+1))
fi

out=$(gen "$tmpd/ok.db" "$tmpd/out" 2>&1); rc=$?
keys=$(grep -c '^[A-Z_][A-Z0-9_]*=' "$tmpd/out/demo.conf" 2>/dev/null || true)
if [ "$rc" -eq 0 ] && [ -f "$tmpd/out/demo.conf" ] && [ "$keys" = 11 ] \
  && grep -qx 'AGENT=cf-demo' "$tmpd/out/demo.conf" \
  && grep -qx 'NAMESPACE=demo' "$tmpd/out/demo.conf" \
  && grep -qx 'REF=main' "$tmpd/out/demo.conf" && grep -qx 'TTL=6h' "$tmpd/out/demo.conf" \
  && grep -qx 'GITHUB_TOKEN_FILE=~/.config/code-factory/demo/github.token' "$tmpd/out/demo.conf" \
  && [ "$(grep '^[A-Z_][A-Z0-9_]*=' "$tmpd/out/demo.conf" | LC_ALL=C sort -c 2>&1)" = "" ]; then
  say "  PASS  one family -> demo.conf with 11 sorted keys, AGENT=cf-demo, token keys as paths"
else
  say "  FAIL  the generated config was wrong or absent (exit $rc, $keys keys)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# the real provisioner must parse it: KEY=VALUE only, no unknown key
mkdir -p "$tmpd/bin"
printf '#!/usr/bin/env bash\ncase "$1" in list) echo bunker-01 ;; info) echo "agent b 6h" ;; exec) exit 0 ;; *) exit 1 ;; esac\n' > "$tmpd/bin/bunker"
chmod +x "$tmpd/bin/bunker"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" /bin/bash "$HERE/scripts/bunker-provision.sh" \
  --config "$tmpd/out/demo.conf" --check 2>&1)
if printf '%s\n' "$out" | grep -q '  PASS  config — demo.conf — ' \
  && ! printf '%s\n' "$out" | grep -q 'FAIL  config'; then
  say "  PASS  bunker-provision.sh parses the generated config with no unknown key"
else
  say "  FAIL  the provisioner refused the generated config"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(gen "$tmpd/phantom.db" "$tmpd/out-phantom" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q '  FAIL  ghost — PHANTOM — repo_url names local:.*/gone' \
  && [ ! -e "$tmpd/out-phantom" ]; then
  say "  PASS  a PHANTOM repo_url is refused by name, exit $rc, nothing written"
else
  say "  FAIL  the phantom lane was not refused or something was written (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(gen "$tmpd/dup.db" "$tmpd/out-dup" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q "'cf-demo-alpha' derived by demo--alpha and demo-alpha" \
  && [ ! -e "$tmpd/out-dup" ]; then
  say "  PASS  two projects deriving one AGENT are refused by name, exit $rc, nothing written"
else
  say "  FAIL  the AGENT collision was not refused (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(gen "$tmpd/amb.db" "$tmpd/out-amb" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'AMBIGUOUS — no lane name or family key is a prefix' \
  && [ ! -e "$tmpd/out-amb" ]; then
  say "  PASS  a group with no common name prefix is refused as AMBIGUOUS, exit $rc"
else
  say "  FAIL  an ambiguous group was guessed instead of refused (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

before=$(sha256sum "$tmpd/out/demo.conf" | awk '{print $1}')
out=$(gen "$tmpd/ok.db" "$tmpd/out" 2>&1); rc=$?
after=$(sha256sum "$tmpd/out/demo.conf" | awk '{print $1}')
if [ "$rc" -eq 0 ] && [ "$before" = "$after" ] \
  && printf '%s\n' "$out" | grep -q '  PASS  unchanged — .*/demo.conf — byte-identical' \
  && ! printf '%s\n' "$out" | grep -q 'PASS  wrote'; then
  say "  PASS  a second run is byte-identical and reports unchanged, exit $rc"
else
  say "  FAIL  the second run rewrote the config or reported a write (exit $rc)"; fails=$((fails+1))
fi

sed -i 's/^SERVER=.*/SERVER=other-host/' "$tmpd/out/demo.conf"
mutated=$(sha256sum "$tmpd/out/demo.conf" | awk '{print $1}')
out=$(python3 -B "$GEN" --db "$tmpd/ok.db" --server bunker-01 --projects "$tmpd/out" --check 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q "  FAIL  drift — .*/demo.conf — SERVER: file 'other-host' ≠ registry 'bunker-01'" \
  && [ "$(sha256sum "$tmpd/out/demo.conf" | awk '{print $1}')" = "$mutated" ]; then
  say "  PASS  --check names the drifted key, exits $rc and writes nothing"
else
  say "  FAIL  --check did not name the drifted SERVER key (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(gen "$tmpd/ok.db" "$tmpd/out" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'pass --force to rewrite' \
  && grep -qx 'SERVER=other-host' "$tmpd/out/demo.conf"; then
  say "  PASS  a differing config is not rewritten without --force, exit $rc"
else
  say "  FAIL  a differing config was rewritten without --force (exit $rc)"; fails=$((fails+1))
fi

out=$(gen "$tmpd/ok.db" "$tmpd/out" --force 2>&1); rc=$?
out2=$(python3 -B "$GEN" --db "$tmpd/ok.db" --server bunker-01 --projects "$tmpd/out" --check 2>&1); rc2=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '  PASS  rewrote — ' \
  && [ "$rc2" -eq 0 ] && printf '%s\n' "$out2" | grep -q 'BUNKER-CONFIG: PASS — 1 config checked, no drift'; then
  say "  PASS  --force rewrites the file and --check is green afterwards (exit $rc2)"
else
  say "  FAIL  --force did not restore the file (rewrite exit $rc, check exit $rc2)"; fails=$((fails+1))
  printf '%s\n' "$out2" | sed 's/^/    | /'
fi
rm -rf "$tmpd"
# BEGIN cf244-node-freshness
say "47. a node checkout freshness check can go RED: drift and a local edit are named (CF-244)"
# The failure this closes: a node's clone sat one commit behind origin/main while every layer
# printed PASS, because nothing measured the checkout's git state. Each arm builds a real local
# origin and drives the real scripts. The first arm is the fixture's own green proof — a clone in
# sync with its origin — so a red arm below is the check refusing real drift, not a broken fixture.
NF="$HERE/scripts/node_freshness.py"
if python3 -B -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$NF"; then
  say "  PASS  scripts/node_freshness.py parses (python3 -B, stdlib only)"
else
  say "  FAIL  scripts/node_freshness.py does not parse"; fails=$((fails+1))
fi
tmpd=$(mktemp -d)
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
git init -q -b main "$tmpd/seed"
printf 'one\n' > "$tmpd/seed/a.txt"
git -C "$tmpd/seed" add a.txt
git -C "$tmpd/seed" commit -qm one
git init -q --bare "$tmpd/origin.git"
git -C "$tmpd/origin.git" symbolic-ref HEAD refs/heads/main
git -C "$tmpd/seed" push -q "$tmpd/origin.git" main
# cloned BEFORE origin advances: this is the node that stayed behind
git clone -q "$tmpd/origin.git" "$tmpd/behind"
printf 'two\n' > "$tmpd/seed/b.txt"
git -C "$tmpd/seed" add b.txt
git -C "$tmpd/seed" commit -qm two
git -C "$tmpd/seed" push -q "$tmpd/origin.git" main
# cloned AFTER the last push: in sync, the fixture's proof that it can go green
git clone -q "$tmpd/origin.git" "$tmpd/pass"
git clone -q "$tmpd/origin.git" "$tmpd/dirty"
git clone -q "$tmpd/origin.git" "$tmpd/det"
git clone -q "$tmpd/origin.git" "$tmpd/noorigin"
git -C "$tmpd/noorigin" remote remove origin
git -C "$tmpd/det" checkout -q --detach HEAD
printf 'a local edit\n' >> "$tmpd/dirty/a.txt"
# Provisioning fixtures, cloned now so their clones do NOT carry scripts/node_freshness.py:
# they exercise the node-side fallback (rung 2 of layer 40), not the clone's own copy.
mkdir -p "$tmpd/pn-dirty" "$tmpd/pn-drift"
git clone -q "$tmpd/origin.git" "$tmpd/pn-dirty/repo"
git clone -q "$tmpd/origin.git" "$tmpd/pn-drift/repo"
printf 'a local edit\n' >> "$tmpd/pn-dirty/repo/a.txt"

out=$(python3 -B "$NF" --workdir "$tmpd/pass" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS' \
  && printf '%s\n' "$out" | grep -Fq 'branch=main' \
  && printf '%s\n' "$out" | grep -Fq 'ancestor=true behind=0'; then
  say "  PASS  a clone in sync with its origin -> RESULT: PASS, exit $rc (the fixture can go green)"
else
  say "  FAIL  a clean clone did not pass (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(python3 -B "$NF" --workdir "$tmpd/behind" 2>&1); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Eq '^RESULT: FAIL \(behind 1 commit' \
  && printf '%s\n' "$out" | grep -Fq 'behind=1' \
  && printf '%s\n' "$out" | grep -Fq 'differing path(s) — b.txt'; then
  say "  PASS  origin advances -> exit $rc, RESULT names the lag and the differing file b.txt"
else
  say "  FAIL  drift was not refused with the lag and the file named (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(python3 -B "$NF" --workdir "$tmpd/dirty" 2>&1); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Eq '^RESULT: FAIL \(1 uncommitted path' \
  && printf '%s\n' "$out" | grep -Fq 'uncommitted path(s): a.txt' \
  && printf '%s\n' "$out" | grep -Fq 'the fix belongs upstream'; then
  say "  PASS  an uncommitted edit -> exit $rc, the path is named and called upstream's problem"
else
  say "  FAIL  a local edit was not reported as a finding (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(python3 -B "$NF" --workdir "$tmpd/det" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq 'detached HEAD at'; then
  say "  PASS  a detached HEAD -> exit $rc, the branch state is named"
else
  say "  FAIL  a detached HEAD was not named (exit $rc)"; fails=$((fails+1))
fi

out=$(python3 -B "$NF" --workdir "$tmpd/noorigin" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "no 'origin' remote"; then
  say "  PASS  a checkout with no origin -> exit $rc, the reason is named (no crash)"
else
  say "  FAIL  a missing origin crashed or was not refused (exit $rc)"; fails=$((fails+1))
fi

# Bunker mode: one exec round trip, home resolved from the agent, rows parsed on this host.
mkdir -p "$tmpd/bin" "$tmpd/node/pass"
git clone -q "$tmpd/origin.git" "$tmpd/node/pass/repo"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
printf 'exec\n' >> "${FIXTURE_LOG:?}"
exec bash -c "${!#}"
EOF
chmod +x "$tmpd/bin/bunker"
out=$(env PATH="$tmpd/bin:$PATH" FIXTURE_LOG="$tmpd/bunker.log" HOME="$tmpd/node/pass" \
  python3 -B "$NF" --agent cf-fixture --server fixture 2>&1); rc=$?
execs=$(wc -l < "$tmpd/bunker.log")
if [ "$rc" -eq 0 ] && [ "$execs" = 1 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS' \
  && printf '%s\n' "$out" | grep -Fq 'agent cf-fixture via fixture' \
  && printf '%s\n' "$out" | grep -Fq "checkout $tmpd/node/pass/repo"; then
  say "  PASS  bunker mode: one exec round trip, home resolved from the agent, RESULT: PASS"
else
  say "  FAIL  bunker mode did not measure the agent's checkout ($execs execs, exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
out=$(env PATH="$tmpd/bin:$PATH" FIXTURE_LOG="$tmpd/bunker.log" HOME="$tmpd/node/pass" \
  python3 -B "$NF" --agent cf-fixture --server fixture --path "$tmpd/behind" --json 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" \
  | python3 -B -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["status"]=="FAIL" and d["behind"]==1 and d["differing_files"]==["b.txt"] and d["branch"]=="main" else 1)'; then
  say "  PASS  bunker mode --json: status FAIL, behind 1, differing_files [b.txt] (provisioning stores this)"
else
  say "  FAIL  bunker mode --json did not carry the measurement (exit $rc)"; fails=$((fails+1))
fi

# Provisioning: layer 40 measures the checkout after the clone. DIRTY is a WARN (the node may be
# mid-task); DRIFT is a FAIL (the node would work a tree that no longer matches origin/main).
pn40() {  # $1 home -> project-node.sh --check --layers 40 output+rc
  env HOME="$1" NODE_PROJECT=demo NODE_DISK_FLOOR=1 CRIER_URL=http://fixture.invalid:8767 \
    /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 40 2>&1
}
# rung 1: the clone carries the probe (a code-factory node). Its own seed and origin, because
# the probe commit must not advance the origin rungs 2 and 3 measure against: a fixture ordering
# that advances a shared origin turns the dirty arm into drift and grades the fixture, not the code.
git init -q -b main "$tmpd/seed2"
printf 'one\n' > "$tmpd/seed2/a.txt"
git -C "$tmpd/seed2" add a.txt
git -C "$tmpd/seed2" commit -qm one
mkdir -p "$tmpd/seed2/scripts"
cp "$NF" "$tmpd/seed2/scripts/node_freshness.py"
git -C "$tmpd/seed2" add scripts/node_freshness.py
git -C "$tmpd/seed2" commit -qm "carry the probe"
git init -q --bare "$tmpd/origin2.git"
git -C "$tmpd/origin2.git" symbolic-ref HEAD refs/heads/main
git -C "$tmpd/seed2" push -q "$tmpd/origin2.git" main
mkdir -p "$tmpd/pn-probe"
git clone -q "$tmpd/origin2.git" "$tmpd/pn-probe/repo"
out=$(pn40 "$tmpd/pn-probe"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  PASS  freshness — branch=main' \
  && printf '%s\n' "$out" | grep -Fq 'behind=0 ancestor=true' \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS'; then
  say "  PASS  provisioning runs the clone's own probe after the clone -> PASS freshness, NODE: PASS"
else
  say "  FAIL  layer 40 did not measure the clone with the probe it carries (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# rung 2: a clone of another project carries no probe -> the node-side fallback measures it
out=$(pn40 "$tmpd/pn-dirty"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  WARN  freshness — ' \
  && printf '%s\n' "$out" | grep -Fq 'dirty=a.txt' \
  && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL')" = 0 ] \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS'; then
  say "  PASS  a dirty checkout at provision time -> WARN naming a.txt, no FAIL row, NODE: PASS"
else
  say "  FAIL  a dirty checkout was not a named WARN (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# advance origin AFTER the clone, so the node's tree is behind its own remote
git -C "$tmpd/seed" commit -qm three --allow-empty
git -C "$tmpd/seed" push -q "$tmpd/origin.git" main
out=$(pn40 "$tmpd/pn-drift"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq '  FAIL  freshness — ' \
  && printf '%s\n' "$out" | grep -Fq 'behind=1' \
  && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (1)'; then
  say "  PASS  a drifted checkout at provision time -> FAIL naming behind=1, NODE: FAIL (1), exit $rc"
else
  say "  FAIL  drift was not a FAIL row in layer 40 (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# The manifest records the measurement (CF-244 AC3): node.json carries `freshness`.
mkdir -p "$tmpd/pn-scripts/harness" "$tmpd/mf/.node"
cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" "$tmpd/pn-scripts/"
cat > "$tmpd/pn-scripts/harness/install-fixture.sh" <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/../lib.sh"
say "harness: fixture (CF-244)"
ok "harness:fixture" "simulated passing adapter"
exit 0
EOF
chmod +x "$tmpd/pn-scripts/harness/install-fixture.sh"
cat > "$tmpd/bin/curl" <<'EOF'
#!/usr/bin/env bash
o=""
while [ $# -gt 0 ]; do
  case "$1" in -o) o="$2"; shift 2 ;; -*) shift ;; *) shift ;; esac
done
[ -n "$o" ] && [ "$o" != /dev/null ] && printf '%s' '{"status":"ok","auth_required":true}' > "$o"
printf '200'
EOF
chmod +x "$tmpd/bin/curl"
printf '{"agent":"fixture"}' > "$tmpd/mf/.node/crier.json"
chmod 600 "$tmpd/mf/.node/crier.json"
git clone -q "$tmpd/origin.git" "$tmpd/mf/repo"
full_apply() {  # $1 home
  env PATH="$tmpd/bin:$PATH" HOME="$1" NODE_PROJECT=demo NODE_HARNESS=fixture \
    CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
    /bin/bash "$tmpd/pn-scripts/project-node.sh" --apply --project demo --harness fixture 2>&1
}
out=$(full_apply "$tmpd/mf"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS' \
  && python3 -B - "$tmpd/mf/.node/node.json" <<'PY'
import json, sys
fresh = json.load(open(sys.argv[1]))["freshness"]
assert fresh["status"] == "PASS", fresh
assert fresh["ladder"] == "PASS", fresh
assert fresh["branch"] == "main", fresh
assert fresh["behind"] == 0, fresh
assert fresh["dirty_files"] == [], fresh
assert fresh["differing_files"] == [], fresh
PY
then
  say "  PASS  --apply records freshness{status:PASS, ladder:PASS, behind:0} in node.json, exit $rc"
else
  say "  FAIL  node.json did not carry the measured freshness (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
printf 'a local edit\n' >> "$tmpd/mf/repo/a.txt"
out=$(full_apply "$tmpd/mf"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  WARN  freshness — ' \
  && python3 -B - "$tmpd/mf/.node/node.json" <<'PY'
import json, sys
fresh = json.load(open(sys.argv[1]))["freshness"]
assert fresh["status"] == "FAIL", fresh
assert fresh["ladder"] == "WARN", fresh
assert fresh["dirty_files"] == ["a.txt"], fresh
PY
then
  say "  PASS  a dirty checkout is recorded (status FAIL, ladder WARN, dirty_files [a.txt]) and the ladder still passes, exit $rc"
else
  say "  FAIL  a dirty checkout was not recorded as a finding (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -rf "$tmpd"
# END cf244-node-freshness

# --- node_seed.py: the seed contract (CF-220) ------------------------------------------------
# A seed that cannot refuse is a copy. Each arm below fails for a different
# reason: a missing file in the record, a tampered file on disk, a budget
# breach, and a backup artefact declared as seedable.

say ""
say "node_seed — the declared seed, its digests, and what it refuses"

SEED="$(cd "$(dirname "$0")/.." && pwd)/scripts/node_seed.py"
SEED_MANIFEST="$(cd "$(dirname "$0")/.." && pwd)/config/node-seed.txt"
seed_tmp=$(mktemp -d); seed_home=$(mktemp -d)

out=$(python3 -B "$SEED" build --manifest "$SEED_MANIFEST" --repo-root "$(cd "$(dirname "$0")/.." && pwd)" --out "$seed_tmp/seed.tar" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$seed_tmp/seed.tar.json" ] \
  && python3 - "$seed_tmp/seed.tar.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["files"], "record has no files"
assert all(len(f["sha256"]) == 64 for f in d["files"]), "a digest is not sha256"
assert any(f["path"].startswith("prompts/") for f in d["files"]), "no prompts declared"
assert any(f["path"].startswith("skills/") for f in d["files"]), "no skills declared"
PY
then
  say "  PASS  build writes a record with a sha256 per declared file, exit $rc"
else
  say "  FAIL  build did not produce a digest record (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(python3 -B "$SEED" apply --tar "$seed_tmp/seed.tar" --record "$seed_tmp/seed.tar.json" --home "$seed_home" 2>&1); rc=$?
out2=$(python3 -B "$SEED" check --record "$seed_tmp/seed.tar.json" --home "$seed_home" 2>&1); rc2=$?
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -f "$seed_home/.hermes/prompts/foreman.md" ] \
  && [ -f "$seed_home/.hermes/seed-applied.json" ]; then
  say "  PASS  apply installs prompts and skills and a green check follows (exit $rc, $rc2)"
else
  say "  FAIL  apply/check did not land a usable seed (exit $rc, $rc2)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

printf 'tampered\n' >> "$seed_home/.hermes/prompts/foreman.md"
out=$(python3 -B "$SEED" check --record "$seed_tmp/seed.tar.json" --home "$seed_home" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'prompts/foreman.md drifted'; then
  say "  PASS  a tampered file fails the check and is named (exit $rc)"
else
  say "  FAIL  a tampered file did not fail the check (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# A record whose digest does not match the archive must install NOTHING.
python3 - "$seed_tmp" <<'PY'
import json, sys
p = sys.argv[1] + "/seed.tar.json"
d = json.load(open(p))
d["files"][0]["sha256"] = "0" * 64
json.dump(d, open(sys.argv[1] + "/bad.json", "w"))
PY
seed_home2=$(mktemp -d)
out=$(python3 -B "$SEED" apply --tar "$seed_tmp/seed.tar" --record "$seed_tmp/bad.json" --home "$seed_home2" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ ! -d "$seed_home2/.hermes/prompts" ]; then
  say "  PASS  a digest mismatch refuses the whole seed and installs nothing (exit $rc)"
else
  say "  FAIL  a digest mismatch was not refused, or files were installed anyway (exit $rc)"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

out=$(python3 -B "$SEED" build --manifest "$SEED_MANIFEST" --repo-root "$(cd "$(dirname "$0")/.." && pwd)" --out "$seed_tmp/small.tar" --budget 100 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'exceeds the declared ceiling'; then
  say "  PASS  a seed over the size budget is refused (exit $rc)"
else
  say "  FAIL  the size budget did not refuse (exit $rc)"; fails=$((fails+1))
fi

printf 'backups/board.tar.gz\n' > "$seed_tmp/bad.manifest"
out=$(python3 -B "$SEED" build --manifest "$seed_tmp/bad.manifest" --out "$seed_tmp/b.tar" 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  say "  PASS  a backup artefact declared as seedable is refused (exit $rc)"
else
  say "  FAIL  a backup artefact was accepted as seed input (exit $rc)"; fails=$((fails+1))
fi

rm -rf "$seed_tmp" "$seed_home" "$seed_home2"

# BEGIN cf250-seed-drift
say "48. verify-node.sh folds the seed record: a node's seeded prompts and skills are the digests the seed named (CF-250)"
# The failure this closes: node_seed.py check can refuse a drifted seed (CF-220) but nothing on
# the control host ran it — provisioning deletes the node-side copy of the seeder after it
# applies. verify-node.sh grew a seed_drift leg that stages the seeder and reads its verdict.
# Each arm below builds the fixture with the REAL seeder (build + apply) and drives the REAL
# wrapper offline; the bunker arm proves the one-round-trip staging against a stub node.
NSD="$HERE/scripts/node_seed_drift.py"
if python3 -B -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$NSD"; then
  say "  PASS  scripts/node_seed_drift.py parses (python3 -B, stdlib only)"
else
  say "  FAIL  scripts/node_seed_drift.py does not parse"; fails=$((fails+1))
fi
tmpd=$(mktemp -d)
mkdir -p "$tmpd/src/prompts" "$tmpd/src/skills"
printf 'prompts/foreman.md\nskills/fake-skill.md\n' > "$tmpd/fixture.manifest"
# The fixture's own green proof: the bytes the record will pin, applied by the real seeder.
printf 'the foreman procedure\n' > "$tmpd/src/prompts/foreman.md"
printf 'a declared skill\n' > "$tmpd/src/skills/fake-skill.md"
out=$(python3 -B "$SEED" build --manifest "$tmpd/fixture.manifest" --repo-root "$tmpd/src" --out "$tmpd/seed.tar" 2>&1)
if [ $? -eq 0 ] && [ -f "$tmpd/seed.tar.json" ]; then
  say "  PASS  the fixture seed record built (2 files, sha256 each)"
else
  say "  FAIL  the fixture seed record did not build"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
out=$(python3 -B "$SEED" apply --tar "$tmpd/seed.tar" --record "$tmpd/seed.tar.json" --home "$tmpd/node-home" 2>&1)
if [ $? -eq 0 ] && [ -f "$tmpd/node-home/.hermes/seed-applied.json" ]; then
  say "  PASS  the fixture node home carries the applied record at .hermes/seed-applied.json"
else
  say "  FAIL  the seeder did not apply to the fixture node home"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# green: record and files agree — PASS and the row names the file count.
out=$(python3 -B "$NSD" --home "$tmpd/node-home" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  seed_drift — ' \
  && printf '%s\n' "$out" | grep -Fq '2 seeded files present and matching'; then
  say "  PASS  a seed whose files match its record -> exit $rc, RESULT: PASS, the row names the count"
else
  say "  FAIL  a matching seed did not pass with the file count named (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# red: one file tampered by hand — the drifted path and both digest prefixes are named.
printf 'tampered by hand\n' >> "$tmpd/node-home/.hermes/prompts/foreman.md"
out=$(python3 -B "$NSD" --home "$tmpd/node-home" 2>&1); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fq 'prompts/foreman.md drifted (expected ' \
  && printf '%s\n' "$out" | grep -Eq '\(expected [0-9a-f]{12}, measured [0-9a-f]{12}\)' \
  && printf '%s\n' "$out" | grep -Fxq 'RESULT: FAIL (1 seeded path(s) differ from the record)'; then
  say "  PASS  a tampered file -> exit $rc, the path and both digest prefixes are named"
else
  say "  FAIL  a tampered seed did not fail with the path and prefixes named (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
printf 'the foreman procedure\n' > "$tmpd/node-home/.hermes/prompts/foreman.md"
out=$(python3 -B "$NSD" --home "$tmpd/node-home" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS'; then
  say "  PASS  the file restored -> exit $rc, RESULT: PASS again (the red arm can go green)"
else
  say "  FAIL  the restored file did not pass again (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# absent: no seed record — WARN naming the record's path; --strict-seed turns the SAME fixture into FAIL.
rec="$tmpd/node-home/.hermes/seed-applied.json"
mv "$rec" "$tmpd/record.bak"
out=$(python3 -B "$NSD" --home "$tmpd/node-home" 2>&1); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Fq '  WARN  seed_drift — no seed record at ' \
  && printf '%s\n' "$out" | grep -Fq "$rec"; then
  say "  PASS  a node with no seed record -> exit $rc, the absent record's path is named"
else
  say "  FAIL  an absent record was not a WARN naming its path (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
out=$(python3 -B "$NSD" --home "$tmpd/node-home" --strict-seed 2>&1); rs=$?
if [ "$rs" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — no seed record at ' \
  && printf '%s\n' "$out" | grep -Fq 'an unknown seed is not a pass'; then
  say "  PASS  the SAME fixture under --strict-seed -> exit $rs, FAIL (unknown is not a pass)"
else
  say "  FAIL  --strict-seed did not refuse the absent record (exit $rs)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
mv "$tmpd/record.bak" "$rec"
out=$(python3 -B "$NSD" --home "$tmpd/node-home" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS'; then
  say "  PASS  the record restored -> exit $rc, RESULT: PASS again (the absent arm can go green)"
else
  say "  FAIL  the restored record did not pass again (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# Bunker mode offline: the wrapper must stage the seeder to the "node", run its check, and clean
# the staged file up — in ONE bunker exec round trip, exactly like the freshness arm's stub.
mkdir -p "$tmpd/bin"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
printf 'exec\n' >> "${FIXTURE_LOG:?}"
exec bash -c "${!#}"
EOF
chmod +x "$tmpd/bin/bunker"
out=$(env PATH="$tmpd/bin:$PATH" FIXTURE_LOG="$tmpd/bunker.log" HOME="$tmpd/node-home" \
  python3 -B "$NSD" --agent cf-fixture --server fixture 2>&1); rc=$?
execs=$(wc -l < "$tmpd/bunker.log")
if [ "$rc" -eq 0 ] && [ "$execs" = 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS' \
  && printf '%s\n' "$out" | grep -Fq 'agent cf-fixture via fixture' \
  && printf '%s\n' "$out" | grep -Fq '2 seeded files present and matching'; then
  say "  PASS  bunker mode offline: ONE exec round trip stages the seeder, checks the node home, RESULT: PASS"
else
  say "  FAIL  bunker mode did not measure the seeded home in one round trip ($execs execs, exit $rc)"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi
out=$(env PATH="$tmpd/bin:$PATH" FIXTURE_LOG="$tmpd/bunker.log" HOME="$tmpd/node-home" \
  python3 -B "$NSD" --agent cf-fixture --server fixture --json 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" \
  | python3 -B -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["status"]=="PASS" and d["record_present"] is True and d["file_count"]==2 and d["home"]!="" else 1)'; then
  say "  PASS  bunker mode --json: status PASS, record_present true, file_count 2"
else
  say "  FAIL  bunker mode --json did not carry the measurement (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"
# END cf250-seed-drift

# BEGIN cf218-kinds
# CF-218: layer 10 graded a fixed list (python3+venv, git, curl, tar, sha256sum) and
# warned on node, so a node with no Go toolchain printed PASS while unable to build the
# fleet's largest repo class (61 distinct repo origins: go 27, node 22, python 16,
# rust 5). This section proves the derived set can go RED and GREEN on the SAME tree,
# that a refused module proxy is a named FAIL, and that the generic fallback names
# itself instead of silently grading the old fixed list.
say "49. layer 10 grades the toolchain the repository kind needs, Go included (CF-218)"
tmpd=$(mktemp -d)
# Layer 10 reads $HOME/repo for kind evidence, because it runs BEFORE layer 40 clones.
# A fresh node has no clone, so the fixture only seeds the marker file.
mkdir -p "$tmpd/home/repo"
printf 'module fixture.example/demo\n\ngo 1.21\n' > "$tmpd/home/repo/go.mod"
mkdir -p "$tmpd/bin" "$tmpd/empty"

# A PATH with a named tool removed entirely, built by dropping every directory that
# carries it: a fixture that hardcoded /usr/bin would assert nothing on a host where
# the tool lives in ~/.local/bin or /usr/local/go/bin, and would lie on the other.
path_without() {
  local skip="$1" out="" d
  IFS=: read -ra path_dirs <<< "$PATH"
  for d in "${path_dirs[@]}"; do
    [ -n "$d" ] || continue
    [ -x "$d/$skip" ] && continue
    out="${out:+$out:}$d"
  done
  printf '%s' "$out"
}
nogo_path=$(path_without go)
if env PATH="$nogo_path" bash -c 'command -v go' >/dev/null 2>&1; then
  say "  FAIL  fixture could not build a go-free PATH (go still resolvable)"; fails=$((fails+1))
else
  say "  PASS  fixture PATH carries no go"
fi

# --- arm RED: a go.mod workspace and no Go binary.
out=$(env PATH="$nogo_path" HOME="$tmpd/home" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  tool:go — ')" = 1 ] \
  && printf '%s\n' "$out" | grep -Fq '  PASS  kinds — go (derived from workspace ' \
  && printf '%s\n' "$out" | grep -Fq 'markers: go.mod' \
  && ! printf '%s\n' "$out" | grep -q '^  WARN  tool:go'; then
  say "  PASS  go.mod workspace without go -> exit $rc and ONE FAIL tool:go row (not a WARN)"
else
  say "  FAIL  a go.mod workspace without go did not FAIL the layer by name (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm GREEN: the same tree, with a stub go that answers version and the proxy probe.
cat > "$tmpd/bin/go" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  version) printf 'go version go1.99.0 fixture/amd64\n' ;;
  env) case "$2" in GOPROXY) printf 'https://proxy.fixture.invalid,direct\n' ;; *) printf '\n' ;; esac ;;
  mod) case "$2" in init) : ;; download) printf '{"Path":"rsc.io/quote","Version":"v1.5.2"}\n' ;; esac ;;
esac
exit 0
EOF
chmod +x "$tmpd/bin/go"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -Fq '  PASS  tool:go — ' \
  && printf '%s\n' "$out" | grep -Fq 'go1.99.0 fixture/amd64' \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  go:proxy — rsc.io/quote@v1.5.2 resolved via https://proxy.fixture.invalid,direct' \
  && ! printf '%s\n' "$out" | grep -q '^  FAIL  '; then
  say "  PASS  the same tree with a go that resolves the pinned module -> go rows PASS, exit 0"
else
  say "  FAIL  the go-present arm did not go green (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm PROXY-RED: go present, the module proxy refuses -> named FAIL naming both.
cat > "$tmpd/bin/go" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  version) printf 'go version go1.99.0 fixture/amd64\n' ;;
  env) printf 'https://proxy.fixture.invalid,direct\n' ;;
  mod) case "$2" in
         init) : ;;
         download) printf 'go: rsc.io/quote@v1.5.2: dial tcp: connection refused\n' >&2; exit 1 ;;
       esac ;;
esac
exit 0
EOF
chmod +x "$tmpd/bin/go"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -Fq '  PASS  tool:go — ' \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  go:proxy — rsc.io/quote@v1.5.2 via https://proxy.fixture.invalid,direct: go: rsc.io/quote@v1.5.2: dial tcp: connection refused'; then
  say "  PASS  a proxy that refuses -> FAIL go:proxy naming the proxy and the error"
else
  say "  FAIL  an unresolvable module proxy was not a named FAIL (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm DECLARED: --kinds drives the set on a tree with NO marker at all, and the
# set is not a fixed list: rust and node are graded, go is not.
cat > "$tmpd/bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo 1.99.0 (fixture 2026-11-05)\n'
EOF
cat > "$tmpd/bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'v99.0.0\n'
EOF
chmod +x "$tmpd/bin/cargo" "$tmpd/bin/node"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/empty" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 --kinds rust,node 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  kinds — rust,node (declared via --kinds/NODE_KINDS)' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  tool:cargo — ' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  tool:node — ' \
  && ! printf '%s\n' "$out" | grep -q 'tool:go'; then
  say "  PASS  --kinds rust,node on a marker-less tree grades cargo and node, not go"
else
  say "  FAIL  --kinds did not drive the graded set (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm NODE-RED: node is the kind and there is no node -> FAIL, not the old WARN.
nonode_path=$(path_without node)
out=$(env PATH="$nonode_path" HOME="$tmpd/empty" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 --kinds node 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  tool:node — missing' \
  && ! printf '%s\n' "$out" | grep -q '^  WARN  tool:node'; then
  say "  PASS  a declared node kind with no node -> FAIL tool:node (the WARN shape is gone)"
else
  say "  FAIL  a declared node kind still warned instead of failing (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm GENERIC: no declaration and no marker => the fallback SAYS it is the fallback.
out=$(env PATH="$nogo_path" HOME="$tmpd/empty" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 2>&1); rc=$?
if printf '%s\n' "$out" | grep -Fq '  WARN  kinds — generic fallback — no --kinds/NODE_KINDS and no kind marker in ' \
  && ! printf '%s\n' "$out" | grep -q 'tool:go'; then
  say "  PASS  no evidence -> generic fallback is named on the row, and nothing else is graded"
else
  say "  FAIL  the generic fallback was silent (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# --- arm UNKNOWN: a typo in the kind list is refused by name before any layer runs.
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/empty" NODE_PROJECT=demo \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo --layers 10 --kinds go,cobol 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -Fq "  FAIL  kinds — unknown kind 'cobol'" \
  && ! printf '%s\n' "$out" | grep -q '\[10\] base'; then
  say "  PASS  an unknown kind is a named FAIL before any layer runs (never a silent pass)"
else
  say "  FAIL  an unknown kind was not refused by name (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

rm -rf "$tmpd"
# END cf218-kinds

# ch:trace row=CF-219 spec=specs/NODE.md#layer-10 test=tests/selftest.sh::install-go doc=specs/NODE.md evidence=tests/selftest.sh::install-go witness=none:fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unresolved-namespace
# BEGIN install-go
say "50. install-go.sh can go red, and its pin is a digest (CF-219)"
tmpd=$(mktemp -d)
go_pin=$(sed -n 's/^GO_PIN="\([^"]*\)"$/\1/p' "$HERE/scripts/install-go.sh")

# NEGATIVE: a clean environment with no Go must produce one named FAIL row.
negative_home="$tmpd/negative-home"
out=$(env -i PATH=/usr/bin:/bin HOME="$negative_home" \
  /bin/bash "$HERE/scripts/install-go.sh" --check 2>&1); rc=$?
expected="  FAIL  go — missing: pinned $go_pin not found under $negative_home/go-toolchain"
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
  say "  PASS  install-go negative: no Go -> named FAIL, exit $rc"
else
  say "  FAIL  install-go negative did not name the absent pin (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# DIGEST: the shared verifier must reject wrong bytes without publishing a destination;
# the same local fixture with its measured digest is the green control.
printf 'cf219 fixture archive bytes\n' > "$tmpd/archive"
wrong=0000000000000000000000000000000000000000000000000000000000000000
if fetch_verified "file://$tmpd/archive" "$tmpd/wrong-dest" "$wrong" >/dev/null 2>&1 \
  || [ -e "$tmpd/wrong-dest" ]; then
  say "  FAIL  install-go digest: wrong sha256 accepted or destination published"; fails=$((fails+1))
else
  say "  PASS  install-go digest: wrong sha256 refused and destination absent"
fi
right=$(sha256sum "$tmpd/archive" | cut -d' ' -f1)
if fetch_verified "file://$tmpd/archive" "$tmpd/right-dest" "$right" >/dev/null 2>&1 \
  && [ "$(sha256sum "$tmpd/right-dest" | cut -d' ' -f1)" = "$right" ]; then
  say "  PASS  install-go digest control: measured sha256 accepted"
else
  say "  FAIL  install-go digest control: correct sha256 refused"; fails=$((fails+1))
fi

# POSITIVE: this control host carries the same applied pin used by node provisioning.
host_go=$(command -v go || true)
if [ -n "$host_go" ]; then
  host_path="${host_go%/*}:/usr/bin:/bin"
  out=$(env -i PATH="$host_path" HOME="$tmpd/positive-home" \
    /bin/bash "$HERE/scripts/install-go.sh" --check 2>&1); rc=$?
else
  out="host go missing"; rc=127
fi
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -Eq "^  PASS  go — go version $go_pin [^[:space:]]+/[^[:space:]]+$"; then
  say "  PASS  install-go positive: applied host pin read back ($out)"
else
  say "  FAIL  install-go positive: host toolchain did not read back $go_pin (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -rf "$tmpd"
# END install-go

say ""
say "51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)"
# CF-254: the Tier-1 lint lane takes its scope from staged file EXTENSIONS and grades
# only *.py (.gitreins/config.yaml:9-16, naming engine/guard_manager.py:2823). This arm
# pins both states of the checker that lane runs, so the finding cannot be hand-edited
# away: the red that reached the branch is verdict
# .gitreins/history/2026-11-05/0e9f844d (F401 at scripts/master_doc_fill.py:16,18,19
# and scripts/master_doc_skeleton.py:10).
if ! command -v ruff >/dev/null 2>&1; then
  say "  FAIL  ruff is not on PATH, so the lint lane cannot be graded on this host"; fails=$((fails+1))
else
  tmpd=$(mktemp -d)
  # RED: an unused import is a finding the lane fails on, and it is named F401.
  printf 'import os\nprint("x")\n' > "$tmpd/one_unused.py"
  out=$(ruff check "$tmpd/one_unused.py" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'F401'; then
    say "  PASS  one unused import -> exit $rc naming F401"
  else
    say "  FAIL  one unused import did not red (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # GREEN: the same file, same checker, one line removed.
  printf 'print("x")\n' > "$tmpd/one_unused.py"
  if out=$(ruff check "$tmpd/one_unused.py" 2>&1); then
    say "  PASS  same file once the import is removed -> exit 0"
  else
    say "  FAIL  the clean file still reds, so the arm cannot go green"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # The tracked surface the lane grades must itself be clean.
  tracked=$(git -C "$HERE" ls-files '*.py')
  n_tracked=$(printf '%s\n' "$tracked" | grep -c . || true)
  if out=$(ruff check $tracked 2>&1); then
    say "  PASS  tracked python surface clean: $n_tracked files graded"
  else
    say "  FAIL  tracked python surface is red: a python-staging commit is refused"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  rm -rf "$tmpd"
fi
# END python-lint

# BEGIN master-doc-selection
say "52. master-doc fills converge on runner-owned status without network (CF-257)"
tmpd=$(mktemp -d)
if python3 - "$HERE/scripts/master_doc_fill.py" "$tmpd" <<'PY'
import importlib.util
import re
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("master_doc_fill", sys.argv[1])
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
root = Path(sys.argv[2])
master = root / "master"
master.mkdir()
source = root / "fixture.py"
source.write_text("# local fixture source\n")
runner.STATE = root / "state.jsonl"
runner.REPO_ROOT = root
text = (
    "# Fixture module\n\n"
    f"| Path | `{source}` |\n"
    "| Status | **RED — no verification recorded** |\n\n"
    "## Source\n"
    "The source is at fixture.py:1.\n"
    + "Local fixture evidence stays unchanged.\n" * 12
    + "\n## Unverified work\nRED — no verification recorded\n"
)
first = master / "01-first.md"
second = master / "02-second.md"
first.write_text(text)
second.write_text(text)
# Give the index a Path row too: its name must still exclude it, even with --force.
(master / "00-INDEX.md").write_text(text)
(master / "03-not-a-module.md").write_text("# Notes\n| Status | **RED** |\n")

# Exercise BOTH accepted-output writers using only local stubs, never provider calls.
with patch.object(runner, "call", return_value=(text, 0.0)):
    assert runner.fill_one(first, "fixture-api")[1] == "filled"
with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0)):
    assert runner.fill_one_hermes(second, "fixture-hermes", "fixture-model")[1] == "filled"
for md, provider in ((first, "fixture-api"), (second, "fixture-hermes")):
    filled = md.read_text()
    counts = runner.census(filled)
    assert counts["h2"] == 2 and counts["locators"] == 1
    status = runner.STATUS_ROW.findall(filled)
    assert len(status) == 1
    assert status[0].startswith(
        f"**{runner.FILLED_MARKER}{counts['h2']} sections, "
        f"{counts['locators']} locators, {provider}, "
    )
    assert re.search(r", \d{4}-\d{2}-\d{2} UTC\*\*$", status[0])
    assert "RED — no verification recorded" in filled  # unresolved body stays RED

# A missing status row must be refused, not silently recorded as a successful fill.
bad = text.replace("| Status | **RED — no verification recorded** |\n", "")
with patch.object(runner, "call", return_value=(bad, 0.0)):
    assert runner.fill_one(first, "fixture-api")[1] == "rejected"
assert runner.STATUS_ROW.findall(first.read_text())[0].startswith("**" + runner.FILLED_MARKER)
with patch("subprocess.run", side_effect=lambda *a, **k: (
    second.write_text(bad), subprocess.CompletedProcess([], 0)
)[1]):
    before = second.read_bytes()
    assert runner.fill_one_hermes(second, "fixture-hermes", "fixture-model")[1] == "rejected"
    assert second.read_bytes() == before

(root / "filled-first.md").write_bytes(first.read_bytes())
first.write_text(text)  # selection starts with exactly one unfinished module
print("  PASS  both fill writers stamp census/provider/UTC; missing status is rejected")
PY
then
  say "  PASS  local writer fixtures completed without provider calls"
else
  say "  FAIL  runner-owned status writer fixture"; fails=$((fails+1))
fi
out=$(CF_MASTER_DIR="$tmpd/master" python3 "$HERE/scripts/master_doc_fill.py" --dry-run 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^todo=1 ' \
  && [ "$(printf '%s\n' "$out" | grep -c '^candidate ')" = 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 01-first.md' \
  && printf '%s\n' "$out" | grep -Fxq 'skip 00-INDEX.md index' \
  && printf '%s\n' "$out" | grep -Fxq 'skip 03-not-a-module.md no path field'; then
  say "  PASS  RED module selected, index and missing-Path document skipped"
  printf '%s\n' "$out"
else
  say "  FAIL  RED/index/Path selection (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
cp "$tmpd/filled-first.md" "$tmpd/master/01-first.md"
# Negative control: the old body-string selector would select BOTH filled modules.
if [ "$(grep -l 'RED — no verification recorded' "$tmpd/master"/0[12]-*.md | wc -l)" -eq 2 ]; then
  say "  PASS  old selector would wrongly refill both completed modules"
else
  say "  FAIL  negative control no longer distinguishes the old selector"; fails=$((fails+1))
fi
before=$(sha256sum "$tmpd/master/"*.md)
for pass in 1 2; do
  out=$(CF_MASTER_DIR="$tmpd/master" python3 "$HERE/scripts/master_doc_fill.py" --dry-run 2>&1); rc=$?
  after=$(sha256sum "$tmpd/master/"*.md)
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^todo=0 ' \
    && ! printf '%s\n' "$out" | grep -q '^candidate ' && [ "$before" = "$after" ]; then
    say "  PASS  filled run $pass: todo=0 exit=0 sha256sum unchanged"
    printf '%s\n' "$out" | grep '^todo='
  else
    say "  FAIL  filled run $pass did not converge or changed fixture bytes (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out"
  fi
done
out=$(CF_MASTER_DIR="$tmpd/master" python3 "$HERE/scripts/master_doc_fill.py" --dry-run --force 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^todo=2 ' \
  && [ "$(printf '%s\n' "$out" | grep -c '^candidate ')" = 2 ] \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 01-first.md' \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 02-second.md'; then
  say "  PASS  --force selects both filled modules, never the non-modules"
else
  say "  FAIL  --force selection (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"
# END master-doc-selection

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

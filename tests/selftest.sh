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
if "$auth_python" - "$tmpd" <<'PY'
import os
from pathlib import Path
import sys

import yaml

root = Path(sys.argv[1])
(root / "bin").mkdir()
home = root / "home"
(home / ".hermes").mkdir(parents=True)
(home / "hermes-venv/bin").mkdir(parents=True)
# Random throwaway values stay in the private fixture, never in output or argv.
username, password = (os.urandom(16).hex() for _ in range(2))
auth = {"username": username, "password": password}
configs = {
    "commented": "# dashboard:\n#   basic_auth:\n#     username: ignored\n#     password: ignored\n",
    "empty-value": "dashboard:\n  basic_auth:\n",
    "real-value": yaml.safe_dump({"dashboard": {"basic_auth": auth}}),
    "block-absent": "dashboard: {}\n",
    "wrong-key": yaml.safe_dump({"other": {"basic_auth": auth}}),
    "empty-username": yaml.safe_dump({"dashboard": {"basic_auth": dict(auth, username=" ")}}),
    "empty-password": yaml.safe_dump({"dashboard": {"basic_auth": dict(auth, password="")}}),
    "invalid-yaml": "dashboard: [\n",
}
for name, text in configs.items():
    (root / name).write_text(text)
(root / "credentials").write_text(username + "\n" + password + "\n")
python = home / "hermes-venv/bin/python"
python.write_text('#!/usr/bin/env bash\nexec "${AUTH_PYTHON:?}" "$@"\n')
python.chmod(0o755)
stubs = {
    "python": '''#!/usr/bin/env bash
if [ "$1" = --version ]; then echo 'Python 3.12.3'; exit 0; fi
exec "${AUTH_PYTHON:?}" "$@"
''',
    "hermes": '''#!/usr/bin/env bash
if [ "$1" = --version ]; then echo 'hermes auth fixture'; exit 0; fi
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
PY
then
  auth_fixture_run() {
    cp "$tmpd/$1" "$tmpd/home/.hermes/config.yaml"
    rm -f "$tmpd/launch"
    env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" HERMES_PYTHON_BIN="$tmpd/bin/python" \
      HERMES_PIN=0.19.0 NODE_GATEWAY_PORT=10800 FAILED=0 AUTH_FIXTURE="$tmpd" \
      AUTH_PYTHON="$auth_python" AUTH_HTTP_CODE="${2:-200}" \
      /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply
  }
  for arm in commented empty-value real-value block-absent wrong-key empty-username empty-password invalid-yaml; do
    out=$(auth_fixture_run "$arm" 2>&1); rc=$?
    case "$arm" in
      commented) reason=commented ;;
      block-absent|wrong-key) reason='block absent' ;;
      invalid-yaml) reason='block absent (invalid YAML)' ;;
      *) reason='empty value (username and password must both be non-empty)' ;;
    esac
    if [ "$arm" = real-value ]; then
      expected='  PASS  gateway_start — /api/status -> 200'
      launch_expected='serve launch reached'
      expected_rc=1  # The initial port check sees no listener; gateway_start itself is green.
    else
      expected="  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — $reason"
      launch_expected=''
      expected_rc=1
    fi
    launch_observed=$(cat "$tmpd/launch" 2>/dev/null || true)
    if [ "$rc" -eq "$expected_rc" ] \
      && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ] \
      && [ "$launch_observed" = "$launch_expected" ] \
      && ! printf '%s\n' "$out" | grep -Fqf "$tmpd/credentials"; then
      say "  PASS  CF-071 $arm: exit $rc, launch=${launch_observed:-not reached}"
      printf '%s\n' "$expected"
    else
      say "  FAIL  CF-071 $arm: exit $rc, launch=${launch_observed:-not reached}, expected gateway_start row missing or credentials exposed"
      fails=$((fails+1))
    fi
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
  unset -f auth_fixture_run
else
  say "  FAIL  CF-071 public-bind-auth fixture setup (Python with PyYAML required)"; fails=$((fails+1))
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
for c in 401 302 403 404 000 500 200; do
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
  && [ "$(printf '%s\n' "$with_ref" | grep -c .)" -eq 5 ] \
  && ! printf '%s\n' "$with_ref" | grep -Fq 'unknown arg:'; then
  say "  PASS  --staged-files --ref master -> exit 0, same five-file staged set"
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

    for name in ("node-create.sh", "lib.sh", "project-node.sh", "disk_floor.py", "reclaim_disk.py"):
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

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

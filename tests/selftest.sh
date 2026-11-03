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

say "7. the board is valid JSONL"
b="$HERE/.coding-hermes/board/tasks.jsonl"
if [ -f "$b" ]; then
  # One parser process for the whole board. A python3 per row cost ~37 ms of wait4 per row
  # (PERF-012: 669 wait4 calls / 1.805 s on a 30-row board). The slice keeps the old
  # `while read` semantics exactly: only newline-terminated records count, so an unterminated
  # last line is skipped and an empty file is 0/0.
  read -r good n < <(python3 - "$b" <<'PY'
import json, sys
data = open(sys.argv[1], "rb").read()
rows = data.split(b"\n")[:-1]
good = 0
for row in rows:
    try:
        json.loads(row.decode("utf-8"))
        good += 1
    except Exception:
        pass
print(good, len(rows))
PY
)
  [ "$good" = "$n" ] && say "  PASS  $good/$n rows parse" || { say "  FAIL  $good of $n rows parse"; fails=$((fails+1)); }
else
  say "  FAIL  board missing"; fails=$((fails+1))
fi

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
case "$1" in
  spawn) printf '%s\n' "$2" > "$FIXTURE_AGENT" ;;
  cp) [ "${FIXTURE_CP_FAIL:-0}" = 0 ] || { echo 'fixture copy refused' >&2; exit 1; } ;;
  exec) case "$*" in *NODE_PROJECT=*) exit 1 ;; esac ;;
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
    FIXTURE_AGENT="$tmpd/agent" FIXTURE_CP_FAIL="$cp_fail" \
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
  env PATH="$tmpd/bin:$PATH" BUNKER_SERVER=fixture STATS_CODE="$1" STATUS_BODY="$2" \
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

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

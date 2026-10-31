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
printf '%s' "$out" | grep -q 'FAIL' && say "  PASS  report contains FAIL rows" || { say "  FAIL  no FAIL rows"; fails=$((fails+1)); }

say "3. unreachable Crier reports one HTTP status code"
tmpd=$(mktemp -d)
cat > "$tmpd/curl" <<'EOF'
#!/usr/bin/env bash
printf '000'
exit 7
EOF
chmod +x "$tmpd/curl"
out=$(env PATH="$tmpd:$PATH" HOME="$tmpd/home" NODE_PROJECT=demo CRIER_URL=http://closed.test:8767 \
  /bin/bash "$HERE/scripts/project-node.sh" --check --project demo 2>&1); rc=$?
expected='  FAIL  reach:http://closed.test:8767/health — -> 000'
if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
  say "  PASS  unreachable URL -> one 000 status"
else
  say "  FAIL  unreachable URL status was duplicated or missing"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# ch:trace row=CF-034 spec=README.md#status wave=none:serial test=tests/selftest.sh::clone-error-classification doc=README.md prompt=prompts/readme.md evidence=tests/selftest.sh::clone-error-classification witness=none:local-fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unresolved-namespace
say "4. clone errors distinguish missing refs from repository access"
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
  --repo "file://$tmpd/origin.git" 2>&1); rc=$?
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
  --repo https://private.fixture.invalid/repo.git 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$private_repo" | grep -Fq 'private repos need a deploy key'; then
  say "  PASS  repository access failure retains deploy-key hint"
else
  say "  FAIL  repository access failure lost deploy-key hint"; fails=$((fails+1))
fi
rm -rf "$tmpd"

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
  n=$(wc -l < "$b"); good=0
  while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && good=$((good+1)); done < "$b"
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

say "11. the README's first evidence artifact carries the claims it is cited for"
# The evidence line names the artifact a reader is meant to trust first; that artifact must
# exist and contain the tokens the current README's claims rest on: repo_clone (status row),
# 9402f6a (the measured clone sha), Prompt (prompt-file section) and eleven (prompts/ file
# count). CF-038/CF-039: the first-named artifact had zero case-sensitive counts for Prompt
# and eleven — evidence named first but not carried.
# ch:trace row=CF-039 spec=README.md#the-lanes wave=none:serial test=tests/selftest.sh::evidence-pointer doc=README.md prompt=prompts/qa.md evidence=docs/audits/code-factory-CF-039.md witness=none:local-fixture verdict=none:open-finding commit=none:self-referential-hash memory=none:unresolved-namespace
evidence_first() {  # $1=README -> first `path` after the evidence marker (empty if none)
  grep -m1 'Evidence for the state of this README' "$1" | grep -oE '`[^`]+`' | head -1 | tr -d '`'
}
evidence_deficiency() {  # $1=README $2=repo root -> prints why the first artifact is deficient; rc 1 when it carries every token
  local art tok miss="" root="$2"
  art=$(evidence_first "$1")
  [ -n "$art" ] || { echo "no evidence pointer"; return 0; }
  [ -f "$root/$art" ] || { echo "absent artifact: $art"; return 0; }
  for tok in repo_clone 9402f6a Prompt eleven; do
    grep -qF -- "$tok" "$root/$art" || miss="$miss $tok"
  done
  [ -n "$miss" ] && { echo "$art lacks:$miss"; return 0; }
  return 1
}
if deficiency=$(evidence_deficiency "$HERE/README.md" "$HERE"); then
  say "  FAIL  first README evidence artifact cannot support the README: $deficiency"
  fails=$((fails+1))
else
  say "  PASS  $(evidence_first "$HERE/README.md") exists and carries every claim token"
fi
# negative fixture: the same README against a copy of the artifact with the claim tokens stripped
tmpd=$(mktemp -d)
art=$(evidence_first "$HERE/README.md")
if [ -n "$art" ] && [ -f "$HERE/$art" ]; then
  mkdir -p "$tmpd/$(dirname "$art")"
  grep -vE 'repo_clone|9402f6a|Prompt|eleven' "$HERE/$art" > "$tmpd/$art"
  if deficiency=$(evidence_deficiency "$HERE/README.md" "$tmpd"); then
    say "  PASS  token-stripped artifact refused ($deficiency)"
  else
    say "  FAIL  a first evidence artifact lacking claim tokens was accepted"; fails=$((fails+1))
  fi
else
  say "  FAIL  negative fixture skipped: no readable artifact"; fails=$((fails+1))
fi
rm -rf "$tmpd"

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

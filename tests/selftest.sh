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
# CF-280 red-proof: revert fetch_verified to the pre-fix body (an unchecked `mkdir -p`/`mv` followed
# by `chmod ... || true`) and BOTH arms below go RED — the positive arm sees exit 0 (the chmod's
# status) and the caller arm prints no `go:download` FAIL row. They are regression arms, not
# decoration. The destination's parent is a regular FILE, so `mkdir -p` fails with ENOTDIR for root
# and non-root alike (0555 permissions are not used here: root ignores them).
: > "$tmpd/blocker"
fetch_rc=0
fetch_verified "file://$tmpd/src" "$tmpd/blocker/bin" "$want" >/dev/null 2>&1 || fetch_rc=$?
if [ "$fetch_rc" -ne 0 ] && [ ! -e "$tmpd/blocker/bin" ]; then
  say "  PASS  uncreatable destination -> fetch_verified exit $fetch_rc, no artifact installed"
else
  say "  FAIL  uncreatable destination was reported as a verified install (exit $fetch_rc)"; fails=$((fails+1))
fi
# The caller arm proves the failure is SURFACED, not silent: it mirrors the install-go.sh branch
# (`fetch_verified ... || bad "go:download" ...`) and asserts the ROW, not the substring FAIL — a
# shell death also prints FAIL and would fake a pass. `bad` returns the status of its own printf, so
# the fixture states `exit 1` rather than inheriting that 0.
cat > "$tmpd/caller.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
. "$1"
fetch_verified "$2" "$3" "$4" || { bad "go:download" "verified download did not install to $3"; exit 1; }
EOF
caller_out=$(bash "$tmpd/caller.sh" "$HERE/scripts/lib.sh" "file://$tmpd/src" "$tmpd/blocker/bin" "$want" 2>&1)
caller_rc=$?
caller_rows=$(printf '%s\n' "$caller_out" | grep -Ec '^  FAIL  go:download' || true)
if [ "$caller_rc" -ne 0 ] && [ "$caller_rows" = 1 ]; then
  say "  PASS  caller surfaced the failed install: 1 '^  FAIL  go:download' row, fixture exit $caller_rc"
else
  say "  FAIL  caller did not surface the failed install (exit $caller_rc, $caller_rows go:download row(s))"; fails=$((fails+1))
fi

# BEGIN cf281-have-absence
# CF-281: have() could not report absence. Its body ended in `|| true`, so the exit status was
# `true`'s whether the tool existed or not: `b=$(have bunker) || { … }` could never fire, a bare
# `have timeout && tmo=timeout` was always true, and the empty substitution reached `"$b" spawn`
# as `: command not found` reported under someone else's row.
# The contract this arm owns: present -> exit 0 and the resolved path on stdout; absent -> non-zero
# and NOTHING on stdout (a message there would be executed as a path by `"$b" cp …`).
# Every library is sourced inside its own subshell, so the pre-fix copy below cannot redefine
# `have` for the rest of this suite.
have_absence_arm() {  # $1 = lib.sh path -> 0 when THAT library reports absence correctly
  local lib="$1" aout arc pout prc
  aout=$(. "$lib"; have cf281-no-such-tool-xyzzy); arc=$?
  pout=$(. "$lib"; have bash); prc=$?
  printf 'have() reports absence — absent: rc=%s stdout=%sB; present(bash): rc=%s stdout=%s\n' \
    "$arc" "${#aout}" "$prc" "${pout:-<empty>}"
  [ "$arc" -ne 0 ] && [ -z "$aout" ] && [ "$prc" -eq 0 ] && [ -n "$pout" ]
}
if have_out=$(have_absence_arm "$HERE/scripts/lib.sh"); then
  say "  PASS  $have_out"
else
  say "  FAIL  $have_out"; fails=$((fails+1))
fi
# The repaired caller, end to end: node-create.sh with the client off PATH prints ONE named FAIL row
# and no shell diagnostic. The fixture PATH is asserted to resolve no client — a host that had one
# in /usr/bin would make this arm vacuous.
nc_path="/usr/bin:/bin"
if PATH="$nc_path" command -v bunker >/dev/null 2>&1; then
  say "  FAIL  have() reports absence — caller: fixture PATH $nc_path still resolves bunker; the arm would prove nothing"; fails=$((fails+1))
else
  nc_out=$(env -i PATH="$nc_path" HOME="$tmpd/nc-home" CRIER_URL=http://crier.example:8767 BUNKER_SERVER=srv.example \
    /bin/bash "$HERE/scripts/node-create.sh" --project demo --repo git@git.example:demo/repo.git --harness hermes 2>&1); nc_rc=$?
  nc_rows=$(printf '%s\n' "$nc_out" | grep -Ec '^  FAIL  bunker_cli — ' || true)
  if [ "$nc_rc" -eq 1 ] && [ "${nc_rows:-0}" = 1 ] \
    && ! printf '%s\n' "$nc_out" | grep -Fq 'command not found' \
    && ! printf '%s\n' "$nc_out" | grep -Fq '  FAIL  spawn'; then
    say "  PASS  have() reports absence — caller: node-create.sh with the client off PATH -> 1 'FAIL bunker_cli' row, exit $nc_rc, no shell diagnostic"
  else
    say "  FAIL  have() reports absence — caller: node-create.sh with the client off PATH -> $nc_rows bunker_cli row(s), exit $nc_rc"; fails=$((fails+1))
    printf '%s\n' "$nc_out" | sed 's/^/    | /'
  fi
fi
# Red control: the SAME script against the pre-fix library must reproduce the misattribution, or this
# arm cannot discriminate. Taken from the base commit, so a revert of have() turns both arms red.
if git -C "$HERE" show 06adfa6:scripts/lib.sh > "$tmpd/pre-fix-lib.sh" 2>/dev/null; then
  pre_out=$(have_absence_arm "$tmpd/pre-fix-lib.sh"); pre_rc=$?
  if [ "$pre_rc" -ne 0 ] && printf '%s\n' "$pre_out" | grep -Fq 'absent: rc=0 stdout=0B'; then
    say "  PASS  have() reports absence — pre-fix control: 06adfa6:scripts/lib.sh answers rc=0 for an absent tool; the arm is falsifiable"
  else
    say "  FAIL  have() reports absence — pre-fix control did not reproduce the defect (exit $pre_rc): $pre_out"; fails=$((fails+1))
  fi
  cp -a "$HERE/scripts" "$tmpd/pre-fix-scripts"
  cp "$tmpd/pre-fix-lib.sh" "$tmpd/pre-fix-scripts/lib.sh"
  cf_out=$(env -i PATH="$nc_path" HOME="$tmpd/nc-home" CRIER_URL=http://crier.example:8767 BUNKER_SERVER=srv.example \
    /bin/bash "$tmpd/pre-fix-scripts/node-create.sh" --project demo --repo git@git.example:demo/repo.git --harness hermes 2>&1); cf_rc=$?
  if [ "$cf_rc" -eq 1 ] && printf '%s\n' "$cf_out" | grep -Fq '  FAIL  spawn' \
    && printf '%s\n' "$cf_out" | grep -Fq 'command not found' \
    && ! printf '%s\n' "$cf_out" | grep -Fq '  FAIL  bunker_cli'; then
    say "  PASS  have() reports absence — caller control: the pre-fix library reports the absent client as 'FAIL spawn — …: command not found', exit $cf_rc"
  else
    say "  FAIL  have() reports absence — caller control did not reproduce the pre-fix misreport (exit $cf_rc)"; fails=$((fails+1))
    printf '%s\n' "$cf_out" | sed 's/^/    | /'
  fi
else
  say "  FAIL  have() reports absence — pre-fix source unavailable (git show 06adfa6:scripts/lib.sh)"; fails=$((fails+1))
fi
# END cf281-have-absence
rm -rf "$tmpd"

say "6. no literal credential assignments"
if grep -rnE '^[A-Z_]*(API_KEY|TOKEN|SECRET)=[^$"[:space:]]' "$HERE"/scripts "$HERE"/specs "$HERE"/docs 2>/dev/null | grep -v 'example' | head -3 | grep -q .; then
  say "  FAIL  a literal credential assignment is in the tree"; fails=$((fails+1))
else
  say "  PASS  none found"
fi

# BEGIN tailnet-address-gate
# CF-378: this repository is PUBLIC, so a CGNAT/tailnet literal in a tracked file hands anyone who
# clones it a map of the fleet's control-plane topology. The gate grades every tracked file except
# two surfaces that are not this row's to rewrite:
#   .coding-hermes/board — append-only, foreman-owned;
#   .gitreins           — CF-050 owns stopping the publication of .gitreins/history/*/commit.patch
#                         and worktree.patch; those bundles republish whole patches, so they
#                         re-carry every literal any commit ever held (17 at HEAD b2d187f).
# It sits inside section 6 (the repo-wide literal scan, above) instead of a new numbered section,
# so arms_tree stays 55 and docs/ACCEPTANCE-PLAN.md needs no mapping row — the CF-374 precedent.
tailnet_re='100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]+\.[0-9]+'
# $1 = repository root -> one <path>:<line>:<content> line per hit, board and .gitreins excluded.
tailnet_scan() {
  local root="$1" f
  while IFS= read -r -d '' f; do
    # -H is load-bearing: the loop grades one file per grep, and grep drops the filename prefix
    # when a single file is named — the FAIL row would then name a line number, not the file.
    grep -nHIE -e "$tailnet_re" -- "$root/$f" 2>/dev/null | sed -e "s|^$root/||"
  done < <(git -C "$root" ls-files -z -- . ':(exclude).coding-hermes/board' ':(exclude).gitreins')
  return 0
}
# $1 = root, $2 = label. One PASS row, or one FAIL row naming path:line. It never quotes the
# address itself: a gate that prints what it forbids republishes the class in every log it reds.
# A run that graded nothing is a FAIL, not a green (a gate whose empty case passes is decoration).
tailnet_verdict() {
  local root="$1" label="$2" hits files graded n
  graded=$(git -C "$root" ls-files -- . ':(exclude).coding-hermes/board' ':(exclude).gitreins' 2>/dev/null | grep -c . || true)
  hits=$(tailnet_scan "$root")
  if [ -z "$hits" ] && [ "${graded:-0}" -gt 0 ]; then
    say "  PASS  $label — 0 tailnet-address hits in $graded tracked file(s) outside .coding-hermes/board and .gitreins"
    return 0
  fi
  if [ -z "$hits" ]; then
    say "  FAIL  $label — 0 tracked file(s) graded at $root; the gate proved nothing"
    return 1
  fi
  n=$(printf '%s\n' "$hits" | cut -d: -f1 | sort -u | grep -c . || true)
  files=$(printf '%s\n' "$hits" | cut -d: -f1,2 | sort -u | tr '\n' ' ')
  say "  FAIL  $label — $n tracked file(s) publish a tailnet address at ${files% }; replace the literal with a <host> placeholder whose real value lives in the operator's own config"
  return 1
}
say "  section 6 tailnet-address (CF-378): no tracked file outside the board publishes a tailnet address"
tailnet_verdict "$HERE" 'tailnet-address' && : || fails=$((fails+1))
# Red proof: a seeded repository, so the gate grades the fixture the way it grades the tree (a
# fixture directory that is not a git index would grade 0 files and prove nothing). The literal is
# assembled from octet variables because this file is itself graded — writing the address here would
# put the class straight back. The second line is a subnet OUTSIDE the CGNAT range, so the arm shows
# the boundary and not just a hit.
tmpd=$(mktemp -d)
git init -q -b trunk "$tmpd/seed"
mkdir -p "$tmpd/seed/docs"
o1=100 o2=97 o3=236 o4=14 o5=63
printf '%s\n' '# seeded fixture — not part of the tree' '' \
  "crier bus: http://$o1.$o2.$o3.$o4:8767/inbox" \
  "near miss: http://$o1.$o5.7.7:8767 — outside the CGNAT range, must stay green" \
  > "$tmpd/seed/docs/seeded.md"
git -C "$tmpd/seed" add docs/seeded.md
out=$(tailnet_verdict "$tmpd/seed" 'tailnet-address' 2>&1); rc=$?
expected="  FAIL  tailnet-address — 1 tracked file(s) publish a tailnet address at docs/seeded.md:3; replace the literal with a <host> placeholder whose real value lives in the operator's own config"
if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
  say "  PASS  seeded fixture -> FAIL names docs/seeded.md:3; the out-of-range subnet stays green"
else
  say "  FAIL  seeded tailnet literal escaped the gate (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -rf "$tmpd"
# END tailnet-address-gate

# BEGIN github-app-refresh-gate
# CF-320: this script used to print a FAIL mode row and then rewrite the git credential store
# with that insecure token anyway, exit 0, and call the run "refreshed" on the strength of a
# substring in the minter's stdout. The arms below run the REAL script against a stub minter,
# each in its own mktemp -d: the script sources lib.sh from its own directory and execs
# $HERE/github-app-token.py, so the stub replaces the copied minter beside it. No network, no
# bunker, no real credential. Every arm asserts NAMED rows — a bootstrap crash that prints
# "unbound variable", or a bare FAIL, satisfies none of them.
gar_fixture() {  # gar_fixture <dir> — repo scripts tree plus a stub minter at <dir>/scripts
  mkdir -p "$1/scripts"
  cp -R "$HERE/scripts/." "$1/scripts/"
  cat > "$1/scripts/github-app-token.py" <<'PY'
import os, sys
mode = os.environ.get("CF_STUB_MODE", "mint")
if mode == "skip":
    print("  SKIP  token — fixture token is young, still valid")
    print("GITHUB APP TOKEN: SKIP — nothing to do")
    sys.exit(0)
dest = sys.argv[sys.argv.index("--out") + 1]
with open(dest, "w", encoding="utf-8") as fh:
    fh.write(os.environ.get("CF_STUB_TOKEN", "fixture-token") + "\n")
os.chmod(dest, 0o644 if mode == "bad-mode" else 0o600)
print("  PASS  token — written at mode %s (fixture minter)" % oct(os.stat(dest).st_mode & 0o777)[2:])
print("GITHUB APP TOKEN: PASS — minted a 3600s fixture token")
PY
  printf 'GITHUB_APP_ID=1\nGITHUB_APP_INSTALLATION_ID=1\n' > "$1/github-app.env"
  printf 'https://x-access-token:fixture-old\n' > "$1/git-credentials"
  chmod 600 "$1/git-credentials"
}
# (a) An insecure mint must be a verdict, not a remark: non-zero exit, one named `FAIL mode` row,
# no `PASS refresh` row, and the credential store left byte-identical.
gar=$(mktemp -d)
gar_fixture "$gar"
cp -p "$gar/git-credentials" "$gar/git-credentials.pre"
gar_out=$(env HOME="$gar" CF_STUB_MODE=bad-mode CF_STUB_TOKEN=insecure-fixture-token \
  bash "$gar/scripts/github-app-refresh.sh" --env-file "$gar/github-app.env" \
  --token-file "$gar/github.token" --git-credentials "$gar/git-credentials" 2>&1); gar_rc=$?
gar_mode_rows=$(printf '%s\n' "$gar_out" | grep -Ec '^  FAIL  mode' || true)
gar_refresh_rows=$(printf '%s\n' "$gar_out" | grep -Ec '^  PASS  refresh' || true)
if [ "$gar_rc" -ne 0 ] && [ "$gar_mode_rows" = 1 ] && [ "$gar_refresh_rows" = 0 ] \
  && cmp -s "$gar/git-credentials.pre" "$gar/git-credentials"; then
  say "  PASS  insecure mint (mode 644) -> exit $gar_rc, one '^  FAIL  mode' row, no '^  PASS  refresh' row, credential store byte-identical"
else
  say "  FAIL  insecure mint still rewrote the credential store (exit $gar_rc, $gar_mode_rows mode row(s), $gar_refresh_rows refresh row(s))"; fails=$((fails+1))
fi
rm -rf "$gar"
# (b) The clock-behind case: a token two hours old must be re-minted, and the re-mint must be
# read off the FILE — mtime advanced and content digest changed — not off the minter's sentence.
gar=$(mktemp -d)
gar_fixture "$gar"
printf 'stale-fixture-token\n' > "$gar/github.token"
chmod 600 "$gar/github.token"
touch -d '2 hours ago' "$gar/github.token"
gar_pre_mtime=$(stat -c %Y "$gar/github.token")
gar_pre_digest=$(sha256sum "$gar/github.token" | cut -d' ' -f1)
gar_out=$(env HOME="$gar" CF_STUB_MODE=mint CF_STUB_TOKEN=fresh-fixture-token \
  bash "$gar/scripts/github-app-refresh.sh" --env-file "$gar/github-app.env" \
  --token-file "$gar/github.token" --git-credentials "$gar/git-credentials" 2>&1); gar_rc=$?
gar_post_mtime=$(stat -c %Y "$gar/github.token")
gar_post_digest=$(sha256sum "$gar/github.token" | cut -d' ' -f1)
gar_refresh_rows=$(printf '%s\n' "$gar_out" | grep -Ec '^  PASS  refresh' || true)
if [ "$gar_rc" -eq 0 ] && [ "$gar_post_mtime" -gt "$gar_pre_mtime" ] \
  && [ "$gar_post_digest" != "$gar_pre_digest" ] && [ "$gar_refresh_rows" = 1 ]; then
  say "  PASS  token mtime 2h old -> re-minted: mtime $gar_pre_mtime -> $gar_post_mtime, digest changed, one '^  PASS  refresh' row"
else
  say "  FAIL  a 2h-old token was not re-minted from a re-read (exit $gar_rc, mtime $gar_pre_mtime -> $gar_post_mtime, digest changed: $([ "$gar_post_digest" != "$gar_pre_digest" ] && echo yes || echo no))"; fails=$((fails+1))
fi
rm -rf "$gar"
# (c) A fresh token whose minter reports a skip is a no-op: exit 0, neither file rewritten, and
# the row says so. The file is re-read here too, so "no-op" is a measurement, not a quote.
gar=$(mktemp -d)
gar_fixture "$gar"
printf 'still-valid-fixture-token\n' > "$gar/github.token"
chmod 600 "$gar/github.token"
cp -p "$gar/github.token" "$gar/github.token.pre"
cp -p "$gar/git-credentials" "$gar/git-credentials.pre"
gar_out=$(env HOME="$gar" CF_STUB_MODE=skip \
  bash "$gar/scripts/github-app-refresh.sh" --env-file "$gar/github-app.env" \
  --token-file "$gar/github.token" --git-credentials "$gar/git-credentials" 2>&1); gar_rc=$?
gar_says_noop=no
printf '%s\n' "$gar_out" | grep -Fq 'no-op' && gar_says_noop=yes
if [ "$gar_rc" -eq 0 ] && cmp -s "$gar/github.token.pre" "$gar/github.token" \
  && cmp -s "$gar/git-credentials.pre" "$gar/git-credentials" && [ "$gar_says_noop" = yes ]; then
  say "  PASS  fresh token + minter skip -> exit 0, token and credential store byte-identical, the row says 'no-op'"
else
  say "  FAIL  a fresh token was not reported as a no-op (exit $gar_rc, no-op row: $gar_says_noop)"; fails=$((fails+1))
fi
rm -rf "$gar"
# END github-app-refresh-gate

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
  # Empty is 0/0; a non-empty board must not hide an unterminated final row.
  python3 - "$b" <<'PY'
import json, sys
try:
    data = open(sys.argv[1], "rb").read()
except OSError as exc:
    print(f"  FAIL  board unreadable: {exc}")
    sys.exit(1)
unterminated = bool(data) and not data.endswith(b"\n")
rows = data.split(b"\n")
if rows and rows[-1] == b"":
    rows.pop()
if unterminated:
    legacy_rows = data.split(b"\n")[:-1]
    print(f"  FAIL  board: 1 unterminated row (line {len(rows)})")
    print(f"  note  pre-fix parser control would accept {len(legacy_rows)} of {len(rows)} rows")
    sys.exit(1)
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
# board-arm-unterminated-tail: the same valid records must pass intact and fail without
# the last newline. The empty board intentionally remains PASS 0/0.
printf '%s\n' '{"id":"CF-001","status":"pending"}' '{"id":"CF-002","status":"complete"}' > "$tmpd/intact.jsonl"
printf '%s\n%s' '{"id":"CF-001","status":"pending"}' '{"id":"CF-002","status":"complete"}' > "$tmpd/tail.jsonl"
touch "$tmpd/empty.jsonl"
for arm in intact tail empty; do
  out=$(board_arm "$tmpd/$arm.jsonl" 2>&1); rc=$?
  case "$arm:$rc" in
    intact:0)
      if [ "$out" = '  PASS  2/2 rows parse' ]; then
        say "  PASS  board-arm-unterminated-tail intact: $out"
      else
        say "  FAIL  board-arm-unterminated-tail intact: $out"; fails=$((fails+1))
      fi ;;
    tail:1)
      if printf '%s\n' "$out" | grep -Fxq '  FAIL  board: 1 unterminated row (line 2)' \
        && printf '%s\n' "$out" | grep -Fxq '  note  pre-fix parser control would accept 1 of 2 rows'; then
        say "  PASS  board-arm-unterminated-tail tail: $out"
      else
        say "  FAIL  board-arm-unterminated-tail tail (exit $rc): $out"; fails=$((fails+1))
      fi ;;
    empty:0)
      if [ "$out" = '  PASS  0/0 rows parse' ]; then
        say "  PASS  board-arm-unterminated-tail empty: $out"
      else
        say "  FAIL  board-arm-unterminated-tail empty: $out"; fails=$((fails+1))
      fi ;;
    *) say "  FAIL  board-arm-unterminated-tail $arm (exit $rc): $out"; fails=$((fails+1)) ;;
  esac
done
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
    # The §5 contract library (CF-229): without it the mutated copy dies on its own include and
    # every "rejected mutation" arm below would pass for the wrong reason.
    (scripts / "harness/harness-vars.sh").write_text(
        (repo / "scripts/harness/harness-vars.sh").read_text())
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
# CF-082: a decimal floor is preserved, never truncated down (5.9G used to resolve to
# 5, so admission enforced a lower number than the operator wrote). Two layers are
# graded here — the resolver's JSON and bare print, then the admission ROW from the
# real lib.sh require_disk against a df shim reporting exactly 5.5 GB free. The pre-fix
# resolver is re-run from git, so these arms are falsifiable in the suite itself and not
# only in the unit file. Part of section 12: no new numbered section and no census change
# (arms_tree stays 58), the CF-230 precedent.
cf082=$(mktemp -d)
mkdir -p "$cf082/bin"
cat > "$cf082/bin/df" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' 'fixture 20971520 15204352 5767168 74% /'
EOF
chmod +x "$cf082/bin/df"
cf082_explain() { python3 "$HERE/scripts/disk_floor.py" resolve --cli "$1" --explain; }
cf082_bare() { python3 "$HERE/scripts/disk_floor.py" resolve --cli "$1"; }
cf082_bad=""
for pair in '5.9G:5.9' '5.5G:5.5' '5.1G:5.1' '5G:5' '5:5' '1.5G:1.5'; do
  value=${pair%%:*}
  want=${pair##*:}
  want_json="{\"role\": \"worker\", \"floor_gib\": $want, \"source\": \"cli\"}"
  if [ "$(cf082_explain "$value")" != "$want_json" ] || [ "$(cf082_bare "$value")" != "$want" ]; then
    cf082_bad="$cf082_bad ${value}->$(cf082_bare "$value" 2>&1)"
  fi
done
if [ -z "$cf082_bad" ]; then
  say "  PASS  CF-082 decimals preserved: 5.9G -> 5.9, 5.5G -> 5.5, 5.1G -> 5.1, 1.5G -> 1.5; integral 5G -> 5 in JSON and bare print"
else
  say "  FAIL  CF-082 a decimal floor did not survive resolution:$cf082_bad"; fails=$((fails+1))
fi
# One admission arm per pole: 5.1 PASSes and 5.9 FAILs, both against a host whose only
# free space is 5.5 GB. The literal rows are asserted, not a substring: the printed floor
# is the operator's own number, which is what used to hide the truncation.
cf082_pass=$( (PATH="$cf082/bin:$PATH"; require_disk "$HOME" "$(cf082_bare 5.1G)") 2>&1 ); cf082_pass_rc=$?
cf082_fail=$( (PATH="$cf082/bin:$PATH"; require_disk "$HOME" "$(cf082_bare 5.9G)") 2>&1 ); cf082_fail_rc=$?
cf082_pass_want='  PASS  disk — 5.5 GB free (floor 5.1 GB)'
cf082_fail_want="  FAIL  disk — 5.5 GB free < floor 5.9 GB at $HOME"
if [ "$cf082_pass_rc" -eq 0 ] && [ "$cf082_pass" = "$cf082_pass_want" ] \
  && [ "$cf082_fail_rc" -eq 1 ] && [ "$cf082_fail" = "$cf082_fail_want" ]; then
  say "  PASS  CF-082 admission on 5.5 GB free: floor 5.1 GB admitted, floor 5.9 GB refused, both rows name the written floor"
  printf '%s\n' "$cf082_pass" "$cf082_fail"
else
  say "  FAIL  CF-082 admission did not split 5.1G from 5.9G (pass rc $cf082_pass_rc: $cf082_pass / fail rc $cf082_fail_rc: $cf082_fail)"; fails=$((fails+1))
fi
# The control: the resolver as shipped at deafbc3 truncates the same value. Without this
# row a green here could be a resolver that never had the defect, or an arm that never ran.
if git -C "$HERE" show deafbc3:scripts/disk_floor.py > "$cf082/pre-fix.py" 2>/dev/null; then
  pre_out=$(python3 "$cf082/pre-fix.py" resolve --cli 5.9G --explain 2>&1); pre_rc=$?
  pre_want='{"role": "worker", "floor_gib": 5, "source": "cli"}'
  if [ "$pre_rc" -eq 0 ] && [ "$pre_out" = "$pre_want" ]; then
    say "  PASS  CF-082 pre-fix control: the deafbc3 resolver truncates 5.9G to $pre_want"
  else
    say "  FAIL  CF-082 pre-fix control did not reproduce the truncation (exit $pre_rc): $pre_out"; fails=$((fails+1))
  fi
else
  say "  FAIL  CF-082 pre-fix control: deafbc3:scripts/disk_floor.py is unavailable"; fails=$((fails+1))
fi
rm -rf "$cf082"
# CF-357: a lane may not be cloned onto itself. `--from X --to X` used to rewrite the source
# row as the destination and disable a LIVE lane. The arm proves the refusal lands before any
# database is opened: exit 2, stderr naming --to/--from and the lane, the source row unchanged,
# and a genuine clone still succeeding so the guard is not a blanket break. Part of section 12:
# no new numbered section and no census change (arms_tree stays 55), like the CF-230 block below.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_clone_lane.py" >/dev/null 2>&1; then
  say "  PASS  CF-357 clone_lane same-lane clone refused before the DB open, source row intact, genuine clone still lands"
else
  say "  FAIL  CF-357 clone_lane same-lane refusal contract"; fails=$((fails+1))
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
  say "  PASS  AC2 no double counting: $fail_rows printed FAIL rows -> NODE: FAIL ($summary)"
else
  say "  FAIL  AC2 summary said $summary but the run printed $fail_rows FAIL rows"; fails=$((fails+1))
fi
# A silent nonzero adapter must create one parent-side FAIL row and no manifest. This is the
# CF-066 control for an adapter crash, missing binary or set -e abort without its own row.
cat > "$tmpd/scripts/harness/install-fixture.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmpd/scripts/harness/install-fixture.sh"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=fixture \
  NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
  /bin/bash "$tmpd/scripts/project-node.sh" --check --layers 20 2>&1); rc=$?
silent_summary=$(printf '%s\n' "$out" | grep -oE '^NODE: FAIL \([0-9]+\)$' | grep -oE '[0-9]+')
silent_manifest=0
[ -e "$tmpd/home/.node/node.json" ] && silent_manifest=1
if [ "$rc" -ne 0 ] && [ "$silent_summary" = 1 ] && [ "$silent_manifest" -eq 0 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  harness:fixture — installer exited 1'; then
  say "  PASS  AC1 silent adapter fails closed: parent row names exit 1, NODE: FAIL (1), no manifest"
else
  say "  FAIL  AC1 silent adapter did not fail closed (rc $rc, summary $silent_summary, manifest $silent_manifest)"; fails=$((fails+1))
fi
# the same fixture goes green: a passing adapter must keep NODE: PASS and exit 0
cat > "$tmpd/scripts/harness/install-fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
say "harness: fixture (cf-066)"
exit 0
EOF
chmod +x "$tmpd/scripts/harness/install-fixture.sh"
out=$(env PATH="$tmpd/bin:$PATH" HOME="$tmpd/home" NODE_PROJECT=fixture \
  NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
  /bin/bash "$tmpd/scripts/project-node.sh" --check --layers 20 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL')" = 0 ] \
  && printf '%s\n' "$out" | grep -Fq 'NODE: PASS'; then
  say "  PASS  AC3 passing adapter with no FAIL rows keeps NODE: PASS and exit 0"
else
  say "  FAIL  AC3 passing adapter produced FAIL rows or a nonzero exit"; fails=$((fails+1))
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
  # CF-051: a supplied --agent is proved to exist before any success row; this fixture's
  # agent exists, so the reuse path still runs as it did.
  info) exit 0 ;;
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
# CF-087: the staged-set validator reads every spelling of a HERE reference in every staged
# member, and the set it prints is the closure it derived — not a second list nobody checks.
# tests/node-create-staged-set.sh mutates its own temporary copy of scripts/ (never this tree)
# and prints one row per arm, each naming the staged_set row it measured; those rows are the
# rows below, so one arm cannot go green by asserting nothing.
for staged_arm in spellings members derive; do
  staged_out=$(bash "$HERE/tests/node-create-staged-set.sh" "$staged_arm" 2>&1); staged_rc=$?
  staged_rows=0
  while IFS= read -r staged_row; do
    [ -n "$staged_row" ] || continue
    case "$staged_row" in
      "  PASS  "*staged_set*)
        say "$staged_row"
        staged_rows=$((staged_rows+1)) ;;
      *)
        say "  FAIL  staged_set:$staged_arm — probe row did not name its staged_set evidence: $staged_row"
        fails=$((fails+1)) ;;
    esac
  done <<< "$staged_out"
  if [ "$staged_rc" -ne 0 ] || [ "$staged_rows" -eq 0 ]; then
    say "  FAIL  staged_set:$staged_arm — probe exited $staged_rc with $staged_rows asserted rows"
    fails=$((fails+1))
  fi
done
rm -rf "$tmpd"

# CF-077: stub transport only; exercise the real verifier and node-create admission.
say "17. auth verification fails closed, with a pre-fix detector control"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/bin" "$tmpd/before"
cp "$HERE/scripts/lib.sh" "$tmpd/before/"
# CF-291: step 6 folds the node's seed record into the verdict, so this fixture carries a
# measurable seed — a node home with a real record and its files. Without it the seed leg is a
# WARN, which now means UNVERIFIED, and these arms would measure the fixture instead of the auth
# legs they name. The seed probe is the ONE bunker exec below whose command runs for real.
mkdir -p "$tmpd/home/.hermes" "$tmpd/seed-src/prompts"
printf 'prompts/foreman.md\n' > "$tmpd/seed.manifest"
printf 'the foreman procedure\n' > "$tmpd/seed-src/prompts/foreman.md"
python3 -B "$HERE/scripts/node_seed.py" build --manifest "$tmpd/seed.manifest" \
  --repo-root "$tmpd/seed-src" --out "$tmpd/seed.tar" >/dev/null 2>&1
python3 -B "$HERE/scripts/node_seed.py" apply --tar "$tmpd/seed.tar" \
  --record "$tmpd/seed.tar.json" --home "$tmpd/home" >/dev/null 2>&1
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
# CF-224: the node reports a ROUTABLE address (TEST-NET-1, never actually routed — the stub curl
# answers for it). A loopback address is refused by the verifier now, so a fixture that echoed
# 127.0.0.1 would measure that refusal instead of the auth legs these arms name.
for a in "$@"; do
  case "$a" in *seed-applied.json*) exec bash -c "${!#}" ;; esac
  case "$a" in *hostname\ -I*) echo 192.0.2.10; exit 0 ;; esac
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
    HOME="$tmpd/home" STATS_CODE="$1" STATUS_BODY="$2" \
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
# CF-097: `repo-url` and `verify` probe the same kind of root, so a path whose git
# top level IS $HOME must be refused by repo-url with the reason verify already gives
# (`not_home_repo`, exit 4) instead of being reported as a valid root. HOME is set to
# the fixture, so this measures the same directory both arms resolve and never the
# host's real home.
home_root="$tmpd/home"
mkdir -p "$home_root"
git init -q -b main "$home_root"
git -C "$home_root" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
home_real=$(cd "$home_root" && pwd -P)
home_head=$(git -C "$home_real" rev-parse HEAD)
home_verify=$(env HOME="$home_real" python3 -B "$HERE/scripts/lane_target.py" verify "$home_real" 2>&1); home_verify_rc=$?
home_refused=$(env HOME="$home_real" python3 -B "$HERE/scripts/lane_target.py" repo-url "$home_real" 2>&1); home_refused_rc=$?
if [ "$home_verify_rc" -eq 4 ] && [ "$home_refused_rc" -eq 4 ] \
  && printf '%s\n' "$home_verify" | grep -A1 -F '"check": "not_home_repo"' | grep -Fq '"ok": false' \
  && printf '%s\n' "$home_refused" | grep -Fxq "FAIL repo_url '$home_real' — not_home_repo: git top level is the home directory '$home_real'" \
  && printf '%s\n' "$home_refused" | grep -Fxq 'repo_url: 1 rejected, 0 accepted'; then
  say "  PASS  repo-url refuses the home-rooted repo verify refuses (exit 4, not_home_repo)"
else
  say "  FAIL  repo-url accepted a home-rooted repo — missing not_home_repo check (verify exit $home_verify_rc, repo-url exit $home_refused_rc)"
  fails=$((fails+1))
fi
# ARM (red control): the same fixture against the revision this row was raised on
# (a32f234), which carries no home check on the repo-url arm. It must report the home
# root as an accepted root — pointed at the fixed script the control fails, so the arm
# above discriminates rather than merely passing.
if git -C "$HERE" show a32f234:scripts/lane_target.py > "$tmpd/lane_target_prefix.py" 2>/dev/null; then
  prefix_out=$(env HOME="$home_real" python3 -B "$tmpd/lane_target_prefix.py" repo-url "$home_real" 2>&1); prefix_rc=$?
  if [ "$prefix_rc" -eq 0 ] \
    && printf '%s\n' "$prefix_out" | grep -Fxq "PASS repo_url '$home_real' — root '$home_real' HEAD $home_head" \
    && ! printf '%s\n' "$prefix_out" | grep -q 'not_home_repo'; then
    say "  PASS  pre-fix a32f234 accepts the home-rooted repo — the repo-url arm is falsifiable"
  else
    say "  FAIL  the pre-fix control did not reproduce the missing not_home_repo check (exit $prefix_rc)"
    fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source unavailable (git show a32f234:scripts/lane_target.py)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# CF-007 AC3: reclaim-before-refusal, using the shipped scripts in a local HOME.
say "20. reclaim runs before disk refusal, while check never reaps"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts" "$tmpd/bin" "$tmpd/home/.cache/pip"
cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" \
  "$HERE/scripts/reclaim_disk.py" "$tmpd/scripts/"
dd if=/dev/zero of="$tmpd/home/.cache/pip/payload" bs=4096 count=2 2>/dev/null
# CF-290: build caches are TTL-gated by the NEWEST mtime in the subtree, so this fixture
# must be genuinely stale — writing the payload moved the cache dir's own mtime to now.
touch -d '48 hours ago' "$tmpd/home/.cache/pip/payload" "$tmpd/home/.cache/pip"
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
# CF-290: age the cache the check arm just wrote — a fresh cache is now kept, so a
# non-stale fixture would leave df red and prove nothing about the reclaimer.
touch -d '48 hours ago' "$tmpd/home/.cache/pip/payload" "$tmpd/home/.cache/pip"
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
# CF-290: two behaviours this reclaimer did not have — a build cache is age-gated by the
# NEWEST mtime in its subtree, and an outside-root path is answered instead of spinning
# forever (at `/`, `Path("/").parent == Path("/")`, so the pre-fix walk never returned).
# Each arm is paired with the pre-fix source from c32b53c, so a revert turns it red.
cf290=$(mktemp -d)
mkdir -p "$cf290/home/.cache/pip/fresh" "$cf290/home/.cache/uv/old" "$cf290/outside"
dd if=/dev/zero of="$cf290/home/.cache/pip/fresh/blob" bs=4096 count=1 2>/dev/null
dd if=/dev/zero of="$cf290/home/.cache/uv/old/blob" bs=4096 count=1 2>/dev/null
touch -d '48 hours ago' "$cf290/home/.cache/uv/old/blob" "$cf290/home/.cache/uv/old" "$cf290/home/.cache/uv"
cf290_out=$(python3 -B "$HERE/scripts/reclaim_disk.py" run --root "$cf290/home" --json 2>&1); cf290_rc=$?
if [ "$cf290_rc" -eq 0 ] \
  && [ -f "$cf290/home/.cache/pip/fresh/blob" ] \
  && [ ! -e "$cf290/home/.cache/uv" ] \
  && printf '%s\n' "$cf290_out" | grep -Fq 'keep  .cache/pip — fresh (' \
  && printf '%s\n' "$cf290_out" | grep -Fq 'reap  .cache/uv — '; then
  say "  PASS  fresh build cache kept by the newest-subtree-mtime age gate, aged sibling reaped"
else
  say "  FAIL  build-cache age gate (exit $cf290_rc)"; fails=$((fails+1)); printf '%s\n' "$cf290_out"
fi
cat > "$cf290/probe.py" <<'EOF'
import importlib.util as util
import sys
from pathlib import Path

spec = util.spec_from_file_location("probe", sys.argv[1])
module = util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.safety_reason(Path(sys.argv[2]), Path(sys.argv[3])))
EOF
if git -C "$HERE" show c32b53c:scripts/reclaim_disk.py > "$cf290/prefix.py" 2>/dev/null; then
  mkdir -p "$cf290/pre/.cache/pip"
  dd if=/dev/zero of="$cf290/pre/.cache/pip/blob" bs=4096 count=1 2>/dev/null
  python3 -B "$cf290/prefix.py" run --root "$cf290/pre" >/dev/null 2>&1
  if [ ! -e "$cf290/pre/.cache/pip/blob" ]; then
    say "  PASS  pre-fix c32b53c reaps a fresh build cache — the age-gate arm is falsifiable"
  else
    say "  FAIL  the pre-fix control kept a fresh cache; the age-gate arm cannot discriminate"
    fails=$((fails+1))
  fi
  timeout 5s python3 -B "$cf290/probe.py" "$cf290/prefix.py" "$cf290/home" "$cf290/outside" >/dev/null 2>&1
  prefix_rc=$?
  if [ "$prefix_rc" -eq 124 ]; then
    say "  PASS  pre-fix c32b53c never returns on an outside-root path (timeout 5s -> exit 124)"
  else
    say "  FAIL  the pre-fix control returned on an outside-root path (exit $prefix_rc); the arm cannot discriminate"
    fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source unavailable (git show c32b53c:scripts/reclaim_disk.py)"
  fails=$((fails+1))
fi
probe_out=$(timeout 20s python3 -B "$cf290/probe.py" "$HERE/scripts/reclaim_disk.py" "$cf290/home" "$cf290/outside" 2>&1); probe_rc=$?
if [ "$probe_rc" -eq 0 ] && [ "$probe_out" = "skipped:outside-root" ]; then
  say "  PASS  outside-root path returns skipped:outside-root under a bounded containment walk"
else
  say "  FAIL  outside-root containment (exit $probe_rc, output '$probe_out')"; fails=$((fails+1))
fi
rm -rf "$cf290"
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_reclaim.py" >/dev/null 2>&1; then
  say "  PASS  reclaim targets, cache+job TTL, symlink safety, protected files, dry-run and idempotence"
else
  say "  FAIL  reclaim contract"; fails=$((fails+1))
fi
# CF-307: the scan-scope gate must never print a green it did not measure. Its
# surface resolution is exercised arm-by-arm (unreadable dir, dangling symlink,
# root one level off, readable-but-empty, unscoped, scoped) in a python unit leg
# so a regression to the old glob/exists resolution turns the suite red.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_scan_scope.py" >/dev/null 2>&1; then
  say "  PASS  scan scope names every surface outcome (unreadable != empty)"
else
  say "  FAIL  scan-scope surface resolution (CF-307)"; fails=$((fails+1))
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
# ch:trace row=CF-128 spec=AGENTS.md#rules wave=none:serial test=tests/selftest.sh::drift-head-ancestry doc=none:board-row prompt=none:foreman-brief evidence=tests/selftest.sh::drift-head-ancestry witness=none:local-fixture verdict=none:foreman-judges commit=none:self-referential-hash memory=none:foreman-writes
# CF-128: every arm above passes --published-dir, and that flag suppresses the HEAD-ancestry leg
# outright (`if not args.no_head and not args.published_dir`). The documented Git form — a real
# --ref and no published dir — therefore had no arm at all: the whole block could be deleted and
# this suite still printed SELFTEST: PASS. These two arms drive that form in both directions on a
# scratch repository whose board matches its own ref, so the ancestry row alone decides the verdict.
drift_fixture_git() {  # $1=repo, rest=git args — hermetic identity, no host hooks or global config
  local repo="$1"; shift
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -C "$repo" -c user.email=fixture@example.invalid -c user.name=fixture \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}
drift_git_form() {  # $1=repo $2=ref -> prints the tool report, returns the tool's exit status
  env -u GIT_DIR -u GIT_WORK_TREE GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    python3 -B "$HERE/scripts/board_drift.py" check --workdir "$1" --ref "$2" 2>&1
}
drift_repo="$tmpd/head-ancestry"
mkdir -p "$drift_repo/.coding-hermes/board"
printf '%s\n' '{"id":"CF-001","title":"fixture","status":"pending"}' \
  > "$drift_repo/.coding-hermes/board/tasks.jsonl"
printf '%s\n' '{"event_type":"created","target_id":"CF-001"}' \
  > "$drift_repo/.coding-hermes/board/events.jsonl"
drift_fixture_git "$drift_repo" init -q -b main \
  && drift_fixture_git "$drift_repo" add -A \
  && drift_fixture_git "$drift_repo" commit -qm 'board fixture' \
  && drift_fixture_git "$drift_repo" commit -qm 'ref tip' --allow-empty
drift_base=$(drift_fixture_git "$drift_repo" rev-parse HEAD~1 2>/dev/null)
drift_tip=$(drift_fixture_git "$drift_repo" rev-parse HEAD 2>/dev/null)
if [ -n "$drift_base" ] && [ -n "$drift_tip" ]; then
  # Green direction: HEAD is the first commit and --ref names the second -> PASS row, RESULT: OK.
  drift_fixture_git "$drift_repo" checkout -q --detach "$drift_base"
  drift_out=$(drift_git_form "$drift_repo" main); drift_rc=$?
  if [ "$drift_rc" -eq 0 ] \
    && printf '%s\n' "$drift_out" | grep -Fq 'PASS  HEAD ancestry' \
    && printf '%s\n' "$drift_out" | grep -Fxq 'RESULT: OK' \
    && ! printf '%s\n' "$drift_out" | grep -Fq 'Traceback (most recent call last)'; then
    say "  PASS  git-form ancestry present (HEAD=$drift_base ancestor of main=$drift_tip) -> RESULT: OK"
  else
    say "  FAIL  git-form ancestry present (exit $drift_rc)"; fails=$((fails+1))
    printf '%s\n' "$drift_out"
  fi
  # Red direction: a sibling commit off the same base is NOT an ancestor of --ref -> FAIL + DRIFT.
  # `1 failed` is asserted exactly: every other row of this fixture is green, so a widening gap
  # elsewhere in the tool cannot make this arm pass for the wrong reason.
  drift_fixture_git "$drift_repo" checkout -q --detach "$drift_base" \
    && drift_fixture_git "$drift_repo" commit -qm 'sibling' --allow-empty
  drift_sibling=$(drift_fixture_git "$drift_repo" rev-parse HEAD 2>/dev/null)
  drift_out=$(drift_git_form "$drift_repo" main); drift_rc=$?
  if [ "$drift_rc" -eq 1 ] \
    && printf '%s\n' "$drift_out" | grep -Fq "FAIL  HEAD ancestry — HEAD=$drift_sibling main=$drift_tip; " \
    && printf '%s\n' "$drift_out" | grep -Fxq 'RESULT: DRIFT (1 failed)' \
    && ! printf '%s\n' "$drift_out" | grep -Fq 'Traceback (most recent call last)'; then
    say "  PASS  git-form ancestry absent (HEAD=$drift_sibling not an ancestor of main=$drift_tip) -> RESULT: DRIFT"
  else
    say "  FAIL  git-form ancestry absent (exit $drift_rc)"; fails=$((fails+1))
    printf '%s\n' "$drift_out"
  fi
else
  say "  FAIL  git-form ancestry fixture setup"; fails=$((fails+1))
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
# harness-vars.sh is the §5 contract every adapter sources (CF-229): a spliced copy of an adapter
# is only meaningful with the library beside it.
shutil.copyfile(root / "scripts/harness/harness-vars.sh", fixture / "scripts/harness/harness-vars.sh")
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
# proves it, never mutate the file (a classifier that deletes would be a second
# defect), and refuse to answer RESIDUE when its own probe could not run (CF-259).
# Verdict token is asserted, not the counts: the fixture lock lives outside a
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
# CF-259: a lock the process cannot open is an UNKNOWN observation, not a clean negative.
# Before the fix `adjudicate` mapped every non-held probe result to RESIDUE, so an
# unreadable lock printed "RESIDUE consumers=0 commits_after_mtime=unknown" with exit 0 —
# "no barrier, proceed with the board write", i.e. the safety check failed OPEN. The
# verdict must now be an ERROR line with a non-zero exit; RESIDUE is reserved for a probe
# that actually ran and proved the file unheld.
noread="$tmpd/board/noread.lock"
: > "$noread"
chmod 000 "$noread"
if python3 -B -c 'import sys; open(sys.argv[1], "rb").close()' "$noread" 2>/dev/null; then
  say "  SKIP  CF-259 unreadable lock — this user (uid $(id -u)) can read mode-000 files, so the ERROR path cannot be provoked"
else
  out=$(python3 -B "$HERE/scripts/board_lock.py" "$noread" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] \
    && ! printf '%s\n' "$out" | grep -Eq '^RESIDUE' \
    && printf '%s\n' "$out" | grep -Eq '^(ERROR|UNKNOWN) '; then
    say "  PASS  unreadable lock -> not RESIDUE, exit $rc ($out)"
  else
    say "  FAIL  an unreadable lock was folded into a clean negative (rc=$rc): $out"
    fails=$((fails+1))
  fi
fi
chmod 600 "$noread"
rm -f "$noread"
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

# --- CF-383: tier-1 secrets grades the WORKING TREE, so gitignored bytecode became a secret ----
# `gitleaks detect --no-git` — the tier-1 "secrets" step — reads files git can never commit. The
# synthetic PEM fixture tests/test_node_provisioning.py writes, to prove a 0644 deploy key is
# refused, lands in tests/__pycache__/*.pyc, and tier-1 graded it as `private-key`
# (tests/__pycache__/test_node_provisioning.cpython-314.pyc:35, entropy 4.74, 2026-11-07) while the
# commit guard — staged files only — reported clean on the same tree: verdict c46e82aa failed
# CF-003 with lint, tests and tier-2 all PASS. `.gitleaks.toml` now allowlists generated bytecode.
# Three arms over one scratch tree: GREEN (a PEM inside __pycache__ yields no finding), CONTROL
# (the same PEM outside __pycache__ is still REPORTED, so the exclusion is scoped, not a mute) and
# LOAD-BEARING (with the entry removed the same bytecode IS reported, so deleting it reds this).
# It sits inside section 34 rather than a new numbered section, so arms_tree and the
# docs/ACCEPTANCE-PLAN.md mapping stay as they are — the CF-374/CF-378 precedent.
say "  section 34 bytecode allowlist (CF-383): tier-1 grades the working tree, bytecode is gitignored"
if ! command -v gitleaks >/dev/null 2>&1; then
  say "  SKIP  bytecode-allowlist — gitleaks absent from PATH, tier-1 secrets not measurable here"
else
  cf383=$(mktemp -d)
  mkdir -p "$cf383/tree/tests/__pycache__"
  cp "$HERE/.gitleaks.toml" "$cf383/tree/.gitleaks.toml"
  # Assembled from parts on purpose: this file is graded by the very ruleset it exercises, so a
  # literal BEGIN/END block written here would make tests/selftest.sh itself the finding.
  cf383_b='-----BE'; cf383_b2='GIN '; cf383_k='OPENSSH PRIVATE KEY-----'
  cf383_e='-----E'; cf383_e2='ND '
  cf383_begin="$cf383_b$cf383_b2$cf383_k"
  cf383_end="$cf383_e$cf383_e2$cf383_k"
  cf383_pem() { printf '%s\n%s\n%s\n' "$cf383_begin" 'FIXTUREKEYMATERIALnobody-should-print-this' "$cf383_end"; }
  # A scannable anchor, so a clean run cannot be a scan that read nothing (CF-378 doctrine: a gate
  # whose empty case passes is decoration). The bytecode is the only PEM in the tree for arm 1.
  printf "anchor = 'graded'\n" > "$cf383/tree/tests/anchor.py"

  # ARM 1 — GREEN: the bytecode carries the synthetic PEM and is not graded.
  cf383_pem > "$cf383/tree/tests/__pycache__/fixture.cpython-314.pyc"
  out=$(cd "$cf383/tree" && gitleaks detect --no-git --no-banner --redact \
    --report-format json --report-path "$cf383/green.json" 2>&1); rc=$?
  graded=$(printf '%s\n' "$out" | sed -n 's/.*scanned ~\([0-9][0-9]*\) bytes.*/\1/p' | head -1)
  if [ "$rc" -eq 0 ] && [ -f "$cf383/green.json" ] \
     && ! grep -qF 'tests/__pycache__/fixture.cpython-314.pyc' "$cf383/green.json" \
     && [ "${graded:-0}" -gt 0 ]; then
    say "  PASS  bytecode-allowlist — a PEM in tests/__pycache__/*.pyc yields no finding ($graded bytes graded)"
  else
    say "  FAIL  bytecode-allowlist — a PEM in tests/__pycache__/*.pyc was graded as a secret (exit $rc, ${graded:-0} bytes graded)"
    fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi

  # ARM 2 — CONTROL: the same bytes outside __pycache__ are still a finding. Every entry in
  # `[allowlist].paths` applies to the whole tree, so an entry wide enough to hide a key here
  # would be a mute rather than a scoped exclusion.
  cf383_pem > "$cf383/tree/tests/plain.py"
  out=$(cd "$cf383/tree" && gitleaks detect --no-git --no-banner --redact \
    --report-format json --report-path "$cf383/control.json" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && [ -f "$cf383/control.json" ] \
     && grep -qF 'tests/plain.py' "$cf383/control.json"; then
    say "  PASS  bytecode-allowlist-control — the same PEM outside __pycache__ is still reported"
  else
    say "  FAIL  bytecode-allowlist-control — a PEM outside __pycache__ escaped the scan, so the exclusion is a mute (exit $rc)"
    fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi

  # ARM 3 — LOAD-BEARING: derive a copy of the config without the two bytecode entries and scan
  # the same bytecode alone. The derivation is asserted first: a reformatted config must red this
  # arm loudly instead of leaving it green while it proves nothing.
  rm -f "$cf383/tree/tests/plain.py"
  grep -vxF "  '''__pycache__/'''," "$HERE/.gitleaks.toml" \
    | grep -vxF "  '''\\.pyc\$'''," > "$cf383/tree/.gitleaks.toml"
  if grep -qF "'''__pycache__/'''" "$cf383/tree/.gitleaks.toml" \
     || grep -qF "'''\\.pyc" "$cf383/tree/.gitleaks.toml" \
     || ! grep -qF "'''docs/'''" "$cf383/tree/.gitleaks.toml"; then
    say "  FAIL  bytecode-allowlist-loadbearing — could not derive a config without the bytecode entry; the arm proves nothing"
    fails=$((fails+1))
  else
    out=$(cd "$cf383/tree" && gitleaks detect --no-git --no-banner --redact \
      --report-format json --report-path "$cf383/loadbearing.json" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && [ -f "$cf383/loadbearing.json" ] \
       && grep -qF 'tests/__pycache__/fixture.cpython-314.pyc' "$cf383/loadbearing.json"; then
      say "  PASS  bytecode-allowlist-loadbearing — entry removed, the same .pyc is reported"
    else
      say "  FAIL  bytecode-allowlist-loadbearing — the .pyc stayed clean without the entry, so the arm cannot go red (exit $rc)"
      fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
  fi
  rm -rf "$cf383"
fi


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
  && [ "$(printf '%s\n' "$with_ref" | grep -c .)" -eq 12 ] \
  && ! printf '%s\n' "$with_ref" | grep -Fq 'unknown arg:'; then
  say "  PASS  --staged-files --ref master -> exit 0, same twelve-file staged set"
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

    for name in ("node-create.sh", "lib.sh", "project-node.sh", "install-go.sh", "disk_floor.py",
                 "reclaim_disk.py", "node_gateway_auth.py", "install-node.sh", "node_hygiene.py",
                 "gomodcache.py", "deploy_key.py"):
        shutil.copyfile(root / "scripts" / name, scripts / name)
    shutil.copyfile(root / "scripts/harness/install-hermes.sh", scripts / "harness/install-hermes.sh")
    # The adapter sources this (CF-229); the fixture's staging tree must be a complete node.
    shutil.copyfile(root / "scripts/harness/harness-vars.sh", scripts / "harness/harness-vars.sh")
    executable(scripts / "verify-node.sh", "#!/bin/bash\nexit 0\n")
    executable(binary / "bunker", '''#!/bin/bash
case "$1" in
  info) exit 0 ;;   # CF-051: the reused agent exists, so the payload arms still reach staging
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

# the preflight must validate the credential FILES it will read, before it touches a host, and its
# passing row must NAME them: "every file is readable" without a path proves nothing was measured
if grep -q 'ok "inputs" "readable: ' "$HERE/scripts/bunker-provision.sh"; then
  say "  PASS  the preflight names every credential file it read"
else
  say "  FAIL  the preflight reports readability without naming a file"; fails=$((fails+1))
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

# CF-266: `--check` used to certify a hook it could never run. installed() fell back to whatever
# `gitreins` was on PATH and reported both sources identically, so apply() answered "already at
# pin (no install)", created no venv, then wrote a hook pinned to $VENV/bin/gitreins — the first
# commit in that repo died with "No such file or directory". Three offline arms: the check must
# name the interpreter it cannot run; --apply with only a PATH binary must create the venv or
# refuse, never write a dead hook; and once the venv carries the pin the hook it writes must
# really execute, measured by the stub's own marker on a real commit.
cf266_tmp=$(mktemp -d)
cf266_home="$cf266_tmp/home"
mkdir -p "$cf266_home" "$cf266_tmp/bin"
cf266_pin=$(grep -m1 '^PIN=' "$HERE/scripts/install-gitreins.sh" | sed 's/[^0-9.]//g')
cat > "$cf266_tmp/bin/gitreins" <<STUB
#!/usr/bin/env bash
[ "\${1:-}" = --version ] && { echo "gitreins $cf266_pin"; exit 0; }
exit 0
STUB
chmod +x "$cf266_tmp/bin/gitreins"
# Every git call reads the fixture home only: an ambient global core.hooksPath would bypass the
# hook under test and make the commit arm vacuous.
cf266_git() { env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM HOME="$cf266_home" XDG_CONFIG_HOME="$cf266_home/.config" git "$@"; }
cf266_git config --global user.name fixture
cf266_git config --global user.email fixture@example.invalid
cf266_run() {  # cf266_run <repo> <mode...> — the installer exactly as a node would run it, no network
  local repo="$1"; shift
  env -u GIT_CO_AUTHOR HOME="$cf266_home" XDG_CONFIG_HOME="$cf266_home/.config" \
    PATH="$cf266_tmp/bin:$PATH" PIP_NO_INDEX=1 GITREINS_VENV="$cf266_tmp/venv" NODE_REPO="$repo" \
    /bin/bash "$HERE/scripts/install-gitreins.sh" "$@"
}
# a repo whose hook names an interpreter that is not there — the shape apply() used to write
cf266_seed() {  # cf266_seed <repo> <hook:yes|no>
  local repo="$1" hook="$1/.git/hooks/pre-commit"
  git init -q -b main "$repo"
  mkdir -p "$repo/.gitreins"; printf 'guards: []\n' > "$repo/.gitreins/config.yaml"
  [ "$2" = yes ] || return 0
  cat > "$hook" <<HOOK
#!/usr/bin/env bash
# (DF-011): a bare \`gitreins\` resolves via PATH
REPO_ROOT="\$(git rev-parse --show-toplevel)"
if [ ! -f "\$REPO_ROOT/.gitreins/config.yaml" ]; then
    exit 0
fi
cd "\$REPO_ROOT"
$cf266_tmp/venv/bin/gitreins guard --quality-async
exit \$?
HOOK
  chmod +x "$hook"
}
cf266_hookbin() { [ -r "$1/.git/hooks/pre-commit" ] && sed -n 's/^\(.*\/gitreins\) guard.*/\1/p' "$1/.git/hooks/pre-commit" | head -1; }

cf266_seed "$cf266_tmp/repo-broken" yes
out=$(cf266_run "$cf266_tmp/repo-broken" --check 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -Fq "  FAIL  hook" \
  && printf '%s\n' "$out" | grep -Fq "calls $cf266_tmp/venv/bin/gitreins which does not exist" \
  && ! printf '%s\n' "$out" | grep -q 'GITREINS: PASS'; then
  say "  PASS  CF-266: --check names the hook interpreter that is absent and never says GITREINS: PASS"
else
  say "  FAIL  CF-266: --check certified a hook whose interpreter is absent (exit $rc): $(printf '%s\n' "$out" | grep -Ei 'hook|GITREINS' | head -3 | tr '\n' ' ')"
  fails=$((fails+1))
fi

cf266_seed "$cf266_tmp/repo-apply" no
out=$(cf266_run "$cf266_tmp/repo-apply" --apply --author-name fixture --author-email fixture@example.invalid 2>&1); rc=$?
cf266_bin=$(cf266_hookbin "$cf266_tmp/repo-apply")
if [ "$rc" -eq 0 ] && [ -n "$cf266_bin" ] && [ -x "$cf266_bin" ]; then
  say "  PASS  CF-266: --apply provisioned the venv and pinned its hook to an executable ($cf266_bin)"
elif [ "$rc" -ne 0 ] && [ ! -e "$cf266_tmp/repo-apply/.git/hooks/pre-commit" ] \
  && printf '%s\n' "$out" | grep -Eq '  FAIL  (venv|install|hook) — '; then
  say "  PASS  CF-266: --apply refused with a named row instead of writing a hook it cannot run (exit $rc)"
else
  say "  FAIL  CF-266: --apply reported exit $rc and left hook=${cf266_bin:-none} behind"; fails=$((fails+1))
fi

mkdir -p "$cf266_tmp/venv/bin"
cat > "$cf266_tmp/venv/bin/gitreins" <<STUB
#!/usr/bin/env bash
[ "\${1:-}" = --version ] && { echo "gitreins $cf266_pin"; exit 0; }
[ "\${1:-}" = guard ] && { : > "$cf266_tmp/guard-ran"; exit 0; }
exit 0
STUB
chmod +x "$cf266_tmp/venv/bin/gitreins"
out=$(cf266_run "$cf266_tmp/repo-apply" --apply --author-name fixture --author-email fixture@example.invalid 2>&1); rc=$?
cf266_git -C "$cf266_tmp/repo-apply" commit -q --allow-empty -m t; crc=$?
cf266_bin=$(cf266_hookbin "$cf266_tmp/repo-apply")
if [ "$rc" -eq 0 ] && [ "$crc" -eq 0 ] && [ -n "$cf266_bin" ] && [ -x "$cf266_bin" ] && [ -f "$cf266_tmp/guard-ran" ]; then
  say "  PASS  CF-266: the hook apply wrote executes on a real commit ($cf266_bin guard ran)"
else
  say "  FAIL  CF-266: hook did not run on commit (apply=$rc commit=$crc hook=${cf266_bin:-none} marker=$([ -f "$cf266_tmp/guard-ran" ] && echo yes || echo no))"
  fails=$((fails+1))
fi
rm -rf "$cf266_tmp"

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
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'refusing to destroy without --yes' \
   && printf '%s\n' "$out" | grep -q 'would remove agent a on s'; then
  say "  PASS  destroy without --yes is refused, exit $rc, naming the exact agent and server it would remove"
else
  say "  FAIL  destroy ran without confirmation, or did not name agent a on s (exit $rc)"; fails=$((fails+1))
fi
rm -rf "$tmpd"

# --- CF-214 (continued): the config is data, the command line wins over it, and the credentials
# move as FILES. The fixture is a bunker client whose `exec` really runs the staged command against
# a fixture HOME, so a staged file really lands and a staged install really executes — a stub that
# only echoed would let every hygiene row pass without measuring anything.
cf214=$(mktemp -d)
mkdir -p "$cf214/bin" "$cf214/home/tmp"
: > "$cf214/argv.log"; : > "$cf214/argv.log.modes"
cat > "$cf214/bin/bunker" <<'FBUNKER'
#!/usr/bin/env bash
# fixture bunker client — $BUNKER_FAKE_HOME plays the node. Every argv is appended to the log, so a
# secret that reached a command line is visible to the assertion that greps for it.
set -uo pipefail
printf '%s\n' "$*" >> "${BUNKER_FAKE_LOG:?BUNKER_FAKE_LOG unset}"
cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  list) printf '%s\n' "${BUNKER_FAKE_SERVER:-demo-server}" ;;
  info) exit 0 ;;
  spawn) : > "${BUNKER_FAKE_LOG}.spawn" ;;
  cp)
    src="${1:-}"; dst="${2:-}"; dst="${dst#*:}"
    case "$dst" in /*) ;; *) dst="$BUNKER_FAKE_HOME/$dst" ;; esac
    mkdir -p "$(dirname "$dst")"
    printf '%s %s\n' "$(stat -c '%a' "$src")" "$(basename "$dst")" >> "${BUNKER_FAKE_LOG}.modes"
    cp "$src" "$dst" ;;
  exec)
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do shift; done
    [ $# -gt 0 ] && shift
    case "${BUNKER_FAKE_FAIL:-}" in
      '') ;;
      *) case "$*" in *"$BUNKER_FAKE_FAIL"*) exit 1 ;; esac ;;
    esac
    case "$*" in
      *node-bus-worker.py*)
        if [ "${BUNKER_FAKE_CRIER_SIGNED:-0}" = 1 ]; then
          printf '%s\n' '  PASS  inbox — GET /agents/demo-node/inbox/stats -> 200 (signed read accepted; queue_depth 0, leased_count 0)'
        fi
        exit 0 ;;
    esac
    HOME="$BUNKER_FAKE_HOME" TMPDIR="$BUNKER_FAKE_HOME/tmp" "$@"; exit $? ;;
  destroy) exit 0 ;;
esac
exit 0
FBUNKER
chmod +x "$cf214/bin/bunker"
cf214_run() {  # cf214_run <provisioner args...>; CF214_EXTRA_PATH prefixes the fixture PATH
  local cf214_provisioner="${CF214_PROVISIONER_OVERRIDE:-$HERE/scripts/bunker-provision.sh}"
  env -i PATH="${CF214_EXTRA_PATH:-}$cf214/cbin:$cf214/bin:/usr/bin:/bin" HOME="$cf214/home" TMPDIR="$cf214/home/tmp" \
    BUNKER_FAKE_LOG="$cf214/argv.log" BUNKER_FAKE_HOME="$cf214/home" \
    BUNKER_FAKE_FAIL="${BUNKER_FAKE_FAIL:-}" BUNKER_FAKE_CRIER_SIGNED="${BUNKER_FAKE_CRIER_SIGNED:-0}" \
    HERE="${CF214_SCRIPT_ROOT:-$HERE/scripts}" \
    /bin/bash "$cf214_provisioner" "$@"
}

# (a) --check is READ-ONLY. The probe has to travel as a file (bunker's exec does not forward
# stdin), so the run must remove it again: before CF-214 every check left cf-probe.sh in the
# node's home for good, which made "read-only" a claim about intent rather than a measurement.
out=$(cf214_run --check --project demo --agent demo-node --server demo-server 2>&1); rc=$?
cf214_left=$(find "$cf214/home" -type f | wc -l)
if printf '%s\n' "$out" | grep -q 'PASS  agent — demo-node exists' \
   && grep -q 'cf-probe' "$cf214/argv.log" && [ "$cf214_left" -eq 0 ] && [ "$rc" -ne 0 ]; then
  say "  PASS  CF-214: --check probed the node, left no file behind, and an unmeasured node is a FAIL (exit $rc)"
else
  say "  FAIL  CF-214: --check left $cf214_left file(s) on the node or never probed (exit $rc)"
  fails=$((fails+1))
fi

# (b) --apply reuses an existing agent, and the credential leg is files-only: one mode-600 bundle
# in, installed at 600, deleted on both sides, and the value never on stdout or on any argv.
cf214_tok="SYNTHETIC-CF214-CREDENTIAL-NOT-A-SECRET"
printf '%s\n' "$cf214_tok" > "$cf214/gh.token"; chmod 600 "$cf214/gh.token"
out=$(cf214_run --apply --project demo --repo https://example.invalid/x.git --agent demo-node \
      --server demo-server --harness none --github-token-file "$cf214/gh.token" 2>&1); rc=$?
cf214_inst="$cf214/home/.node/auth/github.token"
cf214_mode=$(stat -c %a "$cf214_inst" 2>/dev/null || echo absent)
cf214_val=$(cat "$cf214_inst" 2>/dev/null || true)
cf214_out_leak=$(printf '%s\n' "$out" | grep -c "$cf214_tok")
cf214_arg_leak=$(grep -c "$cf214_tok" "$cf214/argv.log")
# the bundle's own mode at the moment it was copied in — not the mode of some later artefact
cf214_bundle_mode=$(awk '$2 == "cf-auth.bundle" {print $1}' "$cf214/argv.log.modes" | tail -1)
cf214_bundle=$([ -e "$cf214/home/cf-auth.bundle" ] && echo left || echo gone)
cf214_tmpfiles=$(find "$cf214/home/tmp" -type f | wc -l)
cf214_cred=$(stat -c %a "$cf214/home/.git-credentials" 2>/dev/null || echo absent)
if [ "$cf214_mode" = 600 ] && [ "$cf214_val" = "$cf214_tok" ] && [ "$cf214_out_leak" -eq 0 ] \
   && [ "$cf214_arg_leak" -eq 0 ] && [ "$cf214_bundle_mode" = 600 ] && [ "$cf214_bundle" = gone ] \
   && [ "$cf214_tmpfiles" -eq 0 ] && [ "$cf214_cred" = 600 ] && [ ! -e "$cf214/argv.log.spawn" ] \
   && printf '%s\n' "$out" | grep -q 'PASS  agent — demo-node reused (no second agent)'; then
  say "  PASS  CF-214: one 600 bundle in, installed at 600, gone from both sides, no secret in stdout or argv, existing agent reused (no second agent)"
else
  say "  FAIL  CF-214 credential leg: mode=$cf214_mode value=$([ "$cf214_val" = "$cf214_tok" ] && echo match || echo mismatch) stdout-leak=$cf214_out_leak argv-leak=$cf214_arg_leak bundle-cp-mode=${cf214_bundle_mode:-none} bundle=$cf214_bundle local-tmp=$cf214_tmpfiles git-credentials=$cf214_cred spawn=$([ -e "$cf214/argv.log.spawn" ] && echo yes || echo no)"
  fails=$((fails+1))
fi

# (c) the credential rows are MEASURED, not asserted. Two reds, both of which passed silently
# before CF-214: a node reporting a non-600 mode, and a bundle the node could not delete.
# (c1) the fixture shims `stat` so the snippet's own mode line says 644; the row must follow it.
mkdir -p "$cf214/sbin"
cat > "$cf214/sbin/stat" <<'FSTAT'
#!/usr/bin/env bash
# fixture stat — every file under .node/auth reports mode 644
case "$*" in
  *".node/auth/"*) printf '644\n' ;;
  *) exec /usr/bin/stat "$@" ;;
esac
FSTAT
chmod +x "$cf214/sbin/stat"
CF214_EXTRA_PATH="$cf214/sbin:"
out=$(cf214_run --apply --project demo --repo https://example.invalid/x.git --agent demo-node \
      --server demo-server --harness none --github-token-file "$cf214/gh.token" 2>&1)
CF214_EXTRA_PATH=""
if printf '%s\n' "$out" | grep -q 'FAIL  auth — installed but not mode 600: github.token=644' \
   && ! printf '%s\n' "$out" | grep -q 'PASS  auth — installed under'; then
  say "  PASS  CF-214: the auth row follows the mode the node reported (644 -> FAIL), it does not assert 'mode 600'"
else
  say "  FAIL  CF-214: the auth row certified mode 600 while the node reported 644"
  fails=$((fails+1))
fi
# (c2) a bundle the node cannot remove is a credential leak: it must be a named row, not `|| true`
BUNKER_FAKE_FAIL=cf-auth.bundle
out=$(cf214_run --apply --project demo --repo https://example.invalid/x.git --agent demo-node \
      --server demo-server --harness none --github-token-file "$cf214/gh.token" 2>&1); rc=$?
unset BUNKER_FAKE_FAIL
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'FAIL  auth_bundle — could not delete' \
   && printf '%s\n' "$out" | grep -q 'FAIL  auth — the bundle install failed on the node'; then
  say "  PASS  CF-214: an install that fails and a bundle the node cannot delete are both named FAIL rows (exit $rc)"
else
  say "  FAIL  CF-214: a failed install or an undeletable bundle was not named (exit $rc)"
  fails=$((fails+1))
fi

# (d) the command line wins over the file for every key the requirement names: agent, server, repo,
# ref, harness, namespace, crier URL, duckbrain URL and the token-file paths.
cat > "$cf214/cli.conf" <<'CONF'
PROJECT=conf-project
AGENT=conf-agent
SERVER=conf-server
REPO=https://conf.invalid/r.git
REF=conf-ref
HARNESS=conf-harness
NAMESPACE=conf-ns
CRIER_URL=http://conf.invalid:1
DUCKBRAIN_URL=http://conf.invalid:3000
GITHUB_TOKEN_FILE=/dev/null
CONF
out=$(cf214_run --config "$cf214/cli.conf" --check --project cli-project --agent cli-agent \
      --server cli-server --repo https://cli.invalid/r.git --ref cli-ref --harness cli-harness \
      --namespace cli-ns --crier-url http://cli.invalid:2 --duckbrain-url http://cli.invalid:3001 \
      --github-token-file /nonexistent/cf214.token 2>&1)
cf214_win=yes
for cf214_need in 'project=cli-project agent=cli-agent server=cli-server' \
                   'repo=https://cli.invalid/r.git' 'ref=cli-ref' 'harness=cli-harness' \
                   'namespaces=cli-ns' 'crier=http://cli.invalid:2' \
                   'duckbrain=http://cli.invalid:3001' \
                   'not readable: GITHUB_TOKEN_FILE(/nonexistent/cf214.token)'; do
  printf '%s\n' "$out" | grep -qF -- "$cf214_need" || cf214_win="no:$cf214_need"
done
for cf214_lost in 'conf-agent' 'conf-server' 'conf.invalid'; do
  printf '%s\n' "$out" | grep -qF -- "$cf214_lost" && cf214_win="file-won:$cf214_lost"
done
# and a passing inputs row names the file it read, so "readable" is a measurement and a --flag that
# silently lost is visible as a path change rather than as nothing at all
cf214_conf_out=$(cf214_run --config "$cf214/cli.conf" --check --agent demo-node --server demo-server 2>&1)
printf '%s\n' "$cf214_conf_out" | grep -qF 'PASS  inputs — readable: GITHUB_TOKEN_FILE=/dev/null' \
  || cf214_win="no:inputs-row-names-the-file"
if [ "$cf214_win" = yes ]; then
  say "  PASS  CF-214: the command line won over the config for agent/server/repo/ref/harness/namespace/crier/duckbrain/token-file"
else
  say "  FAIL  CF-214: config precedence — $cf214_win"
  fails=$((fails+1))
fi

# (e) crier connect: CONNECTED is a claim about a 200, and 401/403/404/000 are named distinctly.
mkdir -p "$cf214/cbin"
cat > "$cf214/cbin/curl" <<'FCURL'
#!/usr/bin/env bash
# fixture curl — /health answers 200, every other route answers $FIXTURE_CODE
case "$*" in
  */health*) printf '200' ;;
  *) printf '%s' "${FIXTURE_CODE:-200}" ;;
esac
exit 0
FCURL
chmod +x "$cf214/cbin/curl"
printf '{"agent":"demo-node","project":"demo","url":"http://crier.invalid:8767"}\n' > "$cf214/home/.node/crier.json"
cf214_crier() {  # cf214_crier <inbox code>
  env -i PATH="$cf214/cbin:$cf214/bin:/usr/bin:/bin" HOME="$cf214/home" FIXTURE_CODE="$1" \
    BUNKER_FAKE_LOG="$cf214/argv.log" BUNKER_FAKE_HOME="$cf214/home" \
    /bin/bash "$HERE/scripts/bunker-crier-connect.sh" --check --agent demo-node \
    --server demo-server --url http://crier.invalid:8767 2>&1
}
cf214_codes=yes
for cf214_arm in '401|FAIL  inbox — .*-> 401 \(authentication or agent signature refused\)' \
                  '403|FAIL  inbox — .*-> 403 \(owner mismatch or guard refused\)' \
                  '404|FAIL  inbox — .*-> 404 \(agent is genuinely not registered on the bus\)' \
                  '000|FAIL  inbox — .*-> 000 \(no answer: refused, unresolvable or timed out'; do
  cf214_code="${cf214_arm%%|*}"; cf214_want="${cf214_arm#*|}"
  cf214_cout=$(cf214_crier "$cf214_code")
  printf '%s\n' "$cf214_cout" | grep -qE -- "  $cf214_want" || cf214_codes="no:$cf214_code"
  printf '%s\n' "$cf214_cout" | grep -q 'CRIER: CONNECTED' && cf214_codes="connected-on-$cf214_code"
done
cf214_cout=$(cf214_crier 200); cf214_rc=$?
printf '%s\n' "$cf214_cout" | grep -q 'CRIER: CONNECTED' || cf214_codes="no:200-connected"
printf '%s\n' "$cf214_cout" | grep -q 'CRIER: UNVERIFIED' && cf214_codes="unsigned-200-unverified"
[ "$cf214_rc" -eq 0 ] || cf214_codes="inbox-200-exit-$cf214_rc"
if [ "$cf214_codes" = yes ]; then
  say "  PASS  CF-214: crier connect names 401/403/404/000 distinctly and reports CONNECTED only when the inbox route returns 200"
else
  say "  FAIL  CF-214: crier code naming — $cf214_codes: $(printf '%s\n' "$cf214_cout" | grep -E 'FAIL|WARN|CRIER' | head -4 | tr '\n' ' ')"
  fails=$((fails+1))
fi
# (f) the provisioner must describe the measurement that made crier CONNECTED. With no node-side
# signed probe, the host's unsigned 200 is a WARN; a real signed_read row is quoted as such.
cf214_provisioner_out=$(cf214_run --check --project demo --agent demo-node --server demo-server \
  --crier-url http://crier.invalid:8767 2>&1)
cf214_provisioner_row=yes
printf '%s\n' "$cf214_provisioner_out" | grep -q 'WARN  crier — host inbox route answered 200, unsigned; signed read was not measured' \
  || cf214_provisioner_row="no:unsigned-200-warning"
printf '%s\n' "$cf214_provisioner_out" | grep -q 'signed read accepted' \
  && cf214_provisioner_row="claims-unmeasured-signed-read"
BUNKER_FAKE_CRIER_SIGNED=1
cf214_signed_out=$(cf214_run --check --project demo --agent demo-node --server demo-server \
  --crier-url http://crier.invalid:8767 2>&1)
unset BUNKER_FAKE_CRIER_SIGNED
printf '%s\n' "$cf214_signed_out" | grep -q 'PASS  crier — signed read accepted: PASS  signed_read — node-side signed inbox read accepted' \
  || cf214_provisioner_row="no:signed-row-quote"
cf214_mutated="$cf214/scripts/bunker-provision.sh"
mkdir -p "$cf214/scripts"
cp "$HERE/scripts/bunker-provision.sh" "$cf214_mutated"
cp "$HERE/scripts/bunker-crier-connect.sh" "$cf214/scripts/bunker-crier-connect.sh"
cp "$HERE/scripts/lib.sh" "$cf214/scripts/lib.sh"
python3 -B - "$cf214_mutated" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = '''        local signed_row
        signed_row=$(printf '%s' "$crier_out" | grep -E '^  PASS  signed_read —' | head -1 | sed 's/^ *//')
        if [ -n "$signed_row" ]; then
          ok "crier" "signed read accepted: $signed_row"
        else
          warn "crier" "host inbox route answered 200, unsigned; signed read was not measured (node-side probe skipped)"
        fi ;;'''
new = '''        ok "crier" "signed read accepted: $(printf '%s' "$crier_out" | grep -E 'PASS  inbox' | head -1 | sed 's/^ *//')" ;;'''
if old not in text:
    raise SystemExit("CF-214 mutation target not found")
path.write_text(text.replace(old, new, 1))
PY
CF214_PROVISIONER_OVERRIDE="$cf214_mutated"
cf214_old_out=$(cf214_run --check --project demo --agent demo-node --server demo-server \
  --crier-url http://crier.invalid:8767 2>&1)
CF214_PROVISIONER_OVERRIDE=""
printf '%s\n' "$cf214_old_out" | grep -q 'signed read accepted' \
  && printf '%s\n' "$cf214_old_out" | grep -q 'PASS  inbox' \
  || cf214_provisioner_row="mutation-did-not-red"
if [ "$cf214_provisioner_row" = yes ]; then
  say "  PASS  CF-214: provisioner crier row distinguishes unsigned 200 from signed_read and the old PASS inbox certification reds"
else
  say "  FAIL  CF-214: provisioner crier evidence row — $cf214_provisioner_row"
  fails=$((fails+1))
fi
# (g) the skill ships with the scripts it documents. A skill that names a script nobody ships — or a
# mode the script refuses — is drift the operator only discovers at the command line.
cf214_skill="$HERE/skills/code-factory-bunker/SKILL.md"
cf214_missing=""
for cf214_cmd in 'bunker-provision.sh' 'bunker-crier-connect.sh' '--check' '--apply' '--destroy' '--yes'; do
  grep -qF -- "$cf214_cmd" "$cf214_skill" 2>/dev/null || cf214_missing="$cf214_missing $cf214_cmd"
done
if [ -z "$cf214_missing" ]; then
  say "  PASS  CF-214: skills/code-factory-bunker/SKILL.md ships in the repo and names both scripts and check/apply/destroy(--yes)"
else
  say "  FAIL  CF-214: the repo skill does not name:$cf214_missing"; fails=$((fails+1))
fi
# The fleet copy lives outside this repo and does not exist on a clean box: absent is a NOTE, while a
# present copy that disagrees on the scripts is a FAIL (its owning lane reconciles it, not this test).
cf214_fleet="${CF214_FLEET_SKILL:-$HOME/.hermes/skills/coding-hermes/code-factory-bunker/SKILL.md}"
if [ -r "$cf214_fleet" ]; then
  cf214_split=""
  for cf214_cmd in 'bunker-provision.sh' 'bunker-crier-connect.sh'; do
    grep -qF -- "$cf214_cmd" "$cf214_fleet" || cf214_split="$cf214_split $cf214_cmd"
  done
  if [ -z "$cf214_split" ]; then
    say "  PASS  CF-214: the fleet skill copy names the same two scripts as the repo copy"
  else
    say "  FAIL  CF-214: the fleet skill copy does not name:$cf214_split"; fails=$((fails+1))
  fi
else
  say "  NOTE  CF-214: no fleet skill copy at $cf214_fleet — repo copy only (not a failure on a clean host)"
fi
rm -rf "$cf214"

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

# i. the same command twice changes nothing — and the gate still runs on the already-landed
# path, because ancestry is not evidence that the node's own tree is green. i1 asserts a red
# gate is a refusal there (the pre-fix script printed LANDED (already) and exited 0 without ever
# running --gate-cmd); i2 asserts idempotence survives: exit 0, the gate row printed, no ref moved.
head_before=$(git -C "$tmpd/wd" rev-parse HEAD)
origin_before=$(git -C "$tmpd/origin.git" rev-parse refs/heads/main)
cf213 "already-landed red gate" 1 "  FAIL  gate — 'echo fixture gate refused; exit 99' exited 99 at ${node2:0:12}" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" --gate-cmd 'echo fixture gate refused; exit 99'
if ! printf '%s\n' "$out" | grep -Fq "LANDED (already)" \
  && [ "$(git -C "$tmpd/wd" rev-parse HEAD)" = "$head_before" ]; then
  say "  PASS  a red gate on an already-landed commit refused and moved no ref (main ${head_before:0:12})"
else
  say "  FAIL  a red gate on an already-landed commit printed LANDED or moved a ref"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
cf213 "idempotent re-run" 0 "  PASS  gate — 'test -f node.txt' exited 0 at ${node2:0:12} (detached worktree)" \
  --workdir "$tmpd/wd" --branch node/crier/fixture --commit "$node2" --gate-cmd 'test -f node.txt'
if printf '%s\n' "$out" | grep -Fq "LANDED (already)" \
  && printf '%s\n' "$out" | grep -Fq "  PASS  gate —" \
  && [ "$(git -C "$tmpd/wd" rev-parse HEAD)" = "$head_before" ] \
  && [ "$(git -C "$tmpd/origin.git" rev-parse refs/heads/main)" = "$origin_before" ]; then
  say "  PASS  second run exited $rc, ran the gate, and moved no ref — main ${head_before:0:12}, origin/main ${origin_before:0:12}"
else
  say "  FAIL  second run changed the tree or did not run the gate"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
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

# CF-229 AC4: the RECEIVING side of the §5 contract. The installers are held to it by the
# conformance battery; the bus worker is held to it here — the directive's set reaches the harness
# child, and the run records WHICH values it passed (name -> {set,len}) without recording them.
# The two refusal arms are the failure path, so this arm can go red. Part of section 44 rather than
# a new section: the drift probe compares the plan's section count against this file's.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_section5_receipt.py" >/dev/null 2>&1; then
  say "  PASS  §5 set accepted from the directive, receipt records name/set/len only, ambient CF_* scrubbed"
else
  say "  FAIL  the §5 contract on the receiving side (tests/test_section5_receipt.py)"; fails=$((fails+1))
fi

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
# CF-231: the hermetic I3 writer and the battery's unsupported runtime rows are falsifiable.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_harness_memory.py"; then
  say "  PASS  shared memory fixture and missing/wrong namespace refusals (CF-231)"
else
  say "  FAIL  shared memory fixture or namespace refusal (CF-231)"; fails=$((fails+1))
fi
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

# (d) CF-225: a binary the adapter measured OUTSIDE PATH is still smokeable. The claude-code
# adapter installs under $HOME/.local/harness/npm/bin, which is not on PATH, so a smoke leg that
# re-resolves with `command -v` alone refused to test a harness our own installer installed and
# blamed PATH instead. The stub below sits off PATH and records its own argv[0], and a synthetic
# credential (never a real one) lets the turn run, so the row proves the resolved path was the
# binary that EXECUTED -- not merely a string that was printed.
mkdir -p "$tmpd/offpath-bin" "$tmpd/offpath" "$tmpd/nobin" "$tmpd/prefix/tests"
cat > "$tmpd/offpath-bin/claude" <<'STUB'
#!/usr/bin/env bash
printf 'stub-binary: %s\n' "$0"
printf '%s\n' "$*" > smoke.txt
STUB
chmod +x "$tmpd/offpath-bin/claude"
cat > "$tmpd/offpath/install-claude-code.sh" <<'FIX'
#!/usr/bin/env bash
. "${FIXTURE_LIB:?}"
case "${1:---check}" in
  --check)
    say "harness: claude-code (fixture, binary off PATH)"
    ok binary "$FIXTURE_BIN/offpath-bin/claude (installed by this adapter)"
    ok version "9.9.9-fixture"
    say ""
    say "CLAUDE-CODE: PASS" ;;
  *) bad apply "fixture adapter has no ladder"; exit 1 ;;
esac
FIX
# (e) an adapter that names no binary, with the binary genuinely absent: still a SKIP naming the
# absence -- the resolution above must not turn "nothing to measure" into a green row.
cat > "$tmpd/nobin/install-codex.sh" <<'FIX'
#!/usr/bin/env bash
. "${FIXTURE_LIB:?}"
case "${1:---check}" in
  --check)
    say "harness: codex (fixture, names no binary)"
    ok version "9.9.9-fixture"
    say ""
    say "CODEX: PASS" ;;
  *) bad apply "fixture adapter has no ladder"; exit 1 ;;
esac
FIX
synthetic_key="synthetic-$(printf '%s' fixture-key)"
runb_nopath() {  # runb_nopath <adapter-dir> <only> [script] -- PATH holds no harness binary
  local dir="$1" only="$2" script="${3:-$HERE/tests/harness-conformance.sh}"
  env -i PATH="/usr/bin:/bin" HOME="$tmpd/home" FIXTURE_BIN="$tmpd" FIXTURE_LIB="$HERE/scripts/lib.sh" \
    ANTHROPIC_API_KEY="$synthetic_key" \
    /bin/bash "$script" --only "$only" --adapter-dir "$dir" 2>&1
}
out=$(runb_nopath "$tmpd/offpath" claude-code)
smoke_row=$(printf '%s\n' "$out" | grep '^  PASS  claude-code:smoke' | head -1)
if [ -n "$smoke_row" ] \
  && printf '%s' "$smoke_row" | grep -qF "binary $tmpd/offpath-bin/claude" \
  && grep -rqF 'stub-binary: ' "$tmpd/home/.harness-conformance" 2>/dev/null \
  && ! printf '%s\n' "$out" | grep -q 'claude-code:smoke .*absent'; then
  say "  PASS  a binary measured off PATH is resolved from the adapter's own row and that path runs the turn"
else
  say "  FAIL  an off-PATH measured binary did not smoke (or the row does not quote the path): $(printf '%s\n' "$out" | grep 'claude-code:smoke' | tr '\n' ' ')"
  fails=$((fails+1))
fi
out=$(runb_nopath "$tmpd/nobin" codex)
if printf '%s\n' "$out" | grep -qF '  SKIP  codex:smoke' \
  && printf '%s\n' "$out" | grep -qF 'binary `codex` absent' \
  && printf '%s\n' "$out" | grep -qF 'no `codex` is on PATH' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  codex:smoke'; then
  say "  PASS  no binary row and no binary anywhere -> SKIP naming the absence"
else
  say "  FAIL  an absent binary was not a named SKIP: $(printf '%s\n' "$out" | grep 'codex:smoke' | tr '\n' ' ')"
  fails=$((fails+1))
fi
# (f) the arm above can fail. The frozen body below is the leg_smoke that shipped before CF-225
# (git show 2f4df2f:tests/harness-conformance.sh): it resolves the smoke binary with `command -v`
# alone. Its em dashes and ellipses are rendered as -- and ... so this diff stays ASCII; nothing
# else differs. The shipped script is copied with only that one function replaced, so the
# comparison isolates the resolution rule -- and on the same fixture it prints the wrong verdict,
# which is what makes the green above evidence.
ln -sfn "$HERE/scripts" "$tmpd/prefix/scripts"
ln -sfn "$HERE/specs" "$tmpd/prefix/specs"
cat > "$tmpd/prefix-leg-smoke.sh" <<'PREFIX'
leg_smoke() {  # <id> <binary> <generation> <measured>
  local id="$1" bin="$2" gen="$3" measured="$4" dir cred rc token out sum want prompt attempt
  local path
  path="$(command -v "$bin" 2>/dev/null || true)"
  if [ -z "$path" ]; then
    emit "$id" smoke SKIP "binary \`$bin\` absent from PATH"
    return 0
  fi
  if [ "$gen" != "0" ]; then
    local ver major
    ver="$(ver_of "$bin")"; major="${ver%%.*}"
    if [ "${major:-}" != "$gen" ]; then
      emit "$id" smoke SKIP "no $bin $gen.x binary on PATH (measured $ver is v${major:-unknown}); a v1 binary cannot smoke a v2 harness"
      return 0
    fi
  fi
  if [ "$measured" != "1" ]; then
    emit "$id" smoke SKIP "$bin is present but this repo has measured no non-interactive surface for it (specs/HARNESS.md): refusing to invent a turn"
    return 0
  fi
  cred=""; cred_rc=0
  case "$id" in
    hermes) cred="$(cred_hermes)" || cred_rc=$? ;;
    claude-code) cred="$(cred_claude)" || cred_rc=$? ;;
    codex) cred="$(cred_codex)" || cred_rc=$? ;;
    opencode|opencode-v2) cred="$(cred_opencode)" || cred_rc=$? ;;
    deepseek) cred="$(cred_deepseek)" || cred_rc=$? ;;
    pi-agent) cred="$(cred_pi)" || cred_rc=$? ;;
  esac
  if [ "$cred_rc" -ne 0 ]; then
    emit "$id" smoke SKIP "$cred"
    return 0
  fi

  dir="$WORK/smoke/$id"
  rm -rf "$dir"; mkdir -p "$dir"
  token="CF-CONF-${id//[^a-zA-Z0-9]/}-$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  prompt="Create a file named smoke.txt in the current working directory whose entire contents are exactly: $token. Do not do anything else."
  attempt=1
  while : ; do
    out="$(smoke_turn "$id" "$dir" "$prompt" 2>&1)"; rc=$?
    printf '%s\n' "$out" > "$WORK/$id.smoke-$attempt.log"
    [ -f "$dir/smoke.txt" ] && break
    [ "$rc" -eq 0 ] && break
    [ "$attempt" -ge 2 ] && break
    [ "$rc" -eq 124 ] && break   # a hang is not transient; a second window proves nothing
    note_row "$id: smoke attempt $attempt exited $rc with no artifact -- retried once"
    attempt=$((attempt+1)); sleep 2
  done
  if [ "$rc" -ne 0 ] && [ ! -f "$dir/smoke.txt" ]; then
    emit "$id" smoke FAIL "turn exited $rc and wrote no smoke.txt after $attempt attempt(s) -- $(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -1)"
    return 0
  fi
  if [ ! -f "$dir/smoke.txt" ]; then
    emit "$id" smoke FAIL "turn exited $rc but left no smoke.txt in $dir"
    return 0
  fi
  if ! grep -qF -- "$token" "$dir/smoke.txt"; then
    emit "$id" smoke FAIL "smoke.txt does not contain the token it was asked for ($(wc -c < "$dir/smoke.txt") B, sha256 $(sha256sum "$dir/smoke.txt" | cut -c1-12)..., exit $rc)"
    return 0
  fi
  sum="$(sha256sum "$dir/smoke.txt" | cut -c1-12)"
  want="$(printf '%s' "$token" | sha256sum | cut -c1-12)"
  emit "$id" smoke PASS "smoke.txt contains $token ($(wc -c < "$dir/smoke.txt") B, sha256 $sum..., exit $rc; token sha256 $want...)"
  return 0
}
PREFIX
awk -v body="$tmpd/prefix-leg-smoke.sh" '
  /^leg_smoke\(\) \{/ { while ((getline line < body) > 0) print line; close(body); skip=1; next }
  skip && /^\}$/ { skip=0; next }
  !skip { print }
' "$HERE/tests/harness-conformance.sh" > "$tmpd/prefix/tests/harness-conformance.sh"
prefix_defs=$(grep -c '^leg_smoke() {' "$tmpd/prefix/tests/harness-conformance.sh" 2>/dev/null || true)
if bash -n "$tmpd/prefix/tests/harness-conformance.sh" 2>/dev/null && [ "$prefix_defs" = 1 ] \
  && ! grep -qF "the path its --check measured" "$tmpd/prefix/tests/harness-conformance.sh"; then
  out=$(runb_nopath "$tmpd/offpath" claude-code "$tmpd/prefix/tests/harness-conformance.sh")
  if printf '%s\n' "$out" | grep -qF '  SKIP  claude-code:smoke' \
    && printf '%s\n' "$out" | grep -qF 'binary `claude` absent from PATH' \
    && ! printf '%s\n' "$out" | grep -q '^  PASS  claude-code:smoke'; then
    say "  PASS  the pre-CF-225 PATH-only leg prints SKIP 'absent from PATH' on the same fixture -> the new arm can fail"
  else
    say "  FAIL  the pre-CF-225 leg did not print the wrong verdict: $(printf '%s\n' "$out" | grep 'claude-code:smoke' | tr '\n' ' ')"
    fails=$((fails+1))
  fi
else
  say "  FAIL  could not splice the pre-CF-225 leg_smoke into a scratch copy (defs=$prefix_defs)"; fails=$((fails+1))
fi

# (g) CF-227: the codex smoke turn must pin its provider AND its model on argv. `codex exec`
# with neither inherits `model_provider`/`model` from the ambient ~/.codex/config.toml, and this
# host's file pins claude-code-router at a port nothing listens on -- so the `codex:smoke` cell
# measured that router, not codex. The stub below records its own argv and never writes the
# artifact: no network, no credential value and no model token is involved (the auth.json is
# synthetic and only satisfies cred_codex's shape probe). The control case is the same battery
# with the pre-CF-227 codex arm spliced back in, which must record an argv WITHOUT the pin --
# that is what keeps the arm above falsifiable.
mkdir -p "$tmpd/codexpin/bin" "$tmpd/codexpin/adapters" "$tmpd/codexpin/home/.codex" "$tmpd/nopin/tests"
printf '{"auth_mode":"fixture","tokens":{"synthetic":true}}\n' > "$tmpd/codexpin/home/.codex/auth.json"
cat > "$tmpd/codexpin/bin/codex" <<'STUB'
#!/usr/bin/env bash
# A codex that records the argv it was handed and exits as told. It never writes an artifact,
# because the point of the arm is that the artifact -- not the exit code -- is the evidence.
case "${1:-}" in
  --version) printf 'codex-cli 9.9.9-fixture\n'; exit 0 ;;
esac
printf '%s\n' "$*" >> "${FAKE_CODEX_ARGV:?}"
[ "${FAKE_CODEX_EXIT:-1}" = 0 ] && exit 0
exit "${FAKE_CODEX_EXIT:-1}"
STUB
chmod +x "$tmpd/codexpin/bin/codex"
cat > "$tmpd/codexpin/adapters/install-codex.sh" <<'FIX'
#!/usr/bin/env bash
. "${FIXTURE_LIB:?}"
case "${1:---check}" in
  --check)
    say "harness: codex (fixture, names no binary)"
    ok version "9.9.9-fixture"
    say ""
    say "CODEX: PASS" ;;
  *) bad apply "fixture adapter has no ladder"; exit 1 ;;
esac
FIX
runb_codex() {  # runb_codex <script> <argv-file> <stub exit code>
  env -i PATH="$tmpd/codexpin/bin:/usr/bin:/bin" HOME="$tmpd/codexpin/home" \
    FIXTURE_LIB="$HERE/scripts/lib.sh" HC_CODEX_MODEL=fixture-codex-model \
    FAKE_CODEX_ARGV="$2" FAKE_CODEX_EXIT="$3" \
    /bin/bash "$1" --only codex --adapter-dir "$tmpd/codexpin/adapters" 2>&1
}
out=$(runb_codex "$HERE/tests/harness-conformance.sh" "$tmpd/codexpin/pinned.argv" 1)
smoke_row=$(printf '%s\n' "$out" | grep '^  FAIL  codex:smoke' | head -1)
if grep -qF -- '-c model_provider="openai"' "$tmpd/codexpin/pinned.argv" 2>/dev/null \
  && grep -qF -- '-m fixture-codex-model' "$tmpd/codexpin/pinned.argv" \
  && grep -qE 'Create a file named smoke.txt .*CF-CONF-codex-' "$tmpd/codexpin/pinned.argv" \
  && [ -n "$smoke_row" ] \
  && printf '%s' "$smoke_row" | grep -qF 'provider openai' \
  && printf '%s' "$smoke_row" | grep -qF 'base_url codex built-in OpenAI endpoint' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  codex:smoke'; then
  say "  PASS  codex smoke argv carries -c model_provider=\"openai\" -m fixture-codex-model and the needle; the FAIL names the provider and its base_url"
else
  say "  FAIL  the codex smoke turn did not pin its binding: $(printf '%s\n' "$out" | grep 'codex:smoke' | tr '\n' ' ')"
  fails=$((fails+1))
fi
# exit 0 is not evidence: the same stub exiting 0 must still FAIL, by that exact name.
out=$(runb_codex "$HERE/tests/harness-conformance.sh" "$tmpd/codexpin/zero.argv" 0)
if printf '%s\n' "$out" | grep -qxF '  FAIL  codex:smoke — exited 0 without writing smoke.txt' \
  && ! printf '%s\n' "$out" | grep -q '^  PASS  codex:smoke'; then
  say "  PASS  codex exiting 0 with no artifact -> FAIL 'exited 0 without writing smoke.txt'"
else
  say "  FAIL  exit 0 without an artifact was not refused by that name: $(printf '%s\n' "$out" | grep 'codex:smoke' | tr '\n' ' ')"
  fails=$((fails+1))
fi
# the control: the same battery with the pre-CF-227 codex arm (git show 2f4df2f:tests/harness-conformance.sh)
ln -sfn "$HERE/scripts" "$tmpd/nopin/scripts"
ln -sfn "$HERE/specs" "$tmpd/nopin/specs"
printf '%s\n' '    codex)      ( cd "$dir" && timeout "$TIMEOUT" codex exec --skip-git-repo-check -s workspace-write "$prompt" </dev/null ) ;;' > "$tmpd/nopin-arm.txt"
# Replace the whole codex smoke arm -- both of its lines -- and leave the `codex) cred_...`
# arm of the credential probe alone: the anchor is `codex)      ( cd`, which only smoke_turn has.
awk -v arm="$tmpd/nopin-arm.txt" '
  skip { if ($0 ~ /;;[[:space:]]*$/) skip=0; next }
  /^    codex\)      \( cd / { while ((getline l < arm) > 0) print l; close(arm); skip=1; next }
  { print }
' "$HERE/tests/harness-conformance.sh" > "$tmpd/nopin/tests/harness-conformance.sh"
if bash -n "$tmpd/nopin/tests/harness-conformance.sh" 2>/dev/null \
  && grep -qF 'codex exec --skip-git-repo-check -s workspace-write "$prompt"' "$tmpd/nopin/tests/harness-conformance.sh" \
  && ! grep -qF 'model_provider=\"$CODEX_PROVIDER\"' "$tmpd/nopin/tests/harness-conformance.sh"; then
  out=$(runb_codex "$tmpd/nopin/tests/harness-conformance.sh" "$tmpd/codexpin/nopin.argv" 1)
  if [ -s "$tmpd/codexpin/nopin.argv" ] \
    && ! grep -qF 'model_provider' "$tmpd/codexpin/nopin.argv" \
    && ! grep -qF -- '-m fixture-codex-model' "$tmpd/codexpin/nopin.argv"; then
    say "  PASS  the pin-removed control records an argv with no model_provider -> the arm above can fail"
  else
    say "  FAIL  the pin-removed control still recorded a pinned argv: $(tr '\n' ' ' < "$tmpd/codexpin/nopin.argv" 2>/dev/null)"
    fails=$((fails+1))
  fi
else
  say "  FAIL  could not splice the pre-CF-227 codex arm into a scratch copy"; fails=$((fails+1))
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
# ch:trace row=CF-289 spec=docs/handbook/OUTLINE.md#M1-PROVISIONING wave=none:serial-worker test=tests/selftest.sh::CF-289-node-json-union doc=docs/handbook/chapters/M1-provisioning.md evidence=tests/selftest.sh witness=none:local-fixture verdict=none:foreman-will-run-gitreins commit=none:worker-commit memory=none:foreman-closeout
# CF-289: ~/.node/node.json has two writers. node_identity.py merges identity keys; layer 90 of
# project-node.sh used to REPLACE the document with its own schema, so a later --apply deleted
# `agent`, `namespace`, `duckbrain` and `provisioned_by` and still exited 0 (the node then had no
# agent for the bus: node-bus-worker.py reads node.json.agent). The arm below is the union after
# identity-then-apply; the second arm replays the SAME fixture against the pre-fix script and
# requires the loss, so the pair discriminates instead of asserting a shape both revisions print.
cf289_scripts() {  # $1 dest dir, $2 project-node.sh source
  mkdir -p "$1/harness"
  cp "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" "$1/"
  cp "$2" "$1/project-node.sh"
  cp "$tmpd/pn-scripts/harness/install-fixture.sh" "$1/harness/install-fixture.sh"
}
cf289_identity() {  # $1 home -> node_identity.py merges the identity keys an operator's step writes
  mkdir -p "$1/.node"
  printf '{"agent":"fixture"}\n' > "$1/.node/crier.json"
  chmod 600 "$1/.node/crier.json"
  python3 "$HERE/scripts/node_identity.py" "$1/.node/node.json" \
    agent=cf-289-fixture namespace=demo 'duckbrain.namespaces[]=demo,coder' \
    'bus.channel=fleet-ops' provisioned_by=bunker-provision \
    provisioned_at=2026-11-09T00:00:00Z >/dev/null 2>&1
}
cf289_apply() {  # $1 scripts dir, $2 fresh home -> project-node.sh --apply output+rc
  git clone -q "$tmpd/origin.git" "$2/repo"
  cf289_identity "$2"
  env PATH="$tmpd/bin:$PATH" HOME="$2" NODE_PROJECT=demo NODE_HARNESS=fixture \
    CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
    /bin/bash "$1/project-node.sh" --apply --project demo --harness fixture 2>&1
}
cf289_scripts "$tmpd/pn-union" "$HERE/scripts/project-node.sh"
out=$(cf289_apply "$tmpd/pn-union" "$tmpd/union"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS' \
  && [ "$(stat -c '%a' "$tmpd/union/.node/node.json")" = 600 ] \
  && python3 -B - "$tmpd/union/.node/node.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
# every key the identity writer merged survives the ladder's own write
for key, value in (("agent", "cf-289-fixture"), ("namespace", "demo"),
                   ("provisioned_by", "bunker-provision"),
                   ("provisioned_at", "2026-11-09T00:00:00Z")):
    assert d.get(key) == value, (key, d.get(key))
assert d["duckbrain"]["namespaces"] == ["demo", "coder"], d.get("duckbrain")
assert d["bus"]["channel"] == "fleet-ops", d.get("bus")
assert d["bus"]["base"] == "http://fixture.invalid:8767", d.get("bus")
# and every key the ladder owns is still written
for key in ("node_id", "project", "repo", "harness", "freshness", "created_by", "created_at"):
    assert key in d, "ladder key missing: %s" % key
assert d["project"] == "demo"
assert d["harness"]["name"] == "fixture"
assert d["freshness"]["status"] == "PASS", d.get("freshness")
PY
then
  say "  PASS  CF-289-node-json-union — identity-then-apply leaves agent/namespace/duckbrain/provisioned_by AND the ladder's keys (mode 600, exit $rc)"
else
  say "  FAIL  CF-289-node-json-union — the union was not preserved after --apply (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
  [ -r "$tmpd/union/.node/node.json" ] && python3 -B -c 'import json,sys;print("keys:",sorted(json.load(open(sys.argv[1])).keys()))' "$tmpd/union/.node/node.json" | sed 's/^/    | /'
fi
# The red control: the SAME fixture against the script this row was raised on. It must exit 0
# (the loss was silent) and must NOT carry the identity keys — otherwise the arm proves nothing.
if git -C "$HERE" show 23114f4:scripts/project-node.sh > "$tmpd/pn-prefix-src.sh" 2>/dev/null; then
  cf289_scripts "$tmpd/pn-prefix" "$tmpd/pn-prefix-src.sh"
  rout=$(cf289_apply "$tmpd/pn-prefix" "$tmpd/prefix"); rrc=$?
  if [ "$rrc" -eq 0 ] && printf '%s\n' "$rout" | grep -Fxq 'NODE: PASS' \
    && python3 -B - "$tmpd/prefix/.node/node.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
lost = [k for k in ("agent", "namespace", "duckbrain", "provisioned_by") if k not in d]
assert lost == ["agent", "namespace", "duckbrain", "provisioned_by"], lost
assert "node_id" in d and "harness" in d, sorted(d)
PY
  then
    say "  PASS  pre-fix 23114f4 exits 0 while deleting agent/namespace/duckbrain/provisioned_by — this arm discriminates"
  else
    say "  FAIL  pre-fix 23114f4 did not lose the identity keys (exit $rrc) — the union arm proves nothing"; fails=$((fails+1))
    printf '%s\n' "$rout" | sed 's/^/    | /'
  fi
else
  say "  FAIL  pre-fix source unavailable (git show 23114f4:scripts/project-node.sh)"; fails=$((fails+1))
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

# --- node_seed.py: apply preserves local edits unless --force (CF-288) -------------------------
# The failure this closes: apply_seed() used to rmtree prompts/ and skills/
# before copying, so a hand-written or hand-edited file on the node was
# deleted or overwritten with no per-path report. Without --force the node
# must keep every file it would lose or mutate, and name each one, by path.

say ""
say "node_seed - apply is non-destructive unless --force (CF-288)"

seed_nt=$(mktemp -d); seed_home288=$(mktemp -d)
SEED_REPO="$(cd "$(dirname "$0")/.." && pwd)"
out=$(python3 -B "$SEED" build --manifest "$SEED_MANIFEST" --repo-root "$SEED_REPO" --out "$seed_nt/seed.tar" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$seed_nt/seed.tar.json" ]; then
  say "  PASS  CF-288 fixture seed built (exit $rc)"
else
  say "  FAIL  CF-288 fixture seed did not build (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# (a): a fresh apply into an empty home lands the seed.
out=$(python3 -B "$SEED" apply --tar "$seed_nt/seed.tar" --record "$seed_nt/seed.tar.json" --home "$seed_home288" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$seed_home288/.hermes/prompts/foreman.md" ]; then
  say "  PASS  CF-288 fixture fresh apply landed a seed (exit $rc)"
else
  say "  FAIL  CF-288 fixture fresh apply did not land a seed (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# (b): a local edit to a seeded prompt, plus a note the seed never shipped.
printf '\n# local edit CF-288\n' >> "$seed_home288/.hermes/prompts/foreman.md"
printf '# a note nobody seeded\n' > "$seed_home288/.hermes/prompts/local-notes.md"

# (c): re-apply WITHOUT --force keeps both local files and names each one.
out=$(python3 -B "$SEED" apply --tar "$seed_nt/seed.tar" --record "$seed_nt/seed.tar.json" --home "$seed_home288" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && grep -q 'local edit CF-288' "$seed_home288/.hermes/prompts/foreman.md" \
  && [ -f "$seed_home288/.hermes/prompts/local-notes.md" ] \
  && printf '%s\n' "$out" | grep -Fq 'preserved prompts/foreman.md' \
  && printf '%s\n' "$out" | grep -Fq 'preserved prompts/local-notes.md'; then
  say "  PASS  re-apply without --force preserves a changed prompt and a local note, naming both (exit $rc)"
else
  say "  FAIL  re-apply without --force did not preserve local edits or name them (exit $rc)"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# (d): re-apply WITH --force replaces the prompt wholesale and names it.
out=$(python3 -B "$SEED" apply --tar "$seed_nt/seed.tar" --record "$seed_nt/seed.tar.json" --home "$seed_home288" --force 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && ! grep -q 'local edit CF-288' "$seed_home288/.hermes/prompts/foreman.md" \
  && printf '%s\n' "$out" | grep -Fq 'changed prompts/foreman.md'; then
  say "  PASS  re-apply with --force overwrites the changed prompt and names it (exit $rc)"
else
  say "  FAIL  re-apply with --force did not overwrite the local edit or name it (exit $rc)"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

rm -rf "$seed_nt" "$seed_home288"

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

# CF-291: step 6 could not move the verdict. A seed the leg could not measure printed a WARN row
# and then fell through to `VERIFY: PASS` (exit 0) at the bottom of scripts/verify-node.sh, so a
# node carrying a 0-byte seed-applied.json — or no record at all — was certified by the gate, and
# the same fixture passed under --strict-seed only because that flag takes a different branch.
# These arms drive the REAL verifier over a fixture node: stub bunker runs the "remote" command
# locally, stub curl answers the two gateway reads, and the fixture home carries the applied
# record AND a real checkout level with its origin — so steps 1-5 are green and the seed leg is
# the only thing any arm below can move.
vn=$(mktemp -d)
mkdir -p "$vn/bin" "$vn/tree" "$vn/before" "$vn/home/.hermes"
cp -r "$HERE/scripts" "$vn/tree/scripts"
rm -rf "$vn/tree/scripts/__pycache__"
cp -r "$vn/tree/scripts" "$vn/before/scripts"
# The control is the immutable source at 436def5 — the verifier as it stood before this row — not a
# stub of the defect: its siblings are byte-identical to the tree under test, so the ONLY difference
# between the two runs is the verdict the gate reaches on the same unmeasurable seed.
git -C "$HERE" show 436def5:scripts/verify-node.sh > "$vn/before/scripts/verify-node.sh"
prefix_rc=$?
cat > "$vn/bin/bunker" <<'EOF'
#!/usr/bin/env bash
printf 'exec\n' >> "${FIXTURE_LOG:?}"
exec bash -c "${!#}"
EOF
cat > "$vn/bin/curl" <<'EOF'
#!/usr/bin/env bash
o="" u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) o="$2"; shift 2 ;;
    -*) shift ;;
    *) u="$1"; shift ;;
  esac
done
case "$u" in */api/system/stats) c=401 ;; *) c=200 ;; esac
if [ -n "$o" ] && [ "$o" != /dev/null ]; then
  printf '%s' '{"status":"ok","auth_required":true}' > "$o"
fi
printf '%s' "$c"
EOF
chmod +x "$vn/bin/bunker" "$vn/bin/curl"
# The node home: the fixture seed applied by the REAL seeder (same tar the arms above built), and a
# clean checkout level with origin so step 5 PASSes instead of warning.
python3 -B "$SEED" apply --tar "$tmpd/seed.tar" --record "$tmpd/seed.tar.json" --home "$vn/home" >/dev/null 2>&1
git init -q -b main --bare "$vn/origin.git"
git clone -q "$vn/origin.git" "$vn/home/repo" 2>/dev/null
git -C "$vn/home/repo" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
git -C "$vn/home/repo" push -q -u origin main
git -C "$vn/home/repo" fetch -q origin
vn_run() {  # vn_run <tree-with-scripts> [verify-node args...]: the fixture home is the "node"
  local tree="$1"; shift
  env PATH="$vn/bin:$PATH" FIXTURE_LOG="$vn/bunker.log" HOME="$vn/home" \
    /bin/bash "$tree/scripts/verify-node.sh" --agent cf-fixture --server fixture "$@" 2>&1
}
vn_rec="$vn/home/.hermes/seed-applied.json"
# A pristine copy of the record: the corrupt arm overwrites the live one, so the absent arm's
# `mv` backup would restore a corrupt record and the green control could never go green.
cp "$vn_rec" "$vn/good-record.json"

# green: the fixture node is verifiable, so every arm below has something to move.
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  seed_drift — ' \
  && printf '%s\n' "$out" | grep -Fq '2 seeded files present and matching' \
  && printf '%s\n' "$out" | grep -Eq '^  PASS  checkout_freshness'; then
  say "  PASS  a node whose seed matches its record -> VERIFY: PASS, exit $rc (the fixture can go green)"
else
  say "  FAIL  the fixture node did not verify (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# empty record (AC 2): 0 bytes is not a passed seed, it is an unmeasured one.
: > "$vn_rec"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Fq '  WARN  seed_drift — the seed record at ' \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED — seed_drift: the seed record at ' \
  && printf '%s\n' "$out" | grep -Fq "$vn_rec" \
  && printf '%s\n' "$out" | grep -Fq 'does not parse' \
  && ! printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS'; then
  say "  PASS  a 0-byte seed record -> exit $rc, VERIFY: UNVERIFIED naming seed_drift (not a PASS)"
else
  say "  FAIL  an empty seed record did not end UNVERIFIED (exit $rc): $(printf '%s\n' "$out" | grep -E '^VERIFY|seed_drift' | head -3 | tr '\n' ' ')"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# pre-fix control: the SAME fixture through 436def5 must pass, or these arms prove nothing.
if [ "$prefix_rc" -eq 0 ]; then
  out=$(vn_run "$vn/before"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
    && printf '%s\n' "$out" | grep -Fq '  WARN  seed_drift — '; then
    say "  PASS  pre-fix 436def5 certifies the same unmeasured seed: VERIFY: PASS, exit $rc (the fixture detects CF-291)"
  else
    say "  FAIL  pre-fix 436def5 control did not pass the unmeasured seed (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
else
  say "  FAIL  pre-fix source 436def5:scripts/verify-node.sh unavailable"; fails=$((fails+1))
fi

# corrupt record: not JSON at all — same verdict, and the reason names the record.
printf 'this is not a seed record\n' > "$vn_rec"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED — seed_drift: the seed record at ' \
  && printf '%s\n' "$out" | grep -Fq "$vn_rec" \
  && printf '%s\n' "$out" | grep -Fq 'does not parse' \
  && ! printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS'; then
  say "  PASS  an unparseable seed record -> exit $rc, VERIFY: UNVERIFIED naming seed_drift and the path"
else
  say "  FAIL  a corrupt seed record did not end UNVERIFIED (exit $rc): $(printf '%s\n' "$out" | grep -E '^VERIFY|seed_drift' | head -3 | tr '\n' ' ')"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# CF-379: a record that PARSES but declares no files. node_seed.py check prints `0 files present
# and matching` and exits 0 for it, so the wrapper's PASS branch — "the seeder exited 0 with a
# parseable count" — certified a node whose seed applied nothing. The record is not UNMEASURABLE:
# it was read and it is conclusively empty, so the verdict is a named FAIL on the empty collection.
printf '{"files": []}' > "$vn_rec"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — ' \
  && printf '%s\n' "$out" | grep -Fq 'the record declares no files' \
  && printf '%s\n' "$out" | grep -Fq 'the files collection is empty' \
  && ! printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS'; then
  say "  PASS  a seed record that declares no files -> exit $rc, VERIFY: FAIL naming the empty collection (not a PASS)"
else
  say "  FAIL  an empty seed record was not a named FAIL (exit $rc): $(printf '%s\n' "$out" | grep -E '^VERIFY|seed_drift' | head -3 | tr '\n' ' ')"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# The CF-379 control: the SAME empty record through the checker at 226bae2 — the row's measured
# premise commit — inside the SAME verifier must still reach VERIFY: PASS and print `0 seeded files
# present and matching`. Without it the arm above could be green on a fixture that refuses every
# seed. Spliced from the pre-fix revision, not hand-written: `declared_files()` does not exist there,
# so there is no refusal to weaken and the control cannot drift into a stub of the fix.
vn_pfx="$vn/prefix-cf379/scripts"
mkdir -p "$vn_pfx"
cp -r "$vn/tree/scripts/." "$vn_pfx/"
if git -C "$HERE" show 226bae2:scripts/node_seed_drift.py > "$vn_pfx/node_seed_drift.py" 2>/dev/null; then
  if cmp -s "$vn_pfx/node_seed_drift.py" "$vn/tree/scripts/node_seed_drift.py"; then
    say "  FAIL  the CF-379 control is not a pre-fix checker — byte-identical to the tree under test"; fails=$((fails+1))
  else
    out=$(vn_run "$vn/prefix-cf379"); rc=$?
    if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
      && printf '%s\n' "$out" | grep -Fq '0 seeded files present and matching'; then
      say "  PASS  pre-fix 226bae2 certifies the same empty record: VERIFY: PASS, exit $rc (the fixture detects CF-379)"
    else
      say "  FAIL  pre-fix 226bae2 control did not pass the empty record (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
  fi
else
  say "  FAIL  pre-fix source 226bae2:scripts/node_seed_drift.py unavailable"; fails=$((fails+1))
fi

# Green control for the two arms above: the record restored — its two seeded files still match —
# must reach VERIFY: PASS again, naming a count greater than zero. A red that cannot go green
# proves nothing, and this is the count a pass is supposed to look like.
cp "$vn/good-record.json" "$vn_rec"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fq '2 seeded files present and matching'; then
  say "  PASS  the record restored with its 2 seeded files -> VERIFY: PASS, exit $rc (a pass names a count above zero)"
else
  say "  FAIL  the restored two-file record did not verify (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# absent record: no seed was ever applied — unmeasured, so the gate refuses to call it verified.
mv "$vn_rec" "$vn/record.bak"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED — seed_drift: no seed record at ' \
  && printf '%s\n' "$out" | grep -Fq "$vn_rec" \
  && ! printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS'; then
  say "  PASS  an absent seed record -> exit $rc, VERIFY: UNVERIFIED naming seed_drift and the path"
else
  say "  FAIL  an absent seed record did not end UNVERIFIED (exit $rc): $(printf '%s\n' "$out" | grep -E '^VERIFY|seed_drift' | head -3 | tr '\n' ' ')"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# the strict path keeps its wording: an unknown seed is a FAIL, never an UNVERIFIED.
out=$(vn_run "$vn/tree" --strict-seed); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — no seed record at ' \
  && printf '%s\n' "$out" | grep -Fq 'an unknown seed is not a pass'; then
  say "  PASS  an absent record under --strict-seed is still a FAIL, exit $rc (wording preserved)"
else
  say "  FAIL  --strict-seed no longer refuses the absent record as a FAIL (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# one owning source (QA-CODE-FACTORY-2): the sentence may live in the checker, never again in the
# verifier — a second copy is what drifted. Count the tracked scripts, not the fixtures.
owners=$(grep -rlF --include='*.py' --include='*.sh' 'an unknown seed is not a pass' "$HERE/scripts" 2>/dev/null \
  | sed -e "s|^$HERE/scripts/||" | paste -sd ',' -)
if [ "$owners" = "node_seed_drift.py" ]; then
  say "  PASS  the strict-seed sentence has one owning source: scripts/$owners"
else
  say "  FAIL  the strict-seed sentence is not owned by exactly one file (found in: ${owners:-nowhere})"
  fails=$((fails+1))
fi

# the OTHER strict branch of the seed leg: an ABSENT record reaches the checker's own exit 1, so the
# verifier quotes the checker's row and the wording is the checker's by construction (arm above). A
# record that does not parse (here: 0 bytes) is EXIT_UNMEASURABLE = 3 whatever --strict-seed says, so
# the verifier writes that FAIL row ITSELF — and the sentence re-typed there had lost the word `seed`
# (`unknown is not a pass`), which made this suite's phrase arm depend on WHICH branch the seed leg
# happened to take. `does not parse` only appears in the checker's WARN detail, so asserting it also
# proves the run took exit 3 and not exit 1: this arm drives the divergent branch on purpose.
: > "$vn_rec"
out=$(vn_run "$vn/tree" --strict-seed); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — ' \
  && printf '%s\n' "$out" | grep -Fq 'does not parse' \
  && printf '%s\n' "$out" | grep -Fq 'an unknown seed is not a pass'; then
  say "  PASS  a 0-byte record under --strict-seed -> exit $rc, FAIL via the verifier's exit-3 branch with the checker's sentence"
else
  say "  FAIL  the exit-3 strict branch lost the checker's sentence (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# seeded negative for the arm above: mutate the ONE owning sentence in a scratch copy of the tree and
# the same run must lose the phrase. Without it the arm could be greening on a sentence that came
# from somewhere else and nobody would know the instrument was blind.
vn_mut="$vn/mutant"
mkdir -p "$vn_mut"
cp -r "$vn/tree/scripts" "$vn_mut/scripts"
sed -e 's/an unknown seed is not a pass/an unknown is not a pass/' \
  "$vn/tree/scripts/node_seed_drift.py" > "$vn_mut/scripts/node_seed_drift.py"
if cmp -s "$vn/tree/scripts/node_seed_drift.py" "$vn_mut/scripts/node_seed_drift.py"; then
  say "  FAIL  the seeded negative mutated nothing — the arm above would prove nothing"; fails=$((fails+1))
else
  : > "$vn_rec"
  out=$(vn_run "$vn_mut" --strict-seed); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
    && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — ' \
    && ! printf '%s\n' "$out" | grep -Fq 'an unknown seed is not a pass'; then
    say "  PASS  a scratch tree whose single source lost the phrase -> the arm above goes red (exit $rc, phrase absent)"
  else
    say "  FAIL  the phrase arm cannot fail: a mutated source still greened it (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
fi
# the record is restored here because the arms below (missing seeder, then the green re-run) expect a
# readable one; the sibling arms above restore the same way, from the pristine copy.
cp "$vn/good-record.json" "$vn_rec"

# the seeder itself gone: nothing could stage a check, and that is a named FAIL, not a warning.
mv "$vn/tree/scripts/node_seed_drift.py" "$vn/node_seed_drift.py.bak"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)' \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  seed_drift — ' \
  && printf '%s\n' "$out" | grep -Fq 'node_seed_drift.py missing'; then
  say "  PASS  a missing seeder -> exit $rc, VERIFY: FAIL naming the unmeasured seed"
else
  say "  FAIL  a missing seeder did not fail the gate (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# green again: restore the seeder and the record — the arms can go green, not only red.
mv "$vn/node_seed_drift.py.bak" "$vn/tree/scripts/node_seed_drift.py"
cp "$vn/good-record.json" "$vn_rec"
out=$(vn_run "$vn/tree"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fq '2 seeded files present and matching'; then
  say "  PASS  seeder and record restored -> VERIFY: PASS, exit $rc again (the arms can go green)"
else
  say "  FAIL  the restored fixture did not verify (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# CF-270 — the port reached the remote shell. `--port` was taken verbatim into PORT and then
# expanded LOCALLY inside a double-quoted string that was handed to a REMOTE `bash -lc`, so
#   --port "10800'; touch <path>; echo '"
# ran code on the node (measured: the remote command became
#   ... 'http://127.0.0.1:10800'; touch /tmp/cf270-canary; echo '/api/status').
# The stub below RECORDS the argv it is handed and never executes it: what matters is the command
# the remote shell would have received, not what it would have done. Three arms plus the pre-fix
# red control, so a green here can go red. Part of section 48, where the verifier fixture lives:
# no new numbered section and no census change (arms_tree stays 57), the CF-230 precedent.
say "  ..  CF-270: --port is a port or a usage error, and it reaches the node as an argument"
cf270=$(mktemp -d)
mkdir -p "$cf270/bin" "$cf270/tree" "$cf270/home"
cp -r "$HERE/scripts" "$cf270/tree/scripts"
rm -rf "$cf270/tree/scripts/__pycache__"
canary="$cf270/cf270-canary"
cat > "$cf270/bin/bunker" <<'EOF'
#!/usr/bin/env bash
# CF-270: record the argv, never run it.
printf '%s\n' "$*" >> "${FIXTURE_LOG:?}"
printf 'ALIVE fixture-node\n'
EOF
cat > "$cf270/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '000'
EOF
chmod +x "$cf270/bin/bunker" "$cf270/bin/curl"
cf270_run() {  # cf270_run <port>: a fresh record per run, the REAL verifier, stub transport
  : > "$cf270/remote.log"
  env PATH="$cf270/bin:$PATH" FIXTURE_LOG="$cf270/remote.log" HOME="$cf270/home" \
    /bin/bash "$cf270/tree/scripts/verify-node.sh" --agent cf-fixture --server fixture \
    --port "$1" 2>&1
}

# AC2 (a): a non-numeric port is a usage error, refused before the first remote invocation.
out=$(cf270_run not-a-port); rc=$?
if [ "$rc" -eq 2 ] && [ ! -s "$cf270/remote.log" ] && [ ! -e "$canary" ] \
  && [ "$(printf '%s\n' "$out" | grep -cF -- 'verify-node: --port must be digits 1-65535 (got: not-a-port)')" = 1 ] \
  && ! printf '%s\n' "$out" | grep -q 'VERIFY:'; then
  say "  PASS  CF-270 --port not-a-port -> exit $rc, stderr names --port, 0 recorded remote invocations"
else
  say "  FAIL  CF-270 a non-numeric --port was not refused before the first remote call (exit $rc, $(grep -ac . "$cf270/remote.log") recorded)"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# AC2 (b): the boundary. 1..65535 is the whole legal range, so 0, 65536, an empty value and a
# padded value are refused by the same rule, and none of them reaches the transport.
cf270_bad=""
for cf270_port in 0 65536 "" " 10800"; do
  out=$(cf270_run "$cf270_port"); rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$cf270/remote.log" ] \
    && printf '%s\n' "$out" | grep -qF -- 'verify-node: --port must be digits 1-65535 (got: '; then :; else
    cf270_bad="${cf270_bad:+$cf270_bad, }'$cf270_port' (exit $rc, $(grep -ac . "$cf270/remote.log") recorded)"
  fi
done
if [ -z "$cf270_bad" ]; then
  say "  PASS  CF-270 --port 0 / 65536 / empty / ' 10800' -> exit 2 each, 0 recorded remote invocations"
else
  say "  FAIL  CF-270 out-of-range --port accepted: $cf270_bad"
  fails=$((fails+1))
fi

# AC2 (c): the measured exploit. Pre-fix this value closed the single quotes of the remote curl
# URL and `touch` ran on the node; now it never leaves this host.
inject="10800'; touch $canary; echo '"
out=$(cf270_run "$inject"); rc=$?
if [ "$rc" -eq 2 ] && [ ! -s "$cf270/remote.log" ] && [ ! -e "$canary" ] \
  && printf '%s\n' "$out" | grep -qF -- 'verify-node: --port must be digits 1-65535 (got: ' \
  && ! printf '%s\n' "$out" | grep -q 'VERIFY:'; then
  say "  PASS  CF-270 injection --port -> exit $rc, refused before the first remote call, canary never created"
else
  say "  FAIL  CF-270 the injection --port was not refused (exit $rc, $(grep -ac . "$cf270/remote.log") recorded, canary $([ -e "$canary" ] && echo CREATED || echo absent))"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
fi

# Control: a real port still runs the legs, and it reaches the remote shell as POSITIONAL DATA —
# the recorded body is the FIXED single-quoted script plus `_ 10800 <path>`, never a locally
# expanded URL — so this is a hardening, not a blanket refusal.
out=$(cf270_run 10800); rc=$?
inside_recs=$(grep -acF -- '"http://127.0.0.1:$1$2" _ 10800 /' "$cf270/remote.log")
if [ "$rc" -eq 3 ] && [ "$inside_recs" -eq 2 ] \
  && grep -aFq -- '_ 10800 /api/status' "$cf270/remote.log" \
  && grep -aFq -- '_ 10800 /api/system/stats' "$cf270/remote.log" \
  && ! grep -aFq 'cf270-canary' "$cf270/remote.log" \
  && ! grep -aFq "127.0.0.1:10800'" "$cf270/remote.log" \
  && printf '%s\n' "$out" | grep -Eq '^  PASS  agent_alive' \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED — '; then
  say "  PASS  CF-270 --port 10800 -> both inside legs run, port and path travel as arguments, no canary in any command"
else
  say "  FAIL  CF-270 a valid --port no longer runs the legs as positional data (exit $rc, $inside_recs inside call(s))"
  fails=$((fails+1)); printf '%s\n' "$out" | sed 's/^/    | /'
  sed 's/^/    rec| /' "$cf270/remote.log"
fi

# Pre-fix red control: the same value through the pre-fix body must put the canary INSIDE the
# recorded remote command, or the arms above prove nothing. The body is a copy of the `inside()`
# the verifier carried at 2f070b0 — unchanged except that PORT and the path are its arguments.
cat > "$cf270/prefix-inside.sh" <<'EOF'
#!/usr/bin/env bash
inside() { bunker exec --server "${SERVER:-fixture}" "${AGENT:-cf-fixture}" -- bash -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 5 'http://127.0.0.1:$PORT$1'" 2>/dev/null; }
PORT="$1"
inside "$2"
EOF
: > "$cf270/remote.log"
env PATH="$cf270/bin:$PATH" FIXTURE_LOG="$cf270/remote.log" \
  bash "$cf270/prefix-inside.sh" "$inject" /api/status >/dev/null 2>&1
if [ -s "$cf270/remote.log" ] && [ ! -e "$canary" ] \
  && grep -aFq -- "; touch $canary; echo '/api/status'" "$cf270/remote.log" \
  && ! grep -aFq -- ' _ 10800' "$cf270/remote.log"; then
  say "  PASS  CF-270 pre-fix inside() interpolates the port: the canary IS in the recorded remote command (the fixture detects the defect)"
else
  say "  FAIL  CF-270 the pre-fix body did not reproduce the interpolation — these arms would pass vacuously"
  fails=$((fails+1)); sed 's/^/    | /' "$cf270/remote.log"
fi
rm -rf "$cf270"

rm -rf "$vn"
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
# CF-257: every module filled before 2026-11-05 carries a `VERIFIED — ` Status row from the
# earlier accepted-output writer (37 of them on the real tree), and one module carries the bare
# `**VERIFIED**` form. The template's RED string stays in their bodies, exactly as a real fill
# leaves it — so a selector that tests the body re-fills documents it already completed.
for name, row in (
    ("04-verified.md", "**VERIFIED — 2 sections, 1 locator, fixture-api, 2026-11-05 UTC**"),
    ("05-bare-verified.md", "**VERIFIED**"),
):
    (master / name).write_text(
        text.replace("| Status | **RED — no verification recorded** |", f"| Status | {row} |")
    )

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
# CF-257 regression: a module whose single Status row starts with `**VERIFIED — ` — or with the
# bare `**VERIFIED**` — is complete. On the pre-fix selector both were candidates, so every run
# re-filled the 37 modules the older writer had already verified and the program never converged.
marker_leaks=
for name in 04-verified.md 05-bare-verified.md; do
  printf '%s\n' "$out" | grep -Fxq "candidate $name" && marker_leaks="$marker_leaks $name"
done
if [ -z "$marker_leaks" ]; then
  say "  PASS  VERIFIED and bare VERIFIED Status rows are complete, never candidates"
else
  say "  FAIL  a completed module is still selected:$marker_leaks"; fails=$((fails+1))
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
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^todo=4 ' \
  && [ "$(printf '%s\n' "$out" | grep -c '^candidate ')" = 4 ] \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 01-first.md' \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 02-second.md' \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 04-verified.md' \
  && printf '%s\n' "$out" | grep -Fxq 'candidate 05-bare-verified.md' \
  && ! printf '%s\n' "$out" | grep -Fxq 'candidate 00-INDEX.md' \
  && ! printf '%s\n' "$out" | grep -Fxq 'candidate 03-not-a-module.md'; then
  say "  PASS  --force selects all four modules, VERIFIED ones included, never the non-modules"
else
  say "  FAIL  --force selection (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out"
fi
rm -rf "$tmpd"
# CF-374: the checker's default root was the literal "docs/master", which the Apollo re-arrange
# removed from the tree, so its glob matched nothing and one run printed "0 module(s): 0 VERIFIED,
# 0 error(s)" together with "MASTER-DOC: PASS". A gate whose empty case is green cannot catch the
# locator/FACT drift it exists for. The three arms below pin the fixed behaviour, each of them a
# that-command-succeeds assertion so this block can go red rather than print a shape.
# Part of section 52: no new numbered section and no census change (arms_tree stays 55), like the
# CF-230 block in section 12. A numbered section would force a docs/ACCEPTANCE-PLAN.md mapping row
# and the prose arm count with it (docs/audits/cf198-section-mapping.sh), and this row may not
# touch docs/.
# BEGIN master-doc-reachability
say "  section 52 reachability (CF-374): the checker resolves its root and refuses a zero-module pass"
tmpd=$(mktemp -d)
# arm 1: no candidate root exists -> one named FAIL per candidate tried, non-zero, never PASS.
mkdir -p "$tmpd/bare"
out=$(env -u CF_MASTER_DIR python3 "$HERE/scripts/master_doc_check.py" --repo "$tmpd/bare" 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -q '^   FAIL  no master doc root at .*docs/master$' \
  && printf '%s\n' "$out" | grep -q '^   FAIL  no master doc root at .*docs/handbook/appendices/units$' \
  && ! printf '%s\n' "$out" | grep -q 'MASTER-DOC: PASS'; then
  say "  PASS  absent root -> exit $rc, both candidate roots named, no PASS"
else
  say "  FAIL  absent root was not a named refusal (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# arm 2: a root that really holds one module still counts it, and can still pass. The module is
# built from the shipped shape: the eight required headings, the `| Status | **VERIFIED ...**` row,
# three locators that resolve inside the fixture repository, and one ledger fact it may cite.
fixture="$tmpd/one/docs/handbook/appendices/units"
mkdir -p "$fixture"
printf '# fixture source line one\n# fixture source line two\n# fixture source line three\n' \
  > "$tmpd/one/fixture_source.py"
cat > "$fixture/01-fixture.md" <<'MD'
# 01. fixture_source.py

| Field | Value |
|---|---|
| Path | `fixture_source.py` |
| Status | **VERIFIED - three locators and one ledger fact, measured on the fixture repo** |

## 1. Purpose and why it matters

The fixture module exists so the gate can be shown counting one real module rather than none.
It cites `fixture_source.py:1`, `fixture_source.py:2` and `fixture_source.py:3`.

## 2. Dependencies and library contracts

Standard library only; the fixture source is a three-line file the checker reads back.

## 3. Verification

The fixture was checked with the gate under test and cites `fact: FACT-01` from its ledger.

## 4. Metrics emitted

No metric is emitted; the only output is the gate summary line and its verdict.

## 5. Log lines it can generate

No levelled log line is generated; the module surface is the checker summary itself.

## 6. Failure modes

A missing section, a locator past the end of the fixture source, or an absent ledger fact reds.

## 7. Environment and settings it reads

No environment variable is read; the root is resolved from the repository argument.

## 8. Evidence of record

Every claim above comes from re-running the gate on this fixture directory, not a commit message.
MD
printf '| id | claim | how measured | measured at | confidence |\n|---|---|---|---|---|\n| FACT-01 | The fixture ledger carries exactly one fact | this file | 2026-11-06 | measured |\n' \
  > "$fixture/_facts.md"
out=$(env -u CF_MASTER_DIR python3 "$HERE/scripts/master_doc_check.py" --repo "$tmpd/one" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -q '^1 module(s): 1 VERIFIED' \
  && ! printf '%s\n' "$out" | grep -q '0 module(s)' \
  && printf '%s\n' "$out" | grep -q 'MASTER-DOC: PASS'; then
  say "  PASS  one-module root -> exit 0, summary reads 1 module(s)"
else
  say "  FAIL  one-module root did not count one module (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# arm 3: the red-proof for the vacuous case. The root exists, so resolution succeeds, but it holds
# no NN-*.md module: that must be a named FAIL against the resolved root, not a clean PASS.
mkdir -p "$tmpd/empty"
out=$(python3 "$HERE/scripts/master_doc_check.py" "$tmpd/empty" 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
  && printf '%s\n' "$out" | grep -q '^   FAIL  no module files (NN-\*.md) in the resolved root:' \
  && printf '%s\n' "$out" | grep -Fq "$tmpd/empty" \
  && printf '%s\n' "$out" | grep -q '^0 module(s):' \
  && ! printf '%s\n' "$out" | grep -q 'MASTER-DOC: PASS'; then
  say "  PASS  zero-module root -> exit $rc, FAIL names the root, 0 module(s), no PASS"
else
  say "  FAIL  zero-module root still reported itself healthy (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -rf "$tmpd"
# END master-doc-reachability
# END master-doc-selection

# CF-051: `--agent` is a REUSE, not a claim. Pre-fix, a supplied id was reported as reused without
# any check, so a nonexistent agent produced
#   PASS  spawn — reusing ghost-agent
# and work proceeded into staging; the operator only learned the truth from an unrelated
# downstream failure. Three arms share one PATH stub (no network, no real bunker): INFO_FAIL=1
# for the red arm, 0 for the green control, and the pre-fix revision re-run against the same
# fixture so the check keeps a demonstrable red. Every assertion names its row.
say "53. node-create refuses a --agent that does not exist, before any staging (CF-051)"
tmpd=$(mktemp -d)
mkdir -p "$tmpd/scripts/harness" "$tmpd/bin"
staged=$(bash "$HERE/scripts/node-create.sh" --staged-files); staged_rc=$?
if [ "$staged_rc" -eq 0 ]; then
  while IFS= read -r file; do
    cp "$HERE/scripts/$file" "$tmpd/scripts/$file" || fails=$((fails+1))
  done <<< "$staged"
else
  say "  FAIL  CF-051 fixture cannot stage the tree (manifest exit $staged_rc)"; fails=$((fails+1))
fi
cp "$HERE/scripts/node-create.sh" "$tmpd/scripts/" || fails=$((fails+1))
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpd/scripts/verify-node.sh"
chmod +x "$tmpd/scripts/verify-node.sh"
cat > "$tmpd/bin/bunker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  info)
    printf 'info %s\n' "${2:-}" >> "${FIXTURE_LOG:?}"
    [ "${FIXTURE_INFO_FAIL:-0}" = 0 ] || { echo "agent ${2:-}: no such agent" >&2; exit 1; }
    ;;
  spawn|cp|exec) printf '%s\n' "$*" >> "${FIXTURE_LOG:?}" ;;
  *) echo 'unexpected bunker command' >&2; exit 99 ;;
esac
EOF
chmod +x "$tmpd/bin/bunker"
# The stub records every invocation to FIXTURE_LOG, so a staging call is countable, not inferred.
cf051_run() {  # cf051_run <node-create path> <info-fails 0|1> <log>
  : > "$3"
  env -i HOME="$tmpd/control-home" PATH="$tmpd/bin:/usr/bin:/bin" BUNKER_SERVER=fixture-server \
    CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
    FIXTURE_INFO_FAIL="$2" FIXTURE_LOG="$3" \
    /bin/bash "$1" --project fixture --agent ghost-agent 2>&1
}
missing_row='  FAIL  agent — ghost-agent not found on fixture-server — spawn it (drop --agent) or pass an existing agent id'
reuse_row='  PASS  spawn — reusing ghost-agent'
# ARM 1 (red): the id does not exist -> one named FAIL naming id and remedy, exit 1, no staging.
out=$(cf051_run "$tmpd/scripts/node-create.sh" 1 "$tmpd/red.log"); rc=$?
if [ "$rc" -eq 1 ] \
  && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$missing_row")" = 1 ] \
  && ! printf '%s\n' "$out" | grep -Fq -- "$reuse_row" \
  && grep -aFq 'info ghost-agent' "$tmpd/red.log" \
  && ! grep -aEq '^(spawn|cp|exec)( |$)' "$tmpd/red.log" \
  && ! printf '%s\n' "$out" | grep -Eq 'unbound variable|^unexpected bunker command|line [0-9]+:'; then
  say "  PASS  missing --agent -> named FAIL agent, exit $rc, info probed, zero staging calls"
else
  say "  FAIL  missing --agent was not refused before staging (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
  sed 's/^/    log| /' "$tmpd/red.log"
fi
# ARM 2 (green control): the id exists -> the reuse row prints and staging is reached, so the new
# check is a real test, not a blanket refusal of --agent.
out=$(cf051_run "$tmpd/scripts/node-create.sh" 0 "$tmpd/green.log"); rc=$?
if [ "$rc" -eq 0 ] \
  && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$reuse_row")" = 1 ] \
  && ! printf '%s\n' "$out" | grep -Eq '^  FAIL  ' \
  && [ "$(grep -acE '^(spawn|cp|exec)( |$)' "$tmpd/green.log")" -gt 0 ] \
  && printf '%s\n' "$out" | grep -Fq 'NODE CREATED: ghost-agent'; then
  say "  PASS  existing --agent -> reuse row printed, staging reached, node created (exit $rc)"
else
  say "  FAIL  existing --agent was refused or never reached staging (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
# ARM 3 (pre-fix control): the same fixture against the revision the row was raised on must still
# print the false PASS and stage into the absent agent, or this section proves nothing.
mkdir -p "$tmpd/before"
cp -a "$tmpd/scripts/." "$tmpd/before/" 2>/dev/null
# Pair the pre-fix node-create.sh with the project-node.sh of the SAME revision: the staging
# manifest validator reads project-node.sh's $HERE references, and the current one now names
# node_gateway_auth.py (CF-150), which the pre-fix manifest does not stage — mixing revisions
# would fail the control for the wrong reason.
git -C "$HERE" show 943ef98:scripts/project-node.sh > "$tmpd/before/project-node.sh" 2>/dev/null || true
if git -C "$HERE" show 943ef98:scripts/node-create.sh > "$tmpd/before/node-create.sh" 2>/dev/null; then
  out=$(cf051_run "$tmpd/before/node-create.sh" 1 "$tmpd/before.log"); rc=$?
  if [ "$rc" -eq 0 ] \
    && printf '%s\n' "$out" | grep -Fxq -- "$reuse_row" \
    && [ "$(grep -acE '^(spawn|cp|exec)( |$)' "$tmpd/before.log")" -gt 0 ] \
    && ! printf '%s\n' "$out" | grep -Fq -- "$missing_row"; then
    say "  PASS  pre-fix revision reports the false reuse row and stages anyway (fixture detects CF-051)"
  else
    say "  FAIL  pre-fix control did not reproduce the false reuse (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
else
  say "  FAIL  pre-fix source unavailable (git show 943ef98:scripts/node-create.sh)"
  fails=$((fails+1))
fi
rm -rf "$tmpd"
# END cf051-agent-reuse

say "54. the bus worker decodes the wire directive member, and the pre-fix revision cannot (CF-354)"
# specs/ENVELOPE.md sends the directive as `text_b64`; this repo's node read only `text`, so every
# dispatch the scheduler actually sent was refused HERE with the `brief` row, and the fleet only
# worked because a dispatcher outside this repository decodes the member. The fixture asserts what
# the HARNESS RECEIVED, not what the worker said it would do: five arms, three of them the failure
# path, so a green here can go red. No network, no credential, everything under one mktemp -d.
cf354=$(mktemp -d)
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_bus_dispatch_encoding.py" \
     >"$cf354/out" 2>&1; then
  say "  PASS  text_b64 decoded to the harness bytes, legacy text still runs, corrupt text_b64 / absent instruction / base64 digest each refused"
else
  say "  FAIL  the dispatch encoding on the receiving side (tests/test_bus_dispatch_encoding.py)"
  fails=$((fails+1))
  sed 's/^/    | /' "$cf354/out"
fi
# ARM (red control): the SAME fixture against the revision this row was raised on. It must refuse
# the text_b64 dispatch with the named `brief` row — pointed at the fixed worker the control fails,
# so it discriminates rather than merely passing.
if git -C "$HERE" show 5b11bdc:scripts/node-bus-worker.py > "$cf354/node-bus-worker.py" 2>/dev/null; then
  if CF_BUS_WORKER_SOURCE="$cf354/node-bus-worker.py" CF_BUS_DISPATCH_PREFIX_CONTROL=1 \
       PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_bus_dispatch_encoding.py" \
       >"$cf354/prefix" 2>&1; then
    say "  PASS  pre-fix 5b11bdc refuses the text_b64 dispatch with the brief row (fixture detects CF-354)"
  else
    say "  FAIL  pre-fix control did not reproduce the brief refusal on a text_b64 dispatch"
    fails=$((fails+1))
    sed 's/^/    | /' "$cf354/prefix"
  fi
else
  say "  FAIL  pre-fix source unavailable (git show 5b11bdc:scripts/node-bus-worker.py)"
  fails=$((fails+1))
fi
rm -rf "$cf354"

# ch:trace row=CF-150 spec=specs/NODE.md#layer-20 test=tests/selftest.sh::gateway-basic-auth doc=docs/OPERATIONS.md prompt=none:worker-brief evidence=tests/selftest.sh::gateway-basic-auth witness=none:local-fixture verdict=none:foreman-verifies commit=none:self-referential-hash memory=none:foreman-owns
# BEGIN gateway-basic-auth
say "55. the create path stages dashboard.basic_auth before the adapter, and the gate still refuses without it (CF-150)"
# Layer 20 asks the Hermes adapter to start a PUBLIC bind; the adapter refuses that bind unless
# ~/.hermes/config.yaml parses to a non-empty dashboard.basic_auth, and NOTHING in the create path
# wrote it — so a freshly created node could never reach NODE: PASS (CF-150). The arms below are
# offline and touch no real HOME: one mktemp -d holds the stub bin, three node homes that start
# exactly where a fresh node starts, and a copy of the staged entry point.
#   staged  node-create.sh stages the producer that writes the block
#   A       the adapter still REFUSES a config without the block, and never starts serve
#   B       project-node.sh --apply --layers 20 stages a non-empty block and a mode-600 file,
#           and never prints the secret
#   C       the adapter in that staged home no longer prints the refusal: gateway_start PASSes
#   D       a dashboard block the producer cannot reconcile is a FAIL row the parent counts
cf150=$(mktemp -d)
cf150_python=$(command -v python3)
if python3 - "$cf150" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
(root / "bin").mkdir()
# The same stub surface section 10 (CF-071) measured: a python inside the pin's range, a venv
# hermes that reports the pin and records its own launch, an ss that sees no listener (so the
# adapter takes the start-the-gateway branch), and a curl that answers 200.
stubs = {
    "python": '#!/usr/bin/env bash\nif [ "$1" = --version ]; then echo \'Python 3.12.3\'; exit 0; fi\nexec "${CF150_PY:?}" "$@"\n',
    "hermes": '#!/usr/bin/env bash\nif [ "$1" = --version ]; then echo \'hermes 0.19.0\'; exit 0; fi\n[ "$*" = \'serve --host 0.0.0.0 --port 10800 --skip-build\' ] || exit 99\nprintf \'%s\\n\' \'serve launch reached\' > "${CF150_FIXTURE:?}/launch"\n',
    "ss": "#!/usr/bin/env bash\nexit 1\n",
    "nohup": '#!/usr/bin/env bash\nexec "$@"\n',
    "sleep": '#!/usr/bin/env bash\nfor ((i=0; i<100; i++)); do\n  [ ! -f "${CF150_FIXTURE:?}/launch" ] || exit 0\n  /bin/sleep 0.01\ndone\nexit 1\n',
    "curl": '#!/usr/bin/env bash\nprintf \'%s\' "${CF150_HTTP_CODE:?}"\n',
}
for name, text in stubs.items():
    path = root / "bin" / name
    path.write_text(text)
    path.chmod(0o755)
# A node home as a fresh node has it: a config with NO dashboard block (or one the producer must
# refuse), and the adapter's venv already at the pin — so --apply never reaches pip, no network.
for name, config in (
    ("refused-home", "model: {}\n"),
    ("staged-home", "model: {}\n"),
    ("conflict-home", "dashboard:\n  theme: dark\n"),
    ("listening-home", "model: {}\n"),
):
    home = root / name
    (home / ".hermes").mkdir(parents=True)
    (home / "hermes-venv/bin").mkdir(parents=True)
    (home / ".hermes/config.yaml").write_text(config)
    (home / "hermes-venv/bin/hermes").symlink_to(root / "bin/hermes")
    (home / "hermes-venv/bin/python").symlink_to(root / "bin/python")
# CF-192: a listener that this adapter did NOT start. The adapter's occupied-port branch greps
# `ss -tln` for ":<port> ", so this stub answers with a real LISTEN line (the shared `ss` above
# exits 1 and keeps every other arm on the not-listening path).
listen = root / "listen-bin"
listen.mkdir()
(listen / "ss").write_text(
    "#!/usr/bin/env bash\n"
    "printf '%s\\n' 'LISTEN 0 128 0.0.0.0:10800 0.0.0.0:*'\n"
    "exit 0\n"
)
(listen / "ss").chmod(0o755)
# The adapter's last counting row is inference_key. This home carries a dummy key (existence is all
# the row reads, the value is never used) so the ONLY row that can fail it is the port gate — that
# is what makes the pre-fix run reproduce the row's claim literally: PASS on a no-auth public bind.
(root / "listening-home/.hermes/.env").write_text("FIXTURE_API_KEY=fixture-not-a-key\n")
# The staged entry point, with a stub adapter: arm B proves the STAGING step, not the install
# ladder the adapter already owns.
tree = root / "tree/scripts"
(tree / "harness").mkdir(parents=True)
(tree / "harness/install-hermes.sh").write_text(
    '#!/usr/bin/env bash\n. "$(dirname "$0")/../lib.sh"\n'
    'ok "stub" "adapter reached"\nexit 0\n'
)
(tree / "harness/install-hermes.sh").chmod(0o755)
PY
then
  cf150_env() {  # cf150_env <home> <command...>
    rm -f "$cf150/launch"
    # CF150_BIN_PREFIX (optional) puts a stub dir ahead of the shared one — arm E uses it to swap
    # in the listening `ss` while every shared stub (python, hermes, curl, sleep) still resolves.
    env -i PATH="${CF150_BIN_PREFIX:+$CF150_BIN_PREFIX:}$cf150/bin:/usr/local/bin:/usr/bin:/bin" HOME="$1" \
      HERMES_PYTHON_BIN="$cf150/bin/python" HERMES_PIN=0.19.0 NODE_GATEWAY_PORT=10800 \
      CF150_PY="$cf150_python" CF150_FIXTURE="$cf150" CF150_HTTP_CODE=200 \
      NODE_PROJECT=fixture "${@:2}"
  }
  cp "$HERE/scripts/project-node.sh" "$HERE/scripts/lib.sh" "$HERE/scripts/disk_floor.py" \
     "$HERE/scripts/node_gateway_auth.py" "$cf150/tree/scripts/" || fails=$((fails+1))

  # ARM staged: the file the entry point runs is actually staged by node-create.sh. The manifest
  # validator derives that from project-node.sh's own $HERE references, so dropping
  # node_gateway_auth.py from the manifest turns this red.
  cf150_staged=$(bash "$HERE/scripts/node-create.sh" --staged-files 2>&1); cf150_staged_rc=$?
  if [ "$cf150_staged_rc" -eq 0 ] && printf '%s\n' "$cf150_staged" | grep -Fxq 'node_gateway_auth.py'; then
    say "  PASS  staged set carries node_gateway_auth.py ($(printf '%s\n' "$cf150_staged" | grep -c .) files)"
  else
    say "  FAIL  node_gateway_auth.py is not in the staged set (exit $cf150_staged_rc)"; fails=$((fails+1))
    printf '%s\n' "$cf150_staged" | sed 's/^/    | /'
  fi

  # ARM A: the negative control. Without the block the adapter refuses BY NAME, exits nonzero and
  # never launches serve — the gate this row must not weaken.
  out=$(cf150_env "$cf150/refused-home" /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  cf150_refusal='  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent'
  if [ "$rc" -ne 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$cf150_refusal")" = 1 ] \
    && [ ! -f "$cf150/launch" ]; then
    say "  PASS  no dashboard.basic_auth -> exit $rc, refusal named, serve never launched"
  else
    say "  FAIL  the adapter did not refuse a config without dashboard.basic_auth (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | grep -E 'PASS|FAIL' | tail -4 | sed 's/^/    | /'
  fi

  # ARM B: layer 20 stages the block BEFORE the adapter runs.
  out=$(cf150_env "$cf150/staged-home" /bin/bash "$cf150/tree/scripts/project-node.sh" \
    --apply --project fixture --layers 20 2>&1); rc=$?
  cf150_pass="  PASS  gateway_auth — dashboard.basic_auth present in $cf150/staged-home/.hermes/config.yaml; password in $cf150/staged-home/.node/auth/gateway.pass (mode 600, value not printed)"
  cf150_mode=$(stat -c '%a' "$cf150/staged-home/.node/auth/gateway.pass" 2>/dev/null || true)
  cf150_secret=$(cat "$cf150/staged-home/.node/auth/gateway.pass" 2>/dev/null || true)
  if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$cf150_pass")" = 1 ] \
    && grep -Eq '^    username: [^ ]' "$cf150/staged-home/.hermes/config.yaml" \
    && grep -Eq '^    password: [^ ]' "$cf150/staged-home/.hermes/config.yaml" \
    && [ "$cf150_mode" = 600 ] && [ -n "$cf150_secret" ] \
    && ! printf '%s' "$out" | grep -Fq -- "$cf150_secret"; then
    say "  PASS  layer 20 staged a non-empty basic_auth block and a mode $cf150_mode password file, secret never printed"
  else
    say "  FAIL  layer 20 did not stage the block (exit $rc, mode ${cf150_mode:-missing})"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi

  # ARM C: the gate is satisfied by what the staging step wrote — the refusal is gone and the
  # adapter reaches its gateway_start PASS. The run still exits 1 on inference_key (a fresh node
  # has no provider key yet), which is a different row from the refusal.
  out=$(cf150_env "$cf150/staged-home" /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  if [ "$(printf '%s\n' "$out" | grep -Fxc '  PASS  gateway_start — /api/status -> 200')" = 1 ] \
    && ! printf '%s\n' "$out" | grep -Fq 'refused: a public bind needs dashboard.basic_auth' \
    && [ "$(cat "$cf150/launch" 2>/dev/null)" = 'serve launch reached' ]; then
    say "  PASS  staged home: gateway_start PASSes, no refusal row, serve launched (exit $rc is inference_key)"
  else
    say "  FAIL  the staged home still refuses the public bind (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | grep -E 'PASS|FAIL' | tail -4 | sed 's/^/    | /'
  fi

  # ARM D: a dashboard block the producer cannot reconcile is a FAIL row the parent COUNTS, so
  # NODE: FAIL (n) stays truthful, and the node's own config is left untouched.
  out=$(cf150_env "$cf150/conflict-home" /bin/bash "$cf150/tree/scripts/project-node.sh" \
    --apply --project fixture --layers 20 2>&1); rc=$?
  if [ "$rc" -eq 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  gateway_auth — could not stage dashboard.basic_auth in ')" = 1 ] \
    && printf '%s\n' "$out" | grep -Fxq 'NODE: FAIL (1)' \
    && [ "$(cat "$cf150/conflict-home/.hermes/config.yaml")" = "$(printf 'dashboard:\n  theme: dark')" ]; then
    say "  PASS  a dashboard block without basic_auth -> one counted FAIL row, NODE: FAIL (1), config untouched"
  else
    say "  FAIL  the unreconcilable dashboard block was not a counted FAIL (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # ARM E (CF-192): an occupied port is NOT evidence that the bind is legal. Measured at the
  # unfixed revision: with a listener on :10800 and a config carrying NO dashboard.basic_auth,
  # `--apply` printed `PASS port` / `PASS status_probe` / `HERMES: PASS` and exited 0 — a
  # 127.0.0.1 probe answers on an unauthenticated 0.0.0.0 gateway too, so the occupied branch
  # skipped the one gate that makes a public bind legal. Two arms on the listening stub: E-red
  # (no auth) must name a FAIL port row and never certify; E-green (the staged home arm B already
  # gave basic_auth) must keep today's PASS rows — "fail on any listener" is not a fix.
  CF150_BIN_PREFIX="$cf150/listen-bin"
  out=$(cf150_env "$cf150/listening-home" /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  cf192_row='  FAIL  port — listening on :10800 (not started by this adapter; auth unverified — a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent)'
  if [ "$rc" -ne 0 ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$cf192_row")" = 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc 'HERMES: FAIL (1)')" = 1 ] \
    && ! printf '%s\n' "$out" | grep -Fq 'HERMES: PASS' \
    && ! printf '%s\n' "$out" | grep -Eq '^  PASS  (port|status_probe)' \
    && ! printf '%s\n' "$out" | grep -Eq 'unbound variable|^FAILED:' \
    && [ ! -f "$cf150/launch" ]; then
    say "  PASS  occupied :10800 without dashboard.basic_auth -> exit $rc, named FAIL port row, HERMES: FAIL (1), nothing certified"
    printf '%s\n' "$cf192_row"
  else
    say "  FAIL  an occupied :10800 with no dashboard.basic_auth was certified (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # E-green: the SAME listener with the block arm B staged. A gateway a previous --apply started
  # must still be certifiable; in this home only inference_key may fail.
  out=$(cf150_env "$cf150/staged-home" /bin/bash "$HERE/scripts/harness/install-hermes.sh" --apply 2>&1); rc=$?
  unset CF150_BIN_PREFIX
  if [ "$rc" -eq 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc '  PASS  port — listening on :10800')" = 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc '  PASS  status_probe — /api/status -> 200')" = 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -Fxc 'HERMES: FAIL (1)')" = 1 ]; then
    say "  PASS  occupied :10800 WITH dashboard.basic_auth keeps PASS port / PASS status_probe (only inference_key fails)"
  else
    say "  FAIL  the auth-carrying occupied port lost its PASS rows (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | grep -E 'PASS|FAIL' | tail -4 | sed 's/^/    | /'
  fi
  # ch:trace row=CF-388 spec=specs/NODE.md#layer-20 test=tests/selftest.sh::gateway-fresh-home doc=README.md prompt=none:worker-brief evidence=tests/selftest.sh::gateway-fresh-home witness=none:local-fixture verdict=none:foreman-verifies commit=none:self-referential-hash memory=none:foreman-owns
  # CF-388: every arm above starts from a home that ALREADY has ~/.hermes (a config file is written
  # there before the writer runs), so not one of them could see the state the create path actually
  # starts from: a freshly created node has no ~/.hermes at all — the adapter that owns it runs
  # later in this same layer, and install-hermes.sh never creates it. Measured at 2dcef4c, the
  # writer opened <config>.cf-tmp into that absent directory and died with FileNotFoundError, so
  # layer 20 printed `FAIL gateway_auth` and the adapter then refused the bind. F/G below start
  # from an empty HOME (the writer alone, and the whole layer-20 path) and H is the control: the
  # SAME two probes against the pre-fix writer must fail, or this section proves nothing.
  cf388=$(mktemp -d)
  mkdir -p "$cf388/f" "$cf388/g" "$cf388/h" "$cf388/h2"
  cf388_pre=absent
  [ ! -e "$cf388/f/.hermes" ] || cf388_pre=present
  if [ "$cf388_pre" = absent ]; then
    say "  PASS  fixture starts where a fresh node starts: HOME exists, .hermes does not"
  else
    say "  FAIL  the CF-388 fixture pre-created .hermes — the arm cannot see the defect"; fails=$((fails+1))
  fi

  # ARM F: the producer alone, invoked exactly as layer 20 invokes it, against a HOME with no
  # ~/.hermes. env -i proves the success cannot come from an ambient HOME or PATH.
  out=$(env -i HOME="$cf388/f" "$cf150_python" "$HERE/scripts/node_gateway_auth.py" \
    "$cf388/f/.hermes/config.yaml" "$cf388/f/.node/auth/gateway.pass" 2>&1); rc=$?
  cf388_secret=$(cat "$cf388/f/.node/auth/gateway.pass" 2>/dev/null || true)
  cf388_mode=$(stat -c '%a' "$cf388/f/.node/auth/gateway.pass" 2>/dev/null || true)
  cf388_blocks=0
  [ -f "$cf388/f/.hermes/config.yaml" ] && cf388_blocks=$(grep -c 'basic_auth:' "$cf388/f/.hermes/config.yaml" || true)
  if [ "$rc" -eq 0 ] \
    && [ "$cf388_blocks" -ge 1 ] \
    && grep -Eq '^    username: [^ ]' "$cf388/f/.hermes/config.yaml" \
    && grep -Eq '^    password: [^ ]' "$cf388/f/.hermes/config.yaml" \
    && [ "$cf388_mode" = 600 ] && [ -n "$cf388_secret" ] \
    && [ "$(printf '%s\n' "$out" | grep -c '^PASS  gateway_auth — added dashboard.basic_auth ')" = 1 ] \
    && [ "$(printf '%s\n' "$out" | grep -c '^PASS  gateway_auth — password stored at .*mode 600 (not printed)$')" = 1 ] \
    && ! printf '%s' "$out" | grep -Fq -- "$cf388_secret"; then
    say "  PASS  no ~/.hermes -> exit $rc, block created, password mode $cf388_mode, secret never printed"
  else
    say "  FAIL  the writer did not stage the block on a HOME with no ~/.hermes (exit $rc, blocks ${cf388_blocks:-0}, mode ${cf388_mode:-missing})"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi

  # ARM G: the whole layer-20 path from the same empty HOME — the row the create path prints, and
  # the row README promises. The block must be staged BEFORE the adapter's gate, and the secret
  # must not travel in the output the node logs.
  out=$(cf150_env "$cf388/g" /bin/bash "$cf150/tree/scripts/project-node.sh" \
    --apply --project fixture --layers 20 2>&1); rc=$?
  cf388_g_pass="  PASS  gateway_auth — dashboard.basic_auth present in $cf388/g/.hermes/config.yaml; password in $cf388/g/.node/auth/gateway.pass (mode 600, value not printed)"
  cf388_g_secret=$(cat "$cf388/g/.node/auth/gateway.pass" 2>/dev/null || true)
  cf388_g_blocks=0
  [ -f "$cf388/g/.hermes/config.yaml" ] && cf388_g_blocks=$(grep -c 'basic_auth:' "$cf388/g/.hermes/config.yaml" || true)
  if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$cf388_g_pass")" = 1 ] \
    && ! printf '%s\n' "$out" | grep -q '^  FAIL  gateway_auth' \
    && [ "$cf388_g_blocks" -ge 1 ] \
    && [ -n "$cf388_g_secret" ] && ! printf '%s' "$out" | grep -Fq -- "$cf388_g_secret"; then
    say "  PASS  layer 20 on a fresh HOME -> gateway_auth PASSes, block written, secret never printed (exit $rc)"
  else
    say "  FAIL  layer 20 could not stage the block on a fresh HOME (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi

  # ARM H (pre-fix control): the revision this row was raised on. h1 is the producer alone — it
  # must die without creating anything, exactly as measured; h2 drives the same layer-20 path, so
  # the counted FAIL row the create path printed is reproduced rather than asserted from memory.
  if git -C "$HERE" show 2dcef4c:scripts/node_gateway_auth.py > "$cf388/prefix-writer.py" 2>/dev/null; then
    out=$(env -i HOME="$cf388/h" "$cf150_python" "$cf388/prefix-writer.py" \
      "$cf388/h/.hermes/config.yaml" "$cf388/h/.node/auth/gateway.pass" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && [ ! -e "$cf388/h/.hermes/config.yaml" ] \
      && printf '%s\n' "$out" | grep -Fq 'FileNotFoundError'; then
      say "  PASS  pre-fix 2dcef4c on a fresh HOME -> exit $rc, FileNotFoundError, nothing created (fixture detects CF-388)"
    else
      say "  FAIL  the pre-fix producer did not fail on a HOME with no ~/.hermes (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
    cp -a "$cf150/tree" "$cf388/pretree"
    cp "$cf388/prefix-writer.py" "$cf388/pretree/scripts/node_gateway_auth.py"
    out=$(cf150_env "$cf388/h2" /bin/bash "$cf388/pretree/scripts/project-node.sh" \
      --apply --project fixture --layers 20 2>&1); rc=$?
    if [ "$rc" -ne 0 ] \
      && [ "$(printf '%s\n' "$out" | grep -c '^  FAIL  gateway_auth — could not stage dashboard.basic_auth in ')" = 1 ] \
      && ! printf '%s\n' "$out" | grep -Fq 'PASS  gateway_auth — dashboard.basic_auth present in' \
      && [ ! -e "$cf388/h2/.hermes/config.yaml" ]; then
      say "  PASS  pre-fix layer 20 on a fresh HOME -> one counted FAIL gateway_auth row, no block, exit $rc"
    else
      say "  FAIL  the pre-fix layer 20 did not report the staging failure (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
  else
    say "  FAIL  pre-fix source unavailable (git show 2dcef4c:scripts/node_gateway_auth.py)"
    fails=$((fails+1))
  fi
  rm -rf "$cf388"
  unset -f cf150_env
else
  say "  FAIL  CF-150 fixture setup (stdlib Python required)"; fails=$((fails+1))
fi
rm -rf "$cf150"
# END gateway-basic-auth

# BEGIN cf006-harness-node
# ch:trace row=CF-006 spec=docs/handbook/OUTLINE.md#M5 wave=none:serial-worker test=tests/harness-node-e2e.sh doc=specs/HARNESS.md evidence=tests/harness-node-e2e.sh witness=none:local-fixture verdict=none:foreman-will-run-gitreins commit=HEAD memory=none:foreman-closeout
say "56. a foreign harness is measured in a node, and verify-node.sh re-measures what the manifest records (CF-006)"
# The failure this closes: node.json carried harness{name,port} only and verify-node.sh never
# opened it, so a node provisioned with one harness and running another still printed VERIFY: PASS.
# The arms live in tests/harness-node-e2e.sh (real adapters, real project-node.sh --apply, real
# verify-node.sh, one stub transport); this section drives that battery and proves it can go RED.
cf006="$HERE/tests/harness-node-e2e.sh"
if [ ! -x "$cf006" ]; then
  say "  FAIL  tests/harness-node-e2e.sh is absent — the node slice has no test"; fails=$((fails+1))
else
  out=$(bash "$cf006" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'HARNESS-NODE-E2E: PASS' \
     && printf '%s\n' "$out" | grep -Fq 'PASS  node:manifest — harness{name:codex, version:' \
     && printf '%s\n' "$out" | grep -Fq 'PASS  verify:green — a node created with codex -> VERIFY: PASS' \
     && printf '%s\n' "$out" | grep -Fq 'PASS  verify:red-version' \
     && printf '%s\n' "$out" | grep -Fq 'PASS  verify:null-version' \
     && printf '%s\n' "$out" | grep -Fq 'PASS  turn:directive'; then
    say "  PASS  node slice: the manifest records the measured harness, verify re-measures it, 4 red arms + a directive turn"
  else
    say "  FAIL  the node slice battery did not pass (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | grep -E '^  FAIL|^HARNESS' | head -8 | sed 's/^/    | /'
  fi
  # A green child proves nothing unless it can go red on the same tree: drop the `binary` row from
  # a COPY of the codex adapter, so the node manifest records no binary, and the manifest arm must
  # FAIL. The mutation is confined to $cf006t — this checkout is never written.
  cf006t=$(mktemp -d)
  mkdir -p "$cf006t/tree/tests"
  cp -r "$HERE/scripts" "$cf006t/tree/scripts"
  cp "$cf006" "$cf006t/tree/tests/harness-node-e2e.sh"
  sed -i '/ok "binary"/d' "$cf006t/tree/scripts/harness/install-codex.sh"
  out=$(bash "$cf006t/tree/tests/harness-node-e2e.sh" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'FAIL  node:manifest' \
     && printf '%s\n' "$out" | grep -Fq 'HARNESS-NODE-E2E: FAIL'; then
    say "  PASS  with the adapter's binary row removed the manifest arm goes RED (exit $rc) — the battery is falsifiable"
  else
    say "  FAIL  the node slice battery stayed green without the binary measurement (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | grep -E '^  FAIL|^HARNESS' | head -6 | sed 's/^/    | /'
  fi
  rm -rf "$cf006t"

  # CF-006: criterion 1 says every adapter has a `--check` that is REAL. Two of them classified a
  # row that does not stop an install as a WARN, so on a host where the harness was installed and
  # measured they could not reach PASS: claude-code warned about a missing credential (a run input,
  # already reported as `--turn` SKIP) and pi-agent warned that an auth file "is not a binary"
  # beside a binary row that had just PASSed. The classification test pins both, each against the
  # PRE-FIX adapter from the same fixture, and keeps two negative arms (an ambient exported key,
  # a credential with no binary) so the fix cannot be "silence every non-green row".
  cf006c="$HERE/tests/harness/adapter-check-classification-test.sh"
  if [ ! -f "$cf006c" ]; then
    say "  FAIL  tests/harness/adapter-check-classification-test.sh is absent — the --check classification has no test"
    fails=$((fails+1))
  else
    out=$(bash "$cf006c" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'RESULT: PASS' \
       && printf '%s\n' "$out" | grep -Fq "claude-code: the pin installed with no credential reaches 'CLAUDE-CODE: PASS'" \
       && printf '%s\n' "$out" | grep -Fq 'claude-code: the pre-fix adapter' \
       && printf '%s\n' "$out" | grep -Fq 'pi-agent: a measured binary with an auth.json reaches' \
       && printf '%s\n' "$out" | grep -Fq 'pi-agent: the pre-fix adapter' \
       && printf '%s\n' "$out" | grep -Fq 'claude-code: an ambient exported key is still refused by name' \
       && printf '%s\n' "$out" | grep -Fq 'pi-agent: a credential file with no binary is still'; then
      say "  PASS  adapter --check classification: measured installs reach PASS, the pre-fix adapters do not, and the ambient/credential-only negatives still refuse"
    else
      say "  FAIL  the adapter --check classification test did not pass (exit $rc)"
      fails=$((fails+1))
      printf '%s\n' "$out" | grep -E '^  FAIL|^RESULT' | head -6 | sed 's/^/    | /'
    fi
  fi
fi
# END cf006-harness-node

# ch:trace row=CF-275 spec=specs/ENVELOPE.md#dispatch-control-host--node-inbox test=tests/selftest.sh::brief-digest-binding doc=docs/OPERATIONS.md prompt=none:worker-brief evidence=tests/selftest.sh::brief-digest-binding witness=none:local-fixture verdict=none:foreman-verifies commit=none:self-referential-hash memory=none:foreman-owns
say "57. the brief digest binds every effectful field, and the pre-fix worker runs a tampered gate (CF-275)"
# The failure this closes: brief.digest was sha256 over the directive TEXT alone while run_gate()
# hands gate.cmd to `/bin/sh -lc` in the clone, so a brief rewritten in flight verified and then
# executed attacker-chosen shell. The fixture asserts SIDE EFFECTS — a marker file the gate writes,
# or does not — not intentions: six arms, four of them refusal paths. No network, no credential,
# everything under one mktemp -d.
cf275=$(mktemp -d)
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_brief_digest_binding.py" >"$cf275/out" 2>&1; then
  say "  PASS  a bound text+gate+repo/ref digest runs its gate; a tampered gate.cmd, a legacy text-only digest beside a gate, and a gate with no digest are each refused without the gate starting"
else
  say "  FAIL  the brief digest binding on the receiving side (tests/test_brief_digest_binding.py)"
  fails=$((fails+1))
  sed 's/^/    | /' "$cf275/out"
fi
# ARM (red control): the SAME fixture against the revision this row was raised on. It must RUN the
# altered gate; pointed at the fixed worker the control fails, so it discriminates rather than
# merely passing.
if git -C "$HERE" show c05880d:scripts/node-bus-worker.py > "$cf275/node-bus-worker.py" 2>/dev/null; then
  if CF_BUS_WORKER_SOURCE="$cf275/node-bus-worker.py" CF_BRIEF_DIGEST_PREFIX_CONTROL=1 \
       PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_brief_digest_binding.py" \
       >"$cf275/prefix" 2>&1; then
    say "  PASS  pre-fix c05880d runs the gate whose cmd was altered after the digest was minted (fixture detects CF-275)"
  else
    say "  FAIL  pre-fix control did not reproduce the tampered-gate execution"
    fails=$((fails+1))
    sed 's/^/    | /' "$cf275/prefix"
  fi
else
  say "  FAIL  pre-fix source unavailable (git show c05880d:scripts/node-bus-worker.py)"
  fails=$((fails+1))
fi
rm -rf "$cf275"

# ch:trace row=CF-003 spec=specs/NODE.md#credentials--per-repo-deploy-keys wave=none:single-shared-checkout test=tests/test_node_provisioning.py doc=docs/handbook/chapters/M1-provisioning.md prompt=CF-003-brief evidence=tests/test_node_provisioning.py witness=bash tests/selftest.sh verdict=none:foreman-lifecycle commit=none:worker-commit-pending memory=none:foreman-closeout
say "58. per-repo deploy key, node runtime, shared module cache, footprint, orphan reap (CF-003)"
# Two layers of proof. The unit battery owns the mechanisms (a key refused at 0644, a wrong
# digest installing nothing, a sealed cache that builds with GOPROXY=off and refuses to grow,
# a footprint that adds up, a reaper that spares live ids and symlinks). The shell arms below
# prove the WIRING: layer 10 must grade the runtime the ladder provisioned rather than an
# ambient PATH node, layer 40 must use the declared key for the clone and refuse a readable
# key instead of cloning without one, and layer 00 must print a footprint row.
cf003=$(mktemp -d)
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_node_provisioning.py" >"$cf003/out" 2>&1; then
  say "  PASS  five mechanisms with their refusal arms (deploy key, node pin, sealed GOMODCACHE, footprint, reap)"
  if grep -q 'MEASURED shared GOMODCACHE' "$cf003/out"; then
    say "  PASS  $(grep -m1 'MEASURED shared GOMODCACHE' "$cf003/out" | sed 's/^ *//')"
  else
    say "  ..    no MEASURED line: the go-backed no-download arm skipped (no Go toolchain here)"
  fi
else
  say "  FAIL  the CF-003 unit battery (tests/test_node_provisioning.py)"
  fails=$((fails+1))
  sed 's/^/    | /' "$cf003/out"
fi

# ARM: layer 10 grades the OWNED pin. A fresh node has no node at all; the row must name
# $HOME/node-toolchain/current/bin/node, not whichever node an ambient image exposes.
mkdir -p "$cf003/home/node-toolchain/current/bin"
printf '#!/bin/sh\necho v22.22.3\n' > "$cf003/home/node-toolchain/current/bin/node"
chmod +x "$cf003/home/node-toolchain/current/bin/node"
out=$(env HOME="$cf003/home" NODE_PROJECT=demo CRIER_URL=http://127.0.0.1:9 \
  bash "$HERE/scripts/project-node.sh" --check --project demo --kinds node --layers 10 2>&1); rc=$?
expected="  PASS  tool:node — $cf003/home/node-toolchain/current/bin/node (v22.22.3)"
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$expected")" = 1 ]; then
  say "  PASS  layer 10 grades the owned node pin, not a PATH runtime"
else
  say "  FAIL  layer 10 did not name the owned node runtime (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | grep -E 'tool:node|NODE:' | sed 's/^/    | /'
fi

# ARM: layer 40 clones with the declared per-repo key and pins it into that one repository.
git init -q -b main "$cf003/src"
git -C "$cf003/src" config user.email fixture@example.invalid
git -C "$cf003/src" config user.name fixture
echo fixture > "$cf003/src/README"
git -C "$cf003/src" add README
git -C "$cf003/src" commit -qm fixture
for arm in green red; do
  mkdir -p "$cf003/$arm/.node/keys"
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nFIXTURE\n-----END OPENSSH PRIVATE KEY-----\n' \
    > "$cf003/$arm/.node/keys/project.key"
  printf 'Host gitlab.example\n  IdentitiesOnly yes\n  IdentityFile %s\n' \
    "$cf003/$arm/.node/keys/project.key" > "$cf003/$arm/.node/keys/ssh_config"
  chmod 600 "$cf003/$arm/.node/keys/ssh_config"
done
chmod 600 "$cf003/green/.node/keys/project.key"
chmod 644 "$cf003/red/.node/keys/project.key"
out=$(env HOME="$cf003/green" NODE_PROJECT=demo CRIER_URL=http://127.0.0.1:9 \
  NODE_DEPLOY_KEY="$cf003/green/.node/keys/project.key" \
  NODE_SSH_CONFIG="$cf003/green/.node/keys/ssh_config" \
  bash "$HERE/scripts/project-node.sh" --apply --project demo --repo "$cf003/src" --ref main --layers 40 2>&1); rc=$?
key_row="  PASS  repo_key — $cf003/green/.node/keys/project.key mode 600"
conf_row="  PASS  repo_key:config — core.sshCommand set in $cf003/green/repo (this repository only)"
if [ "$rc" -eq 0 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$key_row")" = 1 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$conf_row")" = 1 ]; then
  say "  PASS  layer 40 clones with the declared key and pins core.sshCommand in that repo only"
else
  say "  FAIL  layer 40 did not use the declared deploy key (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | grep -E 'repo_key|repo_clone|repo —|NODE:' | sed 's/^/    | /'
fi
# CONTROL: the same fixture with the key readable by group/other must refuse the clone
# rather than fall back to an ambient identity.
out=$(env HOME="$cf003/red" NODE_PROJECT=demo CRIER_URL=http://127.0.0.1:9 \
  NODE_DEPLOY_KEY="$cf003/red/.node/keys/project.key" \
  NODE_SSH_CONFIG="$cf003/red/.node/keys/ssh_config" \
  bash "$HERE/scripts/project-node.sh" --apply --project demo --repo "$cf003/src" --ref main --layers 40 2>&1); rc=$?
bad_key="  FAIL  repo_key — $cf003/red/.node/keys/project.key mode 644 — group/other can read it (chmod 600)"
no_clone='  FAIL  repo_clone — not attempted — the declared deploy key is unusable (see repo_key)'
if [ "$rc" -ne 0 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$bad_key")" = 1 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc -- "$no_clone")" = 1 ]; then
  say "  PASS  a 0644 deploy key is refused and the clone is not attempted"
else
  say "  FAIL  a readable deploy key did not block the clone (exit $rc)"; fails=$((fails+1))
  printf '%s\n' "$out" | grep -E 'repo_key|repo_clone|NODE:' | sed 's/^/    | /'
fi

# ARM (CF-003 spawn gate): the credential is validated on the CONTROL HOST before an agent
# exists, not after the bytes have been copied into one. Measured at the pre-fix revision
# (4f32a50): a mode-600 `.pub`, a mode-600 junk file and a passphrase-protected key each printed
# `PASS deploy_key — … mode 600` and went on to spawn; an HTTPS remote with a valid key did the
# same and only failed inside the node. Every arm below runs node-create.sh with NO BUNKER_SERVER,
# so a refusal is reached without a server, a bunker client or a spawned agent — and the green
# arm proves the gate ADMITS a usable credential by continuing to `server_declared`.
if ! command -v ssh-keygen >/dev/null 2>&1; then
  say "  SKIP  the node-create spawn gate — ssh-keygen absent from PATH, a deploy key cannot be measured here"
else
  mkdir -p "$cf003/keys"
  mkdir -p "$cf003/create-home"
  ssh-keygen -q -t ed25519 -N '' -f "$cf003/keys/real" -C cf003-fixture >/dev/null 2>&1
  ssh-keygen -q -t ed25519 -N 'passphrase' -f "$cf003/keys/enc" -C cf003-fixture >/dev/null 2>&1
  cp "$cf003/keys/real.pub" "$cf003/keys/public.key"
  printf 'not a key at all\n' > "$cf003/keys/junk.key"
  chmod 600 "$cf003/keys/real" "$cf003/keys/enc" "$cf003/keys/public.key" "$cf003/keys/junk.key"
  cf003_create() {
    env -u BUNKER_SERVER HOME="$cf003/create-home" NODE_PROJECT=demo \
      CRIER_URL=http://127.0.0.1:9 \
      bash "$HERE/scripts/node-create.sh" --project demo --repo "$1" --deploy-key "$2" 2>&1
  }
  gate_fail='  FAIL  deploy_key:loadable — '
  for unusable in public.key junk.key enc; do
    out=$(cf003_create git@gitlab.example:group/repo.git "$cf003/keys/$unusable"); rc=$?
    if [ "$rc" -eq 1 ] \
       && [ "$(printf '%s\n' "$out" | grep -cF "$gate_fail")" = 1 ] \
       && printf '%s\n' "$out" | grep -qF -- "$cf003/keys/$unusable does not load as an unencrypted private key" \
       && ! printf '%s\n' "$out" | grep -q '^  FAIL  server_declared' \
       && ! printf '%s\n' "$out" | grep -q '^  ..    spawning'; then
      say "  PASS  node-create refuses $unusable at the spawn gate, before any agent exists (exit $rc)"
    else
      say "  FAIL  node-create accepted $unusable as a deploy key (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
  done
  # The other half of the same credential: an HTTPS remote can never be cloned with a deploy key.
  out=$(cf003_create https://gitlab.example/group/repo.git "$cf003/keys/real"); rc=$?
  if [ "$rc" -eq 1 ] \
     && [ "$(printf '%s\n' "$out" | grep -cF '  FAIL  deploy_key:repo — https://gitlab.example/group/repo.git is not an SSH remote')" = 1 ] \
     && ! printf '%s\n' "$out" | grep -q '^  FAIL  server_declared'; then
    say "  PASS  node-create refuses a deploy key on an HTTPS remote at the spawn gate (exit $rc)"
  else
    say "  FAIL  an HTTPS remote was accepted with a deploy key (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # GREEN control: a real 0600 key on an SSH remote passes both rows and the run proceeds to the
  # next precondition. Without this, "refuses everything" would read as a pass.
  out=$(cf003_create git@gitlab.example:group/repo.git "$cf003/keys/real"); rc=$?
  if [ "$rc" -eq 1 ] \
     && [ "$(printf '%s\n' "$out" | grep -Fxc -- "  PASS  deploy_key — $cf003/keys/real mode 600")" = 1 ] \
     && [ "$(printf '%s\n' "$out" | grep -Fxc -- "  PASS  deploy_key:loadable — $cf003/keys/real loads as an unencrypted private key")" = 1 ] \
     && [ "$(printf '%s\n' "$out" | grep -Fxc -- '  PASS  deploy_key:repo — git@gitlab.example:group/repo.git is an SSH remote')" = 1 ] \
     && printf '%s\n' "$out" | grep -q '^  FAIL  server_declared' \
     && ! printf '%s\n' "$out" | grep -q '^  FAIL  deploy_key'; then
    say "  PASS  a usable read-only key passes the spawn gate and the run continues past it"
  else
    say "  FAIL  the spawn gate did not admit a usable deploy key (exit $rc)"; fails=$((fails+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
  # RED proof: the same public-key fixture against the revision this row was raised on must NOT be
  # refused. Pointed at the fixed script the control fails, so the arm discriminates.
  mkdir -p "$cf003/prefix"
  cp -r "$HERE/scripts" "$cf003/prefix/scripts"
  if git -C "$HERE" show 4f32a50:scripts/node-create.sh > "$cf003/prefix/scripts/node-create.sh" 2>/dev/null; then
    chmod +x "$cf003/prefix/scripts/node-create.sh"
    out=$(env -u BUNKER_SERVER HOME="$cf003/create-home" NODE_PROJECT=demo CRIER_URL=http://127.0.0.1:9 \
      bash "$cf003/prefix/scripts/node-create.sh" --project demo \
      --repo git@gitlab.example:group/repo.git --deploy-key "$cf003/keys/public.key" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] \
       && ! printf '%s\n' "$out" | grep -q 'deploy_key:loadable' \
       && printf '%s\n' "$out" | grep -qF -- "$cf003/keys/public.key mode 600" \
       && printf '%s\n' "$out" | grep -q '^  FAIL  server_declared'; then
      say "  PASS  pre-fix 4f32a50 accepts the public key as a deploy key — the gate arm is falsifiable"
    else
      say "  FAIL  the pre-fix control did not reproduce the unvalidated spawn gate (exit $rc)"; fails=$((fails+1))
      printf '%s\n' "$out" | sed 's/^/    | /'
    fi
  else
    say "  FAIL  pre-fix source unavailable (git show 4f32a50:scripts/node-create.sh)"; fails=$((fails+1))
  fi
  unset -f cf003_create
fi

# ARM: layer 00 reports the footprint it will occupy against the resolved floor.
out=$(env HOME="$cf003/home" NODE_PROJECT=demo CRIER_URL=http://127.0.0.1:9 \
  bash "$HERE/scripts/project-node.sh" --check --project demo --layers 00 2>&1)
if printf '%s\n' "$out" | grep -q '^  PASS  footprint — ' \
   && printf '%s\n' "$out" | grep -q '^  PASS  footprint:floor — '; then
  say "  PASS  layer 00 measures the node footprint and admits it against the floor"
else
  say "  FAIL  layer 00 printed no footprint row"; fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi
rm -rf "$cf003"

# ch:trace row=CF-141 spec=docs/handbook/OUTLINE.md#M5-HARNESS wave=none:serial-worker test=selftest:59 doc=specs/HARNESS.md,M5-harness.md evidence=tests/selftest.sh commit=none:self-referential-hash memory=none:foreman-closeout
say "59. an adapter's verdict counts its WARN rows, not just its FAIL rows (CF-141)"
# Measured defect (d4f2600): every adapter ended with
#   [ "$FAILED" -eq 0 ] && { say "X: PASS"; exit 0; } || { say "X: FAIL ($FAILED)"; exit 1; }
# and lib.sh's warn() counted nothing, so an adapter whose own banner says `UNVERIFIED adapter`
# printed `OPENCODE: PASS` and exited 0 beside two WARN rows. specs/HARNESS.md "The verdict line"
# is the authority: FAIL (n) / UNVERIFIED / PASS, decided by row counts. One fixture, three arms —
# only the rows the stub prints change, so nothing but the count can decide the verdict.
cf141="$(mktemp -d)"
mkdir -p "$cf141/bin" "$cf141/home/work" "$cf141/harness-bin"
cat > "$cf141/bin/stub-adapter.sh" <<'FIX'
#!/usr/bin/env bash
. "${FIXTURE_LIB:?}"
case "${STUB_ROWS:-pass}" in
  warn) warn "non_interactive" "fixture: no non-interactive surface advertised"
        warn "user_space_binary" "fixture: nothing installed under $HOME" ;;
  fail) bad  "binary" "fixture: absent — no stub binary on this HOST" ;;
  pass) ok   "binary" "$0" ;;
esac
say ""
verdict STUB
exit $?
FIX
chmod +x "$cf141/bin/stub-adapter.sh"
cf141_arm() {  # cf141_arm <rows> — the arms differ only in this one value
  env -i PATH="$cf141/bin:/usr/bin:/bin" HOME="$cf141/home" \
    FIXTURE_LIB="$HERE/scripts/lib.sh" STUB_ROWS="$1" \
    /bin/bash "$cf141/bin/stub-adapter.sh" 2>&1
}

# ARM (a): a WARN row is a measurement, not a green tick. Two WARN rows and no FAIL row must be
# UNVERIFIED with a nonzero exit, and `PASS` must not appear at all.
out=$(cf141_arm warn); rc=$?
printf '%s\n' "$out" > "$cf141/a.out"
if [ "$rc" -eq 3 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc 'STUB: UNVERIFIED')" = 1 ] \
   && [ "$(printf '%s\n' "$out" | grep -c '^  WARN  ')" = 2 ] \
   && ! printf '%s\n' "$out" | grep -qF 'STUB: PASS'; then
  say "  PASS  a WARN row -> 'STUB: UNVERIFIED', exit 3, never PASS ($(printf '%s\n' "$out" | grep -c '^  WARN  ') WARN rows)"
else
  say "  FAIL  a WARN row did not end UNVERIFIED (exit $rc): $(printf '%s\n' "$out" | grep -E 'STUB: ' | tr '\n' ' ')"
  fails=$((fails+1))
fi

# ARM (b): the same fixture with a FAIL row is FAIL (n) — the count is on the line — and nonzero.
out=$(cf141_arm fail); rc=$?
printf '%s\n' "$out" > "$cf141/b.out"
if [ "$rc" -eq 1 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc 'STUB: FAIL (1)')" = 1 ] \
   && ! printf '%s\n' "$out" | grep -qE '^STUB: (PASS|UNVERIFIED)$'; then
  say "  PASS  a FAIL row -> 'STUB: FAIL (1)', exit 1, never PASS/UNVERIFIED"
else
  say "  FAIL  a FAIL row did not end FAIL (n) with a nonzero exit (exit $rc): $(printf '%s\n' "$out" | grep -E 'STUB: ' | tr '\n' ' ')"
  fails=$((fails+1))
fi

# ARM (c): every row PASS is the ONLY state that may print PASS, and it exits 0. Without this arm
# "never PASS" could be satisfied by an adapter that can never go green.
out=$(cf141_arm pass); rc=$?
printf '%s\n' "$out" > "$cf141/c.out"
if [ "$rc" -eq 0 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc 'STUB: PASS')" = 1 ] \
   && ! printf '%s\n' "$out" | grep -qE '^STUB: (FAIL|UNVERIFIED)'; then
  say "  PASS  all rows PASS -> 'STUB: PASS', exit 0"
else
  say "  FAIL  an all-PASS fixture did not print PASS with exit 0 (exit $rc): $(printf '%s\n' "$out" | grep -E 'STUB: ' | tr '\n' ' ')"
  fails=$((fails+1))
fi

# ARM (d): the row's own probe, against the REAL adapter. A PATH-local stub whose --help
# advertises no run/exec/serve mode: two WARN rows, no FAIL row, so the verdict is UNVERIFIED.
cat > "$cf141/harness-bin/opencode" <<'FIX'
#!/bin/sh
if [ "$1" = "--version" ]; then echo 9.9.9; else echo "opencode cli help"; fi
FIX
chmod +x "$cf141/harness-bin/opencode"
cf141_opencode() {  # cf141_opencode <adapter>
  env -i PATH="$cf141/harness-bin:/usr/bin:/bin" HOME="$cf141/home" /bin/bash "$1" --check 2>&1
}
out=$(cf141_opencode "$HERE/scripts/harness/install-opencode.sh"); rc=$?
printf '%s\n' "$out" > "$cf141/d.out"
if [ "$rc" -eq 3 ] \
   && [ "$(printf '%s\n' "$out" | grep -Fxc 'OPENCODE: UNVERIFIED')" = 1 ] \
   && [ "$(printf '%s\n' "$out" | grep -c '^  WARN  ')" = 2 ] \
   && ! printf '%s\n' "$out" | grep -qF 'OPENCODE: PASS'; then
  say "  PASS  install-opencode.sh --check on the row's stub -> 'OPENCODE: UNVERIFIED', exit 3, never PASS"
else
  say "  FAIL  the real adapter still misreports the verdict (exit $rc): $(printf '%s\n' "$out" | grep -E 'OPENCODE: ' | tr '\n' ' ')"
  fails=$((fails+1))
  printf '%s\n' "$out" | sed 's/^/    | /'
fi

# The control that makes arm (d) falsifiable: the revision the row was raised on, on the SAME
# fixture, must print PASS and exit 0 — so the arm above is green because the adapter changed,
# not because the stub is new.
cp -r "$HERE/scripts" "$cf141/prefix-scripts"
mkdir -p "$cf141/prefix"
mv "$cf141/prefix-scripts" "$cf141/prefix/scripts"
if git -C "$HERE" show d4f2600:scripts/harness/install-opencode.sh > "$cf141/prefix/scripts/harness/install-opencode.sh" 2>/dev/null; then
  chmod +x "$cf141/prefix/scripts/harness/install-opencode.sh"
  pre_out=$(cf141_opencode "$cf141/prefix/scripts/harness/install-opencode.sh"); pre_rc=$?
  if [ "$pre_rc" -eq 0 ] \
     && printf '%s\n' "$pre_out" | grep -qF 'OPENCODE: PASS' \
     && [ "$(printf '%s\n' "$pre_out" | grep -c '^  WARN  ')" = 2 ]; then
    say "  PASS  pre-fix d4f2600 prints 'OPENCODE: PASS' with exit 0 beside the same two WARN rows — the arm is falsifiable"
  else
    say "  FAIL  the pre-fix control did not reproduce PASS-beside-WARN (exit $pre_rc): $(printf '%s\n' "$pre_out" | grep -E 'OPENCODE: ' | tr '\n' ' ')"
    fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source unavailable (git show d4f2600:scripts/harness/install-opencode.sh)"
  fails=$((fails+1))
fi

# ARM (e): every shipped adapter reaches a verdict line, and that line is the one ITS OWN row
# counts require. install-hermes.sh used to `exit 1` at the interpreter gate with rows and no
# verdict (CF-141), so a caller could not tell a verdict from a crash.
cf141_bad=""
for name in opencode hermes claude-code codex pi-agent deepseek; do
  case "$name" in
    opencode) label=OPENCODE ;;
    hermes) label=HERMES ;;
    claude-code) label=CLAUDE-CODE ;;
    codex) label=CODEX ;;
    pi-agent) label=PI-AGENT ;;
    deepseek) label=DEEPSEEK ;;
  esac
  out=$(env -i PATH="$cf141/bin:/usr/bin:/bin" HOME="$cf141/home" \
        /bin/bash "$HERE/scripts/harness/install-$name.sh" --check 2>&1); rc=$?
  f=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
  wn=$(printf '%s\n' "$out" | grep -c '^  WARN  ')
  last=$(printf '%s\n' "$out" | grep -v '^$' | tail -1)
  if [ "$f" -gt 0 ]; then want="FAIL ($f)"; wrc=1
  elif [ "$wn" -gt 0 ]; then want="UNVERIFIED"; wrc=3
  else want="PASS"; wrc=0
  fi
  printf '%s\t%s\t%s\n' "$name" "$want" "$last" >> "$cf141/vocab.table"
  if [ "$last" != "$label: $want" ] || [ "$rc" -ne "$wrc" ]; then
    cf141_bad="$cf141_bad $name('$last',rc=$rc,want='$label: $want')"
  fi
done
if [ -z "$cf141_bad" ]; then
  say "  PASS  all six adapters end with the verdict their row counts require (table in the scratch dir)"
else
  say "  FAIL  adapter verdict(s) disagree with the printed rows:$cf141_bad"
  fails=$((fails+1))
fi

# ARM (f): criterion 4's named symptom — an unsupported interpreter. The ladder stops, but the
# verdict does not: `FAIL python` AND `HERMES: FAIL (1)`, exit 1, not a bare exit.
printf '#!/bin/sh\necho "Python 3.14.9"\n' > "$cf141/bin/python-unsupported"
chmod +x "$cf141/bin/python-unsupported"
out=$(env -i PATH="$cf141/bin:/usr/bin:/bin" HOME="$cf141/home" \
  HERMES_PYTHON_BIN="$cf141/bin/python-unsupported" \
  /bin/bash "$HERE/scripts/harness/install-hermes.sh" --check 2>&1); rc=$?
printf '%s\n' "$out" > "$cf141/f.out"
if [ "$rc" -eq 1 ] \
   && printf '%s\n' "$out" | grep -q '^  FAIL  python — ' \
   && [ "$(printf '%s\n' "$out" | grep -Fxc 'HERMES: FAIL (1)')" = 1 ]; then
  say "  PASS  an unsupported interpreter ends 'HERMES: FAIL (1)', exit 1, after the named row"
else
  say "  FAIL  the interpreter refusal printed no verdict line (exit $rc): $(printf '%s\n' "$out" | tail -1)"
  fails=$((fails+1))
fi
rm -rf "$cf141"

# ch:trace row=CF-006 spec=specs/HARNESS.md#adapters-and-their-measured-state wave=none:serial test=tests/selftest.sh::aider-goose-adapter doc=docs/handbook/chapters/M5-harness.md prompt=none:worker-brief evidence=tests/selftest.sh witness=none:local-fixture verdict=none:foreman-will-run-gitreins commit=none:self-referential-hash memory=none:foreman-closeout
say "60. every harness the spec names now has an adapter: aider and goose go red by name, never silent (CF-006)"
# Measured defect: specs/HARNESS.md names eight harnesses and states its own rule — "A harness named in
# the tables above with no adapter file is a FAIL, never a skip" — while scripts/harness/ shipped no
# install-aider.sh/install-goose.sh and tests/harness-conformance.sh listed neither, so both harnesses
# produced NO row at all. The fixed state is asserted on both surfaces here: each adapter prints named
# rows and exactly ONE verdict line, the verdict is the one its own PASS/WARN/FAIL counts require (so
# a hand-written `say "X: PASS"` or a bare exit code cannot satisfy the arm), and each --apply is a
# named refusal that places nothing on disk.
cf006="$(mktemp -d)"
mkdir -p "$cf006/home"
for cf006_pair in aider:AIDER goose:GOOSE; do
  cf006_id="${cf006_pair%%:*}"; cf006_label="${cf006_pair##*:}"
  cf006_adapter="$HERE/scripts/harness/install-$cf006_id.sh"

  # ARM (a): --check is a real check — named rows, one verdict line, and the verdict the rows imply.
  out=$(env -i PATH="$PATH" HOME="$cf006/home" /bin/bash "$cf006_adapter" --check 2>&1); rc=$?
  printf '%s\n' "$out" > "$cf006/$cf006_id.check.out"
  rows=$(printf '%s\n' "$out" | grep -c '^  \(PASS\|FAIL\|WARN\)  ')
  f=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
  wn=$(printf '%s\n' "$out" | grep -c '^  WARN  ')
  if [ "$f" -gt 0 ]; then want="FAIL ($f)"; wrc=1
  elif [ "$wn" -gt 0 ]; then want="UNVERIFIED"; wrc=3
  else want="PASS"; wrc=0
  fi
  verdicts=$(printf '%s\n' "$out" | grep -Ec "^$cf006_label: (PASS|UNVERIFIED|FAIL \([0-9]+\))$")
  last=$(printf '%s\n' "$out" | grep -v '^$' | tail -1)
  if [ "${rows:-0}" -ge 1 ] && [ "${verdicts:-0}" -eq 1 ] && [ "$last" = "$cf006_label: $want" ] \
     && [ "$rc" -eq "$wrc" ]; then
    say "  PASS  $cf006_id --check — $rows named row(s), one verdict line '$last', exit $rc (the rows require it)"
  else
    say "  FAIL  $cf006_id --check — ${rows:-0} named row(s), ${verdicts:-0} '$cf006_label:' verdict line(s) ('${last:-none}'), exit $rc; the rows require '$cf006_label: $want' and exit $wrc"
    fails=$((fails+1))
  fi

  # ARM (b): --apply refuses BY NAME, ends FAIL (n) over its own rows, exits 1, and installs nothing.
  # A scratch HOME per harness, so "placed nothing" is measured rather than asserted.
  cf006_h="$cf006/home-$cf006_id"; mkdir -p "$cf006_h"
  out=$(env -i PATH="$PATH" HOME="$cf006_h" /bin/bash "$cf006_adapter" --apply 2>&1); rc=$?
  printf '%s\n' "$out" > "$cf006/$cf006_id.apply.out"
  f=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
  wn=$(printf '%s\n' "$out" | grep -c '^  WARN  ')
  [ "$f" -gt 0 ] && want="FAIL ($f)" || { [ "$wn" -gt 0 ] && want="UNVERIFIED" || want="PASS"; }
  verdicts=$(printf '%s\n' "$out" | grep -Fxc "$cf006_label: $want")
  placed=$(find "$cf006_h" -type f -perm -u+x 2>/dev/null | wc -l)
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^  FAIL  apply — refused' \
     && printf '%s\n' "$out" | grep -qi 'unmeasured' \
     && [ "$verdicts" -eq 1 ] && [ "${placed:-1}" -eq 0 ] \
     && ! printf '%s\n' "$out" | grep -q '^  PASS  install'; then
    say "  PASS  $cf006_id --apply — refused by name ($(printf '%s\n' "$out" | grep -c '^  FAIL  apply — refused') row + '$cf006_label: $want'), exit $rc, 0 executable(s) placed in a scratch \$HOME"
  else
    say "  FAIL  $cf006_id --apply — exit $rc (want 1), ${verdicts:-0} '$cf006_label: $want' line(s), ${placed:-?} executable(s) placed, or the refusal is not named"
    printf '%s\n' "$out" | tail -3 | sed 's/^/    | /'
    fails=$((fails+1))
  fi
done
rm -rf "$cf006"
# ch:trace row=CF-050 spec=docs/ACCEPTANCE-PLAN.md#section-61 wave=none:serial-worker test=tests/selftest.sh::CF050_publish_gate doc=docs/ACCEPTANCE-PLAN.md evidence=none:no-frozen-transcript witness=none:not-published verdict=none:foreman-runs-gitreins commit=none:foreman-commit memory=none:foreman-closeout
# CF-050: the published tree must not gain new absolute host-home paths. The measured baseline
# counts legacy files so cleanup remains a separate row; this gate blocks only regressions.
cf050_publish_gate() {
  local root=$1 baseline=$2 hits count paths
  hits=$(git -C "$root" grep -lIE '/home/[a-z][a-z0-9_-]*/' HEAD -- . \
    ':!.gitreins/**' ':!.coding-hermes/board/**' 2>/dev/null || true)
  count=$(printf '%s\n' "$hits" | grep -c . || true)
  paths=$(printf '%s\n' "$hits" | sed 's/^HEAD://' | sort -u | sed -n '1,10p' | tr '\n' ' ')
  if [ "$count" -gt "$baseline" ]; then
    say "  FAIL  publish paths — baseline $baseline, current $count; paths: ${paths% }"
    return 1
  fi
  say "  PASS  publish paths — baseline $baseline, current $count"
  return 0
}
say "61. the published tree does not add absolute host-home paths (CF-050)"
cf050_publish_gate "$HERE" 143 || fails=$((fails+1))
# Red proof: a committed fixture exercises the same git-grep path as HEAD. Build the path from
# pieces so this test does not itself seed the production tree with a host-specific literal.
cf050=$(mktemp -d)
git init -q -b trunk "$cf050/seed"
mkdir -p "$cf050/seed/docs"
printf '/%s/%s/fixture\n' home "${USER:-user}" > "$cf050/seed/docs/fixture.md"
git -C "$cf050/seed" add docs/fixture.md
git -C "$cf050/seed" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm fixture
out=$(cf050_publish_gate "$cf050/seed" 0 2>&1); rc=$?
if [ "$rc" -ne 0 ] \
   && printf '%s\n' "$out" | grep -Eq '^  FAIL  publish paths — baseline 0, current 1; paths: docs/fixture\.md$'; then
  say "  PASS  seeded fixture -> FAIL names docs/fixture.md; gate is falsifiable"
else
  say "  FAIL  seeded fixture did not trigger the named publish-path row: $out"; fails=$((fails+1))
fi
git -C "$cf050/seed" rm -q docs/fixture.md
git -C "$cf050/seed" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm clean
out=$(cf050_publish_gate "$cf050/seed" 0 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq '  PASS  publish paths — baseline 0, current 0'; then
  say "  PASS  removed fixture -> clean control passes"
else
  say "  FAIL  removed fixture did not restore PASS: $out"; fails=$((fails+1))
fi
rm -rf "$cf050"

# ch:trace row=CF-224 spec=F2/M1.S5 wave=none:serial test=tests/selftest.sh::section-62 doc=docs/OPERATIONS.md,specs/NODE.md prompt=/home/kara/.hermes/cache/scratch/code-factory-20261108-133437/brief-CF-224.txt evidence=docs/audits/cf-224-verify-transport-2026-11-08.md witness=none:offline-fixture verdict=none:foreman-runs-judge commit=none:self-referential-hash memory=none:foreman-writes-receipt
say "62. verify-node names its transport, and a probe that never leaves the node is a FAIL (CF-224)"
# The failure this closes: the verifier read `hostname -I` off the node and probed that address from
# the control host, so a bunker node (no LAN address by default) reported itself unverified while a
# completely green one printed `VERIFY: PASS` off a loopback address that answered on the CONTROL
# host. The arms below drive the REAL verifier over one fixture node home with a stub transport and
# a stub HTTP probe (no bunker, no network): the loopback fixture is measured twice — through the
# pre-fix verifier, which certifies it, and through this one, which refuses — and each transport is
# exercised for its PASS row and for its named unavailable row.
cf224=$(mktemp -d)
mkdir -p "$cf224/bin" "$cf224/tree" "$cf224/prefix" "$cf224/home/.hermes" "$cf224/seed-src/prompts"
cp -r "$HERE/scripts" "$cf224/tree/scripts"
rm -rf "$cf224/tree/scripts/__pycache__"
cp -r "$cf224/tree/scripts" "$cf224/prefix/scripts"
cf224_prefix=1
git -C "$HERE" show bf16c05:scripts/verify-node.sh > "$cf224/prefix/scripts/verify-node.sh" 2>/dev/null || cf224_prefix=0
# One stub transport for every leg: `hostname -I` answers FIXTURE_IP when one is set (the loopback
# arm), otherwise the body runs locally with the real positional convention — the freshness and seed
# legs then measure the fixture home exactly as they measure a node.
cat > "$cf224/bin/bunker" <<'EOF'
#!/usr/bin/env bash
if [ -n "${FIXTURE_IP:-}" ]; then
  for a in "$@"; do
    case "$a" in *hostname\ -I*) printf '%s\n' "$FIXTURE_IP"; exit 0 ;; esac
  done
fi
args=("$@")
i=0
while [ "$i" -lt "${#args[@]}" ]; do
  case "${args[$i]}" in bash|sh) break ;; esac
  i=$((i + 1))
done
[ "$i" -lt "${#args[@]}" ] || { printf 'stub bunker: no shell in argv\n' >&2; exit 2; }
shell="${args[$i]}"
body="${args[$((i + 2))]:-}"
rest=("${args[@]:$((i + 3))}")
exec "$shell" -c "$body" "${rest[@]}"
EOF
# One stub probe. `127.0.0.1:10800` is the INSIDE-the-node probe (the verifier's in-node diagnostic),
# anything else is the control-host probe the transport under test carries; the two are answered
# from different variables so an arm cannot confuse "the node answers itself" with "this host
# reached it".
cat > "$cf224/bin/curl" <<'EOF'
#!/usr/bin/env bash
o="" u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) o="$2"; shift 2 ;;
    -*) shift ;;
    *) u="$1"; shift ;;
  esac
done
hp="${u#*://}"; hp="${hp%%/*}"
case "$hp" in 127.0.0.1:10800) inner=1 ;; *) inner=0 ;; esac
case "$u" in
  */api/system/stats) if [ "$inner" = 1 ]; then c="${CURL_IN_STATS:-401}"; else c="${CURL_STATS:-401}"; fi ;;
  *)                  if [ "$inner" = 1 ]; then c="${CURL_IN:-200}"; else c="${CURL_CODE:-200}"; fi ;;
esac
if [ -n "$o" ] && [ "$o" != /dev/null ]; then printf '%s' '{"status":"ok","auth_required":true}' > "$o"; fi
printf '%s' "$c"
EOF
chmod +x "$cf224/bin/bunker" "$cf224/bin/curl"
# The fixture node home: a real applied seed record and a clean checkout level with its origin, so
# steps 1/5/6 are green and the only thing any arm below moves is the transport.
printf 'prompts/foreman.md\n' > "$cf224/seed.manifest"
printf 'the foreman procedure\n' > "$cf224/seed-src/prompts/foreman.md"
python3 -B "$HERE/scripts/node_seed.py" build --manifest "$cf224/seed.manifest" \
  --repo-root "$cf224/seed-src" --out "$cf224/seed.tar" >/dev/null 2>&1
python3 -B "$HERE/scripts/node_seed.py" apply --tar "$cf224/seed.tar" \
  --record "$cf224/seed.tar.json" --home "$cf224/home" >/dev/null 2>&1
git init -q -b main --bare "$cf224/origin.git"
git clone -q "$cf224/origin.git" "$cf224/home/repo" 2>/dev/null
git -C "$cf224/home/repo" -c user.email=fixture@example.invalid -c user.name=fixture \
  commit -qm fixture --allow-empty
git -C "$cf224/home/repo" push -q -u origin main
git -C "$cf224/home/repo" fetch -q origin
cf224_run() {  # cf224_run <tree> [verify-node args...] — the fixture home is the "node"
  local tree="$1"; shift
  env -i PATH="$cf224/bin:$PATH" HOME="$cf224/home" FIXTURE_IP="${FIXTURE_IP:-}" \
    CURL_CODE="${CURL_CODE:-200}" CURL_IN="${CURL_IN:-200}" \
    CURL_STATS="${CURL_STATS:-401}" CURL_IN_STATS="${CURL_IN_STATS:-401}" \
    /bin/bash "$tree/scripts/verify-node.sh" --agent cf-fixture --server fixture "$@" 2>&1
}

# 1. The pre-fix control: this verifier had no transport at all, so an operator on a bunker could
#    not even declare one. That is the row's premise, measured rather than asserted.
if [ "$cf224_prefix" -eq 1 ]; then
  out=$(cf224_run "$cf224/prefix" --transport published-port --transport-address 203.0.113.9:10800); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -Fq 'unknown arg: --transport'; then
    say "  PASS  pre-fix bf16c05 has no --transport: exit $rc, 'unknown arg: --transport' (CF-224 premise)"
  else
    say "  FAIL  the pre-fix verifier did not refuse --transport (exit $rc): $(printf '%s\n' "$out" | head -2 | tr '\n' ' ')"
    fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source bf16c05:scripts/verify-node.sh unavailable"; fails=$((fails+1))
fi

# 2. The wrong behaviour, recorded: a node that reports only loopback PASSes the pre-fix verifier
#    because the probe answered on THIS host — nothing names a transport, so nothing exposes it.
if [ "$cf224_prefix" -eq 1 ]; then
  out=$(FIXTURE_IP=127.0.0.1 cf224_run "$cf224/prefix"); rc=$?
  if [ "$rc" -eq 0 ] \
    && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
    && printf '%s\n' "$out" | grep -Fxq '  PASS  gateway_reachable — http://127.0.0.1:10800/api/status -> 200' \
    && ! printf '%s\n' "$out" | grep -q '^  PASS  transport'; then
    say "  PASS  pre-fix bf16c05 certifies a loopback-only node: VERIFY: PASS, exit $rc, no transport row (the fixture detects CF-224)"
  else
    say "  FAIL  the pre-fix loopback control did not pass (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
    fails=$((fails+1))
  fi
fi

# 3. Same fixture, this verifier: a loopback address is not a transport, so the run cannot pass.
out=$(FIXTURE_IP=127.0.0.1 cf224_run "$cf224/tree"); rc=$?
if [ "$rc" -eq 3 ] \
  && printf '%s\n' "$out" | grep -Fq '  WARN  transport — node-address 127.0.0.1:10800 — refused:' \
  && printf '%s\n' "$out" | grep -Fq 'no LAN address for cf-fixture' \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED' \
  && ! printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && ! printf '%s\n' "$out" | grep -Fq 'PASS  gateway_reachable'; then
  say "  PASS  a loopback-only node -> exit $rc, named transport refusal, VERIFY: UNVERIFIED (never a PASS row)"
else
  say "  FAIL  a loopback node was not refused as unverified (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 4. The local behaviour is preserved: a node on a reachable address still verifies, and the row now
#    says which transport carried the probe.
out=$(FIXTURE_IP=192.0.2.10 cf224_run "$cf224/tree"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  transport — node-address 192.0.2.10:10800 — the node'"'"'s own address, probed from this host (the LAN case; a bunker node has no LAN address by default)' \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  gateway_reachable — http://192.0.2.10:10800/api/status -> 200 (transport: node-address)'; then
  say "  PASS  a reachable node-address -> VERIFY: PASS, exit $rc, the row names node-address and the measured 200"
else
  say "  FAIL  a reachable node-address did not verify (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 5. A published port is the bunker transport: the probe runs HERE and the row names it.
out=$(cf224_run "$cf224/tree" --transport published-port --transport-address 203.0.113.9:10800); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fq '  PASS  transport — published-port 203.0.113.9:10800 — a port published on the bunker host, probed from this host (never inside the node)' \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  gateway_reachable — http://203.0.113.9:10800/api/status -> 200 (transport: published-port)'; then
  say "  PASS  --transport published-port -> VERIFY: PASS, exit $rc, the gateway row names the transport and the code"
else
  say "  FAIL  a published port did not verify (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 6. An unavailable transport is NAMED, and no row prints a bare 000 (criterion 4).
out=$(CURL_CODE=000 cf224_run "$cf224/tree" --transport published-port --transport-address 203.0.113.9:10800); rc=$?
cf224_why=$(printf '%s\n' "$out" | grep -F '  WARN  gateway_reachable — no published port for cf-fixture:10800')
if [ "$rc" -eq 3 ] && [ -n "$cf224_why" ] \
  && printf '%s\n' "$out" | grep -Eq '^VERIFY: UNVERIFIED' \
  && ! printf '%s\n' "$out" | grep -Eq -- '-> 000|000000'; then
  say "  PASS  no published port -> exit $rc, 'no published port for cf-fixture:10800' in the row, and no 000 anywhere in the output"
else
  say "  FAIL  an unavailable published port was not named (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 7. A tunnel endpoint on THIS host is legal even when it is loopback, because the declaration says
#    what it is: the request still originates here and re-enters the node through the forward.
out=$(cf224_run "$cf224/tree" --transport tunnel --transport-address 127.0.0.1:18080); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
  && printf '%s\n' "$out" | grep -Fxq '  PASS  gateway_reachable — http://127.0.0.1:18080/api/status -> 200 (transport: tunnel)'; then
  say "  PASS  --transport tunnel 127.0.0.1:18080 -> VERIFY: PASS, exit $rc (a declared forward, not a node-internal loopback)"
else
  say "  FAIL  a declared tunnel endpoint did not verify (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -5 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 8. Criterion 3: a probe that never leaves the node is a FAIL, not a PASS — even though it measures
#    a 200 from the gateway's own loopback.
out=$(cf224_run "$cf224/tree" --transport bunker-exec); rc=$?
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  gateway_reachable — loopback inside the node -> 200 (transport: bunker-exec)' \
  && printf '%s\n' "$out" | grep -Fq 'a request that did not leave the node proves nothing about reachability, so this is a FAIL, not a PASS' \
  && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (2)' \
  && ! printf '%s\n' "$out" | grep -Fq 'PASS  gateway_reachable' \
  && ! printf '%s\n' "$out" | grep -Eq '^VERIFY: (PASS|UNVERIFIED)'; then
  say "  PASS  --transport bunker-exec -> exit $rc, named loopback FAIL, VERIFY: FAIL (2) (never PASS, never UNVERIFIED)"
else
  say "  FAIL  an in-node loopback probe was not a FAIL (exit $rc): $(printf '%s\n' "$out" | grep -E '^(  (PASS|FAIL|WARN))|^VERIFY' | head -6 | tr '\n' ' ')"
  fails=$((fails+1))
fi

# 9. The transport flags fail closed as usage, so no run silently probes something nobody declared.
cf224_usage() {  # cf224_usage <expect-substring> [args...]
  local want="$1"; shift
  local got rc2
  got=$(FIXTURE_IP=192.0.2.10 cf224_run "$cf224/tree" "$@" 2>&1); rc2=$?
  [ "$rc2" -eq 2 ] && printf '%s\n' "$got" | grep -Fq -- "$want"
}
if cf224_usage '--transport must be node-address, published-port, tunnel or bunker-exec (got: bogus)' --transport bogus \
  && cf224_usage '--transport published-port needs --transport-address HOST:PORT' --transport published-port \
  && cf224_usage '--transport-address is used by --transport published-port|tunnel only' \
       --transport node-address --transport-address 203.0.113.9:10800; then
  say "  PASS  a bad transport, a missing address and an address with no transport are each exit 2 with a named refusal"
else
  say "  FAIL  the transport usage refusals did not all hold"; fails=$((fails+1))
fi
rm -rf "$cf224"
# END cf224-transport

# ch:trace row=CF-211 spec=specs/ENVELOPE.md#result-node--reply_to-inbox wave=none:serial-worker test=tests/test_bus_result_delivery.py doc=specs/ENVELOPE.md prompt=none:worker-brief evidence=tests/test_bus_result_delivery.py witness=none:local-fixture verdict=none:foreman-runs-judge commit=none:self-referential-hash memory=none:foreman-closeout
say "63. a node result completes a tick, fails one, and a wrong corr_id completes nothing (CF-211)"
# The scheduler always had the RECEIVING half: dispatch_leg.go polls its own inbox, correlates by
# in_reply_to / corr_id, acks and derives a verdict. What had never been exercised is the
# PRODUCING half — and two things were missing from it. The scheduler reads `payload["ok"]` and
# treats its ABSENCE as success, so a node that only said `"status": "failed"` had its failure
# closed as a COMPLETED tick; and a result was cached only AFTER delivery, so a refused or lost
# delivery re-ran the harness instead of re-sending the result. The fixture drives the REAL worker
# CLI against one stub relay that speaks crier's documented inbox surface, and models the
# scheduler's consumer from its own code (pinned by anchors in dispatch_leg.go when a checkout is
# present) plus the scheduler's own test names. No network, no credential, no live node.
cf211=$(mktemp -d)
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_bus_result_delivery.py" \
     >"$cf211/out" 2>&1; then
  say "  PASS  completed + failed results POST to reply_to before the ack; a mismatched corr_id expires the tick and is named; a refused/lost delivery retries with the same key and never re-runs the work"
else
  say "  FAIL  the result leg on the producing side (tests/test_bus_result_delivery.py)"
  fails=$((fails+1))
  sed 's/^/    | /' "$cf211/out"
fi
# ARM (red control): the SAME fixture against the revision this row was raised on. It must show no
# `ok`/`in_reply_to`/idempotency key, a failed gate read as a completed tick, and a redelivery that
# re-runs the harness — pointed at the fixed worker the control fails, so it discriminates.
if git -C "$HERE" show 9af58a0:scripts/node-bus-worker.py > "$cf211/node-bus-worker.py" 2>/dev/null; then
  if CF_BUS_WORKER_SOURCE="$cf211/node-bus-worker.py" CF_BUS_RESULT_PREFIX_CONTROL=1 \
       PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_bus_result_delivery.py" \
       >"$cf211/prefix" 2>&1; then
    say "  PASS  pre-fix 9af58a0 completes a failed gate and re-runs on redelivery (fixture detects CF-211)"
  else
    say "  FAIL  pre-fix control did not reproduce the result-leg defect"
    fails=$((fails+1))
    sed 's/^/    | /' "$cf211/prefix"
  fi
else
  say "  FAIL  pre-fix source unavailable (git show 9af58a0:scripts/node-bus-worker.py)"
  fails=$((fails+1))
fi
# The contract the arms assert is only the contract if the spec states it: the verdict field, the
# path home, the correlation rule, the durable-delivery rule and the ack-after-delivery rule.
cf211_doc_missing=""
for cf211_anchor in \
  '`ok` is the field the scheduler reads' \
  'POSTs the result envelope into the inbox named by the dispatch' \
  'never completes a tick' \
  'idempotency_key` derived from the **dispatch alone**' \
  'only after** its result' ; do
  grep -Fq -- "$cf211_anchor" "$HERE/specs/ENVELOPE.md" || cf211_doc_missing="$cf211_doc_missing [$cf211_anchor]"
done
if [ -z "$cf211_doc_missing" ]; then
  say "  PASS  specs/ENVELOPE.md states the verdict field, the path home, the correlation rule, the delivery budget/key and the ack-after-delivery rule"
else
  say "  FAIL  specs/ENVELOPE.md no longer documents:$cf211_doc_missing"
  fails=$((fails+1))
fi
rm -rf "$cf211"

# ch:trace row=CF-226 spec=specs/HARNESS.md#the-verdict-line wave=none:serial test=tests/harness/dsh-install-test.sh doc=specs/HARNESS-MATRIX.md#5-the-variable-contract--what-an-installer-and-a-harness-are-given prompt=none:worker-brief evidence=tests/harness/dsh-install-test.sh witness=none:local-fixture verdict=none:foreman-runs-judge commit=none:self-referential-hash memory=none:foreman-closeout
say "64. a credential-less --turn reaches the dsh adapter's documented SKIP before the §5 run set is required (CF-226)"
# CF-226: install-dsh.sh forced `cfv_validate contract` for --turn and called require_run_set in
# main, both BEFORE do_turn's credential gate — so with no credential the adapter exited 2
# "contract:required" and its documented SKIP (exit 3, specs/HARNESS.md "The verdict line") was
# unreachable. The adapter's own test asserted the SKIP, so the shipped test and the shipped
# subject disagreed; nothing in this suite ran that test, so the suite stayed green on the defect.
# This section runs the test file and then runs the SAME file against the pre-fix subject, where it
# must fail: a test that cannot fail on the defect is decoration (AGENTS.md rule 2). The test is
# hermetic here — a stub launcher reports the pin, so no credential, no network and no model turn.
dsh_env=(env -u DEEPSEEK_API_KEY -u CF_API_KEY_FILE -u CF_API_KEY -u DSH_API_KEY
         -u CF_MODEL -u CF_PROVIDER -u CF_WORKDIR -u CF_NAMESPACE -u CF_RUN_ID -u CF_LANE)
out=$("${dsh_env[@]}" bash "$HERE/tests/harness/dsh-install-test.sh" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^DSH-INSTALL-TEST: PASS' \
  && printf '%s\n' "$out" | grep -q '^  SKIP  no DeepSeek credential on this host'; then
  say "  PASS  tests/harness/dsh-install-test.sh is green ($(printf '%s\n' "$out" | grep -c '^  PASS') rows), with the live turn skipped by name"
else
  say "  FAIL  tests/harness/dsh-install-test.sh (exit $rc): $(printf '%s\n' "$out" | grep -E '^  FAIL|^DSH-INSTALL-TEST|^  SKIP' | head -4 | tr '\n' ' ')"
  fails=$((fails+1))
fi
# A green aggregate is not enough: the rows that decide the ordering must be present, so gutting
# the test into a bare `exit 0` cannot satisfy this section.
dsh_absent=""
for dsh_want in \
  'PASS  --turn reports SKIP with exit 3 when no credential exists' \
  'PASS  the run-set check does not pre-empt the credential gate' \
  'PASS  the skipped turn started nothing (the only launcher call was --version)' \
  'PASS  a credential-present --turn with no §5 run set is still refused' \
  'PASS  the refusal names every missing §5 run-set variable' ; do
  printf '%s\n' "$out" | grep -Fq -- "$dsh_want" || dsh_absent="$dsh_absent [$dsh_want]"
done
if [ -z "$dsh_absent" ]; then
  say "  PASS  the rows that decide the ordering are present: SKIP/3, no run-set refusal before it, nothing started, and the strict refusal kept"
else
  say "  FAIL  the dsh test did not print:$dsh_absent"
  fails=$((fails+1))
fi
# The red control: the same test file against the subject revision this row was raised on.
dsh_prefix=$(mktemp -d)
mkdir -p "$dsh_prefix/scripts/harness" "$dsh_prefix/tests/harness"
if git -C "$HERE" show 899bfe5:scripts/harness/install-dsh.sh > "$dsh_prefix/scripts/harness/install-dsh.sh" 2>/dev/null \
  && cp "$HERE/scripts/lib.sh" "$dsh_prefix/scripts/lib.sh" \
  && cp "$HERE/scripts/harness/harness-vars.sh" "$dsh_prefix/scripts/harness/harness-vars.sh" \
  && cp "$HERE/tests/harness/dsh-install-test.sh" "$dsh_prefix/tests/harness/dsh-install-test.sh"; then
  chmod +x "$dsh_prefix/scripts/harness/install-dsh.sh"
  rout=$("${dsh_env[@]}" bash "$dsh_prefix/tests/harness/dsh-install-test.sh" 2>&1); rrc=$?
  if [ "$rrc" -ne 0 ] \
    && printf '%s\n' "$rout" | grep -q 'refused the §5 run set before the credential gate'; then
    say "  PASS  pre-fix 899bfe5 fails the same test on the ordering row (exit $rrc) — this section discriminates"
  else
    say "  FAIL  pre-fix 899bfe5 did not fail the ordering row (exit $rrc): $(printf '%s\n' "$rout" | grep -E '^  FAIL|^DSH-INSTALL-TEST' | head -3 | tr '\n' ' ')"
    fails=$((fails+1))
  fi
else
  say "  FAIL  pre-fix source unavailable (git show 899bfe5:scripts/harness/install-dsh.sh)"
  fails=$((fails+1))
fi
rm -rf "$dsh_prefix"

say "65. resolver and ladder role tables stay in pair parity (CF-299)"
cf299=$(mktemp -d)
cf299_clean=$(python3 "$HERE/scripts/check_role_parity.py" 2>&1); cf299_clean_rc=$?
if [ "$cf299_clean_rc" -eq 0 ] && printf '%s\n' "$cf299_clean" | grep -q '^PASS role parity:'; then
  say "  PASS  clean role tables -> exit 0: $(printf '%s\n' "$cf299_clean" | grep '^PASS role parity:')"
else
  say "  FAIL  clean role tables -> exit $cf299_clean_rc: $cf299_clean"
  fails=$((fails+1))
fi
mkdir -p "$cf299/ladder/scripts" "$cf299/resolver/scripts" "$cf299/marker/scripts"
cp "$HERE/scripts/check_role_parity.py" "$cf299/ladder/scripts/check_role_parity.py"
cp "$HERE/scripts/check_role_parity.py" "$cf299/resolver/scripts/check_role_parity.py"
cp "$HERE/scripts/check_role_parity.py" "$cf299/marker/scripts/check_role_parity.py"
cp "$HERE/scripts/disk_floor.py" "$cf299/ladder/scripts/disk_floor.py"
cp "$HERE/scripts/project-node.sh" "$cf299/ladder/scripts/project-node.sh"
cp "$HERE/scripts/disk_floor.py" "$cf299/resolver/scripts/disk_floor.py"
cp "$HERE/scripts/project-node.sh" "$cf299/resolver/scripts/project-node.sh"
cp "$HERE/scripts/disk_floor.py" "$cf299/marker/scripts/disk_floor.py"
cp "$HERE/scripts/project-node.sh" "$cf299/marker/scripts/project-node.sh"
sed -i 's/builder) FLOOR_BUILTIN=10/builder) FLOOR_BUILTIN=12/' "$cf299/ladder/scripts/project-node.sh"
sed -i 's/"full": 20/"full": 25/' "$cf299/resolver/scripts/disk_floor.py"
sed -i 's/worker) FLOOR_BUILTIN=5/wkr) FLOOR_BUILTIN=5/' "$cf299/marker/scripts/project-node.sh"
cf299_ladder=$(python3 "$cf299/ladder/scripts/check_role_parity.py" --root "$cf299/ladder" 2>&1); cf299_ladder_rc=$?
cf299_resolver=$(python3 "$cf299/resolver/scripts/check_role_parity.py" --root "$cf299/resolver" 2>&1); cf299_resolver_rc=$?
cf299_marker=$(python3 "$cf299/marker/scripts/check_role_parity.py" --root "$cf299/marker" 2>&1); cf299_marker_rc=$?
if [ "$cf299_ladder_rc" -eq 1 ] && printf '%s\n' "$cf299_ladder" | grep -q '^FAIL role builder: resolver=10; ladder=12$'; then
  say "  PASS  ladder mutation -> exit 1: $(printf '%s\n' "$cf299_ladder" | grep '^FAIL role builder:')"
else
  say "  FAIL  ladder mutation -> exit $cf299_ladder_rc: $cf299_ladder"
  fails=$((fails+1))
fi
if [ "$cf299_resolver_rc" -eq 1 ] && printf '%s\n' "$cf299_resolver" | grep -q '^FAIL role full: resolver=25; ladder=20$'; then
  say "  PASS  resolver mutation -> exit 1: $(printf '%s\n' "$cf299_resolver" | grep '^FAIL role full:')"
else
  say "  FAIL  resolver mutation -> exit $cf299_resolver_rc: $cf299_resolver"
  fails=$((fails+1))
fi
if [ "$cf299_marker_rc" -eq 1 ] && printf '%s\n' "$cf299_marker" | grep -q '^FAIL role-set drift:'; then
  say "  PASS  case marker mutation -> exit 1: $(printf '%s\n' "$cf299_marker" | grep '^FAIL role-set drift:')"
else
  say "  FAIL  case marker mutation -> exit $cf299_marker_rc: $cf299_marker"
  fails=$((fails+1))
fi
cf299_dirty=$(git -C "$HERE" status --porcelain -- scripts/disk_floor.py)
if [ -z "$cf299_dirty" ]; then
  say "  PASS  fixture mutations stayed in scratch copies; tracked role-table files are unchanged"
else
  say "  FAIL  fixture mutation changed tracked files: $cf299_dirty"
  fails=$((fails+1))
fi
rm -rf "$cf299"

# CF-008 lifecycle arm: keep this inside the existing section census; supervisor, lease,
# process-group cancellation and destroy/create replay are one row-specific battery.
# The fixture owns every process and state file; live bunker state is intentionally UNVERIFIED.
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/test_node_lifecycle.py" >/dev/null 2>&1; then
  say "  PASS  CF-008 lifecycle supervisor restart evidence, TTL renewal/refusal, process-group cancellation and destroy/create replay"
else
  say "  FAIL  CF-008 lifecycle battery"
  fails=$((fails+1))
fi
# CF-398 arm: keep this inside the existing section census; evidence pointers are an
# additive board invariant, not a new numbered selftest section.
cf398_out=$(python3 "$HERE/scripts/board_evidence_check.py" --quiet-findings 2>&1); cf398_rc=$?
cf398_count=$(printf '%s\n' "$cf398_out" | tail -1)
cf398_named=$(printf '%s\n' "$cf398_out" | sed -n 's/^expected_unresolved=\([0-9][0-9]*\) .*/\1/p')
if printf '%s\n' "$cf398_count" | grep -Eq '^checked [0-9]+ complete rows, [0-9]+ unresolved$'; then
  cf398_unresolved=$(printf '%s\n' "$cf398_count" | sed -E 's/^checked [0-9]+ complete rows, ([0-9]+) unresolved$/\1/')
  python3 "$HERE/scripts/board_evidence_check.py" --strict --quiet-findings >/dev/null 2>&1; cf398_strict_rc=$?
  cf398_expected_strict=0
  [ "$cf398_unresolved" -gt 0 ] && cf398_expected_strict=1
else
  cf398_unresolved=-1
  cf398_strict_rc=2
  cf398_expected_strict=2
fi
if [ "$cf398_rc" -eq 0 ] \
  && [ "$cf398_strict_rc" -eq "$cf398_expected_strict" ] \
  && [ "$cf398_unresolved" -ge 0 ] \
  && [ -n "$cf398_named" ] \
  && [ "$cf398_named" = "$cf398_unresolved" ]; then
  cf398_display=${cf398_count#checked }
  say "  PASS  CF-398 evidence checker reports a derived count ($cf398_display) and --strict matches it"
else
  say "  FAIL  CF-398 evidence checker (exit $cf398_rc, strict $cf398_strict_rc): $cf398_count"
  fails=$((fails+1))
fi

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

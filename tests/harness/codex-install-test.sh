#!/usr/bin/env bash
# tests/harness/codex-install-test.sh — standalone proof for scripts/harness/install-codex.sh (CF-227).
#
#   ./tests/harness/codex-install-test.sh            # everything
#   ./tests/harness/codex-install-test.sh --hermetic  # no network, no real turn
#
# Two halves, deliberately separated:
#
#   HERMETIC  every refusal and the whole install ladder, against a fake $HOME and a local
#             mirror tarball whose digest the test computes itself. No network, no credential,
#             no real codex: the stub binary reports whatever version the case needs, which is
#             how the version-mismatch arm can go red on purpose.
#   LIVE      one real turn that must write a fixed token, and the app-server probe, against the
#             installed pin. These SKIP — with the reason named — when there is no binary at the
#             pin or no credential surface, because a skipped leg that names why is honest and a
#             green leg that never ran is not.
#
# Exit 0 only when every non-skipped assertion passed.
#
# ch:trace row=CF-384 spec=specs/HARNESS.md#verdict-line wave=none:serial-worker test=tests/harness/codex-install-test.sh::codex-warn-classification doc=docs/handbook/chapters/M5-harness.md prompt=~/.../CF-384-brief.txt evidence=tests/harness/codex-install-test.sh verdict=none:foreman-runs-gitreins-after-worker commit=none:worker-commit-created-at-exit memory=none:foreman-writes-after-publish witness=none:foreman-verifies
# STATUS: complete
# TIER: T1
# EVIDENCE: tests/harness/codex-install-test.sh
#
# CF-384: the arms B5 (positive) and B5b (negative) are the `codex-warn-classification` pair. B5
# proves the two former WARN rows (app_server, auth-with-host-login) are notes that cannot move the
# verdict; B5b proves a genuine WARN (no credential surface at all) still ends `CODEX: UNVERIFIED`
# with exit 3. Both are required: either one alone is satisfiable by the wrong code.
set -uo pipefail
HERE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALLER="$HERE_REPO/scripts/harness/install-codex.sh"
PIN_DEFAULT=0.166.0
MODE="${1:-}"

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$*"; }
no()   { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %s\n' "$*"; }
say()  { printf '%s\n' "$*"; }

# A synthetic value that is not a credential. Built from parts so no assignment in this file
# looks like a literal key to the tree-hygiene grep in tests/selftest.sh (AGENTS.md r8).
SYNTH_KEY="sk-$(printf 'cf227-test-%s' 'not-a-real-credential')"

SB="$(mktemp -d "${TMPDIR:-/tmp}/cf227-codex-test.XXXXXXXX")"
cleanup() { rm -rf "$SB" "${TURN_W:-}"; }
trap cleanup EXIT INT TERM

# Every case runs with a clean credential environment: an inherited key must never be the thing
# that makes a case pass.
clean_env() { env -u OPENAI_API_KEY -u CF_API_KEY -u ANTHROPIC_API_KEY "$@"; }

run() {  # run <outfile> <cmd...>  → echoes exit code, leaves stdout+stderr in <outfile>
  local out="$1"; shift
  clean_env "$@" >"$out" 2>&1
  printf '%s' "$?"
}

run_home() {  # run_home <home> <outfile> <cmd...> — the same, with $HOME replaced
  local home="$1" out="$2"; shift 2
  clean_env HOME="$home" "$@" >"$out" 2>&1
  printf '%s' "$?"
}

# The full §4 set, minus the key file: --workdir cannot be refused for a bad path until the
# required set is complete, so every workdir case supplies it.
FULL_SET=(--model gpt-5.6-luna --provider openai-codex --namespace code-factory --run-id r-lane --lane cf-qa)

expect_refused() {  # expect_refused <label> <outfile> <rc> [needle]
  local label="$1" out="$2" rc="$3" needle="${4:-}"
  if [ "$rc" != "2" ]; then no "$label — expected REFUSED (exit 2), got $rc"; return 1; fi
  grep -q 'CODEX: REFUSED' "$out" || { no "$label — no 'CODEX: REFUSED' line"; return 1; }
  if [ -n "$needle" ] && ! grep -qF -- "$needle" "$out"; then
    no "$label — the refusal does not name '$needle'"; return 1
  fi
  ok "$label — refused and named the reason"
}

say "codex installer test (CF-227) — installer: $INSTALLER"
[ -x "$INSTALLER" ] || { say "  FAIL  installer is missing or not executable: $INSTALLER"; exit 1; }
bash -n "$INSTALLER" && ok "bash -n is clean" || no "bash -n reports a syntax error"

# ---------------------------------------------------------------------------------------------
say ""
say "A. refusals — a credential as a VALUE, ambient keys, bad input"
# ---------------------------------------------------------------------------------------------
O="$SB/a1.out"
rc=$(run "$O" "$INSTALLER" --check --api-key "$SYNTH_KEY")
expect_refused "A1 --api-key <value> is refused" "$O" "$rc" "credential_argv"
grep -qF -- "$SYNTH_KEY" "$O" && no "A1 the credential value was echoed into the output" \
  || ok "A1 the credential value never appears in the output"

O="$SB/a2.out"
rc=$(clean_env CF_API_KEY="$SYNTH_KEY" "$INSTALLER" --check >"$O" 2>&1; echo $?)
expect_refused "A2 CF_API_KEY in the environment is refused" "$O" "$rc" "credential_ambient"
grep -qF -- "$SYNTH_KEY" "$O" && no "A2 the ambient credential value was echoed" \
  || ok "A2 the ambient credential value never appears in the output"

O="$SB/a3.out"
rc=$(env -u CF_API_KEY OPENAI_API_KEY="$SYNTH_KEY" "$INSTALLER" --check >"$O" 2>&1; echo $?)
expect_refused "A3 OPENAI_API_KEY in the environment is refused" "$O" "$rc" "credential_ambient"

O="$SB/a4.out"
rc=$(run "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir /etc)
expect_refused "A4 a CF_WORKDIR outside \$HOME is refused" "$O" "$rc" "CF_WORKDIR"

O="$SB/a5.out"
rc=$(run "$O" "$INSTALLER" --check --model gpt-5.6-luna)
expect_refused "A5 an incomplete CF_* set is refused and names what is missing" "$O" "$rc" "CF_WORKDIR"

O="$SB/a6.out"
rc=$(run "$O" "$INSTALLER" --check --frobnicate)
expect_refused "A6 an unknown argument is refused" "$O" "$rc" "unknown argument"

O="$SB/a7.out"
rc=$(run "$O" "$INSTALLER" --check --api-key-file /nonexistent/key)
expect_refused "A7 a missing CF_API_KEY_FILE is refused" "$O" "$rc" "does not exist"

# A mode-644 key file is a FAIL by name; the same file at 600 is accepted.
FAKEHOME="$SB/home"; mkdir -p "$FAKEHOME/.local/bin" "$FAKEHOME/keys" "$FAKEHOME/work"
git -C "$FAKEHOME/work" init -q >/dev/null 2>&1
git -C "$FAKEHOME/work" -c user.email=cf227@local -c user.name=cf227 commit -q --allow-empty -m init >/dev/null 2>&1
printf '%s\n' "$SYNTH_KEY" >"$FAKEHOME/keys/provider.key"
chmod 644 "$FAKEHOME/keys/provider.key"
HOME="$FAKEHOME" run "$SB/a8.out" "$INSTALLER" --check --api-key-file "$FAKEHOME/keys/provider.key" >/dev/null
rc=$(clean_env HOME="$FAKEHOME" "$INSTALLER" --check --api-key-file "$FAKEHOME/keys/provider.key" >"$SB/a8.out" 2>&1; echo $?)
expect_refused "A8 a CF_API_KEY_FILE that is mode 644 is refused" "$SB/a8.out" "$rc" "mode 600"
grep -qF -- "$SYNTH_KEY" "$SB/a8.out" && no "A8 the key file's value was echoed" \
  || ok "A8 the key file's value never appears in the output"

chmod 600 "$FAKEHOME/keys/provider.key"
O="$SB/a9.out"
rc=$(run_home "$FAKEHOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" \
      --workdir "$FAKEHOME/work" --api-key-file "$FAKEHOME/keys/provider.key")
if [ "$rc" = "2" ]; then
  no "A9 a mode-600 key file inside \$HOME must be accepted (got a refusal)"; sed 's/^/        /' "$O"
else
  grep -qF -- "$SYNTH_KEY" "$O" && no "A9 the key file's value was printed" \
    || ok "A9 a mode-600 key file inside \$HOME is accepted, and its value is never printed"
fi

O="$SB/a10.out"
rc=$(clean_env HOME="$FAKEHOME" CF_CODEX_ARCH=aarch64 "$INSTALLER" --apply >"$O" 2>&1; echo $?)
expect_refused "A10 an arch with no measured artefact is refused, not faked" "$O" "$rc" "no measured codex artefact"

O="$SB/a11.out"
mkdir -p "$FAKEHOME/notrepo"
rc=$(run_home "$FAKEHOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir "$FAKEHOME/notrepo")
expect_refused "A11 a CF_WORKDIR that is not a git work tree is refused" "$O" "$rc" "not a git work tree"

# ---------------------------------------------------------------------------------------------
say ""
say "B. the install ladder — fake \$HOME, local mirror tarball, digest enforced"
# ---------------------------------------------------------------------------------------------
# A stub that behaves like the real CLI for every surface the installer probes.
STUB="$SB/stub/codex"
mkdir -p "$(dirname "$STUB")"
stub_body() {  # stub_body <version string>
  cat >"$STUB" <<STUBEOF
#!/usr/bin/env bash
case "\$1" in
  --version) echo "codex-cli $1"; exit 0 ;;
  exec)
    if [ "\${2:-}" = "resume" ]; then echo "Resume a previous session by id"; exit 0; fi
    if [ "\${2:-}" = "--help" ]; then
      printf 'Run Codex non-interactively\n  -m, --model <MODEL>\n  -s, --sandbox <MODE>\n      --json\n      --skip-git-repo-check\n'; exit 0
    fi
    echo '{"type":"thread.started","thread_id":"stub"}'; exit 0 ;;
  app-server) echo "[experimental] Run the app server"; exit 0 ;;
esac
echo "stub codex: unsupported \$*" >&2; exit 64
STUBEOF
  chmod +x "$STUB"
}
stub_body "$PIN_DEFAULT"
TAR="$SB/mirror/codex-x86_64-unknown-linux-musl.tar.gz"
mkdir -p "$SB/mirror/root"
cp "$STUB" "$SB/mirror/root/codex-x86_64-unknown-linux-musl"
tar czf "$TAR" -C "$SB/mirror/root" codex-x86_64-unknown-linux-musl
TAR_SHA=$(sha256sum "$TAR" | cut -d' ' -f1)
ok "mirror artefact built locally (sha256 ${TAR_SHA:0:12}…)"

# CF-006: the exec file-write sidecar is a SECOND pinned artefact of the same release. The fixture
# mirrors it too, so the sidecar leg is measured with no network and its digest is enforced exactly
# like the main one — a ladder that installed it from an unpinned URL would not be testable here.
CMH_STUB="$SB/mirror/root-cmh/codex-code-mode-host-x86_64-unknown-linux-musl"
mkdir -p "$(dirname "$CMH_STUB")"
cat >"$CMH_STUB" <<'CMHEOF'
#!/usr/bin/env bash
case "${1:-}" in
  -h|--help) printf 'Usage: codex-code-mode-host [OPTIONS]\n'; exit 0 ;;
  *) exit 0 ;;
esac
CMHEOF
chmod +x "$CMH_STUB"
CMH_TAR="$SB/mirror/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz"
tar czf "$CMH_TAR" -C "$SB/mirror/root-cmh" codex-code-mode-host-x86_64-unknown-linux-musl
CMH_SHA=$(sha256sum "$CMH_TAR" | cut -d' ' -f1)
ok "mirror sidecar built locally (sha256 ${CMH_SHA:0:12}…)"
# Both artefacts the ladder fetches are redirected at the local mirror for every --apply arm below;
# an arm that forgets one would reach the network, so the pair travels together.
MIRROR_ENV=(CF_CODEX_URL="file://$TAR" CF_CODEX_SHA256="$TAR_SHA"
            CF_CODEX_CMH_URL="file://$CMH_TAR" CF_CODEX_CMH_SHA256="$CMH_SHA")

# B1 — --check on an empty home reports absence, and says so with a FAIL.
BARE="$SB/home-bare"; mkdir -p "$BARE"
O="$SB/b1.out"
# A bare box also means a PATH with no codex on it: the host's own shim must not answer for it.
rc=$(clean_env HOME="$BARE" PATH="/usr/local/bin:/usr/bin:/bin" "$INSTALLER" --check >"$O" 2>&1; echo $?)
grep -q 'FAIL  binary — absent' "$O" && [ "$rc" = "1" ] \
  && ok "B1 --check on a bare box reports absence honestly (exit 1)" \
  || no "B1 --check on a bare box should print 'FAIL binary — absent' and exit 1 (rc=$rc)"

# B2 — a digest that does not match the pin refuses, and nothing is installed.
O="$SB/b2.out"
rc=$(clean_env HOME="$FAKEHOME" CF_CODEX_URL="file://$TAR" CF_CODEX_SHA256="0000000000000000000000000000000000000000000000000000000000000000" \
     CF_CODEX_CMH_URL="file://$CMH_TAR" CF_CODEX_CMH_SHA256="$CMH_SHA" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
[ "$rc" = "1" ] && grep -q 'FAIL  download' "$O" && grep -q 'digest mismatch' "$O" \
  && ok "B2 a digest mismatch FAILs the download leg and names both digests" \
  || no "B2 a digest mismatch must FAIL the download leg (rc=$rc)"
[ -e "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex" ] \
  && no "B2 a mismatched download still left a binary behind" \
  || ok "B2 a mismatched download installs nothing"

# B2b — the SIDECAR digest is enforced the same way, and a mismatch leaves no sidecar behind: the
# binary lands (its own digest matched) but the run exits nonzero rather than producing a harness
# that answers and cannot write. This is the arm that keeps the CF-006 fix from becoming "fetch
# whatever the URL serves".
CMHM_HOME="$SB/home-cmh-mismatch"; mkdir -p "$CMHM_HOME"
O="$SB/b2b.out"
rc=$(clean_env HOME="$CMHM_HOME" "${MIRROR_ENV[@]}" \
     CF_CODEX_CMH_SHA256="1111111111111111111111111111111111111111111111111111111111111111" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
if [ "$rc" = "1" ] && grep -q 'FAIL  code_mode' "$O" && grep -q 'digest mismatch' "$O" \
   && [ ! -e "$CMHM_HOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host" ] \
   && [ -x "$CMHM_HOME/.local/codex/$PIN_DEFAULT/bin/codex" ]; then
  ok "B2b a sidecar digest mismatch FAILs the code_mode leg, places no sidecar, and exits 1 (the binary itself was verified)"
else
  no "B2b the sidecar digest mismatch was not refused by name (rc=$rc, sidecar $([ -e "$CMHM_HOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host" ] && echo present || echo absent))"; sed 's/^/        /' "$O" | tail -12
fi

# B3 — the pinned install succeeds, user-space, and reads the version back.
O="$SB/b3.out"
rc=$(clean_env HOME="$FAKEHOME" "${MIRROR_ENV[@]}" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
if [ "$rc" = "0" ] && grep -q 'PASS  install' "$O" && grep -q "PASS  version — $PIN_DEFAULT (pin $PIN_DEFAULT)" "$O"; then
  ok "B3 --apply installs the pin and reads the version back"
else
  no "B3 --apply should install and read back $PIN_DEFAULT (rc=$rc)"; sed 's/^/        /' "$O"
fi
[ -x "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex" ] \
  && ok "B3 the binary lives under \$HOME/.local/codex/$PIN_DEFAULT (user-space, no root)" \
  || no "B3 the binary is not at the pinned user-space path"
# CF-006: the sidecar is placed beside the binary it pairs with, which is the only path codex
# loads it from, and the ladder names it.
[ -x "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host" ] \
  && grep -q "PASS  code_mode — $FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host" "$O" \
  && ok "B3 the exec sidecar is installed beside the pin and reported by the ladder" \
  || no "B3 the exec sidecar was not installed/reported beside the pin"
[ -L "$FAKEHOME/.local/bin/codex" ] && ok "B3 the ~/.local/bin shim points at the pin" \
  || no "B3 no ~/.local/bin/codex shim"

# B4 — idempotence: a second --apply changes nothing and exits 0.
BEFORE=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex")
CMH_BEFORE=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host")
O="$SB/b4.out"
rc=$(clean_env HOME="$FAKEHOME" "${MIRROR_ENV[@]}" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
BIN_AFTER=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex")
CMH_AFTER=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host")
if [ "$rc" = "0" ] && grep -q 'already installed' "$O" && [ "$BEFORE" = "$BIN_AFTER" ] \
   && [ "$CMH_BEFORE" = "$CMH_AFTER" ]; then
  ok "B4 a second --apply is a no-op (exit 0, binary and sidecar unchanged: $BIN_AFTER / $CMH_AFTER)"
else
  no "B4 a second --apply changed something (rc=$rc, $BEFORE -> $BIN_AFTER, $CMH_BEFORE -> $CMH_AFTER)"
fi

# B5 — CF-384 codex-warn-classification, POSITIVE arm. --check on the installed fake home measures
# the binary and version legs and ends PASS (exit 0): the two rows this adapter used to WARN on are
# environment FACTS the measured exec adapter does not need, so they are notes —
#   app_server  the [experimental] subcommand exists (crier runs exec mode, never a sidecar)
#   auth        a host login exists (~/.codex/auth.json), so a turn can authenticate
# Neither absence-blocks a run, so neither may move the verdict (specs/HARNESS.md "Which conditions
# are notes, and which are WARNs"). Their TEXT is still printed, so the information is not lost.
mkdir -p "$FAKEHOME/.codex"
printf '%s\n' '{"fixture":"host login placeholder — no credential value"}' >"$FAKEHOME/.codex/auth.json"
chmod 600 "$FAKEHOME/.codex/auth.json"
O="$SB/b5.out"
rc=$(clean_env HOME="$FAKEHOME" "$INSTALLER" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "0" ] && grep -q "PASS  binary — $FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex" "$O" \
  && grep -q 'PASS  version — ' "$O" \
  && grep -qF '  ..    app_server — [experimental] app-server subcommand present' "$O" \
  && grep -qF '  ..    auth — $HOME/.codex/auth.json exists (mode 600)' "$O" \
  && [ "$(grep -c '^  WARN  ' "$O")" = 0 ] \
  && grep -qx 'CODEX: PASS' "$O"; then
  ok "B5 codex-warn-classification: --check on the installed pin with a host login ends 'CODEX: PASS' (exit 0); app_server and auth are printed as notes, 0 WARN rows"
else
  no "B5 codex-warn-classification: --check did not reach PASS with the two former WARN rows as notes (rc=$rc, $(grep -c '^  WARN  ' "$O") WARN rows)"; sed 's/^/        /' "$O"
fi

# B5b — CF-384 codex-warn-classification, NEGATIVE arm. The PASS above must not be reachable by
# deleting the warning mechanism: the same pinned binary in a home with NO credential surface at all
# still prints a genuine `WARN auth` row and ends UNVERIFIED with exit 3. app_server still exists on
# this binary, so the only row that can move the verdict here is the auth absence.
# The B5 login is removed first so no later arm inherits it — D2 below keeps the state it had before.
rm -f "$FAKEHOME/.codex/auth.json"
NOCRED="$SB/home-nocred"
mkdir -p "$NOCRED/.local"
cp -r "$FAKEHOME/.local/codex" "$NOCRED/.local/codex"
O="$SB/b5b.out"
rc=$(clean_env HOME="$NOCRED" "$INSTALLER" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "3" ] && grep -q '^  WARN  auth — no CF_API_KEY_FILE and no \$HOME/.codex/auth.json' "$O" \
  && grep -qF '  ..    app_server — [experimental] app-server subcommand present' "$O" \
  && [ "$(grep -c '^  FAIL  ' "$O")" = 0 ] \
  && grep -qx 'CODEX: UNVERIFIED' "$O"; then
  ok "B5b codex-warn-classification: a genuine WARN (no credential surface) still ends 'CODEX: UNVERIFIED' (exit 3) — the WARN mechanism is intact, the notes are not the reason PASS is reachable"
else
  no "B5b codex-warn-classification: a forced no-credential run did not end UNVERIFIED with a named WARN auth row (rc=$rc)"; sed 's/^/        /' "$O"
fi

# B6 — a version that is not the pin FAILs and names both values.
MIS="$SB/home-mismatch"
mkdir -p "$MIS/.local/codex/$PIN_DEFAULT/bin" "$MIS/.local/bin"
stub_body 0.165.0; cp "$STUB" "$MIS/.local/codex/$PIN_DEFAULT/bin/codex"
stub_body "$PIN_DEFAULT"
O="$SB/b6.out"
rc=$(clean_env HOME="$MIS" "$INSTALLER" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "1" ] && grep -q "FAIL  version — 0.165.0 != pin $PIN_DEFAULT" "$O"; then
  ok "B6 a version mismatch names both the measured value and the pin and FAILs"
else
  no "B6 the version-mismatch arm did not go red as specified (rc=$rc)"; sed 's/^/        /' "$O"
fi

# B7 — a host-provided binary on PATH is labelled, not adopted.
HOSTBIN="$SB/home-host/.local/bin"
mkdir -p "$HOSTBIN"
stub_body "$PIN_DEFAULT"; cp "$STUB" "$HOSTBIN/codex"
O="$SB/b7.out"
rc=$(clean_env HOME="$SB/home-host" PATH="$HOSTBIN:/usr/local/bin:/usr/bin:/bin" "$INSTALLER" --check >"$O" 2>&1; echo $?)
grep -q 'host-provided' "$O" && [ "$rc" = "1" ] \
  && ok "B7 a PATH binary is labelled host-provided and FAILs the binary leg" \
  || no "B7 a PATH binary must be labelled host-provided (rc=$rc)"

# B8 — CF-006: the `code_mode` row is what turns a binary-only pin red, and the PRE-FIX adapter
# (which printed no such row) calls the same tree PASS. Both halves are needed: without the row the
# defect is invisible, and without the control the row could be decoration. The pre-fix revision is
# the tree this change was made on, run against the same fake HOME with a host login so that the
# ONLY difference left is the sidecar.
CMH_MISS="$SB/home-cmh-missing"
mkdir -p "$CMH_MISS/.codex"
cp -r "$FAKEHOME/.local" "$CMH_MISS/.local"
rm -f "$CMH_MISS/.local/codex/$PIN_DEFAULT/bin/codex-code-mode-host"
printf '%s\n' '{"fixture":"host login placeholder — no credential value"}' >"$CMH_MISS/.codex/auth.json"
chmod 600 "$CMH_MISS/.codex/auth.json"
O="$SB/b8.out"
rc=$(clean_env HOME="$CMH_MISS" "$INSTALLER" --check >"$O" 2>&1; echo $?)
if [ "$rc" = "3" ] && grep -q '^  WARN  code_mode — absent at ' "$O" \
   && grep -qx 'CODEX: UNVERIFIED' "$O" && [ "$(grep -c '^  FAIL  ' "$O")" = 0 ]; then
  ok "B8 a pin installed without its exec sidecar ends 'CODEX: UNVERIFIED' (exit 3) with a named code_mode WARN"
else
  no "B8 a binary-only pin did not go UNVERIFIED with a named code_mode row (rc=$rc)"; sed 's/^/        /' "$O" | tail -12
fi
PREFIX_REV="${CF006_PREFIX_REV:-dc7641f}"
PREFIX_TREE="$SB/prefix"; mkdir -p "$PREFIX_TREE/scripts/harness"
cp "$HERE_REPO/scripts/lib.sh" "$PREFIX_TREE/scripts/lib.sh"
if git -C "$HERE_REPO" show "$PREFIX_REV:scripts/harness/install-codex.sh" >"$PREFIX_TREE/scripts/harness/install-codex.sh" 2>/dev/null; then
  chmod +x "$PREFIX_TREE/scripts/harness/install-codex.sh"
  O="$SB/b8-prefix.out"
  rc=$(clean_env HOME="$CMH_MISS" "$PREFIX_TREE/scripts/harness/install-codex.sh" --check >"$O" 2>&1; echo $?)
  if [ "$rc" = "0" ] && grep -qx 'CODEX: PASS' "$O" && ! grep -q 'code_mode' "$O"; then
    ok "B8 the pre-fix adapter ($PREFIX_REV) calls that same binary-only pin 'CODEX: PASS' with no code_mode row — the arm is falsifiable"
  else
    no "B8 the pre-fix control did not reproduce the false PASS (rc=$rc)"; sed 's/^/        /' "$O" | tail -8
  fi
else
  skip "B8 the pre-fix revision $PREFIX_REV is unavailable here (git show $PREFIX_REV:scripts/harness/install-codex.sh)"
fi

# ---------------------------------------------------------------------------------------------
say ""
say "C. live legs — the installed pin, a real credential, one real turn"
# ---------------------------------------------------------------------------------------------
REAL_BIN="$HOME/.local/codex/$PIN_DEFAULT/bin/codex"
v=""
[ -x "$REAL_BIN" ] && v=$(timeout 20 "$REAL_BIN" --version 2>/dev/null | head -1)

if [ "$MODE" = "--hermetic" ]; then
  skip "C — --hermetic: the live legs were not run"
elif [ -z "$v" ]; then
  skip "C — no binary at $REAL_BIN (run scripts/harness/install-codex.sh --apply first)"
else
  ok "C0 the installed pin answers: $v"

  O="$SB/c1.out"
  rc=$(clean_env "$INSTALLER" --app-server >"$O" 2>&1; echo $?)
  if [ "$rc" = "0" ] && grep -q 'PASS  app_server — initialize answered' "$O"; then
    ok "C1 the app-server sidecar starts on stdio and answers initialize: $(sed -n 's/.*initialize answered: \(.*\)/\1/p' "$O" | head -1)"
  else
    bad_line=$(grep -E 'FAIL|WARN' "$O" | head -1)
    skip "C1 app-server probe did not pass ($bad_line) — crier does not need it (exec mode), so this is not a FAIL"
  fi

  CRED=""
  if [ -f "$HOME/.codex/auth.json" ]; then CRED="host login ~/.codex/auth.json"; fi
  if [ -z "$CRED" ]; then
    skip "C2 — no credential surface (no ~/.codex/auth.json and no key file): a turn cannot be proved"
  else
    # The turn's workdir must be inside the REAL $HOME (the installer refuses anything else),
    # and TMPDIR may point outside it — so build this one under ~/.cache.
    W="$(mktemp -d "$HOME/.cache/cf227-turn.XXXXXXXX")"
    TURN_W="$W"
    git -C "$W" init -q >/dev/null 2>&1
    git -C "$W" -c user.email=cf227@local -c user.name=cf227 commit -q --allow-empty -m init >/dev/null 2>&1
    TOKEN="CF-227-TOKEN-7f3a9c"
    O="$SB/c2.out"
    rc=$(clean_env CF_MODEL="${CF_TEST_MODEL:-gpt-5.6-luna}" CF_PROVIDER=openai-codex \
         CF_WORKDIR="$W" CF_NAMESPACE=code-factory CF_RUN_ID="cf227-test-$$" CF_LANE=code-factory-qa \
         timeout 420 "$INSTALLER" --turn >"$O" 2>&1; echo $?)
    if [ "$rc" = "0" ] && grep -q 'PASS  artifact' "$O" && [ -f "$W/codex-turn.txt" ] \
       && [ "$(tr -d '\r' <"$W/codex-turn.txt")" = "$TOKEN" ]; then
      ok "C2 one real turn ($CRED) wrote $W/codex-turn.txt containing the fixed token"
      ok "C2 model_served: $(sed -n 's/.*PASS  model_served — \(.*\)/\1/p' "$O" | head -1)"
    else
      no "C2 the real turn did not produce the artifact (rc=$rc)"; sed 's/^/        /' "$O" | head -20
    fi
  fi
fi

# ---------------------------------------------------------------------------------------------
say ""
say "D. CF_RUN_ID admission and turn-home containment (CF-277)"
# ---------------------------------------------------------------------------------------------
# A run id is refused at admission or not at all, and the only directory a turn removes is the
# fresh mktemp one it made. Two sentinels stand in for the victim: one where the brief names it
# ($SB/victim), and one at the path a `../../victim` id would actually resolve to under a turn
# home ($RUNID_HOME/victim) — so a traversal shows up as a missing file, not as a passing grep.
RUNID_HOME="$SB/home-runid"
mkdir -p "$RUNID_HOME/work" "$RUNID_HOME/keys" "$RUNID_HOME/victim" "$SB/victim"
git -C "$RUNID_HOME/work" init -q >/dev/null 2>&1
git -C "$RUNID_HOME/work" -c user.email=cf277@local -c user.name=cf277 commit -q --allow-empty -m init >/dev/null 2>&1
printf '%s\n' "$SYNTH_KEY" >"$RUNID_HOME/keys/provider.key"; chmod 600 "$RUNID_HOME/keys/provider.key"
printf 'sentinel\n' >"$SB/victim/keep.txt"
printf 'sentinel\n' >"$RUNID_HOME/victim/keep.txt"

# Everything a --turn needs except the run id itself: so the only thing standing between the
# value and the delete is the admission check.
D1_SET=(--model gpt-5.6-luna --provider openai-codex --namespace code-factory --lane cf-qa
        --workdir "$RUNID_HOME/work" --api-key-file "$RUNID_HOME/keys/provider.key")

# D1a — a traversal id is refused by --check, and nothing outside the cache root is removed.
O="$SB/d1a.out"
rc=$(run_home "$RUNID_HOME" "$O" "$INSTALLER" --check "${D1_SET[@]}" --run-id '../../victim')
expect_refused "D1a --check refuses CF_RUN_ID='../../victim'" "$O" "$rc" "run_id"
grep -qF -- "got '../../victim'" "$O" && ok "D1a the refusal quotes the value it refused" \
  || no "D1a the refusal does not quote the refused value"
if [ -d "$SB/victim" ] && [ -f "$SB/victim/keep.txt" ]; then
  ok "D1a \$SB/victim and its file survive the refusal"
else
  no "D1a \$SB/victim or its file was removed by a refused run"
fi
if [ -d "$RUNID_HOME/victim" ] && [ -f "$RUNID_HOME/victim/keep.txt" ]; then
  ok "D1a the traversal target under \$HOME also survives the refusal"
else
  no "D1a a refusal still removed \$HOME/victim"
fi

# D1b — the same value is refused in --turn, the mode that would have reached the delete.
O="$SB/d1b.out"
rc=$(run_home "$RUNID_HOME" "$O" "$INSTALLER" --turn "${D1_SET[@]}" --run-id '../../victim')
expect_refused "D1b --turn refuses the same id (the mode that reaches the delete)" "$O" "$rc" "run_id"
if [ -f "$SB/victim/keep.txt" ] && [ -f "$RUNID_HOME/victim/keep.txt" ]; then
  ok "D1b neither sentinel was removed in --turn"
else
  no "D1b a refused --turn removed a sentinel"
fi
[ -e "$RUNID_HOME/.cache/cf-codex" ] && no "D1b a refused run created the turn cache root anyway" \
  || ok "D1b a refused run created nothing under \$HOME/.cache"

# D1c — every shape the contract forbids is refused by name: separators, dot-dot, a leading dot,
# whitespace, a shell metacharacter, and an over-long id.
for bad in '../victim' '.hidden' 'a/b' 'a;b' 'a b' '$x' "$(printf 'a%.0s' $(seq 1 129))"; do
  O="$SB/d1c.out"
  rc=$(run_home "$RUNID_HOME" "$O" "$INSTALLER" --check "${D1_SET[@]}" --run-id "$bad")
  if [ "$rc" = "2" ] && grep -q 'CODEX: REFUSED' "$O" && grep -q 'run_id' "$O"; then
    ok "D1c refused run_id=$(printf '%.16s' "$bad") (${#bad} chars)"
  else
    no "D1c run_id='$(printf '%.16s' "$bad")' (${#bad} chars) was not refused by name (rc=$rc)"
  fi
done

# D2 — the id the suite already uses is not refused for that reason. A refusal for a different,
# named reason would be acceptable; the pass row names whichever verdict the run produced.
O="$SB/d2.out"
rc=$(run_home "$FAKEHOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir "$FAKEHOME/work")
if grep -q 'run_id' "$O"; then
  no "D2 --run-id r-lane must not be refused for the run id (rc=$rc)"; sed 's/^/        /' "$O"
else
  D2_VERDICT="$(grep -m1 -E '^CODEX: ' "$O" || echo 'CODEX: no-verdict')"
  ok "D2 --run-id r-lane is admitted (rc=$rc; verdict: $D2_VERDICT)"
fi
grep -qF -- 'contract:CF_RUN_ID = r-lane' "$O" \
  && ok "D2 the CF_RUN_ID contract record line is still emitted" \
  || no "D2 the CF_RUN_ID contract record line is missing from the report"

# D3 — the delete is confined, measured behaviourally: a stub codex that fails every invocation
# lets the turn home exist and the EXIT trap run, so the removal path is really exercised.
TURN_HOME_BASE="$SB/home-turn"
mkdir -p "$TURN_HOME_BASE/work" "$TURN_HOME_BASE/keys" "$TURN_HOME_BASE/.cache/cf-codex" "$SB/stub-turn"
git -C "$TURN_HOME_BASE/work" init -q >/dev/null 2>&1
git -C "$TURN_HOME_BASE/work" -c user.email=cf277@local -c user.name=cf277 commit -q --allow-empty -m init >/dev/null 2>&1
printf '%s\n' "$SYNTH_KEY" >"$TURN_HOME_BASE/keys/provider.key"; chmod 600 "$TURN_HOME_BASE/keys/provider.key"
printf 'sentinel\n' >"$TURN_HOME_BASE/.cache/cf-codex/sentinel.keep"
cat >"$SB/stub-turn/codex" <<'STUBEOF'
#!/usr/bin/env bash
# CF-277 D3: fails every invocation immediately — the turn runs, the trap fires, nothing is served.
printf 'stub codex: fails on purpose\n' >&2
exit 1
STUBEOF
chmod +x "$SB/stub-turn/codex"

O="$SB/d3.out"
rc=$(clean_env -u XDG_CACHE_HOME HOME="$TURN_HOME_BASE" PATH="$SB/stub-turn:/usr/local/bin:/usr/bin:/bin" \
     "$INSTALLER" --turn --model gpt-5.6-luna --provider openai-codex --namespace code-factory \
     --run-id r-lane --lane cf-qa --workdir "$TURN_HOME_BASE/work" \
     --api-key-file "$TURN_HOME_BASE/keys/provider.key" >"$O" 2>&1; echo $?)
grep -q 'FAIL  turn_exit' "$O" \
  && ok "D3 the stub codex was really invoked (FAIL turn_exit row present)" \
  || { no "D3 the turn never reached the stub, so the trap was not exercised (rc=$rc)"; sed 's/^/        /' "$O"; }
turn_dir=$(sed -n 's/^  PASS  turn_home — \([^ ]*\) (isolated.*/\1/p' "$O" | head -1)
case "$turn_dir" in
  "$TURN_HOME_BASE/.cache/cf-codex/run."*)
    ok "D3a the reported turn_home is a mktemp directory under the cache root: $turn_dir" ;;
  *) no "D3a the turn_home row names no mktemp directory under \$HOME/.cache/cf-codex (got '${turn_dir:-none}')" ;;
esac
case "$turn_dir" in
  *r-lane*) no "D3a the turn home is still derived from CF_RUN_ID: $turn_dir" ;;
  *) ok "D3a the turn home carries no part of the run id" ;;
esac
if [ -n "$turn_dir" ] && [ ! -e "$turn_dir" ]; then
  ok "D3b that exact directory is gone after the run"
elif [ -n "$turn_dir" ]; then
  no "D3b the turn home survived the EXIT trap: $turn_dir"
else
  no "D3b no turn home was reported, so the removal could not be measured"
fi
[ -f "$TURN_HOME_BASE/.cache/cf-codex/sentinel.keep" ] \
  && ok "D3c the sentinel beside the turn home still exists (the trap removed only its own leaf)" \
  || no "D3c the trap removed a file it did not create"

# ---------------------------------------------------------------------------------------------
say ""
say "E. CF-278 — the isolated CF_API_KEY_FILE branch runs, and its temporary auth.json exists for the turn only"
# ---------------------------------------------------------------------------------------------
# ch:trace row=CF-278 spec=docs/handbook/OUTLINE.md#M5-HARNESS wave=none:serial-worker test=tests/harness/codex-install-test.sh::E1-isolated-credential-branch doc=specs/HARNESS.md evidence=none:worker-test-output witness=none:worker-local verdict=none:open-finding commit=none:open memory=none:pending-closeout
# E1 is not a --check arm and not a grep: the stub codex records CODEX_HOME and the auth.json it
# is actually handed DURING the turn (mode + bytes, copied out to a capture dir), and writes the
# token artifact, so the same arm proves both halves — the file exists for the turn and is gone
# after it. E2 is the red control: the pre-fix revision (45bd4bd, whose turn branch interpolates a
# bare $VAR[CF_RUN_ID]) runs against the same fixture and must die with `unbound variable` before
# the stub is ever reached, so this arm goes red if that branch is unreachable again. E3 proves the
# single-line key admission is live rather than decorative.
ISO_HOME="$SB/home-isolated"
ISO_CAP="$SB/iso-capture"
ISO_STUB="$SB/stub-iso"
ISO_FILE="cf278-turn.txt"
ISO_TOKEN="CF-278-TOKEN-5c1e"
# The one-line JSON the turn must be handed — built from the key file's VALUE, never printed.
printf '{"OPENAI_API_KEY":"%s"}\n' "$SYNTH_KEY" >"$SB/iso-expected-auth.json"
mkdir -p "$ISO_HOME/work" "$ISO_HOME/keys" "$ISO_CAP" "$ISO_STUB"
git -C "$ISO_HOME/work" init -q >/dev/null 2>&1
git -C "$ISO_HOME/work" -c user.email=cf278@local -c user.name=cf278 commit -q --allow-empty -m init >/dev/null 2>&1
# A key file written the ordinary way: one token, one trailing newline. That newline is the
# difference between a readable auth.json and a JSON string broken across two lines.
printf '%s\n' "$SYNTH_KEY" >"$ISO_HOME/keys/provider.key"; chmod 600 "$ISO_HOME/keys/provider.key"

cat >"$ISO_STUB/codex" <<'STUBEOF'
#!/usr/bin/env bash
# CF-278 E1: a codex that measures the credential the installer handed it for THIS turn.
case "${1:-}" in
  --version) echo "codex-cli 0.166.0"; exit 0 ;;
  exec)
    cap="${CAPTURE_DIR:?}"; ch="${CODEX_HOME:-}"
    printf '%s\n' "$ch" >"$cap/codex_home"
    printf '%s\n' "$PWD" >"$cap/pwd"
    if [ -f "$ch/auth.json" ]; then
      printf '%s\n' "$(stat -c '%a' "$ch/auth.json")" >"$cap/auth.mode"
      cp "$ch/auth.json" "$cap/auth.during.json"
    fi
    if [ -f "$ch/config.toml" ]; then
      printf '%s\n' "$(stat -c '%a' "$ch/config.toml")" >"$cap/config.mode"
      cp "$ch/config.toml" "$cap/config.during.toml"
    fi
    printf '%s\n' "${CF_TURN_TOKEN:-}" >"${CF_TURN_FILE:-codex-turn.txt}"
    echo '{"type":"thread.started","thread_id":"cf278-iso"}'
    exit 0 ;;
esac
echo "cf278 stub codex: unsupported $*" >&2; exit 64
STUBEOF
chmod +x "$ISO_STUB/codex"

O="$SB/e1.out"
rc=$(clean_env -u XDG_CACHE_HOME HOME="$ISO_HOME" PATH="$ISO_STUB:/usr/local/bin:/usr/bin:/bin" \
     CAPTURE_DIR="$ISO_CAP" CF_TURN_FILE="$ISO_FILE" CF_TURN_TOKEN="$ISO_TOKEN" \
     "$INSTALLER" --turn --model gpt-5.6-luna --provider openai-codex --namespace code-factory \
     --run-id cf278-iso --lane cf-qa --workdir "$ISO_HOME/work" \
     --api-key-file "$ISO_HOME/keys/provider.key" >"$O" 2>&1; echo $?)
iso_dir=$(sed -n 's/^  PASS  turn_home — \([^ ]*\) (isolated.*/\1/p' "$O" | head -1)
case "$iso_dir" in
  "$ISO_HOME/.cache/cf-codex/run."*)
    ok "E1 the isolated-credential branch runs end to end (rc=$rc): turn_home is a mktemp leaf $iso_dir" ;;
  *)
    no "E1 the isolated-credential branch did not run (rc=$rc, turn_home='${iso_dir:-none}')"; sed 's/^/        /' "$O" | tail -15 ;;
esac
cap_home="$(head -1 "$ISO_CAP/codex_home" 2>/dev/null || true)"
if [ -n "$cap_home" ] && [ "$cap_home" = "$iso_dir" ]; then
  ok "E1 the turn was really executed with CODEX_HOME=$cap_home (the stub recorded it)"
else
  no "E1 the stub codex was not reached with the reported turn home (recorded '${cap_home:-none}', reported '${iso_dir:-none}')"
fi
[ "$cap_home" = "$ISO_HOME/.codex" ] \
  && no "E1 the isolated branch fell back to the host login directory \$HOME/.codex" \
  || ok "E1 CODEX_HOME was an isolated home, not \$HOME/.codex"
if [ -f "$ISO_CAP/auth.during.json" ]; then
  printf '{"OPENAI_API_KEY":"%s"}\n' "$SYNTH_KEY" >"$SB/iso-expected-auth.json"
  cmp -s "$ISO_CAP/auth.during.json" "$SB/iso-expected-auth.json" \
    && ok "E1 during the turn \$CODEX_HOME/auth.json held exactly one line of JSON: {\"OPENAI_API_KEY\":\"<the key>\"}" \
    || no "E1 the auth.json handed to the turn is not the expected one-line JSON (a key file's trailing newline must not be embedded in the string)"
  [ "$(cat "$ISO_CAP/auth.mode" 2>/dev/null)" = "600" ] \
    && ok "E1 the temporary auth.json was mode 600 while the turn ran" \
    || no "E1 the temporary auth.json mode was '$(cat "$ISO_CAP/auth.mode" 2>/dev/null)' — expected 600"
else
  no "E1 no auth.json existed under CODEX_HOME while the turn ran — the branch never handed the key to the turn"
fi
if [ -f "$ISO_CAP/config.during.toml" ] && [ "$(cat "$ISO_CAP/config.mode" 2>/dev/null)" = "600" ] \
   && grep -qx 'model = "gpt-5.6-luna"' "$ISO_CAP/config.during.toml" \
   && grep -qx 'model_provider = "openai"' "$ISO_CAP/config.during.toml"; then
  ok "E1 the isolated config.toml pinned model + provider on disk (mode 600), so neither is inherited from ~/.codex"
else
  no "E1 the isolated config.toml was missing, world-readable, or did not pin model/provider"
fi
if [ -n "$iso_dir" ] && [ ! -e "$iso_dir" ]; then
  ok "E1 the isolated home is gone after the turn — the temporary auth.json was removed with it"
elif [ -n "$iso_dir" ]; then
  no "E1 the isolated home survived the turn: $iso_dir"
else
  no "E1 no isolated home was reported, so its removal could not be measured"
fi
iso_left=$(find "$ISO_HOME" -name auth.json -print 2>/dev/null | wc -l)
[ "$iso_left" = "0" ] && ok "E1 no auth.json survives anywhere under the fake \$HOME" \
  || no "E1 $iso_left auth.json file(s) survived under the fake \$HOME"
[ -e "$ISO_HOME/.codex" ] && no "E1 the adapter created the host login directory \$HOME/.codex" \
  || ok "E1 \$HOME/.codex was never created"
grep -qF -- "$SYNTH_KEY" "$O" && no "E1 the key value was printed into the installer output" \
  || ok "E1 the key value never appears in the installer output"

# E2 — the red control. The same fixture against the pre-fix tree: the branch must die on the
# expansion, before any credential file is written and before the stub is reached.
PREFIX278_REV="${CF278_PREFIX_REV:-45bd4bd}"
P278="$SB/prefix-cf278"
RED_HOME="$SB/home-isolated-prefix"
RED_CAP="$SB/iso-capture-prefix"
mkdir -p "$P278/scripts/harness" "$RED_HOME/work" "$RED_HOME/keys" "$RED_CAP"
git -C "$RED_HOME/work" init -q >/dev/null 2>&1
git -C "$RED_HOME/work" -c user.email=cf278@local -c user.name=cf278 commit -q --allow-empty -m init >/dev/null 2>&1
printf '%s\n' "$SYNTH_KEY" >"$RED_HOME/keys/provider.key"; chmod 600 "$RED_HOME/keys/provider.key"
cp "$HERE_REPO/scripts/lib.sh" "$P278/scripts/lib.sh"
if git -C "$HERE_REPO" show "$PREFIX278_REV:scripts/harness/install-codex.sh" >"$P278/scripts/harness/install-codex.sh" 2>/dev/null; then
  chmod +x "$P278/scripts/harness/install-codex.sh"
  O="$SB/e2.out"
  rc=$(clean_env -u XDG_CACHE_HOME HOME="$RED_HOME" PATH="$ISO_STUB:/usr/local/bin:/usr/bin:/bin" \
       CAPTURE_DIR="$RED_CAP" CF_TURN_FILE="$ISO_FILE" CF_TURN_TOKEN="$ISO_TOKEN" \
       "$P278/scripts/harness/install-codex.sh" --turn --model gpt-5.6-luna --provider openai-codex \
       --namespace code-factory --run-id cf278-iso --lane cf-qa --workdir "$RED_HOME/work" \
       --api-key-file "$RED_HOME/keys/provider.key" >"$O" 2>&1; echo $?)
  red_left=$(find "$RED_HOME" -name auth.json -print 2>/dev/null | wc -l)
  if [ "$rc" != "0" ] && grep -q 'unbound variable' "$O" \
     && [ ! -f "$RED_CAP/codex_home" ] && [ "$red_left" = "0" ]; then
    ok "E2 the pre-fix adapter ($PREFIX278_REV) dies with 'unbound variable' before the stub is reached and writes no auth.json — E1 is falsifiable"
  else
    no "E2 the pre-fix control did not fail on the expansion (rc=$rc, stub reached=$([ -f "$RED_CAP/codex_home" ] && echo yes || echo no), auth.json left=$red_left)"
    sed 's/^/        /' "$O" | tail -6
  fi
else
  skip "E2 the pre-fix revision $PREFIX278_REV is unavailable here (git show $PREFIX278_REV:scripts/harness/install-codex.sh)"
fi

# E2b — the SECOND half of that branch has its own control. The tree this change was made on
# (7cedd1f) still copies the key file's trailing newline INTO the JSON string, so the auth.json it
# hands the turn is not parseable at all. Against that tree the E1 byte assertion fails, which is
# what makes it a measurement rather than a restatement of the current code.
PREPATCH278_REV="${CF278_PREPATCH_REV:-7cedd1f}"
P278B="$SB/prepatch-cf278"
PB_HOME="$SB/home-isolated-prepatch"
PB_CAP="$SB/iso-capture-prepatch"
mkdir -p "$P278B/scripts/harness" "$PB_HOME/work" "$PB_HOME/keys" "$PB_CAP"
git -C "$PB_HOME/work" init -q >/dev/null 2>&1
git -C "$PB_HOME/work" -c user.email=cf278@local -c user.name=cf278 commit -q --allow-empty -m init >/dev/null 2>&1
printf '%s\n' "$SYNTH_KEY" >"$PB_HOME/keys/provider.key"; chmod 600 "$PB_HOME/keys/provider.key"
cp "$HERE_REPO/scripts/lib.sh" "$P278B/scripts/lib.sh"
if git -C "$HERE_REPO" show "$PREPATCH278_REV:scripts/harness/install-codex.sh" >"$P278B/scripts/harness/install-codex.sh" 2>/dev/null; then
  chmod +x "$P278B/scripts/harness/install-codex.sh"
  O="$SB/e2b.out"
  rc=$(clean_env -u XDG_CACHE_HOME HOME="$PB_HOME" PATH="$ISO_STUB:/usr/local/bin:/usr/bin:/bin" \
       CAPTURE_DIR="$PB_CAP" CF_TURN_FILE="$ISO_FILE" CF_TURN_TOKEN="$ISO_TOKEN" \
       "$P278B/scripts/harness/install-codex.sh" --turn --model gpt-5.6-luna --provider openai-codex \
       --namespace code-factory --run-id cf278-iso --lane cf-qa --workdir "$PB_HOME/work" \
       --api-key-file "$PB_HOME/keys/provider.key" >"$O" 2>&1; echo $?)
  if [ "$rc" = "0" ] && [ -f "$PB_CAP/auth.during.json" ] \
     && ! cmp -s "$PB_CAP/auth.during.json" "$SB/iso-expected-auth.json" \
     && [ "$(wc -l <"$PB_CAP/auth.during.json")" -gt 1 ]; then
    ok "E2b the pre-patch adapter ($PREPATCH278_REV) embeds the key file's newline in auth.json (two lines, not the expected one) — the E1 byte assertion is falsifiable"
  else
    no "E2b the pre-patch control did not reproduce the embedded newline (rc=$rc, auth.json captured=$([ -f "$PB_CAP/auth.during.json" ] && echo yes || echo no))"
  fi
else
  skip "E2b the pre-patch revision $PREPATCH278_REV is unavailable here (git show $PREPATCH278_REV:scripts/harness/install-codex.sh)"
fi

# E3 — a two-line key file is refused by name. The per-line token grep alone accepted it and the
# auth.json would then carry a key no provider ever issued; admission is where that fails closed.
printf '%s\n%s\n' "$SYNTH_KEY" 'second-line' >"$ISO_HOME/keys/two-line.key"
chmod 600 "$ISO_HOME/keys/two-line.key"
O="$SB/e3.out"
rc=$(run_home "$ISO_HOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir "$ISO_HOME/work" \
      --api-key-file "$ISO_HOME/keys/two-line.key")
expect_refused "E3 a CF_API_KEY_FILE holding two lines is refused by name" "$O" "$rc" "more than one line"

# T-A (CF-278 HIGH) — `wc -l` counts NEWLINE bytes, not lines. A key file whose bytes are two tokens
# separated by ONE newline with NO trailing newline measured 1 under the old guard, passed it, and
# was then embedded whole by key_token="$(cat …)" — a raw newline inside a JSON string, which is the
# parse error the guard claims to prevent. The fixture measures its own shape first, so the arm can
# only go green against the byte layout `wc -l` miscounts.
TA_KEY="$ISO_HOME/keys/no-trailing-nl.key"
printf '%s\n%s' "$SYNTH_KEY" 'second-token-no-trailing-newline' >"$TA_KEY"
chmod 600 "$TA_KEY"
ta_wcl=$(wc -l <"$TA_KEY")
ta_nl=$(tr -dc '\n' <"$TA_KEY" | wc -c)
ta_last=$(tail -c 1 "$TA_KEY" | tr -d '\n' | wc -c)
if [ "$ta_nl" = "1" ] && [ "$ta_last" = "1" ]; then
  ok "T-A fixture is the shape the old guard miscounted: $ta_wcl newline (wc -l reports 1), 2 tokens, no trailing newline"
else
  no "T-A fixture is not the intended shape (newlines=$ta_nl, last byte non-newline=$ta_last) — the arm would prove nothing"
fi
O="$SB/ta.out"
rc=$(run_home "$ISO_HOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir "$ISO_HOME/work" \
      --api-key-file "$TA_KEY")
expect_refused "T-A a two-token key file with no trailing newline is refused as multi-line" "$O" "$rc" "more than one line"
grep -qF -- 'second-token-no-trailing-newline' "$O" \
  && no "T-A the refusal printed the key file's content" \
  || ok "T-A the refusal printed no part of the key file"

# T-B (CF-278 MEDIUM) — a key file whose only byte is a newline. The command substitution turns it
# into an EMPTY token, which the write path serialised as {"OPENAI_API_KEY":""} into the isolated
# auth.json: a credential file that authenticates as nothing. It must be refused by name, in --check
# AND in --turn (the mode that writes auth.json), and no isolated auth.json may exist afterwards.
TB_HOME="$SB/home-blank-key"
mkdir -p "$TB_HOME/work" "$TB_HOME/keys"
git -C "$TB_HOME/work" init -q >/dev/null 2>&1
git -C "$TB_HOME/work" -c user.email=cf278@local -c user.name=cf278 commit -q --allow-empty -m init >/dev/null 2>&1
TB_KEY="$TB_HOME/keys/blank.key"
printf '\n' >"$TB_KEY"; chmod 600 "$TB_KEY"
tb_bytes=$(wc -c <"$TB_KEY"); tb_tokens=$(tr -d '\n' <"$TB_KEY" | wc -c)
if [ "$tb_bytes" = "1" ] && [ "$tb_tokens" = "0" ]; then
  ok "T-B fixture is a one-byte file whose only byte is a newline — one empty awk record, zero-length token"
else
  no "T-B fixture is not a lone newline ($tb_bytes bytes, $tb_tokens non-newline bytes)"
fi
O="$SB/tb1.out"
rc=$(run_home "$TB_HOME" "$O" "$INSTALLER" --check "${FULL_SET[@]}" --workdir "$TB_HOME/work" \
      --api-key-file "$TB_KEY")
expect_refused "T-B a CF_API_KEY_FILE whose only byte is a newline is refused as a blank token" "$O" "$rc" "no key token"
O="$SB/tb2.out"
rc=$(run_home "$TB_HOME" "$O" "$INSTALLER" --turn "${FULL_SET[@]}" --workdir "$TB_HOME/work" \
      --api-key-file "$TB_KEY")
expect_refused "T-B --turn refuses the same blank key (the mode that writes auth.json)" "$O" "$rc" "no key token"
tb_auth=$(find "$TB_HOME" -name auth.json -print 2>/dev/null | wc -l)
[ "$tb_auth" = "0" ] && ok "T-B no isolated auth.json was produced under the fake \$HOME" \
  || no "T-B $tb_auth auth.json file(s) were produced for a blank key"
[ -e "$TB_HOME/.cache/cf-codex" ] \
  && no "T-B the blank-key refusal still created the turn cache root" \
  || ok "T-B the blank-key refusal created nothing under \$HOME/.cache"

# ---------------------------------------------------------------------------------------------
say ""
say "codex installer test: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] && { say "RESULT: PASS"; exit 0; } || { say "RESULT: FAIL"; exit 1; }

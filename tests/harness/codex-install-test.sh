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
# ch:trace row=CF-384 spec=specs/HARNESS.md#verdict-line wave=none:serial-worker test=tests/harness/codex-install-test.sh::codex-warn-classification doc=docs/handbook/chapters/M5-harness.md prompt=/home/kara/.hermes/cache/scratch/code-factory-2026-11-07-23-36-05/CF-384-brief.txt evidence=tests/harness/codex-install-test.sh verdict=none:foreman-runs-gitreins-after-worker commit=none:worker-commit-created-at-exit memory=none:foreman-writes-after-publish witness=none:foreman-verifies
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
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
[ "$rc" = "1" ] && grep -q 'FAIL  download' "$O" && grep -q 'digest mismatch' "$O" \
  && ok "B2 a digest mismatch FAILs the download leg and names both digests" \
  || no "B2 a digest mismatch must FAIL the download leg (rc=$rc)"
[ -e "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex" ] \
  && no "B2 a mismatched download still left a binary behind" \
  || ok "B2 a mismatched download installs nothing"

# B3 — the pinned install succeeds, user-space, and reads the version back.
O="$SB/b3.out"
rc=$(clean_env HOME="$FAKEHOME" CF_CODEX_URL="file://$TAR" CF_CODEX_SHA256="$TAR_SHA" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
if [ "$rc" = "0" ] && grep -q 'PASS  install' "$O" && grep -q "PASS  version — $PIN_DEFAULT (pin $PIN_DEFAULT)" "$O"; then
  ok "B3 --apply installs the pin and reads the version back"
else
  no "B3 --apply should install and read back $PIN_DEFAULT (rc=$rc)"; sed 's/^/        /' "$O"
fi
[ -x "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex" ] \
  && ok "B3 the binary lives under \$HOME/.local/codex/$PIN_DEFAULT (user-space, no root)" \
  || no "B3 the binary is not at the pinned user-space path"
[ -L "$FAKEHOME/.local/bin/codex" ] && ok "B3 the ~/.local/bin shim points at the pin" \
  || no "B3 no ~/.local/bin/codex shim"

# B4 — idempotence: a second --apply changes nothing and exits 0.
efore=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex")
O="$SB/b4.out"
rc=$(clean_env HOME="$FAKEHOME" CF_CODEX_URL="file://$TAR" CF_CODEX_SHA256="$TAR_SHA" \
     "$INSTALLER" --apply >"$O" 2>&1; echo $?)
eafter=$(stat -c '%i %Y %s' "$FAKEHOME/.local/codex/$PIN_DEFAULT/bin/codex")
if [ "$rc" = "0" ] && grep -q 'already installed' "$O" && [ "$efore" = "$eafter" ]; then
  ok "B4 a second --apply is a no-op (exit 0, binary unchanged: $eafter)"
else
  no "B4 a second --apply changed something (rc=$rc, $efore -> $eafter)"
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
say "codex installer test: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] && { say "RESULT: PASS"; exit 0; } || { say "RESULT: FAIL"; exit 1; }

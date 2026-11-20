#!/usr/bin/env bash
# CF-395 — one indentation rule, three readers: prove they agree on one fixture set.
#
# The reader that authorises a public bind is `check_public_bind_auth` in
# scripts/harness/install-hermes.sh. TWO other parties answer the same question about the same
# file — the producer scripts/node_gateway_auth.py (and its read-only `--check` mode) and the
# standalone preflight scripts/project-node.sh --check — and they used to answer it differently:
# the preflight matched `basic_auth:` at ANY indent inside the `dashboard:` block, the producer
# never looked at the two child values, and neither noticed a block whose children disagree on
# indentation. This harness makes that disagreement impossible to reintroduce quietly.
#
# It COMPARES, it does not assert. Every party's verdict is normalised to a class
# (present / absent / invalid-yaml / empty-value / unreadable) and the classes are diffed per
# fixture: one line per fixture per party, `shape party verdict`, and exit 1 at the first shape
# where two parties disagree (a NOTE on stderr names all four verdicts). Nothing is hard-coded, so
# a shape added below is graded by the same comparison — a party that starts answering differently
# turns this red without anyone editing the harness.
#
# The parties:
#   producer   python3 scripts/node_gateway_auth.py --check <config>  (the verdict --apply acts on)
#   gate       check_public_bind_auth, extracted from install-hermes.sh (the bind authority)
#   preflight  scripts/project-node.sh --check's `gateway_auth` ROW (the standalone certificate)
#   fallback   project-node.sh's shell fallback (the no-python3 path in the same row)
#   wired      the same ROW with no producer beside the script — the fallback as the row reaches it
#
# Hermetic: every party runs against a tempfile HOME — no network, no real ~/.hermes, nothing
# written outside this scratch tree (removed on exit). The preflight party runs the REAL
# scripts/project-node.sh from a scratch copy of scripts/ with a stub harness adapter, so the row
# logic under test is the shipped one while the adapter cannot touch the host.
#
# Usage: bash tests/gateway_auth_parity.sh
#   CF395_PREFLIGHT_SRC=<file>   grade a different project-node.sh (red-proof control)
#   CF395_GATE_SRC=<file>        grade a different install-hermes.sh
#   CF395_MODULE_SRC=<file>      grade a different node_gateway_auth.py
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PYTHON="${CF395_PYTHON:-$(command -v python3 || true)}"
GATE_SRC="${CF395_GATE_SRC:-$ROOT/scripts/harness/install-hermes.sh}"
PREFLIGHT_SRC="${CF395_PREFLIGHT_SRC:-$ROOT/scripts/project-node.sh}"
MODULE_SRC="${CF395_MODULE_SRC:-$ROOT/scripts/node_gateway_auth.py}"
PORT="${CF395_PORT:-59417}"

# The six shapes the row names, plus three controls: a positive control (a well-formed direct-child
# block must read `present` everywhere — without it the harness never proves the pass path), a
# quoted-empty variant of the empty-value shape, and the mixed-indent shape that specifically used
# to certify (a `basic_auth:` at the block's MINIMUM indent while the gate refuses the file).
SHAPES="direct-child sibling-key child-key column-0 after-block empty-value empty-strings mixed-indent mixed-false-pass"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cf395-parity.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
fails=0

die() {
  printf 'FAIL  gateway_auth_parity — %s\n' "$1" >&2
  exit 2
}

[ -n "$PYTHON" ] || die "no python3 on PATH (the producer party needs it)"
[ -r "$MODULE_SRC" ] || die "module not found: $MODULE_SRC"
[ -r "$GATE_SRC" ] || die "consumer gate not found: $GATE_SRC"
[ -r "$PREFLIGHT_SRC" ] || die "preflight not found: $PREFLIGHT_SRC"

# ---------------------------------------------------------------- party 2: the consumer gate
# Extracted from the shipped adapter, never re-written here: the authority the other two parties
# are graded against must be the code that authorises the bind. `check_public_bind_auth` is the
# last function before the adapter's first top-level `say "harness:` line, so that line is its end.
gate_start="$(grep -n '^check_public_bind_auth() {' "$GATE_SRC" | head -1 | cut -d: -f1)"
[ -n "$gate_start" ] || die "check_public_bind_auth() { not found in $GATE_SRC"
gate_end="$(awk -v s="$gate_start" 'NR > s && /^say "harness:/ { print NR; exit }' "$GATE_SRC")"
[ -n "$gate_end" ] || die "no top-level say \"harness: line after check_public_bind_auth in $GATE_SRC"
{
  printf 'set +e\n'
  sed -n "${gate_start},$((gate_end - 1))p" "$GATE_SRC"
  printf 'check_public_bind_auth\n'
} >"$WORK/gate.sh"

# ---------------------------------------------------------------- party 4: the shell fallback
# Same extraction rule for the fallback: the two helpers project-node.sh ships for the no-python3
# case, so the party under test is the shipped fallback rather than a copy of it. A project-node.sh
# that has no fallback (the pre-fix control) simply does not field this party.
fallback_start="$(grep -n '^gw_scalar() {' "$PREFLIGHT_SRC" | head -1 | cut -d: -f1)"
fallback_end=""
have_fallback=0
if [ -n "$fallback_start" ]; then
  fallback_end="$(awk -v s="$fallback_start" \
    '/^# -+ 20 harness$/ { if (NR > s) { print NR; exit } }' "$PREFLIGHT_SRC")"
  if [ -n "$fallback_end" ]; then
    {
      printf 'set +e\n'
      sed -n "${fallback_start},$((fallback_end - 1))p" "$PREFLIGHT_SRC"
      printf 'gateway_auth_shell_verdict "$1"\n'
      printf 'printf "%%s %%s\\n" "$gw_present" "$gw_reason"\n'
    } >"$WORK/fallback.sh"
    have_fallback=1
  fi
fi
if [ "$have_fallback" = 0 ]; then
  printf 'NOTE  gateway_auth_parity — no shell fallback in %s: the fallback party is skipped\n' \
    "$PREFLIGHT_SRC" >&2
fi

# ---------------------------------------------------------------- the preflight party's tree
# scripts/project-node.sh resolves its siblings through $HERE, so a scratch copy of scripts/ is what
# lets the REAL row logic run with a stub adapter: the adapter is a stub (it must not touch the
# host), the gateway_auth row is not.
mkdir -p "$WORK/scripts/harness" || die "cannot create the preflight scratch tree"
for f in project-node.sh lib.sh disk_floor.py node_gateway_auth.py; do
  [ -r "$ROOT/scripts/$f" ] || die "scripts/$f missing from the repo"
  cp "$ROOT/scripts/$f" "$WORK/scripts/" || die "cannot stage scripts/$f"
done
cp "$PREFLIGHT_SRC" "$WORK/scripts/project-node.sh" || die "cannot stage $PREFLIGHT_SRC"
# The module under test travels into the scratch tree too, so the preflight row delegates to the
# same producer the other parties grade (CF395_MODULE_SRC can point both at another revision).
cp "$MODULE_SRC" "$WORK/scripts/node_gateway_auth.py" || die "cannot stage $MODULE_SRC"
{
  printf '#!/usr/bin/env bash\n'
  printf 'HERE="$(cd "$(dirname "$0")" && pwd)"\n'
  printf '. "$HERE/../lib.sh"\n'
  printf 'say "harness: hermes (cf-395 parity stub)"\n'
  printf 'exit 0\n'
} >"$WORK/scripts/harness/install-hermes.sh"
chmod +x "$WORK/scripts/harness/install-hermes.sh"
# A second copy of the tree with the producer removed: the row must still answer through its shell
# fallback (the no-python3 branch), and with the same verdicts.
cp -r "$WORK/scripts" "$WORK/nomodule" || die "cannot duplicate the preflight scratch tree"
rm -f "$WORK/nomodule/node_gateway_auth.py" || die "cannot remove the producer from the copy"

# `ss` is stubbed so the adapter's listener branch cannot depend on what this host happens to run.
mkdir -p "$WORK/bin" || die "cannot create the stub bin dir"
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/bin/ss"
chmod +x "$WORK/bin/ss"

# ---------------------------------------------------------------- fixtures
write_shape() {  # $1 shape, $2 config path
  case "$1" in
    direct-child)
      cat >"$2" <<'YAML'
dashboard:
  basic_auth:
    username: node
    password: correct-horse-battery
YAML
      ;;
    sibling-key)
      cat >"$2" <<'YAML'
server:
  host: 0.0.0.0
dashboard:
  theme: dark
other:
  basic_auth:
    username: sibling
    password: not-this-path
YAML
      ;;
    child-key)
      cat >"$2" <<'YAML'
dashboard:
  theme: dark
  child:
    basic_auth:
      username: nested
      password: not-this-path
YAML
      ;;
    column-0)
      cat >"$2" <<'YAML'
dashboard:
  theme: dark
basic_auth:
  username: toplevel
  password: not-this-path
YAML
      ;;
    after-block)
      cat >"$2" <<'YAML'
dashboard:
  theme: dark
  lang: en

# credentials live in the next block
other:
  basic_auth:
    username: after
    password: not-this-path
YAML
      ;;
    empty-value)
      cat >"$2" <<'YAML'
dashboard:
  basic_auth:
YAML
      ;;
    empty-strings)
      cat >"$2" <<'YAML'
dashboard:
  basic_auth:
    username: ""
    password: ""
YAML
      ;;
    mixed-indent)
      cat >"$2" <<'YAML'
dashboard:
  theme: dark
    lang: en
YAML
      ;;
    mixed-false-pass)
      cat >"$2" <<'YAML'
dashboard:
    theme: dark
  basic_auth:
    username: mixed
    password: not-this-path
YAML
      ;;
    *)
      die "unknown shape $1 — every shape needs a fixture"
      ;;
  esac
}

classify() {  # $1 text, $2 rc -> one class; the vocabulary is shared, the prose is not
  case "$1" in
    *'invalid YAML'*) printf 'invalid-yaml' ;;
    *'empty value'*) printf 'empty-value' ;;
    *'config unreadable'*) printf 'unreadable' ;;
    *'commented'*) printf 'commented' ;;
    *) if [ "$2" -eq 0 ]; then printf 'present'; else printf 'absent'; fi ;;
  esac
}

# ---------------------------------------------------------------- the four parties
party_producer() {  # $1 home -> prints the class
  local out rc
  # Run from the scratch dir: a module without a `--check` mode reads `--check` as the CONFIG path
  # and materialises a file called `--check` in the CWD. That belongs in the scratch tree, not in
  # the tree under test.
  out="$(cd "$WORK" && "$PYTHON" "$WORK/scripts/node_gateway_auth.py" --check \
    "$1/.hermes/config.yaml" 2>&1)"
  rc=$?
  [ -n "$out" ] || { printf 'no-output'; return 0; }
  # The verdict has to be spoken in the shared vocabulary; anything else (an older module that
  # reads `--check` as a config path, a traceback) is not a verdict and must not be classified.
  case "$out" in
    'gateway_auth: '*) classify "${out#gateway_auth: }" "$rc" ;;
    *) printf 'no-verdict' ;;
  esac
}

party_gate() {  # $1 home -> prints the class
  local out rc
  out="$(HOME="$1" VENV="$WORK/no-venv" PYTHON_BIN="$PYTHON" bash "$WORK/gate.sh" 2>&1)"
  rc=$?
  case "$rc" in
    0) [ -z "$out" ] && printf 'present' || classify "$out" 0 ;;
    1) [ -n "$out" ] && classify "$out" 1 || printf 'no-output' ;;
    *) classify "$out" "$rc" ;;
  esac
}

party_preflight() {  # $1 home -> prints the class
  local out rc row
  out="$(HOME="$1" PATH="$WORK/bin:$PATH" NODE_PROJECT=parity NODE_HARNESS=hermes \
    CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
    bash "$WORK/scripts/project-node.sh" --check --layers 20 --port "$PORT" 2>&1)"
  rc=$?
  row="$(printf '%s\n' "$out" | grep -E '^  (PASS|FAIL)  gateway_auth — ' | head -1)"
  if [ -z "$row" ]; then
    printf 'no-row'
    return 0
  fi
  case "$row" in
    '  PASS  gateway_auth — '*) printf 'present' ;;
    *) classify "$row" 1 ;;
  esac
}

party_fallback() {  # $1 home -> prints the class
  local out
  [ "$have_fallback" = 1 ] || { printf 'skipped'; return 0; }
  out="$(bash "$WORK/fallback.sh" "$1/.hermes/config.yaml" 2>&1)"
  case "$out" in
    '1 '*) printf 'present' ;;
    '0 '*) printf '%s' "${out#0 }" | { read -r reason; classify "$reason" 1; } ;;
    *) printf 'no-output' ;;
  esac
}

party_preflight_nomodule() {  # $1 home -> the same row with no producer beside the script
  # The wiring, not just the helper: with the module absent the row must reach the shell fallback
  # and still answer, rather than going silent or falling back to a looser rule. This is the branch
  # a node without python3 takes (empty PATH), reached here without hiding python3 from the host.
  local out row
  out="$(HOME="$1" PATH="$WORK/bin:$PATH" NODE_PROJECT=parity NODE_HARNESS=hermes \
    CRIER_URL=http://fixture.invalid:8767 NODE_DISK_FLOOR=1 \
    bash "$WORK/nomodule/project-node.sh" --check --layers 20 --port "$PORT" 2>&1)"
  row="$(printf '%s\n' "$out" | grep -E '^  (PASS|FAIL)  gateway_auth — ' | head -1)"
  if [ -z "$row" ]; then
    printf 'no-row'
    return 0
  fi
  case "$row" in
    '  PASS  gateway_auth — '*) printf 'present' ;;
    *) classify "$row" 1 ;;
  esac
}

# ---------------------------------------------------------------- run
# Every party reads its OWN copy of the fixture (fresh_home). A party is graded on what it says
# about a config, and a producer that is not read-only — the pre-fix module has no `--check` mode,
# so `--check <config>` hands it `<config>` as the PASSWORD path — would otherwise rewrite the file
# its neighbours then measure, turning a verdict comparison into a race.
fresh_home() {  # $1 shape, $2 party -> prints a HOME holding an unmodified copy of the fixture
  local home="$WORK/run/$1/$2"
  mkdir -p "$home/.hermes" || die "cannot create $home/.hermes"
  cp "$WORK/templates/$1.yaml" "$home/.hermes/config.yaml" ||
    die "cannot stage the $1 fixture for $2"
  printf '%s' "$home"
}

printf 'CF-395 gateway-auth parity: producer / gate / preflight / fallback / wired\n'
for shape in $SHAPES; do
  mkdir -p "$WORK/templates" || die "cannot create the fixture dir"
  write_shape "$shape" "$WORK/templates/$shape.yaml"

  p_producer="$(party_producer "$(fresh_home "$shape" producer)")"
  p_gate="$(party_gate "$(fresh_home "$shape" gate)")"
  p_preflight="$(party_preflight "$(fresh_home "$shape" preflight)")"
  p_fallback="$(party_fallback "$(fresh_home "$shape" fallback)")"
  p_wired="$(party_preflight_nomodule "$(fresh_home "$shape" wired)")"

  printf '%-17s %-10s %s\n' "$shape" producer "$p_producer"
  printf '%-17s %-10s %s\n' "$shape" gate "$p_gate"
  printf '%-17s %-10s %s\n' "$shape" preflight "$p_preflight"
  printf '%-17s %-10s %s\n' "$shape" fallback "$p_fallback"
  printf '%-17s %-10s %s\n' "$shape" wired "$p_wired"

  if [ "$p_producer" != "$p_gate" ] || [ "$p_producer" != "$p_preflight" ] ||
    [ "$p_producer" != "$p_wired" ] ||
    { [ "$p_fallback" != skipped ] && [ "$p_producer" != "$p_fallback" ]; }; then
    printf 'NOTE  gateway_auth_parity — %s diverges: producer=%s gate=%s preflight=%s fallback=%s wired=%s\n' \
      "$shape" "$p_producer" "$p_gate" "$p_preflight" "$p_fallback" "$p_wired" >&2
    printf 'FAIL  gateway_auth_parity — the readers disagree on a shape the contract names\n' >&2
    exit 1
  fi
  case "$p_producer" in
    no-output | no-row) printf 'NOTE  gateway_auth_parity — %s produced no verdict\n' "$shape" >&2 ; fails=$((fails + 1)) ;;
  esac
done

if [ "$fails" -ne 0 ]; then
  printf 'FAIL  gateway_auth_parity — %d shape(s) produced no verdict\n' "$fails" >&2
  exit 1
fi
printf 'PASS  gateway_auth_parity — %d shapes, all five readers agree\n' \
  "$(printf '%s\n' $SHAPES | grep -c .)"
exit 0

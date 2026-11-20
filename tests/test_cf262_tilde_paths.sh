#!/usr/bin/env bash
# CF-262: every CLI path flag expands a leading ~/ before the value is used. The two that did not
# (--config, --node-env-file) handed the literal string "~/..." to load_config and to the inputs /
# env_profile rows, so a profile named with a tilde read as an unreadable file. The fixture drives
# the REAL script twice under a throwaway HOME (no network, no node, no credentials: both runs are
# the --check bad-config paths, which print rows and exit non-zero), then proves it can go red by
# running a COPY of the script with the expand_tilde calls removed.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT
mkdir -p "$tmpd/bin" "$tmpd/home" "$tmpd/red"

die() {  # $1 = which arm, $2 = why, $3 = captured output
  printf 'CF-262 FAIL: %s — %s\noutput follows\n%s\n' "$1" "$2" "$3"
  exit 1
}

# A stub on PATH: the env_profile row sits after the bunker client/server/agent checks, so the
# fixture supplies the smallest client that lets --check reach it. It answers the four subcommands
# the check issues and nothing else; no host is contacted.
cat > "$tmpd/bin/bunker" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list) printf 'NAME  STATUS\nstub-server  running\n' ;;
  info) printf 'agent stub-agent\n' ;;
  cp|exec) : ;;
esac
exit 0
STUB
chmod +x "$tmpd/bin/bunker"

run_real() {  # $1... = argv -> prints output, sets $rc
  out=$(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
    /bin/bash "$ROOT/scripts/bunker-provision.sh" --check "$@" 2>&1)
  rc=$?
  return 0
}

# --- arm A: --node-env-file ~/… is expanded ---------------------------------------------------
# The assertion is the emitted row, not a substring: the "~/" form can only satisfy
# "NODE_ENV_FILE<path>" when the path has already been rewritten to $HOME/….
run_real --project demo --server stub-server --agent stub-agent --node-env-file "~/absent-node.env"
want_inputs="  FAIL  inputs — not readable: NODE_ENV_FILE($tmpd/home/absent-node.env)"
want_profile="  FAIL  env_profile — NODE_ENV_FILE $tmpd/home/absent-node.env is unreadable"
[ "$rc" -eq 1 ] || die "A --node-env-file" "exit $rc, expected 1" "$out"
[ "$(printf '%s\n' "$out" | grep -Fxc -- "$want_inputs")" = 1 ] \
  || die "A --node-env-file" "inputs row absent or repeated: $want_inputs" "$out"
[ "$(printf '%s\n' "$out" | grep -Fxc -- "$want_profile")" = 1 ] \
  || die "A --node-env-file" "env_profile row absent or repeated: $want_profile" "$out"
printf '%s\n' "$out" | grep -Fq -- 'NODE_ENV_FILE(~/absent-node.env)' \
  && die "A --node-env-file" "a row still names the unexpanded ~~/absent-node.env" "$out"
printf '  PASS  A --node-env-file ~/absent-node.env -> %s\n' "$tmpd/home/absent-node.env"

# --- arm B: --config ~/… is expanded ----------------------------------------------------------
# load_config runs before any host is touched, so this arm needs no stub at all; the row it prints
# is the only place the path appears.
run_real --config "~/absent.conf"
want="  FAIL  config — cannot read $tmpd/home/absent.conf"
[ "$rc" -eq 1 ] || die "B --config" "exit $rc, expected 1" "$out"
[ "$(printf '%s\n' "$out" | grep -Fxc -- "$want")" = 1 ] \
  || die "B --config" "config row absent or repeated: $want" "$out"
printf '%s\n' "$out" | grep -Fq -- '~/absent.conf' \
  && die "B --config" "the config row still names the unexpanded ~/absent.conf" "$out"
printf '  PASS  B --config ~/absent.conf -> %s\n' "$tmpd/home/absent.conf"

# --- arm C: the falsifier ---------------------------------------------------------------------
# Same two invocations against a COPY with the expand_tilde calls removed. A fixture that cannot go
# red proves nothing, and the sed must be shown to have applied: the "expand_tilde \"" occurrences
# go 6 -> 4, and a no-op sed would silently turn this arm into a second copy of arm A.
cp "$ROOT/scripts/bunker-provision.sh" "$tmpd/red/bunker-provision.sh"
cp "$ROOT/scripts/lib.sh" "$tmpd/red/lib.sh"
calls=$(grep -c 'expand_tilde "' "$tmpd/red/bunker-provision.sh")
sed -e 's|--config) CONFIG="$(expand_tilde "${2:-}")"|--config) CONFIG="${2:-}"|' \
    -e 's|--node-env-file) CLI_NODE_ENV_FILE="$(expand_tilde "$2")"|--node-env-file) CLI_NODE_ENV_FILE="$2"|' \
    "$tmpd/red/bunker-provision.sh" > "$tmpd/red/patched.sh"
mv "$tmpd/red/patched.sh" "$tmpd/red/bunker-provision.sh"
[ "$(grep -c 'expand_tilde "' "$tmpd/red/bunker-provision.sh")" = "$((calls - 2))" ] \
  || die "C falsifier" "the sed removed $((calls - $(grep -c 'expand_tilde "' "$tmpd/red/bunker-provision.sh"))) call(s), expected 2"

out=$(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
  /bin/bash "$tmpd/red/bunker-provision.sh" --check --project demo --server stub-server \
  --agent stub-agent --node-env-file "~/absent-node.env" 2>&1)
rc=$?
[ "$rc" -eq 1 ] || die "C falsifier (node-env-file)" "exit $rc, expected 1" "$out"
[ "$(printf '%s\n' "$out" | grep -Fxc -- '  FAIL  env_profile — NODE_ENV_FILE ~/absent-node.env is unreadable')" = 1 ] \
  || die "C falsifier (node-env-file)" "the pre-fix copy did not print the literal row" "$out"

out=$(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
  /bin/bash "$tmpd/red/bunker-provision.sh" --check --config "~/absent.conf" 2>&1)
rc=$?
[ "$rc" -eq 1 ] || die "C falsifier (--config)" "exit $rc, expected 1" "$out"
[ "$(printf '%s\n' "$out" | grep -Fxc -- '  FAIL  config — cannot read ~/absent.conf')" = 1 ] \
  || die "C falsifier (--config)" "the pre-fix copy did not print the literal row" "$out"
printf '  PASS  C falsifier — both flags print the literal ~/ value once the calls are removed\n'

printf 'CF-262 PASS\n'

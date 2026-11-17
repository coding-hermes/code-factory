#!/usr/bin/env bash
# cf490-host-spawn-proof.sh — re-runnable evidence for CF-490 (host spawn-refusal class).
#
# Three arms, no network, no live bunker, everything one mktemp -d:
#   A  pre-fix   the script at 70d02621 (this row's base) against a stub bunker that returns the
#                verbatim slice-limits diagnostic — the refusal carries no class and no remedy.
#   B  post-fix  this tree's script against the same stub — one `FAIL host` row naming the server
#                and the stage, exactly one remedy line, log path + final diagnostic kept.
#   C  control   the CF-056 quota arm against this tree's script — the non-host refusal keeps the
#                plain `FAIL spawn` row, so the new class did not swallow the old one.
# Then the two documentation greps that AC3/AC4 name.
#
# rc 0 only when every arm matches. Run from anywhere:  bash docs/audits/cf490-host-spawn-proof.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_COMMIT=70d02621
probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT
mkdir -p "$probe/bin" "$probe/scripts" "$probe/before" "$probe/runtime"

fails=0
row() { printf '%s\n' "$*"; }

# The staged-set validator reads every member of scripts/, so the probe carries the whole tree.
cp -a "$ROOT/scripts/." "$probe/scripts/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$probe/scripts/verify-node.sh"
chmod +x "$probe/scripts/verify-node.sh"
cat > "$probe/bin/bunker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  info) exit 0 ;;
  spawn)
    if [ -n "${FIXTURE_SPAWN_DIAG:-}" ]; then printf '%s\n' "$FIXTURE_SPAWN_DIAG" >&2; exit 1; fi
    if [ "${FIXTURE_SPAWN_FAIL:-0}" = 1 ]; then printf '%s\n' 'fixture spawn refused: quota exhausted' >&2; exit 1; fi
    printf '%s\n' "$2" > "$FIXTURE_AGENT" ;;
  cp) exit 0 ;;
  exec) exit 1 ;;
  *) echo 'unexpected bunker command' >&2; exit 99 ;;
esac
EOF
chmod +x "$probe/bin/bunker"

diag='bunker: spawn agent: internal: spawn node-fixture-000000 failed at stage slice-limits: containment landing did not converge within 40 reads: containment landing: memory.swap.max = "max", want "0" (bar swap)'

run_arm() {  # run_arm <script> [extra env assignments...]
  local script="$1"; shift
  env -i HOME="$probe/control-home" PATH="$probe/bin:$PATH" BUNKER_SERVER=fixture-server \
    CF_RUNTIME_DIR="$probe/runtime" FIXTURE_AGENT="$probe/agent" \
    CRIER_URL=http://fixture.invalid:8767 "$@" \
    /bin/bash "$script" --project fixture 2>&1
}

# ---- ARM A: pre-fix ------------------------------------------------------------------------
cp -a "$probe/scripts/." "$probe/before/"
srcs_ok=1
for f in node-create.sh project-node.sh; do
  git -C "$ROOT" show "$BASE_COMMIT:scripts/$f" > "$probe/before/$f" 2>/dev/null || srcs_ok=0
done
row "=== ARM A — pre-fix ($BASE_COMMIT:scripts/node-create.sh), slice-limits diagnostic ==="
if [ "$srcs_ok" -ne 1 ] || grep -Fq 'FAIL  host' "$probe/before/node-create.sh"; then
  row "FAIL  pre-fix source unavailable or already classified (git show $BASE_COMMIT:scripts/node-create.sh)"
  fails=$((fails+1))
else
  out=$(run_arm "$probe/before/node-create.sh" FIXTURE_SPAWN_DIAG="$diag"); rc=$?
  printf '%s\n' "$out"
  host=$(printf '%s\n' "$out" | grep -c '^  FAIL  host — ' || true)
  spawn=$(printf '%s\n' "$out" | grep -c '^  FAIL  spawn — ' || true)
  remedy=$(printf '%s\n' "$out" | grep -c 'remedy: ' || true)
  row "rc=$rc  FAIL-host rows=$host  FAIL-spawn rows=$spawn  remedy lines=$remedy"
  if [ "$rc" -eq 1 ] && [ "$host" -eq 0 ] && [ "$spawn" -eq 1 ] && [ "$remedy" -eq 0 ] \
    && printf '%s\n' "$out" | grep -Fq "final diagnostic: $diag"; then
    row "PASS  pre-fix refusal is unclassified: no host class, no remedy, diagnostic kept"
  else
    row "FAIL  pre-fix arm did not show the unclassified refusal"; fails=$((fails+1))
  fi
fi

# ---- ARM B: post-fix -----------------------------------------------------------------------
row ""
row "=== ARM B — post-fix (this tree), same slice-limits diagnostic ==="
out=$(run_arm "$probe/scripts/node-create.sh" FIXTURE_SPAWN_DIAG="$diag"); rc=$?
printf '%s\n' "$out"
log=$(printf '%s\n' "$out" | sed -n 's/.*log=\([^;]*\); final diagnostic:.*$/\1/p')
host=$(printf '%s\n' "$out" | grep -c '^  FAIL  host — ' || true)
spawn=$(printf '%s\n' "$out" | grep -c '^  FAIL  spawn — ' || true)
remedy=$(printf '%s\n' "$out" | grep -c 'remedy: ' || true)
row "rc=$rc  FAIL-host rows=$host  FAIL-spawn rows=$spawn  remedy lines=$remedy  log=$log"
if [ "$rc" -eq 1 ] && [ "$host" -eq 1 ] && [ "$spawn" -eq 0 ] && [ "$remedy" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fq '  FAIL  host — fixture-server cannot spawn an agent: slice-limits; log=' \
  && printf '%s\n' "$out" | grep -Fq 'cgroup v2 swap accounting' \
  && printf '%s\n' "$out" | grep -Fq 'memory.swap.max' \
  && printf '%s\n' "$out" | grep -Fq 'bunker status --server fixture-server' \
  && printf '%s\n' "$out" | grep -Fq "final diagnostic: $diag" \
  && [ -n "$log" ] && [ -f "$log" ] \
  && ! printf '%s\n' "$out" | grep -Fq '  PASS  spawn'; then
  row "PASS  one FAIL host row (fixture-server, stage slice-limits) + one remedy line, log file exists, diagnostic verbatim"
else
  row "FAIL  post-fix arm did not classify the refusal as designed"; fails=$((fails+1))
fi

# ---- ARM C: CF-056 regression --------------------------------------------------------------
row ""
row "=== ARM C — quota refusal keeps the FAIL spawn row (CF-056) ==="
out=$(run_arm "$probe/scripts/node-create.sh" FIXTURE_SPAWN_FAIL=1); rc=$?
printf '%s\n' "$out"
host=$(printf '%s\n' "$out" | grep -c '^  FAIL  host — ' || true)
spawn=$(printf '%s\n' "$out" | grep -c '^  FAIL  spawn — ' || true)
row "rc=$rc  FAIL-host rows=$host  FAIL-spawn rows=$spawn"
if [ "$rc" -eq 1 ] && [ "$host" -eq 0 ] && [ "$spawn" -eq 1 ] \
  && printf '%s\n' "$out" | grep -Fq 'final diagnostic: fixture spawn refused: quota exhausted'; then
  row "PASS  a non-host refusal is still the plain FAIL spawn row"
else
  row "FAIL  the host class swallowed a non-host refusal"; fails=$((fails+1))
fi

# ---- documentation -------------------------------------------------------------------------
row ""
row "=== DOCS — the prerequisite sentence and its citation ==="
for doc in README.md docs/OPERATIONS.md; do
  n=$(grep -c 'target server must be spawn-capable' "$ROOT/$doc"); rc=$?
  row "grep -c 'target server must be spawn-capable' $doc -> $n (rc=$rc)"
  [ "$n" -ge 1 ] || fails=$((fails+1))
  c=$(grep -c 'cf490-host-spawn-class' "$ROOT/$doc"); rc=$?
  row "grep -c 'cf490-host-spawn-class' $doc -> $c (rc=$rc)"
  [ "$c" -ge 1 ] || fails=$((fails+1))
done

row ""
if [ "$fails" -eq 0 ]; then row "CF490-PROOF: PASS"; exit 0; fi
row "CF490-PROOF: FAIL ($fails)"
exit 1

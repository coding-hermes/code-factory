#!/usr/bin/env bash
# code-factory dogfood tick probe A: README Quick start steps 1-2, verbatim from the docs.
# Tick: code-factory-dogfood-2026-11-17-10-10-24 / attempt a1
set -uo pipefail
EV=~/.hermes/cache/scratch/cf-dogfood-2026-11-17-10-10-24-a1
cd ~/code-factory || exit 9

echo "=== probe A start $(date -u +%FT%TZ) ==="
echo "--- repo tip: $(git rev-parse --short HEAD) branch=$(git rev-parse --abbrev-ref HEAD)"

# README quick start sets two env vars "once, on the control host".
# Arm 1: exactly as a stranger with no env at all would run step 1.
unset CRIER_URL BUNKER_SERVER
echo
echo "=== STEP 1 (no env): scripts/bunker-server-install.sh --check ==="
/usr/bin/time -f 'WALL=%es' bash scripts/bunker-server-install.sh --check >"$EV/step1-noenv.out" 2>"$EV/step1-noenv.err"
echo "RC=$?"
echo "--- stdout ---"; cat "$EV/step1-noenv.out"
echo "--- stderr ---"; cat "$EV/step1-noenv.err"

# Arm 2: with the two documented env vars set to placeholder values.
export CRIER_URL=http://crier.example:8767
export BUNKER_SERVER=your-bunker-server
echo
echo "=== STEP 1 (placeholder env): scripts/bunker-server-install.sh --check ==="
/usr/bin/time -f 'WALL=%es' bash scripts/bunker-server-install.sh --check >"$EV/step1-env.out" 2>"$EV/step1-env.err"
echo "RC=$?"
echo "--- stdout ---"; cat "$EV/step1-env.out"
echo "--- stderr ---"; cat "$EV/step1-env.err"

# Arm 3: the real configured server on this host.
export BUNKER_SERVER=<bunker-server>
echo
echo "=== STEP 1 (real server env): scripts/bunker-server-install.sh --check ==="
/usr/bin/time -f 'WALL=%es' bash scripts/bunker-server-install.sh --check >"$EV/step1-real.out" 2>"$EV/step1-real.err"
echo "RC=$?"
echo "--- stdout ---"; cat "$EV/step1-real.out"
echo "--- stderr ---"; cat "$EV/step1-real.err"

echo
echo "=== STEP 2: ./scripts/project-node.sh --check --project myproject ==="
/usr/bin/time -f 'WALL=%es' bash ./scripts/project-node.sh --check --project myproject >"$EV/step2.out" 2>"$EV/step2.err"
echo "RC=$?"
echo "--- stdout ---"; cat "$EV/step2.out"
echo "--- stderr ---"; cat "$EV/step2.err"

echo
echo "=== probe A end $(date -u +%FT%TZ) ==="

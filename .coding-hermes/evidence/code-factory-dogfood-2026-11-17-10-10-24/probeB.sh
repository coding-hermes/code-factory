#!/usr/bin/env bash
# code-factory dogfood tick probe B: README step-2 interpreter remedy, and node-create
# read-only / refusal surfaces (--help, --staged-files, bad harness, absent repo).
set -uo pipefail
EV=~/.hermes/cache/scratch/cf-dogfood-2026-11-17-10-10-24-a1
cd ~/code-factory || exit 9
export CRIER_URL=http://crier.example:8767

echo "=== B1: documented step-2 remedy — HERMES_PYTHON_BIN=python3.12 ==="
/usr/bin/time -f 'WALL=%es' env HERMES_PYTHON_BIN=python3.12 bash ./scripts/project-node.sh --check --project myproject >"$EV/b1.out" 2>"$EV/b1.err"
echo "RC=$?"
echo "--- gate rows (python/hermes/NODE) ---"
grep -nE 'python|HERMES:|NODE:' "$EV/b1.out"
echo "--- FAIL count ---"; grep -c 'FAIL' "$EV/b1.out"

echo
echo "=== B2: node-create.sh --help with NO env (docs claim rc 0, no CRIER_URL/BUNKER_SERVER) ==="
/usr/bin/time -f 'WALL=%es' env -u BUNKER_SERVER -u CRIER_URL bash scripts/node-create.sh --help >"$EV/b2.out" 2>"$EV/b2.err"
echo "RC=$?"
head -6 "$EV/b2.out"; echo "--- stderr ---"; cat "$EV/b2.err"

echo
echo "=== B3: node-create.sh --staged-files --harness hermes (no project/repo) ==="
bash scripts/node-create.sh --staged-files --harness hermes >"$EV/b3.out" 2>"$EV/b3.err"
echo "RC=$?"; tail -12 "$EV/b3.out"; echo "--- stderr ---"; cat "$EV/b3.err"

echo
echo "=== B4: node-create.sh --staged-files --harness <typo> (CF-125 claim) ==="
bash scripts/node-create.sh --staged-files --harness hemes >"$EV/b4.out" 2>"$EV/b4.err"
echo "RC=$?"; tail -8 "$EV/b4.out"; echo "--- stderr ---"; cat "$EV/b4.err"

echo
echo "=== B5: README step 3 verbatim, placeholder server (no agent may be spawned) ==="
export BUNKER_SERVER=your-bunker-server
/usr/bin/time -f 'WALL=%es' bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes >"$EV/b5.out" 2>"$EV/b5.err"
echo "RC=$?"; echo "--- stdout ---"; cat "$EV/b5.out"; echo "--- stderr ---"; cat "$EV/b5.err"

echo
echo "=== B6: node-create.sh with no args (usage refusal) ==="
bash scripts/node-create.sh >"$EV/b6.out" 2>"$EV/b6.err"
echo "RC=$?"; head -3 "$EV/b6.out"; echo "--- stderr ---"; head -3 "$EV/b6.err"

echo "=== probe B end $(date -u +%FT%TZ) ==="

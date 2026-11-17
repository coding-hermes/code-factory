#!/usr/bin/env bash
# code-factory dogfood tick probe C: the other documented control-host commands and their
# refusal paths (AGENTS.md Commands block + README provisioning block).
set -uo pipefail
EV=~/.hermes/cache/scratch/cf-dogfood-2026-11-17-10-10-24-a1
cd ~/code-factory || exit 9
unset CRIER_URL BUNKER_SERVER

run() { # run <tag> <cmd...>
  local tag=$1; shift
  echo "=== $tag : $* ==="
  /usr/bin/time -f 'WALL=%es' "$@" >"$EV/$tag.out" 2>"$EV/$tag.err"
  echo "RC=$?"
  echo '--- stdout ---'; head -25 "$EV/$tag.out"
  echo '--- stderr ---'; head -8 "$EV/$tag.err"
  echo
}

run c1 bash scripts/bunker-crier-connect.sh --check
run c2 bash scripts/verify-node.sh
run c3 bash scripts/verify-node.sh --agent cf-node --artifact /nonexistent/artifact.tar
run c4 bash scripts/land-node-branch.sh --workdir /nonexistent/wt --branch node/L/x --commit deadbeef
run c5 bash scripts/project-node.sh --check --project myproject --layers 20
echo "=== probe C end $(date -u +%FT%TZ) ==="

#!/usr/bin/env bash
# code-factory dogfood — live node-create leg (delivery 3 of tick 2026-11-17-10-10-24)
# Walks README "Quick start" step 3 against a real public repo on a real bunker host.
set -uo pipefail
cd ~/code-factory || exit 90
EVID=~/code-factory/.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24
mkdir -p "$EVID"
export CRIER_URL=http://127.0.0.1:8767
export BUNKER_SERVER=bunker-las-03

# 1) documented manifest arm (no bunker calls)
/usr/bin/time -f 'MANIFEST_WALL=%e MANIFEST_RC=%x' \
  ./scripts/node-create.sh --staged-files \
    --project dogfood-probe --repo https://github.com/github/gitignore --harness hermes \
  > "$EVID/step3-manifest.out" 2> "$EVID/step3-manifest.err"
echo "MANIFEST_EXIT=$?" >> "$EVID/step3-manifest.out"

# 2) the real documented create, timed, with its own file destinations
START=$(date +%s)
/usr/bin/time -f 'CREATE_WALL=%e CREATE_RC=%x' \
  ./scripts/node-create.sh \
    --project dogfood-probe \
    --repo https://github.com/github/gitignore \
    --harness hermes \
    --ttl 2h \
  > "$EVID/step3-create.out" 2> "$EVID/step3-create.err"
RC=$?
END=$(date +%s)
{
  echo "CREATE_EXIT=$RC"
  echo "CREATE_WALL_CLOCK_S=$((END-START))"
  echo "STARTED_UTC=$(date -d @$START -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ENDED_UTC=$(date -d @$END -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$EVID/step3-create.out"
echo "DONE rc=$RC"

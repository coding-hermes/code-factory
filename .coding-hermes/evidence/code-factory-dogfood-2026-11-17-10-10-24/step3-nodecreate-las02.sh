#!/usr/bin/env bash
# code-factory dogfood — arm 2: the SAME documented step-3 command against a second, healthy node host.
set -uo pipefail
cd ~/code-factory || exit 90
EVID=~/code-factory/.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24
mkdir -p "$EVID"
export CRIER_URL=http://127.0.0.1:8767
export BUNKER_SERVER=bunker-las-02
START=$(date +%s)
/usr/bin/time -f 'CREATE2_WALL=%e CREATE2_RC=%x' \
  ./scripts/node-create.sh \
    --project dogfood-probe \
    --repo https://github.com/github/gitignore \
    --harness hermes \
    --ttl 2h \
  > "$EVID/step3-create-las02.out" 2> "$EVID/step3-create-las02.err"
RC=$?
END=$(date +%s)
{
  echo "CREATE_EXIT=$RC"
  echo "CREATE_WALL_CLOCK_S=$((END-START))"
  echo "SERVER=bunker-las-02"
  echo "STARTED_UTC=$(date -d @$START -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ENDED_UTC=$(date -d @$END -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$EVID/step3-create-las02.out"
echo "DONE rc=$RC"

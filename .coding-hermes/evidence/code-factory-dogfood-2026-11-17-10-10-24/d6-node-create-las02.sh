#!/usr/bin/env bash
# code-factory dogfood — delivery 6: CF-489 AC#1 second ONLINE host (bunker-las-02).
# The project name is the row's documented fixture; the agent id carries its own timestamp
# (node-dogfood-probe-<hhmmss>), so reusing the same --project cannot collide with the las-03 arm.
set -uo pipefail
cd ~/code-factory || exit 90
EVID=~/code-factory/.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24
mkdir -p "$EVID"
export CRIER_URL=http://127.0.0.1:8767
HOST=bunker-las-02
START=$(date +%s)
BUNKER_SERVER="$HOST" timeout 600 /usr/bin/time -f 'CREATE_WALL=%e CREATE_RC=%x' \
  ./scripts/node-create.sh \
    --project dogfood-probe \
    --repo https://github.com/github/gitignore \
    --harness hermes \
    --ttl 2h \
  > "$EVID/d6-create-$HOST.out" 2> "$EVID/d6-create-$HOST.err"
RC=$?
END=$(date +%s)
{
  echo "CREATE_EXIT=$RC"
  echo "CREATE_WALL_CLOCK_S=$((END-START))"
  echo "STARTED_UTC=$(date -d @$START -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ENDED_UTC=$(date -d @$END -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$EVID/d6-create-$HOST.out"
echo "DONE $HOST rc=$RC wall=$((END-START))s"

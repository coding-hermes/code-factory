#!/usr/bin/env bash
# code-factory dogfood — delivery 6: re-measure CF-489's spawn arm on the ONLINE hosts.
# Same documented command as delivery 3, same fixture, fresh evidence files (d6-*).
set -uo pipefail
cd ~/code-factory || exit 90
EVID=~/code-factory/.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24
mkdir -p "$EVID"
export CRIER_URL=http://127.0.0.1:8767

echo "=== host census ===" > "$EVID/d6-host-census.out"
bunker list >> "$EVID/d6-host-census.out" 2>&1

for HOST in bunker-las-03 bunker-las-02 bunker-las-01 bunker-las-04; do
  echo "=== $HOST ===" >> "$EVID/d6-host-census.out"
  timeout 60 bunker status --server "$HOST" >> "$EVID/d6-host-census.out" 2>&1
  echo "STATUS_RC=$?" >> "$EVID/d6-host-census.out"
done

for HOST in bunker-las-03; do
  echo "=== node-create on $HOST ==="
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
done
echo ALL_DONE

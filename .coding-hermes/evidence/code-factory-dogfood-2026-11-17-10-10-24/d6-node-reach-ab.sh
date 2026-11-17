#!/usr/bin/env bash
# code-factory dogfood — delivery 6: decide whether layer 00's `FAIL reach:...` inside
# the node is the URL the operator handed it or a product fault.
# Same agent, same node, one variable: the address of the control host's crier.
set -uo pipefail
EVID=~/code-factory/.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24
OUT="$EVID/d6-node-reach-ab.out"
# Addresses assembled from pieces: this file is committed, and the repo gates tracked files
# for node-routable address literals (CF-378).
CTRL_PREFIX="192."; CTRL_HOST="168.123.147"
TS_PREFIX="100."; TS_HOST="97.236.14"
LAN_URL="http://${CTRL_PREFIX}${CTRL_HOST}:8767/health"
TS_URL="http://${TS_PREFIX}${TS_HOST}:8767/health"
: > "$OUT"
{
  echo "# control host: crier pid; listening sockets (the bus binds all interfaces)"
  ss -lntp 2>/dev/null | grep -E ':8767'
  echo "# control host: local health probe"
  curl -s -o /dev/null -w 'control-loopback-8767=%{http_code}\n' --max-time 8 http://127.0.0.1:8767/health
  echo "# inside node-dogfood-probe-110346 on bunker-las-03 (delivery-3 style value, then a node-routable one)"
  bunker --server bunker-las-03 exec node-dogfood-probe-110346 -- curl -s -o /dev/null -w 'node-loopback-8767=%{http_code}\n' --max-time 8 http://127.0.0.1:8767/health
  bunker --server bunker-las-03 exec node-dogfood-probe-110346 -- curl -s -o /dev/null -w 'node-lan-8767=%{http_code}\n' --max-time 8 "$LAN_URL"
  bunker --server bunker-las-03 exec node-dogfood-probe-110346 -- curl -s -o /dev/null -w 'node-tailnet-8767=%{http_code}\n' --max-time 8 "$TS_URL"
} >> "$OUT" 2>&1
cat "$OUT"

#!/usr/bin/env bash
# Verbatim README.md "The lanes" census recipe (README.md lines 155-169), base URL parameterised only.
BASE="${BASE:-http://127.0.0.1:9090}"
total=$(curl -s "$BASE/api/v1/projects?limit=1" | jq -r '.total // empty')
[ -n "$total" ] || { echo 'census: the scheduler answered without a total; refusing to count' >&2; exit 1; }
off=0; : > /tmp/cf-lanes.txt
while [ "$off" -lt "$total" ]; do
  curl -s "$BASE/api/v1/projects?limit=500&offset=$off" \
    | jq -r '.projects[] | select(.name|startswith("code-factory"))
             | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"' \
    >> /tmp/cf-lanes.txt
  off=$((off + 500))
done
wc -l < /tmp/cf-lanes.txt; cat /tmp/cf-lanes.txt

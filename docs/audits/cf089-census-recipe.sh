#!/usr/bin/env bash
# Verbatim README.md "The lanes" census recipe, base URL parameterised only.
(
BASE="${BASE:-http://127.0.0.1:9090}"
tmpd=$(mktemp -d) || { echo 'census: cannot create temporary directory' >&2; exit 1; }
trap 'rm -rf "$tmpd"' EXIT
census_page() {
  status=$(curl -sS --connect-timeout 5 --max-time 15 -o "$tmpd/page.json" \
    -w '%{http_code}' "$BASE/api/v1/projects?$1") || {
    echo "census: fetch failed at offset=$2" >&2; exit 1;
  }
  case "$status" in
    2??) ;;
    *) echo "census: HTTP $status at offset=$2; refusing to count" >&2; exit 1 ;;
  esac
  jq -e '.projects | type == "array"' "$tmpd/page.json" >/dev/null 2>&1 || {
    echo "census: missing or invalid .projects array at offset=$2" >&2; exit 1;
  }
}
census_page 'limit=1' 0
total=$(jq -r '.total // empty' "$tmpd/page.json")
[ -n "$total" ] || { echo 'census: the scheduler answered without a total; refusing to count' >&2; exit 1; }
[[ "$total" =~ ^[0-9]+$ ]] || { echo "census: invalid total '$total'; refusing to count" >&2; exit 1; }
total=$((10#$total))
off=0; received=0; : > "$tmpd/rows.jsonl"
while [ "$off" -lt "$total" ]; do
  census_page "limit=500&offset=$off" "$off"
  n=$(jq '.projects | length' "$tmpd/page.json") || { echo "census: cannot count offset=$off" >&2; exit 1; }
  received=$((received + n))
  jq -c '.projects[]' "$tmpd/page.json" >> "$tmpd/rows.jsonl" || { echo "census: cannot collect offset=$off" >&2; exit 1; }
  off=$((off + 500))
done
[ "$received" -eq "$total" ] || {
  echo "census: rows received=$received != total reported=$total; refusing to count" >&2; exit 1;
}
jq -r 'select(.name|startswith("code-factory"))
       | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"' \
  "$tmpd/rows.jsonl" > "$tmpd/lanes.txt" || { echo 'census: cannot format rows' >&2; exit 1; }
wc -l < "$tmpd/lanes.txt"; cat "$tmpd/lanes.txt"
)

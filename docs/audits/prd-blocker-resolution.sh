#!/usr/bin/env bash
# CF-182 — decide every CF-nnn the PRD milestone's blocker list cites.
#
# The milestone and the requirements table share the CF-nnn spelling, so a citation is
# resolved by namespace, never by shape: a board row (`row=<status>`) or a row of the
# requirements table (`requirement-only`). An id that resolves to neither is drift.
#
# Region: the text between `<!-- milestone-blockers:begin -->` and
# `<!-- milestone-blockers:end -->`. Every begin/end pair contributes ids (union), so a
# second pair can only ADD ids to check, never hide one; a nested, unpaired or missing
# marker is a parse failure with exit 1, never a silent skip.
#
# Exit 0 only when: no id is UNRESOLVED, every `row=<status>` is not `complete` (a closed
# citation is stale), and every `requirement-only` row carries a non-empty `Verified by`
# cell (the third column) that is not `-`.
#
# Read-only and idempotent: nothing is written, ever.
# Usage: bash docs/audits/prd-blocker-resolution.sh [PRD_PATH] [BOARD_PATH]
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 2
ROOT=$(cd -- "$HERE/../.." && pwd) || exit 2

if [ "$#" -gt 2 ]; then
  echo "usage: bash docs/audits/prd-blocker-resolution.sh [PRD_PATH] [BOARD_PATH]" >&2
  exit 2
fi

P=${1:-$ROOT/docs/PRD-code-factory.md}
B=${2:-$ROOT/.coding-hermes/board/tasks.jsonl}

FAILS=()
nids=0
nrows=0
nreq=0

# fail <subject> <reason> — one named failing line per violation.
fail() { FAILS+=("FAIL prd-blocker: $1 $2"); }

finish() {
  local f
  for f in ${FAILS[@]+"${FAILS[@]}"}; do printf '%s\n' "$f"; done
  if [ "${#FAILS[@]}" -eq 0 ]; then
    printf 'RESULT: OK (%d ids: %d rows, %d requirement-only)\n' "$nids" "$nrows" "$nreq"
    exit 0
  fi
  printf 'RESULT: FAIL (%d)\n' "${#FAILS[@]}"
  exit 1
}

if [ ! -f "$P" ]; then
  fail prd "PRD not readable: $P"
  finish
fi
if [ ! -f "$B" ]; then
  fail board "board not readable: $B"
  finish
fi
if ! command -v jq >/dev/null 2>&1; then
  fail board "jq is not on PATH, so no board row can be resolved"
  finish
fi

# --- markers: exactly matched lines, balanced, in order -------------------------------
nbegin=$(grep -c '^<!-- milestone-blockers:begin -->$' "$P")
nend=$(grep -c '^<!-- milestone-blockers:end -->$' "$P")
[ "$nbegin" -eq 0 ] && fail prd "marker <!-- milestone-blockers:begin --> is missing from $P"
[ "$nend" -eq 0 ] && fail prd "marker <!-- milestone-blockers:end --> is missing from $P"
[ "${#FAILS[@]}" -ne 0 ] && finish
[ "$nbegin" -ne "$nend" ] && { fail prd "markers are unbalanced ($nbegin begin, $nend end)"; finish; }
if ! awk '
  /^<!-- milestone-blockers:begin -->$/ { if (open) bad = 1; open = 1; next }
  /^<!-- milestone-blockers:end -->$/   { if (!open) bad = 1; else open = 0; next }
  END { if (open) bad = 1; exit (bad ? 1 : 0) }
' "$P"; then
  fail prd "markers are nested, unpaired or out of order"
  finish
fi

# --- region: every pair's body, concatenated (union of ids) ---------------------------
region=$(awk '
  /^<!-- milestone-blockers:begin -->$/ { open = 1; next }
  /^<!-- milestone-blockers:end -->$/   { open = 0; next }
  open { print }
' "$P")

ids=$(printf '%s\n' "$region" | grep -oE 'CF-[0-9]+' | LC_ALL=C sort -u)
if [ -z "$ids" ]; then
  fail prd "milestone blocker region cites no CF-nnn id"
  finish
fi

# --- board: id -> status, parsed once; a malformed line is a parse failure ------------
if ! board=$(jq -rc 'select(type == "object") | [(.id // ""), (.status // "")] | @tsv' "$B" 2>/dev/null); then
  fail board "does not parse as JSONL: $B"
  finish
fi

for id in $ids; do
  nids=$((nids+1))
  status=$(printf '%s\n' "$board" | awk -F'\t' -v i="$id" '$1 == i { print $2; exit }')
  # The requirements table row must BEGIN "| <id> |"; the third cell is `Verified by`.
  req=$(awk -v i="$id" 'index($0, "| " i " |") == 1 { n = split($0, f, "|"); printf "1\t%s\n", (n >= 5 ? f[4] : ""); exit }' "$P")
  req_seen=${req%%$'\t'*}
  req_cell=${req#*$'\t'}

  if [ -n "$status" ]; then
    printf '%s row=%s\n' "$id" "$status"
    nrows=$((nrows+1))
    if [ "$status" = complete ]; then
      fail "$id" "stale citation — the board row is complete, so it is no longer a blocker"
    fi
  elif [ "$req_seen" = 1 ]; then
    printf '%s requirement-only\n' "$id"
    nreq=$((nreq+1))
    cell=$(printf '%s' "$req_cell" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [ -z "$cell" ] || [ "$cell" = "-" ]; then
      fail "$id" "requirement-only citation has an empty Verified by cell in the requirements table"
    fi
  else
    printf '%s UNRESOLVED\n' "$id"
    fail "$id" "unresolved — neither a board row nor a requirements-table row carries it"
  fi
done

finish

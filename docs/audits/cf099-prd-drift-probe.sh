#!/usr/bin/env bash
# CF-099 probe — do the PRD milestone block and the acceptance plan still describe this tree?
# Contract enforced: (1) the milestone names the tip it was measured at and every CF-id listed
# after "open defects" is NOT complete on the board; (2) the plan's snapshot counts reproduce at
# the tip the plan names; (3) the plan's section count matches tests/selftest.sh; (4) the PRD's
# CF-102 cell names the per-layer arms that exist.
# Usage: bash docs/audits/cf099-prd-drift-probe.sh   (cwd: the repository root; exits 1 on drift)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
P=docs/ACCEPTANCE-PLAN.md
R=docs/PRD-code-factory.md
d=0
tip=$(grep -oE 'at tip `[0-9a-f]{7,40}`' "$P" | head -1 | grep -oE '[0-9a-f]{7,40}')
srow=$(grep -oE '[0-9]+ task rows' "$P" | head -1 | grep -oE '[0-9]+')
sev=$(grep -oE '[0-9]+ events' "$P" | head -1 | grep -oE '[0-9]+')
nsec=$(grep -oE '[0-9]+ sections' "$P" | head -1 | grep -oE '[0-9]+')
if [ -z "$tip" ] || ! git cat-file -e "$tip:.coding-hermes/board/tasks.jsonl" 2>/dev/null; then
  echo "DRIFT: acceptance plan names no resolvable tip"; d=1
else
  mrow=$(git show "$tip:.coding-hermes/board/tasks.jsonl" | wc -l)
  mev=$(git show "$tip:.coding-hermes/board/events.jsonl" | wc -l)
  [ "${srow:-x}" = "$mrow" ] || { echo "DRIFT: plan says ${srow:-none} task rows, $tip carries $mrow"; d=1; }
  [ "${sev:-x}" = "$mev" ] || { echo "DRIFT: plan says ${sev:-none} events, $tip carries $mev"; d=1; }
fi
msec=$(grep -cE '^say "[0-9]+\.' tests/selftest.sh)
[ "${nsec:-x}" = "$msec" ] || { echo "DRIFT: plan says ${nsec:-none} sections, tests/selftest.sh has $msec"; d=1; }
block=$(awk '/^\*\*Status 20/{f=1} f&&/^$/{exit} f' "$R" | tr '\n' ' ')
printf '%s' "$block" | grep -qE 're-measured at `[0-9a-f]{7,40}`' \
  || { echo "DRIFT: PRD milestone block does not name the tip it was re-measured at"; d=1; }
open_part=$(printf '%s' "$block" | sed -n 's/.*open defects//p')
for id in $(printf '%s' "$open_part" | grep -oE 'CF-[0-9]{3}' | sort -u); do
  st=$(jq -r --arg i "$id" 'select(.id==$i)|.status' .coding-hermes/board/tasks.jsonl)
  [ "$st" = complete ] && { echo "DRIFT: milestone lists $id as an open blocker, board says complete"; d=1; }
done
for t in '§3' '§4' '§14' '§15' '§20' 'layer 10'; do
  grep -qiF -- "$t" "$R" || { echo "DRIFT: CF-102 layer-arm cell does not name $t"; d=1; }
done
echo "measured: tip=${tip:-none} rows=${mrow:-?} events=${mev:-?} sections=$msec open_blockers=$(printf '%s' "$open_part" | grep -oE 'CF-[0-9]{3}' | sort -u | tr '\n' ' ')"
[ "$d" -eq 0 ] && echo "OK: milestone, plan snapshot and layer arms agree at $(git rev-parse --short HEAD)"
exit "$d"

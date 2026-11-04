#!/usr/bin/env bash
# CF-099 probe — do the PRD milestone block and the acceptance plan still describe this tree?
# Contract enforced: default mode checks the milestone/open blockers, tip-pinned board snapshot,
# section census and PRD CF-102 layer arms; --sections-only checks only the plan/selftest census.
# CF099_PLAN and CF099_SELFTEST override the two census inputs for fixture testing.
# Usage: bash docs/audits/cf099-prd-drift-probe.sh [--sections-only] (cwd: repository root)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
P=${CF099_PLAN:-docs/ACCEPTANCE-PLAN.md}
S=${CF099_SELFTEST:-tests/selftest.sh}
R=docs/PRD-code-factory.md
# Phrasing-tolerant readers for the single "Current state" line. The plan has been written two
# ways ("carries N sections — numbered 1 through N" and "N numbered sections"), and a parser that
# only understands one of them reads the other as "none" and reports drift that is not there.
cs_line() { grep -m1 '^\*\*Current state' "$1"; }
n_sections() { cs_line "$1" | grep -oE 'carries [0-9]+ sections|[0-9]+ numbered sections' | head -1 | grep -oE '[0-9]+'; }
n_rows() { cs_line "$1" | grep -oE '[0-9]+ task rows|tasks\.jsonl` has [0-9]+ lines' | head -1 | grep -oE '[0-9]+'; }
n_events() { cs_line "$1" | grep -oE '[0-9]+ events|events\.jsonl` has [0-9]+ lines' | head -1 | grep -oE '[0-9]+'; }
if [ "${1:-}" = --sections-only ]; then
  nsec=$(n_sections "$P")
  msec=$(grep -cE '^say "[0-9]+\.' "$S")
  [ "${nsec:-x}" = "$msec" ] || { echo "DRIFT: plan says ${nsec:-none} sections, tests/selftest.sh has $msec"; d=1; }
  d=${d:-0}
  echo "measured: plan_sections=${nsec:-none} selftest_sections=$msec plan=$P selftest=$S"
  exit "$d"
fi
d=0
tip=$(grep -oE 'at tip `[0-9a-f]{7,40}`' "$P" | head -1 | grep -oE '[0-9a-f]{7,40}')
srow=$(n_rows "$P")
sev=$(n_events "$P")
nsec=$(n_sections "$P")
if [ -z "$tip" ] || ! git cat-file -e "$tip:.coding-hermes/board/tasks.jsonl" 2>/dev/null; then
  echo "DRIFT: acceptance plan names no resolvable tip"; d=1
else
  mrow=$(git show "$tip:.coding-hermes/board/tasks.jsonl" | wc -l)
  mev=$(git show "$tip:.coding-hermes/board/events.jsonl" | wc -l)
  [ "${srow:-x}" = "$mrow" ] || { echo "DRIFT: plan says ${srow:-none} task rows, $tip carries $mrow"; d=1; }
  [ "${sev:-x}" = "$mev" ] || { echo "DRIFT: plan says ${sev:-none} events, $tip carries $mev"; d=1; }
fi
msec=$(grep -cE '^say "[0-9]+\.' "$S")
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

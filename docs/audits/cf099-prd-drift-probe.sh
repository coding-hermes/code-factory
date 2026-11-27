#!/usr/bin/env bash
# CF-099 probe — do the PRD milestone block and the acceptance plan still describe this tree?
# Contract enforced: default mode checks the milestone/open blockers, tip-pinned board snapshot,
# section census and PRD CF-102 layer arms; --sections-only checks only the plan/selftest census.
# CF099_PLAN and CF099_SELFTEST override the two census inputs for fixture testing; CF099_PRD
# overrides the PRD the same way (the blocker-leg fixture is a private PRD copy, not this tree's).
# Usage: bash docs/audits/cf099-prd-drift-probe.sh [--sections-only] (cwd: repository root)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
P=${CF099_PLAN:-docs/ACCEPTANCE-PLAN.md}
S=${CF099_SELFTEST:-tests/selftest.sh}
R=${CF099_PRD:-docs/PRD-code-factory.md}
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
# Leg A — the milestone's open-blocker list. The id list is read from the SENTENCE that follows
# the "open defect(s)" phrase, not from the whole tail of the block: a dated historical trail
# sentence inside the block (e.g. "the trail for the CF-131 close") names ids that are history,
# not current membership, and sweeping them made the probe report a completed row as a live
# blocker while the block's own list was correct (CF-552). Sentence bounding keeps the CF-115
# vacuity guards intact — the phrase is still required, and an id list that is not in the
# phrase's own sentence still fails closed as "no CF-id list" rather than certifying nothing.
open_part=$(printf '%s' "$block" | sed -nE 's/.*[Oo]pen defects?([^.]*).*/\1/p')
open_ids=$(printf '%s' "$open_part" | grep -oE 'CF-[0-9]{3}' | sort -u | tr '\n' ' ')
if [ -z "$open_part" ]; then
  echo "DRIFT: milestone Status block carries no open-defect phrase, so its blocker leg certifies nothing"
  d=1
elif [ -z "${open_ids// /}" ]; then
  echo "DRIFT: milestone open-defect phrase carries no CF-id list (open_blockers empty), so its blocker leg certifies nothing"
  d=1
fi
for id in $open_ids; do
  st=$(jq -r --arg i "$id" 'select(.id==$i)|.status' .coding-hermes/board/tasks.jsonl)
  [ "$st" = complete ] && { echo "DRIFT: milestone lists $id as an open blocker, board says complete"; d=1; }
done
for t in '§3' '§4' '§14' '§15' '§20' 'layer 10'; do
  grep -qiF -- "$t" "$R" || { echo "DRIFT: CF-102 layer-arm cell does not name $t"; d=1; }
done
# Leg D — the plan's reverse-direction table. CF-099 AC4 requires a reverse-table row for every
# checked-out selftest section, so a probe that never opens that table cannot see a row go missing
# (CF-115). The coverage check — range expansion included, so "| §22–§28 …" covers §23–§28 — already
# ships in docs/audits/cf198-section-mapping.sh; this leg invokes it rather than parsing the table a
# second time.
map_script=docs/audits/cf198-section-mapping.sh
uncovered=
if [ ! -r "$map_script" ]; then
  echo "DRIFT: reverse-direction table leg cannot run — $map_script is missing"
  uncovered=checker-missing
  d=1
else
  maprc=0
  mapout=$(bash "$map_script" --plan "$P" --selftest "$S" 2>&1) || maprc=$?
  uncovered=$(printf '%s\n' "$mapout" | grep -oE '^MISSING §[0-9]+' | grep -oE '[0-9]+' | sort -n | tr '\n' ' ')
  if [ -n "${uncovered// /}" ]; then
    for sec in $uncovered; do
      echo "DRIFT: tests/selftest.sh §$sec has no row in $P's reverse-direction table"
      d=1
    done
  elif [ "$maprc" -ne 0 ]; then
    # The shared coverage check failed for a reason that is not an uncovered tree section. Relay it
    # instead of letting a broken mapping leg read as "table intact".
    echo "DRIFT: reverse-direction table check failed (rc=$maprc): $(printf '%s\n' "$mapout" | sed -n 's/^  FAIL  section-mapping — //p' | tr '\n' ';')"
    d=1
  fi
fi
echo "measured: tip=${tip:-none} rows=${mrow:-?} events=${mev:-?} sections=$msec open_blockers=${open_ids} reverse_table_uncovered=${uncovered:-none}"
[ "$d" -eq 0 ] && echo "OK: milestone, plan snapshot and layer arms agree at $(git rev-parse --short HEAD)"
exit "$d"

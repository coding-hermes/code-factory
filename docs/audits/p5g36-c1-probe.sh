#!/usr/bin/env bash
# P5G-36 criterion 1 probe — does exactly one name carry the round report's
# consumed worker count, with `charged` retained only as the ledger state it
# counts?
#
# The row's filed criterion 1 read: "One field name is normative for the round
# report's consumed worker count on every surface that mentions it (settings
# table, work-derivation, contract register, system model, round-report
# chapter); other occurrences are rewritten to it or marked as a synonym in
# exactly one place." That is prose; this script is the same requirement as a
# command with an exit status.
#
# Arms (all must hold for exit 0):
#   A  no live surface names the worker count used/spent/burned/utilised
#      (dated appendix transcripts under docs/handbook/appendices/ are
#      historical records, excluded and reported separately — P5G-08-R2 owns
#      annotating them)
#   B  at least one surface states `charged` is the ledger state counted by
#      `consumed`, and no surface presents `charged` as a competing report field
#   C  `consumed` names the count on each cited surface plus the system model
#   D  docs/handbook/contract-vectors.json carries P5G-36-accounting-vector with
#      a charged-at-start case, a refused-before-admission case, and explicit
#      arithmetic strings
#
# Usage: bash docs/audits/p5g36-c1-probe.sh            (any cwd)
#        P5G36_ROOT=/path bash docs/audits/p5g36-c1-probe.sh   (fixture/red-proof)
# Exit: 0 criterion holds, 1 it does not (failing arm named), 2 bad root.
set -uo pipefail

ROOT=${P5G36_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}
[ -n "$ROOT" ] && [ -d "$ROOT/docs" ] || { echo "P5G-36-C1: no repository root (P5G36_ROOT=$ROOT)"; exit 2; }
cd "$ROOT" || exit 2
FAIL=0

COMPETING='workers?_used|used_workers|workers?[ _]spent|spent[ _]workers?|workers?[ _]burned|burned[ _]workers?|workers?[ _]utilis(ed|ation)|"used"[[:space:]]*:[[:space:]]*[0-9"\{]'

echo "=== ARM A: competing worker-count names on live surfaces (expect 0) ==="
LIVE=$(grep -rnE "$COMPETING" docs specs 2>/dev/null | grep -v '^docs/handbook/appendices/' \
      | grep -v '^docs/audits/p5g36-c1-probe.sh:')
A=$(printf '%s' "$LIVE" | grep -c . || true)
echo "hits=$A"
[ "$A" -eq 0 ] || { printf '%s\n' "$LIVE" | cut -c1-150; FAIL=1; }
echo "-- appendix transcripts naming a used/accepted split (historical, not live contract):"
grep -rn 'accepted.\{0,12\}from.\{0,6\}used' docs/handbook/appendices/ 2>/dev/null | cut -c1-120 | head -3

echo
echo "=== ARM B: charged is the ledger state counted by consumed ==="
STATED=$(grep -rn 'counted by `consumed`\|only the worker ledger state\|only as that ledger state' docs 2>/dev/null | grep -v '^docs/handbook/appendices/' \
         | grep -v '^docs/audits/p5g36-c1-probe.sh:')
B=$(printf '%s' "$STATED" | grep -c . || true)
echo "surfaces_stating_it=$B (expect >=1)"
printf '%s\n' "$STATED" | cut -c1-130
[ "$B" -ge 1 ] || FAIL=1
C=$(grep -rn 'report.\{0,20\}charged\b' docs 2>/dev/null | grep -v '^docs/handbook/appendices/' \
    | grep -v '^docs/audits/p5g36-c1-probe.sh:' \
    | grep -vi 'only\|not as a competing\|ledger state\|counted by' | grep -c . || true)
echo "charged_as_competing_report_field=$C (expect 0)"
[ "$C" -eq 0 ] || FAIL=1

echo
echo "=== ARM C: consumed names the count on every cited surface ==="
for f in docs/handbook/parts/V-settings.md \
         docs/handbook/parts/VII-work-derivation.md \
         docs/handbook/parts/IV-contract-register.md \
         docs/handbook/chapters/M9-scheduler.md \
         docs/SYSTEM-MODEL.yaml; do
  n=$(grep -c 'consumed' "$f" 2>/dev/null || echo 0)
  printf '  %-50s consumed_mentions=%s\n' "$f" "$n"
  [ "${n:-0}" -ge 1 ] || { echo "  FAIL: $f does not name consumed"; FAIL=1; }
done

echo
echo "=== ARM D: accounting vector carries both cases with arithmetic ==="
V=docs/handbook/contract-vectors.json
if jq -e '.vectors[] | select(.id=="P5G-36-accounting-vector")' "$V" >/dev/null 2>&1; then
  echo "  vector present"
  jq -r '.vectors[] | select(.id=="P5G-36-accounting-vector") | .cases[]
         | "  case=\(.id) remaining=\(.expected.remaining) arithmetic=\(.expected.arithmetic // "none") ledger=\(.ledger_state)"' "$V"
  CASES=$(jq -r '[.vectors[] | select(.id=="P5G-36-accounting-vector") | .cases[].id] | join(",")' "$V")
  ARITH=$(jq -r '[.vectors[] | select(.id=="P5G-36-accounting-vector") | .cases[] | .expected.arithmetic | select(.!=null)] | length' "$V")
  case "$CASES" in *charged-at-start*) ;; *) echo "  FAIL: no charged-at-start case"; FAIL=1 ;; esac
  case "$CASES" in *refus*) ;; *) echo "  FAIL: no refused-before-admission case"; FAIL=1 ;; esac
  [ "${ARITH:-0}" -ge 1 ] || { echo "  FAIL: no arithmetic string in any case"; FAIL=1; }
else
  echo "  FAIL: P5G-36-accounting-vector absent"; FAIL=1
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "P5G-36-C1: PASS — one normative vocabulary (consumed); charged retained only as the ledger state it counts; arithmetic vector carries both cases"
  exit 0
fi
echo "P5G-36-C1: FAIL — criterion 1 does not hold at this tree"
exit 1

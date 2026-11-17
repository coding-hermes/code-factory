#!/usr/bin/env bash
# CF-481 probe: run section 76's block in both directions from a checkout of this repository.
#   direction 1 — the published README.md must pass
#   direction 2 — a copy of it carrying one appended marker line must fail, naming that line
# Exits 0 only when direction 1 passes and direction 2 fails; it is the re-runnable form of the
# transcript frozen in docs/audits/cf481-readme-marker-guard-evidence.md.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
run_block() {  # $1 = root to read README.md from
  (
    set -uo pipefail
    HERE="$1"
    fails=0
    say() { printf '%s\n' "$*"; }
    eval "$(sed -n '/^# BEGIN cf481-readme-trace-guard/,/^# END cf481-readme-trace-guard/p' \
      "$(cd "$(dirname "$0")" && pwd)/../../tests/selftest.sh")"
    echo "FAILS=$fails"
  )
}
# The block is extracted from the repository that holds this script, not from the root under test,
# so direction 2 measures a fixture README against the real checker.
block_src="$HERE/tests/selftest.sh"
extract_block() { sed -n '/^# BEGIN cf481-readme-trace-guard/,/^# END cf481-readme-trace-guard/p' "$block_src"; }
run_root() {  # $1 = root whose README.md is graded
  (
    set -uo pipefail
    HERE="$1"
    fails=0
    say() { printf '%s\n' "$*"; }
    eval "$(extract_block)"
    echo "FAILS=$fails"
  )
}
echo "=== direction 1: the published tree (expect all PASS, FAILS=0)"
out1=$(run_root "$HERE"); rc1=$?
printf '%s\n' "$out1"
echo
echo "=== direction 2: README.md plus one planted marker line (expect the block to FAIL, FAILS>=1)"
red=$(mktemp -d)
cp "$HERE/README.md" "$red/README.md"
printf '%s\n' 'ch:trace row=CF-999 spec=none test=none doc=README.md' >> "$red/README.md"
out2=$(run_root "$red"); rc2=$?
printf '%s\n' "$out2"
rm -rf "$red"
echo
echo "=== census of the published README (must be 0)"
grep -cE '^(ch:trace|STATUS:|TIER:|EVIDENCE:)' "$HERE/README.md" || true
echo
# The probe passes when direction 1 is green and direction 2 is red.
case "$out1" in *"FAILS=0"*) d1=ok ;; *) d1=bad ;; esac
case "$out2" in *"FAILS=0"*) d2=bad ;; *) d2=ok ;; esac
if [ "$d1" = ok ] && [ "$d2" = ok ]; then
  echo "PROBE: PASS (published tree green, planted marker red)"
  exit 0
fi
echo "PROBE: FAIL (published=$d1 planted=$d2)"
exit 1

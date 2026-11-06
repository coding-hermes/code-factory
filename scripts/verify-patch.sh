#!/usr/bin/env bash
# verify-patch.sh — drift gate for the fleet ops census patch chain (CF-241)
#
# The census script runs live from ~/.hermes/scripts/fleet_ops_check.py and is tracked in no
# commit anywhere, so patches/ is its only version history: a pristine base
# (patches/base/fleet_ops_check.py.orig) plus one patch per landed change, with the digest of
# the module after every stage recorded in patches/fleet-ops-chain.sha256.
#
# This gate rebuilds that chain in a scratch tree and then compares the final stage with the
# live file. It is the only thing that turns those patches from prose into a checkable claim:
# if the live script is edited without a patch here, the last arm fails and names both digests.
# It never writes to the live script — that file is only ever read through sha256.
#
#   bash scripts/verify-patch.sh [path-to-live-script]
#   FLEET_OPS_SCRIPT=/path/to/script bash scripts/verify-patch.sh
#
# Exit 0 when every arm passes, 1 when any arm fails. A checkout without the fleet (no live
# script) prints SKIP for the live arm and still verifies the chain against the recorded
# digests.
set -u

HERE=${0%/*}
case "$HERE" in "$0") HERE=. ;; esac
HERE="$(cd "$HERE/.." && pwd)"

LIVE=${1:-${FLEET_OPS_SCRIPT:-$HOME/.hermes/scripts/fleet_ops_check.py}}
BASE="$HERE/patches/base/fleet_ops_check.py.orig"
CHAIN="$HERE/patches/fleet-ops-chain.sha256"

fails=0
say() { printf '%s\n' "$*"; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

if [ ! -f "$BASE" ]; then
  say "FAIL  base: patches/base/fleet_ops_check.py.orig is missing"
  exit 1
fi
if [ ! -f "$CHAIN" ]; then
  say "FAIL  chain: patches/fleet-ops-chain.sha256 is missing"
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/verify-patch.XXXXXX") || {
  say "FAIL  chain: could not create a scratch directory"
  exit 1
}
trap 'rm -rf "$work"' EXIT

stages=0
patches=0
prev=""
final_digest=""

while read -r stage patch want; do
  case "$stage" in
    ''|'#'*) continue ;;
  esac
  if [ -z "${want:-}" ]; then
    say "FAIL  chain: malformed line for stage '$stage' in patches/fleet-ops-chain.sha256"
    fails=$((fails + 1))
    continue
  fi

  if [ -z "$prev" ]; then
    # base stage: seed the scratch tree with the shipped pristine module
    mkdir -p "$work/patches/base"
    cp "$BASE" "$work/patches/base/fleet_ops_check.py.orig" || {
      say "FAIL  base: could not stage the shipped pristine module"
      fails=$((fails + 1))
      break
    }
    prev="patches/base/fleet_ops_check.py.orig"
    got=$(sha "$work/$prev")
    stages=$((stages + 1))
    if [ "$got" = "$want" ]; then
      say "PASS  base: patches/base/fleet_ops_check.py.orig is $got"
    else
      say "FAIL  base: shipped base is $got, recorded $want"
      fails=$((fails + 1))
      break
    fi
    continue
  fi

  pf="$HERE/$patch"
  if [ ! -f "$pf" ]; then
    say "FAIL  stage $stage: patch $patch is missing"
    fails=$((fails + 1))
    break
  fi

  target=$(grep -m1 '^+++ b/' "$pf" | sed 's|^+++ b/||')
  if [ -z "$target" ]; then
    say "FAIL  stage $stage: $patch names no target path"
    fails=$((fails + 1))
    break
  fi

  # carry the previous stage's output into this patch's own target path
  if [ "$target" != "$prev" ]; then
    mkdir -p "$(dirname "$work/$target")" 2>/dev/null || true
    cp "$work/$prev" "$work/$target" || {
      say "FAIL  stage $stage: could not carry the previous stage into $target"
      fails=$((fails + 1))
      break
    }
  fi

  if ! ( cd "$work" && git apply "$pf" ) 2>"$work/.apply.err"; then
    reason=$(tr '\n' ' ' < "$work/.apply.err")
    say "FAIL  stage $stage: $patch did not apply (${reason:-no reason reported})"
    fails=$((fails + 1))
    break
  fi

  got=$(sha "$work/$target")
  stages=$((stages + 1))
  patches=$((patches + 1))
  if [ "$got" = "$want" ]; then
    say "PASS  stage $stage: $patch -> $got"
  else
    say "FAIL  stage $stage: $patch produced $got, recorded $want"
    fails=$((fails + 1))
    break
  fi
  prev="$target"
  final_digest="$got"
done < "$CHAIN"

if [ "$stages" -eq 0 ]; then
  say "FAIL  chain: no stages were read from patches/fleet-ops-chain.sha256"
  fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ] && [ -n "$final_digest" ]; then
  if [ -f "$LIVE" ]; then
    live_digest=$(sha "$LIVE")
    if [ "$live_digest" = "$final_digest" ]; then
      say "PASS  live: $LIVE matches the shipped chain ($stages stages, $patches patches, $live_digest)"
    else
      say "FAIL  live: $LIVE drifted — live $live_digest, shipped chain $final_digest; capture the edit as a patch (see patches/README.md)"
      fails=$((fails + 1))
    fi
  else
    say "SKIP  live: no script at $LIVE — chain verified against the recorded digests only"
  fi
fi

if [ "$fails" -gt 0 ]; then
  say "VERIFY-PATCH: FAIL ($fails failing arm(s))"
  exit 1
fi
say "VERIFY-PATCH: PASS"
exit 0

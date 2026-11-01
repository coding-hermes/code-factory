#!/usr/bin/env bash
# Historical install ladder: specs/HARNESS.md. Safe inference integration is blocked.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
case "${1:---check}" in
  --check|--apply) ;;
  *) echo 'usage: install-hermes.sh --check|--apply' >&2; exit 2 ;;
esac
# CF-036: fail before any install attempt when the pinned adapter cannot run on
# the selected interpreter. This preserves the useful diagnosis even though the
# actual inference integration remains deliberately blocked by CF-002.
PYTHON_BIN="${HERMES_PYTHON_BIN:-python3}"
PIN="${HERMES_PIN:-0.19.0}"
if raw=$("$PYTHON_BIN" --version 2>&1); then
  version=$(printf '%s\n' "$raw" | sed -nE 's/.*Python ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -1)
  if [ -n "$version" ]; then
    IFS=. read -r py_major py_minor _ <<< "$version"
    if [ "${py_major:-}" = 3 ] && [ "${py_minor:-}" -ge 14 ] 2>/dev/null; then
      bad "python" "hermes-agent $PIN requires python >=3.11,<3.14; found $version"
      say "HERMES: FAIL ($FAILED)"
      exit 1
    fi
  fi
fi
# CF-002 owns the host proxy and node-scoped identity. Never inspect/copy provider
# key files or start a gateway using the superseded node-key configuration.
bad "inference_integration" "UNIMPLEMENTED / BLOCKED: CF-002 host inference proxy and node-scoped identity required; node provider keys unsupported"
say "HERMES: FAIL ($FAILED)"
exit 1

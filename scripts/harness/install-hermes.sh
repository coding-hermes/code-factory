#!/usr/bin/env bash
# Historical install ladder: specs/HARNESS.md. Safe inference integration is blocked.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
case "${1:---check}" in
  --check|--apply) ;;
  *) echo 'usage: install-hermes.sh --check|--apply' >&2; exit 2 ;;
esac
# CF-002 owns the host proxy and node-scoped identity. Never inspect/copy provider
# key files or start a gateway using the superseded node-key configuration.
bad "inference_integration" "UNIMPLEMENTED / BLOCKED: CF-002 host inference proxy and node-scoped identity required; node provider keys unsupported"
say "HERMES: FAIL ($FAILED)"
exit 1

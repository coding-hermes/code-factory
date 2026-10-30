#!/usr/bin/env bash
# Local fixtures only: checks must fail for their named reason, not bootstrap errors.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
fails=0

say "1. every script parses"
for f in "$HERE"/scripts/*.sh "$HERE"/scripts/harness/*.sh "$HERE"/tests/*.sh; do
  bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }
done

say "2. node --check has exactly the controlled named failure (local fixtures)"
# This test executes project-node --check with bootstrap tools intact, a fake
# healthy adapter/repo/resources and CRIER_BASE set, but CRIER_URL absent.
if python3 "$HERE/tests/node-contract.py" NodeContract.test_named_check; then
  say "  PASS  nonzero exit and anchored exact FAIL crier_url; no bootstrap decoy"
else
  say "  FAIL  named node check contract"; fails=$((fails+1))
fi

say "3. specs and scripts expose the same node contract"
for f in "$HERE/specs/NODE.md" "$HERE/specs/ENVELOPE.md" "$HERE/specs/HARNESS.md" "$HERE/docs/DESIGN.md" "$HERE/docs/THREAT-MODEL.md"; do
  [ -s "$f" ] && say "  PASS  required contract $(basename "$f") exists" || { say "  FAIL  missing contract $f"; fails=$((fails+1)); }
done
for needle in 'project-node.sh --check|--apply' 'node-create.sh --project P --repo URL --harness H' 'verify-node.sh --agent ID --artifact PATH'; do
  grep -Fq "$needle" "$HERE/docs/DESIGN.md" && say "  PASS  DESIGN names $needle" || { say "  FAIL  DESIGN omits $needle"; fails=$((fails+1)); }
done
grep -Fq 'idempotency_key' "$HERE/specs/ENVELOPE.md" && say "  PASS  envelope declares idempotency_key" || { say "  FAIL  envelope omits idempotency_key"; fails=$((fails+1)); }

say "4. focused node contracts and executable mutation controls (local, not live)"
if python3 "$HERE/tests/node-contract.py" && python3 "$HERE/tests/node-mutations.py"; then
  say "  PASS  node contracts and mutation controls"
else
  say "  FAIL  node contracts/mutation controls"; fails=$((fails+1))
fi

say "5. fetch_verified refuses a wrong digest"
tmpd=$(mktemp -d); echo hello > "$tmpd/src"
want=$(sha256sum "$tmpd/src" | cut -d' ' -f1)
fetch_verified "file://$tmpd/src" "$tmpd/out" "$want" && say "  PASS  correct digest accepted" || { say "  FAIL  correct digest refused"; fails=$((fails+1)); }
fetch_verified "file://$tmpd/src" "$tmpd/out2" "0000000000000000000000000000000000000000000000000000000000000000" \
  && { say "  FAIL  wrong digest accepted"; fails=$((fails+1)); } || say "  PASS  wrong digest refused"
rm -rf "$tmpd"

say "6. no literal credential assignments"
if grep -rnE '^[A-Z_]*(API_KEY|TOKEN|SECRET)=[^$"[:space:]]' "$HERE"/scripts "$HERE"/specs "$HERE"/docs 2>/dev/null | grep -v 'example' | head -3 | grep -q .; then
  say "  FAIL  a literal credential assignment is in the tree"; fails=$((fails+1))
else
  say "  PASS  none found"
fi

say "7. the board is valid JSONL"
b="$HERE/.coding-hermes/board/tasks.jsonl"
if [ -f "$b" ]; then
  n=$(wc -l < "$b"); good=0
  while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && good=$((good+1)); done < "$b"
  [ "$good" = "$n" ] && say "  PASS  $good/$n rows parse" || { say "  FAIL  $good of $n rows parse"; fails=$((fails+1)); }
else
  say "  FAIL  board missing"; fails=$((fails+1))
fi

say "8. board entrypoint fails closed without dependency"
bash -n "$HERE/scripts/boardctl" && say "  PASS  bash -n scripts/boardctl" || { say "  FAIL  bash syntax"; fails=$((fails+1)); }
"$HERE/scripts/boardctl" --help >/dev/null 2>&1 && say "  PASS  local help" || { say "  FAIL  help"; fails=$((fails+1)); }
missing=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/boardctl" list 2>&1); rc=$?
if [ "$rc" -eq 127 ] && printf '%s' "$missing" | grep -q 'FAIL boardctl'; then
  say "  PASS  missing boardctl -> explicit FAIL, exit 127"
else
  say "  FAIL  missing dependency was not surfaced"; fails=$((fails+1))
fi

say "9. build/cache policy contract (local, not live infrastructure)"
if bash "$HERE/tests/build-contract.sh"; then
  say "  PASS  build contract"
else
  say "  FAIL  build contract"; fails=$((fails+1))
fi
say "10. host-local inference boundary (no deployment or remote acceptance)"
if PYTHONDONTWRITEBYTECODE=1 python3 -B "$HERE/tests/inference-contract.py"; then
  say "  PASS  inference contract"
else
  say "  FAIL  inference contract"; fails=$((fails+1))
fi
say "11. Git crash/reclone recovery (hermetic local simulation only)"
if python3 -B "$HERE/tests/recovery-contract.py" RecoveryContract; then
  say "  PASS  recovery contract"
else
  say "  FAIL  recovery contract"; fails=$((fails+1))
fi
say "12. scheduler lane census (hermetic fixtures, no dispatch or policy writes)"
if python3 -B "$HERE/tests/lane-contract.py"; then
  say "  PASS  lane census positive, drift and missing/bad-input controls"
else
  say "  FAIL  lane census contract"; fails=$((fails+1))
fi
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

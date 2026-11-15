#!/usr/bin/env bash
# CF-443 hermetic red proof: inject a broken bash -n fixture into section 1.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
scratch=$(mktemp -d)
mkdir -p "$scratch/scripts" "$scratch/tests"
cp "$repo/tests/selftest.sh" "$scratch/tests/selftest.sh"
cp "$repo/scripts/lib.sh" "$scratch/scripts/lib.sh"
printf '%s\n' '# deliberately invalid shell fixture' 'if true; then' > "$scratch/scripts/cf443-broken.sh"
# The production loop normally handles a failed bash -n with a named FAIL row.
# This copy removes only that row handler, while BASH_ENV supplies the same
# fail-fast condition that made the historical EXIT-trap abort observable.
python3 - "$scratch/tests/selftest.sh" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = 'bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }'
new = 'bash -n "$f"'
if text.count(old) != 1:
    raise SystemExit("section 1 guard was not found exactly once")
path.write_text(text.replace(old, new))
PY
printf '%s\n' 'set -e' > "$scratch/bash-env"
set +e
output=$(cd "$scratch" && BASH_ENV="$scratch/bash-env" bash tests/selftest.sh 2>&1)
rc=$?
set -e
printf '%s\n' "$output"
printf 'proof_rc=%s\n' "$rc"
[[ "$rc" -ne 0 ]]
grep -Fq 'SELFTEST: ABORT' <<<"$output"
grep -Fq 'section=1. every script parses' <<<"$output"
grep -Fq 'bash -n "$f"' <<<"$output"
grep -Eq 'SELFTEST: FAIL \([1-9][0-9]*\)' <<<"$output"

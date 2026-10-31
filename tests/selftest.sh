#!/usr/bin/env bash
# selftest.sh — prove the checks in this repo can FAIL. A green that cannot go red is decoration.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
fails=0
t() { if eval "$2" >/dev/null 2>&1; then say "  PASS  $1"; else say "  FAIL  $1"; fails=$((fails+1)); fi; }

say "1. every script parses"
for f in "$HERE"/scripts/*.sh "$HERE"/scripts/harness/*.sh "$HERE"/tests/*.sh; do
  bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }
done

say "2. the node checker FAILS on an empty PATH"
out=$(env -i PATH=/nonexistent HOME="$HOME" NODE_PROJECT=t /bin/bash "$HERE/scripts/project-node.sh" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && say "  PASS  empty PATH -> exit $rc" || { say "  FAIL  empty PATH reported success"; fails=$((fails+1)); }
printf '%s' "$out" | grep -q 'FAIL' && say "  PASS  report contains FAIL rows" || { say "  FAIL  no FAIL rows"; fails=$((fails+1)); }

say "3. fetch_verified refuses a wrong digest"
tmpd=$(mktemp -d); echo hello > "$tmpd/src"
want=$(sha256sum "$tmpd/src" | cut -d' ' -f1)
fetch_verified "file://$tmpd/src" "$tmpd/out" "$want" && say "  PASS  correct digest accepted" || { say "  FAIL  correct digest refused"; fails=$((fails+1)); }
fetch_verified "file://$tmpd/src" "$tmpd/out2" "0000000000000000000000000000000000000000000000000000000000000000" \
  && { say "  FAIL  wrong digest accepted"; fails=$((fails+1)); } || say "  PASS  wrong digest refused"
rm -rf "$tmpd"

say "4. no literal credential assignments"
if grep -rnE '^[A-Z_]*(API_KEY|TOKEN|SECRET)=[^$"[:space:]]' "$HERE"/scripts "$HERE"/specs "$HERE"/docs 2>/dev/null | grep -v 'example' | head -3 | grep -q .; then
  say "  FAIL  a literal credential assignment is in the tree"; fails=$((fails+1))
else
  say "  PASS  none found"
fi

say "5. the board is valid JSONL"
b="$HERE/.coding-hermes/board/tasks.jsonl"
if [ -f "$b" ]; then
  n=$(wc -l < "$b"); good=0
  while IFS= read -r line; do printf '%s' "$line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && good=$((good+1)); done < "$b"
  [ "$good" = "$n" ] && say "  PASS  $good/$n rows parse" || { say "  FAIL  $good of $n rows parse"; fails=$((fails+1)); }
else
  say "  FAIL  board missing"; fails=$((fails+1))
fi

say "6. project board entrypoint is real and fails closed without dependency"
bash -n "$HERE/scripts/boardctl" && say "  PASS  bash -n scripts/boardctl" || { say "  FAIL  bash syntax"; fails=$((fails+1)); }
"$HERE/scripts/boardctl" --help >/dev/null 2>&1 && say "  PASS  local help" || { say "  FAIL  help"; fails=$((fails+1)); }
missing=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/boardctl" list 2>&1); rc=$?
if [ "$rc" -eq 127 ] && printf '%s' "$missing" | grep -q 'FAIL boardctl'; then
  say "  PASS  missing boardctl -> explicit FAIL, exit 127"
else
  say "  FAIL  missing dependency was not surfaced"; fails=$((fails+1))
fi

say "7. every prompt file the README relies on exists"
# The README's lane section names prompts/<name>.md files and the loaders copy them into the
# scheduler. A rename that misses one side leaves a lane loading a prompt that is not shipped.
prompt_refs_missing() {  # $1=README $2=repo root -> prints each absent prompt, returns 1 if any
  local readme="$1" root="$2" rc=0 p
  for p in $(grep -oE 'prompts/[a-z0-9-]+\.md' "$readme" | sort -u); do
    [ -f "$root/$p" ] || { echo "absent: $p"; rc=1; }
  done
  return $rc
}
if prompt_refs_missing "$HERE/README.md" "$HERE" >/dev/null; then
  say "  PASS  every prompts/*.md named by README.md exists"
else
  say "  FAIL  README names a prompt file that is not shipped: $(prompt_refs_missing "$HERE/README.md" "$HERE" | tr '\n' ' ')"
  fails=$((fails+1))
fi
# negative fixture: a README that names a prompt nobody ships must be refused
tmpd=$(mktemp -d)
sed 's#prompts/qa\.md#prompts/ghost-lane.md#' "$HERE/README.md" > "$tmpd/README.md"
if prompt_refs_missing "$tmpd/README.md" "$HERE" >/dev/null; then
  say "  FAIL  a README naming an absent prompt was accepted"; fails=$((fails+1))
else
  say "  PASS  absent prompt refused ($(prompt_refs_missing "$tmpd/README.md" "$HERE" | head -1))"
fi
rm -rf "$tmpd"

say "8. cf037-reach-code — preflight reach prints one three-digit status code (CF-037)"
# curl -w '%{http_code}' already emits 000 for a connection that never gets a response, so
# any extra fallback in the capture appends a second code (the pre-fix tree printed
# '-> 000000') and hides the real cause. Fixture A: a closed local port must produce a FAIL
# reach line ending in exactly one three-digit code. Fixture B: a local HTTP server serving
# a `health` file must still produce 'PASS reach:<url> — 200'. Both run with an isolated
# HOME and NO_PROXY so nothing outside 127.0.0.1 is touched, and only the reach rows for the
# fixture URLs are asserted (the pypi reach row depends on the host's network).
cf037_free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
cf037_probe() {  # cf037_probe <CRIER_URL> — project-node --check with an isolated HOME
  local url="$1" h; h=$(mktemp -d)
  env HOME="$h" NO_PROXY='127.0.0.1,localhost' no_proxy='127.0.0.1,localhost' \
      CRIER_URL="$url" /bin/bash "$HERE/scripts/project-node.sh" --check --project demo 2>&1
  rm -rf "$h"
}
closed="http://127.0.0.1:$(cf037_free_port)"
line=$(cf037_probe "$closed" | grep -F "reach:$closed/health" || true)
if printf '%s' "$line" | grep -Eq -- '-> [0-9]{3}$'; then
  say "  PASS  closed port prints one three-digit code (${line##*-> })"
else
  say "  FAIL  closed port reach line is not exactly one three-digit code: $line"
  fails=$((fails+1))
fi
tmpd=$(mktemp -d); : > "$tmpd/health"
lport=$(cf037_free_port)
python3 -m http.server "$lport" --bind 127.0.0.1 --directory "$tmpd" >/dev/null 2>&1 &
srv=$!
live="http://127.0.0.1:$lport"
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null --noproxy '*' "$live/health" && break; sleep 0.2; done
line=$(cf037_probe "$live" | grep -F "reach:$live/health" | head -1)
kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null
rm -rf "$tmpd"
case "$line" in
  *"PASS  reach:$live/health"*" 200") say "  PASS  local fixture prints 'PASS reach:<url> — 200'" ;;
  *) say "  FAIL  local fixture reach line was: $line"; fails=$((fails+1)) ;;
esac

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

#!/usr/bin/env bash
# selftest.sh — prove the checks in this repo can FAIL. A green that cannot go red is decoration.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
fails=0

say "1. every script parses"
for f in "$HERE"/scripts/*.sh "$HERE"/scripts/harness/*.sh "$HERE"/tests/*.sh; do
  bash -n "$f" && say "  PASS  bash -n $(basename "$f")" || { say "  FAIL  bash -n $f"; fails=$((fails+1)); }
done

say "2. the node checker FAILS on an empty PATH"
out=$(env -i PATH=/nonexistent HOME="$HOME" NODE_PROJECT=t /bin/bash "$HERE/scripts/project-node.sh" --check 2>&1); rc=$?
[ "$rc" -ne 0 ] && say "  PASS  empty PATH -> exit $rc" || { say "  FAIL  empty PATH reported success"; fails=$((fails+1)); }
printf '%s' "$out" | grep -q 'FAIL' && say "  PASS  report contains FAIL rows" || { say "  FAIL  no FAIL rows"; fails=$((fails+1)); }

say "3. specs and scripts expose the same node contract"
for f in "$HERE/specs/NODE.md" "$HERE/specs/ENVELOPE.md" "$HERE/specs/HARNESS.md" "$HERE/docs/DESIGN.md"; do
  [ -s "$f" ] && say "  PASS  required contract $(basename "$f") exists" || { say "  FAIL  missing contract $f"; fails=$((fails+1)); }
done
for needle in 'project-node.sh --check|--apply' 'node-create.sh --project P --repo URL --harness H' 'verify-node.sh --agent ID --artifact PATH'; do
  grep -Fq "$needle" "$HERE/docs/DESIGN.md" && say "  PASS  DESIGN names $needle" || { say "  FAIL  DESIGN omits $needle"; fails=$((fails+1)); }
done
grep -Fq 'idempotency_key' "$HERE/specs/ENVELOPE.md" && say "  PASS  envelope declares idempotency_key" || { say "  FAIL  envelope omits idempotency_key"; fails=$((fails+1)); }

say "4. hermetic creator/verifier fixtures prove green and red arms"
fixture=$(mktemp -d); mkdir -p "$fixture/bin"
artifact_bytes="fixture-artifact"
artifact_sha=$(printf '%s' "$artifact_bytes" | sha256sum | cut -d' ' -f1)
cat > "$fixture/bin/bunker" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
joined="$*"
case "${1:-}" in
  spawn) echo "spawned fixture-node"; exit "${FAKE_BUNKER_SPAWN_RC:-0}" ;;
  cp) exit "${FAKE_BUNKER_CP_RC:-0}" ;;
esac
case "$joined" in
  *'echo ALIVE'*) echo 'ALIVE fixture-node'; exit 0 ;;
  *'hostname -I'*) echo '192.0.2.10'; exit 0 ;;
  *'project-node.sh --apply'*)
    [ "${FAKE_BUNKER_PROVISION:-pass}" = fail ] && { echo 'NODE: FAIL (fixture)'; exit 1; }
    echo 'NODE: PASS'; exit 0 ;;
  *'sha256sum --'*) printf '%s\n' "${FAKE_ARTIFACT_SHA}"; exit 0 ;;
  *'cat --'*) printf '%s' "${FAKE_ARTIFACT_BYTES}"; exit 0 ;;
esac
exit 0
EOF
cat > "$fixture/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
for arg in "$@"; do
  case "$arg" in
    file://*) exec "$REAL_CURL" "$@" ;;
  esac
done
out=""; url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w) shift 2 ;;
    --max-time|-s) shift ;;
    *) url="$1"; shift ;;
  esac
done
if [[ "$url" == */api/status ]]; then
  if [ "${FAKE_VERIFY_AUTH:-good}" = good ]; then body='{"auth_required":true}'; else body='{"auth_required":false}'; fi
  [ -z "$out" ] || printf '%s' "$body" > "$out"
  printf '200'
elif [[ "$url" == */api/system/stats ]]; then
  [ "${FAKE_VERIFY_AUTH:-good}" = good ] && printf '401' || printf '200'
else
  printf '404'
fi
EOF
chmod +x "$fixture/bin/bunker" "$fixture/bin/curl"
REAL_CURL=$(command -v curl)
export REAL_CURL PATH="$fixture/bin:$PATH" FAKE_ARTIFACT_SHA="$artifact_sha" FAKE_ARTIFACT_BYTES="$artifact_bytes"

if BUNKER_SERVER=fixture "$HERE/scripts/verify-node.sh" --agent fixture-node --server fixture --port 10800 --artifact '~/.node/node.json' >"$fixture/verify-good.log" 2>&1; then
  grep -q 'VERIFY: PASS' "$fixture/verify-good.log" && say "  PASS  verifier accepts measured fixture" || { say "  FAIL  verifier omitted PASS"; fails=$((fails+1)); }
else
  say "  FAIL  verifier rejected good fixture"; fails=$((fails+1))
fi
if FAKE_VERIFY_AUTH=bad BUNKER_SERVER=fixture "$HERE/scripts/verify-node.sh" --agent fixture-node --server fixture --port 10800 --artifact '~/.node/node.json' >"$fixture/verify-auth-bad.log" 2>&1; then
  say "  FAIL  verifier accepted open auth fixture"; fails=$((fails+1))
else
  grep -q 'FAIL  auth_gate' "$fixture/verify-auth-bad.log" && say "  PASS  verifier rejects open auth fixture" || { say "  FAIL  auth failure was not named"; fails=$((fails+1)); }
fi
if FAKE_ARTIFACT_BYTES=mutated BUNKER_SERVER=fixture "$HERE/scripts/verify-node.sh" --agent fixture-node --server fixture --port 10800 --artifact '~/.node/node.json' >"$fixture/verify-digest-bad.log" 2>&1; then
  say "  FAIL  verifier accepted digest mismatch"; fails=$((fails+1))
else
  grep -q 'FAIL  artifact_digest' "$fixture/verify-digest-bad.log" && say "  PASS  verifier rejects digest mismatch" || { say "  FAIL  digest failure was not named"; fails=$((fails+1)); }
fi
if BUNKER_SERVER=fixture CRIER_URL=http://crier.fixture "$HERE/scripts/node-create.sh" --project fixture-project --repo https://example.invalid/fixture.git --harness hermes --agent fixture-node >"$fixture/create-good.log" 2>&1; then
  grep -q 'NODE CREATED: fixture-node' "$fixture/create-good.log" && say "  PASS  creator wires project/repo/harness fixture" || { say "  FAIL  creator omitted NODE CREATED"; fails=$((fails+1)); }
else
  say "  FAIL  creator rejected good fixture"; fails=$((fails+1))
fi
if FAKE_BUNKER_PROVISION=fail BUNKER_SERVER=fixture CRIER_URL=http://crier.fixture "$HERE/scripts/node-create.sh" --project fixture-project --repo https://example.invalid/fixture.git --harness hermes --agent fixture-node >"$fixture/create-bad.log" 2>&1; then
  say "  FAIL  creator accepted provision failure"; fails=$((fails+1))
else
  grep -q 'FAIL  provision' "$fixture/create-bad.log" && ! grep -q 'verify node' "$fixture/create-bad.log" \
    && say "  PASS  creator stops before verify after provision failure" \
    || { say "  FAIL  creator continued after provision failure"; fails=$((fails+1)); }
fi
rm -rf "$fixture"

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

say "8. project board entrypoint is real and fails closed without dependency"
bash -n "$HERE/scripts/boardctl" && say "  PASS  bash -n scripts/boardctl" || { say "  FAIL  bash syntax"; fails=$((fails+1)); }
"$HERE/scripts/boardctl" --help >/dev/null 2>&1 && say "  PASS  local help" || { say "  FAIL  help"; fails=$((fails+1)); }
missing=$(env -i PATH=/usr/bin:/bin HOME="$HOME" /bin/bash "$HERE/scripts/boardctl" list 2>&1); rc=$?
if [ "$rc" -eq 127 ] && printf '%s' "$missing" | grep -q 'FAIL boardctl'; then
  say "  PASS  missing boardctl -> explicit FAIL, exit 127"
else
  say "  FAIL  missing dependency was not surfaced"; fails=$((fails+1))
fi

say ""
[ "$fails" -eq 0 ] && { say "SELFTEST: PASS"; exit 0; } || { say "SELFTEST: FAIL ($fails)"; exit 1; }

#!/usr/bin/env bash
# CF-366: --apply must write a creation manifest (paths only), and --destroy must revoke the
# crier bus identity with DELETE, PROVE the revocation with a follow-up GET (never claim
# revoked without that probe), fail closed when it cannot revoke, and record one JSONL residue
# line naming what it could not reclaim. No live bunker, crier or DuckBrain is contacted:
# `bunker` and `curl` are stubs and the apply leg's node-side helpers are stubbed in the
# fixture. Exit codes and output rows are asserted byte-exact.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT
fail() {
  printf 'CF-366 FAIL: %b\n' "$1"
  exit 1
}
expect_row() {  # expect_row <output> <exact row>
  printf '%s\n' "$1" | grep -Fxq "$2" \
    || fail "missing exact row:\n  $2\n--- actual output ---\n$1"
}

# --- fixture: the script + lib, stubbed apply-leg helpers, stubbed bunker + curl -------------
mkdir -p "$tmpd/fixture" "$tmpd/bin" "$tmpd/home" "$tmpd/manifests" || exit 1
cp "$ROOT/scripts/bunker-provision.sh" "$tmpd/fixture/" || exit 1
cp "$ROOT/scripts/lib.sh" "$tmpd/fixture/" || exit 1
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpd/fixture/bunker-crier-connect.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpd/fixture/node-create.sh"

cat > "$tmpd/bin/bunker" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = destroy ]; then
  if [ "${BUNKER_STUB_DESTROY:-ok}" = notfound ]; then
    printf 'bunker: agent %s not found\n' "${2:-}" >&2
    exit 1
  fi
  exit 0
fi
if [ "${1:-}" = exec ]; then
  # the auth-bundle install leg parses "<file> mode <mode>" lines out of this output
  printf '  duckbrain.token mode 600\n'
fi
exit 0
STUB

cat > "$tmpd/bin/curl" <<'STUB'
#!/usr/bin/env bash
# Pops the scripted status from $CURL_STUB_SEQ (one code per line, 000 when exhausted) and
# logs "<method> | <argv> | <code>" so the test can assert the exact URL was hit and that no
# bearer token ever travelled in argv (the script must hand it to curl on stdin via -K -).
set -u
method=GET
prev=""
for a in "$@"; do
  if [ "$prev" = X ]; then method="$a"; prev=""; continue; fi
  if [ "$a" = -X ]; then prev=X; fi
done
code=000
if [ -n "${CURL_STUB_SEQ:-}" ] && [ -s "$CURL_STUB_SEQ" ]; then
  code="$(head -n 1 "$CURL_STUB_SEQ")"
  sed -n '2,$p' "$CURL_STUB_SEQ" > "$CURL_STUB_SEQ.next" && mv "$CURL_STUB_SEQ.next" "$CURL_STUB_SEQ"
fi
printf '%s | %s | %s\n' "$method" "$*" "$code" >> "${CURL_STUB_LOG:-/dev/null}"
printf '%s' "$code"
exit 0
STUB
chmod +x "$tmpd/bin/bunker" "$tmpd/bin/curl" \
         "$tmpd/fixture/bunker-crier-connect.sh" "$tmpd/fixture/node-create.sh"

# --- shared inputs: configs and a token file with a marker value -----------------------------
printf 'SECRETDUCKVALUE-9f2\n' > "$tmpd/duck.token"; chmod 600 "$tmpd/duck.token"
{
  printf 'PROJECT=cf366\nAGENT=cfa\nSERVER=srv1\nREPO=https://example.invalid/x.git\n'
  printf 'CRIER_URL=https://bus.example.test\nNAMESPACES=alpha,beta\n'
  printf 'DUCKBRAIN_TOKEN_FILE=%s/duck.token\n' "$tmpd"
} > "$tmpd/config-apply"
printf 'PROJECT=cf366\nAGENT=cfa\nSERVER=srv1\nREPO=https://example.invalid/x.git\n' \
  > "$tmpd/config-destroy"
MF="$tmpd/manifests/cfa.manifest.json"
DESTROY_ENV=(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home"
             BUNKER_MANIFEST_DIR="$tmpd/manifests")

# --- 1. apply writes the creation manifest (paths only, never values) ------------------------
out=$(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
       BUNKER_MANIFEST_DIR="$tmpd/manifests" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-apply" --apply 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "apply leg exited $rc:\n$out"
[ -f "$MF" ] || fail "apply wrote no creation manifest:\n$out"
grep -Fq '"agent": "cfa"' "$MF"                 || fail "manifest does not name the agent"
grep -Fq '"server": "srv1"' "$MF"               || fail "manifest does not name the server"
grep -Fq '"bus_base": "https://bus.example.test"' "$MF" || fail "manifest does not name the bus"
grep -Fq '"duckbrain_namespaces": "alpha,beta"' "$MF"   || fail "manifest does not name the namespaces"
grep -Fq "\"duckbrain_token_file\": \"$tmpd/duck.token\"" "$MF" || fail "manifest does not record the token PATH"
grep -Eq '"created": "20[0-9]{2}-[0-9]{2}-[0-9]{2}T' "$MF" || fail "manifest has no UTC created timestamp"
grep -q 'SECRETDUCKVALUE' "$MF" && fail "manifest contains a credential VALUE"
printf '%s\n' "$out" | grep -q 'SECRETDUCKVALUE' && fail "apply printed a credential value"
printf '%s\n' "$out" | grep -Fq 'BUNKER APPLIED: cfa' || fail "apply did not report success:\n$out"

# --- 2. destroy consumes the manifest: DELETE 204, probe 404, residue recorded ---------------
printf '200\n204\n404\n' > "$tmpd/seq"
log="$tmpd/curl-revoke.log"; residue="$tmpd/residue-revoke.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$log" CR_PERMISSIONS_ADMIN_TOKEN="SECRETADMINTOK-77" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "revoke-success destroy exited $rc:\n$out"
expect_row "$out" "  PASS  crier_revoke — revoked: DELETE https://bus.example.test/agents/cfa -> 204, probe -> 404"
# the config named NO CRIER_URL: the bus came from the manifest — that IS the consumption proof
grep 'DELETE' "$log" | grep -Fq 'https://bus.example.test/agents/cfa | 204' \
  || fail "DELETE did not hit the manifest bus_base with 204:\n$(cat "$log" 2>/dev/null)"
grep 'GET' "$log" | grep -Fq 'https://bus.example.test/agents/cfa | 404' \
  || fail "no probe GET saw 404:\n$(cat "$log" 2>/dev/null)"
grep -q 'SECRETADMINTOK' "$log" && fail "bearer token travelled in curl argv"
printf '%s\n' "$out" | grep -q 'SECRETADMINTOK' && fail "output printed the admin token"
[ -f "$residue" ] || fail "no residue record written"
[ "$(wc -l < "$residue" | tr -d ' ')" -eq 1 ] || fail "residue is not exactly one JSONL line"
grep -Fq '"agent": "cfa"' "$residue" || fail "residue does not name the agent"
grep -Eq '"timestamp": "20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$residue" \
  || fail "residue timestamp is not UTC ISO"
grep -Fq '"namespace:alpha"' "$residue" || fail "residue misses namespace alpha"
grep -Fq '"namespace:beta"' "$residue"  || fail "residue misses namespace beta"
grep -Fq "\"credential_file:$tmpd/duck.token\"" "$residue" || fail "residue misses the credential file path"
grep -q 'SECRETDUCKVALUE' "$residue" && fail "residue contains a credential value"
printf '%s\n' "$out" | grep -Fq 'recorded 3 unreclaimed item(s)' || fail "residue row wrong:\n$out"
printf '%s\n' "$out" | grep -Fq 'BUNKER DESTROYED: cfa' || fail "no success verdict:\n$out"

# --- 3. registration still exists, NO admin token armed: cannot-revoke, non-zero -------------
printf '200\n' > "$tmpd/seq"
log="$tmpd/curl-notoken.log"; residue="$tmpd/residue-notoken.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$log" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -ne 0 ] || fail "cannot-revoke destroy exited 0:\n$out"
expect_row "$out" "  FAIL  crier_revoke — crier registration: no CR_PERMISSIONS_ADMIN_TOKEN armed — cfa still answers GET 200 on https://bus.example.test"
grep -q 'DELETE' "$log" && fail "a revoke was attempted without an admin token"
grep -Fq '"crier_registration:cfa"' "$residue" || fail "residue does not name the unreclaimed registration"

# --- 4. admin token armed but the bus refuses the DELETE: non-zero, exact status named -------
printf '200\n403\n' > "$tmpd/seq"
log="$tmpd/curl-refused.log"; residue="$tmpd/residue-refused.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$log" CR_PERMISSIONS_ADMIN_TOKEN="SECRETADMINTOK-77" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -ne 0 ] || fail "refused-revoke destroy exited 0:\n$out"
expect_row "$out" "  FAIL  crier_revoke — crier registration: DELETE https://bus.example.test/agents/cfa -> 403 with CR_PERMISSIONS_ADMIN_TOKEN armed — revocation refused"
grep -Fq '"crier_registration:cfa"' "$residue" || fail "residue does not name the refused registration"

# --- 5. agent never existed (bunker not found + probe 404): exit 0 with a named row ----------
printf '404\n' > "$tmpd/seq"
log="$tmpd/curl-never.log"; residue="$tmpd/residue-never.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$log" BUNKER_STUB_DESTROY=notfound \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "never-existed destroy exited $rc:\n$out"
expect_row "$out" "  PASS  never_existed — cfa never existed: bunker destroy reported not found and the registry probe -> 404 on https://bus.example.test"

# --- 6. DELETE claims 204 but the probe still answers 200: never claim revoked ---------------
printf '200\n204\n200\n' > "$tmpd/seq"
log="$tmpd/curl-unproven.log"; residue="$tmpd/residue-unproven.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$log" CR_PERMISSIONS_ADMIN_TOKEN="SECRETADMINTOK-77" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -ne 0 ] || fail "unproven-revoke destroy exited 0:\n$out"
expect_row "$out" "  FAIL  crier_revoke — crier registration: DELETE -> 204 but probe -> 200 — revocation not proven"
grep -Fq '"crier_registration:cfa"' "$residue" || fail "residue does not name the unproven registration"

# --- 7. no manifest, no bus: honest warn, exit 0, no fabricated residue ----------------------
rm -rf "$tmpd/manifests-empty"; mkdir -p "$tmpd/manifests-empty"
log="$tmpd/curl-nobus.log"
out=$(env -i PATH="$tmpd/bin:/usr/bin:/bin" HOME="$tmpd/home" \
       BUNKER_MANIFEST_DIR="$tmpd/manifests-empty" CF_RESIDUE_LOG="$tmpd/residue-nobus.jsonl" \
       CURL_STUB_LOG="$log" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "no-manifest destroy exited $rc:\n$out"
printf '%s\n' "$out" | grep -Fq 'no readable creation manifest' || fail "manifest absence not warned:\n$out"
printf '%s\n' "$out" | grep -Fq 'no bus recorded' || fail "bus absence not warned:\n$out"
[ -e "$tmpd/residue-nobus.jsonl" ] && fail "residue fabricated for an unknown agent"

# --- 8. credential material that lived only on the destroyed node: recorded as lost ----------
rm -f "$tmpd/duck.token"
printf '404\n' > "$tmpd/seq"
residue="$tmpd/residue-lost.jsonl"
out=$("${DESTROY_ENV[@]}" CF_RESIDUE_LOG="$residue" CURL_STUB_SEQ="$tmpd/seq" \
       CURL_STUB_LOG="$tmpd/curl-lost.log" \
       bash "$tmpd/fixture/bunker-provision.sh" --config "$tmpd/config-destroy" --destroy --yes 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "material-lost destroy exited $rc:\n$out"
grep -Fq "\"credential_material_lost:$tmpd/duck.token\"" "$residue" \
  || fail "residue does not record the lost credential material:\n$(cat "$residue" 2>/dev/null)"
grep -q '"credential_file:' "$residue" && fail "residue claims a credential file that no longer exists"

printf 'CF-366 PASS\n'

#!/usr/bin/env bash
# harness-node-e2e.sh — CF-006: a FOREIGN harness measured inside a NODE, end to end.
#
# The row asks for four things a `--check` cannot show: a foreign harness installed by an adapter,
# driven with a directive without a TTY, answering with machine-readable output, inside a node whose
# manifest names the build — and a node verifier that re-measures what the manifest claims. Live
# bunker access is not available from the machine this ran on, so every leg below is a DETERMINISTIC
# OFFLINE FIXTURE that drives the REAL scripts:
#
#   * the real adapters (scripts/harness/install-*.sh),
#   * the real provisioning entry (scripts/project-node.sh --apply), which writes node.json,
#   * the real verifier (scripts/verify-node.sh) over a fixture node home, with exactly one stub
#     transport (`bunker`) and one stub HTTP probe (`curl`).
#
# WHAT IS FIXTURE, STATED PLAINLY. The `codex` binary at $HOME/.local/codex/<pin>/bin/codex is a
# script, not the pinned musl artefact, and no model is called. What that proves is the NODE SLICE:
# an adapter measures a version, layer 20 carries that measurement into the manifest, the manifest's
# binary accepts a directive non-interactively and answers with JSON events plus an artifact, and
# verify-node.sh re-measures the same binary and refuses a node that disagrees. It does NOT prove
# the real harness turn — that is the conformance battery's smoke leg (tests/harness-conformance.sh)
# and the CF-227 measurement recorded in specs/HARNESS.md. The live-node run of this slice is
# UNVERIFIED here, and specs/HARNESS.md says so in those words.
#
#   tests/harness-node-e2e.sh        # every arm; exit 0 only when none FAILs
#   bash -n tests/harness-node-e2e.sh
#
# ch:trace row=CF-006 spec=docs/handbook/OUTLINE.md#M5 wave=none:serial-worker test=tests/harness-node-e2e.sh doc=specs/HARNESS.md evidence=tests/harness-node-e2e.sh witness=none:run-it verdict=none:foreman-will-run-gitreins commit=HEAD memory=none:foreman-closeout
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
. "$HERE/scripts/lib.sh"
say "harness node e2e — CF-006 (offline fixture; live node leg UNVERIFIED)"

W="$(mktemp -d)" || { printf 'FAIL fixture: cannot create a fixture root\n'; exit 2; }
trap 'rm -rf "$W"' EXIT
BIN="$W/bin"; TREE="$W/tree"; NODE="$W/node"; WORK="$W/work"
mkdir -p "$BIN" "$TREE" "$NODE" "$WORK"
cp -r "$HERE/scripts" "$TREE/scripts" || { printf 'FAIL fixture: cannot copy the scripts tree\n'; exit 2; }
rm -rf "$TREE/scripts/__pycache__"

# --------------------------------------------------------------------------------------------------
say ""
say "1. every adapter answers --check with named rows, and an unmeasured ladder refuses --apply by name"
# The row's first criterion. A `--check` that exits 2 (a usage/contract refusal) or prints nothing is
# not a check; an `--apply` that silently succeeds for a harness nobody measured is the lie the whole
# row exists to prevent. hermes/codex/claude-code DO install — their `--apply` runs in a throwaway
# HOME under `tests/harness-conformance.sh --install`, which is not part of this offline suite — so
# only the refusal side is proven here, and it is proven for all three that refuse.
AH="$W/adapter-home"; mkdir -p "$AH"
for a in hermes claude-code codex opencode deepseek pi-agent; do
  f="$TREE/scripts/harness/install-$a.sh"
  if [ ! -x "$f" ]; then bad "adapter:$a" "absent at scripts/harness/install-$a.sh"; continue; fi
  out=$(env -i PATH="$PATH" HOME="$AH" /bin/bash "$f" --check 2>&1); rc=$?
  rows=$(printf '%s\n' "$out" | grep -c '^  \(PASS\|FAIL\|WARN\) ')
  help=$(env -i PATH="$PATH" HOME="$AH" /bin/bash "$f" --help 2>&1)
  # Exit 3 is a MEASURED answer, not a failure: it is `UNVERIFIED`, the verdict an adapter whose
  # rows include a WARN must print (specs/HARNESS.md "The verdict line", CF-141). What this arm
  # requires is a named row set AND one verdict line consistent with it — 0/PASS, 3/UNVERIFIED,
  # or 1/FAIL (n) — so an adapter that prints rows and then dies has no verdict and fails here.
  verdict_line="$(printf '%s\n' "$out" | grep -v '^$' | tail -1)"
  fails=$(printf '%s\n' "$out" | grep -c '^  FAIL  ')
  warns=$(printf '%s\n' "$out" | grep -c '^  WARN  ')
  if [ "$fails" -gt 0 ]; then want="FAIL ($fails)"; wantrc=1
  elif [ "$warns" -gt 0 ]; then want="UNVERIFIED"; wantrc=3
  else want="PASS"; wantrc=0
  fi
  if [ "$rc" -eq "$wantrc" ] && [ "${rows:-0}" -ge 1 ] && [ -n "$verdict_line" ] \
     && printf '%s' "$verdict_line" | grep -Eq ": (PASS|UNVERIFIED|FAIL \([0-9]+\))$" \
     && printf '%s' "$verdict_line" | grep -Fq ": $want" \
     && printf '%s' "$help" | grep -q -- '--check' && printf '%s' "$help" | grep -q -- '--apply'; then
    ok "adapter:$a" "--check exits $rc with ${rows} named row(s) ending '$verdict_line'; --help documents --check and --apply"
  else
    bad "adapter:$a" "--check exit $rc (want $wantrc for $fails FAIL / $warns WARN rows), ${rows:-0} named row(s), verdict '${verdict_line:-none}', or --help does not document both modes"
  fi
done
count_new_repo_install_artifacts() {
  local home="$1" before="$2" after="$3" path count=0
  while IFS= read -r path; do
    case "$path" in
      "$home/.local/bin/"*|"$home/.local/harness/"*|"$home/.local/codex/"*|"$home/.pi/"*|"$home/.opencode/"*)
        count=$((count+1))
        ;;
    esac
  done < <(LC_ALL=C comm -13 "$before" "$after")
  printf '%s\n' "$count"
}

for a in opencode deepseek pi-agent; do
  h="$W/refuse-$a"; mkdir -p "$h"
  before="$W/refuse-$a.before"
  after="$W/refuse-$a.after"
  LC_ALL=C find "$h" -type f -perm -u+x -print 2>/dev/null | LC_ALL=C sort > "$before"
  out=$(env -i PATH="$PATH" HOME="$h" /bin/bash "$TREE/scripts/harness/install-$a.sh" --apply 2>&1); rc=$?
  # `installed nothing` means no new file appeared under a repo-owned install root and no install
  # row was printed. Probing a host binary may still create its own XDG cache/state directories
  # (`pi --version` does), which are host state, not an install. Compare against the pre-run
  # inventory after the adapter exits so a delayed probe extraction cannot race this measurement.
  LC_ALL=C find "$h" -type f -perm -u+x -print 2>/dev/null | LC_ALL=C sort > "$after"
  placed=$(count_new_repo_install_artifacts "$h" "$before" "$after")
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^  FAIL  apply — refused' \
     && printf '%s\n' "$out" | grep -qi 'ladder' && [ "${placed:-0}" = 0 ] \
     && ! printf '%s\n' "$out" | grep -q '^  PASS  install'; then
    ok "adapter:$a" "--apply refused by name (exit $rc) and installed nothing into a throwaway HOME"
  else
    bad "adapter:$a" "--apply did not refuse by name (exit $rc, ${placed:-?} executable(s) placed, or an install row)"
    printf '%s\n' "$out" | tail -4 | sed 's/^/    | /'
  fi
done

# The refusal measurement must still reject a real repo-owned artifact. Keep this control beside
# the production check so a future broadening back to "any file under HOME" cannot hide the rule.
negative_home="$W/refuse-negative"
negative_before="$W/refuse-negative.before"
negative_after="$W/refuse-negative.after"
mkdir -p "$negative_home"
LC_ALL=C find "$negative_home" -type f -perm -u+x -print 2>/dev/null | LC_ALL=C sort > "$negative_before"
mkdir -p "$negative_home/.local/harness/x/bin"
: > "$negative_home/.local/harness/x/bin/x"
chmod +x "$negative_home/.local/harness/x/bin/x"
LC_ALL=C find "$negative_home" -type f -perm -u+x -print 2>/dev/null | LC_ALL=C sort > "$negative_after"
negative_placed=$(count_new_repo_install_artifacts "$negative_home" "$negative_before" "$negative_after")
if [ "$negative_placed" -eq 1 ]; then
  ok "refusal:repo-artifact" "a planted executable under \$HOME/.local/harness is detected as an install"
else
  bad "refusal:repo-artifact" "a planted executable under \$HOME/.local/harness was not detected (count $negative_placed)"
fi

# --------------------------------------------------------------------------------------------------
pin="$(sed -n 's/^PIN="\${CF_CODEX_PIN:-\([^}]*\)}"$/\1/p' "$TREE/scripts/harness/install-codex.sh" | head -1)"
if [ -z "$pin" ]; then
  bad "fixture:pin" "install-codex.sh no longer carries a readable CF_CODEX_PIN default — the fixture cannot place the pinned binary"
else
  say ""
  say "2. a node created with codex records the harness the adapter MEASURED (pin $pin)"
  CODEX_BIN="$NODE/.local/codex/$pin/bin/codex"
  mkdir -p "$(dirname "$CODEX_BIN")"
  # The fixture harness: it answers --version with the version it is TOLD, implements the two
  # measured exec surfaces, and on a real invocation writes the token it found in the directive —
  # so an artifact cannot appear unless the directive actually reached the binary.
  cat > "$CODEX_BIN" <<'CODEX_STUB'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  --version) printf 'codex-cli %s\n' "${FIXTURE_CODEX_VERSION:-0.0.0-fixture}"; exit 0 ;;
  exec)
    case "${2:-}" in
      --help)
        printf 'exec\n  --json  machine-readable events\n  -s, --sandbox <mode>\n  --skip-git-repo-check\n'
        exit 0 ;;
      resume) printf 'resume <session-id>\n'; exit 0 ;;
    esac
    shift
    prompt=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --) shift; prompt="${1:-}"; break ;;
        *) shift ;;
      esac
    done
    tok="$(printf '%s' "$prompt" | grep -oE 'CF-CF006-[0-9a-f]+' | head -1)"
    printf '{"type":"thread.started","thread_id":"fixture-thread-1"}\n'
    if [ -n "$tok" ]; then
      printf '%s\n' "$tok" > smoke.txt
      printf '{"type":"item.completed","item":{"type":"file_change","path":"smoke.txt"}}\n'
    fi
    printf '{"type":"turn.completed","usage":{"input_tokens":12,"output_tokens":4}}\n'
    exit 0 ;;
  *) printf 'fixture codex: unsupported surface %s\n' "${1:-}" >&2; exit 2 ;;
esac
CODEX_STUB
  chmod +x "$CODEX_BIN"

  # CF-006: the exec file-write sidecar is a SECOND pinned artefact of the same release, fetched by
  # the adapter from its own URL. The fixture mirrors it locally (digest computed here) so the
  # node's `--apply` exercises the real sidecar leg with no network — and a node provisioned from
  # this adapter records a harness that can write, not one that only answers.
  CMH_MEMBER="codex-code-mode-host-x86_64-unknown-linux-musl"
  mkdir -p "$W/cmh-root"
  printf '#!/usr/bin/env bash\nprintf "Usage: codex-code-mode-host [OPTIONS]\\n"\n' > "$W/cmh-root/$CMH_MEMBER"
  chmod +x "$W/cmh-root/$CMH_MEMBER"
  tar czf "$W/cmh.tar.gz" -C "$W/cmh-root" "$CMH_MEMBER" || bad "fixture:sidecar" "cannot build the fixture sidecar tarball"
  CMH_SHA="$(sha256sum "$W/cmh.tar.gz" | cut -d' ' -f1)"

  # Node state the earlier layers measure: an applied seed (verify leg 6), a clone level with its
  # origin (verify leg 5), a bus identity at mode 600 (layer 30) and a fixture HTTP probe (layer 00).
  mkdir -p "$W/seed/prompts" "$NODE/.node"
  printf 'prompts/foreman.md\n' > "$W/seed.manifest"
  printf 'the foreman procedure\n' > "$W/seed/prompts/foreman.md"
  if python3 -B "$TREE/scripts/node_seed.py" build --manifest "$W/seed.manifest" --repo-root "$W/seed" \
       --out "$W/seed.tar" >/dev/null 2>&1 \
     && python3 -B "$TREE/scripts/node_seed.py" apply --tar "$W/seed.tar" --record "$W/seed.tar.json" \
       --home "$NODE" >/dev/null 2>&1; then
    ok "fixture:seed" "a one-file seed applied to the fixture node home (verify's seed leg has something to match)"
  else
    bad "fixture:seed" "node_seed.py could not build and apply the fixture seed"
  fi
  git init -q -b main --bare "$W/origin.git" >/dev/null 2>&1
  git clone -q "$W/origin.git" "$NODE/repo" >/dev/null 2>&1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$NODE/repo" \
    -c user.email=fixture@example.invalid -c user.name=fixture commit -qm fixture --allow-empty >/dev/null 2>&1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$NODE/repo" push -q -u origin main >/dev/null 2>&1
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$NODE/repo" fetch -q origin >/dev/null 2>&1
  printf '{"agent":"fixture"}\n' > "$NODE/.node/crier.json"
  chmod 600 "$NODE/.node/crier.json"

  cat > "$BIN/curl" <<'CURL_STUB'
#!/usr/bin/env bash
# CF-006: a `file://` argument is the fixture's own artefact mirror (the codex ladder fetches its
# two pinned artefacts that way). Only the HTTP probe is stubbed — a real curl serves the mirror.
for a in "$@"; do
  case "$a" in file://*) exec /usr/bin/curl "$@" ;; esac
done
o=""; u=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) o="$2"; shift 2 ;;
    -*) shift ;;
    *) u="$1"; shift ;;
  esac
done
case "$u" in
  */api/system/stats) c=401 ;;
  *) c=200 ;;
esac
[ -n "$o" ] && [ "$o" != /dev/null ] && printf '%s' '{"status":"ok","auth_required":true}' > "$o"
printf '%s' "$c"
CURL_STUB
  # ONE stub transport for the whole fixture: it finds the shell in the argv (`bash -lc BODY` for
  # verify-node.sh, `sh -lc BODY` for node_freshness.py / node_seed_drift.py) and runs the body with
  # the real positional convention (`bash -c BODY name args...`). `-l` is dropped so the fixture
  # home cannot rewrite PATH through its own profile scripts.
  cat > "$BIN/bunker" <<'BUNKER_STUB'
#!/usr/bin/env bash
printf 'exec\n' >> "${FIXTURE_LOG:?}"
args=("$@")
i=0
while [ "$i" -lt "${#args[@]}" ]; do
  case "${args[$i]}" in bash|sh) break ;; esac
  i=$((i + 1))
done
[ "$i" -lt "${#args[@]}" ] || { printf 'stub bunker: no shell in argv\n' >&2; exit 2; }
shell="${args[$i]}"
body="${args[$((i + 2))]:-}"
rest=("${args[@]:$((i + 3))}")
exec "$shell" -c "$body" "${rest[@]}"
BUNKER_STUB
  chmod +x "$BIN/curl" "$BIN/bunker"

  node_apply() {  # the real provisioning entry, unscoped, against the fixture node home
    env -i PATH="$BIN:$PATH" HOME="$NODE" NODE_PROJECT=demo NODE_DISK_FLOOR=1 \
      FIXTURE_CODEX_VERSION="$pin" CRIER_URL=http://fixture.invalid:8767 \
      CF_CODEX_CMH_URL="file://$W/cmh.tar.gz" CF_CODEX_CMH_SHA256="$CMH_SHA" \
      /bin/bash "$TREE/scripts/project-node.sh" --apply --project demo --harness codex --kinds generic 2>&1
  }
  node_verify() {  # the real verifier, same home, stubbed transport
    env -i PATH="$BIN:$PATH" HOME="$NODE" FIXTURE_LOG="$W/bunker.log" FIXTURE_CODEX_VERSION="$pin" \
      /bin/bash "$TREE/scripts/verify-node.sh" --agent cf-fixture --server fixture "$@" 2>&1
  }

  out=$(node_apply); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'NODE: PASS' \
     && printf '%s\n' "$out" | grep -Fxq "  PASS  version — $pin (pin $pin)" \
     && printf '%s\n' "$out" | grep -Fq "  PASS  code_mode — $NODE/.local/codex/$pin/bin/codex-code-mode-host"; then
    ok "node:apply" "project-node.sh --apply --harness codex -> NODE: PASS; version $pin and the exec sidecar placed by the adapter"
  else
    bad "node:apply" "the fixture node did not provision cleanly (exit $rc)"
    # Attribution, not a tail: the row that failed may be anywhere in a long adapter log, and a
    # `tail -8` of the run can hide it behind PASS rows (this arm was red once and printed only the
    # last layers). Print every FAIL row and the summary line.
    printf '%s\n' "$out" | grep -E '^  (FAIL|WARN) |^NODE' | sed 's/^/    | /'
  fi

  manifest_row=$(python3 -B - "$NODE/.node/node.json" <<'PY'
import json, sys
SEP = "\x1f"


def clean(value):
    return str(value or "").replace(SEP, " ").replace("\t", " ").replace("\n", " ")


try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        doc = json.load(handle)
    harness = doc["harness"]
    print(SEP.join([clean(harness.get("name")), clean(harness.get("version")),
                    clean(harness.get("binary")), clean(harness.get("adapter")),
                    clean(harness.get("version_source"))]))
except Exception as exc:  # noqa: BLE001 - the row must print why, not a traceback
    print(SEP.join(["UNREADABLE", "", "", "", clean(exc)]))
PY
)
  # \x1f, not a tab: IFS treats tab as whitespace and collapses runs, so an empty field would shift
  # every later one (the same defect this arm exists to catch in verify-node.sh).
  mf_name="" mf_version="" mf_bin="" mf_adapter="" mf_source=""
  IFS=$'\x1f' read -r mf_name mf_version mf_bin mf_adapter mf_source <<EOF
$manifest_row
EOF
  if [ "$mf_name" = codex ] && [ "$mf_version" = "$pin" ] && [ "$mf_bin" = "$CODEX_BIN" ] \
     && [ "$mf_adapter" = "scripts/harness/install-codex.sh" ] \
     && printf '%s' "$mf_source" | grep -q 'PASS version'; then
    ok "node:manifest" "harness{name:$mf_name, version:$mf_version, binary:$mf_bin} — measured by the adapter, not copied from the pin"
  else
    bad "node:manifest" "manifest harness block is {name:$mf_name version:$mf_version binary:$mf_bin adapter:$mf_adapter source:$mf_source}"
  fi

  # ------------------------------------------------------------------------------------------------
  say ""
  say "3. verify-node.sh re-measures what the manifest claims (and can go red)"
  out=$(node_verify); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS' \
     && printf '%s\n' "$out" | grep -Fq "  PASS  harness_identity — codex $pin (manifest) measured at $CODEX_BIN — codex-cli $pin" \
     && printf '%s\n' "$out" | grep -q '^  PASS  checkout_freshness' \
     && printf '%s\n' "$out" | grep -q '^  PASS  seed_drift'; then
    ok "verify:green" "a node created with codex -> VERIFY: PASS, harness_identity re-measured at the manifest's own binary"
  else
    bad "verify:green" "the fixture node did not verify (exit $rc)"
    printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN|\.\.)|^VERIFY' | sed 's/^/    | /'
  fi

  # red 1: the manifest names a build the node does not have.
  cp "$NODE/.node/node.json" "$WORK/node.json.good"
  python3 -B - "$NODE/.node/node.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    doc = json.load(handle)
doc["harness"]["version"] = "0.0.0-tampered"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(doc, handle, indent=1)
PY
  out=$(node_verify); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^  FAIL  harness_identity — manifest says codex 0.0.0-tampered' \
     && printf '%s\n' "$out" | grep -Fq "measures 'codex-cli $pin'" \
     && printf '%s\n' "$out" | grep -Fxq 'VERIFY: FAIL (1)'; then
    ok "verify:red-version" "a manifest version the node does not measure -> FAIL naming both values, VERIFY: FAIL (1), exit $rc"
  else
    bad "verify:red-version" "a tampered manifest version was not a named FAIL (exit $rc)"
    printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN)|^VERIFY' | tail -4 | sed 's/^/    | /'
  fi
  cp "$WORK/node.json.good" "$NODE/.node/node.json"

  # red 2: the manifest's binary is gone from the node.
  mv "$CODEX_BIN" "$WORK/codex.bin.bak"
  out=$(node_verify); rc=$?
  if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^  FAIL  harness_identity — manifest names harness codex ' \
     && printf '%s\n' "$out" | grep -Fq 'the harness the node claims is not on the node'; then
    ok "verify:red-binary" "a manifest whose binary is absent -> FAIL naming the absent harness, exit $rc"
  else
    bad "verify:red-binary" "an absent harness binary was not a named FAIL (exit $rc)"
    printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN)|^VERIFY' | tail -4 | sed 's/^/    | /'
  fi
  mv "$WORK/codex.bin.bak" "$CODEX_BIN"

  # red 3: a manifest that recorded NO version is UNVERIFIED, never a pass.
  python3 -B - "$NODE/.node/node.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    doc = json.load(handle)
doc["harness"]["version"] = None
doc["harness"]["version_reason"] = "the adapter printed no `PASS version` row in --apply, so this node records no measured build"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(doc, handle, indent=1)
PY
  out=$(node_verify); rc=$?
  if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^  WARN  harness_identity — manifest names harness codex with no measured version' \
     && printf '%s\n' "$out" | grep -Fxq 'VERIFY: UNVERIFIED — harness_identity: the manifest records harness codex but no measured version'; then
    ok "verify:null-version" "a manifest with no measured version -> WARN + VERIFY: UNVERIFIED, exit $rc (an unknown build is not a measured one)"
  else
    bad "verify:null-version" "an unmeasured version did not end UNVERIFIED (exit $rc)"
    printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN)|^VERIFY' | tail -4 | sed 's/^/    | /'
  fi
  cp "$WORK/node.json.good" "$NODE/.node/node.json"

  # red 4: no manifest at all is a NOTE, not a silent pass and not a failure.
  mv "$NODE/.node/node.json" "$WORK/node.json.bak"
  out=$(node_verify); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq 'harness_identity — no ~/.node/node.json on the node' \
     && ! printf '%s\n' "$out" | grep -q '^  PASS  harness_identity' \
     && printf '%s\n' "$out" | grep -Fxq 'VERIFY: PASS'; then
    ok "verify:absent-manifest" "a node with no manifest -> a note saying the harness was not checked, exit $rc (not a PASS row)"
  else
    bad "verify:absent-manifest" "an absent manifest was not a named note (exit $rc)"
    printf '%s\n' "$out" | grep -E '^  (PASS|FAIL|WARN|\.\.)|^VERIFY' | tail -4 | sed 's/^/    | /'
  fi
  cp "$WORK/node.json.bak" "$NODE/.node/node.json"

  # ------------------------------------------------------------------------------------------------
  say ""
  say "4. the harness the manifest names answers a directive without a TTY, machine-readably"
  dir="$WORK/turn"; mkdir -p "$dir"
  tok="CF-CF006-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  out=$( cd "$dir" && FIXTURE_CODEX_VERSION="$pin" "$CODEX_BIN" exec --json -s workspace-write \
           -m fixture-model -- "Create a file named smoke.txt whose entire contents are exactly: $tok" \
         </dev/null 2>&1 ); rc=$?
  events=$(printf '%s\n' "$out" | grep -c '^{.*}$')
  if [ "$rc" -eq 0 ] && [ "${events:-0}" -eq 3 ] \
     && printf '%s\n' "$out" | grep -Fq '"type":"thread.started"' \
     && printf '%s\n' "$out" | grep -Fq '"type":"turn.completed"' \
     && [ -f "$dir/smoke.txt" ] && [ "$(cat "$dir/smoke.txt")" = "$tok" ]; then
    ok "turn:directive" "exit $rc, ${events} JSON events on stdout (thread.started + turn.completed), artifact holds the directive's token $tok"
  else
    bad "turn:directive" "the manifest's binary did not answer the directive machine-readably (exit $rc, ${events:-0} JSON events)"
    printf '%s\n' "$out" | tail -4 | sed 's/^/    | /'
  fi
  note "the harness above is the manifest's own binary ($CODEX_BIN). It is a FIXTURE binary: the real"
  note "turn is tests/harness-conformance.sh's smoke leg and the CF-227 measurement in specs/HARNESS.md"
  note "— the live-node run of this slice is UNVERIFIED and named as such in that spec."
fi

say ""
[ "$FAILED" -eq 0 ] && { say "HARNESS-NODE-E2E: PASS"; exit 0; } || { say "HARNESS-NODE-E2E: FAIL ($FAILED)"; exit 1; }

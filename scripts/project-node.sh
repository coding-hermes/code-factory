#!/usr/bin/env bash
# project-node.sh — provision ONE node, from inside that node.
#
# Runs on the agent, not on the control host (node-create.sh stages it).
#
#   project-node.sh --check   [--project P] [--harness hermes] [--repo URL] [--ref main]
#   project-node.sh --apply   [same args]
#   project-node.sh --check   [same args] --layers 00,10,20,30,40
#   project-node.sh --check   [same args] --kinds go,node
#
# Layers: 00 preflight, 10 base, 20 harness, 30 bus, 40 repo, 90 verify (verify is the
# control host's job; here we only prove the node-side plumbing exists).
#
# --kinds <csv> (or NODE_KINDS) declares which project kinds layer 10 grades the
# toolchain for: go, rust, node, python, generic. Without it layer 10 derives the
# kinds from the workspace ($HOME/repo) when a clone is already present, and only
# falls back to the fixed base set when there is no evidence at all — naming that
# fallback on the row (CF-218). An unknown kind is a named FAIL before any layer runs.
#
# --layers <list> runs only the named check layers: a comma-separated subset of
# 00,10,20,30,40 (a single value is a list of one). It exists for fixtures that assert
# one layer's rows, where a full node run costs several times the CPU of the row under
# test (PERF-013). A scoped run is NOT a node certification: it prints one SCOPE line,
# prints `SKIP layer NN (out of scope)` where each skipped layer would have run, and
# never writes $HOME/.node/node.json — not even under --apply with every in-scope layer
# green. A scoped run that excludes 00 does not resolve the disk floor, because nothing
# consumes it and a fixture installs nothing. Unscoped runs are unchanged: same rows,
# same order, same manifest behaviour, same exit codes.
set -uo pipefail
# Resolve HERE with shell builtins only: this script must still report real FAIL rows
# when PATH is broken (that is exactly what tests/selftest.sh section 2 exercises).
HERE="${0%/*}"
case "$HERE" in "$0") HERE=. ;; esac
HERE="$(cd "$HERE" 2>/dev/null && pwd)" || HERE=.
FAILED=${FAILED:-0}
if [ ! -f "$HERE/lib.sh" ] || [ ! -r "$HERE/lib.sh" ]; then
  printf '  FAIL  lib.sh — missing or unreadable: %s\n' "$HERE/lib.sh" >&2
  exit 1
fi
if ! . "$HERE/lib.sh"; then
  printf '  FAIL  lib.sh — could not source: %s\n' "$HERE/lib.sh" >&2
  exit 1
fi

PROJECT="${NODE_PROJECT:-}"
HARNESS="${NODE_HARNESS:-hermes}"
REPO=""
REF="${NODE_REF:-main}"
PORT="${NODE_GATEWAY_PORT:-10800}"
ROLE="${NODE_ROLE:-worker}"
FLOOR_CLI=""
MODE=""
LAYERS=""
SCOPED=0
KINDS="${NODE_KINDS:-}"
KINDS_SET=0
[ -n "${NODE_KINDS+set}" ] && KINDS_SET=1
# What layer 20 MEASURED about the harness (CF-006). Layer 90 carries these into node.json, so the
# manifest records the build that is on the node instead of the pin a config asked for. A value the
# adapter never printed stays EMPTY here and the manifest says why it is empty — an invented version
# is worse than a named absence, and a null without a reason is junk.
HARNESS_VERSION=""
HARNESS_VERSION_ROW=""
HARNESS_BINARY=""
STATE="$HOME/.node"
# The checkout this script works, cloned by layer 40. Layer 10 reads it BEFORE the
# clone for kind evidence (CF-218), so it is resolved here, once, for both layers.
RP="$HOME/repo"

usage_line() {
  echo "usage: $0 --check|--apply [--project P] [--harness H] [--repo URL] [--ref R] [--role worker|builder|full] [--disk-floor GIB] [--layers 00,10,20,30,40] [--kinds go,rust,node,python,generic]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --apply) MODE=apply; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --disk-floor) FLOOR_CLI="$2"; shift 2 ;;
    --layers)
      SCOPED=1
      if [ $# -lt 2 ]; then usage_line; exit 2; fi
      LAYERS="$2"; shift 2 ;;
    --kinds)
      KINDS_SET=1
      if [ $# -lt 2 ]; then usage_line; exit 2; fi
      KINDS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$MODE" ] && { usage_line; exit 2; }
[ -z "$PROJECT" ] && { echo "--project is required (a node belongs to exactly one project)"; exit 2; }

# --layers is validated before any layer runs: an empty list, an unknown element or a
# stray comma must never reach layer 00 with half a scope applied.
if [ "$SCOPED" -eq 1 ]; then
  case "$LAYERS" in
    ''|*[!0-9,]*|,*|*,|*,,*) usage_line; exit 2 ;;
  esac
  scoped_seen=""
  for lyr in ${LAYERS//,/ }; do
    case "$lyr" in
      00|10|20|30|40) ;;
      *) usage_line; exit 2 ;;
    esac
    case ",$scoped_seen," in *",$lyr,"*) ;; *) scoped_seen="${scoped_seen:+$scoped_seen,}$lyr" ;; esac
  done
  # Canonical order whatever order the caller wrote, so the SCOPE line and the SKIP rows
  # do not depend on how the list was spelled.
  LAYERS=""
  for lyr in 00 10 20 30 40; do
    case ",$scoped_seen," in *",$lyr,"*) LAYERS="${LAYERS:+$LAYERS,}$lyr" ;; esac
  done
fi

# --kinds (or NODE_KINDS) is validated the same way and before any layer runs: an
# empty list or an unknown element is a NAMED FAIL and a non-zero exit, because a
# typo that silently fell through to the fixed base set is exactly the bug CF-218
# exists to fix — a node would print PASS while grading nothing the repo needs.
if [ "$KINDS_SET" -eq 1 ]; then
  if [ -z "$KINDS" ]; then
    bad "kinds" "empty kind list — expected a subset of go,rust,node,python,generic"
    say "NODE: FAIL ($FAILED)"
    exit 1
  fi
  case "$KINDS" in
    ,*|*,|*,,*)
      bad "kinds" "empty element in '$KINDS' — expected a subset of go,rust,node,python,generic"
      say "NODE: FAIL ($FAILED)"
      exit 1 ;;
  esac
  kinds_seen=""
  for knd in ${KINDS//,/ }; do
    case "$knd" in
      go|rust|node|python|generic) ;;
      *)
        bad "kinds" "unknown kind '$knd' — expected a subset of go,rust,node,python,generic"
        say "NODE: FAIL ($FAILED)"
        exit 1 ;;
    esac
    case ",$kinds_seen," in *",$knd,"*) ;; *) kinds_seen="${kinds_seen:+$kinds_seen,}$knd" ;; esac
  done
  KINDS=""
  for knd in go rust node python generic; do
    case ",$kinds_seen," in *",$knd,"*) KINDS="${KINDS:+$KINDS,}$knd" ;; esac
  done
fi

in_scope() {  # $1 = layer id -> true when that layer runs (always true when unscoped)
  [ "$SCOPED" -eq 0 ] && return 0
  case ",$LAYERS," in *",$1,"*) return 0 ;; esac
  return 1
}

# Disk floor is operator policy, resolved by one ordered chain:
#   --disk-floor > NODE_DISK_FLOOR > config [disk] > role default.
# A malformed value fails closed here, before any install or clone. A host without
# python3 cannot read config, so it falls back to the built-in role default and says
# so — the missing-toolchain case still reaches the [10] base layer and fails loudly.
case "$ROLE" in
  worker) FLOOR_BUILTIN=5 ;;
  builder) FLOOR_BUILTIN=10 ;;
  full) FLOOR_BUILTIN=20 ;;
  *) echo "unknown role: $ROLE (expected worker|builder|full)" >&2; exit 2 ;;
esac
if ! in_scope 00; then
  # Preflight is out of scope, so nothing measures the floor and nothing consumes it.
  # The fail-closed floor path keeps its coverage on unscoped runs (selftest section 13).
  FLOOR_GIB=""
  FLOOR_SRC=""
elif ! command -v python3 >/dev/null 2>&1; then
  FLOOR_GIB="$FLOOR_BUILTIN"
  FLOOR_SRC="role-default(no-python3)"
  echo "  WARN  disk_floor — python3 absent, using built-in ${ROLE} default ${FLOOR_GIB} GiB"
else
  if [ ! -r "$HERE/disk_floor.py" ]; then
    bad "disk_floor" "resolver missing or unreadable: $HERE/disk_floor.py"
    say "NODE: FAIL ($FAILED)"
    exit 1
  fi
  floor_args=(resolve --role "$ROLE")
  [ -n "$FLOOR_CLI" ] && floor_args+=(--cli "$FLOOR_CLI")
  if ! FLOOR="$(python3 "$HERE/disk_floor.py" "${floor_args[@]}" --explain 2>&1)"; then
    bad "disk_floor" "$FLOOR"
    say "NODE: FAIL ($FAILED)"
    exit 1
  fi
  FLOOR_GIB="$(printf '%s' "$FLOOR" | python3 -c 'import json,sys; print(json.load(sys.stdin)["floor_gib"])' 2>/dev/null || true)"
  FLOOR_SRC="$(printf '%s' "$FLOOR" | python3 -c 'import json,sys; print(json.load(sys.stdin)["source"])' 2>/dev/null || true)"
  if [ -z "${FLOOR_GIB:-}" ]; then
    bad "disk_floor" "resolver returned no number: $FLOOR"
    say "NODE: FAIL ($FAILED)"
    exit 1
  fi
  ok "disk_floor" "${FLOOR_GIB} GiB from ${FLOOR_SRC}"
fi

mkdir -p "$STATE"
say "node provisioning — project=$PROJECT harness=$HARNESS host=$(hostname)"
# One line, before layer 00, so no reader mistakes a fixture run for a certification.
[ "$SCOPED" -eq 1 ] && say "SCOPE: layers $LAYERS (fixture mode — not a node certification)"

# ---------------------------------------------------------------- 00 preflight
if in_scope 00; then
  say "[00] preflight"
  arch=$(uname -m); ok "arch" "$arch ($(uname -sr))"
  ok "role" "$ROLE (floor ${FLOOR_GIB} GiB from ${FLOOR_SRC})"
  # Check stays read-only and keeps measuring; apply reclaims before a final verdict.
  if [ "$MODE" = check ]; then
    require_disk "$HOME" "$FLOOR_GIB" || say "  note reclaim — --apply would reap build caches, job dirs and stale clones first (check mode never mutates)"
  else
    free=$(free_gb "$HOME")
    if awk -v f="$free" -v m="$FLOOR_GIB" 'BEGIN{exit !(f>=m)}'; then
      ok "disk" "${free} GB free (floor ${FLOOR_GIB} GB)"
    else
      say "  note reclaim — below floor; reaping build caches, job dirs and stale clones before refusing"
      if [ ! -r "$HERE/reclaim_disk.py" ]; then
        bad "disk_floor" "reclaimer missing or unreadable: $HERE/reclaim_disk.py"
        say "NODE: FAIL ($FAILED)"
        exit 1
      fi
      # Rehearse, then reap (CF-290): the projected set is printed and recorded before a
      # single byte is deleted, so a refusal is judged against a named plan. Build caches
      # are TTL-gated by newest subtree mtime, so a cache in active use is not "stale".
      if ! REHEARSAL="$(python3 "$HERE/reclaim_disk.py" run --root "$HOME" --dry-run --json 2>&1)"; then
        bad "disk_floor" "reclaim rehearsal failed: $REHEARSAL"
        say "NODE: FAIL ($FAILED)"
        exit 1
      fi
      say "${REHEARSAL%$'\n'*}"
      projected=$(printf '%s\n' "${REHEARSAL##*$'\n'}" | python3 -c 'import json,sys; d=json.load(sys.stdin); rows=["%s (%s)"%(e["name"],e["reason"]) for e in d["entries"] if e["action"]=="reaped"]; print(", ".join(rows) if rows else "none")' 2>/dev/null) || projected=unreadable
      say "  note reclaim — rehearsal projects: ${projected} (nothing deleted yet)"
      if ! RECLAIM="$(python3 "$HERE/reclaim_disk.py" run --root "$HOME" --json 2>&1)"; then
        bad "disk_floor" "reclaim failed: $RECLAIM"
        say "NODE: FAIL ($FAILED)"
        exit 1
      fi
      say "${RECLAIM%$'\n'*}"
      # The deleted set is part of this run's own output: a later reader can name what
      # was removed without re-running the reaper against a tree that no longer exists.
      removed=$(printf '%s\n' "${RECLAIM##*$'\n'}" | python3 -c 'import json,sys; d=json.load(sys.stdin); rows=["%s (%s)"%(e["name"],e["reason"]) for e in d["entries"] if e["action"]=="reaped"]; print(", ".join(rows) if rows else "none")' 2>/dev/null) || removed=unreadable
      say "  note reclaim — removed: ${removed}"
      freed=$(printf '%s\n' "${RECLAIM##*$'\n'}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["reclaimed_mib"])' 2>/dev/null) || {
        bad "disk_floor" "reclaimer returned no reclaimed size"
        say "NODE: FAIL ($FAILED)"
        exit 1
      }
      free=$(free_gb "$HOME")
      if awk -v f="$free" -v m="$FLOOR_GIB" 'BEGIN{exit !(f>=m)}'; then
        ok "disk" "${free} GB free after reclaim (freed ${freed} MiB; floor ${FLOOR_GIB} GB)"
      else
        bad "disk" "${free} GB free after reclaim < floor ${FLOOR_GIB} GB at $HOME (freed ${freed} MiB)"
        say "NODE: FAIL (disk admission)"
        exit 1
      fi
    fi
  fi
  mem=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)
  [ "${mem:-0}" -ge 1024 ] && ok "mem" "${mem} MB" || bad "mem" "${mem} MB < 1024"
  # Footprint, not just free space: the floor is admission policy, and the number that
  # decides admission is what THIS node will occupy. Bounded component set only (repo,
  # toolchains, harness home, node state, declared module cache), so the row stays cheap
  # on a host with a large $HOME. A measured footprint above the floor refuses admission
  # here rather than at 98 % disk (CF-003, specs/NODE.md "Disk floor").
  if command -v python3 >/dev/null 2>&1 && [ -r "$HERE/node_hygiene.py" ]; then
    fp_args=(footprint --root "$HOME" --floor-gib "$FLOOR_GIB" --floor-source "${FLOOR_SRC:-role-default}")
    [ -n "${NODE_GOMODCACHE:-}" ] && fp_args+=(--modcache "$NODE_GOMODCACHE")
    fp_out="$(python3 "$HERE/node_hygiene.py" "${fp_args[@]}" 2>&1)"; fp_rc=$?
    printf '%s\n' "$fp_out"
    fp_fails="$(printf '%s\n' "$fp_out" | grep -c '^  FAIL')" || true
    FAILED=$((FAILED + fp_fails))
    if [ "$fp_rc" -ne 0 ] && [ "$fp_fails" -eq 0 ]; then
      bad "footprint" "measurement exited $fp_rc without a FAIL row"
    fi
  else
    warn "footprint" "node_hygiene.py or python3 unavailable — component sizes are unmeasured"
  fi
  CRIER="${CRIER_URL:-}"
  if [ -z "$CRIER" ]; then
    bad "crier_url" "CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)"
  else
    ok "crier_url" "$CRIER"
    # Method per endpoint, for two measured reasons (cf-node, 2026-11-05):
    #   * pypi's /simple/ index is ~48 MB — a GET under an 8 s budget returns 000 on a healthy
    #     link (44 MB received), while HEAD answers 200 in 0.29 s;
    #   * crier /health is a GET-only handler — a HEAD there answers 405, which is not a fault.
    for u in "$CRIER/health" https://pypi.org/simple/; do
      if [ "$u" = "https://pypi.org/simple/" ]; then
        c=$(curl -sI -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null) || c=000
      else
        c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null) || c=000
      fi
      [ "$c" = 200 ] && ok "reach:$u" "200" || bad "reach:$u" "-> $c"
    done
  fi
else
  say "  SKIP  layer 00 (out of scope)"
fi

# ---------------------------------------------------------------- 10 base
# CF-218: this layer used to grade a FIXED set (python3+venv, git, curl, tar, sha256sum)
# with jq/rg/node as WARN-only, so a node could print PASS while unable to build the
# largest class of repo in the fleet: a census of 61 distinct repo origins measured go 27,
# node 22, python 16, rust 5, and cf-node measured 'go MISSING', 'rg MISSING' against a
# PASS. The graded set is now derived from the project KIND.
#
# Layer 10 runs BEFORE layer 40 clones, so on a fresh node there is no workspace to
# inspect. Evidence, first hit wins, and the `kinds` row names which one was used:
#   a) declared  — --kinds / NODE_KINDS (validated before any layer ran, above)
#   b) workspace — $RP already holds the clone: go.mod, Cargo.toml, package.json,
#                  pyproject.toml | setup.py
#   c) generic   — no evidence => the fixed base set, and the row SAYS it is the
#                  fallback; a silent fall back to it is the bug this row exists to fix
# Graded per kind: go (binary + version + the node's own GOPROXY resolving a pinned
# module), rust (cargo --version), node (node --version), python (python3 + venv).
KIND_EV_KINDS=""
KIND_EV_MARKERS=""
GO_PROBE_MODULE="rsc.io/quote"   # tiny, pinned, unchanged since 2019
GO_PROBE_VERSION="v1.5.2"

has_kind() {  # $1 = kind -> true when it is in the resolved set
  case ",$KINDS," in *",$1,"*) return 0 ;; esac
  return 1
}

kind_evidence() {  # sets KIND_EV_KINDS / KIND_EV_MARKERS from $RP; true when it found one
  local kinds="" markers="" f k
  for f in go.mod Cargo.toml package.json pyproject.toml setup.py; do
    [ -f "$RP/$f" ] || continue
    markers="${markers:+$markers,}$f"
    case "$f" in
      go.mod) k=go ;; Cargo.toml) k=rust ;; package.json) k=node ;; *) k=python ;;
    esac
    case ",$kinds," in *",$k,"*) ;; *) kinds="${kinds:+$kinds,}$k" ;; esac
  done
  KIND_EV_KINDS="$kinds"
  KIND_EV_MARKERS="$markers"
  [ -n "$kinds" ]
}

row_tail() {  # $1 text -> its last non-empty line, capped: one row stays one line
  printf '%s\n' "$1" | awk 'NF { last=$0 } END { print last }' | cut -c1-240
}

harness_measurement() {  # harness_measurement <adapter-log> <version|binary> [value|path]
  # The adapter's own `  PASS  <row> — <value>` line is the ONLY measurement of the harness in this
  # system (CF-006). Read it back from the log layer 20 captured instead of parsing `--version`
  # again here: a second parser is a second answer to "which build is on this node", and the two
  # disagree the first time an adapter changes how it reads a version.
  #
  # `path` mode answers "where does the binary live": adapters annotate the binary row in different
  # ways (`<path> (installed by this adapter)`, `<path> runs`, a bare `<path>`), so the first token
  # that is an absolute path is the path and the annotation is not part of it.
  local log="$1" row="${2:-}" what="${3:-value}"
  [ -r "$log" ] && [ -n "$row" ] || return 0
  awk -v r="$row" -v what="$what" '
    index($0, "  PASS  " r " — ") == 1 {
      sub("^  PASS  " r " — ", "")
      if ($0 == "") next
      if (what == "path") {
        n = split($0, f, " ")
        for (i = 1; i <= n; i++) if (substr(f[i], 1, 1) == "/") { print f[i]; exit }
        next
      }
      print; exit
    }' "$log" 2>/dev/null
}

go_proxy_row() {  # $1 = go binary -> one row: the node's own proxy resolves a pinned module
  local gb="$1" proxy dir rc out tmo=""
  proxy="$("$gb" env GOPROXY 2>/dev/null | head -1)"
  [ -n "$proxy" ] || proxy="${GOPROXY:-unset}"
  have timeout >/dev/null 2>&1 && tmo="timeout"
  dir="$(mktemp -d)" || { bad "go:proxy" "$GO_PROBE_MODULE@$GO_PROBE_VERSION — no temp dir to probe in"; return 0; }
  # Cold module cache inside the temp dir: a warm $GOPATH answers listing and download
  # from cache/download, which would prove the cache and not the proxy. GOSUMDB=off
  # because the checksum database is a second network, not the proxy under test;
  # GOTOOLCHAIN=local so the probe never downloads a toolchain; the whole probe is
  # bounded (30 s) and never runs `go get`.
  ( cd "$dir" && "$gb" mod init cfproxy >/dev/null 2>&1 \
    && GOPROXY="$proxy" GOMODCACHE="$dir/gomod" GOTOOLCHAIN=local GOFLAGS= GOSUMDB=off \
       ${tmo:+$tmo 30} "$gb" mod download "$GO_PROBE_MODULE@$GO_PROBE_VERSION" ) >"$dir/probe.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "go:proxy" "$GO_PROBE_MODULE@$GO_PROBE_VERSION resolved via $proxy"
  else
    out="$(row_tail "$(cat "$dir/probe.log" 2>/dev/null)")"
    bad "go:proxy" "$GO_PROBE_MODULE@$GO_PROBE_VERSION via $proxy: ${out:-exit $rc with no output}"
  fi
  chmod -R u+w "$dir" 2>/dev/null || true
  rm -rf "$dir"
  return 0
}

if in_scope 10; then
  say "[10] base"
  for t in python3 git curl tar sha256sum; do
    p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || bad "tool:$t" "missing"
  done
  python3 -c 'import venv' 2>/dev/null && ok "python:venv" "importable" || bad "python:venv" "venv missing — no user-space installs possible"

  # Which kinds this layer grades, and which evidence said so (CF-218).
  if [ "$KINDS_SET" -eq 1 ]; then
    KIND_SRC="declared via --kinds/NODE_KINDS"
  elif kind_evidence; then
    KINDS="$KIND_EV_KINDS"
    KIND_SRC="derived from workspace $RP (markers: $KIND_EV_MARKERS)"
  else
    KINDS="generic"
    KIND_SRC="generic fallback — no --kinds/NODE_KINDS and no kind marker in $RP"
  fi
  if [ "$KINDS" = generic ]; then
    warn "kinds" "$KIND_SRC — grading the fixed base set only, so a Go/Rust/Node repo would go ungraded"
  else
    ok "kinds" "$KINDS ($KIND_SRC)"
  fi
  # The row names its own census command: run this layer on each node and the kind set
  # it prints (plus the markers above) is the census. CF-218 measured the fleet counts.
  note "census: bash scripts/project-node.sh --check --project <p> --layers 10 grades one node — markers go.mod→go, Cargo.toml→rust, package.json→node, pyproject.toml|setup.py→python; CF-218 counted 61 distinct fleet repo origins: go 27, node 22, python 16, rust 5"

  # Optional helpers stay WARN-only in every mode: their absence never fails a node.
  for t in jq rg; do
    p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (optional — some repos' tests use them)"
  done

  if has_kind node; then
    # Apply provisions the pinned runtime, the same way the go branch installs its pin: a
    # kind-node repo whose tests shell out to `node` cannot run on a fresh agent, which is
    # exactly how a Go repo reported 11 failing tests with `exec: node: not found` (CF-003).
    # Check stays read-only and grades what is already there.
    node_root="${NODE_INSTALL_ROOT:-$HOME/node-toolchain}"
    if [ "$MODE" = apply ]; then
      if ! node_install_log="$(mktemp)"; then
        bad "tool:node" "cannot create installer log"
      elif [ ! -x "$HERE/install-node.sh" ]; then
        bad "tool:node" "installer missing or not executable: $HERE/install-node.sh"
        rm -f "$node_install_log"
      else
        "$HERE/install-node.sh" --apply >"$node_install_log" 2>&1
        node_install_rc=$?
        cat "$node_install_log"
        node_install_fails="$(grep -c '^  FAIL' "$node_install_log")" || true
        FAILED=$((FAILED + node_install_fails))
        if [ "$node_install_rc" -ne 0 ] && [ "$node_install_fails" -eq 0 ]; then
          bad "tool:node" "installer exited $node_install_rc without a FAIL row"
        fi
        rm -f "$node_install_log"
      fi
    fi
    # The owned pin wins over PATH: a node must run the runtime this ladder provisioned,
    # not whatever an ambient image happens to expose.
    if [ -x "$node_root/current/bin/node" ]; then
      p="$node_root/current/bin/node"
    else
      p=$(have node)
    fi
    if [ -z "$p" ]; then
      bad "tool:node" "missing — kind node needs a Node runtime (a package.json repo cannot install or test here)"
    else
      nv="$("$p" --version 2>&1)"; nrc=$?
      nv="$(row_tail "$nv")"
      if [ "$nrc" -eq 0 ] && [ -n "$nv" ]; then
        ok "tool:node" "$p ($nv)"
      else
        bad "tool:node" "$p — 'node --version' failed (exit $nrc): ${nv:-no output}"
      fi
    fi
  elif has_kind generic; then
    # The pre-CF-218 shape, kept only where the layer cannot know a node is needed.
    p=$(have node); [ -n "$p" ] && ok "tool:node" "$p" || warn "tool:node" "missing (some repos' tests need node)"
  fi

  if has_kind rust; then
    p=$(have cargo)
    if [ -z "$p" ]; then
      bad "tool:cargo" "missing — kind rust needs a Cargo toolchain (a Cargo.toml repo cannot build here)"
    else
      cv="$("$p" --version 2>&1)"; crc=$?
      cv="$(row_tail "$cv")"
      if [ "$crc" -eq 0 ] && [ -n "$cv" ]; then
        ok "tool:cargo" "$p ($cv)"
      else
        bad "tool:cargo" "$p — 'cargo --version' failed (exit $crc): ${cv:-no output}"
      fi
    fi
  fi

  if has_kind go; then
    # A check remains read-only and grades the binary already present. Apply is the
    # provisioning path: install the owned pin before grading it, and fold every
    # installer FAIL row into this process's summary just like a harness adapter.
    if [ "$MODE" = apply ]; then
      if ! go_install_log="$(mktemp)"; then
        bad "tool:go" "cannot create installer log"
      elif [ ! -x "$HERE/install-go.sh" ]; then
        bad "tool:go" "installer missing or not executable: $HERE/install-go.sh"
        rm -f "$go_install_log"
      else
        "$HERE/install-go.sh" --apply >"$go_install_log" 2>&1
        go_install_rc=$?
        cat "$go_install_log"
        go_install_fails="$(grep -c '^  FAIL' "$go_install_log")" || true
        FAILED=$((FAILED + go_install_fails))
        if [ "$go_install_rc" -ne 0 ] && [ "$go_install_fails" -eq 0 ]; then
          bad "tool:go" "installer exited $go_install_rc without a FAIL row"
        fi
        rm -f "$go_install_log"
      fi
    fi
    go_root="${GO_INSTALL_ROOT:-$HOME/go-toolchain}"
    if [ -x "$go_root/current/bin/go" ]; then
      gb="$go_root/current/bin/go"
    else
      gb=$(have go)
    fi
    if [ -z "$gb" ]; then
      bad "tool:go" "missing — kind go needs a Go toolchain on PATH (go is the largest repo class in the fleet: 27 of 61 origins)"
    else
      gv="$("$gb" version 2>&1)"; grc=$?
      gv="$(row_tail "$gv")"
      if [ "$grc" -eq 0 ] && [ -n "$gv" ]; then
        ok "tool:go" "$gb ($gv)"
        go_proxy_row "$gb"
        # A private GOMODCACHE costs every node the same 656 MB re-download (CF-003). When a
        # shared cache is declared, prove it is sealed and read-only; when it is not, say so
        # instead of leaving the absence unexplained — the node keeps a private copy.
        if [ -n "${NODE_GOMODCACHE:-}" ]; then
          if [ ! -r "$HERE/gomodcache.py" ]; then
            bad "go:modcache" "declared $NODE_GOMODCACHE but $HERE/gomodcache.py is missing"
          else
            mc_out="$(python3 "$HERE/gomodcache.py" check --dir "$NODE_GOMODCACHE" 2>&1)"; mc_rc=$?
            printf '%s\n' "$mc_out"
            mc_fails="$(printf '%s\n' "$mc_out" | grep -c '^  FAIL')" || true
            FAILED=$((FAILED + mc_fails))
            if [ "$mc_rc" -ne 0 ] && [ "$mc_fails" -eq 0 ]; then
              bad "go:modcache" "check exited $mc_rc without a FAIL row"
            fi
          fi
        else
          warn "go:modcache" "not declared — this node keeps a private module cache (~656 MB per node); set NODE_GOMODCACHE to a sealed shared cache"
        fi
      else
        bad "tool:go" "$gb — 'go version' failed (exit $grc): ${gv:-no output}"
      fi
    fi
  fi
else
  say "  SKIP  layer 10 (out of scope)"
fi

# ---------------------------------------------------------------- 20 harness
if in_scope 20; then
  say "[20] harness"
  # CF-150: this layer asks the adapter to start a PUBLIC bind, and the adapter refuses that
  # bind unless ~/.hermes/config.yaml parses to a non-empty dashboard.basic_auth
  # (install-hermes.sh:check_public_bind_auth; the refusal row is emitted at the gate). No
  # stage in the create path wrote that block, so the documented path could print every other
  # row and still end NODE: FAIL. Stage it HERE, before the adapter runs, through the one
  # producer that knows the block's shape (scripts/node_gateway_auth.py, staged by
  # node-create.sh): the password is generated on the node, stored in a mode-600 file, and
  # never printed, never passed in argv.
  if [ "$HARNESS" = hermes ]; then
    gw_config="$HOME/.hermes/config.yaml"
    gw_pass="$STATE/auth/gateway.pass"
    if [ "$MODE" = apply ]; then
      if [ ! -r "$HERE/node_gateway_auth.py" ]; then
        bad "gateway_auth" "stager missing: $HERE/node_gateway_auth.py — nothing can write dashboard.basic_auth, so the gateway gate will refuse the public bind"
      else
        gw_dir="${gw_pass%/*}"
        mkdir -p "$gw_dir" 2>/dev/null && chmod 700 "$gw_dir" 2>/dev/null
        # An existing basic_auth block is left untouched (second run changes nothing); a
        # dashboard block that is NOT basic_auth is refused by the producer, not overwritten.
        if gw_out=$(python3 "$HERE/node_gateway_auth.py" "$gw_config" "$gw_pass" 2>&1); then
          gw_mode=$(stat -c '%a' "$gw_pass" 2>/dev/null || true)
          if [ "$gw_mode" = 600 ]; then
            ok "gateway_auth" "dashboard.basic_auth present in $gw_config; password in $gw_pass (mode $gw_mode, value not printed)"
          else
            bad "gateway_auth" "$gw_pass mode ${gw_mode:-unreadable} — a gateway password file must be mode 600"
          fi
        else
          gw_rc=$?
          bad "gateway_auth" "could not stage dashboard.basic_auth in $gw_config (exit $gw_rc): $(row_tail "$gw_out")"
        fi
      fi
    else
      # --check is read-only: no secret is generated and nothing is written. The adapter's
      # parser stays the authority; this row only says whether --apply has work to do, and an
      # absent block is a FAIL because the consequence is a refused gateway. Read with shell
      # builtins only — this layer still runs under section 2's empty PATH.
      gw_present=0 gw_block=0
      if [ -r "$gw_config" ]; then
        while IFS= read -r gw_line || [ -n "$gw_line" ]; do
          case "$gw_line" in
            ''|'#'*) : ;;
            "dashboard:"*) gw_block=1 ;;
            [[:space:]]*)
              if [ "$gw_block" = 1 ] && [[ "$gw_line" =~ ^[[:space:]]+basic_auth: ]]; then
                gw_present=1
              fi
              ;;
            *) gw_block=0 ;;
          esac
        done < "$gw_config"
      fi
      if [ "$gw_present" = 1 ]; then
        ok "gateway_auth" "dashboard.basic_auth present in $gw_config (presence only — the adapter's gate is the authority)"
      else
        bad "gateway_auth" "dashboard.basic_auth absent from $gw_config — the gateway gate will refuse a public bind; --apply stages the block (CF-150)"
      fi
    fi
  fi
  inst="$HERE/harness/install-$HARNESS.sh"
  if [ ! -x "$inst" ]; then
    bad "harness:$HARNESS" "no adapter at scripts/harness/install-$HARNESS.sh"
  else
    # CF-055: the adapter is a child process, so its own FAILED counter (lib.sh)
    # never reaches ours. Capture its output, echo it through unchanged, and add
    # the `  FAIL` rows it printed to the parent counter so the NODE: FAIL (n)
    # summary equals every FAIL row the run printed.
    adapter_log="$(mktemp)"
    if [ "$MODE" = apply ]; then
      NODE_GATEWAY_PORT="$PORT" "$inst" --apply >"$adapter_log" 2>&1
    else
      NODE_GATEWAY_PORT="$PORT" "$inst" --check >"$adapter_log" 2>&1
    fi
    rc=$?
    adapter_fails="$(grep -c '^  FAIL' "$adapter_log")" || true
    cat "$adapter_log"
    # CF-066: a crashing or otherwise silent adapter must fail the node even when it printed no
    # FAIL row. Use bad() for the parent-side row so the summary counts exactly the rows printed.
    if [ "$rc" -ne 0 ] && [ "$adapter_fails" -eq 0 ]; then
      bad "harness:$HARNESS" "installer exited $rc"
    fi
    # CF-006: keep the adapter's measurement before the log is removed. `version` is the row that
    # says which build is on the node; `binary` says where it is. An adapter that measured neither
    # leaves these empty and node.json records the absence and its reason instead of the pin.
    HARNESS_VERSION_ROW="$(harness_measurement "$adapter_log" version)"
    # A trailing `(pin 0.166.0)` is adapter bookkeeping about the row, not part of the version, so
    # it is stripped from the VALUE and kept in `version_row`. A value with no annotation is
    # carried unchanged.
    HARNESS_VERSION="${HARNESS_VERSION_ROW%% (*}"
    HARNESS_BINARY="$(harness_measurement "$adapter_log" binary path)"
    rm -f "$adapter_log"
    FAILED=$((FAILED + adapter_fails))
  fi
else
  say "  SKIP  layer 20 (out of scope)"
fi

# ---------------------------------------------------------------- 30 bus
if in_scope 30; then
  say "[30] bus"
  if [ -f "$STATE/crier.json" ]; then
    ok "crier_identity" "$STATE/crier.json"
    m=$(stat -c '%a' "$STATE/crier.json"); [ "$m" = 600 ] && ok "crier_mode" "600" || bad "crier_mode" "$m (must be 600)"
  else
    bad "crier_identity" "absent — stage a bundle and re-run; a node without an identity is invisible"
  fi
else
  say "  SKIP  layer 30 (out of scope)"
fi

# ---------------------------------------------------------------- 40 repo
# Checkout freshness helpers (CF-244). The clone's git state is what the node
# actually works, and nothing measured it: a node one commit behind origin/main,
# or carrying a local edit that blocks its own fast-forward, printed PASS at
# every layer (measured on cf-node, 2026-11-05: HEAD 7f22d02 vs origin/main
# 04fc398, an earlier .gitignore edit having blocked the pull).
#
# Two rungs, same classification: the clone carries scripts/node_freshness.py
# when the repo is this one, so use it; otherwise a checkout of another project
# has no copy, and a node-side fallback measures the same four arms with the
# git CLI alone. Nothing here depends on the control host's scripts existing on
# the node.
freshness_measure() {  # $1 repo, $2 json out, $3 stderr out -> exit code
  local rp="$1" js="$2" er="$3"
  if [ -r "$rp/scripts/node_freshness.py" ]; then
    python3 "$rp/scripts/node_freshness.py" --workdir "$rp" --json >"$js" 2>"$er"
    return $?
  fi
  python3 - "$rp" >"$js" 2>"$er" <<'PY'
# Node-side fallback: the same four arms (branch, worktree, ancestor, sync),
# the same row texts and the same exit codes as scripts/node_freshness.py.
# It exists because the clone only carries the probe when the repo IS the
# probe's repo. Keep the two in step: tests/selftest.sh section 47 drives this
# path through project-node.sh --layers 40 with no probe in the clone.
import json, os, subprocess, sys

rp = sys.argv[1]
res = {"mode": "inline", "path": rp, "status": "FAIL", "reason": "", "exit_code": 1,
       "branch": "", "head": "", "origin_main": "", "comparison_ref": "",
       "ancestor": None, "behind": None, "dirty_files": [], "differing_files": [],
       "rows": []}


def run(*args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", LC_ALL="C")
    try:
        p = subprocess.run(["git", "-C", rp] + list(args), capture_output=True,
                           text=True, timeout=120, env=env, check=False)
    except Exception as exc:  # a probe never crashes the ladder
        return 255, "", str(exc)
    return p.returncode, p.stdout, p.stderr


def row(status, check, value):
    res["rows"].append({"status": status, "check": check, "value": value})


def finish(reason, status="FAIL", code=1):
    res["status"], res["reason"], res["exit_code"] = status, reason, code
    res["result"] = "PASS" if status == "PASS" else "FAIL (%s)" % reason
    print("node-freshness — workdir %s (inline: the clone carries no "
          "scripts/node_freshness.py)" % rp, file=sys.stderr)
    for r in res["rows"]:
        print("  %s  %s — %s" % (r["status"], r["check"], r["value"]), file=sys.stderr)
    print("RESULT: %s" % res["result"], file=sys.stderr)
    print(json.dumps(res, indent=1))
    raise SystemExit(code)


top = run("rev-parse", "--show-toplevel")
if top[0] != 0 or not os.path.isdir(rp):
    row("FAIL", "checkout", "%s is not a git checkout (%s) — no tree to measure"
        % (rp, (top[2].strip().splitlines() or ["no git"])[0][:160]))
    finish("no checkout at %s" % rp)
res["path"] = top[1].strip()

branch = run("rev-parse", "--abbrev-ref", "HEAD")
res["branch"] = branch[1].strip() if branch[0] == 0 else ""
head = run("rev-parse", "--verify", "HEAD")
res["head"] = head[1].strip() if head[0] == 0 else ""
status = run("status", "--porcelain")
if status[0] == 0:
    res["dirty_files"] = [l[3:].strip() for l in status[1].splitlines() if l.strip()]

failures = []
if res["branch"] and res["branch"] != "HEAD":
    row("PASS", "branch", "branch=%s" % res["branch"])
else:
    state = ("detached HEAD at " + res["head"][:12]) if res["head"] else "unborn HEAD (no commits)"
    row("FAIL", "branch", "%s — no attached branch to fast-forward" % state)
    failures.append(state)
if res["dirty_files"]:
    row("FAIL", "worktree", "%d uncommitted path(s): %s — a local edit on the node "
        "blocks its fast-forward; the fix belongs upstream"
        % (len(res["dirty_files"]), ", ".join(res["dirty_files"])))
    failures.append("%d uncommitted path(s)" % len(res["dirty_files"]))
else:
    row("PASS", "worktree", "0 uncommitted paths")

remotes = [r for r in run("remote")[1].split() if r]
if "origin" not in remotes:
    row("FAIL", "origin", "no 'origin' remote (remotes: %s) — cannot compare "
        "against origin/main" % (", ".join(remotes) or "none"))
    finish("; ".join(failures + ["no origin remote"]))

fetch_rc = run("fetch", "--quiet", "--no-tags", "origin")[0]
ref = ""
sha = run("rev-parse", "--verify", "--quiet", "origin/main")
if sha[0] == 0 and sha[1].strip():
    ref, res["origin_main"] = "origin/main", sha[1].strip()
else:
    cand = run("rev-parse", "--abbrev-ref", "--symbolic-full-name", "origin/HEAD")[1].strip()
    if cand.startswith("origin/") and "HEAD" not in cand:
        found = run("rev-parse", "--verify", "--quiet", cand)
        if found[0] == 0 and found[1].strip():
            ref, res["origin_main"] = cand, found[1].strip()
if not ref:
    row("FAIL", "origin", "no origin/main and no origin/HEAD — nothing to compare against")
    finish("; ".join(failures + ["no comparison ref"]))
res["comparison_ref"] = ref

anc = run("merge-base", "--is-ancestor", "HEAD", ref)[0]
if anc == 0:
    res["ancestor"] = True
    row("PASS", "ancestor", "HEAD %s is an ancestor of %s %s"
        % (res["head"][:12], ref, res["origin_main"][:12]))
elif anc == 1:
    res["ancestor"] = False
    row("FAIL", "ancestor", "HEAD %s is NOT an ancestor of %s %s — the checkout has diverged"
        % (res["head"][:12], ref, res["origin_main"][:12]))
    failures.append("diverged from %s" % ref)
else:
    row("FAIL", "ancestor", "ancestry of HEAD against %s could not be measured" % ref)
    failures.append("ancestry against %s unmeasurable" % ref)

behind = run("rev-list", "--count", "HEAD..%s" % ref)
if behind[0] == 0 and behind[1].strip().isdigit():
    res["behind"] = int(behind[1].strip())
    diff = run("diff", "--name-only", "HEAD", ref)
    if diff[0] == 0:
        res["differing_files"] = [d for d in diff[1].splitlines() if d.strip()]
if res["behind"] is None:
    row("FAIL", "sync", "lag against %s could not be counted" % ref)
    failures.append("lag against %s unmeasurable" % ref)
elif res["behind"] > 0:
    row("FAIL", "sync", "behind=%d (HEAD..%s %s): %d differing path(s) — %s"
        % (res["behind"], ref, res["origin_main"][:12], len(res["differing_files"]),
           ", ".join(res["differing_files"]) or "none"))
    failures.append("behind %d commit(s) vs %s" % (res["behind"], ref))
else:
    row("PASS", "sync", "behind=0 (HEAD..%s %s)" % (ref, res["origin_main"][:12]))
    if fetch_rc != 0:
        row("FAIL", "fetch", "git fetch origin failed (exit %d) — the comparison ref may be stale"
            % fetch_rc)
        failures.append("origin unreachable (lag counted from stale refs)")

if failures:
    finish("; ".join(failures))
row("PASS", "freshness", "branch=%s head=%s origin_main=%s ancestor=true behind=0"
    % (res["branch"], res["head"][:12], res["origin_main"][:12]))
finish("", "PASS", 0)
PY
}

# One TAB-separated line out of the freshness JSON, for the ladder's single row.
freshness_fields() {  # $1 json, $2 captured stderr
  python3 - "$1" "$2" <<'PY'
import json, sys

path, errpath = sys.argv[1], sys.argv[2]


def cap(items, limit=10):
    items = [str(i) for i in (items or [])]
    if not items:
        return "-"
    shown = ", ".join(items[:limit])
    if len(items) > limit:
        shown += " (+%d more)" % (len(items) - limit)
    return shown


try:
    d = json.load(open(path))
except Exception as exc:
    reason = "result unreadable (%s)" % exc
    try:
        lines = [l for l in open(errpath).read().splitlines() if l.strip()]
        if lines:
            reason += ": " + lines[-1][:200]
    except OSError:
        pass
    print("\t".join(["-"] * 8 + [reason]))
    raise SystemExit(0)

anc = d.get("ancestor")
print("\t".join([
    str(d.get("branch") or "-"),
    str(d.get("head") or "")[:12] or "-",
    str(d.get("origin_main") or "")[:12] or "-",
    "-" if d.get("behind") is None else str(d.get("behind")),
    "-" if anc is None else ("true" if anc else "false"),
    cap(d.get("dirty_files")),
    cap(d.get("differing_files")),
    str(d.get("result") or "-"),
    str(d.get("reason") or "-"),
]))
PY
}

freshness_record_ladder() {  # $1 json, $2 ladder verdict (PASS|WARN|FAIL)
  python3 - "$1" "$2" <<'PY'
import json, sys

try:
    d = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
d["ladder"] = sys.argv[2]
json.dump(d, open(sys.argv[1], "w"), indent=1)
PY
}

REPO_READY=0
KEY_BLOCKED=0
if in_scope 40; then
  say "[40] repo"
  # Per-repo credentials (CF-003). node-create.sh copies the key to $HOME/.node/keys and
  # runs deploy_key.py install there, which writes the mode-600 key plus an ssh_config
  # carrying `IdentitiesOnly yes`. Here the key is only USED, and only for this clone:
  # GIT_SSH_COMMAND is scoped to this process, so no global git identity changes and no
  # other repo on the node inherits the credential. A declared key that is unreadable or
  # group/world-readable blocks the clone instead of falling back to an ambient identity.
  if [ -n "${NODE_DEPLOY_KEY:-}" ]; then
    ssh_cfg="${NODE_SSH_CONFIG:-$(dirname "$NODE_DEPLOY_KEY")/ssh_config}"
    if [ ! -r "$NODE_DEPLOY_KEY" ]; then
      bad "repo_key" "$NODE_DEPLOY_KEY declared but unreadable — refusing to clone without the credential"
      KEY_BLOCKED=1
    else
      key_mode=$(stat -c '%a' "$NODE_DEPLOY_KEY" 2>/dev/null || echo '?')
      case "$key_mode" in
        600|400) ok "repo_key" "$NODE_DEPLOY_KEY mode $key_mode" ;;
        *) bad "repo_key" "$NODE_DEPLOY_KEY mode $key_mode — group/other can read it (chmod 600)"; KEY_BLOCKED=1 ;;
      esac
      if [ "$KEY_BLOCKED" -eq 0 ] && [ ! -r "$ssh_cfg" ]; then
        bad "repo_key" "$ssh_cfg absent — ssh has no identity for this repo (deploy_key.py install writes it)"
        KEY_BLOCKED=1
      fi
      if [ "$KEY_BLOCKED" -eq 0 ]; then
        export GIT_SSH_COMMAND="ssh -F $ssh_cfg"
        export GIT_TERMINAL_PROMPT=0
        ok "repo_key:ssh" "GIT_SSH_COMMAND='ssh -F $ssh_cfg' (this process only)"
      fi
    fi
  fi
  # $RP was resolved once at the top (layer 10 reads it for kind evidence before the
  # clone exists); the clone target is the same path layer 40 has always used.
  if [ -d "$RP/.git" ]; then
    ok "repo" "$RP @ $(git -C "$RP" rev-parse --short HEAD)"
    REPO_READY=1
  elif [ "$KEY_BLOCKED" -eq 1 ]; then
    bad "repo_clone" "not attempted — the declared deploy key is unusable (see repo_key)"
  else
    if [ "$MODE" = apply ] && [ -n "$REPO" ]; then
      say "  ..    cloning $REPO @ $REF"
      clone_log="$STATE/clone.log"
      if git clone --depth 1 --branch "$REF" "$REPO" "$RP" >"$clone_log" 2>&1; then
        ok "repo_clone" "$RP @ $(git -C "$RP" rev-parse --short HEAD)"
        REPO_READY=1
      else
        clone_error="$(tail -1 "$clone_log")"
        if git ls-remote --exit-code "$REPO" "refs/heads/$REF" "refs/tags/$REF" >/dev/null 2>&1; then
          bad "repo_clone" "${clone_error:-git clone failed} (clone failed after ref '$REF' resolved)"
        else
          remote_rc=$?
          if [ "$remote_rc" -eq 2 ]; then
            bad "repo_clone" "ref '$REF' was not found; pass --ref <branch-or-tag>"
          else
            bad "repo_clone" "${clone_error:-git clone failed} (repository access failed; private repos need a deploy key)"
          fi
        fi
      fi
      rm -f "$clone_log"
    else
      bad "repo" "$RP absent (pass --repo to clone)"
    fi
  fi

  # The clone inherited GIT_SSH_COMMAND; a node that fetches or pushes afterwards must use
  # the same identity, so pin it into THAT repository's config — never the global one.
  if [ "$REPO_READY" -eq 1 ] && [ -n "${GIT_SSH_COMMAND:-}" ]; then
    if git -C "$RP" config core.sshCommand "$GIT_SSH_COMMAND" 2>/dev/null; then
      ok "repo_key:config" "core.sshCommand set in $RP (this repository only)"
    else
      bad "repo_key:config" "cannot set core.sshCommand in $RP"
    fi
  fi

  # The clone is not the deliverable: the TREE the node will work is. Measure it
  # against origin/main here, after the clone/pull, and record the measurement.
  # Verdict policy (specs/NODE.md, "Failure semantics"): a DIRTY checkout is a
  # WARN — the node may be mid-task — while DRIFT (behind or diverged, so the
  # pull cannot fast-forward) is a FAIL, because the node would then work a tree
  # that no longer matches origin/main. Neither is repaired silently: the fix
  # belongs upstream, which is what the recorded paths are for.
  if [ "$REPO_READY" -eq 1 ]; then
    if [ "$SCOPED" -eq 1 ]; then
      fs_json="$(mktemp)"; fs_err="$(mktemp)"; fs_record=0
    else
      fs_json="$STATE/freshness.json"; fs_err="$(mktemp)"; fs_record=1
    fi
    freshness_measure "$RP" "$fs_json" "$fs_err"; frc=$?
    IFS=$'\t' read -r fs_branch fs_head fs_origin fs_behind fs_anc fs_dirty fs_diff fs_result fs_reason \
      < <(freshness_fields "$fs_json" "$fs_err")
    fs_row="branch=${fs_branch:-?} head=${fs_head:-?} origin_main=${fs_origin:-?} behind=${fs_behind:-?} ancestor=${fs_anc:-?}"
    case "${fs_dirty:--}" in -|'') ;; *) fs_row="$fs_row dirty=$fs_dirty" ;; esac
    case "${fs_diff:--}" in -|'') ;; *) fs_row="$fs_row differing=$fs_diff" ;; esac
    if [ "$frc" -eq 0 ]; then
      ok "freshness" "$fs_row"
      fs_ladder=PASS
    elif [ "$frc" -eq 1 ] && [ "${fs_behind:-}" = "0" ] && [ "${fs_anc:-}" = "true" ] \
      && [ -n "${fs_dirty:-}" ] && [ "${fs_dirty:--}" != "-" ]; then
      warn "freshness" "$fs_row — a local edit on the node is a finding: it blocks the node's fast-forward and the fix belongs upstream (not repaired here)"
      fs_ladder=WARN
    else
      bad "freshness" "$fs_row — ${fs_reason:-checkout freshness could not be measured}"
      fs_ladder=FAIL
    fi
    if [ -n "$fs_result" ] && [ "$fs_result" != "-" ]; then
      if [ "$fs_record" -eq 1 ]; then
        say "  ..    check verdict: $fs_result — recorded in $STATE/freshness.json"
      else
        say "  ..    check verdict: $fs_result (fixture mode: nothing recorded)"
      fi
    fi
    if [ "$fs_record" -eq 1 ]; then
      freshness_record_ladder "$fs_json" "$fs_ladder"
    else
      rm -f "$fs_json"
    fi
    rm -f "$fs_err"
  fi
else
  say "  SKIP  layer 40 (out of scope)"
fi


# ---------------------------------------------------------------- manifest
if [ "$SCOPED" -eq 1 ]; then
  # A scoped run is a fixture, not a node: it leaves no identity behind, even when
  # every in-scope layer is green. The summary line keeps its shape (tests match it).
  say "  SKIP  layer 90 (fixture mode: no manifest)"
else
  say "[90] manifest"
  if [ "$MODE" = apply ] && [ "$FAILED" -eq 0 ]; then
    # CF-289: node.json has TWO writers. node_identity.py MERGES identity keys (agent,
    # namespace, duckbrain, provisioned_by, provisioned_at) into it; this layer used to
    # REPLACE the document with its own schema, so a later --apply deleted every key it did
    # not know about and still exited 0 — the node was left with no `agent` for the bus.
    # One file, one shape: BOTH writers merge. Read what is there, set only the keys this
    # ladder owns, write the union back atomically at mode 600 (the same write discipline
    # node_identity.py uses). An existing document that is not a readable JSON object is a
    # named FAIL with the file left untouched — guessing (or silently rewriting) it is how
    # the identity keys were lost in the first place.
    if man_out=$(python3 - "$STATE/node.json" "$PROJECT" "$HARNESS" "$PORT" "$REPO" "$REF" "$(hostname)" "$STATE/freshness.json" \
      "$HARNESS_VERSION" "$HARNESS_VERSION_ROW" "$HARNESS_BINARY" "$MODE" <<'PY'
import json, os, sys, tempfile, time
path, project, harness, port, repo, ref, host, fresh_path = sys.argv[1:9]
# Names distinct from the freshness variables below: `measured` in this body is the checkout
# measurement, and reusing it silently replaced the harness version with a dict of git state.
hver, hver_row, hbin, hmode = (sys.argv[9:13] + ["", "", "", ""])[:4]
# The checkout's measured state (CF-244). It is carried into the manifest so a
# node can never claim an identity without saying which tree it holds: status is
# the CHECK's own verdict (a dirty checkout is a FAIL there, because a local edit
# on a node is a finding), `ladder` is how the provisioning ladder graded it
# (DIRTY == WARN at provision time, per specs/NODE.md), and the paths are the
# ones an operator has to take upstream.
freshness = {"status": "FAIL", "reason": "checkout freshness was not measured by layer 40"}
try:
    measured = json.load(open(fresh_path))
    freshness = {
        "status": measured.get("status") or "FAIL",
        "branch": measured.get("branch") or "",
        "head": measured.get("head") or "",
        "origin_main": measured.get("origin_main") or "",
        "behind": measured.get("behind"),
        "dirty_files": measured.get("dirty_files") or [],
        "differing_files": measured.get("differing_files") or [],
        "ladder": measured.get("ladder") or "",
        "reason": measured.get("reason") or "",
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
except (OSError, ValueError) as exc:
    freshness["reason"] = "checkout freshness was not measured by layer 40: %s" % exc
# The harness block (CF-006) records the build the ADAPTER measured, not the pin the config asked
# for: the name, the version that was read back and where that binary lives. When the adapter
# printed no version row the field is null and carries the reason — a manifest that silently
# omitted it would let verify-node.sh certify a harness nobody ever measured.
harness_obj = {"name": harness, "port": int(port),
               "adapter": "scripts/harness/install-%s.sh" % harness}
if hver:
    harness_obj["version"] = hver
    harness_obj["version_row"] = hver_row or hver
    harness_obj["version_source"] = "the adapter's own `PASS version` row in --%s" % (hmode or "check")
else:
    harness_obj["version"] = None
    harness_obj["version_reason"] = (
        "the adapter printed no `PASS version` row in --%s, so this node records no measured build"
        % (hmode or "check"))
if hbin:
    harness_obj["binary"] = hbin

# Read the document an identity writer may already have merged into. A file that exists but
# is not a JSON object is refused rather than overwritten: this ladder cannot tell which keys
# matter, so it must not pretend the old bytes were its own.
doc = {}
try:
    if os.path.exists(path):
        with open(path) as fh:
            doc = json.load(fh)
        if not isinstance(doc, dict):
            raise ValueError("top level is not an object")
except (OSError, ValueError) as exc:
    print("FAIL  manifest — %s is not a readable JSON object (%s); left untouched" % (path, exc),
          file=sys.stderr)
    raise SystemExit(1)

# Only the keys this ladder owns are set; everything else in the document survives. `bus` is a
# dict both writers touch, so it is merged one level down instead of replaced: an identity step
# that added a sibling key under `bus` keeps it, and the base is the bus the create path
# exported (CRIER_BASE, then CRIER_URL) rather than the documented placeholder.
bus = doc.get("bus")
if not isinstance(bus, dict):
    bus = {}
bus["base"] = (os.environ.get("CRIER_BASE") or os.environ.get("CRIER_URL")
               or "http://crier.example:8767")

doc["node_id"] = host
doc["project"] = project
doc["repo"] = {"origin": repo, "ref": ref,
               "path": "/home/" + os.environ.get("USER", "node") + "/repo"}
doc["harness"] = harness_obj
doc["bus"] = bus
doc["freshness"] = freshness
doc["created_by"] = "project-node.sh v1"
doc["created_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

# Atomic, mode 600, same shape as node_identity.py: a reader never sees half a manifest and a
# crash never leaves the node without the identity it just had.
directory = os.path.dirname(os.path.abspath(path)) or "."
os.makedirs(directory, exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=directory)
try:
    with os.fdopen(fd, "w") as fh:
        json.dump(doc, fh, indent=1, sort_keys=True)
        fh.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print("merged into", path)
PY
    ); then
      printf '%s\n' "$man_out" | sed 's/^/  ..    /'
      ok "manifest" "$STATE/node.json (merged: keys this ladder does not own are preserved)"
    else
      bad "manifest" "could not merge the manifest into $STATE/node.json: $(row_tail "$man_out")"
    fi
  elif [ -f "$STATE/node.json" ]; then
    ok "manifest" "$STATE/node.json"
  else
    note "manifest is written only when every layer passes"
  fi
fi

say ""
if [ "$FAILED" -eq 0 ]; then say "NODE: PASS"; exit 0; else say "NODE: FAIL ($FAILED)"; exit 1; fi

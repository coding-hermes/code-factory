#!/usr/bin/env bash
# project-node.sh — provision ONE node, from inside that node.
#
# Runs on the agent, not on the control host (node-create.sh stages it).
#
#   project-node.sh --check   [--project P] [--harness hermes] [--repo URL] [--ref main]
#   project-node.sh --apply   [same args]
#
# Layers: 00 preflight, 10 base, 20 harness, 30 bus, 40 repo, 90 verify (verify is the
# control host's job; here we only prove the node-side plumbing exists).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PROJECT="${NODE_PROJECT:-}"
HARNESS="${NODE_HARNESS:-hermes}"
REPO=""
REF="${NODE_REF:-main}"
PORT="${NODE_GATEWAY_PORT:-10800}"
FLOOR="${NODE_DISK_FLOOR:-5}"
MODE=""
STATE="$HOME/.node"

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --apply) MODE=apply; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$MODE" ] && { echo "usage: $0 --check|--apply [--project P] [--harness H] [--repo URL] [--ref R]"; exit 2; }
[ -z "$PROJECT" ] && { echo "--project is required (a node belongs to exactly one project)"; exit 2; }

mkdir -p "$STATE"
say "node provisioning — project=$PROJECT harness=$HARNESS host=$(hostname)"

# ---------------------------------------------------------------- 00 preflight
say "[00] preflight"
arch=$(uname -m); ok "arch" "$arch ($(uname -sr))"
require_disk "$HOME" "$FLOOR" || true
mem=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)
[ "${mem:-0}" -ge 1024 ] && ok "mem" "${mem} MB" || bad "mem" "${mem} MB < 1024"
CRIER="${CRIER_URL:-}"
if [ -z "$CRIER" ]; then
  bad "crier_url" "CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)"
else
  for u in "$CRIER/health" https://pypi.org/simple/; do
    c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null || echo 000)
    [ "$c" = 200 ] && ok "reach:$u" "200" || bad "reach:$u" "-> $c"
  done
fi

# ---------------------------------------------------------------- 10 base
say "[10] base"
for t in python3 git curl tar sha256sum; do
  p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || bad "tool:$t" "missing"
done
python3 -c 'import venv' 2>/dev/null && ok "python:venv" "importable" || bad "python:venv" "venv missing — no user-space installs possible"
for t in jq rg node; do
  p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (some repos' tests need node)"
done

# ---------------------------------------------------------------- 20 harness
say "[20] harness"
inst="$HERE/harness/install-$HARNESS.sh"
if [ ! -x "$inst" ]; then
  bad "harness:$HARNESS" "no adapter at scripts/harness/install-$HARNESS.sh"
else
  if [ "$MODE" = apply ]; then NODE_GATEWAY_PORT="$PORT" "$inst" --apply; else NODE_GATEWAY_PORT="$PORT" "$inst" --check; fi
fi

# ---------------------------------------------------------------- 30 bus
say "[30] bus"
if [ -f "$STATE/crier.json" ]; then
  ok "crier_identity" "$STATE/crier.json"
  m=$(stat -c '%a' "$STATE/crier.json"); [ "$m" = 600 ] && ok "crier_mode" "600" || bad "crier_mode" "$m (must be 600)"
else
  bad "crier_identity" "absent — stage a bundle and re-run; a node without an identity is invisible"
fi

# ---------------------------------------------------------------- 40 repo
say "[40] repo"
RP="$HOME/repo"
if [ -d "$RP/.git" ]; then
  ok "repo" "$RP @ $(git -C "$RP" rev-parse --short HEAD)"
else
  if [ "$MODE" = apply ] && [ -n "$REPO" ]; then
    say "  ..    cloning $REPO @ $REF"
    if git clone --depth 1 --branch "$REF" "$REPO" "$RP" >/tmp/clone.log 2>&1; then
      ok "repo_clone" "$RP @ $(git -C "$RP" rev-parse --short HEAD)"
    else
      bad "repo_clone" "$(tail -1 /tmp/clone.log) (private repos need a deploy key)"
    fi
  else
    bad "repo" "$RP absent (pass --repo to clone)"
  fi
fi

# ---------------------------------------------------------------- manifest
say "[90] manifest"
if [ "$MODE" = apply ] && [ "$FAILED" -eq 0 ]; then
  python3 - "$STATE/node.json" "$PROJECT" "$HARNESS" "$PORT" "$REPO" "$REF" "$(hostname)" <<'PY'
import json, sys, time
path, project, harness, port, repo, ref, host = sys.argv[1:8]
json.dump({"node_id": host, "project": project,
           "repo": {"origin": repo, "ref": ref, "path": "/home/" + __import__("os").environ.get("USER", "node") + "/repo"},
           "harness": {"name": harness, "port": int(port)},
           "bus": {"base": __import__("os").environ.get("CRIER_BASE", "http://crier.example:8767")},
           "created_by": "project-node.sh v1",
           "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())},
          open(path, "w"), indent=1)
print("wrote", path)
PY
  ok "manifest" "$STATE/node.json"
elif [ -f "$STATE/node.json" ]; then
  ok "manifest" "$STATE/node.json"
else
  note "manifest is written only when every layer passes"
fi

say ""
if [ "$FAILED" -eq 0 ]; then say "NODE: PASS"; exit 0; else say "NODE: FAIL ($FAILED)"; exit 1; fi

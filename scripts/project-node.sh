#!/usr/bin/env bash
# project-node.sh — provision ONE node, from inside that node.
#
# Runs on the agent, not on the control host (node-create.sh stages it).
#
#   project-node.sh --check   [--project P] [--harness hermes] [--repo URL] [--ref main]
#   project-node.sh --apply   [same args]
#   project-node.sh --check   [same args] --layers 00,10,20,30,40
#
# Layers: 00 preflight, 10 base, 20 harness, 30 bus, 40 repo, 90 verify (verify is the
# control host's job; here we only prove the node-side plumbing exists).
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
. "$HERE/lib.sh"

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
STATE="$HOME/.node"

usage_line() {
  echo "usage: $0 --check|--apply [--project P] [--harness H] [--repo URL] [--ref R] [--role worker|builder|full] [--disk-floor GIB] [--layers 00,10,20,30,40]" >&2
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
      if ! RECLAIM="$(python3 "$HERE/reclaim_disk.py" run --root "$HOME" --json 2>&1)"; then
        bad "disk_floor" "reclaim failed: $RECLAIM"
        say "NODE: FAIL ($FAILED)"
        exit 1
      fi
      say "${RECLAIM%$'\n'*}"
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
if in_scope 10; then
  say "[10] base"
  for t in python3 git curl tar sha256sum; do
    p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || bad "tool:$t" "missing"
  done
  python3 -c 'import venv' 2>/dev/null && ok "python:venv" "importable" || bad "python:venv" "venv missing — no user-space installs possible"
  for t in jq rg node; do
    p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" || warn "tool:$t" "missing (some repos' tests need node)"
  done
else
  say "  SKIP  layer 10 (out of scope)"
fi

# ---------------------------------------------------------------- 20 harness
if in_scope 20; then
  say "[20] harness"
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
if in_scope 40; then
  say "[40] repo"
  RP="$HOME/repo"
  if [ -d "$RP/.git" ]; then
    ok "repo" "$RP @ $(git -C "$RP" rev-parse --short HEAD)"
    REPO_READY=1
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
    python3 - "$STATE/node.json" "$PROJECT" "$HARNESS" "$PORT" "$REPO" "$REF" "$(hostname)" "$STATE/freshness.json" <<'PY'
import json, sys, time
path, project, harness, port, repo, ref, host, fresh_path = sys.argv[1:9]
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
json.dump({"node_id": host, "project": project,
           "repo": {"origin": repo, "ref": ref, "path": "/home/" + __import__("os").environ.get("USER", "node") + "/repo"},
           "harness": {"name": harness, "port": int(port)},
           "bus": {"base": __import__("os").environ.get("CRIER_BASE", "http://crier.example:8767")},
           "freshness": freshness,
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
fi

say ""
if [ "$FAILED" -eq 0 ]; then say "NODE: PASS"; exit 0; else say "NODE: FAIL ($FAILED)"; exit 1; fi

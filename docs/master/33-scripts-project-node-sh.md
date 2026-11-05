# 33. scripts/project-node.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/project-node.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: Node-side check/apply cannot run. The script is the node-side entry point: `project-node.sh --check` / `--apply`, running layers 00 preflight, 10 base, 20 harness, 30 bus, 40 repo, then writing a manifest only on unscoped all-green apply. Source: `"project-node.sh — provision ONE node, from inside that node."`
- What breaks if it lies: A node can print `NODE: PASS` while not grading the repo-required toolchain, or while holding a stale checkout. Source: `"a node would print PASS while grading nothing the repo needs"` and `"a node one commit behind origin/main, or carrying a local edit that blocks its own fast-forward, printed PASS at every layer"`.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `git` | unknown | On the node's PATH | Layer 10 loop: `for t in python3 git curl tar sha256sum; do p=$(have "$t"); [ -n "$p" ] && ok "tool:$t" "$p" \|\| bad "tool:$t" "missing"; done` |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | Python 3 standard library | JSON parse/serialization: `import json,sys`; `json.load(sys.stdin)["floor_gib"]`; `json.dump(...)` | Breaks disk-floor resolver parsing, freshness recording, or manifest writing |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| ? | `usage: $0 --check\|--apply [--project P] [--harness H] [--repo URL] [--ref R] [--role worker\|builder\|full] [--disk-floor GIB] [--layers 00,10,20,30,40] [--kinds go,rust,node,python,generic]` | Invalid/missing mode or invalid layer/kind syntax calls `usage_line` | descriptive |
| ? | `unknown arg: $1` | Unknown CLI argument is parsed | descriptive |
| ? | `--project is required (a node belongs to exactly one project)` | Mode is set but `PROJECT` is empty after argument parsing | descriptive |
| WARN | `  WARN  disk_floor — python3 absent, using built-in ${ROLE} default ${FLOOR_GIB} GiB` | Preflight is in scope and `command -v python3` fails | descriptive |
| ? | `unknown role: $ROLE (expected worker\|builder\|full)` | `ROLE` is not one of `worker`, `builder`, `full` | descriptive |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Missing `--project` | `--project is required (a node belongs to exactly one project)` on stderr, exit 2 | Valid invocation but project not provided | Re-run with `--project P` or `NODE_PROJECT=P` |
| Invalid role | `unknown role: $ROLE (expected worker\|builder\|full)` on stderr, exit 2 | Other CLI parse errors | Re-run with valid `--role` |
| Empty/unknown `--kinds` or `--layers` | `bad "kinds" ...` or usage, then `NODE: FAIL (n)`, exit 1 | Fails before any layer runs | Correct `--kinds`/`--layers` to a valid subset |
| Missing/unreadable `disk_floor.py` | `bad "disk_floor" "resolver missing or unreadable: $HERE/disk_floor.py"` then `NODE: FAIL`, exit 1 | Distinct from python3-absent path, which warns and uses built-in floor | Restore/install `scripts/disk_floor.py` |
| Disk below floor after reclaim | `bad "disk" "${free} GB free after reclaim < floor ${FLOOR_GIB} GB at $HOME ..."` then `NODE: FAIL (disk admission)`, exit 1 | Reclaim ran but disk still below floor | Free disk or raise floor |
| `CRIER_URL` unset | `bad "crier_url" "CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)"` | Preflight row identifies crier URL | Export `CRIER_URL` |
| Required base tool missing | `bad "tool:<t>" "missing"` in layer 10; `NODE: FAIL` | Row names missing tool | Install missing tool |
| Required kind tool missing | e.g. `bad "tool:go" "missing — kind go needs a Go toolchain on PATH ..."` | Occurs only when declared/derived kind requires the tool | Install required toolchain |
| Harness adapter absent | `bad "harness:$HARNESS" "no adapter at scripts/harness/install-$HARNESS.sh"` | Layer 20 row identifies harness | Add/install harness adapter |
| Crier identity absent/incorrect mode | `bad "crier_identity" "absent — stage a bundle and re-run; a node without an identity is invisible"` or `bad "crier_mode" "$m (must be 600)"` | Layer 30 row identifies identity/mode | Stage identity bundle and set mode to 600 |
| Repo absent | `bad "repo" "$RP absent (pass --repo to clone)"` | Check mode, or apply without `--repo` | Pass `--repo` or clone separately |
| Clone ref not found | `bad "repo_clone" "ref '$REF' was not found; pass --ref <branch-or-tag>"` | `git ls-remote` reports ref missing | Provide valid `--ref` branch/tag |
| Repository access failure | `bad "repo_clone" "... (repository access failed; private repos need a deploy key)"` | `git ls-remote` could not access repository | Provide deploy key or fix access |
| Dirty checkout | `warn "freshness" "$fs_row — a local edit on the node is a finding: it blocks the node's fast-forward and the fix belongs upstream (not repaired here)"` | Dirty checkout is WARN; drift is FAIL | Fix upstream, do not repair silently |
| Drift/behind checkout | `bad "freshness" "$fs_row — ${fs_reason:-checkout freshness could not be measured}"` | Behind/diverged, so fast-forward impossible | Fix upstream and re-check |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `NODE_PROJECT` | `""` | `PROJECT` remains empty after parsing; if no `--project`, script prints `--project is required...` and exits 2 |
| `NODE_HARNESS` | `"hermes"` | `HARNESS` becomes `hermes` |
| `NODE_REF` | `"main"` | `REF` becomes `main` |
| `NODE_GATEWAY_PORT` | `"10800"` | `PORT` becomes `10800` |
| `NODE_ROLE` | `"worker"` | `ROLE` becomes `worker` |
| `NODE_KINDS` | empty | `KINDS_SET` remains 0, so layer 10 derives kinds from `$HOME/repo` or falls back to `generic`; if set but empty, `KINDS_SET=1` and is rejected as empty kind list |
| `CRIER_URL` | empty | Preflight emits `bad "crier_url" "CRIER_URL unset — the node has nothing to connect to..."`; node eventually fails |
| `CRIER_BASE` | `"http://crier.example:8767"` in manifest | Manifest `bus.base` uses default URL |
| `GO_INSTALL_ROOT` | `$HOME/go-toolchain` | Go toolchain searched at `$HOME/go-toolchain/current/bin/go`, else falls back to `have go` |
| `GOPROXY` | `unset` | Used only if `go env GOPROXY` returns empty during go proxy probe; row prints `unset` |
| `HOME` | — | Used for `$STATE` (`$HOME/.node`), `$RP` (`$HOME/repo`), and disk checks; unset would break expansion |
| `USER` | `"node"` fallback in manifest | Manifest repo path uses `$USER`; if unset, fallback is `node` |

## 8. Evidence of record

- Source file supplied and reviewed: `/home/kara/code-factory/scripts/project-node.sh`

# 40. specs/NODE.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/NODE.md` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: **UNKNOWN** — the source defines the node as “the unit of execution: one bunker agent bound to one project and one repo” and says “The manifest is the node's identity: a scheduler target names `node_id`; the control host reads the manifest to know where the artifacts are,” but it does not state the exact break if the module is absent.
- What breaks if it lies: **UNKNOWN** — every self-reporting component has this failure mode.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| arch | not specified | node preflight | layer 00 preflight |
| disk ≥ floor | floor configurable; role defaults 5/10/20 GiB | node preflight | refusal below floor that names free space and configured floor |
| memory | not specified | node preflight | layer 00 preflight |
| `$CRIER_URL/health` reachable with HTTP 200 | — | endpoint probed by preflight | unset reach block is skipped and layer prints `FAIL crier_url`; non-200 fails layer 00 |
| `https://pypi.org/simple/` reachable with HTTP 200 | — | endpoint probed by preflight | layer 00 probe failure |
| `python3`, `git`, `curl`, `tar`, `sha256sum` | not specified | “fixed base set” | layer 10 base |
| `jq` / `rg` | not specified | “fixed base set” | WARN-only in layer 10 |
| Go toolchain | digest-pinned `go1.26.5` user-space archive | installed by `scripts/install-go.sh` during `--apply` | `--check` “names the absent Go binary as a failure” |
| Rust toolchain | not specified | toolchain for rust kinds | `cargo --version` read back |
| Node toolchain | not specified | toolchain for node kinds | `node --version` read back |
| Python toolchain | not specified | `python3` + `venv` | read back in layer 10 |
| Harness binary | manifest example `hermes` version `0.19.0` | layer 20 harness | layer 20 FAIL if harness absent |
| Bus identity file | — | `$HOME/.node/crier.json` and mode `600` | layer 30 `-f $STATE/crier.json`, then `stat -c '%a'` against `600` |
| Repo clone at pinned ref | pinned ref | layer 40 repo | layer 40 checkout measured by `scripts/node_freshness.py` or node-side fallback |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| — | — | **RED: no imports detected** | — |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `$CRIER_URL/health` endpoint | outbound | HTTP GET | HTTP `200` | `scripts/project-node.sh:190` probes this endpoint; a HEAD against that GET-only handler answers `405` |
| `https://pypi.org/simple/` | outbound | HTTP HEAD | HTTP `200`; index is ~48 MB, GET under 8 s budget reports `000` on a healthy link | `scripts/project-node.sh:190` probes this endpoint |
| Node's own `GOPROXY` | outbound | Go module fetch | resolves pinned `rsc.io/quote@v1.5.2` through the node's own `GOPROXY` | `scripts/project-node.sh`, `go_proxy_row` |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Layer census | `bash scripts/project-node.sh --check --project <p> --layers 10` | prints its own census command; `kinds` row names evidence | UNKNOWN | UNKNOWN |
| Disk floor resolver | `python3 scripts/disk_floor.py resolve --role builder --explain` | prints `{"role":…,"floor_gib":…,"source":…}` | UNKNOWN | UNKNOWN |
| Disk floor roles | `python3 scripts/disk_floor.py roles` | lists defaults | UNKNOWN | UNKNOWN |
| Lane target parse | `scripts/lane_target.py parse <target>` | emits components as JSON; unparseable or relative local paths exit `2` | UNKNOWN | UNKNOWN |
| Lane target verify | `scripts/lane_target.py verify ...` | local: real checkout; remote: structural-only unless `--allow-remote`; bunker: `--exec-bunker` proves `path_exists` | UNKNOWN | UNKNOWN |
| Lane target plan | `scripts/lane_target.py plan <projects.jsonl> --agent <id> --server <server>` | emits intended `bunker://<agent>/<home><suffix>` target per lane | UNKNOWN | UNKNOWN |
| Lane target scan | `scripts/lane_target.py scan <projects.jsonl> [--allow-remote]` | exits nonzero if any target invalid | UNKNOWN | UNKNOWN |
| Node freshness | `scripts/node_freshness.py --agent A --server S [--path REL]` | proves checkout matches `origin/main`; exit codes `0` PASS, `1` drift/dirty, `2` usage/unreachable | UNKNOWN | UNKNOWN |
| Node seed drift | `scripts/node_seed_drift.py --agent A --server S` | PASS row counts seeded files; FAIL row names drifted paths; exit `0` matched, `1` drift, `2` usage, `3` could not measure | UNKNOWN | UNKNOWN |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.

## 5. Log lines it can generate

- `FAIL crier_url`
- `WARN kinds — generic fallback …`
- `FAIL tool:node`
- `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml`
- `FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size…`
- `SCOPE: layers <list> (fixture mode — not a node certification)`
- `  SKIP  layer NN (out of scope)`
- `  SKIP  layer 90 (fixture mode: no manifest)`
- `NODE: PASS`
- `NODE: FAIL (n)`
- `[90] manifest`
- `crier_identity` / `crier_mode`
- `python`, `binary`, `version`, `port`, `inference_key`, `gateway_start` gate rows
- `HERMES: FAIL (n)`

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Below disk floor | Refuses admission, naming both measured free space and configured floor plus the source that set it | Identified by floor refusal and source rung | `--apply` runs `scripts/reclaim_disk.py run --root "$HOME" --json`, then re-measures free space and refuses only if still below floor |
| Harness down | `layer 20 FAIL; no work is accepted.` | Layer 20 failure | UNKNOWN |
| Bus identity missing | `layer 30 FAIL; the node is invisible, which is worse than empty.` | Layer 30 failure | UNKNOWN |
| Repo dirty at provision time | `WARN, not FAIL`; uncommitted paths are named and recorded in `$HOME/.node/freshness.json` and manifest `freshness` | Mid-task local edits; WARN, not FAIL | Edits belong upstream, not in the node's tree |
| Repo drifted at provision time | `FAIL under --apply`; node would work a tree that no longer matches `origin/main` | Pull cannot fast-forward | Neither condition repaired silently by ladder |
| Round trip fails | node is quarantined | Round-trip failure | Scheduler must not send it more work |
| `gateway_start` refusal | Layer 20 ends `HERMES: FAIL (n)`, ladder ends `NODE: FAIL (n)`; prints `FAIL gateway_start — refused…` | Missing `dashboard.basic_auth` in `~/.hermes/config.yaml` | CF-150 owns create-path fix; no shipped stage writes that file |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_URL` | unknown | `With CRIER_URL unset the reach block is skipped entirely and the layer prints FAIL crier_url instead of two probe rows.` |
| `NODE_KINDS` | unknown | falls through to workspace evidence and then generic fallback; empty or unknown element is a named `FAIL kinds` and exits 1 |
| `NODE_DISK_FLOOR` | unknown | lower-precedence rungs apply: config `[disk] <role>_gib`, config `[disk] default_gib`, built-in role default |
| `NODE_ROLE` | unknown | role may come from `--role`; if unset, the config/built-in role default path applies |
| `NODE_DISK_FLOOR_CONFIG` | unknown | if unset, config file location may come from `--config` or defaults to `$HOME/.node/floor.toml` |
| `GOPROXY` | unknown | layer 10 resolves the pinned `rsc.io/quote@v1.5.2` through the node's own `GOPROXY` |

## 8. Evidence of record

- none yet

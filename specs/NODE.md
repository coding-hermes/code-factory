# SPEC — NODE

A **node** is the unit of execution: one bunker agent bound to one project and one repo.

## Manifest (`$HOME/.node/node.json`)

```json
{
  "node_id": "<agent id>",
  "project": "crier",
  "repo": {"origin": "git@…", "ref": "main", "path": "/home/<uid>/repo"},
  "harness": {"name": "hermes", "version": "0.19.0", "port": 10800},
  "bus": {"agent_id": "node-crier", "base": "http://crier.example:8767"},
  "created_by": "project-node.sh v1",
  "created_at": "2026-10-29T18:40:00Z"
}
```

The manifest is the node's identity: a scheduler target names `node_id`; the control host reads
the manifest to know where the artifacts are.

## Layers (each has a check that can fail)

| Layer | Establishes | Depends on |
|---|---|---|
| 00 preflight | arch, disk ≥ floor, memory, and HTTP 200 from the only two endpoints this layer probes — `$CRIER_URL/health` and `https://pypi.org/simple/` (`scripts/project-node.sh:190`). With `CRIER_URL` unset the reach block is skipped entirely and the layer prints `FAIL crier_url` instead of two probe rows. Reachability to a Go module proxy is **not measured** by this or any shipped layer: no probe row is emitted for one, and `GOPROXY` / `GOPRIVATE` appear nowhere under `scripts/` (CF-164) | — |
| 10 base | python3 + venv, git, curl, tar, sha256sum; optionally jq, rg, node | preflight |
| 20 harness | the harness binary plus the adapter's own gate rows, printed verbatim (`python`, `binary`, `version`, `port`, `inference_key`, and `gateway_start` when that block runs); `gateway_start` is a refusal on any node whose `~/.hermes/config.yaml` does not parse to a non-empty `dashboard.basic_auth` username and password (`scripts/harness/install-hermes.sh:66–186`) | base |
| 30 bus | a crier identity file at `$HOME/.node/crier.json` and its mode 600 | harness |
| 40 repo | the repo cloned at a pinned ref | base |
| 90 verify | the node manifest (`$HOME/.node/node.json`), written only when every layer passed | all |

Three capabilities that the design describes are **not** established by any shipped layer, and this
table no longer claims them:

- **A started gateway on a freshly created node.** Layer 20 runs the adapter with `--apply`
  (`scripts/project-node.sh:228`), and the adapter starts `hermes serve` only when
  `~/.hermes/config.yaml` already parses to a non-empty `dashboard.basic_auth` username and password
  (`scripts/harness/install-hermes.sh:66–186`, gate at `:251–258`); otherwise it prints
  `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml`.
  No shipped stage writes that file — `scripts/node-create.sh --staged-files` prints five files
  (`project-node.sh`, `lib.sh`, `disk_floor.py`, `reclaim_disk.py`, `harness/install-hermes.sh`) and
  no `config.yaml`, and no script under `scripts/` redirects into it — so on a node created by
  `scripts/node-create.sh` layer 20 ends `HERMES: FAIL (n)`, the ladder ends `NODE: FAIL (n)`, and
  `NODE: PASS` is unreachable. Whether a bunker agent image already ships that file is **not
  measured** by this repo. CF-150 owns the create-path fix; it is the source of this cell.
- **A node-side bus worker.** Layer 30 starts and checks no process and opens no socket:
  `scripts/project-node.sh:244-249` tests `-f $STATE/crier.json`, then `stat -c '%a'` against `600`,
  and prints `crier_identity` / `crier_mode`. Whether a worker is running on the node is unmeasured
  by this ladder; CF-068 owns the file-existence weakness this layer still has.
- **A round trip whose digest is recomputed on the control host.** Layer 90 prints `[90] manifest`
  and writes `$HOME/.node/node.json` (`scripts/project-node.sh:294-312`); it recomputes no artifact
  digest and consults no control host. That criterion is what the runbook calls NOT YET
  (`docs/OPERATIONS.md` §6), CF-004 owns building it, and `AGENTS.md` rule 4 keeps it as the proof
  a node works — it is the standard layer 90 is graded against, not something layer 90 delivers.

Layer 40's cell was narrowed to the clone alone for the same reason (`6f75e28`, CF-032). Every cell
in this table now names only something the shipped script measures or prints.

### Fixture scope (`--layers`)

A run costs every layer's work, but a test that asserts one layer's row needs that layer only.
`project-node.sh --layers 00,10,20,30,40` runs only the named check layers: a comma-separated
subset of `00,10,20,30,40`, where a single value is a list of one. An unknown element, an empty
list or a stray comma prints the usage line to stderr and exits 2 before any layer runs, so a
half-applied scope can never reach layer 00.

A scoped run is a **fixture**, never a certification:

- it prints one `SCOPE: layers <list> (fixture mode — not a node certification)` line before
  layer 00, and `  SKIP  layer NN (out of scope)` in the position each skipped layer would have
  taken;
- it never writes `$HOME/.node/node.json`, even under `--apply` with every in-scope layer green:
  layer 90 reports `  SKIP  layer 90 (fixture mode: no manifest)` instead, so **N-4** holds by
  construction — no manifest, no node identity;
- it does not resolve the disk floor when `00` is out of scope, because nothing measures or
  consumes it and a fixture installs nothing (the fail-closed floor path keeps its coverage on
  unscoped runs, `tests/selftest.sh` section 13);
- the summary line keeps its existing shape (`NODE: PASS` / `NODE: FAIL (n)`); the absence of a
  manifest, not the summary, is what makes a scoped run non-certifying.

An unscoped run is unchanged in every respect: same rows, same order, same manifest behaviour,
same exit codes.

## Laws

- **N-1** No root. Any step needing sudo is wrong.
- **N-2** Idempotent. A second `--apply` changes nothing and exits 0.
- **N-3** Every check names the measured value.
- **N-4** The manifest is written only after each layer's check passes.
- **N-5** A node refuses to start work below the disk floor, and says the number; reap before refusing.
- **N-6** Destroying the agent destroys the node; the scripts must rebuild it exactly.

## Disk floor

Measured components per repo node: 97 MB repo + 656 MB module cache + toolchain + harness. Build cache is not provisioned by shipped scripts and is excluded.

Floor = repo + harness + 2 GB working room. The ladder reads free space and refuses below the floor **with the number in the refusal**.

Before refusing, `--apply` runs `scripts/reclaim_disk.py run --root "$HOME" --json`
against bounded user-space targets: `.cache/pip`, `.cache/uv`, `.cache/pre-commit`,
`.cache/go-build`, and `.npm/_cacache` are removed whole; immediate job directories
under `.node/jobs` and stale clones under `.node/clones` are removed only when their
mtime exceeds the TTL (default 24 hours, configurable with `--job-ttl-hours`).
Targets are fixed, resolved inside the real root, and symlinks are never followed.
The repo and node identity/configuration files are never targets. The reclaimer
refuses `/` and non-directory roots, supports `--dry-run`, and reports reclaimed bytes.
The ladder re-measures free space after reclaim and refuses only if still below the
floor. `--check` never reclaims: it reports the existing disk failure, explains what
`--apply` would reap first, and keeps measuring the other layers.

### Configurable floors (roles)

The floor is operator policy, so it is configurable — and the precedence is fixed, highest first:

| Rung | Source | Example |
|---|---|---|
| 1 | `--disk-floor <GiB>` | `project-node.sh --check --disk-floor 8` |
| 2 | `NODE_DISK_FLOOR` | `NODE_DISK_FLOOR=8G` |
| 3 | config `[disk] <role>_gib` | `worker_gib = "8"` |
| 4 | config `[disk] default_gib` | `default_gib = "6"` |
| 5 | built-in role default | see below |

Role defaults: `worker` 5 GiB, `builder` 10 GiB, `full` 20 GiB. The role is selected with `--role` or `NODE_ROLE`. Accepted value forms: `7`, `7G`, `7GiB`, `1.5G` (whole GiB, 1–4096).

A malformed value fails closed **before** any install, clone or adapter run: `FAIL disk-floor: NODE_DISK_FLOOR: 'plenty' is not a size…`. A typo never lowers a floor, and a below-floor node refuses admission naming both the measured free space and the configured floor, plus the source that set it.

Config file location: `--config`, `NODE_DISK_FLOOR_CONFIG`, or `$HOME/.node/floor.toml`. See `examples/floor.toml.example`.

Resolver: `python3 scripts/disk_floor.py resolve --role builder --explain` prints `{"role":…,"floor_gib":…,"source":…}`; `python3 scripts/disk_floor.py roles` lists defaults.

## Workdir targets

A lane's `workdir` is a **target**, not a local directory string. Remote execution means the workdir can live on another host, addressed the way people address remote paths:

| Form | Kind | Example |
|---|---|---|
| absolute / `~` path | local | `/home/agent/code-factory` |
| `local:` / `file://` | local | `local:/srv/cf` |
| `user@host:path` | remote (ssh/scp style) | `builder@node-01:/srv/code-factory` |
| `ssh://user@host[:port]/path` | remote | `ssh://builder@node-01:2222/srv/cf` |
| `sftp://` / `ftp://` / `ftps://` / `rsync://` | remote | `sftp://deploy@mirror/srv/cf` |
| `bunker://<agent>/path` | remote (bunker identity) | `bunker://cf-worker/srv/cf` |

Rules:

- `scripts/lane_target.py parse <target>` structurally validates and emits the components as JSON; unparseable or relative local paths exit 2.
- `verify` on a **local** target proves it is a real checkout: directory exists, `git rev-parse --show-toplevel` succeeds, the top level is **not `$HOME`** (the stand-in locator defect where a lane reads the home repo's board), the top level matches the target, a remote exists, and HEAD is an attached branch.
- `verify` on a **remote** target is `remote-structural-only`: reachability and existence are NOT checked locally, and that must be requested explicitly with `--allow-remote` (exit 3 otherwise). A remote target is never silently treated as verified.
- `verify --exec-bunker [--bunker-server S]` on a **bunker** target proves it against the agent itself: `bunker exec <agent> -- sh -lc 'echo $HOME; test -d <path>'` must return a home and an existing directory. Checks recorded: `bunker_cli`, `agent_reachable`, `path_exists`.
- `lane_target.py plan <projects.jsonl> --agent <id> --server <server> [--suffix /repo] [--prefix P]` emits the intended `bunker://<agent>/<home><suffix>` target per lane. The agent's home is **resolved from the agent**, never templated: homes are `/home/bunker-<full-id>`, so a `{agent}` template builds a wrong path that still parses.
- `lane_target.py scan <projects.jsonl> [--allow-remote]` checks every row and exits nonzero if any target is invalid.
- Lane writers (`scripts/configure_family.py`) only `mkdir` a **local** target; a remote target is registered verbatim and materialised by the node side.

## Failure semantics

- Harness down → layer 20 FAIL; no work is accepted.
- Bus identity missing → layer 30 FAIL; the node is invisible, which is worse than empty.
- Repo dirty at provision time → WARN, not FAIL (the node may be mid-task); `verify` still runs.
- Round trip fails → the node is quarantined; the scheduler must not send it more work.

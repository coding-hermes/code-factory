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
| 00 preflight | arch, disk ≥ floor, memory, reachability to crier / PyPI / Go proxy | — |
| 10 base | python3 + venv, git, curl, tar, sha256sum; optionally jq, rg, node | preflight |
| 20 harness | the chosen harness + its gateway/CLI | base |
| 30 bus | a crier identity file (600) and a pull worker | harness |
| 40 repo | the repo cloned at a pinned ref | base |
| 90 verify | one round trip whose digest is recomputed on the control host | all |

## Laws

- **N-1** No root. Any step needing sudo is wrong.
- **N-2** Idempotent. A second `--apply` changes nothing and exits 0.
- **N-3** Every check names the measured value.
- **N-4** The manifest is written only after each layer's check passes.
- **N-5** A node refuses to start work below the disk floor, and says the number.
- **N-6** Destroying the agent destroys the node; the scripts must rebuild it exactly.

## Disk floor

Measured components per repo node: 97 MB repo + 656 MB module cache + toolchain + harness. Build cache is not provisioned by shipped scripts and is excluded.

Floor = repo + harness + 2 GB working room. The ladder reads free space and refuses below the floor **with the number in the refusal**.

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
- `lane_target.py scan <projects.jsonl> [--allow-remote]` checks every row and exits nonzero if any target is invalid.
- Lane writers (`scripts/configure_family.py`) only `mkdir` a **local** target; a remote target is registered verbatim and materialised by the node side.

## Failure semantics

- Harness down → layer 20 FAIL; no work is accepted.
- Bus identity missing → layer 30 FAIL; the node is invisible, which is worse than empty.
- Repo dirty at provision time → WARN, not FAIL (the node may be mid-task); `verify` still runs.
- Round trip fails → the node is quarantined; the scheduler must not send it more work.

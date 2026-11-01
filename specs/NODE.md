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
| 40 repo | the repo cloned at a pinned ref, build cache present | base |
| 90 verify | one round trip whose digest is recomputed on the control host | all |

## Laws

- **N-1** No root. Any step needing sudo is wrong.
- **N-2** Idempotent. A second `--apply` changes nothing and exits 0.
- **N-3** Every check names the measured value.
- **N-4** The manifest is written only after each layer's check passes.
- **N-5** A node refuses to start work below the disk floor, and says the number.
- **N-6** Destroying the agent destroys the node; the scripts must rebuild it exactly.

## Disk floor

Measured footprint per repo node: ~1.5 GB (97 MB repo + 656 MB module cache + ~520 MB build
cache + toolchain, plus harness). Floor = repo + harness + 2 GB working room. The ladder reads
free space and refuses below the floor **with the number in the refusal**.

## Failure semantics

- Harness down → layer 20 FAIL; no work is accepted.
- Bus identity missing → layer 30 FAIL; the node is invisible, which is worse than empty.
- Repo dirty at provision time → WARN, not FAIL (the node may be mid-task); `verify` still runs.
- Round trip fails → the node is quarantined; the scheduler must not send it more work.

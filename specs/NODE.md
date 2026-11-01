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

The historical estimate per repo node is ~1.5 GB (97 MB repo + 656 MB module cache +
~520 MB build cache + toolchain, plus harness). This is not a current measurement per
role. Role sizing and justified role-specific floors remain open under CF-007.

The provisioning default is a provisional 5 GiB, overridden by `NODE_DISK_FLOOR` or
`--disk-floor` on `project-node.sh` and `node-create.sh`. Floors are unsigned decimal
GiB, with 1–9 digits per part. Invalid floors or malformed/failed `df -Pk` observations
fail closed, even at floor zero. Integer KiB and rational arithmetic admit equality
and refuse strictly below the floor; output names both measured KiB and exact GiB.
Admission precedes node-state creation, adapter execution, clone and manifest writes.
`--check` does not create node state.

Reclaim is disabled by default. Only `--apply --reclaim-disposable` may reclaim, only
when below the floor, and only flat enrolled `cache-*.bin` files in the fixed
`$HOME/.node/disposable-cache-v1` namespace. Home, directories, names, regular-file
type, ownership, permissions, link count and device checks fail closed; no caller-
selected root or recursive cleanup is allowed. The helper takes an exclusive lock,
remeasures before deleting (skipping deletion if capacity recovered), validates the
whole namespace before unlinking and remeasures after reclaim before admission.
Checks never reclaim, even when the flag is supplied. Missing namespaces are not
created by reclaim. Broad build-cache/job/stale-clone cleanup and owner-authorized
live Bunker orphan-home/key/user inventory and reaping are not verified.

This is a provisioning admission gate, not a runtime quota or scheduler disk guard.
The control host validates the floor before Bunker operations and stages the policy
helper before invoking the remote provisioner; staging failures stop the flow.

## Failure semantics

- Harness down → layer 20 FAIL; no work is accepted.
- Bus identity missing → layer 30 FAIL; the node is invisible, which is worse than empty.
- Repo dirty at provision time → WARN, not FAIL (the node may be mid-task); `verify` still runs.
- Round trip fails → the node is quarantined; the scheduler must not send it more work.

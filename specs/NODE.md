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

## Script boundary and manifest mapping

`scripts/project-node.sh` is the node-side entry point. `--check` runs the layers without writing
the manifest; it may create `$HOME/.node` as the state directory. `--apply` writes the manifest only
after the adapter check, bus identity check, and repository check have all passed. The adapter must
print a measured `PASS  version` line; that value is copied into `harness.version`. An existing
manifest is preserved byte-for-byte on a second apply so the created timestamp does not defeat N-2.

`--node-id` (or `NODE_ID`) supplies `node_id`; `node-create.sh` passes the bunker agent id here.
The bus fields are `CRIER_AGENT_ID` (falling back to the node id) and `CRIER_BASE` (falling back to
`CRIER_URL`). The identity file must already exist at `$HOME/.node/crier.json`, be mode 600, and be
provisioned through an approved secure bundle process. The checked-in scripts do not create a crier
pull worker or transfer credentials, so that part of layer 30 remains an external precondition and
must stay **BLOCKED / NOT VERIFIED** until measured.

`scripts/node-create.sh` is the control-host orchestrator for the project + repo + harness triple:
it reuses or spawns an agent, stages the node scripts, runs `project-node.sh --apply` with the
validated values, then calls `scripts/verify-node.sh` with the node manifest as the required
artifact. It stops on staging or provisioning failure and never reports a created node after a
failed layer. The live bunker path is not a local self-test; absence of a configured bunker is
**NOT VERIFIED / BLOCKED**, not a successful creation.

`scripts/verify-node.sh` is a control-host check. It requires `--artifact`, verifies agent exec,
HTTP status 200, an explicit `auth_required:true` response, rejection of unauthenticated stats,
and equality between the node's reported SHA-256 and a SHA-256 recomputed from pulled bytes.
Unknown HTTP/auth outcomes and digest mismatches are FAIL, never WARN.

## Disk floor

Measured footprint per repo node: ~1.5 GB (97 MB repo + 656 MB module cache + ~520 MB build
cache + toolchain, plus harness). Floor = repo + harness + 2 GB working room. The ladder reads
free space and refuses below the floor **with the number in the refusal**.

## Failure semantics

- Harness down → layer 20 FAIL; no work is accepted.
- Bus identity missing → layer 30 FAIL; the node is invisible, which is worse than empty.
- Repo dirty at provision time → WARN, not FAIL (the node may be mid-task); `verify` still runs.
- Round trip fails → the node is quarantined; the scheduler must not send it more work.

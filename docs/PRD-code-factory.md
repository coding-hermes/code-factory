# PRD — code-factory

**Goal.** Turn a bare bunker agent into a node that can receive a unit of work, execute it in a
repo with a real harness, and return evidence a stranger can verify — repeatably, without root,
and without a human in the loop.

## Requirements

| ID | Requirement | Verified by |
|---|---|---|
| CF-101 | A node is created by one command from a project + repo + harness triple. | `node-create.sh --project X --repo Y --harness Z` stages the node-side scripts, runs `project-node.sh --apply`, and then invokes `verify-node.sh --artifact ~/.node/node.json`; live success remains an external acceptance gate. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `bash tests/selftest.sh` exits 0 and its controlled missing-`CRIER_URL` fixture exits 1 with named `FAIL` rows and a `NODE: FAIL (N)` summary; a bootstrap error containing the word `FAIL` must not satisfy the fixture. |
| CF-103 | Creation is idempotent; a second run changes nothing. | In a disposable HOME with fixed project/repo/ref/harness inputs, run the apply command twice; the second run exits 0, prints `unchanged` for each reusable layer, and produces byte-identical manifest/repo file hashes. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | Run the supported ladder as a non-root uid with a command trace; require `id -u` nonzero, no `sudo` or `apt` invocation, and every created artifact under the permitted HOME paths. |
| CF-105 | Downloads are pinned and digest-checked before use. | A `fetch_verified` fixture with the expected SHA exits 0; the same fixture with a wrong 64-hex SHA exits nonzero, prints `digest mismatch`, and leaves no destination file. |
| CF-106 | The harness is a parameter, not an assumption. | In separate disposable nodes, run the Hermes and opencode adapter checks and compare the required manifest fields; each adapter must produce an explicit measured result, and an unverified adapter must remain a nonzero refusal rather than count as supported. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | Run `verify-node.sh --artifact` against a produced artifact, independently hash the transferred bytes with `sha256sum`, require equal full digests and exit 0, then mutate one byte and require a nonzero verification result. |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | During disposable provisioning, capture `/proc/<pid>/cmdline` and logs; require exactly one bundle with `stat -c '%a'` equal to `600`, no credential value in argv/logs, and `test ! -e` for the bundle after consumption. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | A deterministic `require_disk` fixture just below the configured floor exits nonzero and prints both measured free space and floor; the boundary at/above the floor exits 0. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | Run the documented destroy command, verify fresh inventory absence, run the documented create command with the same inputs, and require exit 0, a new manifest, and the normal verification command without interactive steps. |
| CF-111 | A node's manifest records project, repo, ref, harness, gateway port, node id, created-by. | Parse `~/.node/node.json` with a checked-in validator and require typed values for `node_id`, `project`, `repo.origin`, `repo.ref`, `harness.name`, `harness.port`, and `created_by`; missing or wrong values exit nonzero. |
| CF-112 | The scheduler can target a node by lane; removing the target returns the lane to the local path with no code change. | Add one target and run one real tick, then remove only that target and run a second real tick; preserve both tick ids and require remote routing first, local routing second, with no source-code change between the two runs. |

## Out of scope (for v1)

- Multi-node scheduling policy (which node gets which lane) — scheduler's job.
- Harness-specific prompt engineering — the harness adapter's job.
- Model selection — task-router's job.

## Acceptance for the first milestone

One project (crier), one node, one directive that travelled over crier and reached a Hermes
gateway, one commit produced there, one artifact digest verified back on the control host, and a
recorded FAIL when the gate is made to fail.

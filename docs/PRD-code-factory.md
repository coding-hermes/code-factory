# PRD — code-factory

**Goal.** Turn a bare bunker agent into a node that can receive a unit of work, execute it in a
repo with a real harness, and return evidence a stranger can verify — repeatably, without root,
and without a human in the loop.

## Requirements

| ID | Requirement | Verified by |
|---|---|---|
| CF-101 | A node is created by one command from a project + repo + harness triple. | `project-node.sh --project X --repo Y --harness Z` exits 0 and writes `node.json`. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `--check` output; a fixture in `tests/selftest.sh` proves FAIL is reachable. |
| CF-103 | Creation is idempotent; a second run changes nothing. | Run twice; second run prints `unchanged` per layer and exits 0. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | The ladder runs as the agent uid; a `sudo`/`apt` call is a test failure. |
| CF-105 | Downloads are pinned and digest-checked before use. | `fetch_verified` refuses a mismatched digest (fixture). |
| CF-106 | The harness is a parameter, not an assumption. | Installing Hermes and installing opencode produce the same node contract. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | `verify-node.sh` exit code + digest comparison. |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | grep of argv/logs; bundle absence after provisioning. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | Boundary test in `tests/selftest.sh`. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | destroy → create → verify green. |
| CF-111 | A node's manifest records project, repo, ref, harness, gateway port, node id, created-by. | `node.json` schema check. |
| CF-112 | The scheduler can target a node by lane; removing the target returns the lane to the local path with no code change. | dispatch-targets.jsonl add/remove, two ticks. |

## Out of scope (for v1)

- Multi-node scheduling policy (which node gets which lane) — scheduler's job.
- Harness-specific prompt engineering — the harness adapter's job.
- Model selection — task-router's job.

## Acceptance for the first milestone

One project (crier), one node, one directive that travelled over crier and reached a Hermes
gateway, one commit produced there, one artifact digest verified back on the control host, and a
recorded FAIL when the gate is made to fail.

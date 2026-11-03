# PRD — code-factory

**Goal.** Turn a bare bunker agent into a node that can receive a unit of work, execute it in a
repo with a real harness, and return evidence a stranger can verify — repeatably, without root,
and without a human in the loop.

## Requirements

Every "Verified by" cell names the command, exit code or number that decides the requirement. A
cell that says **no test** means the repository ships nothing that can fail on that requirement
today; `CF-083` tracks the gap and `docs/ACCEPTANCE-PLAN.md` carries the per-requirement status.
Quoting a green selftest as proof of a requirement it does not exercise is the failure mode this
column exists to prevent.

| ID | Requirement | Verified by |
|---|---|---|
| CF-101 | A node is created by one command from a project + repo + harness triple. | **No test.** `scripts/project-node.sh --apply --project X --repo Y --harness hermes` must exit 0 and leave `$HOME/.node/node.json` parseable. Today the documented create path stages no `scripts/disk_floor.py`, so the run dies at layer 00 before any check (CF-075, point 1 of this row's status); the cell is unproven, not green. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `bash tests/selftest.sh` §2 (exit nonzero with named `  FAIL  tool:` rows — a `FAILED: unbound variable` bootstrap crash is a FAIL of the test itself) and §14 (`NODE: FAIL (n)` equals the printed `  FAIL` row count). No arm covers layers 00, 10, 20, 30 or 40 individually. |
| CF-103 | Creation is idempotent; a second run changes nothing. | **No test.** Required: two `--apply` runs in one fixed `$HOME`; the second exits 0 and `find "$HOME/.node/node.json" "$HOME/repo" -type f -exec sha256sum {} +` is byte-identical across the pair. A second run that rewrites `node.json`'s `created_at` fails. The previous wording ("second run prints `unchanged` per layer") named an output no shipped script emits — `grep -rn unchanged scripts/` returns only two comments. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | **No test.** No `sudo`/`apt` gate exists in the tree (`grep -rniE 'sudo|apt-get' tests/` = 0 hits), so the requirement is currently unfalsifiable. Required: a committed check that fails on uid 0 or on any `sudo`/`apt` invocation in the ladder transcript, plus a red arm that plants one. |
| CF-105 | Downloads are pinned and digest-checked before use. | `bash tests/selftest.sh` §5: `fetch_verified` accepts the matching sha256 and refuses the all-zero digest (both arms must appear as `  PASS`). Covers the helper only — no installer's own download is audited. |
| CF-106 | The harness is a parameter, not an assumption. | **No test.** A pass requires every row of `specs/HARNESS.md#the-contract` to be exercised for two adapters and printed as `PASS` with its value. Only `hermes` is measured; `opencode` `--apply` refuses by design, so this requirement cannot pass today and must not be reported as satisfied. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | **No test.** Required: `scripts/verify-node.sh --agent A --server S --port P --artifact PATH` exits 0 with matching 64-hex digests, and exits nonzero after one byte of the pulled artifact is mutated. A node-reported digest alone is never a pass (`specs/ENVELOPE.md`, `AGENTS.md` rule 10). |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | **No test.** `tests/selftest.sh` §6 only greps for literal `KEY=` assignments in the tree; it proves nothing about argv, logs, mode or deletion. Required: `stat -c '%a' <bundle>` = `600`, zero occurrences of the synthetic value in the provisioning transcript and `/proc/<pid>/cmdline`, and `test ! -e <bundle>` after provisioning. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | **Partial test.** `bash tests/selftest.sh` §12 (floor resolution and malformed-value refusal) and §13 (`FAIL disk-floor` before any install). The **below-floor boundary is untested** — no arm forces free space under the floor and asserts the refusal names both the measured free space and the floor. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | **No test — and no destroy path ships** (`grep -rn destroy scripts/*.sh` = 0 hits), so the requirement is unsatisfiable in v1. Blocked on CF-008; until that lands this row must be reported BLOCKED, never PASS. |
| CF-111 | A node's manifest records project, repo, ref, harness, gateway port, node id, created-by. | **No test, and the field list contradicted `specs/NODE.md`.** The spec's manifest requires ten fields — `node_id`, `project`, `repo.{origin,ref,path}`, `harness.{name,version,port}`, `bus.{agent_id,base}`, `created_by`, `created_at` — and the spec is the design authority (`AGENTS.md` rule 1), so this row now names the same ten. Required: a parse-and-assert check over `$HOME/.node/node.json` that fails naming each absent key; none ships today (`grep -rln node.json tests/` = 0) and the writer currently omits two of them (CF-078). |
| CF-112 | The scheduler can target a node by lane; removing the target returns the lane to the local path with no code change. | **No test.** The requirement names `dispatch-targets.jsonl`, but no script or test references that file (`grep -rl dispatch-targets scripts tests` = 0 hits) — the artifact does not exist in the shipped code. Required: add the target, run one real tick and record its id plus the delivered directive; remove it, run a second real tick, and show the lane ran locally with `git diff` on the repo empty between the two ticks. |

## Out of scope (for v1)

- Multi-node scheduling policy (which node gets which lane) — scheduler's job.
- Harness-specific prompt engineering — the harness adapter's job.
- Model selection — task-router's job.

## Acceptance for the first milestone

One project (crier), one node, one directive that travelled over crier and reached a Hermes
gateway, one commit produced there, one artifact digest verified back on the control host, and a
recorded FAIL when the gate is made to fail.

**Status 2026-11-03 (measured at `400a5ab`): NOT MET.** Nothing in this paragraph has been
observed end to end, and three legs are blocked by open defects rather than by environment:
the documented creation path dies at layer 00 because the staging list predates
`scripts/disk_floor.py` (CF-075); `--apply` clones the repo after the bus layer has already failed
(CF-080); and `verify-node.sh` reports `VERIFY: PASS` on an inconclusive auth probe (CF-077), so a
"verified" node can carry an unproven identity. `docs/ACCEPTANCE-PLAN.md` records per-requirement
state; its summary is the authority for what has actually run.

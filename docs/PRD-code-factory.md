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
| CF-101 | A node is created by one command from a project + repo + harness triple. | **No test.** `scripts/project-node.sh --apply --project X --repo Y --harness hermes` must exit 0 and leave `$HOME/.node/node.json` parseable. The staging gap that used to kill this path at layer 00 is closed (`CF-075`, commit `77caa02`; selftest §16 runs `node-create.sh --staged-files` and the staged entry point, and fails when `scripts/disk_floor.py` is dropped from the manifest), so nothing shipped dies there any more — but no end-to-end creation is recorded either. The open defect on this path is `CF-080` (`--apply` clones after the bus layer has already failed), so the cell is unproven, not green. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `bash tests/selftest.sh` §2 (exit nonzero with named `  FAIL  tool:` rows — a `FAILED: unbound variable` bootstrap crash is a FAIL of the test itself) and §14 (`NODE: FAIL (n)` equals the printed `  FAIL` row count). Per-layer arms, measured at `80fca8b`: layer 00 by §3 (`--layers 00`, exactly one `FAIL reach:` row) and §20 (apply-mode reclaim-then-refuse), layer 20 by §14 (`--layers 20`), layer 40 by §4/§4b (`--layers 40`), layer 30 only inside §15's `--layers 30,40` pair. **Layer 10 (base) has no arm**, and nothing asserts the layer 90 verify row, so the requirement is PARTIAL, never satisfied. |
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

**Status 2026-11-03 (re-measured at `80fca8b`): NOT MET.** No crier directive has been observed
arriving at a gateway, no commit has been produced on a node, and no artifact digest has been
recomputed on the control host, so nothing in the paragraph above is demonstrated end to end.
Two of the three defects the previous status cited were closed after its `400a5ab` measurement and
are no longer blockers: `CF-075` (the documented create path staged no `scripts/disk_floor.py`, so
it died at layer 00 — fixed in `77caa02`, proven by selftest §16) and `CF-077` (an inconclusive auth
probe still reported `VERIFY: PASS` — fixed in `1232f7a`, proven by §17 and §18). The confirmed
open defects on this path are `CF-080` (`--apply` clones the workspace after the bus layer has
already FAILED, manufacturing the repo-with-no-bus node `AGENTS.md` rule 9 forbids) and the
never-exercised legs `CF-001` (scheduler→crier dispatch is built but has never run), `CF-004` (no
round trip through the node's own gateway), `CF-110` (no destroy path ships) and `CF-112` (no
`dispatch-targets.jsonl` consumer ships). `docs/ACCEPTANCE-PLAN.md` records per-requirement state;
its summary is the authority for what has actually run.

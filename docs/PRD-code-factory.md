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
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `bash tests/selftest.sh` §2 (exit nonzero with named `  FAIL  tool:` rows — a `FAILED: unbound variable` bootstrap crash is a FAIL of the test itself) and §14 (`NODE: FAIL (n)` equals the printed `  FAIL` row count). Per-layer arms, measured at `f49d85b`: layer 00 by §3 (`--layers 00`, exactly one `FAIL reach:` row) and §20 (apply-mode reclaim-then-refuse), layer 20 by §14 (`--layers 20`), layer 40 by §4/§4b (`--layers 40`), layer 30 only inside §15's `--layers 30,40` pair. **Layer 10 (base) has no arm** (`grep -n 'layers 10' tests/selftest.sh` = 0 hits at `f49d85b`), and nothing asserts the layer 90 verify row (`grep -n 'layer 90' tests/selftest.sh` = 0 hits), so the requirement is PARTIAL, never satisfied: a PASS needs one arm per layer 00/10/20/30/40/90, each running `scripts/project-node.sh --layers NN` and printing exactly the FAIL rows `specs/NODE.md` specifies for that layer. |
| CF-103 | Creation is idempotent; a second run changes nothing. | **No test.** Required: two `--apply` runs in one fixed `$HOME`; the second exits 0 and `find "$HOME/.node/node.json" "$HOME/repo" -type f -exec sha256sum {} +` is byte-identical across the pair. A second run that rewrites `node.json`'s `created_at` fails. The previous wording ("second run prints `unchanged` per layer") named an output no shipped script emits — `grep -rn unchanged scripts/` returns only two comments. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | **No test.** No `sudo`/`apt` gate exists in the tree (`grep -rniE 'sudo\|apt-get' tests/` = 0 hits, `grep -rn 'id -u' tests/ scripts/` = 0 hits at `f49d85b`), so the requirement is currently unfalsifiable. Required: a committed check that exits nonzero on uid 0 and on any `sudo`/`apt` line in the ladder transcript it is handed, plus a red arm in `tests/selftest.sh` that plants one (a transcript file containing `sudo apt-get install x`, and a stubbed `id -u` printing `0`) and asserts the named `  FAIL  no-root:` row; today neither the check nor the stub exists. |
| CF-105 | Downloads are pinned and digest-checked before use. | `bash tests/selftest.sh` §5: `fetch_verified` accepts the matching sha256 and refuses the all-zero digest (both arms must appear as `  PASS`). Covers the helper only — no installer's own download is audited. |
| CF-106 | The harness is a parameter, not an assumption. | **No test.** A pass requires every row of `specs/HARNESS.md#the-contract` to be exercised for two adapters and printed as `PASS` with its value. Only `hermes` is measured; `opencode` `--apply` refuses by design, so this requirement cannot pass today and must not be reported as satisfied. Two falsifiable legs decide it: `bash scripts/harness/install-opencode.sh --check` and `bash scripts/harness/install-hermes.sh --check` must each print the same contract row set, every row `PASS`, and exit nonzero while any row is `WARN`/`FAIL`. Neither holds at `f49d85b`: the adapters' verdict line counts `FAIL` rows only, so a stubbed-PATH run prints `OPENCODE: PASS` and exits 0 beside two `WARN` rows (`CF-141`), and on this host `install-hermes.sh --check` exits 1 printing `FAIL python — … found 3.14.9` with no verdict line at all. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | **No test.** Required: `scripts/verify-node.sh --agent A --server S --port P --artifact PATH` exits 0 with matching 64-hex digests, and exits nonzero after one byte of the pulled artifact is mutated. A node-reported digest alone is never a pass (`specs/ENVELOPE.md`, `AGENTS.md` rule 10). |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | **No test.** `tests/selftest.sh` §6 only greps for literal `KEY=` assignments in the tree; it proves nothing about argv, logs, mode or deletion. Required: `stat -c '%a' <bundle>` = `600`, zero occurrences of the synthetic value in the provisioning transcript and `/proc/<pid>/cmdline`, and `test ! -e <bundle>` after provisioning. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | **Partial test.** `bash tests/selftest.sh` §12 (floor resolution and malformed-value refusal) and §13 (`FAIL disk-floor` before any install). The **below-floor boundary is untested** — no arm forces free space under the floor and asserts the refusal names both the measured free space and the floor. The arm is cheap and needs no real disk: `free_gb` is `df -Pk "$1" | awk 'NR==2{printf "%.1f", $4/1048576}'` (`scripts/lib.sh:32`), so a PATH-local `df` stub whose second line carries `1048576` in column 4 must make `bash -c '. scripts/lib.sh; require_disk . 5'` exit 1 and print exactly `  FAIL  disk — 1.0 GB free < floor 5 GB at .` (measured at `f49d85b` with that stub), while the same stub at `5242880` (5.0 GB) must print the `PASS disk` row and exit 0. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | **No test — and no destroy path ships** (`grep -rn destroy scripts/*.sh` = 2 hits at `bc68e59`, both advisory rather than code paths: the comment at `scripts/node-create.sh:12` and the `printf 'cleanup required: bunker destroy …'` at `:54`, which hands the operator a manual command instead of destroying anything), so the requirement is unsatisfiable in v1. Blocked on CF-008; until that lands this row must be reported BLOCKED, never PASS. |
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

**Status 2026-11-04T07:38Z (board re-measured at `bc68e59` — 148 task rows, 273 events: 49 complete,
8 in_progress, 91 pending; the node-run evidence below is the 02:35Z measurement at `d02916e`): NOT MET.** One leg moved since the `80fca8b`
measurement: a directive is now recorded arriving at a node and executing there. The dispatch at
19:37:51 handed the node the envelope itself as its prompt (`CF-139`, P0, open), and two later node
runs ended `exit 124` at a 32.1 s caller-derived kill instead of the old 243.4 s constant, with the
node's inbox empty afterwards (`CF-137`, `CF-138`, both `in_progress` pending a resolvable verdict).
Those runs are the board's and the implementing commits' record; no re-runnable control-host proof of
them ships in this repository, so the leg is named, not certified. Still absent: a commit produced on
a node, an artifact digest recomputed from pulled bytes on the control host, and a recorded FAIL from
a deliberately broken gate there. `CF-075` and `CF-077` remain closed (`77caa02` + selftest §16;
`1232f7a` + §17/§18). The other row this list gained on 2026-11-04, the node-create `CRIER_URL` gap
`CF-126`, was closed at `85f852b` on the `dd7f64bc` verdict, so it is not listed among the blockers.
Rows that are open, leg-adjacent and deliberately EXCLUDED from the blocker list, one clause each so membership stays decidable at `bc68e59`: `CF-162` (verify-node.sh has no bus leg) and `CF-163` (the public `master` lineage) stop none of the four legs and stay board-only, as do the three rows the dogfood lane filed after the `1aeb0c7` measurement — `CF-172` (a layer-40 message tells the caller to pass `--repo` it already passed), `CF-173` (the layer-00 reach probe records `000` when `--max-time` cuts a transfer, so a URL that answered 200 reads unreachable) and `CF-174` (a harness `version` row prints `PASS` with an empty measurement). Every other open row is outside these legs by subject — v1-scope features (`CF-003`, `CF-006`), node sizing (`CF-007`), scheduler throughput (`CF-134`) and the repository/tooling rows below `P1`. The open defects this milestone's legs depend on are `CF-080` (`--apply` clones
the workspace after the bus layer has already FAILED, manufacturing the repo-with-no-bus node
`AGENTS.md` rule 9 forbids), the never-exercised legs `CF-001` (scheduler→crier dispatch has never
completed a full arm/tick cycle), `CF-004` (no round trip through the node's own gateway), `CF-110`
(no destroy path ships) and `CF-112` (no `dispatch-targets.jsonl` consumer ships), one row that stops
a leg and was missing from this list before 2026-11-04 — `CF-002` (P0: a node turn dies at
`agent init failed: No inference provider configured`, so the "commit produced on a node" leg cannot
be reached) — plus the dispatch
defects the live runs exposed: `CF-131` (a completion reply that echoes the task body is refused
`403 GUARD_BLOCKED`), `CF-132` (no receive-side idempotency key), `CF-133` (a result dialect
`specs/ENVELOPE.md` does not define), `CF-136` (a dispatch row never reaches a terminal state when its
tick times out), `CF-137` (a failed dispatch is never acked, so it redelivers the same failure
forever) and `CF-138` (the dispatcher still kills a real task on a caller-derived timeout — 32.1 s in
the 02:35Z runs; the old 243 s constant the row's title names is in no shipped file, `grep -rn '243'
scripts/ specs/` = 0 hits) far below the 15 m 40 s the scheduler budgets for the same tick — then
`CF-139`, and one row this re-measure added: `CF-150` (the documented create path stages no
`dashboard.basic_auth`, so `install-hermes.sh:112` refuses the public bind and a node created by the
documented path never starts the gateway the directive leg has to reach. Reproduced 2026-11-04T06:13Z:
`installer_basic_auth=3 create_path_basic_auth=scripts/node-create.sh:0,scripts/project-node.sh:0,`
plus `refused: a public bind needs dashboard.basic_auth`, probe exit 0). The list is decidable, not editorial: read
`jq -r 'select(.status!="complete") | [.id,.priority] | @tsv' .coding-hermes/board/tasks.jsonl`, then
require every open row whose failure stops one of the four legs named above to appear here; rows
outside those legs (v1 scope features such as foreign harnesses or the deploy-key lane) belong to the
board, not the milestone. The milestone cannot be claimed while any row above is open.
`docs/ACCEPTANCE-PLAN.md` records per-requirement state; its summary is the authority for what has
actually run.

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

The `ID` column is a **requirement namespace**, not the board's task-id namespace. `CF-101`–`CF-112`
identify requirements in this document. That the two namespaces are disjoint is **no longer true**:
at `171bf23` the board carried no row for them (`jq -r 'select(.id=="CF-110") | .id'` printed
nothing), but at `9f7cd648` (2026-11-20) it carries one row per id for the four ids this tick
checked — `CF-101`, `CF-102`, `CF-104` `pending`, `CF-110` `blocked` — so the same spelling now
resolves to a requirement cell *and* a board row, and the `jq` command above prints `CF-110`
instead of nothing. A citation must therefore name its namespace in words ("requirement `CF-104`"
vs "row `CF-104`"); the gate arm `CF-182` owns cannot lean on id shape, only on an explicit
namespace tag. An id that resolves to neither a row nor a row of the table below is still drift.

| ID | Requirement | Verified by |
|---|---|---|
| CF-101 | A node is created by one command from a project + repo + harness triple. | **No test.** `scripts/project-node.sh --apply --project X --repo Y --harness hermes` must exit 0 and leave `$HOME/.node/node.json` parseable. The staging gap that used to kill this path at layer 00 is closed (`CF-075`, commit `77caa02`; selftest §16 runs `node-create.sh --staged-files` and the staged entry point, and fails when `scripts/disk_floor.py` is dropped from the manifest), so nothing shipped dies there any more — but no end-to-end creation is recorded either. The open defect on this path is `CF-080` (`--apply` clones after the bus layer has already failed), so the cell is unproven, not green. |
| CF-102 | Every layer reports `PASS`/`FAIL` with the value it measured. | `bash tests/selftest.sh` §2 (exit nonzero with named `  FAIL  tool:` rows — a `FAILED: unbound variable` bootstrap crash is a FAIL of the test itself) and §14 (`NODE: FAIL (n)` equals the printed `  FAIL` row count). Per-layer arms, measured at `f49d85b`: layer 00 by §3 (`--layers 00`, exactly one `FAIL reach:` row) and §20 (apply-mode reclaim-then-refuse), layer 20 by §14 (`--layers 20`), layer 40 by §4/§4b (`--layers 40`), layer 30 only inside §15's `--layers 30,40` pair. **Layer 10 gained arms**: `grep -n 'layers 10' tests/selftest.sh` = 8 hits at `9f7cd648` (2026-11-20), up from 0 at `f49d85b`, each one a `project-node.sh --check --layers 10` invocation (three of them adding `--kinds`). **Layer 90 is still unasserted**: `grep -n 'layer 90' tests/selftest.sh` = 1 hit at `9f7cd648`, and that hit is the `CF-289` comment at `tests/selftest.sh:5195`, not an arm. So the requirement is still PARTIAL, never satisfied: a PASS needs one arm per layer 00/10/20/30/40/90, each running `scripts/project-node.sh --layers NN` and printing exactly the FAIL rows `specs/NODE.md` specifies for that layer. |
| CF-103 | Creation is idempotent; a second run changes nothing. | **No test.** Required: two `--apply` runs in one fixed `$HOME`; the second exits 0 and `find "$HOME/.node/node.json" "$HOME/repo" -type f -exec sha256sum {} +` is byte-identical across the pair. A second run that rewrites `node.json`'s `created_at` fails. The previous wording ("second run prints `unchanged` per layer") named an output no shipped script emits — `grep -cE '(PASS|FAIL|WARN|SKIP).*unchanged' scripts/project-node.sh` = 0 at `2f07051`. A tree-wide `grep -rn unchanged scripts/` is NOT a usable measure of this cell: it returns 8 non-comment hits from unrelated tooling (`node_identity.py`, `bunker_config_gen.py`, `install-codex.sh`), which is why the citation is file- and predicate-scoped. |
| CF-104 | No root, no apt: all artifacts user-space under `$HOME`. | **No test.** No `sudo`/`apt-get` gate exists in the tree — `grep -rniE 'sudo\|apt-get' tests/` = 0 hits at `9f7cd648` (2026-11-20) — and the root refusal is only partial: `grep -rn 'id -u' tests/ scripts/` = 4 hits at `9f7cd648`, up from 0 at `f49d85b`, of which three are real `[ "$(id -u)" -eq 0 ]` refusals (`scripts/harness/install-dsh.sh:750`, `scripts/harness/install-claude-code.sh:460` and `:527`) and the fourth is a `SKIP` message at `tests/selftest.sh:2528` that prints the uid without gating anything. None of the three inspects a ladder transcript for `sudo`/`apt` lines, and no arm exercises them with a stubbed `id -u`. Required: a committed check that exits nonzero on uid 0 and on any `sudo`/`apt` line in the ladder transcript it is handed, plus a red arm in `tests/selftest.sh` that plants one (a transcript file containing `sudo apt-get install x`, and a stubbed `id -u` printing `0`) and asserts the named `  FAIL  no-root:` row; today neither the transcript check nor the stub exists, so the requirement is unproven. |
| CF-105 | Downloads are pinned and digest-checked before use. | `bash tests/selftest.sh` §5: `fetch_verified` accepts the matching sha256 and refuses the all-zero digest (both arms must appear as `  PASS`). Covers the helper only — no installer's own download is audited. |
| CF-106 | The harness is a parameter, not an assumption. | **No test.** A pass requires every row of `specs/HARNESS.md#the-contract` to be exercised for two adapters and printed as `PASS` with its value. Only `hermes` is measured; `opencode` `--apply` refuses by design, so this requirement cannot pass today and must not be reported as satisfied. The verdict half is tested: `bash tests/selftest.sh` §59 arms (a)–(c) drive one stub adapter whose only difference is its row counts — `WARN` → `UNVERIFIED` exit 3, `FAIL` → `FAIL (n)` exit 1, all-`PASS` → `PASS` exit 0 — and the same section runs the `CF-141` probe against the real `install-opencode.sh --check` (PATH stub, two `WARN` rows → `OPENCODE: UNVERIFIED`, not `PASS`), the pre-fix adapter at `d4f2600` on the same fixture as the red control, the verdict every shipped adapter's `--check` actually prints against its own row counts, and the `install-hermes.sh` interpreter refusal ending `HERMES: FAIL (1)` instead of exiting with no summary. `specs/HARNESS.md` "The verdict line" is the vocabulary's authority. What remains open is the row-set half: the two legs (`install-opencode.sh --check`, `install-hermes.sh --check`) do not yet print the same contract row set, every row `PASS`. |
| CF-107 | A node proves itself with a round trip whose artifact digest is recomputed on the control host. | **No test.** Required: `scripts/verify-node.sh --agent A --server S --port P --artifact PATH` exits 0 with matching 64-hex digests, and exits nonzero after one byte of the pulled artifact is mutated. A node-reported digest alone is never a pass (`specs/ENVELOPE.md`, `AGENTS.md` rule 10). |
| CF-108 | Credentials arrive as one bundle, mode 600, never as an argument; deleted after use. | **No test.** `tests/selftest.sh` §6 only greps for literal `KEY=` assignments in the tree; it proves nothing about argv, logs, mode or deletion. Required: `stat -c '%a' <bundle>` = `600`, zero occurrences of the synthetic value in the provisioning transcript and `/proc/<pid>/cmdline`, and `test ! -e <bundle>` after provisioning. |
| CF-109 | A node refuses work below a measured disk floor, naming the number. | **Partial test.** `bash tests/selftest.sh` §12 (floor resolution and malformed-value refusal) and §13 (`FAIL disk-floor` before any install). The **below-floor boundary is untested** — no arm forces free space under the floor and asserts the refusal names both the measured free space and the floor. The arm is cheap and needs no real disk: `free_gb` is `df -Pk "$1" | awk 'NR==2{printf "%.1f", $4/1048576}'` (`scripts/lib.sh:32`), so a PATH-local `df` stub whose second line carries `1048576` in column 4 must make `bash -c '. scripts/lib.sh; require_disk . 5'` exit 1 and print exactly `  FAIL  disk — 1.0 GB free < floor 5 GB at .` (measured at `f49d85b` with that stub), while the same stub at `5242880` (5.0 GB) must print the `PASS disk` row and exit 0. |
| CF-110 | Destroying a node and re-running creation reproduces it with no manual step. | **No test — and the destroy path that ships is for the wrong object.** `grep -rn destroy scripts/*.sh` = 13 hits at `9f7cd648` (2026-11-20), up from 2 at `bc68e59`. Of those, one is a real code path: `scripts/bunker-provision.sh:679` defines `destroy()`, refuses without `--yes` (`:681`), and dispatches `bunker destroy "$AGENT" --server "$SERVER"` at `:686`, reachable from the `destroy)` arm at `:753`. It destroys a **bunker agent**, not the node `node-create.sh` builds, and `scripts/node-create.sh:173` still prints `cleanup required: bunker destroy …`, handing the operator a manual command instead of destroying anything. So the requirement is unsatisfiable in v1 and still blocked — now on wiring the node teardown to the shipped agent-destroy path, not on the absence of any destroy path. Blocked on CF-008; until that lands this row must be reported BLOCKED, never PASS. |
| CF-111 | A node's manifest records project, repo, ref, harness, gateway port, node id, created-by. | **No test, and the field list contradicted `specs/NODE.md`.** The spec's manifest requires ten fields — `node_id`, `project`, `repo.{origin,ref,path}`, `harness.{name,version,port}`, `bus.{agent_id,base}`, `created_by`, `created_at` — and the spec is the design authority (`AGENTS.md` rule 1), so this row now names the same ten. Required: a parse-and-assert check over `$HOME/.node/node.json` that fails naming each absent key; none ships today — `grep -rn 'bus\.agent_id\|harness\.port\|repo\.ref' tests/` = 0 at `2f07051`. A `grep -rln node.json tests/` is NOT a usable measure of this cell: it now returns hits only because other arms write fixture manifests under that name (`node_identity.py`'s namespace edit, the bus worker's fixtures), and none of them asserts a single one of the ten fields. The writer currently omits two of them (CF-078). |
| CF-112 | The scheduler can target a node by lane; removing the target returns the lane to the local path with no code change. | **No test.** The requirement names `dispatch-targets.jsonl`, but no script or test references that file (`grep -rl dispatch-targets scripts tests` = 0 hits) — the artifact does not exist in the shipped code. Required: add the target, run one real tick and record its id plus the delivered directive; remove it, run a second real tick, and show the lane ran locally with `git diff` on the repo empty between the two ticks. |

## Out of scope (for v1)

- Multi-node scheduling policy (which node gets which lane) — scheduler's job.
- Harness-specific prompt engineering — the harness adapter's job.
- Model selection — task-router's job.

## Acceptance for the first milestone

One project (crier), one node, one directive that travelled over crier and reached a Hermes
gateway, one commit produced there, one artifact digest verified back on the control host, and a
recorded FAIL when the gate is made to fail.

**Status 2026-11-21T10:57Z (board re-measured at `fc26da9b` — 604 task rows, 962 events: 209
complete, 16 in_progress, 4 blocked, 375 pending): NOT MET, and the three legs are still absent —
re-scanned rather than re-asserted.** The scan behind the 2026-11-20 paragraph was re-run at
`fc26da9b` over the title and acceptance criteria of all 209 `complete` rows for the three legs. It
returned seven hits and each was read: `CF-013` and `CF-202` are absence findings that *name* the
missing digest recomputation, `CF-302` and `CF-315` are the commit-attribution rows, `CF-396` and
`CF-443` match the word "broken" in an unrelated sense, and `P5G-12` is the release-manifest
specification. None is a commit produced on a node, none recomputes an artifact digest from pulled
bytes on the control host, and none records a FAIL from a gate deliberately made to fail. So the leg
status is unchanged, and is now stated with the hits that were inspected and rejected rather than by
absence of evidence. The thirteen blocker rows keep their 2026-11-20 statuses at `fc26da9b`:
`CF-001`, `CF-002`, `CF-004`, `CF-136`, `CF-137`, `CF-138`, `CF-139` `in_progress`; `CF-080`,
`CF-131`, `CF-132`, `CF-133` `pending`; `CF-110`, `CF-112` `blocked`.

**`complete` does not mean gradable, and this paragraph measures the legs accordingly.** At
`fc26da9b`, 41 of 209 `complete` rows (19%) and 136 of 375 `pending` rows (36%, 31 of them P0/P1)
carry acceptance criteria containing no command, path, exit code or number — text a reader can agree
with but nobody can re-run. The `P5G` specification wave is the worst case: 33 of its 38 rows carry
the same three-clause prose ("the normative specification answers this question explicitly"), and 14
of them (`P5G-01`, `-02`, `-03`, `-04`, `-06`, `-07`, `-08`, `-10`, `-11`, `-12`, `-13`, `-14`,
`-15`, `-16`) were closed `complete` on it. Those rows are a record of what the wave's authors
believed, not evidence that the specification exists; certifying the milestone means reading the
chapter, never counting the row. This tick converted `P5G-17` through `P5G-33` — the 17 `pending` P1
rows in that wave — from prose into four re-runnable arms: the cited chapter contains a section that
names the row id (`grep -c 'P5G-17' <chapter>` >= 1) and carries the five labelled lines `Actor:`,
`Data shape:`, `Ordering:`, `Failure behavior:`, `Recovery rule:`; the section ships one deterministic
artifact plus the command that validates it and its exit code; every repository path it cites resolves
(`test -e` on each extracted path prints nothing); and the section pins the version or commit it was
measured against. The row is not tightened because the text reads better — it is tightened because a
stranger can run those four checks and get an answer. Left for later ticks: 119 bare `pending` rows
and the 41 bare `complete` ones, which are a measurement problem (nothing can re-open them
mechanically) before they are a documentation problem.

**Status 2026-11-20T07:12Z (board re-measured at `9f7cd648` — 590 task rows, 930 events: 195
complete, 16 in_progress, 4 blocked, 375 pending): NOT MET, and the three legs the 2026-11-04
paragraph names as absent are still absent.** Checked by scanning every `complete` row at
`9f7cd648` for the three legs: no complete row is a commit produced on a node, no complete row
recomputes an artifact digest from pulled bytes on the control host, and no complete row records a
FAIL from a deliberately broken gate. The nearest rows and why each falls short: `CF-315`
(`1d2c889d`) makes a node commit *attributable* — `Run-Id:` trailer plus the selftest §42 proof —
but no node has produced one; `CF-302` hardens the lander's refusal of an unattributed branch, not
the digest round trip; `CF-110` stays `blocked` on node teardown. The counts and prose in the
2026-11-04 paragraph below still reproduce at the tips it names; it is superseded only where this
paragraph measures a changed tree. It supersedes the 2026-11-04 blocker leg in measurement, not in
membership: the open defects these three legs still depend on are `CF-001`, `CF-002`, `CF-004`,
`CF-136`, `CF-137`, `CF-138` and `CF-139` (`in_progress`), `CF-080`, `CF-131`, `CF-132` and
`CF-133` (`pending`), and `CF-110` and `CF-112` (`blocked`) — all thirteen re-checked on the board
at `0d50d6f0`, none `complete`, and the closed-membership reasons in the 2026-11-04 list below still
stand.

**Status 2026-11-04T09:34Z (board re-measured at `aef18d2` — 161 task rows, 322 events: 54 complete,
8 in_progress, 99 pending; the previous snapshots still reproduce at the tips they name — `171bf23`
carried 158 rows / 308 events at 52/8/98 and `bc68e59` 148 / 273 at 49/8/91; the node-run evidence
below is the 02:35Z measurement at `d02916e`): NOT MET.** One leg moved since the `80fca8b`
measurement: a directive is now recorded arriving at a node and executing there. The dispatch at
19:37:51 handed the node the envelope itself as its prompt (`CF-139`, P0, open), and two later node
runs ended `exit 124` at a 32.1 s caller-derived kill instead of the old 243.4 s constant, with the
node's inbox empty afterwards (`CF-137`, `CF-138`, both `in_progress` pending a resolvable verdict).
Those runs are the board's and the implementing commits' record; no re-runnable control-host proof of
them ships in this repository, so the leg is named, not certified. Still absent: a commit produced on
a node, an artifact digest recomputed from pulled bytes on the control host, and a recorded FAIL from
a deliberately broken gate there. `CF-075` and `CF-077` remain closed (`77caa02` + selftest §16;
`1232f7a` + §17/§18) — with one reader trap disclosed rather than hidden: `CF-077`'s verdict artifact
(`.gitreins/history/2026-11-03/410022a2/verdict.json`) binds `1dfb58b8`, the pre-rewrite copy of the
same fix, and no branch contains that object; the closure stands on the row's `commit_hash`
`1232f7a`, which is an ancestor of `origin/main` (`CF-181`, open, owns the repair of that pointer). The other row this list gained on 2026-11-04, the node-create `CRIER_URL` gap
`CF-126`, was closed at `85f852b` on the `dd7f64bc` verdict, so it is not listed among the blockers.
Rows that are open, leg-adjacent and deliberately EXCLUDED from the blocker list, one clause each so membership stays decidable at `aef18d2`: `CF-162` (verify-node.sh has no bus leg) and `CF-163` (the public `master` lineage) stop none of the four legs and stay board-only, as do the three rows the dogfood lane filed after the `1aeb0c7` measurement — `CF-172` (a layer-40 message tells the caller to pass `--repo` it already passed), `CF-173` (the layer-00 reach probe records `000` when `--max-time` cuts a transfer, so a URL that answered 200 reads unreachable) and `CF-174` (a harness `version` row prints `PASS` with an empty measurement) — plus `CF-183` (the
adapter certified any `hermes` on `PATH` as the pin, so the harness-identity row could not fail; it
CLOSED at `5069c0a` on verdict `a539f890`, so it is no longer an open row and leaves this list — the
reason it was never a leg blocker stands: the directive leg needs a gateway that answers, not a
certified pin). The list is open rows only, and that is checkable rather than editorial:
`jq -r 'select(.id=="CF-183")|.status' .coding-hermes/board/tasks.jsonl` printed `complete` at
`aef18d2`, which is why it moved here. Every other open row is outside these legs by subject — v1-scope features (`CF-003`, `CF-006`), node sizing (`CF-007`), scheduler throughput (`CF-134`) and the repository/tooling rows below `P1`.
<!-- milestone-blockers:begin -->
The open defects this milestone's legs depend on are `CF-080` (`--apply` clones
the workspace after the bus layer has already FAILED, manufacturing the repo-with-no-bus node
`AGENTS.md` rule 9 forbids), the never-exercised legs `CF-001` (scheduler→crier dispatch has never
completed a full arm/tick cycle), `CF-004` (no round trip through the node's own gateway), requirement
`CF-110` (no destroy path ships — a requirement id from the table above, which also carries a board row
of the same id; the row is `blocked`, so this id now resolves as `row=blocked`, not as a
requirement with no row) and requirement `CF-112` (no `dispatch-targets.jsonl` consumer ships —
likewise both a requirement row and a `blocked` board row, never `complete`), one row that stops
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
`CF-139`.
<!-- milestone-blockers:end -->

Closed since this list was written (`row=complete`, so it is no longer a blocker and the check
rejects a citation of it): `CF-150` — the documented create path staged no `dashboard.basic_auth`, so
`install-hermes.sh` refused the public bind and a node created by the documented path never started
the gateway the directive leg has to reach (reproduced 2026-11-04T06:13Z:
`installer_basic_auth=3 create_path_basic_auth=scripts/node-create.sh:0,scripts/project-node.sh:0,`
plus `refused: a public bind needs dashboard.basic_auth`, probe exit 0). Closed 2026-11-07: layer 20
of `scripts/project-node.sh` runs the staged `scripts/node_gateway_auth.py` before the adapter, and
`tests/selftest.sh` §55 holds the refusal and the staged-block pass as a pair.
The list is decidable, not editorial: every id cited in it resolves to exactly one of two
namespaces — `row=<status>` from `jq -r 'select(.id=="<id>") | .status' .coding-hermes/board/tasks.jsonl`,
or `requirement-only` when the id names a row of the requirements table above and no board row carries
it (at `171bf23`: `CF-110` and `CF-112`, which had never been rows). That rule stands; what changed on
2026-11-16 under CF-421 is which namespace those two fall in — each requirement now owns a board row of
its own id, so `CF-110` and `CF-112` resolve `row=blocked` and no id in the list is requirement-only any
more. The check is `bash docs/audits/prd-blocker-resolution.sh`: it prints `row=<status>` or `requirement-only` for every id in the list above and exits 0 only when each resolves, is still open, and carries a `Verified by` cell. Then read
`jq -r 'select(.status!="complete") | [.id,.priority] | @tsv' .coding-hermes/board/tasks.jsonl`, and
require every open row whose failure stops one of the four legs named above to appear here; rows
outside those legs (v1 scope features such as foreign harnesses or the deploy-key lane) belong to the
board, not the milestone. The milestone cannot be claimed while any row above is open.
`docs/ACCEPTANCE-PLAN.md` records per-requirement state; its summary is the authority for what has
actually run.

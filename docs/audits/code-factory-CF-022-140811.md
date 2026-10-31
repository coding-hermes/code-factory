# CF-022 — satellite alignment audit and tested local tranche

STATUS: partial. TIER: T3 for invoked local tests only.

The repository now has a rerunnable read-only lane audit, safe JSON evidence,
15 hermetic CLI tests wired into selftest, and a verification/sync-consumption
contract. No live scheduler fields, lane enablement, boards, namespaces, sync
workdirs, services, cron jobs or scheduler source were changed. CF-022's original
alignment acceptance remains open; this report is not a live repair receipt.

## Identity and evidence scope

- Control/implementation branch: `wt/CF-022-140811`.
- Verified starting HEAD/base: `27a6725226abc50df2d578eb74f60ebb8721d6aa`.
- Published integration target: `feat/code-factory-bankai-20261030`, not `main`.
- Requested/runtime-reported seat: `gpt-6.1-sol` / `openai-codex`. This is not a
  claim of independently attested remote served identity.
- Live observations: 2026-10-30; safe census timestamp is embedded in
  [the lane snapshot](code-factory-CF-022-140811-lanes.json). Reads are sequential,
  not an atomic DB/API/filesystem transaction; rerun before any later repair.
- Trusted scheduler checkout revision inspected:
  `6d135f1c7daaf7c2f542f4cbae75e16eeb29ca29`. Its checker source hash is in the snapshot.
- Paths below are normalized: `$HERMES_HOME` is the operator's Hermes state
  directory; `$PROJECT_ROOT` is the live primary's registered integration
  worktree; `$CONTROL_ROOT` is this isolated CF-022 implementation worktree;
  `$SCHEDULER_ROOT` is the explicitly selected scheduler checkout containing
  `ops/check-fleet-invariants.py`. The shorter similarly named checkout does
  not contain that ops file. `$SCRATCH` is the operator's private scratch root.
- [Exact lane findings](code-factory-CF-022-140811-findings.json) preserve the
  checker's Code Factory lane diagnostics with only private paths normalized.
  [Safe census](code-factory-CF-022-140811-lanes.json) contains allowlisted fields,
  prompt lengths, resolved boards, issue codes, pins and declared/suffix targets.
  No full API payloads, prompts, keys, delivery IDs or private endpoints are published.

## Live census and per-lane dispositions

The read-only DB query was `WHERE name LIKE 'code-factory%'`, not a handwritten
lane roster. Result: 19 registered lanes, 14 enabled, including 13 enabled
satellites; five already-disabled lanes remain disabled. Every enabled workdir
exists. All satellite rows declare `parent=code-factory`; every satellite uses
explicit cooldown admission with adaptive cooldown off. The primary remains
`admission_mode=tasks`, `cooldown_s=60`, floor/ceiling zero, pin unset.

`B` below means a nonempty parseable direct tasks file resolves to the primary's
same canonical board; `M` means missing/invalid, not a duplicate board invented
by this worker. `D` means disabled and its workdir/board is absent. All paths
other than the primary are relative to `$HERMES_HOME`. The JSON snapshot carries
floor, ceiling, pin and prompt-length details for every row. All 19 project
blocks are absent from the loaded TOML; that absence is not store parity.

| Lane | Enabled | Observed namespace | Workdir | Board | cooldown_s | Canonical family cadence / disposition |
|---|---|---|---|---|---:|---|
| code-factory | yes | coding-hermes | $PROJECT_ROOT | B | 60 | Protected operator value; checker flags it; untouched |
| code-factory-docs | yes | docs | stand-in/docs/code-factory | M | 604800 | Cadence/pin already canonical; board unresolved |
| code-factory-docs-qa | yes | qa | stand-in/pm/code-factory-docs | M | 900 | 43200; suffix target code-factory-docs, not its org parent |
| code-factory-dogfood | yes | dogfood | stand-in/dogfood/code-factory | B | 900 | 259200; live cooldown disagrees with its existing floor |
| code-factory-duckbrain | yes | duckbrain-sync | stand-in/duckbrain/code-factory-duckbrain | M | 900 | No canonical role suffix; policy/intent owner decision required |
| code-factory-duckbrain-dogfood | no | dogfood | stand-in/dogfood/code-factory-duckbrain | D | 21600 | Disabled; no enablement attempted |
| code-factory-duckbrain-pm | no | coding-hermes | stand-in/pm-lane/code-factory-duckbrain | D | 21600 | Namespace convention is pm even while disabled |
| code-factory-duckbrain-qa | no | qa | stand-in/pm/code-factory-duckbrain | D | 21600 | Disabled; no enablement attempted |
| code-factory-duckbrain-releng | no | releases | stand-in/releng-lane/code-factory-duckbrain | D | 21600 | Disabled; no enablement attempted |
| code-factory-duckbrain-sync | no | coding-hermes | sync-workdirs/code-factory-duckbrain-sync | D | 21600 | Namespace convention is duckbrain-sync even while disabled |
| code-factory-perf | yes | perf | stand-in/perf/code-factory | M | 900 | 604800 |
| code-factory-pm | yes | coding-hermes | stand-in/pm/code-factory | B | 900 | Namespace pm; cadence 86400 |
| code-factory-qa | yes | qa | stand-in/qa/code-factory | B | 900 | 43200 |
| code-factory-readme | yes | docs | stand-in/readme/code-factory | M | 900 | 604800 |
| code-factory-readme-qa | yes | qa | stand-in/pm/code-factory-readme | M | 900 | 43200; suffix target code-factory-readme |
| code-factory-releng | yes | releases | stand-in/releng-lane/code-factory | B | 900 | 86400; checker also permits 259200 |
| code-factory-releng-qa | yes | qa | stand-in/pm/code-factory-releng | M | 900 | 43200; suffix target code-factory-releng |
| code-factory-review | yes | review | stand-in/review/code-factory | M | 900 | 604800 |
| code-factory-sync | yes | coding-hermes | sync-workdirs/code-factory-sync | B | 900 | Namespace duckbrain-sync; cadence 21600; README missing |

The 12 enabled lanes still at 900 seconds reproduce the original cadence finding.
The original seven missing boards are not the present census: the stricter
probe now finds eight enabled satellites without a valid primary-board link
(docs, docs-qa, duckbrain, perf, readme, readme-qa, releng-qa, review). The fleet
checker reports only the three `*-qa` cases in that set: check 5c covers only
qa/pm/dogfood/sync and accepts a board directory without checking tasks content.
This difference is a checker-coverage boundary, not an invented live repair.

The observed role-suffixed workdirs match the nine-family API roots in
`internal/api/lane_onboarding.go:74-90,155-175`. The role-less duckbrain lane has
no entry in that map; do not infer a sanctioned family from its namespace alone.
Disabled duckbrain satellites have canonical-shaped paths but no actual dirs.

## Namespace, prompt, target and writer review

The canonical namespace matrix is the actual checker's
`SATELLITE_FAMILY_NAMESPACES` (`ops/check-fleet-invariants.py:326-336`), not stale
prose or a private per-project namespace. Live non-Code-Factory peers were
aggregated read-only: qa uses qa; pm uses pm; sync uses duckbrain-sync; dogfood
uses dogfood; releng uses releases; docs/readme use docs; perf and review use
their corresponding namespaces. Peer cadences are not all clean, so the
checker's canonical matrix, not a majority vote, remains the authority.

Every enabled lane has nonempty own instructions above the checker's short
threshold. Safe prompt projection found Code Factory target tokens and the
expected role terms; no raw prompt is reproduced. All 19 use append mode.
`buildForemanPrompt` (`internal/scheduler/spawn.go:1234-1249`) combines the
namespace prompt with the lane prompt. Thus PM and sync still inherit the
coding-hermes foreman fallback rather than their role namespace procedure;
adequate length is not proof of correct instructions. No live lane's own prompt
mentions boardctl. This is an unresolved writer/procedure verification boundary,
not permission to replace prompts or bypass the board engine.

The docs/readme/releng QA own prompts name `code-factory`, while suffix-derived
targets are their respective support lanes. The declared org parent is also
`code-factory`. These facts are deliberately recorded separately; no lane tree
was rewritten merely to make the suffix and parent look equal. The disabled
nested duckbrain prompts name `code-factory-duckbrain` instead. That role-less
lane owns five named satellite records, so name/parent-derived scheduler
classification also deserves owner review before treating it as an ordinary
sync satellite.

The primary board is owned by the registered primary integration worktree.
Resolved satellite links point to that same tasks file, and their empty
board_ownership override derives shared ownership rather than an independent
tasks-mode waiver (`internal/scheduler/admission_mode.go:132-180`). This is
read-path evidence only. Neither link resolution nor existing pending work
certifies a lane-specific dispatchable backlog or its writer authorization.

## Policy and durable-store blocker

Exact API reads of all 19 `GET /api/v1/projects/<lane>` responses, unwrapped at
`project`, matched every selected DB field: name, namespace_id, parent, workdir,
enabled, cooldown_s/floor/ceiling/pin, adaptive_cooldown, admission_mode,
board_ownership, prompt_mode. No missing field was accepted as equality.
`GET /api/v1/config`'s selected db_path matched the audited DB;
`GET /api/v1/status` reports the loaded `$HERMES_HOME/fleet.toml` path.
Its config_drift block reports the docs pin at 604800 against absent TOML
cooldown (reported as 0). Direct parsing found no Code Factory project blocks.

There is no observed Code-Factory-scoped supported operation that applies the
canonical family policy AND yields the required durable TOML diff/readback and
reversal. The inspected project PUT path updates the DB only. The inspected
source describes the TOML regeneration writer as retired
(`internal/api/server_projects.go:764-807`); seed-only loading imports pins
without blindly overriding operator DB state (`internal/config/loader.go:855-876`).
That makes old dual-store prose stale, but does not authorize this worker to
waive CF-022's explicit dual-store acceptance or edit generated TOML.

The deployed `$HERMES_HOME/scripts/fleet-cooldown-policy.py` still has a
fleet-wide `--apply`, no project/lane scope option, and no FAMILY_CANONICAL map.
Its read-only `--dry-run` exited 0 but proposed 900 -> 3600 for dogfood, PM, QA,
releng and sync; it also proposed protected primary 60 -> 3600. It skipped
unreadable boards and hard-skipped the weekly docs convention. These are NOT
the checker's canonical family decisions. No apply, arbitrary partial API PUT,
hand-edited TOML or scheduler-source change was attempted. There is consequently
no applied diff or reversal to claim. A scheduler-owner scoped transaction or
explicit revised authority is needed; preserve every primary operator setting.

## Sync orientation blocker and useful repository fix

The repository now provides
[SCHEDULER-LANE-VERIFICATION](../SCHEDULER-LANE-VERIFICATION.md), including a
findable local evidence-consumption contract and the intended project memory
namespace `code-factory`. It does not certify a DuckBrain marker's existence,
freshness or read-back content. The trace's `/project/code-factory/status` lookup
is not a memory written by this worker.

The actual enabled sync workdir has no README and no companion sync-data skill
found by the checker. Its ancestor Git root resolves to `$HOME`, not a Code
Factory-owned tracked deployment source, and no README is tracked there. Writer
ownership is therefore unresolved. No README, duplicate board or fabricated
skill was installed there. The workdir owner must provision orientation from a
tracked source and bind it to an actual consumption contract. The live
`sync-orientation` violation remains open.

## Exact checker failures and separation

The real checker exited 1, not PASS. The findings JSON preserves all 32
Code-Factory-name findings: four namespace-membership, 13 cooldown (including
protected primary), three boards, 11 family-floor, one sync-orientation.
Two additional primary-board findings also remain open:

- `board-vocab CF-002: status=blocked`. This repository's board contract permits
  blocked; the fleet checker vocabulary does not. No sibling row was edited.
- `event-id-ascending`: 54 integer IDs are below the 19-digit floor
  1000000000000000000 and the events file carries no ID at that scale.
  No append-log IDs were rewritten. Boardctl accepts this history, so the two
  gates genuinely disagree; both results are retained.

The safe audit therefore reports 34 scoped findings. Six separate global cap
failures are outside this lane repair scope (but can affect shared admission):
coding-hermes 8 vs checker 16; qa, pm, dogfood and releases 9 vs checker 1;
duckbrain-sync 12 vs checker 1. No caps were changed. The safe adapter reports
these as `unrelated_finding_count=6`, not a green fleet or an ignored exit.

## Original acceptance dispositions

| Criterion | Disposition |
|---|---|
| 1. Verify enabled satellites' namespace/parent/prompt/target/workdir against peers and checker | PARTIAL: all rows observed and canonical roots/maps compared; wrong PM/sync namespace fallback, nested target/procedure and duckbrain-role intent remain unresolved. |
| 2. Ensure all registered support lanes resolve owned valid boards, without duplicates | BLOCKED: existing shared links identified; eight enabled board roots unresolved; no unauthorized cross-workdir writes or duplicate boards. |
| 3. Repair cadence through supported family policy and explicit pins, preserving intent, read DB/API and TOML | BLOCKED: readback complete; no scoped canonical durable policy operation found; deployed dry-run proposes wrong family values and would touch protected primary. |
| 4. Sync README/orientation and findable consumption contract | PARTIAL: useful repo contract added; live sync README/contract deployment blocked on writer ownership. |
| 5. Run checker/board validation, record unresolved failures without disabling | SATISFIED as verification: checker exit 1 failures retained; boardctl exit 0 with header warning; no disabling. This is not invariant PASS. |
| 6. No forced dispatch until dispatchable work and writer boundary verified | SATISFIED as safety constraint: no dispatch; readiness/writer authorization remain unverified. |

Original parent CF-022 stays open. Foreman owns board lifecycle and judge; this
worker neither closes the row nor runs `gitreins complete`.

## Commands, exits and observed test results

Commands use normalized paths, with the same explicit arguments as executed.
Raw private logs are `$SCRATCH/cf022-140811-*`, outside git. Suites were serialized.

| Command / observation | Observed result |
|---|---|
| `pwd; git branch --show-current; git rev-parse HEAD; git merge-base --is-ancestor <base> HEAD` | Correct isolated worktree/branch, exact base above, exit 0 |
| `scripts/boardctl show CF-022` | Exact in_progress row and six criteria read, exit 0 |
| `python3 "$SCHEDULER_ROOT/ops/check-fleet-invariants.py" --help` | Supported explicit --db/--toml/--json/--board/--skills-root flags, exit 0 |
| `python3 "$SCHEDULER_ROOT/ops/check-fleet-invariants.py" --db "$HERMES_HOME/coding-hermes/scheduler.db" --toml "$HERMES_HOME/fleet.toml" --board "$CONTROL_ROOT/.coding-hermes/board/tasks.jsonl" --json` | Exit 1; exact normalized lane findings retained; board/global failures above |
| `python3 "$HERMES_HOME/scripts/fleet-cooldown-policy.py" --dry-run` | Exit 0, mode DRY-RUN; unsafe/noncanonical proposals above; not applied |
| `python3 -B scripts/audit-lanes.py --db "$HERMES_HOME/coding-hermes/scheduler.db" --toml "$HERMES_HOME/fleet.toml" --checker "$SCHEDULER_ROOT/ops/check-fleet-invariants.py" --hermes-home "$HERMES_HOME" --project-root "$PROJECT_ROOT"` | Exit 1, DRIFT; 19 rows / 14 enabled, 34 scoped / six global findings; generated safe snapshot |
| Same audit with `--db "$SCRATCH/cf022-140811-absent.db"` | Exit 2, explicit ERROR; file still absent, assertion exit 0 |
| `python3 -B tests/lane-contract.py` | Final 15 tests OK, exit 0; includes positive, live-value drift negative/recovery, missing/bad/zero-match input and checker/board/redaction controls |
| `python3 -B tests/lane-contract.py LaneContract.test_checker_malformed_shapes_are_safe_errors` before shape validation fix | Exit 1 RED; malformed list/null result produced an AttributeError; after fix covered by green 15-test suite |
| `bash tests/selftest.sh` | Final SELFTEST: PASS, exit 0; 15 lane tests, existing 11 node tests, seven executable node mutants, 10 build tests, 16 inference tests, 11 recovery tests, plus named-check/shell/digest/board/dependency checks |
| `scripts/boardctl validate` | Exit 0; 26 tasks / 54 events; key uniformity 26/26; one headerless-board warning |
| `ruff check scripts/audit-lanes.py tests/lane-contract.py` | All checks passed, exit 0 |
| `ruff format --check scripts/audit-lanes.py tests/lane-contract.py` | Two files already formatted, exit 0; initial formatting check required formatting, which was applied |
| `git diff --check` | Exit 0 |
| `timeout 600 gitreins guard --full` after staging final source/tests | Exit 0; Tier 1 PASS (test mode full, whole tree), secrets clean, lint OK, tests (full). No bypass. |

The guard log identifies a real full test run, not a shell-only short circuit.
It is not a Tier 2 judge verdict. The public artifacts are staged for the same
source commit; its full hash is provided by the worker handoff and is retrievable
with `git log -1 --format=%H -- docs/audits/code-factory-CF-022-140811.md`.
Push/readback are reported after the commit exists, not fabricated here.

Initial cache discovery for
`scheduler-satellite-workdir-board-cooldown-invariant` returned HTTP 404
not-found, not infrastructure failure. The post-debug solution/context was
submitted with cadence `post-debug`: HTTP 200, submission `sub_e5f842`; exact
queue readback HTTP 200 confirmed the same problem_class and in_progress status.
That is a queued solver submission, not a verified answer or a memory sync.

## Remaining work and exclusions

Scheduler owner: reconcile actual policy generator/DB-authority/TOML contract,
provide a scoped canonical diff with reversal, then re-run all readbacks and
checker. Workdir owners: resolve shared-board links and tracked sync orientation
without copying boards. Foreman: review prompt procedures and nested targets,
verify lane-specific work and writer boundaries, adjudicate board-vocabulary and
event-ID gate disagreements, then decide original acceptance.

No live remote execution, Bunker provisioning, Crier round trip, inference
integration, service restart, forced dispatch, credential copying, namespace
deletion, primary-setting change or integration-branch merge is claimed.

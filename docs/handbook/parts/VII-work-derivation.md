# Part VII — Work derivation

The unit of work this part derives is the **project**: a person tells their agent what
project they want, the agent turns that intent into a Boardctl-backed plan, and the
Factory builds the requested project end to end, producing an integrated, usable result
demonstrated against the project's acceptance criteria. The chain that does it is:

The normative execution protocol is `work.v1`. It distinguishes transport custody,
execution, verification, publication, closeout and scheduler settlement; each state has
one writer and a durable identity. Legacy node/dispatcher messages remain accepted only
through the explicit compatibility mapping in §VII.13; they are not a second normative
path. The total-worker allowance belongs to the round, is reserved monotonically across
successive compatible waves, and is never replenished by a new wave. Worker, wave and
round memory records remain separate even when a service outage leaves their
synchronization pending.


**project → initiative/acceptance plan → Boardctl tasks/dependencies → foreman round →
compatible worker waves → execution attempts → verified integration → project
acceptance** (§11).

Within that chain, the execution hop is what the rest of this part has always measured:
a row is filed, a tick admits it, the bus carries it, a harness executes it under a
brief, a judge grades the result, and the row closes on evidence — or it does not close
at all. Every hop names the contract that carries it, and every contract cites the
chapter that measured it. Two rules the chain inherits from the mission: a quiet board,
one commit, or a successful tick is not project completion evidence (§11), and the
deterministic IaC control loop of Part V is the supporting control that keeps
infrastructure ready — it is not itself the work derivation (§11.9).

## VII.1 The chain, as a table

The following target sequence is normative. The `Measured in` column is implementation
coverage only; it does not change the target actor or state owner.

| Hop | Actor decides | Contract | Carries | State transition / durable proof | Measured in |
|---|---|---|---|---|---|
| file | foreman | CT-14 | row, criteria, dependencies | absent → pending; unique row/event | M4 §6 |
| admit | scheduler | CT-01 | lane config and round reservation | pending → admitted or named refusal | M9 §6 |
| envelope | scheduler → Crier | CT-02 | versioned envelope, run/corr IDs, digest | custody accepted before launch | M9 §6 |
| lease | Crier → Bunker foreman | CT-03 | delivery and lease | custody → leased; lease/fence durable | M2 §6 |
| execute | Bunker foreman → workers | CT-04/CT-06R | brief, attempt ID, typed result | leased → running → reported | M2 §6 |
| verify | foreman / judge | CT-12/CT-13 | criteria, verdict, tree/evidence refs | reported → verified or correction | M3 §6 |
| publish | foreman | CT-14 | exact commit/tree proof | verified → published | M4 §6 |
| close | foreman → board | CT-14 | evidence-bound transition | published → complete | M4 §6 |
| settle | scheduler | CT-06 | correlated round report | return → settled; unknown never means pass | M9 §6 |

Legacy `node → crier` and `dispatcher` observations remain implementation coverage and
are translated into `work.v1` only when their IDs, typed status and evidence satisfy the
compatibility rules in §VII.13.

One hop may refuse. A refusal names a reason; a silent drop is a defect, not a decision.

## VII.2 The board row lifecycle

The board is two JSONL stores, `tasks.jsonl` (rows) and `events.jsonl` (transitions), in
`.coding-hermes/board/` (M4 §1). At the 2026-11-07 measurement the store held 357 rows and
520 events (M4 §7). A row moves `pending` → `in_progress` → `complete`, and the non-forward
states are part of the design: `blocked` carries a named blocker, `deferred` carries an
unmet dependency (M4 §12; the front-matter overview, figures/board-lifecycle.svg).

Three rules govern the write path:

- **Closeout requires evidence.** `boardctl update --status complete` refuses without
  `--evidence-run-id` (M4 §5, TR-251). A completion is bound to a run the board can name.
- **Identity is unique.** A duplicate id is refused (`task id "…" already exists — create
  aborted`), and so is a duplicate finding fingerprint (M4 §5).
- **The lock is classified, never assumed.** `board_lock.py adjudicate` (`:166-185`)
  returns one of four verdicts — ABSENT, HELD, ERROR, RESIDUE (M4 §3). ERROR means the
  lock state is unknown, exits 3, and is never permission to write (M4 §3, CF-259).

The read path has its own rule: the board lives in git, `origin/main` is the canonical
store, and the working copy is a cache other writers are allowed to dirty.
`scripts/board_read.py load` (`:59-70`) resolves `origin/main` → `origin/master` → `main`
→ `HEAD` and falls back to the worktree only when no ref resolves; it never refuses, and
it reports which source it used (M4 §3; prompts/foreman.md, "Read your own board first").
The prompt rule is explicit: a dirty worktree is a reading instruction, not a reason to
refuse, and a tick that reports "board read prohibited" while 252 rows are dispatchable is
the defect (prompts/foreman.md).

## VII.3 Admission — tasks versus cooldown

Admission is the scheduler's authority: it decides when a lane's cadence tick fires and
whether the tick is admitted (M9 §2). The decision is an ordered procedure, and the order
is the contract (M9 §3, "Ordered admission procedure"):

1. Mode precedence: a project mode wins, then the namespace mode, then `cooldown`
   (`admission_mode.go:98-107`).
2. Board ownership: an explicit override wins, otherwise filesystem workdir containment
   (`:177-184`).
3. Board workability: a tasks-mode lane with a workable owned board earns the cooldown
   waiver; an empty workdir, a non-owned board or an unreadable board returns false, which
   falls the lane back to its cooldown pin rather than refusing dispatch (`:230-243`).
4. Last-tick failure: a project whose last tick failed stands the waiver down and paces on
   the full cooldown (SCHED-GAP-214).
5. Usage-pool reservation: disabled enforcement, an unavailable authority and a capacity
   denial are three distinct outcomes with distinct caller obligations
   (`usage_pool_policy.go:26-63`).
6. Board-stasis gate: a cooldown BUILDER lane whose board is unchanged since its previous
   completed tick is excluded from selection, and no cooldown is consumed
   (`packer_select.go:474`, flag default true, SCHED-GAP-1678).
7. Load gate: above the threshold, new spawns are deferred, not dropped
   (`load_gate.go:63`, SCHED-GAP-125).
8. NOOP-PACING: a tasks-admitted lane that produces no artifact has its next admission
   spaced by `cooldown_floor_s`, doubling to 8× the floor, and any artifact resets the
   streak (`noop_pacing.go:59, :74`; M9 §3).

The design intent of the two modes is the trade the numbers name: `tasks` mode admits on
work — a workable board row dispatches now, and the waiver replaces the wait. `cooldown`
mode admits on time — the lane paces itself, and stasis or failure stretches the gap. The
measured defect that motivated step 8 ran 76 spawns a day with 63 dry-run ticks and no
artifact, because a no-op tick burned nothing and reset no counter (M9 §3, the
NOOP-PACING finding). The readback rule at settlement belongs to the same authority and
is the honest edge of it: `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only
`payload["ok"]`, and the absence of a verdict is treated as success (M9 §2; CF-355 open).

## VII.4 Dispatch — envelope, lease, execution

The admitted tick becomes an envelope: run_id, corr_id, lane, board reference and a
`text_b64` directive, signed and POSTed to the bus (CT-02; M9 §6). Crier grants a lease on
retrieve (CT-03), and two consumers exist: the node worker (M2) and the dispatcher (M11).

The node worker's refusals come before any network work. It refuses a dispatch with no
`text` directive and a dispatch whose `brief.digest` does not match `sha256(text)` — a
brief altered in flight is refused, not run (`node-bus-worker.py:1036-1042, :1044-1052`;
M2 §11). Settlement is ordered: execute, deliver each result, write the seen-cache only
after delivery succeeds, ack last (M2 §11, B10). The real reply fields are
`env_version, dispatch_id, corr_id, status, host_identity, harness, vars, exit_codes,
gate_exit, branch, commit, artifacts, wall_s, finished_at` (`node-bus-worker.py:1176-1192`;
M2 §6) — there is no `run_id`/`outcome` field, and the register row that said otherwise was
stale (M2 §6).

The dispatcher (M11) is the other consumer: one loop per agent per box, executing inside
the agent's container via `bunker exec`. Its job model is start detached, poll with short
calls, kill on deadline (`dispatcher.py:215-331`), and its ledger replays a recorded result
instead of re-running a redelivery (`:470-475`; M11 §3). The deadline kill terminates
run.sh's process group; whether it reaches the GNU-timeout group holding the harness is
unverified, so the descendant-termination guarantee is withdrawn until a test proves it
(M11 §10, F11-8). Its known margins are named the same way: a redelivery replay is not
unconditionally crash-safe, because the task runs before the ledger write (`:479` vs
`:481`; F11-3), and the serial loop head-of-line-blocks later agents (F11-5).

## VII.5 The worker brief — variable contract, commit discipline, guards

A dispatched directive becomes a run only if the harness accepts its brief. The variable
contract is `harness-vars.sh`: `CFV_DECLARED` lists 12 variables and `CFV_REQUIRED` 6, and
`--contract` mode refuses the run when a required variable is missing or malformed (M5 §5).
The rules that matter to a brief writer:

- **Credentials are paths, never values.** `CF_API_KEY_FILE` must be a path with mode
  `[0-7]00`; a key value in the environment is refused, and `CF_BASE_URL` carrying
  `user:pass@` is refused (M5 §5).
- **The write boundary is `$HOME`.** `CF_WORKDIR` must resolve inside it (M5 §5).
- **Commits are composed in a file and written with `git commit -F <file>`.** The brief
  requires a commit message that survives shell quoting, carries the co-author trailer,
  and describes what changed; the harness flight data file grades exactly this — "a commit
  lands carrying the co-author trailer" (M5, FLIGHT DATA FILE). A commit message is
  never evidence: "never claim a row complete unless a command someone else can re-run
  demonstrates the acceptance criteria" (prompts/foreman.md, Ground rules).
- **Work is isolated in a worktree.** The landing gate runs in a detached worktree at the
  node's commit, so it measures the node's tree and not main's (M3 §11); the lander merges
  the envelope's exact commit, never the branch tip (M3, appendix unit 20). A lane works in
  its own checkout for the same reason two writers may not share one index.
- **Guards run at commit.** The pre-commit hook invokes `gitreins guard --quality-async`
  against the already-staged changes, and tier-1 (`gitleaks detect --no-git`) grades the
  working tree while the guard grades staged files only (M3 §5, §6; CT-12). A guard that
  did not run is a named condition: the hook exits 0 when `.gitreins/config.yaml` is
  absent, and a bypass of `core.hooksPath` must be disclosed in the commit message when
  used (M3 §10, "by design but dangerous — the bypass must be disclosed"; quorum 5/5).
- **Hooks are not proven by presence.** A generated hook file does not prove git invokes
  it; the effective `core.hooksPath` must resolve, and the rejecting-commit fixture that
  proves a refused commit cannot advance HEAD is the missing evidence (M3 §11, B11).

## VII.6 Judge and verdict readback

The judge is a gate, not a correspondent. The staged diff goes to gitreins (CT-12, M3 §6),
and the verdict that comes back is what closes a row (CT-13, M4 §6). The readback rules:

- **The verdict names criteria.** A grade is PASS or FAIL "with named criteria, never a
  silent skip" (M5, FLIGHT DATA FILE). A verdict that cannot name what it graded is
  not a verdict.
- **The verdict line is a row-count contract.** The harness adapter's verdict is decided
  by row counts — every row `PASS` makes `PASS` with exit 0, one `WARN` row makes
  `UNVERIFIED` with exit 3, any `FAIL` row makes `FAIL (n)` with exit 1 (M5 §6). A summary
  line that contradicts its own rows was the defect; the fix held the contract in both
  directions with a red control, so the pass is not reachable by deleting the warning
  mechanism (M5 §6, CF-384).
- **Readback mismatches are findings, not interpretations.** The control-plane half reads
  only `ok` while the node sends `status` — a failed result can be recorded as a pass, and
  the row stays open until the two fields agree (M2 §6, M9 §2; CF-355). The mirror rule
  holds on the worker side: a false `ok` for a failed run records a pass for work that
  never happened (M2 §2).
- **A verdict file readback is a surface, not a courtesy.** Closing work requires reading
  the verdict and binding it: the board's own completion verb refuses a closeout that does
  not name the run id that proves it (M4 §5).

## VII.7 Closeout

Closeout is a landing plus a board transition, in that order. The landing proves ancestry
before it pushes: the merge target is the envelope's commit, the pushed object is the merge
it just created, and the fast-forward path checks the merge tip against the envelope before
anything moves (`land-node-branch.sh:238-265`; M3, appendix unit 20). The evidentiary rows
are `LANDED: <branch> @ <commit>` on success and `LAND: REFUSED — <reason>` on any failed
precondition (M3 §9).

The board transition carries the run id. A row closes `complete` only with
`--evidence-run-id`, the event log grows by exactly one line, and the closing evidence must
tie to the exact tree the run produced (M4 §5, FLIGHT DATA FILE). Rows that cannot proceed
go `blocked` with a named blocker and the one command that unblocks them, and the
classification comes before the receipt: a dirty checkout held by a live worker is a
stand-down, not a block, because "nothing is wrong, something is working"
(prompts/foreman.md, "Before you block").

What each hop must be able to prove, in one line per hop:

| Hop | The proof that must exist |
|---|---|
| file | a row with acceptance criteria someone else can re-run |
| admit | the tick line names admitted or deferred, never dropped (M9, FLIGHT DATA FILE) |
| dispatch | a run id and a corr id, in the envelope and in the reply |
| execute | a digest-verified brief, a bounded wall, a signed reply |
| grade | a verdict with named criteria and an exit that matches its rows |
| close | a landed commit, an evidence run id, one new event |

> CAUTION: a hop that cannot produce its proof is a finding to file, not a prose
> placeholder. Any RED field the row touches stays RED until a command proves it
> (prompts/foreman.md, "Rules that come from the document").

## VII.8 Work-item authorities

Every transition a row can undergo is an authority: a named actor, deciding on named
evidence, recording a named board event. Where the current implementation states no
authority, the row says so rather than inventing one.

| Action | Authority | Decided on what evidence | What the board records |
|---|---|---|---|
| create | the foreman (or an operator standing in) | a row is filed with acceptance criteria someone else can re-run (prompts/foreman.md) | a `pending` row with a unique id; a duplicate id is refused |
| split | the actor who owns the row at split time | a row too large for one bounded run is divided; each child carries its own id and acceptance criteria | new rows with unique ids; a duplicate finding fingerprint is refused (M4 §5) |
| priority | the scheduler, through lane weights and admission order | lane weight, cadence and the weight budget — never per-row whim (M9 §3) | no row edit; priority is an admission property, not a board field |
| defer | the foreman | an unmet dependency, named | a `deferred` row carrying the dependency (M4 §12) |
| unblock | the foreman, after the dependency clears | the one command that unblocks the row, recorded at block time (VII §7) | a `blocked` → `pending` transition naming the resolving command |
| cancel | unstated — a named gap | — | the board schema carries no cancel verb; cancellation authority is an owner decision (TARGET-UNIMPLEMENTED) |

Two authority rules bound the table. First, a worker never cancels and never re-prioritizes:
those decisions belong to the scheduler and the owner, and a worker that cannot proceed
files a block or stands down — "a dirty checkout held by a live worker is a stand-down, not
a block" (VII §7). Second, deferral and blocking are distinct states with distinct records:
`deferred` waits on a dependency, `blocked` waits on a fix, and conflating them hides which
one a stale row needs.

**Retry lineage.** A rework and a retry are different lineages. Rework is a
changes-requested verdict sending the same row back to the worker: the row keeps its id,
the new run gets a new run id, and the board's events log accumulates both. Retry is a
failed or lost execution run again: the corr_id changes per dispatch attempt, the row id
does not. The lineage rule is that the board must be able to name every attempt — dispatch
id, corr id, run id, verdict — for the row it closed. The current store cannot honor that
rule end to end: the node worker writes no board rows (CT-10, BROKEN), so attempt lineage
lives only in the scheduler ledger, and the review's stale-claim and unknown-verdict
classes (VI §13, §14) are the failure modes of that gap.

## VII.9 Resource, path and model constraints

The constraints a dispatched run operates inside, and what enforces each:

| Constraint | Boundary | Enforced by |
|---|---|---|
| write boundary | the run writes only inside `$HOME`; `CF_WORKDIR` must resolve inside it | `harness-vars.sh` refusal (M5 §5) |
| turn budget | `CF_MAX_TURNS` 1..1000 | refusal out of range (M5 §5) |
| wall clock | `CF_TIMEOUT_S` 1..86400 per turn; the dispatcher's own envelope ceiling `DISPATCH_TASK_CAP_S` 7200 | refusal / clamp (M5 §5, M11 §5) |
| disk floor | per-role admission floor before any spawn | `disk_floor.py` refusal, role- and range-checked (M1 §5) |
| memory cap | per-spawn `RLIMIT_AS` when `spawn-mem-limit-mb` is set | the scheduler at spawn (M9 §5); 0 disables — a profile choice, not a guarantee |
| shared cache | a shared Go module cache must be a sealed absolute path | relative path refused; declared-but-unsealed is a counted FAIL (M1 §5) |
| credential form | keys as file paths, mode 0600-class, never values in argv or env | `CF_API_KEY_FILE` predicate; ambient-key ban (M5 §5) |
| model route | a node may request only an allowlisted model | 403 outside `CF_PROXY_ALLOWED_MODELS`; the allowed list denies all when empty (M12 §5) |
| target identity | work lands on the envelope's exact commit, in a detached worktree | the lander's ancestry proof (M3, VII §7) |
| Bunker quota | disk size is per-file, not an aggregate quota; egress defaults open | the effective deployment profile — qualified, not guaranteed (V §matrix, VI §23) |

The constraint rows are target requirements, not a summary of what the scripts happen to
check: where an enforcement exists it is cited, and where the boundary is a profile
qualification it is marked as one.

## VII.10 Required work metrics, derived from intended behavior

Metrics are derived from the intended chain in VII §1, not from what current scripts
emit: every hop that can refuse, delay, duplicate or lie gets a metric whose definition
exists before any instrumentation does (review acceptance standard; user decision 7 —
existing scripts prove observed implementation, not the metric design). Each metric
carries a definition, an owner and a readout; a count without those three is not a
metric.

| Metric | The intended question | Definition (units) | Owner |
|---|---|---|---|
| `admission_outcomes_total{admitted, deferred, refused, noop_paced}` | is the cadence spending on work, and where does it refuse? | counter, per lane and outcome class (M9 §3's named decisions) | scheduler |
| `dispatch_to_settlement_seconds` | how long from envelope to correlated durable result? | histogram, seconds, per lane | scheduler |
| `settlement_outcomes_total{pass, fail, unknown}` | does every execution settle to a named outcome? | counter; `unknown` is distinct, never folded into pass (CF-355, VI §14) | scheduler |
| `refusals_total{no_directive, digest_mismatch, out_of_range, ...}` | what does the node refuse, and why? | counter, one bounded class per refusal reason (M2 §11) | node worker |
| `rework_rate` | how much accepted work needed a changes-requested round? | changes-requested verdicts per closed row, ratio | gitreins / board |
| `closeout_evidence_rate` | is every closure evidence-bound? | closures with `--evidence-run-id` over all closures, ratio | board |
| `lineage_completeness` | can the board name every attempt for a closed row? | closed rows with a full attempt lineage over all closed rows (TARGET — CT-10 BROKEN, VII §8) | board |
| `board_work_age_seconds` / `board_drift` | is work staling between copies? | age of the oldest dispatchable row; behind-count of the working copy (M4 review) | scheduler |
| `queue_depth` / `oldest_message_age_seconds` | is the bus holding real work or draining it? | gauge, seconds (M10 review definitions) | Crier store owner |
| `replayed_results` / `uncertain_starts` / `orphans_reaped` | is execution crash-safe? | counters (M11 review definitions, VI §16) | dispatcher |
| `expiry_headroom_seconds` / `refused_scope_total` | will credentials die mid-run, and is scope narrowing real? | minimum headroom gauge; refusal counter by class (M7 review) | credential issuer |
| `worker_budget{used, remaining}` | how much of the round's total-worker allowance is spent, per round and per wave? | gauge, workers; observable per wave, never reset at a wave boundary (V2-Q-02, §16) | foreman (round report) / scheduler (admission) |
| `round_stop_reasons_total{reason}` | why did rounds stop — useful-work exhaustion, budget spent, or a required condition? | counter, one named reason class per stop (§11.8) | foreman |
| `project_acceptance_progress{initiative}` | how much of the accepted plan is delivered and verified? | derived: accepted/verified integration results over planned acceptance criteria (§11.9) | foreman / board |

Grep absence in current scripts is coverage evidence, not the metric design: where a
definition above has no emitter, the metric is required behavior with the emitter named as
TARGET-UNIMPLEMENTED — the same three-state discipline the settings register uses (V,
"The four review columns and the three states").
Every metric's collection and readout ownership follows its owner row; a metric nobody
reads out is a definition, not a control.

## VII.11 The project derivation chain — from conversational intent to acceptance

The scopes are distinct and each has one owner:

| Scope | What it is | Owner | Where it is recorded |
|---|---|---|---|
| **project** | the requested outcome: what the person asked to have built, with its acceptance criteria | the user, with their agent as proxy | the project's initiative plan and Boardctl plan rows |
| **initiative** | a coherent slice of the project — a milestone with an acceptance plan | the agent, refined with the user | initiative rows on the board |
| **task** | one bounded, dispatchable unit with acceptance criteria someone else can re-run | the foreman (filing) / scheduler (admission) | `tasks.jsonl` (VII §2) |
| **round** | one scheduler-admitted span of foreman work covering a board scope, e.g. an initiative | the foreman executes; the scheduler admits and settles | round record returned through Crier |
| **wave** | one compatible grouping of tasks launched together within the round's remaining budget | the foreman | wave manifests + wave memory entry (§14) |
| **attempt** | one worker execution of one task (retry lineage per §8) | the worker, verified independently | attempt lineage + worker memory entry (§14) |

**Intake and refinement.** Conversational intent is refined with the user into the
initiative plan *before* tasks exist: what will be accepted as done, in what order, and
what is explicitly out of scope. The plan is expressed as Boardctl tasks with
dependencies and per-task acceptance criteria — the board row contract of §2, at plan
granularity.

**Decomposition and specifications before implementation.** A task that cannot state its
acceptance criteria is not dispatchable; it is refined until it can, or blocked with the
named refinement work (VII §7's block discipline). Specifications precede implementation
where the task's criteria cannot be re-run without one — the judge grades against named
criteria (VII §6), and a criterion that exists nowhere cannot be named.

**Prioritization, eligibility and unblocking.** The scheduler owns priority through lane
weights and admission (VII §3, §8); the foreman selects among eligible tasks and claims
them; completed tasks unblock their dependents, and the foreman re-reads eligibility as
each wave's results land (F1 step 6). A round "aims to accomplish as much useful work as
possible until further progress is unavailable" — one board item is not the round limit
(user decision).

**Useful-work and stopping rules.** A round continues while three conditions hold:
eligible useful work exists, remaining total-worker allowance permits (a cap, never a
quota — no workers are spawned merely to exhaust it), and required operating conditions
(memory write paths, verification) are available or degraded per their resolved policy.
The round ends with a **named stop reason** (§12's round record): `work_exhausted`,
`budget_spent`, `blocked`, `degraded`, or a required-condition failure. Stopping without
a name is a defect.

**Project delivery versus perpetual maintenance.** Project acceptance is defined by the
requested outcome — integrated, usable behavior demonstrated against the plan's criteria,
including deployment where deployment belongs to that project's scope. Maintenance that
follows (upgrades, hygiene, new initiatives on the same repo) is a new plan, not a
continuation of the old acceptance.

**The quiet-board fallacy.** None of these is project completion evidence: a quiet board
(rows may simply never have been filed), one merged commit (one attempt of one task),
a green build (a mechanical gate, VIII §9), or a successful tick (transport, not
verification). Completion is claimed only from the project-acceptance record of §11.9.

**The supporting control loop.** The deterministic IaC layer of Part V keeps the
execution environment ready: readiness, drift repair, replacement placement. It derives
no work; when it cannot keep readiness, its shortfall is exposed (V §V.0) and work
admission degrades per policy — the work chain never silently assumes infrastructure
that the control loop reports absent.

### VII.11.9 The project-acceptance record

Project acceptance is a distinct record, produced at the end of the derivation chain and
bound to the initiative plan: every acceptance criterion named, with the verified
integration result that demonstrates it (attempt lineage, merged-tree proof, publication
evidence — §12, §7), the rounds that carried them, and the residual work explicitly
deferred. An acceptance demonstration is re-runnable by someone else — the same rule a
single row's evidence has always had (§5, "a command someone else can re-run"), applied
at project scope. The record is what turns "the board went quiet" into "the project is
delivered."

## VII.12 Owned state transitions

Every state change in the chain names its owner. A transition without a named owner is a
gap recorded as one (§8's cancel row), never silently assigned:

| Transition | Owner | Meaning | Recorded where |
|---|---|---|---|
| admit lane / create run record | scheduler | the round is admitted; the allowance granted | scheduler execution history |
| custody / delivery of the round request | Crier | transport accepted the envelope with its lease | Crier registry (durable backend required, VI §2) |
| execution boundary | Bunker | the foreman process is launched inside the Bunker | Bunker spawn record |
| scope selection / claims / briefing | foreman | eligible tasks claimed, briefs issued with criteria | board claims + brief manifests |
| implementation | worker | the attempt produces its commit in an isolated worktree | attempt lineage; worker memory entry (§14) |
| independent acceptance | GitReins judge | the staged diff is graded against named criteria | verdict bound to the attempt (VII §6) |
| verification / integration / publication | foreman | merged-tree proof, integration checks, publication | `LANDED:` proof rows (VII §7) |
| board closeout | foreman | task rows closed with `--evidence-run-id` | board events (VII §2) |
| memory projection | foreman | worker/wave/round entries persisted | DuckBrain namespace (§14) |
| round return | foreman → Crier | the correlated round report returns through Crier | round report envelope |
| settlement | scheduler | the round result is durably recorded; the execution history is distinct from the board's truth | scheduler records |

**Three records that must not be conflated** (V2-WRK-02): a **preliminary execution
receipt** — delivery accepted, worker running, heartbeats — proves custody, not outcome;
a **verified/published task closeout** — merged-tree proof plus evidence-bound board
close; and the **final round accounting** — all waves, budget use, stop reason. A
preliminary receipt is never cited as a closeout; the merged-tree proof is what separates
"branch passed" from "the tree that was published contains the work."

**The allowance across waves.** The round's total-worker allowance is consumed
monotonically: each wave's launches debit the remainder, results never credit it back
except through the declared failed-start accounting (§16), and a new wave never
replenishes it. Newly eligible work after each wave competes for what remains.

**Worker and attempt accounting.** A *worker* is one charged worker identity selected
for a round; an *attempt* is one execution of one task by that worker; a *session* is a
harness process within an attempt; and a *launch* is one native start request. Only
worker identities debit the round allowance. The selected policy is `charge-on-start`:
reserve one worker and launch intent atomically before a wave. Native acceptance
moves reserved directly to charged; started is an observation, not an intermediate
budget state. Before acknowledgement, reserved still counts against allowance.
Only proven NEVER_ACCEPTED refunds once. Unknown acceptance remains held/quarantined;
a failed running attempt never refunds. M9.17 defines the exact stored rows,
transaction groups and recovery queries. Worker state is reserved/charged/refunded;
invalid transitions return BUDGET_STATE_INVALID. Attempts are bounded by V.9
max_attempts, backoff and the original round deadline.

The round allowance and simultaneous capacity are independent. For example, an
8-worker round on a host with concurrency 2 is legal: at most two workers run at once,
but successive waves may charge all eight. The round's total budget is never reduced to
2 and a wave never replenishes it. A T3 example with allowance 2 and one worker identity
uses `w-1/worker-1`: reserve, start, charge, attempt 1 fails judge, correction attempt
2 reuses the same worker, then release; the ledger remains `reserved → charged`
with no second worker charge. Native start is observed in the same accounting transition. If worker-1 is lost before start, the refund transition
returns one allowance and a replacement may reserve it; if it is lost after start, the
replacement is charged only if remaining allowance permits. Controller restart reads
these ledger entries rather than recomputing them from task rows.

## VII.13 Correlation and result schemas

The canonical `work.v1` correlation and result schema is normative. The existing
implementation mapping follows it without pretending missing fields exist
(V2-WRK-03 — existing fields are mapped, not invented, and not discarded):

| Schema | Required fields | State / refusal semantics | Durable identity |
|---|---|---|---|
| `register.v1` | `registration_id`, `agent_id`, `project_id`, `profile`, `public_identity`, `capabilities` | `accepted`, `UNAUTHORIZED`, `PROFILE_UNSUPPORTED`, `IDENTITY_STALE`; round/wave/worker/attempt IDs are not required | `registration_id` |
| `round-admission.v1` | `round_id`, `run_id`, `corr_id`, `task_scope`, `total_budget`, `config_generation` | `accepted`, `deferred`, `refused`; invalid budget/config is typed refusal; future wave/worker/attempt IDs are absent | `round_id` |
| `worker-brief.v1` | `round_id`, `wave_id`, `task_id`, `attempt_id`, `brief_digest`, `criteria`, `workspace` | digest mismatch or missing criteria is `BRIEF_INVALID`; brief custody is not success | `attempt_id` |
| `worker-result.v1` | `attempt_id`, `dispatch_id`, `corr_id`, `status`, `commit`, `artifacts`, `evidence_refs`, `finished_at` | status enum `pass`, `fail`, `unverified`, `partial`, `unknown`; absent status is `INVALID_RESULT`; conflicting legacy `ok` is `RESULT_CONFLICT` | `attempt_id` |
| `wave-result.v1` | `round_id`, `wave_id`, worker results, integration result, budget used/remaining | `complete`, `partial`, `failed`; partial memory sync remains visible | `(round_id, wave_id)` |
| `round-report.v1` | `round_id`, `run_id`, `corr_id`, all wave results, stop reason, budget, memory refs | final report is `settled` only after durable memory and evidence references | `round_id` |
| `publication.v1` | `task_id`, `attempt_id`, exact commit/tree digest, verdict, remote proof | mismatch is `PUBLICATION_MISMATCH`; no board closeout | `(task_id, attempt_id, tree_digest)` |

Every schema is carried in the outer `cf2a.v1` envelope with `message_type`,
`schema_version`, `request_id`, `corr_id`, `sender`, `created_at` and `body`.
Timestamps are RFC3339 UTC and digests are lowercase SHA-256 hex. A required field
cannot be null, empty or omitted; optional fields are explicitly nullable and their
absence has the card's stated meaning. Durable state transitions are `custody → running
→ reported → verified → published → closed → settled`; the foreman owns execution,
verification, publication and closeout, Crier owns custody, and Scheduler owns admission
and settlement. A preliminary custody receipt is never a final outcome. Duplicate same-digest
results replay the original outcome; conflicting digests are refused. Unsupported schema
versions and unknown fields outside `extensions` are refused rather than coerced.

Identity creation is ordered: the controller creates `registration_id`; the scheduler
creates `round_id` and `run_id`; the foreman creates `wave_id` and `attempt_id`; Crier
creates `delivery_id` and `lease_id`; the launching foreman assigns `dispatch_id`
and `launch_id` before process creation (M11.16); and the foreman
creates `report_digest`. Thus registration and round admission do not require future
wave/worker/attempt identities.

Legacy mapping: `{dispatch_id, corr_id, status, ok}` becomes `worker-result.v1` only
when `status` is in the canonical enum and the digest/evidence are present; legacy `ok`
is advisory and is rejected when it conflicts with `status`. A legacy reply without
`run_id` receives the surrounding envelope's `run_id` only as an explicit translation
field, never as evidence that the producer emitted it. Missing verdicts map to `unknown`.
The node-bus and dispatcher alternatives are compatibility adapters, not competing MVP
execution authorities; the normative target launches the foreman in the project Bunker
through Crier and returns `CT-06R`.

**Resident launch/return consumer.** The scheduler persists and sends one
`round-admission.v1` through Crier. Crier returns custody, the Bunker foreman retrieves
it under lease, creates waves and attempts, and returns one signed `round-report.v1`.
The scheduler settles only after reading the report and its referenced durable memory
and publication records. A timeout or conflicting digest records `unknown`; a retry
reuses the same request identity and never starts a second round without reconciliation.
Compatibility adapters may translate node-pull or dispatcher messages, but they do not
change the selected Crier launch/return authority.

**Concrete conformance trace.** Registration carries `{registration_id: reg-17,
agent_id: bunker-a, project_id: code-factory, profile: homelab-vpn,
public_identity: key-ref, capabilities: [hermes]}` and receives generation 3.
Admission carries `{round_id: r-17, run_id: run-17, corr_id: c-17,
task_scope: [CF-1, CF-2], total_budget: 2, config_generation: 17}` with no wave or
attempt IDs. The foreman creates `wave_id: w-1`, then `attempt_id: a-1`; a correction
creates `a-2`. A result with `status: unverified` remains non-passing. Missing version,
unknown field, unknown version, same-id/different-digest, and legacy `ok: true` with
`status: fail` produce `INVALID_FIELD`, `UNKNOWN_FIELD`, `UNSUPPORTED_VERSION`,
`RESULT_CONFLICT`, and `RESULT_CONFLICT` respectively.

| Canonical field | Meaning | Exists today as | Producer |
|---|---|---|---|
| `round_id` | identifies the foreman round | none — no field; correlated only in the scheduler's tick records | (target) foreman round envelope |
| `wave_id` | round-scoped wave ordinal | none | (target) foreman |
| `task_id` | board row id | board row `id` | board |
| `attempt_id` | one worker execution | none as a field; `dispatch_id` + `corr_id` pair identifies one dispatch attempt | node worker (partial) |
| `dispatch_id` | dispatch envelope identity | `dispatch_id` (`node-bus-worker.py` reply, `:1176-1192`) | node worker / dispatcher |
| `corr_id` | end-to-end correlation | `corr_id` (same reply) | scheduler envelope |
| `run_id` | execution run identity | **absent** from the reply (M2 §6, measured); required in closeout proof tables | (target) — canonical, emitted when implementation catches up |
| `status` | typed outcome: pass/fail/unverified/partial/unknown | `status` exists; the value domain is untyped in the reader (`dispatch_leg.go:713-726` reads only `ok`) | node worker |
| `ok` | legacy boolean verdict bit | `ok` (dispatcher always sets it, M11 §6; node worker does not, M2 §6) | dispatcher (reliably), node worker (not) |

Rules the schemas impose:

- **Missing status does not imply success.** A reader that treats absence as pass is the
  R-01 defect; the canonical schema requires a typed outcome — `pass`, `fail`,
  `unverified`, `partial` — and `unknown` when no verdict exists (VI §14).
- **The mapping is truthful.** Producers, consumers, registries and examples are updated
  together with the schema: no prose fix invents a field the implementation does not emit
  (there is no `run_id` in the reply today), and no integration contract silently drops
  the required correlation (the closeout proof table requires a run id — the target
  schema names it; until emitted, the gap is named here and in M2 §6).
- **Compatibility translation is explicit.** A consumer receiving the legacy
  `{dispatch_id, corr_id, status, ok}` form maps it through this table; an unsupported
  schema version is refused, not coerced.

## VII.14 Memory contracts — per worker, per wave, per round

Three record types (V2-Q-03, user-resolved), kept distinct and correlated; the **writer
is the foreman unless a section specifies otherwise** — the user required that every
worker *have* an entry, and did not require workers to hold direct memory-write
credentials (F3 step 3: "persist … through the designated supported writer; do not assume
all workers require direct write credentials"):

| Record | Written by | When | Carries | Idempotency key |
|---|---|---|---|---|
| **worker-outcome entry** | the foreman, persisting the worker's report | at each attempt's closeout | what the worker did, its typed outcome, task/round/wave/attempt ids, commit and evidence references | `(round_id, attempt_id)` |
| **wave-summary entry** | the foreman | after each wave completes | its workers and results, integration/verification outcomes, newly eligible or remaining work, budget after the wave | `(round_id, wave_id)` |
| **round-summary entry** | the foreman | at round stop/settlement | all waves, aggregate outcomes, budget use, stop reason, correlation to every worker and wave record | `round_id` |

Rules:

- **Task-level traceability is preserved through linked records** — multiple worker
  attempts on one task remain distinguishable — without inventing a fourth mandatory
  record type.
- **No weekly-rollup substitution.** The scheduler's DuckBrain sync cadence (5 minutes,
  M9 §5) is a transport schedule; no aggregate of worker/wave records substitutes for
  the final round entry.
- **Board-task state and audit events remain foreman-owned**; scheduler settlement is a
  separate execution record (§12). A board note that DuckBrain is unavailable is not a
  completed memory write.
- **Outage path (V2-Q-04):** on temporary unavailability the foreman continues useful
  work and creates durable pending entries at every level, using the local Git-backed
  namespace (supported local persistence) when the HTTP path is down; pending
  synchronization is tracked and reported (VI §30). Scheduler records and Git history
  retain *parts* of the trail and do not substitute for the full pending entries.

## VII.15 Board synchronization before eligibility

Eligibility, claims and cleanup are decided against a synchronized board — never against
a stale local copy:

1. Before a round begins, the foreman synchronizes the controller and Bunker board
   copies: fetch the canonical ref (`origin/main`, VII §2), resolve the working copy's
   drift, and record the board revision the round works from.
2. Claims are made only after synchronization; a claim made on a stale copy is re-derived,
   never resumed (VI §13).
3. Between waves, results that change eligibility (closes, unblocks) are written through
   the board's own write path and re-read before the next wave is composed.
4. Cleanup at round end classifies against the same synchronized revision.

The revision the round worked from is part of the round report — the proof §2's read-path
rule demands ("it reports which source it used"), bound into the round contract.

### VII.15.1 Eligibility, claims and partial-write recovery

Eligibility is a canonical predicate evaluated against the synchronized revision. A row is
eligible only when its status is `pending`, its dependencies resolve to `complete`, its
acceptance criteria are non-empty and executable, no active claim lease exists, and its
project/lane scope is admitted. `in_progress`, `blocked`, `deferred`, malformed, cyclic,
unknown-project and stale-revision rows are not eligible; an unreadable board is an
`ELIGIBILITY_UNKNOWN` refusal, never an empty-board result.

Claims use exactly Part I §1.9.6 and CT-10's canonical object: task_id,
board_revision, claimant_id, claim_id, lease_expires_at and claim_generation,
plus project owner_fence at the broker boundary. M4's owner_id/lease_until/
fence_token/expected_revision names are legacy aliases translated only by its adapter;
they are not accepted alternate canonical keys. The foreman requests and Boardctl
publishes the row/event/claim candidate tree via broker ref CAS. A CAS loser receives
CLAIM_CONFLICT and re-derives; a stale owner receives STALE_OWNER. Lease expiry alone
never authorizes replacement. Resource enforcement is VI.35.2, not a local Git lock.

Closeout is idempotent by `(task_id, claim_generation, evidence_run_id, tree_digest)`.
Validation refusals before staging leave canonical state unchanged. Any partial
staging/publication or event failure records PARTIAL_WRITE with operation ID and
marks scheduling UNAVAILABLE until M4 repair reads the remote ref, verifies the
row/event/claim set and either adopts it or retries from the current revision.
No blanket unchanged-store claim applies to an uncertain publication. Scheduler admission may decide whether
a lane runs, but it cannot claim a task or substitute for this foreman-owned board
transaction.

## VII.16 Round crash recovery without double-counting

A round that crashes mid-flight recovers from durable state, and three accounting rules
keep the recovery honest:

- **Budget is read from the ledger, never re-derived.** The reservation/consumption
  ledger (§12) is updated *before* each wave launches; a recovered round resumes with the
  consumed remainder, not a fresh allowance (R-29's silent-reset class).
- **Work is reconciled before it is resumed.** Completed tasks are identified by their
  evidence-bound board closeout plus merged-tree proof; a recovered round does not
  re-execute them. An attempt whose outcome is unknown (crash between execution and
  result) is first queried by its preassigned `attempt_id`/`dispatch_id` and checked for
  descendant quiescence, durable board, Crier, Git and memory side effects. Only when
  reconciliation proves no authorized execution or side effect remains may the foreman
  create a new attempt id; otherwise it records the existing result or quarantines the
  task as `UNKNOWN_START`. The attempt lineage (§8) records every case, and a control-side
  idempotency check alone never authorizes a rerun.

- **Protected writes are fenced at the resource.** Board events, Git publication,
  Crier bindings and memory commits use the broker/authority serialization in
  VI.35.2 with the active claim_generation/owner_fence; a stale controller lease is insufficient. A
  resource returns `STALE_OWNER` without mutation. If descendants or external effects
  cannot be proven quiescent, the execution remains quarantined and the project is not
  ready for replacement admission.
- **Memory writes complete before the round reports.** The recovered round reconciles
  pending memory entries (§14's outage path) before its round-summary entry; the report
  states local-persistence, Git-commit and remote-synchronization as distinct states
  (V2-FLW-05's acknowledgement discipline).

The recovery sequence is F8's, applied at round scope: detect and persist the incident,
fence stale actors (R-27), reconcile Crier custody and scheduler attempts against the
ledger and published commits, resume, and retain the recovery evidence.

## VII.18 Concrete records, deterministic waves and settlement (P5-C-15/28/29/38)

The canonical outer envelope and inner body versions are Part I §1.9.1; VII.13's
schema table is an index, not permission to omit body.schema_version or flatten
fields. Its examples show body fragments only. Admission is round-admission.v1;
round-request.v1 is retired. IDs are assigned at the boundaries in VII.13/M11.16.
worker-result.v1 has required correlation IDs, status and finished_at plus commit,
artifacts, evidence_refs and error keys. For pass, commit is a full Git OID,
artifacts/evidence_refs contain at least one digest-bound verification record and
error is null. For fail/partial/unverified/unknown, commit may be null and lists may
be empty; error is required Part I Error and names failure/refusal phase. Thus a
pre-launch refusal has status fail, commit:null, artifacts:[], evidence_refs:[],
error code HARNESS_UNAVAILABLE with retryable:true; it is valid, not fabricated work.
A supervisor refusal receipt in its ledger provides the audit trail independently.
A missing status is INVALID_RESULT, not auto-converted to unknown; only an explicit
legacy adapter may create unknown plus a missing-verdict diagnostic. §13's blanket
non-null rule excludes these declared nullable fields and empty failure collections.

An accepted initiative is initiative.v1: id,project_id,revision (positive integer),
title (1..512 characters),status (proposed/accepted/cancel_requested/cancelled/accepted_delivery),
criteria (1..1024 Criterion),task_ids (ID set),accepted_by (principal ID),accepted_at
(UTC),input_digest. A task.v1 contains id,initiative_id,project_id,title,status
(pending/in_progress/blocked/deferred/complete/cancel_requested/cancelled),dependencies
(ID set),criteria,created_seq (nonnegative integer),paths (1..1024 normalized
repository-relative prefixes),resources (set of `{name:ID,mode:exclusive/shared}`),
claim (M4 object or null),evidence_refs (digest refs, empty until available).
Criterion is `{id,description,argv,cwd,timeout_s,expected_exit,oracle_digest}`; argv is
nonempty string array, cwd is safe repo-relative path, timeout_s 1..1800, expected_exit
0..255 and oracle_digest identifies the versioned assertion/fixture code. Evidence
is `{criterion_id,run_id,commit,tree_digest,argv_digest,exit_code,stdout_digest,
stderr_digest,started_at,finished_at,outcome}` with outcome pass/fail/unknown.
All records use canonical JSON, explicit schema_version, unknown-key rejection and
append-only revision CAS via M4. Priority is lane-only; task ordering is below.

On a fixed synchronized board, compute eligible tasks using VII.15, then sort by
(created_seq,id), bytewise ID tie-break. Scan once: admit a candidate iff all its
dependencies are already complete at that snapshot, its path prefixes have no ancestor/
descendant overlap with selected tasks, and no equal resource name is exclusive on
either task. Repository-wide/generated-file effects declare path `.`; undeclared
write paths are BRIEF_SCOPE_VIOLATION, not post-hoc compatibility. Stop selecting at
min(remaining worker allowance, free concurrency); skip conflicts and keep scanning.
The snapshot, sorted candidates, selected set and rejection reasons form wave-plan.v1.
Claims CAS as a group; any conflict refreshes and re-derives before launching any
member. Integration follows the same selected order; a conflict halts the wave's
publication pending correction, never silently reorders merges.

Cancellation is requested by the initiative owner through authenticated boardctl
adapter POST `/v1/projects/{id}/initiatives/{initiative}/cancel` with expected_revision,
reason and idempotency_key. It records cancel_requested, blocks new claims, invokes
M11 cancel for live launches, and retains completed publications. Only quiescence
and durable partial outcomes permit cancelled; unknown children remain quarantined.
A foreman can stop its round for deadline/budget without cancelling the initiative.
project-acceptance.v1 contains project_id,initiative_id,initiative_revision,published_oid,
criteria_results (one Evidence per criterion),task_refs,round_report_refs,memory_receipts,
reviewer_id,accepted_at,outcome. outcome is accepted/refused/unknown; accepted requires
all criteria pass on the SAME published tree, closed tasks and all required receipts.
Owner acceptance, when required by initiative, is a separate signed decision ref.

The CSV fixture fixes columns `[name,count]` and records
`[{name:"a,b",count:2},{name:"quoted\"name",count:0}]`. T1 owns src/export and tests/export;
T2 owns src/cli and tests/cli; T3 owns tests/roundtrip and depends on T1/T2. Their
created_seq values are 1,2,3. Each criterion invokes its repository-owned assertion
via argv without a shell; T3's oracle parses generated CSV and compares column order,
quoted names and integer values with this exact input, then checks the CLI exit is 0.
With two slots the deterministic selected set is T1,T2; next wave waits for their
published-tree closeouts. A reversed-column or dropped-column mutation fails T3;
a correct round trip passes. These are required fixture cases, not reports of a run.

### VII.18.1 Git memory layout and local interface

Each namespace is a Git repository rooted at V.9 local_root; records live under
`records/<record_id>/<payload_digest>.json`, immutable. payload_digest is SHA-256 of
RFC8785 JSON of the entire record excluding payload_digest, with schema_version
memory-record.v1, record_id,namespace,record_type,round_id,writer_identity,created_at,
body, and scope fields. worker-outcome requires wave_id/attempt_id/task_id and body
worker-result.v1; wave-summary requires wave_id, forbids attempt_id/task_id and has
body `{worker_refs,integration_result,budget,remaining_tasks}`; round-summary forbids
wave_id/attempt_id/task_id and body is round-report.v1 excluding its own memory ref.
Ref is `{record_id,payload_digest}`. Budget is `{allowance,used,held,remaining}` integers
satisfying M9.17. No self-referential digest is constructed.

The protected local writer exposes HTTP over owner-only Unix socket
`<local_root>/writer.sock`: POST `/v1/records` accepts the record; GET
`/v1/records/{id}?digest=<hex>` reads exact bytes; POST `/v1/sync` requests brokered
publication; POST `/v1/conflicts/{id}/resolve` accepts resolution; GET
`/v1/view?after=<record_id>&limit=<1..1000>` defaults 100 and returns records sorted
bytewise by record_id,payload_digest plus next_cursor, local_commit, sync_commit,
synced_at, pending_count, conflict_count and freshness. Socket peer UID and project
capability scope authenticate; workloads do not hold a canonical push credential.
Mutation idempotency is namespace/record_id/digest, different digest preserves both
as MEMORY_CONFLICT. Local acknowledgement requires Git objects/ref and containing
directory fsync; it never claims remote synchronization.

Each writer owns `refs/heads/pending/<writer_id>`; only brokered sync owner publishes
`refs/heads/namespace`. Sync fetches declared pending refs over authenticated Git,
validates each record/fence, unions file paths by bytes, and writes a sorted
`index.json` of record IDs/digests. Conflicts are indexed, not overwritten. A
resolution.v1 record contains record_id, all conflicting digests, selected_digest or
replacement_digest, reason and authorized resolver identity; every original survives.
The canonical view chooses only a valid resolution or a single nonconflicting digest;
unresolved IDs are returned as conflicts, never arbitrary last-writer-wins.

Canonical merge uses sorted unique parent OIDs, fixed author/committer
`factory-memory-sync <factory-memory-sync@invalid>`, timestamp equal to the maximum
parent commit timestamp, message `memory merge <index SHA-256>`, no signatures in
commit bytes; the external broker receipt authenticates it. The same parent set and
records therefore produce the same tree/commit. Different intermediate merge history
may produce different commit IDs but must produce identical index/view digests.
Remote CAS failure fetches and recomputes; no force push. Auth/authority failure leaves
pending-sync. Freshness is now minus acknowledged sync time; >V.9 stale_after_s is
stale, null acknowledgement is unknown. Local-only mode is single-host and cannot
satisfy a cross-host settled receipt. [CT-09/15; F3; VI.30/31/35.2]

### VII.18.2 Disconnected completion

Local committed entries permit continued work and a returned execution report; they
do not settle the round. The scheduler stores REPORTED_PENDING_MEMORY with exact
record/digest refs and the authenticated supervisor receipt. It releases physical
capacity only after quiescence, keeps worker debit unchanged, and blocks the next
round for that lane until broker sync/readback proves every referenced record visible
on the control side. No local receipt substitutes for that readback. On reconnect,
the sync owner publishes once, scheduler verifies refs, then applies remaining
projections and settles. Host loss before sync is MEMORY_LOST with named missing
records; owner-approved abandonment is a separate fenced terminal failure, not
successful completion. VII.17's outage example reaches acceptance only after sync.

## VII.17 Worked example — one project through the whole chain

A worked end-to-end example (V2-WRK-05), with every step bound to its schema, setting
and observable evidence. Actors and locations are named per step.

**Intake.** The person tells their agent: "build the export-CSV feature for the report
tool." The agent refines it into an initiative plan with acceptance criteria — "a CSV
export that round-trips the current report columns, verified by a runnable check" — and
files the initiative on the project board (actor: agent, control host; evidence: an
initiative row with criteria someone else can re-run, §2's create rule).

**Dependency plan.** The foreman (next admitted round, inside its Bunker) decomposes the
initiative: three tasks — T1 "export function with tests", T2 "CLI flag wiring", T3
"round-trip verification harness" — with dependencies T1 → T3, T2 → T3 (boardctl create
with dependencies, Bunker board; §2's uniqueness rules).

**First round, wave 1.** The scheduler admits the round with a total-worker allowance of
2 (V.3 card 1). T1 and T2 are both eligible (independent); T3 waits on them both. The
foreman claims T1 and T2
(board claims, after board synchronization per §15), briefs two workers in isolated
worktrees (§5's brief contract; `CF_*` variables, credentials as paths). Both implement;
both pass the commit guard and the independent judge (§6). The foreman verifies
integration — merged-tree proof (§12) — and closes T1 and T2 with evidence run ids
(`boardctl update --status complete --evidence-run-id …`; refusal without one, §2).
It persists two worker-outcome entries and wave 1's wave-summary entry (§14; writer:
foreman; DuckBrain namespace, local record). Budget: 2 of 2 consumed.

**Wave 2 — and the rejection.** T3 unblocked by T1+T2. Budget: the round is spent — the
foreman stops with stop reason `budget_spent`, returns the round report through Crier
(all waves, outcomes, budget use, remaining work: T3), and the scheduler settles it
durably (§12). No worker was spawned for T3 — the cap is not a quota (§11).

**Second round; fixup.** The next admitted round claims T3 (allowance 1). The worker's
attempt 1 fails the judge: the round-trip check drops a column ("changes-requested", §8's
rework lineage). The foreman persists the worker-outcome entry for attempt 1, re-briefs,
attempt 2 passes, integration is verified, T3 closes with its evidence id. **Partial
outage:** during wave 1 of this round the DuckBrain HTTP path goes down; the foreman
continues, persists the entries through the local namespace writer, marks them
pending-sync (§14's outage path), and the round report states the three acknowledgement
levels distinctly. The sync completes after recovery (VI §30's repair).

**Project acceptance.** The acceptance demonstration (§11.9) re-runs the round-trip
check against the published tree, names all three criteria met, cites the attempt
lineage (two attempts on T3, one on T1/T2), the round reports, and the merged-tree
proofs. The project is delivered — not because the board went quiet, but because the
acceptance record demonstrates the requested outcome.

**Blocked and deferred, for contrast.** If T2's brief had named an unmet dependency, the
row goes `deferred` carrying the dependency; if its check needed a fix nobody filed, it
goes `blocked` with the one command that unblocks it (§7). A worker that cannot proceed
on a healthy system stands down — that is *busy/working*, not failed (§7's
"nothing is wrong, something is working"). The four states — busy, blocked, deferred,
failed — are distinct records with distinct owners.

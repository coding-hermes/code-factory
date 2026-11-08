# Part II — Flows

Sixteen flows carry the system from intent to evidence. Each subsection below is
ONE continuous section, in this fixed order: the flow heading, the flow's figure,
the figure caption, the explanatory paragraph directly beneath it (what the flow
accomplishes, why and when it runs, which actors perform the handoffs, where it
executes, and what state proves the result), then the precise ordered steps, the
exceptional branches, the contracts (`CT-nn`), the settings that govern it and the
owner of its metrics. Each flow also states its preconditions and inputs, and ends
with named verification scenarios — to specify and run, not results claimed by this
handbook — after the minimum contract every flow must satisfy. Section 2.17 maps
the twelve required scenario families to the flows that carry their normative
sequences. A figure is mounted at its reading position — hero-sized on
the flow's own sheet where it fits; a figure too large for a text sheet gets its
own sheet with a reference line in its place, and the flow id is repeated on every
continuation head. Nothing here is invented: every step cites the chapter text or
contract row it came from, and where a chapter marks a wire UNVERIFIED, BROKEN or
MISSING, the flow says so. Where the handbook has no measured metric for a flow,
the metric-owner line names the gap rather than inventing a counter. The sequence
diagrams are generated from `docs/SYSTEM-MODEL.yaml` by
`scripts/gen_handbook_figures.py`.

## 2.1 F1 — Dispatch and settlement

![FIGURE 2.1](figures/F1.svg)

F1 is the parent dispatch-and-return of one foreman round: a scheduler admission
becomes a bounded program of compatible worker waves inside one project Bunker and
settles back into the scheduler's durable records. It runs whenever F11 admits a
lane. The scheduler delivers the identified round request and its total-worker
allowance through Crier; the selected execution adapter launches the project
foreman inside its Bunker; the foreman reads the board and project memory, selects
and claims useful compatible work, briefs workers with acceptance criteria, model
access and isolated workspaces, verifies and publishes their results, updates each
task row with evidence, and forms the next wave from newly unblocked work while
useful work and the remaining allowance permit. The allowance covers the whole
round — wave boundaries never replenish it (V2-FLW-01/02). The handoffs are
scheduler to Crier to Bunker foreman to workers (Hermes) to commit guard and
independent judge to board and DuckBrain memory, then back through Crier to
scheduler recording; foreman-to-board and foreman-to-DuckBrain writes are foreman
ownership, distinct from the scheduler's execution-store records. The result is
proven by a durably recorded round outcome correlated by run id across all waves —
worker, wave and round memory entries, budget use, remaining work and stop reason —
together with merged-tree/publication evidence and reconciled board copies. The
worker-attempt detail (brief, commit, guard and judge verdicts, the worker's own
memory entry) is the inner cycle of step 4; F3 and F5 carry its contracts.

**Preconditions and inputs:** the lane is enabled and configured (`CT-01`); the repository and board copies were refreshed before eligibility; the board-check verifier found work; admission reserved capacity. Inputs: the dispatch envelope — run_id, corr_id, lane, board, text_b64 (`CT-02`, PROVEN); the lane prompt text (`CT-05`, UNVERIFIED); the board revision checked at admission.

**Steps:**

1. Entry from F11: the relevant board copies are refreshed and checked, eligible
   work is classified against no-work/stale/unreadable states, and the lane is
   admitted under its configured policy.
2. The scheduler delivers an identified foreman-round request and total-worker
   allowance through Crier (`CT-02`, PROVEN; `internal/bus/dispatch.go:202,266`);
   the node's bus worker pulls the message and holds a 30-second lease (`CT-03`,
   PROVEN; `scripts/node-bus-worker.py:1356,1383`), and the execution adapter
   launches the project foreman inside its Bunker.
3. The foreman reads the current board and project memory, analyzes impact through
   Hilo, selects and claims useful compatible work, and assembles worker briefs
   with acceptance criteria, model/provider access and isolated workspaces. Local
   namespace queries remain a supported path when the DuckBrain HTTP service is
   unavailable. The MVP harness is fixed — the foreman invokes Hermes directly; a
   future Task Router would sit between Node and Harness and is drawn NOT PART OF
   MVP.
4. Workers implement and produce commits under the required GitReins guard
   (Tier 1) and independent acceptance process (Tier 2) (M3 §2, M9 §6). Failed
   criteria return to correction; branch success remains distinct from verified
   merged/published work.
5. The foreman verifies the integrated/published results as required, updates each
   relevant task-board record with evidence (`CT-14`, UNVERIFIED, M4 §6), ensures
   every worker has a correlated DuckBrain entry describing its work, and creates
   a DuckBrain entry for that wave (`CT-15`, UNVERIFIED boundary, M9 §6). If the
   DuckBrain HTTP path is unavailable but the local namespace is usable, it uses
   supported native local persistence, retains worker/wave records and tracks
   pending synchronization while continuing useful work.
6. The foreman recomputes the work unblocked by those results and forms the next
   compatible wave while useful work and the remaining total-worker allowance
   permit. Wave boundaries do not replenish the budget.
7. At the end the foreman creates a DuckBrain summary for the complete round,
   linked to its worker and wave records, and returns through Crier a correlated
   report covering all waves, task/worker outcomes, evidence, budget use, remaining
   work and stop reason (`CT-06R`, UNVERIFIED; Crier correlates it into the
   scheduler's durable inbox, `CT-06`, PROVEN, `internal/registry/handler.go:170,1452`).
   The final round entry is likewise durably captured locally; local persistence,
   Git commit and remote synchronization are reported as distinct states.
8. The scheduler durably records the round result. The end-of-lane repository/board
   refresh and verifier then produce explicit results whose order and
   final-acceptance effect are defined so a required post-hook failure cannot be
   hidden by an earlier success record.

**Exceptional branches:** settlement must distinguish delivery acceptance, running,
interrupted, rejected, partially published and settled results — but the measured
implementation reads only `ok` (`dispatch_leg.go:713-726`), so a node reply carrying
`status:"failed"` and no `ok` — the field `node-bus-worker.py:1180` actually sends —
is scored a success (CF-355, M9 §2). An unacked message redelivers after lease
expiry; reconciliation on replay must not duplicate accepted publication or reset
the round budget, and an empty inbox list is not a lost message (M10 §11). A failed
POST closeout hook never changes the recorded outcome; its failure must stay
visible in the final accepted state rather than being absorbed (M9 §3). On DuckBrain
unavailability the round continues on local native memory with pending
synchronization tracked (V2-FLW-05, F3).

**Contracts:** `CT-01` admission configuration (UNVERIFIED), `CT-02` dispatch
envelope (PROVEN), `CT-03` lease/redelivery (PROVEN), `CT-05` lane prompt
(UNVERIFIED), `CT-06`/`CT-06R` durable return, `CT-09` memory records (MISSING),
`CT-13` verdict evidence, `CT-14` board closeout, `CT-15` memory boundary.

**Settings:** lane cadence, weight, pin and admission mode (`CT-01`,
`fleet.example.toml:15,35`); the total-worker budget per foreman round with durable
reservation/consumption accounting and remaining-budget readback; the lane hook
plan (PRE/POST steps and fail-open/fail-closed posture,
`scripts/hooks/hooks.example.toml`); lease and reply deadlines.

**Metric owner:** the scheduler's tick/spawn/deferral counters at
`GET /api/v1/metrics` (M9 §8) cover settlement; the round's remaining worker budget,
per-wave progress and stop reason have no measured counter — named gaps, not
satisfied requirements.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. A task unlocks additional compatible tasks; the foreman forms another wave without replenishing its total-worker allowance; board evidence, worker/wave/round memory and scheduler records correlate.
2. Redeliver a previously settled request; reconciliation does not duplicate accepted publication or reset the round budget.
## 2.2 F2 — Provisioning

![FIGURE 2.2](figures/F2.svg)

F2 turns a declared host/project deployment into a ready Bunker runtime, and it is
the path for three distinct intents: factory bootstrap, adding a project, and
replacing a failed runtime. It runs when the operator (or the management layer, on
host loss) declares a lane or a replacement. The management layer selects eligible
capacity under the deployment profile, drives the declared installation path, and
verifies the effective application, configuration, credentials, project files and
memory — creation alone does not make a target ready for scheduled work. The
handoffs run from the desired-deployment request through host selection and the
Bunker/native installation path to readback verification and finally a verified
Crier/scheduler binding. The result is proven by a verifier ladder with every leg
VERIFIED, a readback of effective host/isolation/resource settings, and a
registered routing binding that matches the verified identity and readiness.

**Preconditions and inputs:** the host meets the disk floor; the lane declaration exists; the Bunker deployment profile is chosen for this Bunker. Inputs: the lane declaration (project, harness, pin); the node manifest (prompts, skills, env); the seed repo and embedded board; Crier registration material; the per-Bunker DuckBrain namespace credential.

**Steps:**

1. Validate the desired project/repo, deployment profile, host pool,
   resource/storage requirements and references to credentials and versions;
   distinguish factory bootstrap from adding a project or replacing a failed
   runtime (M1 §3).
2. Select an eligible host using current health and capacity — the host must meet
   the disk floor; reserve and account for the allocation and persist a resumable
   provisioning operation.
3. Use the declared Bunker/native installation path to prepare the project
   workspace, repository and embedded Boardctl board, local DuckBrain namespace,
   Hermes and model access (M1 §3 S2 — container, per-agent home, layered node).
4. Provision/install authorized configuration and scoped credential
   references/material using the documented distribution path; keep issuance
   authority distinct from installation (resolved decision: install/provisioning
   scripts transport credentials).
5. Read back effective state and verify repository access, application readiness,
   memory paths, runtime permissions and required service connectivity — CREATED
   is not VERIFIED (M1 §12).
6. Register or replace the target binding in Crier and scheduler; confirm matching
   identity/readiness before enabling admission, and retain evidence and the actual
   allocation.

**Exceptional branches:** the certification ladder awards VERIFIED per leg — agent,
gateway, auth, artifact, tree, seed — and an unreachable port is UNVERIFIED
(exit 3), not FAIL (M1 §10, CF-224). The node's registration producer half is not
established; crier's `HandleRegister`/`HandleRegisterByID` are named, the wire is
UNVERIFIED (M1 §6). A partial failure re-runs from the manifest: the seed reapplies
and names drift per file (M1 §3 S4). Preparation steps persist which legs
succeeded, so retry is idempotent or compensates named partial resources, and
created-but-unverified is never reported as ready. If no eligible capacity
satisfies the request, desired state is retained, the unsatisfied allocation is
exposed as a metric/event with configured webhook delivery, and host eligibility is
never silently widened.

**Contracts:** node manifest and seed (`M1 §3`); registration producer/wire
(UNVERIFIED, M1 §6); verifier ladder legs (M1 §10–12); crier registration
`HandleRegister`/`HandleRegisterByID` (UNVERIFIED).

**Settings:** disk floor; the Bunker deployment profile (fresh image-backed or
persistent container) and per-Bunker Factory configuration with setup/readback;
harness pin; registry and namespace credentials.

**Metric owner:** none measured — the chapters name no provisioning counter; the
verifier's per-leg ladder is the record of record (M1 §11).

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Provision a new project under each supported profile; the target cannot receive work before its readiness and routing checks pass.
2. Lose a selected host mid-install; partial allocation is reconciled and resumed or replaced without registering two active owners.
## 2.3 F3 — Memory

![FIGURE 2.3](figures/F3.svg)

F3 is project memory end to end: the foreman uses project memory before planning
work, and the system preserves a distinct record of every worker, each wave and the
completed round. It runs at every brief, every wave close and every round settle,
and at any later recall by project, week or lane. DuckBrain stores local namespace
data in Git-backed repositories on the machine, so a failed HTTP service does not
by itself remove local access (V2-Q-04): local keyed/keyword/read-only queries and
supported local persistence continue against the same configured namespace and data
root. The handoffs run from namespace resolution through pre-brief recall, the
designated writer persisting each worker's correlated description and outcome, the
foreman's wave and final-round summaries, to synchronization that converges the
controller and Bunker views under a declared freshness and conflict policy. The
result is proven by read-after-write: the written record is retrievable under the
intended namespace with its correlation intact, with native persistence
acknowledgement, Git commit state and pending/complete remote synchronization
recorded as three separate states.

**Preconditions and inputs:** the DuckBrain namespace exists and is configured per project; the writer holds the namespace credential (M1 §3). Inputs: run records with run correlation (R1 detail, R2 fleet index); foreman decisions, findings and goals (R3 rollup); recall queries by project, week and lane.

**Steps:**

1. Resolve the configured project namespace, local data root, authorized access
   path and controller/Bunker synchronization mapping (M1 §3, M9 §5).
2. Query relevant local or available service memory before briefing and return the
   selected context with provenance and freshness; retrieved records are pointers
   requiring verification, not verified facts (M9 §6).
3. Persist a correlated description and outcome for every worker through the
   designated supported writer (`CT-09`, MISSING — CF-329, M2 §6); do not assume
   all workers require direct write credentials (V2-FLW-02).
4. After each wave persist the foreman summary, then add a distinct final-round
   summary at stop/settlement — a weekly rollup is not the final-round record.
5. Record native persistence/durability acknowledgement, Git commit state and
   pending/complete remote synchronization as separate states; Git backing alone
   does not establish crash durability or synchronization.
6. Synchronize under the declared owner, resolve conflicts and duplicates, and
   make freshness and deferred synchronization visible to subsequent readers.

**Exceptional branches:** continue useful work with native local reads/writes when
the HTTP path is down (V2-FLW-05). Six failure classes are distinguished, not
conflated: service/API failure, network disconnection, semantic-provider failure,
stale or missing local data, native write failure, and remote-sync failure;
semantic search may have additional provider dependencies that keyed and keyword
local queries do not share. Recover pending synchronization after restart; protect
local unsynchronized records from cleanup/TTL/rebuild (F6) and state what can be
recovered if an unsynchronized host is lost. Scheduler records and Git history are
supporting evidence with limits — a board note about unavailable DuckBrain is not a
completed memory write, and remote memory unavailability is never silently promoted
to lost records. The measured defect stands: `node-bus-worker.py` makes zero
DuckBrain calls, so no R1 or R2 record exists to recall (CF-329, M2 §6); a
per-Bunker instance cut off from the controller view is a shared-view consistency
failure whose offline/reconnect behavior remains an open requirement, not a handled
case.

**Contracts:** `CT-09` structured run-record sync (MISSING), `CT-15` foreman memory
boundary (UNVERIFIED), namespace credential (M1 §3), sync cadence for cron-side
writers (M9 §5).

**Settings:** namespace selection (explicit per project — an omitted namespace
falls back to sticky active configuration); HTTP/MCP auth (`x-api-key`); local data
root and native persistence mode; sync cadence, retry/backoff and conflict policy
for controller/Bunker copies (M9 §5).

**Metric owner:** none measured — no recall-quality or sync-lag counter exists; the
gap is named in M9 §8.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Stop the HTTP service while local namespaces remain healthy; local recall plus worker/wave/round persistence and later convergence hold.
2. Replay a partially synchronized round; stable record identities prevent duplicate history or lost entries.
## 2.4 F4 — Documentation

![FIGURE 2.4](figures/F4.svg)

F4 converts approved product intent and versioned sources into an implementable,
internally consistent handbook issue. It runs when a module needs an approved
document: the foreman opens a skeleton, seats fill it with cited facts, checks and
panels grade it, and the built book reaches the operator. The actors and handoffs
are the foreman, the writing/panel seats, the doc gate, the spine gate and the
handbook builder — distinct purposes that must not collapse: writing, structural
checking, independent semantic review and rendered-page inspection each catch
defects the others cannot. The result is proven by a versioned review package with
dispositions and explicit draft/accepted status under the defined approval
authority — a successful build or a panel stop produces an artifact or a review
result, not automatic owner acceptance.

**Preconditions and inputs:** the module chapter exists in the build manifest; sources with citable locators are available. Inputs: the skeleton and source set; seat drafts; the cross-chapter set for spine consistency.

**Steps:**

1. Identify the target product requirements, source revisions, previous accepted
   issue and outstanding redlines for this document change.
2. Author the operating story, contracts, configuration, flows and evidence with
   the NASA page grammar and complete build-from-spec detail (M6 §2: the foreman
   hands the doc gate the skeleton and sources; a seat fills sections and cites
   `file:line` for every fact).
3. Run structural/schema/reference checks and independent semantic reviews; the
   doc gate returns PASS or named refusals (`CT-16`;
   `scripts/master_doc_check.py:263`), and three panel seats grade independently
   with splits reported, never voted away (M6 §3 S4).
4. Reconcile changes across components, flows, settings, risk, work derivation,
   delivery and linked documents — the spine gate checks canonical CT ids, states
   and dangling references (M6 §3 S9).
5. Build and inspect actual pages, including figure/prose adjacency, legible
   message labels, unique IDs and complete schemas/examples (M6 §6).
6. Issue a versioned review package with dispositions and explicit draft/accepted
   status under the defined approval authority (`CT-18`, M6 §6).

**Exceptional branches:** the doc gate is structural, not a truth verifier — it
cannot tell whether a sentence is true (M6 §2). `CT-16` was downgraded from PROVEN:
the handbook build reads no MASTER-DOC output, so the receiver half is uncited
(M6 §6). A panel STOP exit is process success, not document acceptance (M6 §5); a
budget or no-progress stop is a review termination reason, and material unresolved
issues stay attached to the issue package. If a source or requirement changes
during review, affected sections are marked for revalidation rather than carrying
old evidence forward unqualified. A semantic contradiction that passes format
checks must still be caught by semantic review before an unqualified accepted issue.

**Contracts:** `CT-16` doc gate (downgraded — receiver half uncited), `CT-18`
delivered status per module, build manifest `BOOK.yaml`.

**Settings:** panel seat budget and model pins; the build manifest; print
constraints (page size, fonts, the 2.05 mm label floor).

**Metric owner:** none measured — gate outcomes are per-run exit codes, not
counters.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Introduce a semantic contradiction that passes format checks; semantic review still blocks an unqualified accepted issue.
2. Trace one user redline into its revised flow, schema, diagram and acceptance evidence, with no orphaned old statement.
## 2.5 F5 — Landing

![FIGURE 2.5](figures/F5.svg)

F5 carries worker changes from an isolated branch to verified accepted publication
under the project policy. It runs whenever a worker holds a candidate commit that
must reach main. The actors and handoffs are the worker committing under the guard,
the independent acceptance judge, the integration/publication step that merges by
the configured policy, and the foreman closing the board item only after the
required verdict and publication evidence match the work being accepted. A commit
guard only authorizes its guarded action; it does not establish independent
acceptance or prove the published tree — guard, judge, merged-tree verification and
publication are distinct stages. The result is proven by the commit being an
ancestor of origin/main AND the board row closed bound to the accepted verdict and
retained evidence; either alone is insufficient.

**Preconditions and inputs:** a worker branch commit exists; the pre-commit hook is installed in the seeded repo; the row's acceptance criteria are gradable. Inputs: the staged diff (`CT-12`); the gate verdict (`CT-13`); the branch and commit ids; the evidence run id.

**Steps:**

1. Associate the candidate changes with the task/attempt, acceptance criteria, base
   revision and isolated workspace.
2. Run the required commit guard on the relevant content, create the permitted
   candidate commit and return any refusal for correction (`CT-12`;
   `scripts/install-gitreins.sh:124`).
3. Run independent acceptance and record verdict/evidence bound to the candidate
   content and criteria (`CT-13`).
4. Integrate by the configured PR/direct-merge or other supported policy, resolve
   conflicts and account for concurrent base movement; the foreman proves the
   commit is an ancestor of origin/main (M3 §2), rerunning the gates on the merged
   tree as the same owner requires.
5. Verify the integrated/published tree and required checks, recording destination
   revision and evidence; rerun invalidated checks as policy requires.
6. Return publication evidence to the foreman; update the task board and
   worker/wave memory through recoverable closeout steps (`CT-14`, completion
   requires `--evidence-run-id` on `boardctl update`, M4 §6).

**Exceptional branches:** rejected criteria return to correction; missing required
verification cannot become accepted merely because a hook exits successfully. The
hook side is pinned, but that git invokes the hook is unproven (M3 §6, M3 §11);
where the gate is absent the pre-commit hook exits 0 — a silent bypass that must be
disclosed (M3 §10). A best-effort refresh warning cannot silently establish
publication proof (M3 §2). If publication succeeds and the board/memory update
fails, reconcile the actual published revision and finish closeout without
publishing the same work again; interrupting after publication but before closure
must replay to one publication and evidence-backed closure.

**Contracts:** `CT-12` staged diff/guard, `CT-13` verdict, `CT-14` board closeout
with evidence id; GitReins pin and hook installation (M3 §2).

**Settings:** GitReins pin and hook installation; gate policy — mandatory versus
optional checks, and the owner-waiver rule for judged-versus-Tier-1-only passes
(M3 §2).

**Metric owner:** none measured — no landing or gate-latency counter exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Accept a branch candidate, then change the base before merge; required integrated-tree checks still run and bind to the published result.
2. Interrupt after publication but before task closure; replay preserves one publication and completes evidence-backed closure.
## 2.6 F6 — Maintenance

![FIGURE 2.6](figures/F6.svg)

F6 reclaims eligible resources and measures drift while preserving active work,
evidence and local unsynchronized memory. It runs on the configured periodic or
capacity-driven maintenance pass against disks, branches, caches and freshness.
The actors are the provisioner and safety reaper on the control host working
against node hosts and job dirs, with freshness probes against nodes and
checkouts. Cache cleanup, package/image lifecycle and repository freshness are
distinct operations with explicit ownership — installed harness packages and
images use M5 lifecycle operations, not generic cache deletion. Age alone does not
establish that a resource is safe to remove: live ownership, protected paths,
evidence retention and pending memory synchronization are resolved before any
destructive action. The result is proven by the pass's own record — what was
reaped, what was retained or refused and why, and the measured (not merely
logical) freed bytes.

**Preconditions and inputs:** the maintenance window/pass is scheduled; protected paths are declared before inspection. Inputs: TTL configuration for caches and job dirs; the live agent registry; the protected-path list; gitleaks scan-scope claims.

**Steps:**

1. Trigger the configured periodic or capacity-driven maintenance operation and
   inventory the scoped candidate resources (M8 §3 S1: `reclaim_disk` reaps build
   caches and job directories past the 24-hour TTL).
2. Resolve live runtime/worker/claim ownership, protected paths, evidence
   retention, backups and pending memory synchronization before selecting
   destructive actions.
3. Classify eligible, retained, refused and unknown resources; keep uncertainty
   visible and apply the declared destructive-action authority (`node_hygiene`
   removes orphan homes and keys after a 60-minute grace, M1 §5).
4. Perform eligible cleanup through the correct resource owner; use M5 lifecycle
   operations for installed harness packages/images rather than treating them as
   generic caches.
5. Measure results, free capacity and repository freshness — `repo_freshness`
   measures how far a workdir lags origin (M3 §5), the verifier's `node_freshness`
   measures branch, HEAD and lag on the node (M1 §11) — reporting each operation
   and retained/refused reason.
6. Update actual capacity and reconciliation observations; retry or escalate
   unresolved pressure through events/metrics under configured policy.

**Exceptional branches:** the TTL governs age, not citation; the reaper can delete
a directory a module cites as evidence (M8 §2). A gitleaks claim without its
`--log-opts` scope is refused (M8 §2). Safety refuses protected paths before
inspection — the repo, `node.json`, `crier.json` (M8 §5); a refused path stops the
pass for that path, not the remaining targets. An unknown active owner or retained
evidence cannot be treated as an expired cache, and a failed deletion produces a
partial maintenance result whose reported reclaimed capacity reflects actual, not
planned, bytes. Symlink/path boundaries and runtime ownership are verified with
the selected implementation contract, never inferred from an old directory
timestamp.

**Contracts:** TTL and grace configuration (M8 §3 S1, M1 §5); protected-path
refusal (M8 §5); gitleaks scan-scope claim (M8 §2).

**Settings:** cache and job TTLs; the hygiene grace period; the protected-path
list; the scan-scope requirement.

**Metric owner:** the reaper's own freed-byte accounting is measured per pass; no
fleet-level maintenance metric is served anywhere (M9 §8 gap).

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. An old job directory is still active and a second old directory holds unsynchronized memory/evidence; both survive cleanup.
2. Simulate a partial deletion failure; reported reclaimed capacity reflects actual results rather than planned bytes.
## 2.7 F7 — Monitoring

![FIGURE 2.7](figures/F7.svg)

F7 establishes whether the requested factory and project services are healthy,
ready and making useful progress. It runs on operator request, on cadence, or from
the management layer's reconciliation loop, and it observes application and
credential failures inside an otherwise healthy Bunker as well as host/runtime
failures — Bunker liveness is not project readiness. The actors are the read-only
HTTP surfaces on the scheduler, crier and proxy, and the management layer that
compares observed with desired state; deterministic recovery uses authorized
policies, while typed webhooks and metrics expose state for user-owned
interpretation and alerting — the Factory does not choose the receiver's responder.
The result is proven by a read that returns attributable series with names, types
and collection meaning defined — not a port that happens to answer.

**Preconditions and inputs:** the surfaces are running and reachable; the reader is authorized where auth applies. Inputs: HTTP reads — metrics and status endpoints; the proxy's usage JSONL.

**Steps:**

1. Declare the health, readiness, progress, capacity and authorization questions
   for each participating subsystem, with metric/event meanings and observation
   owners.
2. Collect through actual supported HTTP, local/native, file/log or state-store
   interfaces, preserving identity, time and freshness: the scheduler serves
   `GET /api/v1/metrics` — spawns, deferrals, ticks, tick duration (M9 §8) — and
   `/api/v1/status` per-project failure breakdown (M9 §5); crier serves `/metrics`,
   default-ON (M10 §8); the proxy appends a usage JSONL line per request (M12 §8).
3. Compare observed and desired state and attribute a deviation to its affected
   host/Bunker/application/credential/project scope.
4. Invoke the appropriate authorized reconciliation operation for repairable drift,
   then independently read back effective readiness.
5. Emit configured progress/state/failure webhooks to all matching destinations
   and expose metrics, including unsatisfied Bunker allocation.
6. Record continuing or exhausted recovery state. Receiver systems decide whether
   to log, page or run external repair; the Factory does not choose their responder.

**Exceptional branches:** the measured gap is coverage, not correctness — 11 of 13
modules emit no metrics, so most of the system is answerable only by grepping logs
(M9 §8, model note). A stats error that degrades queue counters to zero cannot
prove emptiness (M10 §6). Missing or stale telemetry is unknown observation, not
evidence of health, and monitoring/repair failure must itself be observable.
Subscriber outage has its own delivery state and retry policy; webhook failure is
never conflated with the health event being reported.

**Contracts:** scheduler metrics/status endpoints (M9 §5, §8), crier `/metrics`
(M10 §8), proxy usage JSONL (M12 §8); typed webhook delivery boundary (V2-OPS-02,
F14).

**Settings:** the metrics default-ON flags; scrape targets and cadence; webhook
subscriptions and endpoints.

**Metric owner:** the scheduler, crier and proxy own their own series; the other
ten modules have no owner because they have no counter — the flow's named gap.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Keep the Bunker alive while its forge credential expires; attribution is correct, renewal is authorized and repository access is verified.
2. Deliver one failure event to several configured subscribers; per-destination delivery outcomes are independent and a metric is independently queryable.
## 2.8 F8 — Recovery

![FIGURE 2.8](figures/F8.svg)

F8 resumes useful work after a process, service, controller or host failure without
losing accepted results or creating competing owners. It runs when a crash, a
restart, a partition or an orphaned run leaves work in an unknown state. The
deterministic management layer reconciles durable execution records, actual
processes, claims, the total-worker budget, project publication and memory; native
platform restart (Kubernetes restoring a pod) and Factory replacement through F2
are distinct mechanisms, and both must leave consistent routing and readiness. The
handoffs run from incident detection through ownership fencing, Crier/scheduler
reconciliation and runtime recreation to verified readiness and resumed work. The
result is proven by the affected row and run being in a named state with a recorded
reason — never silently dropped — plus the reconciled board row and the
replay/redelivery record.

**Preconditions and inputs:** the crash site is identified; no writer is mutating the affected state. Inputs: the replay ledger; crier's unacked inbox messages; the board lock state; the session store's stale sessions.

**Steps:**

1. Detect and persist a recovery incident with affected scope, last durable
   checkpoint and current observation quality.
2. Resolve active ownership and fence stale actors before allowing replacement
   work; inspect existing runtime/process state where reachable — a partitioned old
   host may still be running, and unreachability alone proves neither termination
   nor safe replay (V2-ARCH-01).
3. Reconcile Crier delivery/custody and recorded results with scheduler attempts,
   board claims, the total-worker budget and actual published commits.
4. Resume or complete partial work where supported; otherwise recreate the runtime
   on eligible capacity through F2 with preserved/restored project and memory
   state.
5. Update Crier identity/endpoint binding and scheduler eligibility consistently,
   verify readiness and reconcile late/duplicate results.
6. Resume allowed work and retain recovery evidence; emit typed state/failure
   events and allocation metrics if convergence remains impossible.

**Exceptional branches:** the replay ledger only proves what it durably contains —
the dispatcher replays the recorded result on redelivery instead of re-running
(`dispatcher.py:470-475`, M11 §3 S2), but a result lost with the process is re-run
from scratch, and a missing ledger row does not prove no external side effect
occurred. Crier redelivers an unacked message after lease expiry; an empty list is
not a lost message (M10 §11). The scheduler's `--reap-sessions` closes stale
sessions, dry-run without `--apply` (M9 §5); `board_read` resolves the board from
origin/main when the working copy drifts (M4 §3); a `board_lock` ERROR verdict
means lock state is unknown — stop and diagnose, never write (M4 §3). The
dispatcher's deadline kill terminates run.sh's process group, not the harness's own
group, so the kill-the-group guarantee is withdrawn (M11 §2); unknown-start
reconciliation is a required behavior, not an implemented one (M11 §2). Restarting
the controller must not replenish worker allowance or dispatch to a stale target,
and automatic repair stays within configured authority and capacity.

**Contracts:** replay ledger (M11 §3 S2), lease/redelivery (`CT-03`, M10 §11),
board lock verdicts (M4 §3), session reap (M9 §5), Crier binding update
(V2-ARCH-01).

**Settings:** lease TTLs; reap dry-run/apply flags; replay-ledger retention;
fencing/lease policy for partitioned owners.

**Metric owner:** redelivery counts exist in crier's inbox series (M10 §8); no
counter covers replay-ledger hits or orphaned runs.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Lose a host after publication but before reply delivery; task/evidence state is reconciled and duplicate publication on the replacement is prevented.
2. Restart the controller and re-read round budget/claims; the worker allowance is not replenished and no dispatch targets a stale node.
## 2.9 F9 — Degradation

![FIGURE 2.9](figures/F9.svg)

F9 defines which work remains permitted when a dependency is unavailable and how
normal operation is restored. It runs at every component boundary when a
dependency fails, and the component postures are reconciled with the project
acceptance and safety policy rather than each component choosing alone. Local
memory access can continue during a DuckBrain service outage (F3, V2-FLW-05),
while unavailable required verification leaves outputs retained and unverified —
never accepted. The actors are each component at its own boundary — scheduler
admission, guard, proxy, hook — resolving a configured degraded-mode policy and
recording the selected mode, reason and allowed/deferred/refused work. The result
is proven by each degraded interval being attributable: a named reason on a
deferred tick or a disclosed posture, never an unexplained silence.

**Preconditions and inputs:** the dependency outage is detectable by the component itself. Inputs: the failing dependency's error signal (gateway down, provider outage, missing token file, absent gate).

**Steps:**

1. Classify the failed dependency and affected operation using fresh observations
   rather than assuming all service failures have the same impact.
2. Resolve the configured degraded-mode policy and record the selected mode,
   reason and allowed/deferred/refused work.
3. Continue supported local memory and durable recording where usable; defer
   operations that require unavailable transport, capacity, credentials or
   verification.
4. Preserve pending effects and useful output with stable identities while bounded
   retries/recovery run under policy.
5. Expose mode/state transitions through metrics and configured webhooks without
   prescribing receiver actions.
6. On recovery, verify the dependency, reconcile pending operations and
   re-evaluate admission before leaving the degraded mode.

**Exceptional branches:** the measured postures disagree by design — the gateway
tick is deferred, not exec-spawned (`no-exec-fallback=true`, M9 §5); the load gate
defers new spawns at or above the threshold (M9 §3); the guard fails open on
provider outage unless policy is FailClosed (M10 §10); the proxy fails closed at
startup — no token file or no upstream key exits 2 (M12 §11); the commit gate
absent leaves the pre-commit hook exiting 0 — a silent bypass that must be
disclosed (M3 §10). The only one of the three that is fail-closed and measured is
the proxy's startup check. Existing fail-open or passing-absent-hook behavior is
implementation evidence requiring explicit target disposition; it does not
authorize accepted publication without required checks. For DuckBrain, service
outage, local storage loss, stale remote view and semantic-provider loss are
different states with different recoveries. Recovery is the dependency's own
recovery plus the next cadence tick; nothing re-queues the degraded interval's
work automatically beyond the policy's pending-effect rules.

**Contracts:** `no-exec-fallback` (M9 §5), guard posture policy (M10 §10), proxy
startup check (M12 §11), hook installation completeness (M3 §10), local memory
fallback (F3, V2-FLW-05).

**Settings:** `no-exec-fallback`; the guard's fail-open/FailClosed policy; the load
threshold; hook installation completeness; degraded-mode policy per dependency
class.

**Metric owner:** deferral counters on the scheduler (M9 §8); guard posture is
visible in crier's `/metrics` (M10 §8); the silent hook bypass is invisible by
definition — the gap is the finding.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Disable DuckBrain HTTP but retain healthy local storage; local work continues and pending synchronization is visible.
2. Make a required acceptance judge unavailable; outputs remain retained/unverified and are never marked accepted.
## 2.10 F10 — Teardown and rebuild

![FIGURE 2.10](figures/F10.svg)

F10 removes an explicitly selected deployment under its lifecycle policy, and
rebuild restores a desired runtime and its required state. Stopping, replacing and
permanently deleting a project are different intents, and planned removal, repair
and host-loss replacement take different paths through the same flow. It runs on
operator request (destroy is operator-gated) or from the management layer after
host loss. Evidence, memory and durable records remain subject to retention even
when runtime resources are destroyed — "no residue" never authorizes erasing
audit history. The handoffs run from intent resolution and draining through
quiescence and preservation, revocation and binding removal, to destruction of
eligible resources and, for rebuild, re-application of desired state through F2
with verified readiness before work re-enables. The result is proven by the
registry no longer listing the agent, the home gone, and a rebuild's seed diff
naming every restored file — readback, not intention.

**Preconditions and inputs:** destroy is operator-gated; the target agent is named; nothing active holds the node's work. Inputs: the agent name and `--yes`; the seed manifest for rebuild.

**Steps:**

1. Resolve the requested stop/remove/rebuild intent, target, configured authority
   and retention policy; mark the deployment draining and prevent new assignments
   (`--destroy` requires `--yes` and a named agent, M1 §5).
2. Quiesce or checkpoint active work and prove process/claim state; preserve
   required workspace, memory, evidence and durable control records.
3. Revoke or retire old identity/access as appropriate and remove stale
   routing/scheduler bindings without erasing audit history.
4. Destroy only eligible resources using the supported Bunker/platform path — the
   provisioner removes the container and the per-agent home (M1 §5) — then verify
   actual remaining resources and ownership.
5. For rebuild/replacement, reapply desired state, restore preserved data and
   install valid replacement access through F2 — the rebuild reapplies the seed
   from the manifest, naming drift per file (M1 §3 S4).
6. Verify application readiness and new bindings before re-enabling work; emit
   lifecycle and failure events with retained operation history.

**Exceptional branches:** the orphan-home reap runs against a live-registry check
(M1 §10), and the reaper's 60-minute grace refuses a home reclaimed inside the
window (M1 §5). Destroy is operator-gated, not foreman-reachable — the chapters
name no autonomous destroy path. No chapter measures residue left inside the
container image itself; the teardown claim stops at the home and container
boundaries. Partial destruction is not a completed removal: remaining resources
are persisted and retries target the same authorized operation. Host loss may
prevent quiescence or local preservation; explicit ownership fencing applies and
the actual recovery point/loss boundary is reported. An interrupted teardown
retried must leave unrelated projects and retained evidence unaffected.

**Contracts:** destroy flags and grace (M1 §5), orphan-home live-registry check
(M1 §10), seed manifest/diff (M1 §3 S4), F2 replacement path.

**Settings:** the destroy flags; the grace period; the seed manifest; retention
policy for evidence and memory.

**Metric owner:** none measured — teardown has no counter; the refusal records are
the trace.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Rebuild a Bunker with pending local memory and active work; the preservation/checkpoint policy holds and routing is fresh and verified.
2. Interrupt teardown and retry; unrelated projects and retained evidence are unaffected.
## 2.11 F11 — Scheduling admission

![FIGURE 2.11](figures/F11.svg)

F11 determines whether a lane can start useful work under current board,
readiness, capacity and pacing policy — and if not, why not, by name. It runs on
the lane's cadence tick or a supported wakeup, before any F1 round. It uses fresh
board information and one eligibility rule shared with the foreman: an empty
board, dependency-blocked work and an unreadable or stale board have different
outcomes, and an unreadable board is never treated as no work. The actor is the
scheduler on the control host, reading the board's local copy after refreshing it
against remote. The result is proven by an admission or refusal record carrying
its reason and the board revision it was based on.

**Preconditions and inputs:** the lane is enabled (`CT-01`); the repository and board copies were refreshed before eligibility — the approved target — and the checked revision is recorded. Inputs: the resolved admission configuration (`CT-01`, UNVERIFIED); the board's workability signal; usage-pool state; the tick cadence.

**Steps:**

1. On the configured cadence or supported wakeup, resolve current lane/project
   configuration and deployment readiness.
2. Run the required repository/board refresh before the workability decision and
   read the relevant board version and ownership — the revision checked is
   recorded (today's PRE lane hook runs after admission, not here; the gap is
   shown, not concealed).
3. Compute eligible work, dependencies and claims using the canonical lifecycle
   rules; distinguish no work from unavailable information — WORK, NO-WORK and
   UNREADABLE are distinct outcomes (M9 §3).
4. Evaluate applicable admission, capacity, fairness, load and pacing rules and
   durably account for reservations: admission mode resolves project override,
   then namespace default, then cooldown (`admission_mode.go:98,112`); usage pools
   reserve or emit a capacity denial; the board-stasis gate excludes an unchanged
   cooldown builder lane (`packer_select.go:474,614`); NOOP-PACING spaces a
   no-artifact lane, doubling to 8 times the floor (`noop_pacing.go:74`).
5. If admitted, send the identified round through Crier (`CT-02`, PROVEN); if
   deferred or refused, record the exact reason, release unused reservations and
   define the next eligible wakeup.
6. After settlement, perform the required repository refresh and board-check
   verifier; record their results and final-status effect explicitly — a required
   post-hook failure cannot be hidden by an earlier success record.

**Exceptional branches:** refusal is always a named reason — budget hold, cooldown,
load gate, fairness, namespace allocation (M9 §3); the load gate defers rather than
drops. A failed fresh-board read is not a no-work success, and a required hook
failure cannot be hidden by an earlier successful execution record. A documented
implementation pacing constant (the NOOP-PACING doubling) is not an approved
universal target default without an explicit configuration contract. Completing a
prerequisite remotely just before admission must admit newly unblocked work via
the refresh; an unreadable board restores to named deferral with a supported
wakeup, never a false no-op completion. The admission configuration itself is
`CT-01`, UNVERIFIED.

**Contracts:** `CT-01` lane/admission configuration (UNVERIFIED), `CT-02` dispatch
envelope (PROVEN), board workability/ownership rules (M9 §3), hook plan
(`scripts/hooks/hooks.example.toml`).

**Settings:** cadence, weight, pin and mode per lane (`fleet.example.toml:15,35`);
cooldown and stasis thresholds; pool sizes; hook ordering and
fail-open/fail-closed posture.

**Metric owner:** the scheduler's admission and deferral counters (M9 §8) are the
owner; the workability scan's three outcomes are not separately counted — named
gap.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Complete a prerequisite remotely just before admission; refreshed board data admits the newly unblocked work.
2. Return an unreadable board and then restore it; the deferral is named, the wakeup supported, and no false no-op completion is recorded.
## 2.12 F12 — Credential lifecycle

![FIGURE 2.12](figures/F12.svg)

F12 provides the least authority needed by each declared project and service, then
maintains or removes that authority under policy — expiry renewal, rotation, and
rapid revocation including leak response. Forge access (GitHub, GitLab and
explicitly identified additional providers), Bunker administration, Crier
identities, memory access and model-proxy access are separate credential domains;
GitHub App semantics are not assumed to apply to GitLab or other providers
(V2-ARR-06). It runs when a token is needed, as one ages toward expiry, or when a
leak signal requires immediate revocation. Installers distribute approved
credentials; they do not implicitly own every issuance or revocation decision —
issuance/scoping authority stays distinct from installation. The result is proven
by a readback of the installed credential's scope and expiry from the consumer
side — the file's existence and age are not validity — and, after revocation, by
proven denial of the old authority.

**Preconditions and inputs:** the App private key exists at 0600; the token file paths and their consumers are configured. Inputs: the App private key; installation id; the scope request for per-dispatch tokens; the node bearer token file.

**Steps:**

1. Resolve user-owned provider/app installation, principal, project/repository
   scope, requested operations and credential reference under the declared access
   policy.
2. Use the native issuer to create appropriately scoped and expiring access,
   retaining signing/administrative authority at its specified boundary: the
   operator mints from an 0600 App private key — JWT, then installation token
   (M7 §5).
3. Distribute through the supported provisioning/install path and bind the
   credential to the exact target identity/service/resource: the token is written
   to a 0600 file, the value never printed (M7 §7); `refresh --node` installs
   `auth/github.token` on the node (M7 §5); `fleet-gh-scope` mints the per-dispatch
   scoped token the dispatcher injects (M11 §3 S4, M11 §6).
4. Verify permitted operations and denied out-of-scope operations, expiry/readiness
   and effective configuration without exposing secret values: the proxy checks
   the node bearer against the token file — fail-closed admission (M12 §6).
5. Perform authorized renewal/rotation when expiry or a configured leak signal
   requires it, and read back successful use of replacement authority.
6. Revoke affected old authority, prove denial, update operational state and
   reconcile interrupted work; emit credential state/failure events and preserve
   revoked state across restore (V2-FLW-08, F15).

**Exceptional branches:** if the issuer or renewal fails, desired access policy is
retained and unavailable current access is reported — scope is never widened and a
user primary identity is never silently substituted. The App mint was never run on
the documenting host — no App credentials exist there, so `CT-21` is UNVERIFIED end
to end (M7 §6). The node bearer half of `CT-19` is config-wired with no call site
in this repo; the proxy side is measured (401 without a token, M12 §6). An expired
file is not detected by age alone — validity needs expiry proof, distinct from
explicit revocation (M7 §6). Provider capability maps are defined separately for
GitHub, GitLab and other confirmed providers; role labels do not prove
resource-scope enforcement in Bunker. A revocation or denied permission is never
authority to silently expand a grant.

**Contracts:** `CT-19` node bearer (half-config-wired), `CT-21` App mint
(UNVERIFIED), per-dispatch scoped token (M11 §3 S4), proxy admission (M12 §6),
provider/identity responsibility matrix with GitHub and GitLab explicit
(V2-ARR-06).

**Settings:** key and token file paths and modes; refresh cadence; scope templates
per dispatch; node-token TTL; leak-signal triggers for revocation.

**Metric owner:** none measured — no credential-age or refresh-failure counter
exists; the gap is named in M7 §6.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Expire a repository credential; authorized renewal restores required push/pull capability without changing desired scope.
2. Revoke a leaked credential and restore a backup; the old credential stays denied while new scoped access can be provisioned.
## 2.13 F13 — Upgrade and migration

![FIGURE 2.13](figures/F13.svg)

F13 applies a declared compatible component or schema change while preserving
recoverable work and state. It runs when a pinned bump or a schema change must
reach the running system. The manager coordinates pinned artifacts, migrations and
runtime activation rather than treating version readback as complete readiness;
the installer is a named actor, and supported rollback or forward recovery depends
on the particular data and component change — an irreversible schema migration
needs a named recovery procedure, because restarting an old binary is not
automatically a safe rollback. The actors are the operator invoking installers and
migrations, the scheduler applying its schema stores, and boardctl migrating row
vocabulary. The result is proven by read-back against the pin at every upgraded
component plus a post-migration state check; installation output alone is not the
proof.

**Preconditions and inputs:** the new pin's artifact is published and digest-checked; the schema migration set is versioned. Inputs: pin manifests; migration scripts; the row-vocabulary mapping.

**Steps:**

1. Validate the proposed version/config/schema change and compatibility matrix for
   the chosen deployment profile and participating components — Bunker
   daemon/client/runtime, Hermes, Crier, DuckBrain and board schema.
2. Plan a staged rollout with named prerequisites, drain/checkpoint requirements
   and a backup/recovery point.
3. Fetch and verify declared artifacts, apply component changes and migrations in
   the documented dependency order, persisting each operation (M5 §5: the
   installer fetches a digest-checked artifact).
4. Read back actual versions and schema/config state — installed version against
   the pin, drift named (M5 §10); the scheduler's migration stores apply schema
   change to the 30-table store (M9 §3).
5. Resume admitted work only on verified compatible targets; publish the effective
   rollout state and evidence.
6. On failed apply/readback, perform supported rollback or explicit forward
   recovery without silently reporting the desired version as effective.

**Exceptional branches:** version drift is detected by read-back and named per file
(M5 §10); the chapters name no automatic rollback. Schema migration is a measured
30-table store (M9 §3); the row-vocabulary migration is a boardctl
`normalize-statuses` command with no measured post-migration state (M4 §4). An
irreversible schema migration requires a named recovery procedure, and partially
upgraded targets stay out of incompatible dispatch while only policy-supported
mixed-version operation continues. Failing after migration but before runtime
readiness must preserve data and report the effective version accurately; an old
installed version against a new desired pin remains visible drift, and admission
follows compatibility policy.

**Contracts:** pin manifests and digest check (M5 §5), version drift readback
(M5 §10), scheduler schema migration stores (M9 §3), board row-vocabulary
normalization (M4 §4).

**Settings:** the pin set per component; migration ordering; dry-run modes;
compatibility policy for mixed versions.

**Metric owner:** none measured — no upgrade-success or drift counter exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Fail after migration but before runtime readiness; the documented recovery path preserves data and reports the effective version accurately.
2. Read an old installed version despite a new desired pin; drift remains visible and admission follows compatibility policy.
## 2.14 F14 — Observability ingestion

![FIGURE 2.14](figures/F14.svg)

F14 turns runtime activity into attributed, queryable metrics, events, logs and
execution evidence with explicit capture guarantees. It runs continuously across
every tick, turn and message. These records correlate project, round, wave, task
and attempt scopes without pretending every telemetry line is a memory entry —
session/token/cost telemetry, durable execution evidence and semantic memory stay
distinct, linked by documented identifiers. The actors are the emitters (node,
scheduler, proxy, foreman), the named sinks (session store, JSONL files, DuckBrain
namespaces), and the webhook fan-out boundary: the Factory's responsibility is
event delivery to configured endpoints; the receiving system may log, alert, page
or act, and those downstream actions are outside the delivery contract (V2-OPS-02).
The result is proven by an attributed line existing for the event at every enabled
emitter — verified by sampling the sink, not by trusting the emitter's exit code.

**Preconditions and inputs:** the emitters are enabled; the sinks (session store, JSONL files, DuckBrain namespaces) exist. Inputs: per-turn records; scheduler counters; proxy request records; foreman decisions and findings.

**Steps:**

1. Define versioned signal schemas, identifiers, meanings, units and ownership for
   required events, metrics, logs, execution evidence and memory links.
2. Emit from the actual runtime/control components and ingest through supported
   pull/push/native/file interfaces to named sinks: the node records every turn,
   model, tokens and cost (`CT-11`, boundary, M2 §6); the scheduler serves tick and
   spawn counters at `/api/v1/metrics` (M9 §8); the proxy appends usage and capture
   JSONL per request.
3. Acknowledge persistence at the documented boundary; apply specified local
   buffering, retention and backpressure where needed.
4. Expose capture/delivery gaps and freshness so missing records cannot be confused
   with no activity.
5. Serve operator/API/metric readout and fan out subscribed events to configured
   webhook endpoints with independent delivery accounting per endpoint, retries
   and outage retention under the defined policy; events carry no secret material.
6. Recover or reconcile pending ingestion/delivery after restart under explicit
   replay and duplicate rules, preserving correlation and retention.

**Exceptional branches:** capture loss at the proxy is silent today — a missing line
cannot be distinguished from a missing request (M12 §11); that is an identified
defect to correct, not a normative delivery guarantee, and what can be replayed
versus what is lost must be defined. The node-to-session-store wire is a boundary
both of whose ends are the Hermes runtime, out of scope (M2 §6). This flow, like
F7, inherits the 11-of-13 metric gap. A successful webhook delivery does not prove
a receiver paged someone or performed repair — a failed subscriber is a delivery
outcome, never a declaration that the underlying incident failed, and optional
subscriber unavailability does not mark a dispatch failed; any required-delivery
policy is configured explicitly.

**Contracts:** `CT-11` turn records (boundary), `CT-15` memory boundary
(UNVERIFIED), scheduler metrics (M9 §8), proxy JSONL (M12 §8), versioned event
catalog and webhook fan-out contract (V2-OPS-02).

**Settings:** metric endpoint toggles; JSONL paths and retention; DuckBrain sync
cadence and namespaces; webhook subscriptions, endpoints and delivery policy.

**Metric owner:** the three emitters above own their own series; every other module
is a named gap (M9 §8).

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Fail one webhook subscriber while another succeeds; both per-destination results are recorded and the underlying incident state is unchanged.
2. Interrupt capture and restart; recovery or explicit loss indicators appear with consistent task/round correlation.
## 2.15 F15 — Backup and restore

![FIGURE 2.15](figures/F15.svg)

F15 preserves a defined recoverable state of the Factory and project, then proves
that state can run again. It runs on the configured backup trigger and on any
restore drill or disaster recovery. Board consistency and one known-row read are
useful checks but do not create a backup or establish cross-component recovery:
the consistency boundary spans the project repository/board, local DuckBrain
data/history, scheduler/Crier records, configuration/manifests and required
evidence. Credentials and revoked authority require a recovery policy separate
from ordinary data restoration — restoring a backup must never reactivate
compromised or revoked credentials (V2-FLW-08). The actors are the configured
backup owner, the restore operator, and the provisioning path that brings a
replacement deployment up through F2. The result is proven by representative board
and memory records verified from the restored copy, execution recovery, accepted
publications, application readiness, and recorded actual loss/recovery evidence —
a copied file is not a restored one.

**Preconditions and inputs:** a backup exists; a scratch environment is available for the restore drill. Inputs: the backup artifact; the known row/record to read back; the board's origin/main copy.

**Steps:**

1. Define configured backup scope, trigger, owner, destination/access, retention,
   recovery-point and acceptable loss objectives without inventing numeric
   defaults.
2. Establish the documented consistency/checkpoint boundary across project
   repository/board, local DuckBrain data/history, scheduler/Crier records,
   configuration/manifests and required evidence.
3. Create and verify the backup inventory, integrity and recovery metadata,
   tracking incomplete or unsynchronized sources — Git repositories alone do not
   back up every service state or unsynchronized host.
4. Select a recovery point and restore into an isolated or replacement deployment
   through the supported profile and provisioning path.
5. Reconcile current identities/revocation, valid replacement credentials,
   ownership and routing before exposing the restored runtime — revoked/expired
   state is preserved so a restore cannot reactivate compromised authority.
6. Verify representative board and memory records, execution recovery, accepted
   publications and application readiness; resume only after checks pass and
   record actual loss/recovery evidence.

**Exceptional branches:** `board_drift` compares the checkout's board against
origin/main row by row, not as a bulk count (M4 §7); `--verify-board` checks board
consistency at boot (M9 §5); the operator restores into a scratch home and reads
back a known row. The model defines these steps and the chapters measure none of
them end to end — this subsection stays short rather than padded with unmeasured
detail. A failed or partial restore remains isolated and unready. Do not reactivate
compromised or revoked credentials from a historical backup: a backup containing
an old revoked secret must recover with revocation preserved. Protect backup
access, report incomplete coverage, and state recoverability limits and manual
steps rather than claiming Git alone backs up every component.

**Contracts:** `board_drift` row-level report (M4 §7), boot `--verify-board`
(M9 §5), scratch-restore readback (M9 §5), F2 provisioning path for replacement,
revocation persistence (V2-FLW-08, F12).

**Settings:** backup cadence, scope, destination/access and retention; the boot
verification flag; scratch-home provisioning; revocation/credential recovery
policy.

**Metric owner:** none measured — no restore-drill counter or durability series
exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Restore onto another eligible host; board, memory, durable execution state, valid access and updated Crier/scheduler routing verify.
2. Use a backup containing an old revoked secret; recovery preserves revocation rather than restoring authority.
## 2.16 F16 — Multi-node fan-out

![FIGURE 2.16](figures/F16.svg)

F16 delivers a directive to a declared set of targets and accounts for each target
independently before computing the requested aggregate outcome. It runs when one
directive must reach several nodes, each with its own receipt. It is distinct from
a foreman dividing one round into worker waves (F1's total-worker budget is a
round-scoped allowance, not fan-out accounting) and from the manager reallocating
Bunkers after host loss (V2-ARCH-01). The actors are the scheduler addressing
per-target operations, Crier carrying custody and replay identities, and each
target's execution adapter launching its permitted Bunker execution. Partial
delivery or completion must remain visible. The result is proven by one settled
receipt per target — a fleet-wide count is the per-target receipts, each
correlated by its own dispatch id, never an aggregate assumption.

**Preconditions and inputs:** every target agent is registered and reachable; per-target credentials exist. Inputs: the directive text; the target registry; per-dispatch scoped tokens.

**Steps:**

1. Resolve the directive, target-set snapshot, per-target scope/binding and
   configured capacity/concurrency/aggregate policy.
2. Create correlated per-target operations and deliver through the documented
   Crier path with custody and replay identities.
3. Validate each target and launch its permitted Bunker execution —
   `bunker exec` runs the harness inside each target container (M11 §3 S1) —
   without conflating directive fan-out with worker-budget accounting.
4. Track per-target progress, deadlines, cancellation and durable results; deliver
   results and acknowledge according to the supported custody contract — the
   dispatcher delivers the reply before ack, and a redelivery replays, never
   re-runs (M11 §3 S3).
5. Compute and persist the aggregate result under the declared policy, retaining
   partial successes and unreachable/interrupted targets.
6. Retry only eligible incomplete operations with ownership/idempotency checks;
   emit per-target and aggregate events/metrics and reconcile target replacement
   where required.

**Exceptional branches:** the dispatcher's loop is serial today — one long job
head-of-line-blocks later agents (M11 §11); that is current implementation
evidence, and the target contract is an explicit concurrency region, not a
serial mandate. The replay guarantee covers only results that reached the ledger
before the crash (M11 §3 S2), and result replay implies nothing about exactly-once
execution — external effects are reconciled when no durable result was recorded.
The deadline-kill defect of F8 applies per target (M11 §2). One slow or
unreachable target follows the defined partial-completion policy rather than
silently hiding all other targets; no concurrency number or fail-fast/all-targets
default is selected here.

**Contracts:** `CT-06` per-dispatch settlement (PROVEN), custody/replay identities
(M11 §3 S3), replay ledger (M11 §3 S2), per-dispatch scoped tokens (M11 §3 S4).

**Settings:** target registry contents; per-target deadlines; ledger retention;
aggregate policy and partial-completion rules.

**Metric owner:** settlement counters per dispatch (M9 §8, `CT-06`); no fan-out
width or completion-ratio counter exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Dispatch to several targets with one unavailable and one slow; per-target receipts, partial state and the aggregate policy hold.
2. Replay delivery after a target result was durably recorded; it is not rerun or counted twice.

## 2.17 Subflows and scenario families

The sixteen flows above are the primary sequences; the coverage audit names twelve
scenario families that must each have an explicit home. Each family below is
cross-referenced to the flow that carries its normative sequence — those flows'
steps, exceptional branches, contracts and verification scenarios ARE the family's
minimum-contract subflow. Where a family will need its own dedicated figure and
contract rows as the design completes, the carrying flow is named and the gap is
stated rather than invented.

| Family | Normative sequence lives in | Subflow status |
| --- | --- | --- |
| 1. Factory bootstrap and deployment-profile selection | F2 steps 1–2 (validate/profile), F12 (identities), F13 (component versions) | carried; per-profile support matrix (Kubernetes, Compose, homelab/VPN, standalone) is an explicit F2/V2-ARCH-02 requirement — cloud adapters lower priority |
| 2. Project and initiative onboarding | F2 (project path: repo, board, namespace, model access), F1 (worker budget seed), F11 (admission enable) | carried; ready state precedes admission (F2 step 6) |
| 3. Controller-agent access and delegation | F12 (access policy, issuer, binding, verification), F2 (provisioned access), F1 (work delivery distinct) | carried; controller administration/repair access is distinct from Crier work delivery and per-Bunker foreman authority (V2-FLW-07) |
| 4. Desired-state reconciliation and automatic host-loss replacement | F8 steps 3–5 (reconcile, recreate, rebind), F2 (replacement provisioning), F10 (teardown of the old target) | carried; fencing/lease semantics per V2-ARCH-01 |
| 5. Board synchronization, claims and work wakeup | F11 step 2 (refresh before workability), F1 step 3 (claims), F8 (divergent copies, stale owners) | carried; one eligibility rule shared by scheduler and foreman |
| 6. Local memory operation and controller/Bunker synchronization | F3 (all steps; the local fallback and three-state durability record) | carried; V2-FLW-05 failure classes and sync policy |
| 7. Pause, cancellation, drain, restart and resume | F10 steps 1–2 (drain, checkpoint), F8 (resume, no budget reset), F13 (checkpoint requirements), F9 (deferred work) | carried; no silent budget reset, no duplicate publication |
| 8. Credential leak, revocation and reauthorization | F12 steps 5–6 (rotation, revoke, prove denial), F15 step 5 (revocation across restore), F9 (degraded posture) | carried; leak triggers configurable (V2-FLW-08) |
| 9. Backup, disaster restore and evidence retention | F15 (all steps), F6 (retention vs cleanup), F8 (recovery points), F10 (preserve-before-destroy) | carried; loss boundary of unsynchronized hosts stated in F3/F15 |
| 10. Configuration and harness/model/policy lifecycle | F13 (pins, schema, rollout), F2 (per-Bunker configuration), F9 (policy postures) | carried; Hermes fixed for MVP, future harness routing explicit, Terminal Jail optional and disabled by default (V2-ARR-04) |
| 11. Idle, discovery, external signals and useful-work limits | F11 step 5 (named deferral, next wakeup), F1 step 6 (stop when useful work is gone), F7 (observation of progress) | carried; no-op pacing is implementation evidence, not an approved universal default |
| 12. Publication, application handoff and document change control | F5 (task-to-verified-publication), F4 (document issue/acceptance), F13 (effective rollout state) | carried; project-level deployment scope stays a per-project acceptance question, not a Factory default |

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
continuation head. Target steps cite the normative contract or refinement that
requires them. Measured legacy deviations remain separately labeled; they never
substitute for target steps in the CF2A-01/P5-A model. Where the handbook has no measured metric for a flow,
the metric-owner line names the gap rather than inventing a counter. The sequence
diagrams are generated from `docs/SYSTEM-MODEL.yaml` by
`scripts/gen_handbook_figures.py`.

## 2.1 F1 — Dispatch and settlement

![FIGURE 2.1 — F1 DISPATCH AND SETTLEMENT](figures/F1.svg)

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

**Preconditions and inputs:** the lane is enabled and configured (`CT-01`); the repository and board copies were refreshed before eligibility; the board-check verifier found work; admission reserved capacity. Inputs: `round-admission.v1` in `cf2a.v1` (`CT-02`); the CT-01 lane_seed extension; the admitted board revision, fixed task_scope and generation. Part I §1.9.6 defines the complete legacy translation; free text never supplies missing budget or authorization.

**Steps:**

1. Entry from F11: the relevant board copies are refreshed and checked, eligible
   work is classified against no-work/stale/unreadable states, and the lane is
   admitted under its configured policy.
2. The scheduler delivers round-admission.v1 and the total-worker allowance
   through Crier (CT-02 target; legacy transport: internal/bus/dispatch.go:202,266);
   the target consumer holds the 60-second `custody.v1` lease (M10 §16), and the
   resident supervisor launches the project foreman inside its Bunker. The measured
   legacy node bus worker uses a 30-second lease (`scripts/node-bus-worker.py:1356,1383`),
   not proof of target custody or crash-safe execution.
3. The foreman reads the current board and project memory, analyzes impact through
   Hilo, selects and claims useful compatible work, and assembles worker briefs
   with acceptance criteria, model/provider access and isolated workspaces. Each
   brief is the immutable `cf.brief-input.v1` JCS byte object owned by the Factory
   foreman/manager; its exact task snapshot, ordered criteria/skills and ordered
   attachment refs are carried by `worker-brief.v1` as `brief_ref` and `brief_digest`
   (M2 §15.1; Part IV §IV.2; CV-01-B). The receiver fetches the referenced skill and
   attachment CAS bytes, verifies each digest (and attachment size), decodes transport
   framing before hashing the brief, refuses missing/changed content before reservation/
   native start, and replays an identical retry without a second start. Local namespace
   queries remain a supported path when the DuckBrain HTTP service is unavailable.
   The MVP harness is fixed — the foreman invokes Hermes directly; a future Task
   Router would sit between Node and Harness and is drawn NOT PART OF MVP.
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
8. The scheduler fsyncs received, verifies controller-readable memory/evidence
   digests (otherwise awaiting_evidence), then runs required postchecks before
   final settlement. Part I §1.9.9 fixes retry deadlines, revocation proof,
   settlement revisions and once-only follow-up; execution success alone never
   increments final-success counters.

**F1 step-to-contract map.** The diagram's numbers are normative references, not
decoration: step 1 refreshes the pinned board (`CT-14`); 2 returns work/no-work/
unavailable; 3 reserves the total round allowance; 4 admits
`round-admission.v1` (`CT-02`); 5–6 retrieve and release signed `custody.v1`
(`CT-03`); 7 launches the resident Bunker foreman; 8 performs only local planning;
9 issues `worker-brief.v1` with launch-custody identity and fences (`CT-05`);
10 returns `worker-result.v1`; 11 executes the pre-commit guard and source/
integrated judgments (`CT-12`/`CT-13`); 12 closes the board from verdict plus
publication proof (`CT-14`); 13 records local/sync memory separately (`CT-15`);
14 returns `worker-result.v1` and `round-report.v1` (`CT-04`/`CT-06R`); and 15
settles the durable report (`CT-06`). Runtime cells `R01`–`R05` in §2.17 cover the
corresponding nominal, replay, crash, concurrency and revocation behavior.

**Exceptional branches:** settlement must distinguish delivery acceptance, running,
interrupted, rejected, partially published and settled results — but the measured
implementation reads only `ok` (`dispatch_leg.go:713-726`), so a node reply carrying
`status:"failed"` and no `ok` — the field `node-bus-worker.py:1180` actually sends —
is scored a success (CF-355, M9 §2). An unacked message redelivers after lease
expiry; reconciliation on replay must not duplicate accepted publication or reset
the round budget, and an empty inbox list is not a lost message (M10 §11). A failed
POST closeout hook never rewrites the immutable execution verdict. It does block
final acceptance: Part I §1.9.9 requires awaiting_evidence/postcheck_pending and
settlement revisions, with success counters and follow-up withheld until checks
pass. M9 §3's outcome-before-hook behavior is a legacy deviation. On DuckBrain
unavailability the round continues on local native memory with pending
synchronization tracked (V2-FLW-05, F3).

**Contracts:** `CT-01` admission configuration (UNVERIFIED), `CT-02` dispatch
envelope (legacy transport measured), `CT-03` lease/redelivery, `CT-05` worker brief
(target), `CT-06`/`CT-06R` durable return, `CT-09` memory records (MISSING),
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
the path for three distinct intents: Factory bootstrap, adding a project, and
replacing a failed runtime. The Factory manager is the deterministic owner of
desired state, observed inventory, reconciliation and binding activation; Scheduler
remains the admission and settlement owner. The manager selects eligible capacity
under the deployment profile, drives the declared installation path, and asks the
node verifier to measure the effective application, configuration, credentials,
project files and memory — creation alone does not make a target ready for
scheduled work. The handoffs run from the desired-deployment request to the manager,
through host selection and Bunker/native installation, to verifier readback; the
manager then registers the verified Crier binding and hands Scheduler the readiness
identity and effective version. The result is proven by a verifier ladder with every
leg VERIFIED, a readback of effective host/isolation/resource settings, and a
binding whose identity/version matches the readiness result.

**Preconditions and inputs:** the host meets the disk floor; the lane declaration exists; the Bunker deployment profile is chosen for this Bunker. Inputs: the lane declaration (project, harness, pin); the node manifest (prompts, skills, env); the seed repo and embedded board; Crier registration material; the per-Bunker DuckBrain namespace credential.

**Steps:**

1. The manager validates the desired project/repo, deployment profile, host pool,
   resource/storage requirements and references to credentials and versions; it
   distinguishes Factory bootstrap, adding a project and replacing a failed runtime
   (M1 §3).
2. The manager selects an eligible host using current health and capacity — the host
   meets the disk floor — reserves and accounts for the allocation, and persists a
   resumable provisioning operation.
3. The provisioner uses the declared Bunker/native installation path to prepare the
   project workspace, repository and embedded Boardctl board, local DuckBrain
   namespace, Hermes and model access (M1 §3 S2 — container, per-agent home,
   layered node).
4. The provisioner installs authorized configuration and scoped credential
   references/material using the documented distribution path; issuance authority
   remains distinct from installation (resolved decision: install/provisioning
   scripts transport credentials).
5. The node verifier reads back effective state and verifies repository access,
   application readiness, memory paths, runtime permissions and required service
   connectivity — CREATED is not VERIFIED (M1 §12). Its result includes the
   verified identity and effective version.
6. The manager prepares Crier and Scheduler candidates, retaining each participant's
   durable prepare receipt and probe/readiness digest. It then owns the sole active
   pointer CAS from generation N to N+1, fsyncs the pointer and operation journal, and
   emits the matching `binding.commit.v1` to both participants. A candidate is not
   routable merely because one participant acknowledged; one-sided acknowledgement is
   recovered by pointer readback and replay of the same generation/fence/digest tuple.
   New dispatch requires a one-use grant only after manager, Crier and Scheduler GET
   readbacks match exactly; partial propagation is `BINDING_NOT_ACTIVE` and remains
   fail-closed.
7. The manager retains the operation, allocation and verifier evidence, including
   the refusal or partial state when any required leg is not complete.

**Exceptional branches:** the certification ladder awards VERIFIED per leg — agent,
gateway, auth, artifact, tree, seed — and an unreachable port is UNVERIFIED
(exit 3), not FAIL (M1 §10, CF-224). Normatively, the authority creates
`registration_id` and the class-`crier` credential reference at enrollment, the Crier
registrar is the only actor that admits CT-22 `register.v1` (outer `cf2a.v1`), allocates
the node identity and returns that reference, and the node proves the verified signed
bus read before it is schedulable. Implementation coverage remains UNVERIFIED: no in-repo
producer was measured; `bunker-crier-connect.sh` stages and probes only (CF-276),
while crier's `HandleRegister`/`HandleRegisterByID` are the measured receiver surface.
A partial failure re-runs from the manifest: the seed reapplies
and names drift per file (M1 §3 S4). Preparation steps persist which legs
succeeded, so retry is idempotent or compensates named partial resources, and
created-but-unverified is never reported as ready. If no eligible capacity
satisfies the request, desired state is retained, the unsatisfied allocation is
exposed as a metric/event with configured webhook delivery, and host eligibility is
never silently widened.

**Contracts:** node manifest and seed (`M1 §3`); CT-21 enrollment credential
installation and CT-22 `register.v1` (outer `cf2a.v1`, M1 §§6, 17.1–17.2);
verifier ladder legs (M1 §10–12). The measured crier receiver surface is
`HandleRegister`/`HandleRegisterByID` (UNVERIFIED); implementation coverage is
not the target contract.

**Settings:** disk floor; the Bunker deployment profile (fresh image-backed or
persistent container) and per-Bunker Factory configuration with setup/readback;
harness pin; registry and namespace credentials.

**Metric owner:** none measured — the chapters name no provisioning counter; the
verifier's per-leg ladder is the record of record (M1 §11).

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Provision a new project under each supported profile; the target cannot receive work before its readiness and routing checks pass.
2. Lose a selected host mid-install; partial allocation is reconciled and resumed or replaced without registering two active owners.
3. Reproduce a one-sided activation by stopping one participant after the manager pointer CAS: inspect the manager journal and pointer, GET both participant generations, replay the exact `binding.commit.v1`, and assert that admission remains false until the three tuple/digest readbacks are identical. A mismatch must report `BINDING_NOT_ACTIVE`; a changed replay must report `BINDING_CONFLICT`; an identical replay must return the original receipt.

**Binding interruption procedure (III.M9.S2/S3; F2/F11):** independently record
`manager_pointer`, Crier GET, Scheduler GET, and each `(binding_generation,owner_fence,
prepared_digest,active_digest)`. The only dispatchable state is all three records
`active` with exact equality. Any missing, stale, conflicting or unreadable record is
`BINDING_NOT_ACTIVE`/unavailable and fail-closed; repair is pointer-led replay, never a
local participant choice or a new generation.


**Builder scenario matrix (F2 / F17.2):**

| Cell | Trigger and required sequence | Observable proof |
|---|---|---|
| B1 cold bootstrap | Operator installs an empty control plane; F2.0 verifies release lock, identity, authority, durable state and initial enrollment before F2 starts. | No manager-dependent prerequisite; initial enrollment is one-use; empty desired/observed state is explicit. |
| B2 new project | Desired deployment → eligible host reservation → workspace/seed → memory/harness → verifier ladder → committed binding → admission. | Every readiness leg is VERIFIED; effective identity/version and Crier binding match; no earlier dispatch. |
| B3 replace failed runtime | Revoke the old generation → drain/checkpoint → preserve workspace/memory → create replacement → reverify → issue a new fence. | Old route cannot accept work; retained evidence survives; only the new generation becomes admissible. |
| B4 late memory | DuckBrain is unavailable through launch and board work; the foreman persists native local records, then syncs after restoration. | Local, commit and sync states remain distinct; pending records converge without duplication or false remote durability. |
| B5 late board | Repository/board read or refresh fails before eligibility, then recovers. | Result is UNAVAILABLE, never NO_WORK; no round is admitted from an empty projection; pinned revision is refreshed. |
| B6 late Crier | Registration/custody response is delayed beyond launch preparation, then arrives. | No route is asserted before binding readback; retrieval uses the correct agent/generation; a stale response cannot start a second foreman. |
| B7 partial readiness | Repository passes while memory or routing fails. | The operation remains created-but-unverified, records the failed leg, and receives no work; retry reuses valid completed legs. |
| B8 retry | The same provisioning operation retries after a crash following workspace creation. | Resumable state and idempotent seed/drift records prevent duplicate allocation, credentials or registration. |
| B9 replay | A signed create/register request or completion is replayed with the same identity and payload. | The original operation/result is returned once; conflicting payload or generation is refused and metered. |

### F2.0 — Cold control-plane bootstrap (P5-A-03)

**Trigger/actors:** an operator requests a new Factory; the offline bootstrap
installer, authority administrator and service supervisors establish the control
plane before the manager exists. F2 steps 1–7 apply only after this subflow.
**Prerequisites/inputs:** a supported prequalified host/profile (Part I §1.6),
operator-owned offline CA/recovery key, independent authority location, signed
release lock, declared endpoint map and mode-0600 one-use enrollment bundle.
No running manager, lane, board or project credential is a prerequisite.

1. The installer verifies release-lock signature against the operator-supplied
   trust anchor, SHA-256 checks every artifact before executing it, and checks
   user-space host prerequisites. It creates isolated durable roots and service
   identities; no download script runs before verification and no root action runs.
2. The authority starts on its independent host with a genesis ledger, consumes
   the enrollment nonce, creates the first administrator binding and issues the
   controller/server identities. The offline signing key leaves the runtime host.
3. The installer writes endpoint discovery and trust references, starts the
   mutation broker and empty manager under supervision, and observes generation
   zero through authenticated GET. Reusing enrollment is refused, not a second admin.
4. The administrator submits a global factory.v1 document with an empty projects
   array and expected_generation zero; its accepted generation is one. This is
   the sole bootstrap exception permitting no projects. The manager's journal
   now owns configuration; the bootstrap installer cannot change later editions.
5. The manager installs durable Crier (no in-memory registry), disabled-admission
   scheduler and controller DuckBrain, then the inference proxy and provider
   adapters. It probes custody across service restart, namespace local commit/
   readback, proxy authorized/denied access and scheduler disabled state. The bus
   exists before any project workspace. Provider enrollment is F12, not implicit.
6. The manager records effective endpoints, certificate identities, release digest
   and restart probes in the bootstrap operation. It destroys the consumed bundle
   after verified enrollment; failure retains only protected diagnostic references.
7. An authorized generation update adds the first project and CT-01 lane seed.
   F2 steps 1–7 provision it; §1.9.4 binding activation is the only admission enable.

For the first private-repository node, the manager is the authoritative enrollment
actor: it obtains the authority/controller-issued Crier identity and class-`crier`
`credential_ref`, then the node performs CT-22 `register.v1` in a `cf2a.v1`
envelope and proves the signed bus read before the §17.2 stage-6 private clone.
This is the target sequence; implementation coverage remains separately measured in
M1 §6 and CF-276.

**State/failure/recovery:** an installer receipt tracks artifact digests and completed
steps; before manager genesis it is a fsynced local journal with one installation
ID. After genesis the manager imports that receipt and owns subsequent steps.
Retry uses the same installation/effect IDs and readback, not duplicate identity
issuance. Bad pins, missing host capability, unreachable authority or failed
custody probe stop bootstrap unready; no fallback login or ephemeral store is
allowed. Removing a failed service never removes its durable root.
**Settings/metrics:** profile, release lock, endpoint map and certificate lifetimes
are Part I §1.6/§1.9; bootstrap timeout is 15 minutes, then degraded/manual retry.
The installer owns pre-genesis step receipts; manager owns bootstrap state events.
**Completion proof:** generation-one receipt, rejected enrollment replay,
authenticated post-restart service readbacks and first-project round-trip evidence
are retained. A daemon version string alone cannot finish bootstrap. [CT-21–CT-29]

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
intended namespace with its correlation intact. A fsynced local Git commit is
the durable acknowledgement; an uncommitted native append is not acknowledged.
Remote synchronization remains a separate state (Part V supported memory profile).

**Preconditions and inputs:** the DuckBrain namespace exists and is configured per project; the writer holds the namespace credential (M1 §3). Inputs: CT-09 worker, wave and round records with stable IDs and correlations; CT-15 decisions/findings; keyed/keyword recall. Legacy R1/R2/weekly R3 is not the required record taxonomy.

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
5. The designated writer fsyncs record data, Git objects and ref transaction before
   returning record_id/local_commit/payload_digest; it reads the record back. No
   commit means PERSISTENCE_UNAVAILABLE. Pending records acquire retention holds.
6. The memory adapter exchanges missing commits with the configured remote every
   300 seconds and on reconnect, through the fenced broker; namespace/writer and
   record digest are checked. Same ID/digest replays; changed digest retains both
   and returns MEMORY_CONFLICT. Authorized resolution creates a new record ID,
   never overwrites the first. Retry uses Part I §1.9.4 backoff. Controller readback
   sets sync_commit/synced_at/freshness; only then is the pending hold released.

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
per-Bunker instance cut off from the controller has pending-sync records. Losing
that host before remote custody is LOCAL_STORE_LOST with a named loss interval,
not a successful write at the controller. Scheduler settlement waits in
awaiting_evidence under Part I §1.9.9; a successful local round is not yet accepted.

**Contracts:** `CT-09` structured run-record sync (MISSING), `CT-15` foreman memory
boundary (UNVERIFIED), namespace credential (M1 §3), sync cadence for cron-side
writers (M9 §5).

**Settings:** namespace selection (explicit per project — omitted namespace is
NAMESPACE_REQUIRED; no sticky fallback); HTTP/MCP auth (`x-api-key`); local data
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
publication are distinct stages. Part I §1.9.7 defines merge/fast-forward ancestry
and squash/rebase tree/mapping proof for the configured destination ref. The
accepted revision AND evidence-bound board closeout are required; either alone
is insufficient. Non-main destinations use the same rules.

**Preconditions and inputs:** a worker branch commit exists; the pre-commit hook is installed in the seeded repo; the row's acceptance criteria are gradable. Inputs: the staged diff (`CT-12`); the gate verdict (`CT-13`); the branch and commit ids; the evidence run id.

**Steps:**

1. Associate the candidate changes with the task/attempt, acceptance criteria, base
   revision and isolated workspace.
2. Run the required commit guard on the relevant content, create the permitted
   candidate commit and return any refusal for correction (`CT-12`;
   `scripts/install-gitreins.sh:124`).
3. Run independent acceptance and record verdict/evidence bound to the candidate
   content and criteria (`CT-13`).
4. The broker integrates under the declared merge/fast-forward/squash/rebase mode
   at an exact remote base, runs every required integrated-tree gate and publishes
   by remote ref CAS. PR transport does not relax the exact-tree proof.
5. The foreman reads the remote ref and validates the mode-specific receipt
   (Part I §1.9.7). Any base/tree/criteria/dependency/gate-config change invalidates
   all integrated-tree checks; CAS conflict repeats integration and these checks.
6. Return publication evidence to the foreman; update the task board and
   worker/wave memory through recoverable closeout steps (`CT-14`, completion
   requires `--evidence-run-id` on `boardctl update`, M4 §6).

**Stage-to-acceptance map (F5).**

| Stage | Required artifact and transition | Refusal / observable proof |
|---|---|---|
| 1 pre-commit guard | The exact staged bytes, criteria and gate configuration produce a guard receipt; only then may the candidate commit exist. | Refusal leaves HEAD unmoved. Re-run with an unstaged fix and with an empty staged set; neither may borrow a green verdict. |
| 2 source judge | Independent acceptance reads the exact candidate commit, criteria and test evidence and returns a source verdict (`CT-13`). | A missing/invalid verdict cannot become accepted; the verdict names the tested commit and evidence run. |
| 3 integrate and publish | Integrate at an exact base, rerun every required check on the merged tree, CAS the destination ref, and read back the mode-specific remote descendant/tree mapping. | Base/tree/config drift or CAS conflict invalidates prior checks; integration repeats. A local merge or push attempt is not publication proof. |
| 4 close and retain | The foreman validates the tested parent and evidence references, then closes the row and persists worker/wave/round records. | No closure artifact contains its own future hash. Interruption after publication replays to one publication and evidence-backed closeout. |

**Landing scenario matrix.** In addition to the two base-change and post-publication
crash cells below, F17.5 requires guard refusal, invalid verdict, pre-integration
crash, integrated-gate denial, CAS conflict, remote denial, post-publication board
failure, memory failure, replay and concurrent claims. Each records the last
durable artifact, recovery actor and proof that no second commit/publication or
unverified closure was created.

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
4. The retention owner CAS-tombstones only hold-free resources, then the local
   agent locks and verifies inode/path identity, quarantines and deletes them
   under Part I §1.9.8. Hold acquisition and deletion are mutually exclusive;
   unknown or unregistered resources remain retained. M5 owns installed packages,
   not the generic cache reaper.
5. Measure results, free capacity and repository freshness — `repo_freshness`
   measures how far a workdir lags origin (M3 §5), the verifier's `node_freshness`
   measures branch, HEAD and lag on the node (M1 §11) — reporting each operation
   and retained/refused reason.
6. Update actual capacity and reconciliation observations; retry or escalate
   unresolved pressure through events/metrics under configured policy.

**Exceptional branches:** M8 §2's age-only reaper can delete cited evidence; this
legacy deviation is prohibited by the target retention protocol (§1.9.8). A gitleaks claim without its
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

**Exceptional branches:** M9 §8 measures scheduler HTTP series and M10 §8 Crier
series; M12 §8 usage JSONL is a log, not a served counter. No numeric fleet-wide
coverage total is asserted without a source-by-source census. A stats error that degrades queue counters to zero cannot
prove emptiness (M10 §6). Missing or stale telemetry is unknown observation, not
evidence of health, and monitoring/repair failure must itself be observable.
Subscriber outage has its own delivery state and retry policy; webhook failure is
never conflated with the health event being reported.

**Contracts:** scheduler metrics/status endpoints (M9 §5, §8), crier `/metrics`
(M10 §8), proxy usage JSONL (M12 §8); typed webhook delivery boundary (V2-OPS-02,
F14).

**Settings:** the metrics default-ON flags; scrape targets and cadence; webhook
subscriptions and endpoints.

**Metric owner:** scheduler and Crier own their served series; proxy owns its
usage log. Foreman owns live round facts, manager owns progress ingestion/freshness
and CT-30 readout under Part I §1.9.9. Required but unimplemented series remain
unverified, not ownerless or zero.

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

**Preconditions and inputs:** the affected scope is identified; old writers may still be running. F8 establishes fencing; quiescence is not assumed. Inputs: the replay ledger; crier's unacked inbox messages; the board lock state; the session store's stale sessions.

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
the legacy dispatcher replays the recorded result on redelivery instead of re-running
(`dispatcher.py:470-475`, M11 §3 S2), but a result lost with the process is re-run
from scratch, and a missing ledger row does not prove no external side effect
occurred. Legacy Crier redelivers an unacked message after lease expiry; target
`custody.v1` instead holds it for reconciliation (M10 §16). An empty list is
not a lost message (M10 §11). The scheduler's `--reap-sessions` closes stale
sessions, dry-run without `--apply` (M9 §5); `board_read` resolves the board from
origin/main when the working copy drifts (M4 §3); a `board_lock` ERROR verdict
means lock state is unknown — stop and diagnose, never write (M4 §3). The
dispatcher's deadline kill terminates run.sh's process group, not the harness's own
group, so the kill-the-group guarantee is withdrawn (M11 §2); unknown-start
reconciliation is a required behavior, not an implemented one (M11 §2). Restarting
the controller must not replenish worker allowance or dispatch to a stale target,
and automatic repair stays within configured authority and capacity.

The target recovery query and independently checkable interruption vector are M9
§17.1; it reconciles all simultaneous local/custody/native/sink states without
inventing a distributed transaction. Runtime conformance is unverified.

**Target fencing:** Part I §§1.9.3–1.9.3a and M7 §17–17.1 govern the
independent authority, effect gate and each protected resource, including the
scheduler; unresolved effects block replacement. This is UNIMPLEMENTED and runtime
UNVERIFIED, not a claim about the current scripts below.

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
### F8.1 — Execution control, drain and resume (P5-A-16)

**Trigger/actors:** a project editor/administrator requests pause, cancel, drain,
resume or restart; scheduler may cancel only its own deadline-expired round.
Manager authenticates, Crier carries control, the resident adapter controls the
entire round cgroup, and foreman/scheduler reconcile claims and budget. This is
not cancellation of a manager provisioning operation.
**Prerequisites/inputs:** an admitted round and its durable execution ledger exist;
reachability is not required. The POST control route (Part I §1.9.1) accepts
`{schema_version: factory.v1, idempotency_key, action: pause|cancel|drain|resume|restart,
expected_control_version: integer, owner_fence, checkpoint_digest: digest or null}`.
Target round is in the route; child attempts are derived from its ledger, never
from a process-name scan. Reusing a key with changed action is refused.

1. The manager CAS-appends `control_id`, action, round identity, incremented control
   version and `requested` state; it closes new-launch grants. It emits an
   authenticated `execution-control.v1` directive with that identity through Crier.
   The response is `{control_id, round_id, control_version,
   state: requested|draining|paused|cancelled|resuming|complete|fenced_unknown,
   checkpoint_digest: digest or null, error: Error or null}`.
2. For drain, existing attempts may finish but no new attempt starts. Pause requests
   cooperative checkpoints; cancel forbids further publication and revokes dispatch
   capabilities immediately. The resident adapter acknowledges custody, then records
   every descendant PID/cgroup and final/checkpoint state. A custody ack is not
   quiescence. Grace is 60 seconds; after grace it sends TERM to the owned cgroup,
   waits 10 seconds, then KILLs that cgroup and verifies it is empty. Permission or
   containment failure is `QUIESCENCE_UNPROVEN`, never a success response.
3. Before destructive operations, the foreman writes and fsyncs
   `execution-checkpoint.v1`: `{round_id, run_id, corr_id, control_version,
   owner_fence, config_generation, board_revision, budget: {allowance, consumed,
   reserved}, attempts: [{attempt_id, task_id, state, claim_id, claim_generation,
   workspace_commit, result_digest}], memory_refs, evidence_refs, published_refs}`.
   Fields without artifacts use explicit null; IDs/digests follow Part I §1.9.1.
   The checkpoint is content-addressed, retained and transferred to controller
   custody. Dirty work requires a retained workspace snapshot and its digest;
   absence of either commit or snapshot makes that attempt unresumable.
4. Reachable pause records `paused` only after checkpoint/readback and empty cgroup.
   A paused started attempt becomes `interrupted`; a cancelled one becomes
   `cancelled`. Claims are released by fenced board CAS with checkpoint evidence;
   tasks become blocked, not complete. Unstarted reservations release; started
   attempts remain consumed under the pinned budget policy.
5. Unreachable owners are fenced through Part I §1.9.3; state is `fenced_unknown`,
   not falsely quiescent. Resource-side mutation denial permits replacement only
   after unknown external effects are reconciled. Destruction of the old host's
   retained data waits for physical access/quiescence proof; network timeout is
   never deletion eligibility.
6. Resume verifies the exact checkpoint digest, live generation/fence and claims,
   reuses round/run/correlation IDs and advances control version. Surviving active
   attempts are discovered, not duplicated; stopped attempts receive new attempt
   IDs with `resumes_attempt_id` and consume budget under the same policy. Resume
   refuses when evidence is missing, an old owner can still publish, or remaining
   budget is insufficient. Restart means pause/checkpoint followed by this resume,
   never reset. Cancelled rounds are terminal; new work requires a new admission.

**Failure/recovery:** duplicate controls replay their durable receipt; a stale
control version returns `CONTROL_CONFLICT`. Crash recovery discovers cgroup,
checkpoint and broker effects before retry. Missing checkpoint yields a named
unrecoverable attempt and retained partial artifacts. Control delivery retries
use Part I §1.9.4 backoff; exhaustion leaves fenced_unknown/degraded, not complete.
**Settings/metric owner:** grace/TERM intervals are 60/10 seconds, configurable
1..3600/1..300; administrators own overrides. Manager owns control transitions,
resident adapter owns quiescence receipts, scheduler owns terminal settlement.
**Completion proof:** exact cgroup-empty receipt or explicit fenced_unknown,
checkpoint readback, denied old capability, reconciled claims and unchanged total
allowance. Required scenarios race cancel with worker start, lose the host before
ack, and replay resume after restart; no scenario creates duplicate publication.
[CT-03/06/10/14/29; F8/F10/F13]

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
provider outage in the legacy policy (M10 §10); target GUARD always refuses
launch on outage under Part I §1.3.5; the proxy fails closed at
startup — no token file or no upstream key exits 2 (M12 §11); the commit gate
absent leaves the pre-commit hook exiting 0 — a silent bypass that must be
disclosed (M3 §10). The only one of the three that is fail-closed and measured is
the proxy's startup check. Existing fail-open or passing-absent-hook behavior is
implementation deviation: target directive guard is fail-closed and it does not
authorize accepted publication without required checks. For DuckBrain, service
outage, local storage loss, stale remote view and semantic-provider loss are
different states with different recoveries. Recovery is the dependency's own
recovery plus the next cadence tick; nothing re-queues the degraded interval's
work automatically beyond the policy's pending-effect rules.

**Contracts:** `no-exec-fallback` (M9 §5), guard posture policy (M10 §10), proxy
startup check (M12 §11), hook installation completeness (M3 §10), local memory
fallback (F3, V2-FLW-05).

**Settings:** `no-exec-fallback`; target guard fail-closed policy and classifier pin; the load
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
rebuild restores a desired runtime and its required state. The Factory manager owns
intent, durable operation state, fencing, retention and final binding activation;
Scheduler only receives the resulting readiness state for admission. Stopping,
replacing and permanently deleting a project are different intents, and planned
removal, repair and host-loss replacement take different paths through the same
flow. It runs on operator request (destroy is operator-gated) or from the manager
after host loss. Evidence, memory and durable records remain subject to retention
even when runtime resources are destroyed — "no residue" never authorizes erasing
audit history. The handoffs run from intent resolution and draining through
quiescence and preservation, revocation and binding removal, to destruction of
eligible resources and, for rebuild, re-application of desired state through F2;
the verifier returns identity/version/readiness to the manager before the manager
activates a new binding. The result is proven by the registry no longer listing the
agent, the home gone, and a rebuild's seed diff naming every restored file —
readback, not intention.

**Preconditions and inputs:** destroy is operator-gated and names the agent; active work is allowed at entry and must be drained or fenced through F8.1 before destructive actions. Inputs: the agent name and `--yes`; the seed manifest for rebuild.

**Steps:**

1. Resolve the requested stop/remove/rebuild intent, target, configured authority
   and retention policy; mark the deployment draining and prevent new assignments
   (`--destroy` requires `--yes` and a named agent, M1 §5).
2. The manager quiesces or checkpoints active work and proves process/claim state;
   it preserves required workspace, memory, evidence and durable control records.
3. The manager revokes or retires old identity/access as appropriate and removes
   stale routing/scheduler bindings without erasing audit history.
4. The provisioner destroys only eligible resources using the supported
   Bunker/platform path — it removes the container and per-agent home (M1 §5) —
   then returns actual remaining resources and ownership to the manager.
5. For rebuild/replacement, the manager reapplies desired state, restores preserved
   data and installs valid replacement access through F2; the seed reapplies from
   the manifest and names drift per file (M1 §3 S4).
6. The node verifier measures application readiness and returns identity/version/
   readiness evidence to the manager. The manager activates the new binding and
   only then enables work; it emits lifecycle and failure events with retained
   operation history.

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
4. Evaluate applicable binding readiness before other admission gates: read the
   manager active pointer plus Crier and Scheduler participant records and require exact
   equality of generation, fence, prepared_digest and active_digest. A missing or
   mismatching record is `BINDING_NOT_ACTIVE` and fails closed; no reservation or grant
   is created. Then evaluate capacity, fairness, load and pacing rules and durably
   account for reservations: admission mode resolves project override, then namespace
   default, then cooldown (`admission_mode.go:98,112`); usage pools reserve or emit a
   capacity denial; the board-stasis gate excludes an unchanged cooldown builder lane
   (`packer_select.go:474,614`); NOOP-PACING spaces a no-artifact lane, doubling to 8
   times the floor (`noop_pacing.go:74`).
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

| Admission cell | Trigger | Required result |
|---|---|---|
| A1 nominal | Fresh pinned revision contains eligible work and all admission gates pass. | One `round-admission.v1` record binds lane, board revision, total allowance and generation. |
| A2 unreadable | Repository/board refresh or decode fails. | UNAVAILABLE plus a retry wakeup; never NO_WORK, never an empty-board round. |
| A3 duplicate | The same admission request is replayed before or after the response. | One reservation and one round; identical replay returns the original receipt. |
| A4 stale | Board revision, lane generation, usage-pool revision or readiness fence is older than the admission decision. | Re-read and re-evaluate; stale work cannot consume the new allowance. |
| A5 reserve crash | Scheduler dies after durable reservation but before Crier custody. | Reconciliation releases or resumes exactly that reservation; restart cannot double the round allowance. |
| A6 concurrent rounds | Two ticks or lanes select the same work/pool capacity. | Atomic board claims and pool CAS admit only compatible ownership; losers name their contention reason. |
| A7 policy denial | Cooldown, load, fairness, capacity, revocation or disabled-lane policy refuses admission. | Durable reason, released reservations and next eligible wakeup; no dispatch message. |
| A9 binding mismatch | Manager pointer, Crier and Scheduler differ in generation, fence or digest, or a readback is unavailable. | `BINDING_NOT_ACTIVE`/unavailable, no reservation, grant or dispatch; repair replays the manager's committed tuple only. |
| A8 post-settlement failure | Execution succeeded but a required refresh, board-check or evidence postcheck fails. | Settlement revision becomes awaiting/postcheck-pending; final-success and follow-up remain withheld. |

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

**Preconditions and inputs:** the selected issuer is enrolled and its protected reference and exact consumer scope are configured. GitHub needs App installation/key references; GitLab needs the project-token issuer/project ID (Part I §1.9.7). Dispatch capability and node inference authority are separate inputs; a GitHub key is not a GitLab prerequisite.

**Steps:**

1. Resolve user-owned provider/app installation, principal, project/repository
   scope, requested operations and credential reference under the declared access
   policy.
2. The provider adapter issues scoped expiring access: GitHub uses its App
   installation flow (M7 §5); GitLab uses project access tokens with the exact
   issue/discover/revoke and lost-response rules in Part I §1.9.7. The issuer
   remains controller-side, and issuer failure cannot widen scopes.
3. Distribute through the supported provisioning/install path and bind the
   credential to the exact target identity/service/resource: the token is written
   to a 0600 file, the value never printed (M7 §7); `refresh --node` installs
   `auth/github.token` on the node in the legacy path (M7 §5). Target forge write
   credentials remain broker-side; nodes receive attenuated, online-revocable
   capabilities under Part I §1.9.7, never the native forge write token.
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

**Preconditions and inputs:** the new `cf.release-lock.v1` is published by the
Factory release manager and digest-checked; the schema migration set is versioned. Inputs:
the complete lock, migration scripts, component receipts and the operation id.
The complete manifest shape and the manager's authority boundary are M1 §18.1; this
flow is the one F13 procedure, not a competing manifest contract.

**Steps:**

1. Qualify/resolve the lock.
2. Verify signature, digest, size, platform, dependency closure and compatibility.
3. Fence the manager, refuse concurrent operations, stop new admission and drain or
   checkpoint in-flight work.
4. Stage all artifacts/migrations in a new immutable generation.
5. Create and verify the F15 pre-migration backup, retain it in an isolated generation,
   and record its receipt.
6. Apply transactional/copy-on-write migration and atomically switch the active pointer.
7. Postcheck binary/config/schema versions, token scope/generation, Crier/scheduler/proxy
   receipts and the in-flight checkpoint.
8. Finalize receipts/outbox and reopen admission.
   This is the same ordered sequence as M1 §18.2; version output alone is not success.

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

1. The resident foreman journals progress.v1 at every budget/attempt/wave change
   and every 10-second heartbeat. Part I §1.9.9 fixes fields, budget equations,
   persistent sequence and restart identity; Part V §V.0.3 fixes manager samples.
2. Emit from the actual runtime/control components and ingest through supported
   pull/push/native/file interfaces to named sinks: the node records every turn,
   model, tokens and cost (`CT-11`, boundary, M2 §6); the scheduler serves tick and
   spawn counters at `/api/v1/metrics` (M9 §8); the proxy appends usage and capture
   JSONL per request.
3. Acknowledge persistence at the documented boundary; apply specified local
   buffering, retention and backpressure where needed.
4. Expose capture/delivery gaps and freshness so missing records cannot be confused
   with no activity.
5. The manager serves authenticated GET /v1/rounds/{id}/progress with last sample,
   receive age and fresh/stale/unavailable quality; disconnected sources are not
   zero budgets. PUT ingestion deduplicates seq/digest and checks the owner fence.
   CT-30 events fan out under Part V's independent destination accounting; events
   carry no secret material.
6. Recover or reconcile pending ingestion/delivery after restart under explicit
   replay and duplicate rules, preserving correlation and retention.

**Exceptional branches:** capture loss at the proxy is silent today — a missing line
cannot be distinguished from a missing request (M12 §11); that is an identified
defect to correct, not a normative delivery guarantee, and what can be replayed
versus what is lost must be defined. The node-to-session-store wire is a boundary
both of whose ends are the Hermes runtime, out of scope (M2 §6). This flow, like
F7, distinguishes served series from JSONL logs; it asserts no unmeasured total. A successful webhook delivery does not prove
a receiver paged someone or performed repair — a failed subscriber is a delivery
outcome, never a declaration that the underlying incident failed, and optional
subscriber unavailability does not mark a dispatch failed; any required-delivery
policy is configured explicitly.

**Contracts:** `CT-11` turn records (boundary), `CT-15` memory boundary
(UNVERIFIED), scheduler metrics (M9 §8), proxy JSONL (M12 §8), versioned event
catalog and webhook fan-out contract (V2-OPS-02).

**Settings:** metric endpoint toggles; JSONL paths and retention; DuckBrain sync
cadence and namespaces; webhook subscriptions, endpoints and delivery policy.

**Metric owner:** foreman owns progress facts, manager owns ingest/freshness,
scheduler owns settlement, Crier owns custody, proxy owns usage logs. Missing
implementation remains a coverage gap, not missing ownership (Part I §1.9.9).

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Fail one webhook subscriber while another succeeds; both per-destination results are recorded and the underlying incident state is unchanged.
2. Interrupt capture and restart; recovery or explicit loss indicators appear with consistent task/round correlation.
## 2.15 F15 — Backup and restore

![FIGURE 2.15](figures/F15.svg)

F15 preserves a defined recoverable state of the Factory and project, then proves
that state can run again. The Factory manager owns the backup operation, manifest,
checkpoint boundary, isolated restore and activation decision; Boardctl, Scheduler
and DuckBrain provide the source-specific readbacks. It runs on the configured
backup trigger and on any restore drill or disaster recovery. Board consistency and
one known-row read are useful checks but do not create a backup or establish
cross-component recovery: the consistency boundary spans the project
repository/board, local DuckBrain data/history, scheduler/Crier records,
configuration/manifests and required evidence. Credentials and revoked authority
require a recovery policy separate from ordinary data restoration — restoring a
backup must never reactivate compromised or revoked credentials (V2-FLW-08). The
manager restores through F2 only after isolated checks pass. The result is proven
by representative board and memory records verified from the restored copy,
execution recovery, accepted publications, application readiness, and recorded
actual loss/recovery evidence — a copied file is not a restored one.

**Preconditions and inputs:** creation requires a declared destination and reachable scoped writers, not an existing backup. Restore requires a verified manifest/artifact and isolated scratch deployment. Inputs are release/config digests, authority identity, source inventory and explicit recovery objectives (F15.1).

**Steps:**

1. Validate the explicit F15.1 backup policy and acquire its ordered barrier.
2. Checkpoint each writer under that barrier and record its exact sequence/ref
   and hash in the consistency marker; missing participants abort complete backup.
3. Capture immutable snapshots and evidence inventory, verify hashes off-host,
   sign and publish the cf.backup.v1 manifest, then release the barrier (F15.1).
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
consistency at boot (M9 §5); these legacy probes alone do not measure F15.1's
coordinated capture. Its conformance scenarios remain required and unverified. A failed or partial restore remains isolated and unready. Do not reactivate
compromised or revoked credentials from a historical backup: a backup containing
an old revoked secret must recover with revocation preserved. Protect backup
access, report incomplete coverage, and state recoverability limits and manual
steps rather than claiming Git alone backs up every component.

**Contracts:** `cf.backup.v1` manifest and `consistency_marker` (M8 §35.1),
`board_drift` row-level report (M4 §7), boot `--verify-board` (M9 §5),
scratch-restore readback (M9 §5), F2 provisioning path for replacement,
revocation persistence (V2-FLW-08, F12). `RESTORE_RESULT` is the common restore
result; no legacy backup schema or result name is a competing target.

**Settings:** backup cadence, scope, destination/access and retention; the boot
verification flag; scratch-home provisioning; revocation/credential recovery
policy and the per-store RPO/RTO.

**Metric owner:** none measured — no restore-drill counter or durability series
exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Restore onto another eligible host; board, memory, durable execution state, valid access and updated Crier/scheduler routing verify.
2. Use a backup containing an old revoked secret; recovery preserves revocation rather than restoring authority.

**Deterministic F15 state vector (specification only; runtime `TARGET-UNIMPLEMENTED` / `UNVERIFIED`).**
Use one `backup_id=backup-1`, `barrier_seq=9`, and the published vector `CV-06-B`.
The manager must acquire the barrier and checkpoint writers before capture: scheduler
admission is closed, the round is drained/checkpointed, broker writes are frozen,
Crier custody is checkpointed, memory writers are flushed, and the manager journal is
checkpointed. Every source receipt is included in `consistency_marker` and every
artifact is in the `cf.backup.v1` manifest. Execute each row independently from the
stated pre-state; do not infer a result from daemon liveness.

| Case | Pre-state at barrier | Required isolated-restore result |
|---|---|---|
| Pending Crier message | `delivery_id=msg-pending`, state `queued`, no ack receipt | Restore retains exactly one pending custody row; it is not auto-launched or duplicated. `RESTORE_RESULT` reports `queued` and the restored Crier source revision. |
| Acknowledged Crier message | `delivery_id=msg-acked`, state `acked`, result digest `r-1` | Restore retains the ack and result receipt; replaying delivery does not create a second message or execution. |
| Pending memory entry | `record_id=mem-pending`, local commit present, canonical sync receipt absent | Restore reports `pending-sync` or loss at the recorded boundary; it does not invent a canonical memory commit from partial history. |
| Stale owner/credential | old `owner_fence=F7` and credential `cred-old` are in the backup; current authority is `F8`, and `cred-old` is revoked | Restore imports the live authority checkpoint/revocation set, keeps `cred-old` denied, and rejects an old-owner write as `STALE_OWNER` / `AUTHORITY_UNAVAILABLE`. It issues no replacement credential before denial is proven. |
| Known-row readback | restored board row `row-known`, plus the pending/acked Crier and memory identities above | `RESTORE_RESULT` is not ready until the exact row and source revisions/digests read back from the isolated stores; a missing row is `UNVERIFIED`, not success. |

For a capture failure, a missing participant, corrupt digest, expired barrier or
failed off-host readback, the manager records `CAPTURE_FAILED`/`ABORTED` or
`INCOMPLETE` with the excluded store and loss interval, retains the holds, and never
publishes a complete manifest. Validation (`VALIDATED`) is distinct from creation
(`CREATED`); publication and release occur only after digest/readback checks. The
known-row procedure is a target acceptance vector, not a claim that live restore has
run. [M8 §35.1; M9 §17; M10 §16; Part I §1.9.3a]

### F15.1 — Coordinated capture and disaster authority (P5-A-06)

**Trigger/actors:** scheduled backup, pre-migration capture or operator restore;
manager coordinates scheduler, resident adapters, broker, Crier, board, DuckBrain
and snapshot writers. Independent authority supplies current fences/revocations.
**Prerequisites/inputs:** a policy names project scope, destination, encryption-key
reference, retention_s, rpo_s and rto_s (positive integers), release digest and
restore-test record IDs. Create does not require an older backup. Restore requires
a signed complete manifest, decrypt authority and an isolated destination.
**DECISION SLOT A-RECOVERY:** the owner chooses recovery/loss objectives, retention
and off-host destination, or explicitly approves a qualification-only drill.
Default is unset and `BACKUP_POLICY_REQUIRED`; production readiness refuses an
unconfigured recovery policy rather than inventing a business loss tolerance.

1. The manager journals a backup_id and acquires barriers in this fixed order:
   scheduler admission closed; resident round drain/checkpoint (F8.1); broker
   canonical writes frozen and in-flight effects resolved; Crier delivery/ack
   state checkpoint; namespace writers flushed/paused; manager journal checkpoint.
   Barriers are keyed by backup_id and idempotent. Authenticated prepare returns
   `{backup_id, participant, state: held, checkpoint_ref, sequence, digest}`;
   all participants retain the hold until explicit release or recovery decision.
2. Barrier acquisition times out after 300 seconds. Any missing participant yields
   an incomplete manifest; the manager releases acquired holds in reverse order
   and records the excluded source/loss interval. It never labels partial coverage
   complete. A disconnected Bunker's unsynced memory is explicitly excluded, and
   its absence prevents a complete scoped backup. A manager crash causes each
   participant to query durable backup state before release; no timeout silently
   reopens a writer into a supposedly frozen snapshot.
3. For each Git store the snapshot writer fsyncs objects/refs, captures all retained
   refs and reachable objects plus pending local commits, and verifies object
   connectivity. Board capture includes row/event/transaction-marker hashes at
   that same ref. Scheduler/session/Crier SQLite stores use their online backup
   API under the hold, not a raw copy missing WAL; other supported Crier stores
   must provide a consistent native snapshot/restore with sequence. An adapter
   without that capability is BACKUP_UNSUPPORTED. Manager copies its verified
   checkpoint plus closed journal suffix. Evidence objects and desired editions
   are captured by content digest; credentials are references only.
4. The consistency_marker is an object, not an arbitrary note:
   `{backup_id, barrier_generation, config_generation, manager_seq,
   authority_id, authority_seq, sources: [{participant, sequence,
   checkpoint_ref, digest}], acquired_at, released_at: timestamp or null}`.
   Authority_seq is a lower-bound observation, never restored authority. All
   snapshots must match these exact source receipts. The manager writes a
   cf.backup.v1 manifest with backup_id, created_at, scope, release_digest,
   consistency_marker, status complete/incomplete, inventory entries
   `{source, object_ref, sha256, bytes, format_version, encrypted}`, excluded
   sources/loss intervals, revocation_snapshot_ref, and restore probes.
5. The writer encrypts artifacts using the configured destination key, uploads and
   reads them back off-host, verifies bytes/digests, and signs the canonical
   manifest digest with the backup identity. Only then does it mark complete and
   release barriers in reverse order. Retention deletion requires a later verified
   backup and the retention protocol, not merely a successful upload command.
6. Restore verifies signature/inventory, installs the pinned compatible release
   into an isolated network with admission and all outgoing mutation disabled,
   restores snapshots, replays journal suffixes, rebuilds indexes, and verifies
   named board/memory records, budget conservation, custody/result identities and
   accepted publication refs. Restoration never pushes an old canonical ref over
   newer remote work; current remote refs are reconciled before activation.
7. Recovery contacts the independently retained authority, advances controller and
   project epochs and imports current revocations; old credentials remain disabled.
   If that authority is lost, the operator revokes ALL previous forge installations/
   project tokens, broker capabilities, Crier/memory/Bunker identities and trust
   roots at their enforcing boundaries, proves denial, and enrolls a new random
   authority_id/CA. Numeric epochs may restart only under that new authority ID.
   Missing provider access or inability to prove denial leaves restore isolated;
   an old backup revocation snapshot never substitutes for current authority.
8. Fresh credentials and §1.9.4 bindings activate only after the restore probes,
   current remote reconciliation and revocation proof pass. A restore receipt
   records recovered sequence per source, loss interval and measured elapsed time
   against configured RPO/RTO. Failure preserves the isolated data for repair.

**Recovery/settings/metrics:** on crash the same backup_id discovers completed
snapshots and holds before resuming; mismatched digests fail closed. Barrier timeout
is 300 s; retry uses Part I §1.9.4. Backup encryption/destination/retention and
business recovery objectives require A-RECOVERY. Manager owns backup/restore
states, bytes verified and objective violations; participants own source receipts.
**Completion proof:** an independently restored copy passes the named readbacks,
old-credential denial, new-owner-only publication and admission probes. Tests
interrupt every barrier stage, omit a Bunker, corrupt one object, and restore a
backup older than a revocation; none may produce ready from incomplete evidence.
[CT-24/25/28/29; Part VI backup manifest; F2/F8/F12]

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

**Preconditions and inputs:** target identities and bindings are snapshotted and authorized; reachability is an outcome, not a prerequisite. Inputs: directive digest, target snapshot, broker capabilities and the required F16.1 policy.

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
silently hiding all other targets. F16.1 requires explicit concurrency/deadline
and aggregate policy; omitted policy is refused rather than guessed.

**Contracts:** `CT-06` per-dispatch settlement (PROVEN), custody/replay identities
(M11 §3 S3), replay ledger (M11 §3 S2), per-dispatch scoped tokens (M11 §3 S4).

**Settings:** target registry contents; per-target deadlines; ledger retention;
aggregate policy and partial-completion rules.

**Metric owner:** settlement counters per dispatch (M9 §8, `CT-06`); no fan-out
width or completion-ratio counter exists.

**Verification scenarios** — to specify and run, not results claimed by this handbook:

1. Dispatch to several targets with one unavailable and one slow; per-target receipts, partial state and the aggregate policy hold.
2. Replay delivery after a target result was durably recorded; it is not rerun or counted twice.

### F16.1 — Fan-out policy and terminal outcomes (P5-A-25)

**Trigger/actors:** an authorized scheduler request fans one directive to registered
project targets. Scheduler owns the aggregate, Crier owns each custody receipt,
resident adapters own execution, and manager owns replacement/fencing.
**Inputs/prerequisites:** a `fanout.v1` body inside cf2a.v1 contains `fanout_id`,
`directive_digest`, `targets: [{agent_id, project_id, binding_generation, owner_fence}]`,
`policy: {concurrency, deadline_s, completion, replacement}` and `idempotency_key`.
Targets are nonempty and unique; concurrency is integer 1..1024, deadline_s is
integer 1..86400, completion is `all` or `fail_fast`, replacement is `never` or
`resume_fenced`. Missing policy/fields returns `422 FANOUT_POLICY_REQUIRED` before
custody. There is no implicit numeric concurrency or failure policy. The target
snapshot digest hashes the sorted canonical target list and is immutable.

1. Scheduler journals the request/policy/snapshot and creates one child operation
   ID per snapshot entry. It dispatches in bytewise agent-ID order, at most
   concurrency unsettled children; target unreachability remains a child outcome.
2. Child identities survive transport retries and binding changes. Each child
   follows CT-03 custody and F1 final settlement; success requires final accepted
   evidence, not a delivery acknowledgement. The aggregate remains running while
   any child is nonterminal and no cancellation/deadline applies.
3. With `all`, failure does not cancel siblings. With `fail_fast`, the first
   terminal non-success stops undispatched children and requests F8.1 cancellation
   of running siblings. Their cancellation/fencing receipts are retained before
   aggregation; successful children are not rolled back.
4. Deadline is measured from accepted monotonic start; restart derives remaining
   time conservatively from persisted UTC deadline and never extends it. At expiry
   unfinished children become timed_out after cancellation/fence requests; unknown
   quiescence is explicit. A result first received after the durable deadline-close
   is retained as late evidence, not a new success. A conflicting duplicate is
   RESULT_CONFLICT, not a second target receipt.
5. An authorized aggregate cancel CAS closes dispatch, invokes F8.1 for every
   running child and records cancelled children plus prior successes. Replacement
   `never` leaves the original target failed/unavailable. `resume_fenced` permits
   the same logical child on a replacement only after F8 fence/effect discovery;
   it records old/new binding and does not expand the target snapshot, duplicate
   effects or reset deadline. New physical execution attempts remain visible.
6. Scheduler computes the closed aggregate below from durable child receipts and
   publishes `{fanout_id, snapshot_digest, policy, children, aggregate,
   completed_at, evidence_refs}`. Children contain their operation/target identity,
   final status, settlement revision and late-result references. Replay reads this
   object; it never launches a settled child again.

| Condition, in priority order | Aggregate |
|---|---|
| Any child still nonterminal, before close/cancel/deadline | `running` |
| Every child is final accepted success | `success` |
| At least one success and at least one failure/cancel/timeout/unavailable/unknown | `partial` |
| No success and explicit aggregate cancellation | `cancelled` |
| No success and at least one timeout at deadline | `timed_out` |
| No success and any other terminal non-success | `failed` |

**Failure/recovery/settings:** pending aggregate recovery re-reads child custody,
effects and settlement before retry; loss of its ledger yields UNKNOWN_RESULT,
not an empty target list. Policy is immutable for the request; changing it needs
another fanout_id and explicit authorization, not replay. Ledger/evidence retention
uses Part I §1.9.8. **Metric owner:** scheduler owns fanout state and per-target
terminal counters; Crier owns delivery counters, never acceptance counters.
**Completion proof:** one receipt per original snapshot entry, bounded concurrency,
unchanged deadline and recomputable aggregate. Scenarios include an unreachable
and slow target, fail-fast cancellation, replacement, late result and duplicate
replay; each must reproduce the truth-table outcome. [CT-02/03/06/29; F8.1]

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
| 1. Factory bootstrap and deployment-profile selection | F2.0 cold bootstrap, Part I §1.6 profiles, F12 identities, F13 versions | carried; per-profile support matrix (Kubernetes, Compose, homelab/VPN, standalone) is an explicit F2/V2-ARCH-02 requirement — cloud adapters lower priority |
| 2. Project and initiative onboarding | F2 (project path: repo, board, namespace, model access), F1 (worker budget seed), F11 (admission enable) | carried; ready state precedes admission (F2 step 6) |
| 3. Controller-agent access and delegation | F12 (access policy, issuer, binding, verification), F2 (provisioned access), F1 (work delivery distinct) | carried; controller administration/repair access is distinct from Crier work delivery and per-Bunker foreman authority (V2-FLW-07) |
| 4. Desired-state reconciliation and automatic host-loss replacement | F8 steps 3–5 (reconcile, recreate, rebind), F2 (replacement provisioning), F10 (teardown of the old target) | carried; fencing/lease semantics per V2-ARCH-01 |
| 5. Board synchronization, claims and work wakeup | F11 step 2 (refresh before workability), F1 step 3 (claims), F8 (divergent copies, stale owners) | carried; one eligibility rule shared by scheduler and foreman |
| 6. Local memory operation and controller/Bunker synchronization | F3 (all steps; the local-commit acknowledgement and separate synchronization state) | carried; V2-FLW-05 failure classes and sync policy |
| 7. Pause, cancellation, drain, restart and resume | F8.1 execution control, F10 drain, F13 migration checkpoint, F9 deferral | carried; no silent budget reset, no duplicate publication |
| 8. Credential leak, revocation and reauthorization | F12 steps 5–6 (rotation, revoke, prove denial), F15 step 5 (revocation across restore), F9 (degraded posture) | carried; leak triggers configurable (V2-FLW-08) |
| 9. Backup, disaster restore and evidence retention | F15 (all steps), F6 (retention vs cleanup), F8 (recovery points), F10 (preserve-before-destroy) | carried; loss boundary of unsynchronized hosts stated in F3/F15 |
| 10. Configuration and harness/model/policy lifecycle | F13 (pins, schema, rollout), F2 (per-Bunker configuration), F9 (policy postures) | carried; Hermes fixed for MVP, future harness routing explicit, Terminal Jail optional and disabled by default (V2-ARR-04) |
| 11. Idle, discovery, external signals and useful-work limits | F11 step 5 (named deferral, next wakeup), F1 step 6 (stop when useful work is gone), F7 (observation of progress) | carried; no-op pacing is implementation evidence, not an approved universal default |
| 12. Publication, application handoff and document change control | F5 (task-to-verified-publication), F4 (document issue/acceptance), F13 (effective rollout state) | carried; project-level deployment scope stays a per-project acceptance question, not a Factory default |

### F17 runtime conformance matrix

Every primary flow has a nominal cell and the applicable replay, stale/late,
crash-window, concurrency and denial/revocation cells. A conformance run must name
the exact input revision, execution/operation identity, injected fault and durable
artifacts; a green nominal path never substitutes for these cells. `Rnn` is the
stable scenario id and `F17.nn` is its acceptance index into the corresponding
Part II section.

| Scenario | Flow and nominal path | Fault cells and required observable proof |
|---|---|---|
| R01 / F17.1 | F1 dispatch: fresh board → one admitted round → custody → briefs/results → guard/verdict → publication → memory → round settlement. | Replay custody/result/report without a second foreman, publication or budget reset; refuse stale generation; crash before launch, after local commit and after report; race two claims for one execution key; revoke mid-round. Exactly one durable settlement revision chain and once-only follow-up. |
| R02 / F17.2 | F2 provisioning: B1–B9 covers bootstrap, project/replacement, late memory/board/Crier, partial readiness, retry and replay. | Crash after create and after binding; concurrent create/register for one desired deployment; stale binding or unauthorized registration denied. One verified identity/fence becomes admissible, with no duplicate allocation. |
| R03 / F17.3 | F3 memory: recall → local fsynced worker/wave/round commits → readback → periodic/reconnect sync → controller readback. | Replay same ID/digest; changed digest returns MEMORY_CONFLICT; crash after fsync before acknowledgement; concurrent local/remote writers; wrong namespace denied. Pending holds survive restart and converge without duplicate or overwritten history. |
| R04 / F17.4 | F4 documentation: source intake → structural gate → independent review → spine/build/render QA → dispositioned owner package. | Replay identical source/draft without a new issue; crash between structural and semantic review; concurrent source edits invalidate stale evidence; owner denial preserves correction state. Accepted status binds exact source and artifact digests, not panel exit. |
| R05 / F17.5 | F5 landing: four stages and artifact transitions in §2.5. | Guard refusal, invalid source verdict, crash before/after integration/publication, integrated-gate denial, CAS race, remote denial, board/memory failure and replay. No unverified acceptance, duplicate publication or self-hashed closure. |
| R06 / F17.6 | F6 maintenance: discover candidates → resolve ownership/retention/pending-sync holds → bounded reclaim → ledger/readback. | Replay pass; crash after deletion before ledger; concurrent worker claim and reaper; protected path or ownership denial. Only proven-unowned eligible resources are removed; retained memory/evidence remains readable. |
| R07 / F17.7 | F7 monitoring: collect signed/host-scoped observations → freshness evaluation → metrics/events → subscriber delivery. | Duplicate sample/event id is idempotent; stale freshness is explicit; exporter crash resumes from checkpoint; concurrent readers see consistent counters; unauthorized subscription denied. No absent series is rendered as zero. |
| R08 / F17.8 | F8 recovery: detect desired/observed divergence → fence/drain → reconcile/recreate → rebind → verify → resume. | Replay recovery operation; crash before/after rebind; two reconcilers race; stale owner and unauthorized resume denied. One live generation owns the route, work resumes without duplicated execution and evidence names the loss interval. |
| R09 / F17.9 | F9 degradation: classify unavailable dependency → select configured posture → retain local/pending work → recover and reconcile. | Retry/replay preserves identities; crash during degraded write retains pending hold; concurrent healthy/degraded writers conflict explicitly; policy may deny degraded admission. Recovery never backdates remote durability or acceptance. |
| R10 / F17.10 | F10 teardown/rebuild: authorize → drain → quiesce/checkpoint → preserve/readback → destroy → reap → rebuild → reverify → re-register. | Replay destroy/rebuild; crash after destroy before ledger; concurrent teardown and rebuild; retention denial blocks destruction. No new dispatch before verified readiness; preserved and lost evidence are both reported. |
| R11 / F17.11 | F11 admission: A1–A8 covers nominal, unreadable, duplicate, stale, reservation crash, concurrency, denial and postcheck failure. | Reservation/claim CAS and generation fences prove one allowance/owner; failed refresh is UNAVAILABLE; revoked/disabled lanes emit no dispatch; recovery defines the next wakeup. |
| R12 / F17.12 | F12 credentials: authorize issue → scoped install/readback → rotate → revoke → prove old denial → reauthorize. | Replay rotation; stale credential/fence refused; crash after issue before binding is reconciled; concurrent rotations serialize; unauthorized issuance denied. Secret material never enters evidence; old authority remains denied after restore. |
| R13 / F17.13 | F13 upgrade: signed candidate → preflight/backup → canary → migration checkpoint → rollout → verification → rollback/continue. | Replay migration; crash mid-migration resumes from checkpoint; concurrent rollouts refuse; policy/signature denial stops before mutation. Effective version and schema readback match; rollback preserves data and names unsupported irreversible steps. |
| R14 / F17.14 | F14 observability ingestion: validate/envelope-authenticate → dedupe → durable append → index → query/export. | Duplicate event returns original receipt; late/stale event retains observed-vs-ingested time; crash after append before index rebuilds; concurrent writers preserve order per stream; malformed/unauthorized input denied. Counts reconcile exactly. |
| R15 / F17.15 | F15 backup/restore: encrypted snapshot → manifest/digest → independent custody → restore to isolated generation → integrity/readiness readback. | Replay restore; stale backup generation is labeled; crash after restore before readback remains unverified; concurrent restore CAS; retention/authorization denial blocks access. RPO/RTO, revoked credentials and unsynchronized loss interval are explicit. |
| R16 / F17.16 | F16 fan-out: derive independent lanes → allocate capacity → bind distinct workspaces → collect individual evidence → join only when required legs settle. | Duplicate/late lane completion reconciles by execution identity; crash after one lane preserves partial state; concurrent allocation cannot share a lane/workspace; stale fence denied. No worker is double-booked and aggregate success never hides a failed lane. |

The matrix is a requirement index, not a claim that these scenarios have already
run. Part VIII carries their execution evidence and unresolved coverage.

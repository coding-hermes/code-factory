# Part I — System arrangement

![System map](figures/system-map.svg)

The Factory arranges the components enumerated by `docs/SYSTEM-MODEL.yaml` on six
layers, joined by `CT-01`…`CT-30` plus `CT-06R` (Part IV), and exercised by
16 primary flows with explicit subflows (Part II). The model also names the two
external forge peers, the inference provider, authority and mutation broker.
A box on the map is a responsibility, not a path; the path that implements a box
lives in its `impl` note and may move without the system changing. Every box also
carries a role/host boundary: components tagged BUNKER execute inside the Bunker
deployment/execution boundary — the Bunker daemon's create/exec/cp surface, in a
profile selected by §1.6. Every model component has an explicit host value;
`external` denotes a provider, `authority` an independent failure domain, and
`controller-and-bunker` a separately instantiated service on both sides. Solid lines are interfaces that work as
documented, dashed lines are broken and named, dotted lines are designed but not
built.

The arrangement exists to serve the governing product definition (Part 0): a
person tells their agent what project or work they want, the agent turns that
intent into a Boardctl-backed plan, and the Factory builds the requested project
end to end against its acceptance criteria — while a deterministic
infrastructure-as-code management layer keeps the Factory's own infrastructure in
its declared state. The six layers are explanatory groupings that aid reading;
they may evolve as the design becomes complete and are neither a frozen
architecture nor a limit on the services the Factory may require. The stack reads
bottom-up: control decides, transport carries, execution does the work, memory
remembers, governance decides whether to believe the result, and evidence is what
a human finally reads. Counts are derived from the model's component/layer membership, including the
GUARD responsibility and external peers, rather than frozen prose totals. The
13 module chapters (M0–M12) remain implementation coverage; boundary peers and
new target responsibilities below do not acquire invented module ownership.

Four resolved decisions fix the arrangement and are repeated wherever they matter.
First, the project foreman runs **inside its Bunker**; Crier is the launch/return
boundary — the scheduler's envelope enters the Bunker through Crier, and the
foreman's response returns through Crier to the scheduler on the control host, which
records it and triggers subsequent processing. Second, **DuckBrain is installed in
every Bunker** and must expose the same logical project memory data/view as the
controller under Part V's same-namespace shared-Git profile; F3 defines local
commit acknowledgement and pending synchronization. This is specified target
behavior, not a measured installation claim. Third, the Task Router is future and not part
of the MVP, placed after Node and before Harness, and the MVP bypasses it — Hermes
is the fixed MVP harness. Fourth, the **Factory manager** — the deterministic
infrastructure-as-code management/reconciliation service and its desired/observed
state store — is a required component of the arrangement; it is specified in this
Part, registered in `docs/SYSTEM-MODEL.yaml`, and marked TARGET-UNIMPLEMENTED: not
yet built. Its language remains open; §1.9.2 fixes persistence semantics. The
CF2A-01/P5-A model contains manager and provider boundaries; wave C must regenerate
figures and the manifest caption from its digest before issuing the book.

## 1.1 General arrangement

The general arrangement drawing (above; regenerated from `docs/SYSTEM-MODEL.yaml`)
places the system's physical and trust structure:

- **The control host** holds the scheduler, the factory manager with its
  desired/observed state store, the credential issuers, the gateway and the
  inference proxy.
- **The Crier delivery boundary** separates control from execution. Every work
  crossing is labelled by payload and direction: the launch leg carries the
  signed envelope (`CT-02` → `CT-03`, LAUNCH); the return leg carries the
  foreman's durable response (`CT-06R` → `CT-06`, FOREMAN RETURN).
- **A representative project Bunker** contains the foreman, the Hermes worker
  (node, harness), the project checkout with its **embedded Boardctl board**, and
  the per-Bunker DuckBrain integration which must expose the same logical project
  memory data/view as the controller. No universal Bunker execution mode is
  assumed: image-backed and persistent-container profiles are chosen per Bunker,
  and memory uses the same-namespace shared-Git profile (F3).
- **The factory manager and its desired/observed state store** sit beside the
  scheduler on the control host. Its arrows carry its provisioning, readiness and
  binding updates **to** the Bunker (provision/install, replacement placement),
  **to** Crier (registration/routing bindings) and **to** the scheduler (target
  availability knowledge). Those arrows are dotted — designed, not built.
- **External Git providers are drawn as two, not one**: GitHub (measured
  credential machinery, M7) and GitLab (a required target provider with its own
  adapter and identity semantics, never assumed to inherit GitHub App behavior).
  Additional providers are identified by name when required, never inferred. Each
  provider sits behind its own credential trust boundary.
- **Credential trust boundaries are drawn as insets**: model access (node → proxy
  → upstream, the node never sees a provider key), forge credentials (issuer →
  install delivery → runtime file), and Bunker platform authentication. The
  insets distinguish who issues a credential, who delivers it, where it executes,
  and what may read it (§1.4).

Arrows on the map carry contract ids as cross-references into Part IV; layer
names are the explanatory groupings of the opening section and may evolve.

## 1.2 The normal operating sequence

The sequence below is the approved target for one foreman round. It is drawn in
Part II (F1) with the round loop and wave detail; the ordering and ownership
stated here govern, and Part II supplies the full procedures.

1. **Refresh and check the board.** The scheduler refreshes the repository and
   board copies — local and remote — *before* eligibility is judged, and a
   scheduler-owned board-check verifier classifies the result: work, no-work, or
   an unreadable board. An unreadable board is never dispatched against.
2. **Admit the lane.** Admission policy (cadence, capacity, fairness, pacing)
   decides whether a round runs now; refusals carry a named reason and release
   their reservations.
3. **Deliver and launch the foreman round.** The scheduler sends an identified
   foreman-round request with its **total-worker allowance** through Crier; the
   selected execution adapter launches the project foreman inside its Bunker.
4. **Select, claim and brief (wave 1).** The foreman reads the current board and
   project memory (local namespace queries remain a supported path when the
   DuckBrain HTTP service is unavailable), analyzes impact through Hilo, selects
   and claims useful compatible work, and assembles worker briefs with acceptance
   criteria, model/provider access and isolated workspaces.
5. **Workers implement under guard.** Each worker produces commits under the
   required GitReins guard and the independent acceptance process. Failed
   criteria return to correction; branch success remains distinct from verified
   merged/published work.
6. **Verify and publish.** The foreman verifies the integrated and published
   results as required — merged-tree proof, required checks — before counting any
   result.
7. **Update board and memory.** The foreman updates each task-board record with
   evidence, ensures every worker has a correlated DuckBrain entry describing its
   work, and creates a DuckBrain entry for the wave. If the DuckBrain HTTP path
   is unavailable but the local namespace is usable, it persists worker/wave
   records through supported native local persistence and tracks pending
   synchronization while continuing useful work.
8. **Recompute and form the next wave.** The foreman recomputes the work
   unblocked by those results and forms the next compatible wave while useful
   work **and remaining total-worker allowance** permit. **Wave boundaries do not
   replenish the budget**: the allowance is the total for the whole round,
   allocated by the foreman across compatible waves. It is a cap, not a quota —
   the foreman launches no unnecessary worker merely to exhaust it.
9. **Summarize and return.** At the end, the foreman creates a distinct DuckBrain
   summary for the complete round, linked to its worker and wave records, and
   returns through Crier a correlated report — all waves, task/worker outcomes,
   evidence, budget use, remaining work, and the **stop reason** (no useful work,
   allowance exhausted, or another named operating condition) — to the
   control-host scheduler. Final round records are durably captured locally, with
   local persistence, Git commit and remote synchronization reported as distinct
   states.
10. **Settle.** The scheduler durably records the round result; the end-of-lane
    repository/board refresh and verifier produce explicit results whose order
    and final-acceptance effect are defined so a required post-hook failure
    cannot be hidden by an earlier success record.

A task completing inside step 6 is what unlocks a later wave in step 8: the
outer loop of steps 4–8 repeats inside one round until stop, all within the
single round-wide worker allowance of step 3.

## 1.3 Components and responsibilities

Each entry states the component's purpose, form and execution location,
caller/trigger, owned decisions and state, inputs, outputs, consumers, failure
behavior, and pointers to its module chapter, contracts and settings. **Form**
separates runtime processes from prompts, configuration and libraries: a prompt
file is not a process, and a library is not a service. Source locators and
measured implementation coverage are evidence, kept in the entries and distinct
from approved target behavior.

### 1.3.1 Control — decides what should happen

**1. OPERATOR**
- **Purpose:** the human boundary — intent, priorities, approval.
- **Form/location:** human; no runtime process.
- **Caller/trigger:** conversational intent; approval requests arriving as
  `CT-18` artifacts (UNVERIFIED).
- **Owned decisions and state:** what projects are wanted and whether a result
  is accepted; the declared desired-state configuration of the Factory may be
  edited by the user or by an authorized agent acting on the user's behalf —
  never by Boardctl work authority (V2-SET-08).
- **Inputs:** approval artifacts, status readouts, events.
- **Outputs:** intent (conversational), lane declarations (`CT-01`), desired-state edits.
- **Consumers:** scheduler (lane config), factory manager (desired state).
- **Failure behavior:** not applicable; operator silence defers admission, it does not authorize work.
- **Pointers:** `CT-01` (UNVERIFIED — declared in `fleet.example.toml:15,35` and
  scheduler.db project rows; consumer `admission_mode.go:112`
  `admissionModeForProject`, M9 §6); desired-state authority Part V (target).

**2. SCHEDULER**
- **Purpose:** the control plane's clock and admission authority — whose turn it is.
- **Form/location:** runtime process (Go) on the control host.
- **Caller/trigger:** configured cadence tick or supported wakeup (F11).
- **Owned decisions and state:** lane admission (tasks vs cooldown), per-lane
  cadence/weight/pin, round issuance and settlement of every dispatch; the
  30-table SQLite execution record. Does not run work and does not know what a
  diff contains.
- **Inputs:** `CT-01` lane configuration and lane_seed extension, `CT-06` round
  reports and refreshed board copies.
- **Outputs:** `CT-02` round-admission.v1 inside cf2a.v1 (§1.9.6), admission
  refusals and settlement revisions. Legacy BuildDispatch fields are translated
  only with the persisted admission; their measured transport is not target proof.
- **Consumers:** crier (delivery), the operator's metrics surface (`/api/v1/metrics`, M9 §8).
- **Failure behavior:** gateway failure defers the tick rather than spawning
  (`no-exec-fallback=true`, M9 §5); load gate defers new spawns at threshold; an
  unreadable board is diagnosed, never dispatched.
- **Pointers:** M9 (`docs/handbook/chapters/M9-scheduler.md`); contracts `CT-01`,
  `CT-02`, `CT-06`; settings Part V (cadence, admission, pacing).

**3. FOREMAN (Hermes)**
- **Purpose:** turn a scope of board work into briefed, verified, published,
  recorded rounds — the operating agent of the project delivery loop.
- **Form/location:** LLM lane driven by seeded prompts and skills; runs **inside
  its Bunker** — a resolved decision, not an implementation detail. It never runs
  on the control host.
- **Caller/trigger:** the scheduler's round request delivered through Crier with
  the round's total-worker allowance (F1 step 2).
- **Owned decisions and state:** task selection and claims within eligible work,
  partitioning compatible work into waves, worker briefing, verification of
  returned evidence, board truth (row create/close/evidence via boardctl),
  worker/wave/round memory entries, and the round's stop reason. Does not grade
  its own homework — a judge seat does.
- **Inputs:** the delivered round request, board and memory reads (local
  namespace queries supported when the DuckBrain HTTP service is unavailable),
  worker results.
- **Outputs:** worker briefs, wave launches, `CT-14` board writes (UNVERIFIED —
  the store is measured at 357 rows/520 events, the foreman write wire is not
  exercised, M4 §6), `CT-15` DuckBrain decisions/findings through its own
  Bunker's instance (UNVERIFIED), `CT-06R` the durable return leg through Crier
  (UNVERIFIED until Part IV cites the producing call).
- **Consumers:** scheduler (via `CT-06` settlement), board, DuckBrain shared view.
- **Failure behavior:** continues useful work during temporary DuckBrain
  unavailability using supported local namespace persistence, keeping durable
  pending entries at worker, wave and round level for later synchronization
  (V2-Q-04); ends the round with a named stop reason; never infers project
  completion from one task or a quiet board.
- **Pointers:** no module chapter — boundary peer; `prompts/foreman.md` and
  `skills/code-factory-foreman` are its configuration (form: prompts, not a
  process); contracts `CT-05`, `CT-14`, `CT-15`, `CT-06R`.

**4. GITHUB CREDENTIALS**
- **Purpose:** mint, cache and refresh GitHub App installation tokens — forge
  authentication for the GitHub provider.
- **Form/location:** scripts (processes run on demand) on the control host.
- **Caller/trigger:** token refresh schedules and node installation runs (F12).
- **Owned decisions and state:** installation-token lifecycle for GitHub; never a
  token in argv (M7 §2). Does not mint the per-dispatch scoped token or the node
  tokens (M7 §12).
- **Inputs:** the App private key file (mode 0600).
- **Outputs:** CT-21 native installation credentials to the controller broker;
  Bunkers receive read-only access and attenuated capabilities (§1.9.7). M7 §6
  describes legacy node token-file delivery, not the fenced target.
- **Consumers:** broker credential custody and issuer refresh runs.
- **Failure behavior:** a failed mint yields no token file rather than a stale one; expiry is handled by refresh, not by extending scope.
- **Pointers:** M7 (`docs/handbook/chapters/M7-github.md`); contracts `CT-21`,
  M7-C1; settings Part V. GitHub is one provider of at least two: GitLab is a
  required target with its own adapter and identity semantics (§1.4, V2-ARR-06).

**5. SCOPE MINTER**
- **Purpose:** attenuate broker authority to one dispatch, not deliver a native
  GitHub write credential to a Bunker.
- **Form/location:** authority/broker service operation on the control boundary;
  fleet-gh-scope.py in M11 is legacy coverage.
- **Caller/trigger:** each admitted attempt and its authorized refresh.
- **Owned state:** capability hash, parent scope, attempt, fence and expiry.
- **Inputs / outputs:** repository/operation scope in; reference-bound capability
  out through the protected runtime-file path (§1.9.7).
- **Consumers:** resident adapter and broker validation, not arbitrary forge clients.
- **Failure behavior:** issuer/revocation outage refuses access; ending a process
  alone is not revocation.
- **Pointers:** CT-21, §1.9.7, F12; M11 legacy implementation evidence.

**6. FACTORY MANAGER** — *TARGET-UNIMPLEMENTED*
- **Purpose:** the deterministic infrastructure-as-code control service. It
  durably tracks declared desired deployment state and observed current state for
  the whole Factory, maps and manages the settings of participating systems
  through adapters, deterministically diffs and applies, and continuously
  reconciles drift and failures so the project execution environment remains
  available and correct. It coordinates the existing small tools so no operator
  or agent must learn and manually sequence every one of them.
- **Form/location (target):** a runtime management service on the control host
  with a durable desired/observed state store. The implementation language and
  HTTP framework remain open; the durable JSONL profile is §1.9.2 and the
  required wire grammar is §1.9.1 (V2-ARCH-01, V2-ARCH-03).
- **Caller/trigger:** declared events and cadence — authorized configuration
  update, drift detection, health/readiness observation, host-loss or placement
  failure, credential lifecycle operations.
- **Owned decisions and state:** the versioned desired-state schema and its
  generations; the durable observed inventory; reconciliation status; replacement
  placement and rebalancing within the declared eligible host pool; Crier
  registration/routing bindings and scheduler target-availability updates;
  lease/active-owner/fencing state for partitioned hosts. It never rewrites the
  user's desired access, capacity or policy intent as a side effect of an
  operational change (V2-SET-08), and it never improvises maintenance with an LLM
  — convergence is deterministic code.
- **Inputs:** versioned desired configuration (authorized API or declared-file
  update), observed state read back through adapters, health events, allocation
  requests.
- **Outputs:** deterministic plans/diffs, ordered adapter changes, effective-state
  readback, converged/degraded/failed status, binding updates to Crier and the
  scheduler, provisioning and replacement operations (F2), status/events/metrics
  via its versioned management API (§1.7).
- **Consumers:** operator and authorized agents (status, management), scheduler
  (availability knowledge), crier (bindings), provisioner (bootstrap work),
  monitoring and webhooks (allocation shortfalls, recovery states).
- **Failure behavior:** explicit degraded and unrecoverable states; retry/backoff,
  idempotent apply, partial-update recovery; when it cannot satisfy the declared
  allocation it exposes the exact shortfall and preserves the desired request
  rather than silently changing desired state; a partitioned old host is fenced
  by lease/active-owner semantics, not assumed dead (§1.8).
- **Pointers:** no module chapter — required target component (V2-ARCH-01);
  normative manager contracts `CT-24`–`CT-30` and `CT-06R` in Part IV §IV.1;
  desired-state and readback schema Part V §V.3/§V.6; state model §1.9.2–§1.9.4.

### 1.3.2 Transport — carries the decision

**7. CRIER (bus)**
- **Purpose:** the launch/return boundary between the control host and the
  Bunkers — delivery with per-agent signature, leases, replies, idempotency (M10 §2).
- **Form/location:** runtime process (Go) reachable from both sides.
- **Caller/trigger:** scheduler deliveries, node inbox pulls, replies, registrations.
- **Owned decisions and state:** durable inbox, leases, registration registry,
  reply routing. Does not decide, does not execute, holds no board admission (M4
  §12 B04); delivery is not task acceptance.
- **Inputs:** `CT-02` the scheduler's signed envelope, accepted by
  `internal/registry/handler.go:990` `HandleDeliver` into the durable inbox,
  verbatim after the CF-354 fix (PROVEN); `CT-04` the node's reply (PARTIAL);
  `CT-22` agent registration: normatively the authority creates `registration_id` and
  the class-`crier` credential reference at enrollment, the Crier registrar is the only
  actor that admits `register.v1` and allocates the node identity;
  the node emits `register.v1` (outer `cf2a.v1`). Implementation coverage is
  unverified because no in-repo producer was measured (CF-276; M1 §6).
- **Outputs:** `CT-03` inbox message plus a 30-second lease, pulled by
  `scripts/node-bus-worker.py:1356,1383` with a signed GET and cleared by
  `/inbox/ack` (PROVEN); `CT-06` the completion event carried with ReplyTo
  correlation into the scheduler's durable inbox by
  `internal/registry/handler.go:170,1452` (PROVEN); `CT-08` hermes-session
  delivery POSTed by `internal/hermesession/hermesession.go:353 Client.Deliver`
  at the gateway origin (PROVEN).
- **Consumers:** node worker and dispatcher (inbox), scheduler (returns), gateway (sessions).
- **Failure behavior:** unacked messages redeliver after lease expiry; an empty
  list is not a lost message (M10 §11).
- **Pointers:** M10 (`docs/handbook/chapters/M10-crier.md`); contracts `CT-02`
  through `CT-04`, `CT-06`, `CT-08`, `CT-22`; settings Part V.

**8. HERMES GATEWAY**
- **Purpose:** controller telemetry/session readout; the resident Bunker adapter
  owns foreman execution. CT-08 is a Bunker-local session endpoint when used for
  work, never a controller execution fallback.
- **Form/location:** separate instances: read-only controller gateway and
  Bunker-local execution gateway under the project principal.
- **Caller/trigger:** crier session delivery; dashboard and status requests.
- **Owned decisions and state:** session records, `/api/status`, dashboard auth.
  Does not schedule and does not store the ledger.
- **Inputs:** `CT-07` model choice (UNVERIFIED), `CT-08` delivered messages
  (legacy coverage, platforms/api_server.py:1763). CT-20 terminates at the
  configured inference provider, not this telemetry gateway.
- **Outputs:** local session rows; model turns only in the Bunker instance.
- **Consumers:** the session store; crier's hermesession client.
- **Failure behavior:** its failure defers scheduler ticks (`no-exec-fallback=true`, M9 §5) — degradation, not fallback.
- **Pointers:** boundary peer — no module chapter; contracts `CT-07`, `CT-08`, `CT-20`.

**9. INFERENCE PROXY**
- **Purpose:** the only holder of the provider credential for node inference.
- **Form/location:** runtime process (`~/.hermes/scripts/cf-inference-proxy.py`) on the control host.
- **Caller/trigger:** node chat-completion requests.
- **Owned decisions and state:** provider credential custody; node admission by
  token; model allowlist; stream/buffer handling (M12 §2). No anonymous paid
  path; a node never sees a provider key.
- **Inputs:** `CT-19` chat completion with a node bearer token — the proxy half
  is measured (401 without a token); the node client half is config-wired with no
  call site in this repo (M12 §6).
- **Outputs:** `CT-20` forwarded inference upstream, 300-second timeout; usage
  JSONL per request (node, model, status, bytes, M12 §8).
- **Consumers:** nodes (responses), observability (usage records).
- **Failure behavior:** fail-closed at startup — no token file or no upstream key
  exits 2 (M12 §11); the upstream is a rumour with one side named and healthy
  streams are unframed to completion (M12 §6).
- **Pointers:** M12 (`docs/handbook/chapters/M12-inference-proxy.md`); contracts `CT-19`, `CT-20`, M12-C1, M12-C2.

### 1.3.3 Execution — does the work

**10. BUNKER DAEMON**
- **Purpose:** the Bunker deployment/execution boundary itself — hosts agent
  containers, provides create/exec/cp, per-agent home.
- **Form/location:** runtime process on the Bunker host.
- **Caller/trigger:** provisioner and dispatcher calls.
- **Owned decisions and state:** container lifecycle and per-agent homes. Does
  not own credentials or config; authentication is only one part of its platform
  role (V2-ARR-08).
- **Inputs:** `CT-23` create/exec/cp driven by `scripts/bunker-provision.sh:504`
  (UNVERIFIED — the calls were measured across M1's batteries; the daemon's
  accept side has no in-repo `file:function` to cite, M1 §6).
- **Outputs:** executing agent containers.
- **Consumers:** provisioner, dispatcher.
- **Failure behavior:** not specified in the register — a named gap; hosting
  lifecycle, isolation, resources, storage/mounts, networking and identity are
  Bunker responsibilities covered per profile in §1.6 and Part V.
- **Pointers:** boundary peer — no module chapter; contract `CT-23`, M1-C2.

**11. NODE**
- **Purpose:** one project per node — repo clone, seeded prompts/skills, env,
  identity, bus worker (M2 §2).
- **Form/location:** runtime processes inside its Bunker (`scripts/project-node.sh`,
  `scripts/node-bus-worker.py`); the node never executes on the control host.
- **Caller/trigger:** the leased inbox message (`CT-03`).
- **Owned decisions and state:** the project working copy, node identity, bus
  worker loop. Does not decide what to work on.
- **Inputs:** `CT-03` (the dispatcher is the second consumer of the same
  contract, M2 §6/M11 §6); `CT-21` the installation token file.
- **Outputs:** `CT-04` the reply — shape `:1176-1192` (PARTIAL: transport works,
  but the scheduler's `dispatchReplyVerdict` at `dispatch_leg.go:713-726` reads
  only `ok`, while the node sends `status:"failed"` with no `ok` at
  `node-bus-worker.py:1180` — CF-355, a failed run recorded as success); `CT-09`
  DuckBrain records (MISSING — zero calls, CF-329, M2 §6); `CT-10` board row
  events (BROKEN — no in-repo producer, M4 §6); `CT-11` turns to the session
  store (boundary wire, M2 §6); `CT-12` the staged diff via the pre-commit hook
  pinned at `scripts/install-gitreins.sh:124` (hook enforcement unproven, M3 §6);
  `CT-19` inference through the proxy; `CT-22` agent registration. The normative
  actor/data shape is the authority/controller-issued `registration_id` and
  class-`crier` credential reference followed by node `register.v1` (outer
  `cf2a.v1`); implementation coverage is unverified because no in-repo producer
  was measured (CF-276, M1 §6).
- **Consumers:** crier (reply), harness, proxy, gitreins.
- **Failure behavior:** a dead worker returns its row to blocked rather than
  letting it vanish (Part 0); redelivery replays only a recorded result (M11 §3 S2).
- **Pointers:** M2 (`docs/handbook/chapters/M2-dispatch.md`); contracts above.

**12. TASK-ROUTER** — *FUTURE, NOT PART OF THE MVP*
- **Purpose:** today, which model answers a prompt (lane chains, caps, PAYG
  ordering); in the stated future design intent, harness selection.
- **Form/location:** runtime service outside the covered code.
- **Caller/trigger:** prompt routing (model/provider) now; a future harness
  selection point after Node and before Harness.
- **Owned decisions and state:** routing tables and caps. The two selection roles
  are kept separate and never equated. Does not carry work.
- **Inputs / outputs:** `CT-07` the model choice for a prompt, in-band
  (UNVERIFIED — neither side has an in-repo `file:function`, the wire was not
  measured, M12 §6).
- **Consumers:** the Hermes gateway.
- **Failure behavior:** the MVP bypasses this point entirely — Hermes is the fixed MVP harness.
- **Pointers:** boundary peer; contract `CT-07`; placement decision Part 0.

**13. HARNESS**
- **Purpose:** the coding loop inside the node — Hermes (fixed MVP harness) plus
  codex, claude-code, opencode, pi, dsh at pins (M5 §2).
- **Form/location:** installed toolchains and scripts (`scripts/harness/*`)
  inside the node; form: process per run, installed at pinned versions.
- **Caller/trigger:** worker/dispatcher invocation.
- **Owned decisions and state:** the edit-test loop within a brief. Does not
  write the board.
- **Inputs:** briefs and workspaces from the foreman/worker flow.
- **Outputs:** commits and evidence; `CT-17` the conformance battery's per-leg
  verdict (check, apply, smoke, vars, memory) is UNVERIFIED — not run this round
  because it needs a live node, and vars and memory had no executor (CF-328, M5 §6).
- **Consumers:** foreman verification, gitreins guard.
- **Failure behavior:** harness support is earned per leg by the conformance
  battery, never assumed.
- **Pointers:** M5 (`docs/handbook/chapters/M5-harness.md`); contract `CT-17`; pins Part V.

**14. DISPATCHER**
- **Purpose:** the target resident adapter launches foreman/worker processes in
  its own Bunker cgroup and persists replay/control state. The legacy central
  dispatcher calls bunker exec from the controller under a lifecycle principal;
  that is not a Bunker-resident process with host-admin credentials (M11 §2).
- **Form/location:** runtime process (`~/crier-fleet/dispatcher.py`) inside the Bunker.
- **Caller/trigger:** the same `CT-03` inbox crier serves; its per-dispatch token
  comes from the scope minter (M11 §3 S4).
- **Owned decisions and state:** the replay ledger and execution lifecycle. May
  not decide admission or what the work is (M11 §2).
- **Inputs:** inbox messages; scoped token.
- **Outputs:** completion reaching the scheduler through crier — it always sends
  `ok`, the field `dispatchReplyVerdict` reads (M11 §6, under `CT-06`).
- **Consumers:** scheduler settlement.
- **Failure behavior:** the ledger replays a recorded result instead of re-running
  a redelivery (`dispatcher.py:470-475`) only for a task whose result reached the
  ledger before the crash (M11 §3 S2); the deadline kill terminates run.sh's
  process group, not the harness's own group, so the kill-the-group guarantee is
  withdrawn (M11 §2).
- **Pointers:** M11 (`docs/handbook/chapters/M11-dispatcher.md`).

**15. PROVISIONER**
- **Purpose:** qualify the host against a disk floor, create the container, mint
  identity, seed prompts/skills/env, connect the bus (M1 §2) — the install side
  of credential and configuration delivery (V2-ARR-08).
- **Form/location:** scripts (processes run on demand) — `scripts/bunker-provision.sh`,
  `scripts/project-node.sh`, `scripts/node-create.sh`.
- **Caller/trigger:** operator destroy/rebuild directives (M1 §5); factory
  manager replacement placement under the target architecture (§1.8).
- **Owned decisions and state:** host qualification, container creation, seeding.
  Does not certify the result — the verifier does (M1 §12).
- **Inputs:** manifests, credentials and configuration to install (issuance
  authority stays with the issuer; the installer delivers, it does not authorize).
- **Outputs:** `CT-23` create/exec/cp against the agent container (UNVERIFIED,
  see BUNKER DAEMON); seeded workspaces; the hygiene reap removes orphan homes
  and keys after a 60-minute grace (M1 §5); the seed reapplies from the manifest
  and names drift per file (M1 §3).
- **Consumers:** node, verifier, bunker daemon.
- **Failure behavior:** qualification failures refuse the host; a failed seed names drift rather than silently proceeding.
- **Pointers:** M1 (`docs/handbook/chapters/M1-provisioning.md`); contracts `CT-23`, M1-C2.

**16. LANDER**
- **Purpose:** broker-mediated publication to the declared destination ref,
  with mode-specific commit/tree proof (§1.9.7, F5). The origin/main ancestry
  rule is the measured merge-only implementation (M3 §2).
- **Form/location:** script (`scripts/land-node-branch.sh`), run on the merged tree.
- **Caller/trigger:** operator or configured foreman integration policy — the
  envelope names branch and commit, it does not call the lander (M3 §2).
- **Owned decisions and state:** the landing act itself; ancestry proof.
- **Inputs / outputs:** candidate branch and commit in; published tree and proof out.
- **Consumers:** foreman verification, board evidence.
- **Failure behavior:** no register row; a failed landing leaves the branch unmerged and the row open.
- **Pointers:** M3 (`docs/handbook/chapters/M3-repository.md`).

### 1.3.4 Memory — remembers what happened

**17. BOARD**
- **Purpose:** the append-only record of work and its state; the fleet's plan (M4 §2).
- **Form/location:** data files with the `boardctl` CLI; the board lives in each
  project repo — including the copy **embedded in the project checkout inside
  each Bunker** — so a local working copy and the remote copy are distinct until
  a recorded refresh or publication reconciles them. Scheduler hooks own their
  admission/settlement read copies; the foreman owns claim/publication retries
  through the canonical broker CAS (§1.9.6).
- **Caller/trigger:** foreman writes, verifier reads, refresh hooks.
- **Owned decisions and state:** row state and audit events — foreman-owned (the
  scheduler's settlement record is a separate execution record, V2-FLW-02). Not a
  run log — rows are reused across attempts.
- **Inputs:** `CT-10` node row events (BROKEN — no producer, M4 §6); `CT-13` the
  verdict that closes a row (completion requires `--evidence-run-id`; the
  verdict-to-close path was not re-run, M4 §6); `CT-14` foreman writes
  (UNVERIFIED, M4 §6).
- **Outputs:** board state to every reader; `board_read` resolves the board from
  origin/main when the working copy drifts (M4 §3).
- **Consumers:** scheduler admission, foreman selection, humans.
- **Failure behavior:** `board_lock` ERROR verdict — lock state unknown: stop and
  diagnose, never write (M4 §3).
- **Pointers:** M4 (`docs/handbook/chapters/M4-board.md`); impl
  `.coding-hermes/board/tasks.jsonl`, `scripts/boardctl`.

**18. DUCKBRAIN**
- **Purpose:** namespaced durable project memory — run records, findings, recall.
- **Form/location:** service plus **local Git-backed namespace repositories on
  the machine**; installed in every Bunker and on the control host. A resolved
  decision requires a per-Bunker instance to expose the same logical project
  memory data/view as the controller using Part V's same-namespace shared-Git
  profile; local commit is the write acknowledgement, remote sync is separate. Losing
  the HTTP server does not imply losing local memory access — local queries and
  supported local persistence run against the same project namespace, with
  synchronization and shared-view freshness handled separately (V2-Q-04).
- **Caller/trigger:** foreman, workers (through the designated writer — each
  worker must HAVE an entry; the user has not required direct worker write
  access), scheduler namespace sync (every 5 m, M9 §5), recall queries.
- **Owned decisions and state:** namespace data and its Git history. Does not own
  the plan or the code.
- **Inputs:** `CT-09` node run records (MISSING — CF-329, M2 §6); `CT-15`
  foreman decisions and findings through the Bunker's own instance (UNVERIFIED
  boundary, M9 §6); worker, wave and round entries under the target memory
  contracts (V2-FLW-02).
- **Outputs:** recall by project, week and lane (Part II, F3); the shared logical view.
- **Consumers:** foreman, operator, scheduler sync.
- **Failure behavior:** service unavailability degrades to supported local
  operations with pending synchronization tracked — it never silently promotes
  remote unavailability to lost records (V2-FLW-05).
- **Pointers:** boundary peer; contracts `CT-09`, `CT-15`; memory settings Part V (target).

**19. SESSION STORE**
- **Purpose:** every model turn, its model, tokens and cost. Not the plan, not the product.
- **Form/location:** SQLite data (`~/.hermes/state.db`).
- **Caller/trigger:** gateway writes.
- **Owned decisions and state:** session ledger only.
- **Inputs:** `CT-11` node turns written via the gateway (UNVERIFIED — both ends
  are the Hermes runtime, out of scope, M2 §6).
- **Outputs:** session history; the scheduler's `--reap-sessions` closes stale
  sessions, dry-run without `--apply` (M9 §5).
- **Consumers:** cost and usage reporting.
- **Failure behavior:** reap is dry-run by default — no destructive surprise.
- **Pointers:** boundary peer.

### 1.3.5 Governance — decides whether to believe it

**20. COMMIT GATE (gitreins)**
- **Purpose:** pre-commit grading — secrets, lint, tests — and the verdict that
  lands work (M3 §2).
- **Form/location:** binary invoked as a git hook inside the node.
- **Caller/trigger:** every commit (`CT-12`).
- **Owned decisions and state:** the commit verdict. Does not decide what to build.
- **Inputs:** the staged diff; the hook side is pinned at
  `scripts/install-gitreins.sh:124` (`$VENV/bin/gitreins guard --quality-async`),
  but that git invokes the hook is unproven (M3 §6, M3 §11).
- **Outputs:** `CT-13` the verdict that closes a row (UNVERIFIED, see BOARD).
- **Consumers:** foreman closeout, board.
- **Failure behavior:** where the gate is absent the pre-commit hook exits 0 — a
  silent bypass that must be disclosed (M3 §10).
- **Pointers:** M3 (`docs/handbook/chapters/M3-repository.md`); contracts `CT-12`, `CT-13`.

**21. DOC GATE**
- **Purpose:** whether a document is citable — sections, locators, facts, earned
  VERIFIED. A structural gate, not a truth verifier; it cannot tell whether a
  sentence is true (M6 §2).
- **Form/location:** script (`scripts/master_doc_check.py`).
- **Caller/trigger:** handbook builds over the foreman's skeleton and seat fills (Part II, F4).
- **Owned decisions and state:** structural citation verdicts.
- **Inputs / outputs:** `CT-16` the module status word, printed at
  `scripts/master_doc_check.py:263` (`MASTER-DOC: PASS|FAIL`, exit 1 on FAIL) —
  downgraded from PROVEN: the handbook build reads no MASTER-DOC output, so the
  receiver half is uncited (M6 §6).
- **Consumers:** handbook build (nominally).
- **Failure behavior:** FAIL exits 1.
- **Pointers:** M6 (`docs/handbook/chapters/M6-documentation.md`); contract `CT-16`.

**22. CONFORMANCE BATTERY**
- **Purpose:** whether a harness is supported, measured per leg on a real node (M5 §2).
- **Form/location:** script (`tests/harness-conformance.sh`).
- **Caller/trigger:** harness changes and pin bumps.
- **Owned decisions and state:** per-leg support verdicts. Does not install anything by itself.
- **Inputs / outputs:** `CT-17` the per-leg verdict into the harness record
  (UNVERIFIED — see HARNESS).
- **Consumers:** harness records, pins.
- **Failure behavior:** a failed leg removes the harness leg's support claim.
- **Pointers:** M5; contract `CT-17`.

**23. NODE VERIFIER**
- **Purpose:** the certification ladder — agent, gateway, auth, artifact, tree,
  seed — with VERIFIED earned per leg (M1 §11).
- **Form/location:** script (`scripts/verify-node.sh`).
- **Caller/trigger:** provisioning and verification runs; a procedure over the
  node, not a standing wire.
- **Owned decisions and state:** node certification state.
- **Inputs / outputs:** the node under test in; per-leg verdicts out. An
  unreachable port is UNVERIFIED (exit 3), not FAIL (M1 §10, CF-224).
- **Consumers:** provisioner, operator.
- **Failure behavior:** UNVERIFIED is distinct from FAIL — absence of evidence is not evidence of failure.
- **Pointers:** M1; contract M1-C2 context.

**24. SAFETY**
- **Purpose:** reap build caches and expired job dirs; refuse a gitleaks claim
  without its `--log-opts` scope (M8 §2).
- **Form/location:** scripts (`scripts/reclaim_disk.py`, `scripts/check_scan_scope.py`).
- **Caller/trigger:** periodic capacity maintenance (F6).
- **Owned decisions and state:** reclaim eligibility by TTL and scope.
- **Inputs:** filesystem state, scan-scope claims.
- **Outputs:** reclaimed space and retained/refused reasons. The target requires
  retention-index hold/tombstone CAS (§1.9.8); M8 §2's age-only deletion of cited
  evidence is a prohibited legacy deviation. Protected paths remain refused.
- **Consumers:** hosts, operators.
- **Failure behavior:** refusal is the safe direction; over-deletion is bounded by protected paths.
- **Pointers:** M8 (`docs/handbook/chapters/M8-safety.md`).

**25. DOC PANEL**
- **Purpose:** three seats grading a module independently; splits are reported,
  never voted away (M6 §3 S4).
- **Form/location:** scripts (`scripts/panel_loop.py`, `scripts/master_doc_panel.py`).
- **Caller/trigger:** module review cycles.
- **Owned decisions and state:** independent seat verdicts.
- **Inputs / outputs:** drafts in, findings out. A STOP exit is process success,
  not document acceptance (M6 §5).
- **Consumers:** documentation flow (F4).
- **Failure behavior:** a split seat is an outcome, not an error.
- **Pointers:** M6.

**26. SPINE GATE**
- **Purpose:** cross-chapter consistency — canonical CT ids cited,
  producer/consumer and state agreement, dangling references, count claims (M6 §3 S9).
- **Form/location:** script (`scripts/handbook_spine.py`).
- **Caller/trigger:** handbook builds over the chapter set.
- **Owned decisions and state:** consistency findings. It checks locator
  presence, not that the cited line exists (M6 §3 S9).
- **Inputs / outputs:** the book set in; findings out.
- **Consumers:** handbook delivery (F4).
- **Failure behavior:** findings fail the spine run.
- **Pointers:** M6.

**28. DIRECTIVE GUARD**
- **Purpose:** screen inbound work before Crier custody/launch; not the GitReins commit gate.
- **Form/location:** Crier middleware on the controller transport boundary.
- **Caller/inputs:** every CT-02 directive, authenticated sender and pinned policy digest.
- **Owned state:** policy generation, redacted classification receipt and quarantine reference.
- **Required behavior:** reserved-key/pattern validation precedes classification. Deny,
  timeout, malformed response or classifier outage returns `503 GUARD_UNAVAILABLE`
  or `403 GUARD_BLOCKED`; no custody acknowledgement or launch occurs. Only a
  valid allow verdict for the exact payload digest passes. Retries keep request ID.
- **Configuration:** administrators may change classifier pin/timeout (default 10 s),
  never enable fail-open for production. Unknown policy refuses startup. Offline
  qualification may simulate allow/deny, but cannot dispatch real work.
- **Consumers/proof:** Crier and scheduler receive typed refusal; Crier owns
  guard verdict/latency/outage counters. Replaying a denied digest cannot bypass
  quarantine. M10 §10's fail-open behavior is legacy deviation. [CT-02/03; F9]

**Boundary peers added by the target profile.** The authority owns authenticated
principals, revocations and owner epochs (§1.9.3), outside the controller failure
domain. The controller mutation broker owns fenced Git/board/memory publication
and dispatch capability checks, not task choice. GitHub and GitLab are distinct
external forge peers behind their own native issuers (§1.9.7); an external
inference provider receives only proxy-mediated traffic (CT-20). The model carries
these peers explicitly, with no claim of a measured adapter installation.

### 1.3.6 Evidence — what a human reads

**27. HANDBOOK**
- **Purpose:** the readable system description plus its own deficiency register.
- **Form/location:** build scripts (`scripts/gen_nasa_handbook.py`,
  `scripts/build_book.py`) over the markdown source; rendered PDF.
- **Caller/trigger:** documentation flow (F4) and delivery acceptance (F15/F16 era flows).
- **Owned decisions and state:** the approved target is the authority for
  normative requirements; this book records implementation coverage and
  deviations against it — the source snapshot is evidence, not the requirement.
- **Inputs:** `CT-16` the module status word (UNVERIFIED, see DOC GATE); chapters, model, registers.
- **Outputs:** `CT-18` the approval artifact to the operator (UNVERIFIED — the
  legacy renderer hardcodes `docs/master` and does not select the M*.md
  chapters, M6 §6).
- **Consumers:** the operator; reviewers.
- **Failure behavior:** build and check gates fail the delivery rather than ship a silent defect.
- **Pointers:** M6; contracts `CT-16`, `CT-18`.

## 1.4 Authority and interfaces

**Table 1.A — who decides what.** Every arrow has a stable contract id and a
human-readable meaning; complete versioned schemas live in Part IV.

| Decision area | Authority | Interface / contract | State |
|---|---|---|---|
| Board eligibility and claims | The foreman, against the refreshed board, via boardctl | `CT-14` | UNVERIFIED |
| Repository publication | Landing policy — lander ancestry proof (M3 §2), foreman integration per configured policy | M3 §2 / `CT-14` evidence | UNVERIFIED |
| Passing verdicts | Commit gate (gitreins) plus a separate independent acceptance judgment — never the foreman alone | `CT-12`, `CT-13` | UNVERIFIED |
| Memory writes and shared visibility | The designated supported writer persists worker-correlated entries through the per-Bunker DuckBrain; each worker must have an entry, direct worker credentials are not required | `CT-09`, `CT-15` | MISSING / UNVERIFIED |
| Scheduler settlement | The scheduler reads the correlated reply (`dispatchReplyVerdict`) | `CT-04`, `CT-06` | PARTIAL / PROVEN |
| Lane admission and round issuance | The scheduler | `CT-01`, `CT-02` | UNVERIFIED / PROVEN |
| Credentials (issuance) | Native issuers at their own boundaries — GitHub App (M7); GitLab equivalent via its own adapter; install scripts deliver, they do not authorize | `CT-21`, M7-C1 | UNVERIFIED |
| Effective configuration | The factory manager — desired vs observed vs effective readback; the configuration file is the desired-state authority, edited by the user or an authorized agent; Boardctl carries project work, never configuration authority | CT-24–CT-30; §1.9 (Part IV) | TARGET-UNIMPLEMENTED |
| Replacement placement and rebalance | The factory manager, within the declared eligible host pool; task choice stays with the foreman, lane admission with the scheduler, delivery with Crier, per-host execution with Bunker | target — V2-ARCH-01 | TARGET-UNIMPLEMENTED |

Duplicate-ownership notes: the node worker and the dispatcher are the two
consumers of the same `CT-03` inbox (M2 §6, M11 §6); a missing call in one
script never proves the whole factory lacks the capability — each wire's
producer and consumer are named in Part IV, and absence there is marked, not
inferred.

**Table 1.B — provider/identity responsibility matrix.** GitHub and GitLab are
both explicit; further providers are identified by name when required, never
inferred, and GitHub App semantics are never assumed to apply to GitLab
(V2-ARR-06). Installation/provisioning scripts are the credential and
configuration delivery actors: issuers keep issuance/scoping authority, installers
place references and material in required runtime locations.

| Identity | Issuer | Recipient and execution location | Scope | Secret reference and delivery | Renewal / revocation | Effective readback | Config owner |
|---|---|---|---|---|---|---|---|
| GitHub App installation token | GitHub App (M7 §5) | Controller broker custody, mode 0600 | Exact allowed repository and operations | Protected reference delivery; no native write token at node | Provider expiry/rotation/revoke, scoped denial probe | Allowed/denied repository operation, fingerprint/scope/expiry (§1.9.7) | M7 + §1.9.7 |
| GitLab project access token (target) | Enrolled project-token issuer (§1.9.7) | Controller broker only | Exact project; Developer/write_repository | Protected secret reference, 0600 file | At most one day; rotate, revoke and denial-probe (§1.9.7) | Project identity/scope/expiry and allowed/denied Git operations | Part V + §1.9.7 |
| Per-dispatch capability (target) | Authority/broker; legacy scope minter is coverage only | Bunker runtime file | Exact attempt/repository/operations/fence | 0600 reference delivery; no forge write secret | Online revocation at end/crash; maximum 300 s (§1.9.7) | Independent old-token denial through broker | §1.9.7 / F12 |
| Node bearer token | Control-host provisioning | Node token file | Inference proxy admission only | File at provision time; fail-closed check (M12 §6) | Reprovision; no in-place widening | 401 without a token (measured) | M12 settings |
| Crier agent identity | Registration exchange (`POST /agents`, M1-C1) | Node/foreman agent, inside its Bunker | Send/receive for one agent | Per-agent signature material from provisioning | Deregistration; registry check before reap (M1 §10) | Registration half not established (M1 §6) | Crier/Part V |
| DuckBrain project authorization | Namespace provisioning (F2) | Per-Bunker DuckBrain instance | One project namespace | Namespace credential at install; same logical view as controller (resolved decision 2) | Re-issuance on rebuild | Identity + namespace readback (F2) | Part V (target) |
| Bunker platform authentication | Bunker's own identity/role system | Controller and agent principals at the Bunker boundary | Agent lifecycle RPCs granted; operator management/system configuration denied (V2-FLW-07); `agent:self` restricted to its own Agent service and does not itself grant Bunkerd exec | Delivered by install/provisioning path | Revoke/reissue on compromise; revoked state preserved across restore (F15) | Role/gate mapping per operation; missing finer resource-scope enforcement is named, not assumed | Bunker profile config |
| Upstream inference key | Model provider | Inference proxy, control host | All provider spend | Control-host key file; nodes never see it (M12 §2) | Provider lifecycle | Startup fail-closed check (M12 §11) | M12 settings |

## 1.5 Operating limits, readiness and verification

**Table 1.C — important supported parameters.** Values marked *target* are
specification requirements whose defaults and enforcement are defined in Part V,
not existing settings.

| Parameter | Value / unit | Meaning | Pointer |
|---|---|---|---|
| Total-worker budget per round | workers, configurable (*target*) | The cap on total workers across **all waves** of one foreman round; never replenished at a wave boundary; a cap, not a quota — no unnecessary workers to exhaust it | V2-ARR-07; Part V (target) |
| Per-wave concurrent workers | workers, distinct ceiling | A runtime/platform concurrency ceiling defined separately from the round budget; **no separate fixed wave-count cap exists** — the user decision requires none | V2-ARR-07; V2-SET-06 |
| Retry/resume accounting | policy (*target*) | How failed starts, retries and resumes count against the round budget, so a crashed round cannot silently regain its allowance | V2-ARR-07; Part V (target) |
| Crier lease | 30 s | Inbox lease before redelivery | `CT-03` (PROVEN) |
| Proxy upstream timeout | 300 s | Forwarded inference deadline | M12-C2 |
| Safety reclaim TTL | 24 h | Age gate for cache/job reaping | M8 §3 S1 |
| Hygiene reap grace | 60 min | Orphan home/key grace | M1 §5 |
| DuckBrain namespace sync | 5 min | Scheduler namespace sync cadence | M9 §5 |
| NOOP-PACING | doubling to 8× the floor | No-artifact lane spacing | M9 §3 |
| Board store (measured) | 357 rows / 520 events | Round-13 measurement snapshot | M4 §6 |

**Readiness vocabulary.** These six words are used exactly as defined here
throughout the book:

| State | Meaning |
|---|---|
| **ready** | Observed effective state passes the readiness check for its scope — host/runtime liveness alone is never project readiness; readiness is verified with the actual authenticated, authorized operation or application behavior |
| **unavailable** | A dependency is absent or failing; work that requires it is deferred, and the absence is visible, not silent |
| **deferred** | Waiting on a named unblock trigger — an unmet dependency, capacity, admission pacing — with the trigger recorded |
| **failed** | Attempted and produced a typed failure; the attempt, correlation and evidence are retained |
| **unverified** | Built, transported or claimed, but no independent verification evidence exists; unverified is never promoted to complete by a tool's status word |
| **complete** | Closed with evidence at the right scope — task: board update + publication proof + verdict; wave: foreman entry; round: summary entry + settled return; project: accepted outcome against its criteria. One task, a quiet board, green formatting or successful transport never implies project completion |

**Operator / setup-agent verification checklist.** Before declaring a deployment
usable, verify each item against live state, not configuration intent:

1. The **deployment profile** in use matches the declared profile and its
   prerequisites (§1.6), with effective readback of the installed configuration.
2. **Credential scope**: each installed credential proves its permitted
   operations and its denied out-of-scope operations, without exposing values.
3. **Repository and board freshness**: the working board and the remote copy
   agree after a recorded refresh; drift is named, not assumed away.
4. **Shared-memory readback**: a record written through the Bunker's DuckBrain is
   readable through the controller's logical view (and pending-synchronization
   state is visible when the HTTP path is down).
5. **Launch/return correlation**: a dispatched round's run id and correlation id
   appear on the return leg and in the scheduler's settlement record.
6. **Durable result visibility**: task, wave and round results are visible from
   board, memory and scheduler records — local persistence, Git commit and
   remote synchronization reported as distinct states.
7. **Wave-budget readback** (next paragraph): the round's allowance and remaining
   amount are observable before, during and after the round.

**Wave-budget readback — a separate operational concept.** The round-wide
total-worker allowance and its **remaining amount** must be observable as a
first-class operational quantity: configured value, consumed amount (including
retry/resume accounting per declared policy) and remaining amount, readable at
any point in the round and reported in the round's return. This readback is
distinct from the per-wave parallel-worker capacity, which is a runtime ceiling,
and from any platform concurrency limit; no separate fixed wave-count cap is
required by the user decision (V2-ARR-07). Required progress, worker-budget and
stop-reason metrics are owned and served by their owning modules (F7, F14).

## 1.6 Deployment and topology profiles

All four topologies below are required target profiles (V2-ARCH-02), not measured
support claims. Profile qualification requires the exact release lock and F2
readback; an unqualified combination returns `PROFILE_UNSUPPORTED`. The control
plane is one manager writer plus scheduler, durable Crier, controller DuckBrain,
proxy and broker. The independent authority is outside that failure domain.
A project execution boundary holds the resident adapter, foreman, Hermes workers,
GitReins and local DuckBrain/session store. Bunkerd is a host service, not a
privileged socket exposed to a worker. [CT-23–CT-29]

| Profile | Installation and supervision | Durable volumes and execution composition |
|---|---|---|
| `kubernetes` | Operator-provided namespace and scoped service account; manager reconciles Deployments/StatefulSets through the Kubernetes adapter; non-root UID, read-only rootfs, dropped capabilities, no host network or Docker socket | one ReadWriteOnce PVC per stateful service and per project; manager replicas=1; image-backed Bunker only, with explicit state PVCs; pod restart never activates a binding |
| `compose` | Operator-provided rootless engine and Compose-v2 CLI; manager applies a pinned Compose bundle; restart policy unless-stopped; no privileged containers or host socket in project containers | named local volumes per stateful service/project; persistent-container or image-backed mode with the same explicit data volumes |
| `homelab-vpn` | Standalone user services on pre-enrolled VPN hosts; DNS names from the enrolled VPN identity resolve endpoints; changed address re-probes and creates a binding generation | standalone persistence rules; VPN is transport, not authorization; no assumption that VPN reachability proves forge/memory connectivity |
| `standalone` | User-space pinned binaries and rootless Bunkerd under a pre-enabled persistent user supervisor; restart-on-failure with 5-second delay | local POSIX data directories; persistent-container or image-backed mode; no ephemeral data root |

All profiles use Linux with user namespaces, cgroup-v2 process containment,
fsync-capable local ext4/XFS storage and a supported TLS stack. These are tested
capabilities, not permission to install root packages. Missing host prerequisites
are `HOST_PREREQUISITE_MISSING`; the installer never invokes sudo/apt or enables
privileged pods. Session/evidence/namespace/repository/journal data survive runtime
replacement; caches are separate disposable volumes. Manager state resides at
§1.9.2's root, project state at `$HOME/.local/state/code-factory/projects/<id>`;
Kubernetes/Compose mount these logical roots at `/state/<service-or-project>`.
Shared manager filesystems and two replicas writing one namespace checkout are
rejected. Memory exchange uses separate Git clones, not a shared mutable worktree.

Each service has a distinct certificate identity and HTTPS endpoint named
`authority`, `manager`, `crier`, `scheduler`, `memory`, `proxy`, or `bunker-<host>`
in `deployment.endpoints`. Defaults are manager 8443, authority 8444, Crier 8445,
scheduler 8446, memory 8447, proxy 8448, Bunkerd 8449; all bind loopback/private
interfaces only, with explicit endpoint ports required when not default.
Kubernetes Service DNS and Compose service DNS map those names; standalone/VPN
use operator-declared DNS. HTTP upstreams must sit behind the profile's TLS adapter
and remain loopback-only. No credential crosses plaintext. Certificate rotation
uses F12 and §1.9.3; expired identity disables readiness. Project workloads receive
only their own scoped capabilities; host lifecycle permission stays controller-side.
The inference upstream is an explicitly configured external provider, not the
control-host Hermes session endpoint. [CT-19–CT-23; F2/F12]

**DECISION SLOT A-RELEASE:** the owner selects a tested release lock with exact
OS/runtime/Kubernetes/Compose/Bunkerd/Hermes/Crier/DuckBrain/adapter artifact pins
and digests, or authorizes a qualification-only installation. Default is no
unmeasured release lock and production admission refused. Qualification mode
cannot dispatch project work. This specification supplies topology and protocol
requirements, not invented upstream version measurements. The lock includes
platform architecture, minimum host capabilities, TLS adapter pin, image digest,
volume layout and the §1.9.8 compatibility receipt. No `latest` or floating tag is
accepted. Public-cloud adapters remain lower priority. Terminal Jail is disabled
by default; enabling it requires the guarded-path probe and no fallback.

F2 installs buses before workspaces, verifies restart durability with a sentinel
per declared volume and an authenticated operation per endpoint, then performs
§1.9.4 activation. A supervisor restart starts unready, replays durable state and
re-probes; container-running/pod-ready alone never authorizes work. F13 changes
pins; F8 replaces owners. Profile and execution-mode changes create a new desired
generation and replacement, not an in-place reinterpretation of stored state.

## 1.7 The management service and its contracts

The factory manager's interfaces are specified before its implementation
(V2-ARCH-03):

- **A versioned management HTTP surface, published as OpenAPI**, covering:
  desired/observed state read and update, configuration validation, deployment/profile
  selection, host/Bunker/project inventory, provisioning and reconciliation
  operations, identity/access bindings, Crier/scheduler registration state,
  operation progress/status, typed errors, retries/idempotency, cancellation, and
  result/readback. Long-running operations are represented explicitly — request
  acceptance is never conflated with readiness.
- **Utility/adapter CLI or library contracts** with exact inputs/configuration,
  outputs/status/exit semantics, side effects, permissions and retry behavior.
  Upstream Bunker/Crier APIs and protocol definitions are reused under adapters;
  the design does not require every private script to become a separate HTTP
  service, and agents are never required to manually sequence all tools.
- **One source of truth for schemas**: management API schemas, configuration
  schemas, the state model, flow diagrams and conformance examples are kept
  consistent and versioned together.

The implementation language/HTTP framework remain open; wire types, persistence,
authentication, idempotency and concurrency are fixed in §1.9. CT-24–CT-30 already
exist in Part IV. TARGET-UNIMPLEMENTED means missing implementation evidence, not
permission to select incompatible schemas.

## 1.8 Host-loss replacement

When a host or Bunker deployment fails, orchestration recovers the intended
project runtime on an available eligible node (V2-ARCH-01). The target sequence:

1. **Detect and classify** the failure; persist a recovery incident with affected
   scope, last durable checkpoint and current observation quality (F8).
2. **Fence the old host.** A partitioned old host may still be running —
   unreachability does not prove termination, and replay is not always safe.
   Explicit active-owner/lease/fencing semantics prevent unsafe duplicate
   ownership before any replacement work starts; existing runtime/process state
   is inspected where reachable.
3. **Select an eligible replacement** from the project's declared host pool using
   current health and capacity; reserve the allocation and persist a resumable
   provisioning operation. Kubernetes may restore a pod on its own; that does not
   restore all application-level state or bindings, so the manager performs the
   remaining steps on orchestrated hosts too.
4. **Bootstrap the host/runtime** through the supported provision/install tools:
   prepare the project workspace, repository and **embedded board**, the local
   DuckBrain namespace/data, harness/configuration/credentials and required
   artifacts — restoring or cloning project state per the declared policy (F2).
5. **Verify effective capabilities and readiness** — repository access,
   application readiness, memory paths, runtime permissions, required service
   connectivity — with the failed operation itself where possible.
6. **Update bindings consistently**: Crier registration/routing and scheduler
   target/availability knowledge are reconciled so a later foreman round has a
   usable destination; only verified readiness enables admission.
7. **Resume work** and retain recovery evidence; reconcile late or duplicate
   results from the fenced host under the fencing decision.
8. **Expose shortfalls.** If the declared allocation cannot be satisfied — the
   manager cannot place all desired Bunkers on eligible surviving capacity — it
   preserves the desired request and reports the exact unsatisfied requirements
   and affected scope, with events/metrics under configured policy; it never
   silently changes desired state (V2-SET-08).

Steps carry resumable state, retries/backoff and idempotency; partial-update
recovery and versioned status/events are required, and both controller views
(desired and observed) are verified before the incident closes.

## 1.9 Normative management and distributed-state profile

This section resolves P5-A-01/02/04/05/07–11/14/15/18/19/21–24/33 for
`CF2A-01/P5-A`. It refines CT-01–CT-30 and Part V without claiming installed
support. The requirements below take precedence over the legacy coverage notes
in §1.3. References identify contracts, not proof that their implementations exist.

### 1.9.1 One wire and configuration authority

The canonical transport is Part IV §IV.1's `cf2a.v1` outer envelope. Its exact keys
are `schema_version` (literal `cf2a.v1`), `message_type` (route verb below),
`request_id`, `corr_id`, `sender` (authenticated principal ID), `created_at`
(RFC3339 UTC), and `body`. Body versions are independent: manager bodies use
`factory.v1`; round bodies use `round-admission.v1` and `round-report.v1`.
Every body includes `schema_version`. Unknown keys are refused except inside
`extensions`, an optional JSON object; null is permitted only where stated.
IDs, timestamps and SHA-256 digests use Part IV's lexical rules. JSON is UTF-8,
rejects duplicate keys and non-finite numbers, and uses RFC 8785 canonicalization
for digests. Native Git object IDs carry `{algorithm: sha1|sha256, value: hex}`;
they are not mislabeled SHA-256 content digests.

Part V's whole-document configuration and routes are canonical, not the older
`manager.v1` project-write routes. There is one integer `generation`, initially
zero (no accepted configuration); creation compares zero and writes generation
one. Every later accepted change writes the next integer. Global/project
revision tuples and `desired_generation` are not additional wire fields:
CT-26's desired-generation concept is this same `generation`. A project editor
submits the complete document with only its authorized project changed; the
manager compares all other fields to the current document and refuses cross-scope
changes. A concurrent file/API edit loses the same CAS, never silently merges.

The declared JSON configuration is authoritative intent, but only an accepted
immutable edition is executable. File editing writes a proposal, not the active
edition: the authenticated importer submits the exact bytes through the same
PUT/CAS path. The manager journals the canonical edition, operation and receipt
in one transaction, then materializes `config/generations/<generation>.json` and
atomically renames the active pointer with directory fsync. A crash between these
writes repairs the projection from the journal before serving reads. Manual edits
to a committed edition are `CONFIG_TAMPERED`; they never become a generation.
The manager never overwrites a user's rejected proposal or changes project intent.
An accepted global change marks affected bindings unready, wakes reconciliation,
and pauses new admission; unchanged effective project digests retain readiness.
Running rounds keep their pinned generation unless access is revoked, in which
case F8 control fences them. Revalidation failure remains degraded with a named
editor action; no silent project resubmission occurs. [CT-24–CT-28; Part V §V.0]

**HTTP grammar.** TLS with mutual authentication is mandatory (§1.9.3).
`Accept: application/json` and `X-Request-Id` are required on all requests;
mutations additionally require `Content-Type: application/json` and
`Idempotency-Key` (an ID). These match envelope `request_id` and body
`idempotency_key`; mismatch is `422 INVALID_FIELD`. GET has no body;
`X-Correlation-Id` is required and is echoed. The body of every mutation also
contains `idempotency_key`. No secret values occur in requests or responses.
Mutation deduplication key is `(principal, scope, route-verb, idempotency_key)`;
request digest is compared data, not part of the key. Same key/digest returns the
original status/body; changed digest is `409 IDEMPOTENCY_KEY_REUSED`. The manager
creates operation_id at accepted request commit, never asks a client to invent
an operation before reconcile. Request deadline is 30 seconds; a timeout requires
same-key retry or operation readback, not a fresh mutation.

| Route / message_type | Body fields beyond common version/key | Result data / HTTP status |
|---|---|---|
| `GET /v1/config` / `config.read` | none | `200 State`; no edition: `404 CONFIG_UNAVAILABLE` |
| `PUT /v1/config` / `config.update` | `expected_generation: integer >=0`, `desired: factory.v1 document` | `202 Accepted`; CAS miss: `409 GENERATION_CONFLICT` |
| `POST /v1/validate` / `config.validate` | `desired: document` | `200 {valid: true, desired_digest}`; invalid: `422` |
| `POST /v1/reconcile` / `reconcile` | `generation: integer >=1`, `project_id: ID or null` (null means whole Factory) | `202 Accepted`; stale: `409 GENERATION_NOT_CURRENT` |
| `GET /v1/projects/{id}/state` / `project.read` | none | `200 State` restricted to project; absent: `404 PROJECT_UNKNOWN` |
| `GET /v1/operations/{id}` / `operation.read` | none | `200 Operation`; absent: `404 OPERATION_UNKNOWN` |
| `POST /v1/operations/{id}/cancel` / `operation.cancel` | `expected_state_version: integer >=1` | `202 Operation`; irreversible/race: `409 NOT_CANCELLABLE` or `STATE_CONFLICT` |
| `GET /v1/readiness/{project_id}` / `readiness.read` | none | `200 Readiness` only when ready, otherwise `503 NOT_READY` with Readiness in data |
| `GET /v1/inventory` / `inventory.read` | `kind=hosts / bunkers / projects`, optional `cursor`, `limit` 1..1000, default 100 | `200 {items: Observation[], next_cursor: ID or null}` |
| `GET /v1/events` / `events.read` | optional cursor/limit as above | `200 {items: event.v1[], next_cursor: ID or null}`; expired cursor: `410 CURSOR_EXPIRED` |
| `GET /v1/metrics` / `metrics.read` | none | `200 {samples: Part V §V.0.3 samples[], observed_at}` |
| `PUT /v1/rounds/{id}/progress` / `round.progress` | `sample: Progress` (§1.9.9) | `200 {accepted_seq: integer}` |
| `GET /v1/rounds/{id}/progress` / `round.read` | none | `200 ProgressView`; absent: `404 ROUND_UNKNOWN` |
| `POST /v1/rounds/{id}/control` / `round.control` | F8 control fields | `202 ControlReceipt`; stale fence: `409 STALE_OWNER` |

Every response is the outer envelope with original request/correlation IDs and
manager sender. Its body is `{schema_version: factory.v1, status: ok|accepted|error,
data: typed object or null, error: Error or null}`. `Error` is exactly
`{code: uppercase ASCII ID, message: redacted string, retryable: boolean,
field: JSON-pointer or null, current_generation: integer or null}`. Success has
null error; failure has non-null error. Authentication failures are `401`, role
failures `403`, malformed JSON `400`, unknown version/field `422`, conflicts `409`,
unavailable durability/authority `503`; unknown routes/methods return `404`/`405`.
`503` returns `Retry-After: 5`; clients retry the same identity, not a new effect.

| Type | Exact required members |
|---|---|
| Accepted | `operation_id: ID`, `generation: integer`, `status: accepted` |
| State | `desired: document`, `observed: Observation[]`, `effective: document or null`, `generation: integer`, `status: operation-state`, `operation_id: ID or null` |
| Observation | `scope: ID`, `adapter_id: ID`, `observation_id: ID`, `observed_at: timestamp`, `values: resource object from capability schema`, `quality: fresh / stale / partial / unavailable`, `effective_digest: digest or null` |
| Operation | `operation_id`, `generation`, `project_id: ID or null`, `state`, `state_version: integer`, `plan_digest: digest or null`, `steps: StepResult[]`, `irreversible_started: boolean`, `error: Error or null` |
| Readiness | `project_id`, `profile`, `generation`, `binding_generation: integer`, `owner_fence: Fence`, `ready: boolean`, `probes: Probe[]` |
| Probe | `name: repository / board / memory / runtime / crier / scheduler / application`, `passed: boolean`, `observed_at`, `evidence_ref: digest`, `error: Error or null` |

Optional pagination cursors name a durable sequence and immutable query scope;
responses contain no cross-project entries. Empty lists remain lists. The public
OpenAPI artifact must encode these exact types and the Part V configuration
schema; its digest is pinned in the release manifest. Unknown nested adapter
objects are rejected unless the capability schema names them (§1.9.5).
Legacy project PUT and operation-ID reconcile routes return `410 ROUTE_RETIRED`
with the canonical route, and do not mutate. [CT-24–CT-30; Part IV §IV.1]

### 1.9.2 Durable records and acknowledgement

The reference profile has one manager writer on a local POSIX filesystem under
`$HOME/.local/state/code-factory/manager`; NFS/shared-volume multiwriter is refused.
Configuration and append-log records are Git-backed JSONL, not a live database.
A lifetime exclusive `flock` prevents a second local writer; the independent
fencing authority (§1.9.3) prevents a second host from becoming a writer. Readers
consume immutable snapshots at a committed sequence; transaction processing is
serializable. The manager serves no writes before replay and index validation.

Each transaction is one newline-terminated JSON object:
`{store_version: 1, seq: positive integer, tx_id: ID, previous_hash: digest,
changes: [{table, key, expected_version, version, value}], receipt: object or null,
hash: digest}`. The hash covers canonical bytes excluding `hash`; genesis uses
64 zeroes as previous_hash. Row versions increment by one; expected version zero
means create-only. Keys encode arrays of IDs, not delimiter concatenations.
The writer validates every CAS/constraint against the preceding committed state,
appends a complete transaction and newline, calls fsync on the file (and parent
on creation), and only then acknowledges or sends an outbox message. In-memory
indexes update as a unit after fsync; no observer sees half a transaction.

| Table / unique key | Persisted value, in addition to row version |
|---|---|
| config / generation | immutable canonical document and digest, principal, parent generation |
| current / singleton | accepted generation, store version, controller fence, active snapshot seq |
| operation / operation_id | Operation, request digest, plan, step intents, retry_at, cancel decision |
| dedupe / principal,scope,verb,idempotency_key | request digest, operation id, original HTTP status/body |
| observation / observation_id | Observation; scope/time index |
| reservation / reservation_id | host, project, operation, integer resource vector, expiry, state |
| binding / project_id | prepared generations, participant receipts, active generation, fence |
| incident / incident_id | scope, error, checkpoint, recovery operation, evidence digests |
| outbox / event_id,destination | payload digest, attempts, ack, next retry, terminal state |
| retention / resource_id | inode/object identity, state, holds, pending-sync, backup receipt |
| progress / round_id | greatest durable seq, Progress, received_at, fenced late samples |
| execution-control / control_id | round, action, control_version, state, checkpoint and error |
| backup / backup_id | policy digest, barrier participants, source checkpoints, manifest and state |

Uniqueness covers generation, transaction/event/observation IDs and the compound
keys above. Secondary indexes (operation state/retry time, reservation host/state,
incident scope, outbox next retry) are rebuildable, never independent authorities.
Request admission atomically commits config CAS when applicable, operation,
dedupe receipt and event outbox. Every operation transition commits its state,
step intent/result and corresponding event in one transaction. Capacity decisions
commit reservation and operation together. Binding activation commits active
pointer and activation event together. No external call runs inside a locked
transaction; its durable intent precedes it and readback resolves unknown outcomes.

**Cross-store crash procedure (III.M9.S3 / F8; P5G-02).** This manager
transaction format is not the scheduler's database format. M9 §17 specifies
the scheduler's SQLite WAL/synchronous FULL round, capacity, result, projection,
event and outbox records and the resident foreman's fsynced worker ledger. The
scheduler owns admission and settlement; the foreman owns worker reservation,
launch and results; Crier owns custody; the broker owns protected effect
mediation. Their transactions are local to each authority, not one distributed
transaction. Part IV §IV.1/IV.2 fixes the `cf2a.v1` wire and the
`round-admission.v1`, `worker-result.v1` and `round-report.v1` bodies.

For a reproducible interruption check, evaluate these rows independently, using
the identities and recovery scans in M9 §17 and the terminal mapping in §1.9.10:

| Last durable fact / interruption | Required recovery outcome |
|---|---|
| Admission committed; acknowledgement lost | Replay the original receipt or delivery identity; custody is not execution success. |
| Worker reservation, attempt intent and launch outbox committed; start uncertain | Query the original `launch_id`; observe running, import terminal, or quarantine if unavailable. Only `NEVER_ACCEPTED` permits the same-ID launch. |
| Result, digest, event and result-delivery outbox committed; input acknowledgement lost | Replay the same result/outbox; do not relaunch. A changed result is `RESULT_CONFLICT`. |
| Round result and projections committed; sink effect or receipt uncertain | Scan non-applied projections, read the destination before replay, and adopt only matching evidence; unavailable readback cannot prove success. |
| Report received; evidence, postcheck or settlement interrupted | Resume the same report/revision under §1.9.9, withhold success and follow-up until required proofs exist, and never rerun completed work. |

These are recovery branches, not claims that a distributed transaction commits
across stores. A crash before a local commit cannot justify its acknowledgement;
unknown external effects remain fenced until readback resolves them. Manager
admission dedupe uses the stored request digest and original receipt; changed
bytes are refused. For the actual versioned records, constraints, retry and
expired-claim scans, use M9 §17 rather than a second record schema here.

ch:trace row=P5G-02 spec=docs/handbook/parts/I-system-arrangement.md#1.9.2-durable-records-and-acknowledgement wave=none:serial test=none doc=docs/handbook/parts/I-system-arrangement.md evidence=none:worker-local-handbook-change witness=none:repository-local-spec-only verdict=none commit=none memory=none

A torn final record is quarantined and truncated to the last verified newline
before restart; no acknowledgement can have depended on that uncommitted tail.
A hash/sequence error in a complete record is `STORE_CORRUPT`: stop writes and
restore a verified checkpoint plus intact suffix; never skip a middle record.
Process/power loss must preserve every fsync-acknowledged transition. Host/media
loss recovers only to the newest off-host verified backup (F15), not an invented
zero-loss guarantee. Git commits archive closed log segments; Git alone does not
replace fsync. A checkpoint contains sorted table/key row images, index metadata,
last sequence/hash and SHA-256 manifest. It is fsynced and atomically published;
compaction removes covered segments only after off-host readback and retention
holds permit it. Retained receipts prevent reuse of old idempotency keys; expired
receipt keys return `410 IDEMPOTENCY_EXPIRED`, never run again.

Store migrations use F13: offline copy, verify, atomic active-directory switch;
unknown store_version refuses startup. Required conformance kills the writer at
every append/fsync/rename boundary, races two CAS requests and two reservations,
starts two controllers, corrupts tail and middle records, and proves either the
single acknowledged state or the named fail-closed result. [CT-24–CT-30]

### 1.9.3 Authentication, fencing and mutation mediation

The bootstrap authority is an operator-held offline CA plus an independently
retained authority ledger. Client certificates contain one URI SAN
`urn:factory:principal:<id>` and clientAuth usage. The manager requires that SAN,
a trusted chain, validity and unrevoked serial before decoding a body; `sender`
must match it. A body `principal_id` is forbidden (`UNKNOWN_FIELD`). Server
certificates bind the configured DNS endpoint and serverAuth usage. TLS 1.3 is
required; client certificates last at most 24 hours and renew before 12 hours.
The authority's versioned bindings map principal to role and explicit project IDs;
role names in caller payloads have no effect. Revocation is checked online for
every mutation/admission; authority outage is `503 AUTHORITY_UNAVAILABLE`, not a
cached allow. Reads may use a role snapshot at most 30 seconds old and expose age.

Administrators may change all desired scopes and trust bindings. Project editors
may read/change/reconcile/cancel only their projects. Scheduler and foreman may
read their scopes and request execution control for their rounds; the
foreman may PUT progress only for its live fenced round. They cannot edit
infrastructure. Adapters may read their own steps and resolve only assigned secret
references. Observers read assigned scopes only. No manager API role reads secret
material. Bootstrap/recovery enrollment requires the offline operator key and a
one-use nonce consumed in the authority ledger; it revokes lost admin serials,
records the new binding and proves denial of the old certificate before reopening
writes. Losing the recovery key is an operator recovery stop, not unauthenticated
administrator creation. [CT-24; F2/F12]

A Fence is `{authority_id: ID, project_id: ID, epoch: integer >=1, owner_id: ID}`.
The independent authority serializes epoch allocation using the same durable
transaction rules as §1.9.2 and never reuses an epoch. Its controller record and
per-project records include active owner, monotonic deadline and revocation state.
Lease defaults are 60 seconds with renewal every 20 seconds. Expiry is judged by
the authority's monotonic clock, not caller wall time; authority restart expires
all leases and requires a fresh epoch. UTC timestamps are diagnostic only.
Replacement advances the epoch and marks the previous owner fenced in one
transaction. Failure to contact this authority prevents takeover and writes.

The control-host mutation broker, owned by the manager, is the only custodian of
forge write credentials and canonical board/memory publication credentials.
Bunkers receive read-only forge access and broker capabilities, never a credential
that bypasses fences. The broker serializes each project mutation with epoch
advance: `begin-effect(fence,effect_id,digest)` validates live ownership and logs
an in-flight intent; `finish-effect` records readback. Epoch advance waits for
in-flight external mutations to be resolved or their credentials revoked and
remote denial proven. An unknown in-flight push blocks takeover; lease expiry is
not proof that a remote write stopped. Git provider requests already accepted
must be read back before the new owner is activated. Direct human/provider writes
outside this broker invalidate the managed single-writer guarantee and trigger
`UNMANAGED_WRITER`, readiness false.

Board ref CAS, memory remote commits and Git publication all pass through that
broker. Crier binding changes and scheduler dispatch permission validate the
current fence online; revocation/fence changes serialize with admission grants.
F15 backup capture does not replace this authority: the manager's ordered
cross-store barrier checkpoints M9 scheduler state and M10 Crier custody, while
this independent authority supplies newer fences and revocations during isolated
restore. The restored manager must reconcile those values before a writer or
credential is admitted; an old backup watermark cannot authorize an old owner.
The target procedure is `cf.backup.v1` with `RESTORE_RESULT` and known-row
readback, and remains `TARGET-UNIMPLEMENTED` / `UNVERIFIED` until a live drill.
The Bunker-local memory writer may commit disconnected draft evidence, but marks
it pending authorization; a fenced draft cannot modify the canonical namespace.
M7 §17–17.1 specifies the resource transaction boundaries and deterministic
stale-owner/recovery oracle, including scheduler and Crier.
A stale owner cannot commit canonical state or publish; its late artifacts remain
quarantined. Ordinary GitHub/GitLab push credentials do not validate a Fence and
therefore cannot be delivered to the old host. [CT-10/14/21/28/29; F8]

**DECISION SLOT A-HA:** options are this single-writer manager with an independent
operator-owned authority service, or a separately specified quorum controller.
Default is the former; automatic multi-controller failover is unsupported.
Authority placement must be a different failure domain from the manager and its
backup. A deployment lacking that placement refuses replacement rather than
claiming partition safety. Recovery without a surviving authority follows F15's
revoke-all/new-authority procedure.

### 1.9.3a Authority and broker requests

The authority uses the same authenticated cf2a.v1 wrapper, typed Error and
durability rules, with body version `authority.v1`. Its allowed operations are
`POST /v1/enroll` (offline-key signed bootstrap/recovery nonce only),
`PUT /v1/principals/{id}` (administrator CAS role/scope bindings),
`POST /v1/revocations` (administrator credential reference/serial and reason),
`POST /v1/owners/{project_id}/acquire`, `/renew`, `/advance`,
`POST /v1/effects/begin`, `/finish`, and `GET /v1/owners/{project_id}`.
A reserved project ID `factory-control` names controller ownership. Acquire/advance
requires the controller principal, expected epoch, owner_id, operation_id and
idempotency_key; renew requires the exact Fence. Acquire only succeeds when no
owner is active, advance also requires completed prior-effect readback or provider
revocation proof. Success returns Fence, authority_seq and lease_remaining_s;
conflict is `STALE_OWNER`, unknown effect is `EFFECT_UNRESOLVED`. Renew does not
advance the epoch. Begin requires Fence, effect_id, input_digest, resource_ref and
credential_ref; success returns a durable effect receipt. Finish requires that
receipt and observed_result_digest; matching retry replays, changed digest is
`EFFECT_CONFLICT`. Only the enrolled broker may begin/finish effects.

The authority records principals by ID, certificate serials by issuer/serial,
nonces by digest, owners by project, effects by effect_id, and revocations by
credential reference. Rows carry version, sequence and a canonical payload digest
under §1.9.2's transaction format. Nonce consumption and first-admin enrollment
are one transaction. Credential revocation and capability denial are one authority
transition; remote-provider revocation remains pending until independently probed.
Online validation returns `{allowed: boolean, authority_seq, fence, reason}` and
never permits a cached allow after connection loss.

The broker accepts `POST /v1/effects` with body version `broker.v1`, capability
reference supplied in `Authorization: Bearer` (never JSON), plus effect_id,
owner_fence, repository/namespace reference, operation enum
`git_publish|board_cas|memory_sync`, input_digest and the corresponding schema from
§1.9.6/§1.9.7/F3. It authenticates the scoped Bunker certificate as well as the
capability. It returns `202` with effect_id/state or replays the original receipt;
`GET /v1/effects/{id}` returns state `pending|applied|refused|unknown`, result digest
or null, and typed error or null. Provider credentials never appear in either
response. It starts an external call only after authority begin and completes the
effect only after remote readback. F12 owns issuance/revocation, F5 owns publication,
F1 owns board mutations and F3 owns memory sync; these endpoints introduce no
uncontracted execution flow. [CT-10/14/15/21/29]

### 1.9.4 Operation transitions and binding activation

The transition relation is closed: `accepted → planned|degraded|failed|cancelled`;
`planned → applying|degraded|failed|cancelled`; `applying → converged|degraded|failed`;
`degraded → planned|applying|converged|failed|cancelled`. Degraded-to-converged
requires readback of all original effects, not skipping them. Degraded-to-cancelled
requires no irreversible intent; degraded-to-applying requires a valid saved plan
and renewed reservation. `converged`, `failed`, `cancelled` are terminal.
A retry of a terminal operation's idempotency key returns its original result;
a deliberate retry creates a new operation/key linked by `retry_of` in its plan.
It first discovers prior effects and never assumes failed means no effect.

Cancellation CAS and first irreversible-intent CAS compete on state_version in
the same journal lock. Irreversible means any credential issue/revoke, resource
create/delete, external config apply, publication, or binding activation; it is
recorded BEFORE dispatching that effect. Validate, plan and unused reservations
are reversible. If cancel wins, pending steps never execute and reservations
release. If intent wins, cancellation returns `NOT_CANCELLABLE`, even when the
call later times out. Readback and compensating reconciliation continue.
Retryable outage uses delays 5, 10, 20, 40, 80, 160, then 300 seconds capped;
ten failed attempts leave degraded awaiting operator retry, without erasing intent.

Binding activation is a prepare/commit protocol, not two unrelated updates.
The manager first marks the project unavailable and closes dispatch grants, drains
or fences old rounds (F8), allocates generation N+1 and probes the candidate.
It sends Crier and scheduler `binding.prepare.v1` containing project, generation,
fence, candidate endpoint, readiness digest and operation ID. Each durably stores
a non-routable candidate and returns `{participant_id, operation_id,
binding_generation, prepared_digest}`. Same tuple/digest replays; changed digest
is `BINDING_CONFLICT`. Only after both receipts and fresh probes exist does the
manager CAS its active pointer to N+1, fsync it, and emit `binding.commit.v1`.
Participant commit acknowledgements contain the same tuple and `active_digest`.
Admission stays false until both readbacks match the pointer.

On every dispatch the scheduler obtains a one-use grant from the manager binding
authority naming round, generation, fence, destination and expiry (30 seconds).
Crier validates/consumes that grant against the active pointer before custody;
the resident adapter revalidates fence/generation before launch. Authority outage
refuses launch. A grant is not a reusable offline lease. A crash with only Crier
prepared leaves no active candidate; a crash after pointer commit repairs both
participants from that pointer. Aborting before pointer commit removes candidates;
after commit recovery rolls forward or fences and creates a later generation,
never rolls the pointer backward. Thus N+1 accepted by Crier with scheduler timeout
admits neither generation until readbacks agree. [CT-26/28/29; F2/F8]

### 1.9.5 Adapter protocol and deterministic placement

Adapters run on the controller as pinned executables, not shell strings. Invocation
is `adapter --protocol factory-adapter.v1 --verb <verb>` with one UTF-8 JSON object
on stdin and one JSON result on stdout, bounded to 1 MiB; stderr is redacted
operator diagnostics. Verbs are `capabilities`, `validate`, `plan`, `reserve`,
`apply`, `discover`, `readback`, `release`. Exit 0 means a valid result, not a
successful effect; exit 2 means invalid input, exit 3 dependency unavailable, other
exit/signal/timeout means unknown outcome. Default call timeout is 60 seconds;
long steps use a returned effect handle and discover, never an unbounded process.

Requests contain `schema_version`, `verb`, `adapter_id`, `operation_id`, `step_id`,
`corr_id`, `generation`, `owner_fence`, `effect_id`, `input`, `input_digest` and
`reservation_id` (null before reserve). Capabilities uses null operation/step/fence
and empty input. Its result is `{protocol: factory-adapter.v1, adapter_id,
version_digest, verbs: enum[], resource_schemas: map of JSON Schemas,
idempotent_resources: string[], discovery_resources: string[]}`. Every input and
observed resource object validates against its pinned schema; unknown capabilities
refuse planning. Results are StepResult:
`{adapter_id, operation_id, step_id, effect_id, attempt: integer >=1,
status: planned|reserved|applied|absent|unknown|refused|released|observed,
output: schema-validated object, effective_digest: digest or null,
observed_at, error: Error or null}`. Non-success requires Error.

Plans contain ordered steps `{step_id, adapter_id, resource_type, input,
depends_on: ID[], irreversible: boolean, compensation: step_id or null}`.
The manager topologically orders ready steps by bytewise step_id, rejects cycles,
and hashes canonical plan bytes. Effect identity is SHA-256 of canonical
`[operation_id,step_id]`; retries change attempt, not effect_id or input_digest.
Before apply, the broker durably reserves that effect identity. The adapter must
use native request deduplication or create a resource with that exact unique name
and discover it by identity plus input digest. Create/credential issue without
such a discovery mechanism is `CAPABILITY_UNSUPPORTED`, not retryable creation.
On timeout, discover/readback runs first: matching effect returns the original
result, proven absence permits same-effect retry, unknown blocks progress.
Compensation is a separately journaled effect with its own identity and fence;
release never deletes a resource merely because reserve expired. [CT-23/25/26]

Capacity and requirements have exactly `cpu_millis`, `memory_bytes`, `disk_bytes`
(nonnegative integers; requirements positive), `capabilities` (sorted unique
strings), and `network_refs` (sorted endpoint IDs). No overcommit is allowed.
Free capacity is componentwise min(declared limit, measured total) minus observed
non-Factory usage minus all committed live allocations and unexpired reservations;
negative results clamp to zero. Each vector uses one observation at most 30 seconds
old with all required probes passing; absent units or partial observations exclude
the host. Allocation snapshots generation, observations and reservation versions.
Existing healthy allocations remain; missing replica ordinals are filled in order,
sorting eligible hosts by bytewise host ID and choosing first fit. Each choice
subtracts its requirement vector before the next. Reservation CAS rechecks all
versions under the manager journal lock; conflict restarts the calculation.
Reservations expire after 120 seconds unless renewed every 40 seconds; entered
irreversible effects remain allocated until discovery proves absence/deletion.
Shortfall reports unplaced replica count plus per-resource requested/allocated
vectors, never sums unlike units. Rebalance occurs only on desired pool/profile
change or failed readiness, not because a lexically earlier host reappeared.
[CT-27; Part V hosts/bunkers requirements; F2]

### 1.9.6 Canonical board, prompt and round identities

CT-05 is solely foreman → worker `worker-brief.v1` (Part IV §IV.1). Its `brief_ref`
and `brief_digest` refer to the exact immutable `cf.brief-input.v1` JCS bytes defined in
Part IV §IV.2 and M2 §15.1; they never refer to a reconstructed prompt or envelope.
The Factory foreman/manager owns the snapshot, CAS resolution, digest verification and
replay. Seeded lane prompt/skill digests are a CT-01 configuration extension
`extensions.lane_seed: {prompt_digest, skills: [{name, digest}]}`; they are not
CT-05. CT-02 uses only `round-admission.v1`, never `round-request.v1`.
Its required fields are Part IV's `round_id, run_id, corr_id, task_scope,
total_budget, config_generation`; `task_scope` is a nonempty unique task-ID array,
a fixed authorization ceiling. Later waves may claim newly eligible tasks in that
array, not newly created/out-of-scope tasks. Initiative admission expands its
membership into that array at the admitted board revision. Extensions carry
`project_id, lane, board_revision, binding_generation, owner_fence, lane_seed`;
config_generation is the single accepted generation (§1.9.1).

Legacy translation requires a scheduler lookup: `run_id` and `corr_id` preserve
identity; lane resolves project and seed; board resolves the canonical repository
and admitted revision; decoded text_b64 must match the configured prompt digest.
The persisted admission supplies round_id, authorized task_scope, budget and
generation. No adapter guesses missing authority from free text; missing lookup
returns `LEGACY_ADMISSION_UNRESOLVED`. Legacy `ok` must agree with typed result
status or the result is `RESULT_CONFLICT`. [CT-01/02/04/05]

The board broker publishes a single Git commit containing both appended task row
and event plus `.coding-hermes/board/transactions/<operation_id>.json`:
`{schema_version: board-transaction.v1, operation_id, parent_revision,
task_id, claim_id, claim_generation, tasks_sha256, events_sha256}`. The two hashes
cover complete resulting files. The canonical ref is the project's configured
`refs/heads/<destination>`; the broker uses Git receive-pack compare-old-OID to
new-OID ref update. The candidate has the advertised old OID as parent, cannot
force-rewrite history, and the server rejects if old OID changed. A local lock
alone is insufficient. A rejected CAS leaves canonical state unchanged; staged
local files are not readable committed state. A reader encountering a published
commit with absent/mismatched marker returns `PARTIAL_WRITE` and disables
scheduling for that project until repair from a verified parent, never half-reads.

Claims use CT-10's `claimant_id, claim_id, lease_expires_at, claim_generation`;
M4's owner_id/lease_until/fence_token are legacy aliases, not alternate keys.
Stale revision is `CLAIM_CONFLICT`, stale owner is `STALE_OWNER`; CONFLICT/FENCED
are translated only at the legacy boundary. Claim generation increments under
remote ref CAS and also checks the project Fence. The broker judges lease expiry
using its authority clock; default lease is 120 seconds, renewed every 40 seconds.
The foreman owns claim retries (fetch/revalidate dependencies and authorization,
then new CAS, at most five conflicts before named deferral). Scheduler owns its
pre-admission and post-result refresh only; it does not synchronize a foreman's
unpublished task changes. A successful CAS wakes scheduler eligibility at the new
revision. A lost acknowledgement is resolved by operation marker lookup before
any append. [CT-10/14; F1/F11]

### 1.9.7 Forge capability lifecycle and publication

GitHub installation tokens and GitLab project access tokens are broker-side only
in the target; node-delivered write tokens in M7/M11 are legacy coverage. GitLab
uses a project access token issued by the GitLab project-token API for the exact
numeric project ID, Developer access and `write_repository` scope; the broker
supports Git receive-pack publication, not privileged project administration.
A separate least-scope `read_api` credential may verify protected-ref policy;
no group or personal token reaches a Bunker. The enrollment operator supplies a
protected issuer reference authorized to create/revoke project tokens; the adapter
never grants itself issuer authority. Issue uses
`POST /api/v4/projects/{id}/access_tokens`, listing/discovery uses
`GET /api/v4/projects/{id}/access_tokens`, revoke uses
`DELETE /api/v4/projects/{id}/access_tokens/{token_id}`. Unique token name is the
effect_id; discovery of an issued token whose secret response was lost revokes it
before creating a separately recorded replacement effect. Required expiry is
at most one day (UTC provider date semantics); rotation begins twelve hours
before expiry, verifies same-project push in a disposable verification ref and
denial against an ungranted project, then revokes the old token and proves denial.
Unsupported API/tier/scope/branch policy returns `PROVIDER_CAPABILITY_UNSUPPORTED`.
The adapter records token ID, fingerprint, scope and provider expiry, never value.
Native API basis: [GitLab project access tokens API](https://docs.gitlab.com/api/project_access_tokens/),
create/list/revoke operations; Developer is access_level 30. Enrollment checks that
the configured instance supports these operations and the required token scope.
[CT-21; F12]

**DECISION SLOT A-GITLAB:** the operator selects/enrolls the GitLab instance,
project and issuer account; default is no enrollment and admission refused for
GitLab projects. This is not permission to use a personal account silently.

Per-dispatch authority is an opaque 256-bit broker capability, stored only as a
hash at the authority and delivered in a mode-0600 runtime file (not argv/log).
It binds project/repository, round/attempt, allowed operations, owner fence and
expiry: minimum of parent credential expiry, round deadline and now+300 seconds.
Refresh requires the live attempt and fence and never widens the parent scope.
Completion/cancel atomically marks the capability revoked before settlement;
a 20-second authority sweeper revokes tokens for non-live attempts. A stolen token
fails online authorization immediately after revocation and always at expiry,
regardless of whether the process/environment survived. A denial probe through
the broker verifies `401 CAPABILITY_REVOKED` using the old reference; cleanup alone
is not proof. If revocation/readback is unavailable, settlement remains pending
and no replacement publication is authorized. [CT-21/29; F8/F12]

Publication policy requires explicit destination ref (default `refs/heads/main`)
and mode `merge`, `fast-forward`, `squash`, or `rebase`. Broker CAS uses the last
verified remote base. A publication receipt contains candidate commit/tree,
base, mode, destination ref, accepted commit/tree, gate-run IDs and remote readback.
Merge/fast-forward require candidate ancestry in the accepted commit; squash
requires the exact tested squash tree; rebase records ordered old→new commit
mapping and tests the resulting tree. All modes require accepted commit ancestry
in the read-back destination and tree equality with the integration gate's tree.
Any base, tree, criteria, dependency-lock or gate-config digest change invalidates
ALL required integrated-tree gates; no path-based exemption is assumed.
The broker tests a detached candidate, publishes by CAS, and repeats integration
and gates after a CAS conflict. PR is an approval transport, not a fifth proof
mode; provider automatic merges that cannot bind the exact tested tree are refused.
[CT-12/13/14; F5]

### 1.9.8 Retention and compatibility

Every runtime workspace, evidence object, pending memory commit and backup enters
the retention index before use. A hold is `{hold_id, owner, reason,
resource_version, expires_at: timestamp or null}`; evidence and pending-sync holds
have no automatic expiry. Publishing evidence first acquires its hold, then writes
the reference. Cleanup CAS changes a resource from `live` to `deleting` only when
it has no live owner/hold, no pending sync, a verified required backup receipt,
TTL elapsed and no protected-path match. New acquisitions require `live`; they
cannot race a tombstone. The local resource agent locks the path, validates its
recorded device/inode (no symlink traversal), renames it into same-filesystem
quarantine and fsyncs before unlink. Failure retains the tombstone for retry;
a restored path with a new inode is a different resource. Unregistered/unknown
resources are retained. Publication/sync/worker startup all use this index;
a reaper without this integration is unsupported. [F6; CT-14/15/29]

A release lock contains every component artifact URL/SHA-256, platform, protocol
versions, config/store schema versions, migration digest and acceptance receipt.
Allowed target wire set is cf2a.v1, factory.v1, factory-adapter.v1,
round-admission.v1, worker-brief.v1, worker-result.v1, round-report.v1,
board-transaction.v1, progress.v1, authority.v1, broker.v1, binding.prepare.v1,
binding.commit.v1, execution-control.v1, execution-checkpoint.v1, fanout.v1,
cf.backup.v1 and store_version 1. Components of different
binary versions may coexist ONLY when they advertise this exact set for their
roles and pass the same contract fixtures; unknown major schemas fail closed.
An upgrade never reinterprets an in-flight envelope. F13 drains old rounds before
changing a wire/store version; queued unsupported versions remain quarantined.
The order is authority/broker, manager store/runtime, Crier custody, memory/board
adapters, Bunker daemon/client, Hermes/runtime, scheduler admission last.
Backward-compatible binary replacement permits rollback before new writes;
store changes use copy/verify/switch, retain the old image, and prohibit old-binary
restart after new-schema writes. Recovery then either rolls forward with the
pinned repair migration or uses F15 isolated restore and explicit loss accounting.
A release missing a migration/recovery recipe is `UPGRADE_UNSUPPORTED`.
[CT-17/23/24; F13]

### 1.9.9 Live round readout and settlement

The resident foreman journals `progress.v1` before every budget reservation,
worker-start, completion, wave boundary and stop; it also emits a heartbeat every
10 seconds. Progress contains `schema_version, project_id, round_id, run_id,
corr_id, owner_fence, seq, process_instance_id, observed_at, allowance, consumed,
reserved, remaining, waves, stop_reason, checkpoint_digest`. Counts are integers
>=0, allowance is fixed at admission, and remaining = allowance − consumed −
reserved. `waves` is an array of `{wave_id, state: planned|running|complete|blocked,
attempt_ids: ID[]}`; stop_reason is null while running, else
`no_useful_work|budget_exhausted|cancelled|paused|deadline|dependency_unavailable|failed`.
Seq survives restart; process_instance_id changes on restart, never round identity.
The start/consume policy follows the pinned Part V retry policy, never resets.

The authenticated Bunker writer PUTs progress to §1.9.1; manager checks identity,
fence, monotonic seq and budget invariants and fsyncs before ack. Same seq/digest
replays; changed digest is `PROGRESS_CONFLICT`; lower seq is `STALE_OBSERVATION`.
Disconnected samples queue locally by seq and flush in order after reconnect;
no sampled success substitutes for final evidence. GET returns
`{sample: Progress or null, received_at: timestamp or null, age_s: integer or null,
quality: fresh|stale|unavailable}`. Age uses controller receive time; fresh requires
age <=30 seconds and a live fence; otherwise stale, or unavailable if no sample.
Operators/observers see only their authorized projects. The same readout is
available locally from the resident journal with source/freshness explicit;
controller outage is not a fabricated zero. Foreman owns budget/wave facts,
manager owns ingestion age/sequence gaps, scheduler owns settlement counters.
Logs such as proxy JSONL are not served metric series. [CT-30; F7/F14]

Scheduler settlement has its own durable states: `received → awaiting_evidence →
postcheck_pending → settled_success|settled_failure|settled_partial|unknown`.
The immutable execution verdict is separate from final acceptance. A locally
committed but controller-inaccessible memory reference leaves awaiting_evidence;
local durability permits continued work, not controller acceptance. Crier custody
of the report alone is insufficient. The scheduler retries digest-addressed reads
every 30 seconds for 24 hours, then records unknown and an incident. Arrival after
that deadline creates an auditable reconciliation revision, never overwrites the
old settlement. Evidence loss is unverified, not success.

After all memory/evidence digests are verified in controller custody, required
refresh/verifier hooks run keyed by `(round_id,report_digest,hook_id,config_digest)`.
Hook failure leaves postcheck_pending with typed error and no success counter,
dependency wakeup or successful-lane follow-up. It retries read-only hooks at
30 seconds up to five times, then settles failure with reason `POSTCHECK_FAILED`.
An authorized retry appends a new settlement revision for the same report and
rechecks evidence; already published work is not executed again. Final success
requires passing execution verdict, evidence readback, capability revocation and
all required hooks. Failure/partial execution remains failure/partial even if
hooks pass. The scheduler increments final counters and issues follow-up only
once per final revision; correction events identify superseded revisions.
[CT-06/06R; F1/F3/F11]

### 1.9.10 Integrated authority, activation and terminal-state contracts (P6-01/08/10/12)

The following operations complete the peer boundaries summarized in §1.9.3a and §1.9.4.
They use the `cf2a.v1` envelope, mTLS principal, signed Crier profile where applicable,
`ResponseBody` and typed Error from §1.9.1. Each mutation body carries `schema_version`,
`idempotency_key` and `request_digest`; each route below adds exactly its listed fields.
A same-key/digest retry returns the original receipt, changed bytes return
`IDEMPOTENCY_KEY_REUSED`, and a lost reply is resolved by the named GET before any new
effect. Secret values never occur in JSON, argv, events or logs. All journal commits and
outbox insertion precede acknowledgement or external effects.

**Certificate and capability lifecycle.** The authority owns these routes. `expires_at`
is UTC for display; monotonic remaining lifetime governs enforcement. A certificate
renewal increments registration_generation exactly once, permits at most the configured
60-second overlap for in-flight reads, and revokes the old serial for mutations immediately.
A failed live revocation check is `AUTHORITY_UNAVAILABLE`, never a cached allow.

|| Route / body version | Additional request fields | Durable result and errors |
||---|---|---|
|| `POST /v1/certificates/renew` / `authority.v1` | registration_id, expected_generation, csr_der, public_key, requested_expires_at | `{registration_id,registration_generation,certificate_der,expires_at,credential_refs,authority_seq}`; wrong generation `REGISTRATION_CONFLICT`, weak/replayed key `UNAUTHORIZED` |
|| `GET /v1/registrations/{id}` | none | registration metadata, certificate serials, generation, revocation state and assigned credential references; never private material |
|| `POST /v1/capabilities/issue` / `authority.v1` | capability_id, subject_id, project_id, operations:ID[1..32], resource_refs:EvidenceRef[1..128], owner_fence, expires_at | `{capability_id,capability_ref,token_sha256,scope,expires_at,transfer_id}`; scope widening `FORBIDDEN`, lifetime above parent `CAPABILITY_EXPIRY_INVALID` |
|| `GET /v1/capabilities/{id}` | none | `issued|active|revoked|expired`, scope, token hash, expiry and current authority sequence |
|| `POST /v1/capabilities/{id}/revoke` / `authority.v1` | expected_authority_seq, reason | `200 {state:revoked,authority_seq}` only after online denial readback; otherwise `503 REVOCATION_UNVERIFIED` |
|| `POST /v1/capabilities/exchange` / `authority.v1` | capability_ref, operation, node_id, registration_generation | metadata plus one-use `transfer_id`; the secret itself follows only the sealed-transfer protocol below |

The Gateway consumes session/inference capabilities only. CT-08 session delivery and
CT-19/CT-20 inference are its complete authority: it may validate a capability, create a
durable session/turn and return usage or typed inference errors. It cannot enroll a Bunker,
issue or consume a dispatch grant, allocate execution identity, launch a worker, acknowledge
Crier custody, infer a worker verdict, or settle a round. A gateway-observed reply remains
evidence to be returned through Crier, never Scheduler settlement.

**One-use dispatch grant.** Scheduler requests `POST /v1/dispatch-grants` on the manager
with body version `dispatch-grant.v1` and fields `grant_id`, `project_id`, `round_id`,
`run_id`, `corr_id`, `binding_generation`, `owner_fence`, `destination:{agent_id,
endpoint_digest}`, `admission_digest`, and `requested_expiry_s:integer[1,30]`. The manager
validates the active pointer, fence, admission digest and destination, then stores
`issued` with token hash and expiry before returning `{grant_id,grant_ref,token_sha256,
expires_at,active_digest,transfer_id}`. The token is delivered only through the control
broker's sealed-descriptor transfer to the Scheduler UID. Scheduler presents it to Crier
in the authorization header; neither the token nor its file path enters the CT-02 body.

Before custody, Crier calls `POST /v1/dispatch-grants/consume` with the same body version
and `grant_id`, `token_sha256`, `delivery_id`, `round_id`, `binding_generation`,
`active_digest`, and its own `operation_id`. The manager compares the token hash and all
bound fields, then atomically transitions `issued → consumed` and inserts Crier's delivery
outbox marker. Success returns `{state:consumed,grant_id,delivery_id,authority_seq}`;
mismatch is `GRANT_CONFLICT`, replay with a different delivery is `GRANT_REUSED`, expiry is
`GRANT_EXPIRED`, and authority/store outage is `503 GRANT_UNAVAILABLE` with no custody.
An identical consume replays the original delivery receipt. `GET /v1/dispatch-grants/{id}`
returns `issued|consumed|expired|revoked`, the bound delivery ID and digests, and resolves
a lost acknowledgement without issuing a second grant. Crier delivery failure after consume
leaves the grant consumed and the round in return/reconciliation, never a second launch.

**Participant binding (the normative III.M9.S2/S3 / F2/F11 contract).** The Factory
manager is the sole activation authority. Crier and Scheduler are participants: each
owns its own durable candidate, prepare receipt and commit/active receipt, but neither
may declare the factory binding active or admit work from a local observation. They expose
the same routes under their enrolled service origins: `POST /v1/factory/bindings/prepare`,
`POST /v1/factory/bindings/commit`, and `GET /v1/factory/bindings/{generation}`.
Their principal role permits only their own `participant_id` and assigned project.

The binding identity is the tuple
`(project_id,binding_generation,owner_fence,prepared_digest,active_digest)`;
`binding_generation` and `owner_fence` fence old routes, `prepared_digest` hashes the
canonical candidate/readiness record, and `active_digest` hashes the manager's committed
pointer plus that candidate. `binding.prepare.v1` contains `operation_id`, `project_id`,
`binding_generation`, `owner_fence`, `participant_id`,
`candidate_endpoint:{url,tls_spki}`, `readiness_ref`, `readiness_digest`, and
`idempotency_key`. The participant verifies a fresh authenticated probe, fsyncs a
non-routable candidate and its receipt, then returns
`{participant_id,operation_id,binding_generation,prepared_digest,state:prepared}`.
The manager retains both participant receipts and the probe evidence in its operation
journal. Same tuple and digest replay the original receipt; a changed tuple or digest
is `BINDING_CONFLICT` and cannot overwrite the candidate.

Only after both durable prepare receipts and repeated authenticated probes match does
the manager CAS its active pointer from N to N+1, fsync the pointer and journal, and
then emit `binding.commit.v1`. The commit contains
`operation_id`, `project_id`, `binding_generation`, `owner_fence`, `participant_id`,
`prepared_digest`, `active_digest`, `committed_at`, and `idempotency_key`. Each participant
must atomically activate only its matching candidate, fsync its active pointer and receipt,
and return `{participant_id,binding_generation,owner_fence,active_digest,state:active}`.
GET returns `candidate|active|superseded|absent`, the tuple digests, and durable
operation ID. A participant acknowledgement is not proof that the other participant
committed.

The active pointer CAS is the commit record: it is the manager's decision that N+1 is the
only candidate eligible for readback. Recovery always reads that pointer and operation
journal. If the manager has committed but one participant's acknowledgement is missing,
it replays the same commit tuple until both participant readbacks match; it never rolls
back to N. If the pointer CAS did not commit, recovery may delete only non-routable
candidates. A readback with a different generation, fence or digest is `BINDING_NOT_ACTIVE`
and blocks every new grant. Two different candidates for the same idempotency key are
`BINDING_CONFLICT`; duplicate identical prepare/commit calls replay the original receipt.
No timeout is interpreted as a negative acknowledgement or as permission to issue N+2.

| Durable observation after interruption | Manager repair action | Dispatch result |
|---|---|---|
| no prepare receipt, or only one participant prepared | retain operation; retry missing prepare or abort the uncommitted candidate | no active replacement; old route remains fenced/unavailable and no new grant |
| both prepare receipts, pointer CAS absent | verify tuple, then commit pointer or abort candidates; never activate locally | no dispatch until a single pointer decision is durable |
| pointer CAS committed; one participant is `prepared`/receipt missing | read pointer, replay the same `binding.commit.v1`, then verify both readbacks | `BINDING_NOT_ACTIVE` / fail closed until both match |
| both participants active with exact tuple and digest | record commit receipts and close operation | one dispatchable binding: the exact pointer tuple only |
| duplicate identical request | return the durable receipt without another effect | unchanged; at most one active binding |
| mismatched generation, fence, prepared or active digest | retain evidence, return `BINDING_CONFLICT` or `BINDING_NOT_ACTIVE` as applicable | no grant, no custody, no launch |

This table is independently checkable from the manager journal, the pointer file and both
participant GET readbacks. Admission is therefore the conjunction
`manager_pointer == participant_Crier_active == participant_Scheduler_active`, with exact
`generation`, `fence`, `prepared_digest` and `active_digest` equality; otherwise it is
false. [CT-26/28/29; F2/F11; III.M9.S2/S3]

**Protected secret resolution and Bunker transfer.** The control broker socket is
`/run/factory/broker/secrets.sock`, owned by the broker service UID, mode 0600. The node
broker socket is `/run/factory/node-broker/secrets.sock`, owned by the node-broker UID,
mode 0600. Neither socket is mounted into a worker namespace. A local request is one JCS
line, at most 65536 bytes: `{schema_version:"secret-resolve.v1",request_id,corr_id,
credential_ref,operation,idempotency_key}`. SO_PEERCRED supplies the principal; a caller
principal field is forbidden. The broker validates the online assigned-reference list,
operation, registration generation and revocation state. Success returns metadata
`{schema_version,request_id,credential_ref,fingerprint,expires_at,scope}` plus exactly one
SCM_RIGHTS descriptor for a sealed memfd. The descriptor carries `F_SEAL_SEAL`,
`F_SEAL_SHRINK`, `F_SEAL_GROW` and `F_SEAL_WRITE`; JSON contains no secret bytes. Errors
are `UNAUTHORIZED`, `CAPABILITY_REVOKED`, `REFERENCE_UNKNOWN` and
`RESOLVER_UNAVAILABLE`, with no descriptor on failure.

A cross-host installation starts with `POST /v1/secret-transfers` on the control broker,
body version `secret-transfer.v1`, fields `transfer_id`, `credential_ref`, `node_id`,
`registration_generation`, `operation`, `expires_at`, and `idempotency_key`. The broker
stores one assigned one-use transfer and returns only its metadata. The enrolled node
broker claims that transfer over mutually authenticated TLS to
`POST /v1/secret-transfers/{id}/claim`, including `transfer_id`, `node_id`,
`registration_generation`, `request_digest`, and `idempotency_key`. The response travels
inside the authenticated encrypted channel, is placed directly into a sealed memfd by the
node broker, and is acknowledged as `{transfer_id,state:delivered,fingerprint,expires_at}`
without contents. Identical claim replays metadata and offers the same still-open local
descriptor; after descriptor loss or process restart, a consumed transfer returns
`TRANSFER_CONSUMED` and requires an explicitly linked replacement transfer. M1 then stages
the descriptor atomically with owner-only permissions and readback. Fanout creates one
independently scoped transfer per consumer; no broadcast descriptor or shared environment
variable exists.

The signed `factory-adapter-capabilities.v1` artifact named by Part V is the required
resource registry. It contains `schema_version`, `registry_digest`, `release_lock_digest`,
and `adapters:[{adapter_id,version_digest,resources}]`. Each resource entry is
`{resource_type,json_schema,idempotent_verbs,discovery_verbs}`. Required resource types
are `host`, `bunker`, `credential`, `endpoint`, `binding`, `release` and `runtime`.
Their schemas respectively validate Capacity/host identity; Bunker image/count/profile;
CredentialRef and revocation state; Endpoint and probe; binding tuple and generation;
SignedArtifact and qualification receipt; execution mode, supervisor/harness digests,
UID/mount/cgroup/network effective state. An adapter result or Observation that does not
validate against the pinned resource schema is `CAPABILITY_SCHEMA_MISMATCH`; an absent
resource type is `CAPABILITY_UNSUPPORTED`, not a manager-side improvised object.

**One terminal reduction and settlement mapping.** Execution outcome, transport,
projection and settlement remain separate records. The following table is exhaustive for
the named failure branches; each branch has one accounting effect and no duplicate launch.

|| Observed branch | Execution/round outcome and required disposition |
||---|---|
|| input refused or native launcher proves `NEVER_ACCEPTED` | attempt `fail` with phase `launch`; one proven never-started reservation refund; no commit or board close |
|| native acceptance unknown, process existence unknown, or control dies before start acknowledgement | attempt `unknown`/`START_UNKNOWN`; reservation stays held, execution quarantined, no retry until native readback and fence |
|| worker exits 0 without a schema-valid durable result | `UNKNOWN_RESULT`, round `unknown`; exit status is not a third verdict and not success |
|| worker dies after result and evidence are fsynced | adopt the original result; replay outbox only; no native relaunch |
|| worker/control dies after native start but before durable evidence | `unknown`, quarantine and reconcile native/board/Git/memory side effects before any new attempt |
|| definitive execution or required gate failure | attempt `fail`; same-worker correction owns the task until terminal disposition or allowance/deadline exhaustion |
|| execution passes and publication definitively fails | execution remains `pass`, task/round `partial`; no settled success |
|| commit/push/gate verdict or remote readback is uncertain | task `unverified`, round `unverified`; no closeout and no inferred commit |
|| required memory sync is pending after local commit | execution outcome is retained; CT-06 `awaiting_evidence`, internally `REPORTED_PENDING_MEMORY`; work may continue locally, next round is blocked |
|| backup coordinator is lost | recover the same barrier while valid; lease expiry or backup deadline makes the cut `ABORTED`, permanently aborts upload, holds writers, and can never become complete |

Task reduction uses `unknown` if any required outcome is unknown; otherwise `partial` for
mixed pass/fail/unverified outcomes or publication partiality; otherwise `unverified` if
any required evidence is unverified; otherwise `fail` if no criterion passes; otherwise
`pass` only when every criterion and required publication passes. Wave reduction applies
the same ordered rule to its tasks. Round reduction applies it to waves, then preserves a
`partial` caused by any publication/projection failure even if execution hooks later pass.
`stop_reason` explains why scheduling stopped and never changes this outcome.

The internal-to-CT-06 mapping is fixed: `RETURNED` maps to `received`;
`PROJECTIONS_PENDING` and VII's `REPORTED_PENDING_MEMORY` map to `awaiting_evidence`
when memory/evidence is missing and to `postcheck_pending` when a required postcheck is
unfinished; `CLOSED` maps to exactly one of `settled_success`, `settled_failure`,
`settled_partial` according to the reduction; unresolved `UNKNOWN` maps to `unknown`.
Physical slots release only after process quiescence, independently of logical pending
state. Allowance is never replenished, and the next round remains blocked until a terminal
settlement revision. POST hooks use the pinned plan's 1..5 attempts, default five for
read-only POST verification, at 30-second intervals within the original deadline.
Exhaustion settles failure with `POSTCHECK_FAILED`; it does not leave an indefinite retry
loop. Late evidence or an authorized retry appends a new reconciliation revision keyed by
`(round_id,report_digest,settlement_revision)`, reruns only readback/hooks, and never
reruns work or changes the immutable execution outcome.

Every operation above emits `factory.telemetry.v1` under Part V §V.10 with its Factory
identity, durable source sequence and typed network failure. Read-only lookup success does
not emit a state-change event. `docs/handbook/contract-vectors.json` is the common fixture
source for enrollment, lost grant/consume replies, one-sided binding acknowledgement,
certificate renewal, secret assignment, failed launch, worker/control death, commit
uncertainty, postcheck exhaustion and late evidence; module prose does not fork those cases.

### 1.9.11 Enrollment identity and trust bootstrap

This subsection is the normative first-registration contract. It specializes §1.9.3 and
§1.9.3a for a fresh Bunker; it does not replace their offline operator-key, certificate,
nonce, revocation or authority-ledger rules. The authority is the only actor that may
issue a bootstrap grant or mint a Bunker principal. The Crier registrar is the only actor
that may admit `register.v1` and allocate a node identity. The operator, provisioner,
Scheduler, Crier worker, Gateway and any other third party may relay or verify these
objects but may not mint either credential or identity.

The bootstrap grant is a single-use, signed `enrollment-grant.v1` reference bound to the
exact registration tuple `(registration_id, project_id, profile_id, operation_id)` and to
the Bunker's public key. The grant file contains a `credential_ref`, never inline secret
material; its authority-side record contains `grant_id`, `registration_id`,
`project_id`, `profile_id`, `operation_id`, `public_key`, `nonce`, `issued_at`,
`expires_at` and `issuer_key_id`. The reference is delivered through the protected
Bunker-control channel in a mode-0600 file and is deleted after successful consumption.
A grant is valid for one operation only and is never placed in argv, JSON, logs or a
worker environment. `profile_id` is the live spelling everywhere; `profile` is not an
alternate enrollment field. The `node_id` is allocated by Crier, not supplied by the
Bunker.

The `register.v1` enrollment request is a closed body with exactly these required
members: `registration_id`, `agent_id`, `project_id`, `operation_id`,
`expected_generation: UInt` (the first registration sends `0`), `profile_id`,
`public_identity {certificate_der, key_id}`, `capabilities` (unique, at least one),
and `idempotency_key`. The caller never supplies `generation`; the registrar allocates
`registration_generation=1` for the first accepted registration and returns exactly
`{registration_id, registration_generation, expires_at, credential_ref}`.

The first exchange is ordered and has one wire/version pair only:

1. The authority validates the offline operator signature, tuple, expiry, nonce and
   public-key proof, then atomically consumes the grant. Bad, expired or replayed grants,
   wrong project/profile, a CAS-miss `expected_generation`, invalid proof and unavailable
   authority fail before allocation.
2. The Crier registrar accepts the authenticated `cf2a.v1` envelope with the closed
   `register.v1` body at `POST /v1/factory/registrations` (CT-22). The first request
   carries `expected_generation=0`; the registrar atomically allocates exactly one
   `node_id` and `registration_generation=1`. CT-21's `credential.install` then
   installs the returned class-`crier` `credential_ref` for that node. No worker-class
   principal, child identity or second allocation is permitted. The registrar exposes that
   durable registration at the single read route `GET /v1/factory/registrations/{registration_id}`,
   returning `{registration_id, node_id, registration_generation, state, expires_at, credential_ref}`;
   it is distinct from the authority's certificate-metadata read `GET /v1/registrations/{id}` and
   never returns secret material.
3. The node resolves the returned reference through the broker, installs the credential,
   and performs a signed Crier bus read under `CF2A-CRIER-1`. Only a verified read proves
   membership and permits M9 admission; installing a file or receiving HTTP 200 does not.

The admitted identity is exactly the Bunker principal and its one `node_id`,
`registration_id`, `project_id`, `profile_id`, registration `generation`, public-key
fingerprint, Crier endpoint and class-`crier` credential reference. Its scope is the
bound project, profile and generation, plus the explicitly listed Crier operations;
it cannot access another project or generation. Worker execution inherits this already
admitted node identity through the node's custody channel. A worker or child process
never registers and cannot claim a worker-class principal: M9 refuses that class before
allocation or launch with `WORKER_IDENTITY_FORBIDDEN`. Round, wave, worker and attempt
IDs are execution identities, not enrollment identities.

Failure is fail-closed and has no hidden allocation. A bad/expired/replayed grant,
wrong project/profile, a CAS-miss `expected_generation`, wrong key or failed authority
validation produces `ENROLLMENT_FAILED`; it allocates no durable `node_id`, registration
or credential.
A Crier registration refusal is also `ENROLLMENT_FAILED` with no durable identity. A
signed-read failure after the registration and credential are durably present produces
`DEGRADED`, closes M9 schedulability and retains the one allocated identity for
readback/recovery; it is not a second enrollment opportunity. Loss or removal of a
Bunker fences and revokes the identity and ends in `REMOVED` only after the revocation
and negative resource probe are recorded. Recovery resumes the same
`(registration_id, operation_id, generation)` request, re-sending the observed
`expected_generation`, and reads back its existing
registration before retrying a missing step.

The idempotency tuple is `(registration_id, operation_id, generation)`, where
`generation` is the registrar-allocated registration generation, together with the
canonical request digest. An exact repeat of the same tuple and digest returns
the original `node_id`, `registration_id`, generation and credential reference and
performs no allocation or installation. A changed tuple or request digest returns `REGISTRATION_CONFLICT`
(compare-and-swap refusal), and the registrar does not mutate state. If the reply is lost, the authority or Crier reads
back `GET /v1/factory/registrations/{registration_id}` and resumes the missing CT-21/read-proof
step; it never allocates a second identity.

| Deterministic state | Durable fact | Next action |
|---|---|---|
| `GRANT_READY` | exact tuple and one-use reference are valid | consume once; no identity yet |
| `ENROLLMENT_FAILED` | validation or registration failed before allocation | retain failure; repair trust/input and retry the same operation |
| `ENROLLED` | one node identity and class-`crier` reference are durable | install reference and prove signed read |
| `DEGRADED` | identity exists but signed read is unproven | no admission; read back and retry proof, never allocate |
| `VERIFIED` | identity, credential and signed read all match | M9 may admit the node |
| `REMOVED` | identity fenced/revoked and negative probe recorded | no reuse; replacement gets a new generation |

The hand-checkable cases are `CV-P5G-09-A` through `CV-P5G-09-E` in
`docs/handbook/contract-vectors.json`. They are the sole normative vector source for
fresh accept, exact repeat, conflicting generation, expired grant and worker-class
refusal. [CT-21/22; M1 §§14–15, 17.1–17.2; M9 §§15–16; M10 §15; VII §13]

ch:trace row=P5G-09 spec=docs/handbook/parts/I-system-arrangement.md#section-1911-enrollment-identity-and-trust-bootstrap wave=none:serial test=docs/handbook/contract-vectors.json::CV-P5G-09-A..E doc=docs/handbook/chapters/M1-provisioning.md prompt=none:worker-owned evidence=docs/handbook/contract-vectors.json witness=docs/handbook/contract-vectors.json verdict=none:foreman-runs-gitreins commit=none memory=none:foreman-writes
STATUS: partial
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json

ch:trace row=P5G-06 spec=docs/handbook/OUTLINE.md#part-iii--modules wave=none:serial-worker test=bash tests/selftest.sh doc=docs/handbook/parts/I-system-arrangement.md evidence=none:handbook-specification-no-live-binding-runtime witness=none:repository-local-spec-only verdict=none:foreman-runs-gitreins commit=none:worker-commit memory=none:foreman-writes
STATUS: complete
TIER: T0
EVIDENCE: docs/handbook/parts/I-system-arrangement.md and commit recorded by the foreman

## 1.10 The contract surface, as a count

The canonical register contains 31 rows: `CT-01`…`CT-23`, the foreman-return leg
`CT-06R`, and the seven manager contracts `CT-24`…`CT-30`. Current implementation
coverage remains separate from this target count: historic transport coverage
appears under each model contract's legacy_coverage. All target wires remain
UNVERIFIED until the versioned target contract is exercised; a legacy PROVEN
transport cannot certify a new schema. Auxiliary boundary_edges are additional
legs of named canonical contracts, not new contract IDs. The target model has
33 component responsibilities including external peers; captions must derive this
count rather than retaining the former 27/28-box scope. Wave C owns the out-of-scope
BOOK.yaml caption and rendered figure updates.

## 1.11 P5-A finding disposition and issue handoff

These entries specify target fixes, not implemented or live-verified behavior.
The owner accepts the combined issue after all waves; explicit decision slots
remain visible at their fail-closed defaults.

| Finding | Normative resolution |
|---|---|
| P5-A-01 | §1.9.2 transactional records, fsync, indexes, corruption and migration |
| P5-A-02 | §1.9.3/3a independent authority, resource-side broker and epoch protocol |
| P5-A-03 | F2.0 cold bootstrap, first administrator and generation one |
| P5-A-04 | §1.9.1 cf2a.v1/factory.v1 layering, routes, types and errors |
| P5-A-05 | §1.9.4 prepared participants, committed pointer and dispatch grants |
| P5-A-06 | F15.1 ordered barriers, consistency marker and post-backup revocation |
| P5-A-07 | §1.9.3 certificate principal, role scopes and recovery enrollment |
| P5-A-08 | §1.9.4 full transition relation and cancel/irreversible CAS |
| P5-A-09 | §1.9.5 CLI JSON protocol, capabilities, effect discovery and retries |
| P5-A-10 | §1.9.5 integer resource units, first-fit ordering and atomic reservation |
| P5-A-11 | §1.9.1 one generation, proposal import and durable active-edition publication |
| P5-A-12 | §1.6 concrete topology/volume/network profiles; A-RELEASE pin decision slot |
| P5-A-13 | Part V shared-Git choice applied to overview, arrangement, F3 and model |
| P5-A-14 | §1.9.9 awaiting_evidence and controller-custody deadline |
| P5-A-15 | §1.9.6 exact Git ref CAS, operation marker and claim vocabulary |
| P5-A-16 | F8.1 execution controls, checkpoint, quiescence/fenced_unknown and resume |
| P5-A-17 | §1.9.9 provisional versus final settlement and postcheck retry |
| P5-A-18 | §1.9.6 CT-05 worker brief; CT-01 lane_seed extension |
| P5-A-19 | §1.9.6 round-admission.v1, legacy translation and fixed authorization set |
| P5-A-20 | §1.9.7 / F5 mode-specific destination/tree proof and gate invalidation |
| P5-A-21 | §1.9.7 / F12 GitLab project-token lifecycle and A-GITLAB enrollment |
| P5-A-22 | §1.9.7 online attenuated capability, expiry, revocation and denial probe |
| P5-A-23 | §1.9.8 / F6 retention holds and delete-versus-acquire CAS |
| P5-A-24 | §1.9.8 / F13 compatibility set, rollout order and migration recovery |
| P5-A-25 | F16.1 required policy, target snapshot and aggregate truth table |
| P5-A-26 | SYSTEM-MODEL canonical CT-19–CT-30, manager and external provider legs |
| P5-A-27 | SYSTEM-MODEL target steps separated from legacy_steps; subflows registered |
| P5-A-28 | Explicit model host ownership; resident execution versus telemetry gateway |
| P5-A-29 | §1.3.5 GUARD responsibility and mandatory fail-closed production posture |
| P5-A-30 | Model-derived caption contract fixed; BOOK.yaml/rendered caption remains wave-C handoff |
| P5-A-31 | Sequential §1.6–§1.10 and CT-24–CT-30 signposts; regeneration release marker |
| P5-A-32 | Part 0 authority/target revision and model precedence; SPEC_CONFLICT refusal |
| P5-A-33 | §1.9.9 / F7/F14 live authenticated progress, sequence, freshness and owners |

Wave C must render boundary_edges and explicit dual-instance/external host labels,
retain target-only sequence figures, and derive the caption from view_contract.
Wave B's contract/settings/work-derivation edits must retain the selected
cf2a.v1/factory.v1/round-admission.v1 vocabulary and CT-05 worker-brief identity;
contradictory legacy cards are not alternative formats. These cross-wave files
are outside wave A's fence, so this handoff does not claim them corrected.

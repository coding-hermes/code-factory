# Part I — System arrangement

![System map](figures/system-map.svg)

The Factory arranges 28 components on six layers, joined by contracts (`CT-01`…`CT-18`
plus the `CT-06R` foreman-return leg, Part IV) and exercised by 16 flows (Part II).
A box on the map is a responsibility, not a path; the path that implements a box
lives in its `impl` note and may move without the system changing. Every box also
carries a role/host boundary: components tagged BUNKER execute inside the Bunker
deployment/execution boundary — the Bunker daemon's create/exec/cp surface, in a
fresh image-backed or persistent-container profile chosen per Bunker — and untagged
components run on the control host. Solid lines are interfaces that work as
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
a human finally reads. Six components sit in control, three in transport, seven in
execution, three in memory, eight in governance, one in evidence. Eight of the 28
— the operator, the foreman, the task-router, the gateway, the bunker daemon,
DuckBrain, the session store and the factory manager — sit outside the 13 module
chapters (M0–M12) and are documented as boundary peers; the remaining 20 each key
to one module chapter in Part III.

Four resolved decisions fix the arrangement and are repeated wherever they matter.
First, the project foreman runs **inside its Bunker**; Crier is the launch/return
boundary — the scheduler's envelope enters the Bunker through Crier, and the
foreman's response returns through Crier to the scheduler on the control host, which
records it and triggers subsequent processing. Second, **DuckBrain is installed in
every Bunker** and must expose the same logical project memory data/view as the
controller; the physical shared-service or replication topology and the offline
behavior are still open specifications, and this book treats the shared view as a
requirement, not an installed fact. Third, the Task Router is future and not part
of the MVP, placed after Node and before Harness, and the MVP bypasses it — Hermes
is the fixed MVP harness. Fourth, the **Factory manager** — the deterministic
infrastructure-as-code management/reconciliation service and its desired/observed
state store — is a required component of the arrangement; it is specified in this
Part, registered in `docs/SYSTEM-MODEL.yaml`, and marked TARGET-UNIMPLEMENTED: not
yet built, with its implementation language and storage explicitly undecided. The
map sheet regenerates from the system model; until that regeneration lands, the
figure above does not yet draw the manager box or the external Git-provider
boundary described in §1.1 — a named deviation, not a concealed one.

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
  and no particular memory replication design is implied by the drawing.
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
- **Inputs:** `CT-01` lane configuration (UNVERIFIED), `CT-05` foreman lane
  prompt text (UNVERIFIED), `CT-06` completion events (PROVEN), refreshed board
  copies.
- **Outputs:** `CT-02` the signed dispatch envelope — run_id, corr_id, lane,
  board, text_b64 — rendered by `internal/bus/dispatch.go:202,266`
  `BuildDispatch` (PROVEN); admission refusals with named reasons; settlement records.
- **Consumers:** crier (delivery), the operator's metrics surface (`/api/v1/metrics`, M9 §8).
- **Failure behavior:** gateway failure defers the tick rather than spawning
  (`no-exec-fallback=true`, M9 §5); load gate defers new spawns at threshold; an
  unreadable board is diagnosed, never dispatched.
- **Pointers:** M9 (`docs/handbook/chapters/M9-scheduler.md`); contracts `CT-01`,
  `CT-02`, `CT-05`, `CT-06`; settings Part V (cadence, admission, pacing).

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
- **Outputs:** `CT-21` an installation token installed at `auth/github.token`,
  mode 0600 (UNVERIFIED — the mint was never run on the documenting host, no App
  credentials; the consumer is a credential file, not a function, M7 §6).
- **Consumers:** node credential files, refresh runs (`refresh --node`).
- **Failure behavior:** a failed mint yields no token file rather than a stale one; expiry is handled by refresh, not by extending scope.
- **Pointers:** M7 (`docs/handbook/chapters/M7-github.md`); contracts `CT-21`,
  M7-C1; settings Part V. GitHub is one provider of at least two: GitLab is a
  required target with its own adapter and identity semantics (§1.4, V2-ARR-06).

**5. SCOPE MINTER**
- **Purpose:** mint the per-dispatch scoped GitHub token the dispatcher injects.
- **Form/location:** script (process run per dispatch) — `~/.hermes/scripts/fleet-gh-scope.py`.
- **Caller/trigger:** each dispatch preparation (M11 §3 S4).
- **Owned decisions and state:** the per-dispatch scope restriction only; a
  separate minter from M7's `github-app-token.py` (M7 §12).
- **Inputs / outputs:** repository/operation scope in; scoped token out, dispatcher-side.
- **Consumers:** the dispatcher's injected environment.
- **Failure behavior:** no register row; the token travels dispatcher-side and the wire is not measured.
- **Pointers:** M11 (`docs/handbook/chapters/M11-dispatcher.md`).

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
  concrete storage/HTTP framework are explicitly undecided — Go, Python and Rust
  were named as possibilities and no selection was made (V2-ARCH-01, V2-ARCH-03).
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
  normative manager contracts `CT-24`–`CT-29` and `CT-06R` in Part IV §IV.1;
  desired-state and readback schema Part V §V.3/§V.6; state model §1.7.1.

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
  `CT-22` agent registration (producer half not established, M1 §6).
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
- **Purpose:** the session API — where a delivered message becomes a model turn.
- **Form/location:** runtime process (`hermes gateway`) on the control host.
- **Caller/trigger:** crier session delivery; dashboard and status requests.
- **Owned decisions and state:** session records, `/api/status`, dashboard auth.
  Does not schedule and does not store the ledger.
- **Inputs:** `CT-07` model choice (UNVERIFIED), `CT-08` delivered messages
  (PROVEN, `platforms/api_server.py:1763`), `CT-20` forwarded inference with the
  control-host key (UNVERIFIED).
- **Outputs:** session rows; model turns.
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
  `CT-19` inference through the proxy; `CT-22` agent registration (producer half
  not established, M1 §6).
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
- **Purpose:** run the work inside the agent's container via `bunker exec` —
  start detached, poll with short calls, kill on deadline — and keep the replay
  ledger (M11 §2).
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
- **Purpose:** merge a worker branch and prove the commit is an ancestor of
  origin/main (M3 §2) — repository publication.
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
  a recorded refresh or publication reconciles them; the scheduler's lane hooks
  own that synchronization, and Figure 2.1 shows the copies and their refresh
  order explicitly.
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
  memory data/view as the controller; the physical shared-service/replication
  topology and offline synchronization behavior are open specifications. Losing
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
- **Outputs:** reclaimed space; refusals. The TTL governs age, not citation — it
  can delete a directory a module cites as evidence (M8 §2). Protected paths —
  the repo, `node.json`, `crier.json` — are refused before inspection (M8 §5).
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
| Effective configuration | The factory manager — desired vs observed vs effective readback; the configuration file is the desired-state authority, edited by the user or an authorized agent; Boardctl carries project work, never configuration authority | target — register extension pending (Part IV) | TARGET-UNIMPLEMENTED |
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
| GitHub App installation token | GitHub App (JWT → installation token, M7 §5) | Node credential file `auth/github.token`, mode 0600 | Repository operations the App installation grants | File delivery via `refresh --node`; value never printed (M7 §7) | Refresh cycle; revocation by App management | Token file presence/mode; consumer is a file, not a function (M7 §6) | M7 settings |
| GitLab provider credential (target) | GitLab's own issuer, via a GitLab-specific adapter — semantics NOT assumed from GitHub App | Bunker/node credential locations per profile | Repository operations per GitLab grant | Same install-delivery path as GitHub rows; reference syntax Part V (target) | Native GitLab lifecycle; renewal/revocation under manager policy | Effective readback required before admission (target) | Part V (target) |
| Per-dispatch scoped token | Scope minter (`fleet-gh-scope.py`, M11 §3 S4) | Dispatcher environment, inside the Bunker | One dispatch, restricted operations | Injected per dispatch, not persisted to disk | Ends with the dispatch | Dispatcher-side; not a measured wire | M11 settings |
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

The Factory must specify, evaluate and reconcile these profiles (V2-ARCH-02).
They are **required target profiles to evaluate and specify** — stating one here
is not a claim that every upstream component already supports it. For each
profile the specification covers supported host/runtime versions, privilege and
container prerequisites, persistent state locations, bootstrap/install ownership,
endpoint discovery, controller-to-Bunker/Crier/memory/model/forge connectivity,
authentication and certificate lifecycle, capacity and readiness checks, and
update/restart and host-loss behavior. Native support and effective readback must
be documented per profile (V2-SET-05); a profile whose requirements cannot be met
is declared **unsupported** with a named reason, never silently attempted.
Public-cloud-specific integrations are lower priority. Terminal Jail remains
optional and disabled by default in every profile.

| Profile | Disposition | Basis and conditions |
|---|---|---|
| Kubernetes | Supported (target profile) | Ordinary Kubernetes is the first-class target. An orchestrator may restore a pod, but that does not automatically restore application-level state or bindings — the factory manager restores project/board/memory state and updates Crier and scheduler bindings (§1.8) |
| Docker Compose | Supported (target profile) | Single-host declarative topology; the manager reconciles Compose-declared state with observed state through its adapters |
| Homelab incl. VPN (Tailscale-style) | Supported — adapter required for endpoint discovery | Connectivity and addressing change with VPN topology; the manager accounts for changed addresses and disconnected sites without assuming every data path has the same reachability |
| Standalone machines | Supported (target profile) | Individual hosts; on non-orchestrated hosts the factory manager coordinates placement/preparation equivalent to orchestrated profiles (V2-ARCH-01) |
| Public-cloud-specific integrations | Lower priority (not unsupported) | Deprioritized by explicit user direction; evaluated after the four required profiles |

The manager selects/applies the profile per project deployment and reconciles
per-Bunker desired configuration under it; profile choice is desired state, and a
forced drift from it is exposed, not absorbed.

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

The implementation language and concrete storage/HTTP framework are explicitly
undecided — Go, Python and Rust were named as possibilities and no selection was
made. The component is therefore registered TARGET-UNIMPLEMENTED in
`docs/SYSTEM-MODEL.yaml`; its contract-register rows are a Part IV extension
pending that implementation reconciliation.

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

## 1.7.1 Manager resource and operation state model

The manager's target contract is versioned independently of implementation coverage.
The resource model uses `manager.v1` and the following stable resources:

| Resource | Required identity | Durable state and meaning |
|---|---|---|
| `desired-config` | `(project_id, generation)` | declared intent; generations are immutable after acceptance |
| `observed-inventory` | `(scope, observation_id)` | adapter readback, timestamp and observation quality |
| `reconciliation-operation` | `(operation_id, desired_generation)` | `accepted`, `planned`, `applying`, `degraded`, `converged`, `failed`, `cancelled` |
| `binding` | `(project_id, binding_generation)` | verified Crier route and scheduler availability binding |
| `incident` | `(incident_id, scope)` | detected failure, fence decision, replacement and recovery evidence |

A manager request carries `schema_version: "manager.v1"`, `request_id`, `project_id`,
`expected_generation` where a compare-and-swap applies, and the requested operation.
The manager authenticates an authorized configuration principal and scopes every request
to the named project or Factory scope. A successful accepted update returns
`202 Accepted` with `operation_id`, `desired_generation`, and `status: "accepted"`;
it does not claim readiness. A current-state read returns desired, observed and
status objects together, with `effective` values only when the owning adapter has
read them back. Secret values are never returned; secret references remain references.

The normative operation set is:

| Operation | Request example | Success / refusal |
|---|---|---|
| `GET /v1/projects/{id}/state` | `schema_version=manager.v1` | `200` with desired, observed, effective and operation status; `404 PROJECT_UNKNOWN` if absent |
| `PUT /v1/projects/{id}/desired` | `{expected_generation: 17, desired: {...}}` | `202` with generation 18; `409 GENERATION_CONFLICT` leaves generation 17 unchanged |
| `POST /v1/operations/{id}/reconcile` | `{desired_generation: 18, idempotency_key: "..."}` | `202` or the existing operation result for the same key; `409 GENERATION_NOT_CURRENT` if stale |
| `POST /v1/operations/{id}/cancel` | `{operation_id: "..."}` | `202` when cancellation is accepted; `409 NOT_CANCELLABLE` after an irreversible adapter step |
| `GET /v1/operations/{id}` | `{}` | `200` with state, per-adapter acknowledgements and readback; `404 OPERATION_UNKNOWN` if absent |
| `GET /v1/readiness/{project_id}` | `{}` | `200 READY` only after authenticated operation probes and binding generation match; `503 NOT_READY` otherwise |

Every mutating request is idempotent by `(principal, project_id, operation, idempotency_key)`.
A reused key with a different request digest returns `409 IDEMPOTENCY_KEY_REUSED`; a
reused key with the same digest returns the original result without a second adapter
side effect. An adapter applies a change only when the operation's active-owner fence
matches; `STALE_OWNER` is a typed refusal. Each adapter acknowledgement records
`adapter_id`, `operation_id`, `attempt`, `effective_digest` or a redacted failure,
and `observed_at`. An operation is `converged` only when every required acknowledgement
and effective readback passes. Missing, stale or partial readback produces `degraded`,
not `converged`.

The manager persists the request, generation check, operation transition, adapter
acknowledgements, binding changes and incident evidence in one durable operation log
with an explicit transaction boundary per transition. Recovery resumes an `accepted`,
`planned` or `applying` operation by idempotency key; it first fences an old owner,
then re-reads observed state, and applies only missing steps. A replacement may publish
a new binding only after readiness for that binding generation. A late result with an
old owner token is rejected at the resource side and recorded as `STALE_OWNER`;
it cannot alter effective state or publish a second binding. These are target guarantees;
the implementation remains TARGET-UNIMPLEMENTED until independently exercised.

### 1.8.1 Manager API and adapter contract

`manager.v1` has one global configuration scope and one project scope; they are
related by immutable generations, not by an implicit last-writer-wins merge. A global
update creates `global_generation`; a project update records both its
`project_generation` and the global generation it was validated against. A project
reconciliation is refused as `GLOBAL_GENERATION_STALE` when its base is no longer the
current global generation. The manager never edits the user's desired project values
while rebasing them; an authorized editor must submit a new generation.

Every request is authenticated before parsing its desired payload. The authentication
principal is carried as `principal_id`, its role is checked against the operation and
scope, and the request is rejected as `UNAUTHORIZED` or `FORBIDDEN` before any
reservation or adapter call. The minimum authorization matrix is:

| Operation | Factory administrator | Project editor | Foreman / scheduler | Adapter identity | Observer |
|---|---|---|---|---|---|
| Read global/project state | all scopes | named project | named project/readiness | own adapter scope | permitted scopes |
| Change desired configuration | global + projects | named project only | no | no | no |
| Reconcile / reserve | all | named project | request/read readiness only | own step only | no |
| Cancel before irreversible step | all | named project | request for its operation | no | no |
| Read secrets | no API caller | no | no | reference resolution only at its boundary | no |

The adapter interface is versioned and observable: `validate(desired_generation)`
returns typed capability failures; `plan` returns ordered steps and a plan digest;
`reserve` returns a reservation id, owner fence and expiry; `apply` accepts that
reservation and owner fence; `readback` returns an immutable observation with
`observed_at`, `quality`, effective digest and binding generation; `release` is
idempotent for reservations that never entered an irreversible step. Adapter results
carry `adapter_id`, `operation_id`, `step_id`, `attempt`, `status`, a redacted error
or effective digest, and the manager's correlation id. An adapter may not report
`converged` from an apply acknowledgement without a successful readback.

The non-circular readiness sequence is: validate candidates and capabilities; reserve
capacity; apply host/runtime state; perform authenticated repository, memory, Crier,
and scheduler probes; read back effective state; activate the binding; then mark the
project `READY`. Candidate `ready` means only that a host can perform its probe; active
route/admission `ready` additionally requires the binding generation and all required
project probes. If a reservation, probe or readback is lost, the operation is
`degraded` and the binding remains fenced. Cancellation is accepted only before the
first irreversible adapter step; after that boundary it returns `NOT_CANCELLABLE` and
reconciliation continues to a visible result. A restart replays the durable operation
log, fences the previous owner, re-reads observations, and applies only missing steps.

## 1.9 The contract surface, as a count

The canonical register contains 31 rows: `CT-01`…`CT-23`, the foreman-return leg
`CT-06R`, and the seven manager contracts `CT-24`…`CT-30`. Current implementation
coverage remains separate from this target count: `CT-02`, `CT-03`, `CT-06` and
`CT-08` are PROVEN; `CT-04` is PARTIAL; `CT-09` is MISSING for its legacy node
producer; `CT-10` is BROKEN for that producer; and the remaining rows are UNVERIFIED
or TARGET-UNIMPLEMENTED as detailed in Part IV. The map's dashed and dotted lines
carry coverage states; they do not weaken the target contracts.

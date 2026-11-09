# Part IV — Contract register

Every interface that can change the behaviour or correctness of a run, named once.
`CT-nn` is the canonical id used by every chapter; a chapter that names one of these
interfaces must use this id, not one of its own.

A contract is **both-sided** only when the sender's guarantee and the receiver's
requirement are each backed by a `file:line` or a command that was run. Where the model
records only one side, the row is marked **RED** and carries the command that would
close it — a register that reads as complete while half its wires are one-sided is worse
than an honest gap.

The normative target contract is specified independently of implementation coverage.
The detailed entries below retain measured producer/consumer citations and explicitly
mark missing evidence; the contract cards in §IV.1 define the behavior an implementation
must provide. A citation cannot replace a field, validation rule, state transition,
error, idempotency key, persistence boundary or recovery rule.

## IV.1 Normative contract cards

All cards use `contract_version: "cf2a.v1"` and require `request_id` and `corr_id`
where a request crosses a process boundary. IDs are opaque strings, ASCII, 1–128
characters; absent required IDs are refused as `INVALID_ID`. Every response carries
`contract_version`, `request_id`, `corr_id`, `status`, and `error` when `status` is not
`ok`. Unknown versions are refused as `UNSUPPORTED_VERSION`; unknown fields are ignored
only when the card says they are extension fields. Secret material is never carried;
credential fields are references governed by Part V.

| Contract | Normative request / result | State, refusal and persistence rule |
|---|---|---|
| `CT-01` | `config_version`, `lane`, `enabled`, `admission_mode`, `cadence_s`, `weight`, `pin`; result `accepted`, `effective_config_version` | validate enum/ranges before persistence; stale generation is `GENERATION_CONFLICT`; accepted configuration is durable before admission |
| `CT-02` | `run_id`, `corr_id`, `lane`, `board_ref`, `directive_digest`, `text_b64`, `envelope_version`, `expires_at`; result `accepted`, `delivery_id` | scheduler persists the envelope before send; Crier deduplicates `(run_id,corr_id)` and returns the existing custody receipt |
| `CT-03` | `agent_id`, `delivery_id`, `lease_s`, `message`; result `lease_id`, `lease_expires_at` | retrieval atomically marks one lease; invalid signature is `UNAUTHORIZED`, expired lease is `LEASE_EXPIRED`; ack/release is durable and redelivery never creates a second execution identity |
| `CT-04` | `delivery_id`, `run_id`, `corr_id`, `dispatch_id`, `attempt_id`, `status`, `commit`, `artifacts`, `finished_at`; result `accepted` or `DUPLICATE_RESULT` | status is typed (`pass`, `fail`, `partial`, `unknown`); missing status is `INVALID_RESULT`; the first durable result wins and conflicting duplicates are `RESULT_CONFLICT` |
| `CT-05` | `lane`, `prompt_digest`, `skills`, `config_generation`; result `brief_version`, `accepted` | prompt/skill digest is immutable for the round; stale generation is `CONFIG_STALE`; acceptance is a custody receipt, not execution success |
| `CT-06` | `run_id`, `corr_id`, `result_ref`, `status`, `attempts`, `finished_at`; result scheduler settlement | scheduler accepts only a correlated durable result; absent or conflicting verdict is `UNKNOWN_RESULT`, never success; settlement is durable before the next cadence decision |
| `CT-06R` | foreman report: `round_id`, `run_id`, `corr_id`, `schema_version`, `waves`, `task_results`, `budget`, `stop_reason`, `memory_refs`, `evidence_refs` | foreman writes local custody and memory records before return; duplicate `(round_id, report_digest)` is replayed, conflicting report is refused |
| `CT-07` | `model`, `provider`, `lane`, `policy_generation`; result selected model or `MODEL_NOT_ALLOWED` | allowlist and policy generation are checked before spend; selection is recorded with the session |
| `CT-08` | `session_id`, `corr_id`, `message`, `model`; result `accepted`, `session_turn_id` | gateway acknowledges durable session custody; timeout is `DELIVERY_UNKNOWN` and replay uses the same idempotency key |
| `CT-09` | memory record `{record_id, namespace, record_type, round_id, wave_id, attempt_id, payload_digest, body, local_commit}`; result `{record_id, local_ack, sync_state}` | local Git-backed namespace commit is the durable acknowledgement; `(namespace,record_id)` is unique; remote sync is separate and can be `pending-sync` |
| `CT-10` | board event `{event_id, task_id, expected_revision, transition, evidence_refs}`; result `new_revision` | compare-and-set against canonical revision; stale revision is `CLAIM_CONFLICT`; append is idempotent by `event_id` and partial writes are replay-safe |
| `CT-11` | `session_id`, `turn_id`, `model`, token usage, cost basis; result durable turn row | gateway writes the turn atomically or returns `PERSISTENCE_UNAVAILABLE`; no usage row is inferred from a transport receipt |
| `CT-12` | staged-tree digest, exact commit candidate, guard version and criteria | guard emits a named verdict bound to the staged tree; missing gate is `GATE_UNAVAILABLE`; no verdict means no closeout |
| `CT-13` | verdict `{run_id, criteria, outcome, evidence_refs, tree_digest}`; result board closeout | board accepts only an evidence-bound verdict whose tree digest matches the landed tree; duplicate closeout is a no-op, conflicting closeout is `CLOSEOUT_CONFLICT` |
| `CT-14` | row/event mutation with `task_id`, `expected_revision`, actor, criteria and evidence | foreman is the task-state writer; claim/close requires CAS and lease/fence; malformed, cyclic or stale updates are refused and never partially applied |
| `CT-15` | memory decision/finding with stable `record_id`, namespace, correlations and evidence | designated foreman writer persists worker, wave and round records separately; remote outage yields durable local pending state, not loss or completion |
| `CT-16` | handbook build receipt `{revision, checks, source_digest, artifact_digest}`; result owner decision receipt | a receipt says what was checked, not that the owner approved it; absent or failed required checks is `BUILD_NOT_ACCEPTED` |
| `CT-17` | conformance leg `{profile, harness, pin, leg, result, evidence}`; result support state | every leg is independently `PASS`, `FAIL` or `UNVERIFIED`; a missing leg cannot be promoted to supported |
| `CT-18` | revisioned delivery artifact `{document_id, revision, scope, artifact_digest, checks, open_findings}` | owner receives a complete receipt; approval is a separate human decision and is never inferred from build success |
| `CT-19` | node token reference, `model`, request body, `corr_id`; result finite stream or typed HTTP error | token scope/expiry is checked before upstream work; revoked/expired token is `UNAUTHORIZED`; cancellation stops upstream work where supported and is recorded |
| `CT-20` | proxy request with model policy, control-host credential reference and upstream correlation | proxy owns provider-key custody and usage accounting; upstream errors before/after headers are distinct, and capture failure follows configured redaction policy |
| `CT-21` | provider/app identity, repository scope, credential reference, destination profile; result fingerprint, expiry, scope | issuer and installer remain distinct; wrong scope/mode is refused; renewal overlaps safely, revocation prevents restore from reactivating the credential |
| `CT-22` | agent registration `{agent_id, project_id, profile, public_identity, capabilities}`; result registration generation and expiry | registration is idempotent by `(agent_id, registration_generation)`; stale identity is refused and deregistration is durable |
| `CT-23` | pinned Bunker CLI/protocol request `{agent_id, operation, image/profile, request_id}`; result typed exit/status, stdout/stderr digest and capability readback | create/exec/cp are scoped to the agent; unsupported capability is refused; retries use the same request id and cannot duplicate a create |
| `CT-24` | manager desired update `{schema_version, project_id, expected_generation, desired, idempotency_key}`; result new generation and operation id | configuration file/API is authoritative; stale generation is `GENERATION_CONFLICT`; desired state is durable before reconciliation |
| `CT-25` | manager observed readback `{scope, adapter_id, observation_id, observed_at, values, quality}`; result effective state | observations are immutable; stale/partial quality is visible and cannot establish convergence |
| `CT-26` | reconcile `{desired_generation, operation_id, idempotency_key}`; result per-adapter plan and status | `accepted → planned → applying → converged/degraded/failed`; each transition is durable and idempotent; same key/different digest is `IDEMPOTENCY_KEY_REUSED` |
| `CT-27` | allocation request `{project_id, requirements, eligible_hosts, desired_count}`; result reservations and exact shortfall | allocation is deterministic and preserves desired count; insufficient capacity is `ALLOCATION_SHORTFALL`, not silent lowering |
| `CT-28` | binding update `{project_id, binding_generation, readiness_ref, crier_ref, scheduler_ref}`; result active binding | publish only after authenticated readiness probes; stale owner/generation is `STALE_OWNER`; old bindings remain fenced until replacement is verified |
| `CT-29` | incident/recovery `{incident_id, scope, owner_fence, checkpoint, replacement}`; result resumed/degraded/failed | old owner is fenced before replacement side effects; crash recovery re-reads state and applies only missing idempotent steps |
| `CT-30` | manager event/metric readout `{event_version, event_id, event_type, scope, payload}` or `{metric_schema_version, samples, observed_at}` | event delivery is per-endpoint durable and replayable; missing metrics are `unknown`, not zero; receiver interpretation remains external |

**Common acceptance cases.** A conforming implementation returns a typed refusal for
missing required fields, wrong scope, unsupported version, stale generation, duplicate
key with a changed digest and unavailable readback. It accepts a same-key retry without
a second side effect, survives restart from its durable transition log, and reports
partial propagation as degraded. A late result from a fenced owner cannot change board,
manager, binding or memory state. These cases are target behavior; the measured evidence
below remains coverage and may be RED or UNVERIFIED.


> CAUTION: a row whose State reads PROVEN while its sender guarantee or receiver
> requirement reads RED is self-contradictory — one side is measured, the other is not.
> Treat such a row as UNVERIFIED until both sides carry citations. The generator
> enforces this: a PROVEN state with an uncited side prints as UNVERIFIED.

**Register requirements (normative).** Approved target behavior governs; the per-entry citations
below are implementation coverage, not the contracts.

- **One versioned registry, 31 entries.** CT-01..CT-23, `CT-06R` and CT-24..CT-30 below
  are the register of record. The older 18-entry assumptions in chapter headers and the build
  spine are reconciled to this count, and figures, tables and cross-references are
  generated/validated from this one versioned registry — unknown/duplicate ids, missing
  definitions and retired local labels (e.g. M12's former M12-C1/M12-C2, now CT-19/CT-20)
  are rejected. Reconciliation is not done by changing the count alone: each entry's
  endpoints, directions and actors must match the chapter that cites it (CT-07 is router →
  gateway model choice; the proxy's legs are CT-19/CT-20).
- **Full contracts independent of citations.** Every entry specifies: types/units/required fields
  with examples; side effects; auth/scope; correlation and generations; ordering/idempotency;
  deadlines, leases and retries; the error vocabulary; durability; telemetry; and recovery. A
  `file:line` citation establishes provenance or implementation coverage — it cannot define
  required field types, validation, side effects, deadlines or observable success/failure, and
  integration tests qualify evidence without replacing the normative contract.
- **Producers reassigned per the resolved architecture.** Memory and board projections belong to
  the **Bunker foreman/projection path** (e.g. the scheduler's `execution_projections` duckbrain/
  board sinks), not to whatever component happens to lack a direct write. CT-09/CT-10's
  MISSING/BROKEN states must not be inferred from the node bus worker's absence of writes —
  absence in a transport worker does not prove the Factory has no board/memory path. Guard, judge,
  landing/closure and the credential stages stay distinct: a GitReins verdict is not itself an
  automatic board close or landing event (CT-12/CT-13).
- **Human/external consumers get complete observable contracts.** Boundary entries are specified
  by observable behavior — CT-18 as a revisioned delivery/decision receipt, CT-23 against the
  pinned Bunker public CLI/proto interface with versioned integration evidence — not by inventing
  internal encode functions or requiring access to third-party internals.

| id | from → to | carries | mode | state |
|---|---|---|---|---|
| CT-01 | owner → scheduler | lane enabled, cadence, weight, pin | config | UNVERIFIED |
| CT-02 | scheduler → crier | envelope: run_id, corr_id, lane, board, text_b64 | async, bearer + signature | PROVEN |
| CT-03 | crier → node | inbox message + lease | pull; retrieval grants the lease (default 30 s, requester-adjustable) | PROVEN |
| CT-04 | node → crier | reply: status, dispatch_id, corr_id, branch, commit, artifacts | async, signed | PARTIAL |
| CT-05 | foreman → scheduler | the lane's prompt text and skills it may load | seeded config | UNVERIFIED |
| CT-06 | crier → scheduler | completion event for a finished run | async | PROVEN |
| CT-07 | router → gateway | model choice for a prompt | in-band | UNVERIFIED |
| CT-08 | crier → gateway | hermes-session delivery (message becomes a session turn) | sync (the 30 s figure is its historical mode/version's timeout, not a universal bound) | PROVEN |
| CT-09 | node → duckbrain | R1 run record, R2 fleet index | http, x-api-key | MISSING |
| CT-10 | node → board | row event with run_id and outcome | append | BROKEN |
| CT-11 | node → sessionstore | every turn, model, tokens | writes via gateway | UNVERIFIED |
| CT-12 | node → gitreins | staged diff | pre-commit hook | UNVERIFIED |
| CT-13 | gitreins → board | verdict that closes a row | human/foreman action | UNVERIFIED |
| CT-14 | foreman → board | row created, row closed, evidence | boardctl | UNVERIFIED |
| CT-15 | foreman → duckbrain | decisions, findings, goal | mcp / http | UNVERIFIED |
| CT-16 | docsgate → handbook | module status word | read at build | UNVERIFIED |
| CT-17 | conformance → harness | per-leg verdict (check, apply, smoke, vars, memory) | executed | UNVERIFIED |
| CT-18 | handbook → owner | the approval artifact | read | UNVERIFIED |
| CT-19 | node → proxy | chat completion with a node bearer token | http, bearer node token | UNVERIFIED |
| CT-20 | proxy → gateway | forwarded inference with the control-host key | http, 300 s timeout | UNVERIFIED |
| CT-21 | github → node | installation token installed at auth/github.token, mode 0600 | https api, JWT mint | UNVERIFIED |
| CT-22 | node → crier | agent registration + token exchange | https, POST /agents | UNVERIFIED |
| CT-23 | provisioner → bunker | create, exec, cp against the agent container | bunker CLI | UNVERIFIED |
| CT-06R | foreman → crier → scheduler | versioned round report and durable return | async, signed, correlated | TARGET-UNIMPLEMENTED |
| CT-24 | owner/agent → manager | desired configuration generation update | authenticated API/file, CAS | TARGET-UNIMPLEMENTED |
| CT-25 | manager adapter → manager | observed/effective readback | adapter result | TARGET-UNIMPLEMENTED |
| CT-26 | manager → adapters | deterministic reconciliation operation | durable async operation | TARGET-UNIMPLEMENTED |
| CT-27 | manager → eligible hosts | allocation reservation and shortfall | fenced resource transaction | TARGET-UNIMPLEMENTED |
| CT-28 | manager → crier/scheduler | verified readiness and binding activation | authenticated, generation-bound | TARGET-UNIMPLEMENTED |
| CT-29 | manager → recovery actors | incident, fence and replacement recovery | durable, idempotent | TARGET-UNIMPLEMENTED |
| CT-30 | manager → subscribers/operators | versioned event delivery and independent metric readout | durable cursor / read-only API | TARGET-UNIMPLEMENTED |

## Contracts in detail

### CT-01 — owner → scheduler

- **Carries:** lane enabled, cadence, weight, pin
- **Mode:** config
- **State:** UNVERIFIED
- **Sends because:** Intent, priorities, approval
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** boundary — the producer is a human writing fleet.toml and scheduler.db project rows; the consumer is admission_mode.go:112 admissionModeForProject (M9 §6)
- **Sender guarantee:** the owner declares it — fleet.example.toml:15,35 (per-lane weight, enabled); project admission rows in scheduler.db are the source of record
- **Receiver requirement:** internal/scheduler/admission_mode.go:112 — admissionModeForProject resolves the project row (override → namespace default → cooldown)

### CT-02 — scheduler → crier

- **Carries:** envelope: run_id, corr_id, lane, board, text_b64
- **Mode:** async, bearer + signature
- **State:** PROVEN
- **Sends because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** CF-354 fixed — crier HandleDeliver delivers the envelope verbatim (M9 §6, M10 §6)
- **Sender guarantee:** internal/bus/dispatch.go:202,266 — BuildDispatch renders run_id/corr_id/lane/board/text_b64 and signs before POST
- **Receiver requirement:** crier internal/registry/handler.go:990 — HandleDeliver accepts the by-id delivery into the durable inbox

### CT-03 — crier → node

- **Carries:** inbox message + lease
- **Mode:** pull; **retrieval grants the lease — delivery does not**. The 30 s lease is the
  retrieve default and is requester-adjustable (M11 leases 1800 s); it is not a delivery or
  job-runtime bound. The historical "nothing beyond 30 seconds" claim is scoped to its
  historical mode/version, not a universal task-runtime assumption
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the node worker (M2 §6) and the dispatcher (M11 §6) are the two consumers
- **Sender guarantee:** crier internal/registry/handler.go:1690 HandleRetrieve — the lease-granting retrieval (delivery at handler.go:990 writes the durable inbox and starts no lease); default lease 30 s at :1732-1743, requester-adjustable
- **Receiver requirement:** scripts/node-bus-worker.py:1356,1383 — signed GET /agents/<id>/inbox retrieve, then /inbox/ack

### CT-04 — node → crier

- **Carries:** reply: status, dispatch_id, corr_id, branch, commit, artifacts
- **Mode:** async, signed
- **State:** PARTIAL
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** transport works; settlement reads only `ok` — CF-355 open (M2 §6, M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace the RED line with those citations.

### CT-05 — foreman → scheduler

- **Carries:** the lane's prompt text and skills it may load
- **Mode:** seeded config
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** both ends in-repo (load_lane_config.py:31 → spawn.go:1249 buildForemanPrompt); the "3 of 14 lanes disagree" breakage was never measured (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `scheduler`, then replace the RED line with those citations.

### CT-06 — crier → scheduler

- **Carries:** completion event for a finished run
- **Mode:** async
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** the dispatcher leg works — it always sends `ok`, the field dispatchReplyVerdict reads (M11 §6)
- **Sender guarantee:** crier internal/registry/handler.go:170,1452 — the answering message carries ReplyTo correlation into the scheduler's durable inbox
- **Receiver requirement:** internal/scheduler/dispatch_leg.go:713 — dispatchReplyVerdict reads the correlated payload's ok (first message wins, :428)

### CT-07 — router → gateway

- **Carries:** model choice for a prompt
- **Mode:** in-band
- **State:** UNVERIFIED
- **Sends because:** Which model answers a prompt; lane chains, caps, PAYG ordering
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** boundary — neither side has an in-repo file:function; the wire was not measured (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `router` commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `router` and the decode/validate site in `gateway`, then replace the RED line with those citations.

### CT-08 — crier → gateway

- **Carries:** hermes-session delivery (message becomes a session turn)
- **Mode:** sync — the "30 s" figure belongs to the historical cluster-baseline mode/version;
  the selected mode/version owns its own HTTP/session/timeout clocks, stated independently
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** crier side named — hermesession.go:353 Client.Deliver (M10 §6)
- **Sender guarantee:** crier internal/hermesession/hermesession.go:353 — Client.Deliver; :554 POSTs /api/sessions at the gateway origin
- **Receiver requirement:** hermes gateway/platforms/api_server.py:1763 — POST /api/sessions creates the session row from the delivered message

### CT-09 — node → duckbrain

- **Carries:** R1 run record, R2 fleet index
- **Mode:** http, x-api-key
- **State:** MISSING
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** node-bus-worker has zero DuckBrain calls (CF-329, M2 §6) — but that absence in a transport worker does NOT establish the Factory has no memory path: the expected producer is the Bunker foreman/projection flow (e.g. the scheduler's execution_projections duckbrain sink), and the register row must be re-assessed against that path, installation, auth, namespaces and shared-view semantics — not against one worker's writes
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `duckbrain`, then replace the RED line with those citations.

### CT-10 — node → board

- **Carries:** row event with run_id and outcome
- **Mode:** append
- **State:** BROKEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the node worker writes no board rows — no in-repo producer (M4 §6). That absence does not make the board path BROKEN system-wide: the expected board-event producer is the Bunker foreman/projection flow, not the node bus worker; the state is scoped to this producer/consumer pair until re-assigned and measured
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-11 — node → sessionstore

- **Carries:** every turn, model, tokens
- **Mode:** writes via gateway
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Every model turn, its model, tokens and cost
- **Measured defect:** boundary — both ends are the Hermes runtime, out of scope (M2 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `sessionstore` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `sessionstore`, then replace the RED line with those citations.

### CT-12 — node → gitreins

- **Carries:** staged diff
- **Mode:** pre-commit hook
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Measured defect:** the hook side is named (install-gitreins.sh:124); hook enforcement — that git invokes it — is unproven (M3 §6, M3 §11)
- **Sender guarantee:** scripts/install-gitreins.sh:124 — the pre-commit hook pins $VENV/bin/gitreins guard --quality-async on every seeded repo
- **Receiver requirement:** RED — what `gitreins` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `gitreins`, then replace the RED line with those citations.

### CT-13 — gitreins → board

- **Carries:** verdict that closes a row
- **Mode:** human/foreman action
- **State:** UNVERIFIED
- **Sends because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** completion requires --evidence-run-id (boardctl update); the verdict→close path was not re-run (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `gitreins` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `gitreins` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-14 — foreman → board

- **Carries:** row created, row closed, evidence
- **Mode:** boardctl
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the store is measured (357 rows / 520 events); the foreman write wire is not exercised in this repo (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-15 — foreman → duckbrain

- **Carries:** decisions, findings, goal
- **Mode:** mcp / http
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** boundary — the foreman lane and the duckbrain service are out of scope (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `duckbrain`, then replace the RED line with those citations.

### CT-16 — docsgate → handbook

- **Carries:** module status word
- **Mode:** read at build
- **State:** UNVERIFIED
- **Sends because:** Whether a document is citable (sections, locators, facts, earned VERIFIED) — a structural gate, not a truth verifier (M6 §2 F6-2)
- **Receives because:** The readable system description plus its own deficiency register
- **Measured defect:** a structural gate, not a truth gate (M6 §6 F6-2); downgraded from PROVEN — the handbook build reads no MASTER-DOC output, so the receiver half is uncited
- **Sender guarantee:** scripts/master_doc_check.py:263 — prints MASTER-DOC: PASS|FAIL and exits 1 on FAIL
- **Receiver requirement:** RED — what `handbook` accepts and rejects is not stated here.
- **To close:** quote the encode site in `docsgate` and the decode/validate site in `handbook`, then replace the RED line with those citations.

### CT-17 — conformance → harness

- **Carries:** per-leg verdict (check, apply, smoke, vars, memory)
- **Mode:** executed
- **State:** UNVERIFIED
- **Sends because:** Whether a harness is supported, measured per leg on a real node (M5 §2)
- **Receives because:** The coding loop inside the node (hermes, codex, claude-code, opencode, pi, dsh) at pins (M5 §2)
- **Measured defect:** not run this round (needs a live node); vars and memory had no executor (CF-328) (M5 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `conformance` commits to.
- **Receiver requirement:** RED — what `harness` accepts and rejects is not stated here.
- **To close:** quote the encode site in `conformance` and the decode/validate site in `harness`, then replace the RED line with those citations.

### CT-18 — handbook → owner

- **Carries:** the approval artifact
- **Mode:** read
- **State:** UNVERIFIED
- **Sends because:** The readable system description plus its own deficiency register
- **Receives because:** Intent, priorities, approval
- **Measured defect:** the legacy renderer hardcodes docs/master and does not select the M*.md chapters (M6 §6). CT-18's contract is a revisioned delivery/decision receipt — an observable human/external boundary, specifiable without inventing an internal encode function for the owner
- **Sender guarantee:** RED — no `file:line` in the model states what `handbook` commits to.
- **Receiver requirement:** RED — what `owner` accepts and rejects is not stated here.
- **To close:** quote the encode site in `handbook` and the decode/validate site in `owner`, then replace the RED line with those citations.

### CT-19 — node → proxy

- **Carries:** chat completion with a node bearer token
- **Mode:** http, bearer node token
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Measured defect:** proxy side verified (401 without a token); the node client half is config-wired, no call site in this repo (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `proxy` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `proxy`, then replace the RED line with those citations.

### CT-20 — proxy → gateway

- **Carries:** forwarded inference with the control-host key
- **Mode:** http, 300 s timeout
- **State:** UNVERIFIED
- **Sends because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** external boundary — the upstream is a rumour with one side named; healthy streams are unframed to completion, F12-7 (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `proxy` commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `proxy` and the decode/validate site in `gateway`, then replace the RED line with those citations.

### CT-21 — github → node

- **Carries:** installation token installed at auth/github.token, mode 0600
- **Mode:** https api, JWT mint
- **State:** UNVERIFIED
- **Sends because:** Mints, caches and refreshes GitHub App installation tokens; never a token in argv (M7 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the mint was never run on this host (no App creds); the consumer is the node's credential file, not a function (M7 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `github` commits to.
- **Receiver requirement:** RED — what `node` accepts and rejects is not stated here.
- **To close:** quote the encode site in `github` and the decode/validate site in `node`, then replace the RED line with those citations.

### CT-22 — node → crier

- **Carries:** agent registration + token exchange
- **Mode:** https, POST /agents
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** the in-repo producer half is not established; crier HandleRegister/HandleRegisterByID named (M1 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace the RED line with those citations.

### CT-23 — provisioner → bunker

- **Carries:** create, exec, cp against the agent container
- **Mode:** bunker CLI
- **State:** UNVERIFIED
- **Sends because:** Qualifies the host (disk floor), creates the container, mints identity, seeds prompts/skills/env, connects the bus (M1 §2)
- **Receives because:** Hosts agent containers; create/exec/cp; per-agent home
- **Measured defect:** short create/exec/cp calls measured across M1's batteries (M1 §6); downgraded from PROVEN — the daemon's accept side has no in-repo file:function to cite. CT-23's normative contract rests on the pinned Bunker public CLI/proto interface (observable request/response/stream/exit/auth/capability semantics with versioned integration evidence); the external daemon's internal functions need not be invented as an in-repo consumer
- **Sender guarantee:** scripts/bunker-provision.sh:504 — the node-create.sh stage drives create/exec/cp against the agent container
- **Receiver requirement:** RED — what `bunker` accepts and rejects is not stated here.
- **To close:** quote the encode site in `provisioner` and the decode/validate site in `bunker`, then replace the RED line with those citations.


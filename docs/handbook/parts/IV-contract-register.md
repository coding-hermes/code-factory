# Part IV — Contract register

Every interface that can change the behaviour or correctness of a run, named once.
`CT-nn` is the canonical id used by every chapter; a chapter that names one of these
interfaces must use this id, not one of its own.

A contract's source coverage and runtime qualification are separate. A locator can
establish an implementation site, never a PROVEN wire. §IV.2.4 requires a version-bound
positive/negative execution record for qualification; external and human boundaries
use observable receipts rather than invented in-repository functions. Missing evidence
remains RED/UNVERIFIED even when the target specification is complete.

The normative target contract is specified independently of implementation coverage.
The detailed entries below retain measured producer/consumer citations and explicitly
mark missing evidence; the contract cards in §IV.1 define the behavior an implementation
must provide. A citation cannot replace a field, validation rule, state transition,
error, idempotency key, persistence boundary or recovery rule.

## IV.0 Canonical execution model and vector source

`docs/SYSTEM-MODEL.yaml#execution_contracts` is the canonical ownership, record,
authority, timing, settlement, evidence and telemetry model. The single normative source
for executable examples is `docs/handbook/contract-vectors.json`. Later chapter examples
reference those vectors rather than maintaining independent field sets or constants.
Fixture results do not claim live adapter or deployment qualification.

The vector file covers every static control: SC-01 Crier's 60-second lease; SC-02 the
20,000 worker-attempt allowance; SC-03 whole-record memory digests; SC-04 criterion and
atomic group claims; SC-05 the resident supervisor request; SC-06 seq-zero inference;
SC-07 the signed Crier read; SC-08 backup expiry; and SC-09 independent turn and attempt
timeouts. Pass 7 adds SC-10 the LCR-1 layer contract, SC-11 the split request and replay
domains, SC-12 the three-object custody chain, SC-13 the canonical group claim, SC-14 the
role-discriminated memory envelope, SC-15 and SC-16 the two total projection tables,
SC-17 phase-discriminated cancellation, SC-18 phase-discriminated evidence, SC-19
enrolment identity allocation and SC-20 the configuration generation. SC7-01, named by
`docs/handbook/PASS7-PLAN.md` §3.9, asserts that the launch identity graph has no cycle.
The same file covers authority transitions, terminal settlement, M7 telemetry,
publication-versus-judgment evidence, signed profiles and containment.

The following resolutions govern every card and registry entry below:

* `total_budget` is the round-wide worker-attempt allowance, range 0–20,000 inclusive;
  concurrency is independent. Round, attempt and turn deadlines compose by minimum,
  never by multiplying turn timeout and turn count. `policy.round_wall_s` is retired.
* A round report uses exactly `allowance`, `consumed`, `reserved` and `remaining` for
  worker-count accounting, with `remaining = allowance - consumed - reserved`. The worker
  ledger state `charged` is the representation counted by `consumed`; a refused admission
  has no reservation or charge and leaves `consumed` unchanged.
* The supervisor protocol is `supervisor.v1` at
  `$HOME/.local/state/factory/supervisor/control.sock`. Launch identity follows LCR-1
  (§IV.2.5): the foreman preallocates `launch_id` and a nonce; the supervisor derives
  `execution_key` and `dispatch_id` once from `{launch_id,input_digest}` after persisting
  the commitment. `launch_id` is not derived from a launch digest and `dispatch_id` is
  never an input to one. The `cf.supervisor.v1` draft is not an alternate protocol.
* Factory custody uses signed `custody.v1` operations with a 30–300-second lease,
  60-second default, 20-second renewal and 5-second bounded renewal call. The
  `CF2A-CRIER-1` profile binds method, path, RFC3339 timestamp, `sha256:` body digest
  and audience; request ID plus idempotency key is the replay nonce. The 1–30-second
  retrieve shorthand and unsigned/audience-free reads are retired. A custody response is
  three objects — unsigned payload, receipt, signed envelope — and the response hash never
  covers the receipt (§IV.2.8).
* Request identity and replay identity are separate named digests with one declared
  excluded-field list (§IV.2.7). An operation that uses one value for both declares the
  pairing; a consumer may not assume it.
* Criterion uses exactly `id`, `description`, `argv`, `cwd`, `timeout_s`,
  `expected_exit` and `oracle_digest`; legacy `text`/`verification` is migration evidence,
  not an executable criterion. Group claims use one protected CAS for every row,
  event and marker; a loser launches no partial wave. A group has exactly one bound (256),
  one ordering (ascending bytewise `task_id`) and one object-id form (§IV.5.3).
* Evidence is phase-discriminated: `staged`, `source`, `integrated`, `publication` and
  `closure` are different records with different subjects, and a staged record never
  names a commit that does not exist yet (§IV.5.2).
* Memory `payload_digest` hashes the complete `memory-record.v1` except that digest field.
  Worker, wave, round and resolution bodies are discriminated; mutable synchronization
  receipts are separate. Body-only hashes are not the same version. The round summary and
  the final report are two records in one chain, not one record written twice (§IV.5.5).
* Worker execution, mechanical policy, model judgment, publication and settlement are
  separate evidence classes. Uncertain judgment does not rewrite mechanical results;
  uncertain publication blocks closeout without becoming a push failure. Settlement is
  total over the outcome lattice — including a uniformly unverified round and a
  zero-budget round, neither of which settles as success (§IV.6.2).
* Cancellation is recorded in the phase where it landed, and a cancellation after the
  terminal state changes nothing (§IV.5.6).
* M12 inference starts at `seq = 0`, settles usage before terminal and treats `[DONE]`
  only as an end marker. Backup expiry aborts and holds writers until a fenced recovery
  decision; it never releases on local capture alone.

Where an older card or example below uses a retired alias, this section and the canonical
model replace that alias. The registry entries are updated to the same field unions;
historical implementation citations remain coverage evidence, not alternate schemas.

## IV.1 Normative contract cards

All cards use the outer envelope `cf2a.v1`: exactly `schema_version`,
`message_type`, `request_id`, `corr_id`, `sender`, `created_at`, `body`.
`schema_version` is the literal `cf2a.v1`, never the body version. `request_id`
identifies a request at its owner boundary; `corr_id` correlates the whole round.
Part I §1.9.1 fixes the manager routes and HTTP framing. §IV.2 below defines
lexical types, the closed body-version registry, typed responses, canonical bytes
and shared failure rules. The six execution bodies are not a restriction on the
other registered domains. Unknown keys/versions refuse; extensions are accepted
only at the explicitly listed object positions and with registered members.
Transport response status is not a worker verdict. Secret values never enter an
envelope; M1 §17 defines credential-reference exchange and authentication.

Identity ownership is explicit: the controller creates `registration_id` and the class-`crier`
`credential_ref` at enrollment, and the Crier registrar alone admits `register.v1` and
allocates the node identity;
the scheduler creates `round_id` and `run_id` at admission; the foreman creates
`wave_id` after admission, allocates `launch_id` and the launch nonce, and creates
`attempt_id` immediately before worker launch; the Crier
creates `delivery_id` and `lease_id` at custody; the supervisor derives `dispatch_id` and
`execution_key` from the persisted launch commitment (§IV.2.5), so no component reserves
an identity it does not own; and the foreman creates the final `report_digest`. Enrollment and round
admission therefore do not require future wave, worker or attempt identities.

The following cards summarize roles, not additional wire field sets. IV.2 supplies
the closed typed bodies and results; M1–M6 supply the referenced operation protocols.

| Contract | Request / result synopsis | State, refusal and persistence rule |
|---|---|---|
| `CT-01` | `config_version`, `lane`, `enabled`, `admission_mode`, `cadence_s`, `weight`, `pin`; result `accepted`, `effective_config_version` | validate enum/ranges before persistence; stale generation is `GENERATION_CONFLICT`; accepted configuration is durable before admission |
| `CT-02` | `round-admission.v1`: `round_id`, `run_id`, `corr_id`, `task_scope`, `total_budget`, `config_generation`; result `accepted`, `deferred`, or typed refusal | scheduler persists the admission before sending; future wave/worker/attempt IDs are absent; Crier deduplicates the envelope custody by `(run_id,corr_id)` |
| `CT-03` | signed `custody.v1` retrieve/renew/ack with registration generation, poll/delivery/lease identity and result receipt | retrieve leases 30–300 s (default 60), renews every 20 s with a 5 s bounded call, replays `(agent_id,poll_id)`; expired lease is `LEASE_EXPIRED`; unavailable custody is never an empty inbox |
| `CT-04` | `worker-result.v1`: execution identity, status, commit, artifacts, evidence and finish time; result accepted/duplicate/result_digest receipt (IV.2) | status is typed (`pass`, `fail`, `unverified`, `partial`, `unknown`); missing status is `INVALID_RESULT`; first durable result wins and conflicting duplicates are `RESULT_CONFLICT`; clean exit without a committed result is `UNKNOWN_RESULT` |
| `CT-05` | `worker-brief.v1`: `round_id`, `wave_id`, `task_id`, `attempt_id`, `brief_ref`, `brief_digest`, `criteria`, `workspace`; result `accepted`, `BRIEF_INVALID` | foreman owns wave/attempt IDs; `brief_ref` and `brief_digest` bind the immutable `cf.brief-input.v1` JCS bytes; acceptance is custody, not execution success |
| `CT-06` | `round-report.v1` reference: `round_id`, `corr_id`, `report_digest`, `status`, `finished_at`; result scheduler settlement | scheduler accepts only a correlated durable report; absent or conflicting verdict is `UNKNOWN_RESULT`, never success; settlement precedes next cadence decision |
| `CT-06R` | foreman report `round-report.v1`: `round_id`, `run_id`, `corr_id`, `waves`, `task_results`, `budget`, `stop_reason`, `memory_refs`, `evidence_refs` | foreman writes local custody and memory records before return; duplicate `(round_id, report_digest)` is replayed, conflicting report is refused |
| `CT-07` | `model`, `provider`, `lane`, `policy_generation`; result selected model or `MODEL_NOT_ALLOWED` | allowlist and policy generation are checked before spend; selection is recorded with the session |
| `CT-08` | `session_id`, `corr_id`, `message_ref`, `model`, `selection_id`; result `accepted`, `session_turn_id` | gateway acknowledges durable session custody; timeout is `DELIVERY_UNKNOWN` and replay uses the same idempotency key |
| `CT-09` | canonical `memory-record.v1`: record/project/namespace/round ids, discriminated type, scoped ids, writer, local sequence, fence, body and payload_digest; result MemorySyncReceipt | local fsync is durable local-only acknowledgement; digest covers the complete record except payload_digest; sync is pending/qualified/failed/partial/conflict; same digest merges once, changed digest preserves conflict evidence |
| `CT-10` | canonical `cf.board-group-claim.v1`: board revision, ordered claim preconditions, owner fence, lease and operation identity; at most 256 claims, `created_seq` then `task_id` | one protected CAS commits every row, event and marker or none; stale revision is `CLAIM_CONFLICT`; remote readback precedes native start and no partial wave launches; a duplicate claim, a reversed order, a paraphrased ordering or an abbreviated object id is refused (§IV.5.3) |
| `CT-11` | `session_id`, `turn_id`, `model`, token usage, cost basis; result durable turn row | gateway writes the turn atomically or returns `PERSISTENCE_UNAVAILABLE`; no usage row is inferred from a transport receipt |
| `CT-12` | staged-tree digest, exact commit candidate, guard version and criteria | guard emits a named verdict bound to the staged tree; missing gate is `GATE_UNAVAILABLE`; no verdict means no closeout |
| `CT-13` | verdict `{run_id, criteria, outcome, evidence_refs, tree_digest}`; result board closeout | board accepts only an evidence-bound verdict whose tree digest matches the landed tree; duplicate closeout is a no-op, conflicting closeout is `CLOSEOUT_CONFLICT` |
| `CT-14` | row/event mutation with `task_id`, `expected_revision`, actor, criteria and evidence | foreman is the task-state writer; claim/close requires CAS and lease/fence; malformed, cyclic or stale updates are refused and never partially applied |
| `CT-15` | memory decision/finding with stable `record_id`, namespace, correlations and evidence | designated foreman writer persists worker, wave and round records separately; remote outage yields durable local pending state, not loss or completion |
| `CT-16` | complete cf.handbook-receipt.v1 from M6 §16.2; result custody/acceptability receipt | a receipt says what was checked, not that the owner approved it; absent or failed required checks is `BUILD_NOT_ACCEPTED`; CT-18 alone carries the owner decision |
| `CT-17` | conformance leg `{profile, harness, pin, leg, result, evidence}`; result support state | every leg is independently `PASS`, `FAIL` or `UNVERIFIED`; a missing leg cannot be promoted to supported |
| `CT-18` | delivered artifact plus CT-16 receipt; authenticated cf.handbook-decision.v1 (M6 §16.3) | owner receives a complete receipt; approval is a separate exact-hash human decision and is never inferred from build success |
| `CT-19` | node token reference, `model`, request body, `corr_id`; result finite stream or typed HTTP error | token scope/expiry is checked before upstream work; revoked/expired token is `UNAUTHORIZED`; cancellation stops upstream work where supported and is recorded |
| `CT-20` | proxy request with model policy, control-host credential reference and upstream correlation | proxy owns provider-key custody and usage accounting; upstream errors before/after headers are distinct, and capture failure follows configured redaction policy |
| `CT-21` | provider/app identity, repository scope, credential reference, destination profile; result fingerprint, expiry, scope | issuer and installer remain distinct; wrong scope/mode is refused; renewal overlaps safely, revocation prevents restore from reactivating the credential |
| CT-22 | `cf2a.v1` envelope with `register.v1` body: registration_id, agent_id, project_id, operation_id, expected_generation, profile_id, public_identity, capabilities, idempotency_key (§IV.2.1); the authority/controller creates `registration_id` and the single-use `enrollment-grant.v1` `credential_ref`, while Crier admits and allocates the node identity; the registrar's individual registration read is `GET /v1/factory/registrations/{registration_id}` | first expected_generation=0 allocates exactly 1; identity class is checked before allocation; same `(registration_id,operation_id,generation)` and request digest replays; changed tuple or digest is `REGISTRATION_CONFLICT`; M1 §17.1 and Part I §1.9.11 define trust, credential exchange, worker refusal and lost-reply readback |
| `CT-23` | pinned Bunker CLI/protocol request `{agent_id, operation, image/profile, request_id}`; result typed exit/status, stdout/stderr digest and capability readback | create/exec/cp are scoped to the agent; unsupported capability is refused; retries use the same request id and cannot duplicate a create |
| `CT-24` | `config.update` in the `cf2a.v1` envelope with `factory.v1` body `{operation_id, idempotency_key, expected_generation, scope, project_id, node_id, desired}`; result `{operation_id,generation,scope,desired_digest}` | the Factory manager is the single writer; file proposals and API requests use the same authenticated CAS; stale generation is `GENERATION_CONFLICT`, changed idempotency digest is `IDEMPOTENCY_KEY_REUSED`, and accepted desired state is durable before reconciliation (Part I §1.9.1; M12 §19) |
| `CT-25` | manager observed readback `{scope, adapter_id, observation_id, observed_at, values, quality}`; result effective state | observations are immutable; stale/partial quality is visible and cannot establish convergence |
| `CT-26` | reconcile `{generation, operation_id, idempotency_key}`; result per-adapter plan and status | `accepted → planned → applying → converged/degraded/failed`; each transition is durable and idempotent; same key/different digest is `IDEMPOTENCY_KEY_REUSED` |
| `CT-27` | allocation request `{project_id, requirements, eligible_hosts, desired_count}`; result reservations and exact shortfall | allocation is deterministic and preserves desired count; insufficient capacity is `ALLOCATION_SHORTFALL`, not silent lowering |
| `CT-28` | manager-owned `binding.prepare.v1` / `binding.commit.v1`: `{project_id, binding_generation, owner_fence, readiness_ref, readiness_digest, crier_ref, scheduler_ref, prepared_digest, active_digest}`; result participant receipts plus manager active pointer | manager is the sole activation authority: durable participant candidates/receipts precede pointer CAS+fsync; exact tuple readback from manager, Crier and Scheduler is required; stale owner/generation is `STALE_OWNER`, mismatch is `BINDING_NOT_ACTIVE`, changed replay is `BINDING_CONFLICT`, and admission remains fail-closed until convergence |
| `CT-29` | incident/recovery `{incident_id, scope, owner_fence, checkpoint, replacement}`; result resumed/degraded/failed | old owner is fenced before replacement side effects; crash recovery re-reads state and applies only missing idempotent steps |
| `CT-30` | manager event/metric readout `{event_version, event_id, event_type, scope, payload}` or `{metric_schema_version, samples, observed_at}` | event delivery is per-endpoint durable and replayable; missing metrics are `unknown`, not zero; receiver interpretation remains external |
| `CT-31` | gateway config envelope merged into each Bunker's `~/.hermes/config.yaml`: `platforms.<platform>.{enabled, token_env, home_channel{platform, chat_id, thread_id, name}, allowed_chats}` plus `gateways.loop_watchdog`; pairs with the scheduler row keys `deliver` / `deliver_mode` as a routing hint | **SPEC-DERIVED (M13)** — token custody is by reference: generated files carry zero token bytes (M13 R2); scheduler routing and chat delivery are independent (M13 R3); an unresolved reference is `GATEWAY_TOKEN_REF_UNRESOLVED` (warning, lane runs scheduler-only) and a dead token fails fast with a named error (M13 R6); the schema is platform-agnostic, Telegram first (M13 R5) |

**Resident Crier launch/return adapter (selected MVP path).** The scheduler persists a
`round-admission.v1` envelope and sends it through Crier. Crier authenticates the
sender, stores custody, and returns `delivery_id`; the project Bunker foreman retrieves
it under a lease, creates waves and attempts only after admission, and returns one
signed `round-report.v1` through Crier. Crier stores the report and forwards its
`report_ref` to the control-host scheduler. The scheduler reads the report by
`(round_id, corr_id, report_digest)`, settles only after the report and its referenced
memory/evidence receipts are durable, and records `UNKNOWN_RESULT` on timeout or
conflict. A node-pull/central-dispatcher implementation may translate these schemas
for compatibility, but it does not become a new MVP authority.

## IV.2 P5 wire types, schemas and evidence qualification

This profile resolves P5-B-01/08/09/10/21/35/37/38. All members named in a type
are required unless explicitly marked optional; null is legal only in an `or null`
union. Objects are closed, arrays preserve order, and empty arrays are legal unless
a minimum is stated. JSON uses UTF-8 without BOM; duplicate JSON keys, non-finite numbers,
invalid Unicode scalars and payloads over 1048576 bytes are rejected before effects.
Large artifacts travel through EvidenceRef, never inline. Integer range is
0..9007199254740991 (UInt), 1..9007199254740991 (PosInt); booleans are not integers.
Text is a Unicode string of 1..65536 UTF-8 bytes, no NUL. ID matches
`[A-Za-z0-9][A-Za-z0-9._:-]{0,127}`; Error.code instead matches `[A-Z][A-Z0-9_]{0,127}`.
Time is canonical UTC `YYYY-MM-DDTHH:MM:SS[.sss]Z` with real calendar values and
no leap second; seconds are integer SI seconds unless explicitly fractional.
SHA is exactly 64 lowercase hex characters. GitOID is `{algorithm:sha1/sha256,
value:hex}` with exactly 40 or 64 lowercase hex characters respectively.
Base64url32/64 decodes to exactly 32/64 bytes without padding (RFC 4648).
AbsolutePath starts `/`, has no NUL, `.` or `..` components; relative paths also
forbid leading slash and empty components. GitRef is a fully qualified
`refs/heads/...` passing Git ref-format validation. HTTPSURL forbids credentials,
fragment and non-HTTPS schemes. DNS is an ASCII hostname with labels 1..63 bytes,
no wildcard, maximum 253 bytes. No implicit coercion is permitted.

Repository is `{forge:github/gitlab,host:DNS,owner:ID,repo:ID,ref:GitRef,commit:GitOID}`.
Fence is Part I §1.9.3's `{authority_id:ID,project_id:ID,epoch:PosInt,owner_id:ID}`;
M7 §17–17.1 defines the shared resource-side effect gate and deterministic oracle,
not a second Fence or wire version. Target fencing is UNIMPLEMENTED/runtime UNVERIFIED.
EvidenceRef and CredentialRef are M3 §17.4 and M1 §17.1; a bare SHA in Part I's
manager `Probe.evidence_ref` is the digest component of EvidenceRef in that probe's
project scope, not another storage scheme. Artifact is `{name:ID,ref:EvidenceRef,
media_type:Text,size_bytes:UInt}`. Workspace is `{repository:Repository,
base:GitOID,relative_path:relative-path}`; relative_path resolves under the enrolled
node's `worktrees` directory and cannot name any other project. Criterion is the closed
Criterion in the canonical execution model; M4 §15.1 owns its board storage and validation.
LaneSeed is `{prompt_digest:SHA,skills:[{name:ID,digest:SHA}]}` with unique names
and meaningful skill order. Limits is `{max_turns:integer[1,10000],
turn_timeout_s:integer[1,86400],attempt_timeout_s:integer[1,86400],
cpu_millis:PosInt,memory_bytes:PosInt,max_output_bytes:PosInt}`. Defaults, when the
whole limits object is omitted from policy proposals, are 40,1800,1800,1000,
4294967296,10485760 respectively; wire execution requests carry the fully materialized
object. EffectiveSettings is `{model:Text,provider:ID,base_url:HTTPSURL,credential_ref:ID,
namespace:ID,run_id:ID,lane:ID,skills_digest:SHA,max_turns:integer[1,10000],
turn_timeout_s:integer[1,86400],attempt_timeout_s:integer[1,86400],cpu_millis:PosInt,
memory_bytes:PosInt,max_output_bytes:PosInt,network_policy_digest:SHA,release_lock_digest:SHA}`.
Resource narrowing/enforcement is M5 §16.2. total_budget is RoundAllowance,
integer[0,20000] worker-attempt slots, not dollars, seconds or concurrency; the pinned
retry policy decides consumption. RoundAdmission.deadline_s and round_deadline bound the
whole round. attempt_wall_s bounds one attempt independently; turn_timeout_s and
max_turns bound individual turns and their count. policy.round_wall_s is retired.

BriefInput is the closed object `{schema_version:"cf.brief-input.v1",directive:Text,
task:TaskRow,criteria:Criterion[1..100],skills:[{name:ID,ref:EvidenceRef,digest:SHA}],
attachments:Artifact[]}`. The Factory foreman/manager owns its construction and persists
its exact immutable bytes at accepted admission. TaskRow is the exact admitted M4
snapshot, not a later board read. Criteria match that snapshot by id/description/order;
skills preserve declared order; attachment names are unique and attachment order is
explicit. The receiver fetches each skill and attachment from project CAS by its
reference before start; skill bytes must hash to `digest`, and attachment bytes must
match both `size_bytes` and their reference digest. The complete object is serialized once
with RFC 8785 JCS as UTF-8, sorted keys, compact separators, no BOM and no trailing LF.
`brief_digest` is lowercase SHA-256 over exactly those bytes; `brief_ref` addresses those
same bytes.
Whitespace and Unicode string bytes are preserved. A transport decoder verifies the
recovered UTF-8 bytes, never base64 text or a reconstructed summary. Missing/changed
content is refused before reservation/native start. `worker-brief.v1` carries the ref
and digest but does not redefine their meaning; identical retries replay the original
receipt without reserving or starting again, while changed content is
`DIGEST_MISMATCH`/`LAUNCH_CONFLICT`. CV-01-B is the shared deterministic vector.

A foreman-role BriefInput uses a synthetic read-only task snapshot naming the round whose
acceptance_criteria require a complete CT-06R report; this snapshot and ordered authorized
task IDs are persisted at admission and cannot widen task_scope. It is never appended as
a real board task.

### IV.2.1 Requests, responses and closed body registry

Every mutation body contains schema_version (the row's literal) and idempotency_key
(ID) in addition to the members below. A declared type's schema_version is not added
twice. The outer message_type is the verb below, response uses the same verb, and
sender matches authenticated identity. HTTP status follows Part I §1.9.1. ResponseBody
is exactly `{schema_version:<request-body-version>,status:ok/accepted/error,
data:<row-result-type> or null,error:Error or null}`. `accepted` means durable async custody;
`ok` means a completed protocol operation, not execution pass. Error is exactly
`{code:ErrorCode,message:Text,retryable:boolean,field:JSON-pointer or null,
current_generation:UInt or null}`; successful response has error=null, failure has
non-null error. Duplicate success returns the original protocol response; data includes
duplicate=true only on the explicitly specified execution/result receipts. The immutable
original receipt remains available by request_id. Transport must not convert fail into ok
execution. Empty/error malformed requests echo validated IDs when available; otherwise
request_id and corr_id are server-allocated diagnostic IDs and no effect is admitted.

The following is the type registry. A referenced chapter section is a type
expansion, not permission to choose fields. Source filenames in historical coverage
are not type definitions. Manager CT-24–30 use the exact routes, typed configuration,
Observation/Operation/Readiness, allocator vectors and event samples of Part I §1.9
and Part V §V.0, not the earlier card shorthand `desired_generation` aliases.

**Complete-schema acceptance rule (P5G-15; F1, F2, F5, F8, F13 and F16).** The
machine-readable schemas under `docs/handbook/conformance/schemas/` are the shape
authority for every nested request and response named by CT-01–CT-30. The registry,
`docs/SYSTEM-MODEL.yaml`, Part I §1.9, M1 §17, M4 §15 and Part V §V.9 are normative
projections of those same types; they may explain ownership and recovery but may not
introduce a field, alias, enum, bound or alternate version. `factory.v1` is the
canonical desired-state document (Part V); `cf.config.v1` is its normalized,
origin-bearing persisted configuration record (the CT-24/CV-24-A record), not a
competing desired-state wire. `cf2a.v1` is the outer transport envelope, and the
body version is always the registered type in the table below.

For every object: all listed members are required unless the type says optional or
`or null`; omission, explicit null and empty string/array/map are distinct and use
only the semantics stated by that type. Objects are closed (`additionalProperties`
false) except the named `extensions` maps; unknown keys and duplicate keys are
refused before side effects. Arrays preserve order unless explicitly called sets;
sets are unique and bytewise sorted. Enums are closed, booleans are not integers,
units are part of the field name or type (`*_s` seconds, `*_bytes` bytes,
`*_gib` binary GiB, worker budget slots, micro-USD per million tokens), and no
implicit string/number coercion is allowed. A response is the typed
`ResponseBody` in §IV.2.1: success has `error:null`, failure has non-null `error`
and `data:null`; transport status never changes the domain result. The named owner
is the actor that allocates or persists the identity in §IV.1, while the named
producer/consumer and ordering in the CT row determine who may submit and read it.

The shared failure rule is: parse/shape errors are HTTP 400, authentication/scope
errors 401/403, schema/version errors 422, conflicts 409, and unavailable durable
authority 503 with `Retry-After: 5`; the typed error code and JSON pointer are
returned. Validation precedes reservation, CAS, native start or publication. Same
idempotency key plus the same canonical request replays the original receipt with
no second effect; a changed digest returns `IDEMPOTENCY_KEY_REUSED`. A timeout or
lost acknowledgement is an unknown outcome and recovers by readback using the same
identity, never by inventing a new operation. Recovery and ordering are owned by the
flow named in each CT row: F2 resumes durable provisioning stages, F5 revalidates
before publication/closeout, F8 fences and repairs, F13 applies generation/CAS
migration order, and F16 waits for every target receipt before native start.

Independent check: from the repository root run the command in
`docs/handbook/conformance/README.md`; it validates all positive bindings and refuses
all 16 negative arms. Then run `python3 tests/test_p5g15_schema_rules.py`; it loads
`cf2a.board-claim.schema.json`, checks the CV-19-A positive claim, mutates one field
at a time for missing required/unknown/enum/bound/order/duplicate cases, and checks
that the cited version vocabulary and flow ids occur in the normative sources. The
expected final line is `P5G-15 schema rules: PASS`; any accepted negative arm or
term/version drift exits non-zero. The source of executable examples remains
`docs/handbook/contract-vectors.json`, never a chapter-local copy.


| ID / verb / body version | Request fields beyond version/key | Result data and domain rules |
|---|---|---|
| CT-01 / lane.configure / lane-config.v1 | project_id:ID, config_version:PosInt, expected_generation:UInt, lane:ID, enabled:boolean, admission_mode:tasks/cooldown, cadence_s:integer[1,31536000], weight:integer[1,1000], pin:{provider:ID,model:Text} or null, extensions:{lane_seed:LaneSeed} | {accepted:boolean,effective_config_version:PosInt}; maps one lane into whole factory.v1 CAS, never a separate configuration authority; ranges match Part V §V.0.1 |
| CT-02 / round-admission / round-admission.v1 | round_id/run_id/corr_id:ID, task_scope:ID[1..10000] unique, total_budget:RoundAllowance integer[0,20000], config_generation:PosInt, execution:{round_deadline:Time,deadline_s:PosInt,attempt_wall_s:PosInt,turn_timeout_s:PosInt,max_turns:PosInt,concurrency:PosInt,retry_policy:RetryPolicy,launch_reserve_s/transfer_reserve_s/cleanup_reserve_s:UInt}, extensions:{project_id:ID,lane:ID,board_revision:GitOID,binding_generation:PosInt,owner_fence:Fence,lane_seed:LaneSeed} | {disposition:accepted/deferred,delivery_id:ID or null,reason:Error or null}; fixed authorization ceiling matches Part V §V.0.1 worker_budget.total, no wave/attempt IDs; one-use binding grant is separate authenticated transport authorization |
| CT-03 / custody.retrieve / custody.v1 | common:{request_id/idempotency_key:ID,owner_fence:Fence,registration_generation:PosInt}; retrieve:{agent_id:ID,poll_id:ID,limit:integer[1,100] default 10,lease_s:integer[30,300] default 60}; renew:{delivery_id/lease_id:ID}; ack adds result_digest:SHA and result_custody_receipt:EvidenceRef | Signed method/path/timestamp/body-hash/audience transcript; (agent_id,poll_id) replays original messages and lease, renewal runs every 20 s with a 5 s bounded call, unavailable custody is CUSTODY_UNAVAILABLE rather than an empty inbox |
| CT-04 / worker-result / worker-result.v1 | project_id/round_id/run_id/wave_id/worker_id/attempt_id/dispatch_id/corr_id:ID, owner_fence:Fence, execution_key:SHA, status:pass/fail/unverified/partial/unknown, commit:GitOID or null, artifacts:Artifact[], evidence_refs:EvidenceRef[], finished_at:Time, error:Error or null | {accepted:boolean,duplicate:boolean,result_digest:SHA}; pass requires error=null; identical body dedupes, differing body RESULT_CONFLICT; clean exit without a committed result is UNKNOWN_RESULT, not a third verdict |
| CT-05 / worker-brief / worker-brief.v1 | project_id/round_id/run_id/wave_id/worker_id/task_id/attempt_id/dispatch_id:ID, owner_fence:Fence, claim_id:ID, claim_generation:PosInt, brief_ref:EvidenceRef, brief_digest:SHA, criteria:Criterion[1..100], workspace:Workspace, effective:EffectiveSettings, launch:{commitment_ref:EvidenceRef,commitment_digest:SHA,launch_id:ID,nonce:Text} | {accepted:boolean,execution_key:SHA,commitment_digest:SHA,duplicate:boolean}; retrieves exact BriefInput and returns the execution key the supervisor derived from the persisted launch commitment (LCR-1, §IV.2.5); a caller-supplied dispatch_id or execution_key is CONTRACT_INVALID rather than accepted |
| CT-06 / round-settlement / round-report.v1 | round_id/run_id/corr_id:ID, report_digest:SHA, report_ref:EvidenceRef, status:pass/fail/unverified/partial/unknown, finished_at:Time | {settlement:received/awaiting_evidence/postcheck_pending/settled_success/settled_failure/settled_partial/unknown,report_digest:SHA}; this reference variant is discriminated by message_type from CT-06R's full-report variant; verifies CT-06R bytes, evidence/replication and scope before durable settlement; Part I §1.9.9 |
| CT-06R / round-report / round-report.v1 | project_id/round_id/run_id/corr_id:ID, owner_fence:Fence, waves:[{wave_id:ID,state:complete/blocked,attempt_ids:ID[]}], task_results:[{task_id:ID,attempt_id:ID,result_ref:EvidenceRef,status:pass/fail/unverified/partial/unknown}], budget:{allowance/consumed/reserved/remaining:RoundAllowance}, stop_reason:StopReason, round_summary_digest:SHA, summary_memory_ref:EvidenceRef, evidence_refs:EvidenceRef[], status:pass/fail/unverified/partial/unknown, finished_at:Time, report_digest:SHA | {accepted:boolean,duplicate:boolean,report_ref:EvidenceRef}; remaining=allowance-consumed-reserved; status not inferred from process exit; the report names the round-summary digest and its memory ref and carries no memory_refs array (LCR-1, §IV.5.5) |
| CT-07 / model.select / model-selection.v1 | project_id:ID, model:Text, provider:ID, lane:ID, policy_generation:PosInt | {model:Text,provider:ID,lane:ID,policy_generation:PosInt,selection_id:ID}; current allowlist checked before session cost |
| CT-08 / session.deliver / session-delivery.v1 | session_id/corr_id:ID, message_ref:EvidenceRef, model:Text, selection_id:ID | {accepted:boolean,session_turn_id:ID}; same request identity on timeout, durable session before ACK |
| CT-09 / memory.append / memory-record.v1 | record_id/project_id/namespace/round_id:ID, wave_id/attempt_id/task_id:ID or null, record_type:worker/wave/round/resolution/decision/finding, writer:{writer_id:ID,writer_role:owner/manager/foreman/worker/judge/reconciler,writer_generation:PosInt,owner_fence:Fence}, local_seq:PosInt, created_at:Time, body_kind:Text, body:discriminated MemoryBody, relations:[{kind,target}], payload_digest:SHA | MemorySyncReceipt below; local fsync then independent broker sync; digest covers the complete record except payload_digest, the sync receipt and the signature; nullable body fields are present and null, never omitted (§IV.5.4) |
| CT-10 / board.claim / cf.board-group-claim.v1 | operation_id/idempotency_key:ID, project_id/board_id:ID, board_revision:GitOID, owner_fence:Fence, ordering:literal, claims:ClaimPrecondition[1..256] where ClaimPrecondition={task_id:ID,created_seq:UInt,expected_revision:UInt,expected_status:pending/in_progress,claim_generation:UInt}, lease_expires_at:Time, transition:claim/renew/release, evidence_refs:EvidenceRef[] | One protected CAS commits every row, event and operation marker or none; CLAIM_CONFLICT names current revision and changed tasks; remote readback precedes native start; the member bound lives in cf2a.board-claim.schema.json maxItems (256) and nowhere else; a duplicate claim, a reversed order, a paraphrased ordering or an abbreviated object id is INVALID_FIELD (§IV.5.3) |
| CT-11 / turn.record / turn-record.v1 | session_id/turn_id:ID, model:Text, input_tokens/output_tokens/cached_tokens:UInt, cost_microusd:UInt or null, cost_basis:list-price/provider-reported/unknown, observed_at:Time | {turn_id:ID,durable_seq:PosInt}; unique session/turn, changed usage is TURN_CONFLICT, unknown cost is null not zero |
| CT-12 / gate.run / cf.gate-request.v1 | run_id:ID, candidate:GitOID, tree_digest:SHA, policy_ref:EvidenceRef, criteria:Criterion[1..100] | M3 §17.1 Verdict; no optional missing required gate |
| CT-13 / board.close / cf.board-close.v1 | operation_id/project_id/board_id/task_id/claim_id:ID, claim_generation:PosInt, owner_fence:Fence, expected_revision:UInt, board_revision:GitOID, completion:Completion | {new_revision:PosInt,board_revision:GitOID,closure_receipt_ref:EvidenceRef}; M4 Completion + M3 §17.3 parent certification |
| CT-14 / board.mutate / cf.board-mutation.v1 | operation_id/project_id/board_id/task_id:ID, expected_revision:UInt, board_revision:GitOID, owner_fence:Fence, row:TaskRow, event:Event | {new_revision:PosInt,board_revision:GitOID}; M4 state transition/CAS; actor may not spoof authenticated principal |
| CT-15 / memory.append / memory-record.v1 | same CT-09, record_type=decision/finding/wave/round/resolution, same writer object | same MemorySyncReceipt; foreman is writer, not transport worker; the round body carries no report_digest and no memory_ref (§IV.5.5) |
| CT-16 / handbook.build / cf.handbook-build.v1 | M6 §16 build request/receipt schemas | M6 build receipt; no owner decision occurs on this edge |
| CT-17 / harness.qualify / cf.harness-conformance.v1 | M5 §16.4 complete report | {support_state:SUPPORTED/UNSUPPORTED/UNVERIFIED,report_ref:EvidenceRef,expires_at:Time}; exact required union, live/fixture separation |
| CT-18 / handbook.decide / cf.handbook-decision.v1 | M6 §16.3 decision fields | {decision_ref:EvidenceRef,artifact_digest:SHA,state:accepted/rejected/withheld}; authenticated human action |
| CT-19 / inference.request / POST /v1/chat/completions | schema_version:cf.inference.v1, model:Text, messages:ChatMessage[1..1000], stream:boolean default false, options:{temperature,top_p,max_output_tokens,stop,tools,tool_choice}, request_id:ID, deadline:Time; canonical body <=1048576 bytes and raw transport ceiling <=4194304 bytes | BufferedCompletion or M12 SSE with seq=0 origin, usage then terminal then [DONE]; arbitrary provider options and multimodal content refuse; token scope/expiry checks precede upstream work |
| CT-20 / inference.forward / proxy request identity | CT-19 request plus token_id, upstream_credential_ref:ID, policy_generation:PosInt, upstream_corr_id:ID | same buffered/stream result and served-model identity; serializable budget/slot reservation precedes forwarding, usage commits before complete, response lookup never re-executes |
| CT-21 / credential.install / credential-install.v1 | operation_id:ID, credential_ref:CredentialRef, destination_profile:ID | {fingerprint:SHA,expires_at:Time,scope:ID[],mode:literal "0600"}; M1 §17.1 sealed-fd resolution/readback |
| CT-22 / register / `cf2a.v1` with `register.v1` body | registration_id/agent_id/project_id:ID, expected_generation:UInt, profile_id/operation_id:ID, public_identity:{certificate_der:Text,key_id:ID}, capabilities:ID[1..100] unique | {registration_id:ID,registration_generation:PosInt,expires_at:Time,credential_ref:CredentialRef}; first expected=0 allocates exactly one after principal-class validation, exact tuple/digest repeats, changed tuple is `REGISTRATION_CONFLICT`, never an unknown generation |
| CT-23 / adapter.apply / factory-adapter.v1 | exact Part I §1.9.5 adapter request, input=cf.provision.v1 from M1 §17.2 for provisioning | StepResult with output=M1 result; CLI/daemon artifact digests from signed release lock |
| CT-24 / config.update / factory.v1 | Part I §1.9.1 PUT /v1/config request and Part V §V.0 desired document | Accepted, generation CAS |
| CT-25 / adapter.readback / factory-adapter.v1 | Part I §1.9.5 readback request | StepResult and exact capability-registered Observation |
| CT-26 / reconcile / factory.v1 | Part I §1.9.1 generation/project_id | Accepted; journal Operation and ordered Steps from §1.9.2/5 |
| CT-27 / adapter.reserve / factory-adapter.v1 | Part I §1.9.5 resource vectors and reservation input registered by pinned capabilities | StepResult, exact shortfall; no resource-unit coercion |
| CT-28 / binding.prepare or binding.commit / binding.prepare.v1 or binding.commit.v1 | Part I §1.9.4 tuple/probes | same tuple/active_digest participant receipt; no dispatch until both readbacks |
| CT-29 / round.control / execution-control.v1 | Part II F8.1 control fields with Fence/version | F8.1 ControlReceipt/checkpoint, fenced replacement only |
| CT-30 / events.read or metrics.read / factory.v1 | GET query grammar Part I §1.9.1 | Part V §V.0.3 events/samples; M0 §16.1 defines M0–M6 telemetry exporter, not a replacement manager API |
| CT-31 / config.emit / gateway-config.v1 (SPEC-DERIVED) | `platforms.<platform>.{enabled:boolean, token_env:Text — an env var NAME, never a value, home_channel:{platform:ID, chat_id:Text, thread_id:Text, name:Text}, allowed_chats:Text[]}` plus `gateways.loop_watchdog:object`; the scheduler row keys `deliver`/`deliver_mode` stay the routing hint | emitted/merged block in the bunker's `~/.hermes/config.yaml`; unresolved reference is `GATEWAY_TOKEN_REF_UNRESOLVED` (warning, lane runs scheduler-only) and generated files carry zero token bytes (M13 §3–§5) |

Outcome remains a generic evidence vocabulary; WorkerResult uses
pass/fail/unverified/partial/unknown and RoundReport uses pass/fail/unverified/partial/unknown. StopReason is
no_useful_work/budget_exhausted/cancelled/paused/deadline/dependency_unavailable/failed.
MemoryBody is discriminated by record_type: worker, wave, round and resolution use the
canonical role bodies; decision/finding use `{text:Text,evidence_refs:EvidenceRef[],relations:ID[]}`.
MemorySyncReceipt is `{record_id:ID,payload_digest:SHA,destination:string,
state:pending/qualified/failed/partial/conflict,remote_receipt:string or null,attempts:UInt,
last_error:Error or null}`. Receipts are mutable and excluded from the memory digest.
ChatMessage is `{role:system/user/assistant/tool,content:string or null,
tool_calls:ToolCall[] optional for assistant,tool_call_id:ID required for tool}`.
ToolCall is `{id:ID,type:function,function:{name:FunctionName,arguments:JSON-text}}`.
BufferedCompletion carries response id, requested and served model, choices, finish reason
and typed Usage. Stream is M12 SSE: delta/usage/terminal frames with seq beginning at zero
and increasing by one, exactly one terminal, then `data: [DONE]`; DONE or EOF without a
terminal is STREAM_TRUNCATED. Usage commits before terminal complete. UTF-8 fragmentation
may split a code point, and tool fragments assemble by call id and index.
First-byte deadline is 30 s, absolute upstream request deadline 300 s; cancellation propagates
by the same request_id and its observed outcome is recorded, never asserted from
socket closure. No automatic retry after any content or unknown provider outcome.

Manager schemas retain their defined `extensions` positions. In the execution schemas
above only CT-01/02 carry extensions, with exactly the listed members; unknown plugin
fields are rejected until a new version registers them. The enrollment/seed/board/
policy/conformance/storage versions in M0–M6 are also registered domain types, not
alternative outer wires. Required protocol versions are the union of Part I §1.9.8's
control-plane baseline and these role-specific types; a role need not implement an
unrelated renderer API. A release lock advertises the union applicable to each role in
`protocol_versions` as specified in M1 §18.1.

### IV.2.2 Shared effects, retries, errors and telemetry

Every mutating endpoint authenticates M1/Part I identity, validates full input, verifies
scope/generation, and writes intent+dedupe+outbox in one fsync transaction before
external effects. Consumers acknowledge only their documented custody boundary.
M2 native starts, M3 Git/evidence, M4 board and M1 credentials have their stronger
protocols; none is weakened by generic replay. Generic calls have 30 s deadlines,
same-key backoff 5,10,20,40,80 s, then RETRY_EXHAUSTED with durable state retained.
Only errors marked retryable permit these retries. An unknown outcome requires readback
first. Authentication, invalid field, unsupported version and conflicts are not automatic
new-key retries. GET has no side effects. All responses use M0 event telemetry and
Part I journal/error formats; telemetry outage cannot invent a successful receipt.

ErrorCode is the closed set named in the referenced normative schemas (uppercase
error tokens); additions require a minor schema registry edition and explicit peer
capability agreement. Common codes are INVALID_ID, INVALID_FIELD, UNKNOWN_FIELD,
UNSUPPORTED_VERSION, UNAUTHORIZED, FORBIDDEN, DIGEST_MISMATCH,
IDEMPOTENCY_KEY_REUSED, PERSISTENCE_UNAVAILABLE, AUTHORITY_UNAVAILABLE,
DELIVERY_UNKNOWN, RESULT_CONFLICT, UNKNOWN_RESULT, CLAIM_CONFLICT, STALE_OWNER,
GENERATION_CONFLICT, RETRY_EXHAUSTED and INTERNAL_ERROR. Unrecognized native errors
map to INTERNAL_ERROR with redacted message/evidence, never success. No secret-containing
message is returned. HTTP 400 is parsing, 401/403 auth/scope, 409 conflict, 422 validation,
503 unavailable with Retry-After=5. Typed execution failures can return HTTP 200 for
successfully stored failed results. A legacy `{ok:true,status:fail}` refuses
RESULT_CONFLICT with no settlement; an identical failed-result retry replays its receipt;
pass execution plus failed publication yields partial round/settlement, never success.

### IV.2.3 Canonical bytes and digest domains

RFC 8785 JCS defines all structured content bytes (UTF-8, sorted object keys, no
trailing LF, no Unicode normalization, arrays unchanged). Integer schema avoids
large-number rounding; semantically invalid objects are rejected before hashing.
Raw archive/file digests hash raw bytes; text payloads preserve CR/LF and normalization.
BriefInput hashes the whole validated object. Memory payload_digest hashes the complete
memory-record.v1 with payload_digest absent, including its writer, fence, ids and body;
mutable MemorySyncReceipt and Git commit ids are outside that domain. Manifest/config/seed hashes cover their
whole objects except an explicitly self-named digest and signature; each such field
is excluded only when named by its type. report_digest hashes CT-06R's entire body
except report_digest, including its schema/idempotency key, evidence and timestamps;
outer request transport fields are excluded. Replay input digest hashes message_type
plus body, omitting only the idempotency_key itself; outer fresh nonce/time/request_id
do not cause a conflicting same-operation retry. Since pass 7 the two values are named
separately — `request_digest` covers the reduced body, `replay_digest` covers
`message_type` plus that body, both omitting the same declared excluded list (§IV.2.7);
the single-value form survives only where an operation declares the pairing.
Signature framing is M1 §17.1, not a digest of arbitrary pretty-printed JSON.

Git tree_digest is SHA-256 of JCS of a path-byte-sorted array of objects
`{path_b64:string,mode:"100644"/"100755"/"120000"/"160000",type:blob/symlink/gitlink,
content_digest:SHA or null,git_oid:GitOID or null}`. Paths are repository-relative raw Git
bytes encoded standard padded base64 (RFC 4648). Blobs/symlinks hash their raw blob
bytes (symlink target is not followed); gitlinks have content_digest=null and their
object ID; other entries have git_oid=null. Directories are implicit, empty tree is
`[]`, and `.git` metadata is absent. All tracked board files are included; closure
C certifies parent P through M3 §17.3 rather than excluding board files invisibly.
No native SHA-1 tree or commit is labeled a SHA-256 tree_digest.

Canonicalization vectors use no final newline. The two inputs
`{"b":2,"a":1}` and ` { "a": 1, "b": 2 } ` have the same canonical bytes
`{"a":1,"b":2}`. Array `[1,2]` differs from `[2,1]`, string `"x\n"` differs from
`"x"`, and composed/decomposed Unicode strings remain different. The following
computed digests are independently reproducible using SHA-256 over the shown bytes:

| Bytes | SHA-256 |
|---|---|
| empty byte sequence | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `abc` | `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` |
| `[]` (empty canonical tree) | `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945` |

### IV.2.4 Evidence states and machine-readable identity registry

A source locator establishes source coverage only. `TARGET-UNIMPLEMENTED` means no
conforming target integration is evidenced; `UNVERIFIED` means a target implementation
is claimed but lacks a complete qualifying record; `FIXTURE-PASS` is bounded offline
proof. `PROVEN` requires an immutable qualification record containing contract_id,
body_version, producer/consumer release digests, source commits, config digest,
mode=live, observed_at, positive and negative input refs, transcript refs, actual
outcomes and independent verifier identity. Missing, expired (>86400 s readiness
window) or mismatched records never certify a current deployment. Historical source
labels below do not qualify cf2a.v1. Human boundaries qualify through authenticated
artifact/receipt review, not invented encode/decode functions in a person.

The following JSON block is the normative identity registry `cf.contract-registry.v1`.
Generators/checkers consume it from this section and reject duplicate/unknown ids;
the card/type tables expand each ID. The resident foreman cancellation/reboot
object is registered in the same machine-readable vector source as
`resident_foreman_contract` in `docs/handbook/contract-vectors.json`, referenced by
M2 §15.2 and M5 §16.1; it is not a competing registry. Aliases are accepted only while importing old
coverage and never in target wires or new chapters. Legacy CT-05 lane-seed coverage
is classified under CT-01; the ID CT-05 always means per-worker brief in this edition.

```json
{"schema_version":"cf.contract-registry.v1","contracts":["CT-01","CT-02","CT-03","CT-04","CT-05","CT-06","CT-06R","CT-07","CT-08","CT-09","CT-10","CT-11","CT-12","CT-13","CT-14","CT-15","CT-16","CT-17","CT-18","CT-19","CT-20","CT-21","CT-22","CT-23","CT-24","CT-25","CT-26","CT-27","CT-28","CT-29","CT-30","CT-31"],"vector_objects":["resident_foreman_contract"],"coverage_aliases":{"M1-C1":"CT-22","M1-C2":"CT-23","M0-C1":"CT-23","M5-C1":"CT-23","M5-C2":"CT-19"},"legacy_reclassification":{"CT-05:lane-seed":"CT-01"}}
```

Its count is derived from contracts (32), never hardcoded 18. It owns identity;
source/evidence state lives in qualification records, so changing a citation does
not rename a contract. CT-31 is registered as SPEC-DERIVED (M13) — its
`docs/SYSTEM-MODEL.yaml` registration is pending, so model-derived counts
elsewhere legitimately still read the pre-CT-31 total. A registry change updates
cards, source-model projection,
chapter edges and generated figures together before qualification. This wave changes
only its assigned chapters/register; older out-of-scope projections remain explicitly
unqualified until the consuming checker is updated. Absence of that implementation
is not a claim that the schema itself remains undecided.

### IV.2.5 LCR-1: the layered commitment rule

Pass 7 found four record families that name a value inside the hash domain which is
derived from the digest of that same record. The launch family was the sharpest:
`dispatch_id` was derived from `execution_key`, `execution_key` from
`{launch_id,input_digest}`, and the launch record's `input_digest` covered a body that
already contained `dispatch_id`. Every reader that recomputed the chain had to iterate
to a fixed point, and two conforming readers could disagree about which fixed point was
authoritative.

One rule replaces the four local exceptions. It is normative for every record family in
this register, not only the launch:

1. Every hash domain is a closed field list plus an explicit `excluded_derived` list.
   A field is either covered or excluded. No domain covers its own output.
2. Every identity is allocated by the component that owns it, durably and idempotently,
   before it is hashed. A derived identifier is never an input to the digest that
   produces it.
3. Records are constructed in layers. A layer may include the digest of a lower layer.
   A lower layer may not include the digest of a higher layer, and no record includes
   its own digest or signature.
4. The construction order `content → record → envelope` is normative. Readers recompute
   in the same order and reject a record whose lower-layer digest changes when a
   higher-layer field changes.
5. Derived identifiers are validated by recomputation, never by iteration. A mismatch is
   a `CONTRACT_INVALID` refusal; searching for a fixed point is never an allowed recovery.

| Layer | Contents | Excluded from its own hash | May include |
|---|---|---|---|
| L0 content | immutable caller payload, preallocated owning identity and nonce | every derived identity, every digest, every signature, every mutable lifecycle field | nothing derived |
| L1 record | L0 content, L0 digest, record identity, role and version | the record's own digest and signature, any higher-layer reference | L0 digest and lower-layer digests |
| L2 envelope | L1 record, L1 digest, audience and transport metadata | the envelope signature, the envelope's own digest when one is defined | L1 digest and lower-layer digests |

The bootstrap identity table is part of the contract. An identity that is not in this
table has no allocation order and cannot appear in a hashed field:

| Identity | Allocator | First durable use | Hash-exempt rule |
|---|---|---|---|
| `launch_id` | launching foreman, before admission | CT-02 and the launch commitment | preallocated; may appear in L0 content; never derived from a launch digest |
| `dispatch_id` | supervisor, from the launch commitment | launch confirmation and CT-05 | derived once; excluded from L0 `input_digest` |
| `execution_key` | supervisor, from `launch_id` and L0 `input_digest` | launch confirmation and execution journal | derived once; excluded from L0 `input_digest` |
| `registration_id` | controller, before the enrolment request | enrolment grant and request | preallocated; never allocated by Crier |
| `node_id`, `registration_generation` | Crier, from the accepted grant | enrolment response and readback | allocated by Crier; may appear in the response, never in the request's L0 digest |
| `task_id`, `wave_id`, `claim_id` | board, before claim construction | CT-10 and the board record | preallocated; ordering fields are not derived from the record digest |
| `receipt_digest` | Crier, after the unsigned response payload | custody receipt | excludes itself and the signature; covers only the unsigned payload digest |
| `report_digest` | reporter, after the final report body | final report | excludes itself and its signature; may include the round-summary digest |

This retires the reading in IV.0 and IV.1 that the foreman reserves `dispatch_id` before
worker delivery. The foreman allocates `launch_id` and the nonce; the supervisor derives
`dispatch_id` and `execution_key` from the persisted commitment. A foreman-supplied
`dispatch_id` is refused with `CONTRACT_INVALID`, because accepting it would restore the
cycle the rule exists to remove.

The cold-launch sequence is finite and single-pass:

1. The foreman allocates `launch_id` and a nonce.
2. The foreman builds `cf.launch-commitment.v1` from the immutable BriefInput, the
   preallocated `launch_id`, the nonce and the owning supervisor identity.
   `input_digest` covers L0 only; `dispatch_id`, `execution_key`, `input_digest` itself
   and every signature are excluded.
3. The foreman submits the commitment. The supervisor validates the commitment digest
   and persists it before deriving anything.
4. The supervisor derives
   `execution_key = H("cf.execution-key.v1" || launch_id || input_digest)` and
   `dispatch_id = "d-" || H("cf.dispatch-id.v1" || launch_id || input_digest)`.
   Neither derivation reads `dispatch_id`, `execution_key` or a commitment digest.
5. The supervisor writes `cf.launch-confirmation.v1` containing the commitment digest,
   both derived identities and the confirmation digest. The confirmation is the first
   record that contains the derived values.
6. The foreman materializes `cf.launch-input.v1` from the commitment, `dispatch_id` and
   `execution_key`. `input_digest` is the commitment's value, carried forward. A reader
   that recomputes it over the materialized object is non-conforming, because the
   materialized object contains the derived identities the digest must not cover.
7. CT-05 for a worker uses the same commitment and the same allocation order. No future
   worker identifier is required at admission.

The frozen values for the fixture launch are:

```
launch_id        l-8bf0b1797a09ac9cae1c0421aa27050b331acdaa554156d08753425acad49048
input_digest     aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a
execution_key    add6df27bfc4facef355695078b5e1171eda32325a99263c30b81b9f0fc842fc
dispatch_id      d-2ccec62df73e9a889ec12b5c1600e4706d2311d766bfc3a6b07bac986b94fcab
commitment       fefb5e5d7887999e0123ebb9bbae94116150941341f2fcb0f1c751861a228b3d
confirmation     093889a3a6f4a61ff1af28d578f1757254446a1c9b3ac15543297097812e6e74
```

`CV-16-A` publishes the whole chain as canonical bytes; `CV-16-B` is the changed-derived-
identifier refusal. `SC7-01` asserts the graph has no cycle and that the cold
construction completes in one pass. `CV-02-A` carries the same commitment in the
`supervisor.v1` request body, so the request and the confirmation cannot drift.

### IV.2.6 Digest-domain registry

One framing convention, stated once: a **record digest** is SHA-256 over the JCS bytes
of the record with its own digest and signature absent. A **layer-crossing digest** — a
value that binds a lower layer into a higher one — is SHA-256 over an ASCII domain tag
concatenated with the canonical bytes named in the table. Every part is either fixed
width or a canonical JSON string, so no separator is needed and none may be added.

| Digest | Domain tag | Covers | Excludes |
|---|---|---|---|
| `input_digest` | none | JCS of the L0 BriefInput | every derived identity, every digest, every signature |
| `commitment_digest` | none | JCS of `cf.launch-commitment.v1` | `commitment_digest`, `signature`, `dispatch_id`, `execution_key`, `confirmation_digest` |
| `confirmation_digest` | none | JCS of `cf.launch-confirmation.v1` | `confirmation_digest`, `signature` |
| `execution_key` | `cf.execution-key.v1` | tag then `launch_id` then `input_digest` | everything else; the tag is not part of any record |
| `dispatch_id` | `cf.dispatch-id.v1` | `d-` then tag then `launch_id` then `input_digest` | everything else |
| `request_digest` | none | JCS of the request body minus the excluded list | `request_digest`, `replay_digest`, `idempotency_key`, every signature |
| `replay_digest` | none | `message_type` then JCS of the same reduced body | the same list |
| `response_body_digest` | `cf.crier.response-body.v1` | tag then JCS of the unsigned payload | the receipt, `receipt_digest`, every signature |
| `receipt_digest` | `cf.crier.receipt.v1` | tag then JCS of the receipt body | `receipt_digest`, `signature` |
| `payload_digest` (memory) | none | JCS of `cf.memory-record.v1` | `payload_digest`, `sync`, `signature` |
| `round_summary_digest` | none | JCS of the round-summary body | `round_summary_digest`, `report_digest`, its own memory ref, `signature` |
| `report_digest` | none | JCS of the final report body | `report_digest`, `signature`, `closure_ref` |
| `group_claim_digest` | none | JCS of `cf.board-group-claim.v1` | `group_claim_digest` |
| `config_digest` | none | JCS of `cf.config.v1` | `config_digest` |
| `settlement_digest` | none | JCS of `cf.settlement.v1` | `settlement_digest` |

Two consequences follow, and both are checked by the bundle rather than trusted:

* A digest that is not in this table is not comparable to one that is. The bundle's
  self-check refuses a vector whose declared digest does not recompute under the row it
  names, and refuses a record digest that only recomputes when a field outside its
  `excluded_derived` list is dropped.
* `input_digest` is the only digest in the launch family that covers content. Every
  other launch digest covers a record that already contains it. That is what makes the
  chain acyclic rather than merely ordered.

### IV.2.7 Request identity, replay identity and the excluded list

`request_digest` and `replay_digest` are separate named domains. Both are computed over
the canonical request body with `request_digest`, `replay_digest`, `idempotency_key`
where the operation defines one, and every signature removed. `replay_digest` additionally
covers `message_type`, so the same body sent as a different operation is a different
replay identity.

An operation that needs one value for both names the formula it uses and records the
pairing; every consumer then reads the pairing, and no consumer may assume a split that
the operation did not declare. `CV-17-C` is the declared-shared case. The default stays
two named values with an explicit mapping.

Readback and deduplication records store both digests and the excluded-field list they
were computed under. A record that stores a digest without the list is not comparable to
one that stores the list, so a receiver refuses it rather than guessing: the same bytes
hashed under a different list produce a different value, and the receiver cannot tell
which one it holds. `CV-17-B` shows the failure this prevents — a retry under the same
`idempotency_key` whose body was edited no longer matches its stored `replay_digest`.

### IV.2.8 The custody chain: payload, receipt, envelope

A custody response is three objects, not one:

1. The unsigned payload holds the operation result and nothing else. It excludes the
   receipt, `receipt_digest` and the signature.
2. `response_body_digest = H("cf.crier.response-body.v1" || canonical(unsigned payload))`.
3. The receipt body holds `response_body_digest`, lease identity, principal, nonce and
   timestamps. `receipt_digest = H("cf.crier.receipt.v1" || canonical(receipt body))`,
   excluding `receipt_digest` and the signature.
4. The signed envelope holds the unsigned payload, the receipt and `receipt_digest`. Its
   signature covers `receipt_digest` and the envelope metadata (audience, transport,
   signing key). The response hash never covers the embedded receipt or its digest.

A client accepts a response in one fixed order: verify the envelope signature;
recompute `receipt_digest` from the receipt body; recompute `response_body_digest` from
the unsigned payload; compare the receipt's `response_body_digest` to the recomputed
value; compare the audience to its own node identity and generation; only then accept
the credential reference. Accepting on the envelope signature alone would let a validly
signed envelope carry a payload the receipt never covered.

The fixture chain is `CV-18-A`; the rewritten-payload refusal is `CV-18-B`. The fixture
ships a deterministic ed25519 test key derived from a published seed string. It signs
this transcript and nothing else, authorizes nothing, and is labelled as such in the
bundle; the credential itself never appears in any fixture, only its CAS reference.

### IV.2.9 The artifact register: canonical bytes and signature transcripts

P5G-16. This subsection is a projection, not a new authority: it mints no digest, no
domain tag, no profile identifier, no audience and no key source, and every cell names
the section that owns the value. Change the owner, not this table. The framing
conventions are stated once and are not restated here: **record digest** and
**layer-crossing digest** are §IV.2.6, and the construction order is §IV.2.5. Profile
identifiers appear only as their owners spell them (M10 §16, M1 §17.1, M1 §17.3,
M1 §17.4, M3 §17.4, VI §35.1). The webhook delivery profile has no `CF2A-*`
identifier, and none is created here (V §V.0.3).

| Artifact class | Canonical byte sequence | Signature profile and transcript | Key-id source | Audience | Timestamp and replay window | Rotation rule |
|---|---|---|---|---|---|---|
| brief | RFC 8785 JCS UTF-8 of the whole validated `cf.brief-input.v1` object: sorted keys, compact separators, no BOM, no trailing LF, whitespace and Unicode bytes preserved. `input_digest` is SHA-256 of exactly those bytes and `brief_ref` addresses the same bytes (§IV.2, §IV.2.3, §IV.2.6, M3 §17.4). `worker-brief.v1` carries the ref and the digest and does not redefine either (§IV.2). Vector CV-01-B. | No signature covers the brief object: `cf.brief-input.v1` and `worker-brief.v1` are closed and carry ref plus digest only (§IV.2, §IV.2.6). Where a brief travels inside a Crier application request, that request is signed under `CF2A-CRIER-1` (M10 §16). | `X-CF2A-Key-Id` on a Crier application request (M10 §16); `cf.brief-input.v1` carries no key id of its own (§IV.2). | NOT SPECIFIED at the object level: neither `cf.brief-input.v1` nor `worker-brief.v1` declares an audience (§IV.2); the only stated audience is `crier.factory` for a Crier application request (M10 §16). | `X-Agent-Ts` with ±30 s skew, and `request_id` plus `idempotency_key` as the replay nonce, differing bytes under the same nonce being `REPLAY_CONFLICT` (M10 §16); the brief's own replay rule is receipt replay on an identical ref and digest (§IV.2). | NOT SPECIFIED for the enrolled Crier signing key (M10 §16 states no rotation); see the table below. |
| report | JCS of the final `round-report.v1` body including its schema and idempotency key, its evidence and its timestamps; `report_digest` excludes itself, its `signature` and `closure_ref` (§IV.2.3, §IV.2.6, §IV.5.5). CT-06 settlement reads the `(round_id, report_digest)` pair (§IV.1). | The digest domain excludes a `signature` member (§IV.2.6, §IV.5.5) but no section assigns it a profile or a transcript — NOT SPECIFIED (table below). The carrying request is `CF2A-CRIER-1` (M10 §16). | NOT SPECIFIED — no profile is named for the report signature (§IV.2.6); the only key id in play is the transport's `X-CF2A-Key-Id` (M10 §16). | NOT SPECIFIED — `round-report.v1` declares none (§IV.2 CT-06R), and settlement is addressed by the `(round_id, report_digest)` pair (CT-06, §IV.1). | `finished_at` is a body member (§IV.2 CT-06R); the request's replay identity is `request_digest` and `replay_digest` with its declared excluded list (§IV.2.7, I §1.9.10); no replay window is stated for the report body (§IV.5.5). | NOT SPECIFIED — no key is assigned to the report signature (§IV.2.6); see the table below. |
| payload | The unsigned `cf.crier.response-payload.v1` result only, as JCS UTF-8 (§IV.2.8). `response_body_digest` is SHA-256 over the bare tag `cf.crier.response-body.v1` concatenated with those bytes, no separator (§IV.2.6, §IV.2.8), and `receipt_digest` is SHA-256 over the bare tag `cf.crier.receipt.v1` plus the receipt body minus `receipt_digest` and `signature` (§IV.2.6, §IV.2.8). Vector CV-18-A. | `CF2A-CRIER-1`: Ed25519, lowercase hex, over five UTF-8 lines with no prefix and no final newline — `<METHOD>`, `<origin-form path with bytewise-canonical query>`, `<X-Agent-Ts>`, `sha256:<request-body-sha256>`, `audience:<registered-principal>`; the response uses the same five lines with `response_ts` and `sha256:<response_envelope_digest>` and carries the value in `X-CF2A-Signature` (M10 §16, §IV.2.8). | `X-CF2A-Key-Id`, resolving only to the enrolled principal and registration generation (M10 §16); the signed envelope names `signer.key_id` with its public key and algorithm (CV-18-A). | Request audience is `crier.factory`; response audience is the original requester, compared to the receiver's own node identity and generation before the credential reference is accepted (M10 §16, §IV.2.8). | `X-Agent-Ts` for requests and `response_ts` for responses with ±30 s skew; the replay nonce is `request_id` plus `idempotency_key` bound to the body digest, and a stale timestamp or nonce/digest conflict is refused before any custody effect (M10 §16). | NOT SPECIFIED for the enrolled Crier signing key (M10 §16 states revocation refusal, not rotation); see the table below. |
| manifest | JCS of the whole object except an explicitly self-named digest and signature (§IV.2.3). `cf.release-lock.v1` carries `manifest_digest` and its signature covers JCS with `signature` omitted (M1 §18.1); `cf.backup.v1` hashes RFC 8785 JSON of the complete content object excluding only `content_digest` and `signature` (VI §35.1); `config_digest` and the other registered manifest digests are §IV.2.6 rows. | Ed25519 over `CF2A-RELEASE-1\n` plus JCS with `signature` omitted (M1 §17.3, M1 §18.1); a `SignedArtifact` signature covers `CF2A-RELEASE-1\n` plus the referenced JCS body without the signature (V §V.9). Seed: `CF2A-SEED-1\n` plus JCS excluding signature (M1 §17.4). Backup: `CF2A-BACKUP-1\n` plus the content digest's lowercase hex bytes (VI §35.1). Evidence receipt: `CF2A-EVIDENCE-1\n` (M3 §17.4). | `issuer_key_id` on the lock (M1 §18.1), `signature.key_id` on `SignedArtifact` (V §V.9), `issuer_key_id` on the evidence receipt (M3 §17.4); the offline operator trust bundle pins the release signer (M1 §17.3). | NOT SPECIFIED — the lock declares no audience (§IV.2 type registry); it is consumed by the release manager after signature, digest, platform, dependency-closure and compatibility verification (M1 §18.2). | NOT SPECIFIED — the lock carries no timestamp member and no replay window (M1 §18.1); deduplication is `expected_generation` plus `operation_id` on the release operation (M1 §18.2). | NOT SPECIFIED — only the trust-bundle pin is stated (M1 §17.3); signer rotation has no procedure, overlap window or re-key transcript. |
| tree | `tree_digest` is SHA-256 of JCS of the path-byte-sorted array of `{path_b64,mode,type,content_digest,git_oid}`; paths are repository-relative raw Git bytes in padded base64, an empty tree is `[]`, and no native SHA-1 tree or commit is labelled a SHA-256 `tree_digest` (§IV.2.3). | None — `tree_digest` is an unsigned digest. What binds it is the commit it was computed over, the fresh-fetch publication readback naming `accepted_object`, `observed_tip` and `remote_tree_digest`, and the closure validator that proves the permitted paths and ancestry (M3 §17.2, M3 §17.3). | NOT SPECIFIED — no signature, hence no key (M3 §17.3; table below). | NOT SPECIFIED — no signature, hence no audience (M3 §17.3; table below). | Records carry `observed_at` and `fetched_at` per publication phase (M3 §17.2); the digest itself carries no timestamp and no replay window — NOT SPECIFIED (table below). | NOT SPECIFIED — no key exists to rotate (§IV.2.3 defines a digest only; table below). |
| webhook | The `event.v1` object as RFC 8785 JSON, delivered as the exact body bytes with no final newline added by the sender (V §V.0.3). | HMAC-SHA256, lowercase hex, in `X-Factory-Signature`: UTF-8 `factory-event-v1`, newline, key ID, newline, delivery time, newline, event ID, newline, then the exact body bytes (V §V.0.3). Not Ed25519, and not a `CF2A-*` profile (V §V.0.3). | `X-Factory-Key-Id`, resolved from the destination bundle's `active_key_id` (V §V.0.3, V §V.4). | NOT SPECIFIED — the receiver is the subscription `endpoint_ref`, and the transcript carries no audience string (V §V.0.3, V §V.4). | `X-Factory-Delivery-Time` in decimal Unix seconds with ±60 s skew; duplicate suppression is `event_id` plus body digest with a changed digest refused as 409; cursor replay signs a fresh delivery time with the active key, retention is 604800 s, and a stale or unknown key returns 401 and cannot advance the cursor (V §V.0.3). | Atomic `active_key_id` change with verification keys preserved for 300 s; a URL change requires a new subscription generation and never reuses the old destination key (V §V.4). |

The memory record is the one payload-shaped artifact outside the custody chain: its
`payload_digest` is the §IV.2.6 row for `cf.memory-record.v1`, JCS of the record
excluding `payload_digest`, `sync` and `signature`. No profile is named for that
`signature` member; the gap is recorded in the table below, not inferred here.

**Authoritative actor, ordering, failure behavior and recovery.** The six classes differ
in what is signed, not in who may act or in which order. One rule set governs them:

* **Actor.** The component that allocates an identity owns the bytes that carry it
  (§IV.2.5 rule 2). The foreman builds and persists the `BriefInput`; the reporter
  builds the round summary and then the report; Crier builds the unsigned payload, then
  the receipt, then the envelope; the release owner publishes and signs the lock; the
  node commits the tree and the landing path publishes it and reads it back; the
  manager's delivery worker signs each webhook with the active key.
* **Ordering.** Content → record → envelope (§IV.2.5); round summary → report → closure
  witness (§IV.5.5); payload → receipt → envelope (§IV.2.8); manifest digest → signature
  (M1 §18.1); tree → commit → publication readback (M3 §17.2); persist → sign → deliver
  (V §V.0.3). A reader recomputes in the same order and rejects a record whose
  lower-layer digest moves when a higher-layer field changes.
* **Failure.** Every class refuses before effects. A digest or ref mismatch is
  `DIGEST_MISMATCH`; a record whose derived identifier does not recompute is
  `CONTRACT_INVALID`; a reused nonce with different bytes is `REPLAY_CONFLICT`
  (§IV.2.7); an unknown key or profile, stale generation, bad body hash, sender or
  audience mismatch, or stale timestamp is `UNAUTHORIZED` (M10 §16); a webhook key or
  signature failure is `ENDPOINT_UNAUTHORIZED` and is not delivery success (V §V.0.3).
  No class permits iterating to a fixed point (§IV.2.5 rule 5).
* **Recovery.** Recover by recomputation and readback, never by re-derivation: fetch the
  object by its reference, recompute the digest in the declared order, and compare
  against the stored value together with the excluded-field list it was computed under
  (§IV.2.7). An identical retry replays the original receipt and the original receipt
  stays available by `request_id` (§IV.2, M10 §16). A publication whose acknowledgement
  is lost is resolved by GET readback and by replaying the same commit, never by
  choosing a new generation (M3 §17.2, M10 §16). A webhook replay re-signs a fresh
  delivery time with the active key and never re-authors the event (V §V.0.3).

**Cells with no normative answer at this revision.** These are findings, not
placeholders: the question asks for a value, the tip has none, and inventing one would
mint a competing contract. Each names the board row that owns the missing rule when one
exists at this revision (`.coding-hermes/board/tasks.jsonl`, read through
`scripts/board_read.py`).

| Artifact class | Cell with no normative answer | Status at this revision | Owning board row |
|---|---|---|---|
| brief | audience at the object level | NOT SPECIFIED: `cf.brief-input.v1` and `worker-brief.v1` declare no audience (§IV.2); only a carrying Crier request has one (M10 §16) | none — digest-pinned delivery is the P5G-08 decision |
| brief, payload, report | rotation of the enrolled Crier signing key | NOT SPECIFIED: M10 §16 resolves a key id to the enrolled principal and generation and refuses an expired or revoked identity, but states no rotation procedure, overlap window or re-key transcript | P5G-09 |
| report | profile, key-id source and audience of the report `signature` member | NOT SPECIFIED: §IV.2.6 and §IV.5.5 exclude a `signature` member from `report_digest`, and the closed `round-report.v1` body carries no signature field (§IV.2 CT-06R), so no profile, key id or audience is assigned | none |
| payload (memory-record variant) | profile over the `cf.memory-record.v1` `signature` member | NOT SPECIFIED: the §IV.2.6 `payload_digest` row excludes `signature`, but no section names the profile that produces it | P5G-22 |
| manifest | audience, timestamp, replay window, signer rotation | NOT SPECIFIED: the lock declares no audience and no timestamp (M1 §18.1), deduplication is generation and operation based (M1 §18.2), and the only trust statement is the trust-bundle pin (M1 §17.3) | none |
| tree | signature, key-id, audience | NOT SPECIFIED: `tree_digest` is unsigned, and certification is commit ancestry plus the closure validator (M3 §17.3) | none |
| webhook | audience | NOT SPECIFIED: the receiver is the subscription `endpoint_ref` and the transcript has no audience field (V §V.0.3, V §V.4) | none |

**One retired spelling (AC2).** The two response domains that §IV.2.6 registers are
concatenated with the bare tag. M10 §16 prints its three response-domain formulas with a
trailing `\n` inside the tag; for the two §IV.2.6 registers — `response_body_digest` and
`receipt_digest` — that shell spelling is **superseded by §IV.2.6** and must not be
reproduced. The published bytes decide it: `CV-18-A`, and the same digests in
`docs/handbook/conformance/fixtures/custody-request-response.json`, recompute only under
the bare tag, and inserting a newline between tag and body changes both values.
M10 §16's profile, signed header set, audience rule and five-line transcript are
unaffected and remain authoritative. `response_envelope_digest` (M10 §16) has no
§IV.2.6 row, so this subsection cites it and neither confirms nor retires its
spelling; registering it is open work, not an alternate contract.

## IV.3 Complete protocol examples

Examples use declared fixture identities and SHA values. They validate wire shape,
not authenticity, availability of objects or permission to run production work.
The repeated `a` digest is a shape-only placeholder, not a claim about stored bytes.
A real receiver recomputes it and refuses absent or mismatching objects. The
following first admission is complete; no future attempt identity is present.

```json
{"schema_version":"cf2a.v1","message_type":"round-admission","request_id":"req-17","corr_id":"c-17","sender":"scheduler","created_at":"2026-11-11T19:00:00Z","body":{"schema_version":"round-admission.v1","idempotency_key":"admit-17","round_id":"r-17","run_id":"run-17","corr_id":"c-17","task_scope":["CF-1","CF-2"],"total_budget":2,"config_generation":17,"extensions":{"project_id":"code-factory","lane":"code-factory","board_revision":{"algorithm":"sha1","value":"1111111111111111111111111111111111111111"},"binding_generation":1,"owner_fence":{"authority_id":"auth-1","project_id":"code-factory","epoch":1,"owner_id":"foreman-1"},"lane_seed":{"prompt_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","skills":[]}}}}
```

First Crier registration occurs only after M1's authenticated enrollment; expected
generation is zero and Crier allocates exactly one node identity after the authority
consumes the grant. Its certificate string below is a fixture label, so it is rejected
by real DER validation; it is never an example of a valid authentication credential.
All mandatory envelope fields remain explicit, including `profile_id` and
`operation_id`. A worker-class claim is refused before allocation.

```json
{"schema_version":"cf2a.v1","message_type":"register","request_id":"reg-req-17","corr_id":"enroll-17","sender":"bunker-a","created_at":"2026-11-11T19:00:00Z","body":{"schema_version":"register.v1","idempotency_key":"enroll-key-reg-bunker-a-op-enroll-17-g1","registration_id":"reg-bunker-a","agent_id":"bunker-a","project_id":"code-factory","profile_id":"bunker.user-image.v1","operation_id":"op-enroll-17","expected_generation":0,"public_identity":{"certificate_der":"FIXTURE-CERTIFICATE-NOT-A-CREDENTIAL","key_id":"bunker-a-key-1"},"capabilities":["hermes"]}}
```

A schema-valid minimal provision request follows. Every digest/reference is fixture-only,
no actual trust/release approval is implied. Five distinct credential classes are
represented; scopes are resolved and checked against authority bindings before use.

```json
{"schema_version":"cf.provision.v1","operation_id":"op-1","request_id":"req-1","project_id":"code-factory","node_id":"node-1","profile_id":"bunker.user-image.v1","generation":1,"expected_generation":0,"operation":"create","manifest_digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","repository":{"forge":"github","host":"github.com","owner":"coding-hermes","repo":"code-factory","ref":"refs/heads/main","commit":{"algorithm":"sha1","value":"1111111111111111111111111111111111111111"}},"credential_refs":[{"id":"forge-1","class":"forge","subject":"node-1","project_id":"code-factory","operations":["read"],"generation":1,"expires_at":"2026-11-12T19:00:00Z","issuer":"auth-1"},{"id":"crier-1","class":"crier","subject":"node-1","project_id":"code-factory","operations":["receive","reply"],"generation":1,"expires_at":"2026-11-12T19:00:00Z","issuer":"auth-1"},{"id":"bunker-1","class":"bunker","subject":"node-1","project_id":"code-factory","operations":["exec"],"generation":1,"expires_at":"2026-11-12T19:00:00Z","issuer":"auth-1"},{"id":"proxy-1","class":"proxy","subject":"node-1","project_id":"code-factory","operations":["infer"],"generation":1,"expires_at":"2026-11-12T19:00:00Z","issuer":"auth-1"},{"id":"memory-1","class":"memory","subject":"node-1","project_id":"code-factory","operations":["read","append"],"generation":1,"expires_at":"2026-11-12T19:00:00Z","issuer":"auth-1"}],"idempotency_key":"provision-1","manifest":{"release_lock_ref":"cas+sha256://code-factory/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","role":"worker","disk_floor_gib":5,"ttl_s":21600,"namespace":"code-factory","endpoints":{"authority":{"host":"authority.example.invalid","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"crier":{"host":"crier.example.invalid","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"forge":{"host":"github.com","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"proxy":{"host":"proxy.example.invalid","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"memory":{"host":"memory.example.invalid","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"artifact_mirror":{"host":"mirror.example.invalid","port":443,"tls_spki":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"dns":{"host":"dns.example.invalid","port":53,"tls_spki":""}},"mount_root":"/srv/node-home","seed_ref":"cas+sha256://code-factory/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","network_phase":"bootstrap"}}
```

## IV.4 P5-B disposition index

These dispositions are specification changes, not implementation qualification.
The source baseline is `fb11e92c1580b98e2e8d64cb9a81cdcb3ef64f02`; wave A's
`b26d2ecc494664322f339aa499d9b38a13179d78` is an ancestor and supplies Part I/II's
canonical cf2a.v1, CT-05, CAS and fencing choices. Release choices remain explicit
owner decisions with refusal defaults, never fabricated artifact evidence.

| Finding | Spec resolution / remaining qualification boundary |
|---|---|
| P5-B-01 | M2 §15 and IV.1–IV.3: one cf2a.v1 outer wire, separate admission/attempt/report boundaries and complete envelope examples |
| P5-B-02 | M2 §15.1 and IV.2 BriefInput: immutable directive, task snapshot, ordered skills/attachments and CAS retrieval |
| P5-B-03 | M1 §17.1: pinned initial trust, one-use enrollment grant, CSR/proof of possession, signed requests, nonce/skew/replay, credential resolution and revocation |
| P5-B-04 | M4 §15.2: receive-pack old-OID CAS, protected-ref validator and loser refusal before launch |
| P5-B-05 | M2 §15.2: reservation/start-intent/gated child, discovery and unknown-start quarantine |
| P5-B-06 | M1 §17.3: full release-lock schema and complete available source pins; B-RELEASE defaults to refusal pending owner-signed complete qualification, not an invented release |
| P5-B-07 | M5 §16.1: exact supervisor/adapter invocation, stdin/event framing, status/control and reboot discovery |
| P5-B-08 | IV.2: types, units, closed objects, null/empty/ranges and role-specific body registry |
| P5-B-09 | IV.2.3: JCS/hash field exclusions, raw file/text bytes, Git tree algorithm and digest vectors |
| P5-B-10 | M2 §15.3 and IV.2: transport/execution/settlement separation, identical replay and conflicting legacy result |
| P5-B-11 | M2 §15.3: complete transition/lease/deadline/control race and retained result outbox rules |
| P5-B-12 | M2 §15.1: immutable execution key, persisted mode/binding and fenced compatibility cutover |
| P5-B-13 | M1 §17.2 and corrected §16: bus and credentials precede private clone |
| P5-B-14 | M1 §17.2: operation discriminator, full state set, generation CAS and replay/resume distinction |
| P5-B-15 | M1 §17.4: bootstrap/runtime egress, mirror and memory endpoints, cold-cache policy |
| P5-B-16 | M1 §17.4: whole persistent HOME, ownership and replacement/uninstall retention |
| P5-B-17 | M1 §17.4: initial live qualification, 300 s remote freshness, expiry/drift and local-progress boundary |
| P5-B-18 | M1 §17.2 and IV.3: closed request/config grammar, precedence and complete shape-only fixture request |
| P5-B-19 | M1 §17.4: versioned identity/seed records, shared lock+CAS and whole-generation atomic seed switch |
| P5-B-20 | M4 §15.1: headers, row-image/event reducer, legal statuses and fixture-aware eligibility API |
| P5-B-21 | M4 §15.2 and IV.2: one claim field vocabulary and explicit wire/row/event mapping |
| P5-B-22 | M4 §15.3: unpublished staging is local; published corruption is globally UNAVAILABLE with named recovery owner |
| P5-B-23 | M3 §17.2/M4 §15.3: broker begin/finish-effect mediation, in-flight barrier and no node write keys |
| P5-B-24 | M3 §17.1/M4 §15.4: default policy, typed judge and exceptions; B-GATES/B-BOARD block activation until selected release qualification |
| P5-B-25 | M3 §17.2: same-operation effect resume, uncertain-push discovery and descendant-tip proof |
| P5-B-26 | M3 §17.3: implementation/integration parent certification and separately validated closure, no self hash |
| P5-B-27 | M3 §17.4: authenticated CAS refs, replicated receipt, retention roots and restore inventory |
| P5-B-28 | M5 §16.2: six required variables, exact credential mode, typed effective settings and separate limits |
| P5-B-29 | M5 §16.3: lifecycle operations, drain deadline, restart, migration commit point and owned removal |
| P5-B-30 | M5 §16.4: full live conformance union, memory, fixture separation, warning reduction and expiry |
| P5-B-31 | M0 §16.1: instrument names/types/units/buckets/labels, endpoint, retention and alerts |
| P5-B-32 | M0 §16: exact helper arity, counters, modes and transactional filesystem failure postconditions |
| P5-B-33 | M6 §16.1: build input/dialect/layout/output/determinism; B-DOC-LOCK blocks reproducible release until owner qualifies tool/font bytes |
| P5-B-34 | M6 §16.3: independent reviews, blocker rules, bounded waivers and authenticated exact-hash decision |
| P5-B-35 | M2 §15 and IV CT-05: worker delivery only; lane_seed belongs to CT-01 |
| P5-B-36 | M6 §6/flight card and IV CT-16/18: current builder/receipt/decision handoff, honest target coverage |
| P5-B-37 | IV.2.4: source coverage versus version-bound live qualification, external observable proof |
| P5-B-38 | IV.2.4 and chapter §6 tables: machine-readable 31-ID registry and legacy import-alias policy |
| P5-B-39 | M0/M1/M5 identity notes: pinned source inventory, historical/fixture/live separation and superseded claims |
| P5-B-40 | M1/M4/M6 runbooks: named missing-lib refusal, ERROR probe and existing source-gate path |

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

- **One versioned registry, 32 entries.** CT-01..CT-23, `CT-06R`, CT-24..CT-30 and the
  spec-derived CT-31 below
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
| CT-02 | scheduler → crier | envelope: run_id, corr_id, lane, board, text_b64 | async, bearer + signature | UNVERIFIED (legacy source located; target unqualified) |
| CT-03 | crier → node | inbox message + lease | pull; retrieval grants the lease (default 30 s, requester-adjustable) | UNVERIFIED (legacy source located; target unqualified) |
| CT-04 | node → crier | reply: status, dispatch_id, corr_id, branch, commit, artifacts | async, signed | PARTIAL |
| CT-05 | foreman → worker | immutable per-attempt worker-brief.v1, criteria, workspace | Crier custody / resident supervisor | TARGET-UNIMPLEMENTED |
| CT-06 | crier → scheduler | completion event for a finished run | async | UNVERIFIED (legacy source located; target unqualified) |
| CT-07 | router → gateway | model choice for a prompt | in-band | UNVERIFIED |
| CT-08 | crier → gateway | hermes-session delivery (message becomes a session turn) | sync (the 30 s figure is its historical mode/version's timeout, not a universal bound) | UNVERIFIED (legacy source located; target unqualified) |
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
| CT-22 | authority/controller → node → crier | single-use tuple-bound `enrollment-grant.v1` reference; then enrollment-issued Crier identity and class-`crier` credential reference, followed by `cf2a.v1`/`register.v1` agent registration + token exchange | target `POST /v1/factory/registrations`; class check precedes one identity allocation; exact repeats replay and conflicts return `REGISTRATION_CONFLICT`; measured `/agents` coverage boundary | UNVERIFIED — implementation producer not measured in-repo (CF-276); target actor and wire are normative |
| CT-23 | provisioner → bunker | create, exec, cp against the agent container | bunker CLI | UNVERIFIED |
| CT-06R | foreman → crier → scheduler | versioned round report and durable return | async, signed, correlated | TARGET-UNIMPLEMENTED |
| CT-24 | owner/agent → manager | desired configuration generation update | authenticated API/file, CAS | TARGET-UNIMPLEMENTED |
| CT-25 | manager adapter → manager | observed/effective readback | adapter result | TARGET-UNIMPLEMENTED |
| CT-26 | manager → adapters | deterministic reconciliation operation | durable async operation | TARGET-UNIMPLEMENTED |
| CT-27 | manager → eligible hosts | allocation reservation and shortfall | fenced resource transaction | TARGET-UNIMPLEMENTED |
| CT-28 | manager → crier/scheduler | verified readiness and binding activation | authenticated, generation-bound | TARGET-UNIMPLEMENTED |
| CT-29 | manager → recovery actors | incident, fence and replacement recovery | durable, idempotent | TARGET-UNIMPLEMENTED |
| CT-30 | manager → subscribers/operators | versioned event delivery and independent metric readout | durable cursor / read-only API | TARGET-UNIMPLEMENTED |
| CT-31 | provisioner → bunker Hermes config | gateway config envelope: `platforms.*` + `gateways.loop_watchdog` by `token_env` reference; scheduler `deliver`/`deliver_mode` as routing hint | config merge at provision/re-sync | SPEC-DERIVED (M13) — target-unimplemented |

## IV.5 Canonical record families

These are the records every other part references. Each has one closed shape, published
as a JSON Schema in `docs/handbook/conformance/schemas/`, and a fixture in
`docs/handbook/conformance/fixtures/`. A reader that needs a different shape versions the
record; it does not extend this one.

| Record version | Family | Owner | Fixture | Vectors |
|---|---|---|---|---|
| `cf.launch-commitment.v1` | execution | launching foreman | `launch-commitment.json` | `CV-16-A`, `CV-02-A` |
| `cf.launch-confirmation.v1` | execution | resident supervisor | `launch-confirmation.json` | `CV-16-A` |
| `cf.launch-input.v1` | execution | launching foreman | `launch-commitment.json` | `CV-16-A` |
| `cf.launch-response.v1` | execution | resident supervisor | `launch-confirmation.json` | `CV-21-A` |
| `cf.settlement.v1` | settlement | resident supervisor | `launch-confirmation.json` | `CV-21-B` |
| `cf.cancellation.v1` | execution | resident supervisor | `launch-confirmation.json` | `CV-22-A` |
| `cf.criterion.v1` | board | board row | `board-group-claim.json` | `CV-19-A` |
| `cf.evidence.v1` | evidence | judge / board | `board-group-claim.json` | `CV-25-A`, `CV-25-B` |
| `cf.board-group-claim.v1` | board | claimant | `board-group-claim.json` | `CV-19-A`, `CV-19-B` |
| `cf.memory-record.v1` | memory | foreman / judge | `memory-round-summary.json` | `CV-20-A`–`CV-20-C` |
| `cf.round-summary.v1` | memory | foreman | `memory-round-summary.json` | `CV-20-A` |
| `cf.round-report.v1` | memory | foreman | `memory-round-summary.json` | `CV-01-C`, `CV-20-A` |
| `cf.round-closure.v1` | memory | foreman | `memory-round-summary.json` | `CV-20-A` |
| `cf.config.v1` | configuration | owner / manager | `launch-commitment.json` | `CV-24-A` |
| `cf.crier.request.v1` `cf.crier.response-payload.v1` `cf.crier.receipt.v1` `cf.crier.envelope.v1` | custody | Crier | `custody-request-response.json` | `CV-17-A`, `CV-17-C`, `CV-18-A`, `CV-18-B` |
| `cf.enrollment-request.v1` `cf.enrollment-response.v1` | enrollment | controller / Crier | `launch-confirmation.json` | `CV-23-A` |

### IV.5.1 The executable criterion

A criterion has exactly three projections, and only the first can qualify a task:

| Projection | Fields | Rule |
|---|---|---|
| executable | `id`, `argv`, `cwd`, `expected_exit`, `timeout_s`, `oracle_digest` | `argv` is the program and its arguments, never a shell string; an empty `argv` is refused |
| storage | the same six fields as board-row columns | the board row stores the executable projection verbatim |
| display | `id`, `description` | prose is a projection of `description` only |

The board-to-brief adapter copies the six executable fields losslessly. A missing
`argv`, `cwd` or `expected_exit` is a typed refusal, not a default: a criterion that
silently acquires `cwd: "."` or `expected_exit: 0` from a fallback is a criterion nobody
wrote. Legacy `text` and `verification` fields remain migration evidence and cannot be
executed. `CV-19-A` carries the canonical instance; the empty-`argv` refusal is a bundle
negative arm.

### IV.5.2 Phase-discriminated evidence

One record, five phases, five non-interchangeable subjects. A record may not borrow a
later phase's subject to look complete, and a later phase may not rewrite an earlier
record.

| Phase | Subject | Proves |
|---|---|---|
| `staged` | `base_oid`, `commit_oid` (must be null), `tree_digest`, `policy_ref` | the pre-commit battery ran on the staged tree |
| `source` | `base_oid`, `commit_oid`, `tree_digest` | the committed tree carries the verdict |
| `integrated` | `base_oid`, `commit_oid`, `integrated_oid`, `tree_digest` | the post-merge tree was re-run |
| `publication` | `accepted_object {commit_oid, tree_digest}`, `observed_tip`, `ref` | the accepted object reached the remote; a later tip does not relabel it |
| `closure` | `accepted_object`, `closure_commit` | closure cites the publication record that permitted it |

A `staged` record names `commit_oid: null` because the object does not exist yet. An
implementation that wants to record a commit it already made is writing a `source`
record, not a staged one. Phases other than `publication` carry no `ancestry` and no
`decision` field at all; the schema refuses them rather than ignoring them.

Publication binds the accepted object by digest. The observed tip may advance, and the
only thing re-judged is ancestry: the accepted object must remain an ancestor of the
observed tip. A publication record whose `accepted_object` is rewritten to the new tip
is refused with `PUBLICATION_DRIFT` — the bytes that were accepted do not become
acceptable bytes by being superseded. `CV-25-A` publishes the five-phase chain for one
task; `CV-25-B` is the staged-names-a-commit refusal.

### IV.5.3 The canonical group claim

A claim has one bound, one ordering literal and one object-id form, and each of them
lives in exactly one place:

* `claims` is non-empty and its maximum length is the bound declared by
  `conformance/schemas/cf2a.board-claim.schema.json` `maxItems` — 256. M4 §15.2 and CT-10
  repeat the number and declare none of their own; a prose copy that disagrees with the
  schema is the defect, and a wider claim is a different record rather than a larger one.
  `CV-19-B` is the refusal.
* `ordering` is one literal: `created_seq ASC, id ASC; dependencies must be settled;
  correction retains its original worker`. A paraphrase is a second ordering, so the
  schema carries it as a `const` and a request with any other value is refused before a
  candidate tree is built.
* `board_revision` is a normal object id: 40 or 64 lowercase hex as a plain string. Never
  a nested `{algorithm,value}` object, never abbreviated, never flagged with `^{commit}`.
* One protected CAS covers every row, event and marker of the claim. A loser launches no
  partial wave, so a partially claimed group cannot exist.

The claims appear in `created_seq` then `task_id` order; that ordering is a property of
the board, not of array position, so a reversed list is refused rather than silently
re-sorted. A repeated `task_id` is refused for the same reason: the request would
otherwise carry two preconditions for one row and leave the reader to pick.

### IV.5.4 One memory envelope, discriminated by role

There is one memory record shape. The role is required, and the body is discriminated by
`record_type`:

| `record_type` | Required body fields | Nullable (present and null, never omitted) |
|---|---|---|
| `worker` | `task_id`, `attempt_id`, `outcome` | `commit`, `error` |
| `wave` | `wave_id`, `attempt_ids`, `outcome` | `stop_reason` |
| `round` | `round_id`, `state`, `wave_refs`, `budget` | `stop_reason` |
| `resolution` | `resolution_id`, `subject`, `outcome` | `rationale` |
| `decision` | `decision_id`, `subject`, `outcome` | `rationale` |
| `finding` | `finding_id`, `severity`, `summary` | `disposition` |

`writer` carries `writer_id`, `writer_role` and an optional `writer_generation` and
`owner_fence`. Earlier revisions wrote `writer_identity` and hyphenated body labels
(`worker-outcome`, `wave-summary`, `round-summary`). Those are labels, not fields: the
alias table maps each one onto the canonical name, and an importer that loses
`writer_role` while doing so is refused rather than trusted. `CV-20-C` is the lossless
import; `CV-20-B` is the lower-layer-names-a-higher-layer refusal.

The sync receipt stays outside `payload_digest`. A delivery acknowledgement arrives after
the record exists; letting it into the digest would mean a record's identity changes when
someone else confirms receipt of it.

### IV.5.5 The round summary, the report and the closure witness

The round summary and the final report are two records in one commitment chain, not one
record written twice:

1. The round-summary body carries the round outcome, wave references, budget and
   evidence references. It excludes `report_digest` and its own memory reference.
2. `round_summary_digest` is SHA-256 over that body.
3. The memory record wraps the body; `payload_digest` covers the record as stored.
4. The final report body may name `round_summary_digest` and `summary_memory_ref`.
   `report_digest` covers the report body excluding itself and its signature.
5. `cf.round-closure.v1` is an optional L2 witness naming both lower layers. It is
   referenced by neither, which is what keeps the chain acyclic.

No lower-layer summary digest includes `report_digest`; no final-report digest includes
its own memory reference. `CV-20-A` publishes the four records and their digests for one
round; `CV-20-B` refuses the summary that names the report.

### IV.5.6 Phase-discriminated cancellation

Cancellation is recorded where it landed, not where it was requested:

| Applied phase | Journal before → after | Terminal effect | Permit |
|---|---|---|---|
| `pre_admission` | none (no launch row) | `refused_no_launch` | never consumed |
| `prestart` | `RESERVED` → `CANCELLED` | `cancelled_before_start` | never consumed |
| `running` | `RUNNING` → `CANCELLED` | `signalled_quiesced` | already consumed |
| `terminal` | unchanged | `already_terminal` | no change |

A cancellation in the `running` phase is not complete when the signal is sent; it is
complete at quiescence, and the record carries both timestamps. A repeated cancellation
in the same phase is idempotent and produces the same `cancellation_digest`. A
cancellation after the terminal state changes nothing and is recorded with
`already_terminal` rather than being rejected silently — an operator who pressed cancel
after completion is owed a truthful record, not an error. A cancelled launch is never
counted as a success. `CV-22-A` carries all four phases.

### IV.5.7 The settlement record

A settlement carries six disjoint counts — `verified`, `unverified`, `failed`,
`cancelled`, `expired`, `unknown` — and no `total` field. The total is their sum, so a
settlement cannot disagree with itself. `revisions` counts late evidence revisions that
arrived after the settlement was written; it does not rewrite the settlement, and it is
what makes `settled_verified_then_reopened` a truthful outcome instead of a silent
retro-edit.

## IV.6 Total projection tables

The tables below are total: every input row maps to exactly one output row, and no row
is missing. "Total" is the property that makes a projection testable — a partial table
leaves the remaining states to be inferred by whoever writes the implementation, and two
implementations infer differently.

### IV.6.1 Journal state to launch response

| Journal state | Response `state` | `resolution` |
|---|---|---|
| `RESERVED` (admitted, permit not consumed) | `accepted` | `none` |
| `START_INTENT` persisted with no native proof | `unknown` | `quarantined`, reason `START_UNKNOWN` |
| `STARTED` with boot id, process instance and native session | `running` | `none` |
| `RUNNING` with a live heartbeat | `running` | `none` |
| terminal success with a `result_digest` | `succeeded` | `none` |
| terminal failure | `failed` | `none` |
| terminal cancelled before start | `cancelled` | `none` |
| terminal cancelled after quiescence | `cancelled` | `none` |
| `EXPIRED` at the admission deadline | `expired` | `none` |
| unreadable or conflicting journal record | `unknown` | `quarantined` |

The response state set is the seven values in the right-hand column. `unknown` is a real
state with a real cause, not a placeholder for a missing one: an ambiguity the control
plane cannot resolve is reported as ambiguity, and consumers are expected to handle it.
Coercing `START_UNKNOWN` into `failed` would report an execution failure that nobody
observed; coercing it into `running` would report liveness that nobody proved.

### IV.6.2 Outcome to settlement

| Outcome | Condition | Settlement |
|---|---|---|
| `settled_success` | every member verified | one success per verified member |
| `settled_failure` | any member failed | failure recorded; verified members keep their evidence |
| `settled_partial` | verified and unverified members together | `settled_partial`; the unverified members are named |
| `settled_unverified` | every member unverified | `settled_unverified`, no success counter |
| `settled_empty` | zero members or zero budget | `settled_empty`, budget consumed 0 |
| `settled_cancelled` | cancellation applied before terminal | `settled_cancelled`; cancelled members never counted as failed |
| `settled_expired` | admission deadline passed unstarted | `settled_expired` |
| `settled_unknown` | control state unresolvable | `settled_unknown`; quarantine retained, no settlement of the work |
| `settled_verified_then_reopened` | late evidence revision after settlement | settlement stands; `revisions` increments; closure re-opens |

Three rules follow from the table and are not negotiable:

* A uniformly unverified round settles as `settled_unverified`. It never settles as
  success because no member failed, and it never triggers a fresh execution as a
  consolation — re-running work to obtain a verdict is a new attempt with a new budget,
  not a repair of the old one.
* A zero-budget or zero-member round settles as `settled_empty`. It is not a success and
  not a failure; it is the honest record of a round that had nothing to spend.
* Late evidence does not edit history. The settlement that was true when it was written
  stays on the record, the revision counter moves, and closure re-opens.

`CV-21-A` and `CV-21-B` publish both tables as data with their counts.

## IV.7 The conformance bundle

`docs/handbook/conformance/` is the companion bundle required by P7-13. It holds the
machine-readable schemas, the non-secret fixture bytes and a manifest that pins the
digests of the model, the vector file, every schema and every fixture. The vector file
remains the single normative source of executable cases; the bundle points at it and does
not restate it.

The bundle exists because a specification that can only be understood by reading a
repository checkout is not a specification. Everything needed to check a record is in the
bundle: the schema for its shape, the fixture for its bytes, the manifest for its digest,
and one command to run.

Read it in this order: `manifest.json` for what is pinned and what each case asserts;
`schemas/` for the closed shapes; `fixtures/` for the bytes those schemas must accept and
reject; then `contract-vectors.json` for the digest arithmetic and the refusal outcomes.
`README.md` gives the single command that checks all of it and states what a pass means.

Two honesty rules apply to the bundle. A shape-only example is labelled shape-only in the
manifest and cannot be counted as a positive qualification — it proves the encoder and
decoder agree on structure, not that a deployment implements the contract. And the bundle
names its relation to the PDF bytes rather than implying it: the manifest records which
artifact the bundle was frozen against, and a reissued PDF whose digest differs is a
bundle that must be re-frozen.

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
- **Identity boundary (pass 7):** admission carries no launch identity. `launch_id`, the
  nonce, `dispatch_id` and `execution_key` are created later by the foreman and the
  supervisor under LCR-1 (§IV.2.5); the cold sequence `allocate → commit → derive →
  confirm` completes without any identity this edge would have had to predict.
  `CV-16-A` is the cold pass, `CV-16-B` the changed-identifier refusal.
- **Mode:** async, bearer + signature
- **State:** UNVERIFIED — historical source coverage is not target-version runtime proof
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
- **State:** UNVERIFIED — historical source coverage is not target-version runtime proof
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

### CT-05 — foreman → worker

- **Carries:** the complete worker-brief.v1 from §IV.2.1; immutable BriefInput ref,
  execution identities, claim/fence, criteria, workspace and enforced limits, plus the
  launch block: the persisted `cf.launch-commitment.v1` ref, its digest, the preallocated
  `launch_id` and the nonce.
- **Mode:** authenticated Crier custody to the resident supervisor.
- **State:** TARGET-UNIMPLEMENTED — no version-bound target fixture/live receipt is cited.
- **Sender guarantee:** the foreman allocates `launch_id` and the nonce and persists the
  commitment before delivery; it does not supply `dispatch_id` or `execution_key` (LCR-1,
  §IV.2.5). It reserves attempt identity and the exact brief before delivery (M2 §15).
- **Receiver requirement:** M5 §16.1 validates the commitment digest, derives
  `execution_key` and `dispatch_id` once from `{launch_id,input_digest}`, writes the
  confirmation and deduplicates before start. A request that carries its own derived
  identifiers is refused with `CONTRACT_INVALID`.
- **Vector:** `CV-16-A` (cold chain), `CV-16-B` (changed derived identifier),
  `CV-02-A` (the supervisor request carrying the same commitment).
- **Historical reclassification:** load_lane_config.py → buildForemanPrompt belongs to
  CT-01 lane_seed configuration, not this worker-launch edge.
- **To qualify:** run valid/invalid brief, duplicate delivery and crash-window cases
  against pinned producer/consumer releases and retain the §IV.2.4 record.

### CT-06 — crier → scheduler

- **Carries:** completion event for a finished run
- **Mode:** async
- **State:** UNVERIFIED — historical source coverage is not target-version runtime proof
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
- **State:** UNVERIFIED — historical source coverage is not target-version runtime proof
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** crier side named — hermesession.go:353 Client.Deliver (M10 §6)
- **Sender guarantee:** crier internal/hermesession/hermesession.go:353 — Client.Deliver; :554 POSTs /api/sessions at the gateway origin
- **Receiver requirement:** hermes gateway/platforms/api_server.py:1763 — POST /api/sessions creates the session row from the delivered message

### CT-09 — node → duckbrain

- **Carries:** R1 run record, R2 fleet index
- **Record frozen (pass 7):** `cf.memory-record.v1` with a required `writer` object
  (`writer_id`, `writer_role`, generation, fence), a body discriminated by `record_type`,
  nullable body fields present and null, and the sync receipt outside `payload_digest`
  (§IV.5.4). The round body carries no `report_digest` and no `memory_ref`; the report
  names the summary digest and the summary memory ref instead (§IV.5.5). Vectors
  `CV-20-A`, `CV-20-B`, `CV-20-C`.
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
- **Record frozen (pass 7):** `cf.board-group-claim.v1` — at most 256 claims, ordered by
  the immutable `created_seq` then `task_id`, one ordering literal, normal-object-id only,
  one protected CAS for rows, events and marker (§IV.5.3), plus the phase-discriminated
  evidence chain `staged → source → integrated → publication → closure` with a null
  `commit_oid` at `staged` and an accepted object bound by digest at `publication`
  (§IV.5.2). Vectors `CV-19-A`, `CV-19-B`, `CV-25-A`, `CV-25-B`.
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

### CT-16 — build service → acceptance service

- **Carries:** immutable cf.handbook-receipt.v1, source/build/review results and artifact ref.
- **Mode:** authenticated durable receipt transfer; M6 §16.2.
- **State:** TARGET-UNIMPLEMENTED — build_book.py is the current source producer, but
  no qualifying receipt adapter/readback record is cited.
- **Coverage:** master_doc_check.py's printed word is a retired numeric-module gate,
  not this receipt. Source lint alone never proves semantic or rendered acceptance.
- **To qualify:** produce/retrieve the typed receipt, refuse an omitted required stage,
  verify artifact bytes and repeat the same request without duplicate custody.

### CT-17 — conformance → readiness

- **Carries:** the complete cf.harness-conformance.v1 from M5 §16.4, including all
  required live legs, mode, expiry and evidence refs.
- **Mode:** authenticated qualification report and readiness readback.
- **State:** UNVERIFIED — historical fixture runs do not qualify target live support.
- **To qualify:** every required live leg passes, all named negative controls fail
  appropriately, and a fresh node restart preserves settings, sessions and memory.

### CT-18 — artifact service → owner → decision service

- **Carries:** exact artifact plus CT-16 receipt, then cf.handbook-decision.v1.
- **Mode:** authenticated human review; M6 §16.3.
- **State:** TARGET-UNIMPLEMENTED — no target owner decision receipt is cited.
- **Producer:** current build_book.py path and the required receipt/delivery adapter;
  gen_nasa_handbook.py's retired renderer is not the target producer.
- **Consumer:** human owner and authenticated decision service, not an in-repo
  function in a person. A valid decision binds artifact digest and permitted waivers.
- **To qualify:** read back the exact owner's durable decision, reject unauthorized
  approval and artifact mismatch, and prove same-key replay without a second decision.

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


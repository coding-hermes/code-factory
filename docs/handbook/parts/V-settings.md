# Part V — Settings register

## V.0 The governing control model

The Factory's foundation is a deterministic infrastructure-as-code management layer. It
holds declared desired state, observes actual state, maps and manages the settings of its
participating systems, and continuously reconciles drift and failures so the project
execution environment remains available and correct. LLM foremen and agents plan and
implement project work; the infrastructure convergence mechanism is deterministic code —
infrastructure maintenance never depends on an agent improvising the manual sequence of
many tools.

This part defines that layer's configuration contract. The inventory of measured
surfaces (M0–M12) follows in "The measured inventory"; the contract governs the whole
system, including the components the thirteen module chapters predate.

**Authority boundary (V2-SET-08, user-resolved).** The configuration file is the declared
desired-state authority, editable by the human user or an authorized agent acting on the
user's behalf, through the documented validation/update interface of V.6. Boardctl
remains the work authority: it carries project tasks, claims and evidence, and no setting
in this register makes Boardctl a configuration authority or requires a repo-linked
configuration format. Three versioned representations are kept separate:

| Representation | What it is | Owner | Where it lives |
|---|---|---|---|
| **Desired** | the declared intent — host pools, capacity, access, policy | the user or an authorized agent | the configuration file (versioned, generation-numbered) |
| **Observed** | the management service's durable inventory of actual state | the management/reconciliation service | its state store |
| **Effective** | the values actually serving, read back from each participating system | each owning subsystem, read back by the manager | subsystem surfaces, exposed through readback contracts |

Reconciliation status — converged, degraded, failed, per scope — is durably recorded
against the generation it describes. A generation whose reconciliation never completed
does not silently become the current truth.

**Allocation shortfall is exposed, never absorbed.** Project configuration declares an
eligible pool of hosts and host/Bunker resource and storage requirements or limits. The
manager maps them into a deterministic allocation contract and may rebalance Bunkers
across eligible surviving capacity after host loss — without changing desired counts,
access or policy. When allocation cannot converge, the manager preserves the desired
request and reports the exact unsatisfied requirements and affected scope as visible
operational state and evidence (metrics, V.6 events); it does not silently lower the
desired state to match the shortfall.

**Operational maintenance does not rewrite intent.** Authorized operational maintenance —
credential expiry renewal, configured leak-triggered revocation and replacement, placement
repair — is part of managed current state. Automatically changing a credential or a
placement never authorizes rewriting the user's desired access, capacity or policy intent.

**Field classes.** Every field in the desired-state schema is classified as one of:
**user intent** (changes only through the declared update interface), **derived** (computed
from intent, recorded but not independently editable), **observed** (written only by the
manager from readback), **secret reference** (names a credential, safe to print), or
**secret material** (never appears in desired state at all — V.4). Which fields may change
automatically follows from the class: observed fields change continuously; secret
references change only through rotation procedures; user intent never changes
automatically.

No repository location, serialization language, or numeric limit for the desired-state
file is selected by the review; the schema below defines shape and semantics. Examples
render in YAML for readability — the serialization is an implementation choice, not a
decision recorded here.

### V.0.1 Canonical desired-state schema (`factory.v1`)

The following is the normative top-level index, completed recursively by V.9. A deployment may add extension fields only
under an `extensions` map; unknown fields elsewhere are refused as `UNKNOWN_FIELD`.
Required fields are marked `required`; omitted optional fields have the stated absence
semantics. The configuration file is the user/authorized-agent declaration; observed and
effective values never overwrite it.

| Path | Type / requiredness | Validation, default and precedence |
|---|---|---|
| `schema_version` | enum `factory.v1`, required | any other version is `UNSUPPORTED_VERSION` |
| `generation` | integer >= 1, required | immutable after write; update requires `expected_generation` |
| `deployment.profile` | enum `kubernetes`, `compose`, `homelab-vpn`, `standalone`, required | no implicit profile; value must resolve in `profiles`; unsupported prerequisites yield `PROFILE_UNSUPPORTED` |
| `deployment.endpoints` | map `name → {url, protocol, credential_ref?}`, required | every selected-profile endpoint name must resolve; `url` is `https` or `ssh`; absent optional credential means anonymous only |
| `profiles` | map `profile_id → {isolation, terminal_jail, persistence?}`, required | profile IDs match `deployment.profile` and every `projects[].bunkers.profile`; unknown profiles are `PROFILE_UNKNOWN`; no implicit profile |
| `hosts[]` | objects `{id, endpoint_ref, capacity, capabilities}`, required | IDs unique; `endpoint_ref` resolves in `deployment.endpoints`; capacity is a declared limit, observed availability is separate |
| `projects[]` | objects `{id, repository, eligible_hosts, bunkers, memory, lanes}`, required | project IDs unique; all host and endpoint references must resolve |
| `projects[].repository` | `{provider, url, credential_ref}`, required | `provider` is `github` or `gitlab`; `url` is repository identity and `credential_ref` is a `secretref://forge/...`; neither may stand in for the other |
| `projects[].eligible_hosts` | non-empty list of host IDs, required | allocation considers only this declared set; no silent expansion |
| `projects[].bunkers` | `{count, requirements, profile}`, required | `count` integer 1..1024; requirements name disk/memory/network/capability constraints; profile resolves to a declared profile |
| `projects[].memory` | `{namespace, local_root, remote_ref, sync_policy}`, required | namespace matches the project id; `local_root` is durable; `remote_ref` is required for `shared-git` and absent only for `local-only` |
| `projects[].lanes[]` | `{name, admission, cadence_s, weight, foreman}`, required | lane names unique; admission is `tasks` or `cooldown`; `cadence_s` is 1..31536000 and `weight` is 1..1000 |
| `projects[].lanes[].foreman.round` | `{worker_budget, concurrency, retry_policy}`, required | `worker_budget.total` is 1..100000; `concurrency` is 1..1024; retry policy is explicit and cannot replenish total budget |
| `events.webhooks[]` | `{subscription_id, endpoint_ref, event_types, project_scope, status, retry_policy, retention_s}`, optional | absent means no delivery; `event_types` is a non-empty set from the catalog; endpoint secret material is referenced only; interpretation remains receiver-owned |
| `safety` | `{terminal_jail, reclaim, backup}`, required | Terminal Jail defaults to `disabled`; enabled mode requires the guarded execution path and has no unguarded fallback |
| `extensions` | map, optional | preserved but not interpreted by core reconciliation |

Canonical precedence is `field update generation` → project → deployment profile →
global default, with native subsystem overrides permitted only when explicitly mapped in
the adapter. An explicit empty value is either rejected or has the card's stated absence
meaning; it never falls through silently. A valid file is first schema-validated, then
cross-field validated, then committed as a new generation. A stale `expected_generation`
returns `GENERATION_CONFLICT` without changing the file. Effective readback is obtained
from the owning subsystem and is exposed separately as `effective`; a missing or stale
readback is `degraded`, never `converged`.

### V.0.2 Canonical update/readback API

The target management surface is `factory.v1` and has these observable operations:

| Operation | Request / result | Refusal or degraded result |
|---|---|---|
| `GET /v1/config` | `{desired, observed, effective, generation, status}` | `404 CONFIG_UNAVAILABLE` when no generation exists |
| `PUT /v1/config` | `{expected_generation, desired, idempotency_key}` → `202 {operation_id, generation}` | `409 GENERATION_CONFLICT`; secret material is `422 SECRET_MATERIAL_FORBIDDEN` |
| `POST /v1/reconcile` | `{generation, idempotency_key}` → `202 {operation_id, status: accepted}` | `409 GENERATION_NOT_CURRENT`; same-key retry returns the original operation |
| `GET /v1/operations/{operation_id}` | per-adapter states, acknowledgements, effective readback | `200 degraded` when any required readback is missing/stale; never `converged` |
| `GET /v1/readiness/{project_id}` | `{profile, generation, binding_generation, probes}` | `503 NOT_READY` until authenticated operation probes and Crier/Scheduler bindings pass |
| `GET /v1/events` | versioned event cursor and delivery state | receiver outage is recorded per endpoint; it does not alter configuration status |

Every mutation is authenticated, scoped, durable before adapters run, and idempotent by
`(principal, scope, operation, idempotency_key)`, where scope is `factory-control`
for whole-document/global operations and the authorized project ID for project reads/
reconcile. Part I §1.9.1 supplies the exact mTLS HTTP wrapper, principal derivation,
response/Error schema and route retirement rules; there is one generation, not a
second project/global tuple. A project edit after any global change re-reads the
whole document and submits the new expected_generation with only its allowed project
changed. The request digest is stored as
compared data, not part of the identity. A changed request under an existing key returns
`IDEMPOTENCY_KEY_REUSED`; a same request returns the original result. The API never
claims convergence from request acceptance alone.

### V.0.3 Factory event delivery and metric readout

Factory events use `event.v1`. The manager emits only delivery facts; receivers own
interpretation, paging, logging and repair-agent action (resolved decision P3-09). Every
event carries `event_version`, `event_id`, `event_type`, `occurred_at`, `source`,
`project_id` where scoped, `generation`, `operation_id` where applicable, and a payload
whose type is fixed by `event_type`. The minimum catalog is:

| Event | Occurs when | Required payload |
|---|---|---|
| `configuration.accepted` | a desired generation is durably accepted | generation, actor, request digest |
| `reconciliation.state` | an operation changes state | operation id, old/new state, reason |
| `allocation.shortfall` | declared capacity cannot be allocated | requirements, eligible hosts, unsatisfied amount |
| `readiness.changed` | effective readiness or binding generation changes | profile, probes, old/new readiness, binding generation |
| `credential.lifecycle` | reference is issued, renewed, revoked or replaced | domain, reference, scope, action, reason; never secret material |
| `memory.sync` | local record sync changes state | namespace, record id, local commit, sync state, freshness |
| `factory.failure` | an operation or adapter enters failed state | operation, adapter, typed error, retry eligibility |

A subscription uses `{subscription_id, endpoint_ref, event_types, project_scope,
status, retry_policy, retention_s}`. `endpoint_ref` is a secret reference. The manager
persists the event before delivery and tracks per-endpoint `attempt`, `acknowledged_at`,
`next_retry_at`, `last_error`, `delivery_state` and `cursor`. The receiver contract is
an HTTPS POST with `Content-Type: application/json`, `X-Factory-Event-Id`,
`X-Factory-Event-Version`, `X-Factory-Delivery-Attempt`, and `X-Factory-Signature`.
The signed headers additionally include `X-Factory-Key-Id` and
`X-Factory-Delivery-Time` (decimal Unix seconds). X-Factory-Signature is lowercase
hex HMAC-SHA256 over UTF-8 `factory-event-v1`, newline, key ID, newline, delivery
time, newline, event ID, newline, followed by exact body bytes (no final newline
added). IDs contain no newline; the body is RFC8785 JSON. Verification checks key ID,
signature and ±60 s delivery-time skew before accepting. occurred_at remains the
original event time; cursor replay signs a fresh delivery time with the active key.
A receiver durably deduplicates event_id/body digest; changed digest is 409 conflict.
A stale or unknown-key delivery returns 401 and cannot advance the cursor.
The body is the `event.v1` object from this section. A valid receiver returns HTTP 202
(or 200) with JSON `{event_id, acknowledged: true}`; any other status, malformed JSON,
wrong event id or missing acknowledgement is `ACK_INVALID`. The same event is
redelivered with the same `event_id` and is not re-authored as a new event. Defaults
are timeout 10 s, max_attempts 5, initial backoff 5 s, maximum backoff 300 s, and
retention 604800 s. Retry n waits a uniformly sampled integer millisecond delay in
`[0, min(300000, 5000 * 2^(n-1))]`, persisted when scheduled; restart does not redraw it.
After exhaustion the event is `delivery_failed` and remains available for replay by
cursor. Later events may deliver, but the contiguous acknowledgement cursor stops
before the failed event; an administrator may explicitly dead-letter/skip it with a
reason receipt, never silently advance it. Replay is ordered by durable sequence and
retention_s; an expired cursor returns 410 CURSOR_EXPIRED with earliest available seq.
Endpoint outage does not change configuration or reconciliation state. Signature or
authentication failure is `ENDPOINT_UNAUTHORIZED`; it is not delivery success.
Receiver interpretation, paging and external repair remain outside Factory responsibility.

A minimum `project.progress` extension uses `event_type: project.progress` and payload
`{project_id, initiative_id, completed, total, unit: "criteria", status, evidence_refs}`;
`completed` and `total` are integers with `0 <= completed <= total`, and `status` is
`in_progress`, `blocked` or `complete`. This extension is emitted by the foreman path;
receivers still own interpretation and paging.

The manager independently serves metrics at a read-only versioned endpoint. Each metric
has a name, metric type, unit, bounded labels, collection owner, reset semantics,
loss/unknown semantics and readout scope:

| Metric | Type / unit | Labels and sample semantics | Owner / reset |
|---|---|---|---|
| `reconciliation_operations_total` | counter / operations | `state` from the transition enum; one sample per durable transition | manager; resets only on process replacement, with `start_time` recorded |
| `allocation_shortfall` | gauge / requested resource units | `project`, `resource`; quantity is the declared minus allocated amount, never a mixed unit | manager; current value, `unknown` if no observation |
| `readiness` | gauge / boolean 0 or 1 | `project`, `profile`; absent probe is `unknown`, not 0 | manager; current observation |
| `event_delivery_total` | counter / deliveries | `endpoint`, `state`; endpoint ids are bounded and secret-free | manager; resets only with `start_time` |
| `memory_sync_pending` | gauge / records | `namespace`; count of durable pending records | memory adapter; current value, `unknown` if store unavailable |
| `effective_readback_age_seconds` | gauge / seconds | `scope`; age since the newest accepted effective readback | manager; `unknown` when no readback exists |

Counters increment only after the corresponding durable transition. A sample carries
`metric_schema_version`, `metric_name`, `metric_type`, `unit`, bounded `labels`, `value`
or `unknown`, `observed_at`, `collection_state` and `reset_at`/`start_time` as applicable.
`GET /v1/metrics` returns those samples; a missing sample is not a successful zero.
Metric collection and serving are manager responsibilities; receiver dashboards may
consume them but do not redefine their meaning.

## V.1 Scopes and the complete participating-system inventory (V2-SET-01)

Every setting belongs to a scope, and every participating system has a settings surface
in exactly one of the five classes of V.2. A settings pass covers the full system — not
only the thirteen original module tables.

**Configuration scopes:**

| Scope | What it binds | Decided by | Examples |
|---|---|---|---|
| global | Factory-wide defaults | user intent | default deployment profile, event/webhook endpoints, retention policy |
| deployment | one chosen deployment topology (Kubernetes, Compose, homelab/VPN, standalone) | user intent per deployment | profile selection, connectivity endpoints, bootstrap ownership |
| profile | one named per-Bunker profile | user intent per profile | isolation basis, persistence, mounts, resource controls |
| project | one project's desired runtime | user intent per project | repo, eligible host pool, resource/storage requirements, memory namespace |
| Bunker | one Bunker's effective configuration | profile application + operational state | resolved mounts, installed credentials (as references), agent identity |
| lane | one scheduling lane | user intent per lane | cadence, admission mode, weight, model routing |
| job | one dispatched job | the dispatching actor | turn budget, wall clock, worktree, brief |

**Participating systems — the complete surface:**

| System | Settings surface | Register owner | State |
|---|---|---|---|
| Management/reconciliation service | desired-state store, reconciliation policy, allocation, health/repair | this part (V.0–V.8) | TARGET-UNIMPLEMENTED — the service is a v2 product requirement |
| Scheduler (M9) | 57 daemon flags, three-layer merge | measured inventory below | SUPPORTED |
| Crier bus (M10) | config.go defaults + `CR_*` env bounds | measured inventory below | SUPPORTED |
| Dispatcher (M11) | `DISPATCH_*` env surface | measured inventory below | SUPPORTED; inert rows named |
| Bunker platform (M1/M5/M8) | provisioning config keys, spawn/mount/resource controls | measured inventory below | SUPPORTED paths; profile choice UNRESOLVED |
| Harness adapters (M5) | `CF_*` variable contract + per-adapter pins | measured inventory below | SUPPORTED; Hermes pinned for MVP |
| Inference proxy (M12) | `CF_PROXY_*` env + fixed constants | measured inventory below | SUPPORTED; upstream source UNVERIFIED |
| Boardctl board (M4) | wrapper verbs and validation flags | measured inventory below | SUPPORTED — work authority, not configuration authority |
| DuckBrain memory | namespace/data-root configuration, sync target | Part V (this part) + M4/M5 review | local namespace SUPPORTED; shared topology UNRESOLVED |
| GitReins (M3) | version pin, hook installation | measured inventory below | SUPPORTED |
| Forge credential issuers | GitHub App (M7); GitLab and other required forges | M7 + provider-adapter rows | GitHub SUPPORTED (mint UNVERIFIED); additional providers TARGET-UNIMPLEMENTED — provider list is not invented |
| Model router / provider access | resolver controls (M5), proxy route (M12) | measured inventory below | SUPPORTED |
| Handbook builder (M6) | build gates, fill engine | measured inventory below | SUPPORTED |

Systems outside the original M0–M12 module chapters carry their settings in the
target-schema sections of this part; where a required capability has no native surface,
the affected profile is marked unsupported with a named reason — a hardcoded
implementation choice must not silently veto a required target setting. Existing
subsystem schema/readback facilities (the scheduler's `schema`/`show-config` switches,
M9 §5) are reused through adapters rather than duplicated.

## V.2 Setting classification

Every control in this register is one of five classes. Listing a variable does not make
it a supported control; the class is part of the contract.

| Class | Definition | Examples (measured) |
|---|---|---|
| **NATIVE** | the owning subsystem exposes the control directly — env var, flag, config key or API — and changing it changes behavior | `CR_REGISTRY_BACKEND` (M10); scheduler `listen` (M9); `CF_MAX_TURNS` (M5) |
| **WRAPPER-MAPPED** | a Factory adapter maps a canonical key onto a native control; the canonical key is the contract | `node_env.py --config-set KEY=VALUE` → `$HOME/.hermes/.env` / `config.yaml` (M1); `bunker_config_gen.py` flags → node config (M1) |
| **FIXED CONSTANT** | hardcoded in the implementation; named because a reader may mistake it for a setting | the proxy `LISTEN` bind (M12); `fetch_verified --max-time` 120 s (M0); the spine gate's four sets (M6) |
| **INERT / DEPRECATED** | present in the surface but without effect in this revision | `DISPATCH_EXEC_TIMEOUT` — assigned, never read (B22, M11); `panel_loop.py --start-round`'s resume semantics (B12, M6) |
| **REQUIRED-BUT-UNSUPPORTED** | the approved target requires the control; no native surface exists; the affected profile is unsupported with a named reason | per-Bunker profile readiness readback (V, matrix row RED); cross-system timing validation (V.5) |

Constants that a chapter explicitly excludes from its settings surface are named in a
note, not given rows — the chapters refuse them the status of settings and this register
records that refusal rather than overruling it. Where a required target setting needs a
code change to exist, it is classified here — not presented as available.

## V.3 The per-setting contract (V2-SET-02)

Every supported setting carries the full contract, in one place. A row without all
twelve fields is a named RED on the missing fields, not a complete card:

1. **Canonical key** — the stable identifier, namespaced by scope (e.g.
   `project.worker_budget.total`).
2. **Native mapping** — the exact env var / flag / config key / API field each
   participating system reads it from, or "none" for a target setting.
3. **Scope** — one of the seven of V.1.
4. **Purpose** — what the setting decides.
5. **Type / units** — with byte/second/count stated.
6. **Range / enum** — valid values; the refusal outside them.
7. **Default / absence semantics** — what unset, empty and zero each mean, separately.
8. **Dependencies** — cross-field constraints and interactions.
9. **Validation + typed error** — what rejects a wrong value and the named error emitted.
10. **Authorized editor** — which field class (V.0) and which actor may change it.
11. **Activation** — next exec / next spawn / next tick / restart / reconcile.
12. **Effective readback** — the command that proves which value is serving, redacted per
    V.4; plus **examples**.

Two worked cards, one target and one measured:

**Card 1 — `foreman.round.worker_budget.total`** (target setting, V2-Q-02):

| Field | Value |
|---|---|
| Canonical key | `foreman.round.worker_budget.total` |
| Native mapping | none — the scheduler injects an allowance; the foreman allocates it across waves |
| Scope | lane (per-project lane running foreman rounds) |
| Purpose | the total number of workers available to one foreman round, across all its waves |
| Type / units | integer, workers |
| Range / enum | >= 1; a value < 1 refused at admission |
| Default / absence | TARGET: a declared default is a specification detail this register leaves to implementation reconciliation; absence refuses admission (fail-closed) rather than defaulting silently — unset, empty and zero are the same refusal |
| Dependencies | distinct from concurrent-workers and from any wave-count limit (no separate fixed wave cap is imposed); not bounded by platform concurrency; only simultaneous workers are bounded by that separate ceiling (VII.12) |
| Validation + typed error | admission validates the round request; error class `BUDGET_INVALID` names the field and the offending value |
| Authorized editor | user intent |
| Activation | the next admitted round; a running round's allowance is fixed at admission |
| Effective readback | the round report's budget-use section (remaining allowance observable per round and per wave) |
| Examples | `total: 8` admits a round that may launch up to 8 workers across any number of compatible waves; a failed start consumes the reservation unless the accounting mode returns it (VII §16) |

**Card 2 — `CR_REGISTRY_BACKEND`** (measured, M10 §5):

| Field | Value |
|---|---|
| Canonical key | `transport.registry.backend` |
| Native mapping | env `CR_REGISTRY_BACKEND`; resolved by `ResolvedRegistryBackend()` (`config/config.go:113-123`) |
| Scope | global (the bus custody store) |
| Purpose | which registry backend holds deliveries and inboxes |
| Type / units | enum: `memory`, `sqlite`, `postgres` |
| Range / enum | the three backends; resolution chain: explicit backend → a `sqlite:` `Database.URL` → any non-empty `Database.URL` (postgres) → `memory` |
| Default / absence | absence resolves to `memory` — process-local, demo-only; absence is itself the hazard (VI §2) |
| Dependencies | `Database.URL` participates in the resolution chain |
| Validation + typed error | the `CR_GUARD_*` bounds refuse non-numeric/`<= 0` values with a named error; the backend itself is not range-validated — an unreachable `sqlite:` URL fails at use |
| Authorized editor | user intent (operational) |
| Activation | restart |
| Effective readback | **no readback exists — a named RED on M10 §5**; the card's own honesty rule: a setting whose readback is not yet written is a RED, not a silent gap |
| Examples | `CR_REGISTRY_BACKEND=sqlite` → durable custody across restart; unset on a deployment holding real work is the VI §2 failure class |

## V.4 Secrets: stores, references and redaction (V2-SET-04)

**No secret backend is selected by the review.** This register defines the contract any
supported store must meet, and the reference/redaction rules that hold regardless of
which backend is chosen.

**Secret-reference syntax.** Desired state, management API payloads and plan/diff output
name credentials only as references, canonically
`secretref://<domain>/<name>` — e.g. `secretref://forge/github/app-private-key`,
`secretref://model/proxy/upstream-key`. `<domain>` is one of the separately-mapped
authority domains below; the reference resolves through the store configured for that
domain. Secret material never appears in: desired-state files, API responses, plan/diff
output, logs, webhook events, or backups of desired state. Each of those surfaces carries
an explicit redaction rule — a reference passes verbatim; a value is refused at write
time (validation, V.6) and elided at read time.

**Authority domains, mapped separately:**

| Domain | Holds | Read a value | Hold a reference only |
|---|---|---|---|
| forge | GitHub App identity/private key, GitLab and other provider credentials, deploy keys | the issuing boundary (control-side signing authority, M7) | nodes and Bunkers (scoped per-repo credentials only) |
| bunker | Bunker control/agent authentication | the Bunker installer/operator boundary | Crier, scheduler, workloads |
| transport | Crier bus bearer, dispatcher signing keys | the dispatcher/bus on their host | — |
| model | inference proxy upstream key, node tokens | the proxy owner's env boundary (M12) | nodes (token files by path, never values) |
| memory | DuckBrain/local-filesystem authorization | the memory service owner | foremen and workers |
| events | typed webhook destination bundle `{url: HTTPS URL, active_key_id: ID, keys: [{id, hmac_key_ref, valid_until}]}` | manager delivery worker and authorized receiver key provisioner | subscription endpoint_ref; host endpoint_ref instead resolves deployment.endpoints |
| backup | encryption recipient and recovery-key reference | backup writer (public encryption key) and offline recovery custodian (private key) | backup configuration |

An events reference resolves to destination metadata plus references to 32-byte HMAC
keys, not a naked URL or concatenated credential. The secret store separately resolves
key bytes only for authorized sender/receiver provisioning. Rotation atomically changes
active_key_id and preserves verification keys for 300 s; URL changes require a new
subscription generation and do not silently reuse an old destination key.

**Issuance vs installation.** The native issuer (GitHub App JWT mint, provider API)
retains signing/administrative authority at its boundary; Bunker
installation/provisioning scripts are the delivery mechanism that puts scoped credential
references and material into the required runtime locations (user decision). Installation
is verified by readback without exposing values: fingerprint listings (sha256 prefixes),
mode checks and presence probes — never printed material.

**Lifecycle.** Expiry, renewal, rotation and revocation are operational capabilities with
declared authority (V.0): renewal follows the native provider lifecycle; a configured
leak signal triggers revocation and replacement; revocation is explicit, never implied by
age; revoked state is preserved across backup/restore so a restore cannot reactivate
compromised credentials (VI §21, §17).

**Mode predicates — measured vs target.** The measured surface contains two lying
predicates: `harness-vars.sh:203` accepts any mode `[0-7]00` while its refusal message
claims "a key file must be 600", and its ambient-key check accepts `CF_API_KEY=""` (F0-6);
`bunker-provision.sh --check` reports "mode 600" while probing only non-emptiness (F1-1).
The target law is: private-key material at mode 0600-class, enforced by a predicate whose
refusal message states what it actually tested. The measured behavior stays recorded in
the inventory rows and the finding IDs; it is not normalized into the target law, and the
target is not claimed as deployed.

## V.5 Timing, lease and budget compatibility (V2-SET-06)

These are different quantities and must never be conflated:

| Quantity | Native surface | Order of magnitude (measured) | Class |
|---|---|---|---|
| Total workers per foreman round | target `foreman.round.worker_budget.total` (V.3 card 1) | configurable | REQUIRED-BUT-UNSUPPORTED |
| Concurrent workers within a wave | distinct setting; bounded by any platform concurrency ceiling | configurable, separate | REQUIRED-BUT-UNSUPPORTED (ceiling: profile) |
| Per-turn wall clock | `CF_TIMEOUT_S` (M5) | 1800 s (codex adapter re-defaults 300) | NATIVE |
| Turn budget | `CF_MAX_TURNS` (M5) | 40 | NATIVE |
| Crier inbox lease | `DEFAULT_LEASE_SECONDS` (M2) / retrieve lease | 30 s | NATIVE |
| Inbox long-poll budget | `--wait-seconds` (M2) | 0..120 s | NATIVE |
| Dispatcher envelope wall | `DISPATCH_TASK_CAP_S` (M11) | 7200 s | NATIVE |
| Scheduler tick wall | `tick-timeout` (M9) | 7200 s | NATIVE |
| Per-request transport call | `fetch_verified --max-time` (M0) | 120 s | FIXED CONSTANT |
| Inert "timeout" | `DISPATCH_EXEC_TIMEOUT` (M11) | — | INERT |

**Compatibility validation at admission.** Impossible combinations are validated when
configuration is applied, not discovered at runtime: a round budget below one worker; a
round deadline exceeding the tick cap; attempt wall exceeding remaining round time
minus reserves; a lease that cannot cover renewal latency/skew; a tick timeout shorter
than the round it launches. V.9 defines the exact inequalities. `CF_TIMEOUT_S` bounds
the entire harness invocation, not each of its model turns; multiplying it by
`CF_MAX_TURNS` is not a valid compatibility test. The
cross-field check is a target requirement — where no cross-system validation exists today
it is TARGET-UNIMPLEMENTED, and the affected combination is recorded here rather than
implied safe. Hardcoded account-specific paths (`BUNKER_BIN`, `TOKEN_FILE`, M11/M12) are
replaced by declared profile mappings in the target; the hardcoded values remain recorded
in the inventory as measured evidence. The supported Hermes variant, GitReins policy
version, binaries, images and adapters are pinned with migration compatibility
(`HERMES_PIN` 0.19.0, `GITREINS_PIN` 0.17.1, et al., inventory below) — pins are
re-verified at implementation reconciliation, never copied forward as freshly approved.

## V.6 The configuration lifecycle and propagation (V2-SET-03)

The lifecycle is an ordered chain; each stage owns an outcome:

1. **Authorized update.** A desired-state edit arrives through the documented
   validation/update interface — file write or management API call, by an authorized
   editor (V.0). The management HTTP surface is published as OpenAPI, generated from the
   same model as the configuration schemas, so API contracts and settings schemas cannot
   drift apart.
2. **Validation.** Schema validation plus cross-field checks (V.5): a wrong value is
   refused with its typed error before anything is persisted; secret material in desired
   state is refused at this boundary (V.4).
3. **Versioned persistence.** The accepted edit is stored as a new generation of the
   desired state; the previous generation is retained.
4. **Deterministic diff/plan.** The manager computes desired-vs-observed differences as
   a plan; plan output carries secret references, never material.
5. **Reconciliation.** Queued or immediate per the setting's activation class; concurrent
   edits resolve by generation compare-and-swap — a stale generation is refused with a
   named conflict error, never last-writer-wins silently.
6. **Ordered adapter changes.** Each participating system's adapter applies its share;
   idempotent re-apply; partial propagation is tracked per node with acknowledgements and
   retried with backoff — a node that did not acknowledge is degraded, not converged.
7. **Effective readback.** Each change is proven by the setting's readback (V.3 field
   12); a setting whose readback fails leaves the scope degraded.
8. **Status.** Converged / degraded / failed is recorded against the generation, exposed
   via the management API, metrics and configured webhooks (V2-OPS-02); activation
   barriers, safe restart/drain, rollback or forward repair follow the owning flow (F13).

Installed settings survive daemon restart, replacement placement and resync: a
re-provisioned host re-applies the desired generation through F2 rather than inheriting a
competing config source, and no unmanaged source silently overwrites a managed value.
The lifecycle control-flow figure is a named gap in this revision — this wave's scope
keeps figures/ unchanged — and the ordered steps above are the normative statement until
the figure lands.

## V.7 Example desired-state file and resolved-state comparison (V2-SET-07)

A complete example (YAML for readability; the serialization is not decided):

```yaml
# CF2A desired state — factory.v1, generation 17
schema_version: factory.v1
generation: 17
deployment:
  profile: homelab-vpn
  endpoints:
    h1-vpn: {url: https://h1.example.invalid, protocol: https}
    h2-vpn: {url: https://h2.example.invalid, protocol: https}
    backup: {url: https://backup.example.invalid/factory, protocol: https}
hosts:
  - id: h1
    endpoint_ref: h1-vpn
    capacity: {disk_gib: 80, memory_gib: 16, concurrent_workers: 2}
    capabilities: [hermes, git]
  - id: h2
    endpoint_ref: h2-vpn
    capacity: {disk_gib: 80, memory_gib: 16, concurrent_workers: 2}
    capabilities: [hermes, git]
profiles:
  homelab-vpn: {isolation: persistent-container, terminal_jail: disabled}
projects:
  - id: code-factory
    repository:
      provider: github
      url: git@github.com:example/code-factory.git
      credential_ref: secretref://forge/github/deploy-key.cf2a
    eligible_hosts: [h1, h2]
    bunkers:
      count: 2
      requirements: {disk_gib: 40, memory_gib: 8, capabilities: [hermes, git]}
      profile: homelab-vpn
    memory:
      namespace: code-factory
      local_root: /var/lib/factory/memory/code-factory
      remote_ref: https://memory.example.invalid/git/code-factory.git
      sync_policy: shared-git
    lanes:
      - name: builder
        admission: tasks
        cadence_s: 300
        weight: 100
        foreman: {round: {worker_budget: {total: 8}, concurrency: 2,
          retry_policy: {name: charge-on-start, failed_start: refund-before-run}}}
events:
  webhooks:
    - subscription_id: ops
      endpoint_ref: secretref://events/ops-webhook
      event_types: [configuration.accepted, reconciliation.state, allocation.shortfall,
        readiness.changed, credential.lifecycle, memory.sync, factory.failure]
      project_scope: [code-factory]
      status: enabled
      retry_policy: {max_attempts: 5, initial_backoff_s: 5, max_backoff_s: 300}
      retention_s: 604800
safety:
  terminal_jail: disabled
  reclaim: {enabled: true}
  backup: {enabled: true, destination_ref: backup, key_ref: secretref://backup/recovery}
extensions: {}
```

Resolved-state comparison (how the same file reads back):

| Key | Desired | Observed | Effective | Status |
|---|---|---|---|---|
| `projects[code-factory].bunkers.count` | 2 | 2 allocated on h1/h2 | 2 Bunkers serving | CONVERGED — allocation requirements and host references resolve |
| `projects[code-factory].lanes[builder].foreman.round.worker_budget.total` | 8 | injected at admission | 8, remaining 3 after two waves | CONVERGED |
| `projects[code-factory].memory` | shared-git, namespace `code-factory` | local commit acknowledged; remote sync pending | `pending-sync`, controller freshness not yet proven | **DEGRADED / UNVERIFIED** — the example defines the readback but does not claim it ran |
| `deployment.profile` | homelab-vpn | profile applied | readiness record pending the profile-specific authenticated probes | **DEGRADED / UNVERIFIED** — no effective-readback evidence is available in this example; a RED procedure cannot establish convergence |
| `safety.terminal_jail` | disabled | not enabled | no guarded path in use | CONVERGED — NOTE: enabling it is an operator act, and enabled mode has no unguarded fallback |
| `projects[code-factory].repository` | `provider: github`, `url: git@github.com:example/code-factory.git` | repository identity read back independently | repository identity is not credential material | CONVERGED only for identity; credential activation remains a separate readback |
| `projects[code-factory].repository.credential_ref` | `secretref://forge/github/deploy-key.cf2a` | reference only everywhere | installed key file, mode 0600, fingerprint `SHA256:…` | **UNVERIFIED** until the credential file and permitted operation are read back; value is never printed |

## V.8 Operator setting index

| The operator needs to… | Setting / card | Where |
|---|---|---|
| size a foreman round's workforce | `foreman.round.worker_budget.total` (V.3 card 1); never a wave count | V.3, V.5 |
| make bus custody survive a restart | `transport.registry.backend` (V.3 card 2) | V.3, VI §2 |
| keep credentials out of logs and plans | reference syntax and redaction rules | V.4 |
| declare where projects may run and what they need | project host pool + requirements | V.0 allocation, V.7 example |
| know why a Bunker count is short | allocation-shortfall exposure | V.0, V.7 |
| read back what is actually serving | per-setting readback field; RED where missing | V.3 field 12 |
| tune timing without creating an impossible combination | compatibility validation | V.5 |
| know which measured variables are not settings | classification | V.2, inventory notes |
| audit a configuration change | lifecycle stages, audit events | V.6 |

## V.9 Recursive target types and activation (P5-C-03/04/06/30)

This section completes V.0.1; it is normative target design, not a generated validator
or a claim of deployment. Serialization is JSON UTF-8 as selected in Part I §1.9.1;
V.7 YAML is a lossless authoring illustration. Duplicate JSON/YAML keys, NaN/Infinity,
unknown keys, wrong types and null (unless explicitly allowed) are refused. Boolean
is not integer. All integers are in 0..9007199254740991 before narrower bounds.
`ID` is ASCII `[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}`; desired-state map keys use the same
rule. A path is an absolute normalized POSIX path with no parent traversal; a URL is
absolute HTTPS without userinfo (repository identity also accepts scp-style SSH).
Lists are ordered unless called sets; sets refuse duplicates. Lists/maps have at most
1024 entries, except tasks/criteria governed by VII.18. Empty collections are valid
only where explicitly stated. All members below are required unless a default or
optional marker appears. Defaults materialize before digesting; explicit empty/null
never means default. Root contains exactly V.0.1's keys plus transport, scheduler,
execution, inference, credentials and readiness; the new objects may be omitted and
expand to defaults below. Enabled features with unresolved references refuse activation.

| Object | Complete members, types, bounds and defaults |
|---|---|
| deployment | profile: profile ID; endpoints: nonempty map of Endpoint |
| Endpoint | url: URL; protocol: https or ssh (must match URL, ssh permitted only for repository transport); credential_ref: optional SecretRef |
| profiles entry | isolation: persistent-container or image-container; terminal_jail: disabled or required; persistence: optional `{workspace: path, memory: path, evidence: path}` (all three distinct), absent uses manager-assigned per-Bunker durable roots; required jail additionally needs global jail policy |
| host | id: ID; endpoint_ref: Endpoint key; capacity: Capacity; capabilities: nonempty set of capability IDs |
| Capacity | disk_gib: integer 1..1048576; memory_gib: integer 1..1048576; concurrent_workers: integer 1..1024; cpu_millis: integer 100..1024000 default 2000; pids: integer 16..1048576 default 256. GiB is 1073741824 bytes, no decimal rounding |
| project | id: ID; repository: Repository; eligible_hosts: nonempty host-ID set; bunkers: Bunkers; memory: Memory; lanes: nonempty Lane list |
| Repository | provider: github or gitlab; url: repository URL; credential_ref: forge SecretRef |
| Bunkers | count: integer 1..1024; requirements: Requirements; profile: profile ID |
| Requirements | disk_gib, memory_gib: Capacity ranges; capabilities: nonempty capability-ID set; network: endpoint-ID set default all deployment endpoints; cpu_millis,pids: Capacity ranges/defaults |
| Memory | namespace: project ID; local_root: path; sync_policy: shared-git or local-only; remote_ref: required HTTPS Git URL for shared-git, forbidden for local-only; sync_owner: ID default factory-memory-sync; sync_interval_s: integer 1..300 default 30; stale_after_s: integer 30..3600 default 90 |
| Lane | name: ID; admission: tasks or cooldown; cadence_s: integer 1..31536000; weight: integer 1..1000; priority: integer 0..9 default 5; foreman: `{round: Round}`; enabled: boolean default true; hooks: M9.18 Hook list, default empty (required-hook readiness still refuses) |
| Round | worker_budget: `{total: integer 1..100000}`; concurrency: integer 1..1024; retry_policy: WorkerRetry; deadline_s: integer 120..7200 default 7200; attempt_wall_s: integer 1..1800 default 1800; max_turns: integer 1..1000 default 40 |
| WorkerRetry | name: literal charge-on-start; failed_start: literal refund-before-run; max_attempts: integer 1..10 default 3; initial_backoff_s: integer 1..60 default 5; max_backoff_s: integer 1..300 default 60 |
| events | webhooks: Subscription list, default empty |
| Subscription | subscription_id: unique ID; endpoint_ref: events SecretRef; event_types: nonempty set of V.0.3 catalog enums including project.progress; project_scope: nonempty project-ID set; status: enabled or disabled; retry_policy: DeliveryRetry; retention_s: integer 3600..2592000 default 604800 |
| DeliveryRetry | max_attempts: integer 1..20 default 5; initial_backoff_s: integer 1..60 default 5; max_backoff_s: integer 1..3600 default 300 |
| safety | terminal_jail: disabled or required; jail_policy: optional M8.16 policy object, mandatory for required mode; reclaim: Reclaim; backup: Backup |
| Reclaim | enabled: boolean; job_ttl_hours: finite number 0..8760 default 24; cache_ttl_hours: same default 24; free_floor_gib: integer 1..1024 default 4; classes: set of cache/job, default `[cache,job]`; no package/image/evidence deletion by this policy |
| Backup | enabled: boolean; interval_s: integer 300..86400 default 3600; retention_s: integer 86400..31536000 default 2592000; rpo_s: integer 300..86400 default 3600; rto_s: integer 300..86400 default 7200; destination_ref: endpoint ID required if enabled; key_ref: backup SecretRef required if enabled; offline_policy: refuse or partial default refuse |
| transport | registry: `{backend: sqlite or postgres, endpoint_ref: optional Endpoint key}`; default backend sqlite, endpoint required for postgres; lease_s: integer 30..300 default 60; renew_s: integer 1..60 default 20; call_timeout_s: integer 1..10 default 5 |
| scheduler | budget: integer 1..1000000 default 100; max_concurrent: integer 1..1024 default 10; tick_wall_s: integer 120..86400 default 7200; namespaces: map of project-ID to `{reserved: integer 0..1024 default 0, hard_cap: integer 1..1024 default max_concurrent}`, absent means every project gets defaults |
| execution | mode: resident or central-compat default resident; artifact_ref: optional ID resolving to M11.17 release record, mandatory at activation; launch_reserve_s: integer 1..120 default 30; transfer_reserve_s: integer 1..120 default 30; cleanup_reserve_s: integer 15..120 default 15 |
| credentials | renewal_margin_s: integer 60..3600 default 300; overlap_s: integer 0..300 default 60; proxy_ttl_s: integer 600..86400 default 3600 |
| readiness | probe_interval_s: integer 5..60 default 10; stale_after_s: integer 15..300 default 30; failures_to_fail: integer 1..10 default 3 |
| inference | routes: Route list default empty (no inference admission); node_scope: NodeScope; capture: Capture; upstream_timeout_s: integer 1..300 default 300 |
| Route | id: ID; requested_model: nonempty string <=128; provider: ID; served_model: nonempty string <=128; endpoint_ref: Endpoint key; credential_ref: model SecretRef; input_micro_usd_per_million, output_micro_usd_per_million: integer >=0; tokenizer_digest: SHA-256 |
| NodeScope | allowed_routes: route-ID set default empty; budget_micro_usd: integer >=0 default 0; window_s: integer 60..86400 default 86400; concurrency: integer 1..64 default 1; max_output_tokens: integer 1..131072 default 4096 |
| Capture | enabled: boolean default false; max_chars: integer 1..120000 default 120000; retention_s: integer 60..2592000 default 2592000; sink_ref: Endpoint key required when enabled; failure: refuse or record default refuse; redaction: literal credentials-and-secrets default credentials-and-secrets |

Before Part I §1.9.5 allocator invocation, declared disk_gib/memory_gib multiply
exactly by 1073741824 into disk_bytes/memory_bytes, and requirements.network maps to
network_refs. The allocator's closed byte-vector is an adapter request type, not
another accepted desired-state shape; configured concurrent_workers remains a
separate slot constraint. Conversion overflow refuses RANGE_INVALID.

Capabilities are declarations matched byte-for-byte against authenticated adapter
capability inventories; unknown/unavailable capability refuses activation rather than
being assumed. `SecretRef` has domain from V.4 and name of 1..256 ASCII path characters,
no empty/dot/parent segments; it is not a value. extensions is an optional map keyed
by reverse-DNS namespace, each value a JSON object <=64 KiB, retained uninterpreted;
core behavior never depends on it. Empty hosts/projects/profiles/endpoints refuse.
Duplicate IDs anywhere within their owning collection refuse DUPLICATE_ID. Missing
required keys return REQUIRED_FIELD; type/range/ref errors return TYPE_INVALID,
RANGE_INVALID, REFERENCE_UNKNOWN with JSON pointer; no adapter runs on validation error.

The owner edits intent. Activation is the next reconcile for transport/profile/
credentials/readiness, next round for scheduler/round/retry/hooks, and next request
for inference after a generation CAS. In-flight requests/rounds pin generation;
revocation overrides pins. Readback is `GET /v1/config` and project state from Part I,
with per-adapter generation, canonical applied-values digest and observed_at. Native
mapping is CR_REGISTRY_BACKEND for transport, scheduler budget/max-concurrent/
tick-timeout for scheduler, CF_TIMEOUT_S/CF_MAX_TURNS for attempt limits, and the
reclaimer's two TTL flags for Reclaim. All other new controls are target adapter
fields, not fictitious native flags: an adapter without mapping/readback returns
SETTING_UNSUPPORTED and readiness false. Model routing, token scope, capture,
renewal margin, execution mode and backup bounds are therefore declared controls
with explicit unsupported behavior, not hidden extension keys.

Cross-field validation runs both at config acceptance and admission: concurrency <=
host concurrent_workers and round allowance (allowance may exceed host concurrency);
initial backoff <= maximum; sum namespace reserved <= global slots; each weight <=
budget; readiness stale_after >= 3*probe_interval; lease_s > renew_s + call_timeout_s
+ 5 s clock margin + cleanup_reserve_s; renewal_margin < proxy_ttl; overlap < margin.
Round deadline <= tick wall; each attempt gets min(attempt_wall_s, remaining round
seconds minus launch/transfer/cleanup reserves). A nonpositive remainder refuses
DEADLINE_INSUFFICIENT. Deadline is pinned at admission using UTC plus a monotonic
remaining-time budget; clock rollback cannot extend it. Default reserves total 75 s,
so the 7200 s round admits a 1800 s harness with up to 40 turns, not 40 separate
1800 s entitlements. Backoffs, hooks and subsequent waves consume the same deadline.
[Part I §1.9; M9.16–18; M11.16]

## V.10 Metric and readiness sample protocol (P5-C-32)

The target collector polls authenticated subsystem readbacks every 10 s and serves
`GET /v1/metrics` in the Part I response wrapper. Every module contributes
`factory_operations_total`, `factory_operation_duration_seconds`,
`factory_active`, `factory_pending`, `factory_oldest_pending_seconds` and
`factory_available`. Labels are exactly module (M0..M12 or manager), operation
(configure/admit/launch/deliver/renew/verify/publish/sync/reclaim/backup/restore/
issue/revoke/infer), outcome (accepted/pass/fail/refused/unknown/cancelled), and
project (configured ID or factory-control). A metric not applicable to a module is
omitted with a reason in collection_state; unknown source is value:null,
collection_state:unavailable, never 0. Duration histogram boundaries are
0.01,0.1,0.5,1,5,10,30,60,300,1800,7200 seconds plus infinity, with count/sum.
Counters/histograms persist from committed event sequences; collector restart
replays its durable cursor without double increment. Gauges reflect the latest
snapshot, carrying observed_at and source_seq. No raw token, task ID or error text
becomes a label. Module-specific units are budget in micro-USD, disk in bytes,
inodes/counts as integers, expiry/freshness in seconds; readiness is boolean.

Rates use delta of persistent counts over the trailing 300 s; fewer than two samples
or a zero denominator yields null/insufficient_data, not zero percent. Each ratio
names numerator and denominator in the sample. Healthy idle is fresh available=1,
active=0, pending=0; stale is age > stale_after_s, degraded is a fresh failed optional
probe or pending required projection, failed is three consecutive failed required
probes. Missing observations are unknown and readiness false immediately; an old
passing probe does not sustain readiness. Required operation-specific measures named
in module sections are views of these counters/events plus the named unit gauges,
not undocumented new label schemas. Receiver alert policy remains external. [V.0.3;
Part I Probe; VII.10]

---

## The measured inventory (M0–M12)

Everything above is the governing contract; what follows is the measured settings
inventory of the thirteen module chapters, retained with its first-batch discipline.

Every setting the thirteen module chapters register, in one place. `Where it lives` names
the file and the mechanism (env var, flag, config key or hardcoded constant). `Default`
carries the chapter's citation; a setting with no known default reads `unknown` with the
reason — never blank. `Changes` is the consequence of moving it, from the chapter's own
measured words. The cross-ref names the chapter section that owns the row; the locators
there are the authority, and a chapter that re-pins a locator amends this register in the
same commit. Locators are quoted from the chapters' measured revisions; where later
commits have shifted a line, the chapter's citation stands until the chapter re-pins it.

Where a module's settings live in several files, the module carries one table per file,
matching the chapter's own subdivision. Constants that a chapter explicitly excludes from
its settings surface (`FAILED` in M0, `LISTEN` in M12, the spine gate's four hardcoded
sets in M6) are named in a note, not given rows — the chapters refuse them the status of
settings and this register records that refusal rather than overruling it.

## The four review columns and the three states

The review requires the register to carry, for every expected setting, the exact
configuration method, scope and owner, type/units/range/default, requiredness,
validation and errors, precedence and interactions, activation, and a redacted effective
readback. The per-module tables above carry the first three natively (`Lives in` is the
configuration method and owner section; `Default` and `Range` are the type and bounds).
The remaining four dimensions are carried in one place — the deployment-profile matrix
below — because they are properties of a deployment, not of a single file:

- **Requiredness** — whether a deployment may omit the setting, and what a missing value
  costs: refusal, fallback, or a silent default that is itself the hazard (the memory
  registry backend, VI §2).
- **Validation / errors** — what rejects a wrong value, and the named error it emits.
- **Precedence / activation** — the order of overrides, and the moment a change takes
  effect: the next exec, the next spawn, the next tick, or a restart.
- **Redacted effective readback** — the command or boot line that proves which value is
  actually serving, with credential material never printed. A setting whose readback is
  not yet written is a named RED, not a silent gap.

Every deployment-profile row carries one of three states:

- **SUPPORTED** — implemented and measured in the pinned source; the row cites the
  measured surface or the per-module table that does.
- **TARGET-UNIMPLEMENTED** — approved target behavior the current implementation does not
  yet provide; the row states the requirement and makes no implementation claim.
- **UNRESOLVED** — a user decision or the review leaves the value open; the row names the
  open question and does not guess.

The per-module rows above are SUPPORTED unless the row itself names a RED, UNVERIFIED or
refusal condition; those markings are the same three states applied to a single setting.

## Deployment profiles — the per-Bunker dimension

No universal Bunker execution mode is selected (user decision, handoff §1.8). The Factory
target is per-Bunker configuration with setup and readback: each Bunker carries a named
deployment profile, and every dimension below is set and proven per Bunker. The matrix is
the authoritative cross-module statement of that surface; the module chapters own the
rows' details.

**Supported memory profile — same-namespace local/remote.** Each project has one logical
namespace and stable `record_id` values. The controller and every project Bunker hold
Git-backed local namespace repositories with the same namespace identifier; the Bunker
writer commits locally before acknowledging a record. A remote synchronization target is
an optional transport for exchanging commits, not the durability authority for a local
write. The supported local profile therefore remains usable when the HTTP/service path is
unavailable. A local loss is distinct from service outage and is reported as
`LOCAL_STORE_LOST`; it is not represented as a successful pending sync.

A record write proposes `record_id`, `namespace`, `record_type`, `round_id`, `wave_id`,
`attempt_id`, `payload_digest`, `body`, `writer_identity` and `created_at`. The local
writer returns the resulting `local_commit`, `sync_state` and `freshness`; those output
fields are never trusted as write input. Repeating the same identity and digest is an
idempotent acknowledgement; the same identity with a different digest is
`MEMORY_CONFLICT` and does not overwrite the first record. A reconnect exchanges commits,
verifies namespace and writer authorization, and records `sync_commit`, `synced_at` and
freshness. The supported operations are `POST record` (local commit), `PUSH pending`
(exchange missing commits), `MERGE namespace` (fast-forward or explicit conflict
resolution), `REPLAY record_id` (same digest only), and `GET record_id` (readback with
freshness). A conflict retains both digests and requires an authorized `RESOLVE` with a
new record id; replay never overwrites the first record. Controller readback is `fresh`,
`pending-sync` or `stale`; it never upgrades a local record to controller-fresh without
the synchronization evidence. Worker, wave and round records remain distinct and
correlated. Permissions bind the writer to one project namespace; a cross-project write
is `NAMESPACE_FORBIDDEN`. `local-only` is valid only for one Bunker plus controller
sharing the same Git-backed namespace repository or an explicitly mounted shared view;
a multi-Bunker configuration without that shared view is refused as `MEMORY_TOPOLOGY_UNSUPPORTED`.
The profile is a target contract until its cross-host and outage cases are exercised.

| Dimension | State | Requiredness | Validation / errors | Precedence / activation | Redacted effective readback |
|---|---|---|---|---|---|
| Profile selection and identity (M1, M5) | TARGET-UNIMPLEMENTED | required — no Bunker reaches readiness without a named profile | readiness must validate effective host/isolation/resource/network/storage settings and real cross-host memory, inference and repo use; install success alone is insufficient | per-Bunker Factory settings override published defaults; platform examples establish no native support | the profile named in the readiness record — procedure not yet written (RED) |
| Host: user and isolation basis (M1, M5, M8) | SUPPORTED paths, choice UNRESOLVED | exactly one execution path per Bunker | provisioning prerequisites differ by path (host-user, fresh image-backed, persistent container, detached unit) and each must be verified, not assumed | set at spawn; a fresh exec inherits nothing | agent identity in `.node/node.json`; a per-path conformance readback is pending |
| Image (M5) | SUPPORTED; pin TARGET | the image carries the exact Hermes/Oh My Hermes build | `HERMES_PIN` and digest checks refuse a wrong build at install (M5 §5) | pin change is a deliberate re-provision, not drift | `install-hermes.sh --check` against the pin |
| Persistence (M5) | SUPPORTED (opt-in), assignment TARGET | which Factory state survives the next exec must be stated per profile | a fresh rootfs install does not survive the next exec — no validation can assume it does | persistent containers are opt-in; the default is ephemeral | the profile's persistence row in the readiness record (pending) |
| Mounts (M1, M5) | SUPPORTED measured; contract TARGET | dependency/package/cache/session/evidence persistence mounts declared per profile | a relative `--gomodcache` is refused; a declared-but-unsealed cache is a counted FAIL | mount changes take effect at the next spawn | `node_hygiene.py footprint --modcache` names the cache or prints `not-declared` |
| Shared DuckBrain identity and topology (M1, M4, M5) | TARGET-UNIMPLEMENTED — supported local profile specified below | every Bunker and controller use one Git-backed project namespace; service replication is optional, not required for local durability | `record_id` and namespace are validated; duplicate identity is refused; local commit is required before acknowledgement; remote outage yields `pending-sync` | local write applies immediately; remote sync retries with backoff; conflicts use record-id plus payload digest and retain both sides for explicit resolution | local namespace commit, pending-sync manifest, then controller readback of the same `record_id` |
| Crier (M10) | SUPPORTED; selected profile TARGET | a durable registry backend on every deployment holding real work | `CR_GUARD_*` bounds refuse non-numeric and `<= 0` at startup with a named error | explicit `CR_REGISTRY_BACKEND` → `sqlite:` URL → postgres URL → `memory` (the last is the hazard); changes activate on restart | which backend is actually serving custody has no readback — a named RED on M10 §5 |
| Board sync and hooks (M4, M9) | TARGET-UNIMPLEMENTED | scheduler-facing reads, claim/sync paths, local and remote board copies and the required lane hooks with a board-check verifier | an unreadable board is distinct from an empty one; the distinction is required behavior, current input handling is partial | PRE hooks follow selection, POST follows outcome recording and cannot change that tick's result | `repo_freshness` and `board_read.py load` report the source used |
| Forge credentials (M7) | SUPPORTED mint/check; delivery TARGET | per-Bunker scoped delivery, activation and readback for forge credentials | wrong key mode refused by name before any mint or store rewrite | control-side signing authority; only scoped credentials reach nodes | fingerprint listing (`show` prints sha256 prefixes, never material) |
| Model credentials (M12, M5) | SUPPORTED; proxy source UNVERIFIED | node-proxy tokens distinct from forge credentials; keys as file paths, never values | `CF_API_KEY` value refused; key-file mode `[0-7]00` accepted while the message claims 600 (F0-6); no token file or no upstream key → exit 2 before binding | env read at request time; startup is fail-closed | token file mode and presence checks; no credential value ever printed |
| Gates and landing (M3) | SUPPORTED | every landing that needs a project gate passes `--gate-cmd` | a wrong gitreins version is refused (`bad "gitreins" "version … != pin"`); a hook bypass is legal only when disclosed in the commit message | gate runs in a detached worktree at the node's commit | the `LANDED:` / `LAND: REFUSED` proof rows |
| Resources, safety and cleanup (M8, M9, M1) | SUPPORTED, profile-qualified | per-role disk floors, spawn memory caps and reap boundaries set before admission | out-of-range floors and roles refused by name (`MIN_GIB`/`MAX_GIB`, unknown role) | `--disk-floor` → `NODE_DISK_FLOOR` → `[disk]` config → `ROLE_DEFAULTS`; Terminal Jail stays disabled until an operator configures it, and enabled mode has no unguarded fallback | `disk_floor` admission rows; `footprint` measured components |
| Metrics (all modules) | TARGET-UNIMPLEMENTED | every required metric has a definition, units, collection and readout owner | — | — | dashboards/readouts per module — definitions first (Part VII.10) |
| Documentation release (M6, Part VIII) | SUPPORTED builder; policy in Part VIII | staged, revisioned output; release only with required checks satisfied | lint, fit, page-parity and checker gates exit non-zero and stop the build | gates run in order; the first failure stops delivery | the build's OK line — the only delivery receipt |

> WARNING: at the pinned Bunker source, egress defaults open, network defaults shared,
> and disk size is per-file, not an aggregate quota. Any Part VI claim of Bunker
> containment is qualified by the profile actually deployed (VI §23).

## M0 — shared contract

`lib.sh` carries one tunable constant and no env-var surface (M0 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `fetch_verified` `--max-time` | `scripts/lib.sh:22`, hardcoded | 120 s | fixed | download stall ceiling — a download stalling past 120 s fails with rc 1; lowering it rejects slow-but-valid mirrors | M0 §5 |

`FAILED` (`lib.sh:11`) is a per-script failure counter, not a setting. The `CF_*` variable
contract lives under M5 below.

## M1 — provisioning

**`disk_floor.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `ROLE_DEFAULTS` | `disk_floor.py:40` | `{"worker": 5, "builder": 10, "full": 20}` GiB | 1..4096 GiB (`MIN_GIB`/`MAX_GIB`) | admission floor per role — a value outside the range is refused (`:85-91`); role-table parity is gated by `tests/selftest.sh` section 65 | M1 §5 |
| `DEFAULT_ROLE` | `disk_floor.py:41` | `worker` | one of the role keys | which floor applies when no role is named — an unknown explicit role is refused, not defaulted (F1-2, raise at `:123-125`) | M1 §5 |

Floor precedence, verified (F1-3): `--disk-floor` → `NODE_DISK_FLOOR` → the `[disk]`
config key (`{role}_gib`, then `default`) → `ROLE_DEFAULTS[role]` (`disk_floor.py:115-141`).

**`bunker-provision.sh`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| config keys | `bunker-provision.sh:38-46` (declared), `:108-123` (loaded) | see the declared surface | KEY=VALUE lines only | provisioning inputs — an unknown key is refused (`:119`); a non-`KEY=VALUE` line is refused (`:103`) | M1 §5 |
| `TTL` | spawn fallback `${TTL:-6h}` (`:356`) | 6h | a Go duration | container spawn TTL — an absent or empty TTL falls back to 6h, not an error | M1 §5 |
| mode | `:561-609` | — | `check` / `apply` / `destroy` | what the run does — `--destroy` requires `--yes` and a non-empty `--agent`, else exit 2 (`:552-554`) | M1 §5 |

**`node_seed.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--manifest` (build) | `node_seed.py:43`, `:374` | `config/node-seed.txt` | a path | which files enter the seed — a wrong manifest seeds a different procedure | M1 §5 |
| `--budget` (build) | `DEFAULT_BUDGET` `:44`, `:377` | 16 MiB | bytes | aggregate uncompressed source-file byte ceiling — the total is compared before the archive is created (`:130-150`); compression and tar overhead are not bounded (B05); a budget under the raw source total is refused (`seed_budget` FAIL, return 1) | M1 §5 |
| `--force` (apply) | `:387-390` | false | flag | wholesale replace of `prompts/`+`skills/` — true deletes node-local edits via `rmtree` (`:290`) after reporting each path (`:280-288`); destructive, names what it removes | M1 §5 |
| `--home` (apply/check) | `:383`, `:393` | `~` | a path | the node `.hermes` root — a wrong home installs or checks the wrong tree | M1 §5 |

**`bunker_config_gen.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--harness` | `:107`, `:515` | `hermes` | a harness name | the node's default harness — a wrong default changes every generated node config | M1 §5 |
| `--ref` | `:106`, `:516` | `main` | a git ref | the seeded branch — a wrong ref seeds the wrong tree | M1 §5 |
| `--ttl` | `:108`, `:517` | `6h` | a Go duration | config TTL — a wrong TTL expires containers early | M1 §5 |
| `--force` / `--check` | `:523-524` | off / off | flags | rewrite a differing config / read-only drift check — `--check` is read-only | M1 §5 |

Config-vs-CLI precedence: `load_config` (`:96-123`) parses the file as data, then the CLI
flags are re-applied on top — the command line always wins (`:589`); six flags are
re-applied after the config (`:604-609`).

**`node_env.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--env-file` | `node_env.py` | none — required with `--config-set` | a path | which declared profile is read — absent with no `--config-set` → `Refusal` "nothing declared" (`:484-485`) | M1 §5 |
| `--config-set` | `:474-481` | none, repeatable | `KEY=VALUE` | additional overrides applied after the file — a malformed set is refused at parse (`:476`) | M1 §5 |
| mode | `:482-483` | none — required | `--check` or `--apply` | whether the run mutates — no mode → `Refusal` "one of --check or --apply is required" | M1 §5 |
| `HOME` | `:491-494` | required | env | where the paths resolve — unset → `Refusal` "HOME is unset" | M1 §5 |
| target paths | `:495-496` | `$HOME/.hermes/.env` + `$HOME/.hermes/config.yaml` | fixed | what is rewritten — a wrong HOME rewrites the wrong tree | M1 §5 |
| unmanaged variables | `:548-556` | carried forward | per-variable | variables present but not declared — each emits `WARN unmanaged:<name>`; preserved, not dropped | M1 §5 |

**`node_freshness.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--path` | `:677-682` | `repo` | a remote path relative to agent home | which checkout is measured — a wrong path measures a different tree | M1 §5 |
| `--timeout` | `:684-689` | 180 s | int >= 1 | per-command bunker exec timeout — `< 1` is refused (`RESULT: FAIL (usage…)`); the help notes the bunker exec stream dies at 300 | M1 §5 |

**`node-create.sh`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--deploy-key FILE` | `node-create.sh` | none | an SSH private key, owner-only mode | injects the per-repo credential at spawn — a readable key is refused before any agent is spawned; unset means the node clones with whatever identity it has | M1 §5 |
| `--gomodcache PATH` | `node-create.sh` | none | an absolute path on the node | points the node at a sealed shared module cache — a relative path is refused; unset leaves a private cache and layer 10 prints the WARN | M1 §5 |
| `--ref R` | `node-create.sh` | `main` (or `NODE_REF`) | a git ref | the branch or tag cloned | M1 §5 |

**`deploy_key.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| subcommand | `deploy_key.py` | none | `install` / `check` / `show` | mutating install / read-only proof / fingerprint listing — `check` never writes; `show` prints sha256 prefixes, never key material | M1 §5 |
| key file mode | `deploy_key.py` | — | `0600` or `0400` accepted | who can read the key — `0644` is `FAIL key_mode` and nothing is installed | M1 §5 |
| key body | `deploy_key.py` | — | a private OpenSSH/PEM header | accepted material — a public key (`ssh-*`, `ecdsa-*`) is `FAIL key_file` | M1 §5 |
| remote form | `deploy_key.py` | — | `git@host:path` or `ssh://[user@]host[:port]/path` | what a deploy key can authenticate — HTTPS/local forms are `FAIL repo` naming why | M1 §5 |
| `--replace` | `deploy_key.py` | off | flag | rotation of a key already registered for that repo — a different key without it is refused, so a rotation is never silent | M1 §5 |

**`node_hygiene.py`** (M1 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `footprint --working-room-mib` | `WORKING_ROOM_MIB` | 2048 | MiB | headroom added to the measured components before admission — a shortfall is `FAIL footprint:room` naming the bytes short | M1 §5 |
| `footprint --floor-gib` | `node_hygiene.py` | none (measured only) | GiB | whether the total is admitted against the resolved floor — without it the total is measured but not admitted | M1 §5 |
| `footprint --modcache` | `node_hygiene.py` | none → `not-declared` | path | whether the shared cache counts toward the footprint — an undeclared cache is named, never a silent zero | M1 §5 |
| `reap --min-age-minutes` | `node_hygiene.py` | 60 | minutes | grace before an orphan is removed — a younger entry is kept (an agent being created is not an orphan) | M1 §5 |
| `reap --registry` | `node_hygiene.py` | none — required | id list or `bunker list` output | which ids are live — absent or unreadable → `FAIL reap_registry`, nothing removed | M1 §5 |

## M2 — dispatch

`node-bus-worker.py` fixes the run-budget and inbox constants (`:81-114`) and the CLI
(`:1425-1499`) (M2 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `CF_MAX_TURNS` | `node-bus-worker.py:113` | 40 | 1..1000 | turn budget — out of range refused | M2 §5 |
| `CF_TIMEOUT_S` | `:114` | 1800 | 1..86400 | wall-clock per turn — out of range refused | M2 §5 |
| `DEFAULT_INBOX_LIMIT` | `:81` | 10 | positive int; the bus caps a batch at 100 (`handler.go:1718-1731` returns 400 `max must be <= 100`) | inbox batch size — larger batches raise per-poll latency; a value >100 is refused by the bus, not the worker | M2 §5 |
| `DEFAULT_LEASE_SECONDS` | `:82` | 30 | positive int | lease on each retrieve — too long holds messages during a crash | M2 §5 |
| `SEEN_LIMIT` | `:85` | 200 | positive int | idempotency window — a smaller window re-runs a redelivered dispatch | M2 §5 |
| `--reply-to` | `:1479-1480` | `scheduler` | an agent id | result recipient when the dispatch names none — a wrong default drops replies | M2 §5 |
| `--wait-seconds` | `:1486` | 0 | 0..120 (`:1511`) | inbox long-poll budget — outside 0..120 → exit 2 (the bus answers 400 outside it) | M2 §5 |
| `--interval` | `:1489` | 15 | positive int | seconds between `--loop` polls — 0 starves the loop | M2 §5 |
| `--harness-wall` / `--timeout` | `DEFAULT_HARNESS_WALL` `:84`, `DEFAULT_TIMEOUT` `:83`; CLI defaults at `:1491-1499` | 1800 / 10 | positive int | per-run wall / per-request timeout — see F2-3 for the wall fallback (a fractional positive below 1 converts to 0, an out-of-range value falls back rather than being bounded) | M2 §5, §11 |
| `--dry-run` lease | `:1312` (`lease = 5 if args.dry_run else args.lease_seconds`) | 5 s | fixed | a dry run leases each retrieved message for 5 s — it skips execution, post and ack, not the lease (B08) | M2 §5 |
| `--home`, `--identity`, `--bus-identity`, `--key`, `--token-file`, `--agent`, `--project`, `--crier`, `--workdir`, `--harness-cmd`, `--gateway-port` | `:1443-1476` | unknown — registered NAME ONLY (M2 §5): default, validation and consequence are not individually stated; a named RED on this field | — | identity/credential/destination/executable selection — the surface exists, its per-variable contract does not | M2 §5 |

## M3 — repository

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `GITREINS_PIN` | `install-gitreins.sh:19` | `0.17.1` | exact version | gate binary pin — a non-matching installed version → `bad "gitreins" "version … != pin"` (`:53`) | M3 §5 |
| `GITREINS_VENV` | `:23` | `$HOME/gitreins-venv` | a `$HOME` path | where the pinned binary lives — the hook hardcodes this venv path (`:134`); moving it breaks the hook | M3 §5 |
| `REMOTE` / `MAIN` | `land-node-branch.sh:38` | `origin` / `main` | git ref names | push/fetch targets — a different remote is an explicit operator choice | M3 §5 |
| `GATE` (`--gate-cmd`) | `:38`, set only by `--gate-cmd` (`:108`) | empty | a shell command | the optional pre-merge gate — when empty no gate runs (`run_gate` guards `[ -n "$GATE" ] || return 0` at `:75`); the landing publishes with no project gate by default (F3-3) | M3 §5 |
| `repo_freshness --bound` | `repo_freshness.py:559` | 0 | int commits | behind-count before a workdir is FAIL — a higher bound tolerates a staler workdir | M3 §5 |
| `repo_freshness --gate` | `:565` | off | flag | exit 1 when any workdir FAILs — without it a stale row does not fail the process | M3 §5 |
| `repo_freshness --strict` | `:570` | off | flag | escalate WARN (unmeasurable) → FAIL — without it an unknown measurement does not fail | M3 §5 |
| `repo_freshness --no-fetch` | `:575` | off | flag | measure local refs only, no network — on it avoids mutation/fetch | M3 §5 |
| `repo_freshness --max-fetch-age` | `:581` | None | seconds | FAIL when the last fetch is older — off by default | M3 §5 |
| `repo_freshness --jobs` | `:588` | 8 | int | parallel workdir probes — lower serialises | M3 §5 |
| `repo_freshness --timeout` | `:591` | 60 s | int | per-git-command timeout — too low fails slow remotes | M3 §5 |
| `.gitleaks.toml` `[allowlist].paths` | `.gitleaks.toml:57-58` | bytecode entries `__pycache__/` + `\.pyc$` | unanchored regex list matched against the file path | which files tier-1 grades — tier-1 grades the working tree while the commit guard grades staged files only; deleting the entries reds selftest §34 `bytecode-allowlist-loadbearing`; widening one mutes real sources and reds `bytecode-allowlist` / `bytecode-allowlist-control` | M3 §5 |

## M4 — board

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `-C <repo-or-board-dir>` | `boardctl` wrapper | none — the wrapper forces `-C "$ROOT"` | a board dir | which board the verb targets — the wrapper pins it to the repo root so a bare `boardctl` cannot hit the wrong board | M4 §5 |
| `update --status complete` | `boardctl update` | — | requires `--evidence-run-id` | row closeout — a completion without a bound run id is refused (TR-251) | M4 §5 |
| `create` / `update` (id, fingerprint) | `boardctl` | — | unique id; unique finding fingerprint | row identity — a duplicate id is refused (`task id "…" already exists — create aborted`); a duplicate finding fingerprint is refused | M4 §5 |
| `validate [--strict-keys] [--fail-on dangling-dep]` | `boardctl validate` | — | flags | semantic validation strictness — `--strict-keys` tightens key uniformity; `--fail-on dangling-dep` promotes a dangling dependency from warning to failure | M4 §5 |

## M5 — harness

**`harness-vars.sh` (S5)** — the `CF_*` surface; `CFV_DECLARED` (`:28-29`, 12 vars) and
`CFV_REQUIRED` (`:31`, 6 vars) define it (M5 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `CF_MAX_TURNS` | `harness-vars.sh:276` | 40 | integer 1..1000 (`:281`) | turn budget — 0 or >1000 refused; loosening lets a run spin unbounded | M5 §5 |
| `CF_TIMEOUT_S` | `:277` | 1800 | integer 1..86400 (`:287`) | wall-clock per turn — refusal outside range; `install-codex.sh` re-defaults to 300 (see the adapter table) | M5 §5 |
| `CF_MODEL` | `:225` | unset — required in `--contract` | no spaces | model id — a model id with spaces refused | M5 §5 |
| `CF_PROVIDER` / `CF_NAMESPACE` / `CF_LANE` | `:226-231` | unset | lowercase `[a-z0-9._-]` | lane/namespace naming — an uppercase or symbol name refused | M5 §5 |
| `CF_RUN_ID` | `:236` | unset | `[A-Za-z0-9._:-]` | correlation id — a non-id value refused | M5 §5 |
| `CF_BASE_URL` | `:216`, `:219` | unset | http(s), no userinfo | harness endpoint — a URL carrying `user:pass@` is refused (credential-in-URL) | M5 §5 |
| `CF_API_KEY_FILE` | `:203` | unset | a path, mode `[0-7]00` | credential delivery — a VALUE refused; missing/empty file refused; mode 644 refused (`:204`); the predicate accepts modes `000..700` while the refusal message claims "a key file must be 600" (F0-6) | M5 §5 |
| `CF_API_KEY` + `CFV_AMBIENT_KEYS` (`:33`) | `:176-185` | unset | must be empty | ambient credential ban — a non-empty value refused; the check tests non-emptiness, so `CF_API_KEY=""` is accepted (F0-6) | M5 §5 |
| `CF_WORKDIR` | `:244-249` | unset | exists, resolves inside `$HOME` | harness write boundary — outside `$HOME` refused | M5 §5 |
| `CF_SKILLS_DIR` | `:258` | unset | a path | skills root — warns (not fails) if the dir does not exist yet (`:260`) | M5 §5 |
| `CF_HARNESS_OPTS` | `:268-271` | unset | `key=value[,key=value]`, no secret | harness-specific options — a secret-shaped value refused | M5 §5 |
| `--contract` mode | `:313-315` | — | requires all 6 `CFV_REQUIRED` | acceptance check — a missing required var refused (`dropped:$missing`) | M5 §5 |

**Per-adapter installation registers (B12)** (M5 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `NODE_GATEWAY_PORT` (hermes) | `install-hermes.sh:23` | 10800 | a TCP port | the gateway port the adapter installs against — a wrong port installs against the wrong gateway | M5 §5 |
| `HERMES_PIN` (hermes) | `:24` | `0.19.0` | exact version | the pinned hermes build — a drift installs an unmeasured build | M5 §5 |
| `HERMES_PYTHON_BIN` (hermes) | `:26` | `python3` | a python path | the interpreter the pin runs under — a wrong interpreter breaks the >=3.11,<3.14 gate | M5 §5 |
| `CF_CODEX_PIN` (codex) | `install-codex.sh:49` | `0.166.0` | exact version | the codex pin — drift installs an unmeasured build | M5 §5 |
| `SHA256` / `CF_CODEX_SHA256` (codex) | `:51` / override at `:428` | `a0bf572d…` | a digest | artifact integrity — a wrong digest is refused by `fetch_verified` | M5 §5 |
| `DISK_FLOOR_GB` (codex) | `:56` | 1.0 | GiB | admission floor — a lower floor admits a too-small host | M5 §5 |
| `DEFAULT_SANDBOX` (codex) | `:57` | `workspace-write` | a sandbox mode | codex write boundary — a wider sandbox loosens containment | M5 §5 |
| `TIMEOUT_S` (codex) | `:60` | `CF_TIMEOUT_S` or 300 | seconds | per-turn wall — the codex adapter re-defaults the shared 1800 to 300 | M5 §5 |
| `CLAUDE_CODE_PIN` (claude) | `install-claude-code.sh:39` | `2.1.318` | exact version | the claude pin — drift installs an unmeasured build | M5 §5 |
| `CLAUDE_CODE_SHASUM` (claude) | `:40` | `c11067a3…` | a digest | artifact integrity — a wrong digest is refused | M5 §5 |
| `NODE_MIN_MAJOR` (claude) | `:43` | 22 | Node major | the Node floor — a lower Node violates the pin's `engines` | M5 §5 |

**`install-go.sh` (S3)** — the Go toolchain installer register (B12) (M5 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `GO_PIN` | `install-go.sh:7` | `go1.26.5` | exact version | the Go toolchain installed — drift installs an unmeasured toolchain | M5 §5 |
| `GO_SHA256_LINUX_AMD64` / `_ARM64` | `:8-9` | `5c2c3b16…` / `fe4789e9…` | a digest | artifact integrity per architecture — a wrong digest is refused by `fetch_verified` | M5 §5 |
| `GO_DISK_FLOOR_GB` | `:10` | 1 | GiB | install admission floor — a lower floor admits a too-small host | M5 §5 |
| `GO_PROBE_MODULE` / `GO_PROBE_VERSION` | `:11-12` | `rsc.io/quote` / `v1.5.2` | a module@version | the cold-cache module proof — a changed probe no longer proves a working toolchain | M5 §5 |
| `MODE` | `:13`, first positional | `--check` | `--check` / `--apply` | what the run does — any other arg → usage, exit 2 (`:18-20`) | M5 §5 |
| `GO_INSTALL_ROOT` | `:14` | `$HOME/go-toolchain` | a path | where the pinned toolchain lives — a wrong root installs or checks the wrong toolchain | M5 §5 |
| module proof `timeout` | `:73` | 30 s | seconds | the `go mod download` proof ceiling — too short fails a slow-but-valid proxy | M5 §5 |
| module proof GOPROXY | `:53-57` | `$GOPROXY` or the toolchain's own `env GOPROXY` | a URL | which proxy resolves the probe — a misconfigured proxy fails the proof | M5 §5 |
| `GO_DL_BASE` | `:138` (`url="${GO_DL_BASE:-https://go.dev/dl}/$archive"`) | `https://go.dev/dl` | a URL | the toolchain download mirror — a wrong mirror fails `fetch_verified` on every install | M5 §5 |

**Resolver controls (B10)** — `harness_resolve.py:327-372` (M5 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--explain` | `:328-332` | none — required | a model id | which model to resolve — omitted → argparse exits 2 | M5 §5 |
| `--lane` | `:333` | None | a lane name | lane-scoped resolution — a wrong lane reads the wrong lane config | M5 §5 |
| `--lane-class` | `:335-339` | None, derived | `foreman` / `satellite` | overrides the lane-class derivation — a forced `foreman` on a satellite changes the refusal path (non-hermes foreman refused, `:284`) | M5 §5 |
| `--directive-harness` | `:341-345` | None | a harness name | pins the harness above everything (directive > lane > matrix) — forces a harness the matrix would refuse | M5 §5 |
| `--lane-harness` | `:346-350` | None | a harness name | pins the harness above the matrix — overrides the matrix for one lane | M5 §5 |
| `--node-harnesses` | `:351-356` | None | comma list | restricts the selection to installed harnesses — selection must be one of them, else refused | M5 §5 |
| `--shims` | `:357-361` | None | comma `family=name` / `harness:family=name` | shim bindings — a wrong binding routes a family to the wrong harness | M5 §5 |
| `--matrix-file` | `:362-366` | None | a path | the harness table (default `DEFAULT_MATRIX_FILE`) — a wrong file reads the wrong matrix | M5 §5 |

**Node runtime and shared module cache (S3, CF-003)** (M5 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `NODE_PIN` | `install-node.sh:26` | `v22.22.3` | one released Node version | the runtime every `node`-kind node gets — the layer grades whatever version the archive yields; a different pin needs its digests re-pinned | M5 §5 |
| `NODE_SHA256_LINUX_X64` / `_ARM64` | `install-node.sh` | `2e5d1356…` / `1c4a9933…` | 64 hex per arch | archive integrity — a mismatch is `FAIL node_dist`; nothing is extracted | M5 §5 |
| `--root` | `NODE_INSTALL_ROOT` | `$HOME/node-toolchain` | an absolute path | where the pin is installed — an explicit root makes `--check` a scoped question (a PATH runtime cannot answer it); a wrong root installs beside the runtime the layer grades | M5 §5 |
| `--tarball` + `--sha256` | `install-node.sh` | none | a local archive + its digest | the fixture seam; the digest is still verified — either alone is refused (`--tarball needs --sha256`) | M5 §5 |
| `gomodcache.py --dir` | `gomodcache.py` | none — required | a directory | which cache is seeded/sealed/checked — a wrong dir seals the wrong tree | M5 §5 |
| `gomodcache.py seal` | `gomodcache.py` | — | — | removes every write bit and records bytes/entries — an unsealed cache drifts per node back toward 656 MB | M5 §5 |
| `NODE_GOMODCACHE` | node env | none | an absolute node path | whether layer 10 admits a shared cache — unset → `WARN go:modcache` (private cache); declared-but-unsealed → counted FAIL | M5 §5 |

## M6 — documentation

**`master_doc_check.py` / `master_doc_fill.py`** (M6 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `CF_MASTER_DIR` | `master_doc_fill.py:26`, `master_doc_check.py:67` | unset | a directory | overrides root resolution — pointing it at a nonexistent dir yields a named failure | M6 §5 |
| `DEFAULT_ROOTS` | `master_doc_check.py:52` | `("docs/master", "docs/handbook/appendices/units")` | existing dirs | root discovery order — `docs/master` no longer exists, so the gate resolves to `appendices/units` | M6 §5 |
| fill `--engine` | `master_doc_fill.py:409-412` | `api` | `api` / `hermes` | which seat fills a module — `hermes` runs a real seat; `api` is one completions call | M6 §5 |
| fill `--workers` | `:396` | 2 | positive int | parallel fill workers — 0 or negative raises `ValueError: max_workers must be greater than 0` (no serial fallback); `1` is serial execution (`:450`) (B14) | M6 §5 |
| fill `--provider` | `:397` | `deepseek` | a `PROVIDERS` key | fill provider — an unknown provider is refused | M6 §5 |
| fill `--limit` | `:395` | 0 | int | cap on modules filled in one run — 0 = no cap; a positive N fills only the first N candidates | M6 §5 |
| fill `--force` | `:401` | false | flag | refill modules already FILLED/VERIFIED — without it, already-complete modules are skipped | M6 §5 |
| fill `--only` | `:404` | `""` | comma prefixes | narrow the candidate set (e.g. `05-,07-`) — a prefix matching none yields an empty run | M6 §5 |
| fill `--model` | `:411` | `""` | a model id | the seat model for `--engine hermes` — empty falls back to `openai/gpt-6.1-sol` (`:454`) | M6 §5 |
| fill `--dry-run` | `:413` | false | flag | list candidates without provider calls or writes — `--dry-run` suppresses all provider calls and writes (`:438-440`); `--force` decides which documents may be rewritten (B11) | M6 §5 |

**Spine gate (S9, B5).** `handbook_spine.py` carries no settings surface; its policy is
four hardcoded sets: `CANON` (the contract ids plus expected producer/consumer systems),
`BOUNDARY` (the 13 boundary contracts whose far side has no in-repo file), the
`SETTING_ROW`/`REF`/`COUNT_CLAIM` regexes, and the internal-vs-boundary split (M6 §5).
No rows — the absence of a surface is itself the register entry.

**`panel_loop.py` settings and stop semantics (B14)** (M6 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--rounds` | `panel_loop.py:323` | 6 | int; 0 = no cap (`:340` maps 0 → `10**9`) | absolute round ceiling — the loop condition (`:351`) compares the stored round against `--rounds`; it does not count iterations from `--start-round` (B12); a cap is a session budget, not a definition of done | M6 §5 |
| `--max-seconds` | `:324` | 21000 | int; 0 = no cap (`:341`) | the wall-clock budget — same stop semantics as `--rounds` | M6 §5 |
| `--start-round` | `:325` | None | int | inert for the loop body — `:342` sets only the printed value, then `:352` overwrites it from stored state before each writer runs (B12); the flag does not resume at a specific round as its help implies | M6 §5 |
| `--writer-timeout` | `:326` | 4200 | seconds | writer session deadline — too short kills the writer mid-round | M6 §5 |
| `--judge-timeout` | `:327` | 2700 | seconds | judge session deadline — too short yields MISSING seats | M6 §5 |
| `--chapters` | `:328` | `""` | comma list | narrow the chapter set — empty = all chapters | M6 §5 |
| `--groups` | `:329` | `""` | `M0,M1;M4,M5` semicolon-separated | explicit section groups (one writer per group) — overrides `--parallel`; a wrong grouping splits a contract seam across writers | M6 §5 |
| `--parallel` | `:331` | 1 | int | writers per round (0/1 = single writer) — >1 splits chapters by interleaved slice when `--groups` is absent (`:365-366`) | M6 §5 |
| `PANEL_WRITER_MODEL` / `PANEL_WRITER_PROVIDER` | `:37-38` | `deepseek-v4-pro` / `deepseek` | env override | writer seat model/provider — a wrong model runs the writer on an unmeasured seat | M6 §5 |
| `FANOUT` / `MANIFEST` | `:34-35` | hardcoded `cf-quorum-20261104` scratch paths | a path | the external fanout script + seat manifest — a dated scratch dir that no longer exists breaks the loop | M6 §5 |

Stop semantics: `panel_loop.py:442-457` exits 0 on unanimous PASS (`:445`), on
`clean_streak >= 2` (`:447-451` — two consecutive rounds with no new defect class, even
while blocking findings remain open), or on the cap (`:456`). A `STOP: no new defect
class` exit is a successful process termination, not proof the document is aligned.

## M7 — github

**`github-app-token.py` / `github-app-refresh.sh`** (M7 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| subcommand | `github-app-token.py` | none | `check` / `token` / `jwt` / `manifest` | which credential operation runs — a bare invocation performs no mint: usage, exit 2 | M7 §5 |
| `GITHUB_APP_ID` | `:295`, `:304-305` | unset | numeric | the App identity — unset or non-numeric → named problem; no mint | M7 §5 |
| `GITHUB_APP_INSTALLATION_ID` | `:307`, `:316-320` | unset | numeric | the installation scope — unset or non-numeric → named problem | M7 §5 |
| `GITHUB_APP_PRIVATE_KEY_FILE` | `:326-358` | unset | a path, mode exactly 0600 | the RSA signing key — absent, wrong mode, or parse failure all refused by name | M7 §5 |
| `--env-file` | `GITHUB_APP_ENV_FILE` or `DEFAULT_ENV_FILE` `~/.config/code-factory/github-app.env` (`:45`, argparse `:110`) | see lives-in | a path | the App's identity source — absent env file → mint fails | M7 §5 |
| `--api-base` | `GITHUB_API_BASE` or `DEFAULT_API` `https://api.github.com` (`:47`, argparse `:115`) | see lives-in | a URL | API endpoint (tests point it local) — a wrong base breaks the mint | M7 §5 |
| token destination | `args.out` or `GITHUB_APP_TOKEN_FILE` or `DEFAULT_TOKEN_FILE` (`:579`) | see lives-in | a path | where the token is written — a wrong path writes the credential to the wrong place | M7 §5 |
| `--if-older` | `:719-723` | 0 | seconds | no-op while the destination token is younger than N — 0 = always re-mint | M7 §5 |
| refresh controls | `github-app-refresh.sh:37-53` | per-flag | `--env-file --token-file --node --server --min-age --git-credentials --api-base --local --dry-run --quiet` | local vs node install, write/no-write — `--dry-run` prevents mutation (exits before mint/write at `:106` and `:154`); `--quiet` suppresses selected output only (`say_q` at `:55`) and does not prevent minting — the two flags are distinct controls (B16); `--node` installs into `$NODE:$HOME/.node/auth/github.token` (`:145-174`) | M7 §5 |

**Lifecycle controls, individually registered (B14)** (M7 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `MIN_AGE` | `github-app-refresh.sh:28` | 2400 s | non-negative int (spelling validated at `:53` → exit 2) | skip the mint while the destination token is younger than this — a too-large value serves a near-expiry token while reporting fresh | M7 §5 |
| `ENV_FILE` | `:24` | `$GITHUB_APP_ENV_FILE` or `~/.config/code-factory/github-app.env` | a path | the App identity source — absent file → `bad env_file`, exit 1 before any mint (`:57`) | M7 §5 |
| `TOKEN_FILE` | `:58`, after flag/env resolution | `~/.config/code-factory/github.token` | a path | local-mode token destination — a wrong path mints the credential to the wrong place | M7 §5 |
| `GIT_CREDENTIALS` | `:29` | `~/.git-credentials` | a path | the credential-store rewrite target — the store is rewritten only when it already exists (`:131`); the script never creates a second store | M7 §5 |
| `--local` / `--node` | `:30`, `:103` | local | mode | where the token lands — local writes `TOKEN_FILE`; node mints on this host, installs into `$NODE:$HOME/.node/auth/github.token`, then deletes the local copy (`:145-174`) | M7 §5 |
| `--min-age` | `:28` | 2400 | seconds | refresh no-op window — `--min-age` vs token lifetime (3600 s) determines when a refresh is a no-op | M7 §5 |
| mode-600 check | `:127-130` | — | exactly `600` | token-file privacy before the store is rewritten — `bad "mode"` exits 1 before the credential store rewrite (CF-320) | M7 §5 |
| `JWT_BACKDATE` / `JWT_LIFETIME` | `:50-51` | 60 s / 540 s | seconds | JWT exp/iat window — GitHub rejects exp >10 min out | M7 §5 |
| `TIMEOUT` | `:52` | 20 s | seconds | HTTP timeout — too short fails the mint | M7 §5 |

## M8 — safety

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `--job-ttl-hours` | `scripts/reclaim_disk.py`, CF-290 | 24 | finite, nonnegative hours | age of job/clone directories; cache age is independently controlled below | M8 §5 |
| `--cache-ttl-hours` | `scripts/reclaim_disk.py`, CF-290 | 24 | finite, nonnegative hours | fresh build caches survive; eligibility uses newest subtree mtime and inclusive TTL boundary | M8 §5 |
| `--root` | `:134` | required | a directory other than `/` (`:44-45`) | the reap boundary — `/` or a non-directory → `ValueError` (`:45`) | M8 §5 |
| `--dry-run` | `reclaim_disk.py` | false | boolean | whether anything is deleted — true → nothing unlinked (`:78-79`); byte totals are still printed as projected (`would free`), not actually reclaimed (`:119-123`, B15) | M8 §5 |

Exact targets (B15): `BUILD_CACHES` (`:14-19` — `.cache/pip`, `.cache/uv`,
`.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache`) are processed with `aged=True`
and cache TTL (default 24 h), using newest subtree mtime (CF-290);
`AGED_PARENTS` (`:21` — `.node/jobs`, `.node/clones`) also use `aged=True` with job TTL, where the TTL is a
`<=` boundary (inclusive); `PROTECTED` (`:22` — `repo`, `.node/node.json`,
`.node/crier.json`, `.node/floor.toml`) are refused via `safety_reason` (`:25-39`) before
inspection.

## M9 — scheduler

**Binary defaults (B18/F9-3).** The daemon's actual flag defaults are in
`cmd/schedulerd/main.go` (flag definitions span `:95-200+`); `config.example.toml` is the
example register and its commented values are not the runtime defaults. The full flag
surface is 57 definitions (`grep -cE 'flag\.(String|Int|Int64|Bool|Duration|Float64)'
cmd/schedulerd/main.go` = 57). The three-layer merge is struct defaults → the TOML file →
`SCHEDULER_*` environment overrides (`internal/config/loader.go` `applyEnvOverrides`);
`config.LoadRootConfig` is called ten times at boot (M9 §5). The residual RED: the reader
and precedence of each flag are documented for the group but not re-verified per flag.

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `db` | `cmd/schedulerd/main.go:95` | `$HOME/.hermes/coding-hermes/scheduler.db` | a path | SQLite store — a wrong path opens a different store | M9 §5 |
| `listen` | `:96` | `127.0.0.1:9090` | an addr | HTTP surface — off-loopback exposes the API (see the WARNING below) | M9 §5 |
| `min-interval` | `:108` | 30 s | Go duration | fastest tick interval — below it ticks are refused or never fire | M9 §5 |
| `max-interval` | `:109` | 24 h | Go duration | slowest tick interval — above it lanes starve | M9 §5 |
| `num-levels` | `:110` | 10 | >= 1 | priority levels — 0 breaks the priority sort | M9 §5 |
| `budget` (weight budget) | `:111` | 100 | >= 1 | weight budget per evaluation — 0 admits nothing | M9 §5 |
| `max-concurrent` | `:112` | 10 | >= 1 | concurrent foreman ticks — a load gate is a separate knob | M9 §5 |
| `namespace-mode` | `:113` | false | bool | multi-namespace scheduling — off disables reserved/hard_cap | M9 §5 |
| `tick-timeout` | `:114` | 7200 s (2 h) | Go duration | wall-clock before a tick is killed — too short kills legitimate ticks | M9 §5 |
| `api-read-timeout` | `:122` | 5 s | Go duration | per-request deadline for heavy read surfaces — a stalled DB helper returns 504 naming it (SCHED-GAP-1575-B) | M9 §5 |
| `gateway-response-timeout` | `:128` | 30 m | Go duration | per-turn POST deadline (min of this and tick-timeout) — 0 disables | M9 §5 |
| `gateway-transient-retries` | `:138` | 3 | int | 5xx/refused retry count (SCHED-GAP-1681) — 0 = single attempt | M9 §5 |
| `slot-patience` | `:142` | 5 m | Go duration | how long a spawn waits for a free slot — the drop emits a `slot_pool` event (ADV-R08/G3) | M9 §5 |
| `tasks-pacing` | `:143` | 60 s | Go duration | min post-tick spacing for tasks-mode projects — 0 = disabled | M9 §5 |
| `load-gate-threshold` | `:144` | 0 (disabled) | float (1-min load avg) | defer new spawns while load >= threshold — 0 disables; namespaces opt out via `load_gate='off'` | M9 §5 |
| `feature-prune-weeks` | `:145` | 8 | int | dead-feature reaper prune window — flag only, nothing is auto-deleted | M9 §5 |
| `peer-freshness-window` | `:148` | `database.PeerFreshnessWindowDefault` | int seconds | REMOTE-003 peer heartbeat freshness — a too-short window spuriously ages peers | M9 §5 |
| `spawn-mem-limit-mb` | `:149` | 0 | MiB | per-spawn `RLIMIT_AS` cap (ADV-R11) — 0 = no cap; a low cap kills spawns | M9 §5 |
| `board-stasis-gate` | `:150` | true | bool | exclude a cooldown BUILDER lane whose board is unchanged (SCHED-GAP-1678) — off admits stasis lanes | M9 §5 |
| `hooks-file` | `:151` | `$HOME/.hermes/hooks.toml` | a path | S13 ordered pre/post hooks — a missing file → a named absence, not a crash | M9 §5 |
| `session-silence-grace` | `:159` | 0 | Go duration | terminate a gateway tick with no token/tool delta (SCHED-GAP-1707) — 0 disables the guard | M9 §5 |
| `session-poll-loop-min-ticks` | `:170` | 0 | int | terminate a confirmed sleep-poll loop (SCHED-GAP-1698) — 0 disables | M9 §5 |
| `disable-tick-push` | `:172` | false | bool | skip the per-tick git push at exit (SCHED-GAP-1594) — true stops tick push-at-exit | M9 §5 |
| `no-exec-fallback` | `:190` | true | bool | disable `exec.Command` fallback when the gateway fails — false re-enables the exec fallback | M9 §5 |

> WARNING: the daemon's HTTP surface is loopback by construction — `listen` defaults to
> `127.0.0.1:9090` (`cmd/schedulerd/main.go:96`). Binding it off-loopback exposes the API
> beyond the host it runs on.

**Auxiliary / routing / lifecycle flags** — the remaining 33 of the 57, grouped as the
chapter groups them; ranges not registered in M9 §5 read `not registered` (M9 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `tls-cert` / `tls-key` | `:102-103` | `""` / `""` | not registered | HTTPS listener pair — both set → TLS on; one without the other → no usable cert | M9 §5 |
| `public-url` | `:107` | `""` | not registered | advertised daemon URL — affects self-links in status/dashboards | M9 §5 |
| `test-verify` | `:174` | 0 | not registered | verification self-check — non-zero runs a verification pass at boot | M9 §5 |
| `verify-board` | `:175` | `""` | not registered | board-consistency self-check — names a board to verify at boot | M9 §5 |
| `session-reap-threshold` | `:176` | `DefaultHermesReapStaleAfter` | not registered | stale-session age floor for `--reap-sessions` — a lower threshold reaps fresher sessions | M9 §5 |
| `reap-sessions` | `:177` | false | not registered | one reap pass against `state.db`, then exit — dry-run by default, writes nothing without `--reap-sessions-apply` | M9 §5 |
| `reap-sessions-apply` | `:178` | false | not registered | apply the reap pass (`ended_at` + `end_reason='reaped'`) — the mutation switch; without it the pass is a dry-run (SCHED-GAP-089) | M9 §5 |
| `session-db` | `:179` | `DefaultHermesSessionDBPath()` | not registered | which `state.db` `--reap-sessions` reads — a wrong path reaps (or fails to find) the wrong store | M9 §5 |
| `duckbrain-ns` / `duckbrain-url` / `duckbrain-interval` | `:180-182` | `scheduler` / `http://localhost:3000` / `5m` | not registered | DuckBrain sync target + cadence — a wrong URL/interval stops the sync spool | M9 §5 |
| `simulate` | `:183` | false | not registered | dry-run mode, no real spawning — true suppresses real spawns; the sim-* knobs only take effect with it | M9 §5 |
| `sim-success` / `sim-idle` / `sim-count` | `:184-186` | 0.85 / 0.0 / 0 | not registered | simulated outcomes — only meaningful under `--simulate`; `sim-count N` generates N synthetic ticks then exits | M9 §5 |
| `gateway-url` / `gateway-key` | `:187-188` | `http://127.0.0.1:8642` / `$API_SERVER_KEY` | not registered | the gateway endpoint + key — a wrong URL/key makes every foreman turn fail; an empty `gateway-url` does not alone authorize `exec.Command` fallback: the fallback requires `no-exec-fallback=false` (default true); with the default a nil gateway client DEFERS the tick (`spawn.go:698` `transientGatewayDeferral`, call site `:1759`, a transport deferral, not a lane failure) (B17) | M9 §5 |
| `model-rates-file` | `:189` | `$SCHEDULER_MODEL_RATES_FILE` | not registered | price-sticker JSON applied over builtin rates — a wrong sticker file re-prices the cost model (ADV-R09/G8) | M9 §5 |
| `foreman-home` | `:191` | `$HOME/.hermes/foreman` | not registered | `HERMES_HOME` for foreman sessions — a wrong path points foreman at the wrong state | M9 §5 |
| `sim-setup` / `sim-ticks` | `:192-193` | false / 10 | not registered | 13-project dry-run fixture — `sim-setup` creates the fixture; `sim-ticks` sets its tick count | M9 §5 |
| `config` | `:194` | `""` | not registered | TOML fleet config path — a wrong path loads no (or the wrong) fleet config | M9 §5 |
| `failure-window` | `:195` | 100 | not registered | per-project tick window for the `/api/v1/status` failure-rate breakdown — a larger window smooths the breakdown | M9 §5 |
| `auto-disable-failure-rate` | `:196` | 0 (off) | 0.0–1.0 | per-project failure-rate threshold for auto-disable — a non-zero threshold arms `internal/scheduler/alert_escalation.go:462-548` to write `projects.enabled=0` on sustained failure, an execution-settlement consequence, not simulation (SCHED-GAP-018) | M9 §5 |
| `auto-disable-window` | `:197` | 100 | not registered | ticks over which the auto-disable rate is computed — a shorter window disables faster on noise | M9 §5 |
| `auto-disable-min-ticks` | `:198` | 50 | not registered | minimum ticks before auto-disable may fire — too low disables projects on thin evidence | M9 §5 |
| `groups-file` / `templates-file` | `:199-200` | `""` / `""` | not registered | deploy group/template JSONL paths — empty = default `<db dir>` paths; a wrong path reads the wrong deploy blocks | M9 §5 |
| `log-file` | `:205` | `defaultLogPath()` | not registered | structured tick log destination — empty disables; a wrong path loses the tick journal | M9 §5 |
| `show-config` | `:206` | false | not registered | print resolved config (CLI + env) as TOML, exit — read-only introspection switch | M9 §5 |
| `schema` | `:207` | false | not registered | output JSON Schema for `schedulerd.toml`, exit — read-only introspection switch | M9 §5 |
| `version` | `:208` | false | not registered | print version/build info, exit — read-only introspection switch | M9 §5 |

## M10 — crier

`config/config.go:621-674` fixes the defaults; `config/config.go:1139-1187` fixes the
guard's env bounds (M10 §5):

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `Port` | `config/config.go:622` | `8767` | a TCP port | the bus HTTP surface — a change orphans every node/dispatcher | M10 §5 |
| `RateLimitPerMinute` | `:627` | 100 | int | per-caller rate limit — 0 disables the limit | M10 §5 |
| `InboxMaxBodyBytes` | `:628` | `1 << 20` | bytes | deliver body ceiling — larger bodies admitted unbounded | M10 §5 |
| `RequireAgentSig` | `:629` | true | bool | signed-read enforcement — off → `requireAgent` returns true without a signature (`agentsig.go:364-368`) | M10 §5 |
| `Webhook.Timeout` | `:636` | 30 s | duration | webhook call timeout — a lower timeout drops deliveries | M10 §5 |
| `Webhook.MaxRetries` | `:637` | 5 | int | webhook retry count — lower = fewer redeliveries | M10 §5 |
| `Webhook.RedeliverEvery` | `:638` | 30 s | duration | redelivery spacing — too fast floods the target | M10 §5 |
| `Webhook.ProbeEvery` | `:639` | 60 s | duration | webhook health probe — slower probes miss outages | M10 §5 |
| `Webhook.CircuitThreshold` | `:640` | 10 | int | circuit-open threshold — lower opens the circuit sooner | M10 §5 |
| `Webhook.BatchMaxMessages` | `:641` | 10 | int | batch size — larger batches raise latency | M10 §5 |
| `Webhook.BatchFlushInterval` | `:642` | 5 s | duration | batch flush cadence — too long delays delivery | M10 §5 |
| `Guard.Enabled` | `:645` | true | bool | guard on/off — off lets untrusted directives through | M10 §5 |
| `Guard.Timeout` | `:646` | 10 s | duration | per-check LLM timeout — a short timeout's outcome is conditional on the error policy, not a blanket fail-open: `guard.go:332-357` `errorResult` depends on `FailClosed`, `policy.Action` and high-confidence deterministic evidence (B20) | M10 §5 |
| `Guard.MaxConcurrent` | `:647` | 8 | int | check concurrency semaphore — `<= 0` is refused at startup, not a saturated guard: `config.go:1154-1158` rejects `CR_GUARD_MAX_CONCURRENT<=0` with a named error; runtime saturation is the distinct failure counted by `crier_guard_saturated_total` (`internal/guard/metrics.go:22`) | M10 §5 |
| `Guard.CircuitThreshold` | `:648` | 10 | int | guard circuit threshold — lower opens the guard circuit sooner | M10 §5 |
| `Guard.CircuitCooldown` | `:649` | 300 s | duration | circuit reopen cooldown — too short thrashes the circuit | M10 §5 |
| `Guard.MaxPayloadBytes` | `:650` | 65536 | bytes | payload ceiling before the router — a raise admits a bigger untrusted payload | M10 §5 |
| `Guard.RenderMaxBytes` | `:651` | 32768 | bytes | render ceiling — a raise sends more to the router | M10 §5 |
| `Guard.DeepSeekBaseURL` / `Guard.Model` | `:652-653` | `https://api.deepseek.com/v1` / `deepseek-v4-flash` | a URL / model | the guard's router — a change re-routes the guard verdicts | M10 §5 |
| `Guard.KanbanQueueSize` | `:654` | 100 | int | guard queue depth — smaller drops queued checks | M10 §5 |
| `Observability.EnableMetrics` | `:673` | true | bool | `/metrics` mount — `CR_ENABLE_METRICS=false` disables it; metrics are default-ON, not opt-in (F10-3); the comment at `internal/metrics/metrics.go:2` calling it "opt-in" disagrees with the default-ON config | M10 §5 |
| front `defaultListen` | `crier-front/main.go:39` | `127.0.0.1:8770` | a loopback listen | the front's surface — binding off-loopback exposes the front | M10 §5 |
| `CR_GUARD_TIMEOUT_MS` / `CR_GUARD_MAX_CONCURRENT` / `CR_GUARD_CIRCUIT_THRESHOLD` / `CR_GUARD_CIRCUIT_COOLDOWN_S` / `CR_GUARD_MAX_PAYLOAD_BYTES` / `CR_GUARD_RENDER_MAX_BYTES` | `config.go:1139-1187` | env, positive only | int > 0 | guard tuning — a non-numeric or `<= 0` value → named error (`invalid CR_GUARD_…`), not a silent default | M10 §5 |
| `CR_REGISTRY_BACKEND` / `Registry.Backend` | `config/config.go:104`, resolved by `ResolvedRegistryBackend()` `:113-123` | resolution chain: explicit backend → a `sqlite:` `Database.URL` → any non-empty `Database.URL` (postgres) → `memory` | an enum of the three backends | which backend serves custody — the `memory` backend is process-local and demo-only; see Part VI for the WARNING; how an operator proves which backend is actually serving custody (readback of the resolved backend at boot) is not yet written — a named RED on this register (M10 §5) | M10 §5 |

Guard policy precedence (B21): `policy.go:172-202` `ResolvePolicy` — first agent policy
whose `channel_match` glob matches the session/thread key, then `serverDefault`
(`CR_GUARD_DEFAULT_POLICY`), then `BuiltinDefaultPolicy()`; a channel-glob-only policy
never matches an unchanneled message.

## M11 — dispatcher

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `DISPATCH_POLL_S` | `dispatcher.py:43` | 5 | positive float | poll interval — shorter polls raise bus load | M11 §5 |
| `DISPATCH_PROGRESS_S` | `:45` | 20 | positive int | seconds between progress lines the node runner writes — no suppression branch exists: the runner loop (`:250-257`) writes a line then `sleep {hb}`; 0 removes the delay (busy loop), a negative value fails the `sleep` and the loop continues; 0 or negative does not suppress progress (B25) | M11 §5 |
| `DISPATCH_LEASE_S` | `:46` | 1800 | positive int | inbox lease — too long holds messages during a crash | M11 §5 |
| `DISPATCH_EXEC_TIMEOUT` | `:47` | `"400s"` (a string) | — | inert in this revision — assigned at `:47` and never read (B22 AST check: exactly one `Store` reference, no load); the real per-call timeout is `_bunker`'s `timeout` argument (default 120, `:204-209`), with the outer subprocess capped at `timeout + 20` (`:209`); this env var adds no timeout prefix to `bunker exec` and changes nothing at run time | M11 §5 |
| `DISPATCH_TASK_S` | `:48` | `"240"` (a string) | positive int at use (`task_seconds`, `:196`) | fallback task duration — a non-numeric env value raises `ValueError` at use (`int(TASK_S)` at `:196`), not at admission | M11 §5 |
| `DISPATCH_MARGIN_S` | `:52` | 60 | positive int | reserve before the caller's deadline — see F11-4: the reserve is intended, not guaranteed (`task_seconds(10)` and `task_seconds(60)` both return 30) | M11 §5 |
| `DISPATCH_TASK_CAP_S` | `:53` | 7200 | positive int | ceiling on the envelope wall — a larger envelope wall is clamped | M11 §5 |
| `BUNKER_BIN` | `:60` | `~/.local/bin/bunker` | absolute path | which bunker binary runs — PATH order would otherwise pick a wrong binary | M11 §5 |
| `CF_DURABLE_JOB` | `:336` | `"1"` | `"0"` or non-`"0"` | execution mode switch — `"0"` selects the synchronous `hermes chat -q` path (`:334-358`), bypassing the detached start/poll job model (B23); the synchronous path still participates in the outer replay ledger; the crash-before-ledger-write gap (F11-3) applies to both modes | M11 §5 |
| `DISPATCH_LOG` / `DISPATCH_PIDFILE` | `:41-42` | `$FLEET/logs/dispatcher.log` / `$FLEET/dispatcher.pid` | a path | log/PID location — a wrong path loses the journal/lock | M11 §5 |
| `FLEET_GH_SCOPE` | `:68` | `~/.hermes/scripts/fleet-gh-scope.py` | a path | scoped-token minter — a wrong path disables scoped tokens (non-fatal) | M11 §5 |
| `FLEET_AGENTS` / `FLEET_AGENTS_FILE` | `:104-109` | `fleet_agents.json` | a dict / path | agent registry — empty → "no FLEET_AGENTS configured" | M11 §5 |
| `CRIER_URL` (read as `BUS`) | `:38` | `http://<bus-host>:8767` | an http(s) endpoint | which bus the dispatcher polls and replies to — a wrong URL polls or replies to the wrong bus | M11 §5 |
| `TOKEN_FILE` (bearer) | `:39`, a constant | `~/.hermes/secrets/crier-fleet.token` | a path | the bus bearer identity — a missing file → client construction fails (`client for %s failed`) | M11 §5 |
| `KEYS` (signing) | `:40`, a constant | `$FLEET/keys` | a directory | the reply-signing key store — a missing key dir breaks reply signing | M11 §5 |

## M12 — inference proxy

| Setting | Lives in | Default | Range | Changes | Cross-ref |
|---|---|---|---|---|---|
| `CF_PROXY_UPSTREAM` | proxy source `:43` | `http://127.0.0.1:8642` | an http(s) endpoint | where node inference is served — pointing at a provider gives nodes their own lane; the key still never leaves the host | M12 §5 |
| `CF_PROXY_UPSTREAM_MODEL` | `:45` | `""` | a model name or empty | model rewrite — non-empty rewrites the requested model before forwarding (`:166-170`) | M12 §5 |
| `CF_PROXY_UPSTREAM_KEY_ENV` | `:47` | `API_SERVER_KEY` | an env var name | which credential the proxy reads — a renamed credential must be coordinated with the endpoint; the startup error at `:269` hardcodes `API_SERVER_KEY` in its message even when a different name is configured — the diagnostic lies about which variable it checked (F12-3) | M12 §5 |
| `CF_PROXY_ALLOWED_MODELS` | `:60-62` | `hermes` | comma list | which models a node may ask for — empty env = deny all, never "allow everything" (`:58-59`) | M12 §5 |
| `TOKENS_PATH` | `:48` | `~/.hermes/secrets/cf-node-tokens.json` | a JSON file | the node-token mapping read at request time — a missing file → `FATAL: no token file`, exit 2 (`:265-267`) | M12 §5 |
| `ENV_PATH` | `:49`, read by `upstream_key` `:75-80` | `~/.hermes/.env` | an env file | where the upstream key is scanned — a renamed file must match the provisioner | M12 §5 |
| `USAGE_LOG` | `:50` | `~/.hermes/logs/cf-inference-usage.jsonl` | a path | usage capture sink — a failing sink raises into the request path (F12-6); both sinks are hardcoded `pathlib.Path` constants, not environment settings (F12-8); an earlier register revision carried two invented filenames — an operator following it would open two files that are never written | M12 §5 |
| `CAPTURE_LOG` | `:52` | `~/.hermes/logs/cf-inference-requests.jsonl` | a path | request capture sink — capture loss is silent (`capture_request` swallows every exception); the "last 200 requests only" comment (`:51`) is not implemented — the log appends indefinitely (F12-6) | M12 §5 |
| upstream timeout | `:204`, `:241` | 300 s | seconds | `urlopen` timeout on both stream and buffered legs — a shorter timeout truncates long generations | M12 §5 |
| `MAX_BODY` | `:54` | 4 MiB | positive int | request body ceiling — a body `> MAX_BODY` → 400 (`:142-143`) | M12 §5 |
| `LISTEN` | `:53` | `("0.0.0.0", 8775)` | a hardcoded constant, not a setting | proxy listener — no env/flag override; binds 0.0.0.0 so the tailnet can reach it | M12 §5 |

Fail-closed startup: no token file or no upstream key → `sys.exit(2)` before binding
(`:265-270`). The `_forward` union annotation requires Python >= 3.10 (F12-5).

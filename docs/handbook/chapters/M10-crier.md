# M10 — CRIER

## 1. Identity

| Field | Value |
|---|---|
| Module name | CRIER |
| Path | `~/crier/` (Go) |
| Revision | `ae9fc57fdd4e9df7aff79c6d5a934d54329add95` (crier repo HEAD; moved from `86c4c469` through 23 commits. Every file M10 cites — `internal/registry/handler.go`, `internal/guard/guard.go`, `internal/guard/policy.go`, `internal/guard/metrics.go`, `config/config.go`, `clients/python/crier_client.py`, `cmd/crier-front/main.go`, `cmd/server/observability.go`, `internal/metrics/metrics.go` — is byte-identical since `86c4c469` (verified `git diff --quiet 86c4c469..HEAD` per file). The post-stamp changes are `internal/buildinfo/buildinfo.go` (DF-CRIER-502), `cmd/server/*_test.go` (the flaky-test files), `internal/harness/opencode/*_test.go`, and board/docs/releng files — none cited) |
| Language / runtime | Go — `go.mod` declares `go 1.26.10` (a build/toolchain requirement, not a runtime one); host bootstrap `go` = **go1.26.5** (`~/.local/bin/go` → symlink → `~/sdk/go1.26.5/bin/go`), `/usr/bin/go` = **go1.26.8** (`/usr/lib/go-1.26/bin/go`; measured: `/usr/bin/go version` → `go1.26.8 linux/amd64`); `GOTOOLCHAIN=auto` auto-fetches 1.26.10 for this repo |
| Owner lane | crier (control plane) |
| Status | **UNVERIFIED** — `internal/registry/handler.go` (deliver/retrieve/ack surfaces + the full 3-site slog surface), `internal/guard/guard.go` (pipeline, oversize branch, `errorResult`), `internal/guard/policy.go` (`ResolvePolicy`), `internal/guard/metrics.go`, `config/config.go` (controls + guard bounds + metrics default), `clients/python/crier_client.py`, `cmd/crier-front/main.go` read; the full 1895-line handler body still not read line-by-line (its slog surface *is* complete — see §9) |

## 2. Purpose, authority and position

The bus: registration, routing, acceptance, durable custody, leases, retrieval, ack, TTL,
transfer and dead letters. Every node↔scheduler message rides crier, and Crier is the resolved
**launch/return boundary** for the Bunker foreman: the foreman is launched through Crier and its
response returns through Crier to the scheduler on the control host. It decides who may read
whose inbox (signed read) and what the guard may block. It does **not** decide task acceptance:
a transport response, a lease, an acknowledgment and the task's independent acceptance are four
separate facts, and Crier owns only the first three.

**What breaks if this module is absent.** The bus is gone; no node message or scheduler envelope
moves.

**What breaks if it lies.** The guard (M10.S2) is the pattern pre-scan → payload render → LLM
router verdict → escalation → sanitize quarantine (`guard.go:25-28`). A false pass lets an
untrusted directive reach a node. The reverse guarantee is the signed-read ladder, whose actual
order is documented below (§10) — not "signature before lookup".

**Required behavior (normative).** Approved target behavior governs; the source inventory in
§3–§13 is implementation coverage, not the requirement.

- **Retained custody semantics, selected profile still to be specified.** Custody aliases,
  lease/ack/TTL, signatures, guard policies and degradation, storage-backend selection, metrics
  and the existing adapters (webhook, session/harness) are retained (§3, §5, §8). The **selected
  Factory invocation/return profile and execution location** must still be written: durable pull
  inbox vs webhook vs Hermes-session vs harness-bound ingress, the executor's Bunker boundary,
  reply target, envelope/schema version and compatibility negotiation. A source snapshot
  establishes what the adapters *can* do; it does not establish the MVP wiring.
- **Four separate facts.** A delivery's transport acceptance (with its guard verdict), the
  consumer's lease, the consumer's acknowledgment, and the task's execution outcome/independent
  acceptance are separate facts with separate owners. A successful transport response — or a
  decoder fix on one leg — never proves the Factory workflow was accepted. Fan-out is separate
  recipients and receipts, not one global success.
- **Complete wire contracts.** Full register/deliver/retrieve/ack/session schemas with
  versioning, payload encoding and size limits, auth/scopes, correlation to task/run/attempt
  generations, idempotency-key scope/retention/conflicts and exactly which side may replay,
  lease renewal, and job deadlines are required contracts. The fragments in §3 (aliases, bounds,
  filter-after-claim, TTL semantics) are coverage evidence for parts of them, not the contracts
  themselves; the client library's existence is not a schema.
- **The 30-second claim is scoped, not universal.** The historical cluster-baseline statement
  that Crier cannot carry work beyond 30 seconds is scoped to its historical mode/version — it is
  not a universal task-runtime assumption. The 30 s retrieve lease is the *default* and is
  requester-adjustable (M11's dispatcher leases 1800 s); HTTP, lease, job, heartbeat, retry and
  retention clocks are stated independently, and long-job durability across disconnect/restart
  remains the requirement.
- **Retrieval grants the lease — delivery does not.** A retrieve grants the consumer an inbox
  lease; delivery writes the durable inbox and starts no lease. The flight card below is
  corrected accordingly, and any diagram or procedure that says "delivery starts the lease" is
  wrong.
- **The memory-backend restart drill is a negative control, not readiness.** Restarting under the
  `memory` backend and observing empty inboxes demonstrates **non-durability** — it is a negative
  control, not production-readiness evidence. Durable custody must be proven under the **selected**
  backend (`sqlite:`/`postgres`): restart → retrieve → ack with retained identities, idempotency
  state and held deliveries. Backup-created ≠ backup-validated ≠ restore-drill-passed, and
  historical drills do not prove this fleet's off-host recovery.
- **Degraded counters are not emptiness.** `HandleRetrieve`'s post-retrieve stats path logs an
  error while the returned queue-depth/leased counters can degrade to zero (`handler.go:1795`).
  Zero counters after a stats error cannot prove an empty queue — unavailable/partial-state must
  be carried to operational consumers. Filter-after-claim also leaves nonmatching messages
  temporarily leased, which must not be read as backlog or as its absence.
- **Separately enforceable guarantees.** Signature/ACL enforcement — including the conditional
  `RequireAgentSig` off-switch — and Bunker safety guarantees are kept separately enforceable: a
  guard allow with `errored=true` is not a clean check, deterministic auth/ACL/resource-isolation
  contracts survive guard degradation, and the transport guard is not execution safety or
  accepted work.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 custody and transport | `internal/registry/handler.go` (1895 lines) | **active** | `HandleRegister` (`:598`), `HandleDeliver` (`:990`), `HandleRetrieve` (`:1690`), `HandleAck` (`:1812`) |
| S2 the guard | `internal/guard/guard.go` | **active** | `Guard.Check` (`:167`) is the choke point; pipeline documented at `:25-28`; oversize branch `:198-234`; `errorResult` `:318-361` |
| S3 binaries, ports, services | `config.go:622` port 8767; `crier-front/main.go:39` listen `127.0.0.1:8770` | **active** | read |
| S4 client libraries | `clients/python/crier_client.py`, `clients/typescript` | **active** | Python client read (`deliver` `:975`, `retrieve` `:1009`, `ack` `:1038`) |

**Custody lifecycle (B20).** The wire contract of a retrieve, derived from the
handler and the Python client:

- **Parameter aliases and precedence** (`handler.go:1711-1743`): the spec'd `limit`/`lease_seconds`
  alias the historical `max`/`lease`. When both spellings appear in one request, the historical
  `max`/`lease` **wins** — the alias fills in only what the historical name left absent
  (DF-CRIER-180).
- **Defaults and bounds**: default batch **10** messages, capped at **100** (a `max > 100` returns
  400 `max must be <= 100`, `:1727-1730`); default lease **30 s** (`:1732-1743` — a requester-adjustable
  default, not a fixed bound; M11's dispatcher leases 1800 s). **The lease starts at retrieval**:
  delivery (`HandleDeliver`) writes the durable inbox; it is the retrieve (`HandleRetrieve`, `:1690`)
  that grants the consumer's lease — never the reverse.
- **Filter-after-claim** (`:1770-1775`, CRIER-TAGS §2.4): a retrieve leases first, then applies a
  tag filter in Go over the claimed batch. Entries the filter drops **stay leased until their lease
  expires** — they are not lost, they are briefly unavailable to another reader (a stated KNOWN
  LIMIT, not hidden).
- **Deliver TTL semantics** (`crier_client.py:975-1006`): `ttl_seconds` absent keeps the store
  default (24 h); `0` means never expire (reported `expires_at: null`). Body-signing happens only
  when `sender == this client's agent_id`; other/missing sender stays unsigned for legacy
  recipients.
- **Retrieve semantics** (`crier_client.py:1009-1036`): `GET /agents/{id}/inbox`, signed; a `204`
  or empty body returns `[]`; messages carry their batch `lease_id`. A held (leased) message is
  not returned again until its lease expires — an empty list after a failed ack is expected, not a
  lost message; `stats()` distinguishes "nothing queued" from "everything leased".

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| Go toolchain (build) | `go 1.26.10` (`go.mod`) | build host | `GOTOOLCHAIN=auto` fetches 1.26.10 — `go build ./...` **PASS**; with `GOTOOLCHAIN=local` the 1.26.5 host would refuse |
| PostgreSQL (via `pgx/v5`) / SQLite (via `modernc.org/sqlite`) | driver-pinned | control host | DB open failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `gorilla/mux` | external | HTTP routing | a route change breaks the inbox surface |
| `crier_client.Crier` | this repo (python) | `deliver`/`retrieve`/`ack` + `Message.payload` | a rename breaks the **dispatcher (M11)** — the node worker (M2) does **not** import it (M2 imports `urllib`, F2-1) |

**4c. Service contracts** — see §6.

## 5. Settings register

`config/config.go:621-674` fixes the defaults; `config/config.go:1139-1187` fixes the guard's env
bounds. Individual rows (B21):

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `Port` | `8767` (`:622`) | a TCP port | the bus HTTP surface | a change orphans every node/dispatcher |
| `RateLimitPerMinute` | 100 (`:627`) | int | per-caller rate limit | 0 disables the limit |
| `InboxMaxBodyBytes` | `1 << 20` (`:628`) | bytes | deliver body ceiling | larger bodies admitted unbounded |
| `RequireAgentSig` | true (`:629`) | bool | signed-read enforcement | off → `requireAgent` returns true without a signature (`agentsig.go:364-368`) |
| `Webhook.Timeout` | 30 s (`:636`) | duration | webhook call timeout | a lower timeout drops deliveries |
| `Webhook.MaxRetries` | 5 (`:637`) | int | webhook retry count | lower = fewer redeliveries |
| `Webhook.RedeliverEvery` | 30 s (`:638`) | duration | redelivery spacing | too fast floods the target |
| `Webhook.ProbeEvery` | 60 s (`:639`) | duration | webhook health probe | slower probes miss outages |
| `Webhook.CircuitThreshold` | 10 (`:640`) | int | circuit-open threshold | lower opens the circuit sooner |
| `Webhook.BatchMaxMessages` | 10 (`:641`) | int | batch size | larger batches raise latency |
| `Webhook.BatchFlushInterval` | 5 s (`:642`) | duration | batch flush cadence | too long delays delivery |
| `Guard.Enabled` | true (`:645`) | bool | guard on/off | off lets untrusted directives through |
| `Guard.Timeout` | 10 s (`:646`) | duration | per-check LLM timeout | a short timeout's outcome is **conditional on the error policy**, not a blanket fail-open: `guard.go:332-357` `errorResult` depends on `FailClosed`, `policy.Action` and high-confidence deterministic evidence (B20) |
| `Guard.MaxConcurrent` | 8 (`:647`) | int | check concurrency semaphore | **`<= 0` is refused at startup, not a saturated guard**: `config.go:1154-1158` rejects `CR_GUARD_MAX_CONCURRENT<=0` with a named error; runtime saturation is the distinct failure counted by `crier_guard_saturated_total` (`internal/guard/metrics.go:22`) |
| `Guard.CircuitThreshold` | 10 (`:648`) | int | guard circuit threshold | lower opens the guard circuit sooner |
| `Guard.CircuitCooldown` | 300 s (`:649`) | duration | circuit reopen cooldown | too short thrashes the circuit |
| `Guard.MaxPayloadBytes` | 65536 (`:650`) | bytes | payload ceiling before the router | a raise admits a bigger untrusted payload |
| `Guard.RenderMaxBytes` | 32768 (`:651`) | bytes | render ceiling | a raise sends more to the router |
| `Guard.DeepSeekBaseURL` / `Guard.Model` | `https://api.deepseek.com/v1` / `deepseek-v4-flash` (`:652-653`) | a URL / model | the guard's router | a change re-routes the guard verdicts |
| `Guard.KanbanQueueSize` | 100 (`:654`) | int | guard queue depth | smaller drops queued checks |
| `Observability.EnableMetrics` | **true** (`:673`) | bool | `/metrics` mount | `CR_ENABLE_METRICS=false` disables it |
| front `defaultListen` | `127.0.0.1:8770` (`crier-front/main.go:39`) | a loopback listen | the front's surface | binding off-loopback exposes the front |
| `CR_GUARD_TIMEOUT_MS` / `CR_GUARD_MAX_CONCURRENT` / `CR_GUARD_CIRCUIT_THRESHOLD` / `CR_GUARD_CIRCUIT_COOLDOWN_S` / `CR_GUARD_MAX_PAYLOAD_BYTES` / `CR_GUARD_RENDER_MAX_BYTES` | env, positive only (`config.go:1139-1187`) | int > 0 | guard tuning | a non-numeric or `<= 0` value → named error (`invalid CR_GUARD_…`), not a silent default |

**Metrics-default correction (F10-3).** `config.go:667-673` sets `EnableMetrics: true` by default;
`CR_ENABLE_METRICS` is the disabling override; `cmd/server/observability.go:101-109` mounts
`/metrics`. Metrics are default-ON, not opt-in. **Contradicting artifact (N4, locator re-pinned):**
`internal/metrics/metrics.go:2` still calls the surface "the opt-in GET /metrics surface" — the
comment (line **2**, not 5) disagrees with the default-ON config.

**Storage-selection controls (B20; memory backend B19).** `config/config.go:113-123` `ResolvedRegistryBackend()` resolves the custody backend in this precedence: an explicit `CR_REGISTRY_BACKEND` (`Registry.Backend`, `:104`) → a `sqlite:` `Database.URL` → any non-empty `Database.URL` (`postgres`) → **`memory`**. `:732-767` implements database-URL precedence plus explicit backend validation and refusal conditions; `:770-808` implements pool controls. The **memory** backend is process-local and demo-only: held deliveries and inboxes are **lost on restart** (`config.go:550-551`), so custody is not durable under it. A register that names only the driver rows and transport defaults is incomplete; how an operator proves *which* backend is actually serving custody (readback of the resolved backend at boot) is not yet written (a named RED on §5).

> WARNING: the `memory` registry backend is process-local and demo-only — held deliveries and
> inboxes are lost on restart (`config.go:550-551`). Custody is not durable under it; any
> deployment that must survive a daemon restart requires a `sqlite:` or `postgres` backend.

## 6. Contracts in and out

Canonical ids are the register of record (Part IV, CT-01..CT-23). Local ids are
retired; each row carries the CT id its peer chapter cites, so two ends can be matched.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-02 | scheduler | in | `<scheduler>/internal/bus/dispatch.go:202` `payload()` (envelope with `text_b64`, `board`) | `handler.go:990` `HandleDeliver` | **works (transport)** — crier delivers the envelope verbatim. The former `text_b64` vs `text` mismatch was a **node-consumption** defect, now fixed (the node decodes `text_b64` at `node-bus-worker.py:989`; CF-354 complete), so the scheduler→crier→node leg is now works end-to-end. **This supersedes OUTLINE Part IV's "scheduler → crier … broken" and README I.3's "10 works / 6 broken / 2 missing"** |
| CT-03 | node | out | `handler.go:1690` `HandleRetrieve` (lease-granting side; the client library `crier_client.py:1009` is the consumer-side call) | `scripts/node-bus-worker.py:1007` `process` (the node's inbox consumer; decodes `text_b64` via `directive_text` `:977`) | works — lease/transport works, and the consumption field-mismatch (CF-354) is fixed |
| CT-04 | node | in | **node's own HTTP deliver** — `node-bus-worker.py:1208` `deliver` (urllib, **not** `crier_client.py`; POST `/agents/{target}/inbox`) | `handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport)** — crier accepts the reply verbatim. CF-355 is **this reply's** settlement defect: the node sends `status` (`node-bus-worker.py:1180`), the scheduler's `dispatchReplyVerdict` reads only `ok` — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-08 | gateway | out | crier `internal/registry/dispatch.go:369` `h.hermes.Deliver` (session delivery), implemented by `internal/hermesession/hermesession.go:353` `Client.Deliver` (token acquisition, session selection, chat execution, replay) — **in-repo** | **external** — the Hermes gateway (out of scope) | **works (crier side named)** — the producer is in-repo and named; only the gateway consumer is out of scope (an earlier citation wrongly marked the producer "external") |

CT-08 is a boundary contract: the Hermes gateway is outside the five covered systems, so
"one side named + the other marked external" is the honest terminal state, not a chapter defect.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (crier repo) | exit 0 | 2026-11-07, rev `ae9fc57f` | **PASS** (rc 0) |
| go test | `go test ./...` | green | 2026-11-07, rev `ae9fc57f` | **PASS (0 FAIL, one fresh run)** — all packages ok including `cmd/server` (65.4s) and `internal/registry` (10.6s). See the flakiness note: a single green run at this HEAD does **not** retire the flaky finding |
| port fact | `grep -n 'Port' config/config.go` | 8767 | 2026-11-06 | PASS (`:622`) |
| slog surface | `grep -c 'slog.\(Info\|Error\|Warn\|Debug\)' internal/registry/handler.go` | 3 | 2026-11-06 | **PASS** — exactly 3 sites (all in §9); no `log.Printf`/`fmt.Printf` in the handler |
| signed-read ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox 200 with key+bearer | 2026-11-05, cf-node only | PASS (FACT-04) — not repeatable from this control host |

**Assurance-gap note (re-measured).** An earlier audit recorded `internal/registry` as "no tests to
run". At the same revision the package has **91 test files** (measured: `ls internal/registry/*_test.go`),
and `go test` ran them in 6.962 s. A green run over 91 test files is real, but it still does not
prove line-by-line coverage of the 1895-line handler.

**`go test` flakiness (re-measured).** `go test ./...` has historically **not**
reliably reproduced green: at HEAD `86c4c469` a fresh `go test -count=1 ./cmd/server/` run FAILed
(`--- FAIL: TestSessionFanoutWebhookBodyVerdict`, 78.5s in one run, 34.3s in another) while a cached
full run reported green; a repeat run reproduced `--- FAIL: TestMetricsState_SeriesRenderOnIdleBoot`
twice (58.0s / 47.4s) with `crier_detect_alerts_total{signal="odd_hour_volume",severity="warning"} =
1, want 0`. Each named test passes in isolation under `-run` (0.327s), and the failing test differs
run-to-run — a within-`cmd/server` contamination or clock-sensitive failure, not a deterministic
regression. **At HEAD `ae9fc57f` one fresh full run passed clean (0 FAIL, `cmd/server`
65.4s).** The flaky-test files themselves changed since the `86c4c469` measurement (`cmd/server/metrics_state_test.go`
+41, `cmd/server/session_budget_cut_test.go`, `cmd/server/session_dispatch_live_test.go`), so the green
run is evidence the tests *can* pass at this HEAD, not proof of determinism — the flaky finding stands
until a repeat run under load fails to reproduce a failure. `internal/registry` (91 test files) ran
green.

## 8. Metrics

**Measured — real, not RED (default-ON).** Crier implements a Prometheus text-exposition registry
(`internal/metrics/metrics.go`) mounted at `/metrics` by default (`config.go:673`;
`observability.go:101-109`). **Inventory scope (corrected):** the command
`grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u` returns **67** unique
strings, not ~40; that count mixes runtime series, histogram `_bucket/_sum/_count` exposition
components, and the test-only `crier_test_*` family — so it is a grep census, not a metric contract.
The runtime series (with their emitter lines) are:

- **Guard** (`internal/guard/metrics.go:22-49`): `crier_guard_saturated_total` (`:22`, a counter for
  checks failed open because the concurrency cap stayed full), `crier_guard_all_providers_failed_total`
  (`:28`), `crier_guard_check_duration_seconds{decision,errored}` (`:44-49`, a histogram with closed
  label enums `decision ∈ {allow,block,sanitize}` and `errored ∈ {true,false}`, seeded at 0 so the
  bounded domain is visible before any check).
- **Delivery/inbox** (`internal/registry/handler.go:38-45`): `crier_delivery_accepted_total`,
  `crier_guard_decisions_total{decision}`, `crier_inbox_*` (queue_depth, queue_leased,
  queue_oldest_age_seconds, deliver_duration histogram, expired_total, shed_total, transfers_total,
  deadlettered_total, expiry_receipts_total), `crier_delivery_idempotent_replay_total`.
- **Capability** (`internal/registry/capability.go:99-105`): `crier_capability_routed_total`,
  `crier_capability_unheld_total`.
- **Webhook / harness / store / detect / HTTP / federation**: `crier_webhook_*`,
  `crier_harness_*`, `crier_store_*`, `crier_detect_*`, `crier_http_requests_total{code,route}`,
  `crier_http_request_duration_seconds` (histogram), `crier_federation_*`, `crier_relay_events_total`,
  `crier_ws_subscribers`, `crier_up`, `crier_build_info`, `crier_start_time_seconds`.

The per-metric `question answered` and exact `label domains` for every runtime series are not yet
filled to the schema's per-metric contract — the series names are inventoried, but the full
per-metric `type/labels/question/scrape` table is a named RED on this field (B21), not a completed
register.

Auth posture: `/metrics` is not exempt — it requires Bearer when `CR_AUTH_TOKEN` is set.

## 9. Log lines (verbatim)

The handler's operator-visible surface uses `slog` (not `log.Printf`). **The handler's slog surface
is exactly 3 sites, all captured** (measured: `grep -c 'slog.(Info|Error|Warn|Debug)'
internal/registry/handler.go` = 3; 0 `log.Printf`/`fmt.Printf`). An earlier "non-exhaustive" hedge
is **withdrawn** with this measured count:

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| info | `inbox deliver replayed` (`handler.go:1332`, `slog.Info`) | a redelivery replays a recorded deliver | evidentiary |
| error | `registry stats after retrieve` (`handler.go:1795`, `slog.Error`) | stats read after retrieve fails | descriptive |
| error | `registry store error` (`handler.go:1885`, `slog.Error`) | store write fails | descriptive |
| info | `observability: metrics enabled` (`observability.go:108`, `slog.Info`) | boot with metrics on (emitter is in `cmd/server/`, not the handler) | evidentiary |

**Guard log surface (B22).** The handler census above is file-local, not module-wide. M10
owns the guard too, and `internal/guard/guard.go:430-457` emits `guard` and `guard blocked`
records carrying `request_id`, provider, model, patterns, decision, risk and error status —
operator-critical records absent from this file-local census. The module-wide log inventory is
therefore **not** complete: the three handler sites are, the guard's are not yet tabulated (a
named RED on this field).

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Unsigned read | 401 | a wrong bearer | by design — order is headers → target lookup → caller==target → timestamp → key → signature (`agentsig.go:167-263`); an unknown target 404s at `:204` |
| Mismatched envelope version | old node silently accepts a new control host | a versioned refusal | **OPEN** — CF-369 |
| Client library undocumented | `crier_client.py` + typescript consume a versioned contract with no page | a documented client | **OPEN** — OUTLINE M10.S4 |
| Signature enforcement off | `requireAgentSig` false → reads pass unsigned | a signed-only bus | re-enable `RequireAgentSig` (`config.go:629`; conditional at `agentsig.go:364-368`) |
| **Oversized payload** | guard skips the LLM and branches on deterministic evidence (`guard.go:198-234`): high-confidence prematch → Block; low-confidence → Allow (errored); none → Allow "oversize" (errored) | a normal LLM verdict | automatic — the deterministic pre-scan result is always carried on `Result.Patterns` |
| **Guard error (provider outage)** | `errorResult` (`guard.go:318-361`) defaults to **fail-open** (Allow, errored) unless `policy.FailClosed`, which applies `errorAction(policy.Action)` (default block); a high-confidence prematch escalates even a fail-open to block/high | a clean verdict | set `FailClosed` on the policy to fail closed |
| Empty retrieve ≠ lost message | `[]` after a failed ack while a message is leased | a lost message | use `stats()` to tell "nothing queued" from "everything leased" (`crier_client.py:1018-1021`) |
| **Stats error degrades counters to zero** | `HandleRetrieve` logs `registry stats after retrieve` (`:1795`) while the returned queue-depth/leased counters can read 0 | proof of an empty queue | treat the counters as **unavailable** for that read — zero after a stats error cannot prove emptiness; carry unavailable/partial-state to consumers |

## 11. Limits and margins

- Signature enforcement is **conditional** on `h.requireAgentSig` (`agentsig.go:364-368`).
- A held (leased) message is not returned again until its lease expires (`crier_client.py:1018-1021`).
- Delivery idempotency has distinct replay and busy branches (`handler.go:1307-1365`).
- **Guard policy precedence (B21).** `policy.go:172-202` `ResolvePolicy`: first agent policy whose
  `channel_match` glob matches the session/thread key, then `serverDefault`
  (`CR_GUARD_DEFAULT_POLICY`), then `BuiltinDefaultPolicy()`. A channel-glob-only policy never
  matches an unchanneled message.
- The `:18767` federation surface named in OUTLINE M10.S3 appears in `AGENTS.md:173` (federation
  demo `:18767`/`:18877`) but its live listener status is unmeasured.

## 12. Cross-references

- M9 SCHEDULER is the producer (CT-02) and the settlement consumer of the node reply (CT-04) and the dispatcher completion (CT-06).
- M2 DISPATCH (node) and M11 DISPATCHER are the two inbox consumers; only M11 imports `crier_client`.
- M0 SHARED CONTRACT's `bunker_exec` is *not* a crier contract (F0-1).

## 13. Evidence of record

- Code read: `internal/registry/agentsig.go:160-279, 355-369`; `internal/registry/handler.go`
  (funcs + slog surface + custody `:1711-1775`); `internal/guard/guard.go:1-90, 195-235, 315-362`;
  `internal/guard/policy.go:170-205`; `internal/guard/metrics.go:19-49`; `config/config.go:621-700, 1139-1187`;
  `clients/python/crier_client.py:960-1036`; `cmd/crier-front/main.go:39`;
  `cmd/server/observability.go:95-115, 160-175`; `internal/metrics/metrics.go:1-8`.
- Commands run: `go build ./...` (PASS); `go test ./...` (PASS, 0 FAIL, clean fresh run); `ls internal/registry/*_test.go` (91);
  `grep -c 'slog.(Info|Error|Warn|Debug)' internal/registry/handler.go` (3);
  `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u | wc -l` (67);
  `for f in <9 cited files>; git diff --quiet 86c4c469..HEAD -- "$f"` (all UNCHANGED); `/usr/bin/go version` (go1.26.8).
- Rev: `ae9fc57f` (moved from `86c4c469`; every cited file byte-identical — the post-move changes are buildinfo/tests/harness-test/board/docs, none cited).
- Board rows: CF-337, CF-361, CF-369.
- **Findings:**
  - **F10-1** (carried) — auth order is headers → target → caller → timestamp → key → signature.
  - **F10-2** (corrected) — host bootstrap go is 1.26.5, `/usr/bin/go` is 1.26.8 (re-measured; an earlier measurement recorded 1.26.9); `GOTOOLCHAIN=auto` fetches 1.26.10 and build/test PASS.
  - **F10-3** — metrics are default-ON (`EnableMetrics: true`), not opt-in; `metrics.go:2` still
    says "opt-in" (contradicting artifact, locator re-pinned from `:5` to `:2`).
  - **F10-4** (carried) — guard degradation policy written: oversize branch (`:198-234`) and fail-open/
    fail-closed `errorResult` (`:318-361`) with policy precedence (`policy.go:172-202`).
  - **F10-5** (new) — the handler's slog surface is complete (3/3, §9); the 67-string metric census
    is scoped (runtime vs test helpers vs exposition components), not a completed per-metric register.
  - **F10-6** — repo moved `86c4c469`→`ae9fc57f`; all 9 cited files byte-identical; one fresh `go test ./...` passed clean (0 FAIL, `cmd/server` 65.4s), but the flaky-test files (`cmd/server/*_test.go`) changed since the earlier measurement, so a single green run does not retire the flaky finding.

## 15. Normative Crier launch/return and custody contract (P3-12, P3-18)

The MVP uses Crier as the launch and return boundary: Scheduler on the control host delivers a versioned launch envelope to the project foreman's Bunker inbox; retrieval grants the lease; the foreman returns a correlated result through Crier; Scheduler records the response. Webhook, session and harness adapters are partitioned compatibility modes and cannot execute the same attempt as the selected inbox mode.

The canonical application wire is `cf2a.v1`, with `register.v1`, `round-admission.v1`, worker and report bodies from Part IV/VII.13. The earlier `cf.register.v1`/`cf.return.v1` aliases are retired, not negotiated silently. Registration excludes round/wave/attempt IDs; admission excludes wave/attempt/worker IDs. Custody IDs belong to the Crier response, not to the initial application envelope. §16 defines signed custody operations, including explicit renew and release. Unknown schema, wrong scope, invalid signature, oversized body or expired generation is refused.

The selected production backend is SQLite or PostgreSQL; `memory` is a demo/negative-control backend and cannot satisfy restart durability. Boot readback names the resolved backend. Lease, HTTP, job, heartbeat, retry and retention clocks are independent. A duplicate delivery returns the recorded receipt; a duplicate retrieve returns the existing lease/result; a late return is retained as evidence but cannot alter a replaced attempt. Filter-after-claim reports temporarily leased nonmatching messages rather than calling the queue empty. Stats failure returns `UNAVAILABLE`, never zero-as-empty.

**Binding participant (normative III.M9.S2/S3 / F2/F11).** Crier does not own activation:
the Factory manager owns the active pointer CAS and fsync. Crier durably stores a
non-routable candidate and prepare receipt for `binding.prepare.v1`, then atomically
activates only the matching `(project_id,binding_generation,owner_fence,prepared_digest,
active_digest)` tuple from `binding.commit.v1`, fsyncing its active pointer and receipt.
Identical requests replay their durable receipt; a changed tuple or digest returns
`BINDING_CONFLICT`. A missing commit acknowledgement is resolved by GET readback and
replaying the same manager commit after pointer commit; Crier never chooses a new
generation or rolls the pointer back. Until Crier's active readback equals the manager
pointer and Scheduler's readback in generation, fence and both digests, it must reject
new custody/grant use as `BINDING_NOT_ACTIVE`. This is a participant receipt, not an
activation decision. The interruption table and state procedure are Part I §1.9.4;
Crier's route is one leg of F2 and F11 admission.

The guard result is separate from execution safety and acceptance. `errored=true`, fail-open policy, oversize deterministic decisions and signature-disabled modes remain visible in the result and metrics. The selected policy's fail-closed behavior is explicit. Required metrics cover delivery acceptance, guard decisions/errors, queue and lease state, retries, duplicates, dead letters, backend availability and end-to-end latency. Acceptance cases cover registration, signed read, duplicate delivery, restart under the durable backend, lease expiry, wrong generation, malformed payload, guard outage and late return.

## 16. One signed custody chain and durable operation table (P5-C-07/12; P6-02/08/12; SC-01/07)

Factory peers use TLS 1.3/mTLS enrollment and online revocation from Part I §1.9.3.
Every Crier application request and response uses the `CF2A-CRIER-1` Ed25519 profile
with lowercase-hex signatures; M1's `CF2A-REQUEST-1` remains restricted to
authority enrollment and is not a second Crier signature profile. The profile
identifier is metadata, not a transcript prefix. Signed request headers are
exactly `X-Agent-Id`, `X-Agent-Ts` (RFC3339 UTC), `X-CF2A-Key-Id` and
`X-CF2A-Signature`. The registered body carries request identity, idempotency,
owner fence/epoch and registration generation. `request_id` plus
`idempotency_key` is the replay nonce; no unsigned `X-Nonce` or correlation
header substitutes for it.

The signed bytes are RFC 8785 JCS of the complete application body with any
`signature` member excluded. The body digest is lowercase SHA-256 hex of those
signed JCS bytes. The signature transcript is the following five
UTF-8 lines with no prefix and no final newline:

```text
<METHOD>
<origin-form-path, including bytewise-canonical query when present>
<X-Agent-Ts>
sha256:<lowercase-body-sha256-hex>
audience:<registered-principal>
```

Request audience is `crier.factory`; response audience is the original
requester. A response uses the same headers, JCS rule and transcript with its
own response timestamp and canonical response-body digest. Its signed CustodyReceipt
binds the original request ID/idempotency nonce, request and response principals,
request body digest, response body digest, registration generation, delivery
and lease identity. Mutation and receipt bodies are RFC 8785 JCS UTF-8, at most
1 MiB; an empty signed read hashes zero bytes. Clock skew is ±30 seconds. Signed reads carry `request_id`
and `idempotency_key` as canonical query parameters; their enrolled key resolves
principal/generation and the addressed delivery resolves the active fence. Key
ID resolves only to the enrolled principal and generation. A fresh request ID
with the same idempotency key and body digest replays the original operation;
the same request ID/idempotency nonce and digest returns the saved observation;
the same nonce with different bytes is `REPLAY_CONFLICT`. Unknown key/profile,
stale generation,
incorrect body hash, sender/audience mismatch, expired/revoked identity, stale
timestamp or nonce/digest conflict is `UNAUTHORIZED` or `REPLAY_CONFLICT`
before any custody effect. Signature and body verification precedes
interpretation of queue emptiness, lease or result status.

All target routes are under `/v1/factory`. The `/factory/v1/*` spellings are temporary
migration aliases with identical semantics; unversioned `/agents` and `/agents/*/inbox/*`
return `410 ROUTE_RETIRED` to target clients. Registration is
`POST /registrations` with `register.v1`; collection read is
`GET /deliveries?agent_id=<id>&state=<queued|leased|reconciliation-held|acked|dead>&request_id=<id>&idempotency_key=<key>`;
individual read is
`GET /deliveries/{delivery_id}?request_id=<id>&idempotency_key=<key>`. Reads return the same durable
custody record, never a synthesized zero/empty observation when the store is unavailable.

Every retrieve, renew and ack body contains exactly the common fields
`schema_version:"custody.v1"`, `request_id:ID`, `idempotency_key:ID`,
`owner_fence:Fence` and `registration_generation:PosInt`, plus the operation
fields below. Delivery, result and release bodies use the same common fields and
their registered operation fields; unknown fields are `INVALID_BODY`. The
operation rows add these exact fields:

|| Method/path | Additional request fields | Durable success result |
|---|---|---|
|| `POST /deliver` | recipient, sender, envelope, payload_digest, expires_at, dispatch_grant_hash, `initial_reservation:{reservation_id,receiver_id,visible_at,valid_until}` | 201 `{delivery_id,payload_digest,state:queued,initial_reservation,receipt}`; grant consumed first under Part I §1.9.10 |
|| `POST /retrieve` | agent_id, poll_id, limit 1..100 default 10, lease_s 30..300 default 60 | 200 `{poll_id,messages:Envelope[],lease_id,visible_at,lease_expires_at,valid_until,receipt}`; empty uses messages `[]` and null lease/time fields |
|| `POST /renew` | delivery_id, lease_id | 200 `{delivery_id,lease_id,lease_expires_at,valid_until,receipt}`; the configured 20-second cadence and five-second call never change lease_id |
|| `POST /results` | delivery_id, lease_id, result_envelope, result_digest | 201 `{delivery_id,result_digest,result_custody_receipt,receipt}` after result/outbox fsync |
|| `GET /results/{delivery_id}` | no body | 200 exact stored result and custody receipt; 202 while absent, 503 when readback is unknown |
|| `POST /release` | delivery_id, lease_id, reason, never_started_or_quiescence_ref | 200 `{state:queued,receipt}` only with proof; otherwise 409 `EXECUTION_UNKNOWN` |
|| `POST /ack` | delivery_id, lease_id, result_digest, result_custody_receipt | 200 `{state:acked,result_digest,finalized_at,receipt}` only when result custody matches the original correlation |

`CustodyReceipt` is `{receipt_id:ID,delivery_id:ID,reservation_id:ID,
initial_receiver:ID,request_id:ID,idempotency_key:ID,request_principal:ID,
response_principal:ID,request_body_digest:SHA,response_body_digest:SHA,
registration_generation:PosInt,lease_id:ID|null,chain_seq:PosInt,
previous_receipt_digest:SHA|null,visible_at:Time|null,lease_expires_at:Time|null,
valid_until:Time,finalized_at:Time|null,state,receipt_digest:SHA,signature:Hex}`.
`visible_at` is the initial instant the reserved message became retrievable by
the explicitly named initial receiver. `receipt_id` is the response nonce.
`lease_expires_at` is the current lease deadline. `valid_until` is the earlier of message expiry and round deadline and
bounds every renewal. `finalized_at` is null until ack/dead. `chain_seq` starts
at one on deliver and increases once per signed state transition;
`previous_receipt_digest` links the preceding receipt. `receipt_digest` is
SHA-256 of RFC 8785 JCS of the receipt excluding `receipt_digest` and
`signature`. `signature` is the lowercase-hex Ed25519 response signature over
the transcript above; `X-CF2A-Signature` carries the same value. A wrong
previous digest or sequence is `CUSTODY_CHAIN_CONFLICT`.

One delivery has one lease ID across its whole validity interval. Retrieve creates it;
renewal extends only `lease_expires_at`, never beyond `valid_until`; result return,
release and ack retain it. A repeated poll ID returns the original messages, lease and
receipt without claiming more. A fresh poll excludes currently leased messages. Initial
reservation and claim/receipt insertion are one store transaction. Default lease 60,
renewal 20 and call timeout 5 satisfy `60 > 20 + 5 + 5 clock margin + 15 cleanup reserve`.
SC-01 is therefore valid at the producer, consumer and Part V validator.

Crier monotonic time governs leases; restart conservatively expires active leases while
retaining their chain and marks execution reconciliation required. Expiry returns
`LEASE_EXPIRED` and moves the delivery to reconciliation-held, never to an automatic new
launch. Renewal failure stops new effects and invokes M11 cancellation before expiry.
Release/ack timeout is resolved by GET using the same IDs; a repeated final request
replays the original receipt. Late results remain fenced evidence and cannot replace a
settled generation. Delivery dedupe is `(sender,recipient,idempotency_key)`, result
custody dedupe is `(delivery_id,result_digest)`, and changed bytes are
`IDEMPOTENCY_KEY_REUSED` or `RESULT_CONFLICT`.

Durable states are `queued`, `leased`, `reconciliation-held`, `acked` and `dead`;
result custody and outbox receipts commit in the same SQLite/PostgreSQL transaction.
Backend loss returns `503 CUSTODY_UNAVAILABLE`, never an empty queue. TTL expiry moves to
dead with an expiry receipt without killing or forgetting native execution. Dedupe
receipts persist 30 days after terminal state and archived custody receipts 90 days;
expired IDs return 410. Crier never launches work, infers execution success or settles
Scheduler state. [M9.17; VI.34; shared SC-01/SC-07 vectors]

Crier emits `factory.telemetry.v1` operations `deliver` and `renew` with delivery chain
sequence, bounded backend/peer outcomes and FactoryIdentity. Result custody is
`deliver`, not a `pass` verdict. Duplicate/replay events do not increment operation
counters twice. Unavailable backend observations are `unknown`, and successful read-only
scrapes produce no state-changing event.

## RED field count: 5 (S1 handler 1895-line body not read line-by-line — the slog surface is complete but the body's non-slog semantics are not; §8 per-metric contract — series names inventoried but the type/labels/question/scrape table not filled; §9 guard log surface not tabulated — B22; §5 storage-selection custody-proof not written — B20; §7 `go test ./...` — one fresh clean run at HEAD `ae9fc57f`, but the flaky finding is not retired (single run ≠ determinism))

## FLIGHT DATA FILE - M10 CRIER

```checklist
TITLE: M10 CRIER
WHO: CONTROL HOST
REGISTER - sign and POST /agents
√ 200 - identity accepted, signing key stored
DELIVER - POST a signed envelope to the agent inbox
√ INBOX - durable inbox row written (no lease yet — RETRIEVE grants the lease, not delivery)
RESTART - restart the daemon under the memory backend
√ EMPTY - inboxes are empty after restart (NEGATIVE CONTROL: this proves memory custody is
  NOT durable — readiness requires the durable-backend restart/retrieve/ack proof)
```

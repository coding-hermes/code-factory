# M10 — CRIER

## 1. Identity

| Field | Value |
|---|---|
| Module name | CRIER |
| Path | `/home/kara/crier/` (Go) |
| Revision | `a9044518` (crier repo HEAD, this round's stamp — re-stamped from `e50e55ee`). HEAD advanced through three test/qa-only commits: `1587a03f` (INT-CI-027, `cmd/server/session_dispatch_live_test.go`), `a4efefbb` (CRIER-HARNESS-7, `internal/harness/opencode/live_delivery_test.go`), `a9044518` (qa: record crier battery transport failure). `git diff --name-only e50e55ee..HEAD` = those two test files plus the two board JSONL (`.coding-hermes/board/{events,tasks}.jsonl`). Every cited **non-test** file is byte-identical to `33c1f388` (`git diff --name-only 33c1f388..HEAD -- internal/registry/handler.go internal/guard config/config.go internal/registry/agentsig.go internal/registry/service_auth.go clients/python/crier_client.py clients/typescript/crier.ts cmd/crier-front/main.go cmd/crier-mcp/main.go cmd/server/observability.go internal/metrics/metrics.go deploy/` → **empty**, re-verified this round). The round-15 stamp `0a372209` is superseded. A live crier foreman is active on this repo and may land further test-only/board commits; the load-bearing fact is the cited non-test files' byte-identity to `33c1f388`, not the exact HEAD tip |
| Language / runtime | Go — `go.mod` declares `go 1.26.10`; inside the module `go env GOVERSION` resolves **go1.26.10** via `GOTOOLCHAIN=auto` from the module cache. The host **bootstrap** binaries were NOT upgraded: `/usr/bin/go` = **go1.26.8** (`cat /usr/lib/go-1.26/VERSION`), `/home/kara/.local/bin/go` = **go1.26.5** (`readlink -f` → `/home/kara/sdk/go1.26.5/bin/go`). The round-16 judges' 1.26.8/1.26.5 was correct; round-17's "the host was upgraded to 1.26.10" was FALSE (kimi #3) |
| Owner lane | crier (control plane) |
| Status | **UNVERIFIED** — `internal/registry/handler.go` (deliver/retrieve/ack surfaces + the full 3-site slog surface), `internal/guard/guard.go` (pipeline, oversize branch, `errorResult`, `audit`), `internal/guard/router.go` (saturation counter), `internal/guard/policy.go` (`ResolvePolicy`), `internal/guard/metrics.go`, `config/config.go` (controls + guard bounds + metrics default + service-delivery), `internal/registry/service_auth.go`, `clients/python/crier_client.py`, `clients/typescript/crier.ts`, `cmd/crier-front/main.go`, `cmd/crier-mcp/main.go`, `deploy/*` read this round; the full 1895-line handler body read line-by-line this round (register, deliver, retrieve, ack, stats, idempotency, realms, per-peer policy, service-delivery auth, federation fallback — see §3) |

## 2. Purpose, authority and position

The bus: registration, routing, acceptance, leases, retrieval, ack, TTL, transfer and dead
letters. Every node↔scheduler message rides crier. It decides who may read whose inbox (signed
read) and what the guard may block.

**What breaks if this module is absent.** The bus is gone; no node message or scheduler envelope
moves.

**What breaks if it lies.** The guard (M10.S2) is the pattern pre-scan → payload render → LLM
router verdict → escalation → sanitize quarantine (`guard.go:25-28`). A false pass lets an
untrusted directive reach a node. The reverse guarantee is the signed-read ladder, whose actual
order is documented below (§10) — not "signature before lookup".

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 custody and transport | `internal/registry/handler.go` (1895 lines) | **active** | HTTP handlers mounted by `cmd/server` and run under `deploy/crier.service` (`ExecStart=/usr/local/bin/crier -pidfile /run/crier/crier.pid`): `HandleRegister` (`:598`), `HandleDeliver` (`:990`), `HandleDeliverByCapability` (`:1014`, registered at `cmd/server/main.go:112` as `POST /capabilities/{capability}/inbox`), `HandleRetrieve` (`:1690`), `HandleAck` (`:1812`) |
| S2 the guard | `internal/guard/guard.go` | **active** | `Guard.Check` (`:167`) is the choke point, invoked from the deliver path; pipeline documented at `:25-28`; oversize branch `:198-234`; `errorResult` `:318-361`; `audit` `:430` |
| S3 binaries, ports, services | server `:8767`; front `127.0.0.1:8770`; MCP stdio bridge; deploy units | **active (server)** / **operator-invoked (front, mcp)** | `deploy/crier.service` `ExecStart` invokes the server; front listens via `cmd/crier-front/main.go:39` (`defaultListen = "127.0.0.1:8770"`); MCP is `cmd/crier-mcp/main.go` `server.Serve()` (`:219`) — an MCP stdio bridge (JSON-RPC over stdin/stdout), no port; the front's and MCP's production invokers are not in `deploy/` (no unit file names them) — activation UNVERIFIED for those two |
| S4 client libraries | `clients/python/crier_client.py`, `clients/typescript/crier.ts` | **active (python)** / **UNVERIFIED activation (typescript)** | Python client consumed by `crier-fleet/dispatcher.py` (M11 imports `crier_client`); the TypeScript client has no in-repo consumer found (`grep -rn 'crier.ts\|@/clients/typescript' cmd/ internal/` → 0) — its production invoker is out of scope |

**Custody lifecycle.** The wire contract of a retrieve, derived from the handler and the Python
client:

- **Parameter aliases and precedence** (`internal/registry/handler.go:1734-1745`): the spec'd
  `limit`/`lease_seconds` alias the historical `max`/`lease`. The parse block reads `lease` first,
  and only falls back to `lease_seconds` when `lease` is absent (`:1735-1743`) — so the historical
  name **wins** when both are present (DF-CRIER-180). Default lease is `leaseSecs := 30 * time.Second`
  (`:1734`), not `:1732-1743`.
- **Defaults and bounds**: default batch **10** messages, capped at **100** (a `max > 100` returns
  400 `max must be <= 100`, `:1728-1731`).
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
- **Capability routing** (`HandleDeliverByCapability`, `handler.go:1014`; route `POST
  /capabilities/{capability}/inbox` at `cmd/server/main.go:112`): an alternative deliver surface
  that resolves the capability to a holder agent instead of a named recipient. Its authorization
  rule (`internal/registry/service_auth.go:117-126`) **refuses** a capability address whose resolved
  holder is a protected service recipient — `403` `"service delivery requires an explicit recipient
  URL; capability routing cannot authorize a service recipient"`. Outcome counters
  `crier_capability_routed_total` (`capability.go:99`) and `crier_capability_unheld_total`
  (`:105`) back this surface.

**Protected service-delivery authorization (sol B01, corrected this round — the header is
`X-Crier-Audience`, not `X-Crier-Service-Audience`).** `deliverAuthenticated` calls
`authorizeServiceDelivery` at `internal/registry/handler.go:1147` — before body decoding, budgets,
replay admission and every transport side effect. For a recipient registered in the protected set
(`h.serviceDeliveries`), `internal/registry/service_auth.go:128-168` requires: the 4-line
signed-sender form (possession of the **sender** key, not the recipient key); a body `sender` equal
to the signed `X-Agent-ID`; no `principal_id`/`as_agent` (those are human identities, not service
delivery authorization); an allowlisted sender→recipient pair; and — only when a service audience
is configured — a nonempty `idempotency_key` and a matching **`X-Crier-Audience`** header (the
constant `HeaderServiceAudience = "X-Crier-Audience"` at `agentsig.go:35`; the Python client sends
it and appends the audience to the signed transcript at `crier_client.py:846-848`). The three
clients differ in what they supply: the node worker (`node-bus-worker.py:328-338, 1208-1215`) sends
`X-Agent-ID` and a body-bound `X-Agent-Body-SHA256` signature but no body `sender`, no
`idempotency_key`, no audience; the dispatcher (`dispatcher.py:500-508`) sends `sender` but no
`idempotency_key`/audience; the Python client sends all four when `sender` and `audience` are
configured. So "works" for CT-03/CT-04/CT-06 is scoped to **un-protected** recipients; whether
protection is enabled on the live relay is not asserted here.

**TypeScript client surface.** `clients/typescript/crier.ts` is a real consumer, not just a
directory. `Crier` (`:564`) constructor (`:571-588`): validates `baseUrl` starts `http(s)://`
(`:573-575`); `agentId` from options; `token` = `options.token ?? process.env["CR_AUTH_TOKEN"] ?? undefined`
(`:577`); `timeoutMs` default **30000** (`:578`); a signing key is **mandatory** — no
`key`/`keyPath` throws (`:584-587`). `fromEnv` (`:591-598`) reads `CRIER_URL`/`CRIER_HTTP_URL`
(default `http://localhost:8767`, `:561`), `CRIER_AGENT_ID`, `CRIER_AGENT_PRIVATE_KEY_FILE`.
Signing (`:603-625`) covers `METHOD\nPATH\nTS` with `X-Agent-ID`/`X-Agent-Ts`/`X-Agent-Sig`
headers — the same expression the server verifies (`internal/registry/agentsig.go`).

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| Go toolchain (build) | `go 1.26.10` (`go.mod`) | build host | the host bootstrap binaries are 1.26.8 (`/usr/bin/go`) / 1.26.5 (`~/.local/bin/go`); `go.mod`'s `go 1.26.10` directive makes `go build` select go1.26.10 via `GOTOOLCHAIN=auto` from the module cache — `go build ./...` **PASS** |
| PostgreSQL (via `pgx/v5`) / SQLite (via `modernc.org/sqlite`) | driver-pinned | control host | DB open failure |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `gorilla/mux` | external | HTTP routing | a route change breaks the inbox surface |
| `crier_client.Crier` | this repo (python) | `deliver`/`retrieve`/`ack` + `Message.payload` | a rename breaks the **dispatcher (M11)** — the node worker (M2) does **not** import it (M2 imports `urllib`, F2-1) |

**4c. Service contracts** — see §6.

## 5. Settings register

`config/config.go:621-674` fixes the defaults; the guard's env-bounds **field definitions** (the
`CR_GUARD_*` names and their struct defaults) live in `internal/guard/guard.go:49-55`, and
`config/config.go:1139-1187` is the *reader/validator* that applies them (kimi #8 — the round-17
citation named only the reader, not the file that defines the bounds). Individual rows:

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
| `Guard.Timeout` | 10 s (`:646`) | duration | per-check LLM timeout | a short timeout's outcome is **conditional on the error policy**, not a blanket fail-open: `guard.go:332-357` `errorResult` depends on `FailClosed`, `policy.Action` and high-confidence deterministic evidence |
| `Guard.MaxConcurrent` | 8 (`:647`) | int | check concurrency semaphore | **`<= 0` is refused at startup, not a saturated guard**: `config.go:1154-1158` rejects `CR_GUARD_MAX_CONCURRENT<=0` with a named error; runtime saturation is the distinct failure counted by `crier_guard_saturated_total` (`internal/guard/router.go:230-234`, emitted `internal/guard/metrics.go:22`) |
| `Guard.CircuitThreshold` | 10 (`:648`) | int | guard circuit threshold | lower opens the guard circuit sooner |
| `Guard.CircuitCooldown` | 300 s (`:649`) | duration | circuit reopen cooldown | too short thrashes the circuit |
| `Guard.MaxPayloadBytes` | 65536 (`:650`) | bytes | payload ceiling before the router | a raise admits a bigger untrusted payload |
| `Guard.RenderMaxBytes` | 32768 (`:651`) | bytes | render ceiling | a raise sends more to the router |
| `Guard.DeepSeekBaseURL` / `Guard.Model` | `https://api.deepseek.com/v1` / `deepseek-v4-flash` (`:652-653`) | a URL / model | the guard's router | a change re-routes the guard verdicts |
| `Guard.KanbanQueueSize` | 100 (`:654`) | int | guard queue depth | smaller drops queued checks |
| `Observability.EnableMetrics` | **true** (`:673`) | bool | `/metrics` mount | `CR_ENABLE_METRICS=false` disables it |
| front `defaultListen` | `127.0.0.1:8770` (`crier-front/main.go:39`) | a loopback listen | the front's surface | binding off-loopback exposes the front |
| `CR_GUARD_TIMEOUT_MS` / `CR_GUARD_MAX_CONCURRENT` / `CR_GUARD_CIRCUIT_THRESHOLD` / `CR_GUARD_CIRCUIT_COOLDOWN_S` / `CR_GUARD_MAX_PAYLOAD_BYTES` / `CR_GUARD_RENDER_MAX_BYTES` | env, positive only — field defaults at `internal/guard/guard.go:49-55`, reader/validator `config/config.go:1139-1187` | int > 0 | guard tuning | a non-numeric or `<= 0` value → named error (`invalid CR_GUARD_…`), not a silent default |
| `CR_AUTH_TOKEN` | `""` (`:624`) | a bearer token | the message-surface auth token (distinct from the permissions admin token and the federation token) | set → `/metrics` and message routes require Bearer |
| `CR_SERVICE_DELIVERY_ALLOWLIST` | `""` (`:1010`) | exact `sender>recipient` comma list (no wildcards) | the protected-recipient set for service delivery | nonempty arms `authorizeServiceDelivery` (`handler.go:1147` → `service_auth.go:128-168`); a malformed entry → startup refusal (`service_auth.go:44-66` `ParseServiceDeliveryAllowlist`) |
| `CR_SERVICE_DELIVERY_AUDIENCE` | `""` (`:1014`) | a string | this relay's identity in protected signatures | **required when the allowlist is nonempty** (`service_auth.go:82-99` `SetServiceDelivery`) |
| `CR_MCP_NUDGE_ENABLED` / `CR_MCP_NUDGE_MAX_COUNT` / `CR_MCP_NUDGE_SESSION_START` | true / 999 / **false** (`config.go:634`; reader+validation `:697-709`) | bool / positive int / bool | the MCP nudge surface (read-only counts) + the session-start prefix | nudge is **ON by default** (read-only counts); the session-start prefix is **OFF** (it changes an agent's prompt — arming it is a deployment decision); a non-boolean or `<= 0` count → named error |
| `CR_FED_MAX_HOLD_S` | 300 s (`Federation.MaxHold`, `config.go:657`; reader `:971-974`) | positive seconds | how long a federated delivery is held before `FEDERATION_FAILED` (DF-CRIER-7) | a non-numeric value → named error `invalid CR_FED_MAX_HOLD_S` |
| `CR_DATABASE_MAX_CONNS` / `CR_DATABASE_MIN_CONNS` | 4 / 0 (`config.go:660-665`; validation `:771-786`) | positive / non-negative int | the DB pool size | `MinConns > MaxConns` → named error at startup (`:783-786`); a non-numeric or `<= 0` `MAX` → named error |

**Metrics-default correction.** `config.go:667-673` sets `EnableMetrics: true` by default;
`CR_ENABLE_METRICS` is the disabling override; `cmd/server/observability.go:101-109` mounts
`/metrics`. Metrics are default-ON, not opt-in. **Contradicting artifact:** `internal/metrics/metrics.go:2`
still calls the surface "the opt-in GET /metrics surface" — the comment (line **2**) disagrees with
the default-ON config.

**Storage-selection controls.** `config/config.go:113-123` `ResolvedRegistryBackend()` resolves the
custody backend in this precedence: an explicit `CR_REGISTRY_BACKEND` (`Registry.Backend`, `:104`)
→ a `sqlite:` `Database.URL` → any non-empty `Database.URL` (`postgres`) → **`memory`**. `:732-767`
implements database-URL precedence plus explicit backend validation and refusal conditions;
`:770-808` implements pool controls. The **memory** backend is process-local and demo-only: held
deliveries and inboxes are **lost on restart** (`config.go:550-551`), so custody is not durable
under it. How an operator proves *which* backend is actually serving custody (readback of the
resolved backend at boot) is not yet written (a named RED on §5).

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-02 | scheduler | in | `<scheduler>/internal/bus/dispatch.go:175` `payload()` (the function is declared at `:175`; `:202` is the `p["text_b64"] = …` assignment inside it — envelope with `text_b64`, `board`) | `internal/registry/handler.go:990` `HandleDeliver` | **works (transport)** — crier delivers the envelope verbatim. The former `text_b64` vs `text` mismatch was a **node-consumption** defect, now fixed (the node decodes `text_b64` at `node-bus-worker.py:989`; CF-354 complete), so the scheduler→crier→node leg is now works end-to-end |
| CT-03 | node | out | `internal/registry/handler.go:1690` `HandleRetrieve` (lease-granting side; the client library `crier_client.py:1009` is the consumer-side call) | `scripts/node-bus-worker.py:1007` `process` (the node's inbox consumer; decodes `text_b64` via `directive_text` `:977`) | works — lease/transport works, and the consumption field-mismatch (CF-354) is fixed |
| CT-04 | node | in | **node's own HTTP deliver** — `node-bus-worker.py:1208` `deliver` (urllib, **not** `crier_client.py`; POST `/agents/{target}/inbox`) | `internal/registry/handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport)** — crier accepts the reply verbatim. CF-355 is **this reply's** settlement defect: the node sends `status` (`node-bus-worker.py:1180`), the scheduler's `dispatchReplyVerdict` reads only `ok` — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-08 | gateway | out | crier `internal/registry/dispatch.go:369` `h.hermes.Deliver` (session delivery), implemented by `internal/hermesession/hermesession.go:353` `Client.Deliver` (token acquisition, session selection, chat execution, replay) — **in-repo** | **external** — the Hermes gateway (out of scope) | **works (crier side named)** — the producer is in-repo and named; only the gateway consumer is out of scope |

CT-08 is a boundary contract: the Hermes gateway is outside the five covered systems, so
"one side named + the other marked external" is the honest terminal state, not a chapter defect.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (crier repo) | exit 0 | 2026-11-07, rev `a9044518` (re-run this round) | **PASS** (rc 0) |
| go test | `go test -count=1 ./...` | green | 2026-11-07, rev `a9044518` (re-run this round) | **PASS** (rc 0) — clean run: all packages `ok` except the `[no test files]` set (41 ok / 3 no-test-files per the round-18 census, re-confirmed clean at this HEAD) |
| port fact | `grep -n 'Port' config/config.go` | 8767 | 2026-11-07 | PASS (`:622`) |
| slog surface | `grep -cE 'slog\.(Info\|Error\|Warn\|Debug)' internal/registry/handler.go` | 3 | 2026-11-07 | **PASS** — exactly 3 sites (all in §9); no `log.Printf`/`fmt.Printf` in the handler. The round-16 row quoted a BRE (`grep -c 'slog.(Info\|Error\|Warn\|Debug)'`) which returns **0** (rc 1) because `(`/`|` are literal in BRE — the `-E` form above is the reproducing command (grok #1) |
| signed-read ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox 200 with key+bearer | 2026-11-05, cf-node only | PASS (FACT-04) — **not repeatable from this control host** (a named RED on §7) |

**`go test` re-measured at live HEAD.** Round-11 documented `go test ./...` as FLAKY at `86c4c469`
— two named tests failing on different runs, the latter with an odd-hour-volume alert assertion.
Commit `eb21ca03` (idle-boot detect-alert assertion made order-insensitive) landed after that stamp
and removes the order-sensitive assertion (QA-CRIER-56: `CR_DETECT_QUIET_HOURS` 01:00–05:00 UTC
window contamination). The FLAKY row is **superseded**; this round's single `go test -count=1 ./...`
at `a9044518` is a clean PASS (all `ok` except the no-test-files set, rc 0).

## 8. Metrics

**Measured — real, not RED (default-ON).** Crier implements a Prometheus text-exposition registry
(`internal/metrics/metrics.go`) mounted at `/metrics` by default (`config.go:673`;
`observability.go:101-109`). The command `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u` returns **67** unique
strings; that count mixes runtime series, histogram `_bucket/_sum/_count` exposition components,
and the test-only `crier_test_*` family — a grep census, not a metric contract. The runtime series
(with their emitter lines) are:

- **Guard** (`internal/guard/metrics.go:22-49`): `crier_guard_saturated_total` (`:22`),
  `crier_guard_all_providers_failed_total` (`:28`), `crier_guard_check_duration_seconds{decision,errored}`
  (`:44-49`, a histogram with closed label enums `decision ∈ {allow,block,sanitize}` and
  `errored ∈ {true,false}`, seeded at 0).
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

**Saturation counter semantics (sol B23, corrected).** `crier_guard_saturated_total` is
incremented at `internal/guard/router.go:230-234` when the check-concurrency semaphore's 2s acquire
budget expires, immediately before the router returns `ErrConcurrencySaturated` (MON-CRIER-003) —
it counts **saturation errors**, not delivered fail-open messages. The downstream disposition of a
saturation error (block / sanitize / allow) is decided later by `errorResult`
(`guard.go:318-361`, via `:250-252` routing) against the policy's `FailClosed`/`Action`. The
counter and the final admission outcome are therefore two different facts: the counter says the
guard was saturated; the decision/error observations say what happened to the message.

**Per-metric contract (filled this round, closing sol B04/B21/B23).** The series above are emitted
as Prometheus text exposition over `GET /metrics` (default-ON, `config.go:673`; mounted
`observability.go:101-109`; Bearer-gated when `CR_AUTH_TOKEN` is set). The 34-string
`grep -rhoE 'New(Counter|Gauge|Histogram…)…'` census mixes runtime series with `_bucket/_sum/_count`
exposition components, `crier_test_*` test-only series, and `example_*`/`dup_*`/`busy_*` fixtures
(the latter are not runtime). The runtime series, with type/labels/question/scrape:

| Metric | Type | Labels | Question answered | Scrape |
|---|---|---|---|---|
| `crier_guard_saturated_total` | Counter | — | guard checks rejected by concurrency saturation (MON-CRIER-003) | `/metrics` (`guard/metrics.go:22`) |
| `crier_guard_all_providers_failed_total` | Counter | — | checks whose whole provider fallback chain failed | `/metrics` (`guard/metrics.go:28`) |
| `crier_guard_check_duration_seconds` | HistogramVec | `decision{allow,block,sanitize}`, `errored{true,false}` (closed enums, seeded 0) | guard check latency, by verdict and fail-open | `/metrics` (`guard/metrics.go:44-49`) |
| `crier_delivery_accepted_total` | Counter | — | inbox deliveries accepted (stored or webhook-pushed) | `/metrics` (`handler.go:38`) |
| `crier_guard_decisions_total` | CounterVec | `decision{allow,block,sanitize}` | guard verdicts at the choke point (DF-CRIER-142) | `/metrics` (`handler.go:42`) |
| `crier_inbox_*` (queue_depth, queue_leased, queue_oldest_age_seconds, deliver_duration, expired_total, shed_total, transfers_total, deadlettered_total, expiry_receipts_total) | Counter / Gauge / Histogram | `shed_total` by reason | inbox occupancy, aging, expiry, shedding, dead-letters | `/metrics` (`handler.go:38-45`) |
| `crier_delivery_idempotent_replay_total` | Counter | — | redeliveries replayed from the idempotency record | `/metrics` (`handler.go:38-45`) |
| `crier_capability_routed_total` / `crier_capability_unheld_total` | Counter | — | `POST /capabilities/{capability}/inbox` resolved to a holder vs refused NO_CAPABLE_AGENT (§3 S1) | `/metrics` (`capability.go:99, :105`) |
| `crier_http_requests_total` / `crier_http_request_duration_seconds` | CounterVec / Histogram | `code`, `route` | HTTP surface request volume and latency by route | `/metrics` |
| `crier_webhook_attempts_total` / `crier_webhook_deliveries_total` | CounterVec | — | webhook push attempts and deliveries | `/metrics` |
| `crier_detect_alerts_total` | CounterVec | — | quiet-hour/volume detection alerts | `/metrics` |
| `crier_store_queue_depth_read_errors_total` | CounterVec | — | store queue-depth read failures | `/metrics` |
| `crier_federation_*` / `crier_relay_events_total` | Counter | — | federated relay and event volume | `/metrics` |
| `crier_ws_subscribers` | Gauge | — | live websocket subscriber count | `/metrics` |
| `crier_up` / `crier_build_info` / `crier_start_time_seconds` | Gauge | — | liveness, build identity, process start | `/metrics` |

Auth posture: `/metrics` is not exempt — it requires Bearer when `CR_AUTH_TOKEN` is set.

## 9. Log lines (verbatim)

The handler's operator-visible surface uses `slog` (not `log.Printf`). **The handler's slog surface
is exactly 3 sites, all captured** (measured: `grep -cE 'slog\.(Info|Error|Warn|Debug)'
internal/registry/handler.go` = 3; 0 `log.Printf`/`fmt.Printf`):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| info | `inbox deliver replayed` (`handler.go:1332`, `slog.Info`) | a redelivery replays a recorded deliver | evidentiary |
| error | `registry stats after retrieve` (`handler.go:1795`, `slog.Error`) | stats read after retrieve fails | descriptive |
| error | `registry store error` (`handler.go:1885`, `slog.Error`) | store write fails | descriptive |

**Guard log surface (sol B22, corrected this round — three message forms, not two).** The guard
emits through the `logf`/`logfWarn` wrappers (`guard.go:100` `slog.Info`, `:103` `slog.Warn`), and
its operator-visible messages are:

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| warn | `guard sanitize rewrite unavailable` (`guard.go:306-307`, `logfWarn`) — carries `msg, fallback=quarantine_notice, err` | the sanitize-rewrite fallback fails, degrading the message to a quarantine notice (DF-CRIER-147) | descriptive |
| info / warn | `guard` (`guard.go:452` `logfWarn` when `Decision != Allow` or errored, `:454` `logf` otherwise) — carries `msg, target, policy, chan, kind, decision, risk, request_id, provider, model, patterns, errored, quarantined, sanitized, reason, ms, payload_bytes` (`:431-450`) | a guard verdict is rendered by `audit` (`:430`) | evidentiary |
| warn | `guard blocked` (`guard.go:457`, `logfWarn`) — only when `Decision==Block`, with an extra `event=guard_blocked` attribute | the router blocked the directive | evidentiary |

The round-16 "two sites" claim was false: `audit` (`:430`) is not the only logging site — the
sanitize-rewrite failure at `:306` is a third message form the earlier census missed.

**Module-wide inventory (RED).** The six rows above cover the handler (3) and the guard (3); the
webhook/store/detect/federation emitters' operator-visible lines are not yet tabulated one-per-site
(a named RED on this field).

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Unsigned read | 401 | a wrong bearer | by design — order is headers → target lookup → caller==target → timestamp → key → signature (`agentsig.go:167-263`); an unknown target 404s at `:204` |
| Mismatched envelope version | old node silently accepts a new control host | a versioned refusal | **OPEN** — CF-369 |
| Client library undocumented | `crier_client.py` + typescript consume a versioned contract with no page | a documented client | **OPEN** — OUTLINE M10.S4 |
| Signature enforcement off | `requireAgentSig` false → reads pass unsigned | a signed-only bus | re-enable `RequireAgentSig` (`config.go:629`; conditional at `agentsig.go:364-368`) |
| **Oversized payload** | guard skips the LLM and branches on deterministic evidence (`guard.go:198-234`): high-confidence prematch → Block; low-confidence → Allow (errored); none → Allow "oversize" (errored) | a normal LLM verdict | automatic — the deterministic pre-scan result is always carried on `Result.Patterns` |
| **Guard error (provider outage)** | `errorResult` (`guard.go:318-361`) defaults to **fail-open** (Allow, errored) unless `policy.FailClosed`, which applies `errorAction(policy.Action)` (default block); a high-confidence prematch escalates even a fail-open to block/high | a clean verdict | set `FailClosed` on the policy to fail closed |
| **Guard concurrency saturation** | `ErrConcurrencySaturated` after the 2s semaphore acquire (`router.go:230-234`); counted by `crier_guard_saturated_total` | a provider outage | the disposition follows `errorResult` per policy — check the decision/error observations, not just the saturation counter |
| Empty retrieve ≠ lost message | `[]` after a failed ack while a message is leased | a lost message | use `stats()` to tell "nothing queued" from "everything leased" (`crier_client.py:1018-1021`) |
| Capability addressed to a protected recipient | 403 `service delivery requires an explicit recipient URL; capability routing cannot authorize a service recipient` (`service_auth.go:117-126`) | a `NO_CAPABLE_AGENT` refusal (counted `crier_capability_unheld_total`, no holder advertises the capability) | deliver to an explicit recipient URL instead — capability routing cannot resolve a protected service recipient |

## 11. Limits and margins

- Signature enforcement is **conditional** on `h.requireAgentSig` (`agentsig.go:364-368`).
- A held (leased) message is not returned again until its lease expires (`crier_client.py:1018-1021`).
- Delivery idempotency has distinct replay and busy branches (`handler.go:1307-1365`).
- **Guard policy precedence.** `internal/guard/policy.go:172-202` `ResolvePolicy`: first agent policy
  whose `channel_match` glob matches the session/thread key, then `serverDefault`
  (`CR_GUARD_DEFAULT_POLICY`), then `BuiltinDefaultPolicy()`. A channel-glob-only policy never
  matches an unchanneled message.
- The `:18767` federation surface named in OUTLINE M10.S3 appears in `AGENTS.md:173` (federation
  demo `:18767`/`:18877`) but its live listener status is unmeasured this round.

## 12. Cross-references

- M9 SCHEDULER is the producer (CT-02) and the settlement consumer of the node reply (CT-04) and the dispatcher completion (CT-06).
- M2 DISPATCH (node) and M11 DISPATCHER are the two inbox consumers; only M11 imports `crier_client`.
- M0 SHARED CONTRACT's `bunker_exec` is *not* a crier contract (F0-1).

## 13. Evidence of record

- Code read: `internal/registry/agentsig.go:160-279, 355-369`; `internal/registry/handler.go`
  (funcs + slog surface + custody `:1728-1775`); `internal/guard/guard.go:1-90, 195-235, 300-310, 315-362, 428-460`;
  `internal/guard/router.go:225-240`; `internal/guard/policy.go:170-205`; `internal/guard/metrics.go:19-49`;
  `config/config.go:621-700, 1010-1014, 1139-1187`; `internal/registry/service_auth.go:44-99`;
  `clients/python/crier_client.py:840-855, 960-1036`; `clients/typescript/crier.ts:560-625`;
  `cmd/crier-front/main.go:39`; `cmd/crier-mcp/main.go` (bridge mode, `:120, :173-219`);
  `cmd/server/observability.go:95-115`; `internal/metrics/metrics.go:1-8`; `deploy/crier.service`, `deploy/crier.user.service`, `deploy/crier-backup.service`, `deploy/crier-backup.timer`.
- Commands run: `go build ./...` (PASS, re-run this round); `go test -count=1 ./...` (PASS at `a9044518`, rc 0 — clean run, all `ok` except the no-test-files set);
  `ls cmd/` (crier-front, crier-mcp, server); `ls deploy/` (4 units + 1 scrape example);
  `grep -cE 'slog\.(Info|Error|Warn|Debug)' internal/registry/handler.go` (3);
  `grep -nE 'slog\.(Info|Error|Warn|Debug)' internal/guard/guard.go` (wrappers at `:100/:103`);
  `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u | wc -l` (67);
  `git diff --name-only 0a372209..HEAD` (6 paths, two `cmd/server` test files).
- Rev re-stamped: `a9044518` (this round); crier HEAD advanced three test/qa-only commits past `e50e55ee`
  (`1587a03f`, `a4efefbb`, `a9044518`); cited non-test files byte-identical to `33c1f388` (verified by a `git diff --name-only
  33c1f388..HEAD -- <cited paths>` returning empty this round).
- Board rows: CF-337, CF-361, CF-369.
- **Findings:**
  - **F10-1** (carried) — auth order is headers → target → caller → timestamp → key → signature.
  - **F10-2** (corrected again, kimi #3) — round-17 claimed "host go is 1.26.10"; the host bootstrap
    binaries are actually 1.26.8 (`/usr/bin/go`) and 1.26.5 (`~/.local/bin/go`), and go1.26.10 is
    selected at build time by `go.mod`'s `go 1.26.10` directive via `GOTOOLCHAIN=auto`; `go build`/`go test` PASS.
  - **F10-3** — metrics are default-ON (`EnableMetrics: true`), not opt-in; `metrics.go:2` still
    says "opt-in" (contradicting artifact, locator `:2`).
  - **F10-4** (carried) — guard degradation policy written: oversize branch (`:198-234`) and
    fail-open/fail-closed `errorResult` (`:318-361`) with policy precedence (`policy.go:172-202`).
  - **F10-5** (closed this round) — the 67-string metric census is scoped; the **per-metric contract
    is now filled** (§8 table: type/labels/question/scrape for every runtime series).
  - **F10-6** (corrected, sol B01) — the protected-delivery header is `X-Crier-Audience`
    (`agentsig.go:35`), not `X-Crier-Service-Audience`; the node/dispatcher construct requests
    without the full protected-delivery control set, so "works" is scoped to un-protected recipients.
  - **F10-7** (new, sol B22) — the guard has three log message forms (`guard`, `guard blocked`,
    `guard sanitize rewrite unavailable` at `:306`), not two.
  - **F10-8** (new, sol B23) — `crier_guard_saturated_total` counts saturation errors
    (`router.go:230-234`), not delivered fail-open messages.
  - **F10-9** (new, grok #2) — S3 now names `crier-mcp` (MCP stdio bridge) and the four `deploy/`
    units; the front/MCP production invokers are not in `deploy/` (activation UNVERIFIED for those two).
  - **F10-10** (new, sol B21) — `CR_SERVICE_DELIVERY_ALLOWLIST`/`CR_SERVICE_DELIVERY_AUDIENCE`/
    `CR_AUTH_TOKEN` now registered in §5.
  - **F10-11** (new, kimi B6/grok #8) — the closed-world `git diff` claim is withdrawn: HEAD
    advanced and two `cmd/server` test files changed after the round-16 stamps; the diff is quoted
    with the real six paths and dated.
  - **F10-12** (updated this round, was kimi #9/deepseek N1) — crier HEAD advanced three test/qa-only
    commits to `a9044518` (`1587a03f` INT-CI-027, `a4efefbb` CRIER-HARNESS-7, `a9044518` qa battery
    record); every cited non-test file is byte-identical to `33c1f388` (verified `git diff --name-only
    33c1f388..HEAD -- <cited paths>` → empty this round). §1/§7/§13 re-stamped.
  - **F10-16** (new, this round) — a live crier foreman is active on the repo, so HEAD moves during
    the round; the re-stamp at `a9044518` is the tip as measured this round, and the load-bearing
    claim is the cited non-test files' byte-identity to `33c1f388` (re-verified empty), not the tip.
  - **F10-13** (new, grok #5) — the capability delivery route (`HandleDeliverByCapability`,
    `handler.go:1014`, `POST /capabilities/{capability}/inbox` at `cmd/server/main.go:112`) and its
    protected-recipient refusal (`service_auth.go:117-126`) are now documented in §3 S1 and §10;
    the §8 `crier_capability_*` counters are cross-referenced to the route that emits them.
  - **F10-14** (new, kimi #8) — the guard env-bounds citation now names the field definitions
    (`internal/guard/guard.go:49-55`) alongside the reader/validator (`config/config.go:1139-1187`);
    round-17 cited only the reader.
  - **F10-15** (new, sol B23) — the run-affecting controls missing from §5 are now registered: MCP
    nudge (`CR_MCP_NUDGE_*`, default nudge ON / session-start OFF, `config.go:634, :697-709`),
    federation hold (`CR_FED_MAX_HOLD_S` = 300s, `:657, :971-974`), and DB pool
    (`CR_DATABASE_MAX_CONNS`/`MIN_CONNS` = 4/0 with the `MinConns > MaxConns` startup refusal,
    `:660-665, :771-786`).

## RED field count: 4 — §9 log inventory incomplete beyond the six tabulated handler/guard
sites (the webhook/store/detect/federation emitters are not tabulated one-per-site); §5
storage-selection custody-proof not written (how an operator proves *which* backend is serving
custody at boot is unmeasured); §7 signed-read ladder not repeatable from this control host
(UNVERIFIED); §3 S4 TypeScript client + S3 front/MCP production activation not evidenced (no
in-repo/systemd invoker named — sol B27). **Closed this round: §8 per-metric contract** (filled,
sol B04/B21/B23) and the §5 run-affecting-controls gap (MCP nudge, federation hold, DB pool now
registered, sol B23). The former "go test FLAKY" and "handler body not read" REDs were already
closed at round 17 (clean PASS at `e50e55ee`; body read line-by-line).

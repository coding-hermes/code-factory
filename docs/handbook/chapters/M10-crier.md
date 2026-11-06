# M10 — CRIER

## 1. Identity

| Field | Value |
|---|---|
| Module name | CRIER |
| Path | `/home/kara/crier/` (Go) |
| Revision | `691f0c78fc75717295abf3bd85aaa9192616aac0` (crier repo HEAD, stamped this round) |
| Language / runtime | Go — `go.mod` declares `go 1.26.10` (a build/toolchain requirement, not a runtime one); host `go version` = **go1.26.5** (default PATH), `/usr/bin/go` = 1.26.8, `/snap/bin/go` = 1.27.1; `GOTOOLCHAIN=auto` auto-fetches 1.26.10 for this repo |
| Owner lane | crier (control plane) |
| Status | **UNVERIFIED** — `internal/registry/handler.go` (deliver/retrieve/ack surfaces + the full 3-site slog surface), `internal/guard/guard.go` (pipeline, oversize branch, `errorResult`), `internal/guard/policy.go` (`ResolvePolicy`), `internal/guard/metrics.go`, `config/config.go` (controls + guard bounds + metrics default), `clients/python/crier_client.py`, `cmd/crier-front/main.go` read this round; the full 1895-line handler body still not read line-by-line (its slog surface *is* complete — see §9) |

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
| S1 custody and transport | `internal/registry/handler.go` (1895 lines) | **active** | `HandleRegister` (`:598`), `HandleDeliver` (`:990`), `HandleRetrieve` (`:1690`), `HandleAck` (`:1812`) |
| S2 the guard | `internal/guard/guard.go` | **active** | `Guard.Check` (`:167`) is the choke point; pipeline documented at `:25-28`; oversize branch `:198-234`; `errorResult` `:318-361` |
| S3 binaries, ports, services | `config.go:622` port 8767; `crier-front/main.go:39` listen `127.0.0.1:8770` | **active** | read |
| S4 client libraries | `clients/python/crier_client.py`, `clients/typescript` | **active** | Python client read (`deliver` `:975`, `retrieve` `:1009`, `ack` `:1038`) |

**Custody lifecycle (B20, written this round).** The wire contract of a retrieve, derived from the
handler and the Python client:

- **Parameter aliases and precedence** (`handler.go:1711-1743`): the spec'd `limit`/`lease_seconds`
  alias the historical `max`/`lease`. When both spellings appear in one request, the historical
  `max`/`lease` **wins** — the alias fills in only what the historical name left absent
  (DF-CRIER-180).
- **Defaults and bounds**: default batch **10** messages, capped at **100** (a `max > 100` returns
  400 `max must be <= 100`, `:1727-1730`); default lease **30 s** (`:1732-1743`).
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
bounds. Individual rows (B21, expanded this round):

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
| `Guard.Enabled` | true (`:644`) | bool | guard on/off | off lets untrusted directives through |
| `Guard.Timeout` | 10 s (`:645`) | duration | per-check LLM timeout | too short fails checks open |
| `Guard.MaxConcurrent` | 8 (`:646`) | int | check concurrency semaphore | 0 or overflow saturates the guard |
| `Guard.CircuitThreshold` | 10 (`:647`) | int | guard circuit threshold | lower opens the guard circuit sooner |
| `Guard.CircuitCooldown` | 300 s (`:648`) | duration | circuit reopen cooldown | too short thrashes the circuit |
| `Guard.MaxPayloadBytes` | 65536 (`:649`) | bytes | payload ceiling before the router | a raise admits a bigger untrusted payload |
| `Guard.RenderMaxBytes` | 32768 (`:650`) | bytes | render ceiling | a raise sends more to the router |
| `Guard.DeepSeekBaseURL` / `Guard.Model` | `https://api.deepseek.com/v1` / `deepseek-v4-flash` (`:651-652`) | a URL / model | the guard's router | a change re-routes the guard verdicts |
| `Guard.KanbanQueueSize` | 100 (`:653`) | int | guard queue depth | smaller drops queued checks |
| `Observability.EnableMetrics` | **true** (`:673`) | bool | `/metrics` mount | `CR_ENABLE_METRICS=false` disables it |
| front `defaultListen` | `127.0.0.1:8770` (`crier-front/main.go:39`) | a loopback listen | the front's surface | binding off-loopback exposes the front |
| `CR_GUARD_TIMEOUT_MS` / `CR_GUARD_MAX_CONCURRENT` / `CR_GUARD_CIRCUIT_THRESHOLD` / `CR_GUARD_CIRCUIT_COOLDOWN_S` / `CR_GUARD_MAX_PAYLOAD_BYTES` / `CR_GUARD_RENDER_MAX_BYTES` | env, positive only (`config.go:1139-1187`) | int > 0 | guard tuning | a non-numeric or `<= 0` value → named error (`invalid CR_GUARD_…`), not a silent default |

**Metrics-default correction (F10-3).** `config.go:667-673` sets `EnableMetrics: true` by default;
`CR_ENABLE_METRICS` is the disabling override; `cmd/server/observability.go:101-109` mounts
`/metrics`. Metrics are default-ON, not opt-in. **Contradicting artifact (N4, locator re-pinned):**
`internal/metrics/metrics.go:2` still calls the surface "the opt-in GET /metrics surface" — the
comment (line **2**, not 5) disagrees with the default-ON config.

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M10-C1 | scheduler | in | `<scheduler>/internal/bus/dispatch.go:202` `payload()` (envelope with `text_b64`, `board`) | `handler.go:990` `HandleDeliver` | **works (transport)** — crier delivers the envelope verbatim; the `text_b64` vs `text` mismatch is a **node-consumption** defect (`node-bus-worker.py:986` reads `text`), carried at M2-C1/M9-C2, not a crier defect. Round-4's "broken (CF-354)" mis-scoped the break (kimi B55). **This supersedes OUTLINE Part IV's "scheduler → crier … broken" and README I.3's "10 works / 6 broken / 2 missing"** — the register-of-record re-scope is applied in the README this round (glm #2) |
| M10-C2 | node | out | `handler.go:1690` `HandleRetrieve` (lease); client side `crier_client.py:1009` `retrieve` | `scripts/node-bus-worker.py:972` `process` (the node's inbox consumer; reads `text` at `:986`) | works |
| M10-C3 | node | in | **node's own HTTP deliver** — `node-bus-worker.py:1160` `deliver` (urllib, **not** `crier_client.py`) | `<scheduler>/internal/scheduler/dispatch_leg.go:713` `dispatchReplyVerdict` | **broken** — CF-355 (scheduler reads `ok`; node sends `status`) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| build | `go build ./...` (crier repo) | exit 0 | 2026-11-06, rev `691f0c78` | **PASS** (rc 0) |
| go test | `go test ./...` | green | 2026-11-06, rev `691f0c78` | **PASS** (rc 0); `internal/registry` ran 6.962 s over **91 test files** |
| port fact | `grep -n 'Port' config/config.go` | 8767 | 2026-11-06 | PASS (`:622`) |
| slog surface | `grep -c 'slog.\(Info\|Error\|Warn\|Debug\)' internal/registry/handler.go` | 3 | 2026-11-06 | **PASS** — exactly 3 sites (all in §9); no `log.Printf`/`fmt.Printf` in the handler |
| signed-read ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox 200 with key+bearer | 2026-11-05, cf-node only | PASS (FACT-04) — not repeatable from this control host |

**Assurance-gap note (kimi 6, re-measured).** Round-3 reported `internal/registry` as "no tests to
run". At the same revision the package has **91 test files** (measured: `ls internal/registry/*_test.go`),
and `go test` ran them in 6.962 s. A green run over 91 test files is real, but it still does not
prove line-by-line coverage of the 1895-line handler.

## 8. Metrics

**Measured — real, not RED (default-ON).** Crier implements a Prometheus text-exposition registry
(`internal/metrics/metrics.go`) mounted at `/metrics` by default (`config.go:673`;
`observability.go:101-109`). **Inventory scope (grok #7, corrected this round):** the command
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
internal/registry/handler.go` = 3; 0 `log.Printf`/`fmt.Printf`). The round-5 "non-exhaustive" hedge
is **withdrawn** with this measured count (deepseek #3):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| info | `inbox deliver replayed` (`handler.go:1332`, `slog.Info`) | a redelivery replays a recorded deliver | evidentiary |
| error | `registry stats after retrieve` (`handler.go:1795`, `slog.Error`) | stats read after retrieve fails | descriptive |
| error | `registry store error` (`handler.go:1885`, `slog.Error`) | store write fails | descriptive |
| info | `observability: metrics enabled` (`observability.go:108`, `slog.Info`) | boot with metrics on (emitter is in `cmd/server/`, not the handler) | evidentiary |

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

## 11. Limits and margins

- Signature enforcement is **conditional** on `h.requireAgentSig` (`agentsig.go:364-368`).
- A held (leased) message is not returned again until its lease expires (`crier_client.py:1018-1021`).
- Delivery idempotency has distinct replay and busy branches (`handler.go:1307-1365`).
- **Guard policy precedence (B21).** `policy.go:172-202` `ResolvePolicy`: first agent policy whose
  `channel_match` glob matches the session/thread key, then `serverDefault`
  (`CR_GUARD_DEFAULT_POLICY`), then `BuiltinDefaultPolicy()`. A channel-glob-only policy never
  matches an unchanneled message.
- The `:18767` federation surface named in OUTLINE M10.S3 appears in `AGENTS.md:173` (federation
  demo `:18767`/`:18877`) but its live listener status is unmeasured this round.

## 12. Cross-references

- M9 SCHEDULER is the producer (M10-C1) and the settlement consumer (M10-C3).
- M2 DISPATCH (node) and M11 DISPATCHER are the two inbox consumers; only M11 imports `crier_client`.
- M0 SHARED CONTRACT's `bunker_exec` is *not* a crier contract (F0-1).

## 13. Evidence of record

- Code read: `internal/registry/agentsig.go:160-279, 355-369`; `internal/registry/handler.go`
  (funcs + slog surface + custody `:1711-1775`); `internal/guard/guard.go:1-90, 195-235, 315-362`;
  `internal/guard/policy.go:170-205`; `internal/guard/metrics.go:19-49`; `config/config.go:621-700, 1139-1187`;
  `clients/python/crier_client.py:960-1036`; `cmd/crier-front/main.go:39`;
  `cmd/server/observability.go:95-115, 160-175`; `internal/metrics/metrics.go:1-8`.
- Commands run: `go build ./...` (PASS); `go test ./...` (PASS); `ls internal/registry/*_test.go` (91);
  `grep -c 'slog.(Info|Error|Warn|Debug)' internal/registry/handler.go` (3);
  `grep -rhoE 'crier_[a-z_]+' internal/ cmd/ --include='*.go' | sort -u | wc -l` (67).
- Rev stamped: `691f0c78`.
- Board rows: CF-337, CF-361, CF-369.
- **Findings:**
  - **F10-1** (carried) — auth order is headers → target → caller → timestamp → key → signature.
  - **F10-2** (corrected) — host go is 1.26.5; `GOTOOLCHAIN=auto` fetches 1.26.10 and build/test PASS.
  - **F10-3** — metrics are default-ON (`EnableMetrics: true`), not opt-in; `metrics.go:2` still
    says "opt-in" (contradicting artifact, locator re-pinned from `:5` to `:2`).
  - **F10-4** (carried) — guard degradation policy written: oversize branch (`:198-234`) and fail-open/
    fail-closed `errorResult` (`:318-361`) with policy precedence (`policy.go:172-202`).
  - **F10-5** (new) — the handler's slog surface is complete (3/3, §9); the 67-string metric census
    is scoped (runtime vs test helpers vs exposition components), not a completed per-metric register.

## RED field count: 2 (S1 handler 1895-line body not read line-by-line — the slog surface is complete but the body's non-slog semantics are not; §8 metric contract — series names inventoried but the per-metric type/labels/question/scrape table not filled)

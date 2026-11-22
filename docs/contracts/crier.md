# crier — message relay / bus (contract page)

## Role

The fleet message relay: agent registry, durable per-agent inboxes, delivery with guard and
idempotency. The bus this repo's nodes poll for dispatches and post results to
(`docs/REPOSITORIES.md`, `crier` row).

## Routes or commands

Registry + inbox routes (`cmd/server/main.go:137-152`, `registerRegistryRoutes`):
`POST /agents`, `POST /agents/{id}`, `GET /agents[/{id}]`, `DELETE /agents/{id}`,
`PATCH /agents/{id}`, `POST /agents/{id}/inbox` (deliver), `GET /agents/{id}/inbox`
(retrieve; query `limit`, `lease_seconds`, `wait_seconds` — `internal/registry/handler.go:1864-1944`),
`POST /agents/{id}/inbox/ack`, `GET /agents/{id}/inbox/stats`,
`POST /agents/{id}/inbox/{transfer,dead-letters}`, `POST /capabilities/{capability}/inbox`,
`GET /namespaces`. Plus `GET /health` (:429), `GET /version` (:439), `openapi.json|yaml`,
`/docs` (:459-461). Delivery params: `timeout_ms` default 30000, range `0..120000`
(`internal/registry/handler.go:103-104, 207-212, 248`); unknown `delivery_mode` is a named 400
(DF-CRIER-180, `handler.go:216-248`).

## Auth

- Deployment bearer `CR_AUTH_TOKEN` on non-exempt paths (`internal/middleware/auth.go:170-200`):
  missing header ⇒ `401 {"error":"missing Authorization header"}` (:175); non-Bearer scheme ⇒
  `401 {"error":"authorization scheme must be Bearer"}` (:179-180). A small exempt set incl.
  `/health` and `/version` (`cmd/server/main.go:445-459`). Management surface takes a second
  secret, `CR_PERMISSIONS_ADMIN_TOKEN` (`middleware/auth.go:95-130`).
- Per-agent ed25519 signature (`internal/registry/agentsig.go:21-34`): `X-Agent-ID`,
  `X-Agent-Ts` (unix seconds, ±30 s window — `agentsig.go:41`), `X-Agent-Sig` (hex ed25519 over
  `"<METHOD>\n<path>\n<ts>"`), optional `X-Agent-Body-SHA256` body binding which extends the
  transcript to a 4-line form. Required when `CR_REQUIRE_AGENT_SIG` is on (the default).
- Credential sources here: bearer from the node's `crier.token` file, signing key from
  `$HOME/.node/agent.key` (PKCS#8 PEM) — `scripts/node-bus-worker.py:13-27, 441-449`.

## The reply ladder (protected service delivery)

`internal/registry/service_auth.go:163-260` (`authorizeServiceDelivery`) requires, in order:

1. **sender** — body `sender` must equal the signed `X-Agent-ID`
   (403 `service delivery body sender must equal signed X-Agent-ID`, :216-219).
2. **idempotency_key** — nonempty required
   (400 `protected service delivery requires nonempty idempotency_key`, :220-223).
3. **audience** — `X-Crier-Audience` header (`agentsig.go:35`) must equal the configured
   `CR_SERVICE_DELIVERY_AUDIENCE` (401 `service delivery audience missing or mismatched`,
   :224-228); when present it also extends the signature transcript with
   `"\naudience:<audience>"` (`agentsig.go:290-293`).
4. **signature** — `verifyAgentSignature(w, r, sender, true)`: this path REQUIRES the 4-line
   (body-bound) transcript form (:199-202).
5. Allowlist: exact `sender>recipient` pair from `CR_SERVICE_DELIVERY_ALLOWLIST`
   (:111-135); unlisted pair ⇒ 403 `service delivery sender>recipient pair is not allowlisted`
   (:229-237). A nonempty allowlist without an audience refuses to arm (`:148-153`).

## Failure codes

- `400` invalid json (`handler.go:1357-1360`); missing/null/non-object `payload`
  (`validateDeliverPayload`, `handler.go:317`, called at :1371); negative/over-limit
  `ttl_seconds` (`internal/registry/delivery_validation.go:8-17`); parameter validation 400s
  naming the bound (`timeout_ms must be 0..120000`, DF-CRIER-180).
- `401` bearer refusals (above) and audience mismatch (:224-228).
- `403` `GUARD_BLOCKED` — prompt-injection guard pre-match, patterns `control_keys`
  (`"(system|instructions|prompt|tools|schema)"\s*:`) and `stringified_json`
  (`internal/guard/patterns.go:45-47`; blocked deliveries never queue/store,
  `handler.go:1181`); `DELIVERY_FORBIDDEN`/`NO_BINDING` (:147); `UNKNOWN_NAMESPACE` (:75);
  `AGENT_QUARANTINED` (:1486); body `sender` ≠ signed id (:216-219, :1342-1345).
- `409` agent id already registered under a key (:671); `a delivery with this idempotency_key
  is already in progress` (:1565); service idempotency conflict (:245-249).
- Idempotency limits: dedup window 24 h default (`internal/registry/idempotency.go:55`,
  `DefaultIdempotencyWindow`), configurable via `CR_IDEMPOTENCY_WINDOW_S`
  (`config/config.go:1274-1281`, wired at `cmd/server/main.go:628`); key cap 128 chars
  (`idempotency.go:60`).

## Failure/contract source

- Reply ladder: `internal/registry/service_auth.go:163-260`.
- Signature scheme: `internal/registry/agentsig.go:21-41, 116-150`.
- Delivery validation + limits: `internal/registry/handler.go:317, 103-104, 207-248, 1371`.
- Idempotency: `internal/registry/idempotency.go:31-60`; `config/config.go:1274-1281`.
- Guard patterns: `internal/guard/patterns.go:45-47`.

## Code-factory dependents

- `scripts/node-bus-worker.py` — the bus worker. Call sites: `GET /health` (:821),
  `GET /agents/<id>/inbox/stats` (:852), `GET /agents/<id>` (:879), retrieve
  `GET /agents/<id>/inbox?limit=…&lease_seconds=…[&wait_seconds=…]` (:2000-2009), deliver
  `POST /agents/<reply_to>/inbox` (:1877-1895), ack `POST /agents/<id>/inbox/ack` (:1924-1935);
  signature headers minted at :441-449.
- `specs/ENVELOPE.md` — §The path home (payload/sender/idempotency_key delivery body),
  §Reserved field names (the `control_keys`/`stringified_json` guard).
- `scripts/bunker-crier-connect.sh` — puts a bunker agent on the bus; runs the worker's
  `--check` inside the agent (:62-64) and proves `/health` from the control host (:39-43).

## Measured against

`~/crier`, commit `c148cd6ca3984f6cdb28b62f7a09109118d9624d` (2026-11-22
07:13:29 -0500). Measured 2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.

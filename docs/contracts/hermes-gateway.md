# hermes-gateway — agent HTTP gateway (contract page)

## Role

The Hermes Agent's HTTP gateway: OpenAI-compatible agent endpoints (`/v1/chat/completions`,
`/v1/responses`) plus a session API, served by the agent process (`gateway/platforms/api_server.py:1-3`).

## Routes or commands

Route table `gateway/platforms/api_server.py:1554-1596` (`_http_route_table`; summary :64-81):
`GET /health`, `/health/detailed`, `/v1/health`, `/v1/models`, `/api/model/options`,
`/v1/capabilities`, `/v1/skills`, `/v1/toolsets`; sessions: `GET/POST /api/sessions` (create
:1565), `GET/PATCH/DELETE /api/sessions/{id}`, `/messages`, `/fork`, `/chat`,
`/chat/stream`, `/model` (lock); model calls: `POST /v1/chat/completions`,
`POST /v1/responses` (+ `GET/DELETE /v1/responses/{id}` — non-streaming persistence and
`previous_response_id` chaining live in `gateway/platforms/api_server_openai_routes.py:1-4, 125-131`);
platform events `POST /api/platforms/{platform}/events`; `CRUD /api/jobs`. `/api/status` is
served by the gateway host surface (`gateway/status.py:350`; readiness gate
`gateway/config_env.py:215`).

## Auth

`Authorization: Bearer <API_SERVER_KEY>` — `_check_auth`
(`gateway/platforms/api_server.py:1415-1445`): constant-time compare (`hmac.compare_digest`,
:1435-1437); failure ⇒ 401 `{"error":{"message":"Invalid gateway API key (API_SERVER_KEY)",
"type":"gateway_auth_error","code":"gateway_auth_failed"}}` (:1406-1412). The server refuses to
start without `API_SERVER_KEY` on the default listener, and the `/p/<profile>/` profile
prefixes fail closed without a profile-scoped key (:1390-1404, :1416-1420). Credential source
here: the gateway's own secret store — never a code-factory file; nodes protect a public bind
with `dashboard.basic_auth` in `~/.hermes/config.yaml`, which this repo produces and gates
(see dependents). Platform events authenticate with the adapter's own verifier, not
API_SERVER_KEY (:1584-1587).

## Failure codes

- `401` `gateway_auth_failed` (above, :1406-1412).
- `400` OpenAI validator envelope `{"error":{message, type: "invalid_request_error"}}`
  (:756-757); `missing_message` (:577); `invalid_content_length` (:674); `invalid_json` for
  platform events (:1488).
- `503` `gateway_draining` — draining, retry shortly (:1173); `platform_unavailable`
  (:1469); `platform_http_events_unsupported` (:1474).
- Quota/429 caps with valid credentials are cost errors, deliberately NOT labelled auth
  failures (:941).

## Failure/contract source

- Route table: `gateway/platforms/api_server.py:1554-1596`.
- Auth: `gateway/platforms/api_server.py:1390-1445`.
- `/v1/responses` handlers + persistence: `gateway/platforms/api_server_openai_routes.py:1-4, 125-131, 280-296`.

## Code-factory dependents

- `scripts/node_gateway_auth.py` — producer of the public-bind protection contract (CF-395):
  ensures a direct-child `dashboard.basic_auth` block in `~/.hermes/config.yaml`, with a
  fixed verdict vocabulary `present` / `block absent` / `block absent (invalid YAML)` /
  `block absent (config unreadable)` / `commented` / `empty value (username and password must
  both be non-empty)` (:62-67) and one four-rule indentation contract (:32-61).
- `scripts/harness/install-hermes.sh` — `check_public_bind_auth`, the consumer gate that
  authorises the public bind; named as the authority when the three readers disagree
  (`scripts/node_gateway_auth.py:53-59`).
- `scripts/node-bus-worker.py:960-970` — node readiness probes
  `GET http://127.0.0.1:<gateway port>/api/status` and requires 200.
- `specs/HARNESS-MATRIX.md:151-154` — the `CF_*` harness environment a gateway-hosted child runs with.

## Measured against

`~/.hermes/hermes-agent`, commit `3f87b28cd80351246f142f7738dcc508a5fd6d2e`
(2026-11-11 22:24:28 -0500); installed in-repo as an editable venv (package version `0.0.0`).
Measured 2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.

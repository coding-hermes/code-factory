# 9router — model proxy (contract page)

## Role

LLM provider router: one OpenAI/Anthropic-compatible proxy surface that routes chat,
embeddings and media requests to configured provider accounts, with per-model account pools
and key access control. The model lane the harness child on each node talks to.

## Routes or commands

Next.js API surface under `/api/v1/**` (`src/app/api/v1/`), default port 20128
(`src/shared/constants/config.js:32`, `appPort`): `POST /api/v1/chat/completions`
(`src/app/api/v1/chat/completions/route.js:23-27`, handler `src/sse/handlers/chat.js`),
`POST /api/v1/responses` (`src/app/api/v1/responses/route.js`), `POST /api/v1/messages`
(+ `/count_tokens`, Anthropic shape), `POST /api/v1/embeddings`, `GET /api/v1/models`,
`/api/v1/images/generations`, `/api/v1/audio/**`, `/api/v1/videos/**`, `/api/v1/search`,
`POST /api/v1/web/fetch`, plus `/api/health`.

## Auth

Client key extraction (`src/sse/services/auth.js:383-405`, `extractApiKey`): first
`Authorization: Bearer <key>`, else the Anthropic-style `x-api-key` header; on a federation
LINKED edge the end client's key rides `X-9r-Client-Authorization` while the hop authenticates
with its own federation token (:385-390). Provider credentials are NOT supplied by the caller —
accounts and their keys are stored server-side; the caller's key is the router's own access
key, checked per key-access policy (`src/sse/services/keyAccess.js`, imported at
`src/sse/handlers/chat.js:34`). Credential source here: `CF_API_KEY_FILE` — a mode-600 file
whose contents the harness sends as the bearer key (`specs/HARNESS-MATRIX.md:151-154`).

## Failure codes

- `404` `No active credentials for provider: <X>.` with a mandatory discovery pointer to
  `/v1/models` (`src/sse/handlers/chat.js:48-79`, `noCredentialsMessage`; import of
  `errorResponse`/`unavailableResponse` from `open-sse/utils/error.js` at :17).
- Upstream provider errors (429, 401, 5xx) lock the ACCOUNT per model, not the route
  (`src/sse/services/auth.js:272`).
- Errors surface in OpenAI-compatible shape via `errorResponse` /
  `unavailableResponse` (`open-sse/utils/error.js`).

## Failure/contract source

- Key extraction: `src/sse/services/auth.js:383-405`.
- Credential-absent 404 + discovery pointer: `src/sse/handlers/chat.js:48-79`.
- Per-model account locking: `src/sse/services/auth.js:272`.
- Port default: `src/shared/constants/config.js:32`.

## Code-factory dependents

- No script in this repo calls `:20128` directly. The dependency is the harness variable
  contract: `CF_MODEL`, `CF_PROVIDER`, `CF_BASE_URL` (endpoint the harness must talk to —
  node router/gateway/shim) and `CF_API_KEY_FILE` route every harness child's model calls
  through the router (`specs/HARNESS-MATRIX.md:151-154`; dispatch example
  `specs/ENVELOPE.md:16-24`).
- `scripts/configure_family.py:267, 418-424` — derives family/lane shape from the live
  scheduler DB's `crier`/`9router` family rows (a `:9090` query, not a router call); it
  refuses to invent a shape when those rows are absent.

## Measured against

`~/9router`, version `0.5.116` (`package.json:3`), commit
`414bb699707c92d486e79bfa47aed5eae0792a23` (2026-11-22 08:11:59 -0500). Measured 2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.

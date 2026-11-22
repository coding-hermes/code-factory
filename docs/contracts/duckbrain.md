# duckbrain — memory store (contract page)

## Role

Git-backed persistent memory: namespaces, keyed memory records, receipts, per-namespace
tables. The record store code-factory's harness memory check and sync lanes read and write.

## Routes or commands

Express HTTP server, default port 3000 (`src/cli/http.ts:134`, `:1458`; `--port` flag :1638).
Mounted surfaces (`src/cli/http.ts:884-945`): `/api/memories` (POST create; GET
`/api/memories/key/*key`; GET/PUT/DELETE `/api/memories/:id` — `src/http/routes/memories.ts:363,
608, 652, 837, 990`), `/api/keys` (GET `/`, GET `/flat` — `src/http/routes/keys.ts:44, 94`),
`/api/namespaces`, `/api/events`, `/api/compaction`, `/api/ops`, `/api/ns/:ns/tables`,
`/api/ns/:ns/s3`, `/api/reads`, `/api/receipts`, `GET /api/tree` → 301 to
`/api/keys?prefix=…` (:948-949), `GET /health` (:745).

## Auth

`x-api-key` request header against the configured API-key store
(`src/auth/middleware.ts:193-230`, `ApiKeyAuthBackend.authenticate`): missing header ⇒
`Unauthorized: API key required` (:203-204); unknown key ⇒ `Unauthorized: Invalid API key`
(:212-213); comparison is constant-time over the stored hash (`digestEquals`, :207-211);
expired keys refuse via `assertNotExpired` (:214). Presentation is 401
`{"error": "Authentication required"}` (:335); namespace/permission denials are 403 with
`{"error": …, "code": "FORBIDDEN"}` (:351-353, :382, :406). Credential source here: a mode-600
token file whose contents travel verbatim in `x-api-key`
(`scripts/harness/harness_memory.py:190-199`).

## Failure codes

Error envelope `{"error": …, "code": …}` (`src/http/middleware/errorHandler.ts`): `404
NOT_FOUND` (:100), `400 VALIDATION_ERROR` (:135), `400 INVALID_JSON` (:145), `500
INTERNAL_ERROR` (:153), `404 ROUTE_NOT_FOUND` (:170). Auth layer adds the 401/403 shapes above.

## Failure/contract source

- Auth: `src/auth/middleware.ts:193-230, 335-424`.
- Error vocabulary: `src/http/middleware/errorHandler.ts:100-170`.
- Route mounting: `src/cli/http.ts:884-949`; server/port defaults `src/cli/http.ts:134, 1458`.

## Code-factory dependents

- `scripts/harness/harness_memory.py` — `DuckBrainClient` (:187-225): `x-api-key` +
  `content-type: application/json` headers (:209), `POST /api/memories` (remember, :240),
  `GET /api/memories/key/<key>?namespace=<ns>` (read_exact, :249-255). A transport error
  raises `MemoryRecordError` and is never reported as a write (:185, :213-224).
- `scripts/node-bus-worker.py:1517` — the node's R1/R2 memory write/readback check goes
  through the same client shape.
- `scripts/bunker_config_gen.py:114` — stages `DUCKBRAIN_TOKEN_FILE` (`duckbrain.token`)
  for the node identity.

## Measured against

`~/duckbrain`, commit `4bff1094959c068f37ff771b5c6db5f9771f61a8` (2026-11-22
17:19:06 -0500). Measured 2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.

# scheduler — control-plane API (contract page)

## Role

The coding-hermes fleet scheduler: decides whose turn it is, renders the directive, dispatches
the tick over the bus, and awaits the reply. It is the consumer of every result envelope this
repo's nodes produce (`docs/REPOSITORIES.md`, `scheduler` row).

## Routes or commands

HTTP API, default listen `127.0.0.1:9090` (`cmd/schedulerd/main.go:101`; override
`SCHEDULER_LISTEN`/`--listen`). Route table registered in `internal/api/server.go:293-394`
(`Handler()`): `/api/v1/health`, `/api/v1/live`, `/api/v1/status`, `/api/v1/config`,
`/api/v1/projects` + `/api/v1/projects/{name}` (PUT, full object), `/api/v1/wakes`,
`/api/v1/hooks[/{id}|/plan|/reload]`, `/api/v1/lanes[/tree]`, `/api/v1/links[...]`,
`/api/v1/cadence`, `/api/v1/namespaces[/{id}]`, `/api/v1/groups[/{id}]`, `/api/v1/templates[/{id}]`,
`/api/v1/ticks[/{id}]`, `/api/v1/evaluate`, `/api/v1/pause`, `/api/v1/resume`, `/api/v1/events[+`/stream`],
`/api/v1/observatory[/stream]`, `/api/v1/gateway-errors`, `/api/v1/queue`, `/api/v1/openapi.json`,
`/api/v1/metrics`, `/api/v1/features[/prune-candidates]`, `/api/v1/peers[/{id}]`,
`/api/v1/agents[/{name}]`, `/api/v1/federation/{query,catalogue}`, `/api/v1/cooldown/residue`.

## Auth

Mutation gate, not a login system (`internal/api/auth.go:16-38`, SCHED-GAP-1602): reads are
open; every mutating route requires ONE shared operator credential, accepted as HTTP Basic,
`Authorization: Bearer <token>`, or the raw `X-Operator-Token` header (`auth.go:66-83`).
Credential sources here: `SCHEDULER_OPERATOR_TOKEN`, or read from schedulerd's
`/proc/<pid>/environ` (`scripts/configure_family.py:145-162`; `scripts/add_family_lanes.py:37-56,
79` sends `Authorization: Bearer`). Fail-closed: no configured credential ⇒ mutations refused
503 before any handler runs (`internal/api/auth_gate.go:11-14, 52`). Every decision writes an
`api.auth` events row (allowed INFO, refusals MEDIUM).

## Failure codes

- Error body shape: `{"error": "<msg>"}` (`internal/api/server_helpers.go:78-80`).
- `405` non-GET on GET-only reads (e.g. `server.go`, `health` handler).
- `401` missing/invalid operator credential on a mutation, with `X-Operator-Auth: required`
  and (basic mode) `WWW-Authenticate: Basic realm="scheduler operator"`
  (`internal/api/auth_gate.go:74-85`; writer `internal/api/auth.go:214-220`).
- `503` authOff fail-closed misconfiguration arm (`internal/api/auth_gate.go:52`).
- `504` a heavy read that outlives its per-request deadline, naming the stalled helper
  (`internal/api/server.go:393`).
- `500` with the error text on store failure (`internal/api/gateway_errors.go:56-58`).
- Auth outcome vocabulary in audit rows (SCHED-GAP-1619, `internal/api/auth.go:76-82`):
  `allowed`, `refused-unauthenticated`, `refused-bad-credential`, `refused-no-credential`.

## Result handling (the half this repo's envelope must satisfy)

- Correlation order: `in_reply_to` first, then `corr_id`, then the original dispatch echoed
  inside `task` (string or object) — `internal/scheduler/dispatch_leg.go:689-725`
  (`correlateDispatchReply`).
- Verdict: the `ok` field, absence reads as success; `ok:false` is a failure, reason from
  `error_b64` (decoded) then `error`/`err`/`reply`/`text`/`message` — `dispatch_leg.go:727-745`
  (`dispatchReplyVerdict`).
- Reply text: `reply_b64` decoded first, then `reply`/`answer`/`text`/`message`/`output`,
  else the whole payload as JSON — `dispatch_leg.go:761-786` (`dispatchReplyText`).
- Expiry sentence: `no correlated reply for corr=<corr> (message=<id>) within <budget>` —
  `dispatch_leg.go:390`.

## Failure/contract source

- Routes: `internal/api/server.go:293-394`.
- Auth: `internal/api/auth.go` (SCHED-GAP-1602) + `internal/api/auth_gate.go` (SCHED-GAP-1602/1619).
- Result handling: `internal/scheduler/dispatch_leg.go:380-470, 689-786`.

## Code-factory dependents

- `scripts/configure_family.py:49` (API base `http://127.0.0.1:9090`), `:145-162` (operator
  token from env or `/proc/<pid>/environ`), `:358` (POST `/api/v1/projects`), `:370`
  (PUT `/api/v1/projects/<name>`).
- `scripts/add_family_lanes.py:12` (same default API base), `:102` (project path),
  `:163-185` (GET project / POST `/api/v1/projects` with Bearer token).
- `specs/ENVELOPE.md` §Result, §ok is the verdict, §Correlation semantics — the scheduler's
  reading of `ok`, `in_reply_to`, `corr_id` and `reply_b64` is the envelope's consumer side.

## Measured against

`~/coding-hermes-scheduler/coding-herms-scheduler` (repo `coding-hermes/scheduler`),
commit `f5fbe321b00a5bda2bc627236ad06497c990bd28` (2026-11-22 11:26:45 -0500). Measured
2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.

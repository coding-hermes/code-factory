# M12 — INFERENCE PROXY

## 1. Identity

| Field | Value |
|---|---|
| Module name | INFERENCE PROXY (`cf-inference-proxy.py`) |
| Path | `~/.hermes/scripts/cf-inference-proxy.py` (273 lines) |
| Revision | content sha256 `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` (lives outside any git repo; no revision to stamp) |
| Language / runtime | Python — `#!/usr/bin/env python3`, no pinned version; **requires >= 3.10** (F12-5: `_forward` at `:164` declares `body: bytes | None`, an evaluated union annotation) |
| Owner lane | code-factory (control-host service, consumed by nodes) |
| Status | **VERIFIED (admission/routing/capture), FAILING (streaming)** — read in full (273 lines); content sha256 reproduced; live 401 admission reproduced; the two sink paths corrected (F12-8). **Streaming completion is FAILING (B22):** the healthy SSE stream is unframed to completion (`:206-224`), reproduced as a `200` with no `Content-Length`/`Transfer-Encoding`/`Connection` and a client EOF timeout (§11 F12-7). A blanket VERIFIED would contradict that demonstrated defect — admission, routing and capture are verified, streaming is not |

## 2. Purpose, authority and position

The control-side inference boundary in the resolved chain: **Bunker Hermes → node-token
admission → this proxy → gateway/router/provider → response/usage**. A node gets a NODE TOKEN,
never a provider or gateway key, and this proxy forwards on the node's behalf. **Node-proxy
tokens and forge credentials are separate credential domains** — M7/M11 mint forge scope; this
token only admits a node to the proxy. The credential holders must be named precisely: the proxy
holds the control-host **gateway credential** (`CF_PROXY_UPSTREAM_KEY_ENV`), and any upstream
gateway/router may itself hold the actual provider keys — so "only holder of the real provider
credential" is a control-side claim, and the invariant is **no real provider key ever reaches a
Bunker**. It decides which node may call (token), which model may run (allowlist), and whether
the call is streamed through or buffered. It is a **control-host** service, not a node-local one
(F12-1).

**What breaks if this module is absent.** The node has no inference path ("the node's only
inference path", CF-351).

**What breaks if it lies.** A fail-closed admission that fails open routes an untrusted or
off-contract model to the upstream and spends the fleet's credit on a dearer model. In the settings
register, a sink path that does not exist on disk sends an operator looking at the wrong file —
two invented filenames shipped in an earlier register revision (F12-8), which is the exact "what breaks if it lies"
failure for a paths register.

**Required behavior (normative).** Approved target behavior governs; the local-script audit in
§3–§13 is implementation coverage of one unversioned file, not the requirement.

- **Complete buffered and streamed contracts.** Allowed endpoints/methods/auth, request and
  response schemas, models/token/tool/stream options, body/content-type limits, status/error
  vocabulary, deadlines and client obligations; stream framing/termination, partial data and
  pre/post-header failures (F12-4's `[200, 502]`), backpressure/flush and buffering, downstream
  disconnect cancellation with upstream cleanup, and usage/accounting settlement. **A finite
  successful stream must finish at the client; a partial or error stream must never become an
  accepted complete answer.**
- **The healthy-stream completion defect stays open.** F12-7 (a healthy SSE stream left unframed
  to completion — no `Content-Length`/`Transfer-Encoding`/`Connection: close` — so a client
  reading to EOF times out) is a demonstrated defect. **The flight card's first-byte check cannot
  close it**: closing evidence is successful completion, truncation/error signaling, cancellation
  and usage settlement — not first-byte forwarding.
- **Effective model policy and requested-vs-served identity.** The global allowlist plus optional
  rewrite requires requested/chosen/resolved/actually-served model identity with the policy check
  applied to the **effective** route; the Hermes harness choice is not a model/provider route and
  must not be equated with one.
- **Node-token lifecycle, explicit capture policy.** The token mapping's producer/administrator,
  versioned schema, binding to Bunker/project/namespace and permitted routes/operations/budgets,
  expiry, secure delivery, renewal overlap, revocation/readback and decommissioning are required
  contracts — issuance integrates with M1 deployment and M5 harness configuration, separate from
  forge-app credentials. Per-project/model/budget/concurrency rules and the **raw prompt capture
  policy** (enablement, redaction, size, retention) are explicit contract, not code comments —
  F12-6's silent capture loss and unimplemented retention are coverage gaps against that contract.
- **Source qualification — defects retained.** The local proxy source/runtime was **not supplied
  for independent validation**: the implementation is an unversioned script outside any git repo,
  known only by content digest. The reported streaming/capture defects are retained **with that
  qualification**, and a maintained, versioned source package (or a documented replacement on the
  selected gateway/router) with actual-path conformance evidence is required for a reproducible
  build/deploy/upgrade/restore. A workstation path plus a service-active check does not supply
  that contract.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 admission | token resolution `_node` (`:115-123`), model allowlist (`:155-160`), fail-closed startup (`:265-270`) | **active** | invoked continuously by the systemd unit `~/.config/systemd/user/cf-inference-proxy.service` — loaded, enabled, `active (running)` since 2026-11-05 09:21, Main PID 2603939, drop-in `cf-inference-proxy.service.d/10-upstream.conf` (measured, `systemctl --user status`). The in-repo grep (`grep -rnE '8775\|CF_PROXY\|cf-inference-proxy' scripts/ config/ specs/`) finds no script/cron caller, but the invoker is the systemd unit, not absent (B2) |
| S2 upstream routing | `_forward` (`:164-180`), model rewrite via `UPSTREAM_MODEL` | **active** | `_forward` invoked by `do_GET` `:132` and `do_POST` `:162` (the request handlers under the systemd unit) |
| S3 stream pass-through | `:200-238` (streamed), `:240-258` (buffered) | **active** | the two branches of `_forward` (`:164`), reachable only through `:132`/`:162` |
| S4 usage and request capture | `capture_request` (`:83-95`), `log_usage` (`:98-101`) | **active** | `capture_request` called at `:161`; `log_usage` called at `:152, :156, :220, :227, :232, :248, :252` — all inside the `do_GET`/`do_POST`/`_forward` request path |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 (stdlib only) | **>= 3.10** (`:164` union annotation) | control host | import/syntax failure on < 3.10 |
| node token file | `TOKENS_PATH` `~/.hermes/secrets/cf-node-tokens.json` (`:48`) | control host | `FATAL: no token file … refusing to start open`, exit 2 (`:265-267`) |
| upstream key | selected by `CF_PROXY_UPSTREAM_KEY_ENV` (default `API_SERVER_KEY`, `:47`) in `~/.hermes/.env` | control host | `FATAL: API_SERVER_KEY missing`, exit 2 (`:268-270`) |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `urllib.request` | stdlib | `urlopen` with `timeout=300` (`:204`, `:241`) | the 300s timeout is load-bearing for stream pass-through |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_PROXY_UPSTREAM` | `http://127.0.0.1:8642` (`:43`) | an http(s) endpoint | where node inference is served | pointing at a provider gives nodes their own lane; the key still never leaves the host |
| `CF_PROXY_UPSTREAM_MODEL` | `""` (`:45`) | a model name or empty | model rewrite | non-empty rewrites the requested model before forwarding (`:166-170`) |
| `CF_PROXY_UPSTREAM_KEY_ENV` | `API_SERVER_KEY` (`:47`) | an env var name | which credential the proxy reads | a renamed credential must be coordinated with the endpoint |
| `CF_PROXY_ALLOWED_MODELS` | `hermes` (`:60-62`) | comma list | which models a node may ask for | empty env = deny all, never "allow everything" (`:58-59`) |
| `TOKENS_PATH` | `~/.hermes/secrets/cf-node-tokens.json` (`:48`) | a JSON file | the node-token mapping read at request time | a missing file → `FATAL: no token file`, exit 2 (`:265-267`) |
| `ENV_PATH` | `~/.hermes/.env` (`:49`, read by `upstream_key` `:75-80`) | an env file | where the upstream key is scanned | a renamed file must match the provisioner |
| `USAGE_LOG` | `~/.hermes/logs/cf-inference-usage.jsonl` (`:50`) | a path | usage capture sink | a failing sink raises into the request path (F12-6) |
| `CAPTURE_LOG` | `~/.hermes/logs/cf-inference-requests.jsonl` (`:52`) | a path | request capture sink | capture loss is silent (F12-6) |
| upstream timeout | **300 s** (`:204`, `:241`) | seconds | `urlopen` timeout on both stream and buffered legs | a shorter timeout truncates long generations |
| `MAX_BODY` | 4 MiB (`:54`) | positive int | request body ceiling | a body `> MAX_BODY` → 400 (`:142-143`) |
| `LISTEN` | `("0.0.0.0", 8775)` (`:53`) | **a hardcoded constant, not a setting** | proxy listener | no env/flag override; binds 0.0.0.0 so the tailnet can reach it |

**F12-8 (paths, corrected).** Both sinks are hardcoded `pathlib.Path` constants, not
environment settings. An earlier register revision carried `~/.hermes/logs/cf-usage.jsonl` (`:49`) and
`~/.hermes/logs/cf-capture.jsonl` (`:50`) — neither exists. The measured values are
`USAGE_LOG = …/cf-inference-usage.jsonl` (`:50`) and `CAPTURE_LOG = …/cf-inference-requests.jsonl`
(`:52`; `:51` is the "last 200 requests only" comment). An operator following that earlier register
would open two files that are never written. F12-6's consequence analysis is unchanged — it was
correct and is now attached to the real paths.

**F12-3 (credential selector).** The upstream credential name is configurable
(`CF_PROXY_UPSTREAM_KEY_ENV`, `:47`), read by `upstream_key()` (`:75-80`) which scans `ENV_PATH`
for `NAME=value`. But the startup error at `:269` hardcodes `API_SERVER_KEY` in its message even
when a different name is configured — the diagnostic lies about which variable it checked.

## 6. Contracts in and out

Canonical ids are the register of record (Part IV, CT-01..CT-23). The proxy's two interfaces
are **CT-19** (node → proxy) and **CT-20** (proxy → gateway) — the former local labels M12-C1/
M12-C2 are retired. CT-07 is the **router → gateway** model-choice contract, one hop away from
this module: the model-selection boundary the proxy participates in on the forwarding side is
CT-20, and any figure or table that labels the node→proxy or proxy→gateway hop "CT-07" is wrong.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-07 | gateway | in (model choice) | **external** — the task-router's model choice (out of scope) | **external** — the Hermes gateway (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured; an outline "works" annotation is not implementation evidence (B03) |
| CT-19 | node | in | **unproven client half** — the proxy side is verified (401 on missing/unknown token, `:128-130`); the node side has no in-repo file that *calls* the proxy. `grep -rnE '8775\|CF_PROXY\|cf-inference-proxy' scripts/ config/ specs/` (ERE, re-run) matches **four** text sites: `scripts/panel_loop.py:145`, `scripts/master_doc_skeleton.py:25` and `:211` (self-references listing the path), and `config/node.env.example:22` — which is the **live assignment** `ENV_CF_PROXY_API_KEY=@~/.node/auth/provider.key`, not a comment. `config/node.env.example:26` comments `CONFIG_SET_MODEL_PROVIDER=cf-proxy -> model.provider`, so the producer half is config-driven: `node.env.example:22,26` → `node_env.py`/provisioner config generation → `~/.hermes/config.yaml` `model.provider=cf-proxy`. A quoted command omitting `-E` runs a bare-`\|` BRE and returns **0** matches (measured rc 1) — the opposite of the row's earlier claim. | `cf-inference-proxy.py:135` `do_POST` → `_node` (`:136`) | **UNVERIFIED** — proxy side verified; the node-client call site is config-wired, not a `file:function` in this repo |
| CT-20 | upstream | out | `_forward` (`:164`) builds the upstream request with the control-host key | **rumour — one side only** (the upstream gateway/provider, not a function) | **UNVERIFIED** — external boundary with one side named; a "works" verdict on a rumour is not permitted (B06) |

The CT-19 producer evidence is the empty-grep and config-driven chain above; the client half is
unproven, so the state is UNVERIFIED, not "works". Existing node configuration is evidence of
intended integration, not proof of a successful authorized request.

The CONTRACT section (`:9-19`) documents three routes — `POST /v1/chat/completions`,
`GET /v1/models`, `GET /health` (no auth) — and states: "There is no anonymous path and no
fallback: a node that cannot authenticate cannot spend money." **Corrected (B65):** the
"no anonymous path" wording is an overstatement — `GET /health` **is** unauthenticated
(`cf-inference-proxy.py:12` and the handler at `:126-127`). The true claim is "no anonymous
*paid/model* path": a request that reaches `_node` without a valid token is refused 401, so an
unauthenticated caller cannot spend money. There is no fallback that downgrades a refused caller
to an open path.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| content hash | `sha256sum ~/.hermes/scripts/cf-inference-proxy.py` | full digest | 2026-11-07 | **PASS** — `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` (re-confirmed unchanged) |
| python compile | `python3 -m py_compile ~/.hermes/scripts/cf-inference-proxy.py` | exit 0 | 2026-11-07 | PASS |
| admission (no token) | `curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8775/v1/chat/completions -d '{"model":"hermes"}'` | 401 | 2026-11-07 | **PASS** — 401 (proxy live on `:8775`) |
| systemd unit active | `systemctl --user status cf-inference-proxy.service` | loaded, enabled, `active (running)` | 2026-11-07 | **PASS** — `active` (`systemctl --user is-active` → active) |
| admission (disallowed model, valid token) | POST `{"model":"definitely-not-allowed-model"}` with a valid node token | 403 `model not permitted` | 2026-11-06 | reproduced in an earlier judge run (`:155-160`); **not re-run** — the node token file was not read |

## 8. Metrics

**RED — none (absence-proved).** The proxy emits no counters, gauges or histograms.
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' ~/.hermes/scripts/cf-inference-proxy.py`
→ 0 matches (the file carries no metric registry). It **does** append structured capture/usage
JSONL — `capture_request` (`:83-95`) and `log_usage` (`:98-101`) with
`ts, node, model, status, bytes, secs, first_byte, streamed` (`:220-223`, `:252-253`) — but that
is a capture log, not an emitted metric.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `cf-inference-proxy on %s:%d -> %s, nodes=%s` (`:271`) | startup | descriptive |
| — | `FATAL: no token file at %s — refusing to start open` (`:266`) | token file missing, exit 2 | evidentiary |
| — | `FATAL: API_SERVER_KEY missing from %s` (`:269`) | upstream key missing, exit 2 | evidentiary — but the name is hardcoded even when `CF_PROXY_UPSTREAM_KEY_ENV` differs (F12-3) |
| — | `token file unreadable: %s` (`:71`) | token JSON unreadable | evidentiary |

`log_message` is overridden to a no-op (`:260-261`) so the HTTP journal stays readable.

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Missing/unknown token | 401 `missing or unknown node token` (`:130`) | a wrong bearer | provision the node's token file |
| Disallowed model | 403 `model not permitted` + `allowed` list (`:158-160`) | a malformed body (400) | add the model to the allowlist deliberately |
| No model named | 400 `a model is required` (`:154`) | a disallowed model | send a model field |
| Connection failure (urlopen raises before headers) | a clean 502 `upstream unreachable` (`:236-237`) | an upstream rejection | check the upstream gateway |
| Read failure after headers, before first chunk | the upstream status + headers are already sent (`:206-210`), then the proxy attempts a second 502 — the client sees `[200, 502]`, a corrupt response (F12-4) | a clean 502 | client must detect the truncated stream |
| Upstream dies mid-stream | `first` is set, the stream just ends (`:238`), **no 502** | a buffered failure | client must detect a truncated stream |
| No contract | behaviour defined only by code | a specified contract | **OPEN** — CF-351 |

## 11. Limits and margins

- Fail-closed startup: no token file or no upstream key → `sys.exit(2)` before binding (`:265-270`).
- `MAX_BODY` 4 MiB (`:54`); upstream timeout 300s (`:204`, `:241`).
- **F12-4 (streaming guarantee correction).** The earlier claim "a 502 is returned only
  when the failure happens before the first byte" conflates two distinct cases (B24). The stream
  path sends the upstream status and headers first (`:206-210`), then reads chunks. If `urlopen`
  itself fails, no headers were sent and the 502 is clean. If a later read fails **before the first
  chunk**, headers were already sent, so the attempted 502 is a second status after the 200 —
  `[200, 502]`, not a valid standalone 502. If it fails **after** a chunk, the stream just ends.
- **F12-5 (interpreter constraint).** `_forward` at `:164` declares `body: bytes | None` — an
  evaluated union annotation with no `from __future__ import annotations`. This requires
  **Python >= 3.10**; "Python 3.x, stdlib only" was an insufficient constraint.
- **F12-6 (capture/usage failure semantics, B26).** `capture_request` (`:83-95`) truncates the raw
  body to 120000 chars and swallows every exception (`except Exception: pass`) — capture loss is
  silent. `log_usage` (`:98-101`) has **no** exception suppression, so a usage-sink failure can
  raise into the request path (`:220-238`, `:252-253`). The `CAPTURE_LOG` comment claims "last 200
  requests only" (`:51`) but the code appends indefinitely — no truncation or retention is
  implemented.
- **F12-7 (stream-completion defect, B28).** `_forward`'s streaming path (`:206-210`) sends the
  upstream status/headers but neither `Content-Length`, `Transfer-Encoding`, nor `Connection: close`,
  and returns at `:224` without marking the connection closed. A healthy upstream that finishes its
  SSE cleanly therefore leaves the downstream response unframed: a client reading to EOF times out
  even though every byte was forwarded. This is not an upstream-failure case — it is the *healthy*
  case. An independent verifier exercised the actual `Handler` against a finite local SSE upstream
  and measured `PROXY_STREAM_STATUS=200`, `CONTENT_LENGTH=None`, `TRANSFER_ENCODING=None`,
  `CONNECTION=None`, `PROXY_STREAM_EOF_COMPLETED=False: TimeoutError` (B24) — the reproducible
  failure to cite. **Streaming correctness is FAILING** — the framing defect is reproduced, so a
  repeatable framing/completion oracle is the missing evidence; it is a demonstrated defect, not a
  merely unverified property (B22).

## 12. Cross-references

- The node reaches the proxy over the tailnet via operator-configured `CF_BASE_URL`. **No direct
  client function calls the proxy from this repo** — but node *configuration* does reference it:
  `config/node.env.example:22` (`ENV_CF_PROXY_API_KEY=@~/.node/auth/provider.key`) and `:26`
  (`CONFIG_SET_MODEL_PROVIDER=cf-proxy -> model.provider`) wire the proxy as the node's provider
  (see CT-19). Configuration evidence, actual call-site evidence, and successful live use are
  distinct; only the configuration reference is established (B25).
- **M7 GITHUB does not produce the node tokens.** The proxy loads `TOKENS_PATH` (a JSON mapping,
  `:48`, `:65-72`) and compares bearer tokens against it (`:115-123`); the producer of that mapping
  is unknown (B16, M7 §12).
- The upstream key is read from `~/.hermes/.env` at request time and never logged/echoed (`:23-24`).

## 13. Evidence of record

- Code read: `cf-inference-proxy.py` (273 lines, read in full); content sha256
  `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` (re-confirmed — file unchanged, `wc -l` = 273).
- Commands run: `sha256sum` (PASS); `python3 -m py_compile` (PASS); `curl` no-token → 401;
  `systemctl --user is-active cf-inference-proxy.service` (active);
  `grep -rnE '8775|CF_PROXY|cf-inference-proxy' scripts/ config/ specs/` (4 text sites, node client
  config-wired); `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' <proxy>` (0 matches);
  `sed -n '49,52p'` (sink constants, F12-8).
- Board rows: CF-343, CF-346, CF-351.
- **Findings:**
  - **F12-1** (carried) — control-host service, not node-local.
  - **F12-2** (carried) — the CONTRACT section is in the code (`:9-19`), not in any spec.
  - **F12-3** — the credential selector is configurable but the startup error hardcodes
    `API_SERVER_KEY` (`:269`).
  - **F12-4** — the "502 before first byte" claim is corrected: headers are sent before the first
    read, so a read failure before the first chunk yields `[200, 502]`, not a standalone 502.
  - **F12-5** — Python >= 3.10 required (`:164` union annotation), not "3.x".
  - **F12-6** — capture loss is silent; usage-write failure is not; "last 200 requests" is an
    unimplemented comment.
  - **F12-7** (carried) — the healthy SSE stream is not framed to completion (no Content-Length /
    Transfer-Encoding / Connection: close), so a client reading to EOF times out even on success.
  - **F12-8** (new) — an earlier register revision carried two invented sink filenames (`cf-usage.jsonl`, `cf-capture.jsonl`);
    the measured values are `cf-inference-usage.jsonl` (`:50`) and `cf-inference-requests.jsonl`
    (`:52`).

## 15. Normative node-token, model API and capture contract (P3-12, P3-17)

The maintained proxy package is the deployable authority. A deployment artifact carries a version, source digest, Python compatibility, service unit, configuration schema, upgrade/rollback procedure and restore procedure. A workstation path or active service without this package is `UNVERIFIED` and cannot certify a node.

The node-token mapping is `schema: cf.node-token.v1`: `token_id`, `node_id`, `project_id`, `namespace`, `allowed_routes`, `allowed_models`, `budget`, `concurrency`, `issued_at`, `expires_at`, `generation`, `scope_digest`, `revoked_at` and `issuer_ref`. M1 requests issuance; the proxy owner administers the mapping; the token is delivered as an owner-only file and read back by id, scope digest and expiry without printing its value. Rotation overlaps only within a declared window. Revocation and decommission invalidate the token immediately, and every request checks generation, scope, expiry, budget and concurrency before forwarding.

Supported API version `cf.inference.v1` exposes `GET /health` without paid/model authorization, `GET /v1/models` with node authorization, and `POST /v1/chat/completions` with model, messages, stream and option validation. A buffered result carries requested, chosen, resolved and served model identity, usage, completion state and response id. Errors use `401` missing/unknown/revoked token, `403` scope/model denial, `400` invalid body, `408` deadline, `429` budget/concurrency, `502` upstream-before-headers and `504` timeout. After headers, a failure is a terminal stream error or truncated result, never a second HTTP status.

A streamed response uses framed SSE records and an explicit terminal event containing response id, served model, usage and `complete`/`error`/`cancelled` state. The proxy closes or correctly frames the downstream connection after the terminal event; upstream read failure before headers is a clean 502, while failure after headers is an incomplete/error stream. Client disconnect cancels upstream work. Usage settlement records request id, token id, requested/served model, bytes, duration, first-byte time and terminal state; failed capture or usage persistence follows an explicit policy and is visible.

The deployment package name/version is not yet selected; M11.17's C-ARTIFACT decision
is blocking. No arbitrary `cf-inference-proxy` 1.x release is implied. A qualified artifact must
ship the service unit, `cf.inference.v1` schema, configuration defaults, migration,
upgrade/rollback and restore instructions. The unversioned workstation path measured
above is not a supported build artifact; until a digest-pinned package or an exact
maintained replacement is installed and read back, the deployment is `UNVERIFIED`.
The Hermes compatibility adapter sends the same `model`, `messages`, `stream` and
option fields, accepts HTTP status plus SSE `data:` records, and translates the
terminal record to the client's completion object without inventing a second status.

The node-token administrator exposes `schema: cf.node-token-admin.v1` operations
`issue`, `read`, `rotate`, `revoke` and `offboard`. Requests carry `issuer_ref`,
`node_id`, `project_id`, `namespace`, `allowed_routes`, `allowed_models`, `budget`,
`concurrency`, `ttl`, `generation` and `idempotency_key`; results carry the token id,
scope digest, generation, expiry and state, never the token value. Defaults are
`stream=false`, upstream deadline `300 s`, request body limit `4 MiB`, and no raw
prompt capture. A node token is valid only while the mapping generation, project,
namespace, route, model, budget, concurrency and expiry checks all pass. Rotation has
a declared overlap; revocation and offboarding invalidate immediately and survive
restore.

A stream consists of zero or more `data:` records followed by exactly one
`event: terminal` whose JSON body is `{response_id, served_model, usage, state}`;
`state` is one of `complete`, `error` or `cancelled`. The proxy sends no second HTTP
status after headers. Before headers, upstream failure is `502 UPSTREAM_UNREACHABLE`;
after headers, failure is a terminal `error` event or an incomplete stream, never a
successful completion. Deadlines produce `408` before headers or a terminal error
after headers. Client disconnect cancels the upstream request and records
`cancelled`; successful completion closes or correctly frames the downstream
connection so the Hermes client can finish at EOF. Usage settlement records
`request_id`, token id, requested/chosen/resolved/served model, bytes, duration,
first-byte time, terminal state and settlement status. A failed usage sink is a
visible `USAGE_UNSETTLED` result and cannot be reported as complete.

Raw prompt capture remains disabled unless a policy enables it. That policy names
redaction before persistence, a maximum size of 120000 characters, retention (default
30 days), sink, access scope and failure behavior; capture failure emits
`CAPTURE_FAILED` and never silently becomes a complete audit record. Metrics are
counters/gauges with units and bounded labels for authorization, model mismatch,
upstream error, stream terminal state, cancellation, usage settlement, capture
failure, token expiry/revocation and budget denial. Acceptance cases cover a finite
Hermes-compatible stream to terminal EOF, pre/post-header failure, cancellation,
requested-versus-served identity, expired/revoked token, budget exhaustion and both
capture/usage sink failures.

## 16. Token issuance and atomic inference ledger (P5-C-22/23/25)

The target proxy admin API is mTLS on a separate listener bound to the management
network; only enrolled issuer/provisioner principals with matching project scope can
use `/v1/admin/node-tokens`. POST issues, GET `/{token_id}` reads metadata,
POST `/{token_id}/rotate`, `/revoke`, `/offboard` mutate. Each request is the Part I
cf2a.v1 wrapper with body version cf.node-token-admin.v1, operation_id,
idempotency_key, expected_generation, node_id, project_id, scope (V.9 NodeScope),
ttl_s and delivery_target (registered Bunker ID). Revoke/offboard instead require
token_id and reason; rotate inherits scope unless explicitly narrowed. TTL is 600..86400 s,
default 3600; overlap defaults 60 s, range 0..300, renewal margin 300 s. Admin responses
use Part I Error and return 201/200 metadata only; conflict 409, scope 403, unavailable 503.

Issuer generates 32 cryptographic random bytes, encodes base64url without padding,
and stores only SHA-256(token bytes), token_id, scope, expiry, state and generation
in the authorization ledger. Clear bearer exists in an encrypted, recipient-bound
one-time delivery object at secretref://model/deliveries/<operation_id>; only the
registered M1 credential installer can redeem it using mTLS, over TLS to a protected
installer, never as application API JSON. The reference and receipt ID are returned.
Redemption writes an owner-only file via temporary file/fsync/rename/directory fsync;
readback attests token_id, file mode and scope hash without returning bearer. Delivery
ciphertext expires after 300 s and is destroyed after acknowledgement. Lost receipt
queries installer operation_id; a new bearer is not minted on a blind retry. The
ledger atomically changes staged → active only after matching readback; a CAS replaces
active pointer during rotation. Old credential becomes overlap then revoked. Unknown
delivery stays staged/unusable until receipt or expiry. Revoke records denial in the
independent authority before acknowledgement, cancels admitted requests and marks
unknown upstream spend for conservative settlement; it cannot undo already incurred
cost. Offboard revokes all node token IDs. Restore uses VI.35.2, never restores active
bearers from a backup. [CT-19/21; M7.16]

All proxy replicas share one serializable SQL authorization/accounting database.
Authorization and admission run in a single transaction keyed by `(token_id,request_id)`;
request digest is compared, not part of the key. The transaction locks token generation,
current fixed window and concurrency rows, checks live authority/fence, expiry, route,
and deadline, then reserves both cost and a slot before forwarding. Windows are
UTC-aligned floor(server_epoch_s/window_s), with V.9's units. Budget is integer
micro-USD (one million per USD); route prices are micro-USD per million tokens, pinned
at admission. Reserve ceil(input_tokens*input_rate/1000000) plus
ceil(max_output_tokens*output_rate/1000000). The pinned tokenizer measures input;
unavailable tokenizer or price refuses PRICING_UNAVAILABLE. Condition is
spent + held + reserve <= budget and active < concurrency; a race has one transaction
winner. Zero-price models still reserve a concurrency slot. Streamed output cannot
exceed the reserved maximum. Tokens cannot cross windows by extending a request.

Request row contains request_id,digest,token_id,generation,window,reserved_cost,
actual_cost nullable,state (reserved/forwarding/settled/unsettled),upstream_id nullable,
route/tokenizer/price digests,result_ref nullable,deadline and timestamps. Usage,
result blob digest and terminal state commit together before success is returned.
Unknown spend after upstream timeout/crash is charged the full reservation, tagged
estimated; it is never refunded merely because a client disconnected. Proven no-send
refunds; known usage settles actual <= reserved and releases remainder. Provider
usage above bound is a breach event and blocks the route. Concurrency releases only
when upstream terminal/quiescence is proved; otherwise the slot stays quarantined.
Restart scans forwarding/unsettled rows, queries upstream by ID where supported,
and otherwise retains conservative charge/quarantine. Same-ID retry returns pending
or durable result and never forwards again; changed digest returns 409.

The usage commit is the response commit point. Mandatory ledger failure produces
503 USAGE_UNSETTLED before headers or terminal state error with error.code
USAGE_UNSETTLED after headers; if even that cannot be delivered, EOF without terminal
is incomplete. There is no complete event before settlement. Crash after commit but
before send is recoverable at authenticated GET `/v1/responses/{request_id}` returning
202 pending, 200 committed terminal/result, or 404 unknown. Result records persist
30 days; afterward ID tombstone returns 410, never re-executes. Raw capture failure
uses V.9 policy: refuse prevents complete, record retains a CAPTURE_FAILED diagnostic
without claiming a complete audit record. [VI.18/19; V.9/10]

## 17. Closed completion and stream grammar (P5-C-24)

The supported request is `{model,messages,stream,options,request_id,deadline}`.
model is an allowed route name <=128 UTF-8 characters; request_id is ID, deadline UTC;
messages is 1..1024 entries, body <=4 MiB. stream boolean defaults false. Each message
has role system/user/assistant/tool and content string <=1 MiB (empty allowed only
for assistant tool calls), plus optional tool_calls for assistant or tool_call_id
for tool. tool_calls is a list of `{id,type: function,function:{name,arguments}}`;
arguments is JSON text, not an object. Tool responses must reference a prior call ID.
Images/audio/multimodal content are unsupported and return 400 UNSUPPORTED_CONTENT.
options is a closed object: temperature number 0..2 default 1, top_p number (0,1]
default 1, max_output_tokens integer 1..scope maximum default min(4096,scope maximum), stop list of 0..4
nonempty strings <=256 characters default empty, tools list 0..128 of
`{type: function,function:{name,description,parameters}}`, tool_choice auto/none or a
named declared function default auto. Function name is `[A-Za-z_][A-Za-z0-9_]{0,63}`;
parameters is JSON Schema draft 2020-12 object without remote $ref. Other options,
unknown keys/roles, duplicate call IDs and invalid tool references are 400 INVALID_BODY.

GET `/v1/models` returns `{object:list,data:[{id,object:model,owned_by,capabilities}]}`,
filtered by token scope; capabilities is set text/tools/stream. Buffered completion
is `{id,object:chat.completion,created,model,requested_model,chosen_model,resolved_model,
served_model,choices:[{index:0,message:{role:assistant,content,tool_calls},finish_reason}],
usage,state,error}`. content is string or null when only tool calls; tool_calls is a
list (empty permitted); finish_reason is stop/length/tool_calls; usage is
`{input_tokens,output_tokens,total_tokens,cost_micro_usd,estimated}`; all counts are
nonnegative integers, estimated boolean. state is complete/error/cancelled; error is
null on complete, otherwise `{code,message,retryable}`. Identity mismatch is error,
not a silent replacement. /health returns `{status:healthy/degraded,ready:boolean}`
without a model call and never exposes credential metadata.

SSE uses Content-Type text/event-stream, UTF-8, each record terminated by two LF bytes.
Text/tool chunks have `event: delta` then `data: <one-line canonical JSON>` with
`{id,seq,choices:[{index:0,delta,finish_reason}]}`. seq starts at 0 and increases;
delta contains content string, role assistant, or tool_calls fragments
`{index,id,type:function,function:{name,arguments}}`; indices join fragments and
arguments strings concatenate in order. finish_reason is null until final delta.
A usage event follows with `{id,seq,usage}`. Exactly one terminal event follows with
`{response_id,served_model,usage,state,error}` and then `data: [DONE]` and a framed
connection close. A complete terminal is emitted only after §16's commit; [DONE]
alone is not proof. Midstream failure emits terminal error/cancelled if connection
remains writable, then closes; missing terminal is truncated, never complete.

Before headers: invalid request 400; missing/revoked/expired token 401; model/scope 403;
caller deadline already elapsed or elapsed first 408 DEADLINE_EXCEEDED;
budget/concurrency 429; upstream connect/protocol failure 502; upstream configured
300 s timeout elapsed before caller deadline 504 UPSTREAM_TIMEOUT; ledger failure 503.
After headers the same code appears in terminal.error, not a second HTTP status.
Client disconnect records cancelled and invokes upstream cancellation; bounded
quiescence/unknown-spend rules still apply. Hermes adapter consumes deltas in seq
order, assembles tool calls, waits for terminal + [DONE], returns one completion only
on complete with settled usage, and raises typed error on error/cancelled/truncation.
It may query the response ID after disconnect but cannot silently resend with a new ID.
This translation is the required compatibility behavior, not a claim about current
Hermes implementation. [CT-19/20; VII.13]

## RED field count: 4 (Metrics §8 — absence-proved; CT-19 node-client half UNVERIFIED; CT-20 upstream half UNVERIFIED — one-sided external boundary; stream completion **FAILING** — F12-7 reproduced, and a first-byte-only flight card cannot close it)

## FLIGHT DATA FILE - M12 INFERENCE PROXY

```checklist
TITLE: M12 INFERENCE PROXY
WHO: CONTROL HOST
NO TOKEN - POST a completion with no bearer
√ 401 - named refusal, nothing forwarded
ALLOWLIST - request a model off the allowlist
√ REFUSED - named refusal, no upstream call, no key spent
STREAM - send stream: true
FIRST BYTE - headers go out immediately; first_byte logged, never buffered
! COMPLETION - OPEN (F12-7): a healthy stream is unframed to completion — a client
  reading to EOF times out. First-byte success does NOT close the streaming
  contract; closing evidence is completion/truncation/cancel/usage settlement.
```

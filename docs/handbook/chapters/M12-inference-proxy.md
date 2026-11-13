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

The maintained proxy package is the deployable component, but its release identity is
owned by the single `cf.release-lock.v1` manifest in M1 §18. A deployment artifact carries
a version, source digest, Python compatibility, service unit, configuration schema,
upgrade/rollback procedure and restore procedure; the release manager's lock must also
inventory its adapter, policy, trust and receipt dependencies with architecture, digest,
provenance and compatibility. A workstation path or active service without this package
is `UNVERIFIED` and cannot certify a node. M12 preserves token generations and admitted
request identities during F13; it does not mint replacement tokens or independently
activate a release.

The node-token mapping is `schema: cf.node-token.v1`: `token_id`, `node_id`, `project_id`, `namespace`, `allowed_routes`, `allowed_models`, `budget`, `concurrency`, `issued_at`, `expires_at`, `generation`, `scope_digest`, `revoked_at` and `issuer_ref`. M1 requests issuance; the proxy owner administers the mapping; the token is delivered as an owner-only file and read back by id, scope digest and expiry without printing its value. Rotation overlaps only within a declared window. Revocation and decommission invalidate the token immediately, and every request checks generation, scope, expiry, budget and concurrency before forwarding.

Supported API version `cf.inference.v1` exposes `GET /health` without paid/model authorization, `GET /v1/models` with node authorization, and `POST /v1/chat/completions` with model, messages, stream and option validation. A buffered result carries requested, chosen, resolved and served model identity, usage, completion state and response id. Errors use `401` missing/unknown/revoked token, `403` scope/model denial,
`400` invalid body, `408` deadline, `402 BUDGET_EXHAUSTED` for budget exhaustion,
`429 CONCURRENCY_EXHAUSTED` for concurrency exhaustion, `502`
upstream-before-headers and `504` timeout. After headers, a failure is a terminal
stream error or truncated result, never a second HTTP status.

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
token_id and reason; rotate inherits scope unless explicitly narrowed. TTL is 60..86400 s,
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
cost. Offboard revokes all node token IDs. Restore uses VI.35.2 and the current
authority/revocation readback, never restores active bearers from a backup or
trusts a backup-local watermark. [CT-19/21; M7.16; F15]

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
For budget-unit disambiguation see §V.5: the round-report `budget` object counts worker slots, not micro-USD.

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

The canonical native request `cf.inference.v1` is
`{schema_version:"cf.inference.v1",model,messages,stream,options,request_id,deadline}`.
model is an allowed route name <=128 UTF-8 characters; request_id is ID, deadline UTC;
messages is 1..1000 entries and the canonical JSON body is <=1048576 bytes (1 MiB).
stream boolean defaults false. Each message
has role system/user/assistant/tool and content string <=1048576 bytes (1 MiB)
(empty allowed only for assistant tool calls), plus optional tool_calls for assistant or tool_call_id
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
null on complete, otherwise `{code,message,retryable}`. `id` equals request_id and is
also the stream response_id; upstream_id is the provider's distinct request identity.
`model` is the requested route; chosen_model, resolved_model and served_model are the
exact provider-served model returned by routing and must agree. requested_model is the
caller-supplied string. Identity mismatch is error, not a silent replacement.
/health returns `{status:healthy/degraded,ready:boolean}`
without a model call and never exposes credential metadata.

SSE uses Content-Type text/event-stream, UTF-8, each record terminated by two LF bytes.
Text/tool chunks have `event: delta` then `data: <one-line canonical JSON>` with
`{id,seq,choices:[{index:0,delta,finish_reason}]}`. seq starts at 0 and increases by
exactly 1 per sequenced event record; zero is the native protocol origin and is not
configurable; legacy adapters may add 1 at their boundary.
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
budget exhaustion 402 BUDGET_EXHAUSTED; concurrency exhaustion
429 CONCURRENCY_EXHAUSTED; upstream connect/protocol failure 502; upstream configured
300 s timeout elapsed before caller deadline 504 UPSTREAM_TIMEOUT; ledger failure 503.
After headers the same code appears in terminal.error, not a second HTTP status.
Client disconnect records cancelled and invokes upstream cancellation; bounded
quiescence/unknown-spend rules still apply. Hermes adapter consumes deltas in seq
order, assembles tool calls, waits for terminal + [DONE], returns one completion only
on complete with settled usage, and raises typed error on error/cancelled/truncation.
It may query the response ID after disconnect but cannot silently resend with a new ID.
This translation is the required compatibility behavior, not a claim about current
Hermes implementation. [CT-19/20; VII.13]

## 18. Application-proxy mapping and inference telemetry

The native `cf.inference.v1` grammar in §17 is canonical. CT-19 and CT-20 are
versioned transport adapters, not competing inference grammars. Their v2 body is
`inference-request.v2` / `inference-forward.v2`: all native fields plus
`project_id:ID`, `attempt_id:ID`, `corr_id:ID` and `credential_ref:SecretRef`.
Forward adds `upstream_ref:EndpointRef`, `upstream_credential_ref:SecretRef`,
`upstream_corr_id:ID`, `policy_generation:PosInt` and `upstream_deadline:Time`.
The outer envelope request_id equals body request_id. The adapter authenticates
credential refs locally and never serializes their values into the native request or
provider JSON. The adapter envelope and adapted native JSON are limited to
1048576 bytes, exactly the canonical native-chat schema ceiling in §17. The
service's default 4194304-byte raw transport ceiling does not enlarge a valid
canonical body. The outer Part I 64 KiB text rule is not an inference-body
limit. Oversize input returns PAYLOAD_TOO_LARGE before authorization or forwarding.

The total v2 mapping is: route model unchanged; messages/tool_calls/tool_call_id
unchanged; stream defaults false; max_output_tokens and all other generation/tool
controls live in options with §17 defaults; request_id becomes native id/response_id;
deadline is the caller deadline; upstream_deadline is min(caller deadline, configured
upstream deadline); project/attempt/corr IDs join the accounting row; upstream_corr_id
joins provider logs. The upstream provider request contains only native model,
messages, stream/options and provider-required routing fields. `requested_model`
retains the route string; chosen/resolved/served model identity follows §17. v2 buffered
results use the full §17 completion, including tool_calls and usage.

`inference-request.v1` and `inference-forward.v1` are a read-compatible minimal
profile only. Their ChatMessage `{role,content,call_id}` maps to native role/content
and call_id→tool_call_id; top-level max_output_tokens maps to
options.max_output_tokens; omitted options take §17 defaults; stream defaults false.
That version cannot represent assistant tool_calls or declare tools. A v1 request
that needs tools is refused UNSUPPORTED_VERSION before forwarding, and an unexpected
tool-call response is UPSTREAM_PROTOCOL_ERROR, never silently dropped. v1 buffered
InferenceResult.content concatenates ordered content deltas, finish_reason and error
map directly, and upstream_id maps from the provider identity. A complete result still
requires settled usage even though legacy InferenceResult does not display it.

The native stream starts seq=0 and emits ordered delta events, exactly one usage
event, exactly one terminal event, then [DONE]. `inference-stream.v1` is the legacy
adapter with seq starting at 1 and native seq = legacy seq−1. Legacy delta `chunk`
maps from native content only, legacy usage maps from the usage event, and terminal
response_id is native request id. Tool-capable clients must use v2; v1 cannot erase
tool deltas. Every terminal carries response_id, served_model, final usage, state and
error. A complete terminal follows the usage commit; errors and cancellation use the
same terminal shape. EOF/[DONE] without terminal is truncated. Duplicate sequence,
missing usage, identity mismatch or terminal-after-terminal is
UPSTREAM_PROTOCOL_ERROR. Recovery GET uses request_id; a new id never disguises a
retry.

M12 emits Part V `factory.telemetry.v1` before acknowledgement for event_type
`inference`, `response-lookup`, `capture`, `credential-issue`, `credential-renew` and
`credential-revoke`, with module M12, FactoryIdentity, source_event_id/source_seq,
duration_ms and the closed global outcome set. Payload carries request_id, project_id,
attempt_id, nullable task_id, route, chosen/resolved/served model, upstream_id,
token_id (never bearer), expiry_headroom_seconds, input/output/total tokens,
cost_micro_usd, estimated, state, refusal/error code and capture_ref.
Global operations map inference→infer, response-lookup→verify, capture→capture and
credential events→issue/renew/revoke. Base counters use exactly
module/operation/outcome/project labels; duration histograms use exactly
module/operation/project labels. Derived views are
`factory_inference_tokens_total{module="M12",project,kind="input|output"}`,
`factory_inference_cost_micro_usd_total{module="M12",project}`,
`factory_inference_unsettled{module="M12",project}` and
`factory_upstream_errors_total{module="M12",project,code}` with code from the bounded
Part I/provider error registry. Model, route, token_id, request/attempt/task IDs stay
in payload, never base labels. V.10's durable module/source_event_id/source_seq cursor
deduplicates emission, retry, scrape and restart; one request event counted twice is
a projection defect. Read-only GETs and scrapes emit nothing and do not refresh the
last-operation timestamp.

## 19. III.M12.S1 — Management API, configuration authority and authentication (P5G-05; F12/F13)

This section is the normative M12.S1 contract for proxy admission and management. It
extends the node-token administration surface in §16 without replacing the Factory
manager contract in Part I §1.9 and Part V §V.0. The same terms and versions apply on
both surfaces: the outer request/result envelope is `cf2a.v1`, the configuration body
is `factory.v1`, and the node-token body remains `cf.node-token-admin.v1`. A
`manager.v1`, `desired_generation`, or M12-specific project-write grammar is not a
second target. The manager is TARGET-UNIMPLEMENTED; this specification is not a
claim that the unversioned proxy script implements it.

### 19.1 Boundary and authenticated request/result

The management listener is separate from runtime inference and is reachable only on
the management network over TLS 1.3 with mutual client authentication. Before a
body is decoded, the server validates the client certificate chain, clientAuth usage,
URI SAN `urn:factory:principal:<id>`, validity and online revocation. The authenticated
SAN is the `sender`; a body-supplied principal is refused. The authority maps that
principal to a role and explicit scope. Administrators may mutate global and project
intent; project editors may mutate only their project; M9.S4 operator readers may
read and reconcile only the scopes granted to them. Authority outage is
`503 AUTHORITY_UNAVAILABLE`, never cached authorization. M1.S3 owns node identity
and Crier membership; it does not authorize management configuration or proxy
provider spend.

Every mutation is an HTTP request carrying `Accept: application/json`,
`Content-Type: application/json`, `X-Request-Id`, `X-Correlation-Id` and
`Idempotency-Key`. `X-Request-Id` equals the outer `request_id`, the correlation
header equals `corr_id`, and the header idempotency key equals the body key;
mismatches are `422 INVALID_FIELD`. The canonical outer object is exactly:

`{schema_version:"cf2a.v1",message_type,request_id,corr_id,sender,created_at,body}`

The `body` is closed except for registered `extensions`. A configuration mutation
uses `message_type:"config.update"` and this exact `factory.v1` body shape:

`{schema_version:"factory.v1",operation_id:ID|null,idempotency_key:ID,expected_generation:UInt,scope:"factory-control"|"project:<ID>",project_id:ID|null,node_id:ID|null,desired:FactoryDocument}`

`scope` is `factory-control` for a global update or `project:<project_id>` for a
project update. `project_id` is required for project scope and null for global
scope; `node_id` is null on a configuration update and is present only on the
separate M12 node-token-admin operation. `operation_id` is null on a first attempt;
when supplied on retry it must identify the already accepted operation and cannot
create a second effect. Thus the server, not the caller, allocates the operation
identity at the accepted commit. `expected_generation` is the one global
configuration generation, initially zero. There is no independent project
counter. A project editor submits the complete document with only its authorized
project changed, so the manager can reject a cross-scope edit rather than merge it.

The successful result is the same typed `factory.v1` response everywhere:

`{schema_version:"factory.v1",status:"accepted"|"ok",data:{operation_id,generation,scope,desired_digest},error:null}`

A readback uses the same `cf2a.v1` envelope and returns `State` from Part I §1.9.1:
`{desired,observed,effective,generation,status,operation_id}`. `effective` is
separate from desired and is null or degraded until the owning subsystem supplies a
fresh readback. `Error` is exactly `{code,message,retryable,field,current_generation}`;
messages are redacted and secret values never occur in requests, results, logs,
events, plans, files or desired-state backups.

The node-token endpoints in §16 use the same mTLS, envelope, idempotency and CAS
rules, but their body is `cf.node-token-admin.v1`: `operation_id`,
`idempotency_key`, `expected_generation`, `node_id`, `project_id`, `scope` and the
operation-specific fields (`ttl_s`, `delivery_target`, `token_id`, or `reason`).
They return metadata, `secretref` and receipt identifiers, never a bearer. A node
token authorizes runtime `cf.inference.v1` admission only; it cannot call this
management listener. M7 app-token issuance is a third domain: it issues forge
installation credentials and never issues node tokens, management certificates or
provider keys. M11's scoped forge credential is likewise not a proxy token.

### 19.2 Settings and typed secret references

`FactoryDocument` is the Part V `factory.v1` desired document. Its fields retain
Part V's classes: user intent is caller-editable, derived values are manager-owned,
observed/effective values are readback-only, and secret material is forbidden.
Credential-bearing fields use the typed reference object represented on the wire as
`secretref://<domain>/<name>`; the URI is a reference, not a string containing a
credential. The domain is one of the mapped authority domains in Part V §V.4
(`authority`, `forge`, `bunker`, `transport`, `model`, `memory`, `events`, or
`backup`), the name is non-empty and path-safe, and the reference is resolved only
by the owning issuer/adapter. A `secretref` is safe in desired state, API results,
diffs, events and audit records; resolved material is never returned or copied into
the `factory.v1` document. A plain secret, inline key, bearer, PEM, or environment
value in a secret field returns `422 SECRET_MATERIAL_FORBIDDEN`.

Configuration precedence is explicit and non-implicit: accepted generation and
scope update → project value → deployment/profile mapping → global default, with a
native subsystem override only when the adapter explicitly registers that mapping.
Empty and absent are distinct according to the Part V field card; neither silently
falls through to an unrelated scope. The manager does not rewrite desired intent
from observed/effective state.

### 19.3 One-writer ordering, CAS and recovery

The authoritative actor is the Factory manager's single local writer, fenced by the
independent authority in Part I §1.9.3. The configuration file is the human-readable
desired-state proposal; it is not a second writer. An authenticated file importer
reads the proposal's exact bytes and submits them through the same `config.update`
validator and `expected_generation` CAS as an API caller. The manager serializes
updates under the writer lock, validates schema, scope, cross-field constraints and
secret references, computes the canonical request digest, and then, in order:

1. Append the complete transaction containing the immutable config edition,
   generation, operation and dedupe receipt to Git-backed JSONL.
2. `fsync` the log and parent directory; update in-memory indexes only after fsync.
3. Materialize `config/generations/<generation>.json` from canonical bytes, fsync it,
   atomically rename the active pointer, and fsync the directory.
4. Return the accepted `factory.v1` result only after the journal and active
   projection are readable. Reconciliation and adapter calls begin after this
   commit; they cannot make an unaccepted setting active.

The CAS tuple is `(scope, expected_generation, principal authorization,
request_digest)`, evaluated against the one current generation while holding the
writer/fence. A successful edit advances generation exactly once. A stale
`expected_generation` returns `409 GENERATION_CONFLICT` with
`current_generation`, writes no config edition, and leaves the proposal untouched.
An identical `(principal, scope, route, idempotency_key, request_digest)` returns
the original response without advancing generation. The same key with a different
digest returns `409 IDEMPOTENCY_KEY_REUSED`. A timeout is resolved by retrying the
same idempotency identity or reading the operation; a new key is not a recovery.

A crash before the journal fsync returns no acknowledgement and the next startup
replays only the last complete newline. A crash after journal fsync but before the
active pointer is repaired by replaying the journal and atomically rebuilding the
projection. A torn final record is truncated to the last verified newline; a
middle hash/sequence error is `STORE_CORRUPT` and stops writes until a verified
checkpoint plus intact suffix is restored. Manual edits to a committed generation
are `CONFIG_TAMPERED`, never a new generation. Adapter failure after acceptance
leaves the generation durable and the operation `degraded` or `failed`; recovery
re-reads the operation and retries idempotent steps, or follows F13's fenced
rollback/forward-repair procedure. Running inference remains pinned to its admitted
policy generation unless revocation fences it; a config edit never silently
restarts a round.

### 19.4 Deterministic state table and vector

The following vector is independently checkable without a live service. Start with
current generation `17`, current canonical document digest `D17`, no pending
operation, and a valid administrator certificate `admin-7`. Each row is one request;
all fields not shown are the common `cf2a.v1` fields and valid `factory.v1` values.

| Case | Request identity and CAS | Durable precondition | Required result and next state |
|---|---|---|---|
| Success | `scope=factory-control`, `expected_generation=17`, `idempotency_key=k18`, digest `D18` | generation 17 | `202 accepted`, `operation_id=op-18`, `generation=18`; append one edition and active pointer; current document is D18 |
| Stale generation | same valid request but `expected_generation=17` after the success row | generation 18 | `409 GENERATION_CONFLICT`, `current_generation=18`; no new edition, no operation, state remains D18 |
| Duplicate idempotency | exact replay of the success row: same principal/scope/key/digest | generation 18, receipt for k18 | original `202` body with `op-18`, generation 18; append count and generation do not change |
| Reused key | same principal/scope/key `k18`, digest `D19` | generation 18, receipt for D18 | `409 IDEMPOTENCY_KEY_REUSED`; no new edition and no generation change |
| File/API race, API wins | file importer and API both read 17 and submit different digests with expected 17; API acquires writer first | generation 17 | API is the sole winner at 18; file receives `409 GENERATION_CONFLICT` with 18 and must re-read/produce a new proposal; no merge or last-writer-wins |
| File/API race, file wins | same two requests, file importer acquires writer first | generation 17 | file is the sole winner at 18; API receives `409 GENERATION_CONFLICT` with 18 and retries only with a new read plus new idempotency key or the same key if its digest is unchanged |

For every accepted row, the check is `generation=18 ∧ active_digest=D18 ∧
log_receipt=returned_receipt ∧ operation_state=accepted`; for every conflict,
`generation` and active digest remain unchanged and no adapter call is allowed.
The vector therefore checks CAS, idempotency, file/API ordering, returned
readback and the recovery rule rather than merely checking an HTTP status.

Runtime implementation of this management listener, its authority service and the
file importer remains **UNVERIFIED / TARGET-UNIMPLEMENTED**. The existing proxy
script's measured runtime node-token admission does not qualify this contract.
[Part I §1.9.1–§1.9.3; Part IV CT-24–CT-26; Part V §V.0/§V.4/§V.6;
M1.S3; M9.S4; F12; F13]

ch:trace row=P5G-05 spec=docs/handbook/chapters/M12-inference-proxy.md#19-iii-m12-s1--management-api-configuration-authority-and-authentication wave=none:serial-worker test=none:documentation-contract-readback doc=docs/handbook/chapters/M12-inference-proxy.md evidence=docs/handbook/chapters/M12-inference-proxy.md witness=none:handbook-specification-no-live-management-api verdict=none:foreman-runs-gitreins commit=none:foreman-closeout memory=none:foreman-writes
STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/chapters/M12-inference-proxy.md

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

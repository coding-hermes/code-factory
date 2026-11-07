# M12 — INFERENCE PROXY

## 1. Identity

| Field | Value |
|---|---|
| Module name | INFERENCE PROXY (`cf-inference-proxy.py`) |
| Path | `/home/kara/.hermes/scripts/cf-inference-proxy.py` (273 lines) |
| Revision | content sha256 `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` (lives outside any git repo; no git revision to stamp). Locators re-verified at code-factory HEAD `dbf810b` (this round's code-factory HEAD — the M12-C1 node-client grep evidence; the proxy file itself is outside git) |
| Language / runtime | Python — `#!/usr/bin/env python3`, no pinned version; **requires >= 3.10** (F12-5: `_forward` at `:164` declares `body: bytes \| None`, an evaluated union annotation) |
| Owner lane | code-factory (control-host service, consumed by nodes) |
| Status | **FAILING** — read in full this round (273 lines); content sha256 reproduced; live 401 admission reproduced this round; the two sink paths corrected this round (F12-8). Admission, routing and capture are VERIFIED; **streaming is FAILING (sol B22):** the healthy SSE stream is unframed to completion (`:206-224`), reproduced as a `200` with no `Content-Length`/`Transfer-Encoding`/`Connection` and a client EOF timeout (§11 F12-7). The single status word is the weaker one (FAILING, grok #10); a blanket VERIFIED would contradict the demonstrated streaming defect |

## 2. Purpose, authority and position

The only thing holding the real provider credential (CF-002: no provider key leaves the control
host). A node gets a NODE TOKEN, never a provider key, and this proxy forwards on the node's
behalf. It decides which node may call (token), which model may run (allowlist), and whether the
call is streamed through or buffered. It is a **control-host** service, not a node-local one
(F12-1).

**What breaks if this module is absent.** The node has no inference path ("the node's only
inference path", CF-351).

**What breaks if it lies.** A fail-closed admission that fails open routes an untrusted or
off-contract model to the upstream and spends the fleet's credit on a dearer model. In the settings
register, a sink path that does not exist on disk sends an operator looking at the wrong file —
round-5 shipped two invented filenames here (F12-8), which is the exact "what breaks if it lies"
failure for a paths register.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 admission | token resolution `_node` (`:115-123`), model allowlist (`:155-160`), fail-closed startup (`:265-270`) | **active** | invoked continuously by the systemd unit `~/.config/systemd/user/cf-inference-proxy.service` — loaded, enabled, `active (running)` since 2026-11-05 09:21, Main PID 2603939, drop-in `cf-inference-proxy.service.d/10-upstream.conf` (measured this round, `systemctl --user status`). The in-repo grep (`grep -rnE '8775\|CF_PROXY\|cf-inference-proxy' scripts/ config/ specs/`) finds no script/cron caller, but the invoker is the systemd unit, not absent (B2) |
| S2 upstream routing | `_forward` (`:164-180`), model rewrite via `UPSTREAM_MODEL` | **active** | `_forward` invoked by `do_GET` `:132` and `do_POST` `:162` (the request handlers under the systemd unit) |
| S3 stream pass-through | `:200-238` (streamed), `:240-258` (buffered) | **active** | the two branches of `_forward` (`:164`), reachable only through `:132`/`:162` |
| S4 usage and request capture | `capture_request` (`:83-95`), `log_usage` (`:98-101`) | **active** | `capture_request` called at `:161`; `log_usage` called at `:152, :156, :220, :227, :232, :248, :252` — all inside the `do_GET`/`do_POST`/`_forward` request path |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 (stdlib only) | **>= 3.10** (`:164` union annotation) | control host | import/syntax failure on < 3.10 |
| node token file | `TOKENS_PATH` `/home/kara/.hermes/secrets/cf-node-tokens.json` (`:48`) | control host | `FATAL: no token file … refusing to start open`, exit 2 (`:265-267`) |
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
| `TOKENS_PATH` | `/home/kara/.hermes/secrets/cf-node-tokens.json` (`:48`) | a JSON file | the node-token mapping read at request time | a missing file → `FATAL: no token file`, exit 2 (`:265-267`) |
| `ENV_PATH` | `/home/kara/.hermes/.env` (`:49`, read by `upstream_key` `:75-80`) | an env file | where the upstream key is scanned | a renamed file must match the provisioner |
| `USAGE_LOG` | `/home/kara/.hermes/logs/cf-inference-usage.jsonl` (`:50`) | a path | usage capture sink | a failing sink raises into the request path (F12-6) |
| `CAPTURE_LOG` | `/home/kara/.hermes/logs/cf-inference-requests.jsonl` (`:52`) | a path | request capture sink | capture loss is silent (F12-6) |
| upstream timeout | **300 s** (`:204`, `:241`) | seconds | `urlopen` timeout on both stream and buffered legs | a shorter timeout truncates long generations |
| `MAX_BODY` | 4 MiB (`:54`) | positive int | request body ceiling | a body `> MAX_BODY` → 400 (`:142-143`) |
| `LISTEN` | `("0.0.0.0", 8775)` (`:53`) | **a hardcoded constant, not a setting** | proxy listener | no env/flag override; binds 0.0.0.0 so the tailnet can reach it |

**F12-8 (paths, corrected this round).** Both sinks are hardcoded `pathlib.Path` constants, not
environment settings. Round-5 wrote `~/.hermes/logs/cf-usage.jsonl` (`:49`) and
`~/.hermes/logs/cf-capture.jsonl` (`:50`) — neither exists. The measured values are
`USAGE_LOG = …/cf-inference-usage.jsonl` (`:50`) and `CAPTURE_LOG = …/cf-inference-requests.jsonl`
(`:52`; `:51` is the "last 200 requests only" comment). An operator following the round-5 register
would open two files that are never written. F12-6's consequence analysis is unchanged — it was
correct and is now attached to the real paths.

**F12-3 (credential selector).** The upstream credential name is configurable
(`CF_PROXY_UPSTREAM_KEY_ENV`, `:47`), read by `upstream_key()` (`:75-80`) which scans `ENV_PATH`
for `NAME=value`. But the startup error at `:269` hardcodes `API_SERVER_KEY` in its message even
when a different name is configured — the diagnostic lies about which variable it checked.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). The proxy's own
interfaces (M12-C1, M12-C2) are not among the 18; the canonical id the proxy sits adjacent to is
CT-07 (`router → gateway` model choice), cited as a boundary contract.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-07 | gateway | in (model choice) | **external** — the task-router's model choice (out of scope) | **external** — the Hermes gateway (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured this round; an outline "works" annotation is not implementation evidence (sol B03) |
| M12-C1 | node | in | **unproven client half** — the proxy side is verified (401 on missing/unknown token, `:128-130`); the node side has no in-repo file that *calls* the proxy. `grep -rnE '8775\|CF_PROXY\|cf-inference-proxy' scripts/ config/ specs/` (ERE, re-run this round at CF HEAD `dbf810b`; the `\|` in this table cell is markdown escaping for the bare-`|` alternation actually run — the exact command is in §13) matches **four** text sites: `scripts/panel_loop.py:188` (locator re-pinned this round — round-15 cited `:145`, which is a `log = outdir / …` line), `scripts/master_doc_skeleton.py:25` and `:211` (self-references listing the path), and `config/node.env.example:22` — which is the **live assignment** `ENV_CF_PROXY_API_KEY=@~/.node/auth/provider.key`, not a comment. `config/node.env.example:26` comments `CONFIG_SET_MODEL_PROVIDER=cf-proxy -> model.provider`, so the producer half is config-driven: `node.env.example:22,26` → `node_env.py`/provisioner config generation → `~/.hermes/config.yaml` `model.provider=cf-proxy`. Round-4's quoted command omitted `-E`, so its bare-`\|` BRE returned **0** matches (measured rc 1) — the opposite of the row's claim (grok 2 / glm 4). | `cf-inference-proxy.py:135` `do_POST` → `_node` (`:136`) | **UNVERIFIED** — proxy side verified; the node-client call site is config-wired, not a `file:function` in this repo |
| M12-C2 | upstream | out | `_forward` (`:164`) builds the upstream request with the control-host key | **rumour — one side only** (the upstream gateway/provider, not a function) | **UNVERIFIED** — external boundary with one side named; a "works" verdict on a rumour is not permitted (B06) |

The round-3 M12-C1 producer cell (\"node POST /v1/chat/completions with Authorization: Bearer ***\")
was a broken table row (an unclosed code span, a `***` redaction artifact, a pipe inside the cell)
with an unnamed producer. It is replaced by the empty-grep proof above; the client half is
unproven, so the state is UNVERIFIED, not \"works\".

The CONTRACT section (`:9-19`) documents three routes — `POST /v1/chat/completions`,
`GET /v1/models`, `GET /health` (no auth) — and states: \"There is no anonymous path and no
fallback: a node that cannot authenticate cannot spend money.\" **Corrected (kimi B65):** the
\"no anonymous path\" wording is an overstatement — `GET /health` **is** unauthenticated
(`cf-inference-proxy.py:12` and the handler at `:126-127`). The true claim is \"no anonymous
*paid/model* path\": a request that reaches `_node` without a valid token is refused 401, so an
unauthenticated caller cannot spend money. There is no fallback that downgrades a refused caller
to an open path.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| content hash | `sha256sum /home/kara/.hermes/scripts/cf-inference-proxy.py` | full digest | 2026-11-07 (re-run this round) | **PASS** — `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5` |
| python compile | `python3 -m py_compile /home/kara/.hermes/scripts/cf-inference-proxy.py` | exit 0 | 2026-11-07 (re-run this round) | PASS |
| admission (no token) | `curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8775/v1/chat/completions -d '{"model":"hermes"}'` | 401 | 2026-11-07 (re-run this round) | **PASS** — 401 (proxy live on `:8775`) |
| systemd unit active | `systemctl --user status cf-inference-proxy.service` | loaded, enabled, `active (running)` | 2026-11-07 (re-run this round) | **PASS** — active since 2026-11-05 09:21, Main PID 2603939, drop-in `10-upstream.conf` |
| admission (disallowed model, valid token) | POST `{"model":"definitely-not-allowed-model"}` with a valid node token | 403 `model not permitted` | 2026-11-06 | **UNVERIFIED** — not re-run this round (the node token file was not read); a round-3 judge reproduced the 403 at `:155-160` (provenance, not this round's measured evidence) |
| admission (malformed model type) | POST `{"model":["hermes"]}` with a valid node token | a clean 400/403 refusal | not re-run this round | **UNVERIFIED — and FAILING on the branch:** `asked not in ALLOWED_MODELS` (`:155`) on a non-string `asked` raises `TypeError`, so the refusal is a connection drop, not an HTTP error. Reproduced by a judge's patched-token fixture (sol B26: `PROXY_HANDLER_EXCEPTION=TypeError`, `PROXY_NONSTRING_MODEL_HTTP=RemoteDisconnected`), not a live curl this round |

## 8. Metrics

**RED — none (absence-proved this round).** The proxy emits no counters, gauges or histograms.
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' /home/kara/.hermes/scripts/cf-inference-proxy.py`
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
| **Malformed model type (list/dict, not a string)** | the handler raises `TypeError` at `:155` — `asked = json.loads(body).get("model","")` (`:148`) accepts any JSON value and `asked not in ALLOWED_MODELS` (`:155`, a set membership) requires a hashable string, so `{"model":["hermes"]}` crashes the handler. The client sees a **connection drop** (RemoteDisconnected), no HTTP error response | a disallowed model (403) or a malformed JSON body (400) | send a string `model`; the proxy does **not** validate `asked` is a string before the membership test (sol B26) |
| Connection failure (urlopen raises before headers) | a clean 502 `upstream unreachable` (`:236-237`) | an upstream rejection | check the upstream gateway |
| Read failure after headers, before first chunk | the upstream status + headers are already sent (`:206-210`), then the proxy attempts a second 502 — the client sees `[200, 502]`, a corrupt response (F12-4) | a clean 502 | client must detect the truncated stream |
| Upstream dies mid-stream | `first` is set, the stream just ends (`:238`), **no 502** | a buffered failure | client must detect a truncated stream |
| No contract | behaviour defined only by code | a specified contract | **OPEN** — CF-351 |

## 11. Limits and margins

- Fail-closed startup: no token file or no upstream key → `sys.exit(2)` before binding (`:265-270`).
- `MAX_BODY` 4 MiB (`:54`); upstream timeout 300s (`:204`, `:241`).
- **F12-4 (streaming guarantee correction).** The round-2/round-3 claim \"a 502 is returned only
  when the failure happens before the first byte\" conflates two distinct cases (B24). The stream
  path sends the upstream status and headers first (`:206-210`), then reads chunks. If `urlopen`
  itself fails, no headers were sent and the 502 is clean. If a later read fails **before the first
  chunk**, headers were already sent, so the attempted 502 is a second status after the 200 —
  `[200, 502]`, not a valid standalone 502. If it fails **after** a chunk, the stream just ends.
- **F12-5 (interpreter constraint).** `_forward` at `:164` declares `body: bytes | None` — an
  evaluated union annotation with no `from __future__ import annotations`. This requires
  **Python >= 3.10**; \"Python 3.x, stdlib only\" was an insufficient constraint.
- **F12-6 (capture/usage failure semantics, B26).** `capture_request` (`:83-95`) truncates the raw
  body to 120000 chars and swallows every exception (`except Exception: pass`) — capture loss is
  silent. `log_usage` (`:98-101`) has **no** exception suppression, so a usage-sink failure can
  raise into the request path (`:220-238`, `:252-253`). The `CAPTURE_LOG` comment claims \"last 200
  requests only\" (`:51`) but the code appends indefinitely — no truncation or retention is
  implemented.
- **F12-7 (stream-completion defect, sol B28).** `_forward`'s streaming path (`:206-210`) sends the
  upstream status/headers but neither `Content-Length`, `Transfer-Encoding`, nor `Connection: close`,
  and returns at `:224` without marking the connection closed. A healthy upstream that finishes its
  SSE cleanly therefore leaves the downstream response unframed: a client reading to EOF times out
  even though every byte was forwarded. This is not an upstream-failure case — it is the *healthy*
  case. An independent verifier exercised the actual `Handler` against a finite local SSE upstream
  and measured `PROXY_STREAM_STATUS=200`, `CONTENT_LENGTH=None`, `TRANSFER_ENCODING=None`,
  `CONNECTION=None`, `PROXY_STREAM_EOF_COMPLETED=False: TimeoutError` (sol B24) — the reproducible
  failure to cite. **Streaming correctness is FAILING** — the framing defect is reproduced, so a
  repeatable framing/completion oracle is the missing evidence; it is a demonstrated defect, not a
  merely unverified property (sol B22).

## 12. Cross-references

- The node reaches the proxy over the tailnet via operator-configured `CF_BASE_URL`. **No direct
  client function calls the proxy from this repo** — but node *configuration* does reference it:
  `config/node.env.example:22` (`ENV_CF_PROXY_API_KEY=@~/.node/auth/provider.key`) and `:26`
  (`CONFIG_SET_MODEL_PROVIDER=cf-proxy -> model.provider`) wire the proxy as the node's provider
  (see M12-C1). Configuration evidence, actual call-site evidence, and successful live use are
  distinct; only the configuration reference is established (B25, sol).
- **M7 GITHUB does not produce the node tokens.** The proxy loads `TOKENS_PATH` (a JSON mapping,
  `:48`, `:65-72`) and compares bearer tokens against it (`:115-123`); the producer of that mapping
  is unknown (B16, M7 §12).
- The upstream key is read from `~/.hermes/.env` at request time and never logged/echoed (`:23-24`).

## 13. Evidence of record

- Code read: `cf-inference-proxy.py` (273 lines, read in full); content sha256
  `b12a0ac521c4b5a9cd7e2b76883a7edf2c9e0efd87d9bc3be3d2056d3f39e0b5`.
- Commands run: `sha256sum` (PASS); `python3 -m py_compile` (PASS); `curl` no-token → 401;
  `systemctl --user status cf-inference-proxy.service` (active, Main PID 2603939);
  `grep -rnE '8775|CF_PROXY|cf-inference-proxy' scripts/ config/ specs/` (4 text sites, node client
  config-wired); `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' <proxy>` (0 matches);
  `sed -n '49,52p'` (sink constants, F12-8).
- Board rows: CF-343, CF-346, CF-351.
- **Findings:**
  - **F12-1** (carried) — control-host service, not node-local.
  - **F12-2** (carried) — the CONTRACT section is in the code (`:9-19`), not in any spec.
  - **F12-3** — the credential selector is configurable but the startup error hardcodes
    `API_SERVER_KEY` (`:269`).
  - **F12-4** — the \"502 before first byte\" claim is corrected: headers are sent before the first
    read, so a read failure before the first chunk yields `[200, 502]`, not a standalone 502.
  - **F12-5** — Python >= 3.10 required (`:164` union annotation), not \"3.x\".
  - **F12-6** — capture loss is silent; usage-write failure is not; \"last 200 requests\" is an
    unimplemented comment.
  - **F12-7** (carried) — the healthy SSE stream is not framed to completion (no Content-Length /
    Transfer-Encoding / Connection: close), so a client reading to EOF times out even on success.
  - **F12-8** (new) — round-5 invented two sink filenames (`cf-usage.jsonl`, `cf-capture.jsonl`);
    the measured values are `cf-inference-usage.jsonl` (`:50`) and `cf-inference-requests.jsonl`
    (`:52`).
  - **F12-9** (new, glm #1) — `panel_loop.py` locator re-pinned from `:145` to `:188` (round-15's
    `:145` is a `log = outdir / …` line; the `cf-inference-proxy` reference is `:188`).
  - **F12-10** (new, sol B26) — a non-string `model` (e.g. `{"model":["hermes"]}`) escapes the
    documented 400/403 refusal: `asked not in ALLOWED_MODELS` (`:155`) raises `TypeError` on a
    list/dict, so the handler crashes and the client sees a connection drop (RemoteDisconnected),
    no HTTP error. Documented in §10 and §7; the fix (validate `asked` is a string at `:148-149`
    before the membership test) is a board row, not yet landed.

## RED field count: 3 — Metrics §8 (absence-proved); stream completion **FAILING** (F12-7
reproduced); admission malformed-model-type **FAILING** (F12-10/sol B26 — a demonstrated
`TypeError`/disconnect instead of a clean refusal). **The boundary/local contracts are not REDs.**
Uniform rule (settled this round): a contract row whose far side is an external peer — boundary
(CT-07) or a local edge with no in-repo `file:function` on the node/upstream side (M12-C1, M12-C2)
— is a **terminal** UNVERIFIED state and is not counted as a RED; only an internal contract that was
never measured, or a FAILING submodule, is a RED. The streaming defect and the malformed-model-type
crash are FAILING submodule behaviours (demonstrated code defects), so they are RED; the three
UNVERIFIED contracts are terminal.

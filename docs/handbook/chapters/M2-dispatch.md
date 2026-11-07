# M2 — DISPATCH (NODE SIDE)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCH (NODE SIDE) |
| Path | `/home/kara/code-factory/scripts/` — `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py`, `lane_target.py`, `node-bus-worker.py` |
| Revision | derivation base `9372dc0`; every file M2 cites byte-identical through document HEAD `dbf810b` (verified this round: `git diff --name-only 9372dc0..dbf810b` touches no M2-cited file — only `scripts/panel_loop.py`, `scripts/panel_supervise.sh`, `scripts/reap_orphan_writers.py`, `prompts/foreman.md`, `prompts/unblock.md`, `scripts/board_read.py`, `docs/handbook/_panel/round-9/writer.txt`, M11 — none cited here) |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side); consumes scheduler + crier |
| Status | **UNVERIFIED** — source fully accounted this round (`node-bus-worker.py` 1546 lines read; `add_family_lanes.py` 105, `configure_family.py` 201, `load_lane_config.py` 45 read in full; `lane_target.py` exercised by its 40-test suite), but the live bus-worker ladder (§7) is not repeatable from this control host, so the behavioural half stays unmeasured |

## 2. Purpose, authority and position

The node half of the bus. It decides which lanes a node declares (`add_family_lanes.py`,
`configure_family.py`), which target a run resolves to (`lane_target.py`), and how the inbox is
consumed, signed and answered (`node-bus-worker.py`). It may not decide admission — that is the
scheduler (M9).

**What breaks if this module is absent.** "Whose turn it is" never becomes a brief: no lane is
declared, no target resolved, the inbox is never consumed, and a dispatch sits unanswered until
it expires.

**What breaks if it lies.** `node-bus-worker.py` replies with an outcome; a false `ok` for a
failed run records a pass for work that never happened. The mirror-image defect on the control
side is CF-355 (a failed result with no `ok` is recorded as success).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 declare and configure lanes | `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py` | **operator-invoked** | no in-repo production caller — `grep -rn 'add_family_lanes\|configure_family\|load_lane_config' scripts/` matches only the three files' own docstrings (`add_family_lanes.py:2`, `configure_family.py:2`, `load_lane_config.py:2`), a comment in `handbook_spine.py:69` (names `load_lane_config.py` as the CT-05 producer), and three `.pyc` artifacts under `scripts/__pycache__/` (run this round; glm #5). None is a caller. `configure_family.py:24-28` reads the scheduler operator token at module import |
| S2 resolve a target | `lane_target.py` | **active** | `scripts/configure_family.py:17` imports it and `:149` calls `lane_target.parse(workdir)` then branches on the result — a production caller **in-repo** (grok 3 / sol B09). Round-4's "no production caller" was false. Passing the parse does not prove a remote checkout exists (it is structural parsing, not remote verification) |
| S3 consume the inbox, sign, reply | `node-bus-worker.py` | **active (probe leg) / operator-invoked (daemon leg)** | the one in-repo invoker is `bunker-crier-connect.sh:53` (`python3 "$HOME/node-bus-worker.py" --check`); the dispatch-consumption modes (`--once`/`--loop`, `:1435`, `:1504`) have **no in-repo caller** — the worker is the node's terminal consumer, started by the operator on the node. Internal call sites (`directive_text` `:977`, `process` `:1007`, `deliver` `:1208`) prove what it does, not who invokes it (kimi B-8 re-grade, same rule as M3 S1a/S1b) |

**Finding F2-2.** `configure_family.py:24-28` hardcodes `PID = "1755676"` and reads
`/proc/<PID>/environ` at module import to extract `SCHEDULER_OPERATOR_TOKEN`, with no fallback.
Configuration fails (or mis-targets) before the chapter's "partial write" failure mode unless that
exact process is alive. The config path is non-portable until its credential acquisition contract
is established.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 | 3.x | node | `command -v python3` empty → FAIL row |
| crier bus | reachable | `http://<crier-host>:8767` | `reach:` FAIL row |
| `agent.key` + `crier.json` | present at `~/.node/` | node | `node-bus-worker.py:386-387` binds `bus_path`/`key_path`; `:608` `bad("identity", f"{ident.error}; refusing")` |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `urllib.request` | stdlib | `node-bus-worker.py:78-79` imports urllib (`urllib.error`/`urllib.request`), **not** `crier_client`; the node speaks HTTP + ed25519 signing itself | n/a (stdlib) |
| `lib.sh` / `harness-vars.sh` | this repo | shell helpers + CF_* validation on the run path | see M0 / M5 |

**4c. Service contracts** — see §6.

## 5. Settings register

`node-bus-worker.py` fixes the run-budget and inbox constants (`:81-114`) and the CLI
(`:1425-1526`):

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_MAX_TURNS` | 40 (`:113`) | 1..1000 (`:113`) | turn budget | out of range refused |
| `CF_TIMEOUT_S` | 1800 (`:114`) | 1..86400 | wall-clock per turn | out of range refused |
| `DEFAULT_INBOX_LIMIT` | 10 (`:81`) | positive int; **the bus caps a batch at 100** (`internal/registry/handler.go:1718-1731` returns 400 `max must be <= 100`) | inbox batch size | larger batches raise per-poll latency; a value >100 is refused by the bus, not the worker |
| `DEFAULT_LEASE_SECONDS` | 30 (`:82`) | positive int | lease on each retrieve | too long holds messages during a crash |
| `SEEN_LIMIT` | 200 (`:85`) | positive int | idempotency window | smaller window re-runs a redelivered dispatch |
| `--reply-to` | `"scheduler"` (`:1478-1481`) | an agent id | result recipient when the dispatch names none | a wrong default drops replies |
| `--wait-seconds` | 0 (`:1485-1486`) | 0..120 (`:1511`) | inbox long-poll budget | outside 0..120 → exit 2 (the bus answers 400 outside it) |
| `--interval` | 15 (`:1488-1489`) | positive int | seconds between `--loop` polls | 0 starves the loop |
| `--harness-wall` / `--timeout` | **1800 / 10** (`node-bus-worker.py:84` `DEFAULT_HARNESS_WALL`, `:83` `DEFAULT_TIMEOUT`; the CLI defaults at `:1491-1499` read these) | positive int | per-run wall / per-request timeout | see F2-3 for the wall fallback |

**Operational overrides (sol B08, completed this round — full read of the CLI `:1425-1526` and identity resolution `:381-415`).** The identity/credential/destination/executable selectors, previously registered NAME ONLY:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--home` | `$HOME` (`:1442-1445`) | an existing dir | the node root | a non-directory home → `FAIL  home — … is not a directory` exit 2 (`:1506-1510`) |
| `--identity` | `$HOME/.node/node.json` (`:385`) | a path | node doc (project/repo/harness) | an unreadable path is tolerated (`required=False`, `:392`) — the worker falls back to the bus doc and may mis-target |
| `--bus-identity` | `$HOME/.node/crier.json` (`:386`) | a path | bus doc (agent/project/url) | same tolerated-read rule (`:393`); a missing bus doc drops `agent`/`url` |
| `--key` | `$HOME/.node/agent.key` (`:387`) | a path | the ed25519 signing key | a missing key is a **local** refusal before any network: `bad("signing_key", "…absent…")` return 1 at `:1278-1290` — no signer, no reply, no inbox request (sol B09: round-17 said "reply unsigned or refused", which is false — the worker never reaches `signer.headers()`) |
| `--token-file` | `$HOME/.node/auth/crier.token` (`:388-390`) | a path | the bearer token | a missing token is a **local** refusal: `bad("bus_bearer", …)` return 1 at `:1291-1294`; the first network request (`GET /health`, `:1302`) is never reached, so there is no 401 (sol B09: round-17 said "401 on the inbox read", which is false) |
| `--agent` | bus doc `.agent` or node doc `.agent` (`:394-396`) | an id | which agent id is used | overrides the doc; a wrong id targets a different agent's inbox |
| `--project` | node doc `.project` or bus doc `.project` (`:397-402`) | a name | the project label | overrides the doc; cosmetic unless the harness reads it |
| `--crier` | bus doc `.url` or node doc `.bus.base` (`:403-409`) | a URL | the bus base url | trailing `/` stripped (`:409`); a wrong url means every poll 404s |
| `--workdir` | node doc `.repo.path` (`:410-411`) | a path **inside `$HOME`** | the clone to run in | **validated** — `inside_clone(args.workdir, args.home)` at `:1520-1526`; a path outside `$HOME` → `FAIL  workdir — … is not inside $HOME` exit 2 |
| `--harness-cmd` | node doc `.harness.cmd` (`:412-413`) | an argv template carrying `{prompt}` | how the directive is executed | overrides the doc; the template must contain `{prompt}` (`:1467-1471`) |
| `--gateway-port` | **10800** (`:415`, `:1472-1477`) | an int | the harness gateway port | a wrong port means the gateway probe fails |

**`load_lane_config.py` (S1, module-scope script — sol B07, added this round).** One-time lane configuration; no CLI, no flags — it runs to completion at module scope:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `SCHEDULER_DB` (env) | `~/.hermes/coding-hermes/scheduler.db` (`:13-17`) | a sqlite path | which registry the six lanes are written into | a wrong DB updates a different scheduler's projects |
| `CODE_FACTORY_ROOT` (env) | the script's parent dir (`:18`) | a path | where `prompts/<name>.md` is read from | a wrong root reads a different prompt corpus |
| `CFG` dict | 6 lanes → `(namespace, admission_mode, prompt)` (`:20-27`) | hardcoded | which lane gets which ns/mode/prompt | writes `namespace_id`, `admission_mode`, `prompt`, `prompt_mode='append'` per lane (`:33-36`) |

**`configure_family.py` (S1, module-scope script — sol B07, added this round).** Extends the lane family to the shape of `crier`/`9router`; no CLI, runs to completion:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `DB` | `~/.hermes/coding-hermes/scheduler.db` (`:19`) | a sqlite path | the family-shape read + per-lane write | a wrong DB derives from and writes to a different registry |
| `API` | `http://127.0.0.1:9090` (`:20`) | a URL | the scheduler HTTP API for create/namespace | a wrong URL makes every `POST/PUT /api/v1/projects` fail |
| `ROOT` / `HOME` | `~/code-factory` / `~` (`:21-22`) | paths | where prompt files are written | a wrong ROOT writes prompts to the wrong tree |
| `PID` | **`1755676` hardcoded** (`:24`) | a live process id | the `/proc/<PID>/environ` read of `SCHEDULER_OPERATOR_TOKEN` (`:25-28`) | no fallback: if that exact process is dead the import raises and nothing is configured (F2-2) |
| `PACE_CEILING` | per-lane seconds (`:128-138`; docs/readme/perf `604800*8`, qa/releng `21600*8`, pm `86400*8`, dogfood `259200*8`, sync `21600*8`, duckbrain `0`) | hardcoded | the `cooldown_ceiling_s` written per lane (`:184`) | a wrong ceiling changes scheduler pacing |
| `LANE_PROMPT` | base→prompt-file map (`:117-127`) | hardcoded | which `prompts/<base>.md` is copied into each lane (`:173-176`) | a missing prompt file writes an empty prompt (`:176`) |

**`add_family_lanes.py` (S1, module-scope script — sol B08, read in full this round; 105 lines).** Registers the eight code-factory lane families. It shares the `API`/`DB`/`ROOT` defaults with `configure_family.py` (same values, `:14-17`), but its credential acquisition differs: `PID` is read from `systemctl --user show -p MainPID --value coding-hermes-scheduler` (`:18-23`, fallback `"0"`), **not** hardcoded — so `add_family_lanes.py` fails closed (the `/proc/<PID>/environ` read at `:25-32` raises `FileNotFoundError` when the service is dead), unlike `configure_family.py`'s hardcoded `PID="1755676"` (F2-2). Write sequence and partial-failure behaviour: (1) `os.makedirs(workdir, exist_ok=True)` per lane (`:69`); (2) `POST /api/v1/projects` — 201 → created, 409 → `existing` (idempotent), anything else → appended to `refused` and the loop `continue`s (`:70-81`); (3) `PUT /api/v1/projects/{name}` namespace for every accepted lane (`:82`); (4) a second, independent loop does direct SQL `UPDATE projects SET parent='code-factory', admission_mode='cooldown', prompt=?, prompt_mode='append' WHERE name=?` (`:87-96`); (5) readback prints `accepted:`/`refused:` and a `family:` SELECT (`:98-104`). Partial failure is per-step, not transactional: a refused POST still receives its step-4 SQL UPDATE because step 4 iterates `LANES` again independently (only the namespace PUT is skipped by the `continue`).

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `LANES` | 8 hardcoded tuples `(name, workdir, namespace, prompt_name)` (`:50-65`) | fixed | which lane families are created | a wrong tuple creates the wrong lane family |

**`--dry-run` custody note (B08).** `--dry-run` (`node-bus-worker.py:1437-1441`, help "fetch and print the plan; run/post/ack nothing") does **not** avoid inbox custody mutation: `:1381-1385` prints `BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked ({n} message(s) leased for {lease}s and left to expire)` — the messages were already **leased** before the dry-run branch, so a dry run holds inbox messages until their lease expires. It skips execution/post/ack, not the lease. The dry-run lease is **5 s** (`:1312` `lease = 5 if args.dry_run else args.lease_seconds`), not the configured `--lease-seconds` — a dry run holds each retrieved message for 5 s, distinct from a real run's lease.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in (inbox) | crier `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `scripts/node-bus-worker.py:1007` `process` consumes one dispatch (decodes `text_b64` first via `directive_text` `:977`, then the legacy plain members for older senders) | **works** — CF-354 fixed in commit `1f1c0fe` (decodes `text_b64`), board-closed in commit `6184e52` (F2-5) |
| CT-04 | crier | out (reply) | `scripts/node-bus-worker.py:1208` `deliver` sends the reply built inside `process` (`:1007`; dict at `:1176-1192`) — POST `/agents/{target}/inbox` | crier `internal/registry/handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport, default recipient policy)** — crier accepts the reply verbatim. CF-355 is **this reply's** settlement defect: the node sends `status` (`:1180`), the scheduler's `dispatchReplyVerdict` reads only `ok` — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-09 | duckbrain | out | **missing** — no in-repo producer: `grep -n 'duckbrain' scripts/node-bus-worker.py` → 0 matches, `grep -n '/api/memories' scripts/node-bus-worker.py` → 0 matches; the node's R1/R2 duckbrain sync is not implemented in the node worker | **external** — the duckbrain service (out of scope) | **missing** — OUTLINE Part IV marks `node → duckbrain` missing; no in-repo file on either side |
| CT-11 | sessionstore | out | **external** — the Hermes agent runtime records turns to its own `state.db` (out of scope; not a code-factory script) | **external** — the Hermes session store (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured this round; "works" is not asserted without a measured observation |

The real reply fields are `env_version, dispatch_id, corr_id, status, host_identity, harness,
vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at`
(`node-bus-worker.py:1176-1192`) — there is no `run_id`/`outcome` field (the OUTLINE §IV reply
shape is stale). CT-09 and CT-11 are boundary contracts: their far side is a service outside
the five covered systems, so the covered side is named and the far side is honestly marked
external. The state for a boundary contract with no measured wire is **UNVERIFIED** — an outline
"works" annotation is not implementation evidence (sol B03).

**Operational contract (sol B05, added this round).** Field compatibility is not the whole contract. The measured run loop (read this round) is: retrieve one batch under a lease (`DEFAULT_LEASE_SECONDS=30`; dry-run 5 s, `:1312`) → per message decode `text_b64` (`:1357-1358`) → `process` executes (`:1374`) → `deliver` each result to `reply_to` (`:1389-1392`) → write the seen-cache only after *that* result's delivery succeeded (`:1394-1395`) → `save_seen` (failure only warns, `:1397-1403`) → ack last, only when the whole batch delivered (`:1407-1414`). Idempotency is the seen-cache (key `dispatch_key`, window `SEEN_LIMIT=200`), which deduplicates **across** batches only — two same-key messages in one batch both execute (§11). A crash between execution and delivery leaves the message unacked, so redelivery re-runs and the seen-cache makes that idempotent only when the cache survived. Timing: each `request` carries `timeout=args.timeout` (default 10 s) or `max(timeout, wait_seconds+timeout)` for a long poll (`:1321`). Refusal semantics: an undecodable `text_b64` (`:1022-1034`) or a `brief.digest` mismatch (`:1044-1052`) is refused with a named row and the message left unacked, before any network work (§10).

**Protected service delivery (sol B01, corrected this round).** The node's `deliver()` sends a body of
`{"payload": result}` only (`node-bus-worker.py:1208-1215`); `Signer.headers()` (`:328-343`) supplies
`X-Agent-ID`, `X-Agent-Ts`, `X-Agent-Body-SHA256` (body binding) and `X-Agent-Sig` (a signed sender),
but **not** a body `sender` field, an `idempotency_key`, or an audience header. Crier's
`authorizeServiceDelivery` (`internal/registry/handler.go:1147`) gates a service recipient *before*
body decoding; for a **protected** recipient (`service_auth.go:128-168`) it requires a signed
`X-Agent-ID` sender (`:134-136`), a body `sender` equal to that header (`:149-151`), a nonempty
`idempotency_key` when a service audience is configured (`:153-155`), a matching `X-Crier-Audience`
header (`HeaderServiceAudience`, `service_auth.go:35`; checked at `:157-161`), and an allowlisted
sender→recipient pair (`:166-168`). The node's reply supplies the signed sender and the body digest
but none of the body-`sender`, `idempotency_key` or audience requirements, so the CT-04 "works
(transport)" state is scoped to the **default (unprotected) recipient policy**; against a protected
service recipient the node's reply as constructed would be refused (403 body-sender, or 401
audience). Whether the live relay enables protection is not established from this repo — the state
word is scoped, not a claim that a protected delivery passes.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/add_family_lanes.py scripts/configure_family.py scripts/load_lane_config.py scripts/lane_target.py scripts/node-bus-worker.py` | exit 0 | 2026-11-06, rev `dbf810b` | PASS (rc 0) |
| lane target unit | `python3 tests/test_lane_target.py` | pass | 2026-11-06, rev `dbf810b` | **PASS** (Ran 40 tests, OK) |
| bus worker ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox GET → 200 with key+bearer | 2026-11-05, cf-node only | **UNVERIFIED** — a single-host 2026-11-05 run (FACT-04) is provenance, not this round's measured result; not repeatable from this control host (`~/node-bus-worker.py` does not exist here) |

## 8. Metrics

**RED — none (absence-proved this round).** The node-side dispatch path emits no counters or
gauges. `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics'
scripts/node-bus-worker.py scripts/lane_target.py scripts/configure_family.py
scripts/add_family_lanes.py scripts/load_lane_config.py` → 0 matches (re-run this round). Dispatch
count, reply latency and refusal count are answerable only by grepping the bus worker log.

## 9. Log lines (verbatim)

The worker does **not** source `lib.sh` — it is Python. It re-implements `lib.sh`'s row
vocabulary locally at `node-bus-worker.py:129-141` (`def ok` `:129` prints `  PASS  {name} — {value}`,
`def bad` `:133` → `  FAIL …`, `def warn` `:137` → `  WARN …`, `def note` `:141` → `  ..    …`), a
copy that can drift (the reason M0 F0-4 matters). **Scope (B09, re-measured this round):**
`grep -cE '^\s*(ok|bad|warn|note)\(' scripts/node-bus-worker.py` = **70** call sites. **Counted, not
enumerated — schema exemption (deepseek B4):** the 70 sites emit one of four local templates
(`  PASS  {name} — {value}` etc., `:129-141`) with a runtime measurement name in `{name}`; the name
is data interpolated into the template, not a distinct operator-visible string, so enumerating 70
labels adds no operator knowledge beyond the template and is padding (grok B8). The template is row
1 below; the remaining rows are the evidentiary refusals, which name the rule. This exemption is
the writer's argument under OUTLINE Part VII.3's "absence proved" rule; if the panel rejects it,
the field is RED.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`node-bus-worker.py:129,133`) | every measurement row | descriptive (same rule as M0 F0-4) |
| — | `  FAIL  identity — …; refusing` (`:608`) | unparseable/absent identity | evidentiary |
| — | `inbox — GET /agents/cf-node/inbox/stats -> 200` | a valid signed inbox read (FACT-04) | evidentiary |
| — | `  FAIL  brief_digest — {label} brief.digest {expected[:16]}… != sha256(text) {actual[:16]}… — the brief was altered in flight; refused, not run` (`node-bus-worker.py:1050-1052`) | dispatch digest != sha256(text) | evidentiary — a brief.digest mismatch is refused, not warned |
| — | `BUS WORKER: IDLE` (`node-bus-worker.py:1349`) | no messages in the retrieved batch | **evidentiary** — the empty-inbox terminal (sol B04: these terminal lines were missing from the §9 inventory) |
| — | `BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked ({n} message(s) leased for {lease}s and left to expire)` (`:1384-1385`) | `--dry-run` | **evidentiary** — the dry-run terminal, distinct from `IDLE` |
| — | `BUS WORKER: OK` / `BUS WORKER: FAIL` (`:1419`, `:1421`) | terminal — `all_ok and delivered_ok and acked_ok` / otherwise | **evidentiary** — the run outcome row |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `text_b64` undecodable | node refuses: "`text_b64` does not decode to UTF-8 text" (`:1022-1034`), no silent fallback to another member | a malformed dispatch | **resolved** — CF-354 (complete): the node decodes `text_b64` first and refuses a non-decoding value rather than reading a different member |
| Failed result recorded as success | scheduler pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (control-plane half, M9) |
| `configure_family` PID hardcode | config fails at import unless PID 1755676 is alive | a live scheduler | **OPEN** — F2-2 |
| `configure_family` partial write | one lane configured, fifteen fail, exit 0 | a full failure | **OPEN** — CF-356 |
| Un-FK-checked clone namespace | a cloned lane's workdir may not exist | a validated clone | **OPEN** — CF-358 |
| Seen-cache not persisted | `could not record the seen-cache` (`:1402`) | a durable idempotency window | a redelivery after a crash re-runs — the cache write failure only warns |
| Reply to a protected recipient | `POST /agents/{target}/inbox -> 403` | an unauthenticated read | the node's reply body carries no `sender`/`idempotency_key`; a protected service recipient requires them (`service_auth.go:128-168`) — see §6 |

## 11. Limits and margins

- The node refuses a dispatch without a `text` directive (`:1036-1042`) and a `brief.digest` mismatch
  (`:1044-1052`, emitter `:1050-1052`), before any network work.
- **`dispatch_wall` correction (F2-3).** `node-bus-worker.py:1200-1205` accepts a numeric value
  only when `0 < wall <= 86400` and returns `int(wall)`; otherwise it falls back to
  `args.harness_wall` or `DEFAULT_HARNESS_WALL`. It does **not** clamp: a fractional positive below
  1 is converted by `int()` to **0** (not refused), and an out-of-range value falls back rather
  than being bounded.
- **Settlement ordering (B10, read this round).** `node-bus-worker.py:1389-1422`: execute
  (`process`) → deliver each result → write the seen-cache **only after delivery succeeds**
  (`seen[key] = result` when `delivered_ok`, `:1394-1395`) → ack last. `save_seen` failure only
  warns (`:1398-1403`), so a crash before persistence is not covered by durable replay; ack is
  skipped when delivery failed, "so redelivery is the safer outcome" (`:1407-1414`).
- **Same-batch duplicate (B10 correction, sol B10).** `node-bus-worker.py:1355-1379` processes every
  leased message in a batch using the *same initially loaded* `seen` dictionary; the cache is not
  updated until the later delivery loop (`:1389-1395`). Two previously-unseen messages sharing one
  dispatch key in a single retrieved batch therefore **both execute** before either result enters the
  cache. The idempotency window only deduplicates across batches, not within one. Round-4's
  "crash-before-persistence" discussion missed this same-batch case.
- **Failed delivery blocks later successful results from the seen-cache (sol B10, read this round).**
  `node-bus-worker.py:1389-1395` uses a **cumulative** `delivered_ok` flag: `delivered_ok =
  deliver(…) and delivered_ok` (`:1392`), and `seen[key] = result` only `if delivered_ok and key`
  (`:1394-1395`). Once one deliver fails, `delivered_ok` is permanently false for the rest of the
  batch, so a *later* successful deliver still executes but its result is **not** inserted into the
  seen-cache. Consequence: a redelivered batch re-runs that later result a second time, because its
  first (successful) delivery left no cache entry. The window is distinct from the same-batch
  duplicate above: there the cause is a shared pre-loaded `seen`, here it is a shared delivery flag.
  A code fix would gate caching on per-result delivery success and the batch ack on a separate
  aggregate (filed as F2-7, not fixed this round).

## 12. Cross-references

- F1 DISPATCH AND SETTLEMENT is the primary flow; the node is the terminal actor — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING).
- M9 SCHEDULER is the producer of the CT-03 envelope (CT-02 on its side) and the settlement consumer of CT-04's reply (`dispatchReplyVerdict` reads the node's reply).
- M11 DISPATCHER is the *other* inbox consumer, which **also** decodes `text_b64`
  (`dispatcher.py:142-150`). The two consumers now agree on `text_b64`; CF-354 (the mismatch) is
  fixed and closed.
- **M5 HARNESS owns the CF_* variable contract (M5.S5 `harness-vars.sh`),** not M0 — see M0 §12
  and M5 §5. The node passes the CF_* set to the harness at run time.

## 13. Evidence of record

- Code read: `node-bus-worker.py:60-129, 381-415, 386-392, 977-1010, 1176-1215, 1200-1205, 1389-1422, 1425-1526`.
- `docs/UNIT-MAP.yaml:78-102` (M2 S1–S3); `_facts.md` FACT-03/FACT-04.
- Board rows: CF-354, CF-355, CF-356, CF-358, CF-359.
- **Findings:**
  - **F2-1** (carried) — the node imports `urllib` (`:66-78`), not `crier_client`.
  - **F2-2** — `configure_family.py:24-28` hardcodes PID `1755676` and reads its environ at import.
  - **F2-3** — `dispatch_wall` does not clamp; it accepts-then-int-converts or falls back.
  - **F2-4** (corrected) — round-4 said `add_family_lanes.py`/`configure_family.py`/
    `load_lane_config.py` **and** `lane_target.py` have no in-repo production caller. The S1 trio's
    "no caller" holds, but `lane_target.py` (S2) **does** have one: `configure_family.py:17,149`.
    S1 activation remains operator/fleet-config invoked; S2 is active via `configure_family.py`.
  - **F2-5** (new) — CF-354 was the node reading `text` while the scheduler sent `text_b64`. The
    node now decodes `text_b64` first (`directive_text`, `:989-999`) and falls back to the legacy
    plain members for older senders. The contract state moved from broken to works; CF-354 is
    `complete` on the board (closed in commit `6184e52`). CF-355 (reply `status` vs `ok`) remains
    open.
  - **F2-6** (new, kimi B-8) — S3's "active" classification cited internal call sites; the only
    in-repo invoker is `bunker-crier-connect.sh:53` (`--check` probe). The daemon leg
    (`--once`/`--loop`) is operator-invoked. Re-graded to split the two legs.
  - **F2-7** (new, sol B10) — the cumulative `delivered_ok` flag at `node-bus-worker.py:1389-1395`
    means one failed delivery blocks later successful results from the seen-cache, re-opening the
    duplicate-execution window on redelivery (§11). A code fix would gate caching on per-result
    delivery success and the batch ack on a separate aggregate; not fixed this round.

## RED field count: 3. §8 Metrics — RED, absence-proved. §7 live bus-worker ladder — RED, not-measured (needs a live cf-node). §6 (Contracts in and out) — RED, not-measured: CT-09 (missing producer, wire absent) and CT-11 (external session store, wire unmeasured) stay missing/UNVERIFIED, not "works". Boundary/missing contract states are RED under the single acceptance rule (OUTLINE Part VII.3), not exemptions — see manifest CROSS-SECTION DEPENDENCY on settling that rule document-wide (M4 reads "terminal, not RED") and on the §9-exemption ruling. §5 now registers the worker CLI and all three S1 lane-configuration units (`add_family_lanes.py` read in full this round — sol B08); §9 tabulates the four BUS WORKER terminal forms (`IDLE`, `DRY RUN`, `OK`, `FAIL`) in addition to the counted-not-enumerated 70 helper sites.

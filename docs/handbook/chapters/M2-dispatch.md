# M2 — DISPATCH (NODE SIDE)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCH (NODE SIDE) |
| Path | `~/code-factory/scripts/` — `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py`, `lane_target.py`, `node-bus-worker.py` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; every file M2 cites is byte-identical since `47d68b4`) |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side); consumes scheduler + crier |
| Status | **VERIFIED** for `node-bus-worker.py` contracts (imports `:66-78`, `text_b64` decode `:989-999`, reply shape `:1176-1192`, settlement `:1389-1422`, CLI `:1425-1499`, `dispatch_wall` `:1200-1205`); `add_family_lanes.py`/`configure_family.py`/`load_lane_config.py` structure-mapped only |

## 2. Purpose, authority and position

The node half of the bus. It decides which lanes a node declares (`add_family_lanes.py`,
`configure_family.py`), which target a run resolves to (`lane_target.py`), and how the inbox is
consumed, signed and answered (`node-bus-worker.py`). It may not decide admission — that is the
scheduler (M9).

**What breaks if this module is absent.** "Whose turn it is" never becomes a brief: no lane is
declared, no target resolved, the inbox is never consumed, and a dispatch sits unanswered until
it expires.

**What breaks if it lies.** `node-bus-worker.py` replies with an outcome; a false `ok` for a
failed run records a pass for work that never happened (`ok` stays the verdict carrier under
CF-355). The mirror-image defect on the control side was CF-355 (a failed result with no `ok`
used to be recorded as success); the shipped scheduler law refuses it — a result with neither
a boolean `ok` nor a recognised `status` is refused, contradictions are refused, and
`status: "failed"` with no `ok` is recorded as a FAIL (`dispatchReplyVerdict`,
`internal/scheduler/dispatch_leg.go:742-776`).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 declare and configure lanes | `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py` | **operator-invoked** | no in-repo caller — `grep -rn 'add_family_lanes\|configure_family\|load_lane_config' scripts/` matches only the files themselves. `load_lane_config.py` is read-only by default and prints the six proposed updates; `--apply` is required to write and `--dry-run` is always read-only. `configure_family.py:24-28` reads the scheduler operator token at module import |
| S2 resolve a target | `lane_target.py` | **active** | `scripts/configure_family.py:17` imports it and `:149` calls `lane_target.parse(workdir)` then branches on the result — a production caller **in-repo** (3 / B09). An earlier citation of "no production caller" was false. Passing the parse does not prove a remote checkout exists (it is structural parsing, not remote verification) |
| S3 consume the inbox, sign, reply | `node-bus-worker.py` | **active** | decodes the directive (`directive_text`, `:977`), consumes one dispatch (`process`, `:1007`), builds the reply (`:1176-1192`), delivers (`:1208`), settles (`:1389-1422`) |

**III.M2.S2 — CF-306.** Bunker `plan` and `verify --exec-bunker` check
`client_identity`: `bunker info` must name the requested agent and the selected
server, before an exec probe or plan target. An explicit `--path` does not bypass
this check. The client is pinned by `--bunker-bin PATH`, then `BUNKER_BIN`; if
neither is supplied the check refuses as unpinned. The pin is resolved with
`realpath`, must be an executable regular file, and the same pinned path is used
for both `info` and `exec`; its realpath and SHA-256 are recorded in the check
value. `scan --exec-bunker` forwards the flag, server, and pin through `verify`
so bunker rows are actually probed. `--allow-remote` still permits
structural-only results when exec probing is not requested.
`plan` probes `/` and does not establish that the proposed repository exists.

**III.M2.S2 — CF-305.** `repo-url --row` compares each non-sync satellite against
the row bearing its primary's full name, including a primary that itself ends in
a satellite suffix. A row can participate in both its parent and child families;
duplicate names are rejected as ambiguous. Sync leaves remain independent of
their siblings. Comparable values are checked even when a root is invalid, while
the root's own failure remains. An absent primary retains the existing
lexicographic fallback. `tests/test_lane_target.py` exercises aligned and diverged
ordinary and suffix-named primaries, nested families, duplicate names, invalid
roots, and sync independence. A read-only scheduler census on 2026-11-10 found
881 rows and 174 previously missed pairs: 174 comparable, 173 differing and all
173 reported by the updated checker. This is not evidence that those roots exist.

<!-- ch:trace row=CF-305 spec=docs/handbook/chapters/M2-dispatch.md wave=none:serial test=tests/test_lane_target.py doc=docs/handbook/chapters/M2-dispatch.md prompt=none:external-brief evidence=none:pending-foreman witness=none:pending-foreman verdict=none:pending-judge commit=none:pending-commit memory=none:pending-foreman -->

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
| `urllib.request` | stdlib | `node-bus-worker.py:66-78` imports urllib, **not** `crier_client`; the node speaks HTTP + ed25519 signing itself | n/a (stdlib) |
| `lib.sh` / `harness-vars.sh` | this repo | shell helpers + CF_* validation on the run path | see M0 / M5 |

**4c. Service contracts** — see §6.

## 5. Settings register

`node-bus-worker.py` fixes the run-budget and inbox constants (`:81-114`) and the CLI
(`:1425-1499`):

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_MAX_TURNS` | 40 (`:113`) | 1..1000 (`:113`) | turn budget | out of range refused |
| `CF_TIMEOUT_S` | 1800 (`:114`) | 1..86400 | wall-clock per turn | out of range refused |
| `DEFAULT_INBOX_LIMIT` | 10 (`:81`) | positive int; **the bus caps a batch at 100** (`internal/registry/handler.go:1718-1731` returns 400 `max must be <= 100`) | inbox batch size | larger batches raise per-poll latency; a value >100 is refused by the bus, not the worker |
| `DEFAULT_LEASE_SECONDS` | 30 (`:82`) | positive int | lease on each retrieve | too long holds messages during a crash |
| `SEEN_LIMIT` | 200 (`:85`) | positive int | idempotency window | smaller window re-runs a redelivered dispatch |
| `--reply-to` | `"scheduler"` (`:1479-1480`) | an agent id | result recipient when the dispatch names none | a wrong default drops replies |
| `--wait-seconds` | 0 (`:1486`) | 0..120 (`:1511`) | inbox long-poll budget | outside 0..120 → exit 2 ("the bus answers 400 outside it") |
| `--interval` | 15 (`:1489`) | positive int | seconds between `--loop` polls | 0 starves the loop |
| `--harness-wall` / `--timeout` | **1800 / 10** (`node-bus-worker.py:84` `DEFAULT_HARNESS_WALL`, `:83` `DEFAULT_TIMEOUT`; the CLI defaults at `:1491-1499` read these) | positive int | per-run wall / per-request timeout | see F2-3 for the wall fallback |
| `--stall-s` | 300 seconds | integer >= 0 | maximum interval without harness output or process-tree CPU progress | too low kills slow runs without observable progress; 0 disables the detector and restores waiting until the wall |

**`--dry-run` custody note (B08).** `--dry-run` (`node-bus-worker.py:1437-1441`, help "fetch and print the plan; run/post/ack nothing") does **not** avoid inbox custody mutation: `:1381-1385` prints `BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked ({n} message(s) leased for {lease}s and left to expire)` — the messages were already **leased** before the dry-run branch, so a dry run holds inbox messages until their lease expires. It skips execution/post/ack, not the lease. The dry-run lease is **5 s** (`:1312` `lease = 5 if args.dry_run else args.lease_seconds`), not the configured `--lease-seconds` — a dry run holds each retrieved message for 5 s, distinct from a real run's lease. Unregistered operational overrides: `--home`, `--identity`, `--bus-identity`, `--key`, `--token-file`, `--agent`, `--project`, `--crier`, `--workdir`, `--harness-cmd`, `--gateway-port` (`:1443-1476`) — these select identity/credentials/destination/executable template but are registered **NAME ONLY** (default/validation/consequence not individually stated), a named RED on this field, not a completed register.

## 6. Contracts in and out

Canonical IDs come from the 31-entry Part IV §IV.2.4 registry. The table below is historical implementation coverage, not cf2a.v1 qualification. Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in (inbox) | crier `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `scripts/node-bus-worker.py:1007` `process` consumes one dispatch (decodes `text_b64` first via `directive_text` `:977`, then the legacy plain members for older senders) | **works** — CF-354 fixed in commit `1f1c0fe` (decodes `text_b64`), board-closed in commit `6184e52` (F2-5) |
| CT-04 | crier | out (reply) | `scripts/node-bus-worker.py:1176` builds `{status:"failed"/"completed", dispatch_id, corr_id, …}` (`:1176-1192`) and `:1208` `deliver()` POSTs it to `/agents/{target}/inbox` | crier `internal/registry/handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport)** — crier accepts the reply verbatim. CF-355 was **this reply's** settlement defect: the node sends `status` (`:1180`), and the scheduler's `dispatchReplyVerdict` once read only `ok` — the shipped CF-355 law reads `ok` and validates `status` against it, so a `status:"failed"` reply with no `ok` settles as a FAIL and silence is refused (`internal/scheduler/dispatch_leg.go:742-776`) — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-09 | duckbrain | out | `scripts/node-bus-worker.py:1398` `memory_record` → `DuckBrainClient` → `export_records` (writes R1 to the project namespace, then R2 to the shared `factory` namespace, each with exact-key readback; fail-closed `UNVERIFIED` on transport error) | **external** — the duckbrain service (out of scope) | **works (hermetic)** — implemented in commit `d773480e` (CF-330 seam, closes CF-316 with it): `tests/test_harness_memory.py` 7 passed / 19 subtests (R1-then-R2 order, FAIL outcome on killed run, namespace refusal before write) and `tests/harness-conformance.sh --memory-only` PASS (61/0/10 — skips are live-DuckBrain legs, so the live-node leg stays UNVERIFIED); OUTLINE Part IV's `node → duckbrain` **missing** entry is superseded by this row |
| CT-11 | sessionstore | out | **external** — the Hermes agent runtime records turns to its own `state.db` (out of scope; not a code-factory script) | **external** — the Hermes session store (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured; "works" is not asserted without a measured observation |

Result replies carry `env_version, dispatch_id, corr_id, in_reply_to, run_id, missing, status,
ok, reply_b64, host_identity, harness, vars, exit_codes, gate_exit, branch, commit, artifacts,
wall_s, finished_at`, with `error` when failed. Refusals carry the available identity, `ok=false`,
`error`, `refused_by`, `refusal` and a `missing` array; a missing identity triggers the named
`envelope` refusal. `in_reply_to` is the scheduler's PRIMARY key. No plain member carries
dispatch text: a verbatim echo — a failing gate's `cmd`, a rejected `vars` value — matches the
relay's control-key pre-match and the reply refuses itself (`403 GUARD_BLOCKED`, dispatch unacked,
the tick never settles, CF-131), so the plain `error`/`refusal` members name dispatch-controlled
input by bounded identity (length + sha256 prefix, `specs/ENVELOPE.md` §Reserved field names),
the verbatim text rides in base64 `reply_b64`, and `deliver()` declines to POST a body carrying
the guard's shapes (named `guard` row). CT-09 and CT-11 are boundary
contracts: their far side is a service outside
the five covered systems, so the covered side is named and the far side is honestly marked
external. The state for a boundary contract with no measured wire is **UNVERIFIED** — an outline
"works" annotation is not implementation evidence (B03).

### III.M2.S3 — Result attribution (CF-133)

The node logs the effective stall bound before launch. Unlike the wall, this is the line
between waiting and an apparently hung harness: output bytes or process-tree CPU progress
reset it. On expiry it terminates the process group and emits `stalled: no harness output and
no CPU progress for Ns — the upstream may have accepted the request and produced nothing;
killed at Es (wall limit Ws)`. This is a diagnosis, not proof of what the upstream did.
The result carries `status="failed"` and `error`; the R1/R2 memory export carries the same
stall error when configured and successful, otherwise the result reports `UNVERIFIED`.
`once()` returns 1 for the failed run. This export is not proof of a Hermes session-store write.

The result builder identifies the hand-out with `dispatch_id`, `corr_id` and `in_reply_to`,
classifies the run with `status`/`ok`, and records `host_identity` from the node worker's own
`socket.gethostname()`. Its `harness` object carries the configured harness `name`,
`model_requested`, `served_model` and `served_model_source`. `model_requested` is the dispatched
`CF_MODEL`, or JSON `null` if none was requested. The worker accepts an observation only from a
captured stdout or stderr line `CF-HARNESS-SERVED-MODEL: <model>` emitted by the harness; this
channel is outside the scrubbed `CF_*` environment and carries no credential. An explicit report
sets `served_model` to that reported value and source to `harness_report`. Without one, including
when duplicate report lines conflict, `served_model` is JSON `null` and source is `unobserved`.
The worker never promotes the requested value, a route or a default to a served-model observation.
These fields are present on completed, failed and refused results. The regression arm
`tests/test_bus_result_delivery.py::BusResultDeliveryTest::test_a8_observed_different_model_is_not_misattributed`
proves that a harness-reported model differing from `CF_MODEL` stays distinct; the adjacent A9 arm
proves the explicit unobserved marker. The scheduler-side `correlateDispatchReply` implementation
and its contract test remain outside this repository.

### III.M2.S4 — Result, error and settlement vocabulary (P5G-17)

Board row P5G-17 asks what a dispatch result IS: who emits it, what shape it takes, the order it
settles in, what failure means, and how redelivery is bounded. This subsection is the
specification answer, derived from the shipped sources measured at code-factory commit
`4ba54126`: the code surface is `scripts/node-bus-worker.py` (every bare `file:line` below is
that file at this commit), and the spec surfaces are `specs/ENVELOPE.md` (§Result, §Correlation
semantics, §Durable delivery, §Ack after delivery, §Correlation and idempotency) and
`specs/TRACE.md` (§2 ladder, §3 propagation). The scheduler-side consumer
(`dispatchReplyVerdict`) is outside this tree and pinned by the consumer-pin arm of
`tests/test_bus_result_delivery.py`.

Actor: The executing node's bus worker, and only it. `scripts/node-bus-worker.py` builds every
result: `refusal()` (:1274) for a dispatch the node will not execute, the terminal builder
inside `process()` (:1779-1813) once harness and gate have a terminal outcome, and `deliver()`
(:1839) posts it to the inbox the dispatch names in `reply_to`. The harness never mints a
result; the scheduler only reads one.

Data shape: A terminal result carries `env_version, dispatch_id, corr_id, in_reply_to, run_id,
missing, status, ok, reply_b64, host_identity, harness{name, model_requested, served_model,
served_model_source}, vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s,
finished_at`, plus `error` when failed (:1779-1818); refusals carry the same identity block
plus `status:"refused"`, `ok:false`, `error`, `refused_by` and `refusal` (:1288-1308). `run_id`
is resolved by `run_identity()` (:1252) as `dispatch.run_id` or `dispatch.vars.CF_RUN_ID`,
never `corr_id` (`specs/TRACE.md` ladder rule 1). Failure reasons have two shipped spellings:
the plaintext `error` names dispatch-controlled input by bounded identity — a failing gate's
`cmd` becomes length + sha256 prefix (`bounded_text()` :183, used at :1759) — and the verbatim
node words travel base64 in `reply_b64` (`result_reply()` :1026, `REPLY_MAX_CHARS` 4000). That
split is the CF-131 guard contract (`specs/ENVELOPE.md` §Reserved field names).

Ordering: Delivery before ack, per message. The result envelope is POSTed; only an accepted
delivery (200/201, :1902-1914) puts that message id on the ackable list, and the ack loop runs
last (:2096-2128) — one failed delivery must not leave an unrelated message unacked.
Correlation is identity-ordered, never arrival-ordered: the scheduler matches `in_reply_to`
first (the relay message id, PRIMARY key), then `corr_id`, then the original dispatch echoed
inside `task`; a result naming neither key never completes a tick (`specs/ENVELOPE.md`
§Correlation semantics; arm A4). Node-side, the result is recorded in the seen-cache at
execution time — before any delivery is attempted (key from `dispatch_key()` :1005, check at
:1548) — so a redelivery re-sends the recorded result instead of re-running the harness
(arm A5).

Failure behavior: `ok` is the verdict the scheduler reads (CF-211), and the shipped CF-355 law
(`dispatchReplyVerdict`, `internal/scheduler/dispatch_leg.go:742-776`; refusal arms
`internal/scheduler/dispatch_verdict_test.go:42-47`) never reads absence as success: a reply
carrying neither a boolean `ok` nor a recognised `status` is REFUSED, `status` may not
contradict `ok` (`ok:true` + `status:"failed"/"refused"` and `ok:false` +
`status:"completed"` are named refusals; `status:"completed"` without `ok` is refused), and
`status:"failed"/"refused"` without `ok` is recorded as a FAIL with the reason (decoded
`error_b64`, then plain `error`, then a named default). The node's own side is unchanged: the
shipped coupling `"ok": not failed_status` (:1793) — `failed_status` = harness exit ≠ 0, a
gate that could not run, or a gate exit ≠ `gate.expect_exit` (:1749-1767) — puts an explicit,
contradiction-free verdict on every reply, so no node result reaches the refusal arms; a gate
that could not run is a FAILED result, never a completed tick on work nobody gated (arm A7).
A harness that could not run is classified failed (`status` :1705,
`ok` :1706, `error` :1707) while retaining the refusal builder's `refused_by`/`refusal`
diagnostics. A delivery body matching the relay guard's control-key shapes is never posted at
all (`guard_match` tripwire, :1885-1894): the dispatch stays unacked rather than looping a
reply that refuses itself (CF-131). A failed memory export is recorded on the result as an
`UNVERIFIED` note and never upgraded to a successful write (:1819-1824).

Recovery rule: At-least-once delivery of the result with exactly-once STORAGE of it — never
exactly-once execution. A repeated `dispatch_key` returns the recorded result verbatim
(:1548-1553); `delivery_key()` (:1011) derives the relay idempotency key as
`<dispatch_key>:result` from the dispatch alone, capped at `IDEMPOTENCY_KEY_MAX` 128 (:122),
so a retry inside the relay dedup window (`CR_IDEMPOTENCY_WINDOW_S`, 24 h default) is answered
with the FIRST accept and stores nothing new (arm A6). Failures are delivered and then acked
like any result — withholding the ack would only loop the work (`specs/ENVELOPE.md` §Result).
`deliver()` refuses to emit a non-refusal result missing any of
`in_reply_to`/`corr_id`/`run_id` (:1860-1868), per `specs/ENVELOPE.md` §Correlation and
idempotency.

The settlement state table is the deterministic artifact; every row cites the shipped builder
or test arm it comes from:

| # | Dispatch state | Result `status` | `ok` | Required reason members | Delivered | Dispatch acked |
|---|---|---|---|---|---|---|
| 1 | Missing `in_reply_to`/`corr_id`/`run_id` — named `envelope` refusal | refused | false | `error`, `refused_by`, `refusal`, `missing[]` | yes | yes |
| 2 | `text_b64` does not decode, or no decodable directive (`text_b64`/`brief`) | refused | false | `error`, `refused_by`, `refusal` | yes | yes |
| 3 | `brief.digest` absent or mismatched (`brief_digest`) | refused | false | `error`, `refused_by`, `refusal` | yes | yes |
| 4 | Harness could not run | failed | false | `error`, `reply_b64` (plus retained `refused_by`/`refusal`) | yes | yes |
| 5 | Harness exit ≠ 0 | failed | false | `error`, `reply_b64` | yes | yes |
| 6 | Gate could not run, or gate exit ≠ `expect_exit` | failed | false | `error`, `reply_b64` | yes | yes |
| 7 | Harness exit 0 and gate exit = `expect_exit` | completed | true | none — `reply_b64` is always present | yes | yes |
| 8 | `dispatch_key` already in the seen-cache | recorded result re-returned verbatim (:1548-1553) | unchanged | — | yes (same `delivery_key`) | yes |
| 9 | Reply body matches the relay guard's control-key shapes | none — the envelope is never POSTed (:1885-1894) | — | — | no | no |

Invariant the table encodes: `status:"completed"` ⇔ `ok:true`; `status:"failed"` or
`status:"refused"` ⇒ `ok:false` plus `error`; a result naming neither `in_reply_to` nor
`corr_id` never completes a tick.

Validation vector (shipped, run at the pinned commit from the repository root):
`python3 tests/test_bus_result_delivery.py` drives the real worker CLI
(`scripts/node-bus-worker.py --once`) against a stub crier relay and asserts the verdict,
refusal-shape, idempotent-redelivery and lost-answer arms (A1-A11) plus the consumer pin.
Observed: 12 PASS (consumer-pin, A1..A11), exit 0.

ch:trace row=P5G-17 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=tests/test_bus_result_delivery.py doc=docs/handbook/chapters/M2-dispatch.md evidence=tests/test_bus_result_delivery.py witness=none:shipped-node-bus-worker-and-envelope-trace-specs verdict=none:foreman-verifies-and-closes commit=none:worker-commit memory=none:foreman-writes

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/add_family_lanes.py scripts/configure_family.py scripts/load_lane_config.py scripts/lane_target.py scripts/node-bus-worker.py` | exit 0 | 2026-11-06 | PASS |
| lane target unit | `python3 tests/test_lane_target.py` | pass | 2026-11-06 | **PASS** (40 tests, rc 0) |
| result model attribution | `python3 tests/test_bus_result_delivery.py` | requested and observed models stay distinct; absent observation is explicit | CF-521 | **PASS** — A8 detects misattribution; A9 verifies `unobserved`; A10 verifies refused shape |
| bus worker ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox GET → 200 with key+bearer | 2026-11-05, cf-node only | **UNVERIFIED** — a single-host 2026-11-05 run (FACT-04) is provenance, not a current measured result; not repeatable from this control host (`~/node-bus-worker.py` does not exist here) |

## 8. Metrics

**RED — none (absence-proved).** The node-side dispatch path emits no counters or
gauges. `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics'
scripts/node-bus-worker.py scripts/lane_target.py scripts/configure_family.py
scripts/add_family_lanes.py scripts/load_lane_config.py` → 0 matches. Dispatch count, reply latency
and refusal count are answerable only by grepping the bus worker log.

## 9. Log lines (verbatim)

The worker does **not** source `lib.sh` — it is Python. It re-implements `lib.sh`'s row
vocabulary locally at `node-bus-worker.py:129-141` (`def ok` `:129` prints `  PASS  {name} — {value}`,
`def bad` `:133` → `  FAIL …`, `def warn` `:137` → `  WARN …`, `def note` `:141` → `  ..    …`), a
copy that can drift (the reason M0 F0-4 matters). **Scope (B09, measured):**
`grep -cE '^\s*(ok|bad|warn|note)\(' scripts/node-bus-worker.py` = **70** call sites. The
observable surface is therefore per-measurement helper rows, not a fixed set of distinct strings;
the evidentiary rows below are the refusals, which name the rule. The generic per-measurement
PASS/FAIL/WARN/note rows are **not** inventoried one-per-site — the uncovered count is a named RED
on this field, not a "sample" claimed complete:

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`node-bus-worker.py:125,129`) | every measurement row | descriptive (same rule as M0 F0-4) |
| — | `  FAIL  identity — …; refusing` (`:608`) | unparseable/absent identity | evidentiary |
| — | `inbox — GET /agents/cf-node/inbox/stats -> 200` | a valid signed inbox read (FACT-04) | evidentiary |
| — | `  FAIL  brief_digest — {label} …` (`node-bus-worker.py:1263-1269`) | `cf.brief-input.v1` JCS digest mismatch or unavailable input | evidentiary — `DIGEST_MISMATCH`/`BRIEF_UNAVAILABLE` refusal is before project, workdir, vars, harness and gate checks |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stub, PATH-shadowed, or unpinned Bunker client cannot prove identity | `client_identity` fails; plan is refused and no target emitted. A client that merely prints matching words is insufficient unless it is the pinned executable | a matching client-reported agent and server from the pinned realpath | pass `--bunker-bin PATH` or set `BUNKER_BIN` to the intended executable; inspect the recorded realpath and SHA-256 |
| `text_b64` undecodable | node refuses: "`text_b64` does not decode to UTF-8 text" (`:1022-1034`), no silent fallback to another member | a malformed dispatch | **resolved** — CF-354 (complete): the node decodes `text_b64` first and refuses a non-decoding value rather than reading a different member |
| Failed result recorded as success | scheduler pass for a `status:"failed"` reply | a real pass | **resolved** — CF-355: `dispatchReplyVerdict` refuses silence and contradictions and records `status:"failed"`/`"refused"` with no `ok` as a FAIL (`internal/scheduler/dispatch_leg.go:742-776`; scheduler commit `70956121`, tier-2 judge PASS run `5b997976`; node side §Failure behavior) |
| `configure_family` PID hardcode | config fails at import unless PID 1755676 is alive | a live scheduler | **OPEN** — F2-2 |
| `configure_family` partial write | one lane configured, fifteen fail, exit 0 | a full failure | **resolved** — CF-356: **transaction boundary** is one lane, not the loop — the lane's `UPDATE` is committed at `scripts/configure_family.py:247` before the next lane's API call, and every daemon call for a lane precedes that write (`POST /api/v1/projects` `:356`, `PUT /api/v1/projects/<name>` `:370`), so the daemon never waits on this script's lock; **retry policy** — a `database is locked`/`database is busy` write is retried to `BUSY_ATTEMPTS = 5` attempts in total with a monotonically increasing 0.25 s × 2 backoff (`:58-62`, `busy_backoff` `:186-188`, retry loop `:220-251`), per-lane outcome recorded as configured / already / failed-with-reason; **exit status** — 0 only when every targeted lane is configured or already correct, a shortfall prints each unconfigured lane with its recorded reason and exits 2, and a token/DB/shape failure exits 3 (`:54-56`, `:442-453`) |
| Un-FK-checked clone namespace | a cloned lane's workdir may not exist | a validated clone | **OPEN** — CF-358 |
| Seen-cache not persisted | `could not record the seen-cache` (`:1402`) | a durable idempotency window | a redelivery after a crash re-runs — the cache write failure only warns |

## 11. Limits and margins

- The node refuses a dispatch without a `text` directive (`:1036-1042`) and a `brief.digest` mismatch
  (`:1044-1052`, emitter `:1050-1052`), before any network work.
- **`dispatch_wall` correction (F2-3).** `node-bus-worker.py:1200-1205` accepts a numeric value
  only when `0 < wall <= 86400` and returns `int(wall)`; otherwise it falls back to
  `args.harness_wall` or `DEFAULT_HARNESS_WALL`. It does **not** clamp: a fractional positive below
  1 is converted by `int()` to **0** (not refused), and an out-of-range value falls back rather
  than being bounded.
- **Settlement ordering (B10).** `node-bus-worker.py:1389-1422`: execute
  (`process`) → deliver each result → write the seen-cache **only after delivery succeeds**
  (`seen[key] = result` when `delivered_ok`, `:1394-1395`) → ack last. `save_seen` failure only
  warns (`:1398-1403`), so a crash before persistence is not covered by durable replay; ack is
  skipped when delivery failed, "so redelivery is the safer outcome" (`:1407-1414`).
- **Same-batch duplicate (B10 correction).** `node-bus-worker.py:1355-1379` processes every
  leased message in a batch using the *same initially loaded* `seen` dictionary; the cache is not
  updated until the later delivery loop (`:1389-1395`). Two previously-unseen messages sharing one
  dispatch key in a single retrieved batch therefore **both execute** before either result enters the
  cache. The idempotency window only deduplicates across batches, not within one. An earlier
  "crash-before-persistence" discussion missed this same-batch case.

## 12. Cross-references

- F1 DISPATCH AND SETTLEMENT is the primary flow; the node is the terminal actor.
- M9 SCHEDULER is the producer of the CT-03 envelope (CT-02 on its side) and the settlement consumer of CT-04's reply (`dispatchReplyVerdict` reads the node's reply).
- M11 DISPATCHER is the *other* inbox consumer, which **also** decodes `text_b64`
  (`dispatcher.py:142-150`). The two consumers now agree on `text_b64`; CF-354 (the mismatch) is
  fixed and closed.
- **M5 HARNESS owns the CF_* variable contract (M5.S5 `harness-vars.sh`),** not M0 — see M0 §12
  and M5 §5. The node passes the CF_* set to the harness at run time.

## 13. Evidence of record

- Code read: `node-bus-worker.py:60-129, 381-382, 977-1010, 1176-1210, 1200-1205, 1389-1422, 1425-1499`.
- `docs/UNIT-MAP.yaml:78-102` (M2 S1–S3); `_facts.md` FACT-03/FACT-04.
- Board rows: CF-354, CF-355, CF-356, CF-358, CF-359.
- **Findings:**
  - **F2-1** (carried) — the node imports `urllib` (`:66-78`), not `crier_client`.
  - **F2-2** — `configure_family.py:24-28` hardcodes PID `1755676` and reads its environ at import.
  - **F2-3** — `dispatch_wall` does not clamp; it accepts-then-int-converts or falls back.
  - **F2-4** (corrected) — an earlier citation said `add_family_lanes.py`/`configure_family.py`/
    `load_lane_config.py` **and** `lane_target.py` have no in-repo production caller. The S1 trio's
    "no caller" holds, but `lane_target.py` (S2) **does** have one: `configure_family.py:17,149`.
    S1 activation remains operator/fleet-config invoked; S2 is active via `configure_family.py`.
  - **F2-5** (new) — CF-354 was the node reading `text` while the scheduler sent `text_b64`. The
    node now decodes `text_b64` first (`directive_text`, `:989-999`) and falls back to the legacy
    plain members for older senders. The contract state moved from broken to works; CF-354 is
    `complete` on the board (closed in commit `6184e52`). CF-355 (reply `status` vs `ok`) is
    resolved in the shipped scheduler law — `dispatchReplyVerdict` reads `ok` and validates
    `status` against it (`internal/scheduler/dispatch_leg.go:742-776`); closed in the
    scheduler repo at `a9697e3b`.

## 14. Wave-2 redline — review requirements (target behavior vs implementation coverage)

Per the CF2A-01 review handoff (§1.7, §2): **approved target behavior governs this chapter**; the
source locators and grep counts in §§1–13 are implementation coverage evidence, not authority.
Resolved architecture applied throughout: the project foreman runs **inside its Bunker**; **Crier
is the launch/return boundary** — Crier delivers work to the foreman in the Bunker and returns the
foreman's response to the scheduler on the control host, which records it and triggers subsequent
processing (handoff §1.1); DuckBrain is present in every Bunker with the same logical memory view
as the controller (handoff §1.2); Hermes is the fixed MVP harness and Task Router is
future/non-MVP, placed after Node and before Harness (handoff §1.5) — future harness selection is
not the current model/provider route and must not be conflated with it.

**R1 — Consumer/invocation boundary (required).** The chapter must define the boundary among the
three consumers that exist today: (a) **Crier's harness-adapter layer** — its public
register/deliver/receipt interface, disabled by default, with per-adapter probing and structured
delivery outcomes; (b) **the node-bus-worker pull path** — a transport/execution adapter that
leases from the inbox and builds the harness invocation itself (§3 S3); (c) **the central
dispatcher** (M11) — the *other* inbox consumer. Under the resolved architecture, Crier
launches/delivers to the Bunker foreman and returns its response to the scheduler; any
implementation that keeps the pull worker or an alternative consumer side-by-side requires an
**explicit partition or documented migration**, not silent coexistence. The presence of Crier
adapters does not establish that the pull path uses them, and the pull path's direct
harness-argv construction does not establish the foreman path's invocation shape (review notes
M2, observations). The MVP must name its single execution owner and, if both modes exist,
selection/identity/no-double-execution semantics per mode.

**R2 — Versioned schemas, identities, correlation, generations (required).** Complete versioned
**brief / envelope / result / error** schemas are required content: required fields, types,
requiredness, unknown-field policy, and a pinned release of the bus API they belong to
(review notes M2, open question 3). Identities and correlation: agent id, dispatch id,
correlation id, run/generation identity — every redelivery, retry and reply must be attributable
to its generation so a replayed or re-executed dispatch is distinguishable from the first
execution. Also required: settings/credentials at the integration boundary (inherited Crier/harness
settings named with defaults and validation, not name-only override lists — §5's RED), workspace
ownership, deadlines and leases, and **replay / cancel / restart** behavior including the
seen-cache and same-batch duplicate semantics measured in §11.

**R3 — Separated outcome facts (required).** These six facts are distinct and must never be
collapsed: (1) **transport acceptance** — Crier accepted/leased the message (a delivery receipt is
transport, not acceptance); (2) **executor start** — the harness actually began; (3) **execution
outcome** — the run's own result; (4) **independent acceptance** — the GitReins judge's verdict on
the work (M3); (5) **publication** — the landed/pushed object (M3); (6) **board and memory
projections** — the M4 closeout and DuckBrain records. A successful HTTP status or delivery
receipt says nothing about (2)–(6); execution success says nothing about (4)–(6) (review notes
M2: "execution can succeed while publication or refresh fails"). Under the resolved architecture,
the Bunker foreman's projections to board/memory are first-class; a transport worker that happens
to lack direct board/memory writes does **not** prove the foreman path lacks them — do not infer
system absence from the transport worker's write surface (handoff §3 Part IV).

**R4 — Required metrics with owner and readout (required).** The dispatch path must support:
attempt/outcome counts by class, refusal/failure classes, delivery/execution/reply latency,
queue depth and wait, retries/redeliveries/duplicates, cancellations, and projection-lag
measurements — each with meaning/type/unit, bounded dimensions, an **emission owner**, a
collection point and a named operator **readout** (handoff §3-M2). Where the chosen integration
adopts Crier's harness-registry telemetry (per-adapter dispatch/outcome counts, error classes,
delivery-duration histogram — §6 coverage), M2 must state which instruments it reuses and what
end-to-end attribution remains missing; existing upstream metrics do not automatically instrument
an unrelated node-worker path. §8's absence-proved RED describes the snapshot, not the metric
design.

## 15. Normative launch and return contract (P3-12, P3-10)

The resident foreman cancellation/reboot vectors are the `resident_foreman_contract` object in `docs/handbook/contract-vectors.json`; this is the single offline vector source also referenced by Part IV and M5 §16.1. Runtime supervisor conformance remains unverified.

The MVP execution owner is the project foreman inside the project Bunker. Crier is
the sole launch/return boundary. The canonical wire is the `cf2a.v1` outer envelope
specified in Part I §1.9.1 and Part IV §§IV.1–IV.2. `schema_version` is `cf2a.v1`;
`message_type`, `request_id`, `corr_id`, `sender`, `created_at`, `body` complete its
required key set. Body `schema_version` selects `round-admission.v1`,
`worker-brief.v1`, `worker-result.v1` or `round-report.v1`. There is no
`cf.launch.v1`, `cf.return.v1` or `correlation_id` target wire. The former names
are retired draft terms, refused as `UNSUPPORTED_VERSION`/`UNKNOWN_FIELD`.

CT-02 admission contains `round_id`, `run_id`, `corr_id`, `task_scope`,
`total_budget`, `config_generation` and the Part I §1.9.6 extensions. It contains
no wave, worker or attempt identity. CT-05 is foreman-to-worker delivery, not lane
configuration; CT-01 owns `extensions.lane_seed`. The foreman allocates wave_id,
worker_id, attempt_id and dispatch_id once in its durable launch transaction.
CT-04 returns the worker result; CT-06R returns the entire round report; CT-06
notifies Scheduler of that report. Part IV gives complete bodies and response forms.

### 15.1 Immutable brief and mode selection (P5-B-01/02/12/35)

The Factory foreman/manager is authoritative for BriefInput construction, immutable
storage and replay. It snapshots the accepted admission before any worker reservation:
`BriefInput` is exactly the closed `cf.brief-input.v1` object
`{schema_version:"cf.brief-input.v1",directive:Text,task:TaskRow,criteria:Criterion[1..100],skills:[{name:ID,ref:EvidenceRef,digest:SHA}],attachments:Artifact[]}`.
The object carries the directive bytes, the exact admitted `TaskRow` image (not a later
board read), criteria in their admitted order, skills in their declared order, and
attachments in explicit order. Skill entries are ordered `{name,ref,digest}` descriptors;
the receiver fetches each skill's immutable CAS bytes by `ref` and verifies `digest` before
start. Attachment entries are ordered `Artifact` descriptors; the receiver fetches each
attachment's immutable CAS bytes by `ref` and verifies both `size_bytes` and the referenced
digest before start. The `worker-brief.v1` delivery therefore carries the exact brief
object and its ordered material references, while CAS supplies the skill and attachment
bytes; it does not substitute mutable skill paths, board reads or attachment paths.
Attachment names are unique. No mutable prompt, skill path, board row, criterion list or
attachment path is reread after this snapshot.

The foreman serializes the complete object using RFC 8785 JCS: UTF-8, sorted object
keys, compact separators, no BOM and no trailing LF. String bytes preserve whitespace
and Unicode; no normalization or pretty-printing occurs. `brief_digest` is the lowercase
SHA-256 of exactly those canonical `cf.brief-input.v1` bytes, and `brief_ref` is the
content-addressed `EvidenceRef` for the same bytes. It never covers a reconstructed
summary, the `worker-brief.v1` envelope, transport framing, base64 text, skill/attachment
CAS bytes, or mutable source paths. If a legacy transport base64-encodes the object, the
receiver decodes to exactly the UTF-8 bytes first, then verifies `brief_ref` and
`brief_digest`; base64 text is never hashed. CV-01-B in `docs/handbook/contract-vectors.json`
is the normative positive vector, and CV-01-G is its deterministic negative control: it changes
one criteria argv token while leaving the declared CV-01-B digest, proving refusal before effects.
Hash CV-01-B's `related_objects.brief_input_canonical_json` bytes and compare with
`related_objects.brief_input_sha256` and `brief_ref`.

`worker-brief.v1` carries the launch-custody identity plus `brief_ref` and
`brief_digest`; it does not redefine BriefInput or its digest. The receiver resolves the
ref, verifies byte length/content and digest before reserving an execution key or
starting a native process. A missing CAS object or unavailable skill/attachment fetch is
`BRIEF_UNAVAILABLE`; a recovered byte object whose length, ref or digest does not match is
`DIGEST_MISMATCH`. In either case no reservation, process start or other execution side
effect occurs. The worker receives the same immutable byte object through the M5 supervisor
stdin contract, not a reconstructed summary. An identical retry for the same
`(project_id,round_id,task_id,attempt_id,brief_digest)` replays the original custody and
launch receipt without a second reservation or native start. A changed digest, ref,
TaskRow, criteria, skill or attachment set is `LAUNCH_CONFLICT`/`DIGEST_MISMATCH`, not a
new execution under a new delivery id. [Part I §1.9.6; Part IV §IV.2; CV-01-B.]

ch:trace row=P5G-08 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=none:handbook-contract-probes doc=docs/handbook/chapters/M2-dispatch.md evidence=docs/handbook/contract-vectors.json witness=none:specification-only verdict=none:foreman-closeout commit=none:worker-commit memory=none:foreman-closeout
STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json

The contract is specification-only; runtime delivery and supervisor conformance remain unverified.

The worker `launch_id` is preallocated by the foreman from its round ledger immediately
before CT-05, as specified in §15.4; it is not derived from a launch digest. The
supervisor derives `execution_key` once from `launch_id` and the L0 `input_digest`.
Dispatch/delivery IDs
are receipt identities, not uniqueness authority. Unique indexes exist for
execution_key and for `[project_id,round_id,task_id,attempt_id]`. Reusing an
attempt for different input is `LAUNCH_CONFLICT`. Round custody deduplicates on
`[run_id,corr_id]` independently.
The manager's active binding records `execution_mode=resident`, binding_generation
and owner_fence. Resource-side enforcement of the full Fence follows Part I
§1.9.3a and M7 §17–17.1; it is TARGET-UNIMPLEMENTED/runtime UNVERIFIED.
Mode changes disable admission, drain or fence every old attempt,
prove old credential denial, then prepare/commit a new binding (Part I §1.9.4).
Pull/central adapters can only translate a persisted authorized admission and submit
it to the same supervisor. They cannot allocate another execution key or start
Hermes directly. A different dispatch_id never bypasses deduplication. Unsupported
mode/capability is `EXECUTION_MODE_UNSUPPORTED`; all modes share the same ledger.

### 15.2 Launch journal and crash distinction (P5-B-05/07)

The resident supervisor owns `/var/lib/factory/control/execution/transactions.jsonl`
under the `factory-control` UID, using the Part I §1.9.2 append/fsync/sequence/hash
transaction format, exclusive lifetime lock and rebuildable indexes. Neither the foreman
nor worker can mount or edit that journal. One transaction reserves budget and execution_key and writes
`{execution_key, input_digest, native_name, state, state_version, boot_id,
process_instance_id, native_session_id, result_ref, control_version}`. Optional
identities/result are explicit null before discovery; native_name is
`cf-<execution_key>` and never reused. The supervisor fsyncs RESERVED before start.
Each subsequent transaction CASes state_version, records evidence and an outbox event.
No acknowledgement or process release precedes the corresponding fsync.

The local launcher provides atomic `create-or-discover(native_name,input_digest)`;
its durable START_INTENT is written before creating a process group. The child waits
on a private release pipe before running any harness code. Parent records PID,
`/proc` start ticks, boot_id and native session ID, fsyncs STARTED, then releases the
child. A pipe EOF before release makes the child exit without invoking Hermes.
The launcher retains start/release/exit tombstones for the life of the round and
M3 evidence retention. It never relies on PID alone or a bounded seen cache.

Recovery distinguishes these cases, rather than calling all of them unstarted:

| Durable / native observation | Required recovery |
|---|---|
| RESERVED and launcher proves no START_INTENT | unstarted; same execution_key may enter create-or-discover once |
| START_INTENT, child exists and remains gated | discover by name, input digest, boot/start identity; persist STARTED, then release |
| STARTED but release outcome unknown | discover release tombstone and exact native session; never launch again; reattach/status only |
| launcher release or native output exists but parent STARTED absent | launched-before-parent-persist; recover identity from launcher journal and mark RUNNING; never allocate another process |
| new boot after intent, absent child and no terminal/release proof | `START_UNKNOWN`; quarantine, fence, consume reserved budget conservatively; no same-attempt relaunch |
| terminal journal/result present | replay result/outbox only; no native invocation |

The resident supervisor is the authoritative actor for this recovery decision and
the execution journal is its source of truth; neither the foreman, worker, PID
listing nor a delivery acknowledgement may declare a start absent. Every lookup
is keyed first by `execution_key`, then exact `input_digest`. The durable native
execution name is an internal launcher key, not a second cancellation identity.
When a process incarnation is relevant, the lookup additionally requires the
recorded `boot_id`, `/proc` start ticks and `native_session_id`; those fields are
identity evidence, not replacement keys. The ordering is deliberate: reserve and
fsync the execution record, fsync `START_INTENT` before native creation, discover
the exact native record, then persist `STARTED` before release. A missing journal,
missing tombstone, or contradictory identity is not proof of never-started:
return `START_UNKNOWN`, quarantine/fence the reserved attempt, and do not relaunch.
Only the RESERVED/no-START_INTENT row with authoritative launcher proof of no
intent may use its existing `execution_key` for the single create-or-discover
operation. A terminal record is replayed and never invokes native execution.

The gated child makes the fourth case a protocol violation on the reference launcher,
but it remains a mandatory recovery case for native adapters. An adapter unable to
prove absence/discover a prior run refuses with `START_UNKNOWN`; absence from a
process listing alone is not proof of never-started. A distinct retry attempt is
allowed only after cancellation/quiescence or old-host fencing, and follows the
pinned round retry/budget policy; it does not erase unknown work. [M5 §16; Part II F8.1.]

### 15.3 Time, cancellation and result reduction (P5-B-10/11)

Crier custody leases are 60 s, renew every 20 s, and are independent of the 60 s
owner lease (renew every 20 s) and 120 s task claim (renew every 40 s). The single
Crier lease_id remains stable from initial retrieve through renewal and final ack/release;
its initial visibility, current expiry and final validity are signed custody facts, not
a task-runtime bound. Each authority
uses its monotonic clock; UTC fields are diagnostic with maximum 30 s signature skew.
A launch validates all three and the 30 s one-use dispatch grant. Custody renewal
loss does not create another executor: the durable execution key survives redelivery.
Owner/claim renewal failure immediately freezes protected effects; at their deadline
(with no grace) the supervisor sends TERM to the exact process group, then KILL after
10 s if needed, records quiescence or `STOP_UNKNOWN`, and requests fencing. The round
wall starts once at durable admission (`admitted_at`/`admitted_monotonic` and
`round_deadline`); the attempt wall starts at the first durable native release
(`attempt_released_at`/`attempt_deadline`). Restart cannot reset either clock. A
30-second admission-to-release delay consumes 30 seconds of the same round; it does not
move the round end. Each turn has its own start and timeout, bounded by the remaining
attempt. The deadline record stores both an absolute UTC deadline and a monotonic
remainder, with the restart conversion in Part V §V.12. A missing checkpoint is
`DEADLINE_UNKNOWN`, never a fresh budget.
The default attempt wall is 1800 s, bounded by remaining round wall minus the configured
launch, transfer and cleanup reserves (Part V §V.12). CF_TIMEOUT_S limits each model turn;
it does not replace this attempt wall or the 21600 s default round deadline. Scheduler's
21600 s default tick wall includes the admitted round and its settlement work.

The closed execution transition relation is RESERVED→START_INTENT/CANCELLED/EXPIRED;
START_INTENT→STARTED/FAILED_TO_START/START_UNKNOWN; STARTED→RUNNING/CANCELLED/DEADLINE;
RUNNING→RETURNED/CANCELLED/DEADLINE/STOP_UNKNOWN. FAILED_TO_START requires proof no
harness code ran. Cancel/control and terminal-result CAS compete on state_version:
first durable winner determines execution outcome; a later completion is retained
as late evidence and cannot replace CANCELLED. START_UNKNOWN/STOP_UNKNOWN resolve
only to a discovered running/terminal observation or fenced quarantine; no direct
retry edge exists. Rejected input never reserves an attempt. Every terminal state
produces a durable typed result, outbox and Crier acknowledgement after custody;
expired/unstarted cancellation reports fail with the specific reason, not pass.

**Phase-discriminated cancellation (P7-17).** The
`POST /v1/launches/{launch_id}/cancellation` request is one closed
`cancellation.v1` body: `{schema_version, cancellation_id, request_id,
idempotency_key, request_digest, expected_state_version, reason, launch_id,
requested_phase, execution_key, boot_id, process_instance_id, native_session_id}`.
`requested_phase` is `pre_admission`, `prestart`, `running`, `terminal` or `ambiguous`.
The response records the phase where the cancellation actually landed; it never rewrites
a later phase as an earlier one.

- `pre_admission` has no launch row and returns `refused_no_launch`; the permit is never
  consumed.
- `prestart` is a non-signalling state CAS for proven `RESERVED` work; it moves
  `RESERVED → CANCELLED`, returns `cancelled_before_start`, and never consumes the start
  permit. No TERM/KILL is sent and no reservation is released after a winning cancel.
- `running` requires a durable `STARTED`/`RUNNING` record plus the exact
  `execution_key`, `boot_id`, `process_instance_id` and `native_session_id`. It sends
  TERM, waits 10 seconds, sends KILL, requires an empty cgroup, and returns
  `signalled_quiesced` only at quiescence. Surviving descendants or unavailable readback
  is `STOP_UNKNOWN`, quarantined and blocks replacement.
- `terminal` records `already_terminal` without changing the terminal state; an operator
  who pressed cancel after completion receives a truthful record, not an error.
- `ambiguous` is for `START_UNKNOWN` or an unprovable incarnation. It records a durable
  cancel request without signalling, quarantines the launch and returns
  `quarantined`; absence of proof is never treated as “not running”.

The start-release CAS and cancellation CAS compete on the same `state_version`. A
prestart cancel that wins prevents the first release and no process may start; a release
that wins makes a later cancellation `running` and requires the incarnation identity. The
result is `{cancellation_id,launch_id,requested_phase,applied_phase,terminal_effect,
journal_state_before,journal_state_after,permit_consumed,state_version,
requested_at,applied_at,signal:{kind,sent_at,quiescence_at},evidence_refs,
quarantine_ref,reason}`. Repeating the same `(cancellation_id,requested_phase,
request_digest)` returns the original result. A late result is retained as late evidence
and cannot replace a terminal `CANCELLED`; a mismatched identity or stale version returns
`STATE_CONFLICT` or `STALE_OWNER` without signalling. The state-version record and this
request are the only cancellation identity; retired alternate cancel verbs are refused.

Return transport states are `pending`, `delivered`, `acked`; delivery retries use
the same envelope/result bytes at 5,10,20,40,80,160,300 s (then 300 s), through 24 h.
After 24 h the result/outbox is retained, an incident is emitted, and manual replay
uses the same key. Crier retains unacknowledged custody for 7 days and archived
receipts for 90 days; expiry emits an incident and never permits re-execution.
Scheduler settlement follows Part I §1.9.9, not execution state.

Typed status is `pass`, `fail`, `unverified`, `partial`, or `unknown`. Target bodies
never carry `ok`. The legacy translator requires ok=true iff status=pass and refuses
disagreement as `RESULT_CONFLICT` without settlement. An identical canonical body
returns the original accepted receipt with duplicate=true; different optional evidence
is still a conflict, submitted only as a new supplemental evidence record, never an
overwrite. Execution pass plus publication failure remains execution pass but yields
round partial and settlement partial/failure, never settled_success. No transport
`status=ok/accepted` denotes execution pass. Required telemetry is M0 §16.1; refusal,
start ambiguity, duplicate and deadline each produce one durable event.

Required dispatch metrics are attempts, outcomes, refusals by reason, lease age, renewals, duplicates, cancellation, late results and projection lag. Crier owns transport metrics; the foreman owns execution metrics; Scheduler reads the correlated result. No transport receipt is an execution or acceptance verdict.

### 15.4 One resident/native protocol and identity mapping (P6-01/02/10/11/12)

`supervisor.v1` on `$HOME/.local/state/factory/supervisor/control.sock` is the
sole target control protocol, and `cf.native.v1` on the child's stdin/stdout is
the sole target native-adapter protocol. M5 §16.1 supplies their complete
request/event framing. The socket is owned by `factory-control`, carries a base
owner-only mode and the named `u:factory-foreman:rw-` ACL plus traversal ACLs from
M1 §17.5; the worker has no entry. `$HOME` is `factory-control`'s HOME. The
foreman sends HTTP-shaped `PUT /v1/launches/{launch_id}` with outer fields
`{schema_version:"supervisor.v1",request_id:ID,idempotency_key:ID,
owner_fence:Fence,project_id:ID,method:"PUT",path:"/v1/launches/{launch_id}",
body:LaunchInput}`. The former `.node/execution/control.sock`, `submit.sock`,
`cf.supervisor.v1`, submit/status/cancel/drain/resume verbs and fd-3/fd-4
channels are retired and return `UNSUPPORTED_VERSION`; they are neither an
alternate production profile nor a required compatibility mode. Supervisor
stdout is diagnostic; structured native results travel only in
`cf.native-event.v1` records on the child's stdout, with human output captured
separately.

Execution identity is allocated before any process exists. The launching foreman
preallocates `launch_id` and a nonce before admission; `launch_id` is not derived from a
digest of the launch. The L0 `LaunchCommitment` contains the immutable `BriefInput`,
`launch_id`, nonce, owner identity and the resolved kind/round/workspace fields. Its
`input_digest` covers only those L0 fields and explicitly excludes `dispatch_id`,
`execution_key`, `input_digest` itself and every signature. The supervisor validates and
persists the commitment first, then derives each value exactly once:

```text
execution_key = SHA-256(UTF-8("cf.execution-key.v1\n") || launch_id || "\n" || input_digest)
dispatch_id   = "d-" || SHA-256(UTF-8("cf.dispatch-id.v1\n") || launch_id || "\n" || input_digest)
native_name   = "cf-" || execution_key
```

`LaunchInput` carries the commitment and derived identities; its `input_digest` is the
commitment value and is never recomputed over the materialized object. The construction
order is content, then record, then envelope. No consumer searches for a digest fixed
point; a mismatch is `CONTRACT_INVALID` or `LAUNCH_CONFLICT`.

|| Role | Identity allocation | Derived identities |
|---|---|---|
|| foreman | the foreman preallocates `launch_id` and nonce before CT-02 admission; the round/run reference is recorded in the commitment, not hashed to allocate the ID | `execution_key`, `dispatch_id="d-"+H("cf.dispatch-id.v1"||launch_id||input_digest)`, `native_name="cf-"+execution_key` |
|| worker | the foreman preallocates `launch_id` from its round ledger immediately before CT-05; `attempt_id` is allocated at the same point | the same execution-key, dispatch-ID and native-name derivation |

The dispatcher reserves budget and the supervisor persists the unique
execution_key/launch_id/dispatch_id/native_name and input digest before exec.
The supervisor independently recomputes the execution key from the path launch
ID and body input digest. Duplicate CT-02 or CT-05 with the same digest returns
the original durable record without exec. Changed input under either identity
is `LAUNCH_CONFLICT`; a new request or delivery ID cannot force another
execution. `launch_id` is the launch lookup key, `execution_key` is the budget
and result key, and `native_session_id` identifies one process incarnation
without replacing either. The supervisor is the sole journal authority; the
foreman and worker submit inputs and receive receipts but never write execution
rows.

On cold CT-02 submission the supervisor constructs the synthetic foreman
BriefInput from the admitted task snapshot, ordered authorized task IDs and lane
seed. It allocates no wave, worker or task-attempt identity. The deterministic
foreman launch ID permits exactly one native foreman for the round. After that
foreman starts, it allocates wave and worker identities in its own round ledger
and creates `attempt_id` immediately before each worker launch. It submits the
resulting `LaunchInput` to the same `control.sock`; the supervisor derives the
worker execution key from launch ID and input digest and applies the same gated
launch protocol. No undocumented bridge translates between two supervisor
implementations.

The signed 60-second Crier custody chain in M10 §16 covers initial reserved
receiver, retrieve, renewal, return and final acknowledgement. A lost
release/ack response is read back by delivery ID before any transfer. Lease
expiry produces reconciliation, not a second native run. Duplicate delivery,
lost acknowledgement, supervisor restart and cancellation all resolve by
execution_key/launch_id and the durable state CAS in §15.2.

The shared vectors are the only acceptance examples for this mapping: cold CT-02, one
foreman CT-05, duplicate delivery, lost release acknowledgement, restart, cancellation,
SC-01's 60-second lease and SC-09's turn/attempt/round deadlines. Failure outcomes follow
Part I §1.9.10: proven launch refusal is `fail`, clean exit without a durable result is
`unknown`, uncertain commit/gate evidence is `unverified`, and definitive publication
failure after passing execution is `partial`. Telemetry uses Part V §V.10 with full
FactoryIdentity on every launch, network failure and result event; no metric-only success
is accepted.

## RED field count: 3 (Metrics §8; §7 live bus-worker ladder not repeatable from this host; §9 inventory 4 of 70 helper call sites — the descriptive per-measurement rows not tabulated one-per-site)

## FLIGHT DATA FILE - M2 DISPATCH - NODE SIDE

```checklist
TITLE: M2 DISPATCH - NODE SIDE
WHO: NODE OPERATOR
POLL - node-bus-worker.py --once --dry-run
√ EXIT 0 - row PASS, fetch verified, nothing acked (the 5 s lease returns the batch)
RUN - node-bus-worker.py --once
√ REPLY - brief verified, harness run, reply acked, exit 0
SIGNATURE - replay a retrieve with a tampered header
√ REFUSED - 401 naming the signer; no harness run, no ack
```

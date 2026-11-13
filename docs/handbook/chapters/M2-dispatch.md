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
failed run records a pass for work that never happened. The mirror-image defect on the control
side is CF-355 (a failed result with no `ok` is recorded as success).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 declare and configure lanes | `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py` | **operator-invoked** | no in-repo caller — `grep -rn 'add_family_lanes\|configure_family\|load_lane_config' scripts/` matches only the files themselves. `load_lane_config.py` is read-only by default and prints the six proposed updates; `--apply` is required to write and `--dry-run` is always read-only. `configure_family.py:24-28` reads the scheduler operator token at module import |
| S2 resolve a target | `lane_target.py` | **active** | `scripts/configure_family.py:17` imports it and `:149` calls `lane_target.parse(workdir)` then branches on the result — a production caller **in-repo** (3 / B09). An earlier citation of "no production caller" was false. Passing the parse does not prove a remote checkout exists (it is structural parsing, not remote verification) |
| S3 consume the inbox, sign, reply | `node-bus-worker.py` | **active** | decodes the directive (`directive_text`, `:977`), consumes one dispatch (`process`, `:1007`), builds the reply (`:1176-1192`), delivers (`:1208`), settles (`:1389-1422`) |

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

**`--dry-run` custody note (B08).** `--dry-run` (`node-bus-worker.py:1437-1441`, help "fetch and print the plan; run/post/ack nothing") does **not** avoid inbox custody mutation: `:1381-1385` prints `BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked ({n} message(s) leased for {lease}s and left to expire)` — the messages were already **leased** before the dry-run branch, so a dry run holds inbox messages until their lease expires. It skips execution/post/ack, not the lease. The dry-run lease is **5 s** (`:1312` `lease = 5 if args.dry_run else args.lease_seconds`), not the configured `--lease-seconds` — a dry run holds each retrieved message for 5 s, distinct from a real run's lease. Unregistered operational overrides: `--home`, `--identity`, `--bus-identity`, `--key`, `--token-file`, `--agent`, `--project`, `--crier`, `--workdir`, `--harness-cmd`, `--gateway-port` (`:1443-1476`) — these select identity/credentials/destination/executable template but are registered **NAME ONLY** (default/validation/consequence not individually stated), a named RED on this field, not a completed register.

## 6. Contracts in and out

Canonical IDs come from the 31-entry Part IV §IV.2.4 registry. The table below is historical implementation coverage, not cf2a.v1 qualification. Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in (inbox) | crier `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `scripts/node-bus-worker.py:1007` `process` consumes one dispatch (decodes `text_b64` first via `directive_text` `:977`, then the legacy plain members for older senders) | **works** — CF-354 fixed in commit `1f1c0fe` (decodes `text_b64`), board-closed in commit `6184e52` (F2-5) |
| CT-04 | crier | out (reply) | `scripts/node-bus-worker.py:1176` builds `{status:"failed"/"completed", dispatch_id, corr_id, …}` (`:1176-1192`) and `:1208` `deliver()` POSTs it to `/agents/{target}/inbox` | crier `internal/registry/handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport)** — crier accepts the reply verbatim. CF-355 is **this reply's** settlement defect: the node sends `status` (`:1180`), the scheduler's `dispatchReplyVerdict` reads only `ok` — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-09 | duckbrain | out | **missing** — no in-repo producer: `grep -nE 'duckbrain|/api/memories' scripts/node-bus-worker.py` → 0 matches; the node's R1/R2 duckbrain sync is not implemented in the node worker | **external** — the duckbrain service (out of scope) | **missing** — OUTLINE Part IV marks `node → duckbrain` missing; no in-repo file on either side |
| CT-11 | sessionstore | out | **external** — the Hermes agent runtime records turns to its own `state.db` (out of scope; not a code-factory script) | **external** — the Hermes session store (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured; "works" is not asserted without a measured observation |

The real reply fields are `env_version, dispatch_id, corr_id, status, host_identity, harness,
vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at`
(`node-bus-worker.py:1176-1192`) — there is no `run_id`/`outcome` field (the OUTLINE §IV reply
shape is stale). CT-09 and CT-11 are boundary contracts: their far side is a service outside
the five covered systems, so the covered side is named and the far side is honestly marked
external. The state for a boundary contract with no measured wire is **UNVERIFIED** — an outline
"works" annotation is not implementation evidence (B03).

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/add_family_lanes.py scripts/configure_family.py scripts/load_lane_config.py scripts/lane_target.py scripts/node-bus-worker.py` | exit 0 | 2026-11-06 | PASS |
| lane target unit | `python3 tests/test_lane_target.py` | pass | 2026-11-06 | **PASS** (40 tests, rc 0) |
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
| — | `  FAIL  brief_digest — {label} brief.digest … — the brief was altered in flight; refused, not run` (`node-bus-worker.py:1263-1269`) | reachable node-adapter `node-dispatch.v1` digest mismatch over decoded text, gate, repo, ref, workdir and vars | evidentiary — refusal is before project, workdir, vars, harness and gate checks; the separate supervisor `cf.brief-input.v1` contract is normative in §15.1/Part IV |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `text_b64` undecodable | node refuses: "`text_b64` does not decode to UTF-8 text" (`:1022-1034`), no silent fallback to another member | a malformed dispatch | **resolved** — CF-354 (complete): the node decodes `text_b64` first and refuses a non-decoding value rather than reading a different member |
| Failed result recorded as success | scheduler pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (control-plane half, M9) |
| `configure_family` PID hardcode | config fails at import unless PID 1755676 is alive | a live scheduler | **OPEN** — F2-2 |
| `configure_family` partial write | one lane configured, fifteen fail, exit 0 | a full failure | **OPEN** — CF-356 |
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
    `complete` on the board (closed in commit `6184e52`). CF-355 (reply `status` vs `ok`) remains
    open.

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
is the normative reproducible vector: hash its `related_objects.brief_input_canonical_json`
bytes and compare with `related_objects.brief_input_sha256` and `brief_ref`.

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

The worker `launch_id` derives from the JCS array
`[project_id,round_id,wave_id,worker_id,attempt_id]` as specified in §15.4;
`execution_key = SHA256(JCS({launch_id,input_digest}))`. Dispatch/delivery IDs
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
10 s if needed, records quiescence or `STOP_UNKNOWN`, and requests fencing. Round and
attempt wall clocks start at the first durable release; restart cannot reset them.
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
request/event framing. The socket has mode 0600 and verifies peer UID. The
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

Execution identity is allocated before any process exists. `launch_id` is the
owner's stable logical-launch identity and
`execution_key = SHA256(JCS({launch_id,input_digest}))`. `input_digest` is the
SHA-256 of the complete resolved `LaunchInput` in RFC 8785 JCS, excluding the
digest member itself.

|| Role | launch_id derivation | Other identities |
|---|---|---|
|| foreman | `l-` + SHA-256(JCS(`["foreman",project_id,round_id,run_id]`)) | `execution_key` from launch ID/input digest; `dispatch_id="d-"+execution_key`; `native_name="cf-"+execution_key` |
|| worker | `l-` + SHA-256(JCS(`[project_id,round_id,wave_id,worker_id,attempt_id]`)) | the same execution-key, dispatch-ID and native-name derivation |

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

# M2 — DISPATCH (NODE SIDE)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCH (NODE SIDE) |
| Path | `/home/kara/code-factory/scripts/` — `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py`, `lane_target.py`, `node-bus-worker.py` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD at round-13 derivation; every file M2 cites is byte-identical since `47d68b4`) |
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
| S1 declare and configure lanes | `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py` | **operator-invoked** | no in-repo caller — `grep -rn 'add_family_lanes\|configure_family\|load_lane_config' scripts/` matches only the files themselves (run this round). `configure_family.py:24-28` reads the scheduler operator token at module import |
| S2 resolve a target | `lane_target.py` | **active** | `scripts/configure_family.py:17` imports it and `:149` calls `lane_target.parse(workdir)` then branches on the result — a production caller **in-repo** (grok 3 / sol B09). Round-4's "no production caller" was false. Passing the parse does not prove a remote checkout exists (it is structural parsing, not remote verification) |
| S3 consume the inbox, sign, reply | `node-bus-worker.py` | **active** | decodes the directive (`directive_text`, `:977`), consumes one dispatch (`process`, `:1007`), builds the reply (`:1176-1192`), delivers (`:1208`), settles (`:1389-1422`) |

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

**`--dry-run` custody note (B08, added this round).** `--dry-run` (`node-bus-worker.py:1437-1441`, help "fetch and print the plan; run/post/ack nothing") does **not** avoid inbox custody mutation: `:1381-1385` prints `BUS WORKER: DRY RUN — nothing executed, nothing posted, nothing acked ({n} message(s) leased for {lease}s and left to expire)` — the messages were already **leased** before the dry-run branch, so a dry run holds inbox messages until their lease expires. It skips execution/post/ack, not the lease. The dry-run lease is **5 s** (`:1312` `lease = 5 if args.dry_run else args.lease_seconds`), not the configured `--lease-seconds` — a dry run holds each retrieved message for 5 s, distinct from a real run's lease. Unregistered operational overrides: `--home`, `--identity`, `--bus-identity`, `--key`, `--token-file`, `--agent`, `--project`, `--crier`, `--workdir`, `--harness-cmd`, `--gateway-port` (`:1443-1476`) — these select identity/credentials/destination/executable template but are registered **NAME ONLY** (default/validation/consequence not individually stated), a named RED on this field, not a completed register.

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-03 | crier | in (inbox) | crier `internal/registry/handler.go:1690` `HandleRetrieve` (the lease-granting side) | `scripts/node-bus-worker.py:1007` `process` consumes one dispatch (decodes `text_b64` first via `directive_text` `:977`, then the legacy plain members for older senders) | **works** — CF-354 fixed in commit `1f1c0fe` (decodes `text_b64`), board-closed in commit `6184e52` (F2-5) |
| CT-04 | crier | out (reply) | `scripts/node-bus-worker.py:1176` builds `{status:"failed"/"completed", dispatch_id, corr_id, …}` (`:1176-1192`) and `:1208` `deliver()` POSTs it to `/agents/{target}/inbox` | crier `internal/registry/handler.go:990` `HandleDeliver` (accepts the reply verbatim) | **works (transport)** — crier accepts the reply verbatim. CF-355 is **this reply's** settlement defect: the node sends `status` (`:1180`), the scheduler's `dispatchReplyVerdict` reads only `ok` — carried at CT-04 (node reply), not CT-06 (the dispatcher leg) |
| CT-09 | duckbrain | out | **missing** — no in-repo producer: `grep -nE 'duckbrain|/api/memories' scripts/node-bus-worker.py` → 0 matches; the node's R1/R2 duckbrain sync is not implemented in the node worker | **external** — the duckbrain service (out of scope) | **missing** — OUTLINE Part IV marks `node → duckbrain` missing; no in-repo file on either side |
| CT-11 | sessionstore | out | **external** — the Hermes agent runtime records turns to its own `state.db` (out of scope; not a code-factory script) | **external** — the Hermes session store (out of scope) | **UNVERIFIED (boundary)** — neither side has an in-repo `file:function`, and the wire was not measured this round; "works" is not asserted without a measured observation |

The real reply fields are `env_version, dispatch_id, corr_id, status, host_identity, harness,
vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at`
(`node-bus-worker.py:1176-1192`) — there is no `run_id`/`outcome` field (the OUTLINE §IV reply
shape is stale). CT-09 and CT-11 are boundary contracts: their far side is a service outside
the five covered systems, so the covered side is named and the far side is honestly marked
external. The state for a boundary contract with no measured wire is **UNVERIFIED** — an outline
"works" annotation is not implementation evidence (sol B03).

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/add_family_lanes.py scripts/configure_family.py scripts/load_lane_config.py scripts/lane_target.py scripts/node-bus-worker.py` | exit 0 | 2026-11-06 | PASS |
| lane target unit | `python3 tests/test_lane_target.py` | pass | 2026-11-06 | **PASS** (40 tests, rc 0) |
| bus worker ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox GET → 200 with key+bearer | 2026-11-05, cf-node only | **UNVERIFIED** — a single-host 2026-11-05 run (FACT-04) is provenance, not this round's measured result; not repeatable from this control host (`~/node-bus-worker.py` does not exist here) |

## 8. Metrics

**RED — none (absence-proved this round).** The node-side dispatch path emits no counters or
gauges. `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics'
scripts/node-bus-worker.py scripts/lane_target.py scripts/configure_family.py
scripts/add_family_lanes.py scripts/load_lane_config.py` → 0 matches. Dispatch count, reply latency
and refusal count are answerable only by grepping the bus worker log.

## 9. Log lines (verbatim)

The worker does **not** source `lib.sh` — it is Python. It re-implements `lib.sh`'s row
vocabulary locally at `node-bus-worker.py:129-141` (`def ok` `:129` prints `  PASS  {name} — {value}`,
`def bad` `:133` → `  FAIL …`, `def warn` `:137` → `  WARN …`, `def note` `:141` → `  ..    …`), a
copy that can drift (the reason M0 F0-4 matters). **Scope (B09, measured this round):**
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
| — | `  FAIL  brief_digest — {label} brief.digest {expected[:16]}… != sha256(text) {actual[:16]}… — the brief was altered in flight; refused, not run` (`node-bus-worker.py:1050-1052`) | dispatch digest != sha256(text) | evidentiary — a brief.digest mismatch is refused, not warned |

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
  - **F2-4** (corrected) — round-4 said `add_family_lanes.py`/`configure_family.py`/
    `load_lane_config.py` **and** `lane_target.py` have no in-repo production caller. The S1 trio's
    "no caller" holds, but `lane_target.py` (S2) **does** have one: `configure_family.py:17,149`.
    S1 activation remains operator/fleet-config invoked; S2 is active via `configure_family.py`.
  - **F2-5** (new) — CF-354 was the node reading `text` while the scheduler sent `text_b64`. The
    node now decodes `text_b64` first (`directive_text`, `:989-999`) and falls back to the legacy
    plain members for older senders. The contract state moved from broken to works; CF-354 is
    `complete` on the board (closed in commit `6184e52`). CF-355 (reply `status` vs `ok`) remains
    open.

## RED field count: 3 (Metrics §8; §7 live bus-worker ladder not repeatable from this host; §9 inventory 4 of 70 helper call sites — the descriptive per-measurement rows not tabulated one-per-site)

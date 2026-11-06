# M2 — DISPATCH (NODE SIDE)

## 1. Identity

| Field | Value |
|---|---|
| Module name | DISPATCH (NODE SIDE) |
| Path | `/home/kara/code-factory/scripts/` — `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py`, `lane_target.py`, `node-bus-worker.py` |
| Revision | `943ef984dc093e5780605ac6e54cd043122126ef` (code-factory HEAD, 2026-11-06) |
| Language / runtime | Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side); consumes scheduler + crier |
| Status | **VERIFIED** for `node-bus-worker.py` contracts (imports `:66-78`, `text` read `:986`, reply shape `:1128-1144`, settlement `:1300-1367`, CLI `:1430-1478`, `dispatch_wall` `:1152-1157`); `add_family_lanes.py`/`configure_family.py`/`load_lane_config.py` structure-mapped only |

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
| S3 consume the inbox, sign, reply | `node-bus-worker.py` | **active** | reads the inbox (`:986`), replies (`:1160`), acks (`:1185`), settles (`:1300-1367`) |

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
| `agent.key` + `crier.json` | present at `~/.node/` | node | `node-bus-worker.py:381-382` binds `key_path`/`bus_path`; `:603` `bad("identity", f"{ident.error}; refusing")` |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `urllib.request` | stdlib | `node-bus-worker.py:66-78` imports urllib, **not** `crier_client`; the node speaks HTTP + ed25519 signing itself | n/a (stdlib) |
| `lib.sh` / `harness-vars.sh` | this repo | shell helpers + CF_* validation on the run path | see M0 / M5 |

**4c. Service contracts** — see §6.

## 5. Settings register

`node-bus-worker.py` fixes the run-budget and inbox constants (`:80-114`) and the CLI
(`:1430-1478`):

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_MAX_TURNS` | 40 (`:112`) | 1..1000 (`:112`) | turn budget | out of range refused |
| `CF_TIMEOUT_S` | 1800 (`:113`) | 1..86400 | wall-clock per turn | out of range refused |
| `DEFAULT_INBOX_LIMIT` | 10 (`:80`) | positive int; **the bus caps a batch at 100** (`internal/registry/handler.go:1718-1731` returns 400 `max must be <= 100`) | inbox batch size | larger batches raise per-poll latency; a value >100 is refused by the bus, not the worker |
| `DEFAULT_LEASE_SECONDS` | 30 (`:81`) | positive int | lease on each retrieve | too long holds messages during a crash |
| `SEEN_LIMIT` | 200 (`:84`) | positive int | idempotency window | smaller window re-runs a redelivered dispatch |
| `--reply-to` | `"scheduler"` (`:1432`) | an agent id | result recipient when the dispatch names none | a wrong default drops replies |
| `--wait-seconds` | 0 (`:1438`) | 0..120 (`:1463`) | inbox long-poll budget | outside 0..120 → exit 2 ("the bus answers 400 outside it") |
| `--interval` | 15 (`:1441`) | positive int | seconds between `--loop` polls | 0 starves the loop |
| `--harness-wall` / `--timeout` | `DEFAULT_HARNESS_WALL` / `DEFAULT_TIMEOUT` (`:1446-1449`) | positive int | per-run wall / per-request timeout | see F2-3 for the wall fallback |

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M2-C1 | scheduler | in (via crier) | `<scheduler>/internal/bus/dispatch.go:202` `payload()` emits `text_b64` (base64) | `scripts/node-bus-worker.py:986` reads `dispatch.get("text")` | **broken** — CF-354: the node reads `text`, the scheduler sends `text_b64` |
| M2-C2 | node | out (reply) | `scripts/node-bus-worker.py:1128` builds `{status:"failed"/"completed", dispatch_id, corr_id, …}` | scheduler `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only `payload["ok"]` | **broken** — CF-355: the node sends `status`, the scheduler reads `ok` |

The real reply fields are `env_version, dispatch_id, corr_id, status, host_identity, harness,
vars, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at`
(`node-bus-worker.py:1128-1144`) — there is no `run_id`/`outcome` field (the OUTLINE §IV reply
shape is stale).

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| python compile | `python3 -m py_compile scripts/add_family_lanes.py scripts/configure_family.py scripts/load_lane_config.py scripts/lane_target.py scripts/node-bus-worker.py` | exit 0 | 2026-11-06 | PASS |
| lane target unit | `python3 tests/test_lane_target.py` | pass | 2026-11-06 | **PASS** (40 tests, rc 0) |
| bus worker ladder | `python3 ~/node-bus-worker.py --check` on cf-node | inbox GET → 200 with key+bearer | 2026-11-05, cf-node only | PASS (FACT-04) — **not repeatable from this control host** (`~/node-bus-worker.py` does not exist here) |

## 8. Metrics

**RED — none (absence-proved this round).** The node-side dispatch path emits no counters or
gauges. `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics'
scripts/node-bus-worker.py scripts/lane_target.py scripts/configure_family.py
scripts/add_family_lanes.py scripts/load_lane_config.py` → 0 matches. Dispatch count, reply latency
and refusal count are answerable only by grepping the bus worker log.

## 9. Log lines (verbatim)

The worker prints via `lib.sh` helpers plus three local aliases (`node-bus-worker.py:124-137`:
`PASS`/`FAIL`/`WARN`/`..`). The observable surface is therefore per-measurement helper rows, not a
fixed set of distinct strings; the evidentiary rows are the refusals, which name the rule:

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`node-bus-worker.py:125,129`) | every measurement row | descriptive (same rule as M0 F0-4) |
| — | `  FAIL  identity — …; refusing` (`:603`) | unparseable/absent identity | evidentiary |
| — | `inbox — GET /agents/cf-node/inbox/stats -> 200` | a valid signed inbox read (FACT-04) | evidentiary |
| — | `  FAIL  brief_digest — {label} brief.digest {expected[:16]}… != sha256(text) {actual[:16]}… — the brief was altered in flight; refused, not run` (`node-bus-worker.py:1002-1005`) | dispatch digest != sha256(text) | evidentiary — a brief.digest mismatch is refused, not warned |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `text_b64` vs `text` mismatch | node refuses: "carries no `text`" (`:987-991`) | a malformed dispatch | **OPEN** — CF-354 |
| Failed result recorded as success | scheduler pass for a `status:"failed"` reply | a real pass | **OPEN** — CF-355 (control-plane half, M9) |
| `configure_family` PID hardcode | config fails at import unless PID 1755676 is alive | a live scheduler | **OPEN** — F2-2 |
| `configure_family` partial write | one lane configured, fifteen fail, exit 0 | a full failure | **OPEN** — CF-356 |
| Un-FK-checked clone namespace | a cloned lane's workdir may not exist | a validated clone | **OPEN** — CF-358 |
| Seen-cache not persisted | `could not record the seen-cache` (`:1355`) | a durable idempotency window | a redelivery after a crash re-runs — the cache write failure only warns |

## 11. Limits and margins

- The node refuses a dispatch without a `text` directive (`:987`) and a `brief.digest` mismatch
  (`:997-1012`), before any network work.
- **`dispatch_wall` correction (F2-3).** `node-bus-worker.py:1152-1157` accepts a numeric value
  only when `0 < wall <= 86400` and returns `int(wall)`; otherwise it falls back to
  `args.harness_wall` or `DEFAULT_HARNESS_WALL`. It does **not** clamp: a fractional positive below
  1 is converted by `int()` to **0** (not refused), and an out-of-range value falls back rather
  than being bounded.
- **Settlement ordering (B10, read this round).** `node-bus-worker.py:1300-1367`: execute
  (`process`) → deliver each result → write the seen-cache **only after delivery succeeds**
  (`seen[key] = result` when `delivered_ok`) → ack last. `save_seen` failure only warns (`:1352-1354`),
  so a crash before persistence is not covered by durable replay; ack is skipped when delivery
  failed, "so redelivery is the safer outcome" (`:1358-1365`).
- **Same-batch duplicate (B10 correction, sol B10).** `node-bus-worker.py:1304-1331` processes every
  leased message in a batch using the *same initially loaded* `seen` dictionary; the cache is not
  updated until the later delivery loop (`:1341-1347`). Two previously-unseen messages sharing one
  dispatch key in a single retrieved batch therefore **both execute** before either result enters the
  cache. The idempotency window only deduplicates across batches, not within one. Round-4's
  "crash-before-persistence" discussion missed this same-batch case.

## 12. Cross-references

- F1 DISPATCH AND SETTLEMENT is the primary flow; the node is the terminal actor.
- M9 SCHEDULER is the producer of M2-C1 and the settlement consumer of M2-C2.
- M11 DISPATCHER is the *other* inbox consumer, which **does** decode `text_b64`
  (`dispatcher.py:142-150`) — the two consumers disagree, which is the root of CF-354.
- **M5 HARNESS owns the CF_* variable contract (M5.S5 `harness-vars.sh`),** not M0 — see M0 §12
  and M5 §5. The node passes the CF_* set to the harness at run time.

## 13. Evidence of record

- Code read: `node-bus-worker.py:60-129, 381-382, 975-1014, 1115-1224, 1152-1157, 1300-1367, 1430-1478`.
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

## RED field count: 2 (Metrics §8, §7 live bus-worker ladder not repeatable from this host)

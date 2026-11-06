# HANDBOOK OUTLINE v2 — corrected by quorum

Five families reviewed v1. **Verdicts: 2 REJECT, 3 ACCEPT WITH CORRECTIONS.** All five
failed the merge proposal, and four of five graded v1 **not buildable as written**.

The correction that mattered most, named independently by four seats: **v1 documented
code-factory and left the scheduler, the bus, the dispatcher and the inference proxy as
entries in a contract table rather than as systems.** A reader cannot operate a fleet
from the node's side of it. They are now modules M9–M12.

---

## PART I — SYSTEM ARRANGEMENT

I.1 Purpose and the one idea
I.2 Actors and trust boundary
I.3 Layer arrangement and component boxes
I.4 Component register — owns / does-not-own / where it lives today
I.5 Contract register — 18 interfaces, measured state (10 works, 6 broken, 2 missing)
I.6 Invariants — what must always hold
I.7 Non-goals and why
I.8 Surface inventory — every entry point derived, not imagined
I.9 **What this census does NOT cover** — named areas, and services described only from
    the client side. Mandatory: a set that claims coverage it does not have was the root
    complaint in both quorum rounds.

## PART II — FLOWS (16)

Each flow: trigger · observable exit · actors · preconditions · numbered steps each
naming its module · branches and error paths · state transitions · data read/written by
contract id · timing, limits, retries, idempotency · duplicate/concurrent case ·
day-one/empty case · degradation path · diagram.

**Primary (5, rendered today)**
- **F1 DISPATCH AND SETTLEMENT** — *rescoped*: begins at the node's inbox (admission is
  F11). Exit is a correlated terminal result persisted, or a named refusal / deadline /
  uncertain result — the reply accepted by the bus **and** the acknowledgement recorded.
  v1 conflated transport acceptance with completed work. *(RENDERED)*
- **F2 PROVISIONING AND CERTIFICATION** — exit is certification legs passing, or the
  exact failed or unmeasurable legs named. Must distinguish **CREATED** from **VERIFIED**.
  *(RENDERED)*
- **F3 RUN CAPTURE AND SEARCH** *(RENDERED)*
- **F4 DOCUMENTATION** *(RENDERED)*
- **F5 LANDING** *(RENDERED)*

**Secondary (5, missing — the panel's largest single finding)**
- **F6 MAINTENANCE** — disks, branches, caches, freshness *(MISSING)*
- **F7 MONITORING** — how anyone learns the machine is unwell *(MISSING)*
- **F8 RECOVERY** — after a crash, restart or orphaned run *(MISSING)*
- **F9 DEGRADATION** — a dependency is gone; what the system does *(MISSING)*
- **F10 TEARDOWN / REBUILD** — removing a node or lane without residue *(MISSING)*

**Added by quorum (6)**
- **F11 SCHEDULING ADMISSION** — trigger: a lane's cadence tick fires; exit: admitted to
  the crier envelope, or refused with a named reason (budget hold, cooldown, load gate,
  fairness, namespace allocation). *(MISSING)*
- **F12 CREDENTIAL LIFECYCLE** — trigger: near-expiry, or a new agent or box; exit: fresh
  credential on disk at 0600, the old one rotated, no long-lived token in argv. *(MISSING)*
- **F13 UPGRADE AND MIGRATION** — trigger: a pinned version bump or a schema change; exit:
  the running artifact's version read back, and the DB migrated. *(MISSING)*
- **F14 OBSERVABILITY INGESTION** — trigger: every tick, turn and message; exit: the row
  or line is visible and attributed where a human will look for it. *(MISSING)*
- **F15 BACKUP AND RESTORE** — trigger: schedule, or detected corruption; exit: an
  artifact restored into a scratch home and a known row read back. *(MISSING)*
- **F16 MULTI-NODE FAN-OUT** — trigger: a lane or row targeting more than one node; exit:
  every target acknowledged, each with its own receipt. *(MISSING)*

## PART III — MODULES (13 modules, 34 submodules)

### Chapter headings — corrected

v1's eleven headings produced introductions that say nothing. The corrected thirteen,
each with what it prevents:

1. **Purpose, authority and operational position** — prevents "this script is an
   important part of the pipeline". Requires what it decides, what it may not decide,
   and where it sits.
2. **Consequences of absence, and of false report** — merged from v1's "why it matters";
   prevents "without this the system would not work correctly."
3. **Submodule inventory** — per submodule: responsibility, owner, invocation, execution
   location, producer/consumer links, and classification (active / optional / legacy /
   designed-not-built).
4. **Dependencies** — runtime (version, required location, **how absence is detected**) ·
   library (the call or field relied on) · service (**both sides' file and function**).
5. **Settings register** — every env var, flag, timeout, cap, floor and rate: default,
   valid range, what it governs, what breaks if changed, who reads it.
6. **Contracts in and out** — by contract id, with measured state.
7. **Verification** — commands a stranger can run, expected output, date, revision.
8. **Metrics** — type, labels, the question answered, where scraped. **"None" is RED.**
9. **Log lines** — verbatim, classified **descriptive** or **evidentiary**.
10. **Failure modes, indications and recovery** — how it presents, how it is told from
    its neighbour, what the operator does, and the expected indication after each step
    (Apollo procedure style).
11. **Limits and margins** — hard limits, derating, worst measured case, and what has
    never been measured.
12. **Cross-references** — the flow that uses it, adjacent modules, the page to turn to.
13. **Evidence of record** — board rows, verdicts, run ids, log excerpts with timestamps.

### Merge proposal: REJECTED (5/5)

Criterion, from Sol: *an independently operated responsibility with its own authority,
state, controls, failure consequences or recovery procedure remains independently
addressable.* GLM added the decisive test: M3 owns F5 LANDING — a primary flow — so
folding it into "supporting" leaves a primary flow with no owning chapter. All 13
modules get their own chapter.

### Node-side modules
- **M0 SHARED CONTRACT** — M0.S1 shell contract (`lib.sh`)
- **M1 PROVISIONING** — S1 qualify the host (`bunker-server-install.sh`, `disk_floor.py`) ·
  S2 create the container and its config (`bunker-provision.sh`, `bunker_config_gen.py`,
  `node-create.sh`, `bunker-crier-connect.sh`) · S3 identity and bus membership
  (`node_identity.py`, `node_gateway_auth.py`) · S4 seed prompts, skills and env
  (`node_seed.py`, `node_seed_drift.py`, `node_env.py`) · S5 prove the node works
  (`verify-node.sh`, `node_freshness.py`)
- **M2 DISPATCH (NODE SIDE)** — S1 declare and configure lanes (`add_family_lanes.py`,
  `configure_family.py`, `load_lane_config.py`) · S2 resolve a target (`lane_target.py`) ·
  S3 consume the inbox, sign, reply (`node-bus-worker.py`)
- **M3 REPOSITORY** — S1 clone and track freshness (`clone_lane.py`,
  `repo_freshness.py`) · S2 land a branch (`land-node-branch.sh`)
- **M4 BOARD** — S1 write and validate rows (`boardctl`, `board_lock.py`) · S2 compare
  board copies (`board_drift.py`)
- **M5 HARNESS** — S1 hermes (`install-hermes.sh`) · S2 foreign harnesses (**hermes,
  codex, claude-code, opencode, deepseek, pi-agent** — v1 omitted two) · S3 toolchain,
  gate and node entry (`install-go.sh`, `install-gitreins.sh`, `project-node.sh`) ·
  **S4 harness resolution** (`harness_resolve.py`, `specs/HARNESS-MATRIX.md` §4) ·
  **S5 variable contract** (`harness/harness-vars.sh`, matrix §5, sourced by every
  installer)
- **M6 DOCUMENTATION** — S1 skeleton and census (`master_doc_skeleton.py`) · S2 fill
  (`master_doc_fill.py`) · S3 gate (`master_doc_check.py`) · S4 panel
  (`master_doc_panel.py`) · S5 render (`gen_nasa_handbook.py`, `gen_system_views.py`,
  `sheet_style.py`) · S6 corpus (`extract_owner_decisions.py`) · **S7 unit-map
  generation** (`gen_unit_map.py`) · **S8 patch-chain drift gate** (`verify-patch.sh`)
- **M7 GITHUB** — S1 app credentials (`github-app-setup.sh`, `github-app-token.py`,
  `github-app-refresh.sh`)
- **M8 SAFETY** — S1 disk (`reclaim_disk.py`) · S2 scan scope (`check_scan_scope.py`)

### Control-plane modules (new — the v1 omission)
- **M9 SCHEDULER** — S1 **admission and allocation** (`admission_mode`, `tick_process`,
  `packer_select`, `namespace_alloc`, `usage_pool_policy`: eligibility, tasks-vs-cooldown,
  board gates, fairness, budget reservation) · S2 **execution and settlement** (`spawn`,
  `slot_pool`, `lifecycle`, `dispatch_leg`: local vs remote, queue→running→terminal,
  deadlines, circuit behaviour, accounting, recovery) · S3 **durable state**
  (`scheduler.db`, 26 tables: ticks, tick_dispatch, tick_workers, execution_*,
  deferrals, usage_pool*, verdicts) · S4 **operator surfaces** (`cmd/schedulerd`,
  `scheduler-dispatch`, `scheduler-query`, `queueprobe`, `migrate`; HTTP API, dashboard,
  MCP, lanehook, remote, bus) · S5 **doctrine** (scheduler-rules, dispatch-spec,
  execution-contracts, execution-store, drain-restart, hop-liveness-watchdog)
- **M10 CRIER** — S1 **custody and transport** (registration, routing, acceptance,
  idempotency, retrieval, leases, ack, TTL, transfer, dead letters, backend selection) ·
  S2 **the guard** (pattern pre-scan → render → router verdict → escalation →
  quarantine) · S3 **binaries, ports and services** (server :8767 / :18767, front :8770,
  mcp, deploy units) · S4 **client libraries** (`crier_client.py` + typescript — a
  versioned contract consumed by both the node worker and the dispatcher, previously
  undocumented)
- **M11 DISPATCHER** (`crier-fleet`) — S1 **job model and durable execution**
  (`dispatch_durable`: start, poll, kill process group) · S2 ledger and idempotency ·
  S3 completion bridge (reply encoding, guard interaction) · S4 agent registry and scope
- **M12 INFERENCE PROXY** — S1 admission (token → node, model allowlist, fail-closed) ·
  S2 upstream routing (gateway vs direct provider, model rewrite) · S3 stream
  pass-through · S4 usage and request capture

## PART IV — CONTRACTS (18)

Each contract names **both sides**: producer file:function, consumer file:function,
payload, timing, failure semantics, measured state, breaking-change policy. Current:
**0 of 18** name both implementations.

- **owner → scheduler** — lane enabled, cadence, weight, pin · **works**
- **scheduler → crier** — envelope: run_id, corr_id, lane, board_row, text_b64 · **broken**
- **crier → node** — inbox message + lease · **works**
- **node → crier** — reply: in_reply_to, corr_id, run_id, outcome · **broken**
- **foreman → scheduler** — the lane's prompt text and skills it may load · **broken**
- **crier → scheduler** — completion event for a finished run · **missing**
- **router → gateway** — model choice for a prompt · **works**
- **crier → gateway** — hermes-session delivery (message becomes a session turn) · **works**
- **node → duckbrain** — R1 run record, R2 fleet index · **missing**
- **node → board** — row event with run_id and outcome · **broken**
- **node → sessionstore** — every turn, model, tokens · **works**
- **node → gitreins** — staged diff · **works**
- **gitreins → board** — verdict that closes a row · **broken**
- **foreman → board** — row created, row closed, evidence · **works**
- **foreman → duckbrain** — decisions, findings, goal · **works**
- **docsgate → handbook** — module status word · **works**
- **conformance → harness** — per-leg verdict (check, apply, smoke, vars, memory) · **broken**
- **handbook → owner** — the approval artifact · **works**

## PART V — SETTINGS REGISTER

V.1 Environment variables (~83 measured) · V.2 CLI switches (~215) ·
V.3 Timeouts, caps, floors and rates · V.4 Provider and model routing ·
V.5 Paths and filesystem contracts · V.6 Scheduler configuration
(`config.example.toml`: intervals, weight budget, max_concurrent, tick timeout)

## PART VI — RISK AND UNKNOWNS

VI.1 Known knowns (measured, with how measured) · VI.2 Known unknowns (probe · falsifier ·
who can answer · blocking?) · VI.3 Unknown unknowns (found by comparison · converted to a
measurement or a decision) · VI.4 Unknown knowns (operator constraints, with source) ·
VI.5 **Promotion log** — what moved quadrant, when, why · VI.6 Rejected findings and why

## PART VII — WORK DERIVATION

VII.1 Requirement table (R-nnn · statement · module · assertion · evidence) ·
VII.2 Task list derived from chapters, each citing the section it closes ·
VII.3 **Acceptance gate per chapter** — what makes a chapter WRITTEN rather than merely
present

## PART VIII — DELIVERY MECHANISMS (new)

Shipped mechanisms that change system behaviour and had no chapter:
- **VIII.1 `prompts/`** — 11 files; the `foreman → scheduler` contract is **broken**
  because 3 of 11 disagree
- **VIII.2 `skills/`** — seeded to every node; a node's behaviour changes with the seed
- **VIII.3 `config/`** — harness-matrix, node-seed, node.env.example, bunker.example,
  github-app.example
- **VIII.4 `patches/`** — fleet-ops patch chain with `.orig` base and sha256 chain
- **VIII.5 `tests/`** — selftest, conformance battery, per-unit falsifiers

## APPENDICES

A — Per-unit evidence sections (47 files, `appendices/units/`) · B — Quorum verdicts by
round (`_quorum-*/`) · C — Field contract (`docs/MASTER-DOC-SCHEMA.md`) · D — Change log
and supersession record

---

## Counts

| Item | v1 | v2 |
|---|---|---|
| Parts | 7 | 8 |
| Flows | 10 | 16 |
| Modules | 9 | 13 |
| Submodule chapters | 25 | 34 |
| Headings per chapter | 11 | 13 |
| Coverage gaps folded in | — | 22–28 per seat |

**Buildability:** v1 was graded NO by four of five seats. v2 adds the sub-items they
named as missing — classification per submodule, absence-detection per dependency,
expected indication per recovery step, limits and margins, cross-references.

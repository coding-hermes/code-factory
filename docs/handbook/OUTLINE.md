# HANDBOOK OUTLINE — every part, chapter and heading

This is the table of contents we are building to. Nothing here is written yet
unless marked; it exists so the writing has a fixed target and so a missing
chapter is visible as a gap rather than discovered after 277 pages.


## PART I — SYSTEM ARRANGEMENT

- [ ] I.1 Purpose and the one idea
- [ ] I.2 Actors and trust boundary
- [ ] I.3 Layer arrangement and component boxes
- [ ] I.4 Component register (owns / does-not-own / where it lives)
- [ ] I.5 Contract register (18 interfaces, measured state)
- [ ] I.6 Invariants (what must always hold)
- [ ] I.7 Non-goals and why
- [ ] I.8 Surface inventory (entry points derived, not imagined)
- [ ] I.9 What this census does NOT cover

## PART II — OPERATIONAL FLOWS (10)

Every flow carries: trigger · exit · actors · preconditions · numbered steps (each naming its module) · branches and error paths · state transitions · data read/written by contract id · timing, limits, retries, idempotency · duplicate/concurrent case · day-one case · diagram.

- [ ] **F1 — DISPATCH** (primary) — How does a board row become work?  ·  *RENDERED*
- [ ] **F2 — PROVISIONING** (primary) — How does a bare host become a node?  ·  *RENDERED*
- [ ] **F3 — MEMORY** (primary) — How does a run become searchable?  ·  *RENDERED*
- [ ] **F4 — DOCUMENTATION** (primary) — How does a component become an approved document?  ·  *RENDERED*
- [ ] **F5 — LANDING** (primary) — How does work reach main?  ·  *RENDERED*
- [ ] **F6 — MAINTENANCE** (secondary) — What keeps the disks, branches and caches from decaying?  ·  *MISSING*
- [ ] **F7 — MONITORING** (secondary) — How does anyone learn the machine is unwell?  ·  *MISSING*
- [ ] **F8 — RECOVERY** (secondary) — What happens after a crash, restart or orphaned run?  ·  *MISSING*
- [ ] **F9 — DEGRADATION** (secondary) — What does the system do when a dependency is gone?  ·  *MISSING*
- [ ] **F10 — TEARDOWN / REBUILD** (secondary) — How is a node or lane removed without residue?  ·  *MISSING*

## PART III — SUBSYSTEMS (9 modules, 25 submodules)

Every chapter carries the same 11 headings, in this order:

- III.x.1 Identity and position in the pipeline
- III.x.2 Why it matters — what breaks if absent, what breaks if it lies
- III.x.3 Submodule inventory and the units that serve it
- III.x.4 Dependencies: runtime · library · service (both sides named)
- III.x.5 Settings register — every env var, flag, timeout, cap, default and range, with what changes if it changes
- III.x.6 Contracts in and out
- III.x.7 Verification — the commands, expected output, date, revision
- III.x.8 Metrics emitted
- III.x.9 Log lines — verbatim, descriptive vs evidentiary
- III.x.10 Failure modes and recovery
- III.x.11 Evidence of record

### Module chapters

- [ ] **III.1 — SHARED CONTRACT** — everything below depends on this; it changes alone at your peril
  - [ ] III.1.1 — shell contract  ·  `lib.sh`
- [ ] **III.2 — PROVISIONING** — a bare host becomes a node with an identity, a bus membership and a seeded repo
  - [ ] III.2.1 — qualify the host  ·  `bunker-server-install.sh`, `disk_floor.py`
  - [ ] III.2.2 — create the container and its config  ·  `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh`
  - [ ] III.2.3 — identity and bus membership  ·  `node_identity.py`, `node_gateway_auth.py`
  - [ ] III.2.4 — seed prompts, skills and env  ·  `node_seed.py`, `node_seed_drift.py`, `node_env.py`
  - [ ] III.2.5 — prove the node works  ·  `verify-node.sh`, `node_freshness.py`
- [ ] **III.3 — DISPATCH** — whose turn it is becomes a brief, a run and a reply
  - [ ] III.3.1 — declare and configure lanes  ·  `add_family_lanes.py`, `configure_family.py`, `load_lane_config.py`
  - [ ] III.3.2 — resolve a target  ·  `lane_target.py`
  - [ ] III.3.3 — consume the inbox, sign, reply  ·  `node-bus-worker.py`
- [ ] **III.4 — REPOSITORY** — the node has the right tree, and work can leave it
  - [ ] III.4.1 — clone and track freshness  ·  `clone_lane.py`, `repo_freshness.py`
  - [ ] III.4.2 — land a branch  ·  `land-node-branch.sh`
- [ ] **III.5 — BOARD** — the fleet remembers what it decided and what it proved
  - [ ] III.5.1 — write and validate rows  ·  `boardctl`, `board_lock.py`
  - [ ] III.5.2 — compare board copies  ·  `board_drift.py`
- [ ] **III.6 — HARNESS** — the agent inside the node can actually code, and its commits are graded
  - [ ] III.6.1 — hermes  ·  `install-hermes.sh`
  - [ ] III.6.2 — foreign harnesses  ·  `install-codex.sh`, `install-claude-code.sh`, `install-opencode.sh`
  - [ ] III.6.3 — toolchain, gate and node entry  ·  `install-go.sh`, `install-gitreins.sh`, `project-node.sh`
- [ ] **III.7 — DOCUMENTATION** — the system describes itself, and someone can check the description
  - [ ] III.7.1 — skeleton and census  ·  `master_doc_skeleton.py`
  - [ ] III.7.2 — fill  ·  `master_doc_fill.py`
  - [ ] III.7.3 — gate  ·  `master_doc_check.py`
  - [ ] III.7.4 — panel  ·  `master_doc_panel.py`
  - [ ] III.7.5 — render  ·  `gen_nasa_handbook.py`, `gen_system_views.py`
  - [ ] III.7.6 — corpus  ·  `extract_owner_decisions.py`
- [ ] **III.8 — GITHUB** — the fleet can authenticate to the forge without a long-lived token in argv
  - [ ] III.8.1 — app credentials  ·  `github-app-setup.sh`, `github-app-token.py`, `github-app-refresh.sh`
- [ ] **III.9 — SAFETY** — the checks that must be able to fail, and the disk they must not fill
  - [ ] III.9.1 — disk  ·  `reclaim_disk.py`
  - [ ] III.9.2 — scan scope  ·  `check_scan_scope.py`

## PART IV — CONTRACTS (18)

Each contract names **both sides**: producer file:function, consumer file:function, payload, timing, failure semantics, measured state, breaking-change policy.

- [ ] **owner → scheduler** — lane enabled, cadence, weight, pin · state: **works**
- [ ] **scheduler → crier** — envelope: run_id, corr_id, lane, board_row, text_b64 · state: **broken**
- [ ] **crier → node** — inbox message + lease · state: **works**
- [ ] **node → crier** — reply: in_reply_to, corr_id, run_id, outcome · state: **broken**
- [ ] **foreman → scheduler** — the lane's prompt text and skills it may load · state: **broken**
- [ ] **crier → scheduler** — completion event for a finished run · state: **missing**
- [ ] **router → gateway** — model choice for a prompt · state: **works**
- [ ] **crier → gateway** — hermes-session delivery (message becomes a session t · state: **works**
- [ ] **node → duckbrain** — R1 run record, R2 fleet index · state: **missing**
- [ ] **node → board** — row event with run_id and outcome · state: **broken**
- [ ] **node → sessionstore** — every turn, model, tokens · state: **works**
- [ ] **node → gitreins** — staged diff · state: **works**
- [ ] **gitreins → board** — verdict that closes a row · state: **broken**
- [ ] **foreman → board** — row created, row closed, evidence · state: **works**
- [ ] **foreman → duckbrain** — decisions, findings, goal · state: **works**
- [ ] **docsgate → handbook** — module status word · state: **works**
- [ ] **conformance → harness** — per-leg verdict (check, apply, smoke, vars, memory) · state: **broken**
- [ ] **handbook → owner** — the approval artifact · state: **works**

## PART V — SETTINGS REGISTER

- [ ] V.1 Environment variables (name · default · range · effect · who reads it)
- [ ] V.2 CLI switches (verb · flag · effect · misuse)
- [ ] V.3 Timeouts, caps, floors and rates (value · where enforced · what it governs)
- [ ] V.4 Provider and model routing settings
- [ ] V.5 Paths and filesystem contracts

## PART VI — RISK AND UNKNOWNS

- [ ] VI.1 Known knowns (measured facts, with how measured)
- [ ] VI.2 Known unknowns (probe · falsifier · who can answer · blocking?)
- [ ] VI.3 Unknown unknowns (found by comparison · converted to a measurement or a decision)
- [ ] VI.4 Unknown knowns (operator constraints, with source)
- [ ] VI.5 Promotion log — what moved quadrant, when, why
- [ ] VI.6 Rejected findings and why they were rejected

## PART VII — WORK DERIVATION

- [ ] VII.1 Requirement table (R-nnn · statement · module · assertion · evidence)
- [ ] VII.2 Task list derived from chapters, each citing the section it closes
- [ ] VII.3 Acceptance gate per chapter (what makes it WRITTEN, not merely present)

## APPENDICES

- [ ] A — Per-unit evidence sections (47 files, `appendices/units/`)
- [ ] B — Quorum verdicts by round (`_quorum-*/`)
- [ ] C — Field contract each chapter must satisfy (`docs/MASTER-DOC-SCHEMA.md`)
- [ ] D — Change log and supersession record

## Counts to build to

| Item | Count |
|---|---|
| Parts | 7 + appendices |
| Flows | 10 (5 rendered, 5 missing) |
| Modules | 9 |
| Submodule chapters | 25 |
| Contracts | 18 |
| Settings to register | ~83 env + ~215 flags (measured range across seats) |
| Unit evidence sections | 47 |

# CODE FACTORY — MASTER DOCUMENT SKELETON

Generated mechanically. Every **RED** is a claim that has no evidence yet,
not a section that is merely unwritten. A section turns green by running a command, never by editing prose.

Rows 1–44 are generated from the module files by the doc pipeline and were
never hand-edited. **Rows 45–63 are the exception**: hand-added CF-360 unit
records (2026-11-22), cross-checked by `scripts/master_doc_check.py`, which
recomputes every row's status below against its page and fails the gate on a
mismatch — a hand-added row cannot drift from its record silently.

| # | Module | Repo | Status |
|---|---|---|---|
| 1 | [`scripts/add_family_lanes.py`](01-scripts-add-family-lanes-py.md) | code-factory | UNVERIFIED |
| 2 | [`scripts/board_drift.py`](02-scripts-board-drift-py.md) | code-factory | VERIFIED |
| 3 | [`scripts/board_lock.py`](03-scripts-board-lock-py.md) | code-factory | VERIFIED |
| 4 | [`scripts/bunker-crier-connect.sh`](04-scripts-bunker-crier-connect-sh.md) | code-factory | UNVERIFIED |
| 5 | [`scripts/bunker-provision.sh`](05-scripts-bunker-provision-sh.md) | code-factory | VERIFIED |
| 6 | [`scripts/bunker-server-install.sh`](06-scripts-bunker-server-install-sh.md) | code-factory | VERIFIED |
| 7 | [`scripts/bunker_config_gen.py`](07-scripts-bunker-config-gen-py.md) | code-factory | VERIFIED |
| 8 | [`scripts/check_scan_scope.py`](08-scripts-check-scan-scope-py.md) | code-factory | VERIFIED |
| 9 | [`scripts/clone_lane.py`](09-scripts-clone-lane-py.md) | code-factory | VERIFIED |
| 10 | [`scripts/configure_family.py`](10-scripts-configure-family-py.md) | code-factory | VERIFIED |
| 11 | [`scripts/disk_floor.py`](11-scripts-disk-floor-py.md) | code-factory | VERIFIED |
| 12 | [`scripts/github-app-refresh.sh`](12-scripts-github-app-refresh-sh.md) | code-factory | VERIFIED |
| 13 | [`scripts/github-app-setup.sh`](13-scripts-github-app-setup-sh.md) | code-factory | VERIFIED |
| 14 | [`scripts/github-app-token.py`](14-scripts-github-app-token-py.md) | code-factory | VERIFIED |
| 15 | [`scripts/harness/install-claude-code.sh`](15-scripts-harness-install-claude-code-sh.md) | code-factory | VERIFIED |
| 16 | [`scripts/harness/install-codex.sh`](16-scripts-harness-install-codex-sh.md) | code-factory | VERIFIED |
| 17 | [`scripts/harness/install-hermes.sh`](17-scripts-harness-install-hermes-sh.md) | code-factory | VERIFIED |
| 18 | [`scripts/harness/install-opencode.sh`](18-scripts-harness-install-opencode-sh.md) | code-factory | RED |
| 19 | [`scripts/install-gitreins.sh`](19-scripts-install-gitreins-sh.md) | code-factory | VERIFIED |
| 20 | [`scripts/land-node-branch.sh`](20-scripts-land-node-branch-sh.md) | code-factory | VERIFIED |
| 21 | [`scripts/lane_target.py`](21-scripts-lane-target-py.md) | code-factory | VERIFIED |
| 22 | [`scripts/lib.sh`](22-scripts-lib-sh.md) | code-factory | VERIFIED |
| 23 | [`scripts/load_lane_config.py`](23-scripts-load-lane-config-py.md) | code-factory | VERIFIED |
| 24 | [`scripts/master_doc_skeleton.py`](24-scripts-master-doc-skeleton-py.md) | code-factory | VERIFIED |
| 25 | [`scripts/node-bus-worker.py`](25-scripts-node-bus-worker-py.md) | code-factory | RED |
| 26 | [`scripts/node-create.sh`](26-scripts-node-create-sh.md) | code-factory | VERIFIED |
| 27 | [`scripts/node_env.py`](27-scripts-node-env-py.md) | code-factory | VERIFIED |
| 28 | [`scripts/node_freshness.py`](28-scripts-node-freshness-py.md) | code-factory | VERIFIED |
| 29 | [`scripts/node_gateway_auth.py`](29-scripts-node-gateway-auth-py.md) | code-factory | VERIFIED |
| 30 | [`scripts/node_identity.py`](30-scripts-node-identity-py.md) | code-factory | VERIFIED |
| 31 | [`scripts/node_seed.py`](31-scripts-node-seed-py.md) | code-factory | VERIFIED |
| 32 | [`scripts/node_seed_drift.py`](32-scripts-node-seed-drift-py.md) | code-factory | VERIFIED |
| 33 | [`scripts/project-node.sh`](33-scripts-project-node-sh.md) | code-factory | VERIFIED |
| 34 | [`scripts/reclaim_disk.py`](34-scripts-reclaim-disk-py.md) | code-factory | VERIFIED |
| 35 | [`scripts/repo_freshness.py`](35-scripts-repo-freshness-py.md) | code-factory | VERIFIED |
| 36 | [`scripts/verify-node.sh`](36-scripts-verify-node-sh.md) | code-factory | VERIFIED |
| 37 | [`specs/ENVELOPE.md`](37-specs-envelope-md.md) | code-factory | VERIFIED |
| 38 | [`specs/HARNESS-MATRIX.md`](38-specs-harness-matrix-md.md) | code-factory | FAILING |
| 39 | [`specs/HARNESS.md`](39-specs-harness-md.md) | code-factory | VERIFIED |
| 40 | [`specs/NODE.md`](40-specs-node-md.md) | code-factory | RED |
| 41 | [`specs/FLEET-MEMORY.md`](41-specs-fleet-memory-md.md) | code-factory | RED |
| 42 | [`specs/TRACE.md`](42-specs-trace-md.md) | code-factory | RED |
| 43 | [`specs/HARNESS-MEMORY.md`](43-specs-harness-memory-md.md) | code-factory | RED |
| 44 | [`scripts/master_doc_*.py`](44-doc-pipeline.md) | code-factory | VERIFIED |
| 45 | [`tests/selftest.sh`](45-tests-selftest-sh.md) | code-factory | VERIFIED |
| 46 | [`prompts/foreman.md`](46-prompts-foreman-md.md) | code-factory | VERIFIED |
| 47 | [`skills/code-factory-bunker/SKILL.md`](47-skills-code-factory-bunker-skill-md.md) | code-factory | VERIFIED |
| 48 | [`skills/code-factory-foreman/SKILL.md`](48-skills-code-factory-foreman-skill-md.md) | code-factory | VERIFIED |
| 49 | [`config/bunker.example.conf`](49-config-bunker-example-conf.md) | code-factory | VERIFIED |
| 50 | [`config/github-app.example.env`](50-config-github-app-example-env.md) | code-factory | VERIFIED |
| 51 | [`config/harness-matrix.json`](51-config-harness-matrix-json.md) | code-factory | VERIFIED |
| 52 | [`config/node.env.example`](52-config-node-env-example.md) | code-factory | VERIFIED |
| 53 | [`config/node-seed.txt`](53-config-node-seed-txt.md) | code-factory | VERIFIED |
| 54 | [`docs/OPERATIONS.md`](54-docs-operations-md.md) | code-factory | VERIFIED |
| 55 | [`docs/BOARD.md`](55-docs-board-md.md) | code-factory | VERIFIED |
| 56 | [`docs/DESIGN.md`](56-docs-design-md.md) | code-factory | VERIFIED |
| 57 | [`docs/PRD-code-factory.md`](57-docs-prd-code-factory-md.md) | code-factory | VERIFIED |
| 58 | [`docs/THREAT-MODEL.md`](58-docs-threat-model-md.md) | code-factory | VERIFIED |
| 59 | [`docs/ACCEPTANCE-PLAN.md`](59-docs-acceptance-plan-md.md) | code-factory | VERIFIED |
| 60 | [`docs/MVP-PLAN.md`](60-docs-mvp-plan-md.md) | code-factory | VERIFIED |
| 61 | [`docs/SCHEDULER-ADMISSION.md`](61-docs-scheduler-admission-md.md) | code-factory | VERIFIED |
| 62 | [`docs/MASTER-DOC-SCHEMA.md`](62-docs-master-doc-schema-md.md) | code-factory | VERIFIED |
| 63 | [`docs/LOOP-CODEX.md`](63-docs-loop-codex-md.md) | code-factory | VERIFIED |

## Counts

Recomputed at this tip by `scripts/master_doc_check.py` — the gate recomputes each row's
status from its page, so a row that disagrees with its record fails the gate. The census
figures below were generated for rows 1–44 by `scripts/gen_nasa_handbook.py`; rows 45–63
are the hand-added CF-360 records (see the note above).

- Modules: **63** (54 VERIFIED, 9 not — the gate's count at this tip)
- Modules with a verification section: all 63 carry a `§3 Verification` section; whether
  the verification is *earned* is what the status column states
- Modules that emit metrics or state why not: all 63 carry a `§4 Metrics emitted` section
- Modules whose §2 names both sides of a service contract: see each §2

## What this census covers — and what it does not (read this before trusting the count)

The module set is now **system-shaped**: 63 unit records cover the repo's own scripts and
specs, the ten top-level documents, the five config examples, the foreman lane prompt, the
selftest battery and the two node-ops skills. It is still partial, and the remainder is
named, not hidden. Measured at HEAD `7299a127` (2026-11-22): tracked files per area, lines
= newline counts, with the 19 CF-360 record files themselves excluded from the denominator
— they are the census's output, not system surface (records 01–44 stay counted, as in the
first measurement at `8f77667b`).

| area | files | lines | under module records | uncovered remainder — named reason |
|---|---|---|---|---|
| `scripts/` | 80 | 32,648 | 40 files / 18,978 lines | 40 scripts / 13,670 lines — post-manifest additions not yet under a record: the handbook toolchain (`book_style.py`, `build_book.py`, `handbook_lint.py`, `handbook_spine.py`, `gen_*`), harness installers beyond the four pinned ones, board/panel utilities (`board_read.py`, `board_evidence_check.py`, `boardctl`, `panel_loop.py`), node-side supervisors and one-off probes |
| `specs/` | 9 | 1,911 | 7 / 1,680 | 2 — `GOALS.md`, `NODE-PHYSICAL.md` |
| `docs/` | 354 | 82,823 | 10 / 2,083 | 344 files — the four named classes below |
| `tests/` | 71 | 27,952 | 1 (`selftest.sh`) / 9,383 | 70 — the battery's own arms and fixtures: each is exercised as a numbered section or named arm of `tests/selftest.sh` (record 45), not documented per file |
| `prompts/` | 12 | 396 | 1 (`foreman.md`) / 110 | the 11 per-lane prompt files: `docs.md`, `dogfood.md`, `duckbrain.md`, `perf.md`, `pm.md`, `qa.md`, `readme.md`, `releng.md`, `review.md`, `sync.md`, `unblock.md` |
| `skills/` | 2 | 482 | 2 / 482 | none |
| `config/` | 5 | 150 | 5 / 150 | none |
| **total** | **533** | **146,362** | **66 files — 12.4%** | **32,866 lines — 22.5%** |

Named classes inside the `docs/` remainder:

- `docs/audits/` — 178 files / 21,335 lines. Quoted dated evidence: each file records what
  one run measured at one named tip. An audit's job is to quote, not to document; promoting
  a transcript to a module page would freeze a measurement into prose.
- `docs/handbook/` — 153 files / 55,462 lines. The module layer itself: the M-chapters are
  the descriptions this census indexes and `appendices/units/` is the evidence layer this
  file belongs to. A census does not cover its own substrate.
- `docs/dogfood/` — 3 files / 392 lines. Dated run records, same class as audits.
- top-level `docs/` — 8 pages + 2 registries / 3,551 lines: `00-INDEX.md`,
  `HARDWARE-PLAN.md`, `HARNESS-CONFORMANCE.md`, `PROVIDERS-AND-COST.md`, `REPOSITORIES.md`,
  `RUMSFELD.md`, `SECURITY-TRIAGE.md`, `traceability-doctrine.md`, plus the
  `SYSTEM-MODEL.yaml` / `UNIT-MAP.yaml` registries — real module candidates, still uncovered.

Six systems the docs describe only from the client side, with no page of their own: **scheduler**
(admission modes, cooldowns, weights, its DB), **crier** (routes, guard, leases, service auth),
**DuckBrain** (namespaces, token scoping, squash, embeds), **9router** (provider routing), **Hermes
gateway** (sessions, `/api/status`, dashboard auth), **bunker daemon** (create/exec/cp, keys).

Five flows have no end-to-end description: dispatch round-trip, node provisioning, memory export,
onboarding a new project, and disaster recovery (node loss, key rotation, board or git corruption).

Consequence for the count: 63 modules now cover 66 of 533 tracked files (12.4%) and 32,866 of
146,362 lines (22.5%) in the areas above. A reader must not read "54 VERIFIED" as "the system is
documented" — but the uncovered remainder is now a named list, not a shrug.

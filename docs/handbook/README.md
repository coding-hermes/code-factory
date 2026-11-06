# CODE FACTORY — MASTER HANDBOOK

**Arrangement of the document.** This file is the table of contents and the
honest status of every part. It is not a summary of the system — the system is
described in Part I onward.

A note on what changed and why: an earlier version of this set was 40 sections
titled by file path (`scripts/repo_freshness.py` and so on). Five independent
reviewers graded that arrangement against Apollo-era flight documentation and all
five failed it, on the same grounds: **a per-file census is not a general
arrangement**, it cannot tell a reader which part of the system a thing is, what
calls it, what it affects, or where to turn next. Those 44 file sections are kept
in `appendices/units/` where they belong — as the evidence layer beneath a
subsystem, not as the document.

---

## PART I — SYSTEM ARRANGEMENT

What the machine is made of, layer by layer, and what each box is responsible
for. Read this first; everything else is detail hanging off it.

| § | Contents | Source | Status |
|---|---|---|---|
| I.1 | Master system view — six layers, components, contracts | `docs/SYSTEM-MODEL.yaml` → `gen_system_views.py` | **RENDERED** (sheet 2) |
| I.2 | Component register — 27 components: what each owns, what it explicitly does not own, where it lives today | same, sheet 3 | **RENDERED** |
| I.3 | Contract register — 18 cross-boundary interfaces with measured state | same, sheet 4 | **RENDERED** (10 works / 6 broken / 2 missing) |
| I.4 | Unit map — which module and submodule each unit serves | `docs/UNIT-MAP.yaml` | **MAPPED** (9 modules, 25 submodules, 44 units) |
| I.5 | Boundary and actors | `docs/RUMSFELD.md` | **PARTIAL** |

## PART II — OPERATIONAL FLOWS

Every surface maps to exactly one flow. Primary flows alone are not a system
description: a machine spends most of its life in maintenance, monitoring,
recovery and degradation.

| § | Flow | Class | Status |
|---|---|---|---|
| II.1 | DISPATCH — a lane tick reaches a node and work is logged | primary | **RENDERED** (sheet 5) |
| II.2 | PROVISIONING — a bare host becomes a working node | primary | **RENDERED** (sheet 6) |
| II.3 | MEMORY — what is recorded, where, and how it is read back | primary | **RENDERED** (sheet 7) |
| II.4 | DOCUMENTATION — how this document is produced and kept true | primary | **RENDERED** (sheet 8) |
| II.5 | LANDING — a branch becomes main | primary | **RENDERED** (sheet 9) |
| II.6 | MAINTENANCE — disk reclamation, freshness, pruning, rotation | secondary | **MISSING** |
| II.7 | MONITORING — liveness, health, alerting, what wakes whom | secondary | **MISSING** |
| II.8 | RECOVERY — restart, re-dispatch, orphan reaping, restore | secondary | **MISSING** |
| II.9 | DEGRADATION — what the system does when a dependency is gone | secondary | **MISSING** |
| II.10 | TEARDOWN / REBUILD — remove a node or lane without leaving residue | secondary | **MISSING** |

All five reviewers named II.6–II.10 as absent. That is the largest single hole in
the document.

## PART III — SUBSYSTEMS

One chapter per module in the unit map — a module being a reason the system
exists, not a folder. Each chapter carries: where it enters the pipeline, what
reaches it, what it leads to, why it matters, every setting it reads, every
contract it honours, its verification command, its metrics, its log lines and its
failure modes.

| § | Module | Submodules | Status |
|---|---|---|---|
| III.1 | M0 SHARED CONTRACT | 1 | evidence only |
| III.2 | M1 PROVISIONING | 5 | evidence only |
| III.3 | M2 DISPATCH | 3 | evidence only |
| III.4 | M3 REPOSITORY | 2 | evidence only |
| III.5 | M4 … (see `UNIT-MAP.yaml`) | — | evidence only |

**Status vocabulary:** `WRITTEN` (a chapter exists and satisfies the field
contract), `EVIDENCE ONLY` (units are documented; no subsystem chapter exists).
Every chapter here is currently **EVIDENCE ONLY** — that is the work remaining.

## PART IV — CONTRACTS

Each contract names **both** sides: producer file and function, consumer file and
function, payload, timing, failure semantics, and its measured state.

| § | Contract | State | Both sides named |
|---|---|---|---|
| IV.1–IV.18 | see sheet 4 of the system views | 10 works, 6 broken, 2 missing | **NO — 0 of 18** |

The rule the set already states, and currently violates: *a contract with one
side named is a rumour.*

## PART V — SETTINGS REGISTER

Every dial, limit and switch: environment variables, CLI flags, timeouts, caps,
defaults and validation ranges — with what each does and what it affects if
changed.

| § | Register | Measured | Written with effect |
|---|---|---|---|
| V.1 | Environment variables | ~60–83 across scripts | **partial — 1 of 15 dispatcher names appear in text (Sol)** |
| V.2 | CLI switches | 211–257 | names appear; **effects largely unstated** |
| V.3 | Timeouts, caps and floors | scattered | **NOT REGISTERED** |

## PART VI — RISK AND UNKNOWNS

`docs/RUMSFELD.md` — four quadrants, 40 known-knowns, 18 known-unknowns with
probe and falsifier, 24 unknown-knowns. Reviewers called it the strongest artifact
in the set and still failed its seam: it sits outside the delivered document and
its promotion path is not maintained.

## PART VII — WORK DERIVATION

The reason this document exists. Each chapter yields tasks that cite the section
they close and the command that proves them.

| § | Contents | Status |
|---|---|---|
| VII.1 | Requirement table (R-nnn → module → assertion → evidence) | **NOT WRITTEN** |
| VII.2 | Board row derivation | **NOT WRITTEN** |

## APPENDICES

| § | Contents |
|---|---|
| A | `appendices/units/` — 47 per-unit evidence sections (settings, log lines, failure modes, locators) |
| B | `_quorum-apollo-gap-20261105/` — the five verdicts that produced this arrangement |
| C | `docs/MASTER-DOC-SCHEMA.md` — the field contract a chapter must satisfy |

---

## Measured status of this document

| Question | Answer |
|---|---|
| Does it open with a general arrangement? | Yes — Part I, rendered |
| Are modules framed as subsystems or as files? | Subsystems are **defined** (unit map); chapters are **not written** |
| Are secondary flows covered? | **No** — 5 of 10 flows missing |
| Are contracts both-sided? | **No** — 0 of 18 |
| Are settings documented with effects? | **Partially** — names yes, consequences mostly no |
| Contradictions found by the panel | 4, 8, 8, 8, 12 across five seats |
| Can a task list be derived? | **Not yet** — Part VII unwritten |

Nothing in this file is marked green that a command has not produced. The
remaining work is Parts II.6–II.10, III, IV, V and VII.

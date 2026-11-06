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
| I.2 | Component register — 27 components | same, sheet 3 | **RENDERED** |
| I.3 | Contract register — 18 cross-boundary interfaces with measured state | same, sheet 4 | **RENDERED** (register text says "10 works / 6 broken / 2 missing" — see Part IV note) |
| I.4 | Unit map — which module and submodule each unit serves | `docs/UNIT-MAP.yaml` | **MAPPED** (13 modules, 47 submodules) |
| I.5 | Boundary and actors | `docs/RUMSFELD.md` | **PARTIAL** |

## PART II — OPERATIONAL FLOWS

| § | Flow | Class | Status |
|---|---|---|---|
| II.1 | DISPATCH — a lane tick reaches a node and work is logged | primary | **RENDERED** (sheet 5) |
| II.2 | PROVISIONING — a bare host becomes a working node | primary | **RENDERED** (sheet 6) |
| II.3 | RUN CAPTURE AND SEARCH | primary | **RENDERED** (sheet 7) |
| II.4 | DOCUMENTATION | primary | **RENDERED** (sheet 8) |
| II.5 | LANDING | primary | **RENDERED** (sheet 9) |
| II.6 | MAINTENANCE | secondary | **MISSING** |
| II.7 | MONITORING | secondary | **MISSING** |
| II.8 | RECOVERY | secondary | **MISSING** |
| II.9 | DEGRADATION | secondary | **MISSING** |
| II.10 | TEARDOWN / REBUILD | secondary | **MISSING** |
| II.11 | SCHEDULING ADMISSION (F11) | quorum | **MISSING** (owner: M9) |
| II.12 | CREDENTIAL LIFECYCLE (F12) | quorum | **MISSING** (owner: M1/M7/M12) |
| II.13 | UPGRADE AND MIGRATION (F13) | quorum | **MISSING** (owner: M9/M6) |
| II.14 | OBSERVABILITY INGESTION (F14) | quorum | **MISSING** (no owning module) |
| II.15 | BACKUP AND RESTORE (F15) | quorum | **MISSING** (owner: ops) |
| II.16 | MULTI-NODE FAN-OUT (F16) | quorum | **MISSING** (owner: M11) |

**This round's deliverable is Part III only.** Parts I (beyond the rendered
sheets), II.6–II.10, IV (as a re-derived register), V, VI, VII and VIII have no
chapters. The outline commits to 8 parts; this writer round applies the panel's
round-2 corrections to the 13 Part III chapters. The missing parts are a filed
finding (F-ROOT-1), not a hidden gap.

## PART III — SUBSYSTEMS

One chapter per module. Status vocabulary, applied honestly this round:

- **Identity Status** (schema §1): `VERIFIED` / `UNVERIFIED` / `FAILING` — whether
  the chapter's claims are source-verified.
- **Chapter completeness**: `WRITTEN` (every field filled with evidence, no false
  claim), `PARTIAL` (some submodule unread or a field RED), `SKELETON` (outline
  text only, no source read).
- **Metrics `"none"` is a RED field** (schema §5). A chapter whose module emits no
  metrics is correctly reported as RED, and the observability gap is a *system*
  defect filed as board rows — not a defect in the writing. Per the panel's ruling
  (round-2 B03), a chapter with a RED metrics field stays PARTIAL until the system
  emits metrics or an explicit schema exception is approved.

| § | Module | Identity | Completeness | RED fields |
|---|---|---|---|---|
| III.1 | M0 SHARED CONTRACT | VERIFIED | PARTIAL | Metrics |
| III.2 | M1 PROVISIONING | UNVERIFIED | PARTIAL | Metrics, unit bodies unread |
| III.3 | M2 DISPATCH | VERIFIED | PARTIAL | Metrics |
| III.4 | M3 REPOSITORY | VERIFIED | PARTIAL | Metrics, S2 operator-invoked |
| III.5 | M4 BOARD | VERIFIED | PARTIAL | Metrics |
| III.6 | M5 HARNESS | UNVERIFIED | PARTIAL | Metrics, foreign installer bodies unread |
| III.7 | M6 DOCUMENTATION | UNVERIFIED | PARTIAL | Metrics, own gate reads FAIL |
| III.8 | M7 GITHUB | UNVERIFIED | PARTIAL | Metrics, mint unrun |
| III.9 | M8 SAFETY | VERIFIED | PARTIAL | Metrics |
| III.10 | M9 SCHEDULER | UNVERIFIED | PARTIAL | S1/S5 grep-level, §9 log inventory 2/379, settings register incomplete |
| III.11 | M10 CRIER | UNVERIFIED | PARTIAL | handler body unread, §9 inventory non-exhaustive |
| III.12 | M11 DISPATCHER | VERIFIED | PARTIAL | Metrics, live-job tests |
| III.13 | M12 INFERENCE PROXY | VERIFIED | PARTIAL | Metrics, node-client half, stream completion |

No chapter is `WRITTEN` this round. That is the honest result, not a retreat:
round-2 labelled 11 of 13 WRITTEN while four seats measured false claims, one-sided
contracts and unread bodies behind those labels. Round 3 corrects the claims and
leaves the statuses PARTIAL where the evidence says so.

## PART IV — CONTRACTS

| § | Contract | State |
|---|---|---|
| IV.1–IV.18 | the 18-interface register (sheet 4) | **stale** — the register's "10 works / 6 broken / 2 missing" is the outline's structure text, not re-derived from the chapters |

**Register-of-record re-scope (glm #2, applied round 6).** The OUTLINE Part IV rows
"scheduler → crier — envelope … **broken**" and "crier → node — inbox + lease … **works**" are
superseded by M10-C1/M10-C2 this round: the scheduler→crier envelope leg **works (transport)** —
crier delivers the envelope verbatim (`handler.go:990` `HandleDeliver`), and the `text_b64` vs
`text` mismatch (CF-354) is a **node-consumption** defect on the scheduler→node semantic leg
(`node-bus-worker.py:986` reads `text`, `<scheduler>/internal/bus/dispatch.go:202` emits
`text_b64`), not a scheduler→crier break. The "10 works / 6 broken / 2 missing" count is therefore
not re-derived and stays stale until Part IV is written chapter-by-chapter; the per-row truth is in
the chapters (M9-C2/M9-C3, M10-C1/M10-C2/M10-C3, M2-C1/M2-C2), which are the authority.

The rule: *a contract with one side named is a rumour.* Measured this round across
the 25 contract rows the chapters actually carry:

- **4** name both producer and consumer `file:function` (M10-C1, M10-C2, M10-C3,
  M11-C1). Round-4's "6" (M2-C1, M2-C2, M10-C1, M10-C3, M11-C1, M11-C2) counted
  file:line citations (e.g. `node-bus-worker.py:986`) as a named function; the rule
  requires a *function* on both sides. Under the strict rule the count is 4.
- The remaining 21 rows name one side, a `file:line`, a protocol, or an external
  service — and are now honestly marked **`rumour — one side only`** or `UNVERIFIED`
  in their chapter.
- **State words re-derived:** `broken` survives only where both sides were read
  (CF-354 at M2-C1/M9-C2; CF-355 at M2-C2/M9-C3/M10-C3 — M10-C1 is now correctly
  `works (transport)` since the text/text_b64 break is node-side). Every state word
  inherited from OUTLINE without an in-chapter measurement is now `UNMEASURED`.
- The two contracts the register calls *missing* — `crier → scheduler` completion
  event and `node → duckbrain` — have **no owning chapter** and remain a Part I.9
  gap.

## PART V — SETTINGS REGISTER

| § | Register | Status |
|---|---|---|
| V.1 | Environment variables | partial — node-side chapters carry default/range/consequence registers |
| V.2 | CLI switches | names appear; effects largely unstated |
| V.3 | Timeouts, caps and floors | scattered; scheduler register now written (M9 §5) |

## PART VI — RISK AND UNKNOWNS

`docs/RUMSFELD.md` — four quadrants. It sits outside the delivered document and
its promotion path is not maintained.

## PART VII — WORK DERIVATION

| § | Contents | Status |
|---|---|---|
| VII.1 | Requirement table (R-nnn → module → assertion → evidence) | **NOT WRITTEN** |
| VII.2 | Board row derivation | **NOT WRITTEN** |

## APPENDICES

| § | Contents |
|---|---|
| A | `appendices/units/` — per-unit evidence sections |
| B | `_quorum-*/` — the verdicts that produced this arrangement |
| C | `docs/MASTER-DOC-SCHEMA.md` — the field contract a chapter must satisfy |

---

## Measured status of this document

| Question | Answer |
|---|---|
| Does it open with a general arrangement? | Yes — Part I, rendered |
| Are modules framed as subsystems or as files? | Subsystems (13 modules); 13 chapters exist |
| Are secondary flows covered? | **No** — II.6–II.10 missing |
| Are contracts both-sided? | **No — 4 of 25** by the strict `file:function` rule; the rest marked `rumour`/`UNVERIFIED` |
| Are settings documented with effects? | Partially — node-side + scheduler registers written; V.2/V.3 unregistered |
| Chapter completeness | 0 WRITTEN, 13 PARTIAL, 0 SKELETON (round 5) |
| Can a task list be derived? | **Not yet** — Part VII unwritten |

**Round-5 findings (filed in the chapters):** the two FALSE CLAIMs that inverted
operator-facing facts are corrected — M9 F9-3 (root config sections *are* loaded at
boot; `LoadRootConfig` called 10× in `main.go`) and M9 F9-6 (round-4's `go test` FAIL was
env-contamination, not a code break; clean-env `go test ./...` passes 25/25). The
false "no production caller" (M2 lane_target → `configure_family.py:17,149`) and the
fabricated "invoked by the envelope" (M3 land-node-branch) are reclassified with grep
evidence. The `M12` BRE-vs-ERE grep, the `M6 --workers 0` serial fallback, the `M7
--quiet` mutation claim, and the `M11` synchronous-ledger/progress-disable claims are
all corrected against the code. Metrics `"none"` is now absence-proved (a repo-wide grep
with its command and output) on every node-side chapter rather than asserted. The
metrics-observability gap (11 modules emitting no counters) is the single largest
remaining system defect and is what keeps those chapters PARTIAL.

Nothing in this file is marked green that a command has not produced.

# Part IX — Disposition log

This part is the change/redline disposition log that Part VIII §5 requires. Every finding
from every review round receives exactly one disposition here. A finding without a
disposition entry in this log is an open blocker and cannot be considered resolved
(VIII.5). Dispositions are monotonic: a row moves forward, never back to silence.

The rounds are: the 2026-11-07 style audit (26 baseline findings, worklist commit `d0b1f8c`),
the W3 re-audit (`deleg_3af37f09`), the W6 correctness items, the W9 final re-audit
(`deleg_470476d1`), the owner review handoff v39 (CF2A-01 review handoff, `doc_9d223575598f`,
raised against CF2A-01-w10.pdf), and the v2 second-batch handoff (`doc_eb3b1a4fee91`, raised
against the 182-page issue). The audit headline counts 26 findings. The worklist rows
enumerate 32 identities A1–E5 after splits and added rows; the finding-ID arithmetic is
26 baseline + 6 new = 32 re-audit dispositions (Part VIII §IX, wave D).

Dispositions: **ADOPTED** (implemented, proof cited), **ADOPTED-IN-PROGRESS** (wave landed
or running; new-issue verification pending), **REJECTED**, **DEFERRED** (re-decided at the
next pass), **UNRESOLVED** (open; re-decided at the next pass). Owner "building agent"
means the handbook fix waves; owner "owner" means a recorded user decision.

## IX.1 Original audit — 2026-11-07 (26 baseline findings, rows A1–E5)

Raised against CF2A-01-house-style.pdf (68 pp, grade FAIL). Fix waves: W1 shell `60dd8fe`,
W2 visual graph `9b4203a`, hero sheets `084ed01`, W6 `cb48e59`, W7 `54683a6`, W8 `320b3e5`,
W9 `0e01a6f`, W10 `6447606`, parts waves `fa496e5` / `c7d9c50` / `2143e34`.

| ID | Finding | Disposition | Resolving commit | Proof |
|---|---|---|---|---|
| A1 | Grey ink (#111–#999) vs pure black | ADOPTED | `54683a6` | W9 re-audit: spans #000000 only, 11,743 black / 226 white drawings |
| A2 | 6.0–6.1pt Liberation, serif/sans face flips | ADOPTED | `60dd8fe`, `0e01a6f` | W9: body 8.0pt Liberation Serif throughout, no size/face drift |
| A3 | Running heads absent on 42/68 pages | ADOPTED | `60dd8fe` | W9: head band text on 119/119 pages |
| A4 | Head form wrong (no title, no bold, hairline) | ADOPTED | `60dd8fe` | W9: bold head over heavy black rule, per-page section line |
| A5 | Orphaned headings in folio band | ADOPTED | `cb48e59` | W9: max body extent 269.1mm, nothing in folio band |
| A6 | Footer incomplete, no reserved bottom margin | ADOPTED | `60dd8fe`, `0e01a6f` | W9: full form footer + footer rule + stamped Letter Gothic folio on every page |
| A7 | Cover prints doc number twice | ADOPTED | `60dd8fe` | W9: cover prints the number once with title/subtitle/issue/scope |
| A8 | Markdown debris printed (backticks, escaped junk) | ADOPTED | `320b3e5` | W9: zero backticks, zero `not**`, zero escaped junk; lint gate owns it |
| A9 | Hyphen-breaks inside code tokens/dates | ADOPTED-IN-PROGRESS | `320b3e5`, `6447606` | W9: date/token breaks gone (was ×100+); two mid-word cell wraps remain on p30 |
| A10 | Ordered lists restart at "1." | ADOPTED | `320b3e5` | W9: 16 list starts, zero restarts |
| A11 | Gap sheets not black bold, no legend | ADOPTED | `60dd8fe`, `54683a6` | W9: NOT WRITTEN black bold with explanation; minor bold inconsistency p116 vs p119 |
| B1 | Graphviz look, not Leroy line drafting | ADOPTED-IN-PROGRESS | `9b4203a`, `0e01a6f` | W9: map/state sheets are Leroy; several centered views still read graphviz |
| B2 | Edge labels 1–18, no legend | ADOPTED | `9b4203a` | W9: CT-nn wire labels + line-style legend on every figure sheet |
| B3 | DISPATCHER / INFERENCE PROXY missing from figure | ADOPTED | `084ed01` | W9: both present in the full 27-component set |
| B4 | Figure code family wrong | ADOPTED | `0e01a6f` | W9: `FIGURE x.y-n` + snapshot date on every caption |
| B5 | Label size floor 2.05mm | ADOPTED | `0e01a6f`, `6447606` | W9 found the W9-build regression (1.68mm); W10 removed the shadowed `svg_fit`, gate re-measures min 2.08mm |
| B6 | Referenced-but-missing figures | ADOPTED | `084ed01` | W9: 51 figure codes all captioned, zero dangling refs |
| B7 | Figure sheets 52–82% blank, not hero-sized | UNRESOLVED | — | W9: module centered views still 40–50% blank below; no later wave claims it; re-decided next pass |
| B8 | Pastel chips, coloured edges | ADOPTED | `0e01a6f` | W9: pure B/W, state as line style with legend |
| C1 | Zero TABLE codes | ADOPTED | `54683a6` | W9: 136 unique `TABLE x.y-n` codes, captions above |
| C2 | No continuation declarations | ADOPTED-IN-PROGRESS | `54683a6` | W9: 72 placards welded to repeated headers; terminal units mislabel "1–1 OF 8" on p4/p13 |
| C3 | Cells break frames, transplanted rows | ADOPTED | `cb48e59` | W9: no broken frames or transplanted rows found |
| C4 | `coding-herms-scheduler` typo, non-monotonic register | ADOPTED | `320b3e5` | W9: zero "herms", register monotonic CT-01→CT-23 |
| D1 | Zero NOTE/CAUTION/WARNING blocks | ADOPTED | `54683a6`, `6447606` | W10 promotes hazards to WARNING blocks; wave D defines the notice convention (Part VI §34) |
| D2 | No FDF checklist card | ADOPTED | `6447606` | W10: Letter Gothic checklist card closes all 13 module chapters |
| D3 | No change bars / Change Date | ADOPTED | `54683a6`, `6447606` | W10: change bars gated in the PDF margin, not assumed; Change Date field in every footer |
| D4 | No thumb tabs | ADOPTED | `54683a6` | W9: thumb tabs stair-stepped per part on every page |
| E1 | No set-wide paragraph numbering | ADOPTED-IN-PROGRESS | `320b3e5` | W9: codes and cross-refs set-wide; heading numbers remain module-local |
| E2 | Round chatter / second person on page faces | ADOPTED | `320b3e5` | W9: zero "this round" (was ×110); quoted prompt strings only |
| E3 | Contents without folios; "1 chapters" | ADOPTED | `6447606` | W10: folio column filled by measured post-pass that must converge; pluralized |
| E4 | PROVEN State with RED guarantee (self-contradiction) | ADOPTED | `6447606`, `c6f431b` | W10 mechanically downgrades PROVEN with an uncited side; wave D reconciles the verdict-field contradiction (Part VI) |
| E5 | Six of eight parts missing | ADOPTED | `fa496e5`, `c7d9c50`, `2143e34` | Parts I/II, V/VI, VII/VIII written and rendered |

## IX.2 W3 re-audit partials and the W6 correctness wave

The W3 re-audit (`deleg_3af37f09`) graded CF2A-01-w3.pdf (184 pp) **C+** on a prior FAIL:
12 FIXED, 12 PARTIAL, 8 STILL PRESENT. Its remaining-item groups and the W6
trust-blocking items carry these dispositions.

| ID | Finding | Disposition | Resolving commit | Proof |
|---|---|---|---|---|
| S1 | TABLE codes C1 + unit counts C2 missing | ADOPTED | `54683a6` | IX.1 rows C1, C2 |
| S2 | Genre blocks D1–D4 at zero | ADOPTED | `54683a6`, `6447606` | IX.1 rows D1–D4 |
| S3 | Numbering E1 + contents folios + "1 chapters" E3 | ADOPTED | `320b3e5`, `6447606` | IX.1 rows E1, E3 |
| S4 | Voice: "this round" ×110 | ADOPTED | `320b3e5` | W9: zero hits |
| S5 | Remaining partials (ink, fills, hyphen-breaks, B7 fill, B1 graphviz, footer, PROVEN/RED ×6, herms typo) | ADOPTED-IN-PROGRESS | `0e01a6f`, `6447606` | Closed per IX.1 rows except B7 (UNRESOLVED) and the A9/B1 residuals |
| R1 | Inverted imposition order (Part IV back-to-front) | ADOPTED | `cb48e59` | Forward-assembly pagination; pre/post content-stream hashes identical in a live browser; W9: reading order monotonic |
| R2 | Table-merge corruption (rows transplanted) | ADOPTED | `cb48e59` | Continuations opened per table with their own thead; W9: zero transplanted rows |
| R3 | Stranded header-only tables at page foot | ADOPTED | `cb48e59` | Whole-table move on empty cut; W9: zero header-only frames across all pages |
| R4 | Negative byte counts printed as data | ADOPTED | `cb48e59` | Gitleaks `~` annotation on the M3 §7 rows; W9: zero negative-byte hits |

## IX.3 W9 final re-audit — regressions and grade

The W9 final re-audit (`deleg_470476d1`) graded CF2A-01-w9.pdf (119 pp) **B−** and reported
the tally 17 FIXED · 7 PARTIAL · 2 STILL PRESENT (D2, E3) plus the B5 regression. Its
per-finding verdicts are recorded in the IX.1 rows. Its grade trajectory is FAIL → C+ → B−.

| ID | Finding | Disposition | Resolving commit | Proof |
|---|---|---|---|---|
| W9-R1 | B5 label-floor regression (142 labels at 1.68–1.91mm) | ADOPTED | `6447606` | W10: stale duplicate `svg_fit` removed; gate re-measures min 2.08mm against the 2.05 floor |
| W9-R2 | Terminal continuation placards mislabel "UNITS 1–1 OF 8" (p4, p13) | UNRESOLVED | — | No later wave claims the placard range fix; re-decided next pass |
| W9-R3 | Legend double-books "dotted" (MISSING vs UNVERIFIED) | ADOPTED | `6447606` | W10: MISSING keeps dotted, UNVERIFIED moves to dash-dot |
| W9-R4 | Minor cosmetics: TABLE 3.0.4 caption duplicate, p5 title strike, CT-06 label-in-box | ADOPTED-IN-PROGRESS | `6447606` | W10 moves the system-map title and adds the label-in-box build gate; the caption duplicate is not yet claimed |

The re-audit's four W6 verification items (reading order, table merges, stranded headers,
negative bytes) hold at W9; their dispositions stand (IX.2 R1–R4).

## IX.4 Owner review handoff v39 — section-3 corrections

Raised against CF2A-01-w10.pdf by the compiled running review log version 39
(`doc_9d223575598f`). Each section-3 correction group is adopted by one redline wave.
The governing directive is §1.9: reviews reconcile earlier redlines concurrently, using
exact revision identities and explicit dispositions — this log implements it.

| ID | Correction group | Disposition | Resolving commit | Proof |
|---|---|---|---|---|
| R39-FM12 | Front matter / Parts I–II: mission visible, code-beats-document removed, system arrangement and sixteen flows completed | ADOPTED | `1f745db` | Wave 1: sixteen flows with trigger/actor/inputs/refusal/recovery/settings/metric/proof; build CF2A-01-rl1.pdf green, 200 pp |
| R39-FIG | Figures 0.1, 0.2, 2.1: return path, boundaries, Task Router placement, lifecycle separation | ADOPTED | `1f745db` | Wave 1 commit message, FIGURE 0.1/0.2/2.1 items; CT-06R return leg |
| R39-M0 | M0 shared contract: helper contracts, final-verdict helper, telemetry | ADOPTED | `b90e705` | Wave 2 commit message, M0 items |
| R39-M1 | M1 provisioning: separate onboarding flows, credential enrollment, readiness validation | ADOPTED | `b90e705` | Wave 2 commit message, M1 items |
| R39-M2 | M2 dispatch: consumer/invocation boundary, versioned schemas, six separated outcome facts | ADOPTED | `b90e705` | Wave 2 commit message, M2 items |
| R39-M3 | M3 repository: gate placement, guard vs judge, evidence bound to exact objects | ADOPTED | `b90e705` | Wave 2 commit message, M3 items |
| R39-M4 | M4 board: one eligibility rule, authoritative copies, closure bar, partial-write recovery | ADOPTED | `b90e705` | Wave 2 commit message, M4 items |
| R39-M5 | M5 harness: lifecycle ownership, exact Hermes pin, Terminal Jail optional/off | ADOPTED | `dba3dbb` | Wave 3 commit message, M5 items |
| R39-M6 | M6 documentation: supported build path, six review stages, acceptance discipline | ADOPTED | `dba3dbb` | Wave 3 commit message, M6 items |
| R39-M7 | M7 forge credentials: app mappings, mint-time narrowing, lifecycle | ADOPTED | `dba3dbb` | Wave 3 commit message, M7 items |
| R39-M8 | M8 safety: cleanup vs lifecycle split, Bunker baseline protection, TJ disabled by default | ADOPTED | `dba3dbb` | Wave 3 commit message, M8 items |
| R39-M9 | M9 scheduler: admission/settlement separation, hook-plan behavior, settings precedence | ADOPTED | `e1c2fe0` | Wave 4 commit message, M9 items |
| R39-M10 | M10 Crier: schemas, scoped 30 s claim, retrieval-grants-lease flight-card fix | ADOPTED | `e1c2fe0` | Wave 4: CT-03 lease corrected to retrieval-granted |
| R39-M11 | M11 dispatcher: retained role, crash-safety requirements, falsifiable tests | ADOPTED | `e1c2fe0` | Wave 4 commit message, M11 items |
| R39-M12 | M12 inference proxy: credential holders, CT-19/20, streaming-defect retention | ADOPTED | `e1c2fe0` | Wave 4 commit message, M12 items |
| R39-P4 | Part IV contract register: 23 entries reconciled, one versioned registry, CT-01..CT-23 headers | ADOPTED | `e1c2fe0` | Wave 4: chapter register headers moved CT-01..CT-18 → CT-01..CT-23 |
| R39-P5 | Part V settings register: complete cross-module matrix, profiles, state vocabulary | ADOPTED | `c5e81c1` | Wave 5: per-Bunker deployment-profile matrix, SUPPORTED / TARGET-UNIMPLEMENTED / UNRESOLVED |
| R39-P6 | Part VI failure and risk: cross-system failure classes mapped with owner and proof | ADOPTED | `c5e81c1` | Wave 5: ten new failure classes, consequence-prioritized 20-class mapping |
| R39-P7 | Part VII work derivation: authorities, retry lineage, required metrics from intended behavior | ADOPTED | `c5e81c1` | Wave 5 commit message, Part VII items |
| R39-P8 | Part VIII delivery: disposition log as standing gate, draft/release/approval identity | ADOPTED | `c5e81c1` | Wave 5: VIII.5 + VIII.6 written; this Part IX is the log VIII.5 requires |

## IX.5 v2 second-batch handoff — findings V2-*

Raised against the 182-page issue (`doc_eb3b1a4fee91`). The v2 waves apply the batch:
wave C `1642c1f` (Overview + Part I), wave E `ff53cbe` (Part II flows + inline figure
mounting), wave D `c6f431b` (Parts V–VIII). Every row is ADOPTED-IN-PROGRESS: the wave
commits are landed, and the v2 handoff makes implementation and joint acceptance pending
until the next pass verifies the new issue. Owner: building agent.

| ID | Finding | Disposition | Wave / resolving commit | Proof |
|---|---|---|---|---|
| V2-MISSION-01 | Governing product definition leads the handbook | ADOPTED-IN-PROGRESS | C `1642c1f` | Overview opens with the delivery + infrastructure control loops |
| V2-ARR-01 | Reorganize Part I to section plan; target vs implementation vs verification separated | ADOPTED-IN-PROGRESS | C `1642c1f` | Wave C commit message, Part I items |
| V2-ARR-02 | Foreman as Bunker runtime role through Crier | ADOPTED-IN-PROGRESS | C `1642c1f` | Part I arrangement with Crier boundary and return leg |
| V2-ARR-03 | Precise cross-references; transport vs adapters reconciled | ADOPTED-IN-PROGRESS | C `1642c1f` | Wave C authority table |
| V2-ARR-04 | Hermes fixed MVP; Task Router future; TJ optional/off | ADOPTED-IN-PROGRESS | C `1642c1f` | Part I placement, carried from wave 1 |
| V2-ARR-05 | Keep-with-next, figure pagination, page furniture repairs | ADOPTED-IN-PROGRESS | C `1642c1f` | Wave C build gates |
| V2-ARR-06 | Forge-credential responsibility beyond GitHub (GitLab explicit) | ADOPTED-IN-PROGRESS | C `1642c1f` | GitHub/GitLab provider-identity responsibility matrix |
| V2-ARR-07 | Round/wave/task/worker/attempt separated; total-worker budget across waves | ADOPTED-IN-PROGRESS | C `1642c1f` | Cap-not-quota budget in Part I; component count 27 → 28 |
| V2-ARR-08 | Installer credential-delivery flow; full Bunker scope | ADOPTED-IN-PROGRESS | C `1642c1f` | Part I Bunker responsibilities |
| V2-ARR-09 | Foreman orchestration cycle; stale source rules reconciled | ADOPTED-IN-PROGRESS | C `1642c1f` | Wave C commit message |
| V2-FLW-01 | F1 rewritten as foreman-round dispatch and return | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II rewritten to V2 target sequences |
| V2-FLW-02 | Worker/wave/round memory contracts | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II F1/F3 steps |
| V2-FLW-03 | Canonical typed result and correlation; hook failure visible | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II F1 steps |
| V2-FLW-04 | Flow figure/page layout repairs | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II figures mounted at reading position |
| V2-FLW-05 | DuckBrain outage policy: local namespace persistence, sync states | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II F3 steps |
| V2-FLW-06 | Whole-catalog semantic coverage; subflows for missing lifecycles | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II rewrite |
| V2-FLW-07 | Controller access flow to a Bunker | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II rewrite |
| V2-FLW-08 | Rapid revocation and backup/restore/recovery | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II F12/F15 steps |
| V2-FLW-09 | Figure ID/label defects across sixteen diagrams | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II figure remounting and IDs |
| V2-FLW-10 | Explanatory paragraph under every flow diagram | ADOPTED-IN-PROGRESS | E `ff53cbe` | V2-LAYOUT-01 inline figure mounting in `build_book.py` |
| V2-FLW-11 | Per-flow corrections from the coverage file | ADOPTED-IN-PROGRESS | E `ff53cbe` | Part II per-flow target sequences |
| V2-ARCH-01 | Factory management/reconciliation service added | ADOPTED-IN-PROGRESS | C `1642c1f` | FACTORY MANAGER component, tag UNBUILT, impl TARGET-UNIMPLEMENTED |
| V2-ARCH-02 | Deployment/topology support matrix (K8s, Compose, homelab, standalone) | ADOPTED-IN-PROGRESS | C `1642c1f` | Part I deployment/topology profiles |
| V2-ARCH-03 | Management interface OpenAPI/utility contracts | ADOPTED-IN-PROGRESS | C `1642c1f` | Part I OpenAPI/utility contract requirements; language/storage undecided |
| V2-LAYOUT-01 | Flow text and diagram together, prose under image | ADOPTED-IN-PROGRESS | E `ff53cbe` | `build_book.py` inline-figure mounting (INLINE_FIG_MAX_MM) |
| V2-OPS-01 | Whole-system monitoring and component-level recovery | ADOPTED-IN-PROGRESS | — | Layered checks present in Part VI and F7; no wave commit claims the finding yet |
| V2-OPS-02 | Versioned webhook event catalog and independent metrics | ADOPTED-IN-PROGRESS | — | Webhook settings in Part V and F7; no wave commit claims the finding yet |
| V2-SET-01 | IaC control model opens Part V; desired-state schema | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D Part V items |
| V2-SET-02 | Full per-setting contract, twelve fields | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: two worked cards (worker budget, CR_REGISTRY_BACKEND) |
| V2-SET-03 | Configuration update lifecycle, eight stages | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: generation CAS, per-node acks, OpenAPI from same model |
| V2-SET-04 | Secrets contract: secretref:// syntax, redaction, authority split | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: no backend selected, mode-predicate reconciliation |
| V2-SET-05 | Missing setting domains added (profiles, budget, memory roots, TJ) | ADOPTED-IN-PROGRESS | C `1642c1f`, D `c6f431b` | Wave D Part V inventory |
| V2-SET-06 | Timing/lease/budget compatibility across systems | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: compatibility table with admission-time validation |
| V2-SET-07 | Configuration lifecycle figure, example file, setting index | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: example desired-state file with resolved-state comparison |
| V2-SET-08 | Config file as declared desired-state authority | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: desired/observed/effective separate; Boardctl stays work authority |
| V2-RSK-01 | Risks derived from mission and boundaries, not bugs alone | ADOPTED-IN-PROGRESS | D `c6f431b` | Stable risk IDs R-01..R-33 |
| V2-RSK-02 | Nine manager/state-store failure classes added | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D Part VI items |
| V2-RSK-03 | Detection→repair→readback→resume chain with authority classes | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: automatic/operator/unsupported classification |
| V2-RSK-04 | Verdict-field contradictions reconciled | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: absent-evidence-ID refusal unconditional; dispatcher-leg ok claim reconciled |
| V2-RSK-05 | Stable risk IDs, notice convention, risk diagram | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: summary renumbered to §34 |
| V2-WRK-01 | Part VII rewritten around the full derivation chain | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D Part VII items |
| V2-WRK-02 | Owned state transitions, three-record rule | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: writer = foreman; no weekly-rollup substitution |
| V2-WRK-03 | Canonical round/wave/task/attempt result schemas | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: truthful dispatch_id/corr_id/status/ok mapping |
| V2-WRK-04 | Per-level memory contracts and crash recovery | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: board sync before eligibility; no double-counting |
| V2-WRK-05 | Worked end-to-end project example | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: budget accounting, fixup, partial outage |
| V2-DLV-01 | Seven separate acceptance results; release/evidence manifest | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D Part VIII items |
| V2-DLV-02 | Gate-result consumer reconciled; build OK ≠ owner acceptance | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: CT-16/CT-18 claims reconciled |
| V2-DLV-03 | Per-stage failure behavior; finding-ID arithmetic explicit | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: 26 baseline + 6 new = 32 dispositions named |
| V2-DLV-04 | Layout-semantics test battery; font-substitution assessment | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: footer-claim discipline named |
| V2-DLV-05 | Complete build-from-spec acceptance package map | ADOPTED-IN-PROGRESS | D `c6f431b` | Wave D: three separate acceptance scopes |
| V2-Q-01 | User decision: multi-item successive-wave rounds | ADOPTED | C `1642c1f` | Owner decision recorded; Part I round model implements it |
| V2-Q-02 | User decision: total worker budget per round across waves | ADOPTED | C `1642c1f` | Owner decision recorded; cap-not-quota budget in Part I |
| V2-Q-03 | User decision: worker/wave/round memory entries distinct | ADOPTED | C `1642c1f`, D `c6f431b` | Owner decision recorded; three-record rule in Part VII |
| V2-Q-04 | User decision: continue through memory outage with durable pending entries | ADOPTED | C `1642c1f`, D `c6f431b` | Owner decision recorded; local namespace persistence in Part VII/F3 |

## IX.6 Handoff v39 section-6 — open design follow-ups

The handoff carries these into the next revision; they do not reopen resolved user
decisions. Owner: building agent unless the row names the owner.

| ID | Follow-up | Disposition | Rationale | Where carried |
|---|---|---|---|---|
| FU-1 | Deployment-dependent Bunker support/profile/capability matrix | DEFERRED | Live deployment conformance is unverified; the matrix structure exists and awaits measured rows | Part V profile matrix |
| FU-2 | Shared DuckBrain topology, consistency, offline/reconnect behavior | DEFERRED | Physical topology and offline behavior still need specification (owner decision carries this open) | Part V, Part VI sync-conflict classes |
| FU-3 | Exact Hermes/Oh My Hermes build and Crier invocation wiring | DEFERRED | Pin is named; the exact distribution/version lands during implementation reconciliation | M5, Part V pins |
| FU-4 | Versioned dispatcher/proxy sources and credential issuers | DEFERRED | External dispatcher/proxy source was not supplied for independent validation | M11, M12 qualifications |
| FU-5 | Requirement/contract/settings/metrics/flow reconciliation and corrected evidence | ADOPTED-IN-PROGRESS | Waves D and E execute the reconciliation; next pass verifies the new issue | `c6f431b`, `ff53cbe` |
| FU-6 | Shared DuckBrain authority, namespace/auth mapping, bidirectional readback, replication conflicts | DEFERRED | Installing identical software does not itself provide the same data view | Part VI sync classes, Part V |
| FU-7 | Obtain versioned external dispatcher/proxy artifacts or a documented replacement | DEFERRED | Unverified source/runtime claims stay preserved until evidence closes them | M11/M12 evidence rows |
| FU-8 | Execution/verification/publication/close/memory-projection ownership with failure semantics | ADOPTED-IN-PROGRESS | Wave E F1/F5 and wave D Part VII assign the ownership chain; Crier delivery is not acceptance | `ff53cbe`, `c6f431b` |

## IX.7 Standing rule

A finding without a disposition entry in this log cannot be considered resolved. The
dispositions are monotonic in visibility, deferred and unresolved rows re-decide at the
next pass, and the log — not the page count — is the record that the review was
answered (VIII.5).

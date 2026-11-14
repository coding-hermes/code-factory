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

## IX.8 Pass-3 findings — integrated-wave disposition

These rows preserve the 26 plan identities. A row is ADOPTED only when the resolving
source change and its integrated evidence are identified; a row is DEFERRED when its
owning wave has not yet landed, and names that missing evidence rather than implying
closure. P3-20 also owns the delivery-side consistency readback in Part VIII §14.

| ID | Source finding | Disposition | Resolving commit / reason | Evidence or next check |
|---|---|---|---|---|
| P3-01 | P3-FLW-01 | ADOPTED | `414a231` | `docs/handbook/parts/II-flows.md`: F2 manager ownership, readiness identity and binding handoff are explicit |
| P3-02 | P3-LAYOUT-01 | ADOPTED | `414a231` | `scripts/build_book.py`: flow intro units keep figure, dated caption and explanatory paragraph together; F10 is regenerated |
| P3-03 | P3-INT-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/IV-contract-register.md`: normative `CT-01`–`CT-30` cards and `CT-06R` define the complete registry and examples |
| P3-04 | P3-CONFIG-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/V-settings.md`: `factory.v1` desired-state schema and generation/readback API are added |
| P3-05 | P3-CONFIG-02 | ADOPTED | `bb56c68` | `docs/handbook/parts/V-settings.md`: repository identity and credential reference are separate; worker budget is explicit in the schema/example |
| P3-06 | P3-MEM-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/V-settings.md`: same-namespace local/remote memory, conflict, freshness and pending-sync rules are specified |
| P3-07 | P3-WORK-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/VII-work-derivation.md`: normative `work.v1` round/wave/result/publication schemas and separate memory records are added |
| P3-08 | P3-RECOVERY-01 | ADOPTED | `2497f69` | `docs/handbook/parts/VI-failure-risk.md` §34: durable reservation, fence, crash-point, charging and reconciliation states are defined |
| P3-09 | P3-OPS-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/V-settings.md`: versioned event catalog, subscriptions, delivery state and independent metrics are specified |
| P3-10 | P3-DISPATCH-01 | ADOPTED | `2497f69` | `docs/handbook/chapters/M2-dispatch.md` and `M10-crier.md`: Crier launch/return custody and one normative path are explicit |
| P3-11 | P3-BOARD-01 | ADOPTED | `2497f69`, `bb56c68` | `M4-board.md` defines claim/fence/closeout recovery; `VII-work-derivation.md` adds canonical eligibility and partial-write recovery |
| P3-12 | P3-MODULES-01 | ADOPTED | `2497f69` | M0–M12 each gain a normative contract section; `git show 2497f69` confirms the chapter additions |
| P3-13 | P3-M0-01 | ADOPTED | `2497f69` | `M0-shared-contract.md` defines executable helper inputs/results, refusal branches and a portable caller example |
| P3-14 | P3-REPO-01 | ADOPTED | `2497f69` | `M3-repository.md` defines gate, publication, remote-proof, closeout and recovery states |
| P3-15 | P3-PROVISION-01 | ADOPTED | `2497f69` | `M1-provisioning.md` defines the qualified profile, enrollment lifecycle, credential classes and readiness readback |
| P3-16 | P3-FORGE-01 | ADOPTED | `2497f69` | `M7-github.md` adds GitHub/GitLab mapping, scoped delivery, renewal, revocation and restore rules |
| P3-17 | P3-PROXY-01 | ADOPTED | `2497f69` | `M12-inference-proxy.md` adds token scope/expiry, finite-stream, accounting and deployable package contracts |
| P3-18 | P3-SCHED-01 | ADOPTED | `2497f69` | `M9-scheduler.md` adds typed admission/settlement transitions, reservations, late-result handling and restart reconciliation |
| P3-19 | P3-SAFETY-01 | ADOPTED | `2497f69` | `M8-safety.md` defines measured Bunker baseline, optional fail-closed jail and protected cleanup races |
| P3-20 | P3-CONSISTENCY-01 | ADOPTED | `97435912e0cd96eaf1424e0d03b0f7bc23188fea` | VIII §14 defines dated cross-section readback and separates PASS/PARTIAL/FAIL/NOT RUN |
| P3-21 | P3-MANAGER-01 | ADOPTED | `bb56c68` | `docs/handbook/parts/I-system-arrangement.md`: manager resources, operations, generations, fencing and readback are specified |
| P3-22 | P3-RECOVERY-02 | ADOPTED | `2497f69` | `docs/handbook/parts/VI-failure-risk.md` §35: backup manifest, isolated restore ordering, recovery bounds and revoked-secret policy are defined |
| P3-23 | P3-ACCESS-01 | ADOPTED | `2497f69` | `docs/handbook/chapters/M1-provisioning.md`: controller/Bunker enrollment, scoped authorization and readiness refusal paths are defined |
| P3-24 | P3-FLW-02 | ADOPTED | `414a231` | `docs/handbook/parts/II-flows.md` and generated F1–F15 fixes reconcile flow steps with the normative path |
| P3-25 | P3-DIAGRAM-01 | ADOPTED | `414a231` | `scripts/gen_handbook_figures.py` and F1–F15 SVG diffs update actor arrangement, module diagrams and labeled locations |
| P3-26 | P3-LAYOUT-02 | ADOPTED | `414a231` | `scripts/build_book.py` and figure diffs correct inline mounting, caption adjacency, folio geometry and print-scale layout |

pass3 received, 26 findings, plan committed at ad984337f19d999977bd234475b442fcb84be9a0

pass4 received, 16 findings, plan committed in this change; canonical review record `CF2A-01-pass4-review-log.json`, source `CF2A-01-pass3-integrated.pdf` (275 pages, SHA-256 `841f4626c00730de7940449e60408966c36f152318d5e027893f4f7acc6bd564`).

## IX.9 Pass-4 findings — integrated-wave disposition

The pass-4 source record is the 275-page `CF2A-01-pass3-integrated.pdf` identified above.
The three source waves were integrated on `origin/main` before this wave: wave 1
`90339b85f7c4f4f45ce3b10d41774af8ff30951c`, wave 2
`009c1992a1f8bda4f840441e7c51038fc54be155`, and wave 3
`a66433e9684eb09a8b41b628a79cbd641e7b1147`. Each adoption below was checked against
the named commit's actual diff, not its subject line. `ADOPTED` records source
integration and specification work; it does not imply runtime conformance or owner
acceptance. Those evidence boundaries remain explicit in the final two columns.

| ID | Source finding | Disposition | Resolving commit / proof | Specification completeness | Verification | Runtime conformance | Owner acceptance |
|---|---|---|---|---|---|---|---|
| P4-01 | P4-CONFIG-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff adds the recursive `factory.v1` model, resolved endpoints/hosts, canonical project memory, normalized subscriptions, worked example, and refusal cases in Part V | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no live Factory probe | OPEN; no owner decision recorded |
| P4-02 | P4-PROTOCOL-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff adds the outer `cf2a.v1` envelope, scope-specific registration/admission/brief/result/report schemas, ID ownership, mappings, examples, and Crier consumer trace | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no live Crier round | OPEN; no owner decision recorded |
| P4-03 | P4-MANAGER-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff adds manager generations, versioned adapter operations/results, digest-based idempotency, freshness, reservations, transitions, cancellation, and readiness sequencing | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no live manager probe | OPEN; no owner decision recorded |
| P4-04 | P4-CLAIM-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff selects canonical remote CAS authority and normalizes claim, lease, fence, staging, publication, partial-write, repair, abandonment, and fenced-return behavior | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no competing-clone exercise | OPEN; no owner decision recorded |
| P4-05 | P4-RECOVERY-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds preassigned `launch_id`, lookup/reconciliation before retry, resource-side generation fences, and quarantine when quiescence is unknown | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no crash/partition exercise | OPEN; no owner decision recorded |
| P4-06 | P4-BUDGET-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff defines worker/attempt/session/launch accounting, `charge-on-start` transitions, refund rules, independent total allowance/concurrency, and the corrected T3 example | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no budgeted round execution | OPEN; no owner decision recorded |
| P4-07 | P4-MEMORY-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff defines same-namespace local/remote endpoints and refs, authority, authorization, record/commit schema, merge/conflict/replay, freshness, local-only validity, and pre-write/result metadata | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no two-Bunker sync | OPEN; no owner decision recorded |
| P4-08 | P4-DEPLOY-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds a versioned qualified deployment profile with artifacts, prerequisites, mounts, identities, networking, secret references, bootstrap/readback, upgrade, replacement, and removal | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no clean-host lifecycle run | OPEN; no owner decision recorded |
| P4-09 | P4-AUTH-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds trust enrollment, actor/resource authorization, GitHub/GitLab adapter request/results, scoped delivery/readback, rotation, expiry, revocation, offboarding, restore, and enforcement boundaries | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no provider or revocation exercise | OPEN; no owner decision recorded |
| P4-10 | P4-PUBLICATION-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds versioned gate/evidence/verdict objects, source/integration/landed-tree revalidation, fresh remote proof, uncertain-push handling, and exact published-object closeout | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; handbook lint/build is not runtime conformance | OPEN; no owner decision recorded |
| P4-11 | P4-EVENTS-01 | ADOPTED | `90339b85f7c4f4f45ce3b10d41774af8ff30951c` — actual diff unifies subscription fields and adds signed receiver transport, acknowledgement/retry/cursor rules, progress extension, and metric units/labels/sample semantics | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no independent receiver | OPEN; no owner decision recorded |
| P4-12 | P4-BACKUP-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds `cf.backup.v1`, consistency markers, per-store capture/validation, policy bounds, isolated restore, loss reporting, and revocation preservation; drift is validation, not capture | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no isolated restore | OPEN; no owner decision recorded |
| P4-13 | P4-PROXY-01 | ADOPTED | `009c1992a1f8bda4f840441e7c51038fc54be155` — actual diff adds the supported stream/terminal/error/cancel contract, deadlines, settlement, token defaults/admin, maintained package interface, and capture failure policy | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build pending | NOT RUN; no Hermes stream probe | OPEN; no owner decision recorded |
| P4-14 | P4-CONSISTENCY-01 | ADOPTED | `a66433e9684eb09a8b41b628a79cbd641e7b1147` — actual diff reconciles current flow/figure status views and builder references to the selected Bunker/Crier path and typed status vocabulary; historical material remains distinct | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; `build_book.py --out ~/code-factory-reports/handbook/CF2A-01-pass4-integrated.pdf` emitted the green OK line; 282 pages | NOT RUN; no runtime conformance claim | OPEN; no owner decision recorded |
| P4-15 | P4-LAYOUT-01 | ADOPTED | `a66433e9684eb09a8b41b628a79cbd641e7b1147` — actual diff repairs F1 adjacent-spread mounting, continuation handling, F10 identity, and rendered furniture/layout checks | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; `build_book.py --out ~/code-factory-reports/handbook/CF2A-01-pass4-integrated.pdf` emitted the green OK line; 282 pages | NOT RUN; no independent visual-QA claim | OPEN; no owner decision recorded |
| P4-16 | P4-DISPOSITION-01 | ADOPTED | `812a380dfdfc09214b15148df1ffdf576696e1e8` — this section records all 16 pass-4 identities, exact source commits, source/specification evidence, and residual verification boundaries without downgrading the 26 pass-3 ADOPTED rows | SOURCE INTEGRATED; independent completeness NOT RUN (P5 supersedes the prior COMPLETE claim) | `handbook_lint.py` clean; integrated build receipt recorded above | NOT RUN; procedures are not readback results | OPEN; no owner decision recorded |

The integrated build receipt is recorded above for P4-14 and P4-15. It closes
mechanical artifact build evidence only; no source correction above is represented
as a passed runtime-conformance or owner-acceptance result.

## IX.9 Pass-5 wave C dispositions

Review source is `/tmp/p5-review-C.json`, P5-C-01 through P5-C-38. Source revision
C is `aef60687be3fd73f6dd026d49cbeace8b7bd4018`; A is
`b26d2ecc494664322f339aa499d9b38a13179d78` (the immutable wave-A commit on origin/main). C changes only M7–M12 and
Parts V–IX. Each ADOPTED row records a specification repair, not independent semantic
approval or runtime conformance. Runtime tests and owner acceptance are NOT RUN/OPEN
for every row. Mechanical lint is clean; the final artifact receipt accompanies the
published PDF, not an invented self-referential build hash inside it.

The bounded integration wait observes A landed and B absent through 2026-11-11
19:36 UTC; the wait cap is exhausted. Cross-wave requirements remain explicitly
UNRESOLVED until the register's wave-B correction is verified. The revision links
below identify actual source bytes, not “this commit” placeholders. Owner of remaining
artifact qualification is the deployment/release owner; owner of cross-register
integration is wave B. The next review rechecks all residuals before accepted release.

| Finding | Disposition | Resolving source / replacement contract | Evidence boundary or residual |
|---|---|---|---|
| P5-C-01 | UNRESOLVED | C: M9.15, M10.15, VII.13/18; A: I.1.9.1 | C aliases removed; IV's target envelope/cards still await wave B, so cross-book parity is not claimed |
| P5-C-02 | ADOPTED | C: M9.15, M11.16, VII.13/18 | No future worker IDs at admission; launching foreman owns dispatch/launch IDs |
| P5-C-03 | ADOPTED | C: V.9 | Recursive types, requiredness, bounds, duplicate/extension rules and refusal codes; validator implementation not claimed |
| P5-C-04 | ADOPTED | C: V.9 | Missing controls have accepted paths, activation scope, mapping/readback and unsupported-adapter refusal |
| P5-C-05 | ADOPTED | C: V.4/V.7 | events secret bundle separates destination URL from rotating HMAC key references |
| P5-C-06 | ADOPTED | C: V.0.2; A: I.1.9.1/3 | Whole-document generation CAS, factory-control scope, mTLS principal and retired aliases |
| P5-C-07 | ADOPTED | C: M10.16 | Exact five-line digest/audience transcript, hex signature, enrollment, key generation and replay window |
| P5-C-08 | ADOPTED | C: V.0.3/V.4 | HMAC bytes, signed delivery time, key rotation, jitter and blocked contiguous cursor |
| P5-C-09 | ADOPTED | C: M9.16 | Ordered predicate/allocation, priority aging, reservation and bytewise tie-break rules |
| P5-C-10 | ADOPTED | C: M9.17; VI.34 | Typed records, transaction groups, outbox ownership and restart queries |
| P5-C-11 | ADOPTED | C: M9.18 | Hook plan, fd input/output, ordering, timeout, retries and durable required-hook receipts |
| P5-C-12 | ADOPTED | C: M10.16 | Poll-key replay, renew/release/ack, expiry reconciliation and dedupe retention |
| P5-C-13 | ADOPTED | C: M11.16 | Preassigned launch ID, atomic start permit, authoritative lookup, capture and cancellation |
| P5-C-14 | ADOPTED | C: M9.17; V.9; VII.12 | Reserved-to-charged atomic accounting, uncertain-start hold and bounded attempts |
| P5-C-15 | ADOPTED | C: VII.18 | Failure branch permits null commit/empty artifacts with typed error, never invented output |
| P5-C-16 | UNRESOLVED | C: VII.15.1; VI.13; A: I.1.9.6 | Canonical CT-10 names and errors are selected; the M4 legacy-alias reconciliation still awaits B |
| P5-C-17 | ADOPTED | C: M7.17; VI.35.2; A: I.1.9.3 | Broker-only credentials and effect intents serialize all four resources with epoch advance |
| P5-C-18 | ADOPTED | C: M8.16 | Shared hold/tombstone transaction, private trash, immutable inventory and resumable per-target cursor |
| P5-C-19 | ADOPTED | C: V measured M8 inventory | Cache TTL 24 h, aged=True and newest subtree mtime agree with M8/CF-290 |
| P5-C-20 | ADOPTED | C: M7.16 | Supported GitHub/GitLab modes, endpoints, permissions, provider/local fields and errors; external conformance NOT RUN |
| P5-C-21 | ADOPTED | C: M7.15/16 | Separate mapping/credential states, operation-key rotation, atomic activation and uncertain-mint recovery |
| P5-C-22 | ADOPTED | C: M12.16 | mTLS admin operations, random token/hash, encrypted installer handoff, activation and revocation |
| P5-C-23 | ADOPTED | C: M12.16; V.9 | Shared serializable budget/slot reservation, price units, unknown-spend charging and restart recovery |
| P5-C-24 | ADOPTED | C: M12.17 | Closed messages/options/tools, model list, buffered and SSE records, timeout table and adapter behavior |
| P5-C-25 | ADOPTED | C: M12.16/17 | Usage/result transaction precedes complete; unsettled error and response-ID lookup close crash window |
| P5-C-26 | ADOPTED | C: VI.35.1; V.9 | Coordinated barrier, per-store snapshot/validation, typed manifest, schedule and partial-cut policy |
| P5-C-27 | ADOPTED | C: VI.35.2; A: I.1.9.3 | Independent non-rollback authority; older restore cannot reactivate tokens; authority loss refuses or requires proven revoke-all |
| P5-C-28 | ADOPTED | C: VII.18.1; V.9 | Record layout/types, digest scope, socket API, deterministic namespace union, conflict linkage and freshness |
| P5-C-29 | ADOPTED | C: VII.18.2 | Local durability permits report, not settlement; quiescent capacity releases while lane remains pending memory |
| P5-C-30 | ADOPTED | C: V.9 | Whole-harness wall, round/tick ceilings, explicit reserves and lease-renewal inequality |
| P5-C-31 | DEFERRED | C: M11.17; M12.15 | Exact reproducible issuer/dispatcher/proxy artifacts do not exist in supplied evidence. Owner selects maintained release or commissions replacement; default BLOCKED; no fabricated hashes |
| P5-C-32 | ADOPTED | C: V.10 | Collector endpoint, bounded labels, buckets, windows, persistent counters and unknown/stale readiness |
| P5-C-33 | ADOPTED | C: M8.16; V.9 | Qualified isolation floor, immutable jail policy schema, covered executor paths and bypass-denial readback |
| P5-C-34 | ADOPTED | C: VIII.10/15 | Seven-stage manifest and exact draft/accepted/refused predicate; evaluator implementation remains a target |
| P5-C-35 | ADOPTED | C: IX.7/8; VIII.15 | Exact historical commits replace placeholders; prior COMPLETE claims corrected; runtime/build/owner evidence separated |
| P5-C-36 | ADOPTED | C: VI.13/30/31/36; V.9; VII.18 | Foreman/sync ownership and local durability agree across recovery tables |
| P5-C-37 | ADOPTED | C: M7/M8 register notes; VI.0/36; VIII.1/2 | CT-01..30 plus CT-06R, unique R-33, nine parts and dash-dot UNVERIFIED legend |
| P5-C-38 | ADOPTED | C: VII.18 | Typed initiative/task/criterion/evidence/acceptance records, deterministic compatible waves and cancellation authority |

This disposition is a specification draft: unresolved cross-register integration,
artifact qualification, independent completeness review, runtime conformance and owner
acceptance are not concealed by the mechanically buildable document.

Build evidence at source `28b4f8784390df13fdee887f9a3438ad4288a6ec` is FAIL:
`build_book.py` returns 2 after the skill checker finds page 30's GitLab API link
colour `(0.0, 0.0, 0.933)`. The link originates in Part I, outside wave C's file
fence. Fit passes with 2.1 mm worst-page clearance, but no green OK line exists.
The generated PDF is diagnostic output, not an accepted build. This limitation
requires the Part I owner to correct the link rendering/source, then rebuild.

| PASS5-INTAKE | 2026-11-11 | Pass-5 review package | 16 actionable findings (9 critical / 6 high / 1 medium): 7 new, 9 repeats; all nine package files reconciled | **PLANNED** — `docs/handbook/PASS5-PLAN.md` maps P6-01…P6-16 with P3/P4/P5G crosswalks and four disjoint waves |

PASS5 integrated build evidence uses commit `2ad65a36ffd90a674c36aae5b92682925a03d3d8`: 381 pages, fit clean 2.1 mm, `check.py` green. Source pages below refer to the pass-5 review package; built pages refer to `CF2A-01-pass5-review-integrated.pdf`. Independent readback JSON and page renders are delivered in `CF2A-01-pass5-readback/` beside the PDF. Runtime conformance and owner acceptance remain separately unrun/open.

| ID | Source finding | Disposition | Resolving commit / proof | Specification completeness | Verification | Runtime conformance | Owner acceptance |
|---|---|---|---|---|---|---|---|
| P6-01 | P5-RUNTIME-01; source pp. 23, 111, 145–146, 173–176, 196, 209–214, 223–224 | ADOPTED | `9c0f55574f249668db67d996d0af27384d8a2a10` — wave 1 reconciliation: freezes the canonical contracts: one authority/execution protocol, ownership manifest, idempotent launch identity, per-step timeout/cancel/concurrency, and the runtime conformance matrix, with `docs/handbook/contract-vectors.json` carrying the shared vectors | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 247; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-247-correction-review.json | OPEN; owner joint acceptance pending |
| P6-02 | P5-CUSTODY-01; source pp. 99–100, 108–113, 192–195, 225–228, 247–248 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: binds one signed custody chain to one Crier lease across its validity interval (principal, clock/nonce, body hash, lease_id, visibility/renewal/final validity, explicit initial receiver) in M10 and the register | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 216; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-216-correction-review.json | OPEN; owner joint acceptance pending |
| P6-03 | P5-BOARD-01; source pp. 129–131, 138–139, 167–168, 227–231, 304 | ADOPTED | `8ea4f558fdadae6813a0ad33b353e94a72d3c08b` — wave 3 reconciliation: unifies the criterion record, group-claim ordering and duplicate detection, conditional CAS preconditions, qualification authority, and post-judge settlement in M4 so a row cannot be closed out of order by a sibling | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 146; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-146-correction-review.json | OPEN; owner joint acceptance pending |
| P6-04 | P5-MEMORY-01; source pp. 227–228, 247–249, 251–252, 279–280, 285–291, 296–298 | ADOPTED | `9c0f55574f249668db67d996d0af27384d8a2a10` — wave 1 reconciliation: defines the serializable worker/wave/round memory record and hashing domain, local commit versus HTTP qualification, post-restart receipt reconciliation, and the failed/partial/retry synchronization state machine | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 337; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-337-review.json | OPEN; owner joint acceptance pending |
| P6-05 | P5-INFERENCE-01; source pp. 221–228 | ADOPTED | `8ea4f558fdadae6813a0ad33b353e94a72d3c08b` — wave 3 reconciliation: defines the canonical streamed inference contract at the CT-06/CT-28 boundary: envelope, sequence origin, token identity, typed usage/error/final state, fragmentation, and finite limits | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 244; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-244-correction-review.json | OPEN; owner joint acceptance pending |
| P6-06 | P5-BACKUP-01; source pp. 69–71, 246–249, 289–291 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: gives backup holds and mutable-state capture one lease/recovery contract: single off-host manifest authority, expiry and coordinator-loss behavior, release only after remote upload and readback | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a6743a36aae5b92682925a03d3d8`; built p. 326; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-326-correction-review.json | OPEN; owner joint acceptance pending |
| P5G-07 | P5 BACKUP CONSISTENCY AND RESTORE REVOCATION | ADOPTED-IN-PROGRESS | C: F15, Part VI §35.1, M8 §16, M9 §17, M10 §16, M7 §17, M12 §16 | F15 names the manager-owned ordered barrier, canonical `cf.backup.v1` manifest, isolated restore, current authority fences/revocations, and deterministic CV-06-B pending/acked/loss/stale-owner/known-row vector; Part VI §35.1 owns the manifest and recovery contract, while M8 §16 owns backup holds; live restore remains UNVERIFIED | handbook/spec checks to run; no live restore drill | OPEN; owner joint acceptance pending | ch:trace row=P5G-07 spec=docs/handbook/OUTLINE.md#f15-backup-and-restore wave=none:serial test=none:handbook-specification-only doc=docs/handbook/parts/II-flows.md evidence=none:specification-only witness=none:handbook-specification-no-live-restore verdict=none:foreman-writes |
| P6-07 | P5-CONFIG-01; source pp. 26, 94–95, 127–128, 138–139, 154–156, 245–249, 256–258 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: publishes the executable signed profile set (receipt authority, invocation lifecycle, gate policy, execution artifact, inference routes, global timeout, sandbox) with type/default/owner/consumer/precedence and redacted local-secret binding | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 284, 288; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-284-correction-review.json, page-288-correction-review.json | OPEN; owner joint acceptance pending |
| P6-08 | P5-API-01; source pp. 25–29, 99–102, 165–166, 209–210, 226–227 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: supplies the missing trust/operation state machines: dispatch-grant life cycle, certificate renewal, capability/Gateway semantics, enrollment secret resolution, result/return APIs, and post-enrollment participant binding | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 31; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-031-correction-review.json | OPEN; owner joint acceptance pending |
| P6-09 | P5-ISOLATION-01; source pp. 93–94, 136, 143–145, 153, 209, 257–258 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: makes credential lifetime and artifact isolation enforceable: delivered credential types, non-env transport, atomic owner-only staging, fanout handling, revocation, and the fail-closed containment launcher | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 99; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-099-correction-review.json | OPEN; owner joint acceptance pending |
| P6-10 | P5-SETTLEMENT-01; source pp. 23, 48, 145–146, 196, 209–214, 225–228, 296–298 | ADOPTED | `9c0f55574f249668db67d996d0af27384d8a2a10` — wave 1 reconciliation: defines the terminal-result state machine: timeout trees, worker exit versus control death, idempotent commit, process exit before durable evidence, launch-failure disposition, and no third verdict for a clean exit without a committed result | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 337; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-337-correction-review.json | OPEN; owner joint acceptance pending |
| P6-11 | P5-LIMITS-01; source pp. 31, 111, 146, 225, 245–247, 250–251, 298, 302 | ADOPTED | `32cb05bb84f8ec0f9f7ae9d9a2c789d83d581814` — wave 2 reconciliation: normalizes numeric resources and deadline scopes: global harness deadline in turn scheduling, the 20,000-round total made legal, typed resource replacing boolean-with-budget, defaults pinned to the shared formula | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 289; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-289-correction-review.json | OPEN; owner joint acceptance pending |
| P6-12 | P5-METRICS-01; source pp. 85–86, 167, 189, 218–219, 247, 299 | ADOPTED | `8ea4f558fdadae6813a0ad33b353e94a72d3c08b` — wave 3 reconciliation: makes telemetry a validated event contract and global projection: M7–M12 event mapping, normalized retention/access, live metrics bound to Factory task identity, M7's five counters qualified at emission and scrape | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 90; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-090-correction-review.json | OPEN; owner joint acceptance pending |
| P6-13 | P5-GATES-01; source pp. 40–41, 118–120, 225, 301 | ADOPTED | `8ea4f558fdadae6813a0ad33b353e94a72d3c08b` — wave 3 reconciliation: splits publication, mechanical policy, and model judgment into separately identified artifacts and closes on published machine evidence rather than an uncertain push verdict | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 134; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-134-correction-review.json | OPEN; owner joint acceptance pending |
| P6-14 | P5-FIGURES-01; source pp. 2–3, 37–78, 80–91, 99–218 | ADOPTED | `2ad65a36ffd90a674c36aae5b92682925a03d3d8` — wave 4 render/readback correction: re-renders the figure set from the integrated model via the updated `gen_handbook_figures.py`, restoring host-residency labels and the corrected panel layout; SVG XML and label gates pass | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 39–40; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-039-correction-review.json, page-040-review.json, page-040-transport-review.json | OPEN; owner joint acceptance pending |
| P6-15 | P5-LAYOUT-01; source pp. 2, 39, 41, 56, 143, 152, 164, 208, 269, 271, 275, 277, 284, 287, 293, 320–329 | ADOPTED | `2ad65a36ffd90a674c36aae5b92682925a03d3d8` — wave 4 render/readback correction (includes 3060b3bd578eeeab38810fdb2abf19b8592fa721): repairs the presentation stack: body font per the NASA standard, figure paragraphs mounted directly beneath their figures, continuation splitting, and the overflow instrumentation in `build_book.py`/`book_style.py` that names the failing page and block on failure | SOURCE INTEGRATED; independent completeness PASS — correction visible on built target | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 73, 137, 166; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: page-073-review.json, page-137-correction-review.json, page-166-review.json | OPEN; owner joint acceptance pending |
| P6-16 | P5-ISSUE-01; source pp. 5, 24, 101, 157, 211, 229–231, 312–313, 321–329 | ADOPTED | `29c4384669437702d4315662eb08fad267281ede` — wave 4 integrated reissue: reissues the artifact with current date/revision/release identity, appends these sixteen dispositions with build/readback evidence, and leaves prior P3/P4 dispositions untouched | SOURCE INTEGRATED; independent completeness PASS — 16 rows verified on pp. 377–381 | build `2ad65a36ffd90a674c36aae5b92682925a03d3d8`; built p. 381; `handbook_lint.py` clean; OK 381 pages, fit clean 2.1 mm, check.py green | PASS — independent full-page readback: disposition-manifest.json | OPEN; owner joint acceptance pending |

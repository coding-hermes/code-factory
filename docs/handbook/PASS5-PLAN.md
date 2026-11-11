# CF2A-01 — Pass-5 integration triage and correction plan

Review base: `d4b686c82178208d9c4220b2d6f4f2ba8e87ae4d` (`main` at review time). Review artifacts: all nine files in `/home/kara/.hermes/cache/scratch/pass5/`, SHA-256 `3e6be59164729985b48feb187c1c23401c5f276f848c066a97ba095929e7d8` for `CF2A-01-pass5-review-log.json`.

The pass-5 verdict is **NOT YET BUILDABLE END TO END FROM THE SPECIFICATION ALONE**. The next work is contract integration, not another expansion of independent module detail. There are 16 actionable findings: 9 critical, 6 high, 1 medium; 7 new and 9 repeats/regressions. Runtime conformance remains **NOT ASSESSED / NOT RUN**, and owner acceptance is not granted.

## 1. Resolved-decision guards and conflict screen

The canonical review has `questions_for_user: []`; none of P6-01…P6-16 requires a new product ruling or reverses a resolved user decision. The following are implementation constraints, not options to re-litigate:

- **Placement and custody (P6-01, P6-02, P6-08, P6-10, P6-14).** Preserve the Bunker foreman → Crier → resident worker → Crier return → Scheduler settlement direction. A single canonical protocol must not become a central dispatcher, node pull loop, or gateway-observed reply settlement.
- **Rounds and recovery (P6-03, P6-10, P6-11).** Preserve multi-wave rounds, one round-wide model allowance shared by all waves, no allowance reset between waves, group claims without serial head-of-line blocking, and same-worker correction ownership until terminal disposition.
- **Memory (P6-04, P6-10).** Keep worker, wave, and round as distinct logical records. A shared mounted view is a consistency obligation, not permission to forbid local work or to make every write synchronous; an HTTP outage still requires durable local work and later verifiable synchronization.
- **Control and integrations (P6-07, P6-08, P6-12).** Keep desired configuration with the human or delegate, Boardctl as the work store, generic webhooks with receiver-owned interpretation, and no external repair agent.
- **Product profiles (P6-05, P6-09, P6-16).** Preserve Hermes as the MVP with future Task Router integration, domain-scoped credentials, GitHub/GitLab, qualified rather than universal native-provider modes, per-deployment profiles, optional-off Terminal Jail, and an independently available gate baseline.
- **Presentation (P6-14, P6-15).** Do not relax the direct-paragraph-beneath-each-figure requirement to “on an adjacent page.” Any font correction must implement the selected NASA Handbook standard, not introduce a different visual system.
- **Evidence and disposition (P6-16).** Adopted text is not a complete design, missing upstream qualification is not itself a semantic defect, and no worker may invent artifact digests, live recovery receipts, runtime conformance, or owner acceptance. Prior P3/P4 dispositions remain immutable; pass-5 intake is additive.

## 2. Finding register

Paths beginning `parts/` or `chapters/` are under `docs/handbook/`. “Primary target” is used only for the section census; every listed implementation target is owned by exactly one wave below.

| New id | Source / severity / pages | Primary target | Correction summary and implementation targets |
|---|---|---|---|
| **P6-01** | P5-RUNTIME-01 · critical · 23, 111, 145–146, 173–176, 196, 209–214, 223–224 | `parts/IV-contract-register.md` | Choose and define one authority/execution protocol: ownership manifest, canonical admission, control plane, idempotent launch identity, per-step timeout/cancel/concurrency, final commit versus gate uncertainty, and runtime conformance matrix. Targets: `docs/SYSTEM-MODEL.yaml`; `docs/handbook/contract-vectors.json` (new); `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`; `chapters/M11-dispatcher.md`. |
| **P6-02** | P5-CUSTODY-01 · critical · 99–100, 108–113, 192–195, 225–228, 247–248 | `chapters/M10-crier.md` | Bind one signed custody chain to one Crier lease across its whole validity interval: request and response principal, clock/nonce, body hash, lease_id, initial visibility/renewal/final validity, and an explicit receiver for the initial reserved resource. Targets: `docs/handbook/contract-vectors.json`; `parts/IV-contract-register.md`; `parts/V-settings.md`; `chapters/M1-provisioning.md`; `chapters/M2-dispatch.md`; `chapters/M10-crier.md`. Static controls: SC-01 and SC-07; reproduce the 60-second lease case. |
| **P6-03** | P5-BOARD-01 · critical · 129–131, 138–139, 167–168, 227–231, 304 | `chapters/M4-board.md` | Unify the criterion record, group-claim ordering/duplicate detection, conditional CAS preconditions, qualification authority, and post-judge settlement so one row cannot remain queued behind its own correction while a sibling closes it early. Targets: `docs/handbook/contract-vectors.json`; `parts/IV-contract-register.md`; `parts/VII-work-derivation.md`; `chapters/M3-repository.md`; `chapters/M4-board.md`. Static control: SC-04. |
| **P6-04** | P5-MEMORY-01 · critical · 227–228, 247–249, 251–252, 279–280, 285–291, 296–298 | `parts/VII-work-derivation.md` | Define one serializable record and hashing domain for worker/wave/round memory, including local commit versus HTTP qualification, post-restart global receipt reconciliation, and the complete failed/partial/retry synchronization state machine. Targets: `docs/handbook/contract-vectors.json`; `parts/II-flows.md`; `parts/IV-contract-register.md`; `parts/V-settings.md`; `parts/VI-failure-risk.md`; `parts/VII-work-derivation.md`. Static control: SC-03. Repeat of P4-MEMORY-01. |
| **P6-05** | P5-INFERENCE-01 · critical · 221–228 | `chapters/M12-inference-proxy.md` | Define the canonical streamed inference contract at the CT-06/CT-28 boundary: envelope, sequence origin, token identity, typed usage/error/final state, Unicode/size fragmentation, and finite body/connection/resource limits. Targets: `docs/handbook/contract-vectors.json`; `parts/IV-contract-register.md`; `chapters/M12-inference-proxy.md`. Static control: SC-06. |
| **P6-06** | P5-BACKUP-01 · critical · 69–71, 246–249, 289–291 | `parts/VI-failure-risk.md` | Give backup holds and mutable-state capture one lease/recovery contract: one off-host manifest authority, expiry and coordinator-loss behavior, and release only after remote upload/readback rather than local capture. Targets: `parts/II-flows.md`; `parts/V-settings.md`; `parts/VI-failure-risk.md`. Static control: SC-08. Repeat of P4-BACKUP-01. |
| **P6-07** | P5-CONFIG-01 · critical · 26, 94–95, 127–128, 138–139, 154–156, 245–249, 256–258 | `parts/V-settings.md` | Publish executable signed profiles covering receipt authority/trust, invocation lifecycle, gate policy, execution artifact, exact inference routes, global timeout, and sandbox—each with type, default, owner, consumer, precedence, and redacted local-secret binding. Targets: `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `parts/V-settings.md`; `chapters/M1-provisioning.md`; `chapters/M3-repository.md`; `chapters/M5-harness.md`; `chapters/M8-safety.md`; `chapters/M12-inference-proxy.md`. Repeat of P4-CONFIG-01. |
| **P6-08** | P5-API-01 · critical · 25–29, 99–102, 165–166, 209–210, 226–227 | `parts/I-system-arrangement.md` | Supply the missing trust/operation state machines: dispatch-grant life cycle, certificate renewal, capability/Gateway semantics, enrollment secret resolution, result/return APIs, and post-enrollment participant binding at Crier and Scheduler. Targets: `docs/handbook/contract-vectors.json`; `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `chapters/M1-provisioning.md`; `chapters/M7-github.md`; `chapters/M9-scheduler.md`; `chapters/M10-crier.md`; `chapters/M11-dispatcher.md`. |
| **P6-09** | P5-ISOLATION-01 · critical · 93–94, 136, 143–145, 153, 209, 257–258 | `chapters/M1-provisioning.md` | Make the credential lifetime and artifact isolation enforceable: delivered credential types, non-env transport, atomic owner-only staging, fanout handling, revocation, and a fail-closed containment launcher with no-parent/lifecycle semantics that cannot cross backends. Targets: `parts/V-settings.md`; `chapters/M1-provisioning.md`; `chapters/M5-harness.md`; `chapters/M8-safety.md`; `chapters/M11-dispatcher.md`. |
| **P6-10** | P5-SETTLEMENT-01 · high · 23, 48, 145–146, 196, 209–214, 225–228, 296–298 | `parts/VII-work-derivation.md` | Define one terminal-result state machine covering timeout trees, worker exit versus control death, idempotent commit, process exit before durable evidence, and launch-failure disposition—including no third verdict for a clean exit with no committed result. Targets: `docs/handbook/contract-vectors.json`; `parts/I-system-arrangement.md`; `parts/II-flows.md`; `parts/IV-contract-register.md`; `parts/VII-work-derivation.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`; `chapters/M11-dispatcher.md`. Repeat of P4-RECOVERY-01. |
| **P6-11** | P5-LIMITS-01 · high · 31, 111, 146, 225, 245–247, 250–251, 298, 302 | `parts/V-settings.md` | Normalize numeric resources and deadline scopes: include the global harness deadline in turn scheduling, make the 20,000 Round total legal, replace boolean-with-budget text by a typed resource, and pin every default against a shared formula. Targets: `docs/handbook/contract-vectors.json`; `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `parts/V-settings.md`; `parts/VII-work-derivation.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`. Static controls: SC-02 and SC-09. Repeat of P4-BUDGET-01. |
| **P6-12** | P5-METRICS-01 · high · 85–86, 167, 189, 218–219, 247, 299 | `chapters/M0-shared-contract.md` | Make telemetry a specified, validated event contract and global projection: map M7–M12 events, normalize retention/access, bind live metrics and network failures to Factory task identity, and qualify M7’s five declared counters at emission and scrape. Targets: `parts/IV-contract-register.md`; `parts/V-settings.md`; `parts/VII-work-derivation.md`; `chapters/M0-shared-contract.md`; `chapters/M2-dispatch.md`; `chapters/M7-github.md`; `chapters/M8-safety.md`; `chapters/M9-scheduler.md`; `chapters/M10-crier.md`; `chapters/M11-dispatcher.md`; `chapters/M12-inference-proxy.md`. |
| **P6-13** | P5-GATES-01 · high · 40–41, 118–120, 225, 301 | `chapters/M3-repository.md` | Split publication, mechanical policy, and model judgment into separately identified artifacts; make harness checks and publication independent of uncertain model judgment, and close on published machine evidence rather than an uncertain push verdict. Targets: `docs/handbook/contract-vectors.json`; `parts/II-flows.md`; `parts/IV-contract-register.md`; `parts/VII-work-derivation.md`; `chapters/M3-repository.md`. Repeat of P4-PUBLICATION-01. |
| **P6-14** | P5-FIGURES-01 · high · 2–3, 37–78, 80–91, 99–218 | `docs/handbook/figures/system-map.svg` | Re-render and update all 32 figures from the integrated model: per-target fanout, host residency, missing gateway/Hermes/9router nodes, absent signature/grant/CAS/readback edges, label collisions, full M12 legs, and the F15.1 pre-durable-freeze contradiction. Targets: `docs/SYSTEM-MODEL.yaml`; `scripts/gen_handbook_figures.py`; `parts/00-overview.md`; `parts/II-flows.md`; every file under `docs/handbook/figures/` enumerated in Wave 4. Repeat of P4-CONSISTENCY-01; this consumes rather than reopens P5-A-30’s stale-C-svg handoff. |
| **P6-15** | P5-LAYOUT-01 · high · 2, 39, 41, 56, 143, 152, 164, 208, 269, 271, 275, 277, 284, 287, 293, 320–329 | `scripts/build_book.py` | Repair the actual presentation stack: use the NASA-standard body font/size rather than the serif fallback, place each explanatory paragraph directly beneath its figure, stop orphan flow continuations, and split long tables with full continuation headers instead of cropped strip headers. Targets: `docs/handbook/BOOK.yaml`; `scripts/build_book.py`; `scripts/book_style.py`; `parts/II-flows.md`; `parts/IX-disposition-log.md`; `chapters/M6-documentation.md`; `docs/handbook/figures/F1.svg`; `docs/handbook/figures/F10.svg`. Repeat of P4-LAYOUT-01. |
| **P6-16** | P5-ISSUE-01 · medium · 5, 24, 101, 157, 211, 229–231, 312–313, 321–329 | `parts/IX-disposition-log.md` | Reissue the complete artifact with current date/revision/release identity, qualify legacy V7 registry coverage and experimental provisions, correct incomplete P5-ISSUE stage mapping and adoption text, and attach current build/readback evidence to every pass-5 disposition. Targets: `docs/handbook/BOOK.yaml`; `parts/00-overview.md`; `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `parts/VIII-delivery.md`; `parts/IX-disposition-log.md`; `chapters/M1-provisioning.md`; `chapters/M6-documentation.md`; `chapters/M11-dispatcher.md`. Repeat of P4-DISPOSITION-01. |

## 3. Repeat and landed-design crosswalk

P4 dispositions are the direct repeat map in `CF2A-01-pass5-prior-findings.txt`. P3 antecedents below come from `PASS4-PLAN.md`; they are cross-references, not reopened rows. **P5G** means the landed pass-5 design-hardening generation: Wave A `b26d2ecc` (canonical envelope `cf2a.v1`), Wave B `00ce1825` (M2/IV and module protocols), and Wave C `d5986294` plus its landed fencing/watermark/resident-foreman contract set. The P5G column names the existing requirements each correction must integrate, not discard.

| P6 | Direct P4 repeat | P3 antecedent crosswalk | P5G landed-design crosswalk |
|---|---|---|---|
| P6-01 | New; P4-PROTOCOL-01, P4-RECOVERY-01 and P4-CONSISTENCY-01 are related, not duplicate disposition ids | P3-INT-01; P3-DISPATCH-01; P3-WORK-01; P3-RECOVERY-01; P3-CONSISTENCY-01; P3-DIAGRAM-01 | P5-A-16/18/19/28; P5-B-01/05/07/10/11/12; P5-C-02/13 |
| P6-02 | New | None direct; integrates the P3 protocol/provision chain without rewriting it | P5-A-05/07; P5-B-01/03/08; P5-C-06/07/12 |
| P6-03 | New; related to P4-CLAIM-01 | P3-BOARD-01; P3-RECOVERY-01 (through the claim-family chain only) | P5-A-15/18/19; P5-B-04/20/21/22/23/24/26; P5-C-01/16/38 |
| P6-04 | **P4-MEMORY-01** | P3-MEM-01 | P5-A-13/14/17; P5-B-08/09/10; P5-C-28/29/36 |
| P6-05 | New; related to P4-PROXY-01 | P3-PROXY-01 (related proxy chain, not a declared repeat) | P5-A-26/28; P5-B-08/37; P5-C-22/23/24/25 |
| P6-06 | **P4-BACKUP-01** | P3-RECOVERY-02; P3-FLW-02 | P5-A-02/06; P5-B-27; P5-C-26/27 |
| P6-07 | **P4-CONFIG-01** | P3-CONFIG-01; P3-CONFIG-02 | P5-A-01/04/11/12/32; P5-B-06/18/24/28/30/33; P5-C-03/04/30/33 |
| P6-08 | New; integrates P4-AUTH-01 and P4-MANAGER-01 surfaces | P3-FORGE-01; P3-ACCESS-01; P3-PROXY-01; P3-MANAGER-01; P3-CONFIG-01; P3-SCHED-01 | P5-A-03/04/05/07/08/09/22; P5-B-03/14/18/23; P5-C-06/17/20/21 |
| P6-09 | New; related to P4-DEPLOY-01 and P4-AUTH-01 | P3-PROVISION-01; P3-SAFETY-01; P3-FORGE-01; P3-ACCESS-01; P3-PROXY-01 | P5-A-02/07/12/22/23; P5-B-16/23/28/29; P5-C-17/18/33 |
| P6-10 | **P4-RECOVERY-01** | P3-RECOVERY-01; P3-DISPATCH-01 | P5-A-08/14/16/17/25; P5-B-10/11; P5-C-10/11/14/29/36 |
| P6-11 | **P4-BUDGET-01** | P3-RECOVERY-01; P3-CONFIG-02; P3-WORK-01 | P5-A-10/14/17; P5-B-08/28; P5-C-14/30 |
| P6-12 | New; related to P4-EVENTS-01 and P4-CLAIM-01 | P3-OPS-01; P3-CONFIG-01; P3-BOARD-01 (related evidence chain) | P5-A-26/33; P5-B-31/38; P5-C-08/32/37 |
| P6-13 | **P4-PUBLICATION-01** | P3-REPO-01; P3-WORK-01; P3-CONSISTENCY-01 | P5-A-20; P5-B-24/25/26/36; P5-C-34/35/38 |
| P6-14 | **P4-CONSISTENCY-01** | P3-CONSISTENCY-01; P3-DIAGRAM-01 | P5-A-13/26/27/28/30/31; P5-B-36/38; P5-C-37 |
| P6-15 | **P4-LAYOUT-01** | P3-LAYOUT-01; P3-LAYOUT-02 | P5-A-30/31; P5-B-33/36; no direct P5-C layout row |
| P6-16 | **P4-DISPOSITION-01** | P3-CONSISTENCY-01; P3-MODULES-01 | P5-A-30/31/32; P5-B-06/33/34/36/37/39; P5-C-31/34/35 |

## 4. Disjoint integration waves

The waves are sequential at the contract boundary: Wave 1 freezes the canonical records and vectors; Waves 2 and 3 may then run in parallel because they share no file; Wave 4 starts only after both integrate. No two waves own the same file. `PASS5-PLAN.md` is this triage artifact, not an implementation target.

### Wave 1 — canonical records, authority and executable vectors

**Owned files (exactly 4):**

- `docs/SYSTEM-MODEL.yaml`
- `docs/handbook/contract-vectors.json` **(new)**
- `docs/handbook/parts/IV-contract-register.md`
- `docs/handbook/parts/VII-work-derivation.md`

**Lead findings:** P6-01, P6-03, P6-04, P6-10, P6-11, P6-12, P6-13; supply the shared vector entries required by every other finding.

**Contract:** freeze object ownership, authority transitions, the canonical envelope/custody chain, criterion and claim records, memory digest domain, terminal settlement matrix, numeric budget formulas, telemetry identity, and publication-versus-judgment evidence classes. The JSON vector file must be the single normative source used by later chapter examples, not a second independently drifting specification.

**Exit evidence:** SC-01…SC-09 each have a passing vector or an explicitly documented non-applicability reason; the 60-second lease, 20,000 Round allowance, memory digest, supervisor request, first streamed fragment, signed read, backup expiry, and harness-timeout cases all execute or validate against the same canonical definitions. No module file is edited in this wave.

### Wave 2 — control-plane, configuration, custody and recovery modules

**Owned files (exactly 10):**

- `docs/handbook/parts/I-system-arrangement.md`
- `docs/handbook/parts/V-settings.md`
- `docs/handbook/parts/VI-failure-risk.md`
- `docs/handbook/chapters/M1-provisioning.md`
- `docs/handbook/chapters/M2-dispatch.md`
- `docs/handbook/chapters/M5-harness.md`
- `docs/handbook/chapters/M8-safety.md`
- `docs/handbook/chapters/M9-scheduler.md`
- `docs/handbook/chapters/M10-crier.md`
- `docs/handbook/chapters/M11-dispatcher.md`

**Lead findings:** P6-02, P6-06, P6-07, P6-08, P6-09; implement the module faces of P6-01, P6-10, P6-11 and P6-12 against Wave 1’s records.

**Contract:** make the signed profile and authority graph implementable; align dispatch grant, enrollment, certificate, lease, process/containment, timeout/cancel, backup barrier and terminal-result behavior. Preserve Crier custody and Scheduler settlement. Secret values stay out of the book; only scoped secret identities and resolvers are specified.

**Exit evidence:** validate every consumer against the shared vectors; prove the lease and timeout cases no longer depend on chapter-local defaults; enumerate failed launch, worker death, control-plane death, commit uncertainty and backup coordinator loss with one terminal outcome each.

### Wave 3 — board, publication, provider and telemetry modules

**Owned files (exactly 5):**

- `docs/handbook/chapters/M0-shared-contract.md`
- `docs/handbook/chapters/M3-repository.md`
- `docs/handbook/chapters/M4-board.md`
- `docs/handbook/chapters/M7-github.md`
- `docs/handbook/chapters/M12-inference-proxy.md`

**Lead findings:** P6-05, P6-13 and the module-specific faces of P6-03, P6-07, P6-08 and P6-12.

**Contract:** consume the common criterion/claim schema, typed inference stream, exact routes, signed-profile controls and event projection. Separate mechanical policy from model judgment and make uncertain publication non-blocking for a conforming worker’s other checks. Instrument the M7 five-counter family at both emission and scrape without treating localhost observation as external qualification.

**Exit evidence:** criterion round-trip, group-claim duplicate/correction cases, CT-06/CT-28 stream fragmentation/termination cases, exact-route cases, publication-versus-judgment matrix, and M7–M12 telemetry validation all reference the Wave 1 vectors.

### Wave 4 — integrated figures, presentation, reissue, dispositions and build

**Owned files (exactly 41):**

- `docs/handbook/BOOK.yaml`
- `docs/handbook/parts/00-overview.md`
- `docs/handbook/parts/II-flows.md`
- `docs/handbook/parts/VIII-delivery.md`
- `docs/handbook/parts/IX-disposition-log.md`
- `docs/handbook/chapters/M6-documentation.md`
- `scripts/build_book.py`
- `scripts/book_style.py`
- `scripts/gen_handbook_figures.py`
- `docs/handbook/figures/system-map.svg`
- `docs/handbook/figures/board-lifecycle.svg`
- `docs/handbook/figures/tick-lifecycle.svg`
- `docs/handbook/figures/module-M0.svg`
- `docs/handbook/figures/module-M1.svg`
- `docs/handbook/figures/module-M2.svg`
- `docs/handbook/figures/module-M3.svg`
- `docs/handbook/figures/module-M4.svg`
- `docs/handbook/figures/module-M5.svg`
- `docs/handbook/figures/module-M6.svg`
- `docs/handbook/figures/module-M7.svg`
- `docs/handbook/figures/module-M8.svg`
- `docs/handbook/figures/module-M9.svg`
- `docs/handbook/figures/module-M10.svg`
- `docs/handbook/figures/module-M11.svg`
- `docs/handbook/figures/module-M12.svg`
- `docs/handbook/figures/F1.svg`
- `docs/handbook/figures/F2.svg`
- `docs/handbook/figures/F3.svg`
- `docs/handbook/figures/F4.svg`
- `docs/handbook/figures/F5.svg`
- `docs/handbook/figures/F6.svg`
- `docs/handbook/figures/F7.svg`
- `docs/handbook/figures/F8.svg`
- `docs/handbook/figures/F9.svg`
- `docs/handbook/figures/F10.svg`
- `docs/handbook/figures/F11.svg`
- `docs/handbook/figures/F12.svg`
- `docs/handbook/figures/F13.svg`
- `docs/handbook/figures/F14.svg`
- `docs/handbook/figures/F15.svg`
- `docs/handbook/figures/F16.svg`

**Lead findings:** P6-14, P6-15, P6-16; final integration of every earlier wave.

**Contract:** regenerate all 32 figures from the integrated model, correct drawing topology and F15.1 ordering, repair typography/figure-reference/table layout, update issue identity and maturity notices, and append one row per P6 finding with source page, correction, build commit, built page and independent visual readback. Do not rewrite P3/P4 history or mark missing upstream/runtime qualification as a semantic defect.

**Exit evidence:** clean `python3 scripts/handbook_lint.py`; successful `python3 scripts/build_book.py docs/handbook/CODE-FACTORY-HANDBOOK.pdf`; 32/32 figures regenerated and visually inspected; direct explanatory paragraph beneath every figure; font census shows the selected NASA body face; no cropped continuation strip; current issue identity; final PDF page/content census and disposition evidence. Rendered-page inspection and runtime qualification remain separate evidence classes.

## 5. Census and integration acceptance

Primary-target census (each finding counted once):

| Target section | Count | Finding ids |
|---|---:|---|
| Front matter / overview | 0 | — |
| Part I — arrangement | 1 | P6-08 |
| Part II — flows | 0 as primary; integration owner in Wave 4 | — |
| Part III — modules | 6 | P6-02, P6-03, P6-05, P6-09, P6-12, P6-13 |
| Part IV — contracts | 1 | P6-01 |
| Part V — settings | 2 | P6-07, P6-11 |
| Part VI — failure/risk | 1 | P6-06 |
| Part VII — work derivation | 2 | P6-04, P6-10 |
| Part VIII — delivery | 0 as primary; reissue target in Wave 4 | — |
| Part IX — dispositions | 1 | P6-16 |
| Figures / generator | 1 | P6-14 |
| Build / layout scripts | 1 | P6-15 |
| **Total** | **16** | **P6-01…P6-16** |

Integration is accepted only when:

1. Every P6 row has a landed correction and a pass-5 disposition with source/build/readback references; none is closed from a commit message alone.
2. All nine static conflict cases are green against the same shared vector corpus, including the exact 60-second Crier lease and 20,000 Round allowance cases.
3. Every module example is byte- or schema-consistent with the canonical record it consumes; there is no second prose-only definition of the same wire object.
4. The ownership/custody chain is executable from admission through independently verified settlement, and all recovery/terminal branches reconcile without duplicate settlement or orphan work.
5. Profiles, secret bindings, containment, retention, telemetry and gate evidence are tested at their declared boundaries; external adapters and live recovery remain explicitly unqualified until separately measured.
6. The final book is rebuilt and visually re-read after integration. Figure topology, direct references, fonts, long-table continuations, current issue identity and disposition completeness are checked in the artifact, not inferred from Markdown.

This plan does not claim runtime conformance, upstream qualification, live deployment, or owner acceptance.
